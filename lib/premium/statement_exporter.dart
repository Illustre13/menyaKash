import '../data/database.dart';

/// Prep-only architecture (spec Phase 11) — no working export logic
/// exists yet. This interface exists so the free tier's data model and
/// a future paid Statement Export feature share one contract from day
/// one, rather than the paid feature reverse-engineering a shape
/// against already-shipped code later.
///
/// This module ([lib/premium/]) is deliberately its own top-level
/// directory, segregated from the free/offline core (`lib/accounts/`,
/// `lib/analytics/`, etc.) — a structural signal for where premium-
/// tier-only code is allowed to live, should this app ever grow paid
/// features for real.
enum StatementFormat { pdf, excel, csv }

/// Renders a user's transaction history to a portable file format.
/// Deliberately has no network parameter of any kind — every
/// implementation must be entirely local, consistent with this app's
/// architectural mandate (no INTERNET permission, no cloud, anywhere).
abstract class StatementExporter {
  StatementFormat get format;

  Future<void> export({
    required List<Transaction> transactions,
    required String destinationPath,
  });
}

/// Placeholder so Settings' existing "Export Statement" entry point
/// (`lib/screens/profile/settings_screen.dart`, stubbed since Phase 7)
/// has a real-if-disabled type behind it. No concrete
/// `PdfStatementExporter`/`ExcelStatementExporter`/`CsvStatementExporter`
/// exists yet — building those, and adding the `pdf`/`excel`/`csv`
/// dependency each would need, is implementation-phase work, not part
/// of this prep-only phase.
class UnimplementedStatementExporter implements StatementExporter {
  const UnimplementedStatementExporter(this.format);

  @override
  final StatementFormat format;

  @override
  Future<void> export({
    required List<Transaction> transactions,
    required String destinationPath,
  }) {
    throw UnimplementedError('$format export is not yet available.');
  }
}
