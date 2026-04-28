import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('categorizing a code is remembered for future lookups', () async {
    final categoryId = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'Food'));

    await db.assignCodeToCategory('55123', categoryId);

    final found = await db.findCategoryByCode('55123');
    expect(found, isNotNull);
    expect(found!.name, 'Food');
  });

  test('unknown code has no category', () async {
    final found = await db.findCategoryByCode('does-not-exist');
    expect(found, isNull);
  });
}
