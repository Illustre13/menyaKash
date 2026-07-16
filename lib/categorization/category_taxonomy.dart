import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Menya Kash's default category taxonomy (spec #9) — replaces the
/// previous empty-by-default category list with a real, curated set
/// that reads as "financial intelligence platform," not a generic
/// expense tracker. Seeded once via [AppDatabase._seedCategories];
/// users can still rename/delete these and add their own — nothing
/// here is hardcoded into the schema, only into this lookup table, so
/// the category model itself stays exactly as extensible as before.
///
/// Order matters: [defaultCategorySeed] is seeded in this exact order,
/// and the categorize picker (`transactions_screen.dart`) renders
/// categories in seed/creation order, so this list is already sorted
/// "most frequently used first" per the spec (Transport/Food/Groceries
/// before the long tail like Taxes/Investments).
const List<(String name, String emoji)> defaultCategorySeed = [
  // Essentials
  ('Transport', '🚕'),
  ('Dining & Food', '🍽️'),
  ('Groceries', '🛒'),
  ('Rent & Housing', '🏠'),
  ('Bills & Utilities', '⚡'),
  ('Health & Wellness', '❤️'),
  ('Shopping & Clothing', '👕'),
  ('Personal Care', '🧴'),
  // Lifestyle
  ('Entertainment', '🎉'),
  ('Family & Friends', '👨‍👩‍👧'),
  ('Giving & Donations', '🎁'),
  // Growth
  ('Learning', '📚'),
  ('Business', '💼'),
  // Finance
  ('Income', '💰'),
  ('Transfers', '💸'),
  ('Savings', '🏦'),
  ('Fees & Charges', '💳'),
  ('Investments', '📈'),
  ('Taxes', '🧾'),
  // Assets
  ('Vehicle', '🚗'),
  // Miscellaneous
  ('Other', '📦'),
];

/// A default category's Material icon + brand-consistent color, keyed
/// by exact name. Every entry here corresponds 1:1 to
/// [defaultCategorySeed] — if a name is in one, it must be in the
/// other (enforced by the migration test, not just convention).
///
/// Colors are drawn from a small fixed palette across the app's
/// existing categorical/status hues (`AppBrand`, `ChartPalette`-
/// adjacent tones) grouped by taxonomy section, so e.g. every Finance
/// category reads in the same purple family without being identical —
/// consistent, not monotonous.
const Map<String, (IconData icon, Color color)> _defaultCategoryStyle = {
  // Essentials — warm, everyday tones.
  'Transport': (Icons.directions_car_rounded, Color(0xFF2563EB)),
  'Dining & Food': (Icons.restaurant_rounded, Color(0xFFEA580C)),
  'Groceries': (Icons.local_grocery_store_rounded, Color(0xFF16A34A)),
  'Rent & Housing': (Icons.home_rounded, Color(0xFF7C3AED)),
  'Bills & Utilities': (Icons.bolt_rounded, Color(0xFFCA8A04)),
  'Health & Wellness': (Icons.favorite_rounded, Color(0xFFDC2626)),
  'Shopping & Clothing': (Icons.checkroom_rounded, Color(0xFFDB2777)),
  'Personal Care': (Icons.spa_rounded, Color(0xFF0D9488)),
  // Lifestyle — social, expressive tones.
  'Entertainment': (Icons.celebration_rounded, Color(0xFFF5A623)),
  'Family & Friends': (Icons.diversity_1_rounded, Color(0xFFDB2777)),
  'Giving & Donations': (Icons.volunteer_activism_rounded, Color(0xFF16A34A)),
  // Growth — forward-looking tones.
  'Learning': (Icons.menu_book_rounded, Color(0xFF2563EB)),
  'Business': (Icons.work_rounded, Color(0xFF334155)),
  // Finance — brand purple family, ties to the app's own identity.
  'Income': (Icons.account_balance_wallet_rounded, Color(0xFF15803D)),
  'Transfers': (Icons.swap_horiz_rounded, Color(0xFF2563EB)),
  'Savings': (Icons.savings_rounded, Color(0xFF7F56D9)),
  'Fees & Charges': (Icons.receipt_long_rounded, Color(0xFF9C6208)),
  'Investments': (Icons.trending_up_rounded, Color(0xFF7F56D9)),
  'Taxes': (Icons.account_balance_rounded, Color(0xFF334155)),
  // Assets.
  'Vehicle': (Icons.directions_car_filled_rounded, Color(0xFF2563EB)),
  // Miscellaneous.
  'Other': (Icons.category_rounded, Color(0xFF64748B)),
};

