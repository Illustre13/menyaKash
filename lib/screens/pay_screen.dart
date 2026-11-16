import 'dart:async';

import 'package:flutter/material.dart';

import '../categorization/categorization_service.dart';
import '../categorization/category_taxonomy.dart';
import '../contacts/contacts_service.dart';
import '../contacts/favorite_contacts_service.dart';
import '../data/database.dart';
import '../payments/planned_payment_log_screen.dart';
import '../payments/planned_payment_service.dart';
import '../theme/app_theme.dart';
import '../widgets/coming_soon_popup.dart';
import '../ussd/phone_normalizer.dart';
import '../ussd/sim_selection_controller.dart';
import '../ussd/ussd_builder.dart';
import '../ussd/ussd_dialer.dart';

enum _PayTarget { contact, frequentCode, manual }

/// Bypasses typing `*182*1*1*<number>*<amount>#` by hand: pick a
/// recipient from phone contacts or a previously-used MoMo code, enter
/// an amount, choose a category, and this builds the USSD string and
/// hands it to the native dialer. The user still presses call/send
/// themselves — this screen (and the UssdBuilder/UssdDialer underneath
/// it) never places a call or reads a USSD session on its own.
///
/// The chosen category is captured as a [PlannedPayments] row, NOT
/// written directly onto a [Transactions] row — see that table's own
/// doc for why. [SmsProcessor] reconciles it against the real
/// transaction once the confirming SMS actually arrives.
class PayScreen extends StatefulWidget {
  const PayScreen({
    super.key,
    required this.contactsService,
    required this.categorizationService,
    required this.favoriteContactsService,
    required this.simSelectionController,
    required this.plannedPaymentService,
  });

  final ContactsService contactsService;
  final CategorizationService categorizationService;
  final FavoriteContactsService favoriteContactsService;
  final PlannedPaymentService plannedPaymentService;

  /// Shared, session-scoped SIM choice (review batch item #2) — the
  /// same instance Home's own USSD quick actions use, so a choice made
  /// here is remembered there too and vice versa, and Android's own
  /// SIM picker never appears mid-flow.
  final SimSelectionController simSelectionController;

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  _PayTarget _target = _PayTarget.contact;
  ContactOption? _selectedContact;
  CodeUsage? _selectedCode;
  final _manualRecipientController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isMerchantPayment = false;
  bool _showAdvanced = false;
  Category? _selectedCategory;

  List<SimOption> _sims = const [];

  @override
  void initState() {
    super.initState();
    _loadSims();
    // Opportunistic sweep (this app has no background-execution
    // machinery of its own — see PlannedPaymentService doc): every time
    // Pay screen opens is a natural, frequent-enough moment to flip any
    // stale pending row to expired before it's shown in the log.
    unawaited(widget.plannedPaymentService.expireStale());
  }

  Future<void> _loadSims() async {
    final sims = await UssdDialer.listSims();
    if (!mounted) return;
    setState(() => _sims = sims);
  }

