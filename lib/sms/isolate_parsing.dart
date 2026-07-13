import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../parsers/momo_parser_registry.dart';
import '../parsers/parsed_transaction.dart';

/// Plain-data mirror of a raw inbox SMS — everything [ScanChunk] needs
/// to detect a provider and attempt a parse, with no drift row/
/// connection object anywhere in it, so it can cross an isolate
/// boundary via [compute] (spec Phase 10).
class RawSmsSnapshot {
  const RawSmsSnapshot({required this.sender, required this.body, required this.receivedAt});

  final String sender;
  final String body;
  final DateTime receivedAt;
}

/// The one real body-content disambiguation rule this app has today
/// (`provider_detector_factory.dart`): MTN's `M-Money` shortcode
/// carries both MoMo and eKash traffic, told apart by whether the body
/// mentions "ekash". `containsEkash` matches `ekash_rw`'s real rule
/// (disambiguate BY the keyword's presence); `notContainsEkash`
/// matches `mtn_momo_rw`'s real rule (disambiguate by its ABSENCE) —
/// modeling both directions explicitly rather than approximating the
/// negative case with a positive keyword check, which would silently
/// diverge from the live `ProviderDetector` path for a genuine MTN
/// body that happens to match neither.
enum DisambiguatorRule { none, containsEkash, notContainsEkash }

/// Plain-data mirror of the sender→provider registry
/// ([FinancialProviders]/[ProviderSenders]), fetched once on the main
/// isolate before scanning so the isolate-side detection step never
/// needs a database handle.
class ProviderSnapshot {
  const ProviderSnapshot({
    required this.providerId,
    required this.providerCode,
    required this.senderPatterns,
    this.disambiguator = DisambiguatorRule.none,
  });

  final int providerId;
  final String providerCode;
  final List<String> senderPatterns;
  final DisambiguatorRule disambiguator;
}

/// One raw message's outcome after isolate-side detection + parsing —
/// everything [SmsProcessor.processBatch] needs to write the real
/// database rows, without the isolate itself ever touching the DB.
class ParsedSmsResult {
  const ParsedSmsResult({
    required this.sms,
    required this.smsHash,
    this.providerId,
    this.parsed,
  });

  final RawSmsSnapshot sms;
  final String smsHash;

  /// Null when no known provider matched the sender at all.
  final int? providerId;

  /// Null when a provider was identified but no parser could read the
  /// body — the message is still real evidence, just unrecognized.
  final ParsedTransaction? parsed;

  bool get wasParsed => parsed != null;
}

/// Input bundle for [parseChunk] — [compute] takes exactly one argument,
/// so every isolate-side dependency is packed into this one plain object.
class ParseChunkInput {
  const ParseChunkInput({required this.messages, required this.providers});

  final List<RawSmsSnapshot> messages;
  final List<ProviderSnapshot> providers;
}

/// Runs entirely on a background isolate via `compute(parseChunk, ...)`
/// (spec Phase 10) — the CPU-bound half of the historical scan
/// (sender→provider matching + regex parsing) moved off the main
/// isolate, using only the plain-data [ProviderSnapshot]s captured
/// once up front rather than live database access. Must be a top-level
/// function (Dart's isolate entry-point requirement), which is also
/// why the provider registry and parser registry can't just be passed
/// in as live service objects — everything crossing the isolate
/// boundary has to be plain data or a top-level/static function.
List<ParsedSmsResult> parseChunk(ParseChunkInput input) {
  final registry = MomoParserRegistry();

  return input.messages.map((sms) {
    final smsHash = _hashSmsMessage(sms.sender, sms.body, sms.receivedAt);
    final provider = _detectProvider(sms, input.providers);

    if (provider == null) {
      return ParsedSmsResult(sms: sms, smsHash: smsHash);
    }

    final outcome = registry.processForProvider(
      providerCode: provider.providerCode,
      body: sms.body,
      receivedAt: sms.receivedAt,
    );

    return ParsedSmsResult(
      sms: sms,
      smsHash: smsHash,
      providerId: provider.providerId,
      parsed: outcome.wasParsed ? outcome.transaction : null,
    );
  }).toList();
}

/// Isolate-safe mirror of `ProviderDetector.detect`'s matching logic —
/// same sender-pattern + body-disambiguator rules, but reading from the
/// in-memory [providers] snapshot instead of querying the database.
ProviderSnapshot? _detectProvider(RawSmsSnapshot sms, List<ProviderSnapshot> providers) {
  final candidates = providers.where((p) => p.senderPatterns.contains(sms.sender)).toList();
  if (candidates.isEmpty) return null;
  if (candidates.length == 1) return candidates.single;

  final mentionsEkash = sms.body.toLowerCase().contains('ekash');
  for (final candidate in candidates) {
    final matches = switch (candidate.disambiguator) {
      DisambiguatorRule.containsEkash => mentionsEkash,
      DisambiguatorRule.notContainsEkash => !mentionsEkash,
      DisambiguatorRule.none => false,
    };
    if (matches) return candidate;
  }
  // Mirrors ProviderDetector's fallback: an ambiguous sender with no
  // matching disambiguator still resolves to a candidate (so the
  // message is attributed to *some* provider) rather than being
  // dropped — same fail-safe behavior as the live path.
  return candidates.first;
}

/// Mirrors `hashSmsMessage` in `lib/data/database.dart` exactly — same
/// formula, same inputs — so a chunk parsed here dedupes identically
/// against `SmsMessages.smsHash` as the live single-message listener
/// path does. Reimplemented rather than imported directly so this
/// isolate-safe module doesn't pull in database.dart's drift table
/// definitions; if the formula in database.dart ever changes, this
/// must change with it.
String _hashSmsMessage(String sender, String body, DateTime receivedAt) {
  final input = '$sender|$body|${receivedAt.millisecondsSinceEpoch}';
  return sha256.convert(utf8.encode(input)).toString();
}
