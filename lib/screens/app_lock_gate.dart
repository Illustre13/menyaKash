import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../theme/app_theme.dart';

/// Gates access to [child] behind the device's own biometric/PIN/
/// pattern prompt whenever [enabled] is true (review batch item #5) —
/// the confirmed real gap where `UserProfile.appLockEnabled` was stored
/// and displayed in Settings but never actually checked anywhere:
/// onboarding's Security Setup screen persisted the flag after a real
/// `local_auth` round-trip, but nothing re-checked it at launch, so the
/// dashboard opened unconditionally regardless of the setting.
///
/// Locks on first build (cold start) AND every time the app returns
/// from the background ([AppLifecycleState.resumed]) — an app lock that
/// only checks at cold start would leave the dashboard wide open to
/// anyone who simply reopens the still-running app from the recents
/// tray, which defeats the feature's own stated purpose ("keeps it
/// private even if someone else picks up your phone").
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final _localAuth = LocalAuthentication();
  bool _unlocked = false;
  bool _authenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.enabled) {
      _authenticate();
    } else {
      _unlocked = true;
    }
  }

  @override
  void didUpdateWidget(AppLockGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    // App Lock was just turned on/off in Settings (same running
    // session) — re-evaluate rather than keep whatever state applied
    // under the old setting.
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        setState(() => _unlocked = false);
        _authenticate();
      } else {
        setState(() => _unlocked = true);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;
    // Re-lock on every return from background — a cold-start-only
    // check would leave an already-running app's dashboard reachable
    // just by switching back to it from the recents tray.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_unlocked) setState(() => _unlocked = false);
    } else if (state == AppLifecycleState.resumed && !_unlocked && !_authenticating) {
      _authenticate();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _authenticate() async {
    setState(() {
      _authenticating = true;
      _error = null;
    });

    try {
      final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!canCheck) {
        // No lock method is actually set up on this device anymore
        // (e.g. the user removed their PIN after enabling App Lock) —
        // failing closed here would permanently strand a real user out
        // of their own data with no way back in, which is worse than
        // the security gap this screen exists to close. Let them
        // through; Settings still shows App Lock as enabled so they
        // can revisit it.
        if (!mounted) return;
        setState(() {
          _unlocked = true;
          _authenticating = false;
        });
        return;
      }

      final confirmed = await _localAuth.authenticate(
        localizedReason: 'Unlock Menya Kash',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (!mounted) return;
      setState(() {
        _authenticating = false;
        if (confirmed) {
          _unlocked = true;
        } else {
          _error = 'Couldn\'t confirm — try again.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authenticating = false;
        _error = 'Couldn\'t reach the device\'s lock screen. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline, size: 48, color: scheme.primary),
              ),
              const SizedBox(height: 20),
              const BrandMark(),
              const SizedBox(height: 12),
              Text(
                'Locked for your privacy',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: scheme.error), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              if (_authenticating)
                const CircularProgressIndicator()
              else
                FilledButton.icon(
                  onPressed: _authenticate,
                  icon: const Icon(Icons.fingerprint),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Text('Unlock'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
