import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shows the "Upgrade to Premium" popup (spec #5) — a dismissible modal
/// with 3 vertically-swipeable pages: Premium features (TBD, no real
/// billing exists yet — see below), Support (beta access + contact the
/// team), and what's already free today. Call this from any "Upgrade"
/// entry point (Settings, Profile, a future in-app banner).
Future<void> showPremiumPopup(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _PremiumPopup(),
  );
}

class _PremiumPopup extends StatefulWidget {
  const _PremiumPopup();

  @override
  State<_PremiumPopup> createState() => _PremiumPopupState();
}

class _PremiumPopupState extends State<_PremiumPopup> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppBrand.cardDark
              : AppBrand.cardLight,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
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
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _PremiumFeaturesPage(),
                  _SupportPage(),
                  _FreeTodayPage(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _page == i ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _page == i ? scheme.primary : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PopupPageScaffold extends StatelessWidget {
  const _PopupPageScaffold({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: iconColor),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

/// Page 1: Premium features. Deliberately no price, no "Buy now" — no
/// billing/IAP integration exists anywhere in this app yet (spec #11
/// confirmed this), so a checkout button here would be a lie. Each row
/// is explicitly labeled "Coming soon," matching this app's existing
/// rule of never implying a feature works before it does (see
/// settings_screen.dart's Data section for the same pattern).
class _PremiumFeaturesPage extends StatelessWidget {
  const _PremiumFeaturesPage();

  static const _features = <(IconData icon, String title, String description)>[
    (Icons.description_outlined, 'Statement export', 'Download your transaction history as PDF, Excel, or CSV.'),
    (Icons.save_outlined, 'Encrypted local backup', 'Move your history to a new phone without losing it — still never leaves your device.'),
    (Icons.groups_outlined, 'Family budgeting', 'Share budgets across more than one device.'),
    (Icons.auto_awesome_outlined, 'AI insights', 'Deeper spending patterns and recommendations.'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PopupPageScaffold(
      icon: Icons.workspace_premium_outlined,
      iconColor: scheme.primary,
      title: 'Unlock Premium',
      subtitle: 'Features we\'re building — details still to be confirmed.',
      children: [
        for (final (icon, title, description) in _features)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: scheme.primary),
                  const SizedBox(width: 12),
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
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppBrand.orangeLight.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Coming soon',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(description, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Page 2: Support — beta access, and how to reach the team directly.
/// No real ticketing/chat backend exists (this app has no network
/// capability), so "contact the team" opens the device's own share/mail
/// sheet with a pre-filled subject rather than an in-app chat widget
/// that would need a server.
class _SupportPage extends StatelessWidget {
  const _SupportPage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PopupPageScaffold(
      icon: Icons.support_agent_outlined,
      iconColor: scheme.secondary,
      title: 'Support & Beta',
      subtitle: 'You\'re using an early build — here\'s what that means.',
      children: [
        const _InfoRow(
          icon: Icons.science_outlined,
          title: 'Beta access',
          description: 'You already have it — every feature in Menya Kash today is '
              'part of the beta. New features land here first.',
        ),
        const SizedBox(height: 12),
        const _InfoRow(
          icon: Icons.mail_outline,
          title: 'Talk to the team',
          description: 'Found a bug or have an idea? Reach the production team directly.',
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact details coming soon.')),
          ),
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Contact the team'),
        ),
      ],
    );
  }
}

/// Page 3: what's already free today — the honest counterpart to page
/// 1's "coming soon" list, so the popup doesn't read as pure upsell.
class _FreeTodayPage extends StatelessWidget {
  const _FreeTodayPage();

  static const _included = <String>[
    'Unlimited MoMo & bank SMS tracking',
    'Automatic categorization',
    'Budgets with progress tracking',
    'Full spending insights & trends',
    'Everything stays on your device',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PopupPageScaffold(
      icon: Icons.verified_outlined,
      iconColor: AppBrand.income(Theme.of(context).brightness),
      title: 'Included, free, forever',
      subtitle: 'Premium adds on top of this — it never takes anything away.',
      children: [
        for (final item in _included)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.check_circle,
                    size: 20, color: AppBrand.income(Theme.of(context).brightness)),
                const SizedBox(width: 10),
                Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'No account, no cloud, no ads — that stays true whether or not '
          'you ever upgrade.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