/// Deterministic color for a custom (user-created) category's
/// initial-avatar — picked from the app's own categorical-adjacent
/// palette by a stable hash of the name, so "Shopping" always gets the
/// same color on every screen and every app launch, without storing
/// anything. Distinct from [_defaultCategoryStyle]'s hand-picked colors
/// (those are curated per-category; this is a consistent *generator*
/// for names that were never curated).
const List<Color> _customAvatarPalette = [
  Color(0xFF7F56D9),
  Color(0xFFF5A623),
  Color(0xFF2563EB),
  Color(0xFF16A34A),
  Color(0xFFDC2626),
  Color(0xFFDB2777),
  Color(0xFF0D9488),
  Color(0xFFCA8A04),
];

Color _customAvatarColorFor(String name) {
  final normalized = name.trim().toUpperCase();
  if (normalized.isEmpty) return _customAvatarPalette.first;
  return _customAvatarPalette[normalized.hashCode.abs() % _customAvatarPalette.length];
}

/// Whether [categoryName] is one of the curated defaults — the
/// distinction that decides icon-in-circle (default) vs.
/// initial-avatar (custom) rendering everywhere in the app.
bool isDefaultCategory(String categoryName) => _defaultCategoryStyle.containsKey(categoryName);

/// The category glyph + color for any category, default or custom.
/// Defaults render their curated Material icon; anything else falls
/// back to the old keyword heuristic (so categories created before
/// this taxonomy shipped, e.g. a user's own "Food" typed differently
/// than "Dining & Food", still get a sensible icon instead of looking
/// broken) and only reaches the generic fallback if nothing matches at
/// all. This function is icon-only — [CategoryAvatar] is what actually
/// decides icon-circle vs. initial-avatar for a given name.
(IconData icon, Color color) categoryStyle(String? categoryName) {
  if (categoryName == null) {
    return (Icons.help_outline_rounded, AppBrand.inkMutedLight);
  }
  final exact = _defaultCategoryStyle[categoryName];
  if (exact != null) return exact;
  return (_legacyKeywordIcon(categoryName), _customAvatarColorFor(categoryName));
}

/// Pre-taxonomy keyword fallback — kept only for categories that don't
/// exactly match a default name (typically pre-existing user data from
/// before this taxonomy shipped). New custom categories skip this
/// entirely and always render as an initial-avatar per spec #9; this
/// exists purely so old data doesn't regress to a blank icon.
IconData _legacyKeywordIcon(String categoryName) {
  final n = categoryName.toLowerCase();
  if (n.contains('food') || n.contains('restaurant') || n.contains('bakery')) {
    return Icons.restaurant_rounded;
  }
  if (n.contains('transport') || n.contains('taxi') || n.contains('moto') || n.contains('fuel')) {
    return Icons.directions_car_rounded;
  }
  if (n.contains('bill') || n.contains('utilit') || n.contains('electric') || n.contains('water')) {
    return Icons.receipt_long_rounded;
  }
  if (n.contains('shop')) return Icons.shopping_bag_rounded;
  if (n.contains('airtime') || n.contains('data') || n.contains('bundle')) {
    return Icons.phone_iphone_rounded;
  }
  if (n.contains('health') || n.contains('pharma') || n.contains('hospital') || n.contains('hopital')) {
    return Icons.medical_services_rounded;
  }
  if (n.contains('school') || n.contains('educat')) return Icons.school_rounded;
  if (n.contains('rent') || n.contains('house') || n.contains('home')) return Icons.home_rounded;
  if (n.contains('family') || n.contains('friend')) return Icons.favorite_rounded;
  if (n.contains('business') || n.contains('work')) return Icons.work_rounded;
  if (n.contains('saving') || n.contains('invest')) return Icons.savings_rounded;
  return Icons.category_rounded;
}

/// The one widget every screen should use to render a category's
/// identity (spec #9's "Custom Category Behavior"): a default category
/// shows its curated Material icon in a tinted circle; a custom
/// category shows the first character of its name in a colored
/// circular avatar — no icon picker, no manual step, always automatic.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.categoryName, this.size = 40});

  final String? categoryName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = categoryName;
    if (name == null || !isDefaultCategory(name)) {
      return _InitialAvatar(name: name ?? '?', size: size);
    }
    final (icon, color) = categoryStyle(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _customAvatarColorFor(name);
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
