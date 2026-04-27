import 'package:flutter/material.dart';

import '../../data/portal_models.dart';

class TaskReviewPanel extends StatelessWidget {
  const TaskReviewPanel({
    super.key,
    required this.review,
    required this.isEncouragementPlaying,
    required this.isEncouragementLoading,
    this.onPlayEncouragement,
  });

  final PortalTaskReview review;
  final bool isEncouragementPlaying;
  final bool isEncouragementLoading;
  final VoidCallback? onPlayEncouragement;

  @override
  Widget build(BuildContext context) {
    final scoreLabel = review.score.toStringAsFixed(0);
    final canPlayEncouragement =
        onPlayEncouragement != null && review.encouragement.trim().isNotEmpty;
    final reviewBadgeLabel = isEncouragementLoading
        ? '生成中'
        : isEncouragementPlaying
        ? '停止'
        : 'AI';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FBF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9F1E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ReviewBadge(
                icon: isEncouragementLoading
                    ? Icons.hourglass_top_rounded
                    : isEncouragementPlaying
                    ? Icons.stop_circle_rounded
                    : Icons.auto_awesome_rounded,
                label: reviewBadgeLabel,
                color: const Color(0xFF0F8B6D),
                background: const Color(0xFFDFF8EC),
                onTap: canPlayEncouragement ? onPlayEncouragement : null,
              ),
              if (review.isTeacherReviewedReference)
                const _ReviewBadge(
                  icon: Icons.person_rounded,
                  label: '老师已看',
                  color: Color(0xFF0369A1),
                  background: Color(0xFFE0F2FE),
                ),
              _ReviewBadge(
                icon: Icons.star_rounded,
                label: '$scoreLabel 分',
                color: const Color(0xFFF97316),
                background: const Color(0xFFFFEBD9),
              ),
              if (review.pronunciationScore != null)
                _ReviewMetricChip(
                  label: '发音 ${review.pronunciationScore!.toStringAsFixed(0)}',
                ),
              if (review.fluencyScore != null)
                _ReviewMetricChip(
                  label: '流利 ${review.fluencyScore!.toStringAsFixed(0)}',
                ),
              if (review.completenessScore != null)
                _ReviewMetricChip(
                  label: '完整 ${review.completenessScore!.toStringAsFixed(0)}',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            review.summaryFeedback,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w800,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isPhone = constraints.maxWidth < 720;
              final strengthsCard = _ReviewListCard(
                title: '读得好',
                icon: Icons.thumb_up_alt_rounded,
                background: const Color(0xFFEAFBF1),
                foreground: const Color(0xFF0F8B6D),
                items: review.strengths.isEmpty
                    ? const ['愿意开口读。']
                    : review.strengths,
              );
              final improvementCard = _ReviewListCard(
                title: '小建议',
                icon: Icons.lightbulb_rounded,
                background: const Color(0xFFFFF4E8),
                foreground: const Color(0xFFB45309),
                items: review.improvementPoints.isEmpty
                    ? const ['下次读的时候把尾音带出来，会更自然。']
                    : review.improvementPoints,
              );

              if (isPhone) {
                return Column(
                  children: [
                    strengthsCard,
                    const SizedBox(height: 12),
                    improvementCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: strengthsCard),
                  const SizedBox(width: 12),
                  Expanded(child: improvementCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: onTap == null
            ? null
            : Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return badge;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: badge,
      ),
    );
  }
}

class _ReviewMetricChip extends StatelessWidget {
  const _ReviewMetricChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE7E3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF475569),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReviewListCard extends StatelessWidget {
  const _ReviewListCard({
    required this.title,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color background;
  final Color foreground;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6, color: foreground),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
