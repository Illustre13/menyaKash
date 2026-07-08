import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Transaction type as inferred by a [MomoParser]. Kept as a plain enum
/// (not free text) so analytics queries can group reliably.
enum TransactionType {
  received,
  sent,
  payment, // merchant / till payment
  withdrawal, // agent cash-out
  deposit, // agent cash-in
  airtime,
  bankTransfer,
  reversed,
  unknown,
}

/// Whether an [SmsMessages] row has been run through the provider
/// detector + parser pipeline yet, and what happened when it was.
/// pending -> exactly one of [matched] / [unrecognized]. A message never
/// goes back to pending once processed — reprocessing (e.g. after a
/// parser fix) creates new outcomes rather than mutating history,
/// mirroring how [Transactions.rawSmsBody] already preserves evidence.
enum SmsProcessingStatus { pending, matched, unrecognized }

/// How confident [TransferMatchingEngine] is that two [Transactions]
/// rows are really one internal transfer between the user's own
/// accounts, not two independent transactions. `confirmed` means an
/// explicit cross-provider reference matched (e.g. Equity's `MTN Ref.`
/// against MTN's own transaction id — see docs/SMS_PATTERN_LIBRARY.md
/// "Cross-provider transfer-matching evidence"); `probable` means only
/// amount+time+provider-relationship matched, with no shared reference
/// number to confirm it.
enum TransferMatchConfidence { confirmed, probable }

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name}
      ];
}

/// Maps a merchant/till code or counterparty identifier to a category.
/// Populated entirely by the user the first time they categorize a new
/// code — there is no seed data, per product decision.
class CategoryCodes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The raw counterparty identifier as it appears in the SMS: a till
  /// number, a merchant code, or a phone number for P2P transfers.
  TextColumn get code => text().withLength(min: 1, max: 64)();

  /// User-editable friendly label for the Frequent Codes screen, e.g.
  /// "Kigali Supermarket" for a raw code like "SUPERMARKET LTD (Code:
  /// 55123)". Falls back to [code] itself when not set.
  TextColumn get displayName => text().nullable()();

  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.cascade)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {code}
      ];
}

/// A recognized financial institution/product that can send transaction
/// SMS — mobile money (MTN MoMo, Airtel Money, eKash) or a bank (Bank of
/// Kigali, Equity). This is the real provider abstraction the schema
/// lacked in v1, where `Transactions.provider` was a bare unvalidated
/// string. Seeded once via [AppDatabase._seedProviders] on first
/// creation/migration — see that method for the confirmed-real sender
/// patterns this seed data is based on (docs/AUDIT_PHASE_0.md §3.2).
class FinancialProviders extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Stable machine identifier, e.g. "mtn_momo_rw". Referenced by
  /// [Transactions.providerId] and by parser/detector code — never
  /// shown to the user directly.
  TextColumn get code => text().withLength(min: 1, max: 32)();

  /// Human-readable name for UI, e.g. "MTN Mobile Money".
  TextColumn get displayName => text().withLength(min: 1, max: 64)();

  /// "mobile_money" or "bank" — coarse grouping for the provider-picker
  /// UI (spec Phase 6) and for deciding which parser family applies.
  TextColumn get category => text().withLength(min: 1, max: 32)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {code}
      ];
}

/// A user-facing wallet/account, e.g. "My MTN MoMo" or "My BK Account".
/// Deliberately carries **no stored balance column** — an account's
/// current balance is always computed on demand from the most recent
/// [Transactions.balanceAfter] for that account (see
/// `AccountsService.currentBalance`), the same way this app already
/// reported balance pre-Phase-3. Storing a running balance here would
/// create a second source of truth that could silently drift from what
/// the transaction history actually shows if a transaction is ever
/// edited or deleted — for a financial ledger, the history must remain
/// the single source of truth.
///
/// One [FinancialProviders] row can back more than one account in
/// principle (e.g. two BK accounts), so this is deliberately a
/// separate table rather than reusing `FinancialProviders` directly —
/// today's seeding creates exactly one account per seeded provider
/// (see `AppDatabase._seedDefaultAccounts`), since no real multi-account
/// case has been observed yet, but the schema doesn't assume that stays
/// true.
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get providerId =>
      integer().references(FinancialProviders, #id, onDelete: KeyAction.cascade)();

  /// User-facing label, e.g. "My MTN MoMo". Defaults to the provider's
  /// own display name at creation time but is independently editable
  /// (spec Phase 7's account list implies users may rename accounts).
  TextColumn get label => text().withLength(min: 1, max: 64)();
}

