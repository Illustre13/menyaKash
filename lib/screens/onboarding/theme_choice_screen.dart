import 'package:flutter/material.dart';

/// Onboarding theme choice (sprint #3): Light / Dark / Use System, with
/// Skip defaulting to Light. Selection applies live (the preview *is*
/// the app re-theming underneath), so the user sees exactly what
/// they're choosing before continuing.
class ThemeChoiceScreen extends StatelessWidget {
  const ThemeChoiceScreen({
    super.key,
    required this.current,
    required this.onSelected,
    required this.onContinue,
  });

  final ThemeMode current;

  /// Called on each tap — the caller applies + persists immediately so
  /// the whole app re-themes live under this screen.
  final ValueChanged<ThemeMode> onSelected;

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
        actions: [
          TextButton(onPressed: onContinue, child: const Text('Skip')),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How should Menya Kash look?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'You can change this anytime in Settings. Skipping keeps '
                'the light theme.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _ThemeOptionCard(
                icon: Icons.light_mode_outlined,
                title: 'Light',
                subtitle: 'Bright surfaces, best in daylight',
                selected: current == ThemeMode.light,
                onTap: () => onSelected(ThemeMode.light),
              ),
              const SizedBox(height: 12),
              _ThemeOptionCard(
                icon: Icons.dark_mode_outlined,
                title: 'Dark',
                subtitle: 'Easier on the eyes at night',
                selected: current == ThemeMode.dark,
                onTap: () => onSelected(ThemeMode.dark),
              ),
              const SizedBox(height: 12),
              _ThemeOptionCard(
                icon: Icons.brightness_auto_outlined,
                title: 'Use System Theme',
                subtitle: 'Follow your phone\'s setting automatically',
                selected: current == ThemeMode.system,
                onTap: () => onSelected(ThemeMode.system),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onContinue,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.10) : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.4),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
