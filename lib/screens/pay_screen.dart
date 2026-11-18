import 'dart:async';

import 'package:flutter/material.dart';

import '../accounts/accounts_service.dart';
import '../categorization/categorization_service.dart';
import '../contacts/contacts_service.dart';
import '../contacts/favorite_contacts_service.dart';
import '../payments/planned_payment_log_screen.dart';
import '../payments/planned_payment_service.dart';
import '../theme/provider_assets.dart';
import '../ussd/sim_selection_controller.dart';
import '../ussd/ussd_builder.dart';
import '../ussd/ussd_dialer.dart';
import '../utilities/meter_entry_popup.dart';
import '../utilities/saved_meter_service.dart';
import '../widgets/coming_soon_popup.dart';
import 'pay/send_money_screen.dart';

/// The Pay tab — "Pay & services" (screen 11 of the redesign): a
/// searchable hub of every USSD service the app can run, with Send money
/// as the headline action ([SendMoneyScreen]).
///
/// Every tile direct-dials via [UssdDialer.runDirect] (same standardized
/// path as Send money). Only codes confirmed in [UssdBuilder] are wired;
/// anything unconfirmed (Urubuto, RRA, Cogebanque, KCB) is an honest
/// "coming soon" popup, never a guessed code. Bank tiles open the bank's
/// confirmed root menu and the user finishes on-screen.
class PayScreen extends StatefulWidget {
  const PayScreen({
    super.key,
    required this.contactsService,
    required this.categorizationService,
    required this.favoriteContactsService,
    required this.simSelectionController,
    required this.plannedPaymentService,
    this.accountsService,
    this.savedMeterService,
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

  /// Optional: shows the MTN MoMo balance on Send money.
  final AccountsService? accountsService;

  /// Optional: Electricity/Water offer the saved-meter popup first, the
  /// same convenience Home's quick actions have.
  final SavedMeterService? savedMeterService;

  @override
  State<PayScreen> createState() => _PayScreenState();
}

/// Which brand dot a tile wears.
enum _Network { mtn, airtel }

class _Service {
  const _Service(this.label, this.icon, this.run, {this.network, this.keywords = '', this.bank});

  final String label;
  final IconData icon;
  final Future<void> Function(_PayScreenState state) run;
  final _Network? network;

  /// Extra search terms ("power", "cash power", …).
  final String keywords;

  /// Monogram + brand colour for bank tiles instead of an icon.
  final (String, Color)? bank;

  bool matches(String query) =>
      query.isEmpty || '$label $keywords'.toLowerCase().contains(query.toLowerCase());
}

class _PayScreenState extends State<PayScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Opportunistic sweep (this app has no background-execution
    // machinery of its own — see PlannedPaymentService doc): every time
    // Pay opens is a natural moment to flip any stale pending row to
    // expired before it's shown in the log.
    unawaited(widget.plannedPaymentService.expireStale());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static Future<void> _comingSoon(_PayScreenState s, String feature, IconData icon) =>
      showComingSoonPopup(
        s.context,
        feature: feature,
        icon: icon,
        description: 'We haven\'t confirmed $feature\'s USSD code from a reliable source '
            'yet, so this app won\'t guess it.',
      );

  static final _sections = <(String, List<_Service>)>[
    (
      'Bills',
      [
        _Service(
          'Electricity',
          Icons.bolt_outlined,
          (s) => s._runUtility(
            service: MeterService.electricity,
            title: 'Electricity (Cash Power)',
            code: UssdBuilder.payElectricity(),
          ),
          keywords: 'cash power reg token',
        ),
        _Service(
          'Water',
          Icons.water_drop_outlined,
          (s) => s._runUtility(
            service: MeterService.water,
            title: 'Water (WASAC)',
            code: UssdBuilder.payWater(),
          ),
          keywords: 'wasac',
        ),
        _Service(
          'School fees Urubuto',
          Icons.school_outlined,
          (s) => _comingSoon(s, 'Urubuto (school fees)', Icons.school_outlined),
          keywords: 'urubuto',
        ),
        _Service(
          'Taxes RRA',
          Icons.receipt_long_outlined,
          (s) => _comingSoon(s, 'RRA (taxes)', Icons.receipt_long_outlined),
          keywords: 'rra tax',
        ),
      ],
    ),
    (
      'Airtime & data',
      [
        _Service('MTN Airtime', Icons.phone_iphone_rounded, (s) => s._buyMtnAirtime(),
            network: _Network.mtn, keywords: 'recharge'),
        _Service('MTN Bundles', Icons.wifi_rounded, (s) => s._run(UssdBuilder.mtnBundles()),
            network: _Network.mtn, keywords: 'data internet'),
        _Service(
          'Airtel Airtime',
          Icons.phone_android_rounded,
          (s) => s._run(UssdBuilder.airtelRechargeAirtime()),
          network: _Network.airtel,
          keywords: 'recharge',
        ),
        _Service('Airtel Bundles', Icons.wifi_rounded, (s) => s._run(UssdBuilder.airtelBundles()),
            network: _Network.airtel, keywords: 'data internet'),
        _Service(
          'Airtel Share',
          Icons.share_outlined,
          (s) => s._run(UssdBuilder.airtelShareAirtime()),
          network: _Network.airtel,
          keywords: 'share airtime',
        ),
      ],
    ),
    (
      'Balances & savings',
      [
        _Service(
          'MoMo balance',
          Icons.account_balance_wallet_outlined,
          (s) => s._run(UssdBuilder.checkBalance()),
          network: _Network.mtn,
        ),
        _Service(
          'Airtel balance',
          Icons.account_balance_wallet_outlined,
          (s) => s._run(UssdBuilder.checkAirtimeBalance()),
          network: _Network.airtel,
        ),
        // No confirmed menu-nested MoKash code — open the real MoMo
        // root menu and let the user finish on-screen (UssdBuilder doc).
        _Service('MoKash savings', Icons.savings_outlined, (s) => s._run(UssdBuilder.openMenu()),
            network: _Network.mtn, keywords: 'mokash loan'),
      ],
    ),
    (
      'Banks',
      [
        _Service('Bank of Kigali', Icons.account_balance_outlined,
            (s) => s._run(UssdBuilder.bankMenu(BankUssd.bk)),
            bank: ('BK', providerAccents['bk_bank_rw']!), keywords: 'bk'),
        _Service('BPR', Icons.account_balance_outlined,
            (s) => s._run(UssdBuilder.bankMenu(BankUssd.bpr)),
            bank: ('BPR', const Color(0xFF3A3A40))),
        _Service('I&M Bank', Icons.account_balance_outlined,
            (s) => s._run(UssdBuilder.bankMenu(BankUssd.imBank)),
            bank: ('I&M', const Color(0xFF3A3A40)), keywords: 'im'),
        _Service('Equity', Icons.account_balance_outlined,
            (s) => s._run(UssdBuilder.bankMenu(BankUssd.equity)),
            bank: ('EQ', providerAccents['equity_bank_rw']!)),
        _Service(
          'Cogebanque',
          Icons.account_balance_outlined,
          (s) => _comingSoon(s, 'Cogebanque', Icons.account_balance_outlined),
          bank: ('CG', const Color(0xFF3A3A40)),
        ),
        _Service(
          'KCB',
          Icons.account_balance_outlined,
          (s) => _comingSoon(s, 'KCB', Icons.account_balance_outlined),
          bank: ('KCB', const Color(0xFF3A3A40)),
        ),
      ],
    ),
  ];

  Future<void> _run(String code) async {
    final simSlot = await widget.simSelectionController.ensureChosen(context);
    if (!mounted) return;
    final outcome = await UssdDialer.runDirect(code, simSlotIndex: simSlot);
    if (!mounted || outcome != UssdRunOutcome.failed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not start this on this device.')),
    );
  }

  /// Electricity/Water: the saved-meter popup first (a convenience for
  /// reading the meter number onto the real USSD prompt — it never
  /// changes the dialed string), then the confirmed code.
  Future<void> _runUtility({
    required String service,
    required String title,
    required String code,
  }) async {
    final meters = widget.savedMeterService;
    if (meters != null) {
      final proceed = await showMeterEntryPopup(
        context,
        service: service,
        title: title,
        savedMeterService: meters,
      );
      if (proceed != true || !mounted) return;
    }
    await _run(code);
  }

  Future<void> _buyMtnAirtime() async {
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('MTN Airtime'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Amount (RWF)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Buy'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0 || !mounted) return;
    await _run(UssdBuilder.buyAirtime(amountRwf: amount));
  }

  void _openSendMoney() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SendMoneyScreen(
            contactsService: widget.contactsService,
            categorizationService: widget.categorizationService,
            favoriteContactsService: widget.favoriteContactsService,
            plannedPaymentService: widget.plannedPaymentService,
            simSelectionController: widget.simSelectionController,
            accountsService: widget.accountsService,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final showSend = 'send money transfer pay phone till merchant'.contains(_query.toLowerCase());
    final sections = [
      for (final (title, services) in _sections)
        (title, services.where((s) => s.matches(_query)).toList()),
    ].where((section) => section.$2.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title:
            Text('Pay & services', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search services, banks, bills',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear search',
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _query = '';
                      }),
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
          if (showSend) ...[
            const SizedBox(height: 16),
            _SendMoneyCard(onTap: _openSendMoney),
          ],
          for (final (title, services) in sections) ...[
            const SizedBox(height: 20),
            Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _ServiceGrid(
              services: services,
              onTap: (service) => service.run(this),
            ),
          ],
          if (sections.isEmpty && !showSend)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                'Nothing matches “$_query”.',
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Every tile dials directly and your network shows its own response. '
            'Bank tiles open that bank\'s real menu; finish the last step on-screen.',
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SendMoneyCard extends StatelessWidget {
  const _SendMoneyCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.north_east, color: scheme.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send money',
                      style: text.titleMedium
                          ?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      // MTN MoMo only: Airtel's send path is unconfirmed.
                      'From MTN MoMo to a phone number or till',
                      style:
                          text.bodySmall?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.services, required this.onTap});

  final List<_Service> services;
  final ValueChanged<_Service> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 8,
      childAspectRatio: 0.72,
      children: [
        for (final service in services) _ServiceTile(service: service, onTap: () => onTap(service)),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onTap});

  final _Service service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dot = switch (service.network) {
      _Network.mtn => providerAccents['mtn_momo_rw'],
      _Network.airtel => providerAccents['airtel_money_rw'],
      null => null,
    };
    final bank = service.bank;

    return Semantics(
      button: true,
      label: service.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bank?.$2 ?? scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: bank == null
                        ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: bank == null
                      ? Icon(service.icon, color: scheme.primary)
                      : Text(
                          bank.$1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                ),
                if (dot != null)
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              service.label,
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
