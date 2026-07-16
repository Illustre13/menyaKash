import 'package:drift/drift.dart';

import '../accounts/accounts_service.dart';
import '../data/database.dart';
import '../merchants/merchant_normalization_service.dart';
import '../parsers/momo_parser_registry.dart';
import '../providers/provider_detection.dart';
import 'isolate_parsing.dart';

/// The second half of the ingestion pipeline: reads [SmsMessages] rows
/// still in [SmsProcessingStatus.pending] and turns each into exactly
/// one [Transactions] or [UnparsedMessages] row, per the "SMS -> Raw
/// Event -> Provider Parser -> Normalized Transaction" architecture
/// (see docs/AUDIT_PHASE_0.md §1 and the Phase 1 spec). This is
/// deliberately a separate class from [SmsIngestService] — that service
/// only ever captures and stores raw evidence; this one is the only
/// code path that reads that evidence and produces financial data from
/// it. Splitting these means a parser bug fix can be re-run over all
/// history (reprocess pending/previously-unrecognized rows) without
/// touching the capture path at all.
///
/// Since Phase 3/4, every written [Transactions] row is also attributed
/// to an [Accounts] row (via [AccountsService]) and, when a counterparty
/// was extracted, resolved against [Merchants] (via
/// [MerchantNormalizationService]) — both in addition to, not instead
/// of, the existing [CategoryCodes]-based categorization. Transfer
/// matching (Phase 3.1) is NOT run automatically per-message here — it
/// needs both sides of a transfer to exist first, so callers run
/// [TransferMatchingEngine] as an explicit batch step after ingestion
/// (see `HomeShell`/`OnboardingScreen` wiring in main.dart).
class SmsProcessor {
  SmsProcessor(
    this._db,
    this._registry,
    this._detector, {
    AccountsService? accountsService,
    MerchantNormalizationService? merchantService,
  })  : _accounts = accountsService ?? AccountsService(_db),
        _merchants = merchantService ?? MerchantNormalizationService(_db);

  final AppDatabase _db;
  final MomoParserRegistry _registry;
  final ProviderDetector _detector;
  final AccountsService _accounts;
  final MerchantNormalizationService _merchants;

  /// Cached "Fees & Charges" category id (spec #3) — resolved once,
  /// not once per fee row, since every fee-charge transaction this
  /// processor writes uses the same category.
  int? _feeCategoryId;

  /// The default taxonomy (see [defaultCategorySeed]) always seeds
  /// "Fees & Charges" on every install, but this looks it up by name
  /// rather than assuming a fixed id — a user could rename it, and a
  /// lookup-miss (e.g. a test database that never seeded categories at
  /// all) degrades to `null`, which writes a real, uncategorized fee
  /// transaction rather than throwing.
  Future<int?> _resolveFeeCategoryId() async {
    if (_feeCategoryId != null) return _feeCategoryId;
    final category = await (_db.select(_db.categories)
          ..where((tbl) => tbl.name.equals('Fees & Charges')))
        .getSingleOrNull();
    _feeCategoryId = category?.id;
    return _feeCategoryId;
  }

  /// Processes every currently-pending [SmsMessages] row. Returns how
  /// many were matched into a transaction vs. left unrecognized.
  Future<({int matched, int unrecognized})> processPending() async {
    final pending = await (_db.select(_db.smsMessages)
          ..where((tbl) => tbl.processingStatus.equalsValue(SmsProcessingStatus.pending)))
        .get();

    var matched = 0;
    var unrecognized = 0;
    for (final message in pending) {
      final wasMatched = await _processOne(message);
      if (wasMatched) {
        matched++;
      } else {
        unrecognized++;
      }
    }
    return (matched: matched, unrecognized: unrecognized);
  }

  /// Same as [processPending] but for a single freshly-inserted row —
  /// used by the live SMS listener, where processing one message as it
  /// arrives is cheaper and more responsive than a batch pass.
  Future<bool> processOneById(int smsMessageId) async {
    final message = await (_db.select(_db.smsMessages)
          ..where((tbl) => tbl.id.equals(smsMessageId)))
        .getSingle();
    return _processOne(message);
  }

