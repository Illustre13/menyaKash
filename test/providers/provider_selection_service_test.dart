import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/accounts/accounts_service.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/providers/provider_selection_service.dart';

void main() {
  late AppDatabase db;
  late ProviderSelectionService service;
  late int mtnProviderId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ProviderSelectionService(db, AccountsService(db));
    mtnProviderId = (await (db.select(db.financialProviders)
          ..where((tbl) => tbl.code.equals('mtn_momo_rw')))
        .getSingle())
        .id;
  });

  tearDown(() => db.close());

  test('allProviderOptions lists every known provider, initially unselected', () async {
    final options = await service.allProviderOptions();
    expect(options, isNotEmpty);
    expect(options.every((o) => !o.isSelected), isTrue);
  });

  test('selectProviders writes a selection row and creates a matching account', () async {
    await service.selectProviders([mtnProviderId]);

    final selected = await service.selectedProviders();
    expect(selected.map((p) => p.id), contains(mtnProviderId));

    final accounts = await db.select(db.accounts).get();
    expect(accounts, hasLength(1));
    expect(accounts.single.providerId, mtnProviderId);
  });

  test('selecting an already-selected provider again does not duplicate the account', () async {
    await service.selectProviders([mtnProviderId]);
    await service.selectProviders([mtnProviderId]);

    final accounts = await db.select(db.accounts).get();
    expect(accounts, hasLength(1));
  });

  test('deselectProvider removes the selection but leaves the account and its transactions',
      () async {
    await service.selectProviders([mtnProviderId]);
    final accountBefore = (await db.select(db.accounts).get()).single;

    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: Value(accountBefore.id),
          type: TransactionType.received,
          amount: 5000,
          timestamp: DateTime(2026, 1, 1),
          rawSmsBody: 'irrelevant',
        ));

    await service.deselectProvider(mtnProviderId);

    final selected = await service.selectedProviders();
    expect(selected, isEmpty, reason: 'deselecting must remove the selection row');

    final accountsAfter = await db.select(db.accounts).get();
    expect(accountsAfter, hasLength(1), reason: 'the account itself must survive deselection');

    final txAfter = await db.select(db.transactions).get();
    expect(txAfter, hasLength(1), reason: 'existing transaction history must survive deselection');
  });
}
