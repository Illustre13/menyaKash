import 'dart:async';

import 'package:flutter/material.dart';

import 'analytics/analytics_service.dart';
import 'budgets/budget_service.dart';
import 'categorization/categorization_service.dart';
import 'contacts/contacts_service.dart';
import 'contacts/favorite_contacts_service.dart';
import 'data/database.dart';
import 'parsers/momo_parser_registry.dart';
import 'profile/referral_service.dart';
import 'profile/user_profile_service.dart';
import 'providers/provider_detector_factory.dart';
import 'providers/provider_selection_service.dart';
import 'screens/budgets_screen.dart';
import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/onboarding/onboarding_flow_screen.dart';
import 'screens/transactions_screen.dart';
import 'sms/sms_ingest_service.dart';
import 'sms/sms_processor.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'transfers/transfer_matching_engine.dart';
import 'accounts/accounts_service.dart';

void main() {
  runApp(const IMomoApp());
}

class IMomoApp extends StatelessWidget {
  const IMomoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'Menya Kash',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: const HomeShell(),
      ),
    );
  }
}

/// Owns the app's singletons (db, registry, services) for the lifetime
/// of the app and hosts bottom-nav between the five main screens.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _db = AppDatabase();
  late final _registry = MomoParserRegistry();
  late final _detector = buildProviderDetector(_db);
  late final _processor = SmsProcessor(_db, _registry, _detector);
  late final _ingestService = SmsIngestService(_db, _detector, _processor);
  late final _transferEngine = TransferMatchingEngine(_db);
  late final _categorizationService = CategorizationService(_db);
  late final _analyticsService = AnalyticsService(_db);
  late final _accountsService = AccountsService(_db);
  late final _profileService = UserProfileService(_db);
  late final _providerSelectionService = ProviderSelectionService(_db, _accountsService);
  late final _budgetService = BudgetService(_db);
  late final _themeController = ThemeController(_profileService);
  final _contactsService = ContactsService();
  late final _favoriteContactsService = FavoriteContactsService(_db);
  late final _referralService = ReferralService(_db);

  int _index = 0;

  // null while we haven't yet checked onboarding-completion status from
  // the database; true/false once known. Onboarding runs only when this
  // resolves to false — a returning user goes straight to the dashboard.
  //
  // This is checked via UserProfile.onboardingCompletedAt (spec Phase
  // 5+), not SMS-permission state as it was pre-Phase-5 — identity/
  // provider setup and SMS access are now separable: a user who denies
  // SMS access isn't forced to repeat the whole onboarding flow every
  // launch, only the SMS step itself (still retryable from the
  // dashboard's Settings if needed later).
  bool? _alreadyOnboarded;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    // Apply the persisted theme before anything renders behind the
    // loading state — a dark-theme user shouldn't get a light flash on
    // every launch (sprint #3).
    await _themeController.loadSaved();
    final onboarded = await _profileService.hasCompletedOnboarding();
    if (onboarded) {
      // Historical scan already happened during onboarding: just resume
      // live listening and catch up on any transfer pairs formed by
      // messages received since the last launch.
      if (await _ingestService.hasPermissions()) {
        _ingestService.startLiveListener();
      }
      unawaited(_transferEngine.findAndLinkTransfers());
    }
    setState(() => _alreadyOnboarded = onboarded);
  }

  void _onOnboardingComplete() {
    // Historical scan just finished, so both sides of any real transfer
    // (e.g. a BK debit and its matching MTN credit) now exist — this is
    // the natural point to look for them. Fire-and-forget: transfer
    // links are a refinement on top of already-correct individual
    // transactions, not something the user needs to wait on before
    // seeing their dashboard.
    unawaited(_transferEngine.findAndLinkTransfers());
    setState(() => _alreadyOnboarded = true);
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_alreadyOnboarded == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_alreadyOnboarded == false) {
      return OnboardingFlowScreen(
        ingestService: _ingestService,
        profileService: _profileService,
        providerSelectionService: _providerSelectionService,
        themeController: _themeController,
        onComplete: _onOnboardingComplete,
      );
    }

    // Four calm tabs (UI redesign): Home / Transactions / Budgets /
    // Insights. Pay is a Home quick action (pushed route); the
    // code-bank and unparsed-review tooling live behind the
    // Transactions app bar; Profile hangs off Home's app bar.
    final screens = [
      HomeScreen(
        analytics: _analyticsService,
        accountsService: _accountsService,
        budgetService: _budgetService,
        categorizationService: _categorizationService,
        contactsService: _contactsService,
        favoriteContactsService: _favoriteContactsService,
        profileService: _profileService,
        providerSelectionService: _providerSelectionService,
        referralService: _referralService,
        smsIngestService: _ingestService,
        onOpenTransactions: () => setState(() => _index = 1),
        onOpenBudgets: () => setState(() => _index = 2),
        onOpenInsights: () => setState(() => _index = 3),
      ),
      TransactionsScreen(db: _db, categorizationService: _categorizationService),
      BudgetsScreen(budgetService: _budgetService),
      InsightsScreen(
        analytics: _analyticsService,
        onReviewUncategorized: () => setState(() => _index = 1),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.track_changes), label: 'Budgets'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'Insights'),
        ],
      ),
    );
  }
}
