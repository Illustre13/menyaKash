import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/budgets/budget_service.dart';
import 'package:i_momo/data/database.dart';

void main() {
  late AppDatabase db;
  late BudgetService service;
  late int foodId;

  final june = DateTime(2026, 6, 15);

  Future<int> insertTx({
    required double amount,
    required DateTime timestamp,
    TransactionType type = TransactionType.payment,
    int? categoryId,
    double fee = 0,
  }) {
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
          type: type,
          amount: amount,
          fee: Value(fee),
          timestamp: timestamp,
          rawSmsBody: 'irrelevant',
          categoryId: Value(categoryId),
        ));
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = BudgetService(db);
    foodId = await db.into(db.categories).insert(const CategoriesCompanion(name: Value('Food')));
  });

  tearDown(() => db.close());

  test('no budgets -> empty statuses', () async {
    expect(await service.statusesForMonth(june), isEmpty);
  });

  test(
      'spend is computed live for the requested month only, from tx.amount alone '
      '— a fee no longer folds into its parent\'s contribution (spec #3: a fee is '
      'its own separate Transactions row now, counted on its own if categorized)',
      () async {
    await service.setBudget(categoryId: foodId, monthlyLimit: 50000);
    // fee: 100 here is only the legacy evidence column (what the SMS
    // literally said) — it must NOT be added into this row's own
    // contribution to spend, since a real fee is its own row now.
    await insertTx(amount: 10000, fee: 100, timestamp: DateTime(2026, 6, 3), categoryId: foodId);
    await insertTx(amount: 5000, timestamp: DateTime(2026, 6, 20), categoryId: foodId);
    // Different month — must not count.
    await insertTx(amount: 99999, timestamp: DateTime(2026, 5, 30), categoryId: foodId);
    // Same month, different category — must not count.
    await insertTx(amount: 7777, timestamp: DateTime(2026, 6, 10));
    // Inbound money is never "spend".
    await insertTx(
        amount: 30000,
        type: TransactionType.received,
        timestamp: DateTime(2026, 6, 11),
        categoryId: foodId);

    final status = (await service.statusesForMonth(june)).single;
    expect(status.spentThisMonth, 15000, reason: '10000 + 5000, never +100 for the legacy fee column');
    expect(status.isOver, isFalse);
    expect(status.isNearLimit, isFalse);
    expect(status.remaining, 35000);
  });

  test('a real fee-charge transaction categorized to the same budget counts on its own row',
      () async {
    await service.setBudget(categoryId: foodId, monthlyLimit: 50000);
    await insertTx(amount: 10000, timestamp: DateTime(2026, 6, 3), categoryId: foodId);
    await insertTx(
      amount: 100,
      type: TransactionType.fee,
      timestamp: DateTime(2026, 6, 3),
      categoryId: foodId,
    );

    final status = (await service.statusesForMonth(june)).single;
    expect(status.spentThisMonth, 10100);
  });

  test('near-limit and over-limit flags', () async {
    await service.setBudget(categoryId: foodId, monthlyLimit: 10000);
    await insertTx(amount: 8500, timestamp: june, categoryId: foodId);
    var status = (await service.statusesForMonth(june)).single;
    expect(status.isNearLimit, isTrue);
    expect(status.isOver, isFalse);

    await insertTx(amount: 3000, timestamp: june, categoryId: foodId);
    status = (await service.statusesForMonth(june)).single;
    expect(status.isOver, isTrue);
    expect(status.isNearLimit, isFalse);
  });

  test('transactions linked as internal transfers are excluded from spend', () async {
    await service.setBudget(categoryId: foodId, monthlyLimit: 50000);
    final debitId = await insertTx(
        amount: 20000,
        type: TransactionType.bankTransfer,
        timestamp: june,
        categoryId: foodId);
    final creditId =
        await insertTx(amount: 20000, type: TransactionType.received, timestamp: june);
    await db.into(db.transferLinks).insert(TransferLinksCompanion.insert(
          fromTransactionId: debitId,
          toTransactionId: creditId,
          confidence: TransferMatchConfidence.confirmed,
          matchReason: 'test',
        ));

    final status = (await service.statusesForMonth(june)).single;
    expect(status.spentThisMonth, 0,
        reason: 'a matched transfer is the user\'s own money moving, not spending — '
            'same semantics as AnalyticsService');
  });

  test('setBudget updates rather than duplicates, and removeBudget deletes', () async {
    await service.setBudget(categoryId: foodId, monthlyLimit: 10000);
    await service.setBudget(categoryId: foodId, monthlyLimit: 25000);

    final budgets = await db.select(db.budgets).get();
    expect(budgets, hasLength(1));
    expect(budgets.single.monthlyLimit, 25000);

    await service.removeBudget(foodId);
    expect(await db.select(db.budgets).get(), isEmpty);
  });

  test('categoriesWithoutBudget excludes already-budgeted ones', () async {
    // The database seeds a real default taxonomy (spec #9) on create,
    // so this asserts against a specific unbudgeted category rather
    // than the full list — the exact count/contents of "everything
    // unbudgeted" isn't this test's concern, only that budgeting one
    // category removes it from the list without touching the rest.
    final transportId = (await (db.select(db.categories)
              ..where((tbl) => tbl.name.equals('Transport')))
            .getSingle())
        .id;
    await service.setBudget(categoryId: foodId, monthlyLimit: 10000);

    final available = await service.categoriesWithoutBudget();
    expect(available.map((c) => c.id), contains(transportId));
    expect(available.map((c) => c.id), isNot(contains(foodId)));
  });
}
