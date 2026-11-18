import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/analytics/analytics_service.dart';
import 'package:i_momo/categorization/categorization_service.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/screens/insights_screen.dart';
import 'package:i_momo/theme/app_theme.dart';

/// Lays the Insights tab out at phone size in both themes, in both of
/// its category states — catches overflows and build errors that the
/// AnalyticsService unit tests never exercise.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));

  /// Unmounts the screen and flushes drift's zero-delay stream-cleanup
  /// timers, then closes the database on the real event loop (it does
  /// real I/O, which never completes under the test's fake clock).
  Future<void> tearDownScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
    await tester.runAsync(db.close);
  }

  Future<void> seed({required bool categorized}) async {
    final categoryId = categorized ? (await db.select(db.categories).get()).first.id : null;
    final now = DateTime.now();
    for (var i = 0; i < 5; i++) {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            type: TransactionType.payment,
            amount: 1500.0 * (i + 1),
            timestamp: DateTime(now.year, now.month, 1).add(Duration(hours: i)),
            rawSmsBody: 'irrelevant',
            counterparty: Value('Payee $i'),
            categoryId: Value(categoryId),
          ));
    }
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          type: TransactionType.received,
          amount: 20000,
          timestamp: DateTime(now.year, now.month, 1),
          rawSmsBody: 'irrelevant',
        ));
  }

  Future<void> pump(WidgetTester tester, {required bool dark}) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: InsightsScreen(
          analytics: AnalyticsService(db),
          categorizationService: CategorizationService(db),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
  }

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('mostly uncategorized shows the sort prompt ($mode)', (tester) async {
      await tester.runAsync(() => seed(categorized: false));
      await pump(tester, dark: dark);
      expect(find.text('Net cash flow'), findsOneWidget);
      expect(find.text('Your categories aren’t ready yet'), findsOneWidget);
      expect(find.textContaining('Sort all'), findsOneWidget);
      expect(find.text('Where most money went'), findsOneWidget);
      await tearDownScreen(tester);
    });

    testWidgets('categorized shows the category chart ($mode)', (tester) async {
      await tester.runAsync(() => seed(categorized: true));
      await pump(tester, dark: dark);
      expect(find.text('Your categories aren’t ready yet'), findsNothing);
      expect(find.text('Spending over time'), findsOneWidget);
      await tearDownScreen(tester);
    });
  }
}
