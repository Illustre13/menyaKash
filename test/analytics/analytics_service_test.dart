import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/analytics/analytics_service.dart';
import 'package:i_momo/analytics/period.dart';
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

  test(
      'a fee, as its own separate Transactions row (spec #3), counts exactly '
      'once — never double-counted against its parent payment', () async {
    await insertTx(
      type: TransactionType.payment,
      amount: 3000,
      timestamp: DateTime(2026, 6, 1),
    );
    final feeId = await insertTx(
      type: TransactionType.fee,
      amount: 100,
      timestamp: DateTime(2026, 6, 1),
    );
    // Link it the same way SmsProcessor does — parentTransactionId
    // itself isn't read by summary(), but setting it keeps this test
    // representative of what a real fee row actually looks like.
    await (db.update(db.transactions)..where((tbl) => tbl.id.equals(feeId)))
        .write(const TransactionsCompanion(parentTransactionId: Value(1)));

    final summary = await service.summary();
    expect(summary.totalOut, 3100,
        reason: 'payment (3000) + fee (100) as two independent rows — not 3000 + '
            '(3000+100) which the old amount+fee folding would have produced');
  });

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

  group('categorizationRatio', () {
    test('an empty ledger reports 100% categorized, nothing to review', () async {
      final ratio = await service.categorizationRatio();
      expect(ratio.total, 0);
      expect(ratio.categorized, 0);
      expect(ratio.ratio, 1.0);
      expect(ratio.needsReviewCount, 0);
    });

    test('all transactions categorized reports ratio 1.0', () async {
      final categoryId =
          await db.into(db.categories).insert(const CategoriesCompanion(name: Value('Food')));
      for (var i = 0; i < 3; i++) {
        await db.into(db.transactions).insert(TransactionsCompanion.insert(
              type: TransactionType.payment,
              amount: 1000,
              timestamp: DateTime(2026, 6, i + 1),
              rawSmsBody: 'irrelevant',
              categoryId: Value(categoryId),
            ));
      }

      final ratio = await service.categorizationRatio();
      expect(ratio.total, 3);
      expect(ratio.categorized, 3);
      expect(ratio.ratio, 1.0);
      expect(ratio.needsReviewCount, 0);
    });

    test('a mixed ledger reports the exact fraction categorized', () async {
      final categoryId =
          await db.into(db.categories).insert(const CategoriesCompanion(name: Value('Food')));
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            type: TransactionType.payment,
            amount: 1000,
            timestamp: DateTime(2026, 6, 1),
            rawSmsBody: 'irrelevant',
            categoryId: Value(categoryId),
          ));
      await insertTx(type: TransactionType.payment, amount: 500, timestamp: DateTime(2026, 6, 2));
      await insertTx(type: TransactionType.payment, amount: 200, timestamp: DateTime(2026, 6, 3));

      final ratio = await service.categorizationRatio();
      expect(ratio.total, 3);
      expect(ratio.categorized, 1);
      expect(ratio.needsReviewCount, 2);
      expect(ratio.ratio, closeTo(1 / 3, 0.0001));
    });

    test('period scoping excludes out-of-range transactions', () async {
      await insertTx(type: TransactionType.payment, amount: 500, timestamp: DateTime(2026, 6, 15));
      await insertTx(type: TransactionType.payment, amount: 500, timestamp: DateTime(2026, 5, 15));

      final june = Period(
        granularity: PeriodGranularity.month,
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 7, 1),
      );
      final ratio = await service.categorizationRatio(period: june);
      expect(ratio.total, 1, reason: 'the May transaction must be excluded from a June-scoped query');
    });

    test('a transfer-linked transaction counts in the denominator without needing a category',
        () async {
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
      await db.into(db.transferLinks).insert(TransferLinksCompanion.insert(
            fromTransactionId: debitId,
            toTransactionId: creditId,
            confidence: TransferMatchConfidence.confirmed,
            matchReason: 'test',
          ));

      final ratio = await service.categorizationRatio();
      expect(ratio.total, 2,
          reason: 'transfers are real ledger rows and must count toward "how much is triaged", '
              'unlike summary()/spendByCategory() which exclude them from spend totals');
      expect(ratio.categorized, 0);
    });
  });
}
