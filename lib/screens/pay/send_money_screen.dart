import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../accounts/accounts_service.dart';
import '../../categorization/categorization_service.dart';
import '../../contacts/contacts_service.dart';
import '../../contacts/favorite_contacts_service.dart';
import '../../data/database.dart';
import '../../payments/planned_payment_log_screen.dart';
import '../../payments/planned_payment_service.dart';
import '../../theme/provider_assets.dart';
import '../../ussd/phone_normalizer.dart';
import '../../ussd/sim_selection_controller.dart';
import '../../ussd/ussd_builder.dart';
import '../../ussd/ussd_dialer.dart';
import 'pay_widgets.dart';

/// Send money (screen 12 of the redesign): who → how much on an
/// on-screen keypad → Review payment → the existing direct-dial path.
///
/// Bypasses typing `*182*1*1*<number>*<amount>#` by hand. The user still
/// confirms on the network's own USSD screen — this never places a call
/// or reads a USSD session on its own, and never includes a PIN.
///
/// The category chosen on the review step is captured as a
/// [PlannedPayments] row, NOT written onto a [Transactions] row — see
/// that table's doc. [SmsProcessor] reconciles it once the confirming
/// SMS arrives.
///
/// Only MTN MoMo is offered as the source: Airtel Money's send-money
/// menu position is unconfirmed (see [UssdBuilder.sendMoney]), and this
/// app never guesses codes. No fee is shown because the app has no
/// verified tariff table — the network shows the real fee on the
/// dialer before the user confirms.
class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({
    super.key,
    required this.contactsService,
    required this.categorizationService,
    required this.favoriteContactsService,
    required this.plannedPaymentService,
    required this.simSelectionController,
    this.accountsService,
  });

  final ContactsService contactsService;
  final CategorizationService categorizationService;
  final FavoriteContactsService favoriteContactsService;
  final PlannedPaymentService plannedPaymentService;
  final SimSelectionController simSelectionController;

  /// Optional: when present, the "From MTN MoMo" row shows the last
  /// known balance from SMS.
  final AccountsService? accountsService;

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

/// Who the money goes to. [isMerchant] picks the `*182*8` till path
/// instead of `*182*1` — a real, different menu, not a label.
class _Recipient {
  const _Recipient({required this.code, this.name, this.isMerchant = false});

  final String code;
  final String? name;
  final bool isMerchant;

  String get label => name ?? code;
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  static const _maxDigits = 9;

  final _toController = TextEditingController();
  final _toFocus = FocusNode();
  String _amount = '';
  _Recipient? _recipient;
  bool _merchantMode = false;
  List<_Recipient> _recents = const [];
  AccountSummary? _mtnAccount;

  @override
  void initState() {
    super.initState();
    _loadRecents();
    _loadAccount();
    // Same opportunistic sweep the Pay hub runs — see
    // PlannedPaymentService's doc.
    unawaited(widget.plannedPaymentService.expireStale());
  }

