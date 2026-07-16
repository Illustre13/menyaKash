import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../categorization/categorization_service.dart';
import '../contacts/contacts_service.dart';
import '../contacts/favorite_contacts_service.dart';
import '../data/database.dart';
import '../theme/app_theme.dart';
import '../ussd/phone_normalizer.dart';
import '../ussd/ussd_builder.dart';
import '../ussd/ussd_dialer.dart';

enum _PayTarget { contact, frequentCode, manual }

/// Bypasses typing `*182*1*1*<number>*<amount>#` by hand: pick a
/// recipient from phone contacts or a previously-used MoMo code, enter
/// an amount, and this builds the USSD string and hands it to the
/// native dialer. The user still presses call/send themselves — this
/// screen (and the UssdBuilder/UssdDialer underneath it) never places a
/// call or reads a USSD session on its own.
class PayScreen extends StatefulWidget {
  const PayScreen({
    super.key,
    required this.contactsService,
    required this.categorizationService,
    required this.favoriteContactsService,
  });

  final ContactsService contactsService;
  final CategorizationService categorizationService;
  final FavoriteContactsService favoriteContactsService;

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

  List<SimOption> _sims = const [];
  int? _selectedSimSlot;

  @override
  void initState() {
    super.initState();
    _loadSims();
  }

  Future<void> _loadSims() async {
    final sims = await UssdDialer.listSims();
    if (!mounted) return;
    setState(() {
      _sims = sims;
      if (sims.isNotEmpty) _selectedSimSlot = sims.first.simSlotIndex;
    });
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

  /// "Pay now": run the USSD code directly (ACTION_CALL — Android
  /// executes it and shows the network's own response). Falls back to
  /// dialer pre-fill if the CALL_PHONE permission is refused or direct
  /// dialing isn't available on this device. Uses the chosen SIM slot
  /// (spec #7) when this device has more than one.
  Future<void> _payNow() async {
    final code = _buildCode();
    if (code == null) return;

    final phonePermission = await Permission.phone.request();
    if (phonePermission.isGranted) {
      final ok = await UssdDialer.payNow(code, simSlotIndex: _selectedSimSlot);
      if (ok) return;
    }

    // Refused or unavailable — degrade to pre-fill, and say so rather
    // than silently doing something different from what was tapped.
    final launched = await UssdDialer.dial(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          launched
              ? 'Direct payment isn\'t available — the code is ready in your dialer, press call.'
              : 'Could not start the payment on this device.',
        ),
      ),
    );
  }

  /// "Open dialer instead": pre-fill only, user presses call. A SIM
  /// pre-selection can't be carried through a bare `tel:` intent — the
  /// system dialer/OS asks if it needs to, same as dialing any other
  /// number by hand.
  Future<void> _openDialer() async {
    final code = _buildCode();
    if (code == null) return;
    final launched = await UssdDialer.dial(code);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the dialer on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const BrandMark(compact: true)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Send money', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          // Amount first — the number is the decision; everything else
          // is addressing. Large, centered, tabular figures.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
                const SizedBox(height: 6),
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
              ],
            ),
          ),
          if (_sims.length > 1) ...[
            const SizedBox(height: 12),
            _SimChooser(
              sims: _sims,
              selectedSlot: _selectedSimSlot,
              onSelected: (slot) => setState(() => _selectedSimSlot = slot),
            ),
          ],
          const SizedBox(height: 20),
          Text('To', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SegmentedButton<_PayTarget>(
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
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
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
                    // Confirmed real bug (spec Phase 9): this used to be
                    // hardcoded true for every frequent code, but
                    // CodeUsage.code is the raw Transactions.counterparty
                    // string, which for a P2P transfer is a phone-shaped
                    // number, not a merchant till code. Only treat it as
                    // a merchant payment when it doesn't look like a
                    // phone number.
                    _isMerchantPayment = PhoneNormalizer.normalizeRwandanMobile(c.code) == null;
                  }),
                ),
              _PayTarget.manual => _ManualEntry(
                  controller: _manualRecipientController,
                  isMerchant: _isMerchantPayment,
                  onMerchantChanged: (v) => setState(() => _isMerchantPayment = v),
                ),
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _payNow,
            icon: const Icon(Icons.bolt),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Pay now'),
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _openDialer,
            icon: const Icon(Icons.dialpad, size: 18),
            label: const Text('Open dialer instead'),
          ),
          const SizedBox(height: 4),
          Text(
            'Pay now runs the MoMo code and your network shows its own '
            'confirmation. "Open dialer instead" only pre-fills the code '
            'so you press call yourself. Either way, nothing happens '
            'without you seeing it.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _AdvancedSection(
            expanded: _showAdvanced,
            onToggle: () => setState(() => _showAdvanced = !_showAdvanced),
            accentColor: scheme.secondary,
          ),
        ],
      ),
    );
  }
}

