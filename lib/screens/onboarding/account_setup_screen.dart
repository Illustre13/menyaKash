import 'dart:math';

import 'package:flutter/material.dart';

/// Onboarding step 3 (spec Phase 5, Screen 3): create the local user
/// identity via email. There is deliberately no real OTP delivery here
/// — this app declares no internet permission and has no
/// network-capable dependency, so there is no path to actually send a
/// code anywhere. The "confirmation code" is generated and shown on
/// this device's own screen; re-entering it only confirms the user
/// read the screen and typed their email correctly, not that they own
/// the mailbox. A Skip option is always available and moves straight
/// on to Security Setup — phone verification is deferred to a later
/// pass, not part of this flow.
class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({
    super.key,
    required this.onContinue,
    required this.onSkip,
  });

  /// Called with the confirmed email once the user completes the
  /// code-entry step.
  final ValueChanged<String> onContinue;

  final VoidCallback onSkip;

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

enum _Stage { emailEntry, codeEntry }

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();

  _Stage _stage = _Stage.emailEntry;
  String? _generatedCode;
  String? _codeError;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _sendCode() {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _generatedCode = (100000 + Random().nextInt(900000)).toString();
      _stage = _Stage.codeEntry;
      _codeError = null;
    });
  }

  void _confirmCode() {
    if (_codeController.text.trim() == _generatedCode) {
      widget.onContinue(_emailController.text.trim());
      return;
    }
    setState(() => _codeError = 'That code doesn\'t match — check the screen and try again.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Setup'),
        actions: [
          TextButton(onPressed: widget.onSkip, child: const Text('Skip')),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_stage) {
            _Stage.emailEntry => _EmailEntry(
                formKey: _emailFormKey,
                controller: _emailController,
                onContinue: _sendCode,
              ),
            _Stage.codeEntry => _CodeEntry(
                email: _emailController.text.trim(),
                code: _generatedCode!,
                controller: _codeController,
                error: _codeError,
                onConfirm: _confirmCode,
                onBack: () => setState(() => _stage = _Stage.emailEntry),
              ),
          },
        ),
      ),
    );
  }
}

class _EmailEntry extends StatelessWidget {
  const _EmailEntry({
    required this.formKey,
    required this.controller,
    required this.onContinue,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Create your profile',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add an email so this device remembers who this profile belongs '
            'to. This stays on your phone — nothing is ever sent.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Enter an email address';
              if (!_emailPattern.hasMatch(value.trim())) return 'That doesn\'t look like an email';
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onContinue, child: const Text('Continue')),
        ],
      ),
    );
  }
}

class _CodeEntry extends StatelessWidget {
  const _CodeEntry({
    required this.email,
    required this.code,
    required this.controller,
    required this.error,
    required this.onConfirm,
    required this.onBack,
  });

  final String email;
  final String code;
  final TextEditingController controller;
  final String? error;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Confirm your email', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'This code was generated on your device for $email — it was not '
          'sent anywhere. Type it below to confirm.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            code,
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 4),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: 'Confirmation code',
            border: const OutlineInputBorder(),
            errorText: error,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onConfirm, child: const Text('Confirm')),
        TextButton(onPressed: onBack, child: const Text('Back')),
      ],
    );
  }
}
