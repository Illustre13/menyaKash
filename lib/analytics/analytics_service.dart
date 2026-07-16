import 'package:drift/drift.dart';

import '../data/database.dart';
import 'period.dart';

class CategorySpend {
  const CategorySpend(this.categoryName, this.total);
  final String categoryName;
  final double total;
}

class PeriodSpend {
  const PeriodSpend(this.periodStart, this.total);
  final DateTime periodStart;
  final double total;
}

class SpendSummary {
  const SpendSummary({
    required this.totalIn,
    required this.totalOut,
    required this.currentBalance,
  });
  final double totalIn;
  final double totalOut;
  final double? currentBalance;

  double get net => totalIn - totalOut;
}

/// Pairs a period's summary with the immediately preceding period's, so
/// the dashboard can show "up/down X% vs last month" style deltas.
class PeriodComparison {
  const PeriodComparison({
    required this.period,
    required this.current,
    required this.previous,
  });

  final Period period;
  final SpendSummary current;
  final SpendSummary previous;

  /// Positive = spent more than the previous period; null when the
  /// previous period had zero spend (percentage change is undefined).
  double? get outChangeRatio {
    if (previous.totalOut == 0) return null;
    return (current.totalOut - previous.totalOut) / previous.totalOut;
  }
}

/// How much of the transaction history still needs manual review — the
/// dashboard's "X% categorized / Y need review" indicator (spec Phase
/// 8), replacing the old plain "All Uncategorized" framing. Counts
/// transactions, not summed amounts: the spec's own framing describes
/// a review workload ("how many taps are left"), not a spend-magnitude
/// metric — one large uncategorized rent payment shouldn't make this
/// look worse than ten small uncategorized purchases when the actual
/// task is the same either way.
class CategorizationRatio {
  const CategorizationRatio({required this.categorized, required this.total});

  final int categorized;
  final int total;

  /// 1.0 when there are no transactions at all — an empty ledger has
  /// nothing left to review, not "0% done".
  double get ratio => total == 0 ? 1.0 : categorized / total;

  int get needsReviewCount => total - categorized;
}

const _outboundTypes = {
  TransactionType.sent,
  TransactionType.payment,
  TransactionType.withdrawal,
  TransactionType.airtime,
  TransactionType.bankTransfer,
  // A transaction fee (spec #3) is real money leaving the account —
  // its own first-class Transactions row now, categorized to "Fees &
  // Charges" and linked via parentTransactionId, no longer folded into
  // its parent's `amount + fee` the way totals used to be computed.
  TransactionType.fee,
};

const _inboundTypes = {
  TransactionType.received,
  TransactionType.deposit,
};

/// All read-side aggregation for the dashboard. Every query here reads
/// straight out of the local sqlite database — nothing is computed by
/// calling out anywhere. Every method takes an optional [Period] to
/// scope the query to a week/month/quarter/year window; omitting it
/// covers all-time.
///
/// Every aggregate is exposed as a [Stream] (via `watchX`), not just a
/// one-shot [Future] — confirmed real bug: categorizing a transaction
/// from the Categorize screen updated the raw transaction list live
/// (already `.watch()`-backed, see [CategorizationService.watchAll])
/// but every chart/summary derived from this service stayed stale
/// until the hosting screen was manually reopened, since a plain
/// `Future` has no way to know a write happened elsewhere. Each
/// `watchX` method watches [AppDatabase.transactions] (the table every
/// aggregate here ultimately reads) via drift's own `.watch()` and
/// re-runs the same aggregation logic on every emission — correct
/// because these aggregates are cheap in-memory recomputations over a
/// personal-finance-scale transaction count, not expensive joins that
/// would need debouncing. The old `Future`-returning methods are kept
/// for the few call sites (e.g. one-shot exports) that only need a
/// snapshot, implemented as `watchX(...).first` so there is exactly one
/// aggregation implementation per metric, not two to keep in sync.
class AnalyticsService {
  AnalyticsService(this._db);

  final AppDatabase _db;

  /// Fires whenever [AppDatabase.transactions] changes — the shared
  /// trigger every `watchX` method below re-derives its aggregate from.
  /// Categories/transfer-links changes reach the same transactions rows
  /// via a write to `categoryId`/a new `TransferLinks` row referencing
  /// them, which itself doesn't touch `transactions` — but every write
  /// path in this app that creates a transfer link or assigns a
  /// category (`TransferMatchingEngine`, `CategorizationService`) also
  /// writes to the transaction row it's linking/categorizing, so
  /// watching `transactions` alone is sufficient in practice.
  Stream<void> _transactionsChanged() =>
      _db.select(_db.transactions).watch().map((_) {});

