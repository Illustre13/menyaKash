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
}
