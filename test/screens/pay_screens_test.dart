import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/accounts/accounts_service.dart';
import 'package:i_momo/categorization/categorization_service.dart';
import 'package:i_momo/contacts/contacts_service.dart';
import 'package:i_momo/contacts/favorite_contacts_service.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/payments/planned_payment_service.dart';
import 'package:i_momo/screens/pay/send_money_screen.dart';
import 'package:i_momo/screens/pay_screen.dart';
import 'package:i_momo/theme/app_theme.dart';
import 'package:i_momo/ussd/sim_selection_controller.dart';

/// Lays Pay & services and Send money out at a small phone size in both
/// themes — catches RenderFlex overflows and build errors.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen, {required bool dark}) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: screen,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
  }

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('Pay & services lays out and filters ($mode)', (tester) async {
      await pump(
        tester,
        PayScreen(
          contactsService: ContactsService(),
          categorizationService: CategorizationService(db),
          favoriteContactsService: FavoriteContactsService(db),
          simSelectionController: SimSelectionController(),
          plannedPaymentService: PlannedPaymentService(db),
        ),
        dark: dark,
      );
      expect(find.text('Send money'), findsOneWidget);
      expect(find.text('MTN Airtime'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'water');
      await tester.pump();
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('MTN Airtime'), findsNothing);
    });

    testWidgets('Send money lays out and the keypad builds an amount ($mode)', (tester) async {
      await pump(
        tester,
        SendMoneyScreen(
          contactsService: ContactsService(),
          categorizationService: CategorizationService(db),
          favoriteContactsService: FavoriteContactsService(db),
          plannedPaymentService: PlannedPaymentService(db),
          simSelectionController: SimSelectionController(),
          accountsService: AccountsService(db),
        ),
        dark: dark,
      );
      await tester.tap(find.text('1'));
      await tester.tap(find.text('5'));
      await tester.tap(find.text('000'));
      await tester.pump();
      expect(find.text('15,000'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '0781234567');
      await tester.pump();
      expect(find.textContaining('0781 ••• 567'), findsOneWidget);
    });
  }

  test('maskPhone hides the middle digits', () {
    expect(maskPhone('+250781234567'), '0781 ••• 567');
    expect(maskPhone('till-123'), 'till-123');
  });
}
