import 'package:drift/drift.dart';

import '../data/database.dart';
import 'counterparty_matching.dart';

/// A transaction paired with other uncategorized transactions that look
/// like the same counterparty (case-insensitive substring match on
/// name, e.g. "SUPERMARKET LTD (Code: 55123)" vs "SUPERMARKET LTD"),
/// even when the raw counterparty string isn't byte-identical. Used to
/// offer a one-tap "apply to all N similar" bulk action.
class SimilarGroup {
  const SimilarGroup(this.anchor, this.similar);
  final Transaction anchor;
  final List<Transaction> similar;
}

/// Handles the "teach the app" moment: when a transaction's counterparty
/// code has never been seen before, the user assigns it a category once,
/// and every future transaction from that same code is auto-categorized
/// from then on. No seed data — the mapping table starts empty and grows
/// entirely from real user behavior.
class CategorizationService {
  CategorizationService(this._db);

  final AppDatabase _db;

  Stream<List<Transaction>> watchUncategorized() {
    return (_db.select(_db.transactions)
          ..where((tbl) => tbl.categoryId.isNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)]))
        .watch();
  }

  /// All transactions, most recent first — powers the "edit category"
  /// list where already-categorized transactions can be reassigned.
  Stream<List<Transaction>> watchAll() {
    return (_db.select(_db.transactions)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)]))
        .watch();
  }

  Future<List<Category>> allCategories() => _db.select(_db.categories).get();

  Future<Category?> categoryById(int id) =>
      (_db.select(_db.categories)..where((tbl) => tbl.id.equals(id)))
          .getSingleOrNull();

  /// id → name for every category, loaded once per list build — the
  /// transaction list previously ran a `FutureBuilder` + query *per
  /// visible row* to resolve a category name (a genuine rebuild/query
  /// hotspot); one map lookup per row replaces all of that.
  Future<Map<int, String>> categoryNamesById() async {
    final categories = await _db.select(_db.categories).get();
    return {for (final c in categories) c.id: c.name};
  }

  /// id → display name for every provider — powers the transaction
  /// tile's provider badge without a query per row.
  Future<Map<int, String>> providerNamesById() async {
    final providers = await _db.select(_db.financialProviders).get();
    return {for (final p in providers) p.id: p.displayName};
  }

  /// id → user-facing label for every account — powers the transaction
  /// tile's account line without a query per row.
  Future<Map<int, String>> accountLabelsById() async {
    final accounts = await _db.select(_db.accounts).get();
    return {for (final a in accounts) a.id: a.label};
  }

  /// id → stable code (e.g. 'mtn_momo_rw') for every provider — powers
  /// the transaction tile's logo without a query per row.
  Future<Map<int, String>> providerCodesById() async {
    final providers = await _db.select(_db.financialProviders).get();
    return {for (final p in providers) p.id: p.code};
  }

  /// Every transaction id that's one side of a matched internal
  /// transfer — the Transactions feed renders those rows with the
  /// transfer treatment instead of income/expense.
  Future<Set<int>> linkedTransferTransactionIds() async {
    final links = await _db.select(_db.transferLinks).get();
    return {
      for (final link in links) ...[link.fromTransactionId, link.toTransactionId],
    };
  }

  Future<int> createCategory(String name) {
    return _db
        .into(_db.categories)
        .insert(CategoriesCompanion.insert(name: name));
  }

  Future<void> renameCategory(int categoryId, String newName) {
    return (_db.update(_db.categories)..where((tbl) => tbl.id.equals(categoryId)))
        .write(CategoriesCompanion(name: Value(newName)));
  }

  /// Deletes a category. Transactions and code mappings referencing it
  /// fall back to Uncategorized (schema uses ON DELETE CASCADE for
  /// category_codes and a nullable FK for transactions, so this is safe
  /// — no orphaned rows, just transactions reverting to unlabeled).
  Future<void> deleteCategory(int categoryId) async {
    await (_db.update(_db.transactions)
          ..where((tbl) => tbl.categoryId.equals(categoryId)))
        .write(const TransactionsCompanion(categoryId: Value(null)));
    await (_db.delete(_db.categories)..where((tbl) => tbl.id.equals(categoryId))).go();
  }

  /// Assigns [categoryId] to every transaction currently sharing
  /// [counterparty], and remembers the mapping so future transactions
  /// from the same code are categorized automatically on ingest.
  Future<void> categorizeCounterparty(
    String counterparty,
    int categoryId,
  ) async {
    await _db.assignCodeToCategory(counterparty, categoryId);

    await (_db.update(_db.transactions)
          ..where((tbl) => tbl.counterparty.equals(counterparty)))
        .write(TransactionsCompanion(categoryId: Value(categoryId)));
  }

  /// One-off override for a single transaction without creating a
  /// standing code mapping (e.g. a one-time miscategorized counterparty).
  /// Also used to re-categorize a transaction that already had a
  /// category, since it unconditionally overwrites category_id.
  Future<void> categorizeSingleTransaction(
    int transactionId,
    int categoryId,
  ) async {
    await (_db.update(_db.transactions)
          ..where((tbl) => tbl.id.equals(transactionId)))
        .write(TransactionsCompanion(categoryId: Value(categoryId)));
  }

  /// Finds other currently-uncategorized transactions whose counterparty
  /// looks like the same real-world entity as [anchor]'s, using a loose
  /// case-insensitive substring match rather than exact string equality
  /// — e.g. "SUPERMARKET LTD (Code: 55123)" and "SUPERMARKET LTD - TILL 2"
  /// both contain "SUPERMARKET LTD". This is a suggestion only: nothing
  /// is applied until the user confirms in [categorizeGroup].
  Future<SimilarGroup?> findSimilarUncategorized(Transaction anchor) async {
    final anchorName = anchor.counterparty?.trim();
    if (anchorName == null || anchorName.isEmpty) return null;
    return _findSimilarUncategorizedByName(anchorName, excludeTransactionId: anchor.id);
  }

  /// Same matching rule as [findSimilarUncategorized], anchored on a raw
  /// counterparty string instead of a specific [Transaction] — the
  /// Frequent Codes tab edits a code's category independent of any one
  /// transaction (a [CodeUsage] row, not a [Transaction]), so it has no
  /// anchor row to pass. Used by [categorizeCounterpartyEverywhere] to
  /// fix the confirmed real bug where editing a frequent code's category
  /// only updated transactions sharing its *exact* counterparty string,
  /// silently leaving name-variant transactions for the same real
  /// merchant (e.g. a different trailing till code) uncategorized.
  Future<SimilarGroup?> _findSimilarUncategorizedByName(
    String anchorName, {
    int? excludeTransactionId,
  }) async {
    final anchorKey = significantToken(anchorName);
    if (anchorKey == null) return null;

    final query = _db.select(_db.transactions)
      ..where((tbl) => tbl.categoryId.isNull() & tbl.counterparty.isNotNull());
    if (excludeTransactionId != null) {
      query.where((tbl) => tbl.id.equals(excludeTransactionId).not());
    }
    final candidates = await query.get();

    final similar = candidates.where((tx) {
      final key = significantToken(tx.counterparty!.trim());
      return key != null && key == anchorKey;
    }).toList();

    if (similar.isEmpty) return null;
    // No real anchor transaction exists in this path — the first match
    // stands in as SimilarGroup's anchor slot (categorizeGroup treats
    // every transaction in the group identically, so which one is
    // nominally "the anchor" has no behavioral effect).
    return SimilarGroup(similar.first, similar.skip(1).toList());
  }

  /// Assigns [categoryId] to every transaction matching [counterparty]
  /// by the same loose "same real-world merchant" rule
  /// [findSimilarUncategorized] uses (not just an exact string match),
  /// and remembers the mapping for future auto-categorization on
  /// ingest. This is what the Frequent Codes tab's edit flow should
  /// call instead of the exact-match-only [categorizeCounterparty] —
  /// see that method's doc and the confirmed real bug this fixes.
  Future<void> categorizeCounterpartyEverywhere(String counterparty, int categoryId) async {
    await categorizeCounterparty(counterparty, categoryId);

    final group = await _findSimilarUncategorizedByName(counterparty);
    if (group == null) return;
    await categorizeGroup(group, categoryId);
  }

  /// Applies [categoryId] to [anchor] plus every transaction in
  /// [similar], and remembers each distinct raw counterparty string
  /// involved so exact future matches auto-categorize too.
  Future<void> categorizeGroup(SimilarGroup group, int categoryId) async {
    final allTx = [group.anchor, ...group.similar];
    final distinctCounterparties = allTx
        .map((tx) => tx.counterparty)
        .whereType<String>()
        .toSet();

    for (final counterparty in distinctCounterparties) {
      await _db.assignCodeToCategory(counterparty, categoryId);
    }
    for (final tx in allTx) {
      await categorizeSingleTransaction(tx.id, categoryId);
    }
  }


  /// Every counterparty paid so far, ranked by how often — the
  /// "phonebook" behind the Frequent Codes screen and the Pay screen's
  /// quick-pick list. [limit] caps results (e.g. for a quick-pick
  /// widget); omit for the full management screen.
  Future<List<CodeUsage>> mostUsedCounterparties({int? limit}) {
    return _db.mostUsedCounterparties(limit: limit);
  }

  /// Sets a code's category and/or friendly display name in one step —
  /// the edit action on the Frequent Codes screen. A code-to-category
  /// mapping row must exist to carry a display name, so both are always
  /// written together rather than as two independent actions.
  ///
  /// Uses [categorizeCounterpartyEverywhere], not the exact-match-only
  /// [categorizeCounterparty] — this is the confirmed real bug fix
  /// (spec #8): a real merchant's counterparty string isn't always
  /// byte-identical across messages (e.g. a different trailing till
  /// code each time), so categorizing "the code" from this screen must
  /// sweep up every real-world-same-merchant variant, not just the one
  /// exact string this particular [CodeUsage] row happened to rank on.
  Future<void> updateCode(
    String code, {
    required int categoryId,
    String? displayName,
  }) async {
    await categorizeCounterpartyEverywhere(code, categoryId);
    if (displayName != null && displayName.trim().isNotEmpty) {
      await _db.renameCodeDisplayName(code, displayName.trim());
    }
  }
}
