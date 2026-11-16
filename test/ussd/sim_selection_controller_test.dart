import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/ussd/sim_selection_controller.dart';

void main() {
  const channel = MethodChannel('menyakash/ussd');

  setUp(() {
    // Explicit mock rather than relying on the test binding's default
    // behavior for an unregistered channel — mirrors exactly what
    // UssdDialer.listSims() sees on a real device with no SIMs/no
    // telephony available: a MissingPluginException, handled there by
    // returning an empty list.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException();
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('ensureChosen resolves to null with no chooser shown when fewer than 2 SIMs exist',
      (tester) async {
    final controller = SimSelectionController();
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final result = await controller.ensureChosen(capturedContext);
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(controller.chosenSlot, isNull);
  });

  testWidgets('reselect is also a no-op with fewer than 2 SIMs', (tester) async {
    final controller = SimSelectionController();
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final result = await controller.reselect(capturedContext);
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
