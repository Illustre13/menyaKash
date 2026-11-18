import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/profile/user_profile_service.dart';
import 'package:i_momo/providers/provider_selection_service.dart';
import 'package:i_momo/accounts/accounts_service.dart';
import 'package:i_momo/screens/onboarding/provider_selection_screen.dart';
import 'package:i_momo/screens/onboarding/welcome_screen.dart';
import 'package:i_momo/screens/setup/app_lock_setup_screen.dart';
import 'package:i_momo/screens/setup/appearance_screen.dart';
import 'package:i_momo/screens/setup/setup_checklist_card.dart';
import 'package:i_momo/theme/app_theme.dart';
import 'package:i_momo/theme/theme_controller.dart';

/// Lays each onboarding / setup screen out at a small phone size in
/// both themes — catches RenderFlex overflows and build errors, which
/// unit tests of the services never exercise.
void main() {
  late AppDatabase db;
  late UserProfileService profile;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    profile = UserProfileService(db);
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen, {bool dark = false}) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: screen,
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('Welcome lays out ($mode)', (tester) async {
      await pump(tester, WelcomeScreen(onContinue: () {}), dark: dark);
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('Choose providers lays out ($mode)', (tester) async {
      final service = ProviderSelectionService(db, AccountsService(db));
      await tester.runAsync(() async {
        await pump(
            tester, ProviderSelectionScreen(service: service, onContinue: () {}, onBack: () {}),
            dark: dark);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(find.textContaining('Continue with'), findsOneWidget);
    });

    testWidgets('App Lock setup lays out ($mode)', (tester) async {
      await pump(tester, AppLockSetupScreen(profileService: profile), dark: dark);
      expect(find.text('Turn on App Lock'), findsOneWidget);
    });

    testWidgets('Appearance lays out ($mode)', (tester) async {
      await pump(tester, AppearanceScreen(themeController: ThemeController(profile)), dark: dark);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('Setup checklist lays out ($mode)', (tester) async {
      SetupStep step(String t, bool done) => SetupStep(
          title: t, subtitle: 'Subtitle', done: done, onTap: () {}, recommended: t == 'A');
      await pump(
        tester,
        Scaffold(
          body: SetupChecklistCard(
            steps: [step('A', false), step('B', false), step('C', true)],
            onHide: () {},
          ),
        ),
        dark: dark,
      );
      expect(find.text('1/3'), findsOneWidget);
    });
  }
}
