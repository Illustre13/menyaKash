import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../theme/app_theme.dart';

/// Lookup maps a transaction list loads ONCE per build and shares
/// across every row — replaces the previous per-row FutureBuilder +
/// query pattern (sprint #12/#13 performance note).
class TransactionTileContext {
  const TransactionTileContext({
    required this.categoryNames,
    required this.providerNames,
    required this.accountLabels,
  });

  final Map<int, String> categoryNames;
  final Map<int, String> providerNames;
  final Map<int, String> accountLabels;
}

/// Modern banking-style transaction row (sprint #12): direction icon
/// (green in / red out / blue transfer), signed colored amount,
/// merchant, category + provider badges, account and timestamp.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.tx,
    required this.lookups,
    required this.onEditCategory,
  });

  final Transaction tx;
  final TransactionTileContext lookups;
  final VoidCallback onEditCategory;

  static const _inbound = {TransactionType.received, TransactionType.deposit};

  ({IconData icon, Color color, String sign}) _direction() {
    if (tx.type == TransactionType.bankTransfer) {
      return (icon: Icons.swap_horiz, color: const Color(0xFF1E6FD9), sign: '−');
    }
    if (_inbound.contains(tx.type)) {
      return (icon: Icons.arrow_downward, color: AppBrand.statusGood, sign: '+');
    }
    return (icon: Icons.arrow_upward, color: AppBrand.statusCritical, sign: '−');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currency = NumberFormat.currency(symbol: 'RWF ', decimalDigits: 0);
    final direction = _direction();
    final categoryName =
        tx.categoryId != null ? lookups.categoryNames[tx.categoryId!] : null;
    final providerName =
        tx.providerId != null ? lookups.providerNames[tx.providerId!] : null;
    final accountLabel =
        tx.accountId != null ? lookups.accountLabels[tx.accountId!] : null;

    return InkWell(
      onTap: onEditCategory,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: direction.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(direction.icon, color: direction.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.counterparty ?? _typeLabel(tx.type),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Badge(
                        label: categoryName ?? 'Uncategorized',
                        emphasized: categoryName == null,
                      ),
                      if (providerName != null) _Badge(label: providerName),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      DateFormat('d MMM y, HH:mm').format(tx.timestamp),
                      if (accountLabel != null) accountLabel,
                    ].join(' · '),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${direction.sign}${currency.format(tx.amount)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: direction.color,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  static String _typeLabel(TransactionType type) => switch (type) {
        TransactionType.received => 'Money received',
        TransactionType.sent => 'Money sent',
        TransactionType.payment => 'Payment',
        TransactionType.withdrawal => 'Withdrawal',
        TransactionType.deposit => 'Deposit',
        TransactionType.airtime => 'Airtime',
        TransactionType.bankTransfer => 'Bank transfer',
        TransactionType.reversed => 'Reversed',
        TransactionType.unknown => 'Transaction',
        TransactionType.fee => 'Transaction fee',
      };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.emphasized = false});

  final String label;

  /// Uncategorized gets the accent treatment — it's the one badge the
  /// user is supposed to act on.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: emphasized
            ? AppBrand.orangeLight.withValues(alpha: 0.18)
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500),
      ),
    );
  }
}