  /// [received]/[deposit]/[sent]/[bankTransfer]/etc. totals here
  /// deliberately exclude any transaction linked as one side of an
  /// internal transfer (see [TransferLinks]) — the Phase 3 fix for the
  /// confirmed real problem where e.g. a BK debit and its matching MTN
  /// credit would otherwise be double-counted as unrelated
  /// income+expense instead of recognized as one internal movement of
  /// the user's own money (docs/AUDIT_PHASE_0.md §3.2).
  Future<SpendSummary> summary({Period? period}) => watchSummary(period: period).first;

  /// Reactive form of [summary] — see this class's doc for why every
  /// aggregate here has one.
  Stream<SpendSummary> watchSummary({Period? period}) {
    return _transactionsChanged().asyncMap((_) async {
      final query = _db.select(_db.transactions);
      _applyPeriod(query, period);
      final rows = await query.get();
      final linkedIds = await _linkedTransactionIds();

      var totalIn = 0.0;
      var totalOut = 0.0;
      DateTime? latestTimestamp;
      double? latestBalance;

      for (final tx in rows) {
        final isTransfer = linkedIds.contains(tx.id);
        if (!isTransfer) {
          if (_inboundTypes.contains(tx.type)) totalIn += tx.amount;
          // Just tx.amount, not `amount + fee` (spec #3): a fee is now
          // its own Transactions row (TransactionType.fee, already in
          // _outboundTypes) with its own amount, counted on its own —
          // adding tx.fee here too would double-count it.
          if (_outboundTypes.contains(tx.type)) totalOut += tx.amount;
        }

        if (tx.balanceAfter != null &&
            (latestTimestamp == null || tx.timestamp.isAfter(latestTimestamp))) {
          latestTimestamp = tx.timestamp;
          latestBalance = tx.balanceAfter;
        }
      }

      return SpendSummary(
        totalIn: totalIn,
        totalOut: totalOut,
        currentBalance: latestBalance,
      );
    });
  }

  /// Every transaction id that's one side of a recorded [TransferLinks]
  /// row — fetched once per call site rather than queried per-row, so
  /// excluding transfers from a summary stays a single extra query
  /// regardless of how many transactions are being summarized.
  Future<Set<int>> _linkedTransactionIds() async {
    final fromIds = await (_db.selectOnly(_db.transferLinks)
          ..addColumns([_db.transferLinks.fromTransactionId]))
        .map((row) => row.read(_db.transferLinks.fromTransactionId)!)
        .get();
    final toIds = await (_db.selectOnly(_db.transferLinks)
          ..addColumns([_db.transferLinks.toTransactionId]))
        .map((row) => row.read(_db.transferLinks.toTransactionId)!)
        .get();
    return {...fromIds, ...toIds};
  }

  /// [summary] for [period] alongside the same-granularity previous
  /// period, for "vs last month" style deltas on the dashboard.
  Future<PeriodComparison> summaryWithComparison(Period period) =>
      watchSummaryWithComparison(period).first;

  Stream<PeriodComparison> watchSummaryWithComparison(Period period) {
    return _transactionsChanged().asyncMap((_) async {
      final current = await summary(period: period);
      final previous = await summary(period: period.previous);
      return PeriodComparison(period: period, current: current, previous: previous);
    });
  }

  /// Spend grouped by category, outbound transactions only — this is
  /// what powers the "where did my money go" bar chart. Excludes
  /// internal-transfer transactions (see [summary] doc for why).
  Future<List<CategorySpend>> spendByCategory({Period? period}) =>
      watchSpendByCategory(period: period).first;

  Stream<List<CategorySpend>> watchSpendByCategory({Period? period}) {
    return _transactionsChanged().asyncMap((_) async {
      final categoryName = _db.categories.name;
      final amount = _db.transactions.amount;
      final linkedIds = await _linkedTransactionIds();

      final query = _db.selectOnly(_db.transactions)
        ..addColumns([categoryName, amount.sum()])
        ..join([
          leftOuterJoin(
            _db.categories,
            _db.categories.id.equalsExp(_db.transactions.categoryId),
          ),
        ])
        ..where(_db.transactions.type.isIn(_outboundTypes.map((t) => t.name)))
        ..groupBy([categoryName]);

      if (linkedIds.isNotEmpty) {
        query.where(_db.transactions.id.isNotIn(linkedIds));
      }
      if (period != null) {
        query.where(_db.transactions.timestamp.isBiggerOrEqualValue(period.start) &
            _db.transactions.timestamp.isSmallerThanValue(period.end));
      }

      final rows = await query.get();
      return rows
          .map((row) => CategorySpend(
                row.read(categoryName) ?? 'Uncategorized',
                row.read(amount.sum()) ?? 0,
              ))
          .toList()
        ..sort((a, b) => b.total.compareTo(a.total));
    });
  }

  /// Outbound spend bucketed by calendar month, oldest first — powers the
  /// spending-over-time trend chart. Independent of the period selector:
  /// always shows a rolling window ending at the current month, so the
  /// user has a trend line regardless of which single period is focused.
  /// Excludes internal-transfer transactions (see [summary] doc).
  Future<List<PeriodSpend>> monthlySpend({int months = 6}) =>
      watchMonthlySpend(months: months).first;

