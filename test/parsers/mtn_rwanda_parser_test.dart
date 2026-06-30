import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/parsers/mtn_rwanda_parser.dart';

String _fixture(String name) =>
    File('test/fixtures/mtn_rwanda/$name.txt').readAsStringSync().trim();

void main() {
  late MtnRwandaParser parser;

  setUp(() {
    parser = MtnRwandaParser();
  });

  test('parses a real received-money message', () {
    final result = parser.tryParse(_fixture('received'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.received);
    expect(result.amount, 10000);
    expect(result.counterparty, contains('Jean Uwimana'));
    expect(result.txRef, '13573580816');
    expect(result.balanceAfter, 18458);
  });

  test('extracts the real ISO-ish embedded date (year-first, not DD/MM/YYYY)', () {
    final result = parser.tryParse(_fixture('received'));
    expect(result, isNotNull);
    // Fixture text: "...at 2026-04-17 06:31:24..."
    expect(result!.timestamp, DateTime(2026, 4, 17, 6, 31, 24));
  });

  test('falls back to the SMS inbox date when body has no parseable date', () {
    final receivedAt = DateTime(2024, 1, 1, 9, 0);
    final result = parser.tryParse(
      'You have received 1,000 RWF from someone (250788000000) on your mobile money account. '
      'Financial Transaction Id: 1. Your new balance:1,000 RWF.',
      receivedAt: receivedAt,
    );
    expect(result, isNotNull);
    expect(result!.timestamp, receivedAt);
  });

  test('falls back to now when neither body date nor receivedAt is available', () {
    final before = DateTime.now();
    final result = parser.tryParse(
      'You have received 1,000 RWF from someone (250788000000) on your mobile money account. '
      'Financial Transaction Id: 1. Your new balance:1,000 RWF.',
    );
    final after = DateTime.now();
    expect(result, isNotNull);
    expect(result!.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
    expect(result.timestamp.isBefore(after.add(const Duration(seconds: 1))), isTrue);
  });

  test('parses a real sent-money message (*165*S* shape, full phone shown)', () {
    final result = parser.tryParse(_fixture('sent'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.sent);
    expect(result.amount, 5000);
    expect(result.counterparty, contains('Jean Uwimana'));
    expect(result.fee, 100);
    expect(result.balanceAfter, 27551);
  });

  test('parses a real merchant payment message (name+code as one opaque counterparty)', () {
    final result = parser.tryParse(_fixture('payment'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.payment);
    expect(result.amount, 9283);
    expect(result.counterparty, contains('HOPITAL LA CROIX DU SUD'));
    expect(result.counterparty, contains('100126'), reason: 'name and account code are one blob at this layer — Phase 4 splits them, not the parser');
    expect(result.txRef, '13571597197');
    expect(result.balanceAfter, 11828);
  });

  test('parses a real withdrawal message (via agent)', () {
    final result = parser.tryParse(_fixture('withdrawal'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.withdrawal);
    expect(result.amount, 5000);
    expect(result.counterparty, contains('Alice Mukamana'));
    expect(result.fee, 250);
    expect(result.balanceAfter, 2832);
  });

  test('parses a real bank-deposit message (*113*R* shape)', () {
    final result = parser.tryParse(_fixture('deposit'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.deposit);
    expect(result.amount, 3500);
    expect(result.balanceAfter, 74170);
  });

  test('parses a real merchant-debit message (*164*S* shape)', () {
    final result = parser.tryParse(_fixture('bundle_purchase'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.payment);
    expect(result.amount, 1000);
    expect(result.counterparty, contains('BESOFT LTD'));
    expect(result.balanceAfter, 4278);
  });

  test('parses a real airtime purchase (payment to literal "Airtime")', () {
    final result = parser.tryParse(_fixture('airtime'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.payment);
    expect(result.amount, 100);
    expect(result.counterparty, contains('Airtime'));
    expect(result.balanceAfter, 97467);
  });

  test('a real failed-transaction message is NOT recorded as a transaction', () {
    // Confirmed real shape: the transaction never completed. Returning
    // null (routing to the unparsed/review queue) is deliberate — there
    // is no real successful "failed" transaction to model, and guessing
    // at a TransactionType for money that never moved would corrupt
    // analytics.
    final result = parser.tryParse(_fixture('failed'));
    expect(result, isNull);
  });

  test('returns null for an unrecognized message shape', () {
    final result = parser.tryParse('Happy birthday from MTN!');
    expect(result, isNull);
  });
}