  @override
  void dispose() {
    _manualRecipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String? get _recipient {
    switch (_target) {
      case _PayTarget.contact:
        return _selectedContact?.phoneNumber;
      case _PayTarget.frequentCode:
        return _selectedCode?.code;
      case _PayTarget.manual:
        final text = _manualRecipientController.text.trim();
        return text.isEmpty ? null : text;
    }
  }

  /// Builds the validated USSD code, or shows the relevant error and
  /// returns null.
  String? _buildCode() {
    final recipient = _recipient;
    final amount = int.tryParse(_amountController.text.trim());
    if (recipient == null || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a recipient and enter an amount.')),
      );
      return null;
    }

    if (_isMerchantPayment) {
      // Till codes are opaque merchant identifiers, never phone-shaped
      // — nothing to normalize, just hand the raw code through.
      return UssdBuilder.payMerchant(tillCode: recipient, amountRwf: amount);
    }

    // Confirmed real bug (spec Phase 9): neither the contact picker
    // (only `.trim()`), manual entry, nor frequent-code selection
    // ever validated or normalized the recipient before this point.
    final normalized = PhoneNormalizer.normalizeRwandanMobile(recipient);
    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That doesn\'t look like a valid Rwandan phone number. '
            'Check the recipient and try again.',
          ),
        ),
      );
      return null;
    }
    return UssdBuilder.sendMoney(phoneNumber: normalized, amountRwf: amount);
  }

  /// Discards everything entered on this screen — no [PlannedPayments]
  /// row, no dial, no trace. Distinct from a failed/expired planned
  /// payment (which DOES get logged, since a dial attempt was actually
  /// made) — cancelling before dialing means nothing happened at all.
  void _cancel() {
    setState(() {
      _selectedContact = null;
      _selectedCode = null;
      _selectedCategory = null;
      _manualRecipientController.clear();
      _amountController.clear();
    });
  }

  /// "Done": records the chosen category as a [PlannedPayments] row
  /// (never a [Transactions] row — see that table's own doc for why),
  /// then runs the USSD code directly (ACTION_CALL — Android executes
  /// it and shows the network's own response), falling back to dialer
  /// pre-fill only if permission is refused or direct dialing isn't
  /// available. Uses the chosen SIM slot (spec #7) when this device has
  /// more than one. See [UssdDialer.runDirect] — this is the same
  /// standardized sequence every USSD action in the app now uses
  /// (review batch item #2), not bespoke logic for this screen alone.
  Future<void> _payNow() async {
    final code = _buildCode();
    if (code == null) return;

    final category = _selectedCategory;
    if (category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a category first.')),
      );
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    // Pay screen only ever builds MTN-shaped codes today (no provider
    // selector exists here — Airtel Money's own send-money menu
    // position is unconfirmed, see UssdBuilder's class doc) — this
    // must be revisited if that ever changes.
    await widget.plannedPaymentService.create(
      recipient: _recipient!,
      amount: amount,
      categoryId: category.id,
      providerCode: 'mtn_momo_rw',
    );
    if (!mounted) return;

    final simSlot = await widget.simSelectionController.ensureChosen(context);
    if (!mounted) return;
    final outcome = await UssdDialer.runDirect(code, simSlotIndex: simSlot);
    if (!mounted) return;
    switch (outcome) {
      case UssdRunOutcome.dialedDirectly:
        break;
      case UssdRunOutcome.fellBackToPrefill:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Direct payment isn\'t available — the code is ready in your dialer, press call.',
            ),
          ),
        );
      case UssdRunOutcome.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start the payment on this device.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(compact: true),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Planned payments',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlannedPaymentLogScreen(
                  plannedPaymentService: widget.plannedPaymentService,
                  categorizationService: widget.categorizationService,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Send money', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          // One connected card — amount, SIM chooser, and recipient all
          // read as a single payment form instead of separate floating
          // sections (review batch item #1: "too much dead space / feel
          // disconnected").
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.10),
                  scheme.primary.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Text(
                  'Amount',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'RWF',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    IntrinsicWidth(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        autofocus: false,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                        decoration: const InputDecoration(
                          hintText: '0',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                if (_sims.length > 1) ...[
                  const Divider(height: 24),
                  _SimChooserRow(
                    sims: _sims,
                    controller: widget.simSelectionController,
                    onChanged: () => setState(() {}),
                  ),
                ],
                const Divider(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('To', style: Theme.of(context).textTheme.titleSmall),
                ),
                const SizedBox(height: 10),
                SegmentedButton<_PayTarget>(
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(
                      value: _PayTarget.contact,
                      icon: Icon(Icons.contacts_outlined),
                      label: Text('Contact'),
                    ),
                    ButtonSegment(
                      value: _PayTarget.frequentCode,
                      icon: Icon(Icons.star_outline),
                      label: Text('Frequent'),
                    ),
                    ButtonSegment(
                      value: _PayTarget.manual,
                      icon: Icon(Icons.dialpad),
                      label: Text('Manual'),
                    ),
                  ],
                  selected: {_target},
                  onSelectionChanged: (s) => setState(() => _target = s.first),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: switch (_target) {
                    _PayTarget.contact => _ContactPicker(
                        contactsService: widget.contactsService,
                        favoriteContactsService: widget.favoriteContactsService,
                        selected: _selectedContact,
                        onSelected: (c) => setState(() {
                          _selectedContact = c;
                          _isMerchantPayment = false;
                        }),
                      ),
                    _PayTarget.frequentCode => _FrequentCodePicker(
                        categorizationService: widget.categorizationService,
                        selected: _selectedCode,
                        onSelected: (c) => setState(() {
                          _selectedCode = c;
                          // Confirmed real bug (spec Phase 9): this used
                          // to be hardcoded true for every frequent
                          // code, but CodeUsage.code is the raw
                          // Transactions.counterparty string, which for
                          // a P2P transfer is a phone-shaped number, not
                          // a merchant till code. Only treat it as a
                          // merchant payment when it doesn't look like a
                          // phone number.
                          _isMerchantPayment =
                              PhoneNormalizer.normalizeRwandanMobile(c.code) == null;
                        }),
                      ),
                    _PayTarget.manual => _ManualEntry(
                        controller: _manualRecipientController,
                        isMerchant: _isMerchantPayment,
                        onMerchantChanged: (v) => setState(() => _isMerchantPayment = v),
                      ),
                  },
                ),
                const Divider(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Category', style: Theme.of(context).textTheme.titleSmall),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chosen now, applied automatically once the real payment SMS '
                  'confirms it — nothing is recorded as spent yet.',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                _CategoryPickerRow(
                  categorizationService: widget.categorizationService,
                  selected: _selectedCategory,
                  onSelected: (c) => setState(() => _selectedCategory = c),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancel,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text('Cancel'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _payNow,
                        icon: const Icon(Icons.bolt),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text('Done'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Done runs the MoMo code directly and your network shows its own '
                  'confirmation — nothing happens without you seeing it.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _AdvancedSection(
            expanded: _showAdvanced,
            onToggle: () => setState(() => _showAdvanced = !_showAdvanced),
            accentColor: scheme.secondary,
            simSelectionController: widget.simSelectionController,
          ),
        ],
      ),
    );
  }
}

