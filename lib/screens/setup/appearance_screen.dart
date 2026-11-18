import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';

/// Appearance (screen 9 of the onboarding redesign) — lives in Settings
/// now rather than in onboarding, which defaults everyone to Auto. Mini
/// phone previews instead of plain text rows; the choice is applied and
/// persisted only on Save, so backing out leaves the theme unchanged.
class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  ThemeMode _selected = ThemeController.mode.value;

  Future<void> _save() async {
    await widget.themeController.setMode(_selected);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Image.asset('assets/images/menyacash_icon.png', height: 40),
              ),
              const SizedBox(height: 14),
              Text(
                'Choose your look',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
              ),
              const SizedBox(height: 6),
              Text(
                'Pick what feels right. You can change it any time in Settings.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              ThemeModePicker(
                selected: _selected,
                onChanged: (mode) => setState(() => _selected = mode),
              ),
              const SizedBox(height: 14),
              Text(
                'Auto follows your phone\u2019s setting.',
                style:
                    Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three Light / Dark / Auto preview tiles in a row.
class ThemeModePicker extends StatelessWidget {
  const ThemeModePicker({super.key, required this.selected, required this.onChanged});

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      (ThemeMode.light, Icons.light_mode_outlined, 'Light'),
      (ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
      (ThemeMode.system, Icons.desktop_windows_outlined, 'Auto'),
    ];
    return Row(
      children: [
        for (final (i, (mode, icon, label)) in options.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _ThemeTile(
              mode: mode,
              icon: icon,
              label: label,
              selected: selected == mode,
              onTap: () => onChanged(mode),
            ),
          ),
        ],
      ],
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.mode,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label theme',
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: 0.10) : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.4),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AspectRatio(aspectRatio: 0.72, child: _PhonePreview(mode: mode)),
                    if (selected)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                          child: Icon(Icons.check, size: 14, color: scheme.onPrimary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Scales down rather than overflowing on narrow phones.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: scheme.onSurface),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tiny drawn mock of the dashboard in a given theme. Auto shows the
/// light half on the left and the dark half on the right.
class _PhonePreview extends StatelessWidget {
  const _PhonePreview({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: switch (mode) {
        ThemeMode.light => const _MiniScreen(dark: false),
        ThemeMode.dark => const _MiniScreen(dark: true),
        ThemeMode.system => const Stack(
            fit: StackFit.expand,
            children: [
              _MiniScreen(dark: true),
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.5,
                  child: _MiniScreen(dark: false),
                ),
              ),
            ],
          ),
      },
    );
  }
}

class _MiniScreen extends StatelessWidget {
  const _MiniScreen({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? AppBrand.surfaceDark : AppBrand.cardLight;
    final line = dark ? const Color(0xFF34343A) : const Color(0xFFE5E7EB);
    const purple = AppBrand.purpleLight;
    return Container(
      color: bg,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(color: purple, borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: dark && i == 0 ? AppBrand.orangeDark : line,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final w in const [1.0, 0.6, 1.0]) ...[
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: w,
              child: Container(
                height: 5,
                decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}
