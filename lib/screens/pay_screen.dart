import 'package:flutter/material.dart';

import '../categorization/categorization_service.dart';
import '../contacts/contacts_service.dart';
import '../data/database.dart';
import '../theme/app_theme.dart';
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
  });

  final ContactsService contactsService;
  final CategorizationService categorizationService;

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

  Future<void> _pay() async {
    final recipient = _recipient;
    final amount = int.tryParse(_amountController.text.trim());
    if (recipient == null || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a recipient and enter an amount.')),
      );
      return;
    }

    final code = _isMerchantPayment
        ? UssdBuilder.payMerchant(tillCode: recipient, amountRwf: amount)
        : UssdBuilder.sendMoney(phoneNumber: recipient, amountRwf: amount);

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
          Text('Pay', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Pick a recipient, enter an amount, and we\'ll fill in the '
            'MoMo dialer code for you.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 16),
          switch (_target) {
            _PayTarget.contact => _ContactPicker(
                contactsService: widget.contactsService,
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
                  _isMerchantPayment = true;
                }),
              ),
            _PayTarget.manual => _ManualEntry(
                controller: _manualRecipientController,
                isMerchant: _isMerchantPayment,
                onMerchantChanged: (v) => setState(() => _isMerchantPayment = v),
              ),
          },
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (RWF)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _pay,
            icon: const Icon(Icons.dialpad),
            label: const Text('Open dialer to pay'),
          ),
          const SizedBox(height: 8),
          Text(
            'This fills in the USSD code and opens your phone\'s dialer. '
            'You still confirm and send it yourself — nothing is sent '
            'automatically.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
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

class _ContactPicker extends StatefulWidget {
  const _ContactPicker({
    required this.contactsService,
    required this.selected,
    required this.onSelected,
  });

  final ContactsService contactsService;
  final ContactOption? selected;
  final ValueChanged<ContactOption> onSelected;

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  bool? _hasPermission;
  List<ContactOption> _contacts = const [];
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
    final contacts = await widget.contactsService.loadContactsWithPhoneNumbers();
    if (!mounted) return;
    setState(() => _contacts = contacts);
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
          constraints: const BoxConstraints(maxHeight: 240),
          child: filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No matching contacts.'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final contact = filtered[index];
                    final isSelected = widget.selected?.phoneNumber == contact.phoneNumber;
                    return ListTile(
                      leading: CircleAvatar(child: Text(contact.displayName.characters.first)),
                      title: Text(contact.displayName),
                      subtitle: Text(contact.phoneNumber),
                      selected: isSelected,
                      trailing: isSelected ? const Icon(Icons.check_circle) : null,
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
          decoration: InputDecoration(
            labelText: isMerchant ? 'Merchant / till code' : 'Phone number',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('This is a merchant/till code, not a phone number'),
          value: isMerchant,
          onChanged: onMerchantChanged,
        ),
      ],
    );
  }
}

/// The original raw *182# builder, demoted from its own tab to an
/// expandable section here — it still covers airtime purchase and
/// balance check, which the primary Pay flow above doesn't.
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
                  'Advanced: airtime & balance',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: accentColor),
                ),
                const Spacer(),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, color: accentColor),
              ],
            ),
          ),
        ),
        if (expanded) const _AdvancedDialer(),
      ],
    );
  }
}

class _AdvancedDialer extends StatefulWidget {
  const _AdvancedDialer();

  @override
  State<_AdvancedDialer> createState() => _AdvancedDialerState();
}

enum _AdvancedAction { buyAirtime, checkBalance }

class _AdvancedDialerState extends State<_AdvancedDialer> {
  _AdvancedAction _action = _AdvancedAction.buyAirtime;
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _dial() async {
    String code;
    if (_action == _AdvancedAction.buyAirtime) {
      final amount = int.tryParse(_amountController.text.trim());
      if (amount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter an amount first.')),
        );
        return;
      }
      code = UssdBuilder.buyAirtime(amountRwf: amount);
    } else {
      code = UssdBuilder.checkBalance();
    }
    final launched = await UssdDialer.dial(code);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the dialer on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_AdvancedAction>(
            segments: const [
              ButtonSegment(value: _AdvancedAction.buyAirtime, label: Text('Airtime')),
              ButtonSegment(value: _AdvancedAction.checkBalance, label: Text('Balance')),
            ],
            selected: {_action},
            onSelectionChanged: (s) => setState(() => _action = s.first),
          ),
          if (_action == _AdvancedAction.buyAirtime) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (RWF)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _dial,
            icon: const Icon(Icons.dialpad),
            label: const Text('Open dialer'),
          ),
        ],
      ),
    );
  }
}
