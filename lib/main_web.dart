import 'package:flutter/material.dart';

import 'analytics/analytics_service.dart';
import 'categorization/categorization_service.dart';
import 'contacts/contacts_service.dart';
import 'data/database.dart';
import 'data/dev_seed_data.dart';
import 'screens/categorize_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pay_screen.dart';
import 'screens/review_unparsed_screen.dart';
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
      title: 'i-momo (web dev preview)',
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
  final _contactsService = ContactsService();

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
      DashboardScreen(analytics: _analyticsService),
      PayScreen(
        contactsService: _contactsService,
        categorizationService: _categorizationService,
      ),
      CategorizeScreen(service: _categorizationService),
      ReviewUnparsedScreen(db: _db),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('i-momo — web dev preview'),
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
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.send_outlined), label: 'Pay'),
          NavigationDestination(icon: Icon(Icons.label_outline), label: 'Categorize'),
          NavigationDestination(icon: Icon(Icons.rule_folder_outlined), label: 'Review'),
        ],
      ),
    );
  }
}
