import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../accounts/accounts_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/provider_assets.dart';
import '../../ussd/sim_selection_controller.dart';
import 'balance_refresh_popup.dart';

/// The dashboard hero: total balance headline with the per-account
/// wallet breakdown inside one branded card. Deliberately hard-commits
/// to the brand-purple look in BOTH themes (white ink on #7F56D9 was
/// contrast-validated in app_theme.dart; the gradient only darkens
/// from there) — this is the one intentionally theme-invariant surface
/// in the app, the same way a bank card looks the same at night.
///
/// Sums only accounts with a known balance; some providers (Equity)
/// never report a running balance in their SMS, and silently treating
/// that as zero would understate the real total — the card says so
/// instead.
class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.summaries,
    required this.currency,
    required this.simSelectionController,
    required this.balanceHidden,
    required this.onToggleBalanceHidden,
  });

  final List<AccountSummary> summaries;
  final NumberFormat currency;
  final SimSelectionController simSelectionController;

  /// Review batch item #6: masks the Total Balance headline AND every
  /// per-account balance below it — "hide everything," not just the
  /// headline, so a shoulder-surfer can't read any real number.
  final bool balanceHidden;
  final VoidCallback onToggleBalanceHidden;

  static const _mask = '••••••';

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const SizedBox.shrink();

    final total = summaries.fold<double>(0, (sum, s) => sum + (s.currentBalance ?? 0));
    final hasIncompleteBalance = summaries.any((s) => s.currentBalance == null);
    final textTheme = Theme.of(context).textTheme;

    const ink = Colors.white;
    final inkMuted = Colors.white.withValues(alpha: 0.72);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppBrand.purpleLight, Color(0xFF5B3BAF)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppBrand.purpleLight.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Balance',
                  style: textTheme.labelMedium?.copyWith(color: inkMuted, letterSpacing: 0.4),
                ),
              ),
              // Manual refresh (review batch item #3): "some providers
              // — especially banks — might not always send the SMS for
              // a transaction, so the balance can go stale." This never
              // silently re-derives a number; it opens a picker that
              // dials each chosen account's real USSD code so the user
              // sees the network's own live answer.
              // Balance-hide toggle (review batch item #6) — a private
              // preference, not a data change: masking never touches
              // what's stored, only what this card renders.
              IconButton(
                icon: Icon(
                  balanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: inkMuted,
                ),
                tooltip: balanceHidden ? 'Show balances' : 'Hide balances',
                visualDensity: VisualDensity.compact,
                onPressed: onToggleBalanceHidden,
              ),
              IconButton(
                icon: Icon(Icons.sync, size: 18, color: inkMuted),
                tooltip: 'Check real balances',
                visualDensity: VisualDensity.compact,
                onPressed: () => showBalanceRefreshPopup(
                  context,
                  accounts: summaries,
                  simSelectionController: simSelectionController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            balanceHidden ? _mask : currency.format(total),
            style: textTheme.headlineMedium?.copyWith(
              color: ink,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (hasIncompleteBalance) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.info_outline, size: 13, color: inkMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Some accounts don\'t report a balance — total may be incomplete.',
                    style: textTheme.labelSmall?.copyWith(color: inkMuted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
          const SizedBox(height: 12),
          for (final summary in summaries) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  ProviderLogo(
                    providerCode: summary.providerCode,
                    displayName: summary.providerDisplayName,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      summary.account.label.isNotEmpty
                          ? summary.account.label
                          : summary.providerDisplayName,
                      style: textTheme.bodyMedium?.copyWith(color: ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    balanceHidden
                        ? _mask
                        : summary.currentBalance != null
                            ? currency.format(summary.currentBalance)
                            : 'Balance unknown',
                    style: summary.currentBalance != null
                        ? textTheme.bodyMedium?.copyWith(
                            color: ink,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          )
                        : textTheme.labelSmall?.copyWith(color: inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
