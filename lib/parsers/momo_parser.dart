import 'parsed_transaction.dart';

/// One implementation per mobile money provider/market (e.g. MTN Rwanda,
/// Airtel Rwanda). Adding support for a new provider or country means:
/// write a new class implementing this interface, add its regex set and
/// fixture tests, and register it in [MomoParserRegistry.parsers] — no
/// changes needed anywhere else in the app.
abstract class MomoParser {
  /// Stable identifier stored on every [ParsedTransaction], e.g. 'mtn_rw'.
  String get providerId;

  /// The sender IDs / short codes this parser claims, e.g. {'M-Money'}.
  /// Confirm the real MTN Rwanda sender ID from an actual device — it
  /// varies by market and was not verifiable from public sources.
  Set<String> get knownSenders;

  bool ownsSender(String sender) => knownSenders.contains(sender);

  /// Attempts to parse [body]. Returns null if the message is from a
  /// known sender but doesn't match any recognized template — the caller
  /// is responsible for routing that to the unparsed-message review queue.
  ///
  /// [receivedAt] is the SMS's own inbox timestamp, used as the
  /// transaction date whenever the message body doesn't contain a
  /// parseable date of its own. Without this, a historical inbox scan
  /// would date every past transaction to the moment it was scanned
  /// instead of when it actually happened.
  ParsedTransaction? tryParse(String body, {DateTime? receivedAt});
}
