import 'package:flutter/material.dart';

import 'analytics/analytics_service.dart';
import 'categorization/categorization_service.dart';
import 'contacts/contacts_service.dart';
import 'data/database.dart';
import 'parsers/momo_parser_registry.dart';
import 'screens/categorize_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/pay_screen.dart';
import 'screens/review_unparsed_screen.dart';
import 'sms/sms_ingest_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const IMomoApp());
}

class IMomoApp extends StatelessWidget {
  const IMomoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'i-momo',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomeShell(),
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
  late final _ingestService = SmsIngestService(_db, _registry);
  late final _categorizationService = CategorizationService(_db);
  late final _analyticsService = AnalyticsService(_db);
  final _contactsService = ContactsService();

  int _index = 0;

  // null while we haven't yet checked whether SMS permission is already
  // granted from a previous run; true/false once known. Onboarding
  // (permission explainer + historical scan) only runs when this
  // resolves to false — a returning user goes straight to the dashboard
  // and relies on the live listener for anything new.
  bool? _alreadyOnboarded;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final granted = await _ingestService.hasPermissions();
    if (granted) {
      // Permission already granted from a previous run: the historical
      // scan already happened then, so just resume live listening.
      _ingestService.startLiveListener();
    }
    setState(() => _alreadyOnboarded = granted);
  }

  void _onOnboardingComplete() {
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
      return OnboardingScreen(
        ingestService: _ingestService,
        onComplete: _onOnboardingComplete,
      );
    }

    final screens = [
      DashboardScreen(analytics: _analyticsService),
      PayScreen(
        contactsService: _contactsService,
        categorizationService: _categorizationService,
      ),
      CategorizeScreen(service: _categorizationService),
      ReviewUnparsedScreen(db: _db),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.send_outlined), label: 'Pay'),
          NavigationDestination(icon: Icon(Icons.label_outline), label: 'Categorize'),
          NavigationDestination(icon: Icon(Icons.rule_folder_outlined), label: 'Review'),
        ],
      ),
    );
  }
}
