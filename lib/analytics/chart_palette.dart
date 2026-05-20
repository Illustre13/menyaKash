import 'package:flutter/material.dart';

/// Validated categorical palette (dataviz skill reference palette).
/// Fixed hue order — never cycled arbitrarily; a category is always
/// assigned the same slot for the life of the app via [colorFor].
class ChartPalette {
  ChartPalette._();

  static const categoricalLight = <Color>[
    Color(0xFF2A78D6), // blue
    Color(0xFF1BAF7A), // aqua
    Color(0xFFEDA100), // yellow
    Color(0xFF008300), // green
    Color(0xFF4A3AA7), // violet
    Color(0xFFE34948), // red
    Color(0xFFE87BA4), // magenta
    Color(0xFFEB6834), // orange
  ];

  static const categoricalDark = <Color>[
    Color(0xFF3987E5),
    Color(0xFF199E70),
    Color(0xFFC98500),
    Color(0xFF008300),
    Color(0xFF9085E9),
    Color(0xFFE66767),
    Color(0xFFD55181),
    Color(0xFFD95926),
  ];

  /// Single sequential hue (blue) for magnitude-over-time charts.
  static const sequentialLight = Color(0xFF2A78D6);
  static const sequentialDark = Color(0xFF3987E5);

  static const mutedLight = Color(0xFF898781);
  static const mutedDark = Color(0xFF898781);
  static const gridlineLight = Color(0xFFE1E0D9);
  static const gridlineDark = Color(0xFF2C2C2A);

  /// Stable slot assignment for a category name so the same category
  /// always renders the same color across app sessions and screens.
  /// Categories beyond the 8 fixed slots fold visually (same hue,
  /// distinguished only via the legend/table) rather than generating
  /// new, potentially non-CVD-safe hues.
  static Color colorFor(String categoryName, {required bool isDark}) {
    final palette = isDark ? categoricalDark : categoricalLight;
    final slot = categoryName.hashCode.abs() % palette.length;
    return palette[slot];
  }
}
