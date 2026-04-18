import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_models.dart';
import '../providers/portal_providers.dart';
import '../widgets/tablet_shell.dart';

class TaskDetailPage extends ConsumerWidget {
  final String activityId;

  const TaskDetailPage({required this.activityId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(portalActivityByIdProvider(activityId));

    if (activityAsync.isLoading) {
      return const TabletShell(
        activeSection: TabletSection.teaching,
        title: '任务详情',
        subtitle: '正在加载',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (activityAsync.hasError) {
      return TabletShell(
        activeSection: TabletSection.teaching,
        title: '任务详情',
        subtitle: '加载失败',
        child: Center(
          child: Text(
            '任务数据加载失败，请稍后重试。',
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
        title: '任务详情',
        subtitle: '活动不存在',
        child: Center(
          child: Text(
            '未找到对应活动',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    return TabletShell(
      activeSection: TabletSection.teaching,
      title: '${activity.className} · 任务详情',
      subtitle: '今日完成度 ${(activity.completionRate * 100).round()}%',
      child: Column(
        children: [
          _TimelineHeader(activity: activity),
          const SizedBox(height: 18),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                    child: Row(
                      children: [
                        Expanded(flex: 8, child: _HeaderCell(label: '详情')),
                        Expanded(flex: 2, child: _HeaderCell(label: '状态')),
                        Expanded(flex: 2, child: _HeaderCell(label: '操作')),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  Expanded(
                    child: ListView.separated(
                      itemCount: activity.tasks.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final task = activity.tasks[index];
                        return _TaskRow(task: task);
                      },
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

class _TimelineHeader extends StatelessWidget {
  final PortalActivity activity;

  const _TimelineHeader({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const _DateTab(label: '26年04月', selected: false),
          const SizedBox(width: 12),
          const _DateTab(label: '周一 13', selected: false),
          const SizedBox(width: 12),
          const _DateTab(label: '周二 14', selected: false),
          const SizedBox(width: 12),
          const _DateTab(label: '周三 15', selected: false),
          const SizedBox(width: 12),
          const _DateTab(label: '周四 16', selected: false),
          const SizedBox(width: 12),
          const _DateTab(label: '周五 17', selected: false),
          const SizedBox(width: 12),
          const _DateTab(label: '今日', selected: true),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activity.dateLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTab extends StatelessWidget {
  final String label;
  final bool selected;

  const _DateTab({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2F67F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: selected ? Colors.white : const Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;

  const _HeaderCell({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: const Color(0xFF1E293B),
        fontWeight: FontWeight.w900,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _TaskRow extends StatelessWidget {
  final PortalTask task;

  const _TaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final tagColor = _tagColor(task.kind);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 8,
            child: Row(
              children: [
                Container(
                  width: 92,
                  height: 74,
                  decoration: BoxDecoration(
                    gradient: _previewGradient(task.kind),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    _previewIcon(task.kind),
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: const Color(0xFF1E293B),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: tagColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        task.previewAsset,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF374151),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _statusLabel(task.reviewStatus),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _statusColor(task.reviewStatus),
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                const Icon(
                  Icons.rate_review_outlined,
                  color: Color(0xFF334155),
                ),
                const SizedBox(height: 4),
                Text(
                  task.reviewStatus == TaskReviewStatus.pendingReview
                      ? '点评'
                      : '查看',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _tagColor(TaskKind kind) {
    switch (kind) {
      case TaskKind.dubbing:
        return const Color(0xFFDBEAFE);
      case TaskKind.recording:
        return const Color(0xFFF5D0FE);
      case TaskKind.phonics:
        return const Color(0xFFDCFCE7);
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
          colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
        );
      case TaskKind.phonics:
        return const LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF10B981)],
        );
    }
  }

  IconData _previewIcon(TaskKind kind) {
    switch (kind) {
      case TaskKind.dubbing:
        return Icons.ondemand_video_rounded;
      case TaskKind.recording:
        return Icons.mic_rounded;
      case TaskKind.phonics:
        return Icons.auto_stories_rounded;
    }
  }

  String _statusLabel(TaskReviewStatus status) {
    switch (status) {
      case TaskReviewStatus.checked:
        return '已检查';
      case TaskReviewStatus.pendingReview:
        return '待点评';
      case TaskReviewStatus.inProgress:
        return '进行中';
    }
  }

  Color _statusColor(TaskReviewStatus status) {
    switch (status) {
      case TaskReviewStatus.checked:
        return const Color(0xFF22C55E);
      case TaskReviewStatus.pendingReview:
        return const Color(0xFFF97316);
      case TaskReviewStatus.inProgress:
        return const Color(0xFF2563EB);
    }
  }
}
