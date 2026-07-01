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

const _outboundTypes = {
  TransactionType.sent,
  TransactionType.payment,
  TransactionType.withdrawal,
  TransactionType.airtime,
  TransactionType.bankTransfer,
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
class AnalyticsService {
  AnalyticsService(this._db);

  final AppDatabase _db;

  /// [received]/[deposit]/[sent]/[bankTransfer]/etc. totals here
  /// deliberately exclude any transaction linked as one side of an
  /// internal transfer (see [TransferLinks]) — the Phase 3 fix for the
  /// confirmed real problem where e.g. a BK debit and its matching MTN
  /// credit would otherwise be double-counted as unrelated
  /// income+expense instead of recognized as one internal movement of
  /// the user's own money (docs/AUDIT_PHASE_0.md §3.2).
  Future<SpendSummary> summary({Period? period}) async {
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
        if (_outboundTypes.contains(tx.type)) totalOut += (tx.amount + tx.fee);
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
  Future<PeriodComparison> summaryWithComparison(Period period) async {
    final current = await summary(period: period);
    final previous = await summary(period: period.previous);
    return PeriodComparison(period: period, current: current, previous: previous);
  }

  /// Spend grouped by category, outbound transactions only — this is
  /// what powers the "where did my money go" bar chart. Excludes
  /// internal-transfer transactions (see [summary] doc for why).
  Future<List<CategorySpend>> spendByCategory({Period? period}) async {
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
  }

  /// Outbound spend bucketed by calendar month, oldest first — powers the
  /// spending-over-time trend chart. Independent of the period selector:
  /// always shows a rolling window ending at the current month, so the
  /// user has a trend line regardless of which single period is focused.
  /// Excludes internal-transfer transactions (see [summary] doc).
  Future<List<PeriodSpend>> monthlySpend({int months = 6}) async {
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
      buckets[bucketStart] = (buckets[bucketStart] ?? 0) + tx.amount + tx.fee;
    }

    final sortedKeys = buckets.keys.toList()..sort();
    return sortedKeys.map((k) => PeriodSpend(k, buckets[k]!)).toList();
  }

  /// Excludes internal-transfer transactions (see [summary] doc) — a
  /// transfer's "counterparty" is really just the user's own other
  /// account, not a real payee, so it would be meaningless here anyway.
  Future<List<MapEntry<String, double>>> topCounterparties({
    int limit = 5,
    Period? period,
  }) async {
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
