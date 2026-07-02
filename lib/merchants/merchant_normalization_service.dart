import '../data/database.dart';

/// Splits a raw counterparty string (as extracted by a `MomoParser`,
/// e.g. "THE FAMILYS BAKERY LTD 096957") into a merchant name and its
/// trailing account/till code — the Phase 4 fix for the confirmed real
/// bug where that whole string was stored as one opaque, uncategorizable
/// value (docs/AUDIT_PHASE_0.md §3.3).
///
/// This is new plumbing only — it populates [Merchants] and
/// [Transactions.merchantId] alongside the existing [CategoryCodes]-based
/// flow, but nothing in the Categorize/Pay/Frequent-codes screens reads
/// from it yet (see the schema doc comment on [Merchants] for why that's
/// a deliberate, separate follow-up rather than done here).
class MerchantNormalizationService {
  MerchantNormalizationService(this._db);

  final AppDatabase _db;

  /// A trailing run of 4+ digits (optionally with letters mixed in, e.g.
  /// "100126", "902850", "20231") is treated as an account/till code to
  /// strip — confirmed real examples from docs/SMS_PATTERN_LIBRARY.md:
  /// "HOPITAL LA CROIX DU SUD Ltd 100126", "RITE PHARMACY LTD 902850",
  /// "Future Dynamic Innovations FDI Ltd - 20231". A short trailing
  /// number (1-3 digits) is left alone — real short numbers observed
  /// (e.g. "Pacifique 08077" has 5 digits, kept) are rare enough that a
  /// 4-digit floor avoids stripping something that's actually part of
  /// the name (e.g. a unit number) rather than a code.
  static final _trailingCode = RegExp(r'^(.*?)\s*[-]?\s*(\d{4,})$');

  /// Extracts the merchant name portion of [rawCounterparty], stripping
  /// any trailing account/till code. Returns the input unchanged if no
  /// trailing code pattern is found (e.g. "Jean Uwimana" — a personal
  /// name with no code at all, which should never be misidentified as
  /// having one).
  String extractMerchantName(String rawCounterparty) {
    final match = _trailingCode.firstMatch(rawCounterparty.trim());
    if (match == null) return rawCounterparty.trim();
    final namePart = match.group(1)!.trim();
    if (namePart.isEmpty) return rawCounterparty.trim();
    return namePart;
  }

  /// Extracts just the trailing code, or null if none was found.
  String? extractAccountCode(String rawCounterparty) {
    final match = _trailingCode.firstMatch(rawCounterparty.trim());
    if (match == null) return null;
    final namePart = match.group(1)!.trim();
    if (namePart.isEmpty) return null;
    return match.group(2);
  }

  /// Uppercased, punctuation-stripped, whitespace-collapsed — so
  /// "Family Bakery Ltd", "FAMILY BAKERY LTD.", and "family   bakery
  /// ltd" all resolve to the same [Merchants] row instead of creating
  /// three.
  String normalize(String merchantName) {
    final upper = merchantName.toUpperCase();
    final noPunctuation = upper.replaceAll(RegExp(r'[^\w\s]'), ' ');
    return noPunctuation.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Finds or creates the [Merchants] row for [rawCounterparty],
  /// extracting the merchant name first. Returns null if
  /// [rawCounterparty] is null/empty (nothing to resolve).
  Future<Merchant?> resolveMerchant(String? rawCounterparty) async {
    if (rawCounterparty == null || rawCounterparty.trim().isEmpty) return null;

    final name = extractMerchantName(rawCounterparty);
    final normalized = normalize(name);
    if (normalized.isEmpty) return null;

    final existing = await (_db.select(_db.merchants)
          ..where((tbl) => tbl.normalizedName.equals(normalized)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final id = await _db.into(_db.merchants).insert(
          MerchantsCompanion.insert(name: name, normalizedName: normalized),
        );
    return (_db.select(_db.merchants)..where((tbl) => tbl.id.equals(id))).getSingle();
  }
}
