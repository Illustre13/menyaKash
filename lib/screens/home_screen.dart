import 'dart:async';

import 'package:flutter/material.dart';

import '../accounts/accounts_service.dart';
import '../analytics/analytics_service.dart';
import '../analytics/period.dart';
import '../budgets/budget_service.dart';
import '../categorization/categorization_service.dart';
import '../data/database.dart';
import '../profile/referral_service.dart';
import '../profile/user_profile_service.dart';
import '../providers/provider_selection_service.dart';
import '../sms/sms_ingest_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../ussd/sim_selection_controller.dart';
import '../ussd/ussd_builder.dart';
import '../ussd/ussd_dialer.dart';
import '../utilities/meter_entry_popup.dart';
import '../utilities/saved_meter_service.dart';
import '../widgets/coming_soon_popup.dart';
import '../widgets/design_system.dart';
import 'categorize_screen.dart';
import 'dashboard/overview_card.dart';
import 'home/home_sections.dart';
import 'onboarding/provider_selection_screen.dart';
import 'onboarding/sms_import_flow.dart';
import 'pay_screen.dart';
import 'profile/profile_screen.dart';
import 'setup/app_lock_reminder_sheet.dart';
import 'setup/app_lock_setup_screen.dart';
import 'setup/setup_checklist_card.dart';

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
    required this.onOpenSendMoney,
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

  /// Home's "Send" quick action: pushes Send money directly rather than
  /// switching to the Pay tab first.
  final VoidCallback onOpenSendMoney;

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
  late Future<List<AccountSummary>> _accounts;
  // Streams, not one-shot Futures (confirmed real bug: categorizing a
  // transaction elsewhere never refreshed Home's figures until it was
  // reopened) — see AnalyticsService's class doc.
  late Stream<SpendSummary> _thisMonth;
  late Stream<CategorizationRatio> _categorization;
  late Future<UserProfileData?> _profile;

  // Review batch item #6: masks Total Balance + every per-account
  // balance. Local bool, not re-derived from `_profile`'s Future each
  // build — tapping the eye needs to flip instantly, not wait on a
  // database round-trip; the persisted value is only the source of
  // truth for the NEXT app launch, updated fire-and-forget below.
  bool _balanceHidden = false;

  Map<int, String> _providerNames = const {};

  /// providerCode → 'mobile_money' | 'bank', for the Accounts list.
  Map<String, String> _providerCategories = const {};
  Set<int> _transferIds = const {};

  // "Finish setting up" checklist (onboarding redesign screen 6). Null
  // until first loaded; every step's done-state is derived from real
  // state, so this is re-read whenever a step could have changed.
  _SetupState? _setup;

  @override
  void initState() {
    super.initState();
    _reload();
    unawaited(_loadSetup().then((_) => _maybeRemindAppLock()));
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
    setState(() {
      _accounts = widget.accountsService.allAccountSummaries();
    });
  }

  void _reload() {
    _accounts = widget.accountsService.allAccountSummaries();
    _thisMonth = widget.analytics.watchSummary(
      period: Period.containing(PeriodGranularity.month, DateTime.now()),
    );
    _categorization = widget.analytics.watchCategorizationRatio();
    _profile = widget.profileService.currentProfile();
    _profile.then((profile) {
      if (!mounted || profile == null) return;
      setState(() => _balanceHidden = profile.balanceHidden);
    });
    _loadLookups();
  }

  Future<void> _loadSetup() async {
    final profile = await widget.profileService.currentProfile();
    final providers = await widget.providerSelectionService.selectedProviders();
    // Web dev preview has no SMS inbox — treat the import as done there.
    final smsGranted = await widget.smsIngestService?.hasPermissions() ?? true;
    if (!mounted) return;
    setState(() {
      _setup = _SetupState(
        hidden: profile?.setupChecklistHidden ?? false,
        appLock: profile?.appLockEnabled ?? false,
        sorted: profile?.setupSortedAt != null,
        email: (profile?.email ?? '').isNotEmpty,
        accounts: providers.isNotEmpty,
        sms: smsGranted,
      );
    });
  }

  /// The one-off App Lock reminder sheet (screen 7) — once per launch at
  /// most, only from Home, and only per the reminder rules in
  /// [UserProfileService.shouldShowAppLockReminder].
  Future<void> _maybeRemindAppLock() async {
    final profile = await widget.profileService.currentProfile();
    if (!mounted || !UserProfileService.shouldShowAppLockReminder(profile)) return;
    final enabled = await showAppLockReminderSheet(
      context,
      profileService: widget.profileService,
      dismissalsSoFar: profile!.appLockReminderDismissals,
    );
    if (enabled) widget.onReturnFromProfile?.call();
    await _loadSetup();
  }

  Future<void> _openProfile() async {
    final setup = _setup;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          profileService: widget.profileService,
          accountsService: widget.accountsService,
          providerSelectionService: widget.providerSelectionService,
          referralService: widget.referralService,
          smsIngestService: widget.smsIngestService,
          showFinishSetup: setup != null && setup.hidden && !setup.allDone,
        ),
      ),
    );
    // Settings (reached from Profile) may have just enabled a provider
    // and backfilled its history, or changed App Lock — reload so a
    // newly-imported balance shows without needing a manual
    // pull-to-refresh.
    if (!mounted) return;
    setState(_reload);
    widget.onReturnFromProfile?.call();
    await _loadSetup();
  }

  Future<void> _setUpAppLock() async {
    final enabled = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AppLockSetupScreen(profileService: widget.profileService)),
    );
    if (enabled == true) widget.onReturnFromProfile?.call();
    await _loadSetup();
  }

  Future<void> _sortTransactions() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CategorizeScreen(service: widget.categorizationService)),
    );
    await widget.profileService.markTransactionsSorted();
    await _loadSetup();
    // Sorting is what makes Insights meaningful — land there next.
    widget.onOpenInsights();
  }

  /// The "N transactions need a category" card's Review. Same screen
  /// as the checklist's sort step, so it ticks that step too — but
  /// returns to Home rather than jumping to Insights.
  Future<void> _reviewCategories() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CategorizeScreen(service: widget.categorizationService)),
    );
    await widget.profileService.markTransactionsSorted();
    await _loadSetup();
  }

  Future<void> _chooseAccounts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProviderSelectionScreen(
          service: widget.providerSelectionService,
          inOnboarding: false,
          onContinue: () => Navigator.of(context).pop(),
        ),
      ),
    );
    if (mounted) setState(_reload);
    await _loadSetup();
  }

  Future<void> _importSms() async {
    final ingest = widget.smsIngestService;
    if (ingest == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SmsImportFlow(
          ingestService: ingest,
          profileService: widget.profileService,
          providerSelectionService: widget.providerSelectionService,
          themeController: ThemeController(widget.profileService),
          inOnboarding: false,
          onNotNow: () => Navigator.of(context).pop(),
          onFinished: () => Navigator.of(context).pop(),
        ),
      ),
    );
    if (mounted) setState(_reload);
    // The scan screen also offers App Lock while waiting.
    widget.onReturnFromProfile?.call();
    await _loadSetup();
  }

  Future<void> _hideSetup() async {
    await widget.profileService.setSetupChecklistHidden(true);
    await _loadSetup();
  }

  List<SetupStep> _setupSteps(_SetupState setup) => [
        SetupStep(
          title: 'Turn on App Lock',
          subtitle: 'Keep your balances private',
          done: setup.appLock,
          recommended: true,
          onTap: _setUpAppLock,
        ),
        SetupStep(
          title: 'Sort your transactions',
          subtitle: 'Unlocks spending by category',
          done: setup.sorted,
          onTap: _sortTransactions,
        ),
        SetupStep(
          title: 'Add your email',
          subtitle: 'Names this profile on the device',
          done: setup.email,
          optional: true,
          onTap: _openProfile,
        ),
        SetupStep(
          title: 'Choose your accounts',
          subtitle: 'Pick the providers you use',
          done: setup.accounts,
          onTap: _chooseAccounts,
        ),
        SetupStep(
          title: 'Import your SMS history',
          subtitle: 'Find your past transactions',
          done: setup.sms,
          onTap: _importSms,
        ),
      ];

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

  Future<void> _loadLookups() async {
    final service = widget.categorizationService;
    final names = await service.providerNamesById();
    final transferIds = await service.linkedTransferTransactionIds();
    final options = await widget.providerSelectionService.allProviderOptions();
    if (!mounted) return;
    setState(() {
      _providerNames = names;
      _transferIds = transferIds;
      _providerCategories = {
        for (final o in options) o.provider.code: o.provider.category,
      };
    });
  }

  static String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning';
    if (now.hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: FutureBuilder<UserProfileData?>(
          future: _profile,
          builder: (context, snapshot) {
            final name = snapshot.data?.displayName;
            return Row(
              children: [
                Image.asset('assets/images/menyacash_icon.png', height: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(DateTime.now()),
                        style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      Text(
                        name != null && name.isNotEmpty ? name : 'Menya Kash',
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          _HeaderIconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            tooltip: 'Notifications',
            onPressed: () => showComingSoonPopup(
              context,
              feature: 'Notifications',
              icon: Icons.notifications_none_outlined,
              description: 'Alerts for budgets and unusual spending, all worked out on '
                  'this phone.',
            ),
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            // A dot stays on Profile while the setup checklist is
            // hidden but not finished.
            icon: Badge(
              isLabelVisible: _setup != null && _setup!.hidden && !_setup!.allDone,
              smallSize: 8,
              backgroundColor: AppBrand.orangeLight,
              child: const Icon(Icons.person_outline),
            ),
            tooltip: 'Profile',
            onPressed: _openProfile,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.smsIngestService?.scanNewMessagesSince();
          setState(_reload);
          await _loadSetup();
        },
        child: StreamBuilder<List<Transaction>>(
          stream: widget.categorizationService.watchAll(),
          builder: (context, txSnapshot) {
            // Fee rows are shown as "+100 fee" under the payment they
            // belong to (Transactions.fee), not as rows of their own.
            final activity =
                txSnapshot.data?.where((tx) => tx.type != TransactionType.fee).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                FutureBuilder<List<AccountSummary>>(
                  future: _accounts,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Skeleton(height: 180, radius: 24);
                    }
                    return StreamBuilder<SpendSummary>(
                      stream: _thisMonth,
                      builder: (context, month) => OverviewCard(
                        summaries: snapshot.data!,
                        currency: rwf,
                        simSelectionController: widget.simSelectionController,
                        balanceHidden: _balanceHidden,
                        onToggleBalanceHidden: _toggleBalanceHidden,
                        monthIn: month.data?.totalIn,
                        monthOut: month.data?.totalOut,
                        updatedAt:
                            (activity?.isNotEmpty ?? false) ? activity!.first.timestamp : null,
                      ),
                    );
                  },
                ),
                if (_setup case final setup? when !setup.hidden && !setup.allDone) ...[
                  const SizedBox(height: 16),
                  SetupChecklistCard(steps: _setupSteps(setup), onHide: _hideSetup),
                ],
                const SizedBox(height: 16),
                // Send and All services open the Pay & services tab;
                // Electricity runs its confirmed real code directly.
                // Airtime opens Pay too: the confirmed MTN airtime code
                // needs an amount, which Pay & services asks for.
                Row(
                  children: [
                    HomeQuickAction(
                      icon: Icons.north_east,
                      label: 'Send',
                      accent: true,
                      onTap: widget.onOpenSendMoney,
                    ),
                    HomeQuickAction(
                      icon: Icons.bolt_outlined,
                      label: 'Electricity',
                      onTap: () => _runUtility(
                        service: MeterService.electricity,
                        title: 'Electricity (Cash Power)',
                        code: UssdBuilder.payElectricity(),
                      ),
                    ),
                    HomeQuickAction(
                      icon: Icons.phone_android_outlined,
                      label: 'Airtime',
                      onTap: widget.onOpenPay,
                    ),
                    HomeQuickAction(
                      icon: Icons.grid_view_outlined,
                      label: 'All services',
                      onTap: widget.onOpenPay,
                    ),
                  ],
                ),
                StreamBuilder<CategorizationRatio>(
                  stream: _categorization,
                  builder: (context, snapshot) {
                    final ratio = snapshot.data;
                    if (ratio == null || ratio.needsReviewCount == 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: CategorizePromptCard(ratio: ratio, onReview: _reviewCategories),
                    );
                  },
                ),
                const SizedBox(height: 20),
                FutureBuilder<List<AccountSummary>>(
                  future: _accounts,
                  builder: (context, snapshot) {
                    final summaries = snapshot.data ?? const [];
                    if (summaries.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HomeSectionHeader('Accounts',
                            actionLabel: 'Manage', onAction: _chooseAccounts),
                        AccountsList(
                          summaries: summaries,
                          categoryByCode: _providerCategories,
                          balanceHidden: _balanceHidden,
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),
                HomeSectionHeader(
                  'Recent activity',
                  actionLabel: 'See all',
                  onAction: widget.onOpenTransactions,
                ),
                if (activity == null)
                  const TransactionListSkeleton(rows: 4)
                else if (activity.isEmpty && _setup?.sms == false)
                  const EmptyState(
                    icon: Icons.sms_outlined,
                    title: 'No transactions yet',
                    message: 'Import your SMS history from the checklist above to '
                        'see your past MoMo and bank activity.',
                  )
                else if (activity.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No activity yet',
                    message: 'Your transactions will appear here as soon as a '
                        'MoMo or bank SMS arrives.',
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      child: Column(
                        children: [
                          for (final (i, tx) in activity.take(5).indexed) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                color: scheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ActivityRow(
                              transaction: tx,
                              providerName:
                                  tx.providerId != null ? _providerNames[tx.providerId!] : null,
                              isTransfer: _transferIds.contains(tx.id),
                              onTap: widget.onOpenTransactions,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Round, tinted app-bar button (bell, profile) per the Home design.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.tooltip, required this.onPressed});

  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: icon,
      iconSize: 20,
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _SetupState {
  const _SetupState({
    required this.hidden,
    required this.appLock,
    required this.sorted,
    required this.email,
    required this.accounts,
    required this.sms,
  });

  final bool hidden;
  final bool appLock;
  final bool sorted;
  final bool email;
  final bool accounts;
  final bool sms;

  // Email is optional, so it never keeps the checklist open.
  bool get allDone => appLock && sorted && accounts && sms;
}
