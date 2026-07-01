import 'package:drift/drift.dart';

import '../data/database.dart';

/// An [Account] joined with its computed current balance and provider
/// display info — the read-model the account-list UI (spec Phase 7)
/// and dashboard wallet breakdown (spec Phase 8) both need.
class AccountSummary {
  const AccountSummary({
    required this.account,
    required this.providerDisplayName,
    required this.currentBalance,
  });

  final Account account;
  final String providerDisplayName;

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
        currentBalance: await currentBalance(account.id),
      ));
    }
    return summaries;
  }

  /// The most recent [Transactions.balanceAfter] for [accountId], by
  /// transaction timestamp — this *is* the account's current balance,
  /// computed fresh every call rather than cached anywhere. Returns
  /// null if the account has no transactions with a recorded balance.
  Future<double?> currentBalance(int accountId) async {
    final query = _db.select(_db.transactions)
      ..where((tbl) => tbl.accountId.equals(accountId) & tbl.balanceAfter.isNotNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)])
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
}