/// Dual-SIM row — shown only when the device genuinely has more than
/// one callable SIM ([UssdDialer.listSims] returning 2+). Reads/writes
/// through the shared, session-scoped [SimSelectionController] (review
/// batch item #2) rather than owning its own selection: shows which
/// SIM the session has already settled on (or "Not chosen yet" before
/// the first USSD action this session), with a "Change" action that
/// re-opens the same in-app chooser every other USSD call site uses.
class _SimChooserRow extends StatelessWidget {
  const _SimChooserRow({
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

class _ContactPicker extends StatefulWidget {
  const _ContactPicker({
    required this.contactsService,
    required this.favoriteContactsService,
    required this.selected,
    required this.onSelected,
  });

  final ContactsService contactsService;
  final FavoriteContactsService favoriteContactsService;
  final ContactOption? selected;
  final ValueChanged<ContactOption> onSelected;

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  bool? _hasPermission;
  List<ContactOption> _contacts = const [];
  Set<String> _favorites = const {};
  String _query = '';

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
      return const Center(child: Padding(
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

    final sorted = [...filtered]
      ..sort((a, b) {
        final aFav = isFavorite(a) ? 0 : 1;
        final bFav = isFavorite(b) ? 0 : 1;
        return aFav.compareTo(bFav);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
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
                              color: favorite ? AppBrand.expense(Theme.of(context).brightness) : null,
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

class _FrequentCodePicker extends StatelessWidget {
  const _FrequentCodePicker({
    required this.categorizationService,
    required this.selected,
    required this.onSelected,
  });

  final CategorizationService categorizationService;
  final CodeUsage? selected;
  final ValueChanged<CodeUsage> onSelected;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CodeUsage>>(
      future: categorizationService.mostUsedCounterparties(limit: 10),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No payment history yet — codes you\'ve paid before will show up here.'),
          );
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final usage = items[index];
              final isSelected = selected?.code == usage.code;
              return ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(usage.label),
                subtitle: Text(usage.category?.name ?? 'Uncategorized'),
                trailing: isSelected
                    ? const Icon(Icons.check_circle)
                    : Text('×${usage.usageCount}'),
                selected: isSelected,
                onTap: () => onSelected(usage),
              );
            },
          ),
        );
      },
    );
  }
}

