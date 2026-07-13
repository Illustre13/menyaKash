import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/ussd/phone_normalizer.dart';

void main() {
  group('normalizeRwandanMobile — accepted real shapes', () {
    test('already-canonical 0XXXXXXXXX passes through unchanged', () {
      expect(PhoneNormalizer.normalizeRwandanMobile('0788123456'), '0788123456');
    });

    test('+250XXXXXXXXX international form', () {
      expect(PhoneNormalizer.normalizeRwandanMobile('+250788123456'), '0788123456');
    });

    test('250XXXXXXXXX with no leading plus', () {
      expect(PhoneNormalizer.normalizeRwandanMobile('250788123456'), '0788123456');
    });

    test('9-digit form with no leading 0', () {
      expect(PhoneNormalizer.normalizeRwandanMobile('788123456'), '0788123456');
    });

    test('spaces and dashes are stripped', () {
      expect(PhoneNormalizer.normalizeRwandanMobile('+250 788 123 456'), '0788123456');
      expect(PhoneNormalizer.normalizeRwandanMobile('078-812-3456'), '0788123456');
    });
  });

  group('normalizeRwandanMobile — rejected input', () {
    test('the actual reported broken recipient string is rejected', () {
      expect(PhoneNormalizer.normalizeRwandanMobile('627434673883892627492'), isNull);
    });

    test('empty string is rejected', () {
      expect(PhoneNormalizer.normalizeRwandanMobile(''), isNull);
    });

    test('alphabetic junk is rejected', () {
      expect(PhoneNormalizer.normalizeRwandanMobile('not a number'), isNull);
    });

    test('too-short a number is rejected', () {
      expect(PhoneNormalizer.normalizeRwandanMobile('12345'), isNull);
    });

    test('a free-text merchant counterparty string is rejected, not mangled', () {
      expect(
        PhoneNormalizer.normalizeRwandanMobile('THE FAMILYS BAKERY LTD 096957'),
        isNull,
      );
    });
  });
}
