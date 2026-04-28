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

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// e.g. "mtn_rw", "airtel_rw" — matches a MomoParser.providerId.
  TextColumn get provider => text().withLength(min: 1, max: 32)();

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
  /// and for the "Review unparsed" screen's context.
  TextColumn get rawSmsBody => text()();

  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
}

/// Messages from a known MoMo sender that no registered parser could
/// match. Surfaced in the "Review" screen so the parser can be extended
/// instead of silently dropping data.
class UnparsedMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sender => text()();
  TextColumn get body => text()();
  DateTimeColumn get receivedAt => dateTime()();
  BoolColumn get resolved => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Categories, CategoryCodes, Transactions, UnparsedMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

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
