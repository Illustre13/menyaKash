import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/utilities/saved_meter_service.dart';

void main() {
  late AppDatabase db;
  late SavedMeterService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = SavedMeterService(db);
  });

  tearDown(() => db.close());

  test('meterFor returns null when nothing is saved yet', () async {
    expect(await service.meterFor(MeterService.electricity), isNull);
  });

  test('save then meterFor round-trips the meter number', () async {
    await service.save(MeterService.electricity, '123456789');
    expect(await service.meterFor(MeterService.electricity), '123456789');
  });

  test('saving twice for the same service updates in place, not duplicates '
      '(the confirmed real drift upsert bug class)', () async {
    await service.save(MeterService.electricity, '111');
    await service.save(MeterService.electricity, '222');
    final rows = await db.select(db.savedMeterNumbers).get();
    expect(rows, hasLength(1));
    expect(await service.meterFor(MeterService.electricity), '222');
  });

  test('electricity and water meters coexist independently', () async {
    await service.save(MeterService.electricity, '111');
    await service.save(MeterService.water, '222');
    expect(await service.meterFor(MeterService.electricity), '111');
    expect(await service.meterFor(MeterService.water), '222');
  });

  test('clear removes the saved meter', () async {
    await service.save(MeterService.electricity, '111');
    await service.clear(MeterService.electricity);
    expect(await service.meterFor(MeterService.electricity), isNull);
  });
}
