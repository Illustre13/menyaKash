import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Onboarding step 1 (spec Phase 5, Screen 1): brand-focused value prop,
/// shown before any permission or data-entry ask.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(),
                const SizedBox(height: 40),
                Text(
                  'Track your money automatically.',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const _ValueLine(text: 'Understand spending.'),
                const _ValueLine(text: 'Manage budgets.'),
                const _ValueLine(text: 'Improve financial decisions.'),
                const SizedBox(height: 40),
                FilledButton(
                  onPressed: onContinue,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                    child: Text('Get Started'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ValueLine extends StatelessWidget {
  const _ValueLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
    );
  }
}
