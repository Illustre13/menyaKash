import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../accounts/accounts_service.dart';
import '../../analytics/analytics_service.dart';
import '../../data/database.dart';
import '../../theme/app_theme.dart';
import '../../theme/provider_assets.dart';

/// Building blocks for the redesigned Home tab (screen 10): quick-action
/// tiles, the "N transactions need a category" prompt, the Accounts list
/// and the Recent activity rows. Kept out of home_screen.dart so that
/// file stays about state and navigation.

/// Section title with an optional action link. Unlike the shared
/// [SectionHeader], the title shrinks (ellipsis) instead of pushing the
/// action off a narrow screen.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// One rounded-square quick action. [accent] is the orange "Send" tile.
class HomeQuickAction extends StatelessWidget {
  const HomeQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent ? AppBrand.orangeLight : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  // Dark ink on the orange tile: white on #F5A623 fails
                  // contrast (see AppBrand's orange notes).
                  color: accent ? AppBrand.inkPrimaryLight : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style:
                    Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "94 transactions need a category" — progress toward a fully sorted
/// ledger, with Review opening the Categorize screen. Callers hide it
/// when nothing is left to sort.
class CategorizePromptCard extends StatelessWidget {
  const CategorizePromptCard({super.key, required this.ratio, required this.onReview});

  final CategorizationRatio ratio;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final count = ratio.needsReviewCount;
    final percent = (ratio.ratio * 100).floor();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppBrand.orangeLight.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.sell_outlined, size: 18, color: scheme.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${NumberFormat.decimalPattern().format(count)} '
                        'transaction${count == 1 ? '' : 's'} need${count == 1 ? 's' : ''} a category',
                        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sort them to see where your money really goes.',
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio.ratio,
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: AppBrand.statusGood,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('$percent%', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: onReview,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Review'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The Accounts list: logo, name, provider type, balance. Balances obey
/// Home's hide toggle, same as the hero card.
class AccountsList extends StatelessWidget {
  const AccountsList({
    super.key,
    required this.summaries,
    required this.categoryByCode,
    required this.balanceHidden,
  });

  final List<AccountSummary> summaries;

  /// providerCode → FinancialProviders.category ('mobile_money' | 'bank').
  final Map<String, String> categoryByCode;
  final bool balanceHidden;

  static String _typeLabel(String? category) => switch (category) {
        'bank' => 'Bank',
        'mobile_money' => 'Mobile money',
        _ => 'Account',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final amount = NumberFormat.decimalPattern();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          children: [
            for (final (i, summary) in summaries.indexed) ...[
              if (i > 0) Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.3)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    ProviderLogo(
                      providerCode: summary.providerCode,
                      displayName: summary.providerDisplayName,
                      size: 34,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.account.label.isNotEmpty
                                ? summary.account.label
                                : summary.providerDisplayName,
                            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _typeLabel(categoryByCode[summary.providerCode]),
                            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      balanceHidden
                          ? '••••••'
                          : summary.currentBalance != null
                              ? amount.format(summary.currentBalance)
                              : 'Unknown',
                      style: summary.currentBalance != null || balanceHidden
                          ? text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            )
                          : text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One Recent activity row: initials avatar, counterparty, "Today 08:54 ·
/// MTN MoMo", signed amount and, when the SMS reported one, the fee.
class ActivityRow extends StatelessWidget {
  const ActivityRow({
    super.key,
    required this.transaction,
    required this.providerName,
    required this.isTransfer,
    required this.onTap,
  });

  final Transaction transaction;
  final String? providerName;
  final bool isTransfer;
  final VoidCallback onTap;

  static const _inbound = {
    TransactionType.received,
    TransactionType.deposit,
    TransactionType.reversed,
  };

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final letters = words.length == 1
        ? words.first.substring(0, words.first.length.clamp(0, 2))
        : '${words.first[0]}${words[1][0]}';
    return letters.toUpperCase();
  }

  static String _fallbackTitle(TransactionType type) => switch (type) {
        TransactionType.received => 'Money received',
        TransactionType.sent => 'Money sent',
        TransactionType.payment => 'Payment',
        TransactionType.withdrawal => 'Cash withdrawal',
        TransactionType.deposit => 'Cash deposit',
        TransactionType.airtime => 'Airtime',
        TransactionType.bankTransfer => 'Bank transfer',
        TransactionType.reversed => 'Reversal',
        TransactionType.fee => 'Fee',
        TransactionType.unknown => 'Transaction',
      };

  static String _when(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final time = DateFormat('HH:mm').format(at);
    if (day == today) return 'Today $time';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday $time';
    return '${DateFormat('d MMM').format(at)} $time';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final tx = transaction;
    final title = (tx.counterparty?.trim().isNotEmpty ?? false)
        ? tx.counterparty!.trim()
        : _fallbackTitle(tx.type);
    final inbound = _inbound.contains(tx.type);
    final amount = NumberFormat.decimalPattern().format(tx.amount);
    final amountColor = isTransfer
        ? AppBrand.transfer(brightness)
        : inbound
            ? AppBrand.income(brightness)
            : scheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: scheme.primary.withValues(alpha: 0.14),
              child: Text(
                _initials(title),
                style: text.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [_when(tx.timestamp), if (providerName != null) providerName!].join(' · '),
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${inbound ? '+' : '−'}$amount',
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (tx.fee > 0)
                  Text(
                    '+${NumberFormat.decimalPattern().format(tx.fee)} fee',
                    style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
