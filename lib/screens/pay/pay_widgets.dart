import 'package:flutter/material.dart';

import '../../categorization/categorization_service.dart';
import '../../categorization/category_taxonomy.dart';
import '../../contacts/contacts_service.dart';
import '../../contacts/favorite_contacts_service.dart';
import '../../data/database.dart';
import '../../theme/app_theme.dart';
import '../../ussd/phone_normalizer.dart';
import '../../ussd/sim_selection_controller.dart';
import '../../ussd/ussd_dialer.dart';

// Building blocks shared by the Pay & services hub and Send money —
// moved out of pay_screen.dart unchanged apart from being public.

/// Dual-SIM row — shown only when the device genuinely has more than
/// one callable SIM ([UssdDialer.listSims] returning 2+). Reads/writes
/// through the shared, session-scoped [SimSelectionController] (review
/// batch item #2) rather than owning its own selection: shows which
/// SIM the session has already settled on (or "Not chosen yet" before
/// the first USSD action this session), with a "Change" action that
/// re-opens the same in-app chooser every other USSD call site uses.
class SimChooserRow extends StatelessWidget {
  const SimChooserRow({
    super.key,
    required this.sims,
    required this.controller,
    required this.onChanged,
  });

  final List<SimOption> sims;
  final SimSelectionController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final chosen = controller.chosenSlot;
    final label = chosen == null
        ? 'Not chosen yet'
        : sims.firstWhere((s) => s.simSlotIndex == chosen, orElse: () => sims.first).label;

    return Row(
      children: [
        Icon(Icons.sim_card_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text('Dial with', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: () async {
            await controller.reselect(context);
            onChanged();
          },
          child: const Text('Change'),
        ),
      ],
    );
  }
}

class PayContactPicker extends StatefulWidget {
  const PayContactPicker({
    super.key,
    required this.contactsService,
    required this.favoriteContactsService,
    required this.selected,
    required this.onSelected,
    this.initialQuery = '',
  });

  /// Pre-fills the contact search (Send money's "To" field typed a name).
  final String initialQuery;

  final ContactsService contactsService;
  final FavoriteContactsService favoriteContactsService;
  final ContactOption? selected;
  final ValueChanged<ContactOption> onSelected;

  @override
  State<PayContactPicker> createState() => _PayContactPickerState();
}

class _PayContactPickerState extends State<PayContactPicker> {
  bool? _hasPermission;
  List<ContactOption> _contacts = const [];
  Set<String> _favorites = const {};
  late String _query = widget.initialQuery;
  late final _searchController = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final granted = await widget.contactsService.hasPermission();
    if (!mounted) return;
    setState(() => _hasPermission = granted);
    if (granted) _load();
  }

  Future<void> _requestAndLoad() async {
    final granted = await widget.contactsService.requestPermission();
    if (!mounted) return;
    setState(() => _hasPermission = granted);
    if (granted) _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.contactsService.loadContactsWithPhoneNumbers(),
      widget.favoriteContactsService.favoritedNumbers(),
    ]);
    if (!mounted) return;
    setState(() {
      _contacts = results[0] as List<ContactOption>;
      _favorites = results[1] as Set<String>;
    });
  }

  Future<void> _toggleFavorite(ContactOption contact) async {
    final normalized = PhoneNormalizer.normalizeRwandanMobile(contact.phoneNumber);
    if (normalized == null) return;
    if (_favorites.contains(normalized)) {
      await widget.favoriteContactsService.unfavorite(contact.phoneNumber);
    } else {
      await widget.favoriteContactsService.favorite(contact.phoneNumber);
    }
    if (mounted) setState(() {});
    final favorites = await widget.favoriteContactsService.favoritedNumbers();
    if (mounted) setState(() => _favorites = favorites);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPermission == null) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ));
    }

    if (_hasPermission == false) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Allow contacts access to pick a recipient by name '
                  'instead of typing their number.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _requestAndLoad, child: const Text('Allow access')),
            ],
          ),
        ),
      );
    }

    final filtered = _query.isEmpty
        ? _contacts
        : _contacts
            .where((c) => c.displayName.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    // Favorites first (spec #7), preserving relative order within each
    // group — a stable sort, not a re-shuffle every rebuild.
    bool isFavorite(ContactOption c) {
      final normalized = PhoneNormalizer.normalizeRwandanMobile(c.phoneNumber);
      return normalized != null && _favorites.contains(normalized);
    }

    final sorted = [...filtered]..sort((a, b) {
        final aFav = isFavorite(a) ? 0 : 1;
        final bFav = isFavorite(b) ? 0 : 1;
        return aFav.compareTo(bFav);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search contacts',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: sorted.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No matching contacts.'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final contact = sorted[index];
                    final isSelected = widget.selected?.phoneNumber == contact.phoneNumber;
                    final favorite = isFavorite(contact);
                    return ListTile(
                      leading: CircleAvatar(child: Text(contact.displayName.characters.first)),
                      title: Text(contact.displayName),
                      subtitle: Text(contact.phoneNumber),
                      selected: isSelected,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              favorite ? Icons.favorite : Icons.favorite_border,
                              color:
                                  favorite ? AppBrand.expense(Theme.of(context).brightness) : null,
                              size: 20,
                            ),
                            tooltip: favorite ? 'Remove from favorites' : 'Add to favorites',
                            onPressed: () => _toggleFavorite(contact),
                          ),
                          if (isSelected) const Icon(Icons.check_circle),
                        ],
                      ),
                      onTap: () => widget.onSelected(contact),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Inline category selector (category-before-dialing spec): a
/// horizontally scrollable row of every existing category as chips,
/// picked once per payment. Deliberately no "create new category"
/// action here — Pay screen is a fast, in-the-moment flow, and every
/// category worth having already exists by the time someone is
/// actually paying (created earlier via the Categorize screen).
class CategoryPickerRow extends StatefulWidget {
  const CategoryPickerRow({
    super.key,
    required this.categorizationService,
    required this.selected,
    required this.onSelected,
  });

  final CategorizationService categorizationService;
  final Category? selected;
  final ValueChanged<Category> onSelected;

  @override
  State<CategoryPickerRow> createState() => _CategoryPickerRowState();
}

class _CategoryPickerRowState extends State<CategoryPickerRow> {
  late Future<List<Category>> _categories;

  @override
  void initState() {
    super.initState();
    _categories = widget.categorizationService.allCategories();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: _categories,
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const [];
        if (categories.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No categories yet — add one from the Categorize screen first.'),
          );
        }
        return SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = widget.selected?.id == category.id;
              return InkWell(
                onTap: () => widget.onSelected(category),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 68,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CategoryAvatar(categoryName: category.name, size: 32),
                      const SizedBox(height: 4),
                      Text(
                        category.name,
                        style: Theme.of(context).textTheme.labelSmall,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
