import 'momo_parser.dart';
import 'mtn_rwanda_parser.dart';
import 'parsed_transaction.dart';

class ParseOutcome {
  const ParseOutcome.parsed(this.providerId, this.transaction)
      : unparsedBody = null;
  const ParseOutcome.unparsed(this.unparsedBody)
      : providerId = null,
        transaction = null;

  final String? providerId;
  final ParsedTransaction? transaction;
  final String? unparsedBody;

  bool get wasParsed => transaction != null;
}

/// Central place new providers/countries are registered. To add support
/// for e.g. Airtel Rwanda: implement MomoParser in a new file, add an
/// instance to this list. Nothing else in the app needs to change.
class MomoParserRegistry {
  MomoParserRegistry({List<MomoParser>? parsers})
      : parsers = parsers ?? [MtnRwandaParser()];

  final List<MomoParser> parsers;

  bool isKnownSender(String sender) =>
      parsers.any((parser) => parser.ownsSender(sender));

  ParseOutcome process(String sender, String body, {DateTime? receivedAt}) {
    for (final parser in parsers) {
      if (!parser.ownsSender(sender)) continue;
      final result = parser.tryParse(body, receivedAt: receivedAt);
      if (result != null) {
        return ParseOutcome.parsed(parser.providerId, result);
      }
    }
    return ParseOutcome.unparsed(body);
  }
}
