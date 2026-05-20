/// The four granularities the dashboard can scope itself to. Deliberately
/// a fixed enum, not a free-form date-range picker — matches the
/// "weekly / monthly / quarterly / yearly" tracker the product needs.
enum PeriodGranularity { week, month, quarter, year }

/// A concrete, navigable time window: e.g. "the week of 2026-07-06", or
/// "Q3 2026". [start] is inclusive, [end] is exclusive, so range checks
/// are always `timestamp >= start && timestamp < end`.
class Period {
  const Period({
    required this.granularity,
    required this.start,
    required this.end,
  });

  final PeriodGranularity granularity;
  final DateTime start;
  final DateTime end;

  /// The period containing [now] for the given [granularity].
  factory Period.containing(PeriodGranularity granularity, DateTime now) {
    switch (granularity) {
      case PeriodGranularity.week:
        // ISO-ish week: Monday start.
        final mondayOffset = now.weekday - DateTime.monday;
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: mondayOffset));
        return Period(
          granularity: granularity,
          start: start,
          end: start.add(const Duration(days: 7)),
        );
      case PeriodGranularity.month:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        return Period(granularity: granularity, start: start, end: end);
      case PeriodGranularity.quarter:
        final quarterIndex = (now.month - 1) ~/ 3; // 0..3
        final startMonth = quarterIndex * 3 + 1;
        final start = DateTime(now.year, startMonth, 1);
        final end = DateTime(now.year, startMonth + 3, 1);
        return Period(granularity: granularity, start: start, end: end);
      case PeriodGranularity.year:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year + 1, 1, 1);
        return Period(granularity: granularity, start: start, end: end);
    }
  }

  Period get previous => _shift(-1);
  Period get next => _shift(1);

  Period _shift(int steps) {
    switch (granularity) {
      case PeriodGranularity.week:
        final shift = Duration(days: 7 * steps);
        return Period(
          granularity: granularity,
          start: start.add(shift),
          end: end.add(shift),
        );
      case PeriodGranularity.month:
        return Period(
          granularity: granularity,
          start: DateTime(start.year, start.month + steps, 1),
          end: DateTime(start.year, start.month + steps + 1, 1),
        );
      case PeriodGranularity.quarter:
        return Period(
          granularity: granularity,
          start: DateTime(start.year, start.month + 3 * steps, 1),
          end: DateTime(start.year, start.month + 3 * steps + 3, 1),
        );
      case PeriodGranularity.year:
        return Period(
          granularity: granularity,
          start: DateTime(start.year + steps, 1, 1),
          end: DateTime(start.year + steps + 1, 1, 1),
        );
    }
  }

  /// True when [end] is in the future relative to [now] — used to hide
  /// the "next" control so users can't navigate into an empty future
  /// period.
  bool isCurrentOrFuture(DateTime now) => !end.isBefore(now) || end.isAfter(now);

  bool containsCurrent(DateTime now) =>
      !now.isBefore(start) && now.isBefore(end);

  String label() {
    switch (granularity) {
      case PeriodGranularity.week:
        final endInclusive = end.subtract(const Duration(days: 1));
        return '${_shortDate(start)} – ${_shortDate(endInclusive)}';
      case PeriodGranularity.month:
        return '${_monthNames[start.month - 1]} ${start.year}';
      case PeriodGranularity.quarter:
        final q = (start.month - 1) ~/ 3 + 1;
        return 'Q$q ${start.year}';
      case PeriodGranularity.year:
        return '${start.year}';
    }
  }

  static String _shortDate(DateTime d) =>
      '${_monthNames[d.month - 1].substring(0, 3)} ${d.day}';

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
}
