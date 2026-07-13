import 'dart:async';

import 'package:flutter/foundation.dart' show compute;
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart' as telephony_pkg;

import '../data/database.dart';
import '../providers/provider_detection.dart';
import 'isolate_parsing.dart';
import 'sms_processor.dart';

/// Messages per [compute] call during the historical scan (spec Phase
/// 10) — large enough to amortize isolate spawn/message-passing
/// overhead, small enough that the progress UI updates roughly every
/// 1-2 seconds of scan time and no single chunk's round-trip becomes
/// its own visible stall. Tuned against a real ~8,364-message export;
/// revisit if real-device profiling suggests otherwise.
const _scanChunkSize = 400;

/// Snapshot of an in-progress historical inbox scan, emitted after every
/// message so the onboarding screen can show live counts instead of a
/// blank spinner while potentially thousands of SMS are scanned.
class ScanProgress {
  const ScanProgress({
    required this.totalMessages,
    required this.processedMessages,
    required this.matchedTransactions,
  });

  final int totalMessages;
  final int processedMessages;
  final int matchedTransactions;

  bool get isDone => processedMessages >= totalMessages;
  double get fraction => totalMessages == 0 ? 1.0 : processedMessages / totalMessages;
}

/// The first half of the ingestion pipeline: permission handling and
/// getting SMS off the device and into permanent [SmsMessages] evidence
/// rows — nothing more. This class deliberately does NOT parse message
/// bodies or write [Transactions]/[UnparsedMessages] itself anymore
/// (that moved to [SmsProcessor]) — see docs/AUDIT_PHASE_0.md §1 for why
/// "SMS directly becomes an expense" was the wrong shape. Nothing in
/// this file ever touches the network — it reads the on-device SMS
/// provider and writes to the local sqlite database only.
class SmsIngestService {
  SmsIngestService(this._db, this._detector, this._processor);

  final AppDatabase _db;
  final ProviderDetector _detector;
  final SmsProcessor _processor;
  final telephony_pkg.Telephony _telephony = telephony_pkg.Telephony.instance;

  Future<bool> requestPermissions() async {
    final smsGranted = await Permission.sms.request();
    return smsGranted.isGranted;
  }

  Future<bool> hasPermissions() async {
    return await Permission.sms.isGranted;
  }

  /// Scans the full existing SMS inbox once — intended for first-run
  /// setup, so every transaction the user already has shows up in
  /// analytics immediately rather than only messages arriving from here
  /// on. Emits a [ScanProgress] after every chunk (not every single
  /// message — see [_scanChunkSize]) so a progress UI can track it; the
  /// final emitted value always has [ScanProgress.isDone] true.
  ///
  /// Safe to call again later (e.g. a manual "rescan" action) — unlike
  /// v1, this is now genuinely safe: every [SmsMessages] insert is
  /// deduplicated against [SmsMessages.smsHash] (see
  /// [hashSmsMessage]), so re-scanning the same inbox range is a no-op
  /// rather than a double-insert (the v1 gap documented in
  /// docs/AUDIT_PHASE_0.md §3.5).
  ///
  /// Restructured for spec Phase 10 (confirmed real "Skipped N frames"
  /// jank during this scan on a real ~8,364-message inbox, all on the
  /// main isolate): sender-detection and regex parsing — the CPU-bound
  /// work — now run on a background isolate via [compute], using
  /// plain-data snapshots of the provider registry and the set of
  /// already-known hashes captured once up front, so neither the
  /// isolate call nor the detection step needs a live database handle.
  /// The actual database writes stay on the main isolate (drift's
  /// connection can't be shared across isolates) but are batched per
  /// chunk via [SmsProcessor.processBatch] instead of several
  /// independent round-trips per message.
  Stream<ScanProgress> scanHistoricalInbox() async* {
    final messages = await _telephony.getInboxSms(
      columns: [
        telephony_pkg.SmsColumn.ADDRESS,
        telephony_pkg.SmsColumn.BODY,
        telephony_pkg.SmsColumn.DATE,
      ],
    );

    final providerSnapshot = await _snapshotProviders();
    final knownSenders = providerSnapshot.expand((p) => p.senderPatterns).toSet();
    final knownHashes = (await _db.select(_db.smsMessages).get()).map((m) => m.smsHash).toSet();

    // Only messages from a recognized sender are worth spending isolate
    // time on at all — same "unknown sender, ignore" filtering v1 and
    // the old per-message path both did, just applied up front instead
    // of per message.
    final candidates = <RawSmsSnapshot>[];
    for (final message in messages) {
      final sender = message.address;
      final body = message.body;
      if (sender == null || body == null || !knownSenders.contains(sender)) continue;
      final receivedAt = message.date != null
          ? DateTime.fromMillisecondsSinceEpoch(message.date!)
          : DateTime.now();
      candidates.add(RawSmsSnapshot(sender: sender, body: body, receivedAt: receivedAt));
    }

    final total = candidates.length;
    var processed = 0;
    var matched = 0;

    yield ScanProgress(totalMessages: total, processedMessages: 0, matchedTransactions: 0);

    for (var start = 0; start < candidates.length; start += _scanChunkSize) {
      final chunk = candidates.skip(start).take(_scanChunkSize).toList();

      final parsedChunk = await compute(
        parseChunk,
        ParseChunkInput(messages: chunk, providers: providerSnapshot),
      );

      // Skip anything whose hash already exists (a prior scan already
      // stored it) — mirrors the old per-message dedup check, just
      // applied against the up-front snapshot instead of a query per
      // message. Newly-seen hashes within this same scan are added to
      // the running set so a duplicate SMS appearing twice in one
      // inbox export doesn't get stored twice either.
      final toWrite = <ParsedSmsResult>[];
      for (final result in parsedChunk) {
        if (knownHashes.contains(result.smsHash)) continue;
        knownHashes.add(result.smsHash);
        toWrite.add(result);
      }

      final outcome = await _processor.processBatch(toWrite);
      matched += outcome.matched;
      processed += chunk.length;

      yield ScanProgress(
        totalMessages: total,
        processedMessages: processed,
        matchedTransactions: matched,
      );
    }
  }

