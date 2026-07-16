import 'package:flutter/material.dart';

import '../budgets/budget_service.dart';
import '../categorization/category_taxonomy.dart';
import '../data/database.dart';
import '../theme/app_theme.dart';
import '../widgets/design_system.dart';

/// The Budgets tab (UI redesign): one animated progress ring per
/// budgeted category, health-colored (green under 80%, amber
/// approaching, red over), with a month summary up top and a bottom
/// sheet to add or edit budgets. Spend is computed live for the
/// current calendar month — same semantics as Insights, so the two
/// tabs never disagree.
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key, required this.budgetService});

  final BudgetService budgetService;

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  late Future<List<BudgetStatus>> _statuses;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _statuses = widget.budgetService.statusesForMonth(DateTime.now());
  }

  Future<void> _addOrEdit({BudgetStatus? existing}) async {
    final available = existing == null
        ? await widget.budgetService.categoriesWithoutBudget()
        : <Category>[existing.category];
    if (!mounted) return;

    if (existing == null && available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Every category already has a budget. Create categories '
              'from any transaction first.'),
        ),
      );
      return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _BudgetSheet(
        categories: available,
        initial: existing,
        onSave: (categoryId, limit) =>
            widget.budgetService.setBudget(categoryId: categoryId, monthlyLimit: limit),
        onRemove: existing == null
            ? null
            : () => widget.budgetService.removeBudget(existing.category.id),
      ),
    );
    if (saved == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('New budget'),
      ),
      body: FutureBuilder<List<BudgetStatus>>(
        future: _statuses,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: TransactionListSkeleton(rows: 4),
            );
          }
          final statuses = snapshot.data!;
          if (statuses.isEmpty) {
            return EmptyState(
              icon: Icons.track_changes,
              title: 'No budgets yet',
              message: 'Set a monthly limit for a category — like Food or '
                  'Transport — and watch the ring fill as the month goes on.',
              ctaLabel: 'Create your first budget',
              onCta: () => _addOrEdit(),
            );
          }

          final totalBudget = statuses.fold<double>(0, (s, b) => s + b.budget.monthlyLimit);
          final totalSpent = statuses.fold<double>(0, (s, b) => s + b.spentThisMonth);

          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      ProgressRing(
                        value: totalBudget == 0 ? 0 : totalSpent / totalBudget,
                        color: _healthColor(context, totalBudget == 0 ? 0 : totalSpent / totalBudget),
                        size: 72,
                        child: Text(
                          totalBudget == 0
                              ? '—'
                              : '${((totalSpent / totalBudget) * 100).round()}%',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('This month', style: Theme.of(context).textTheme.labelMedium),
                            const SizedBox(height: 4),
                            Text(
                              '${rwf.format(totalSpent)} of ${rwf.format(totalBudget)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              totalSpent <= totalBudget
                                  ? '${rwf.format(totalBudget - totalSpent)} left to spend'
                                  : '${rwf.format(totalSpent - totalBudget)} over budget',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final status in statuses) ...[
                  _BudgetCard(status: status, onTap: () => _addOrEdit(existing: status)),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

Color _healthColor(BuildContext context, double ratio) {
  if (ratio > 1.0) return AppBrand.expense(Theme.of(context).brightness);
  if (ratio >= 0.8) return AppBrand.orangeButtonLight;
  return AppBrand.income(Theme.of(context).brightness);
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.status, required this.onTap});

  final BudgetStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _healthColor(context, status.ratio);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          ProgressRing(
            value: status.ratio,
            color: color,
            size: 56,
            strokeWidth: 6,
            child: Icon(categoryStyle(status.category.name).$1, size: 20, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        status.category.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (status.isOver || status.isNearLimit) ...[
                      Icon(
                        status.isOver ? Icons.error_rounded : Icons.warning_amber_rounded,
                        size: 16,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.isOver ? 'Over' : 'Almost there',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: color, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${rwf.format(status.spentThisMonth)} of ${rwf.format(status.budget.monthlyLimit)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                // Animated linear echo of the ring, for scanability in
                // a vertical list.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: status.ratio.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      color: color,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet({
    required this.categories,
    required this.initial,
    required this.onSave,
    this.onRemove,
  });

  final List<Category> categories;
  final BudgetStatus? initial;
  final Future<void> Function(int categoryId, double limit) onSave;
  final Future<void> Function()? onRemove;

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late int? _categoryId =
      widget.initial?.category.id ?? (widget.categories.length == 1 ? widget.categories.first.id : null);
  late final _amountController = TextEditingController(
    text: widget.initial != null ? widget.initial!.budget.monthlyLimit.toStringAsFixed(0) : '',
  );

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEdit ? 'Edit budget' : 'New budget',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _categoryId,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final c in widget.categories)
                DropdownMenuItem(value: c.id, child: Text(c.name)),
            ],
            onChanged: isEdit ? null : (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Monthly limit (RWF)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final limit = double.tryParse(_amountController.text.trim().replaceAll(',', ''));
              final categoryId = _categoryId;
              if (limit == null || limit <= 0 || categoryId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pick a category and enter a limit above zero.')),
                );
                return;
              }
              await widget.onSave(categoryId, limit);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: Text(isEdit ? 'Save changes' : 'Create budget'),
          ),
          if (widget.onRemove != null)
            TextButton(
              onPressed: () async {
                await widget.onRemove!();
                if (context.mounted) Navigator.pop(context, true);
              },
              style: TextButton.styleFrom(
                foregroundColor: AppBrand.expense(Theme.of(context).brightness),
              ),
              child: const Text('Remove budget'),
            ),
        ],
      ),
    );
  }
}
