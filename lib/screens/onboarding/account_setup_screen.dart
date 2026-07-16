import 'package:flutter/material.dart';

import '../../profile/email_verification_service.dart';

/// Onboarding Account Setup (spec Phase 5, reworked in the UI sprint's
/// #5): create the local profile identity via email. Verification is
/// delegated to [EmailVerificationService] — the current offline build
/// completes after format validation (no delivery channel exists, so no
/// fake code ceremony is shown), while the code-entry step below
/// activates automatically once a real-delivery implementation is
/// plugged in. A Skip option always moves straight on to Security
/// Setup.
class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({
    super.key,
    required this.onContinue,
    required this.onSkip,
    this.verificationService = const LocalNoDeliveryEmailVerification(),
  });

  /// Called with the accepted email once verification (as defined by
  /// [verificationService]) completes.
  final ValueChanged<String> onContinue;

  final VoidCallback onSkip;

  final EmailVerificationService verificationService;

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
  bool _busy = false;
  String? _codeError;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();

  Future<void> _submitEmail() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);

    final start = await widget.verificationService.startVerification(_email);
    if (!mounted) return;

    switch (start) {
      case EmailVerificationStart.notRequired:
        widget.onContinue(_email);
      case EmailVerificationStart.codeSent:
        setState(() {
          _stage = _Stage.codeEntry;
          _busy = false;
          _codeError = null;
        });
    }
  }

  Future<void> _confirmCode() async {
    setState(() => _busy = true);
    final ok = await widget.verificationService.confirmCode(
      email: _email,
      code: _codeController.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      widget.onContinue(_email);
    } else {
      setState(() {
        _busy = false;
        _codeError = 'That code doesn\'t match. Check your inbox and try again.';
      });
    }
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
                busy: _busy,
                onContinue: _submitEmail,
              ),
            _Stage.codeEntry => _CodeEntry(
                email: _email,
                controller: _codeController,
                error: _codeError,
                busy: _busy,
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
    required this.busy,
    required this.onContinue,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.alternate_email, size: 40, color: scheme.primary),
            ),
          ),
          Text(
            'Create your profile',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add an email so this device knows who this profile belongs to.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Enter an email address';
              if (!_emailPattern.hasMatch(value.trim())) return 'That doesn\'t look like an email';
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy ? null : onContinue,
            child: busy
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

/// Code entry for real-delivery verification — inert in the current
/// offline build (see [LocalNoDeliveryEmailVerification]) and activated
/// automatically once an implementation returns
/// [EmailVerificationStart.codeSent].
class _CodeEntry extends StatelessWidget {
  const _CodeEntry({
    required this.email,
    required this.controller,
    required this.error,
    required this.busy,
    required this.onConfirm,
    required this.onBack,
  });

  final String email;
  final TextEditingController controller;
  final String? error;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Check your inbox', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Enter the verification code sent to $email.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: 'Verification code',
            border: const OutlineInputBorder(),
            errorText: error,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: busy ? null : onConfirm, child: const Text('Confirm')),
        TextButton(onPressed: onBack, child: const Text('Back')),
      ],
    );
  }
}
