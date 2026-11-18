import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics/analytics_service.dart';
import '../analytics/chart_palette.dart';
import '../analytics/period.dart';
import '../categorization/categorization_service.dart';
import '../theme/app_theme.dart';
import 'categorize_screen.dart';
import 'dashboard/categorization_progress.dart';
import 'insights/sort_prompt_card.dart';

/// The Insights tab (screen 13 of the redesign): "where did my money
/// go." Period navigator + Week/Month/Quarter/Year tabs, a net cash
/// flow card with a plain-language comparison to the previous period,
/// spending by category (or, while most transactions are still
/// uncategorized, a "sort a few" prompt that categorizes inline),
/// spending over the last 6 months, and where most money went.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({
    super.key,
    required this.analytics,
    this.onReviewUncategorized,
    this.categorizationService,
  });

  final AnalyticsService analytics;

  /// Called by "Sort all" when [categorizationService] isn't provided
  /// (falls back to the Transactions tab's review filter, since this
  /// screen doesn't own the bottom-nav index).
  final VoidCallback? onReviewUncategorized;

  /// Enables the inline "sort a few" prompt (category chips on the most
  /// recent uncategorized transaction) and opens the Categorize screen
  /// from "Sort all". Optional so older call sites still compile.
  final CategorizationService? categorizationService;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

/// Below this share of categorized transactions the category chart is
/// mostly "Uncategorized" noise, so the sort prompt replaces it.
const _categoriesReadyRatio = 0.8;

class _InsightsScreenState extends State<InsightsScreen> {
  Period _period = Period.containing(PeriodGranularity.month, DateTime.now());
  bool _showCategoryAsPie = true;