class _ManualEntry extends StatelessWidget {
  const _ManualEntry({
    required this.controller,
    required this.isMerchant,
    required this.onMerchantChanged,
  });

  final TextEditingController controller;
  final bool isMerchant;
  final ValueChanged<bool> onMerchantChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          keyboardType: isMerchant ? TextInputType.text : TextInputType.phone,
          decoration: InputDecoration(
            labelText: isMerchant ? 'Merchant / till code' : 'Phone number',
            helperText: isMerchant
                ? 'Uses the merchant *182*8...# code'
                : 'Uses the send-money *182*1...# code',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('This is a merchant/till code, not a phone number'),
          value: isMerchant,
          // Confirmed real distinction (spec #7): a till/merchant code
          // and a phone number use two DIFFERENT *182# menu paths
          // (*182*8...# vs *182*1...#) — this switch is what decides
          // which one _buildCode() uses, not a cosmetic label.
          onChanged: onMerchantChanged,
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
class _CategoryPickerRow extends StatefulWidget {
  const _CategoryPickerRow({
    required this.categorizationService,
    required this.selected,
    required this.onSelected,
  });

  final CategorizationService categorizationService;
  final Category? selected;
  final ValueChanged<Category> onSelected;

  @override
  State<_CategoryPickerRow> createState() => _CategoryPickerRowState();
}

class _CategoryPickerRowState extends State<_CategoryPickerRow> {
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

/// Grid of other USSD services (review batch items #1/#2), all
/// direct-dialing via [UssdDialer.runDirect] — no "open dialer instead"
/// detour for any of them. Grouped by what's actually confirmed real:
/// MTN/Airtel telecom self-service, and each of the four banks whose
/// USSD root is confirmed (Bank of Kigali, BPR, I&M, Equity). Any bank
/// only seen in an unverified source (I&M's competitors, Cogebanque,
/// KCB, etc. beyond the four above) is deliberately a "coming soon"
/// popup, never a guessed code — see UssdBuilder's class doc.
class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.expanded,
    required this.onToggle,
    required this.accentColor,
    required this.simSelectionController,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final Color accentColor;
  final SimSelectionController simSelectionController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.tune, size: 18, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  'More services',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: accentColor),
                ),
                const Spacer(),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, color: accentColor),
              ],
            ),
          ),
        ),
        if (expanded) _AdvancedGrid(simSelectionController: simSelectionController),
      ],
    );
  }
}

enum _AdvancedAction {
  airtime,
  balance,
  mtnBundles,
  mokash,
  airtelRecharge,
  airtelBalance,
  airtelShare,
  airtelBundles,
  bk,
  bpr,
  imBank,
  equity,
  cogebanque,
  kcb,
}

class _AdvancedGrid extends StatefulWidget {
  const _AdvancedGrid({required this.simSelectionController});

  final SimSelectionController simSelectionController;

  @override
  State<_AdvancedGrid> createState() => _AdvancedGridState();
}

class _AdvancedGridState extends State<_AdvancedGrid> {
  _AdvancedAction? _pendingAmountFor;
  final _amountController = TextEditingController();

  static const _mtnAirtelActions = <(_AdvancedAction action, IconData icon, String label)>[
    (_AdvancedAction.airtime, Icons.phone_iphone_rounded, 'MTN Airtime'),
    (_AdvancedAction.balance, Icons.account_balance_wallet_outlined, 'MoMo Balance'),
    (_AdvancedAction.mtnBundles, Icons.wifi_rounded, 'MTN Bundles'),
    (_AdvancedAction.mokash, Icons.savings_outlined, 'Mokash'),
    (_AdvancedAction.airtelRecharge, Icons.phone_android_rounded, 'Airtel Airtime'),
    (_AdvancedAction.airtelBalance, Icons.account_balance_wallet_outlined, 'Airtel Balance'),
    (_AdvancedAction.airtelShare, Icons.share_outlined, 'Airtel Share'),
    (_AdvancedAction.airtelBundles, Icons.wifi_rounded, 'Airtel Bundles'),
  ];

