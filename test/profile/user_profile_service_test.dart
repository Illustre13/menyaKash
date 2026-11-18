import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/profile/user_profile_service.dart';

void main() {
  late AppDatabase db;
  late UserProfileService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = UserProfileService(db);
  });

  tearDown(() => db.close());

  test('no profile exists until something creates one', () async {
    expect(await service.currentProfile(), isNull);
    expect(await service.hasCompletedOnboarding(), isFalse);
  });

  test('updateProfile creates a row on first call and updates fields on later calls', () async {
    await service.updateProfile(email: 'user@example.com');
    var profile = await service.currentProfile();
    expect(profile!.email, 'user@example.com');
    expect(profile.displayName, isNull);

    await service.updateProfile(displayName: 'Alice');
    profile = await service.currentProfile();
    expect(profile!.displayName, 'Alice');
    expect(profile.email, 'user@example.com',
        reason: 'a later partial update must not clear other fields');
  });

  test('setAppLockEnabled persists independently of profile creation order', () async {
    await service.setAppLockEnabled(true);
    final profile = await service.currentProfile();
    expect(profile!.appLockEnabled, isTrue);
  });

  test('markOnboardingComplete transitions onboardingCompletedAt from null to set, exactly once',
      () async {
    expect(await service.hasCompletedOnboarding(), isFalse);

    await service.markOnboardingComplete();
    expect(await service.hasCompletedOnboarding(), isTrue);

    final firstCompletedAt = (await service.currentProfile())!.onboardingCompletedAt;

    await service.markOnboardingComplete();
    final secondCompletedAt = (await service.currentProfile())!.onboardingCompletedAt;
    expect(secondCompletedAt, isNotNull);
    expect(firstCompletedAt, isNotNull);
  });

  group('App Lock reminder rules', () {
    Future<UserProfileData> profileAfterOpens(int opens) async {
      for (var i = 0; i < opens; i++) {
        await service.recordAppOpen();
      }
      return (await service.currentProfile())!;
    }

    test('recordAppOpen counts launches from 1', () async {
      expect(await service.recordAppOpen(), 1);
      expect(await service.recordAppOpen(), 2);
    });

    test('waits for the 3rd app open', () async {
      expect(UserProfileService.shouldShowAppLockReminder(await profileAfterOpens(2)), isFalse);
      expect(UserProfileService.shouldShowAppLockReminder(await profileAfterOpens(1)), isTrue);
    });

    test('never shows once App Lock is on', () async {
      await profileAfterOpens(3);
      await service.setAppLockEnabled(true);
      expect(UserProfileService.shouldShowAppLockReminder(await service.currentProfile()), isFalse);
    });

    test('"Not now" snoozes 7 days, and two dismissals stop it for good', () async {
      await profileAfterOpens(3);
      final now = DateTime(2026, 11, 1);

      await service.snoozeAppLockReminder(now: now);
      var profile = (await service.currentProfile())!;
      expect(profile.appLockReminderDismissals, 1);
      expect(
          UserProfileService.shouldShowAppLockReminder(profile,
              now: now.add(const Duration(days: 6))),
          isFalse);
      expect(
          UserProfileService.shouldShowAppLockReminder(profile,
              now: now.add(const Duration(days: 8))),
          isTrue);

      await service.snoozeAppLockReminder(now: now.add(const Duration(days: 8)));
      profile = (await service.currentProfile())!;
      expect(
          UserProfileService.shouldShowAppLockReminder(profile,
              now: now.add(const Duration(days: 60))),
          isFalse);
    });
  });

  test('setup checklist hide and "sorted" flags persist', () async {
    await service.setSetupChecklistHidden(true);
    await service.markTransactionsSorted();
    final profile = (await service.currentProfile())!;
    expect(profile.setupChecklistHidden, isTrue);
    expect(profile.setupSortedAt, isNotNull);
  });
}
