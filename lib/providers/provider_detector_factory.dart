import '../data/database.dart';
import 'provider_detection.dart';

/// Builds a [ProviderDetector] with the real disambiguation rules this
/// app needs, based on confirmed patterns in real SMS data
/// (docs/AUDIT_PHASE_0.md §3.2) — kept out of [ProviderDetector] itself
/// so that class stays generic and these app-specific rules are easy to
/// find and extend in one place as more providers are added.
ProviderDetector buildProviderDetector(AppDatabase db) {
  final detector = ProviderDetector(db);

  // MTN Rwanda's `M-Money` shortcode carries both MTN MoMo and eKash
  // traffic. Every confirmed-real eKash message body contains the word
  // "ekash" (case-insensitive) — genuine MoMo P2P/merchant/withdrawal/
  // bundle messages never do. See seed data in AppDatabase._seedProviders
  // for why both providers list `M-Money` as a known sender.
  detector.registerDisambiguator('ekash_rw', (body) => body.toLowerCase().contains('ekash'));
  detector.registerDisambiguator('mtn_momo_rw', (body) => !body.toLowerCase().contains('ekash'));

  return detector;
}
