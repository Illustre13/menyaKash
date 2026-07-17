import 'package:flutter/material.dart';

import '../categorization/categorization_service.dart';
import '../categorization/category_taxonomy.dart';
import '../data/database.dart';
import 'widgets/skeleton_list.dart';
import 'widgets/transaction_tile.dart';

/// The "code bank" teaching moment. Four tabs:
///  - Uncategorized: transactions with no category yet, the main queue.
///  - All: every transaction, so an existing categorization can be
///    edited/reassigned after the fact.
///  - Frequent: counterparties ranked by how often they're paid — the
///    "most used MoMo code" phonebook, editable independent of any one
///    transaction.
///  - Manage categories: rename/delete categories themselves.
/// Assigning a category for a counterparty is remembered so future
/// transactions from that same code/person are categorized automatically.
class CategorizeScreen extends StatefulWidget {
  const CategorizeScreen({super.key, required this.service});

  final CategorizationService service;

  @override
  State<CategorizeScreen> createState() => _CategorizeScreenState();
}

class _CategorizeScreenState extends State<CategorizeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorize'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Uncategorized'),
            Tab(text: 'All transactions'),
            Tab(text: 'Frequent'),
            Tab(text: 'Manage categories'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TransactionListTab(
            service: widget.service,
            stream: widget.service.watchUncategorized(),
            emptyMessage: 'Everything is categorized.',
          ),
          _TransactionListTab(
            service: widget.service,
            stream: widget.service.watchAll(),
            emptyMessage: 'No transactions yet.',
          ),
          _FrequentCodesTab(service: widget.service),
          _ManageCategoriesTab(service: widget.service),
        ],
      ),
    );
  }
}

/// Shared body for the Uncategorized / All tabs (sprint #12): the
/// lookup maps (category/provider/account names) load ONCE per tab
/// build and are shared by every [TransactionTile] — the previous
/// implementation ran a FutureBuilder + category query per visible
/// row. Skeleton rows show while either the lookups or the first
/// stream event are still loading (sprint #13).
class _TransactionListTab extends StatefulWidget {
  const _TransactionListTab({
    required this.service,
    required this.stream,
    required this.emptyMessage,
  });

  final CategorizationService service;
  final Stream<List<Transaction>> stream;
  final String emptyMessage;

  @override
  State<_TransactionListTab> createState() => _TransactionListTabState();
}

class _TransactionListTabState extends State<_TransactionListTab> {
  late Future<TransactionTileContext> _lookups = _loadLookups();

  Future<TransactionTileContext> _loadLookups() async {
    return TransactionTileContext(
      categoryNames: await widget.service.categoryNamesById(),
      providerNames: await widget.service.providerNamesById(),
      accountLabels: await widget.service.accountLabelsById(),
    );
  }

