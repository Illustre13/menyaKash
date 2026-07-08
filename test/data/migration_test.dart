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

  /// Verifies the v3 -> v4 grandfather path: a pre-Phase-5 install that
  /// already has real Accounts (from the old unconditional
  /// _seedDefaultAccounts) must land on Dashboard directly after the
  /// upgrade, not be forced through the new onboarding flow — see
  /// AppDatabase._grandfatherExistingUsers.
  test('an existing user with real accounts is grandfathered as already-onboarded on v3->v4',
      () async {
    final raw = sqlite3.sqlite3.openInMemory();

    // Minimal v3 schema: only what _grandfatherExistingUsers actually
    // reads (accounts + financial_providers) plus the tables drift's
    // own onUpgrade touches along the way. Real column set, not a v1
    // schema — this is deliberately testing the v3->v4 step in
    // isolation, same as the v1->v2 test above tests that step alone.
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
      CREATE TABLE financial_providers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        display_name TEXT NOT NULL,
        category TEXT NOT NULL
      );
      CREATE TABLE provider_senders (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        sender_pattern TEXT NOT NULL,
        provider_id INTEGER NOT NULL REFERENCES financial_providers(id)
      );
      CREATE TABLE sms_messages (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        sender TEXT NOT NULL,
        body TEXT NOT NULL,
        received_at INTEGER NOT NULL,
        sms_hash TEXT NOT NULL,
        provider_id INTEGER REFERENCES financial_providers(id),
        processing_status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL
      );
      CREATE TABLE accounts (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        provider_id INTEGER NOT NULL REFERENCES financial_providers(id),
        label TEXT NOT NULL
      );
      CREATE TABLE merchants (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        normalized_name TEXT NOT NULL,
        category_id INTEGER REFERENCES categories(id)
      );
      CREATE TABLE transfer_links (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        from_transaction_id INTEGER NOT NULL,
        to_transaction_id INTEGER NOT NULL,
        confidence TEXT NOT NULL,
        match_reason TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        sms_message_id INTEGER REFERENCES sms_messages(id),
        provider_id INTEGER REFERENCES financial_providers(id),
        account_id INTEGER REFERENCES accounts(id),
        merchant_id INTEGER REFERENCES merchants(id),
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
        sms_message_id INTEGER REFERENCES sms_messages(id),
        sender TEXT NOT NULL,
        body TEXT NOT NULL,
        received_at INTEGER NOT NULL,
        resolved INTEGER NOT NULL DEFAULT 0
      );

      PRAGMA user_version = 3;
    ''');

    raw.execute('''
      INSERT INTO financial_providers (id, code, display_name, category)
      VALUES (1, 'mtn_momo_rw', 'MTN Mobile Money', 'mobile_money');
    ''');
    raw.execute('''
      INSERT INTO accounts (id, provider_id, label)
      VALUES (1, 1, 'My MTN Mobile Money');
    ''');

    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Touch the database to force drift to run the v3 -> v4 migration.
    await db.select(db.categories).get();

    final profile = await db.select(db.userProfile).getSingleOrNull();
    expect(profile, isNotNull, reason: 'an existing user with real accounts must be grandfathered');
    expect(profile!.onboardingCompletedAt, isNotNull,
        reason: 'must never be forced back through onboarding retroactively');

    final sources = await db.select(db.userFinancialSources).get();
    expect(sources, hasLength(1));
    expect(sources.single.providerId, 1,
        reason: 'Connected Services must reflect the provider the existing account already used');
  });

  test('a fresh v4 install has zero accounts until a provider is explicitly selected', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.select(db.categories).get();

    final accounts = await db.select(db.accounts).get();
    expect(accounts, isEmpty,
        reason: 'schemaVersion 4 no longer auto-seeds an account for every provider on create');

    final profile = await db.select(db.userProfile).getSingleOrNull();
    expect(profile, isNull, reason: 'onCreate must not fabricate a profile for a genuinely new user');
  });
}
