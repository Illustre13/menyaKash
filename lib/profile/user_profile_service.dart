import 'package:drift/drift.dart';

import '../data/database.dart';

/// Read/write surface for the single local [UserProfile] row (spec
/// Phase 5 identity, Phase 7 Profile/Settings screens). Mirrors
/// [AccountsService]'s shape: constructor takes [AppDatabase], no
/// hidden state.
class UserProfileService {
  UserProfileService(this._db);

  final AppDatabase _db;

  /// The single profile row, or null if onboarding has never created
  /// one yet (should only happen transiently, mid-onboarding).
  Future<UserProfileData?> currentProfile() {
    return _db.select(_db.userProfile).getSingleOrNull();
  }

  /// Creates the profile row if none exists, otherwise updates the
  /// given fields on the existing one. Onboarding calls this once per
  /// step as the user fills in each field, so it must work whether or
  /// not a row already exists.
  Future<void> updateProfile({
    String? displayName,
    String? email,
    String? phone,
    String? avatarPath,
  }) async {
    final existing = await currentProfile();
    if (existing == null) {
      await _db.into(_db.userProfile).insert(
            UserProfileCompanion.insert(
              displayName: Value(displayName),
              email: Value(email),
              phone: Value(phone),
              avatarPath: Value(avatarPath),
            ),
          );
      return;
    }

    await (_db.update(_db.userProfile)..where((tbl) => tbl.id.equals(existing.id))).write(
      UserProfileCompanion(
        displayName: displayName != null ? Value(displayName) : const Value.absent(),
        email: email != null ? Value(email) : const Value.absent(),
        phone: phone != null ? Value(phone) : const Value.absent(),
        avatarPath: avatarPath != null ? Value(avatarPath) : const Value.absent(),
      ),
    );
  }

  /// Persists whether app lock is enabled. Callers must have already
  /// run a successful `local_auth` authenticate() round-trip before
  /// calling this with `true` — this service has no way to verify that
  /// itself, so the gating is the caller's responsibility (onboarding's
  /// Security Setup screen and Settings' Security section both do this
  /// before calling here).
  Future<void> setAppLockEnabled(bool enabled) async {
    final existing = await currentProfile();
    if (existing == null) {
      await _db.into(_db.userProfile).insert(
            UserProfileCompanion.insert(appLockEnabled: Value(enabled)),
          );
      return;
    }
    await (_db.update(_db.userProfile)..where((tbl) => tbl.id.equals(existing.id)))
        .write(UserProfileCompanion(appLockEnabled: Value(enabled)));
  }

  /// Persists the theme choice ('light' | 'dark' | 'system' — see
  /// [UserProfile.themeMode]). Creates the profile row if onboarding
  /// hasn't created one yet, same as [setAppLockEnabled].
  Future<void> setThemeMode(String mode) async {
    final existing = await currentProfile();
    if (existing == null) {
      await _db.into(_db.userProfile).insert(
            UserProfileCompanion.insert(themeMode: Value(mode)),
          );
      return;
    }
    await (_db.update(_db.userProfile)..where((tbl) => tbl.id.equals(existing.id)))
        .write(UserProfileCompanion(themeMode: Value(mode)));
  }

  /// Persists Home's balance-hide preference (review batch item #6).
  /// Creates the profile row if needed, same as [setAppLockEnabled].
  Future<void> setBalanceHidden(bool hidden) async {
    final existing = await currentProfile();
    if (existing == null) {
      await _db.into(_db.userProfile).insert(
            UserProfileCompanion.insert(balanceHidden: Value(hidden)),
          );
      return;
    }
    await (_db.update(_db.userProfile)..where((tbl) => tbl.id.equals(existing.id)))
        .write(UserProfileCompanion(balanceHidden: Value(hidden)));
  }

  /// Marks onboarding as complete — called once, at the end of the
  /// Phase 6 provider-selection step. [HomeShell] checks this (not SMS
  /// permission state) to decide whether to show onboarding.
  Future<void> markOnboardingComplete() async {
    final existing = await currentProfile();
    if (existing == null) {
      await _db.into(_db.userProfile).insert(
            UserProfileCompanion.insert(onboardingCompletedAt: Value(DateTime.now())),
          );
      return;
    }
    await (_db.update(_db.userProfile)..where((tbl) => tbl.id.equals(existing.id)))
        .write(UserProfileCompanion(onboardingCompletedAt: Value(DateTime.now())));
  }

  Future<bool> hasCompletedOnboarding() async {
    final profile = await currentProfile();
    return profile?.onboardingCompletedAt != null;
  }

  /// Upserts [companion] onto the single profile row.
  Future<void> _write(UserProfileCompanion companion) async {
    final existing = await currentProfile();
    if (existing == null) {
      await _db.into(_db.userProfile).insert(companion);
      return;
    }
    await (_db.update(_db.userProfile)..where((tbl) => tbl.id.equals(existing.id)))
        .write(companion);
  }

  /// Counts one app launch (post-onboarding) and returns the new total —
  /// the App Lock reminder waits for the 3rd open.
  Future<int> recordAppOpen() async {
    final count = ((await currentProfile())?.appOpenCount ?? 0) + 1;
    await _write(UserProfileCompanion(appOpenCount: Value(count)));
    return count;
  }

  /// Hides (or brings back) Home's "Finish setting up" checklist.
  Future<void> setSetupChecklistHidden(bool hidden) =>
      _write(UserProfileCompanion(setupChecklistHidden: Value(hidden)));

  /// Ticks the checklist's "Sort your transactions" step.
  Future<void> markTransactionsSorted() =>
      _write(UserProfileCompanion(setupSortedAt: Value(DateTime.now())));

  /// The App Lock reminder's "Not now": snooze 7 days and count the
  /// dismissal (two stop it for good — see [shouldShowAppLockReminder]).
  Future<void> snoozeAppLockReminder({DateTime? now}) async {
    final profile = await currentProfile();
    final at = now ?? DateTime.now();
    await _write(UserProfileCompanion(
      appLockReminderDismissals: Value((profile?.appLockReminderDismissals ?? 0) + 1),
      appLockReminderSnoozedUntil: Value(at.add(const Duration(days: 7))),
    ));
  }

  /// Reminder rules: from the 3rd app open, only while App Lock is off,
  /// at most two "Not now"s, and never inside a 7-day snooze.
  static bool shouldShowAppLockReminder(UserProfileData? profile, {DateTime? now}) {
    if (profile == null || profile.appLockEnabled) return false;
    if (profile.appOpenCount < 3) return false;
    if (profile.appLockReminderDismissals >= 2) return false;
    final until = profile.appLockReminderSnoozedUntil;
    return until == null || (now ?? DateTime.now()).isAfter(until);
  }
}