/// A real-world merchant/payee, with its name kept separate from any
/// trailing account/till code — the Phase 4 fix for the confirmed real
/// bug where "THE FAMILYS BAKERY LTD 096957" (merchant name + numeric
/// code) was stored as one opaque, uncategorizable string (see
/// docs/AUDIT_PHASE_0.md §3.3).
///
/// This table is added *alongside* the existing [CategoryCodes] table,
/// not as its replacement yet — [CategoryCodes] still backs the
/// Categorize/Pay/Frequent-codes screens as-is. Wiring those screens to
/// query [Merchants] instead is a deliberately separate follow-up, so
/// this migration doesn't risk breaking working, already-shipped UI in
/// the same change that introduces the new plumbing.
class Merchants extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The merchant name as extracted from the SMS, with the trailing
  /// account/till code stripped — e.g. "THE FAMILYS BAKERY LTD" from
  /// "THE FAMILYS BAKERY LTD 096957". See
  /// `MerchantNormalizationService.extractMerchantName`.
  TextColumn get name => text().withLength(min: 1, max: 128)();

  /// Uppercased, punctuation-stripped, whitespace-collapsed form of
  /// [name] — the actual matching key, so "Family Bakery Ltd" and
  /// "FAMILY BAKERY LTD." (different real messages, same real business)
  /// resolve to the same merchant instead of creating two rows.
  TextColumn get normalizedName => text().withLength(min: 1, max: 128)();

  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {normalizedName}
      ];
}

/// Links two [Transactions] rows that are really one internal transfer
/// between the user's own accounts (e.g. a BK debit and an MTN MoMo
/// credit for the same real-world movement of money), so analytics can
/// exclude them from income/expense totals instead of double-counting
/// — the Phase 3 fix for the confirmed real problem in
/// docs/AUDIT_PHASE_0.md §3.2 (an Equity "sent" and an MTN "received"
/// message, 3 seconds apart, same amount, explicitly cross-referencing
/// each other, that v1/v2 would have recorded as unrelated
/// income+expense rather than one transfer).
///
/// `fromTransactionId`/`toTransactionId` are the debit and credit side
/// respectively — not "first found"/"second found" — so a query can
/// always tell which account lost the money and which gained it without
/// re-inspecting each transaction's type.
class TransferLinks extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get fromTransactionId =>
      integer().references(Transactions, #id, onDelete: KeyAction.cascade)();
  IntColumn get toTransactionId =>
      integer().references(Transactions, #id, onDelete: KeyAction.cascade)();

  TextColumn get confidence => textEnum<TransferMatchConfidence>()();

  /// Free-text note on *why* the engine matched these two, e.g. "matched
  /// via shared reference 541077019015" or "matched via amount+time
  /// proximity, no shared reference" — surfaced in a future "why is
  /// this a transfer?" UI affordance rather than being a silent,
  /// unexplainable link.
  TextColumn get matchReason => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {fromTransactionId, toTransactionId}
      ];
}

/// Sender-name patterns that identify a [FinancialProviders] row. A
/// provider can have multiple known senders (confirmed real example:
/// MTN's `M-Money` shortcode carries both MoMo P2P/merchant traffic and
/// eKash traffic — two providers, one sender — so this is a many-to-one
/// mapping of sender string -> provider, not the reverse).
class ProviderSenders extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get senderPattern => text().withLength(min: 1, max: 64)();

  IntColumn get providerId =>
      integer().references(FinancialProviders, #id, onDelete: KeyAction.cascade)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {senderPattern, providerId}
      ];
}

