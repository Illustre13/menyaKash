import '../data/database.dart';

/// Finds pairs of [Transactions] that are really one internal transfer
/// between the user's own accounts, and records them as [TransferLinks]
/// so analytics can exclude them from income/expense totals — the
/// Phase 3 fix for the confirmed real problem where a BK "sent to MTN
/// mobile money" debit and an MTN "received" credit for the same
/// real-world movement would otherwise be counted as unrelated
/// income+expense (docs/AUDIT_PHASE_0.md §3.2,
/// docs/SMS_PATTERN_LIBRARY.md "Cross-provider transfer-matching
/// evidence").
///
/// Runs as a third pipeline stage, after [SmsProcessor] has already
/// written both sides as independent `Transactions` rows — this engine
/// never deletes or merges those rows, it only adds a [TransferLinks]
/// row connecting them. Both originals remain intact as the real
/// evidence of what each provider actually reported.
class TransferMatchingEngine {
  TransferMatchingEngine(this._db);

  final AppDatabase _db;

  /// Real-world tolerance for "same movement" — the strongest evidence
  /// found (docs/SMS_PATTERN_LIBRARY.md) was an Equity/MTN pair 3
  /// seconds apart; this is generous enough to cover that plus normal
  /// SMS-delivery jitter without being so wide it starts matching
  /// unrelated same-amount transactions.
  static const _timeTolerance = Duration(minutes: 5);

  /// Scans unlinked outbound transactions (`sent`, `bankTransfer`,
  /// `withdrawal`) against unlinked inbound transactions (`received`,
  /// `deposit`) for matches, and creates a [TransferLinks] row for each
  /// match found. Returns how many new links were created. Safe to call
  /// repeatedly — already-linked transactions are excluded from the
  /// search on every run, so this never creates a duplicate link for
  /// the same pair (also enforced by [TransferLinks]'s own unique key).
  Future<int> findAndLinkTransfers() async {
    final outbound = await _unlinkedByTypes(const {
      TransactionType.sent,
      TransactionType.bankTransfer,
      TransactionType.withdrawal,
    });
    final inbound = await _unlinkedByTypes(const {
      TransactionType.received,
      TransactionType.deposit,
    });

    var linksCreated = 0;
    final matchedInboundIds = <int>{};

    for (final debit in outbound) {
      Transaction? bestMatch;
      var bestIsConfirmed = false;

      for (final credit in inbound) {
        if (matchedInboundIds.contains(credit.id)) continue;
        if (debit.amount != credit.amount) continue;
        if (debit.accountId != null &&
            credit.accountId != null &&
            debit.accountId == credit.accountId) {
          // Same account on both sides isn't a transfer between
          // accounts — skip (this would be two legitimate same-account
          // transactions that happen to share an amount).
          continue;
        }

        final timeDelta = debit.timestamp.difference(credit.timestamp).abs();
        if (timeDelta > _timeTolerance) continue;

        // Confirmed: an explicit shared reference exists (e.g. Equity's
        // `MTN Ref.` matching MTN's own `Financial Transaction Id`) —
        // see docs/SMS_PATTERN_LIBRARY.md for the real example this is
        // modeled on.
        final isConfirmed = debit.txRef != null &&
            credit.txRef != null &&
            debit.txRef == credit.txRef;

        if (bestMatch == null || (isConfirmed && !bestIsConfirmed)) {
          bestMatch = credit;
          bestIsConfirmed = isConfirmed;
          if (isConfirmed) break; // can't do better than a confirmed match
        }
      }

      if (bestMatch != null) {
        final reason = bestIsConfirmed
            ? 'matched via shared reference ${debit.txRef}'
            : 'matched via amount+time proximity (${debit.amount} RWF, '
                '${debit.timestamp.difference(bestMatch.timestamp).abs().inSeconds}s apart), '
                'no shared reference';

        await _db.into(_db.transferLinks).insertOnConflictUpdate(
              TransferLinksCompanion.insert(
                fromTransactionId: debit.id,
                toTransactionId: bestMatch.id,
                confidence: bestIsConfirmed
                    ? TransferMatchConfidence.confirmed
                    : TransferMatchConfidence.probable,
                matchReason: reason,
              ),
            );
        matchedInboundIds.add(bestMatch.id);
        linksCreated++;
      }
    }

    return linksCreated;
  }

  /// True if [transactionId] is already linked (on either side) to
  /// another transaction as a transfer — analytics uses this to
  /// exclude linked transactions from income/expense totals.
  Future<bool> isPartOfTransfer(int transactionId) async {
    final asFrom = await (_db.select(_db.transferLinks)
          ..where((tbl) => tbl.fromTransactionId.equals(transactionId)))
        .getSingleOrNull();
    if (asFrom != null) return true;
    final asTo = await (_db.select(_db.transferLinks)
          ..where((tbl) => tbl.toTransactionId.equals(transactionId)))
        .getSingleOrNull();
    return asTo != null;
  }

  Future<List<Transaction>> _unlinkedByTypes(Set<TransactionType> types) async {
    final linkedFromIds = await (_db.selectOnly(_db.transferLinks)
          ..addColumns([_db.transferLinks.fromTransactionId]))
        .map((row) => row.read(_db.transferLinks.fromTransactionId)!)
        .get();
    final linkedToIds = await (_db.selectOnly(_db.transferLinks)
          ..addColumns([_db.transferLinks.toTransactionId]))
        .map((row) => row.read(_db.transferLinks.toTransactionId)!)
        .get();
    final linkedIds = {...linkedFromIds, ...linkedToIds};

    final query = _db.select(_db.transactions)
      ..where((tbl) => tbl.type.isIn(types.map((t) => t.name)));
    final rows = await query.get();
    return rows.where((tx) => !linkedIds.contains(tx.id)).toList();
  }
}
