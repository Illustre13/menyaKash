import 'package:flutter/material.dart';

import '../../analytics/analytics_service.dart';
import '../../theme/app_theme.dart';

/// "X% categorized / Y need review" (spec Phase 8) — replaces the old
/// plain "All Uncategorized" framing with an actionable progress meter.
/// Tapping it navigates to [onReview] when there's anything left to
/// review, turning the metric into an entry point rather than just a
/// stat.
class CategorizationProgressBar extends StatelessWidget {
  const CategorizationProgressBar({
    super.key,
    required this.ratio,
    this.onReview,
  });

  final CategorizationRatio ratio;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final needsReview = ratio.needsReviewCount > 0;
    final scheme = Theme.of(context).colorScheme;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio.ratio,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerLow,
            color: AppBrand.statusGood,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(ratio.ratio * 100).round()}% categorized'
          '${needsReview ? ' — ${ratio.needsReviewCount} need review' : ''}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );

    if (!needsReview || onReview == null) return content;
    return InkWell(onTap: onReview, borderRadius: BorderRadius.circular(8), child: content);
  }
}
