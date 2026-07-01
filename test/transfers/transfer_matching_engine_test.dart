import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/transfers/transfer_matching_engine.dart';

void main() {
  late AppDatabase db;
  late TransferMatchingEngine engine;
  late int mtnAccountId;
  late int equityAccountId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    engine = TransferMatchingEngine(db);

    final mtnProvider = await (db.select(db.financialProviders)
          ..where((tbl) => tbl.code.equals('mtn_momo_rw')))
        .getSingle();
    final equityProvider = await (db.select(db.financialProviders)
          ..where((tbl) => tbl.code.equals('equity_bank_rw')))
        .getSingle();
    mtnAccountId =
        (await (db.select(db.accounts)..where((tbl) => tbl.providerId.equals(mtnProvider.id)))
                .getSingle())
            .id;
    equityAccountId =
        (await (db.select(db.accounts)..where((tbl) => tbl.providerId.equals(equityProvider.id)))
                .getSingle())
            .id;
  });

  tearDown(() => db.close());

  Future<int> insertTx({
    required int accountId,
    required TransactionType type,
    required double amount,
    required DateTime timestamp,
    String? txRef,
  }) {
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: Value(accountId),
          type: type,
          amount: amount,
          timestamp: timestamp,
          rawSmsBody: 'irrelevant',
          txRef: Value(txRef),
        ));
  }

  test(
      'confirmed match: real Equity->MTN pair (shared reference, 3 seconds apart, same amount)',
      () async {
    // Modeled directly on the real evidence in docs/SMS_PATTERN_LIBRARY.md:
    // Equity "sent" with MTN Ref. 541077019015, and MTN "received" with
    // Financial Transaction Id 13583914317 that references the transfer
    // in its own body. Only the reference actually shared between the
    // two systems (541077019015) is what the engine can match on.
    final equityDebitId = await insertTx(
      accountId: equityAccountId,
      type: TransactionType.bankTransfer,
      amount: 20000,
      timestamp: DateTime(2026, 4, 17, 19, 24, 13),
      txRef: '541077019015',
    );
    final mtnCreditId = await insertTx(
      accountId: mtnAccountId,
      type: TransactionType.received,
      amount: 20000,
      timestamp: DateTime(2026, 4, 17, 19, 24, 16),
      txRef: '541077019015',
    );

    final linksCreated = await engine.findAndLinkTransfers();
    expect(linksCreated, 1);

    final links = await db.select(db.transferLinks).get();
    expect(links, hasLength(1));
    expect(links.single.fromTransactionId, equityDebitId);
    expect(links.single.toTransactionId, mtnCreditId);
    expect(links.single.confidence, TransferMatchConfidence.confirmed);

    expect(await engine.isPartOfTransfer(equityDebitId), isTrue);
    expect(await engine.isPartOfTransfer(mtnCreditId), isTrue);
  });

  test('probable match: same amount and close timestamp, but no shared reference', () async {
    final debitId = await insertTx(
      accountId: equityAccountId,
      type: TransactionType.bankTransfer,
      amount: 30000,
      timestamp: DateTime(2026, 5, 3, 11, 39, 0),
    );
    final creditId = await insertTx(
      accountId: mtnAccountId,
      type: TransactionType.received,
      amount: 30000,
      timestamp: DateTime(2026, 5, 3, 11, 39, 30),
    );

    final linksCreated = await engine.findAndLinkTransfers();
    expect(linksCreated, 1);

    final links = await db.select(db.transferLinks).get();
    expect(links.single.confidence, TransferMatchConfidence.probable);
    expect(links.single.fromTransactionId, debitId);
    expect(links.single.toTransactionId, creditId);
  });

  test('no match when amounts differ', () async {
    await insertTx(
      accountId: equityAccountId,
      type: TransactionType.bankTransfer,
      amount: 30000,
      timestamp: DateTime(2026, 5, 3, 11, 39, 0),
    );
    await insertTx(
      accountId: mtnAccountId,
      type: TransactionType.received,
      amount: 30001,
      timestamp: DateTime(2026, 5, 3, 11, 39, 30),
    );

    final linksCreated = await engine.findAndLinkTransfers();
    expect(linksCreated, 0);
  });

  test('no match when timestamps are too far apart', () async {
    await insertTx(
      accountId: equityAccountId,
      type: TransactionType.bankTransfer,
      amount: 30000,
      timestamp: DateTime(2026, 5, 3, 11, 0, 0),
    );
    await insertTx(
      accountId: mtnAccountId,
      type: TransactionType.received,
      amount: 30000,
      timestamp: DateTime(2026, 5, 3, 11, 30, 0),
    );

    final linksCreated = await engine.findAndLinkTransfers();
    expect(linksCreated, 0, reason: '30 minutes apart exceeds the 5-minute tolerance');
  });

  test('does not match two transactions on the same account (not a cross-account transfer)',
      () async {
    await insertTx(
      accountId: mtnAccountId,
      type: TransactionType.sent,
      amount: 5000,
      timestamp: DateTime(2026, 5, 3, 11, 0, 0),
    );
    await insertTx(
      accountId: mtnAccountId,
      type: TransactionType.received,
      amount: 5000,
      timestamp: DateTime(2026, 5, 3, 11, 0, 30),
    );

    final linksCreated = await engine.findAndLinkTransfers();
    expect(linksCreated, 0);
  });

  test('running twice does not create duplicate links', () async {
    await insertTx(
      accountId: equityAccountId,
      type: TransactionType.bankTransfer,
      amount: 30000,
      timestamp: DateTime(2026, 5, 3, 11, 39, 0),
    );
    await insertTx(
      accountId: mtnAccountId,
      type: TransactionType.received,
      amount: 30000,
      timestamp: DateTime(2026, 5, 3, 11, 39, 30),
    );

    await engine.findAndLinkTransfers();
    final secondRunLinks = await engine.findAndLinkTransfers();
    expect(secondRunLinks, 0, reason: 'already-linked transactions must be excluded from re-matching');

    final links = await db.select(db.transferLinks).get();
    expect(links, hasLength(1));
  });
}
