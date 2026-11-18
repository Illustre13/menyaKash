import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../accounts/accounts_service.dart';
import '../../theme/app_theme.dart';
import '../../ussd/sim_selection_controller.dart';
import 'balance_refresh_popup.dart';

/// The dashboard hero (Home redesign, screen 10): total balance with
/// this month's money in/out tiles inside one branded card. The
/// per-account breakdown moved out to Home's own "Accounts" section.
/// Deliberately hard-commits to the brand-purple look in BOTH themes
/// (white ink on #7F56D9 was contrast-validated in app_theme.dart; the
/// gradient only darkens from there) — this is the one intentionally
/// theme-invariant surface in the app, the same way a bank card looks
/// the same at night.
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
    this.monthIn,
    this.monthOut,
    this.updatedAt,
  });

  final List<AccountSummary> summaries;
  final NumberFormat currency;
  final SimSelectionController simSelectionController;

  /// Review batch item #6: masks every money figure on the card — "hide
  /// everything," not just the headline, so a shoulder-surfer can't read
  /// any real number.
  final bool balanceHidden;
  final VoidCallback onToggleBalanceHidden;

  /// This calendar month's totals; null while still loading.
  final double? monthIn;
  final double? monthOut;

  /// Time of the newest SMS-derived transaction — the balance is only as
  /// fresh as that. Null hides the footer (nothing imported yet).
  final DateTime? updatedAt;

  static const _mask = '••••••';

  String _updatedLabel(DateTime at) {
    final now = DateTime.now();
    final sameDay = at.year == now.year && at.month == now.month && at.day == now.day;
    final time = DateFormat.jm().format(at);
    return sameDay ? time : '${DateFormat('d MMM').format(at)}, $time';
  }

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const SizedBox.shrink();

    final total = summaries.fold<double>(0, (sum, s) => sum + (s.currentBalance ?? 0));
    final hasIncompleteBalance = summaries.any((s) => s.currentBalance == null);
    final textTheme = Theme.of(context).textTheme;
    final amount = NumberFormat.decimalPattern();

    const ink = Colors.white;
    final inkMuted = Colors.white.withValues(alpha: 0.72);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
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
                  'Total balance · ${summaries.length} account${summaries.length == 1 ? '' : 's'}',
                  style: textTheme.labelMedium?.copyWith(color: inkMuted, letterSpacing: 0.2),
                ),
              ),
              // Balance-hide toggle (review batch item #6) — a private
              // preference, not a data change: masking never touches
              // what's stored, only what this card renders.
              _CircleIconButton(
                icon: balanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                tooltip: balanceHidden ? 'Show balances' : 'Hide balances',
                onPressed: onToggleBalanceHidden,
              ),
              const SizedBox(width: 6),
              // Manual refresh (review batch item #3): "some providers
              // — especially banks — might not always send the SMS for
              // a transaction, so the balance can go stale." This never
              // silently re-derives a number; it opens a picker that
              // dials each chosen account's real USSD code so the user
              // sees the network's own live answer.
              _CircleIconButton(
                icon: Icons.sync,
                tooltip: 'Check real balances',
                onPressed: () => showBalanceRefreshPopup(
                  context,
                  accounts: summaries,
                  simSelectionController: simSelectionController,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: 'RWF ',
                    style: textTheme.titleMedium
                        ?.copyWith(color: inkMuted, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: balanceHidden ? _mask : amount.format(total),
                    style: textTheme.displaySmall?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ]),
              ),
            ),
          ),
          if (hasIncompleteBalance) ...[
            const SizedBox(height: 2),
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
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  child: _MonthTile(
                    label: 'In this month',
                    value: monthIn == null
                        ? '–'
                        : balanceHidden
                            ? _mask
                            : '+${amount.format(monthIn)}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MonthTile(
                    label: 'Out this month',
                    value: monthOut == null
                        ? '–'
                        : balanceHidden
                            ? _mask
                            : '\u2212${amount.format(monthOut)}',
                  ),
                ),
              ],
            ),
          ),
          if (updatedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Updated ${_updatedLabel(updatedAt!)} from your SMS',
              style: textTheme.labelSmall?.copyWith(color: inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
