import 'package:drift/drift.dart';

import '../accounts/accounts_service.dart';
import '../data/database.dart';

/// A [FinancialProviders] row joined with whether the user has selected
/// it — the read-model both the Phase 6 onboarding screen and Settings'
/// "Connected Services" list need to render every known provider with
/// its current selection state.
class ProviderSelectionOption {
  const ProviderSelectionOption({
    required this.provider,
    required this.isSelected,
  });

  final FinancialProvider provider;
  final bool isSelected;
}

/// Read/write surface for [UserFinancialSources] — which providers the
/// user has explicitly chosen to track (spec Phase 6 provider setup,
/// Phase 7 Settings). Selecting a provider immediately ensures a
/// matching [Accounts] row exists via [AccountsService]; deselecting
/// only removes the selection row, never the account or its
/// transaction history.
class ProviderSelectionService {
  ProviderSelectionService(this._db, this._accountsService);

  final AppDatabase _db;
  final AccountsService _accountsService;

  /// Every known provider, each flagged with whether the user has
  /// selected it — ordered by [FinancialProviders.category] then name
  /// so callers can group into "Mobile Money" / "Banks" sections
  /// without a second query.
  Future<List<ProviderSelectionOption>> allProviderOptions() async {
    final providers = await (_db.select(_db.financialProviders)
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.category),
            (tbl) => OrderingTerm.asc(tbl.displayName),
          ]))
        .get();
    final selectedIds = (await selectedProviders()).map((p) => p.id).toSet();

    return providers
        .map((p) => ProviderSelectionOption(
              provider: p,
              isSelected: selectedIds.contains(p.id),
            ))
        .toList();
  }

  Future<List<FinancialProvider>> selectedProviders() async {
    final sources = await _db.select(_db.userFinancialSources).get();
    final providerIds = sources.map((s) => s.providerId).toList();
    if (providerIds.isEmpty) return [];
    return (_db.select(_db.financialProviders)
          ..where((tbl) => tbl.id.isIn(providerIds)))
        .get();
  }

  /// Selects every provider in [providerIds], creating a matching
  /// [Accounts] row for each one that doesn't already have one.
  /// Selecting an already-selected provider again is a no-op for that
  /// id — checked explicitly rather than via `insertOnConflictUpdate`,
  /// since drift's default upsert conflict target is the table's
  /// primary key (autoincrement `id`), not the `providerId` unique
  /// constraint declared in [UserFinancialSources.uniqueKeys], so it
  /// would never actually detect a repeat selection and would violate
  /// that constraint instead.
  Future<void> selectProviders(List<int> providerIds) async {
    for (final providerId in providerIds) {
      final existing = await (_db.select(_db.userFinancialSources)
            ..where((tbl) => tbl.providerId.equals(providerId)))
          .getSingleOrNull();
      if (existing == null) {
        await _db.into(_db.userFinancialSources).insert(
              UserFinancialSourcesCompanion.insert(providerId: providerId),
            );
      }
      await _accountsService.ensureAccountForProvider(providerId);
    }
  }

  /// Removes [providerId] from the user's selection. Deliberately does
  /// not touch any [Accounts] or [Transactions] row — see
  /// [UserFinancialSources] doc for why history must survive this.
  Future<void> deselectProvider(int providerId) async {
    await (_db.delete(_db.userFinancialSources)
          ..where((tbl) => tbl.providerId.equals(providerId)))
        .go();
  }
}
