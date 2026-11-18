import 'package:flutter/material.dart';

/// Onboarding Terms & Privacy (spec Phase 5, redesigned in the UI
/// sprint's #4): expandable sections with icons instead of a wall of
/// text, "I agree" gating unchanged. The copy leads with this app's
/// strongest real guarantee — no internet permission exists, so data
/// cannot leave the phone.
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key, this.onContinue});

  /// Null shows the terms read-only (no "I agree" gate) — how Welcome's
  /// "Terms of use" / "Privacy policy" links open it now that agreeing
  /// is "By continuing…" on the Welcome screen itself.
  final VoidCallback? onContinue;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Privacy')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off_outlined, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Menya Kash has no internet permission. Your money '
                            'data physically cannot leave this phone.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _TermsSection(
                    icon: Icons.gavel_outlined,
                    title: 'Terms of use',
                    initiallyExpanded: true,
                    body: 'Menya Kash is a personal spending tracker. It reads '
                        'the transaction SMS your providers already send you '
                        'and turns them into insights. It does not initiate '
                        'payments, hold your money, or act on your behalf with '
                        'any provider — the Pay feature only pre-fills your '
                        'phone\'s own dialer, and you always confirm yourself.',
                  ),
                  const _TermsSection(
                    icon: Icons.lock_outline,
                    title: 'Privacy',
                    body: 'There is no server, no account system, and no '
                        'analytics or tracking of any kind. Menya Kash cannot '
                        'have a data breach on your behalf, because there is '
                        'nowhere for your data to go.',
                  ),
                  const _TermsSection(
                    icon: Icons.storage_outlined,
                    title: 'How your data is used',
                    body: 'Every mobile money and bank SMS this app reads stays '
                        'in a local database on this device only. It is used to '
                        'build your transaction history, balances, and spending '
                        'analytics — nothing else. Uninstalling the app deletes '
                        'everything.',
                  ),
                ],
              ),
            ),
            if (widget.onContinue != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: _agreed,
                      onChanged: (value) => setState(() => _agreed = value ?? false),
                      title: const Text('I agree to the terms and privacy policy'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _agreed ? widget.onContinue : null,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Continue'),
                        ),
                      ),
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

class _TermsSection extends StatelessWidget {
  const _TermsSection({
    required this.icon,
    required this.title,
    required this.body,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Remove ExpansionTile's default divider lines so the card
        // reads as one clean surface.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, color: scheme.primary),
          title: Text(title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
