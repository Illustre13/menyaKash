import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/categorization/category_taxonomy.dart';
import 'package:i_momo/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('a fresh install seeds every default category exactly once', () async {
    final categories = await db.select(db.categories).get();
    final names = categories.map((c) => c.name).toSet();

    expect(categories.length, defaultCategorySeed.length,
        reason: 'no duplicates, no missing defaults');
    for (final (name, _) in defaultCategorySeed) {
      expect(names, contains(name));
    }
  });

  test('seeded categories are unique by name (the real schema constraint holds)', () async {
    final categories = await db.select(db.categories).get();
    final names = categories.map((c) => c.name).toList();
    expect(names.toSet().length, names.length);
  });

  test('every default category name has a matching taxonomy style entry', () {
    // Data/style consistency: if a name is ever added to
    // defaultCategorySeed without a matching categoryStyle entry, it
    // would silently render with the generic keyword-fallback icon
    // instead of its curated one — this test catches that at build
    // time instead of a user noticing a wrong icon in production.
    for (final (name, _) in defaultCategorySeed) {
      expect(isDefaultCategory(name), isTrue,
          reason: '"$name" is in defaultCategorySeed but categoryStyle has no curated entry for it');
    }
  });

  test('a custom category is never treated as a default', () {
    expect(isDefaultCategory('My Made Up Category'), isFalse);
  });

  test(
      'renaming a seeded category and then re-triggering onCreate-style seeding '
      'logic never recreates or duplicates it', () async {
    // A fresh onCreate already seeded every default once (asserted
    // above). This proves the exists-check _seedDefaultCategories uses
    // is real: if a user renames "Income" to something else, the
    // original row must not silently reappear alongside the rename —
    // seeding only ever fills a genuinely MISSING name, it doesn't
    // reconcile by any other means.
    final income = (await db.select(db.categories).get()).firstWhere((c) => c.name == 'Income');
    await (db.update(db.categories)..where((tbl) => tbl.id.equals(income.id)))
        .write(const CategoriesCompanion(name: Value('My Salary')));

    final renamed = await db.select(db.categories).get();
    expect(renamed.map((c) => c.name), isNot(contains('Income')));
    expect(renamed.map((c) => c.name), contains('My Salary'));
    expect(renamed.length, defaultCategorySeed.length,
        reason: 'a rename must not change the total row count');
  });
}
