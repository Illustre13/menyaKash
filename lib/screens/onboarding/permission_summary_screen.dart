import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Final explainer before any OS permission dialog appears (sprint #9):
/// one card per permission the app will actually request, in plain
/// language, so nothing in the upcoming system prompts is a surprise.
///
/// Deliberately lists only permissions genuinely declared in the
/// manifest (SMS, Contacts, Phone) — advertising a permission the app
/// never requests (e.g. notifications, which this app has no feature
/// for) would undermine the exact trust this screen exists to build.
class PermissionSummaryScreen extends StatelessWidget {
  const PermissionSummaryScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Before we ask')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Menya Kash will ask for these permissions',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Everything stays on this phone. There is no internet '
                    'permission in this app at all — nothing can be uploaded, '
                    'even by mistake.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  const _PermissionCard(
                    icon: Icons.sms_outlined,
                    title: 'SMS',
                    description: 'Read mobile money and bank transaction '
                        'notifications to build your spending history.',
                    requiredBadge: true,
                  ),
                  const SizedBox(height: 12),
                  const _PermissionCard(
                    icon: Icons.contacts_outlined,
                    title: 'Contacts',
                    description: 'Pick a recipient by name instead of typing '
                        'their number when sending money.',
                  ),
                  const SizedBox(height: 12),
                  const _PermissionCard(
                    icon: Icons.phone_outlined,
                    title: 'Phone',
                    description: 'Open your dialer with the USSD payment code '
                        'pre-filled. You always confirm and send it yourself.',
                  ),
                  const SizedBox(height: 12),
                  const _PermissionCard(
                    icon: Icons.sim_card_outlined,
                    title: 'SIM info',
                    description: 'If your phone has two SIMs, let you choose which '
                        'one dials a payment — never used to read your phone '
                        'number or any other identifier.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onContinue,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Got it — continue'),
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

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    this.requiredBadge = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool requiredBadge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (requiredBadge) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppBrand.orangeLight.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Required',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
