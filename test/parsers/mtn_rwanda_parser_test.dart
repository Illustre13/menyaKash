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

  test('parses a received-money message', () {
    final result = parser.tryParse(_fixture('received'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.received);
    expect(result.amount, 5000);
    expect(result.counterparty, contains('Jean Uwimana'));
    expect(result.txRef, '987654321');
    expect(result.balanceAfter, 12500);
  });

  test('extracts the transaction date embedded in the SMS body', () {
    final result = parser.tryParse(_fixture('received'));
    expect(result, isNotNull);
    // Fixture text: "...on 08/07/2026 14:32:10..."
    expect(result!.timestamp, DateTime(2026, 7, 8, 14, 32, 10));
  });

  test('falls back to the SMS inbox date when body has no parseable date', () {
    final receivedAt = DateTime(2024, 1, 1, 9, 0);
    final result = parser.tryParse(
      'You have received 1,000 RWF from someone. TxId: 1. Bal: 1,000 RWF.',
      receivedAt: receivedAt,
    );
    expect(result, isNotNull);
    expect(result!.timestamp, receivedAt);
  });

  test('falls back to now when neither body date nor receivedAt is available', () {
    final before = DateTime.now();
    final result = parser.tryParse(
      'You have received 1,000 RWF from someone. TxId: 1. Bal: 1,000 RWF.',
    );
    final after = DateTime.now();
    expect(result, isNotNull);
    expect(result!.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
    expect(result.timestamp.isBefore(after.add(const Duration(seconds: 1))), isTrue);
  });

  test('parses a sent-money message', () {
    final result = parser.tryParse(_fixture('sent'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.sent);
    expect(result.amount, 10000);
    expect(result.fee, 100);
    expect(result.balanceAfter, 2500);
  });

  test('parses a merchant payment message', () {
    final result = parser.tryParse(_fixture('payment'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.payment);
    expect(result.amount, 3500);
    expect(result.counterparty, contains('SUPERMARKET'));
  });

  test('parses a withdrawal message', () {
    final result = parser.tryParse(_fixture('withdrawal'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.withdrawal);
    expect(result.amount, 20000);
  });

  test('parses a deposit message', () {
    final result = parser.tryParse(_fixture('deposit'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.deposit);
    expect(result.amount, 50000);
  });

  test('parses an airtime purchase message', () {
    final result = parser.tryParse(_fixture('airtime'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.airtime);
    expect(result.amount, 1000);
  });

  test('parses a reversed-transaction message', () {
    final result = parser.tryParse(_fixture('reversed'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.reversed);
  });

  test('returns null for an unrecognized message shape', () {
    final result = parser.tryParse('Happy birthday from MTN!');
    expect(result, isNull);
  });
}
