import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';

/// `SmsIngestService.scanNewMessagesSince`/`scanHistoricalInbox` can't be
/// unit-tested directly — `telephony_pkg.Telephony.instance` is a hard
/// singleton with no injection seam, the same reason this codebase has
/// no existing test file for `SmsIngestService` at all (real coverage
/// for the ingestion pipeline comes from the pure isolate-parsing
/// functions in `isolate_parsing_test.dart`/`provider_aware_scan_test.dart`
/// plus manual on-device testing). This file instead directly verifies
/// the one new piece of persisted state the incremental-refresh feature
/// (review batch item #3) depends on: `UserProfile.lastIncrementalScanAt`
/// round-trips correctly, matching the read/write shape
/// `SmsIngestService` uses internally.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('lastIncrementalScanAt is null until anything sets it', () async {
    final profile = await db.select(db.userProfile).getSingleOrNull();
    expect(profile, isNull, reason: 'no profile row exists until onboarding creates one');
  });

  test('lastIncrementalScanAt can be created and updated on the profile row', () async {
    final id = await db
        .into(db.userProfile)
        .insert(UserProfileCompanion.insert(lastIncrementalScanAt: Value(DateTime(2026, 7, 1))));

    var profile = await (db.select(db.userProfile)..where((tbl) => tbl.id.equals(id))).getSingle();
    expect(profile.lastIncrementalScanAt, DateTime(2026, 7, 1));

    await (db.update(db.userProfile)..where((tbl) => tbl.id.equals(id)))
        .write(UserProfileCompanion(lastIncrementalScanAt: Value(DateTime(2026, 7, 15))));

    profile = await (db.select(db.userProfile)..where((tbl) => tbl.id.equals(id))).getSingle();
    expect(profile.lastIncrementalScanAt, DateTime(2026, 7, 15),
        reason: 'the watermark must advance, not stay pinned to its first value');
  });
}
