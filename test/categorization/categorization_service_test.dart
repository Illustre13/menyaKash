import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/categorization/categorization_service.dart';
import 'package:i_momo/data/database.dart';

void main() {
  late AppDatabase db;
  late CategorizationService service;

  Future<int> insertTx({
    required String counterparty,
    int? categoryId,
    double amount = 1000,
  }) {
    return db.into(db.transactions).insert(TransactionsCompanion.insert(
          type: TransactionType.payment,
          amount: amount,
          counterparty: Value(counterparty),
          timestamp: DateTime(2026, 7, 1),
          rawSmsBody: 'irrelevant',
          categoryId: Value(categoryId),
        ));
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = CategorizationService(db);
  });

  tearDown(() => db.close());

  group('categorizeCounterparty (exact match only)', () {
    test('updates every transaction sharing the exact same counterparty string', () async {
      final categoryId = await service.createCategory('My Custom Groceries');
      final a = await insertTx(counterparty: 'CORNER SHOP LTD (Code: 91234)');
      final b = await insertTx(counterparty: 'CORNER SHOP LTD (Code: 91234)');
      final differentString = await insertTx(counterparty: 'CORNER SHOP LTD - TILL 2');

      await service.categorizeCounterparty('CORNER SHOP LTD (Code: 91234)', categoryId);

      final txs = {for (final tx in await db.select(db.transactions).get()) tx.id: tx};
      expect(txs[a]!.categoryId, categoryId);
      expect(txs[b]!.categoryId, categoryId);
      expect(txs[differentString]!.categoryId, isNull,
          reason: 'a real merchant-name variant with a different exact string is NOT '
              'caught by exact-match categorization — this is the confirmed real gap '
              'categorizeCounterpartyEverywhere exists to close');
    });
  });

  group(
      'categorizeCounterpartyEverywhere — the fix for the confirmed real bug '
      '(spec #8): editing a Frequent code left name-variant transactions '
      'for the same real merchant uncategorized', () {
    test('sweeps up other uncategorized transactions for the same real merchant', () async {
      final categoryId = await service.createCategory('My Custom Groceries');
      final exact1 = await insertTx(counterparty: 'CORNER SHOP LTD (Code: 91234)');
      final exact2 = await insertTx(counterparty: 'CORNER SHOP LTD (Code: 91234)');
      final variant = await insertTx(counterparty: 'CORNER SHOP LTD - TILL 2');
      final unrelated = await insertTx(counterparty: 'A Totally Different Merchant');

      await service.categorizeCounterpartyEverywhere('CORNER SHOP LTD (Code: 91234)', categoryId);

      final txs = {for (final tx in await db.select(db.transactions).get()) tx.id: tx};
      expect(txs[exact1]!.categoryId, categoryId);
      expect(txs[exact2]!.categoryId, categoryId);
      expect(txs[variant]!.categoryId, categoryId,
          reason: 'the real merchant-name variant must now be swept up too');
      expect(txs[unrelated]!.categoryId, isNull,
          reason: 'an unrelated merchant must never be touched');
    });

    test('never touches a transaction that already has a different category', () async {
      final groceries = await service.createCategory('My Custom Groceries');
      final transport = await service.createCategory('My Custom Transport');
      final alreadyCategorized =
          await insertTx(counterparty: 'CORNER SHOP LTD - TILL 2', categoryId: transport);

      await service.categorizeCounterpartyEverywhere('CORNER SHOP LTD (Code: 91234)', groceries);

      final tx = await (db.select(db.transactions)
            ..where((tbl) => tbl.id.equals(alreadyCategorized)))
          .getSingle();
      expect(tx.categoryId, transport,
          reason: 'the sweep only ever catches UNcategorized variants, never '
              'overwrites a transaction someone already categorized deliberately');
    });

    test('remembers the mapping so a future exact-match transaction auto-categorizes', () async {
      final categoryId = await service.createCategory('My Custom Groceries');
      await service.categorizeCounterpartyEverywhere('CORNER SHOP LTD (Code: 91234)', categoryId);

      final resolved = await db.findCategoryByCode('CORNER SHOP LTD (Code: 91234)');
      expect(resolved?.id, categoryId);
    });

    test('updateCode (the real Frequent-tab call site) uses the sweeping behavior', () async {
      final categoryId = await service.createCategory('My Custom Groceries');
      final variant = await insertTx(counterparty: 'CORNER SHOP LTD - TILL 2');
      await insertTx(counterparty: 'CORNER SHOP LTD (Code: 91234)');

      await service.updateCode('CORNER SHOP LTD (Code: 91234)', categoryId: categoryId);

      final tx =
          await (db.select(db.transactions)..where((tbl) => tbl.id.equals(variant))).getSingle();
      expect(tx.categoryId, categoryId,
          reason: 'updateCode is what the Frequent tab actually calls — it must use the '
              'sweeping fix, not the old exact-match-only path');
    });
  });
}