  // Streams, not one-shot Futures (confirmed real bug: categorizing a
  // transaction updated the raw list live but this screen's charts/
  // metrics stayed stale until manually reopened) — every widget below
  // uses StreamBuilder and repaints whenever the underlying transaction
  // data actually changes, with no manual refresh needed.
  late Stream<PeriodComparison> _comparison;
  late Stream<List<CategorySpend>> _byCategory;
  late Stream<List<PeriodSpend>> _monthly;
  late Stream<CategorizationRatio> _categorizationRatio;
  late Stream<List<MapEntry<String, double>>> _topMerchants;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _comparison = widget.analytics.watchSummaryWithComparison(_period);
    _byCategory = widget.analytics.watchSpendByCategory(period: _period);
    _monthly = widget.analytics.watchMonthlySpend();
    _categorizationRatio = widget.analytics.watchCategorizationRatio(period: _period);
    _topMerchants = widget.analytics.watchTopCounterparties(limit: 5, period: _period);
  }

  Future<void> _refresh() async {
    // Pull-to-refresh mainly re-scopes the period-dependent streams (in
    // case the wall-clock has moved into a new period); the streams
    // themselves already stay live between manual refreshes.
    setState(_reload);
  }

  void _setGranularity(PeriodGranularity granularity) {
    setState(() {
      _period = Period.containing(granularity, DateTime.now());
      _reload();
    });
  }

  void _shift(Period to) {
    setState(() {
      _period = to;
      _reload();
    });
  }

  Future<void> _sortAll() async {
    final service = widget.categorizationService;
    if (service == null) {
      widget.onReviewUncategorized?.call();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CategorizeScreen(service: service)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'RWF ', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canGoNext = !_period.containsCurrent(DateTime.now());
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Insights', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          _PeriodNavigator(
            label: _shortLabel(_period),
            onPrevious: () => _shift(_period.previous),
            onNext: canGoNext ? () => _shift(_period.next) : null,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _PeriodTabs(selected: _period.granularity, onChanged: _setGranularity),
            const SizedBox(height: 14),
            StreamBuilder<PeriodComparison>(
              stream: _comparison,
              builder: (context, snapshot) =>
                  _NetCashFlowCard(comparison: snapshot.data, currency: currency),
            ),
            const SizedBox(height: 24),
            StreamBuilder<CategorizationRatio>(
              stream: _categorizationRatio,
              builder: (context, ratioSnapshot) {
                final ratio = ratioSnapshot.data;
                final notReady = ratio != null &&
                    ratio.needsReviewCount > 0 &&
                    ratio.ratio < _categoriesReadyRatio;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: _SectionTitle('Spending by category')),
                        if (!notReady)
                          IconButton(
                            tooltip: _showCategoryAsPie ? 'Show as bars' : 'Show as pie',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              _showCategoryAsPie ? Icons.bar_chart : Icons.pie_chart_outline,
                            ),
                            onPressed: () =>
                                setState(() => _showCategoryAsPie = !_showCategoryAsPie),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (notReady)
                      SortPromptCard(
                        ratio: ratio,
                        period: _period,
                        categorizationService: widget.categorizationService,
                        onSortAll: _sortAll,
                      )
                    else ...[
                      StreamBuilder<List<CategorySpend>>(
                        stream: _byCategory,
                        builder: (context, snapshot) {
                          final data = snapshot.data ?? const [];
                          if (data.isEmpty) {
                            return const _EmptyHint(
                              text: 'No categorized spending in this period.',
                            );
                          }
                          return _showCategoryAsPie
                              ? _CategoryPieChart(data: data, isDark: isDark, currency: currency)
                              : _CategoryBarChart(data: data, isDark: isDark, currency: currency);
                        },
                      ),
                      if (ratio != null && ratio.needsReviewCount > 0) ...[
                        const SizedBox(height: 12),
                        CategorizationProgressBar(ratio: ratio, onReview: _sortAll),
                      ],
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: _SectionTitle('Spending over time')),
                Text(
                  'Last 6 months',
                  style: text.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<PeriodSpend>>(
              stream: _monthly,
              builder: (context, snapshot) {
                final data = snapshot.data ?? const [];
                if (data.every((p) => p.total == 0)) {
                  return const _EmptyHint(text: 'No spending recorded in the last 6 months.');
                }
                return _Panel(child: _MonthlyBarChart(data: data, isDark: isDark));
              },
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Where most money went'),
            const SizedBox(height: 8),
            StreamBuilder<List<MapEntry<String, double>>>(
              stream: _topMerchants,
              builder: (context, snapshot) {
                final data = snapshot.data ?? const [];
                if (data.isEmpty) {
                  return const _EmptyHint(text: 'No spending to a person or merchant yet.');
                }
                return _Panel(child: _TopPayees(data: data, isDark: isDark));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// "Nov 2026" for a month (the shared [Period.label] spells the month
/// out, too wide for an app-bar action); other granularities as-is.
String _shortLabel(Period period) => period.granularity == PeriodGranularity.month
    ? DateFormat('MMM y').format(period.start)
    : period.label();

/// "than in October" / "than last week" — the comparison target.
String _previousPeriodPhrase(Period period) {
  final previous = period.previous;
  return switch (period.granularity) {
    PeriodGranularity.week => 'than last week',
    PeriodGranularity.month => 'than in ${DateFormat.MMMM().format(previous.start)}',
    PeriodGranularity.quarter => 'than in ${previous.label()}',
    PeriodGranularity.year => 'than in ${previous.start.year}',
  };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

/// The rounded surface every Insights section sits on.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({required this.label, required this.onPrevious, this.onNext});

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 20),
          tooltip: 'Previous period',
          visualDensity: VisualDensity.compact,
          onPressed: onPrevious,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 20),
          tooltip: 'Next period',
          visualDensity: VisualDensity.compact,
          onPressed: onNext,
        ),
      ],
    );
  }
}

/// Week / Month / Quarter / Year as one pill strip.
class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onChanged});

  final PeriodGranularity selected;
  final ValueChanged<PeriodGranularity> onChanged;

  static const _labels = {
    PeriodGranularity.week: 'Week',
    PeriodGranularity.month: 'Month',
    PeriodGranularity.quarter: 'Quarter',
    PeriodGranularity.year: 'Year',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          for (final entry in _labels.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: entry.key == selected,
                child: GestureDetector(
                  onTap: () => onChanged(entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: entry.key == selected ? scheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color:
                                entry.key == selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NetCashFlowCard extends StatelessWidget {
  const _NetCashFlowCard({required this.comparison, required this.currency});

  final PeriodComparison? comparison;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final s = comparison?.current;
    final net = s?.net;
    final plain = NumberFormat.decimalPattern();
    final change = comparison?.outChangeRatio;

    return _Panel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net cash flow', style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              net == null ? '—' : '${net < 0 ? '\u2212' : '+'}${currency.format(net.abs())}',
              style: text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FlowTile(
                  icon: Icons.south_west,
                  label: 'Money in',
                  value: s == null ? '—' : plain.format(s.totalIn),
                  color: AppBrand.income(brightness),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FlowTile(
                  icon: Icons.north_east,
                  label: 'Money out',
                  value: s == null ? '—' : plain.format(s.totalOut),
                  color: AppBrand.expense(brightness),
                ),
              ),
            ],
          ),
          if (change != null && change.abs() >= 0.005 && comparison != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  change > 0 ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  // Spending more is the warning direction, less is good.
                  color: change > 0 ? AppBrand.orangeDark : AppBrand.income(brightness),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'You spent ${(change.abs() * 100).round()}% '
                    '${change > 0 ? 'more' : 'less'} '
                    '${_previousPeriodPhrase(comparison!.period)}',
                    style: text.labelMedium?.copyWith(
                      color: change > 0 ? AppBrand.orangeButtonLight : AppBrand.income(brightness),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FlowTile extends StatelessWidget {
  const _FlowTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label, style: text.labelSmall?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Part-to-whole category breakdown as a donut. Capped at 6 slices +
/// "Other" — past that, a pie stops being readable and the bar-chart
/// toggle (with its higher fold threshold and axis-based comparison)
/// is the better tool, per the dataviz skill's series-count ladder.
class _CategoryPieChart extends StatefulWidget {
  const _CategoryPieChart({required this.data, required this.isDark, required this.currency});

  final List<CategorySpend> data;
  final bool isDark;
  final NumberFormat currency;

  @override
  State<_CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<_CategoryPieChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final shown = widget.data.length > 6
        ? [
            ...widget.data.take(5),
            CategorySpend(
              'Other',
              widget.data.skip(5).fold(0.0, (sum, c) => sum + c.total),
            ),
          ]
        : widget.data;
    final total = shown.fold(0.0, (sum, c) => sum + c.total);

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 56,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        // touchedSectionIndex can be -1 (touch registered
                        // but not over any section, e.g. the center hole)
                        // — normalize that to null here so nothing below
                        // ever has to special-case a negative index.
                        final index = response?.touchedSection?.touchedSectionIndex;
                        _touchedIndex = (!event.isInterestedForInteractions ||
                                index == null ||
                                index < 0 ||
                                index >= shown.length)
                            ? null
                            : index;
                      });
                    },
                  ),
                  sections: [
                    for (var i = 0; i < shown.length; i++)
                      PieChartSectionData(
                        value: shown[i].total,
                        color: ChartPalette.colorFor(shown[i].categoryName, isDark: widget.isDark),
                        radius: i == _touchedIndex ? 46 : 40,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              _PieCenterLabel(
                label: _touchedIndex != null ? shown[_touchedIndex!].categoryName : 'Total',
                value: _touchedIndex != null
                    ? widget.currency.format(shown[_touchedIndex!].total)
                    : widget.currency.format(total),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CategoryLegend(data: shown, isDark: widget.isDark, total: total),
      ],
    );
  }
}

class _PieCenterLabel extends StatelessWidget {
  const _PieCenterLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _CategoryBarChart extends StatelessWidget {
  const _CategoryBarChart({required this.data, required this.isDark, required this.currency});

  final List<CategorySpend> data;
  final bool isDark;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    // Cap to top 8 + fold the rest into "Other" so the chart never grows
    // unbounded as the user's category-code bank fills up.
    final shown = data.length > 8
        ? [
            ...data.take(7),
            CategorySpend('Other', data.skip(7).fold(0.0, (sum, c) => sum + c.total)),
          ]
        : data;
    final maxVal = shown.map((c) => c.total).fold(0.0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxVal * 1.2,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxVal / 4 == 0 ? 1 : maxVal / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: isDark ? ChartPalette.gridlineDark : ChartPalette.gridlineLight,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= shown.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          shown[index].categoryName,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? ChartPalette.mutedDark : ChartPalette.mutedLight,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                    '${shown[groupIndex].categoryName}\n${currency.format(rod.toY)}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < shown.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: shown[i].total,
                        color: ChartPalette.colorFor(shown[i].categoryName, isDark: isDark),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _CategoryLegend(data: shown, isDark: isDark),
      ],
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend({required this.data, required this.isDark, this.total});

  final List<CategorySpend> data;
  final bool isDark;

  /// When provided, each legend entry also shows its percentage share —
  /// the secondary encoding a pie chart needs so identity never rests on
  /// color alone (dataviz skill accessibility pass).
  final double? total;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: data.map((c) {
        final pct = total != null && total! > 0 ? (c.total / total! * 100) : null;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: ChartPalette.colorFor(c.categoryName, isDark: isDark),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              pct != null ? '${c.categoryName} (${pct.toStringAsFixed(0)}%)' : c.categoryName,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        );
      }).toList(),
    );
  }
}

