import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../categorization/category_taxonomy.dart';
import '../data/database.dart';
import '../theme/provider_assets.dart';
import 'design_system.dart';

/// One transaction row, banking-app style (UI sprint): direction icon
/// tinted by money kind, merchant/counterparty, category + account
/// context line, colored signed amount, provider logo badge. Identity
/// never rests on color alone — the direction icon and the sign carry
/// it too.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.categoryName,
    this.accountLabel,
    this.providerCode,
    this.providerName,
    this.isTransfer = false,
    this.onTap,
  });

  final Transaction transaction;
  final String? categoryName;
  final String? accountLabel;
  final String? providerCode;
  final String? providerName;

  /// True when this row is one side of a matched internal transfer —
  /// rendered with the transfer treatment instead of income/expense.
  final bool isTransfer;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kind = moneyKindOf(transaction.type, isTransfer: isTransfer);
    final kindColor = kind.color(context);
    final title = transaction.counterparty ?? _typeLabel(transaction.type);
    final contextParts = <String>[
      if (categoryName != null) categoryName!,
      if (accountLabel != null) accountLabel!,
      DateFormat('d MMM, HH:mm').format(transaction.timestamp),
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            // Direction glyph in a tinted squircle; the provider logo
            // rides its corner so both identities read at a glance.
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kindColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    categoryName != null ? categoryStyle(categoryName).$1 : kind.icon,
                    color: kindColor,
                    size: 22,
                  ),
                ),
                if (providerCode != null)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: ProviderLogo(
                      providerCode: providerCode!,
                      displayName: providerName ?? '?',
                      size: 18,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contextParts.join(' · '),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                AmountText(transaction.amount, kind: kind),
                if (isTransfer)
                  Text(
                    'Transfer',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: kindColor,
                        ),
                  )
                else if (categoryName == null)
                  Text(
                    'Uncategorized',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
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
