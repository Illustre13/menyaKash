import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/profile/referral_service.dart';

void main() {
  late AppDatabase db;
  late ReferralService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ReferralService(db);
  });

  tearDown(() => db.close());

  test('generates and persists a code for the profile', () async {
    await db.into(db.userProfile).insert(const UserProfileCompanion());
    final code = await service.currentCode();
    expect(code, startsWith('KASH-'));

    final profile = await db.select(db.userProfile).getSingle();
    expect(profile.referralCode, code);
  });

  test('returns the same code on repeated reads (does not regenerate)', () async {
    await db.into(db.userProfile).insert(const UserProfileCompanion());
    final first = await service.currentCode();
    final second = await service.currentCode();
    expect(first, second);
  });

  test('two different profiles (across two databases) get different codes', () async {
    final otherDb = AppDatabase.forTesting(NativeDatabase.memory());
    final otherService = ReferralService(otherDb);
    try {
      // Both rows land at id=1 in their own in-memory database, so the
      // code must actually vary with createdAt too, not just id —
      // explicit, distinct timestamps make that a real assertion rather
      // than one that happens to pass because the clock ticked.
      await db.into(db.userProfile).insert(
            UserProfileCompanion.insert(createdAt: Value(DateTime.utc(2026, 1, 1))),
          );
      await otherDb.into(otherDb.userProfile).insert(
            UserProfileCompanion.insert(createdAt: Value(DateTime.utc(2026, 6, 15))),
          );

      final codeA = await service.currentCode();
      final codeB = await otherService.currentCode();
      expect(codeA, isNot(codeB));
    } finally {
      await otherDb.close();
    }
  });

  test('falls back gracefully with no profile row yet', () async {
    final code = await service.currentCode();
    expect(code, startsWith('KASH-'));
  });
}
