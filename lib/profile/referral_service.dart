import 'package:drift/drift.dart';

import '../data/database.dart';

/// Generates and persists this device's shareable referral code (spec
/// #6). Purely local: there is no backend to issue, track, or redeem a
/// code against, so this is presentation-only — a stable string a user
/// can show or share, not a coupon/attribution system.
class ReferralService {
  ReferralService(this._db);

  final AppDatabase _db;

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Returns the current profile's referral code, generating and
  /// persisting one first if this profile has never had one (a fresh
  /// install, or an upgrade from before schemaVersion 10). Deterministic
  /// per profile row — derived from [UserProfileData.id] and
  /// [UserProfileData.createdAt], not [DateTime.now]/random, so it never
  /// changes across app restarts or re-reads.
  Future<String> currentCode() async {
    final profile = await _db.select(_db.userProfile).getSingleOrNull();
    if (profile == null) {
      // Onboarding hasn't created a profile row yet; nothing to key a
      // code off. Callers only reach the referral screen post-onboarding
      // in practice, so this is a defensive fallback, not an expected path.
      return _codeFrom(0, DateTime.now());
    }
    if (profile.referralCode != null) return profile.referralCode!;

    final code = _codeFrom(profile.id, profile.createdAt);
    await (_db.update(_db.userProfile)..where((tbl) => tbl.id.equals(profile.id)))
        .write(UserProfileCompanion(referralCode: Value(code)));
    return code;
  }

  String _codeFrom(int profileId, DateTime createdAt) {
    // Simple, dependency-free hash: no cryptographic property needed,
    // just a stable, evenly-spread 6-character code from these two
    // inputs. `crypto`'s sha256 (already a dependency, used for SMS
    // dedup) would work too but is overkill for a display code.
    var seed = profileId * 2654435761 + createdAt.millisecondsSinceEpoch;
    final chars = StringBuffer();
    for (var i = 0; i < 6; i++) {
      seed = (seed ^ (seed >> 13)) * 1274126177 + i;
      final index = seed.abs() % _alphabet.length;
      chars.write(_alphabet[index]);
    }
    return 'KASH-${chars.toString()}';
  }
}
