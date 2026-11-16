import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../accounts/accounts_service.dart';
import '../analytics/analytics_service.dart';
import '../analytics/chart_palette.dart';
import '../analytics/period.dart';
import '../budgets/budget_service.dart';
import '../categorization/categorization_service.dart';
import '../categorization/category_taxonomy.dart';
import '../data/database.dart';
import '../profile/referral_service.dart';
import '../profile/user_profile_service.dart';
import '../providers/provider_selection_service.dart';
import '../sms/sms_ingest_service.dart';
import '../theme/app_theme.dart';
import '../ussd/sim_selection_controller.dart';
import '../ussd/ussd_builder.dart';
import '../ussd/ussd_dialer.dart';
import '../utilities/meter_entry_popup.dart';
import '../utilities/saved_meter_service.dart';
import '../widgets/coming_soon_popup.dart';
import '../widgets/design_system.dart';
import '../widgets/transaction_tile.dart';
import 'dashboard/overview_card.dart';
import 'pay_screen.dart';
import 'profile/profile_screen.dart';

/// The Home tab (UI redesign): greeting, balance hero with wallet
/// breakdown, a single Pay quick action (Transactions/Budgets/Insights
/// already have their own tabs, so they don't need a second doorway
/// here), an Insights preview (period filter + category chart + a
/// one-line Money In/Out row), the budget preview, and the 10 most
/// recent transactions. Every section is a doorway — See all →
/// Transactions, the Insights preview → Insights, budget rings →
/// Budgets — so Home stays a calm overview, not a wall of data.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.analytics,
    required this.accountsService,
    required this.budgetService,
    required this.categorizationService,
    required this.profileService,
    required this.providerSelectionService,
    required this.referralService,
    this.smsIngestService,
    required this.simSelectionController,
    required this.savedMeterService,
    required this.onOpenPay,
    required this.onOpenTransactions,
    required this.onOpenBudgets,
    required this.onOpenInsights,
    this.onReturnFromProfile,
  });

  final AnalyticsService analytics;
  final AccountsService accountsService;
  final BudgetService budgetService;
  final CategorizationService categorizationService;
  final UserProfileService profileService;
  final ProviderSelectionService providerSelectionService;
  final ReferralService referralService;

  /// Null on the web dev-preview entry point (`main_web.dart`), which
  /// has no real SMS inbox to incrementally scan. When present, Home
  /// uses it to catch up on any provider SMS that arrived since the
  /// last check (spec review batch item #3) — on open and on
  /// pull-to-refresh — without re-reading the whole inbox.
  final SmsIngestService? smsIngestService;

  /// Session-scoped SIM choice (review batch item #2) shared with
  /// [PayScreen] — asks the user at most once per app session on a
  /// dual-SIM device instead of letting Android show its own picker
  /// from an un-chosen call, or forgetting the choice the moment the
  /// user leaves Pay screen.
  final SimSelectionController simSelectionController;

  /// Backs the "save this meter?" convenience on the Electricity/Water
  /// quick actions (review batch item #3) — never itself dialed.
  final SavedMeterService savedMeterService;

  /// Switches HomeShell's bottom-nav to the Pay tab (review batch item
  /// #7/#8: Pay is now a persistent tab, not a pushed route) — same
  /// tab-switch pattern as [onOpenTransactions]/[onOpenBudgets]/
  /// [onOpenInsights].
  final VoidCallback onOpenPay;

  final VoidCallback onOpenTransactions;
  final VoidCallback onOpenBudgets;
  final VoidCallback onOpenInsights;

  /// Called after Profile (and whatever it pushed, e.g. Settings) pops
  /// back to Home — lets HomeShell re-read App Lock's setting the
  /// moment it could plausibly have changed, without threading a
  /// dedicated service/callback all the way through Profile→Settings.
  final VoidCallback? onReturnFromProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Period _period = Period.containing(PeriodGranularity.month, DateTime.now());

  late Future<List<AccountSummary>> _accounts;
  // Streams, not one-shot Futures (confirmed real bug: categorizing a
  // transaction elsewhere never refreshed this preview chart/metrics
  // until Home was reopened) — see AnalyticsService's class doc.
  late Stream<PeriodComparison> _summary;
  late Stream<List<CategorySpend>> _byCategory;
  late Future<List<BudgetStatus>> _budgets;
  late Future<UserProfileData?> _profile;

  // Review batch item #6: masks Total Balance + every per-account
  // balance. Local bool, not re-derived from `_profile`'s Future each
  // build — tapping the eye needs to flip instantly, not wait on a
  // database round-trip; the persisted value is only the source of
  // truth for the NEXT app launch, updated fire-and-forget below.
  bool _balanceHidden = false;

  Map<int, String> _categoryNames = const {};
  Map<int, String> _providerCodes = const {};
  Map<int, String> _providerNames = const {};
  Set<int> _transferIds = const {};

  @override
  void initState() {
    super.initState();
    _reload();
    // Catch up on any provider SMS that arrived since the app was last
    // opened (spec review batch item #3) — fire-and-forget: the account
    // balance/transaction Streams already wired below re-emit on their
    // own once new rows land, so Home doesn't need to await this before
    // rendering its first frame.
    unawaited(_catchUpOnNewMessages());
  }

  Future<void> _catchUpOnNewMessages() async {
    await widget.smsIngestService?.scanNewMessagesSince();
    if (!mounted) return;
    // The balance hero reads accountsService.allAccountSummaries() as a
    // plain Future, not a watched Stream (see that field's doc) — so
    // unlike the Stream-backed summary/category widgets, it needs an
    // explicit reload to pick up a balance the catch-up scan just wrote.
    setState(() => _accounts = widget.accountsService.allAccountSummaries());
  }

  void _reload() {
    _accounts = widget.accountsService.allAccountSummaries();
    _summary = widget.analytics.watchSummaryWithComparison(_period);
    _byCategory = widget.analytics.watchSpendByCategory(period: _period);
    _budgets = widget.budgetService.statusesForMonth(DateTime.now());
    _profile = widget.profileService.currentProfile();
    _profile.then((profile) {
      if (!mounted || profile == null) return;
      setState(() => _balanceHidden = profile.balanceHidden);
    });
    _loadLookups();
  }

  void _toggleBalanceHidden() {
    setState(() => _balanceHidden = !_balanceHidden);
    unawaited(widget.profileService.setBalanceHidden(_balanceHidden));
  }

  /// Runs a bill-pay quick action's USSD code directly — no separate
  /// "open dialer" detour (review batch item #2), same standardized
  /// path Pay screen's own "Pay now" and Advanced-grid tiles use. The
  /// SIM slot comes from the shared, session-scoped
  /// [SimSelectionController] so a dual-SIM device is asked in-app at
  /// most once per session, never via Android's own picker.
  Future<void> _runUssd(String code) async {
    final simSlot = await widget.simSelectionController.ensureChosen(context);
    if (!mounted) return;
    final outcome = await UssdDialer.runDirect(code, simSlotIndex: simSlot);
    if (!mounted || outcome != UssdRunOutcome.failed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not start this on this device.')),
    );
  }

  /// Electricity/Water (review batch item #3): shows the meter-number
  /// popup first — a convenience so the user reads/copies their saved
  /// meter number onto the real on-screen USSD prompt — then runs the
  /// same confirmed real root code [_runUssd] already uses. The
  /// popup never changes the dialed string itself.
  Future<void> _runUtility({
    required String service,
    required String title,
    required String code,
  }) async {
    final proceed = await showMeterEntryPopup(
      context,
      service: service,
      title: title,
      savedMeterService: widget.savedMeterService,
    );
    if (proceed != true || !mounted) return;
    await _runUssd(code);
  }

  void _setGranularity(PeriodGranularity granularity) {
    setState(() {
      _period = Period.containing(granularity, DateTime.now());
      _reload();
    });
  }

  Future<void> _loadLookups() async {
    final service = widget.categorizationService;
    final results = await Future.wait([
      service.categoryNamesById(),
      service.providerCodesById(),
      service.providerNamesById(),
      service.linkedTransferTransactionIds(),
    ]);
    if (!mounted) return;
    setState(() {
      _categoryNames = results[0] as Map<int, String>;
      _providerCodes = results[1] as Map<int, String>;
      _providerNames = results[2] as Map<int, String>;
      _transferIds = results[3] as Set<int>;
    });
  }

  static String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(compact: true),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    profileService: widget.profileService,
                    accountsService: widget.accountsService,
                    providerSelectionService: widget.providerSelectionService,
                    referralService: widget.referralService,
                    smsIngestService: widget.smsIngestService,
                  ),
                ),
              );
              // Settings (reached from Profile) may have just enabled a
              // provider and backfilled its history, or changed App
              // Lock — reload so a newly-imported balance shows without
              // needing a manual pull-to-refresh.
              if (mounted) setState(_reload);
              widget.onReturnFromProfile?.call();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.smsIngestService?.scanNewMessagesSince();
          setState(_reload);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            FutureBuilder<UserProfileData?>(
              future: _profile,
              builder: (context, snapshot) {
                final name = snapshot.data?.displayName;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                    name != null && name.isNotEmpty
                        ? '${_greeting(DateTime.now())}, $name'
                        : _greeting(DateTime.now()),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                );
              },
            ),
            FutureBuilder<List<AccountSummary>>(
              future: _accounts,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Skeleton(height: 180, radius: 24);
                }
                return OverviewCard(
                  summaries: snapshot.data!,
                  currency: rwf,
                  simSelectionController: widget.simSelectionController,
                  balanceHidden: _balanceHidden,
                  onToggleBalanceHidden: _toggleBalanceHidden,
                );
              },
            ),
            const SizedBox(height: 16),
            // Pay now switches to its own bottom-nav tab (review batch
            // item #7/#8) rather than pushing a route, plus the
            // most-reached-for bill-pay USSD actions (review batch item
            // #2) as one-tap direct-dial tiles. Electricity/Water use
            // confirmed real codes (quoted verbatim from a real
            // article); Urubuto/RRA have no confirmed code from any
            // source in this app's research, so they're honest "coming
            // soon" tiles, not guessed codes.
            Row(
              children: [
                QuickAction(
                  icon: Icons.bolt,
                  label: 'Pay',
                  onTap: widget.onOpenPay,
                ),
                QuickAction(
                  icon: Icons.flash_on_outlined,
                  label: 'Electricity',
                  onTap: () => _runUtility(
                    service: MeterService.electricity,
                    title: 'Electricity (Cash Power)',
                    code: UssdBuilder.payElectricity(),
                  ),
                ),
                QuickAction(
                  icon: Icons.water_drop_outlined,
                  label: 'Water',
                  onTap: () => _runUtility(
                    service: MeterService.water,
                    title: 'Water (WASAC)',
                    code: UssdBuilder.payWater(),
                  ),
                ),
                QuickAction(
                  icon: Icons.school_outlined,
                  label: 'Urubuto',
                  onTap: () => showComingSoonPopup(
                    context,
                    feature: 'Urubuto (school fees)',
                    icon: Icons.school_outlined,
                    description: 'We haven\'t confirmed Urubuto\'s USSD code from a '
                        'reliable source yet, so this app won\'t guess it.',
                  ),
                ),
                QuickAction(
                  icon: Icons.receipt_long_outlined,
                  label: 'RRA',
                  onTap: () => showComingSoonPopup(
                    context,
                    feature: 'RRA (taxes)',
                    icon: Icons.receipt_long_outlined,
                    description: 'We haven\'t confirmed RRA\'s USSD code from a '
                        'reliable source yet, so this app won\'t guess it.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SectionHeader('Insights', actionLabel: 'Open', onAction: widget.onOpenInsights),
            AppCard(
              onTap: widget.onOpenInsights,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PeriodStrip(
                    selected: _period.granularity,
                    onChanged: _setGranularity,
                  ),
                  const SizedBox(height: 14),
                  // One line each for In/Out (spec #7): a direction
                  // icon then the amount, side by side rather than
                  // stacked, so both fit without the card growing tall.
                  StreamBuilder<PeriodComparison>(
                    stream: _summary,
                    builder: (context, snapshot) {
                      final s = snapshot.data?.current;
                      return Row(
                        children: [
                          Expanded(
                            child: _InlineMoneyRow(
                              icon: Icons.arrow_downward_rounded,
                              kind: MoneyKind.income,
                              amount: s?.totalIn,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _InlineMoneyRow(
                              icon: Icons.arrow_upward_rounded,
                              kind: MoneyKind.expense,
                              amount: s?.totalOut,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<CategorySpend>>(
                    stream: _byCategory,
                    builder: (context, snapshot) {
                      final data = snapshot.data ?? const [];
                      if (data.isEmpty) {
                        return SizedBox(
                          height: 90,
                          child: Center(
                            child: Text(
                              'No categorized spending in this period.',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        );
                      }
                      return _MiniCategoryChart(data: data, isDark: isDark);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<BudgetStatus>>(
              future: _budgets,
              builder: (context, snapshot) {
                final statuses = snapshot.data ?? const [];
                if (statuses.isEmpty) return const SizedBox.shrink();
                final preview = statuses.take(3).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader('Budgets', actionLabel: 'See all', onAction: widget.onOpenBudgets),
                    AppCard(
                      onTap: widget.onOpenBudgets,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (final status in preview)
                            Column(
                              children: [
                                ProgressRing(
                                  value: status.ratio,
                                  color: status.isOver
                                      ? AppBrand.expense(Theme.of(context).brightness)
                                      : status.isNearLimit
                                          ? AppBrand.orangeButtonLight
                                          : AppBrand.income(Theme.of(context).brightness),
                                  size: 54,
                                  strokeWidth: 6,
                                  child: Icon(
                                    categoryStyle(status.category.name).$1,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  status.category.name,
                                  style: Theme.of(context).textTheme.labelSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
            SectionHeader(
              'Recent activity',
              actionLabel: 'See all',
              onAction: widget.onOpenTransactions,
            ),
            StreamBuilder<List<Transaction>>(
              stream: widget.categorizationService.watchAll(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const TransactionListSkeleton(rows: 4);
                final recent = snapshot.data!.take(10).toList();
                if (recent.isEmpty) {
                  return const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No activity yet',
                    message: 'Your transactions will appear here as soon as a '
                        'MoMo or bank SMS arrives.',
                  );
                }
                return AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    children: [
                      for (final tx in recent)
                        TransactionTile(
                          transaction: tx,
                          categoryName:
                              tx.categoryId != null ? _categoryNames[tx.categoryId!] : null,
                          providerCode:
                              tx.providerId != null ? _providerCodes[tx.providerId!] : null,
                          providerName:
                              tx.providerId != null ? _providerNames[tx.providerId!] : null,
                          isTransfer: _transferIds.contains(tx.id),
                          onTap: widget.onOpenTransactions,
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact Week/Month/Quarter/Year filter for the Home Insights
/// preview — same granularities as the Insights tab itself, so tapping
/// a period here and then opening Insights shows a consistent story.
class _PeriodStrip extends StatelessWidget {
  const _PeriodStrip({required this.selected, required this.onChanged});

  final PeriodGranularity selected;
  final ValueChanged<PeriodGranularity> onChanged;

  @override
  Widget build(BuildContext context) {
    // Confirmed real overflow: 4 fixed-text segments ("Quarter" being
    // the longest) can exceed the card's width on narrower phones or a
    // larger system text scale — SizedBox.expand + FittedBox lets the
    // whole control shrink to fit instead of clipping/overflowing,
    // rather than trying to guess a font size that always fits.
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: SegmentedButton<PeriodGranularity>(
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
          ),
          segments: const [
            ButtonSegment(value: PeriodGranularity.week, label: Text('Week')),
            ButtonSegment(value: PeriodGranularity.month, label: Text('Month')),
            ButtonSegment(value: PeriodGranularity.quarter, label: Text('Quarter')),
            ButtonSegment(value: PeriodGranularity.year, label: Text('Year')),
          ],
          selected: {selected},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ),
    );
  }
}

/// One line: a direction icon, then the amount — reserves less
/// vertical space than a stacked label+figure card (spec #7), so both
/// In and Out fit comfortably side by side.
class _InlineMoneyRow extends StatelessWidget {
  const _InlineMoneyRow({required this.icon, required this.kind, required this.amount});

  final IconData icon;
  final MoneyKind kind;
  final double? amount;

  @override
  Widget build(BuildContext context) {
    final color = kind.color(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: amount == null
              ? const Skeleton(width: 60)
              : AmountText(amount!, kind: kind, style: Theme.of(context).textTheme.titleSmall),
        ),
      ],
    );
  }
}

/// A compact donut, capped at 4 slices + "Other" — smaller and busier
/// than the full Insights chart is meant to be, since this is only a
/// preview that invites a tap-through, not the analysis surface
/// itself.
class _MiniCategoryChart extends StatelessWidget {
  const _MiniCategoryChart({required this.data, required this.isDark});

  final List<CategorySpend> data;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final shown = data.length > 4
        ? [
            ...data.take(3),
            CategorySpend('Other', data.skip(3).fold(0.0, (sum, c) => sum + c.total)),
          ]
        : data;

    return Row(
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 26,
              sections: [
                for (final c in shown)
                  PieChartSectionData(
                    value: c.total,
                    color: ChartPalette.colorFor(c.categoryName, isDark: isDark),
                    radius: 18,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            children: shown.map((c) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: ChartPalette.colorFor(c.categoryName, isDark: isDark),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(c.categoryName, style: Theme.of(context).textTheme.labelSmall),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
