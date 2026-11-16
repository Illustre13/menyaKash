import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../theme/app_theme.dart';

/// Menya Kash design-system primitives (UI sprint). Small, composable,
/// and used everywhere so the app reads as one product: AppCard,
/// AmountText, SectionHeader, EmptyState, Skeleton, ProgressRing,
/// QuickAction, and the category→icon mapping.

/// The one shared currency formatter — every amount in the app goes
/// through this so "RWF 1,250,000" renders identically everywhere.
final rwf = NumberFormat.currency(symbol: 'RWF ', decimalDigits: 0);

/// Semantic direction of money for coloring/iconography.
enum MoneyKind { income, expense, transfer, neutral }

MoneyKind moneyKindOf(TransactionType type, {bool isTransfer = false}) {
  if (isTransfer) return MoneyKind.transfer;
  return switch (type) {
    TransactionType.received || TransactionType.deposit => MoneyKind.income,
    TransactionType.bankTransfer => MoneyKind.transfer,
    TransactionType.unknown || TransactionType.reversed => MoneyKind.neutral,
    _ => MoneyKind.expense,
  };
}

extension MoneyKindX on MoneyKind {
  Color color(BuildContext context) {
    final b = Theme.of(context).brightness;
    return switch (this) {
      MoneyKind.income => AppBrand.income(b),
      MoneyKind.expense => AppBrand.expense(b),
      MoneyKind.transfer => AppBrand.transfer(b),
      MoneyKind.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  IconData get icon => switch (this) {
        MoneyKind.income => Icons.arrow_downward_rounded,
        MoneyKind.expense => Icons.arrow_upward_rounded,
        MoneyKind.transfer => Icons.swap_horiz_rounded,
        MoneyKind.neutral => Icons.remove_rounded,
      };

  String get sign => switch (this) {
        MoneyKind.income => '+',
        MoneyKind.expense => '−',
        _ => '',
      };
}

/// A money amount, colored and signed by [kind], always tabular so
/// columns of amounts align digit-for-digit.
class AmountText extends StatelessWidget {
  const AmountText(this.amount, {super.key, required this.kind, this.style});

  final double amount;
  final MoneyKind kind;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.titleSmall;
    return Text(
      '${kind.sign}${rwf.format(amount)}',
      style: base?.copyWith(
        color: kind.color(context),
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// White (dark: charcoal) rounded card with a soft shadow and a tap
/// scale micro-interaction when [onTap] is set.
class AppCard extends StatefulWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Container(
        padding: widget.padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppBrand.cardDark : AppBrand.cardLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: widget.child,
      ),
    );

    if (widget.onTap == null) return card;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: card,
    );
  }
}

/// Section title row with an optional trailing action ("See all").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Never a blank page: icon-in-circle, friendly title/message, and an
/// optional CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onCta,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onCta, child: Text(ctaLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmering placeholder block. Compose into rows/lists while real
/// data loads — never a blank page or a bare spinner.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final glow = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(0 + 2 * t, 0),
              colors: [base, glow, base],
            ),
          ),
        );
      },
    );
  }
}

/// A skeleton stand-in for a list of transaction tiles.
class TransactionListSkeleton extends StatelessWidget {
  const TransactionListSkeleton({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Skeleton(width: 40, height: 40, radius: 12),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 140),
                      SizedBox(height: 6),
                      Skeleton(width: 90, height: 10),
                    ],
                  ),
                ),
                Skeleton(width: 70),
              ],
            ),
          ),
      ],
    );
  }
}

/// Animated circular progress ring — budgets, categorization progress.
/// Sweeps from zero to [value] on first build; color communicates
/// state and is the caller's choice (status colors for budget health).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    this.size = 64,
    this.strokeWidth = 7,
    this.child,
  });

  /// 0..1 (values >1 are drawn full).
  final double value;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: animated,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            ),
            if (child != null) Center(child: child),
          ],
        ),
      ),
    );
  }
}

/// Icon-in-tinted-circle + label, for the Home quick-actions row.
class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: scheme.primary, size: 22),
              ),
              const SizedBox(height: 6),
              // maxLines/overflow (not present before): a row can now
              // hold several of these tiles at once (Pay, Electricity,
              // Water, Urubuto, RRA), so a longer label must ellipsize
              // rather than overflow the tile's narrow width.
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Category icon/color lookup moved to
// lib/categorization/category_taxonomy.dart (categoryStyle,
// CategoryAvatar) as part of the spec #9 default-taxonomy redesign —
// that module also owns the curated default categories, so the
// icon/color mapping now lives next to the data it describes instead
// of in this generic widget file.
