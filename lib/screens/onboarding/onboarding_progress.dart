import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Shared top bar for onboarding's Providers → SMS access steps:
/// optional back chevron, a segmented progress bar, and an optional
/// Skip. Keeping it in one widget is what makes the steps read as one
/// flow instead of unrelated pages.
class OnboardingProgressHeader extends StatelessWidget {
  const OnboardingProgressHeader({
    super.key,
    required this.step,
    this.total = 2,
    this.onBack,
    this.onSkip,
  });

  /// 1-based index of the current screen.
  final int step;
  final int total;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Back',
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Semantics(
              label: 'Step $step of $total',
              child: Row(
                children: [
                  for (var i = 1; i <= total; i++) ...[
                    if (i > 1) const SizedBox(width: 6),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= step
                              ? scheme.primary
                              : scheme.outlineVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (onSkip != null) ...[
            const SizedBox(width: 12),
            TextButton(onPressed: onSkip, child: const Text('Skip')),
          ] else if (onBack != null)
            // Balances the back button so the bar stays centred.
            const SizedBox(width: 56),
        ],
      ),
    );
  }
}

/// Big bold onboarding headline, shared so every step matches.
TextStyle? onboardingTitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        );

/// Green "nothing leaves this phone" note, the app's strongest real
/// guarantee (there is no INTERNET permission at all).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final green = AppBrand.income(brightness);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppBrand.statusGood.withValues(alpha: brightness == Brightness.dark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: green.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: green, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
