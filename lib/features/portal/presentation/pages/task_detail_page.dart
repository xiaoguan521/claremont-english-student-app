import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/portal_models.dart';
import '../../../school/presentation/providers/school_context_provider.dart';
import '../providers/portal_providers.dart';
import '../widgets/tablet_shell.dart';

class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage({required this.activityId, super.key});

  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(portalActivityByIdProvider(activityId));
    final schoolContext =
        ref.watch(schoolContextProvider).valueOrNull ??
        SchoolContext.fallback();

    if (activityAsync.isLoading) {
      return TabletShell(
        activeSection: TabletSection.teaching,
        brandName: schoolContext.displayName,
        brandSubtitle: '学校学习入口',
        title: '任务详情',
        subtitle: '正在加载今天的学习任务',
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (activityAsync.hasError) {
      return TabletShell(
        activeSection: TabletSection.teaching,
        brandName: schoolContext.displayName,
        brandSubtitle: '学校学习入口',
        title: '任务详情',
        subtitle: '加载失败',
        child: Center(
          child: Text(
            '任务加载失败，请稍后重试。',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    final activity = activityAsync.valueOrNull;
    if (activity == null) {
      return TabletShell(
        activeSection: TabletSection.teaching,
        brandName: schoolContext.displayName,
        brandSubtitle: '学校学习入口',
        title: '任务详情',
        subtitle: '内容不存在',
        child: Center(
          child: Text(
            '没有找到这份作业。',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    final completedTasks = activity.tasks
        .where((task) => task.reviewStatus == TaskReviewStatus.checked)
        .length;

    return TabletShell(
      activeSection: TabletSection.teaching,
      brandName: schoolContext.displayName,
      brandSubtitle: '学校学习入口',
      title: activity.title,
      subtitle: '${activity.className} · ${activity.dateLabel}',
      actions: [
        _HeaderAction(
          icon: Icons.arrow_back_rounded,
          label: '返回作业',
          onTap: () => context.go('/activities'),
        ),
      ],
      child: Column(
        children: [
          _OverviewCard(activity: activity, completedTasks: completedTasks),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: activity.tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final task = activity.tasks[index];
                return _TaskCard(index: index + 1, task: task);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.activity, required this.completedTasks});

  final PortalActivity activity;
  final int completedTasks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF34D399), Color(0xFF2F67F6)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              size: 56,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.className,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '今天先按顺序完成下面 ${activity.tasks.length} 个学习任务。',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _OverviewChip(
                      icon: Icons.check_circle_rounded,
                      label: '已完成 $completedTasks 项',
                    ),
                    _OverviewChip(
                      icon: Icons.schedule_rounded,
                      label: '完成度 ${(activity.completionRate * 100).round()}%',
                    ),
                    _OverviewChip(
                      icon: Icons.mark_chat_read_rounded,
                      label: '老师反馈 ${activity.reviewCount} 条',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.play_circle_fill_rounded),
            label: const Text('继续学习'),
          ),
        ],
      ),
    );
  }
}

class _OverviewChip extends StatelessWidget {
  const _OverviewChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2F67F6)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.index, required this.task});

  final int index;
  final PortalTask task;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel(task.reviewStatus);
    final statusColor = _statusColor(task.reviewStatus);
    final actionLabel = _actionLabel(task.reviewStatus);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF2F67F6),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Container(
            width: 92,
            height: 74,
            decoration: BoxDecoration(
              gradient: _previewGradient(task.kind),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(_previewIcon(task.kind), color: Colors.white, size: 36),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '学习方式：${task.previewAsset}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          FilledButton.tonalIcon(
            onPressed: () {},
            icon: Icon(_actionIcon(task.reviewStatus)),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  String _statusLabel(TaskReviewStatus status) {
    switch (status) {
      case TaskReviewStatus.checked:
        return '已完成，可以查看反馈';
      case TaskReviewStatus.pendingReview:
        return '已提交，等待老师点评';
      case TaskReviewStatus.inProgress:
        return '进行中，继续完成';
    }
  }

  Color _statusColor(TaskReviewStatus status) {
    switch (status) {
      case TaskReviewStatus.checked:
        return const Color(0xFF16A34A);
      case TaskReviewStatus.pendingReview:
        return const Color(0xFFF97316);
      case TaskReviewStatus.inProgress:
        return const Color(0xFF2563EB);
    }
  }

  String _actionLabel(TaskReviewStatus status) {
    switch (status) {
      case TaskReviewStatus.checked:
        return '查看点评';
      case TaskReviewStatus.pendingReview:
        return '等待点评';
      case TaskReviewStatus.inProgress:
        return '继续学习';
    }
  }

  IconData _actionIcon(TaskReviewStatus status) {
    switch (status) {
      case TaskReviewStatus.checked:
        return Icons.rate_review_outlined;
      case TaskReviewStatus.pendingReview:
        return Icons.schedule_rounded;
      case TaskReviewStatus.inProgress:
        return Icons.play_circle_fill_rounded;
    }
  }

  LinearGradient _previewGradient(TaskKind kind) {
    switch (kind) {
      case TaskKind.dubbing:
        return const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF2563EB)],
        );
      case TaskKind.recording:
        return const LinearGradient(
          colors: [Color(0xFFEC4899), Color(0xFFF97316)],
        );
      case TaskKind.phonics:
        return const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
        );
    }
  }

  IconData _previewIcon(TaskKind kind) {
    switch (kind) {
      case TaskKind.dubbing:
        return Icons.mic_external_on_rounded;
      case TaskKind.recording:
        return Icons.graphic_eq_rounded;
      case TaskKind.phonics:
        return Icons.spellcheck_rounded;
    }
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