/// Dual-SIM chooser (spec #7) — only ever shown when the device
/// genuinely has more than one callable SIM ([UssdDialer.listSims]
/// returning 2+). A quiet inline row, not a modal — this is a
/// lightweight preference set once per payment, not a decision that
/// needs its own screen.
class _SimChooser extends StatelessWidget {
  const _SimChooser({required this.sims, required this.selectedSlot, required this.onSelected});

  final List<SimOption> sims;
  final int? selectedSlot;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.sim_card_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text('Dial with', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: [
              for (final sim in sims)
                ChoiceChip(
                  label: Text(sim.label),
                  selected: selectedSlot == sim.simSlotIndex,
                  onSelected: (_) => onSelected(sim.simSlotIndex),
                ),
            ],
          ),
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

/// The original raw *182# builder, demoted from its own tab to an
/// expandable section here. Deliberately a grid of quick shortcuts
/// (spec #7) that open each service's real root USSD menu
/// (`UssdBuilder.openMenu`) rather than guessing a menu-nested digit
/// sequence this app hasn't verified against a reliable source —
/// getting a middle digit wrong for e.g. an electricity-token payment
/// risks sending money to the wrong place. Airtime and Balance keep
/// their existing pre-filled shortcuts since those ARE confirmed;
/// Electricity/Water/Bundle/Mokash open the real menu for the user to
/// finish on-screen.
class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.expanded,
    required this.onToggle,
    required this.accentColor,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final Color accentColor;

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
        if (expanded) const _AdvancedGrid(),
      ],
    );
  }
}

enum _AdvancedAction { airtime, balance, electricity, water, bundle, mokash }

class _AdvancedGrid extends StatefulWidget {
  const _AdvancedGrid();

  @override
  State<_AdvancedGrid> createState() => _AdvancedGridState();
}

class _AdvancedGridState extends State<_AdvancedGrid> {
  _AdvancedAction? _pendingAmountFor;
  final _amountController = TextEditingController();

  static const _actions = <(_AdvancedAction action, IconData icon, String label)>[
    (_AdvancedAction.airtime, Icons.phone_iphone_rounded, 'Airtime'),
    (_AdvancedAction.balance, Icons.account_balance_wallet_outlined, 'Balance'),
    (_AdvancedAction.electricity, Icons.bolt_rounded, 'Electricity'),
    (_AdvancedAction.water, Icons.water_drop_outlined, 'Water'),
    (_AdvancedAction.bundle, Icons.wifi_rounded, 'Bundle'),
    (_AdvancedAction.mokash, Icons.savings_outlined, 'Mokash'),
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _run(_AdvancedAction action) async {
    if (action == _AdvancedAction.airtime) {
      setState(() => _pendingAmountFor = action);
      return;
    }
    // Every other shortcut opens the provider's real root menu — the
    // honest choice for anything this app hasn't verified an exact
    // digit sequence for (see class doc).
    final launched = await UssdDialer.dial(UssdBuilder.openMenu());
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the dialer on this device.')),
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
    final launched = await UssdDialer.dial(code);
    if (!mounted) return;
    setState(() => _pendingAmountFor = null);
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the dialer on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: [
              for (final (action, icon, label) in _actions)
                _ServiceTile(
                  icon: icon,
                  label: label,
                  onTap: () => _run(action),
                ),
            ],
          ),
          if (_pendingAmountFor == _AdvancedAction.airtime) ...[
            const SizedBox(height: 16),
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
          const SizedBox(height: 8),
          Text(
            'Electricity, Water, Bundle, and Mokash open your provider\'s menu '
            'directly — finish the last step on-screen, the same way you '
            'would dialing it yourself.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
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
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
