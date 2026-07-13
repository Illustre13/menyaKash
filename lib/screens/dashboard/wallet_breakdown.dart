import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../accounts/accounts_service.dart';

/// Per-account balances (spec Phase 8 Wallet Breakdown, e.g. "MTN MoMo
/// 200,000", "Equity 800,000"). Wires an existing, already-correct
/// read-model (`AccountsService.allAccountSummaries`) into the
/// dashboard for the first time — no new service code needed here.
class WalletBreakdownList extends StatelessWidget {
  const WalletBreakdownList({super.key, required this.summaries, required this.currency});

  final List<AccountSummary> summaries;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No accounts yet — add one in Settings.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      children: summaries.map((summary) {
        final label = summary.account.label.isNotEmpty
            ? summary.account.label
            : summary.providerDisplayName;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ),
              Text(
                summary.currentBalance != null
                    ? currency.format(summary.currentBalance)
                    : 'Balance unknown',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
