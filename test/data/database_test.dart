import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('categorizing a code is remembered for future lookups', () async {
    final categoryId = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'Food'));

    await db.assignCodeToCategory('55123', categoryId);

    final found = await db.findCategoryByCode('55123');
    expect(found, isNotNull);
    expect(found!.name, 'Food');
  });

  test('unknown code has no category', () async {
    final found = await db.findCategoryByCode('does-not-exist');
    expect(found, isNull);
  });

  test('a differently-worded counterparty for the same real merchant still '
      'matches, via the fuzzy fallback (closes the confirmed real gap: '
      'exact-match-only meant "SUPERMARKET LTD - TILL 2" never inherited a '
      'category taught on "SUPERMARKET LTD (Code: 55123)")', () async {
    final categoryId = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'My Custom Groceries'));
    await db.assignCodeToCategory('SUPERMARKET LTD (Code: 55123)', categoryId);

    final found = await db.findCategoryByCode('SUPERMARKET LTD - TILL 2');
    expect(found, isNotNull);
    expect(found!.name, 'My Custom Groceries');
  });

  test('exact match wins over fuzzy match when both are present', () async {
    final groceries = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'My Custom Groceries'));
    final other =
        await db.into(db.categories).insert(CategoriesCompanion.insert(name: 'My Custom Other'));
    await db.assignCodeToCategory('SUPERMARKET LTD', other);
    await db.assignCodeToCategory('SUPERMARKET LTD (Code: 55123)', groceries);

    final found = await db.findCategoryByCode('SUPERMARKET LTD');
    expect(found!.name, 'My Custom Other',
        reason: 'the byte-identical mapping must win, not a fuzzy one');
  });

  test('a bare phone number never fuzzy-matches anything by coincidence',
      () async {
    final categoryId = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'My Custom Transfers'));
    await db.assignCodeToCategory('0788123456', categoryId);

    final found = await db.findCategoryByCode('0722222222');
    expect(found, isNull);
  });

  test('financial providers are seeded on database creation', () async {
    final providers = await db.select(db.financialProviders).get();
    final codes = providers.map((p) => p.code).toSet();
    expect(
      codes,
      containsAll(['mtn_momo_rw', 'ekash_rw', 'airtel_money_rw', 'bk_bank_rw', 'equity_bank_rw']),
    );
  });

  test('M-Money is registered as a sender for both mtn_momo_rw and ekash_rw', () async {
    final senders = await (db.select(db.providerSenders)
          ..where((tbl) => tbl.senderPattern.equals('M-Money')))
        .get();
    expect(senders.length, greaterThanOrEqualTo(2));
  });

  test('hashSmsMessage is deterministic for identical inputs', () {
    final receivedAt = DateTime(2026, 1, 1, 10, 0);
    final a = hashSmsMessage(sender: 'M-Money', body: 'hello', receivedAt: receivedAt);
    final b = hashSmsMessage(sender: 'M-Money', body: 'hello', receivedAt: receivedAt);
    expect(a, b);
  });

  test('hashSmsMessage differs when body differs', () {
    final receivedAt = DateTime(2026, 1, 1, 10, 0);
    final a = hashSmsMessage(sender: 'M-Money', body: 'hello', receivedAt: receivedAt);
    final b = hashSmsMessage(sender: 'M-Money', body: 'goodbye', receivedAt: receivedAt);
    expect(a, isNot(b));
  });

  test('inserting the same sms_messages hash twice violates the unique constraint', () async {
    final receivedAt = DateTime(2026, 1, 1, 10, 0);
    final hash = hashSmsMessage(sender: 'M-Money', body: 'dup test', receivedAt: receivedAt);

    await db.into(db.smsMessages).insert(
          SmsMessagesCompanion.insert(
            sender: 'M-Money',
            body: 'dup test',
            receivedAt: receivedAt,
            smsHash: hash,
          ),
        );

    expect(
      () => db.into(db.smsMessages).insert(
            SmsMessagesCompanion.insert(
              sender: 'M-Money',
              body: 'dup test',
              receivedAt: receivedAt,
              smsHash: hash,
            ),
          ),
      throwsA(anything),
    );
  });
}
