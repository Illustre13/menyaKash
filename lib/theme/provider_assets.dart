import 'package:flutter/material.dart';

/// Provider code → real logo asset under assets/brand/. A provider
/// with no (loadable) entry renders the monogram fallback.
const _providerLogoAssets = <String, String>{
  'mtn_momo_rw': 'assets/brand/mtn.png',
  'airtel_money_rw': 'assets/brand/airtel.png',
  'ekash_rw': 'assets/brand/ekash.png',
  'bk_bank_rw': 'assets/brand/bk.jpg',
  'equity_bank_rw': 'assets/brand/equity.png',
  // No dedicated MoKash logo asset yet — falls back to the monogram
  // tile below, same as any provider not listed here.
};

/// Loose match to each provider's real brand color — used for the
/// monogram fallback ring and as the tile tint behind transparent
/// logos.
const providerAccents = <String, Color>{
  'mtn_momo_rw': Color(0xFFFFCC00),
  'airtel_money_rw': Color(0xFFE40000),
  'ekash_rw': Color(0xFF00A651),
  'bk_bank_rw': Color(0xFF004A8F),
  'equity_bank_rw': Color(0xFF7A1F1F),
  'mokash_rw': Color(0xFFFFCC00),
};

/// A provider's logo in a rounded tile, falling back to a colored
/// monogram when no (loadable) logo asset exists — one widget so the
/// selection cards, Settings' Connected Services, and the wallet
/// breakdown all render providers identically.
class ProviderLogo extends StatelessWidget {
  const ProviderLogo({
    super.key,
    required this.providerCode,
    required this.displayName,
    this.size = 40,
  });

  final String providerCode;
  final String displayName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = providerAccents[providerCode] ?? Theme.of(context).colorScheme.primary;
    final asset = _providerLogoAssets[providerCode];

    Widget monogram() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Text(
            displayName.characters.first,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: size * 0.45,
              color: accent,
            ),
          ),
        );

    if (asset == null) return monogram();

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      padding: EdgeInsets.all(size * 0.12),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        // A missing/corrupt asset must degrade to the monogram, never
        // crash a list row.
        errorBuilder: (_, __, ___) => monogram(),
      ),
    );
  }
}
