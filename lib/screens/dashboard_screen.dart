import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../accounts/accounts_service.dart';
import '../analytics/analytics_service.dart';
import '../analytics/chart_palette.dart';
import '../analytics/period.dart';
import '../profile/user_profile_service.dart';
import '../providers/provider_selection_service.dart';
import '../theme/app_theme.dart';
import 'dashboard/categorization_progress.dart';
import 'dashboard/overview_card.dart';
import 'dashboard/wallet_breakdown.dart';
import 'profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.analytics,
    required this.profileService,
    required this.accountsService,
    required this.providerSelectionService,
    this.onReviewUncategorized,
  });

  final AnalyticsService analytics;
  final UserProfileService profileService;
  final AccountsService accountsService;
  final ProviderSelectionService providerSelectionService;

  /// Called when the categorization-progress indicator is tapped —
  /// wired by `HomeShell` to switch to the Categorize tab, since
  /// `DashboardScreen` doesn't own the bottom-nav index itself.
  final VoidCallback? onReviewUncategorized;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Period _period = Period.containing(PeriodGranularity.month, DateTime.now());
  bool _showCategoryAsPie = true;

  late Future<PeriodComparison> _comparison;
  late Future<List<CategorySpend>> _byCategory;
  late Future<List<PeriodSpend>> _monthly;
  late Future<List<AccountSummary>> _accountSummaries;
  late Future<CategorizationRatio> _categorizationRatio;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _comparison = widget.analytics.summaryWithComparison(_period);
    _byCategory = widget.analytics.spendByCategory(period: _period);
    _monthly = widget.analytics.monthlySpend();
    // Balances are "now" data, not scoped to _period — wallets don't
    // reset each week/month/quarter the way spend totals do.
    _accountSummaries = widget.accountsService.allAccountSummaries();
    _categorizationRatio = widget.analytics.categorizationRatio(period: _period);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait([_comparison, _byCategory, _monthly, _accountSummaries, _categorizationRatio]);
  }

  void _setGranularity(PeriodGranularity granularity) {
    setState(() {
      _period = Period.containing(granularity, DateTime.now());
      _reload();
    });
  }

  void _goToPrevious() {
    setState(() {
      _period = _period.previous;
      _reload();
    });
  }

  void _goToNext() {
    setState(() {
      _period = _period.next;
      _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'RWF ', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canGoNext = !_period.containsCurrent(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(compact: true),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  profileService: widget.profileService,
                  accountsService: widget.accountsService,
                  providerSelectionService: widget.providerSelectionService,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            FutureBuilder<List<AccountSummary>>(
              future: _accountSummaries,
              builder: (context, snapshot) {
                final data = snapshot.data ?? const [];
                return OverviewCard(summaries: data, currency: currency);
              },
            ),
            const SizedBox(height: 16),
            Text('Wallet Breakdown', style: Theme.of(context).textTheme.titleMedium),
            FutureBuilder<List<AccountSummary>>(
              future: _accountSummaries,
              builder: (context, snapshot) {
                final data = snapshot.data ?? const [];
                return WalletBreakdownList(summaries: data, currency: currency);
              },
            ),
            const SizedBox(height: 28),
            _PeriodGranularitySelector(
              selected: _period.granularity,
              onChanged: _setGranularity,
            ),
            const SizedBox(height: 12),
            _PeriodNavigator(
              label: _period.label(),
              onPrevious: _goToPrevious,
              onNext: canGoNext ? _goToNext : null,
            ),
            const SizedBox(height: 16),
            FutureBuilder<PeriodComparison>(
              future: _comparison,
              builder: (context, snapshot) {
                return _SummaryRow(comparison: snapshot.data, currency: currency);
              },
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Spending by category', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  tooltip: _showCategoryAsPie ? 'Show as bars' : 'Show as pie',
                  icon: Icon(_showCategoryAsPie ? Icons.bar_chart : Icons.pie_chart_outline),
                  onPressed: () => setState(() => _showCategoryAsPie = !_showCategoryAsPie),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FutureBuilder<List<CategorySpend>>(
              future: _byCategory,
              builder: (context, snapshot) {
                final data = snapshot.data ?? const [];
                if (data.isEmpty) {
                  return const _EmptyHint(text: 'No categorized spending in this period.');
                }
                return _showCategoryAsPie
                    ? _CategoryPieChart(data: data, isDark: isDark, currency: currency)
                    : _CategoryBarChart(data: data, isDark: isDark, currency: currency);
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<CategorizationRatio>(
              future: _categorizationRatio,
              builder: (context, snapshot) {
                final ratio = snapshot.data;
                if (ratio == null) return const SizedBox.shrink();
                return CategorizationProgressBar(
                  ratio: ratio,
                  onReview: widget.onReviewUncategorized,
                );
              },
            ),
            const SizedBox(height: 28),
            Text('Spending over time', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            FutureBuilder<List<PeriodSpend>>(
              future: _monthly,
              builder: (context, snapshot) {
                final data = snapshot.data ?? const [];
                if (data.every((p) => p.total == 0)) {
                  return const _EmptyHint(text: 'No spending recorded in this period.');
                }
                return _MonthlyTrendChart(data: data, isDark: isDark);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodGranularitySelector extends StatelessWidget {
  const _PeriodGranularitySelector({required this.selected, required this.onChanged});

  final PeriodGranularity selected;
  final ValueChanged<PeriodGranularity> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PeriodGranularity>(
      segments: const [
        ButtonSegment(value: PeriodGranularity.week, label: Text('Week')),
        ButtonSegment(value: PeriodGranularity.month, label: Text('Month')),
        ButtonSegment(value: PeriodGranularity.quarter, label: Text('Quarter')),
        ButtonSegment(value: PeriodGranularity.year, label: Text('Year')),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous period',
          onPressed: onPrevious,
        ),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next period',
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.comparison, required this.currency});

  final PeriodComparison? comparison;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final s = comparison?.current;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Money in',
                value: s == null ? '—' : currency.format(s.totalIn),
                color: AppBrand.statusGood,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'Money out',
                value: s == null ? '—' : currency.format(s.totalOut),
                color: scheme.secondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'Balance',
                value: s?.currentBalance == null ? '—' : currency.format(s!.currentBalance),
                color: scheme.primary,
              ),
            ),
          ],
        ),
        if (comparison?.outChangeRatio != null) ...[
          const SizedBox(height: 10),
          _DeltaBadge(ratio: comparison!.outChangeRatio!),
        ],
      ],
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final isIncrease = ratio > 0;
    // Spending more is the "warning" direction, spending less is "good" —
    // fixed status colors, never reused as chart-series colors.
    final color = isIncrease ? AppBrand.statusCritical : AppBrand.statusGood;
    final icon = isIncrease ? Icons.arrow_upward : Icons.arrow_downward;
    final pct = (ratio.abs() * 100).toStringAsFixed(0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$pct% ${isIncrease ? 'more' : 'less'} spent vs previous period',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border(top: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _MonthlyTrendChart extends StatelessWidget {
  const _MonthlyTrendChart({required this.data, required this.isDark});

  final List<PeriodSpend> data;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isDark ? ChartPalette.sequentialDark : ChartPalette.sequentialLight;
    final monthFmt = DateFormat.MMM();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            drawVerticalLine: false,
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
                  if (index < 0 || index >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      monthFmt.format(data[index].periodStart),
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
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        NumberFormat.compact().format(s.y),
                        const TextStyle(color: Colors.white),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < data.length; i++)
                  FlSpot(i.toDouble(), data[i].total),
              ],
              isCurved: false,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
            ),
          ],
        ),
      ),
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
