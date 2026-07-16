import '../data/database.dart';
import '../ussd/phone_normalizer.dart';

/// Read/write surface for [FavoriteContacts] (spec #7) — which contacts
/// a user has starred on the Pay screen, always sorted first in the
/// contact picker. Keyed by normalized phone number, never an OS
/// contact id — see that table's doc for why.
class FavoriteContactsService {
  FavoriteContactsService(this._db);

  final AppDatabase _db;

  /// Every favorited normalized phone number, as a set for O(1)
  /// membership checks while rendering a contact list.
  Future<Set<String>> favoritedNumbers() async {
    final rows = await _db.select(_db.favoriteContacts).get();
    return rows.map((r) => r.normalizedPhone).toSet();
  }

  /// Stars [rawPhoneNumber]. Silently no-ops if the number doesn't
  /// look like a real Rwandan mobile number — a contact whose raw
  /// number is malformed has nothing stable to key a favorite on.
  ///
  /// Explicit exists-check rather than `insertOnConflictUpdate`: that
  /// method's upsert target is the table's primary key by default in
  /// this drift version, not a declared unique column
  /// (`normalizedPhone` here) — the same class of bug already found
  /// and fixed once in `ProviderSelectionService`/category seeding —
  /// so it would never actually detect an already-favorited number and
  /// would violate the unique constraint on a second favorite() call
  /// for the same contact.
  Future<void> favorite(String rawPhoneNumber) async {
    final normalized = PhoneNormalizer.normalizeRwandanMobile(rawPhoneNumber);
    if (normalized == null) return;
    final existing = await (_db.select(_db.favoriteContacts)
          ..where((tbl) => tbl.normalizedPhone.equals(normalized)))
        .getSingleOrNull();
    if (existing != null) return;
    await _db.into(_db.favoriteContacts).insert(
          FavoriteContactsCompanion.insert(normalizedPhone: normalized),
        );
  }

  Future<void> unfavorite(String rawPhoneNumber) async {
    final normalized = PhoneNormalizer.normalizeRwandanMobile(rawPhoneNumber);
    if (normalized == null) return;
    await (_db.delete(_db.favoriteContacts)
          ..where((tbl) => tbl.normalizedPhone.equals(normalized)))
        .go();
  }
}
