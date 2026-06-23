import 'package:drift/drift.dart' show Value;

import 'database.dart';

/// Dev/testing-only fake data. Used by the Flutter-web entry point
/// (`main_web.dart`) since there is no SMS inbox to read on web — this
/// lets the Dashboard, Categorize, and Review screens render and behave
/// realistically without an Android device or SDK. Never wired into the
/// real Android entry point (`main.dart`).
Future<void> seedDevData(AppDatabase db) async {
  final existing = await db.select(db.transactions).get();
  if (existing.isNotEmpty) return; // already seeded on a previous run

  final foodId = await db.into(db.categories).insert(
        const CategoriesCompanion(name: Value('Food')),
      );
  final transportId = await db.into(db.categories).insert(
        const CategoriesCompanion(name: Value('Transport')),
      );
  final utilitiesId = await db.into(db.categories).insert(
        const CategoriesCompanion(name: Value('Utilities')),
      );

  final now = DateTime.now();
  DateTime daysAgo(int days) => now.subtract(Duration(days: days));
  DateTime monthsAgo(int months) => DateTime(now.year, now.month - months, now.day);

  final rows = <TransactionsCompanion>[
    // This month — categorized.
    _tx(
      type: TransactionType.payment,
      amount: 3500,
      counterparty: 'SUPERMARKET LTD (Code: 55123)',
      categoryId: foodId,
      timestamp: daysAgo(1),
    ),
    _tx(
      type: TransactionType.payment,
      amount: 1200,
      counterparty: 'MOTO TAXI (Code: 88213)',
      categoryId: transportId,
      timestamp: daysAgo(2),
    ),
    _tx(
      type: TransactionType.payment,
      amount: 15000,
      counterparty: 'EUCL PREPAID (Code: 77021)',
      categoryId: utilitiesId,
      timestamp: daysAgo(3),
    ),
    // This month — uncategorized, including two that share a name for
    // testing the bulk-categorize-similar flow.
    _tx(
      type: TransactionType.payment,
      amount: 2000,
      counterparty: 'CORNER SHOP LTD (Code: 91234)',
      timestamp: daysAgo(4),
    ),
    _tx(
      type: TransactionType.payment,
      amount: 4500,
      counterparty: 'CORNER SHOP LTD - TILL 2',
      timestamp: daysAgo(5),
    ),
    _tx(
      type: TransactionType.received,
      amount: 25000,
      counterparty: 'Jean Uwimana (0788123456)',
      timestamp: daysAgo(6),
    ),
    _tx(
      type: TransactionType.sent,
      amount: 5000,
      fee: 100,
      counterparty: 'Alice Mukamana (0788987654)',
      timestamp: daysAgo(7),
    ),
    _tx(
      type: TransactionType.withdrawal,
      amount: 20000,
      counterparty: 'AGENT KIMISAGARA (12345)',
      timestamp: daysAgo(8),
    ),
    _tx(
      type: TransactionType.airtime,
      amount: 1000,
      timestamp: daysAgo(9),
    ),
    // Previous month, for the period-comparison delta.
    _tx(
      type: TransactionType.payment,
      amount: 2800,
      counterparty: 'SUPERMARKET LTD (Code: 55123)',
      categoryId: foodId,
      timestamp: monthsAgo(1),
    ),
    _tx(
      type: TransactionType.payment,
      amount: 900,
      counterparty: 'MOTO TAXI (Code: 88213)',
      categoryId: transportId,
      timestamp: monthsAgo(1),
    ),
    // A few months back, to populate the trend chart.
    _tx(
      type: TransactionType.payment,
      amount: 6200,
      counterparty: 'SUPERMARKET LTD (Code: 55123)',
      categoryId: foodId,
      timestamp: monthsAgo(2),
    ),
    _tx(
      type: TransactionType.payment,
      amount: 3100,
      counterparty: 'SUPERMARKET LTD (Code: 55123)',
      categoryId: foodId,
      timestamp: monthsAgo(3),
    ),
  ];

  for (final row in rows) {
    await db.into(db.transactions).insert(row);
  }

  await db.into(db.unparsedMessages).insert(
        UnparsedMessagesCompanion.insert(
          sender: 'MTN',
          body: 'Dear customer, your bundle expires in 3 days. Dial *182*2# to renew.',
          receivedAt: daysAgo(1),
        ),
      );
}

TransactionsCompanion _tx({
  required TransactionType type,
  required double amount,
  double fee = 0,
  String? counterparty,
  int? categoryId,
  required DateTime timestamp,
}) {
  return TransactionsCompanion.insert(
    provider: 'mtn_rw',
    type: type,
    amount: amount,
    fee: Value(fee),
    counterparty: Value(counterparty),
    timestamp: timestamp,
    rawSmsBody: '[seeded dev data]',
    categoryId: Value(categoryId),
  );
}
