import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../theme/app_theme.dart';

/// Onboarding Security Setup (spec Phase 5, redesigned in the UI
/// sprint's #7): "Enable App Lock?" — gated on a real successful
/// `local_auth` round-trip so the flag is never persisted unless the
/// device can actually satisfy it. Skipping is always allowed; app
/// lock can be turned on later from Settings.
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
        localizedReason: 'Confirm to enable App Lock for Menya Kash',
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shield_outlined, size: 48, color: scheme.primary),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Protect your money data',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your spending history is sensitive. App Lock keeps it private '
                'even if someone else picks up your phone.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const _SecurityMethodCard(
                icon: Icons.fingerprint,
                title: 'Fingerprint or Face',
                subtitle: 'Fastest — uses the biometrics already on your phone',
              ),
              const SizedBox(height: 10),
              const _SecurityMethodCard(
                icon: Icons.pin_outlined,
                title: 'Device PIN or Pattern',
                subtitle: 'Falls back to your phone\'s own screen lock',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 16, color: AppBrand.statusGood),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Menya Kash never stores a password — unlocking is handled '
                      'entirely by your phone\'s own lock screen.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Confirmed real UX gap (user report: a lock screen
              // appearing "during onboarding" was actually this
              // screen's own local_auth confirmation, but the OS's own
              // biometric/PIN chrome carries no Menya Kash branding —
              // easy to misread as being locked out. This line is
              // upfront that tapping the button below hands off to
              // your phone's own screen, once, right now — not a
              // recurring lock happening unexpectedly.
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tapping "Enable App Lock" opens your phone\'s own unlock screen '
                      'once, just to confirm it works — that\'s expected, not an error.',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: scheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              if (_checking)
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        'Waiting for your phone\'s lock screen…',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              else ...[
                FilledButton.icon(
                  onPressed: _enableAppLock,
                  icon: const Icon(Icons.lock_outline),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
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
    );
  }
}

class _SecurityMethodCard extends StatelessWidget {
  const _SecurityMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
