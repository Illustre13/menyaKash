import 'package:flutter/material.dart';

import '../../profile/user_profile_service.dart';
import 'app_lock_setup_screen.dart';

/// "Keep your balance private" (screen 7 of the onboarding redesign).
/// Home shows it at launch when [UserProfileService.shouldShowAppLockReminder]
/// says so: from the 3rd app open, while App Lock is off. "Not now" (or
/// swiping it away) snoozes 7 days; two dismissals stop it for good.
///
/// Returns true if App Lock ended up turned on.
Future<bool> showAppLockReminderSheet(
  BuildContext context, {
  required UserProfileService profileService,
  required int dismissalsSoFar,
}) async {
  final turnOn = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => _AppLockReminderSheet(lastReminder: dismissalsSoFar >= 1),
  );
  if (!context.mounted) return false;
  if (turnOn != true) {
    await profileService.snoozeAppLockReminder();
    return false;
  }
  final enabled = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => AppLockSetupScreen(profileService: profileService)),
  );
  return enabled ?? false;
}

class _AppLockReminderSheet extends StatelessWidget {
  const _AppLockReminderSheet({required this.lastReminder});

  /// This is the second (final) showing, so don't promise another.
  final bool lastReminder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.lock_outline, color: scheme.primary, size: 30),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Keep your balance private',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Right now anyone holding your phone can open Menya Kash. Lock it '
              'with your fingerprint, face or PIN. It takes 10 seconds.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('Turn on App Lock'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
            const SizedBox(height: 4),
            Text(
              lastReminder
                  ? 'We won’t ask again. You can turn it on any time in Settings.'
                  : 'We’ll remind you once more next week. You can also turn it on in Settings.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