/// Raw SMS evidence, stored immediately on arrival before any parsing
/// happens — the "never directly process SMS into expenses" fix. Every
/// SMS from a recognized-provider sender lands here first with
/// [SmsProcessingStatus.pending]; a separate processing step reads
/// pending rows, resolves a provider via the detector, attempts to
/// parse, and writes exactly one [Transactions] or [UnparsedMessages]
/// row before flipping this row to matched/unrecognized. This table is
/// permanent evidence and is never deleted or overwritten by
/// reprocessing — see [SmsProcessingStatus] doc.
class SmsMessages extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get sender => text()();
  TextColumn get body => text()();
  DateTimeColumn get receivedAt => dateTime()();

  /// SHA-256 of `sender|body|receivedAt.millisecondsSinceEpoch`, computed
  /// at insert time (see [AppDatabase.hashSmsMessage]). This is the
  /// dedup key: re-running a historical scan (a known v1 gap — see
  /// docs/AUDIT_PHASE_0.md §3.5) hits the unique constraint below and is
  /// silently skipped instead of double-inserting.
  TextColumn get smsHash => text().withLength(min: 64, max: 64)();

  /// Nullable: set once a provider is identified for this message.
  /// Null means either not yet processed, or processed but no known
  /// provider matched the sender at all (a step before "parsed the
  /// body" — see ProviderDetector).
  IntColumn get providerId =>
      integer().nullable().references(FinancialProviders, #id)();

  TextColumn get processingStatus => textEnum<SmsProcessingStatus>()
      .withDefault(Constant(SmsProcessingStatus.pending.name))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {smsHash}
      ];
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Links back to the exact SMS this transaction was extracted from —
  /// the "financial ledger built from evidence" link the v1 schema
  /// lacked (v1 only kept a copy of the body on the transaction row
  /// itself, with no way to distinguish "reprocessed the same message"
  /// from "a genuinely new message"). Nullable only for rows migrated
  /// from v1 history where no matching sms_messages row could be
  /// reconstructed with full confidence (see migration `onUpgrade`).
  IntColumn get smsMessageId =>
      integer().nullable().references(SmsMessages, #id)();

  /// Real FK now — was a bare unvalidated string in v1. See
  /// [FinancialProviders].
  IntColumn get providerId =>
      integer().nullable().references(FinancialProviders, #id)();

  /// Which of the user's own [Accounts] this transaction moved money
  /// into or out of. Nullable for the same reason [smsMessageId] is:
  /// v1/v2 history predates accounts existing at all, and v2->v3
  /// migrated rows are attributed to the default account for their
  /// provider (see `AppDatabase._backfillAccountsFromV2`) rather than
  /// left permanently unset.
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();

  /// Which real-world [Merchants] row this transaction's counterparty
  /// resolves to, once merchant-name normalization has run on it (Phase
  /// 4). Nullable and independent of [categoryId]/[counterparty] — this
  /// is new plumbing that doesn't yet drive any UI; existing
  /// categorization continues to work off [counterparty] +
  /// `CategoryCodes` exactly as before.
  IntColumn get merchantId => integer().nullable().references(Merchants, #id)();

  TextColumn get type => textEnum<TransactionType>()();

  RealColumn get amount => real()();
  RealColumn get fee => real().withDefault(const Constant(0))();

  /// Raw counterparty identifier (phone number, till code, agent code,
  /// or free-text name) exactly as extracted from the SMS body.
  TextColumn get counterparty => text().nullable()();

  TextColumn get txRef => text().nullable()();
  RealColumn get balanceAfter => real().nullable()();

  DateTimeColumn get timestamp => dateTime()();

  /// Full original SMS body, kept for re-parsing if a regex is fixed later
  /// and for the "Review unparsed" screen's context. Now also duplicated
  /// in [SmsMessages.body] via [smsMessageId] — kept here too rather than
  /// dropped, since removing a NOT NULL column that many existing v1 rows
  /// depend on is a bigger migration risk than a few KB of duplication.
  TextColumn get rawSmsBody => text()();

  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
}

/// The single local user identity created during onboarding (spec Phase
/// 5). Exactly one row is expected to exist in practice — this is a
/// single-user, single-device offline app, not a multi-profile one —
/// but modeled as a table rather than a key-value blob so it composes
/// with drift's existing query/watch machinery like every other table
/// here.
///
/// No password/credential column of any kind: [appLockEnabled] gates
/// access via the OS's own biometric/PIN/pattern prompt (`local_auth`),
/// never a secret this app stores or checks itself.
class UserProfile extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get displayName => text().withLength(min: 1, max: 80).nullable()();

  /// Format-validated and confirmed via a code generated and displayed
  /// on this device's own screen — never actually delivered anywhere.
  /// This app declares no INTERNET permission and has no network-
  /// capable dependency, so there is no real OTP-delivery path; the
  /// confirmation step only catches typos/misreads, it does not prove
  /// mailbox ownership. See docs/ARCHITECTURE.md's onboarding section.
  TextColumn get email => text().nullable()();

  /// Format-validated only, not yet verified by any means — phone
  /// verification is explicitly deferred past this phase.
  TextColumn get phone => text().nullable()();

  /// Local file path under app storage, never a remote URL.
  TextColumn get avatarPath => text().nullable()();

  BoolColumn get appLockEnabled => boolean().withDefault(const Constant(false))();

  /// Set once the onboarding flow (Welcome through Provider Setup) has
  /// been completed at least once. This is the source of truth
  /// `HomeShell` checks to decide whether to show onboarding — replacing
  /// the pre-Phase-5 proxy of "is SMS permission currently granted,"
  /// which conflated permission state with identity/setup completion.
  DateTimeColumn get onboardingCompletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A [FinancialProviders] row the user has explicitly selected on the
/// provider-setup screen (spec Phase 6) or later in Settings — distinct
/// from [FinancialProviders] itself (the static sender-detection
/// registry, never user-editable) and from [Accounts] (from
/// schemaVersion 4 onward, created only for providers selected here,
/// not auto-seeded for every registry row — see
/// `AccountsService.ensureAccountForProvider`).
///
/// Deselecting a provider later removes its row here but deliberately
/// does not cascade-delete any [Accounts]/[Transactions] — a user's
/// transaction history must survive them turning a provider card off.
class UserFinancialSources extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get providerId =>
      integer().references(FinancialProviders, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get selectedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {providerId}
      ];
}

/// Messages from a known-provider sender that no registered parser could
/// match. Surfaced in the "Review" screen so the parser can be extended
/// instead of silently dropping data. Retained as-is post-migration for
/// the existing Review screen; new unrecognized messages are written
/// here *and* have their [SmsMessages] row flipped to `unrecognized` —
/// this table is now a projection of "which sms_messages rows need
/// human attention," not the primary record.
class UnparsedMessages extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Links to the evidence row. Nullable for the same v1-migration
  /// reason as [Transactions.smsMessageId].
  IntColumn get smsMessageId =>
      integer().nullable().references(SmsMessages, #id)();

  TextColumn get sender => text()();
  TextColumn get body => text()();
  DateTimeColumn get receivedAt => dateTime()();
  BoolColumn get resolved => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [
  Categories,
  CategoryCodes,
  Transactions,
  UnparsedMessages,
  FinancialProviders,
  ProviderSenders,
  SmsMessages,
  Accounts,
  Merchants,
  TransferLinks,
  UserProfile,
  UserFinancialSources,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedProviders();
          // Deliberately no _seedDefaultAccounts() call here: from
          // schemaVersion 4, a fresh install creates zero Accounts rows
          // until the user picks providers on the Phase 6 setup screen
          // (see UserFinancialSources doc) — _seedDefaultAccounts is
          // kept only for the pre-v4 migration/grandfather path below.
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(financialProviders);
            await m.createTable(providerSenders);
            await m.createTable(smsMessages);
            await m.addColumn(transactions, transactions.smsMessageId);
            await m.addColumn(transactions, transactions.providerId);
            await m.addColumn(unparsedMessages, unparsedMessages.smsMessageId);
            await _seedProviders();
            await _backfillSmsMessagesFromV1();
          }
          if (from < 3) {
            await m.createTable(accounts);
            await m.createTable(merchants);
            await m.createTable(transferLinks);
            await m.addColumn(transactions, transactions.accountId);
            await m.addColumn(transactions, transactions.merchantId);
            await _seedDefaultAccounts();
            await _backfillAccountsFromV2();
          }
          if (from < 4) {
            await m.createTable(userProfile);
            await m.createTable(userFinancialSources);
            await _grandfatherExistingUsers();
          }
        },
      );

  /// Confirmed-real sender patterns from a genuine 8,364-message SMS
  /// export (docs/AUDIT_PHASE_0.md §3.2) — every sender string here was
  /// directly observed in real device data, not guessed. `M-Money`
  /// intentionally maps to two providers (mtn_momo_rw and ekash_rw)
  /// since both products share that shortcode in practice; the
  /// ProviderDetector (lib/providers/) resolves the ambiguity by
  /// matching message-body shape, not sender alone.
  Future<void> _seedProviders() async {
    final seed = <(String code, String displayName, String category, List<String> senders)>[
      ('mtn_momo_rw', 'MTN Mobile Money', 'mobile_money', ['M-Money', 'MTN', 'MoMo', 'MTNRWANDA']),
      ('ekash_rw', 'eKash', 'mobile_money', ['M-Money', 'Ekash', 'eKash']),
      ('airtel_money_rw', 'Airtel Money', 'mobile_money', ['AirtelMoney', 'AIRTELMONEY']),
      ('bk_bank_rw', 'Bank of Kigali', 'bank', ['BKeBANK', 'BK BANK', 'BK ARENA']),
      ('equity_bank_rw', 'Equity Bank', 'bank', ['EQUITYBANK']),
    ];

    for (final (code, displayName, category, senders) in seed) {
      final providerId = await into(financialProviders).insertOnConflictUpdate(
        FinancialProvidersCompanion.insert(
          code: code,
          displayName: displayName,
          category: category,
        ),
      );
      for (final sender in senders) {
        await into(providerSenders).insertOnConflictUpdate(
          ProviderSendersCompanion.insert(senderPattern: sender, providerId: providerId),
        );
      }
    }
  }

  /// Reconstructs [SmsMessages] rows for pre-v2 history so existing
  /// transactions/unparsed messages gain evidence links without losing
  /// any data. Best-effort: v1 never stored a sender on [Transactions],
  /// so backfilled rows use the transaction's resolved provider's first
  /// known sender as a placeholder sender string — this is documented
  /// as an approximation, not a claim of the original literal sender.
  Future<void> _backfillSmsMessagesFromV1() async {
    final mtnProvider = await (select(financialProviders)
          ..where((tbl) => tbl.code.equals('mtn_momo_rw')))
        .getSingleOrNull();
    final placeholderSender = mtnProvider == null
        ? 'unknown'
        : (await (select(providerSenders)
                  ..where((tbl) => tbl.providerId.equals(mtnProvider.id))
                  ..limit(1))
                .getSingleOrNull())
                ?.senderPattern ??
            'unknown';

    final existingTransactions = await select(transactions).get();
    for (final tx in existingTransactions) {
      final hash = hashSmsMessage(
        sender: placeholderSender,
        body: tx.rawSmsBody,
        receivedAt: tx.timestamp,
      );
      final smsId = await into(smsMessages).insertOnConflictUpdate(
        SmsMessagesCompanion.insert(
          sender: placeholderSender,
          body: tx.rawSmsBody,
          receivedAt: tx.timestamp,
          smsHash: hash,
          providerId: Value(mtnProvider?.id),
          processingStatus: const Value(SmsProcessingStatus.matched),
        ),
      );
      await (update(transactions)..where((tbl) => tbl.id.equals(tx.id)))
          .write(TransactionsCompanion(
        smsMessageId: Value(smsId),
        providerId: Value(mtnProvider?.id),
      ));
    }

    final existingUnparsed = await select(unparsedMessages).get();
    for (final msg in existingUnparsed) {
      final hash = hashSmsMessage(
        sender: msg.sender,
        body: msg.body,
        receivedAt: msg.receivedAt,
      );
      final smsId = await into(smsMessages).insertOnConflictUpdate(
        SmsMessagesCompanion.insert(
          sender: msg.sender,
          body: msg.body,
          receivedAt: msg.receivedAt,
          smsHash: hash,
          processingStatus: const Value(SmsProcessingStatus.unrecognized),
        ),
      );
      await (update(unparsedMessages)..where((tbl) => tbl.id.equals(msg.id)))
          .write(UnparsedMessagesCompanion(smsMessageId: Value(smsId)));
    }
  }

  /// One default [Accounts] row per seeded [FinancialProviders] row,
  /// e.g. "My MTN Mobile Money" for `mtn_momo_rw`. Real multi-account
  /// support (spec Phase 7's account list, multiple BK accounts, etc.)
  /// can add more rows against the same provider later — this seed is
  /// deliberately the minimum needed for every existing transaction to
  /// have *an* account to attribute to, not a claim that one-account-
  /// per-provider is a permanent constraint.
  Future<void> _seedDefaultAccounts() async {
    final providers = await select(financialProviders).get();
    for (final provider in providers) {
      final existing = await (select(accounts)
            ..where((tbl) => tbl.providerId.equals(provider.id)))
          .getSingleOrNull();
      if (existing != null) continue;
      await into(accounts).insert(
        AccountsCompanion.insert(
          providerId: provider.id,
          label: 'My ${provider.displayName}',
        ),
      );
    }
  }

  /// Attributes every pre-v3 transaction to its provider's default
  /// account, using [Transactions.providerId] (already backfilled by
  /// [_backfillSmsMessagesFromV1] for v1 rows, and populated directly
  /// for v2 rows) to look up the matching [Accounts] row. Transactions
  /// with no resolved provider at all (should be rare — only messages
  /// that matched no provider during v1/v2 ingestion) are left with a
  /// null accountId rather than guessed at.
  Future<void> _backfillAccountsFromV2() async {
    final txWithoutAccount =
        await (select(transactions)..where((tbl) => tbl.accountId.isNull())).get();

    for (final tx in txWithoutAccount) {
      if (tx.providerId == null) continue;
      final account = await (select(accounts)
            ..where((tbl) => tbl.providerId.equals(tx.providerId!))
            ..limit(1))
          .getSingleOrNull();
      if (account == null) continue;
      await (update(transactions)..where((tbl) => tbl.id.equals(tx.id)))
          .write(TransactionsCompanion(accountId: Value(account.id)));
    }
  }

  /// Existing users who completed the pre-Phase-5 SMS-only onboarding
  /// already have real transaction history and [Accounts] rows seeded
  /// for every provider by the old unconditional [_seedDefaultAccounts].
  /// Forcing them back through the new identity/provider-setup flow on
  /// their next launch would prompt for information their history
  /// already implies and would read as hostile/data-destructive for no
  /// real gain. Instead: if any [Accounts] rows already exist, mark
  /// onboarding as already complete and backfill [UserFinancialSources]
  /// from whatever providers those accounts already reference, so
  /// Settings' "Connected Services" reflects real existing usage rather
  /// than showing everything unselected. A genuinely fresh v4 install
  /// has no accounts yet and falls through to the real onboarding flow.
  Future<void> _grandfatherExistingUsers() async {
    final existingAccounts = await select(accounts).get();
    if (existingAccounts.isEmpty) return;

    await into(userProfile).insert(
      UserProfileCompanion.insert(
        onboardingCompletedAt: Value(DateTime.now()),
      ),
    );

    final seenProviderIds = <int>{};
    for (final account in existingAccounts) {
      if (!seenProviderIds.add(account.providerId)) continue;
      await into(userFinancialSources).insertOnConflictUpdate(
        UserFinancialSourcesCompanion.insert(providerId: account.providerId),
      );
    }
  }

  Future<Category?> findCategoryByCode(String code) async {
    final mapping = await (select(categoryCodes)
          ..where((tbl) => tbl.code.equals(code)))
        .getSingleOrNull();
    if (mapping == null) return null;
    return (select(categories)..where((tbl) => tbl.id.equals(mapping.categoryId)))
        .getSingle();
  }

  Future<int> assignCodeToCategory(String code, int categoryId) {
    return into(categoryCodes).insertOnConflictUpdate(
      CategoryCodesCompanion.insert(code: code, categoryId: categoryId),
    );
  }

  Future<void> renameCodeDisplayName(String code, String displayName) async {
    final existing =
        await (select(categoryCodes)..where((tbl) => tbl.code.equals(code))).getSingleOrNull();
    if (existing == null) return;
    await (update(categoryCodes)..where((tbl) => tbl.code.equals(code)))
        .write(CategoryCodesCompanion(displayName: Value(displayName)));
  }

  /// Every distinct counterparty seen in transaction history, ranked by
  /// how often it's been paid — this *is* the "most used MoMo code"
  /// signal, computed straight from transaction history rather than a
  /// separately maintained counter that could drift out of sync.
  Future<List<CodeUsage>> mostUsedCounterparties({int? limit}) async {
    final counterparty = transactions.counterparty;
    final countExp = counterparty.count();
    final lastUsedExp = transactions.timestamp.max();

    final query = selectOnly(transactions)
      ..addColumns([counterparty, countExp, lastUsedExp])
      ..where(counterparty.isNotNull())
      ..groupBy([counterparty])
      ..orderBy([OrderingTerm.desc(countExp)]);
    if (limit != null) query.limit(limit);

    final rows = await query.get();
    final result = <CodeUsage>[];
    for (final row in rows) {
      final code = row.read(counterparty);
      if (code == null) continue;
      final mapping = await (select(categoryCodes)..where((tbl) => tbl.code.equals(code)))
          .getSingleOrNull();
      Category? category;
      if (mapping != null) {
        category =
            await (select(categories)..where((tbl) => tbl.id.equals(mapping.categoryId)))
                .getSingleOrNull();
      }
      result.add(CodeUsage(
        code: code,
        displayName: mapping?.displayName,
        usageCount: row.read(countExp) ?? 0,
        lastUsedAt: row.read(lastUsedExp),
        category: category,
      ));
    }
    return result;
  }
}

