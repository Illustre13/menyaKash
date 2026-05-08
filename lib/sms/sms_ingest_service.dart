import 'package:drift/drift.dart' show Value;
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart' hide Value;

import '../data/database.dart';
import '../parsers/momo_parser_registry.dart';

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

/// Owns the entire "get MoMo SMS off the device and into the local DB"
/// pipeline: permission requests, one-time historical scan, and the live
/// listener for new incoming messages. Nothing in this file ever touches
/// the network — it reads the on-device SMS provider and writes to the
/// local sqlite database only.
class SmsIngestService {
  SmsIngestService(this._db, this._registry);

  final AppDatabase _db;
  final MomoParserRegistry _registry;
  final Telephony _telephony = Telephony.instance;

  Future<bool> requestPermissions() async {
    final smsGranted = await Permission.sms.request();
    return smsGranted.isGranted;
  }

  Future<bool> hasPermissions() async {
    return await Permission.sms.isGranted;
  }

  /// Scans the full existing SMS inbox once — intended for first-run
  /// setup, so every MoMo transaction the user already has shows up in
  /// analytics immediately rather than only messages arriving from here
  /// on. Emits a [ScanProgress] after every message (matched or not) so
  /// a progress UI can track it; the final emitted value always has
  /// [ScanProgress.isDone] true. Safe to call again later (e.g. a manual
  /// "rescan" action) — already-ingested messages aren't deduplicated
  /// against here, so this is meant for the empty-database first run.
  Stream<ScanProgress> scanHistoricalInbox() async* {
    final messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
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
          : null;

      if (sender != null && body != null && _registry.isKnownSender(sender)) {
        final wasTransaction = await _ingestOne(sender, body, receivedAt: receivedAt);
        if (wasTransaction) matched++;
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
      onNewMessage: (SmsMessage message) async {
        final sender = message.address;
        final body = message.body;
        if (sender == null || body == null) return;
        if (!_registry.isKnownSender(sender)) return;
        await _ingestOne(sender, body, receivedAt: DateTime.now());
      },
      listenInBackground: false,
    );
  }

  /// Returns true if the message matched a known transaction template
  /// (and was inserted into `transactions`), false if it was routed to
  /// `unparsed_messages` instead.
  Future<bool> _ingestOne(String sender, String body, {DateTime? receivedAt}) async {
    final outcome = _registry.process(sender, body, receivedAt: receivedAt);

    if (!outcome.wasParsed) {
      await _db.into(_db.unparsedMessages).insert(
            UnparsedMessagesCompanion.insert(
              sender: sender,
              body: outcome.unparsedBody ?? body,
              receivedAt: receivedAt ?? DateTime.now(),
            ),
          );
      return false;
    }

    final parsed = outcome.transaction!;
    int? categoryId;
    if (parsed.counterparty != null) {
      final category = await _db.findCategoryByCode(parsed.counterparty!);
      categoryId = category?.id;
    }

    await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            provider: outcome.providerId!,
            type: parsed.type,
            amount: parsed.amount,
            fee: Value(parsed.fee),
            counterparty: Value(parsed.counterparty),
            txRef: Value(parsed.txRef),
            balanceAfter: Value(parsed.balanceAfter),
            timestamp: parsed.timestamp,
            rawSmsBody: body,
            categoryId: Value(categoryId),
          ),
        );
    return true;
  }
}