  /// Writes a whole chunk of already-detected/already-parsed results
  /// (from [parseChunk], run on a background isolate — spec Phase 10)
  /// as one drift transaction instead of the ~6-8 independent awaited
  /// round-trips per message the old per-message path used. This is
  /// the DB-write half of the historical scan's performance fix: the
  /// CPU-bound detection/parsing work already happened off the main
  /// isolate, so this method's only job is turning those plain-data
  /// results into real rows with as few round-trips as possible.
  ///
  /// Every [SmsMessages] row is still inserted individually (not via
  /// `batch()`) because [Transactions.smsMessageId]/
  /// [UnparsedMessages.smsMessageId] need its real generated id to link
  /// back to — drift's `batch()` API doesn't return per-row ids
  /// synchronously, so batching that insert would silently drop the
  /// evidence link the rest of this app depends on. The transactions/
  /// unparsed-messages writes that follow, which don't need each
  /// other's ids, ARE batched — that's where the real round-trip
  /// savings come from, since those are the two writes that happen
  /// once per message.
  ///
  /// Account and merchant resolution are cached per call (not just per
  /// row) — after the first message for a given provider or
  /// counterparty, subsequent lookups in the same chunk are free
  /// in-memory hits instead of repeat queries. Returns how many results
  /// matched vs. were left unrecognized, mirroring [processPending].
  Future<({int matched, int unrecognized})> processBatch(List<ParsedSmsResult> results) async {
    var matched = 0;
    var unrecognized = 0;
    final accountCache = <int, Account>{};
    final feeCategoryId = await _resolveFeeCategoryId();

    final smsIds = <int>[];
    for (final result in results) {
      final sms = result.sms;
      final smsId = await _db.into(_db.smsMessages).insertOnConflictUpdate(
            SmsMessagesCompanion.insert(
              sender: sms.sender,
              body: sms.body,
              receivedAt: sms.receivedAt,
              smsHash: result.smsHash,
              providerId: Value(result.providerId),
              processingStatus: Value(
                result.wasParsed ? SmsProcessingStatus.matched : SmsProcessingStatus.unrecognized,
              ),
            ),
          );
      smsIds.add(smsId);
    }

    // smsMessageId of every matched transaction this call wrote that
    // has a real fee — batch.insert() doesn't return generated ids
    // synchronously, so the fee-charge rows (spec #3) for these are
    // created in a second pass below, looked back up by their unique
    // smsMessageId rather than threaded through the batch.
    final feeBearingSmsIds = <int>[];

    await _db.batch((batch) async {
      for (var i = 0; i < results.length; i++) {
        final result = results[i];
        final smsId = smsIds[i];
        final sms = result.sms;

        if (!result.wasParsed) {
          unrecognized++;
          batch.insert(
            _db.unparsedMessages,
            UnparsedMessagesCompanion.insert(
              smsMessageId: Value(smsId),
              sender: sms.sender,
              body: sms.body,
              receivedAt: sms.receivedAt,
            ),
          );
          continue;
        }

        matched++;
        final parsed = result.parsed!;
        final providerId = result.providerId!;

        var account = accountCache[providerId];
        if (account == null) {
          account = await _accounts.ensureAccountForProvider(providerId);
          accountCache[providerId] = account;
        }
        final merchant = await _merchants.resolveMerchant(parsed.counterparty);

        int? categoryId;
        if (parsed.counterparty != null) {
          final category = await _db.findCategoryByCode(parsed.counterparty!);
          categoryId = category?.id;
        }

        batch.insert(
          _db.transactions,
          TransactionsCompanion.insert(
            smsMessageId: Value(smsId),
            providerId: Value(providerId),
            accountId: Value(account.id),
            merchantId: Value(merchant?.id),
            type: parsed.type,
            amount: parsed.amount,
            fee: Value(parsed.fee),
            counterparty: Value(parsed.counterparty),
            txRef: Value(parsed.txRef),
            balanceAfter: Value(parsed.balanceAfter),
            timestamp: parsed.timestamp,
            rawSmsBody: sms.body,
            categoryId: Value(categoryId),
          ),
        );

        if (parsed.fee > 0) feeBearingSmsIds.add(smsId);
      }
    });

    if (feeBearingSmsIds.isNotEmpty) {
      await _db.batch((batch) async {
        for (final smsId in feeBearingSmsIds) {
          final parent = await (_db.select(_db.transactions)
                ..where((tbl) => tbl.smsMessageId.equals(smsId)))
              .getSingle();
          batch.insert(
            _db.transactions,
            TransactionsCompanion.insert(
              providerId: Value(parent.providerId),
              accountId: Value(parent.accountId),
              parentTransactionId: Value(parent.id),
              type: TransactionType.fee,
              amount: parent.fee,
              counterparty: Value(
                parent.counterparty != null ? 'Fee for ${parent.counterparty}' : 'Transaction fee',
              ),
              timestamp: parent.timestamp,
              rawSmsBody: parent.rawSmsBody,
              categoryId: Value(feeCategoryId),
            ),
          );
        }
      });
    }

    return (matched: matched, unrecognized: unrecognized);
  }

