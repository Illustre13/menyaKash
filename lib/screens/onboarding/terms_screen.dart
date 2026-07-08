import 'package:flutter/material.dart';

/// Onboarding step 2 (spec Phase 5, Screen 2): terms, privacy, and data
/// usage explanation, shown before any permission or identity ask.
/// Continue is disabled until the user checks "I agree."
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Privacy')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  _Section(
                    title: 'Terms',
                    body: 'By using i-momo you agree that this app is a personal '
                        'spending tracker only. It does not initiate payments, hold '
                        'your money, or act on your behalf with any provider.',
                  ),
                  _Section(
                    title: 'Privacy Policy',
                    body: 'i-momo does not have a server, an account system, or an '
                        'analytics/telemetry pipeline. There is nothing to have a '
                        'privacy incident with, because there is nowhere for your '
                        'data to go.',
                  ),
                  _Section(
                    title: 'Data usage explanation',
                    body: 'Every mobile money and bank SMS this app reads stays on '
                        'this device, in a local database only. Nothing is uploaded, '
                        'synced, or shared — this app declares no internet '
                        'permission at all, so it has no way to send data anywhere '
                        'even if it wanted to.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _agreed,
                    onChanged: (value) => setState(() => _agreed = value ?? false),
                    title: const Text('I agree'),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
