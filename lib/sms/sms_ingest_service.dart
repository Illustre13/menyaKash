import 'dart:async';

import 'package:drift/drift.dart' show Value;
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
    this.matchedByProvider = const {},
  });

  final int totalMessages;
  final int processedMessages;
  final int matchedTransactions;

  /// Provider display name → matched-transaction count so far — lets
  /// the scan screen show "MTN Mobile Money: 412, Equity Bank: 38"
  /// instead of one opaque combined total when several providers are
  /// selected (spec #1). Keyed by display name, not code, since that's
  /// what the UI shows directly with no extra lookup.
  final Map<String, int> matchedByProvider;

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

    final providerSnapshot = await snapshotSelectedProviders(_db);
    final knownSenders = providerSnapshot.expand((p) => p.senderPatterns).toSet();
    final knownHashes = (await _db.select(_db.smsMessages).get()).map((m) => m.smsHash).toSet();

    // id -> display name, so per-provider progress can show a real
    // name ("MTN Mobile Money: 412") instead of an opaque provider id.
    final providerNames = {
      for (final row in await _db.select(_db.financialProviders).get()) row.id: row.displayName,
    };
    final matchedByProvider = <String, int>{
      for (final provider in providerSnapshot) providerNames[provider.providerId] ?? '?': 0,
    };

    // Only messages from a recognized sender are worth spending isolate
    // time on at all — same "unknown sender, ignore" filtering v1 and
    // the old per-message path both did, just applied up front instead
    // of per message.
    final candidates = <RawSmsSnapshot>[];
    DateTime? latestReceivedAt;
    for (final message in messages) {
      final sender = message.address;
      final body = message.body;
      if (sender == null || body == null || !knownSenders.contains(sender)) continue;
      final receivedAt = message.date != null
          ? DateTime.fromMillisecondsSinceEpoch(message.date!)
          : DateTime.now();
      if (latestReceivedAt == null || receivedAt.isAfter(latestReceivedAt)) {
        latestReceivedAt = receivedAt;
      }
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

      // Per-provider breakdown (spec #1): counted directly off this
      // chunk's parse results rather than re-querying the DB, since
      // each ParsedSmsResult already carries the resolved providerId
      // and whether it was actually parsed into a transaction.
      for (final result in toWrite) {
        if (!result.wasParsed || result.providerId == null) continue;
        final name = providerNames[result.providerId!];
        if (name == null) continue;
        matchedByProvider[name] = (matchedByProvider[name] ?? 0) + 1;
      }

      yield ScanProgress(
        totalMessages: total,
        processedMessages: processed,
        matchedTransactions: matched,
        matchedByProvider: Map.unmodifiable(matchedByProvider),
      );
    }

    // Establishes the incremental-scan watermark (spec review batch
    // item #3) right after the full historical scan, so the very next
    // call to scanNewMessagesSince() has something to catch up from
    // instead of no-oping on a null watermark. Uses the newest message
    // actually seen in the inbox, not DateTime.now() — a scan that ran
    // against a slightly stale copy of the inbox (e.g. mid-sync) must
    // not silently skip messages between "newest seen" and "now".
    if (latestReceivedAt != null) {
      await _setLastIncrementalScanAt(latestReceivedAt);
    }
  }

  /// Catches up on any provider SMS that arrived since the last
  /// incremental scan (or since [sinceOverride] if given), without
  /// re-reading the whole inbox — the fix for the confirmed real
  /// "balance looked right once, then went stale" complaint (review
  /// batch item #3). The live listener ([startLiveListener]) already
  /// catches messages that arrive while the app is running; this
  /// exists for everything that arrived while it wasn't — e.g. between
  /// app launches, or immediately after enabling a new provider whose
  /// history predates this install.
  ///
  /// Deliberately a separate method from [scanHistoricalInbox] rather
  /// than that method taking an optional "since" parameter: the
  /// historical scan's whole reason to exist is "read everything, once,
  /// at onboarding" with its own progress-UI contract
  /// ([ScanProgress]/chunked isolate parsing for a potentially huge
  /// inbox); this method's workload is "usually zero new messages,
  /// occasionally a handful" — no chunking, no isolate hop, no progress
  /// stream needed, just a bounded query and a single batch write.
  /// Merging them into one parameterized method would make the common
  /// case (few messages) pay for machinery sized for the rare case
  /// (thousands of messages).
  ///
  /// Returns how many new transactions were matched, so a caller (e.g.
  /// Home's pull-to-refresh) can show something happened.
  Future<int> scanNewMessagesSince({DateTime? sinceOverride}) async {
    final profile = await _db.select(_db.userProfile).getSingleOrNull();
    final since = sinceOverride ?? profile?.lastIncrementalScanAt;

    // No watermark yet (a fresh install that hasn't finished onboarding,
    // or an upgrade from before this feature existed) — nothing to
    // "catch up" on; the next full historical scan or the live listener
    // will establish history from here. Scanning the entire inbox here
    // would just duplicate what onboarding's historical scan already
    // does, with none of its chunking/progress UI.
    if (since == null) return 0;

    final providerSnapshot = await snapshotSelectedProviders(_db);
    if (providerSnapshot.isEmpty) return 0;
    final knownSenders = providerSnapshot.expand((p) => p.senderPatterns).toSet();

    final messages = await _telephony.getInboxSms(
      columns: [
        telephony_pkg.SmsColumn.ADDRESS,
        telephony_pkg.SmsColumn.BODY,
        telephony_pkg.SmsColumn.DATE,
      ],
      filter: telephony_pkg.SmsFilter.where(telephony_pkg.SmsColumn.DATE)
          .greaterThan(since.millisecondsSinceEpoch.toString()),
    );

    final knownHashes = (await _db.select(_db.smsMessages).get()).map((m) => m.smsHash).toSet();

    final candidates = <RawSmsSnapshot>[];
    var latestSeen = since;
    for (final message in messages) {
      final sender = message.address;
      final body = message.body;
      if (sender == null || body == null || !knownSenders.contains(sender)) continue;
      final receivedAt = message.date != null
          ? DateTime.fromMillisecondsSinceEpoch(message.date!)
          : DateTime.now();
      if (receivedAt.isAfter(latestSeen)) latestSeen = receivedAt;
      candidates.add(RawSmsSnapshot(sender: sender, body: body, receivedAt: receivedAt));
    }

    var matched = 0;
    if (candidates.isNotEmpty) {
      final parsed = await compute(
        parseChunk,
        ParseChunkInput(messages: candidates, providers: providerSnapshot),
      );

      final toWrite = <ParsedSmsResult>[];
      for (final result in parsed) {
        if (knownHashes.contains(result.smsHash)) continue;
        knownHashes.add(result.smsHash);
        toWrite.add(result);
      }

      final outcome = await _processor.processBatch(toWrite);
      matched = outcome.matched;
    }

    await _setLastIncrementalScanAt(latestSeen);
    return matched;
  }

  Future<void> _setLastIncrementalScanAt(DateTime timestamp) async {
    final existing = await _db.select(_db.userProfile).getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.userProfile).insert(
            UserProfileCompanion.insert(lastIncrementalScanAt: Value(timestamp)),
          );
      return;
    }
    await (_db.update(_db.userProfile)..where((tbl) => tbl.id.equals(existing.id)))
        .write(UserProfileCompanion(lastIncrementalScanAt: Value(timestamp)));
  }

  /// Registers a listener for new incoming SMS. Must be called after
  /// permissions are granted; safe to call once at app startup.
  void startLiveListener() {
    _telephony.listenIncomingSms(
      onNewMessage: (telephony_pkg.SmsMessage message) async {
        final sender = message.address;
        final body = message.body;
        if (sender == null || body == null) return;
        final smsId = await _storeIfSelectedProvider(sender, body, DateTime.now());
        if (smsId != null) {
          await _processor.processOneById(smsId);
        }
      },
      listenInBackground: false,
    );
  }

  /// Stores [body] as a new [SmsMessages] row if — and only if —
  /// [sender] resolves to a provider the user has actually enabled
  /// (see [UserFinancialSources]). Returns the new row's id, or null if
  /// the sender is unrecognized, resolves to a provider the user hasn't
  /// selected (spec #11: only enabled providers are scanned/processed
  /// — same rule the historical scan applies via
  /// [snapshotSelectedProviders]), or if this exact message was already
  /// stored (dedup via the unique hash — see [hashSmsMessage]).
  Future<int?> _storeIfSelectedProvider(String sender, String body, DateTime receivedAt) async {
    final detection = await _detector.detect(sender: sender, body: body);
    if (detection == null) return null;

    final isSelected = await (_db.select(_db.userFinancialSources)
          ..where((tbl) => tbl.providerId.equals(detection.provider.id)))
        .getSingleOrNull();
    if (isSelected == null) return null;

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

/// Plain-data snapshot of the [FinancialProviders] rows the user has
/// explicitly enabled ([UserFinancialSources]) and their known senders,
/// for isolate-safe use in [SmsIngestService.scanHistoricalInbox].
///
/// Selection-filtered by design (spec #11): a user who enabled only MTN
/// MoMo must not have Equity/BK/Airtel messages scanned, stored, or
/// processed — so unselected providers are absent from the snapshot
/// entirely, which removes their senders from the scan's candidate
/// filter AND removes them as resolution targets for shared senders
/// (e.g. `M-Money` carries both MTN MoMo and eKash: with only MTN
/// selected, an eKash-bodied message fails MTN's not-contains-ekash
/// disambiguator, resolves to no provider, and is skipped). An empty
/// selection yields an empty snapshot — the scan scans nothing, which
/// is the honest reading of "no providers enabled," not a fallback to
/// everything.
///
/// [DisambiguatorRule] mirrors the one real body-content disambiguation
/// rule this app has today (`provider_detector_factory.dart`). If a
/// future provider needs a different disambiguator, both this mapping
/// and the live [ProviderDetector] registration need a matching update
/// — they must stay in sync for the isolate path to behave identically
/// to the live single-message path.
///
/// Top-level (not a method on [SmsIngestService]) so tests can exercise
/// the selection filtering against an in-memory database without
/// instantiating the Telephony-backed service.
Future<List<ProviderSnapshot>> snapshotSelectedProviders(AppDatabase db) async {
  final selections = await db.select(db.userFinancialSources).get();
  final selectedIds = selections.map((s) => s.providerId).toSet();

  final providers = await db.select(db.financialProviders).get();
  final senders = await db.select(db.providerSenders).get();

  return providers.where((p) => selectedIds.contains(p.id)).map((provider) {
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