  /// Plain-data snapshot of every seeded [FinancialProviders] row and
  /// its known senders, for isolate-safe use in [scanHistoricalInbox].
  /// [DisambiguatorRule] mirrors the one real body-content
  /// disambiguation rule this app has today
  /// (`provider_detector_factory.dart` — MTN's `M-Money` shortcode
  /// carrying both MoMo and eKash traffic). If a future provider needs
  /// a different disambiguator, both this mapping and the live
  /// [ProviderDetector] registration need a matching update — they
  /// must stay in sync for the isolate path to behave identically to
  /// the live single-message path.
  Future<List<ProviderSnapshot>> _snapshotProviders() async {
    final providers = await _db.select(_db.financialProviders).get();
    final senders = await _db.select(_db.providerSenders).get();

    return providers.map((provider) {
      final patterns = senders
          .where((s) => s.providerId == provider.id)
          .map((s) => s.senderPattern)
          .toList();
      final disambiguator = switch (provider.code) {
        'ekash_rw' => DisambiguatorRule.containsEkash,
        'mtn_momo_rw' => DisambiguatorRule.notContainsEkash,
        _ => DisambiguatorRule.none,
      };
      return ProviderSnapshot(
        providerId: provider.id,
        providerCode: provider.code,
        senderPatterns: patterns,
        disambiguator: disambiguator,
      );
    }).toList();
  }

  /// Registers a listener for new incoming SMS. Must be called after
  /// permissions are granted; safe to call once at app startup.
  void startLiveListener() {
    _telephony.listenIncomingSms(
      onNewMessage: (telephony_pkg.SmsMessage message) async {
        final sender = message.address;
        final body = message.body;
        if (sender == null || body == null) return;
        final smsId = await _storeIfKnownSender(sender, body, DateTime.now());
        if (smsId != null) {
          await _processor.processOneById(smsId);
        }
      },
      listenInBackground: false,
    );
  }

  /// Stores [body] as a new [SmsMessages] row if — and only if —
  /// [sender] matches a known [FinancialProviders] sender pattern.
  /// Returns the new row's id, or null if the sender is unrecognized
  /// (nothing is stored for messages from unknown senders, same
  /// filtering behavior as v1) or if this exact message was already
  /// stored (dedup via the unique hash — see [hashSmsMessage]).
  Future<int?> _storeIfKnownSender(String sender, String body, DateTime receivedAt) async {
    final detection = await _detector.detect(sender: sender, body: body);
    if (detection == null) return null;

    final hash = hashSmsMessage(sender: sender, body: body, receivedAt: receivedAt);
    final existing =
        await (_db.select(_db.smsMessages)..where((tbl) => tbl.smsHash.equals(hash)))
            .getSingleOrNull();
    if (existing != null) return null;

    return _db.into(_db.smsMessages).insert(
          SmsMessagesCompanion.insert(
            sender: sender,
            body: body,
            receivedAt: receivedAt,
            smsHash: hash,
          ),
        );
  }
}
