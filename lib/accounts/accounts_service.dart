import 'package:drift/drift.dart';

import '../data/database.dart';

/// An [Account] joined with its computed current balance and provider
/// display info — the read-model the account-list UI (spec Phase 7)
/// and dashboard wallet breakdown (spec Phase 8) both need.
class AccountSummary {
  const AccountSummary({
    required this.account,
    required this.providerDisplayName,
    required this.providerCode,
    required this.currentBalance,
  });

  final Account account;
  final String providerDisplayName;

  /// Stable provider identifier (e.g. 'mtn_momo_rw') — lets UI resolve
  /// the provider's logo asset without a second query.
  final String providerCode;

  /// Null when the account has no transactions with a recorded
  /// [Transactions.balanceAfter] yet (e.g. a brand-new account, or a
  /// provider like Equity whose real SMS never reports a running
  /// balance at all — see docs/SMS_PATTERN_LIBRARY.md).
  final double? currentBalance;
}

/// Read/query surface for [Accounts]. Deliberately has no
/// `setBalance`/`adjustBalance` method of any kind — per the schema
/// design (see [Accounts] doc comment), an account's balance is always
/// computed from transaction history, never stored or mutated
/// directly, so there is no method here that could let it drift out of
/// sync with the ledger.
class AccountsService {
  AccountsService(this._db);

  final AppDatabase _db;

  Future<List<AccountSummary>> allAccountSummaries() async {
    final accounts = await _db.select(_db.accounts).get();
    final summaries = <AccountSummary>[];
    for (final account in accounts) {
      final provider = await (_db.select(_db.financialProviders)
            ..where((tbl) => tbl.id.equals(account.providerId)))
          .getSingle();
      summaries.add(AccountSummary(
        account: account,
        providerDisplayName: provider.displayName,
        providerCode: provider.code,
        currentBalance: await currentBalance(account.id),
      ));
    }
    return summaries;
  }

  /// The most recent [Transactions.balanceAfter] for [accountId], by
  /// transaction timestamp (tiebroken by row id, so two transactions
  /// sharing an identical embedded SMS timestamp — confirmed real, e.g.
  /// a "received" and its paired "transferred to own account" message
  /// one second apart — resolve deterministically to whichever was
  /// actually inserted later) — this *is* the account's current
  /// balance, computed fresh every call rather than cached anywhere.
  /// Returns null if the account has no transactions with a recorded
  /// balance.
  ///
  /// A confirmed real bug lived here: if a provider's parser silently
  /// fails to extract a balance for its *current* message format (see
  /// MtnRwandaParser's balance-field fix), every recent transaction has
  /// a null balanceAfter, and this query — filtering to non-null
  /// balances only — quietly falls back to whatever much-older
  /// transaction last had one, showing a stale figure with no error of
  /// any kind. This method can't detect that on its own (a null
  /// balance for a genuinely balance-less provider like Equity is
  /// normal, not a bug) — the real fix is keeping every parser's
  /// balance regex current against real message formats, verified by
  /// fixtures sourced from an actual device export, not assumptions.
  Future<double?> currentBalance(int accountId) async {
    final query = _db.select(_db.transactions)
      ..where((tbl) => tbl.accountId.equals(accountId) & tbl.balanceAfter.isNotNull())
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.timestamp),
        (tbl) => OrderingTerm.desc(tbl.id),
      ])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row?.balanceAfter;
  }

  Future<Account?> defaultAccountForProvider(int providerId) {
    return (_db.select(_db.accounts)..where((tbl) => tbl.providerId.equals(providerId)))
        .getSingleOrNull();
  }

  Future<void> renameAccount(int accountId, String newLabel) async {
    await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(accountId)))
        .write(AccountsCompanion(label: Value(newLabel)));
  }

  /// Creates an [Accounts] row for [providerId] if one doesn't already
  /// exist — called by [ProviderSelectionService] the moment a user
  /// selects a provider (onboarding's Phase 6 screen, or later toggling
  /// one on in Settings). From schemaVersion 4 onward this is the only
  /// path that creates a new account for a provider that didn't already
  /// have one; there is no longer an unconditional "one account per
  /// every seeded provider" step.
  Future<Account> ensureAccountForProvider(int providerId) async {
    final existing = await defaultAccountForProvider(providerId);
    if (existing != null) return existing;

    final provider = await (_db.select(_db.financialProviders)
          ..where((tbl) => tbl.id.equals(providerId)))
        .getSingle();
    final id = await _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            providerId: providerId,
            label: 'My ${provider.displayName}',
          ),
        );
    return (_db.select(_db.accounts)..where((tbl) => tbl.id.equals(id))).getSingle();
  }
}
