import 'parsed_transaction.dart';

/// One implementation per financial provider (e.g. MTN MoMo Rwanda,
/// eKash Rwanda, Airtel Money Rwanda). Adding support for a new provider
/// means: write a new class implementing this interface, add its regex
/// set and fixture tests, and register it in
/// [MomoParserRegistry.parsers] — no changes needed anywhere else in
/// the app.
///
/// Which sender a message came from is no longer this class's concern —
/// that's [ProviderDetector]'s job (lib/providers/), since one sender
/// can carry more than one provider's traffic (confirmed real case:
/// MTN's `M-Money` shortcode carries both MoMo and eKash — see
/// docs/AUDIT_PHASE_0.md §3.2). A parser only needs to know its own
/// provider code and how to read its own body format.
abstract class MomoParser {
  /// Stable identifier matching a [FinancialProviders.code] row, e.g.
  /// 'mtn_momo_rw'. This is how [MomoParserRegistry.processForProvider]
  /// finds the right parser once [ProviderDetector] has already
  /// resolved which provider a message came from.
  String get providerCode;

  /// Attempts to parse [body]. Returns null if the message is from this
  /// parser's provider but doesn't match any recognized template — the
  /// caller is responsible for routing that to the unparsed-message
  /// review queue.
  ///
  /// [receivedAt] is the SMS's own inbox timestamp, used as the
  /// transaction date whenever the message body doesn't contain a
  /// parseable date of its own. Without this, a historical inbox scan
  /// would date every past transaction to the moment it was scanned
  /// instead of when it actually happened.
  ParsedTransaction? tryParse(String body, {DateTime? receivedAt});
}
