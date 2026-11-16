import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../categorization/categorization_service.dart';
import '../categorization/category_taxonomy.dart';
import '../data/database.dart';
import 'planned_payment_service.dart';

/// Shows every [PlannedPayments] row (category-before-dialing spec):
/// pending (still within the match window), matched (a real
/// transaction confirmed it and got the chosen category), and expired
/// (no confirming SMS ever arrived — the payment likely failed, was
/// cancelled on the network side, or the confirming SMS is just slow).
/// Never itself a spending record — see [PlannedPayments]'s own doc.
class PlannedPaymentLogScreen extends StatelessWidget {
  const PlannedPaymentLogScreen({
    super.key,
    required this.plannedPaymentService,
    required this.categorizationService,
  });

  final PlannedPaymentService plannedPaymentService;
  final CategorizationService categorizationService;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'RWF ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Planned payments')),
      body: StreamBuilder<List<PlannedPayment>>(
        stream: plannedPaymentService.watchAll(),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nothing yet — a category you choose before dialing on the '
                  'Pay screen shows up here until the real payment SMS confirms it.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return FutureBuilder<Map<int, String>>(
            future: categorizationService.categoryNamesById(),
            builder: (context, categoryNamesSnapshot) {
              final categoryNames = categoryNamesSnapshot.data ?? const {};
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final categoryName = categoryNames[row.categoryId];
                  return ListTile(
                    leading: CategoryAvatar(categoryName: categoryName),
                    title: Text(row.recipient),
                    subtitle: Text(
                      '${categoryName ?? 'Uncategorized'} · ${_statusLabel(row.status)}',
                    ),
                    trailing: Text(
                      currency.format(row.amount),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _statusLabel(PlannedPaymentStatus status) => switch (status) {
        PlannedPaymentStatus.pending => 'Waiting for confirmation',
        PlannedPaymentStatus.matched => 'Confirmed',
        PlannedPaymentStatus.expired => 'No confirmation arrived',
      };
}
