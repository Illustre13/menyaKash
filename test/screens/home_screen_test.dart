import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/accounts/accounts_service.dart';
import 'package:i_momo/analytics/analytics_service.dart';
import 'package:i_momo/budgets/budget_service.dart';
import 'package:i_momo/categorization/categorization_service.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/profile/referral_service.dart';
import 'package:i_momo/profile/user_profile_service.dart';
import 'package:i_momo/providers/provider_selection_service.dart';
import 'package:i_momo/screens/home_screen.dart';
import 'package:i_momo/theme/app_theme.dart';
import 'package:i_momo/ussd/sim_selection_controller.dart';
import 'package:i_momo/utilities/saved_meter_service.dart';

/// Lays the redesigned Home tab out at a small phone size in both
/// themes, with one account and a few uncategorized transactions so the
/// hero, categorize prompt, Accounts and Recent activity all render.
void main() {
  for (final dark in [false, true]) {
    testWidgets('Home lays out (${dark ? 'dark' : 'light'})', (tester) async {
      // Synchronous stream close: drift's query streams otherwise keep a
      // pending timer that a widget test's fake clock never fires.
      final db = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
      );
      addTearDown(db.close);
      final accounts = AccountsService(db);
      final providers = ProviderSelectionService(db, accounts);
      final profile = UserProfileService(db);

      await tester.runAsync(() async {
        final options = await providers.allProviderOptions();
        final mtn = options.firstWhere((o) => o.provider.code == 'mtn_momo_rw').provider;
        await providers.selectProviders([mtn.id]);
        await profile.markOnboardingComplete();
        // Checklist off so the sections below it are inside the viewport.
        await profile.setSetupChecklistHidden(true);
        final account = (await accounts.allAccountSummaries()).single.account;
        for (var i = 0; i < 3; i++) {
          await db.into(db.transactions).insert(TransactionsCompanion.insert(
                type: TransactionType.sent,
                amount: 1500,
                fee: const Value(100),
                counterparty: const Value('Test Person'),
                providerId: Value(mtn.id),
                accountId: Value(account.id),
                balanceAfter: const Value(235601),
                timestamp: DateTime.now().subtract(Duration(hours: i)),
                rawSmsBody: 'redacted',
              ));
        }
      });

      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: HomeScreen(
          analytics: AnalyticsService(db),
          accountsService: accounts,
          budgetService: BudgetService(db),
          categorizationService: CategorizationService(db),
          profileService: profile,
          providerSelectionService: providers,
          referralService: ReferralService(db),
          simSelectionController: SimSelectionController(),
          savedMeterService: SavedMeterService(db),
          onOpenPay: () {},
          onOpenSendMoney: () {},
          onOpenTransactions: () {},
          onOpenBudgets: () {},
          onOpenInsights: () {},
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }

      expect(find.text('Send'), findsOneWidget);
      expect(find.text('All services'), findsOneWidget);
      expect(find.textContaining('need a category'), findsOneWidget);
      expect(find.text('235,601'), findsWidgets);

      // Unmount so drift's stream timers settle before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    });
  }
}
