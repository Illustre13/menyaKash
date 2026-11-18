import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../profile/user_profile_service.dart';
import '../../theme/app_theme.dart';

/// App Lock setup (screen 8 of the onboarding redesign) — reached from
/// Home's "Finish setting up" checklist and the App Lock reminder sheet,
/// no longer from onboarding itself. A short checklist with one clear
/// button. Gated on a real successful `local_auth` round-trip so the
/// flag is never persisted unless the device can actually satisfy it.
/// Pops `true` once App Lock is on, `false` for "Maybe later".
class AppLockSetupScreen extends StatefulWidget {
  const AppLockSetupScreen({super.key, required this.profileService});

  final UserProfileService profileService;

  @override
  State<AppLockSetupScreen> createState() => _AppLockSetupScreenState();
}

class _AppLockSetupScreenState extends State<AppLockSetupScreen> {
  final _localAuth = LocalAuthentication();
  bool _checking = false;
  String? _error;

  Future<void> _enableAppLock() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    final result = await confirmDeviceLock(_localAuth);
    if (!mounted) return;
    if (result == null) {
      await widget.profileService.setAppLockEnabled(true);
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _checking = false;
        _error = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('App Lock')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(Icons.fingerprint, size: 48, color: scheme.primary),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Lock your money data',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Open Menya Kash with your fingerprint, face or phone PIN, '
                        'so no one else can see your spending.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: muted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      // A plain checklist, not tappable-looking cards: the
                      // old per-method cards suggested the user had to pick
                      // one, but the phone decides which method to show.
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: const Column(
                          children: [
                            _ChecklistItem(
                              icon: Icons.check,
                              good: true,
                              title: 'Uses your phone\u2019s own lock.',
                              body: 'Fingerprint, face, PIN or pattern.',
                              stacked: true,
                            ),
                            SizedBox(height: 18),
                            _ChecklistItem(
                              icon: Icons.check,
                              good: true,
                              title: 'No new password.',
                              body: 'Menya Kash never sees or stores it.',
                            ),
                            SizedBox(height: 18),
                            // Confirmed real UX gap: the OS unlock prompt has
                            // no Menya Kash branding and was misread as being
                            // locked out — say up front that it appears once.
                            _ChecklistItem(
                              icon: Icons.info_outline,
                              good: false,
                              body: 'Your phone will ask you to unlock once, to check it works.',
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(color: scheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _checking ? null : _enableAppLock,
                icon: _checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(_checking ? 'Waiting for your phone\u2026' : 'Turn on App Lock'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _checking ? null : () => Navigator.of(context).pop(false),
                child: const Text('Maybe later'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({
    required this.icon,
    required this.good,
    required this.body,
    this.title,
    this.stacked = false,
  });

  final IconData icon;

  /// Green tick for a benefit, purple for a heads-up.
  final bool good;
  final String? title;
  final String body;

  /// Put [body] on its own line under [title] instead of running on.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = good ? AppBrand.statusGood : scheme.primary;
    final style = Theme.of(context).textTheme.bodyMedium;
    final muted = style?.copyWith(color: scheme.onSurfaceVariant);
    final bold = style?.copyWith(fontWeight: FontWeight.w700);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: Icon(icon,
              size: 18, color: good ? AppBrand.income(Theme.of(context).brightness) : color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text.rich(
              TextSpan(children: [
                if (title != null) TextSpan(text: stacked ? '$title\n' : '$title ', style: bold),
                TextSpan(text: body, style: muted),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Runs the phone's own unlock prompt once to prove App Lock will work.
/// Returns null on success, or a message to show. Shared by the App Lock
/// setup screen and the scan screen's "Turn on" shortcut.
Future<String?> confirmDeviceLock(LocalAuthentication localAuth) async {
  try {
    final canCheck = await localAuth.canCheckBiometrics || await localAuth.isDeviceSupported();
    if (!canCheck) return 'This device has no fingerprint, face, PIN, or pattern lock set up.';
    final confirmed = await localAuth.authenticate(
      localizedReason: 'Confirm to enable App Lock for Menya Kash',
      options: const AuthenticationOptions(biometricOnly: false),
    );
    return confirmed ? null : 'Couldn\'t confirm — try again.';
  } catch (_) {
    return 'Couldn\'t reach the device\'s lock screen. Try again, or skip for now.';
  }
}
