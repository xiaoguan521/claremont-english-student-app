import 'package:flutter/material.dart';

import '../../data/portal_models.dart';

class PracticeSentenceSwitchStrip extends StatelessWidget {
  const PracticeSentenceSwitchStrip({
    super.key,
    required this.tasks,
    required this.focusedTaskId,
    required this.completedTaskIds,
    required this.onSelectTask,
  });

  final List<PortalTask> tasks;
  final String focusedTaskId;
  final Set<String> completedTaskIds;
  final ValueChanged<String> onSelectTask;

  @override
  Widget build(BuildContext context) {
    final completedCount = completedTaskIds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '句子切换',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF2FA77D),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEAFBF1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '已完成 $completedCount/${tasks.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF15803D),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _TaskCompletionProgressBar(
          completedCount: completedCount,
          totalCount: tasks.length,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final task = tasks[index];
              final isFocused = task.id == focusedTaskId;
              final isCompleted = completedTaskIds.contains(task.id);
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('句子 ${index + 1}'),
                    if (isCompleted) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: isFocused
                            ? const Color(0xFFEA580C)
                            : const Color(0xFF16A34A),
                      ),
                    ],
                  ],
                ),
                selected: isFocused,
                onSelected: (_) => onSelectTask(task.id),
                selectedColor: const Color(0xFFFFEDD5),
                labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isFocused
                      ? const Color(0xFFEA580C)
                      : const Color(0xFF475569),
                  fontWeight: FontWeight.w800,
                ),
                side: BorderSide(
                  color: isFocused
                      ? const Color(0xFFEA580C)
                      : const Color(0xFFDDE6E6),
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                showCheckmark: false,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TaskCompletionProgressBar extends StatelessWidget {
  const _TaskCompletionProgressBar({
    required this.completedCount,
    required this.totalCount,
  });

  final int completedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final progress = totalCount == 0
        ? 0.0
        : (completedCount / totalCount).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: progress),
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF2FA77D)),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          completedCount >= totalCount
              ? '这一组句子全部完成了'
              : '再完成 ${totalCount - completedCount} 句就能点亮这一组',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
