import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/accounts/accounts_service.dart';
import 'package:i_momo/data/database.dart';

void main() {
  late AppDatabase db;
  late AccountsService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = AccountsService(db);
  });

  tearDown(() => db.close());

  test('one default account exists per seeded provider', () async {
    final summaries = await service.allAccountSummaries();
    final codes = await db.select(db.financialProviders).get();
    expect(summaries.length, codes.length);
  });

  test('a fresh account with no transactions has a null current balance', () async {
    final mtnProvider = await (db.select(db.financialProviders)
          ..where((tbl) => tbl.code.equals('mtn_momo_rw')))
        .getSingle();
    final account = await service.defaultAccountForProvider(mtnProvider.id);
    expect(account, isNotNull);

    final balance = await service.currentBalance(account!.id);
    expect(balance, isNull);
  });

  test('current balance is the most recent transaction\'s balanceAfter, not a stored total', () async {
    final mtnProvider = await (db.select(db.financialProviders)
          ..where((tbl) => tbl.code.equals('mtn_momo_rw')))
        .getSingle();
    final account = await service.defaultAccountForProvider(mtnProvider.id);

    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: Value(account!.id),
          type: TransactionType.received,
          amount: 5000,
          balanceAfter: const Value(5000),
          timestamp: DateTime(2026, 1, 1, 10, 0),
          rawSmsBody: 'irrelevant',
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: Value(account.id),
          type: TransactionType.payment,
          amount: 2000,
          balanceAfter: const Value(3000),
          timestamp: DateTime(2026, 1, 2, 10, 0),
          rawSmsBody: 'irrelevant',
        ));

    final balance = await service.currentBalance(account.id);
    expect(balance, 3000, reason: 'the later transaction\'s balance wins, not a sum');
  });

  test('renaming an account persists the new label', () async {
    final mtnProvider = await (db.select(db.financialProviders)
          ..where((tbl) => tbl.code.equals('mtn_momo_rw')))
        .getSingle();
    final account = await service.defaultAccountForProvider(mtnProvider.id);

    await service.renameAccount(account!.id, 'My Personal MoMo');

    final updated =
        await (db.select(db.accounts)..where((tbl) => tbl.id.equals(account.id))).getSingle();
    expect(updated.label, 'My Personal MoMo');
  });
}