  static const _bankActions = <(_AdvancedAction action, IconData icon, String label)>[
    (_AdvancedAction.bk, Icons.account_balance_outlined, 'Bank of Kigali'),
    (_AdvancedAction.bpr, Icons.account_balance_outlined, 'BPR'),
    (_AdvancedAction.imBank, Icons.account_balance_outlined, 'I&M Bank'),
    (_AdvancedAction.equity, Icons.account_balance_outlined, 'Equity Bank'),
    (_AdvancedAction.cogebanque, Icons.account_balance_outlined, 'Cogebanque'),
    (_AdvancedAction.kcb, Icons.account_balance_outlined, 'KCB'),
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _runCode(String code) async {
    final simSlot = await widget.simSelectionController.ensureChosen(context);
    if (!mounted) return;
    final outcome = await UssdDialer.runDirect(code, simSlotIndex: simSlot);
    if (!mounted) return;
    if (outcome == UssdRunOutcome.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start this on this device.')),
      );
    }
  }

  Future<void> _run(_AdvancedAction action) async {
    switch (action) {
      case _AdvancedAction.airtime:
        setState(() => _pendingAmountFor = action);
        return;
      case _AdvancedAction.balance:
        await _runCode(UssdBuilder.checkBalance());
      case _AdvancedAction.mtnBundles:
        await _runCode(UssdBuilder.mtnBundles());
      case _AdvancedAction.mokash:
        // No confirmed menu-nested Mokash code — open the real root
        // menu and let the user finish on-screen (see UssdBuilder doc).
        await _runCode(UssdBuilder.openMenu());
      case _AdvancedAction.airtelRecharge:
        await _runCode(UssdBuilder.airtelRechargeAirtime());
      case _AdvancedAction.airtelBalance:
        await _runCode(UssdBuilder.checkAirtimeBalance());
      case _AdvancedAction.airtelShare:
        await _runCode(UssdBuilder.airtelShareAirtime());
      case _AdvancedAction.airtelBundles:
        await _runCode(UssdBuilder.airtelBundles());
      case _AdvancedAction.bk:
        await _runCode(UssdBuilder.bankMenu(BankUssd.bk));
      case _AdvancedAction.bpr:
        await _runCode(UssdBuilder.bankMenu(BankUssd.bpr));
      case _AdvancedAction.imBank:
        await _runCode(UssdBuilder.bankMenu(BankUssd.imBank));
      case _AdvancedAction.equity:
        await _runCode(UssdBuilder.bankMenu(BankUssd.equity));
      case _AdvancedAction.cogebanque:
        await showComingSoonPopup(
          context,
          feature: 'Cogebanque',
          icon: Icons.account_balance_outlined,
          description: 'We haven\'t confirmed Cogebanque\'s USSD code from a reliable '
              'source yet, so this app won\'t guess it.',
        );
      case _AdvancedAction.kcb:
        await showComingSoonPopup(
          context,
          feature: 'KCB',
          icon: Icons.account_balance_outlined,
          description: 'We haven\'t confirmed KCB\'s USSD code from a reliable '
              'source yet, so this app won\'t guess it.',
        );
    }
  }

  Future<void> _confirmAirtime() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount first.')),
      );
      return;
    }
    final code = UssdBuilder.buyAirtime(amountRwf: amount);
    setState(() => _pendingAmountFor = null);
    await _runCode(code);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('MTN & Airtel', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _ServiceGrid(actions: _mtnAirtelActions, onTap: _run),
          if (_pendingAmountFor == _AdvancedAction.airtime) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Airtime amount (RWF)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _confirmAirtime, child: const Text('Go')),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text('Banks', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _ServiceGrid(actions: _bankActions, onTap: _run),
          const SizedBox(height: 8),
          Text(
            'Every tile dials directly, same as Pay now — your network shows '
            'its own response. Bank tiles open that bank\'s real menu; finish '
            'the last step on-screen, the same way you would dialing it '
            'yourself.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.actions, required this.onTap});

  final List<(_AdvancedAction action, IconData icon, String label)> actions;
  final ValueChanged<_AdvancedAction> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: [
        for (final (action, icon, label) in actions)
          _ServiceTile(icon: icon, label: label, onTap: () => onTap(action)),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
