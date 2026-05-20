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

  Future<SpendSummary> summary({Period? period}) async {
    final query = _db.select(_db.transactions);
    _applyPeriod(query, period);
    final rows = await query.get();

    var totalIn = 0.0;
    var totalOut = 0.0;
    DateTime? latestTimestamp;
    double? latestBalance;

    for (final tx in rows) {
      if (_inboundTypes.contains(tx.type)) totalIn += tx.amount;
      if (_outboundTypes.contains(tx.type)) totalOut += (tx.amount + tx.fee);

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

  /// [summary] for [period] alongside the same-granularity previous
  /// period, for "vs last month" style deltas on the dashboard.
  Future<PeriodComparison> summaryWithComparison(Period period) async {
    final current = await summary(period: period);
    final previous = await summary(period: period.previous);
    return PeriodComparison(period: period, current: current, previous: previous);
  }

  /// Spend grouped by category, outbound transactions only — this is
  /// what powers the "where did my money go" bar chart.
  Future<List<CategorySpend>> spendByCategory({Period? period}) async {
    final categoryName = _db.categories.name;
    final amount = _db.transactions.amount;

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
  Future<List<PeriodSpend>> monthlySpend({int months = 6}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - months + 1, 1);

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
      final bucketStart = DateTime(tx.timestamp.year, tx.timestamp.month, 1);
      buckets[bucketStart] = (buckets[bucketStart] ?? 0) + tx.amount + tx.fee;
    }

    final sortedKeys = buckets.keys.toList()..sort();
    return sortedKeys.map((k) => PeriodSpend(k, buckets[k]!)).toList();
  }

  Future<List<MapEntry<String, double>>> topCounterparties({
    int limit = 5,
    Period? period,
  }) async {
    final counterparty = _db.transactions.counterparty;
    final amount = _db.transactions.amount;

    final query = _db.selectOnly(_db.transactions)
      ..addColumns([counterparty, amount.sum()])
      ..where(_db.transactions.type.isIn(_outboundTypes.map((t) => t.name)) &
          counterparty.isNotNull())
      ..groupBy([counterparty])
      ..orderBy([OrderingTerm.desc(amount.sum())])
      ..limit(limit);

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
