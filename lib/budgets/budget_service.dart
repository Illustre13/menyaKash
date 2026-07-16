import 'package:drift/drift.dart';

import '../data/database.dart';

/// One category's budget joined with its live spend for the current
/// calendar month — the read-model the Budgets tab renders as a
/// progress ring.
class BudgetStatus {
  const BudgetStatus({
    required this.budget,
    required this.category,
    required this.spentThisMonth,
  });

  final Budget budget;
  final Category category;
  final double spentThisMonth;

  double get ratio => budget.monthlyLimit <= 0 ? 1.0 : spentThisMonth / budget.monthlyLimit;
  double get remaining => budget.monthlyLimit - spentThisMonth;
  bool get isOver => spentThisMonth > budget.monthlyLimit;

  /// Approaching the cap (80%+) — the "warn before it happens" band.
  bool get isNearLimit => !isOver && ratio >= 0.8;
}

const _outboundTypes = {
  TransactionType.sent,
  TransactionType.payment,
  TransactionType.withdrawal,
  TransactionType.airtime,
  TransactionType.bankTransfer,
  // A transaction fee (spec #3) is a real, separately-categorized
  // expense now (see AnalyticsService's matching set for the full
  // reasoning) — included here so a "Fees & Charges" budget, if a user
  // sets one, tracks real fee spend against real fee transactions.
  TransactionType.fee,
};

/// Read/write surface for [Budgets] (UI redesign sprint). Spend is
/// always computed live from [Transactions] for the month in question
/// — never stored — mirroring how account balances work. Outbound
/// types only, and transactions linked as internal transfers are
/// excluded, matching AnalyticsService's spend semantics so the budget
/// ring and the insights charts never disagree about the same month.
class BudgetService {
  BudgetService(this._db);

  final AppDatabase _db;

  Future<List<BudgetStatus>> statusesForMonth(DateTime anyDayInMonth) async {
    final monthStart = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    final monthEnd = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 1);

    final budgetRows = await _db.select(_db.budgets).get();
    if (budgetRows.isEmpty) return const [];

    final linkedIds = await _linkedTransactionIds();
    final statuses = <BudgetStatus>[];

    for (final budget in budgetRows) {
      final category = await (_db.select(_db.categories)
            ..where((tbl) => tbl.id.equals(budget.categoryId)))
          .getSingleOrNull();
      if (category == null) continue; // cascade should prevent this; fail safe

      final rows = await (_db.select(_db.transactions)
            ..where((tbl) =>
                tbl.categoryId.equals(budget.categoryId) &
                tbl.timestamp.isBiggerOrEqualValue(monthStart) &
                tbl.timestamp.isSmallerThanValue(monthEnd) &
                tbl.type.isIn(_outboundTypes.map((t) => t.name))))
          .get();

      var spent = 0.0;
      for (final tx in rows) {
        if (linkedIds.contains(tx.id)) continue;
        // Just tx.amount, not `amount + fee` — see AnalyticsService's
        // matching fix for why (spec #3, a fee is its own row now).
        spent += tx.amount;
      }

      statuses.add(BudgetStatus(budget: budget, category: category, spentThisMonth: spent));
    }

    statuses.sort((a, b) => b.ratio.compareTo(a.ratio));
    return statuses;
  }

  /// Creates or updates the single budget for [categoryId].
  Future<void> setBudget({required int categoryId, required double monthlyLimit}) async {
    final existing = await (_db.select(_db.budgets)
          ..where((tbl) => tbl.categoryId.equals(categoryId)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.budgets).insert(
            BudgetsCompanion.insert(categoryId: categoryId, monthlyLimit: monthlyLimit),
          );
    } else {
      await (_db.update(_db.budgets)..where((tbl) => tbl.id.equals(existing.id)))
          .write(BudgetsCompanion(monthlyLimit: Value(monthlyLimit)));
    }
  }

  Future<void> removeBudget(int categoryId) async {
    await (_db.delete(_db.budgets)..where((tbl) => tbl.categoryId.equals(categoryId))).go();
  }

  /// Categories that don't have a budget yet — what the "new budget"
  /// sheet offers.
  Future<List<Category>> categoriesWithoutBudget() async {
    final budgeted =
        (await _db.select(_db.budgets).get()).map((b) => b.categoryId).toSet();
    final all = await _db.select(_db.categories).get();
    return all.where((c) => !budgeted.contains(c.id)).toList();
  }

  /// Mirrors AnalyticsService._linkedTransactionIds — transfer sides
  /// must not count as spending here either.
  Future<Set<int>> _linkedTransactionIds() async {
    final links = await _db.select(_db.transferLinks).get();
    return {
      for (final link in links) ...[link.fromTransactionId, link.toTransactionId],
    };
  }
}
