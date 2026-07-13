import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/parsers/momo_parser_registry.dart';
import 'package:i_momo/providers/provider_detector_factory.dart';
import 'package:i_momo/sms/isolate_parsing.dart';
import 'package:i_momo/sms/sms_processor.dart';

void main() {
  late AppDatabase db;
  late SmsProcessor processor;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    processor = SmsProcessor(db, MomoParserRegistry(), buildProviderDetector(db));
  });

  tearDown(() => db.close());

  Future<int> insertPendingSms({required String sender, required String body}) {
    final receivedAt = DateTime(2026, 1, 1, 10, 0);
    return db.into(db.smsMessages).insert(
          SmsMessagesCompanion.insert(
            sender: sender,
            body: body,
            receivedAt: receivedAt,
            smsHash: hashSmsMessage(sender: sender, body: body, receivedAt: receivedAt),
          ),
        );
  }

  test('a real eKash payment (on the shared M-Money sender) is correctly matched, not unrecognized',
      () async {
    // Phase 2 added EkashParser — this exact body used to have no
    // parser at all (Phase 1) and was the test case proving fail-safe
    // routing worked. Now it's the test case proving the real parser
    // works, since eKash genuinely is a supported provider.
    final id = await insertPendingSms(
      sender: 'M-Money',
      body: '*162*TxId:13559072472*S*Your payment of 500 RWF to eKash with token  has been '
          'completed at 2026-04-15 21:39:02. Fee was 20 RWF. Your new balance: 21931 RWF . '
          'Message: - ACSC. *EN#',
    );

    final matched = await processor.processOneById(id);
    expect(matched, isTrue);

    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));
    expect(txs.single.amount, 500);

    final updated =
        await (db.select(db.smsMessages)..where((tbl) => tbl.id.equals(id))).getSingle();
    expect(updated.processingStatus, SmsProcessingStatus.matched);
  });

  test('a message from a genuinely unrecognized sender is marked unrecognized, not thrown',
      () async {
    final id = await insertPendingSms(
      sender: 'EQUITYBANK',
      body: 'This is a real Equity sender but a body shape no parser understands yet.',
    );

    final matched = await processor.processOneById(id);
    expect(matched, isFalse);

    final unparsed = await db.select(db.unparsedMessages).get();
    expect(unparsed, hasLength(1));
    expect(unparsed.single.smsMessageId, id);

    final updated =
        await (db.select(db.smsMessages)..where((tbl) => tbl.id.equals(id))).getSingle();
    expect(updated.processingStatus, SmsProcessingStatus.unrecognized);
  });

  test('a parseable real MTN message becomes a transaction linked back to its sms_messages row',
      () async {
    final id = await insertPendingSms(
      sender: 'M-Money',
      body: 'You have received 5000 RWF from Jean Uwimana (250788123456) on your mobile money '
          'account at 2026-07-08 14:32:10. Message from sender: . Your new balance:12500 RWF. '
          'Financial Transaction Id: 987654321.',
    );

    final matched = await processor.processOneById(id);
    expect(matched, isTrue);

    final txs = await db.select(db.transactions).get();
    expect(txs, hasLength(1));
    expect(txs.single.smsMessageId, id);
    expect(txs.single.amount, 5000);
    expect(txs.single.providerId, isNotNull);
    expect(
      txs.single.accountId,
      isNotNull,
      reason: 'a real matched transaction must always get an account, even for a provider the '
          'user never explicitly selected in onboarding (schemaVersion 4 no longer '
          'auto-seeds Accounts for every provider — SmsProcessor creates one on demand '
          'instead of leaving the transaction orphaned)',
    );

    final updated =
        await (db.select(db.smsMessages)..where((tbl) => tbl.id.equals(id))).getSingle();
    expect(updated.processingStatus, SmsProcessingStatus.matched);
    expect(updated.providerId, txs.single.providerId);
  });

  test('processPending processes every pending row and reports counts', () async {
    await insertPendingSms(
      sender: 'M-Money',
      body: 'You have received 1000 RWF from Someone (250788000000) on your mobile money '
          'account at 2026-07-08 09:00:00. Message from sender: . Your new balance:1000 RWF. '
          'Financial Transaction Id: 1.',
    );
    await insertPendingSms(sender: 'EQUITYBANK', body: 'not a shape any parser understands yet');

    final result = await processor.processPending();
    expect(result.matched, 1);
    expect(result.unrecognized, 1);

    final stillPending = await (db.select(db.smsMessages)
          ..where((tbl) => tbl.processingStatus.equalsValue(SmsProcessingStatus.pending)))
        .get();
    expect(stillPending, isEmpty);
  });

  group('processBatch (Phase 10 batched historical-scan path)', () {
    test('produces identical transaction data to the per-message path for the same real body',
        () async {
      const sender = 'M-Money';
      const body = 'You have received 5000 RWF from Jean Uwimana (250788123456) on your mobile '
          'money account at 2026-07-08 14:32:10. Message from sender: . Your new '
          'balance:12500 RWF. Financial Transaction Id: 987654321.';

      // Per-message path (existing behavior, unchanged by this phase).
      final perMessageId = await insertPendingSms(sender: sender, body: body);
      await processor.processOneById(perMessageId);
      final perMessageTx = (await db.select(db.transactions).get()).single;

      // Batch path, same real message.
      final mtnProvider = await (db.select(db.financialProviders)
            ..where((tbl) => tbl.code.equals('mtn_momo_rw')))
          .getSingle();
      final result = ParsedSmsResult(
        sms: RawSmsSnapshot(sender: sender, body: body, receivedAt: DateTime(2026, 7, 8, 14, 32, 10)),
        smsHash: hashSmsMessage(
          sender: sender,
          body: body,
          receivedAt: DateTime(2026, 7, 8, 14, 32, 10),
        ),
        providerId: mtnProvider.id,
        parsed: MomoParserRegistry()
            .processForProvider(providerCode: 'mtn_momo_rw', body: body)
            .transaction,
      );
      final outcome = await processor.processBatch([result]);
      expect(outcome.matched, 1);

      final batchTx =
          (await db.select(db.transactions).get()).where((t) => t.id != perMessageTx.id).single;

      expect(batchTx.amount, perMessageTx.amount);
      expect(batchTx.type, perMessageTx.type);
      expect(batchTx.counterparty, perMessageTx.counterparty);
      expect(batchTx.balanceAfter, perMessageTx.balanceAfter);
      expect(batchTx.providerId, perMessageTx.providerId);
      expect(batchTx.accountId, isNotNull,
          reason: 'the batch path must also create/attribute an account, not just the '
              'per-message path');
      expect(batchTx.smsMessageId, isNotNull,
          reason: 'the evidence link must survive batching, not just single-message processing');
    });

    test('an unrecognized result in a batch is written to unparsedMessages, not silently dropped',
        () async {
      const sender = 'EQUITYBANK';
      const body = 'a shape no parser understands yet';
      final result = ParsedSmsResult(
        sms: RawSmsSnapshot(sender: sender, body: body, receivedAt: DateTime(2026, 1, 1)),
        smsHash: hashSmsMessage(sender: sender, body: body, receivedAt: DateTime(2026, 1, 1)),
        providerId: (await (db.select(db.financialProviders)
                  ..where((tbl) => tbl.code.equals('equity_bank_rw')))
                .getSingle())
            .id,
      );

      final outcome = await processor.processBatch([result]);
      expect(outcome.unrecognized, 1);

      final unparsed = await db.select(db.unparsedMessages).get();
      expect(unparsed, hasLength(1));
      expect(unparsed.single.smsMessageId, isNotNull);
    });

    test('a batch of many messages for the same provider reuses one cached account, not N',
        () async {
      final mtnProvider = await (db.select(db.financialProviders)
            ..where((tbl) => tbl.code.equals('mtn_momo_rw')))
          .getSingle();

      final results = List.generate(5, (i) {
        final body = 'You have received ${1000 + i} RWF from Someone (25078800000$i) on your '
            'mobile money account at 2026-07-08 09:0$i:00. Message from sender: . Your new '
            'balance:${1000 + i} RWF. Financial Transaction Id: $i.';
        return ParsedSmsResult(
          sms: RawSmsSnapshot(
            sender: 'M-Money',
            body: body,
            receivedAt: DateTime(2026, 7, 8, 9, i),
          ),
          smsHash: hashSmsMessage(
            sender: 'M-Money',
            body: body,
            receivedAt: DateTime(2026, 7, 8, 9, i),
          ),
          providerId: mtnProvider.id,
          parsed: MomoParserRegistry()
              .processForProvider(providerCode: 'mtn_momo_rw', body: body)
              .transaction,
        );
      });

      final outcome = await processor.processBatch(results);
      expect(outcome.matched, 5);

      final accounts = await db.select(db.accounts).get();
      expect(accounts, hasLength(1),
          reason: 'all 5 transactions share one provider and must share one account, not create '
              'a duplicate per message');

      final txs = await db.select(db.transactions).get();
      expect(txs.every((t) => t.accountId == accounts.single.id), isTrue);
    });
  });
}