  Stream<List<PeriodSpend>> watchMonthlySpend({int months = 6}) {
    return _transactionsChanged().asyncMap((_) async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month - months + 1, 1);
      final linkedIds = await _linkedTransactionIds();

      final rows = await (_db.select(_db.transactions)
            ..where((tbl) =>
                tbl.timestamp.isBiggerOrEqualValue(start) &
                tbl.type.isIn(_outboundTypes.map((t) => t.name))))
          .get();

      final buckets = <DateTime, double>{};
      for (var i = 0; i < months; i++) {
        final bucketStart = DateTime(start.year, start.month + i, 1);
        buckets[bucketStart] = 0;
      }
      for (final tx in rows) {
        if (linkedIds.contains(tx.id)) continue;
        final bucketStart = DateTime(tx.timestamp.year, tx.timestamp.month, 1);
        // Just tx.amount — see summary()'s doc for why fee is no longer
        // added here (spec #3, fee rows count on their own now).
        buckets[bucketStart] = (buckets[bucketStart] ?? 0) + tx.amount;
      }

      final sortedKeys = buckets.keys.toList()..sort();
      return sortedKeys.map((k) => PeriodSpend(k, buckets[k]!)).toList();
    });
  }

  /// Excludes internal-transfer transactions (see [summary] doc) — a
  /// transfer's "counterparty" is really just the user's own other
  /// account, not a real payee, so it would be meaningless here anyway.
  Future<List<MapEntry<String, double>>> topCounterparties({
    int limit = 5,
    Period? period,
  }) =>
      watchTopCounterparties(limit: limit, period: period).first;

  Stream<List<MapEntry<String, double>>> watchTopCounterparties({
    int limit = 5,
    Period? period,
  }) {
    return _transactionsChanged().asyncMap((_) async {
      final counterparty = _db.transactions.counterparty;
      final amount = _db.transactions.amount;
      final linkedIds = await _linkedTransactionIds();

      final query = _db.selectOnly(_db.transactions)
        ..addColumns([counterparty, amount.sum()])
        ..where(_db.transactions.type.isIn(_outboundTypes.map((t) => t.name)) &
            counterparty.isNotNull())
        ..groupBy([counterparty])
        ..orderBy([OrderingTerm.desc(amount.sum())])
        ..limit(limit);

      if (linkedIds.isNotEmpty) {
        query.where(_db.transactions.id.isNotIn(linkedIds));
      }
      if (period != null) {
        query.where(_db.transactions.timestamp.isBiggerOrEqualValue(period.start) &
            _db.transactions.timestamp.isSmallerThanValue(period.end));
      }

      final rows = await query.get();
      return rows
          .map((row) => MapEntry(
                row.read(counterparty) ?? 'Unknown',
                row.read(amount.sum()) ?? 0,
              ))
          .toList();
    });
  }

  /// Counts categorized vs. total transactions, scoped to [period] if
  /// given. Deliberately includes internal-transfer transactions in
  /// the denominator (unlike [summary]/[spendByCategory]/etc.) — a
  /// transfer never needs a spending category, but it's still a real
  /// ledger row, and this metric is about "how much of my data is
  /// triaged," not "how much did I spend."
  Future<CategorizationRatio> categorizationRatio({Period? period}) =>
      watchCategorizationRatio(period: period).first;

  Stream<CategorizationRatio> watchCategorizationRatio({Period? period}) {
    return _transactionsChanged().asyncMap((_) async {
      final totalQuery = _db.selectOnly(_db.transactions)
        ..addColumns([_db.transactions.id.count()]);
      final categorizedQuery = _db.selectOnly(_db.transactions)
        ..addColumns([_db.transactions.id.count()])
        ..where(_db.transactions.categoryId.isNotNull());

      if (period != null) {
        final inPeriod = _db.transactions.timestamp.isBiggerOrEqualValue(period.start) &
            _db.transactions.timestamp.isSmallerThanValue(period.end);
        totalQuery.where(inPeriod);
        categorizedQuery.where(inPeriod);
      }

      final totalCountExp = _db.transactions.id.count();
      final total = await totalQuery.map((row) => row.read(totalCountExp)).getSingle();
      final categorized =
          await categorizedQuery.map((row) => row.read(totalCountExp)).getSingle();

      return CategorizationRatio(categorized: categorized ?? 0, total: total ?? 0);
    });
  }

  void _applyPeriod(
    SimpleSelectStatement<$TransactionsTable, Transaction> query,
    Period? period,
  ) {
    if (period == null) return;
    query.where((tbl) =>
        tbl.timestamp.isBiggerOrEqualValue(period.start) &
        tbl.timestamp.isSmallerThanValue(period.end));
  }
}
