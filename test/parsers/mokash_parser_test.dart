import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/parsers/mokash_parser.dart';

String _fixture(String name) =>
    File('test/fixtures/mokash/$name.txt').readAsStringSync().trim();

void main() {
  late MokashParser parser;

  setUp(() {
    parser = MokashParser();
  });

  test('parses a real "transferred from Mokash" message as a withdrawal', () {
    final result = parser.tryParse(_fixture('withdrawal'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.withdrawal);
    expect(result.amount, 10000);
    expect(result.balanceAfter, 4670);
    expect(result.txRef, '29236263792');
    expect(result.timestamp, DateTime(2026, 7, 16, 16, 45));
  });

  test('parses a real "transferred to Mokash" message as a deposit, '
      'including its reversed time-then-date ordering', () {
    final result = parser.tryParse(_fixture('deposit'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.deposit);
    expect(result.amount, 150000);
    expect(result.balanceAfter, 163517,
        reason: 'balance must parse even with no space before "Ref" ("163517.Ref")');
    expect(result.txRef, '29102297042');
    expect(result.timestamp, DateTime(2026, 7, 10, 12, 36));
  });

  test('a non-transactional MoKash maintenance notice does not parse', () {
    final result = parser.tryParse(
      'Dear customer, due to system maintenance, MoKash will be unavailable on '
      'Sunday night 28/06/2026 from 12:00 AM to 02:00 AM. We apologize for the '
      'inconvenience.',
    );
    expect(result, isNull);
  });
}
