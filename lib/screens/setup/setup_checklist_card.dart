import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// One row on Home's "Finish setting up" checklist.
class SetupStep {
  const SetupStep({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onTap,
    this.recommended = false,
    this.optional = false,
  });

  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;
  final bool recommended;
  final bool optional;
}

/// Home's "Finish setting up" card (screen 6 of the onboarding
/// redesign): what onboarding deliberately skipped, as quick optional
/// steps. Open steps first; done steps stay listed, ticked and struck
/// through, so progress is visible. [onHide] closes it — Home then
/// keeps a dot on the Profile icon until every step is done.
class SetupChecklistCard extends StatelessWidget {
  const SetupChecklistCard({super.key, required this.steps, required this.onHide});

  final List<SetupStep> steps;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final done = steps.where((s) => s.done).length;
    final remaining = steps.length - done;
    final ordered = [...steps.where((s) => !s.done), ...steps.where((s) => s.done)];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: steps.isEmpty ? 0 : done / steps.length,
                          strokeWidth: 3.5,
                          backgroundColor: scheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      Text(
                        '$done/${steps.length}',
                        style: text.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Finish setting up',
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '$remaining quick step${remaining == 1 ? '' : 's'}, '
                        'about ${remaining <= 1 ? '1 minute' : '2 minutes'}',
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onHide,
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Hide checklist',
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final (i, step) in ordered.indexed) ...[
              if (i > 0)
                Divider(
                    height: 1,
                    indent: 36,
                    endIndent: 8,
                    color: scheme.outlineVariant.withValues(alpha: 0.3)),
              _StepRow(step: step),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final SetupStep step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final green = AppBrand.income(Theme.of(context).brightness);
    final titleStyle = text.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: step.done ? scheme.onSurfaceVariant : null,
      decoration: step.done ? TextDecoration.lineThrough : null,
    );

    return InkWell(
      onTap: step.done ? null : step.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            step.done
                ? Icon(Icons.check_circle, size: 24, color: green)
                : Icon(Icons.radio_button_unchecked, size: 24, color: scheme.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(step.title, style: titleStyle),
                      if (step.recommended && !step.done)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppBrand.orangeLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'RECOMMENDED',
                            style: text.labelSmall?.copyWith(
                              fontSize: 9,
                              color: AppBrand.inkPrimaryLight,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      if (step.optional && !step.done)
                        Text('· optional',
                            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  if (!step.done)
                    Text(
                      step.subtitle,
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            if (!step.done) Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
