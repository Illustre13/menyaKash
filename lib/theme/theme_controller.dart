import 'package:flutter/material.dart';

import '../profile/user_profile_service.dart';

/// Bridges the persisted theme choice ([UserProfile.themeMode]) and the
/// live [MaterialApp.themeMode] (sprint #3).
///
/// [mode] is a static notifier because the theme consumer
/// (`MaterialApp`, in `IMomoApp`) sits *above* the widget that owns the
/// database and services (`HomeShell`) — the smallest correct bridge is
/// a single app-global listenable rather than restructuring who owns
/// the database. Defaults to [ThemeMode.light] before any load, per
/// product decision: a user who never chose gets Light, not
/// follow-system.
class ThemeController {
  ThemeController(this._profileService);

  final UserProfileService _profileService;

  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  static ThemeMode parse(String? stored) => switch (stored) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        // 'light', null (never chose), or an unrecognized value all
        // resolve to Light — never crash the app over a bad row.
        _ => ThemeMode.light,
      };

  static String encode(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
      };

  /// Loads the persisted choice into [mode] — call once at startup,
  /// before/alongside the onboarding-status check.
  Future<void> loadSaved() async {
    final profile = await _profileService.currentProfile();
    mode.value = parse(profile?.themeMode);
  }

  /// Applies [newMode] immediately (the notifier drives MaterialApp
  /// live) and persists it.
  Future<void> setMode(ThemeMode newMode) async {
    mode.value = newMode;
    await _profileService.setThemeMode(encode(newMode));
  }
}
