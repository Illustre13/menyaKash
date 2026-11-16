import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/ussd/ussd_builder.dart';

void main() {
  test('sendMoney builds the expected *182*1*1*<phone>*<amount># code', () {
    expect(
      UssdBuilder.sendMoney(phoneNumber: '0788123456', amountRwf: 100),
      '*182*1*1*0788123456*100#',
    );
  });

  test('sendMoney rejects an unnormalized recipient in debug/test builds', () {
    expect(
      () => UssdBuilder.sendMoney(phoneNumber: '627434673883892627492', amountRwf: 100),
      throwsA(isA<AssertionError>()),
      reason: 'the defensive assert must catch a call site that skipped '
          'PhoneNormalizer — this is the exact garbage string from the '
          'real reported bug',
    );
  });

  test('payMerchant builds the expected *182*8*1*<code>*<amount># code', () {
    expect(
      UssdBuilder.payMerchant(tillCode: '91234', amountRwf: 2000),
      '*182*8*1*91234*2000#',
    );
  });

  group('confirmed-real codes (review batch item #2, quoted verbatim from a real article)', () {
    test('buyAirtime builds the corrected *182*2*1*1*1*<amount># code', () {
      expect(UssdBuilder.buyAirtime(amountRwf: 500), '*182*2*1*1*1*500#');
    });

    test('checkBalance builds *182*6*1#', () {
      expect(UssdBuilder.checkBalance(), '*182*6*1#');
    });

    test('payWater builds *182*3*5#', () {
      expect(UssdBuilder.payWater(), '*182*3*5#');
    });

    test('payElectricity builds *720*1#', () {
      expect(UssdBuilder.payElectricity(), '*720*1#');
    });

    test('mtnBundles builds *345#', () {
      expect(UssdBuilder.mtnBundles(), '*345#');
    });

    test('checkAirtimeBalance builds *131# (same code for MTN and Airtel)', () {
      expect(UssdBuilder.checkAirtimeBalance(), '*131#');
    });

    test('airtelRechargeAirtime builds *130#', () {
      expect(UssdBuilder.airtelRechargeAirtime(), '*130#');
    });

    test('airtelShareAirtime builds *132#', () {
      expect(UssdBuilder.airtelShareAirtime(), '*132#');
    });

    test('airtelBundles builds *255#', () {
      expect(UssdBuilder.airtelBundles(), '*255#');
    });

    test('bankMenu builds each confirmed bank\'s root code', () {
      expect(UssdBuilder.bankMenu(BankUssd.bk), '*334#');
      expect(UssdBuilder.bankMenu(BankUssd.bpr), '*150#');
      expect(UssdBuilder.bankMenu(BankUssd.imBank), '*227#');
      expect(UssdBuilder.bankMenu(BankUssd.equity), '*555#');
    });
  });
}
