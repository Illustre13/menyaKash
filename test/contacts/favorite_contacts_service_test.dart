import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/contacts/favorite_contacts_service.dart';
import 'package:i_momo/data/database.dart';

void main() {
  late AppDatabase db;
  late FavoriteContactsService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = FavoriteContactsService(db);
  });

  tearDown(() => db.close());

  test('favoriting normalizes the number before storing', () async {
    await service.favorite('+250 788 123 456');
    expect(await service.favoritedNumbers(), {'0788123456'});
  });

  test('favoriting twice does not duplicate or throw (the confirmed real drift upsert bug class)',
      () async {
    await service.favorite('0788123456');
    await service.favorite('0788123456');
    final rows = await db.select(db.favoriteContacts).get();
    expect(rows, hasLength(1));
  });

  test('a malformed number is silently ignored, never stored', () async {
    await service.favorite('not a real number');
    expect(await service.favoritedNumbers(), isEmpty);
  });

  test('unfavoriting removes it', () async {
    await service.favorite('0788123456');
    await service.unfavorite('0788123456');
    expect(await service.favoritedNumbers(), isEmpty);
  });

  test('two different real numbers coexist as two rows', () async {
    await service.favorite('0788123456');
    await service.favorite('0722222222');
    expect(await service.favoritedNumbers(), {'0788123456', '0722222222'});
  });
}
