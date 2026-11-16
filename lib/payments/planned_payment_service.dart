import 'package:drift/drift.dart';

import '../data/database.dart';

/// How long a [PlannedPayments] row stays a candidate for matching
/// against a real incoming transaction before it's considered expired
/// (review batch: category-before-dialing spec) — long enough to cover
/// normal USSD confirmation delays (network lag, retrying a PIN),
/// short enough that an unrelated later payment to the same
/// recipient/amount doesn't get misattributed to a stale intent.
const plannedPaymentMatchWindow = Duration(minutes: 15);

/// Read/write surface for [PlannedPayments] — the user's declared
/// payment intent (recipient, amount, chosen category), captured at
/// Pay-screen time and reconciled against real SMS evidence later. See
/// [PlannedPayments]'s own doc for why this is never itself a
/// [Transactions] row.
class PlannedPaymentService {
  PlannedPaymentService(this._db);

  final AppDatabase _db;

  Future<int> create({
    required String recipient,
    required double amount,
    required int categoryId,
    required String providerCode,
  }) {
    return _db.into(_db.plannedPayments).insert(
          PlannedPaymentsCompanion.insert(
            recipient: recipient,
            amount: amount,
            categoryId: categoryId,
            providerCode: providerCode,
            status: PlannedPaymentStatus.pending,
          ),
        );
  }

  /// Finds the best-matching pending planned payment for a real,
  /// newly-inserted transaction and applies its category — called by
  /// [SmsProcessor] right after a real transaction is written. Matching
  /// rule (confirmed with the user): same provider, same amount, within
  /// [plannedPaymentMatchWindow] of the planned payment's creation time,
  /// oldest-first; if more than one pending row satisfies that, prefer
  /// one whose [PlannedPayments.recipient] appears as a substring of
  /// [transactionCounterparty] as a tiebreaker (real SMS often reports
  /// the recipient's name rather than the dialed number/code, so this
  /// is only ever a tiebreaker, never the primary key — see
  /// [PlannedPayments.recipient]'s own doc).
  ///
  /// Returns the matched category id, or null if nothing matched (the
  /// transaction keeps whatever category [SmsProcessor] already
  /// resolved via `CategoryCodes`, if any).
  Future<int?> findMatchAndApply({
    required int transactionId,
    required double amount,
    required String providerCode,
    required DateTime transactionTimestamp,
    String? transactionCounterparty,
  }) async {
    final cutoff = transactionTimestamp.subtract(plannedPaymentMatchWindow);
    final candidates = await (_db.select(_db.plannedPayments)
          ..where((tbl) =>
              tbl.status.equalsValue(PlannedPaymentStatus.pending) &
              tbl.providerCode.equals(providerCode) &
              tbl.amount.equals(amount) &
              tbl.createdAt.isBiggerOrEqualValue(cutoff))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .get();

    if (candidates.isEmpty) return null;

    PlannedPayment chosen = candidates.first;
    if (candidates.length > 1 && transactionCounterparty != null) {
      final counterpartyLower = transactionCounterparty.toLowerCase();
      for (final candidate in candidates) {
        if (counterpartyLower.contains(candidate.recipient.toLowerCase())) {
          chosen = candidate;
          break;
        }
      }
    }

    await (_db.update(_db.plannedPayments)..where((tbl) => tbl.id.equals(chosen.id))).write(
      PlannedPaymentsCompanion(
        status: const Value(PlannedPaymentStatus.matched),
        resolvedAt: Value(DateTime.now()),
        matchedTransactionId: Value(transactionId),
      ),
    );
    return chosen.categoryId;
  }

  /// Flips every pending row older than [plannedPaymentMatchWindow] to
  /// `expired` — called opportunistically (e.g. Home's existing
  /// pull-to-refresh/catch-up path), not on a timer, consistent with
  /// this app having no background-execution machinery of its own.
  Future<void> expireStale() async {
    final cutoff = DateTime.now().subtract(plannedPaymentMatchWindow);
    await (_db.update(_db.plannedPayments)
          ..where((tbl) =>
              tbl.status.equalsValue(PlannedPaymentStatus.pending) &
              tbl.createdAt.isSmallerThanValue(cutoff)))
        .write(
      PlannedPaymentsCompanion(
        status: const Value(PlannedPaymentStatus.expired),
        resolvedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Every planned payment, most recent first — powers the Planned
  /// Payments log (pending + matched + expired).
  Stream<List<PlannedPayment>> watchAll() {
    return (_db.select(_db.plannedPayments)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .watch();
  }
}
