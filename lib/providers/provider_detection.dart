import '../data/database.dart';

/// Result of running a message through [ProviderDetector]. [confidence]
/// is 1.0 when the sender maps to exactly one known provider, and drops
/// when the sender is ambiguous (e.g. MTN's `M-Money` shortcode carries
/// both MoMo and eKash traffic — see [ProviderDetector] doc) and a
/// body-content heuristic had to break the tie.
class ProviderDetection {
  const ProviderDetection({required this.provider, required this.confidence});

  final FinancialProvider provider;
  final double confidence;
}

/// Resolves which [FinancialProviders] row a raw SMS came from, given
/// its sender and body. This is a separate step from parsing: a message
/// can be confidently attributed to a provider even if no parser can
/// yet extract a transaction from its body (e.g. a promotional SMS from
/// a known bank sender) — [ProviderDetector] only answers "who sent
/// this," never "what transaction does this describe."
///
/// Sender alone is enough for most providers, but not all: the real SMS
/// export this app was tuned against (docs/AUDIT_PHASE_0.md §3.2) shows
/// MTN Rwanda's `M-Money` shortcode carries both genuine MoMo messages
/// and eKash messages, which share a sender but not a body shape. For
/// senders mapped to more than one provider, [detect] uses a
/// [bodyDisambiguator] callback per ambiguous sender to break the tie by
/// content; if no disambiguator is registered or none of them match,
/// the first candidate is returned with reduced confidence rather than
/// silently guessing at full confidence.
class ProviderDetector {
  ProviderDetector(this._db);

  final AppDatabase _db;

  /// Body-content predicates for disambiguating a sender that maps to
  /// more than one provider. Keyed by provider code (from
  /// [FinancialProviders.code]) — if a body matches this predicate, that
  /// provider is preferred among the sender's candidates. Registered
  /// externally (see [registerDisambiguator]) rather than hardcoded
  /// here, so provider-specific body heuristics live next to that
  /// provider's parser, not in this generic detection layer.
  final Map<String, bool Function(String body)> _bodyDisambiguators = {};

  void registerDisambiguator(String providerCode, bool Function(String body) predicate) {
    _bodyDisambiguators[providerCode] = predicate;
  }

  /// Returns null if [sender] matches no known provider at all — the
  /// caller's job at that point is the same as v1's "unknown sender,
  /// ignore" path, just made explicit rather than implicit.
  Future<ProviderDetection?> detect({required String sender, required String body}) async {
    final matchingSenders = await (_db.select(_db.providerSenders)
          ..where((tbl) => tbl.senderPattern.equals(sender)))
        .get();
    if (matchingSenders.isEmpty) return null;

    final candidateIds = matchingSenders.map((s) => s.providerId).toSet();
    final candidates = await (_db.select(_db.financialProviders)
          ..where((tbl) => tbl.id.isIn(candidateIds)))
        .get();

    if (candidates.length == 1) {
      return ProviderDetection(provider: candidates.single, confidence: 1.0);
    }

    for (final candidate in candidates) {
      final disambiguator = _bodyDisambiguators[candidate.code];
      if (disambiguator != null && disambiguator(body)) {
        return ProviderDetection(provider: candidate, confidence: 0.9);
      }
    }

    // Ambiguous sender, no disambiguator matched: return a candidate so
    // the message still gets stored under *some* provider (needed for
    // the sms_messages.providerId link), but at low confidence so
    // downstream code/UI can flag it rather than trust it blindly.
    return ProviderDetection(provider: candidates.first, confidence: 0.5);
  }
}
