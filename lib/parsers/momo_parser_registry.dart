import 'airtel_money_parser.dart';
import 'bk_bank_parser.dart';
import 'ekash_parser.dart';
import 'equity_bank_parser.dart';
import 'momo_parser.dart';
import 'mtn_rwanda_parser.dart';
import 'parsed_transaction.dart';

class ParseOutcome {
  const ParseOutcome.parsed(this.transaction) : unparsedBody = null;
  const ParseOutcome.unparsed(this.unparsedBody) : transaction = null;

  final ParsedTransaction? transaction;
  final String? unparsedBody;

  bool get wasParsed => transaction != null;
}

/// Central place new providers are registered. To add support for e.g.
/// Airtel Money Rwanda: implement [MomoParser] in a new file, add an
/// instance to this list with a `providerCode` matching a seeded
/// [FinancialProviders] row. Nothing else in the app needs to change.
///
/// Which sender owns a message is [ProviderDetector]'s job, not this
/// registry's — this class only routes an *already-identified* provider
/// code to the parser that knows how to read that provider's body
/// format. See docs/AUDIT_PHASE_0.md §3.2 for why sender-based routing
/// alone was insufficient (one sender can carry more than one provider).
class MomoParserRegistry {
  MomoParserRegistry({List<MomoParser>? parsers})
      : parsers = parsers ??
            [
              MtnRwandaParser(),
              EkashParser(),
              AirtelMoneyParser(),
              EquityBankParser(),
              BkBankParser(),
            ];

  final List<MomoParser> parsers;

  ParseOutcome processForProvider({
    required String providerCode,
    required String body,
    DateTime? receivedAt,
  }) {
    for (final parser in parsers) {
      if (parser.providerCode != providerCode) continue;
      final result = parser.tryParse(body, receivedAt: receivedAt);
      if (result != null) {
        return ParseOutcome.parsed(result);
      }
    }
    return ParseOutcome.unparsed(body);
  }
}
