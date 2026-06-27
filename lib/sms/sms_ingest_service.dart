import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart' as telephony_pkg;

import '../data/database.dart';
import '../providers/provider_detection.dart';
import 'sms_processor.dart';

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
  /// on. Emits a [ScanProgress] after every message (stored or not) so
  /// a progress UI can track it; the final emitted value always has
  /// [ScanProgress.isDone] true.
  ///
  /// Safe to call again later (e.g. a manual "rescan" action) — unlike
  /// v1, this is now genuinely safe: every [SmsMessages] insert is
  /// deduplicated against [SmsMessages.smsHash] (see
  /// [hashSmsMessage]), so re-scanning the same inbox range is a no-op
  /// rather than a double-insert (the v1 gap documented in
  /// docs/AUDIT_PHASE_0.md §3.5).
  Stream<ScanProgress> scanHistoricalInbox() async* {
    final messages = await _telephony.getInboxSms(
      columns: [
        telephony_pkg.SmsColumn.ADDRESS,
        telephony_pkg.SmsColumn.BODY,
        telephony_pkg.SmsColumn.DATE,
      ],
    );

    final total = messages.length;
    var processed = 0;
    var matched = 0;

    yield ScanProgress(totalMessages: total, processedMessages: 0, matchedTransactions: 0);

    for (final message in messages) {
      processed++;
      final sender = message.address;
      final body = message.body;
      final receivedAt = message.date != null
          ? DateTime.fromMillisecondsSinceEpoch(message.date!)
          : DateTime.now();

      if (sender != null && body != null) {
        final smsId = await _storeIfKnownSender(sender, body, receivedAt);
        if (smsId != null) {
          final wasMatched = await _processor.processOneById(smsId);
          if (wasMatched) matched++;
        }
      }

      yield ScanProgress(
        totalMessages: total,
        processedMessages: processed,
        matchedTransactions: matched,
      );
    }
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