/// Deterministic dedup key for an [SmsMessages] row. Same inputs always
/// produce the same hash, so re-scanning the same inbox range is a
/// no-op against the table's unique constraint on [SmsMessages.smsHash]
/// rather than a double-insert (the v1 gap documented in
/// docs/AUDIT_PHASE_0.md §3.5).
String hashSmsMessage({
  required String sender,
  required String body,
  required DateTime receivedAt,
}) {
  final input = '$sender|$body|${receivedAt.millisecondsSinceEpoch}';
  return sha256.convert(utf8.encode(input)).toString();
}

/// Read-model for the Frequent Codes screen: a counterparty joined with
/// its usage stats (from transaction history) and its current category
/// mapping, if any.
class CodeUsage {
  const CodeUsage({
    required this.code,
    required this.displayName,
    required this.usageCount,
    required this.lastUsedAt,
    required this.category,
  });

  final String code;
  final String? displayName;
  final int usageCount;
  final DateTime? lastUsedAt;
  final Category? category;

  String get label => displayName ?? code;
}

/// Purely local storage, never uploaded — this is the entire persistence
/// layer for the app. `driftDatabase` picks the right backend per
/// platform: a native sqlite3 file on Android/desktop, and a
/// WASM/IndexedDB-backed database in the browser on web. Web is a
/// dev/testing target only (used by `main_web.dart`) — this app's real
/// features (SMS reading, USSD dialing) are Android-only regardless of
/// storage backend.
///
/// The web backend needs two prebuilt assets in `web/`:
///   - `sqlite3.wasm` — downloaded from a sqlite3.dart GitHub release
///     matching the installed `sqlite3` package version, e.g.
///     https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-<version>/sqlite3.wasm
///   - `drift_worker.js` — compiled from drift's worker source via:
///     `dart compile js tool/drift_worker.dart -o web/drift_worker.js -O2`
///     (tool/drift_worker.dart just calls `WasmDatabase.workerMainForOpen()`
///     from `package:drift/wasm.dart`; re-run this after bumping the
///     `drift` package version).
QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'i_momo',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
