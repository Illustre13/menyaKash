import 'package:drift/drift.dart';

import '../data/database.dart';

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

    final anchorKey = _significantToken(anchorName);
    if (anchorKey == null) return null;

    final candidates = await (_db.select(_db.transactions)
          ..where((tbl) =>
              tbl.categoryId.isNull() &
              tbl.id.equals(anchor.id).not() &
              tbl.counterparty.isNotNull()))
        .get();

    final similar = candidates.where((tx) {
      final key = _significantToken(tx.counterparty!.trim());
      return key != null && key == anchorKey;
    }).toList();

    if (similar.isEmpty) return null;
    return SimilarGroup(anchor, similar);
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

  /// Extracts the leading alphabetic "name" portion of a counterparty
  /// string for loose matching, e.g. "SUPERMARKET LTD (Code: 55123)" ->
  /// "supermarket ltd". Returns null when there's nothing meaningful to
  /// key on (e.g. a bare phone number), so numeric-only counterparties
  /// never get lumped together by coincidence.
  String? _significantToken(String raw) {
    final withoutParens = raw.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    final lettersOnly = RegExp(r'[A-Za-z][A-Za-z\s]{2,}').firstMatch(withoutParens);
    if (lettersOnly == null) return null;
    return lettersOnly.group(0)!.trim().toLowerCase();
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
  Future<void> updateCode(
    String code, {
    required int categoryId,
    String? displayName,
  }) async {
    await categorizeCounterparty(code, categoryId);
    if (displayName != null && displayName.trim().isNotEmpty) {
      await _db.renameCodeDisplayName(code, displayName.trim());
    }
  }
}
