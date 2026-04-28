import '../data/database.dart';

/// Result of successfully parsing a MoMo SMS body. Provider-agnostic —
/// every [MomoParser] implementation produces this same shape so the rest
/// of the pipeline (storage, categorization, analytics) never needs to
/// know which provider or country a message came from.
class ParsedTransaction {
  const ParsedTransaction({
    required this.type,
    required this.amount,
    this.fee = 0,
    this.counterparty,
    this.txRef,
    this.balanceAfter,
    required this.timestamp,
  });

  final TransactionType type;
  final double amount;
  final double fee;
  final String? counterparty;
  final String? txRef;
  final double? balanceAfter;
  final DateTime timestamp;
}