  Future<void> _edit(Transaction tx) async {
    await _pickCategoryForTransaction(context, widget.service, tx);
    // A new category may have been created during the flow — refresh
    // the name map so its badge renders immediately.
    if (mounted) setState(() => _lookups = _loadLookups());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TransactionTileContext>(
      future: _lookups,
      builder: (context, lookupSnapshot) {
        final lookups = lookupSnapshot.data;
        return StreamBuilder<List<Transaction>>(
          stream: widget.stream,
          builder: (context, snapshot) {
            if (lookups == null || snapshot.connectionState == ConnectionState.waiting) {
              return const SkeletonList();
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(widget.emptyMessage, textAlign: TextAlign.center),
                ),
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
              itemBuilder: (context, index) {
                final tx = items[index];
                return TransactionTile(
                  tx: tx,
                  lookups: lookups,
                  onEditCategory: () => _edit(tx),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Shared category-picker flow used by both tabs. After the user assigns
/// a category, checks for other uncategorized transactions that look
/// like the same counterparty and offers a one-tap bulk-apply.
Future<void> _pickCategoryForTransaction(
  BuildContext context,
  CategorizationService service,
  Transaction tx,
) async {
  final categories = await service.allCategories();

  if (!context.mounted) return;
  final selected = await showModalBottomSheet<_CategorySelection>(
    context: context,
    builder: (context) => _CategoryPickerSheet(categories: categories),
  );
  if (selected == null) return;

  int categoryId;
  if (selected.newCategoryName != null) {
    categoryId = await service.createCategory(selected.newCategoryName!);
  } else {
    categoryId = selected.existingCategoryId!;
  }

  if (tx.counterparty != null) {
    await service.categorizeCounterparty(tx.counterparty!, categoryId);
  } else {
    await service.categorizeSingleTransaction(tx.id, categoryId);
  }

  final group = await service.findSimilarUncategorized(tx);
  if (group == null || !context.mounted) return;

  final applyToAll = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Apply to similar transactions?'),
      content: Text(
        'Found ${group.similar.length} other uncategorized transaction'
        '${group.similar.length == 1 ? '' : 's'} that look like the same '
        'counterparty. Categorize ${group.similar.length == 1 ? 'it' : 'them'} '
        'the same way?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No, just this one'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Apply to all'),
        ),
      ],
    ),
  );

  if (applyToAll == true) {
    await service.categorizeGroup(group, categoryId);
  }
}

class _CategorySelection {
  const _CategorySelection.existing(this.existingCategoryId) : newCategoryName = null;
  const _CategorySelection.newCategory(this.newCategoryName) : existingCategoryId = null;

  final int? existingCategoryId;
  final String? newCategoryName;
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({required this.categories});

  final List<Category> categories;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.label_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Choose a category', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.categories
                  .map((c) => ActionChip(
                        label: Text(c.name),
                        onPressed: () => Navigator.of(context)
                            .pop(_CategorySelection.existing(c.id)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'New category name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                if (value.trim().isEmpty) return;
                Navigator.of(context)
                    .pop(_CategorySelection.newCategory(value.trim()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The "most used MoMo code" phonebook: every counterparty ever paid,
/// ranked by frequency, with its current category (or none) shown
/// directly — so the codes you pay most are the easiest to find and
/// keep correctly labeled, independent of hunting through transactions.
class _FrequentCodesTab extends StatefulWidget {
  const _FrequentCodesTab({required this.service});

  final CategorizationService service;

  @override
  State<_FrequentCodesTab> createState() => _FrequentCodesTabState();
}

class _FrequentCodesTabState extends State<_FrequentCodesTab> {
  late Future<List<CodeUsage>> _usage = widget.service.mostUsedCounterparties();

  void _reload() => setState(() => _usage = widget.service.mostUsedCounterparties());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CodeUsage>>(
      future: _usage,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonList();
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No payment history yet — codes you pay will show up here, '
                'ranked by how often you use them.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final usage = items[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text('${usage.usageCount}'),
              ),
              title: Text(usage.label),
              subtitle: Text(usage.category?.name ?? 'Uncategorized'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _edit(usage),
            );
          },
        );
      },
    );
  }

  Future<void> _edit(CodeUsage usage) async {
    final categories = await widget.service.allCategories();
    if (!mounted) return;

    final result = await showModalBottomSheet<_CodeEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CodeEditSheet(usage: usage, categories: categories),
    );
    if (result == null) return;

    int categoryId;
    if (result.newCategoryName != null) {
      categoryId = await widget.service.createCategory(result.newCategoryName!);
    } else if (result.existingCategoryId != null) {
      categoryId = result.existingCategoryId!;
    } else {
      return; // no category chosen — nothing to save
    }

    await widget.service.updateCode(
      usage.code,
      categoryId: categoryId,
      displayName: result.displayName,
    );
    _reload();
  }
}

class _CodeEditResult {
  const _CodeEditResult({this.existingCategoryId, this.newCategoryName, this.displayName});
  final int? existingCategoryId;
  final String? newCategoryName;
  final String? displayName;
}

class _CodeEditSheet extends StatefulWidget {
  const _CodeEditSheet({required this.usage, required this.categories});

  final CodeUsage usage;
  final List<Category> categories;

  @override
  State<_CodeEditSheet> createState() => _CodeEditSheetState();
}

class _CodeEditSheetState extends State<_CodeEditSheet> {
  late final _nameController = TextEditingController(text: widget.usage.displayName);
  int? _selectedCategoryId;
  final _newCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.usage.category?.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.usage.code, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Friendly name (optional)',
                hintText: 'e.g. Kigali Supermarket',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Category', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.categories
                  .map((c) => ChoiceChip(
                        label: Text(c.name),
                        selected: _selectedCategoryId == c.id,
                        onSelected: (_) => setState(() => _selectedCategoryId = c.id),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCategoryController,
              decoration: const InputDecoration(
                labelText: 'Or create a new category',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _selectedCategoryId = null),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _canSave ? _save : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSave =>
      _selectedCategoryId != null || _newCategoryController.text.trim().isNotEmpty;

  void _save() {
    Navigator.of(context).pop(_CodeEditResult(
      existingCategoryId: _selectedCategoryId,
      newCategoryName:
          _newCategoryController.text.trim().isEmpty ? null : _newCategoryController.text.trim(),
      displayName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
    ));
  }
}

class _ManageCategoriesTab extends StatefulWidget {
  const _ManageCategoriesTab({required this.service});

  final CategorizationService service;

  @override
  State<_ManageCategoriesTab> createState() => _ManageCategoriesTabState();
}

class _ManageCategoriesTabState extends State<_ManageCategoriesTab> {
  late Future<List<Category>> _categories = widget.service.allCategories();

  void _reload() => setState(() => _categories = widget.service.allCategories());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addCategory,
              icon: const Icon(Icons.add),
              label: const Text('Add category'),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Category>>(
            future: _categories,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SkeletonList(rows: 5);
              }
              final categories = snapshot.data ?? const [];
              if (categories.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No categories yet — add one above, or create one from '
                      'the Categorize screen when labeling a transaction.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.separated(
                itemCount: categories.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return ListTile(
                    leading: CategoryAvatar(categoryName: category.name, size: 36),
                    title: Text(category.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Rename',
                          onPressed: () => _rename(category),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete',
                          onPressed: () => _delete(category),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Groceries'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    try {
      await widget.service.createCategory(name);
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A category named "$name" already exists.')),
      );
    }
  }

  Future<void> _rename(Category category) async {
    final controller = TextEditingController(text: category.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename category'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == category.name) return;
    await widget.service.renameCategory(category.id, newName);
    _reload();
  }

  Future<void> _delete(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Transactions labeled "${category.name}" will become '
          'uncategorized. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.service.deleteCategory(category.id);
    _reload();
  }
}
