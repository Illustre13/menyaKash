import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'onboarding_progress.dart';
import 'terms_screen.dart';

/// Onboarding 1 · Welcome + terms: the value prop and, folded into the
/// "Get started" tap, agreement to the terms (linked, readable without
/// leaving onboarding). Replaces the separate Terms checkbox step.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  void _openTerms(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const TermsScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: muted);
    final link = small?.copyWith(color: scheme.primary, decoration: TextDecoration.underline);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Image.asset('assets/images/menyacash_icon.png', height: 56),
                      const SizedBox(height: 28),
                      Text('See where your money goes', style: onboardingTitleStyle(context)),
                      const SizedBox(height: 12),
                      Text(
                        'All your mobile money and bank accounts in one place, built '
                        'from the SMS you already get.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: muted),
                      ),
                      const SizedBox(height: 32),
                      const _ValueRow(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Every balance, one total',
                        body: 'MoMo, Airtel Money, banks and more',
                      ),
                      const _ValueRow(
                        icon: Icons.insights_outlined,
                        title: 'Clear spending insights',
                        body: 'See who and what your money goes to',
                        accent: true,
                      ),
                      const _ValueRow(
                        icon: Icons.verified_user_outlined,
                        title: 'Private by design',
                        body: 'No internet access. Data never leaves your phone.',
                        good: true,
                      ),
                    ],
                  ),
                ),
              ),
              FilledButton(
                onPressed: onContinue,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Get started'),
                ),
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: small,
                  children: [
                    const TextSpan(text: 'By continuing you agree to our '),
                    TextSpan(
                      text: 'Terms of use',
                      style: link,
                      recognizer: TapGestureRecognizer()..onTap = () => _openTerms(context),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy policy',
                      style: link,
                      recognizer: TapGestureRecognizer()..onTap = () => _openTerms(context),
                    ),
                    const TextSpan(text: '. '),
                    TextSpan(
                      text: 'How your data is used',
                      style: link,
                      recognizer: TapGestureRecognizer()..onTap = () => _openTerms(context),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.icon,
    required this.title,
    required this.body,
    this.accent = false,
    this.good = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool accent;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = good
        ? AppBrand.income(Theme.of(context).brightness)
        : accent
            ? scheme.secondary
            : scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