  @override
  void dispose() {
    _toController.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  /// Most-paid counterparties from real transaction history. A
  /// non-phone-shaped code is a merchant till, so it keeps the
  /// merchant path (confirmed real bug fixed in spec Phase 9).
  Future<void> _loadRecents() async {
    final usages = await widget.categorizationService.mostUsedCounterparties(limit: 8);
    if (!mounted) return;
    setState(() {
      _recents = [
        for (final u in usages)
          _Recipient(
            code: u.code,
            name: u.displayName,
            isMerchant: PhoneNormalizer.normalizeRwandanMobile(u.code) == null,
          ),
      ];
    });
  }

  Future<void> _loadAccount() async {
    final service = widget.accountsService;
    if (service == null) return;
    final summaries = await service.allAccountSummaries();
    if (!mounted) return;
    final mtn = summaries.where((s) => s.providerCode == 'mtn_momo_rw');
    setState(() => _mtnAccount = mtn.isEmpty ? null : mtn.first);
  }

  void _select(_Recipient recipient) {
    setState(() {
      _recipient = recipient;
      _merchantMode = recipient.isMerchant;
      _toController.text = recipient.label;
    });
    _toFocus.unfocus();
  }

  /// Typing in "To" is the manual-entry path: the text itself is the
  /// recipient (a phone number, or a till code in merchant mode).
  void _onToChanged(String text) {
    final trimmed = text.trim();
    setState(() {
      // Letters (outside merchant mode) mean a name: that's a contacts
      // search, not a recipient yet — see _nameQuery.
      _recipient = trimmed.isEmpty || (!_merchantMode && _looksLikeName(trimmed))
          ? null
          : _Recipient(code: trimmed, isMerchant: _merchantMode);
    });
  }

  static bool _looksLikeName(String text) => RegExp('[A-Za-z]').hasMatch(text);

  /// A typed name with no recipient picked yet, to search contacts for.
  String? get _nameQuery {
    final text = _toController.text.trim();
    if (_merchantMode || _recipient != null || !_looksLikeName(text)) return null;
    return text;
  }

  Future<void> _pickContact({String initialQuery = ''}) async {
    final contact = await showModalBottomSheet<ContactOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: PayContactPicker(
          contactsService: widget.contactsService,
          favoriteContactsService: widget.favoriteContactsService,
          selected: null,
          initialQuery: initialQuery,
          onSelected: (c) => Navigator.of(context).pop(c),
        ),
      ),
    );
    if (contact != null) {
      _select(_Recipient(code: contact.phoneNumber, name: contact.displayName));
    }
  }

  void _startNew() {
    setState(() {
      _recipient = null;
      _toController.clear();
    });
    _toFocus.requestFocus();
  }

  void _key(String key) {
    setState(() {
      if (key == '<') {
        if (_amount.isNotEmpty) _amount = _amount.substring(0, _amount.length - 1);
        return;
      }
      if (_amount.isEmpty && key.startsWith('0')) return; // no leading zeros
      _amount = (_amount + key);
      if (_amount.length > _maxDigits) _amount = _amount.substring(0, _maxDigits);
    });
  }

  /// Builds the validated USSD code, or explains what's missing.
  String? _buildCode() {
    final recipient = _recipient;
    final amount = int.tryParse(_amount);
    if (recipient == null || amount == null || amount <= 0) {
      _snack('Choose who to send to and enter an amount.');
      return null;
    }
    if (recipient.isMerchant) {
      // Till codes are opaque merchant identifiers — hand through raw.
      return UssdBuilder.payMerchant(tillCode: recipient.code, amountRwf: amount);
    }
    final normalized = PhoneNormalizer.normalizeRwandanMobile(recipient.code);
    if (normalized == null) {
      _snack('That doesn\'t look like a valid Rwandan phone number. '
          'Check the recipient and try again.');
      return null;
    }
    return UssdBuilder.sendMoney(phoneNumber: normalized, amountRwf: amount);
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _review() async {
    final code = _buildCode();
    if (code == null) return;
    final category = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReviewSheet(
        recipient: _recipient!,
        amount: int.parse(_amount),
        sourceLabel: 'MTN MoMo',
        categorizationService: widget.categorizationService,
        simSelectionController: widget.simSelectionController,
      ),
    );
    if (category == null || !mounted) return;
    await _payNow(code, category);
  }

  /// Records the category as a [PlannedPayments] row, then runs the
  /// USSD code directly ([UssdDialer.runDirect]: ACTION_CALL, falling
  /// back to dialer pre-fill if permission is refused). Same
  /// standardized sequence every USSD action in the app uses.
  Future<void> _payNow(String code, Category category) async {
    await widget.plannedPaymentService.create(
      recipient: _recipient!.code,
      amount: double.parse(_amount),
      categoryId: category.id,
      // Only MTN-shaped codes are built here — revisit if Airtel's
      // send-money path is ever confirmed.
      providerCode: 'mtn_momo_rw',
    );
    if (!mounted) return;
    final simSlot = await widget.simSelectionController.ensureChosen(context);
    if (!mounted) return;
    final outcome = await UssdDialer.runDirect(code, simSlotIndex: simSlot);
    if (!mounted) return;
    switch (outcome) {
      case UssdRunOutcome.dialedDirectly:
        Navigator.of(context).maybePop();
      case UssdRunOutcome.fellBackToPrefill:
        _snack('Direct payment isn\'t available — the code is ready in your dialer, press call.');
      case UssdRunOutcome.failed:
        _snack('Could not start the payment on this device.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = scheme.onSurfaceVariant;
    final amount = int.tryParse(_amount) ?? 0;
    final format = NumberFormat.decimalPattern();
    final balance = _mtnAccount?.currentBalance;
    final overBalance = balance != null && amount > balance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send money'),
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                children: [
                  Text('To', style: text.labelMedium?.copyWith(color: muted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _toController,
                    focusNode: _toFocus,
                    keyboardType: _merchantMode ? TextInputType.text : TextInputType.phone,
                    onChanged: _onToChanged,
                    decoration: InputDecoration(
                      hintText: _merchantMode ? 'Merchant till code' : 'Name or phone number',
                      prefixIcon: Icon(_merchantMode ? Icons.storefront_outlined : Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.contacts_outlined),
                        tooltip: 'Pick from contacts',
                        onPressed: () => _pickContact(initialQuery: _nameQuery ?? ''),
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerLow,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (_nameQuery != null)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.contacts_outlined),
                      title: Text('Search contacts for \u201c$_nameQuery\u201d'),
                      onTap: () => _pickContact(initialQuery: _nameQuery!),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    // Confirmed real distinction: a till code and a phone
                    // number use different *182# menus (*182*8 vs *182*1).
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        _merchantMode = !_merchantMode;
                        _onToChanged(_toController.text);
                      }),
                      icon: Icon(
                        _merchantMode ? Icons.phone_outlined : Icons.storefront_outlined,
                        size: 16,
                      ),
                      label: Text(
                        _merchantMode
                            ? 'Send to a phone number instead'
                            : 'Paying a shop? Use its till code',
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 84,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final r in _recents)
                          _RecipientAvatar(
                            recipient: r,
                            selected: _recipient?.code == r.code,
                            onTap: () => _select(r),
                          ),
                        _NewAvatar(onTap: _startNew),
                      ],
                    ),
                  ),
                  if (_recipient != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _recipient!.isMerchant
                          ? 'Paying till ${_recipient!.code}'
                          : 'Sending to ${_recipient!.name ?? 'this number'} · '
                              '${maskPhone(_recipient!.code)}',
                      style: text.bodySmall?.copyWith(color: muted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'RWF ',
                        style:
                            text.titleMedium?.copyWith(color: muted, fontWeight: FontWeight.w700),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            format.format(amount),
                            style: text.displayMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: amount == 0 ? muted : scheme.onSurface,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ProviderLogo(
                            providerCode: 'mtn_momo_rw',
                            displayName: 'MTN MoMo',
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            balance == null
                                ? 'From MTN MoMo'
                                : 'From MTN MoMo · ${format.format(balance.round())}',
                            style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    overBalance
                        ? 'More than your last known balance. Fees are shown on your '
                            'dialer before you confirm.'
                        : 'Fees are shown on your dialer before you confirm.',
                    style: text.bodySmall?.copyWith(color: overBalance ? scheme.error : muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            _Keypad(onKey: _key),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_recipient != null && amount > 0) ? _review : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text('Review payment'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "0781234567" → "0781 ••• 567": enough to recognise, not to read off
/// over someone's shoulder. Non-phone input is returned unchanged.
String maskPhone(String raw) {
  final n = PhoneNormalizer.normalizeRwandanMobile(raw);
  if (n == null || n.length != 10) return raw;
  return '${n.substring(0, 4)} ••• ${n.substring(7)}';
}

String _initials(String label) {
  final words = label.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (!RegExp('[A-Za-z]').hasMatch(words.first)) return words.first.characters.last;
  final first = words.first.characters.first;
  final second = words.length > 1 ? words[1].characters.first : '';
  return (first + second).toUpperCase();
}

class _RecipientAvatar extends StatelessWidget {
  const _RecipientAvatar({required this.recipient, required this.selected, required this.onTap});

  final _Recipient recipient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstName = recipient.label.split(' ').first;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 60,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? scheme.primary : scheme.primary.withValues(alpha: 0.14),
                  border: selected ? Border.all(color: scheme.primaryContainer, width: 3) : null,
                ),
                child: recipient.isMerchant
                    ? Icon(Icons.storefront_outlined,
                        size: 20, color: selected ? scheme.onPrimary : scheme.primary)
                    : Text(
                        _initials(recipient.label),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selected ? scheme.onPrimary : scheme.primary,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                firstName,
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewAvatar extends StatelessWidget {
  const _NewAvatar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 60,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Icon(Icons.add, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text('New', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});

  /// Digits, '000', or '<' for backspace.
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['000', '0', '<'],
    ];
    final style = Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final row in rows)
            Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: TextButton(
                        onPressed: () => onKey(key),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onSurface,
                        ),
                        child: key == '<'
                            ? const Icon(Icons.backspace_outlined, semanticLabel: 'Delete')
                            : Text(key, style: style),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Review step: who, how much, from where, which SIM, and the category
/// (picked now, applied once the confirming SMS arrives). Pops the
/// chosen [Category] to pay, or nothing to go back and edit.
class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.recipient,
    required this.amount,
    required this.sourceLabel,
    required this.categorizationService,
    required this.simSelectionController,
  });

  final _Recipient recipient;
  final int amount;
  final String sourceLabel;
  final CategorizationService categorizationService;
  final SimSelectionController simSelectionController;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  Category? _category;
  List<SimOption> _sims = const [];

  @override
  void initState() {
    super.initState();
    UssdDialer.listSims().then((sims) {
      if (mounted) setState(() => _sims = sims);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final r = widget.recipient;
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Text(label, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  value,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Review payment', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            row(
              'To',
              r.isMerchant
                  ? 'Till ${r.code}'
                  : (r.name == null ? maskPhone(r.code) : '${r.name} · ${maskPhone(r.code)}'),
            ),
            row('Amount', 'RWF ${NumberFormat.decimalPattern().format(widget.amount)}'),
            row('From', widget.sourceLabel),
            if (_sims.length > 1)
              SimChooserRow(
                sims: _sims,
                controller: widget.simSelectionController,
                onChanged: () => setState(() {}),
              ),
            const Divider(height: 24),
            Text('Category', style: text.titleSmall),
            const SizedBox(height: 2),
            Text(
              'Chosen now, applied automatically once the real payment SMS confirms it '
              '— nothing is recorded as spent yet.',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            CategoryPickerRow(
              categorizationService: widget.categorizationService,
              selected: _category,
              onSelected: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _category == null ? null : () => Navigator.of(context).pop(_category),
              icon: const Icon(Icons.bolt),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('Pay now'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to edit'),
            ),
            Text(
              'Pay now runs the MoMo code directly and your network shows its own '
              'confirmation, including any fee — nothing happens without you seeing it.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
