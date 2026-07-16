import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../categorization/categorization_service.dart';
import '../categorization/category_taxonomy.dart';
import '../data/database.dart';
import '../widgets/design_system.dart';
import '../widgets/transaction_tile.dart';
import 'categorize_screen.dart';
import 'review_unparsed_screen.dart';

enum _Filter { all, income, expenses, uncategorized }

/// The Transactions tab (UI redesign): live feed of every transaction,
/// grouped by day, with search, direction filters, and
/// swipe-to-categorize. The heavier code-bank tooling (bulk-similar,
/// code renaming) stays on the existing CategorizeScreen, reachable
/// from the app bar, as is the unparsed-message Review queue.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    required this.db,
    required this.categorizationService,
  });

  final AppDatabase db;
  final CategorizationService categorizationService;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  _Filter _filter = _Filter.all;
  String _query = '';

  Map<int, String> _categoryNames = const {};
  Map<int, String> _accountLabels = const {};
  Map<int, String> _providerNames = const {};
  Map<int, String> _providerCodes = const {};
  Set<int> _transferIds = const {};
  bool _lookupsReady = false;

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final service = widget.categorizationService;
    final results = await Future.wait([
      service.categoryNamesById(),
      service.accountLabelsById(),
      service.providerNamesById(),
      service.providerCodesById(),
      service.linkedTransferTransactionIds(),
    ]);
    if (!mounted) return;
    setState(() {
      _categoryNames = results[0] as Map<int, String>;
      _accountLabels = results[1] as Map<int, String>;
      _providerNames = results[2] as Map<int, String>;
      _providerCodes = results[3] as Map<int, String>;
      _transferIds = results[4] as Set<int>;
      _lookupsReady = true;
    });
  }

  bool _matches(Transaction tx) {
    final kind = moneyKindOf(tx.type, isTransfer: _transferIds.contains(tx.id));
    final passesFilter = switch (_filter) {
      _Filter.all => true,
      _Filter.income => kind == MoneyKind.income,
      _Filter.expenses => kind == MoneyKind.expense,
      _Filter.uncategorized => tx.categoryId == null && kind != MoneyKind.transfer,
    };
    if (!passesFilter) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    final category = tx.categoryId != null ? _categoryNames[tx.categoryId!] : null;
    return (tx.counterparty?.toLowerCase().contains(q) ?? false) ||
        (category?.toLowerCase().contains(q) ?? false) ||
        rwf.format(tx.amount).toLowerCase().contains(q);
  }

  Future<void> _openCategorizeSheet(Transaction tx) async {
    final categories = await widget.categorizationService.allCategories();
    if (!mounted) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _CategorySheet(
        categories: categories,
        transaction: tx,
        categoryNames: _categoryNames,
        onCreate: (name) => widget.categorizationService.createCategory(name),
      ),
    );
    if (selected == null || !mounted) return;

    // Prefer the standing counterparty mapping (auto-categorizes future
    // messages from the same code) when there is a counterparty; fall
    // back to a one-off for counterparty-less rows like deposits.
    if (tx.counterparty != null && tx.counterparty!.trim().isNotEmpty) {
      await widget.categorizationService.categorizeCounterparty(tx.counterparty!, selected);
    } else {
      await widget.categorizationService.categorizeSingleTransaction(tx.id, selected);
    }
    await _loadLookups(); // a new category may have been created
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            tooltip: 'Manage codes',
            icon: const Icon(Icons.style_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CategorizeScreen(service: widget.categorizationService),
            )),
          ),
          IconButton(
            tooltip: 'Review unrecognized messages',
            icon: const Icon(Icons.rule_folder_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ReviewUnparsedScreen(db: widget.db),
            )),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search merchant, category, amount',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: SegmentedButton<_Filter>(
              segments: const [
                ButtonSegment(value: _Filter.all, label: Text('All')),
                ButtonSegment(value: _Filter.income, label: Text('In')),
                ButtonSegment(value: _Filter.expenses, label: Text('Out')),
                ButtonSegment(value: _Filter.uncategorized, label: Text('To review')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Transaction>>(
              stream: widget.categorizationService.watchAll(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !_lookupsReady) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: TransactionListSkeleton(rows: 8),
                  );
                }
                final visible = snapshot.data!.where(_matches).toList();
                if (visible.isEmpty) {
                  return EmptyState(
                    icon: _query.isEmpty ? Icons.receipt_long_outlined : Icons.search_off,
                    title: _query.isEmpty ? 'Nothing here yet' : 'No matches',
                    message: _query.isEmpty
                        ? (_filter == _Filter.uncategorized
                            ? 'Everything is categorized — nice work.'
                            : 'Transactions appear here as your money moves.')
                        : 'Try a different search or filter.',
                  );
                }
                return _GroupedList(
                  transactions: visible,
                  categoryNames: _categoryNames,
                  accountLabels: _accountLabels,
                  providerNames: _providerNames,
                  providerCodes: _providerCodes,
                  transferIds: _transferIds,
                  onCategorize: _openCategorizeSheet,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({
    required this.transactions,
    required this.categoryNames,
    required this.accountLabels,
    required this.providerNames,
    required this.providerCodes,
    required this.transferIds,
    required this.onCategorize,
  });

  final List<Transaction> transactions;
  final Map<int, String> categoryNames;
  final Map<int, String> accountLabels;
  final Map<int, String> providerNames;
  final Map<int, String> providerCodes;
  final Set<int> transferIds;
  final ValueChanged<Transaction> onCategorize;

  @override
  Widget build(BuildContext context) {
    // Day-grouped: a sticky-feeling date header before each day's rows,
    // newest first (watchAll already orders by timestamp desc).
    final items = <Widget>[];
    DateTime? currentDay;
    final headerFmt = DateFormat('EEEE, d MMMM');

    for (final tx in transactions) {
      final day = DateTime(tx.timestamp.year, tx.timestamp.month, tx.timestamp.day);
      if (day != currentDay) {
        currentDay = day;
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
          child: Text(
            _dayLabel(day, headerFmt),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ));
      }

      final isTransfer = transferIds.contains(tx.id);
      final tile = TransactionTile(
        transaction: tx,
        categoryName: tx.categoryId != null ? categoryNames[tx.categoryId!] : null,
        accountLabel: tx.accountId != null ? accountLabels[tx.accountId!] : null,
        providerCode: tx.providerId != null ? providerCodes[tx.providerId!] : null,
        providerName: tx.providerId != null ? providerNames[tx.providerId!] : null,
        isTransfer: isTransfer,
        onTap: () => onCategorize(tx),
      );

      // Swipe → categorize. confirmDismiss opens the sheet and always
      // returns false: the row is acted on, never removed — deleting
      // history by swipe has no place in a financial ledger.
      items.add(Dismissible(
        key: ValueKey('tx-${tx.id}'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          onCategorize(tx);
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.label_outline, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Categorize',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        child: tile,
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: items,
    );
  }

  static String _dayLabel(DateTime day, DateFormat fmt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return fmt.format(day);
  }
}

/// Bottom sheet: pick a category (or create one inline). Pops with the
/// chosen category id.
class _CategorySheet extends StatefulWidget {
  const _CategorySheet({
    required this.categories,
    required this.transaction,
    required this.categoryNames,
    required this.onCreate,
  });

  final List<Category> categories;
  final Transaction transaction;
  final Map<int, String> categoryNames;
  final Future<int> Function(String name) onCreate;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _newCategoryController = TextEditingController();

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final current = tx.categoryId != null ? widget.categoryNames[tx.categoryId!] : null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.counterparty ?? 'Categorize transaction',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    current != null ? 'Currently: $current' : 'Pick a category',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final category in widget.categories)
                    ListTile(
                      leading: CategoryAvatar(categoryName: category.name, size: 36),
                      title: Text(category.name),
                      trailing: tx.categoryId == category.id
                          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () => Navigator.pop(context, category.id),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCategoryController,
                      decoration: const InputDecoration(
                        hintText: 'New category…',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () async {
                      final name = _newCategoryController.text.trim();
                      if (name.isEmpty) return;
                      final id = await widget.onCreate(name);
                      if (context.mounted) Navigator.pop(context, id);
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
