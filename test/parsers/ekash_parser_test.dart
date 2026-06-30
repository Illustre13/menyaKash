import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/parsers/ekash_parser.dart';

String _fixture(String name) => File('test/fixtures/ekash/$name.txt').readAsStringSync().trim();

void main() {
  late EkashParser parser;

  setUp(() {
    parser = EkashParser();
  });

  test('parses a real eKash payment message', () {
    final result = parser.tryParse(_fixture('payment'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.payment);
    expect(result.amount, 500);
    expect(result.counterparty, contains('eKash'));
    expect(result.fee, 20);
    expect(result.txRef, '13559072472');
    expect(result.balanceAfter, 21931);
  });

  test('returns null for a non-eKash message', () {
    final result = parser.tryParse('You have received 5000 RWF from someone.');
    expect(result, isNull);
  });
}