  Future<bool> _processOne(SmsMessage message) async {
    final detection = await _detector.detect(sender: message.sender, body: message.body);

    if (detection == null) {
      // Sender matched no known provider at all — shouldn't normally
      // happen, since SmsIngestService only stores messages from
      // recognized senders, but fail safe rather than throw.
      await _markUnrecognized(message, providerId: null);
      return false;
    }

    final outcome = _registry.processForProvider(
      providerCode: detection.provider.code,
      body: message.body,
      receivedAt: message.receivedAt,
    );

    if (!outcome.wasParsed) {
      await _markUnrecognized(message, providerId: detection.provider.id);
      return false;
    }

    final parsed = outcome.transaction!;
    int? categoryId;
    if (parsed.counterparty != null) {
      final category = await _db.findCategoryByCode(parsed.counterparty!);
      categoryId = category?.id;
    }

    // ensureAccountForProvider, not defaultAccountForProvider: from
    // schemaVersion 4, Accounts are only created for providers the user
    // has explicitly selected (spec Phase 6), so a provider the user
    // hasn't gotten to yet in the setup screen would otherwise have no
    // account at all and every one of its real transactions would be
    // written with a null accountId. A message that reaches this point
    // already matched a real parser for a real provider — that's
    // sufficient evidence the user actually uses it, so an account is
    // created on demand rather than the transaction being orphaned.
    final account = await _accounts.ensureAccountForProvider(detection.provider.id);
    final merchant = await _merchants.resolveMerchant(parsed.counterparty);

    final parentId = await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            smsMessageId: Value(message.id),
            providerId: Value(detection.provider.id),
            accountId: Value(account.id),
            merchantId: Value(merchant?.id),
            type: parsed.type,
            amount: parsed.amount,
            fee: Value(parsed.fee),
            counterparty: Value(parsed.counterparty),
            txRef: Value(parsed.txRef),
            balanceAfter: Value(parsed.balanceAfter),
            timestamp: parsed.timestamp,
            rawSmsBody: message.body,
            categoryId: Value(categoryId),
          ),
        );

    if (parsed.fee > 0) {
      await _insertFeeTransaction(
        parentId: parentId,
        fee: parsed.fee,
        accountId: account.id,
        providerId: detection.provider.id,
        counterparty: parsed.counterparty,
        timestamp: parsed.timestamp,
        rawSmsBody: message.body,
      );
    }

    await (_db.update(_db.smsMessages)..where((tbl) => tbl.id.equals(message.id))).write(
      SmsMessagesCompanion(
        providerId: Value(detection.provider.id),
        processingStatus: const Value(SmsProcessingStatus.matched),
      ),
    );
    return true;
  }

  /// Writes the fee-charge row for [parentId] (spec #3) — a real,
  /// first-class [Transactions] row of type [TransactionType.fee],
  /// categorized to "Fees & Charges," linked via
  /// [Transactions.parentTransactionId]. Timestamped identically to the
  /// parent (the SMS reports one moment for both the payment and its
  /// fee) and attributed to the same account, since the fee was
  /// deducted from that same wallet.
  Future<int> _insertFeeTransaction({
    required int parentId,
    required double fee,
    required int accountId,
    required int providerId,
    required String? counterparty,
    required DateTime timestamp,
    required String rawSmsBody,
  }) async {
    final feeCategoryId = await _resolveFeeCategoryId();
    return _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            providerId: Value(providerId),
            accountId: Value(accountId),
            parentTransactionId: Value(parentId),
            type: TransactionType.fee,
            amount: fee,
            counterparty: Value(counterparty != null ? 'Fee for $counterparty' : 'Transaction fee'),
            timestamp: timestamp,
            rawSmsBody: rawSmsBody,
            categoryId: Value(feeCategoryId),
          ),
        );
  }

  Future<void> _markUnrecognized(SmsMessage message, {int? providerId}) async {
    await _db.into(_db.unparsedMessages).insert(
          UnparsedMessagesCompanion.insert(
            smsMessageId: Value(message.id),
            sender: message.sender,
            body: message.body,
            receivedAt: message.receivedAt,
          ),
        );
    await (_db.update(_db.smsMessages)..where((tbl) => tbl.id.equals(message.id))).write(
      SmsMessagesCompanion(
        providerId: Value(providerId),
        processingStatus: const Value(SmsProcessingStatus.unrecognized),
      ),
    );
  }
}
