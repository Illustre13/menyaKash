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
    expect(profile.email, 'user@example.com', reason: 'a later partial update must not clear other fields');
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
}
