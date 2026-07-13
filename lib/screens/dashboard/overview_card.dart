import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../accounts/accounts_service.dart';

/// Total balance across every account (spec Phase 8 Overview Card).
/// Sums only accounts with a known [AccountSummary.currentBalance] —
/// some providers (Equity, confirmed in docs/SMS_PATTERN_LIBRARY.md)
/// never report a running balance in their SMS at all, so a null there
/// means "unknown," not "zero." Silently summing null as 0 would
/// understate the real total without telling the user; this card
/// surfaces that gap explicitly instead.
class OverviewCard extends StatelessWidget {
  const OverviewCard({super.key, required this.summaries, required this.currency});

  final List<AccountSummary> summaries;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const SizedBox.shrink();

    final total = summaries.fold<double>(0, (sum, s) => sum + (s.currentBalance ?? 0));
    final hasIncompleteBalance = summaries.any((s) => s.currentBalance == null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Balance', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(
            currency.format(total),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (hasIncompleteBalance) ...[
            const SizedBox(height: 6),
            Text(
              'Some accounts don\'t report a running balance — total may be incomplete.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}