/// Six monthly bars, current month highlighted, "Highest" over the max.
class _MonthlyBarChart extends StatelessWidget {
  const _MonthlyBarChart({required this.data, required this.isDark});

  final List<PeriodSpend> data;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = isDark ? ChartPalette.mutedDark : ChartPalette.mutedLight;
    final now = DateTime.now();
    final monthFmt = DateFormat.MMM();
    final maxIndex = data.indexed.reduce((a, b) => b.$2.total > a.$2.total ? b : a).$1;
    final maxY = data[maxIndex].total;
    bool isCurrent(PeriodSpend p) =>
        p.periodStart.year == now.year && p.periodStart.month == now.month;

    return SizedBox(
      height: 170,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.18,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                NumberFormat.compact().format(rod.toY),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 18,
                getTitlesWidget: (value, meta) => value.toInt() == maxIndex
                    ? Text('Highest', style: TextStyle(fontSize: 10, color: muted))
                    : const SizedBox.shrink(),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  final current = isCurrent(data[i]);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      monthFmt.format(data[i].periodStart),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: current ? FontWeight.w800 : FontWeight.w400,
                        color: current ? scheme.primary : muted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (final (i, p) in data.indexed)
              BarChartGroupData(
                x: i,
                showingTooltipIndicators: const [],
                barRods: [
                  BarChartRodData(
                    toY: p.total,
                    width: 22,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    color: isCurrent(p)
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: isDark ? 0.14 : 0.10),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Top people/merchants by money out, each with a proportional bar.
class _TopPayees extends StatelessWidget {
  const _TopPayees({required this.data, required this.isDark});

  final List<MapEntry<String, double>> data;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final plain = NumberFormat.decimalPattern();
    final maxSpend = data.first.value;
    return Column(
      children: [
        for (final (i, entry) in data.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.key,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                plain.format(entry.value),
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: maxSpend == 0 ? 0 : entry.value / maxSpend,
              minHeight: 5,
              color: scheme.primary,
              backgroundColor: scheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
    );
  }
}
