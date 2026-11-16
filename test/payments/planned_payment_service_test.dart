import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/payments/planned_payment_service.dart';

void main() {
  late AppDatabase db;
  late PlannedPaymentService service;
  late int categoryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = PlannedPaymentService(db);
    categoryId =
        await db.into(db.categories).insert(CategoriesCompanion.insert(name: 'My Custom Bills'));
  });

  tearDown(() => db.close());

  test('create writes a pending row', () async {
    await service.create(
      recipient: '0788123456',
      amount: 5000,
      categoryId: categoryId,
      providerCode: 'mtn_momo_rw',
    );

    final rows = await db.select(db.plannedPayments).get();
    expect(rows, hasLength(1));
    expect(rows.single.status, PlannedPaymentStatus.pending);
  });

  test('findMatchAndApply matches same provider + same amount within the '
      'window and returns the planned category', () async {
    await service.create(
      recipient: '0788123456',
      amount: 5000,
      categoryId: categoryId,
      providerCode: 'mtn_momo_rw',
    );

    final matched = await service.findMatchAndApply(
      transactionId: 1,
      amount: 5000,
      providerCode: 'mtn_momo_rw',
      transactionTimestamp: DateTime.now(),
      transactionCounterparty: 'Jean Uwimana (0788123456)',
    );

    expect(matched, categoryId);
    final row = (await db.select(db.plannedPayments).get()).single;
    expect(row.status, PlannedPaymentStatus.matched);
    expect(row.matchedTransactionId, 1);
  });

  test('does not match a different provider even with the same amount', () async {
    await service.create(
      recipient: '0788123456',
      amount: 5000,
      categoryId: categoryId,
      providerCode: 'mtn_momo_rw',
    );

    final matched = await service.findMatchAndApply(
      transactionId: 1,
      amount: 5000,
      providerCode: 'airtel_money_rw',
      transactionTimestamp: DateTime.now(),
    );

    expect(matched, isNull);
  });

  test('does not match a different amount', () async {
    await service.create(
      recipient: '0788123456',
      amount: 5000,
      categoryId: categoryId,
      providerCode: 'mtn_momo_rw',
    );

    final matched = await service.findMatchAndApply(
      transactionId: 1,
      amount: 3000,
      providerCode: 'mtn_momo_rw',
      transactionTimestamp: DateTime.now(),
    );

    expect(matched, isNull);
  });

  test('does not match a transaction outside the match window', () async {
    await service.create(
      recipient: '0788123456',
      amount: 5000,
      categoryId: categoryId,
      providerCode: 'mtn_momo_rw',
    );

    final matched = await service.findMatchAndApply(
      transactionId: 1,
      amount: 5000,
      providerCode: 'mtn_momo_rw',
      transactionTimestamp: DateTime.now().add(const Duration(hours: 1)),
    );

    expect(matched, isNull);
  });

  test('an already-matched row is never matched again (idempotency guard)', () async {
    await service.create(
      recipient: '0788123456',
      amount: 5000,
      categoryId: categoryId,
      providerCode: 'mtn_momo_rw',
    );
    await service.findMatchAndApply(
      transactionId: 1,
      amount: 5000,
      providerCode: 'mtn_momo_rw',
      transactionTimestamp: DateTime.now(),
    );

    final secondMatch = await service.findMatchAndApply(
      transactionId: 2,
      amount: 5000,
      providerCode: 'mtn_momo_rw',
      transactionTimestamp: DateTime.now(),
    );

    expect(secondMatch, isNull);
  });

  test('with two ambiguous candidates, the one whose recipient appears in the '
      'counterparty string wins the tiebreak', () async {
    final otherCategoryId = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'My Custom Other'));

    await service.create(
      recipient: '0700000001',
      amount: 5000,
      categoryId: categoryId,
      providerCode: 'mtn_momo_rw',
    );
    await service.create(
      recipient: '0788123456',
      amount: 5000,
      categoryId: otherCategoryId,
      providerCode: 'mtn_momo_rw',
    );

    final matched = await service.findMatchAndApply(
      transactionId: 1,
      amount: 5000,
      providerCode: 'mtn_momo_rw',
      transactionTimestamp: DateTime.now(),
      transactionCounterparty: 'Jean Uwimana (0788123456)',
    );

    expect(matched, otherCategoryId);
  });

  test('with ambiguous candidates and no counterparty hint, the oldest wins', () async {
    final otherCategoryId = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'My Custom Other'));

    final firstId = await service.create(
      recipient: '0700000001',
      amount: 5000,
      categoryId: categoryId,
      providerCode: 'mtn_momo_rw',
    );
    await service.create(
      recipient: '0788123456',
      amount: 5000,
      categoryId: otherCategoryId,
      providerCode: 'mtn_momo_rw',
    );

    final matched = await service.findMatchAndApply(
      transactionId: 1,
      amount: 5000,
      providerCode: 'mtn_momo_rw',
      transactionTimestamp: DateTime.now(),
    );

    expect(matched, categoryId);
    final matchedRow = await (db.select(db.plannedPayments)
          ..where((tbl) => tbl.id.equals(firstId)))
        .getSingle();
    expect(matchedRow.status, PlannedPaymentStatus.matched);
  });

  test('expireStale flips old pending rows to expired, leaves recent ones alone', () async {
    final staleId = await service.create(
      recipient: '0788123456',
      amount: 5000,
      categoryId: categoryId,
      providerCode: 'mtn_momo_rw',
    );
    await (db.update(db.plannedPayments)..where((tbl) => tbl.id.equals(staleId))).write(
      PlannedPaymentsCompanion(
        createdAt: Value(DateTime.now().subtract(const Duration(hours: 1))),
      ),
    );
    final freshId = await service.create(
      recipient: '0700000002',
      amount: 2000,
      categoryId: categoryId,
      providerCode: 'mtn_momo_rw',
    );

    await service.expireStale();

    final stale = await (db.select(db.plannedPayments)
          ..where((tbl) => tbl.id.equals(staleId)))
        .getSingle();
    final fresh = await (db.select(db.plannedPayments)
          ..where((tbl) => tbl.id.equals(freshId)))
        .getSingle();
    expect(stale.status, PlannedPaymentStatus.expired);
    expect(fresh.status, PlannedPaymentStatus.pending);
  });
}
