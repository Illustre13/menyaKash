import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../analytics/analytics_service.dart';
import '../../analytics/period.dart';
import '../../categorization/categorization_service.dart';
import '../../data/database.dart';
import '../../theme/app_theme.dart';

/// Shown in place of Insights' category chart while most of the
/// period's transactions are still uncategorized ("Your categories
/// aren't ready yet"). Shows progress, lets the user sort the most
/// recent uncategorized transaction right here with one tap, and links
/// to the full Categorize screen.
///
/// Sorting by tap uses [CategorizationService.categorizeCounterparty]
/// when the transaction has a counterparty, so the person/merchant is
/// remembered and their future transactions are categorized on ingest
/// — the same rule the Categorize screen applies.
class SortPromptCard extends StatefulWidget {
  const SortPromptCard({
    super.key,
    required this.ratio,
    required this.period,
    required this.onSortAll,
    this.categorizationService,
  });

  final CategorizationRatio ratio;
  final Period period;
  final VoidCallback onSortAll;

  /// Null hides the inline transaction (nothing to categorize with).
  final CategorizationService? categorizationService;

  @override
  State<SortPromptCard> createState() => _SortPromptCardState();
}

/// The quick-pick chips, in order, when these default categories exist.
const _quickPickNames = [
  'Transport',
  'Dining & Food',
  'Family & Friends',
  'Bills & Utilities',
];

class _SortPromptCardState extends State<SortPromptCard> {
  Stream<List<Transaction>>? _uncategorized;
  List<Category> _quickPicks = const [];
  Map<int, String> _providerNames = const {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final service = widget.categorizationService;
    if (service == null) return;
    _uncategorized = service.watchUncategorized();
    _loadLookups(service);
  }

  Future<void> _loadLookups(CategorizationService service) async {
    final categories = await service.allCategories();
    final providerNames = await service.providerNamesById();
    if (!mounted) return;
    final byName = {for (final c in categories) c.name: c};
    final picks = [
      for (final name in _quickPickNames)
        if (byName[name] != null) byName[name]!,
    ];
    // A user who renamed/deleted the defaults still gets some chips.
    if (picks.length < 4) {
      picks.addAll(categories.where((c) => !picks.contains(c)).take(4 - picks.length));
    }
    setState(() {
      _quickPicks = picks;
      _providerNames = providerNames;
    });
  }

  /// The newest uncategorized transaction inside the period, falling
  /// back to the newest overall (the stream is already newest-first).
  Transaction? _pick(List<Transaction> all) {
    for (final tx in all) {
      if (!tx.timestamp.isBefore(widget.period.start) && tx.timestamp.isBefore(widget.period.end)) {
        return tx;
      }
    }
    return all.isEmpty ? null : all.first;
  }

  Future<void> _assign(Transaction tx, int categoryId, String categoryName) async {
    final service = widget.categorizationService!;
    setState(() => _saving = true);
    final counterparty = tx.counterparty;
    if (counterparty != null && counterparty.isNotEmpty) {
      await service.categorizeCounterparty(counterparty, categoryId);
    } else {
      await service.categorizeSingleTransaction(tx.id, categoryId);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          counterparty != null && counterparty.isNotEmpty
              ? 'Saved as $categoryName. We’ll remember $counterparty next time.'
              : 'Saved as $categoryName.',
        ),
      ),
    );
  }

  Future<void> _newCategory(Transaction tx) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. School fees'),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    final id = await widget.categorizationService!.createCategory(name);
    await _assign(tx, id, name);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ratio = widget.ratio;
    final left = ratio.needsReviewCount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your categories aren’t ready yet',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Sort a few transactions and this chart will fill in. We’ll remember each '
            'person or merchant next time.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
                    color: AppBrand.income(Theme.of(context).brightness),
                    backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(ratio.ratio * 100).round()}% · $left left',
                style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          if (_uncategorized != null)
            StreamBuilder<List<Transaction>>(
              stream: _uncategorized,
              builder: (context, snapshot) {
                final tx = _pick(snapshot.data ?? const []);
                if (tx == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _InlineTransaction(
                    transaction: tx,
                    providerName: tx.providerId == null ? null : _providerNames[tx.providerId!],
                    categories: _quickPicks,
                    enabled: !_saving,
                    onPick: (category) => _assign(tx, category.id, category.name),
                    onNew: () => _newCategory(tx),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: widget.onSortAll,
            child: Text('Sort all $left'),
          ),
        ],
      ),
    );
  }
}

class _InlineTransaction extends StatelessWidget {
  const _InlineTransaction({
    required this.transaction,
    required this.providerName,
    required this.categories,
    required this.enabled,
    required this.onPick,
    required this.onNew,
  });

  final Transaction transaction;
  final String? providerName;
  final List<Category> categories;
  final bool enabled;
  final ValueChanged<Category> onPick;
  final VoidCallback onNew;

  static String _when(DateTime t) {
    final now = DateTime.now();
    final time = DateFormat.Hm().format(t);
    if (t.year == now.year && t.month == now.month && t.day == now.day) return 'Today $time';
    final yesterday = now.subtract(const Duration(days: 1));
    if (t.year == yesterday.year && t.month == yesterday.month && t.day == yesterday.day) {
      return 'Yesterday $time';
    }
    return DateFormat('d MMM, HH:mm').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tx = transaction;
    final outbound = tx.type != TransactionType.received && tx.type != TransactionType.deposit;
    final amount = NumberFormat.decimalPattern().format(tx.amount);
    final meta = [_when(tx.timestamp), if (providerName != null) providerName!].join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.counterparty ?? 'Unknown',
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(meta, style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Text(
                '${outbound ? '−' : '+'}$amount',
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final category in categories)
                ActionChip(
                  label: Text(_shortName(category.name)),
                  visualDensity: VisualDensity.compact,
                  onPressed: enabled ? () => onPick(category) : null,
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('New'),
                visualDensity: VisualDensity.compact,
                onPressed: enabled ? onNew : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Short chip labels for the default quick picks; any other name
  /// (renamed or user-made) shows as-is.
  static String _shortName(String name) =>
      const {
        'Dining & Food': 'Food',
        'Family & Friends': 'Family',
        'Bills & Utilities': 'Bills',
      }[name] ??
      name;
}
