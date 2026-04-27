import 'package:flutter/material.dart';

import '../../../../core/ui/app_ui_tokens.dart';

class PracticeStageHeader extends StatelessWidget {
  const PracticeStageHeader({
    super.key,
    required this.title,
    required this.taskIndex,
    required this.totalTasks,
    required this.completedCount,
    required this.pageLabel,
    required this.materialTitle,
    required this.comboCount,
    required this.earnedStars,
    this.compact = false,
    this.visualScale = 1,
  });

  final String title;
  final int taskIndex;
  final int totalTasks;
  final int completedCount;
  final String pageLabel;
  final String? materialTitle;
  final int comboCount;
  final int earnedStars;
  final bool compact;
  final double visualScale;

  @override
  Widget build(BuildContext context) {
    final visibleStars = totalTasks.clamp(1, compact ? 6 : 10).toInt();
    final completedStars = completedCount.clamp(0, visibleStars).toInt();
    final material = (materialTitle ?? '').trim();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal:
            (compact ? AppUiTokens.spaceSm : AppUiTokens.spaceMd) * visualScale,
        vertical:
            (compact ? AppUiTokens.spaceXs : AppUiTokens.spaceSm) * visualScale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppUiTokens.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: (compact ? 34 : 40) * visualScale,
                  height: (compact ? 34 : 40) * visualScale,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFD95F),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: Color(0xFF8A4B00),
                    size: 20,
                  ),
                ),
                SizedBox(width: AppUiTokens.spaceXs * visualScale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF16213A),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (!compact && material.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          material,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppUiTokens.spaceSm * visualScale),
          Expanded(
            flex: compact ? 2 : 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < visibleStars; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          left: AppUiTokens.space2xs * 0.75 * visualScale,
                        ),
                        child: Icon(
                          index < completedStars
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: (compact ? 16 : 19) * visualScale,
                          color: index < completedStars
                              ? const Color(0xFFFFB020)
                              : const Color(0xFFB8C7D9),
                        ),
                      ),
                    if (totalTasks > visibleStars) ...[
                      SizedBox(width: AppUiTokens.space2xs * visualScale),
                      Text(
                        '+',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppUiTokens.space2xs),
                Text(
                  '第 $taskIndex/$totalTasks 句 · $pageLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (!compact && (comboCount > 0 || earnedStars > 0)) ...[
            SizedBox(width: AppUiTokens.spaceSm * visualScale),
            PracticeRewardCapsule(
              comboCount: comboCount,
              earnedStars: earnedStars,
            ),
          ],
        ],
      ),
    );
  }
}

class PracticeRewardCapsule extends StatelessWidget {
  const PracticeRewardCapsule({
    super.key,
    required this.comboCount,
    required this.earnedStars,
  });

  final int comboCount;
  final int earnedStars;

  @override
  Widget build(BuildContext context) {
    final label = comboCount > 0 ? '$comboCount 连对' : '+$earnedStars 星币';
    final icon = comboCount > 0
        ? Icons.local_fire_department_rounded
        : Icons.star_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppUiTokens.spaceSm,
        vertical: AppUiTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF2A6), Color(0xFFFFC75A)],
        ),
        borderRadius: BorderRadius.circular(AppUiTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF8A4B00), size: 18),
          const SizedBox(width: AppUiTokens.space2xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6D3E00),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
