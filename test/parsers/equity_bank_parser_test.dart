import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/parsers/equity_bank_parser.dart';

String _fixture(String name) =>
    File('test/fixtures/equity_bank/$name.txt').readAsStringSync().trim();

void main() {
  late EquityBankParser parser;

  setUp(() {
    parser = EquityBankParser();
  });

  test('parses a real sent-to-MTN-number message and extracts the MTN Ref correlation key', () {
    final result = parser.tryParse(_fixture('sent'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.bankTransfer);
    expect(result.amount, 20000);
    expect(result.counterparty, contains('Jean Uwimana'));
    expect(result.txRef, '541077019015', reason: 'MTN Ref is the cross-provider transfer-matching key (Phase 3)');
  });

  test('parses a real sent-to-masked-account message (different shape, no MTN Ref)', () {
    final result = parser.tryParse(_fixture('sent_masked_account'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.bankTransfer);
    expect(result.amount, 130000);
    expect(result.txRef, 'A915514D4F5E8');
  });

  test('parses a real received message', () {
    final result = parser.tryParse(_fixture('received'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.received);
    expect(result.amount, 30000);
    expect(result.txRef, '725436355641');
  });

  test('Equity messages never report a balance — confirmed absent in real data', () {
    final result = parser.tryParse(_fixture('sent'));
    expect(result, isNotNull);
    expect(result!.balanceAfter, isNull);
  });

  test('extracts the numeric date+CAT-time format correctly', () {
    final result = parser.tryParse(_fixture('sent'));
    expect(result, isNotNull);
    // Fixture: "on 17/04/26 at 19:24:13 CAT"
    expect(result!.timestamp, DateTime(2026, 4, 17, 19, 24, 13));
  });

  test('extracts the named-month date format correctly', () {
    final result = parser.tryParse(_fixture('sent_masked_account'));
    expect(result, isNotNull);
    // Fixture: "on 20 Nov 2026 at 14:12 CAT"
    expect(result!.timestamp, DateTime(2026, 11, 20, 14, 12));
  });

  test('returns null for an unrecognized message shape', () {
    final result = parser.tryParse('Your statement is ready.');
    expect(result, isNull);
  });
}
