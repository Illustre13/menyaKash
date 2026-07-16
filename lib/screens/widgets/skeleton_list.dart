import 'package:flutter/material.dart';

/// Pulsing skeleton placeholder rows shown while a list loads (sprint
/// #13) — no blank screens, no spinner-only pages. Implemented as a
/// gentle opacity pulse on shaped placeholders rather than a
/// third-party shimmer package: zero new dependencies, and the effect
/// reads the same at a glance.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.rows = 8});

  final int rows;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
    upperBound: 1.0,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _pulse,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.rows,
        itemBuilder: (_, __) => const _SkeletonRow(),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final tone = Theme.of(context).colorScheme.surfaceContainerHigh;
    Widget block(double width, double height, {double radius = 6}) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: tone,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          block(42, 42, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(double.infinity, 14),
                const SizedBox(height: 8),
                block(140, 10),
              ],
            ),
          ),
          const SizedBox(width: 12),
          block(64, 14),
        ],
      ),
    );
  }
}
