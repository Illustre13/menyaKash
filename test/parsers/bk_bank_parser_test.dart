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

  test('parses a real TRANSFER to another BK account (cross-network, still a real BK debit)', () {
    final result = parser.tryParse(_fixture('transfer_to_bk'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.bankTransfer);
    expect(result.amount, 950000);
    expect(result.txRef, 'FTCM27431AP9LXM4D');
    expect(result.balanceAfter, 2660630);
  });

  test('parses a real TRANSFER to I&M BANK (cross-bank, still a real BK debit)', () {
    final result = parser.tryParse(_fixture('transfer_to_im_bank'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.bankTransfer);
    expect(result.amount, 250000);
    expect(result.txRef, 'FTCM27317WR8ZJQ5N');
  });

  test('parses the English shape\'s "Available Balance" and 12-hour date', () {
    final result = parser.tryParse(_fixture('transfer_to_momo_v2'));
    expect(result, isNotNull);
    expect(result!.balanceAfter, 312294);
    expect(result.timestamp, DateTime(2026, 6, 5, 1, 47));
  });

  test('returns null for an unrecognized message shape', () {
    final result = parser.tryParse('Your OTP is 123456.');
    expect(result, isNull);
  });
}
