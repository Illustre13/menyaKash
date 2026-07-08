import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Onboarding step 4 (spec Phase 5, Screen 3 continued): "Enable App
/// Lock?" — gated on a real successful `local_auth` round-trip so the
/// flag is never persisted unless the device can actually satisfy it.
/// Skipping is always allowed; app lock can be turned on later from
/// Settings.
class SecuritySetupScreen extends StatefulWidget {
  const SecuritySetupScreen({super.key, required this.onContinue});

  /// Called with whether app lock ended up enabled.
  final ValueChanged<bool> onContinue;

  @override
  State<SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends State<SecuritySetupScreen> {
  final _localAuth = LocalAuthentication();
  bool _checking = false;
  String? _error;

  Future<void> _enableAppLock() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!canCheck) {
        setState(() {
          _checking = false;
          _error = 'This device has no fingerprint, face, PIN, or pattern lock set up.';
        });
        return;
      }

      final confirmed = await _localAuth.authenticate(
        localizedReason: 'Confirm to enable App Lock for i-momo',
        options: const AuthenticationOptions(biometricOnly: false),
      );

      if (!mounted) return;
      if (confirmed) {
        widget.onContinue(true);
      } else {
        setState(() {
          _checking = false;
          _error = 'Couldn\'t confirm — try again.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Couldn\'t reach the device\'s lock screen. Try again, or skip for now.';
      });
    }
  }

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
                const Icon(Icons.fingerprint, size: 56),
                const SizedBox(height: 24),
                Text(
                  'Enable App Lock?',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Use your fingerprint, face, PIN, or pattern to keep your '
                  'spending history private if someone else picks up your '
                  'phone. You can change this later in Settings.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                if (_checking)
                  const CircularProgressIndicator()
                else ...[
                  FilledButton(
                    onPressed: _enableAppLock,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Text('Enable App Lock'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onContinue(false),
                    child: const Text('Not now'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
