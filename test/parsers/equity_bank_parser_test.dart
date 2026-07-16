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

  test('parses a real debit bank-statement message, including its running balance', () {
    final result = parser.tryParse(_fixture('debited'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.bankTransfer);
    expect(result.amount, 1000000);
    expect(result.counterparty, contains('CENTRAL BRANCH'));
    expect(result.txRef, '60291847');
    expect(result.balanceAfter, 321900.6);
    expect(result.timestamp, DateTime(2026, 1, 19, 7, 21, 4));
  });

  test('parses a real credit bank-statement message, including its running balance', () {
    final result = parser.tryParse(_fixture('credited'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.received);
    expect(result.amount, 1314000);
    expect(result.txRef, '708451');
    expect(result.balanceAfter, 1511910.6);
    expect(result.timestamp, DateTime(2026, 3, 28, 12, 51, 22));
  });

  test('a card-authorization notice (foreign currency, pending, not settled RWF) does not parse', () {
    final result = parser.tryParse(
      'Dear ALEX, Auth for card 4821..9034 Date:2026-01-22 14:25:45 Amt: USD 1.69 '
      'Details:STREAMING SERVICE . Customer Care: +250700000000/+250711111111',
    );
    expect(result, isNull);
  });

  test('a zero-amount auto-charge debit notice does not parse', () {
    final result = parser.tryParse(
      'Dear AUTO, Debit for card 4821..9034 Date:2026-02-28 04:37:04 Amt: 0.00 '
      'Details:Regular Charge. Customer Care: +250700000000/+250711111111',
    );
    expect(result, isNull);
  });

  test('an agent-withdrawal code notice (nothing has moved yet) does not parse', () {
    final result = parser.tryParse(
      'Use the code 418527 to withdraw from an agent. This code is valid for 15 '
      'minutes. Ref. 250123456789 on 19-01-2026 at 18:20',
    );
    expect(result, isNull);
  });

  test('a "request to send...received for processing" notice (not yet completed) does not parse', () {
    final result = parser.tryParse(
      'Confirmed. Request to send RWF 10000.00 to DEMO USER bank account 0*****7618 '
      'has been received for processing. You will receive a confirmation once the '
      'transaction is completed. Ref. UA92D8C1B0A14 on 10 Apr 2026 at 21:41 CAT. '
      'Charges RWF 1500.00.',
    );
    expect(result, isNull);
  });
}
