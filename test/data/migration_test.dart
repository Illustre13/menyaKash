import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Verifies the v1 -> v2 migration against a database that genuinely
/// started life as v1 — built with raw SQL matching the *old* schema
/// (no sms_messages/financial_providers/provider_id columns), since the
/// whole point is proving real pre-migration user data survives and
/// gets correctly backfilled, not just that a fresh v2 database works.
void main() {
  test('v1 transactions and unparsed messages are backfilled into sms_messages on upgrade',
      () async {
    final raw = sqlite3.sqlite3.openInMemory();

    // Recreate the exact v1 schema by hand (schemaVersion = 1, before
    // this migration existed) and seed it with data shaped the way a
    // real v1 install would have it: Transactions.provider as a bare
    // string, no smsMessageId/providerId columns anywhere.
    raw.execute('''
      CREATE TABLE categories (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      );
      CREATE TABLE category_codes (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        display_name TEXT,
        category_id INTEGER NOT NULL REFERENCES categories(id)
      );
      CREATE TABLE transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        provider TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        fee REAL NOT NULL DEFAULT 0,
        counterparty TEXT,
        tx_ref TEXT,
        balance_after REAL,
        timestamp INTEGER NOT NULL,
        raw_sms_body TEXT NOT NULL,
        category_id INTEGER REFERENCES categories(id)
      );
      CREATE TABLE unparsed_messages (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        sender TEXT NOT NULL,
        body TEXT NOT NULL,
        received_at INTEGER NOT NULL,
        resolved INTEGER NOT NULL DEFAULT 0
      );

      PRAGMA user_version = 1;
    ''');

    final oneTimestamp = DateTime(2026, 3, 1, 9, 0).millisecondsSinceEpoch ~/ 1000;
    raw.execute('''
      INSERT INTO transactions
        (provider, type, amount, fee, counterparty, tx_ref, balance_after, timestamp, raw_sms_body)
      VALUES
        ('mtn_rw', 'received', 5000, 0, 'Jean Uwimana', '987654321', 12500, $oneTimestamp,
         'You have received 5,000 RWF from Jean Uwimana on 01/03/2026. TxId: 987654321.');
    ''');

    final unparsedTimestamp = DateTime(2026, 3, 2, 10, 0).millisecondsSinceEpoch ~/ 1000;
    raw.execute('''
      INSERT INTO unparsed_messages (sender, body, received_at)
      VALUES ('MTN', 'Some promotional text nobody can parse.', $unparsedTimestamp);
    ''');

    // Open that pre-populated v1 database through AppDatabase — this is
    // what a real app upgrade does: same file, new code, drift detects
    // schemaVersion 1 -> 2 and runs onUpgrade.
    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Touch the database to force drift to run its migration.
    await db.select(db.categories).get();

    final migratedTransactions = await db.select(db.transactions).get();
    expect(migratedTransactions, hasLength(1));
    final tx = migratedTransactions.single;
    expect(tx.amount, 5000);
    expect(tx.smsMessageId, isNotNull, reason: 'v1 transaction must gain an evidence link');
    expect(tx.providerId, isNotNull, reason: 'v1 transaction must be attributed to a provider');

    final linkedSms = await (db.select(db.smsMessages)
          ..where((tbl) => tbl.id.equals(tx.smsMessageId!)))
        .getSingle();
    expect(linkedSms.body, tx.rawSmsBody, reason: 'backfilled sms_messages row must preserve the original body verbatim');
    expect(linkedSms.processingStatus, SmsProcessingStatus.matched);

    final migratedUnparsed = await db.select(db.unparsedMessages).get();
    expect(migratedUnparsed, hasLength(1));
    expect(migratedUnparsed.single.smsMessageId, isNotNull);

    final linkedUnparsedSms = await (db.select(db.smsMessages)
          ..where((tbl) => tbl.id.equals(migratedUnparsed.single.smsMessageId!)))
        .getSingle();
    expect(linkedUnparsedSms.sender, 'MTN', reason: 'unparsed messages already had a real sender — must be preserved exactly, not replaced with a placeholder');
    expect(linkedUnparsedSms.processingStatus, SmsProcessingStatus.unrecognized);

    // Providers must be seeded during the same upgrade, not just on
    // fresh onCreate.
    final providers = await db.select(db.financialProviders).get();
    expect(providers, isNotEmpty);
  });
}
