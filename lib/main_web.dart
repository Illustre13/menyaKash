import 'package:flutter/material.dart';

import 'accounts/accounts_service.dart';
import 'analytics/analytics_service.dart';
import 'budgets/budget_service.dart';
import 'categorization/categorization_service.dart';
import 'contacts/contacts_service.dart';
import 'contacts/favorite_contacts_service.dart';
import 'data/database.dart';
import 'data/dev_seed_data.dart';
import 'profile/referral_service.dart';
import 'profile/user_profile_service.dart';
import 'providers/provider_selection_service.dart';
import 'screens/budgets_screen.dart';
import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/transactions_screen.dart';
import 'theme/app_theme.dart';

/// Dev/testing entry point for `flutter run -d chrome`. Not the real app
/// entry point (`main.dart`) — this app's actual purpose (reading MoMo
/// SMS, dialing USSD codes, browsing phone contacts) is Android-only and
/// has no full web equivalent. This lets the Dashboard, Pay (frequent
/// codes + manual entry paths), Categorize, and Review screens — the
/// parts that are just UI + local database + analytics — be exercised
/// in a browser without an Android SDK, using seeded fake transactions
/// instead of a real SMS inbox. The contacts picker inside Pay degrades
/// to an empty list here rather than crashing, since flutter_contacts
/// has no web implementation.
void main() {
  runApp(const IMomoWebDevApp());
}

class IMomoWebDevApp extends StatelessWidget {
  const IMomoWebDevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Menya Kash (web dev preview)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const WebDevHomeShell(),
    );
  }
}

class WebDevHomeShell extends StatefulWidget {
  const WebDevHomeShell({super.key});

  @override
  State<WebDevHomeShell> createState() => _WebDevHomeShellState();
}

class _WebDevHomeShellState extends State<WebDevHomeShell> {
  final _db = AppDatabase();
  late final _categorizationService = CategorizationService(_db);
  late final _analyticsService = AnalyticsService(_db);
  late final _accountsService = AccountsService(_db);
  late final _profileService = UserProfileService(_db);
  late final _providerSelectionService = ProviderSelectionService(_db, _accountsService);
  late final _budgetService = BudgetService(_db);
  final _contactsService = ContactsService();
  late final _favoriteContactsService = FavoriteContactsService(_db);
  late final _referralService = ReferralService(_db);

  bool _seeded = false;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _seed();
  }

  Future<void> _seed() async {
    await seedDevData(_db);
    setState(() => _seeded = true);
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_seeded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
      appBar: AppBar(
        title: const Text('Menya Kash — web dev preview'),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        toolbarHeight: 32,
        titleTextStyle: Theme.of(context).textTheme.labelSmall,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(child: IndexedStack(index: _index, children: screens)),
        ],
      ),
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
