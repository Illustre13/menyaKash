/// Extracts the leading alphabetic "name" portion of a counterparty
/// string for loose matching, e.g. "SUPERMARKET LTD (Code: 55123)" ->
/// "supermarket ltd". Returns null when there's nothing meaningful to
/// key on (e.g. a bare phone number), so numeric-only counterparties
/// never get lumped together by coincidence.
///
/// Shared between [CategorizationService] (applying a category to
/// existing similarly-named transactions) and [AppDatabase]'s
/// `findCategoryByCode` (auto-categorizing a brand-new transaction at
/// SMS-ingest time against a previously-taught, differently-worded
/// counterparty for the same real merchant) — both need the identical
/// matching rule, or a category taught via one path could silently
/// fail to apply via the other.
String? significantToken(String raw) {
  final withoutParens = raw.replaceAll(RegExp(r'\(.*?\)'), '').trim();
  final lettersOnly = RegExp(r'[A-Za-z][A-Za-z\s]{2,}').firstMatch(withoutParens);
  if (lettersOnly == null) return null;
  return lettersOnly.group(0)!.trim().toLowerCase();
}
