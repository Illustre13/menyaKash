import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/parsers/bk_bank_parser.dart';

String _fixture(String name) => File('test/fixtures/bk_bank/$name.txt').readAsStringSync().trim();

void main() {
  late BkBankParser parser;

  setUp(() {
    parser = BkBankParser();
  });

  test('parses the older Kinyarwanda TRANSFER-to-MTN shape', () {
    final result = parser.tryParse(_fixture('transfer_to_momo'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.bankTransfer);
    expect(result.amount, 100000);
    expect(result.txRef, 'FTCM24124SVR7GLGS');
  });

  test('parses the newer English TRANSFER-to-MTN shape (confirmed format change)', () {
    final result = parser.tryParse(_fixture('transfer_to_momo_v2'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.bankTransfer);
    expect(result.amount, 100000);
    expect(result.txRef, 'FTCM26156DRLPXUOI');
  });

  test('parses a real deposit message', () {
    final result = parser.tryParse(_fixture('deposit'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.deposit);
    expect(result.amount, 3000000);
    expect(result.txRef, 'FTCM2544N0JXJVEU');
  });

  test('returns null for a TRANSFER to a non-MTN destination (known gap, not silently guessed)', () {
    final result = parser.tryParse('TRANSFER - Bank of Kigali internal transfer, no MTN involved.');
    expect(result, isNull);
  });

  test('returns null for an unrecognized message shape', () {
    final result = parser.tryParse('Your OTP is 123456.');
    expect(result, isNull);
  });
}
