import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/analytics/analytics_service.dart';
import 'package:i_momo/data/database.dart';

void main() {
  late AppDatabase db;
  late AnalyticsService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = AnalyticsService(db);
  });

  tearDown(() => db.close());

  Future<int> insertTx({
    required TransactionType type,
    required double amount,
    required DateTime timestamp,
  }) {
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
          type: type,
          amount: amount,
          timestamp: timestamp,
          rawSmsBody: 'irrelevant',
        ));
  }

  test('a real expense and a real income are counted normally', () async {
    await insertTx(
      type: TransactionType.payment,
      amount: 3000,
      timestamp: DateTime(2026, 6, 1),
    );
    await insertTx(
      type: TransactionType.received,
      amount: 5000,
      timestamp: DateTime(2026, 6, 2),
    );

    final summary = await service.summary();
    expect(summary.totalOut, 3000);
    expect(summary.totalIn, 5000);
  });

  test(
      'a linked transfer pair (Phase 3) is excluded from income/expense totals — '
      'the fix for the confirmed real double-counting bug', () async {
    final debitId = await insertTx(
      type: TransactionType.bankTransfer,
      amount: 20000,
      timestamp: DateTime(2026, 4, 17, 19, 24, 13),
    );
    final creditId = await insertTx(
      type: TransactionType.received,
      amount: 20000,
      timestamp: DateTime(2026, 4, 17, 19, 24, 16),
    );

    // Without a transfer link, this WOULD be double-counted (confirmed
    // by the next assertion group being different from this one).
    final beforeLinking = await service.summary();
    expect(beforeLinking.totalOut, 20000);
    expect(beforeLinking.totalIn, 20000);

    await db.into(db.transferLinks).insert(TransferLinksCompanion.insert(
          fromTransactionId: debitId,
          toTransactionId: creditId,
          confidence: TransferMatchConfidence.confirmed,
          matchReason: 'test',
        ));

    final afterLinking = await service.summary();
    expect(afterLinking.totalOut, 0, reason: 'the debit side must not count as an expense once linked');
    expect(afterLinking.totalIn, 0, reason: 'the credit side must not count as income once linked');
  });

  test('linked transfers are excluded from spendByCategory too', () async {
    final categoryId =
        await db.into(db.categories).insert(const CategoriesCompanion(name: Value('Food')));

    final debitId = await db.into(db.transactions).insert(TransactionsCompanion.insert(
          type: TransactionType.bankTransfer,
          amount: 20000,
          timestamp: DateTime(2026, 4, 17),
          rawSmsBody: 'irrelevant',
          categoryId: Value(categoryId),
        ));
    final creditId = await insertTx(
      type: TransactionType.received,
      amount: 20000,
      timestamp: DateTime(2026, 4, 17),
    );
    await db.into(db.transferLinks).insert(TransferLinksCompanion.insert(
          fromTransactionId: debitId,
          toTransactionId: creditId,
          confidence: TransferMatchConfidence.confirmed,
          matchReason: 'test',
        ));

    final byCategory = await service.spendByCategory();
    expect(byCategory, isEmpty, reason: 'the linked transfer must not appear in category spend at all');
  });

  test('linked transfers are excluded from monthlySpend too', () async {
    final debitId = await insertTx(
      type: TransactionType.bankTransfer,
      amount: 20000,
      timestamp: DateTime.now(),
    );
    final creditId = await insertTx(
      type: TransactionType.received,
      amount: 20000,
      timestamp: DateTime.now(),
    );
    await db.into(db.transferLinks).insert(TransferLinksCompanion.insert(
          fromTransactionId: debitId,
          toTransactionId: creditId,
          confidence: TransferMatchConfidence.confirmed,
          matchReason: 'test',
        ));

    final monthly = await service.monthlySpend(months: 1);
    expect(monthly.every((m) => m.total == 0), isTrue);
  });
}
