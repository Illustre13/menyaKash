import 'package:drift/drift.dart';

import '../data/database.dart';

/// Stable machine keys for [SavedMeterNumbers.service] — never a
/// display string (that lives in the calling screen), mirrors how
/// [FinancialProviders.code] works.
class MeterService {
  MeterService._();

  static const electricity = 'electricity';
  static const water = 'water';
}

/// Read/write surface for [SavedMeterNumbers] (review batch item #3) —
/// a convenience so the user doesn't retype their meter number every
/// time on the real on-screen USSD prompt. Mirrors
/// [FavoriteContactsService]'s shape: constructor takes [AppDatabase],
/// explicit exists-check before insert rather than
/// `insertOnConflictUpdate` (this codebase's established convention —
/// drift's upsert conflict target defaults to the primary key, not a
/// declared `uniqueKeys` column, so an exists-check is the safe path).
class SavedMeterService {
  SavedMeterService(this._db);

  final AppDatabase _db;

  Future<String?> meterFor(String service) async {
    final row = await (_db.select(_db.savedMeterNumbers)
          ..where((tbl) => tbl.service.equals(service)))
        .getSingleOrNull();
    return row?.meterNumber;
  }

  Future<void> save(String service, String meterNumber) async {
    final existing = await (_db.select(_db.savedMeterNumbers)
          ..where((tbl) => tbl.service.equals(service)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.savedMeterNumbers).insert(
            SavedMeterNumbersCompanion.insert(service: service, meterNumber: meterNumber),
          );
      return;
    }
    await (_db.update(_db.savedMeterNumbers)..where((tbl) => tbl.id.equals(existing.id)))
        .write(SavedMeterNumbersCompanion(meterNumber: Value(meterNumber)));
  }

  Future<void> clear(String service) async {
    await (_db.delete(_db.savedMeterNumbers)..where((tbl) => tbl.service.equals(service))).go();
  }
}
