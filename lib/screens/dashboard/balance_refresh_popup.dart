import 'package:flutter/material.dart';

import '../../accounts/accounts_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/provider_assets.dart';
import '../../ussd/sim_selection_controller.dart';
import '../../ussd/ussd_builder.dart';
import '../../ussd/ussd_dialer.dart';

/// Manual balance-refresh popup (review batch item #3): "some
/// providers — especially banks — might not always send the SMS for a
/// transaction, so the app's balance can go stale even though nothing
/// is wrong with the parser." This lets the user pick which accounts
/// to check and dials each one's real USSD balance/menu code directly.
///
/// Important honesty constraint, same as every other USSD feature in
/// this app: dialing a code only shows the *network's own* response on
/// screen — this app has no Accessibility Service and cannot read that
/// response back, so it cannot auto-update the stored balance from it.
/// The real balance figure only updates once the resulting SMS (if any)
/// arrives and is parsed normally. This popup is upfront about that
/// rather than implying a silent instant refresh.
Future<void> showBalanceRefreshPopup(
  BuildContext context, {
  required List<AccountSummary> accounts,
  required SimSelectionController simSelectionController,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _BalanceRefreshPopup(
      accounts: accounts,
      simSelectionController: simSelectionController,
    ),
  );
}

/// Which USSD action a given provider actually supports checking, per
/// this app's confirmed-real-codes-only rule. Not every provider has a
/// verified one-tap balance readout — see [UssdBuilder]'s own doc for
/// why menu-nested paths aren't guessed at.
enum _CheckKind {
  /// A confirmed real balance-check code (MTN MoMo's *182*6*1#) —
  /// dials straight to the balance prompt.
  directBalance,

  /// No confirmed balance-specific code exists; opens the provider's
  /// real root menu instead, and the user finds "balance" themselves
  /// on the real on-screen menu.
  rootMenuOnly,
}

class _BalanceRefreshPopup extends StatefulWidget {
  const _BalanceRefreshPopup({required this.accounts, required this.simSelectionController});

  final List<AccountSummary> accounts;
  final SimSelectionController simSelectionController;

  @override
  State<_BalanceRefreshPopup> createState() => _BalanceRefreshPopupState();
}

class _BalanceRefreshPopupState extends State<_BalanceRefreshPopup> {
  late final Set<int> _selectedAccountIds = widget.accounts.map((a) => a.account.id).toSet();
  bool _checking = false;

  (_CheckKind, String) _checkFor(String providerCode) {
    return switch (providerCode) {
      'mtn_momo_rw' => (_CheckKind.directBalance, UssdBuilder.checkBalance()),
      'airtel_money_rw' => (
          _CheckKind.rootMenuOnly,
          UssdBuilder.openMenu(provider: UssdProvider.airtelMoney),
        ),
      'bk_bank_rw' => (_CheckKind.rootMenuOnly, UssdBuilder.bankMenu(BankUssd.bk)),
      'equity_bank_rw' => (_CheckKind.rootMenuOnly, UssdBuilder.bankMenu(BankUssd.equity)),
      _ => (_CheckKind.rootMenuOnly, UssdBuilder.openMenu()),
    };
  }

  Future<void> _runChecks() async {
    final selected =
        widget.accounts.where((a) => _selectedAccountIds.contains(a.account.id)).toList();
    if (selected.isEmpty) return;

    setState(() => _checking = true);
    final simSlot = await widget.simSelectionController.ensureChosen(context);
    if (!mounted) return;
    for (final account in selected) {
      final (_, code) = _checkFor(account.providerCode);
      // One at a time, awaited in sequence: dialing a second USSD code
      // while the first's native response dialog is still on screen
      // would interrupt it — the user needs to see and dismiss each
      // one before the next opens.
      await UssdDialer.runDirect(code, simSlotIndex: simSlot);
    }
    if (!mounted) return;
    setState(() => _checking = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppBrand.cardDark
              : AppBrand.cardLight,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Icon(Icons.sync, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Check real balances', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'A transaction\'s SMS can arrive late or not at all, so the '
                'balance shown here can lag behind reality — especially for '
                'banks. Pick which accounts to check; each dials that '
                'provider\'s real USSD code so you can see the actual balance '
                'on screen. This app can\'t read that response automatically '
                '— the stored figure only updates once a real SMS confirms it.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final account in widget.accounts)
                    _AccountCheckTile(
                      account: account,
                      checkKind: _checkFor(account.providerCode).$1,
                      selected: _selectedAccountIds.contains(account.account.id),
                      onChanged: (v) => setState(() {
                        if (v) {
                          _selectedAccountIds.add(account.account.id);
                        } else {
                          _selectedAccountIds.remove(account.account.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _checking || _selectedAccountIds.isEmpty ? null : _runChecks,
                  icon: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.phone_in_talk_outlined),
                  label: Text(_checking ? 'Checking...' : 'Check selected'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCheckTile extends StatelessWidget {
  const _AccountCheckTile({
    required this.account,
    required this.checkKind,
    required this.selected,
    required this.onChanged,
  });

  final AccountSummary account;
  final _CheckKind checkKind;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CheckboxListTile(
      value: selected,
      onChanged: (v) => onChanged(v ?? false),
      secondary: ProviderLogo(
        providerCode: account.providerCode,
        displayName: account.providerDisplayName,
        size: 32,
      ),
      title: Text(account.account.label),
      subtitle: Text(
        checkKind == _CheckKind.directBalance
            ? 'Dials straight to the balance prompt'
            : 'Opens the real menu — find "balance" on screen',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }
}
