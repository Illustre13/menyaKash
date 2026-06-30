import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/parsers/airtel_money_parser.dart';

String _fixture(String name) =>
    File('test/fixtures/airtel_money/$name.txt').readAsStringSync().trim();

void main() {
  late AirtelMoneyParser parser;

  setUp(() {
    parser = AirtelMoneyParser();
  });

  test('parses a real received-money message', () {
    final result = parser.tryParse(_fixture('received'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.received);
    expect(result.amount, 500);
    expect(result.counterparty, contains('Jean Uwimana'));
    expect(result.txRef, 'CI240415.2137.A06010');
    expect(result.balanceAfter, 3320);
  });

  test('parses a real sent-money message (Amount RWF X. CHARGES RWF Y variant)', () {
    final result = parser.tryParse(_fixture('sent'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.sent);
    expect(result.amount, 500);
    expect(result.counterparty, contains('Jean Uwimana'));
    expect(result.fee, 30);
    expect(result.balanceAfter, 305);
  });

  test('parses a real merchant payment message', () {
    final result = parser.tryParse(_fixture('payment'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.payment);
    expect(result.amount, 1000);
    expect(result.counterparty, contains('Future Dynamic Innovations'));
    expect(result.balanceAfter, 1640);
  });

  test('parses a real bundle purchase (balance appears before amount in this shape)', () {
    final result = parser.tryParse(_fixture('bundle_purchase'));
    expect(result, isNotNull);
    expect(result!.type, TransactionType.airtime);
    expect(result.amount, 3000);
    expect(result.balanceAfter, 320);
  });

  test('returns null for an unrecognized message shape', () {
    final result = parser.tryParse('Mukiliya wacu, serivisi zizavugururwa.');
    expect(result, isNull);
  });
}
