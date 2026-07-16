import 'package:flutter/material.dart';

/// Menya Kash brand system — matches the logo (purple "i" swoosh with an
/// orange accent dot and upward arrow, see assets/brand/menyacash.svg,
/// menyacash.png, menyacash.ico).
///
/// Every color below was checked against WCAG contrast before being
/// chosen — see the design notes in docs/ARCHITECTURE.md §Brand. Chart
/// *data* colors (category bars/pies, trend lines) intentionally use a
/// separate, already-validated categorical palette (`ChartPalette`)
/// rather than these brand colors — brand identity and data-series
/// identity are different jobs and mixing them would make the same hue
/// mean two different things on the same screen.
class AppBrand {
  AppBrand._();

  // Primary — brand purple, straight from the logo. Contrast vs white
  // text 4.96:1, vs light surface 4.83:1 (both clear WCAG AA 4.5:1 for
  // normal text). Only 3.51:1 on the dark surface, so dark mode uses a
  // lightened step instead (see purpleDark).
  static const purpleLight = Color(0xFF7F56D9);
  static const purpleDark = Color(0xFFA98CE8); // vs dark surface 6.31:1

  // Accent — brand orange, straight from the logo's dot. At full
  // brightness it only clears ~2:1 on both white text and the light
  // surface, so it's reserved for large marks/icons/badges (the 3:1
  // large-graphic floor) and the dark surface (8.59:1) — never for
  // small light-mode body text. orangeButtonLight is a deepened step
  // for anywhere a light-mode button/chip needs white text (5.04:1).
  static const orangeLight = Color(0xFFF5A623);
  static const orangeButtonLight = Color(0xFF9C6208);
  static const orangeDark = Color(0xFFF5A623); // vs dark surface 8.59:1

  static const surfaceLight = Color(0xFFFAFAFA);
  static const surfaceDark = Color(0xFF1A1A19);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF232322);

  static const inkPrimaryLight = Color(0xFF111827);
  static const inkPrimaryDark = Color(0xFFFFFFFF);
  static const inkMutedLight = Color(0xFF5B6472);
  static const inkMutedDark = Color(0xFFC3C2B7);

  // Status — reserved meaning, never reused as a data-series color.
  static const statusGood = Color(0xFF15803D);
  static const statusCritical = Color(0xFFDC2626);

  // Semantic money colors (UI sprint): every amount in the app wears
  // exactly one of these. The light steps are deepened from the spec
  // hues (#16A34A / #DC2626 / #2563EB) where needed so small bold text
  // clears WCAG AA 4.5:1 on white cards; the dark steps are lightened
  // for the dark surface. Never reused as chart-series colors.
  static const incomeLight = Color(0xFF15803D); // green-700, 5.0:1 on white
  static const incomeDark = Color(0xFF4ADE80);
  static const expenseLight = Color(0xFFDC2626); // spec red, 4.5:1 on white
  static const expenseDark = Color(0xFFF87171);
  static const transferLight = Color(0xFF2563EB); // spec blue, 5.2:1 on white
  static const transferDark = Color(0xFF60A5FA);

  static Color income(Brightness b) => b == Brightness.dark ? incomeDark : incomeLight;
  static Color expense(Brightness b) => b == Brightness.dark ? expenseDark : expenseLight;
  static Color transfer(Brightness b) => b == Brightness.dark ? transferDark : transferLight;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppBrand.purpleLight,
      brightness: Brightness.light,
      primary: AppBrand.purpleLight,
      secondary: AppBrand.orangeButtonLight,
      surface: AppBrand.surfaceLight,
    );
    return _themeFrom(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppBrand.purpleDark,
      brightness: Brightness.dark,
      primary: AppBrand.purpleDark,
      secondary: AppBrand.orangeDark,
      surface: AppBrand.surfaceDark,
    );
    return _themeFrom(scheme);
  }

  static ThemeData _themeFrom(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? scheme.primary : scheme.onSurfaceVariant);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        // Pure white cards on the #FAFAFA canvas (UI sprint) — the card
        // IS the elevation cue, so no border+shadow stacking.
        color: scheme.brightness == Brightness.dark ? AppBrand.cardDark : AppBrand.cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        labelStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.surfaceContainerHigh;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.onSurface;
          }),
        ),
      ),
      textTheme: Typography.material2021(colorScheme: scheme).black.apply(
            displayColor: scheme.onSurface,
            bodyColor: scheme.onSurface,
          ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5)),
    );
  }
}

/// A small branded header used at the top of primary screens — the
/// logo mark (assets/brand/menyacash.png) plus the wordmark. Keeps the
/// brand present without repeating a heavy hero banner on every screen.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final logoHeight = compact ? 26.0 : 32.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/brand/menyacash.png', height: logoHeight),
        SizedBox(width: compact ? 8 : 10),
        Text(
          'Menya Kash',
          style: TextStyle(
            fontSize: compact ? 16 : 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
