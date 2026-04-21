import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/portal_models.dart';
import '../../../school/presentation/providers/school_context_provider.dart';
import '../providers/portal_providers.dart';
import '../widgets/tablet_shell.dart';

class ActivitiesPage extends ConsumerWidget {
  const ActivitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(portalActivitiesProvider);
    final summaryAsync = ref.watch(portalSummaryProvider);
    final schoolContext =
        ref.watch(schoolContextProvider).valueOrNull ??
        SchoolContext.fallback();

    final subtitle = summaryAsync.maybeWhen(
      data: (summary) =>
          '共 ${summary.totalActivities} 份作业 | 已完成 ${summary.completedActivities} 份',
      orElse: () => '正在同步老师布置的作业',
    );

    Widget content;
    if (activitiesAsync.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (activitiesAsync.hasError) {
      content = const _ActivitiesStateMessage(
        title: '作业还没有加载出来',
        message: '请稍后重试，或者联系老师确认班级是否已绑定。',
      );
    } else {
      final activities =
          activitiesAsync.valueOrNull ?? const <PortalActivity>[];
      content = LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 760;
          final list = activities.isEmpty
              ? const _ActivitiesStateMessage(
                  title: '还没有新的作业',
                  message: '老师发布新的英语任务后，这里会马上出现。',
                )
              : ListView.separated(
                  shrinkWrap: isPhone,
                  physics: isPhone
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(),
                  itemCount: activities.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 18),
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    return _ActivityRow(activity: activity);
                  },
                );

          if (isPhone) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _ActionRail(summaryAsync: summaryAsync, isCompact: true),
                  const SizedBox(height: 16),
                  list,
                ],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 248,
                child: _ActionRail(summaryAsync: summaryAsync),
              ),
              const SizedBox(width: 20),
              Expanded(child: list),
            ],
          );
        },
      );
    }

    return TabletShell(
      activeSection: TabletSection.teaching,
      brandName: schoolContext.displayName,
      brandSubtitle: '学校学习入口',
      title: '我的作业',
      subtitle: subtitle,
      actions: [
        _TopToolButton(
          icon: Icons.home_rounded,
          label: '回首页',
          onTap: () => context.go('/home'),
        ),
        const SizedBox(width: 12),
        _TopToolButton(
          icon: Icons.refresh_rounded,
          label: '刷新',
          isPrimary: true,
          onTap: () => ref.invalidate(portalActivitiesProvider),
        ),
      ],
      child: content,
    );
  }
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({required this.summaryAsync, this.isCompact = false});

  final AsyncValue<PortalSummary> summaryAsync;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final summary = summaryAsync.valueOrNull;
    final taskLabel = summary == null
        ? '同步中'
        : '${summary.totalActivities} 份作业';
    final pendingLabel = summary == null
        ? '正在统计'
        : '${summary.pendingTasks} 项待完成';
    final completedLabel = summary == null
        ? '加载中'
        : '${summary.completedActivities} 份已完成';

    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          _RailAction(
            icon: Icons.fact_check_outlined,
            label: '今日作业',
            value: taskLabel,
          ),
          SizedBox(height: isCompact ? 10 : 14),
          _RailAction(
            icon: Icons.pending_actions_outlined,
            label: '待完成',
            value: pendingLabel,
          ),
          SizedBox(height: isCompact ? 10 : 14),
          _RailAction(
            icon: Icons.workspace_premium_outlined,
            label: '已完成',
            value: completedLabel,
          ),
          SizedBox(height: isCompact ? 10 : 14),
          const _StudyHintTile(
            title: '先完成今天的作业',
            subtitle: '每份作业点进去后，先打开教材，再听示范、录音并提交。',
            accent: Color(0xFF4FAE7F),
          ),
          SizedBox(height: isCompact ? 10 : 14),
          const _StudyHintTile(
            title: '完成后回来查看反馈',
            subtitle: '老师和系统处理完成后，这里会显示新的点评和分数。',
            accent: Color(0xFFFF9B55),
          ),
        ],
      ),
    );
  }
}

class _ActivitiesStateMessage extends StatelessWidget {
  const _ActivitiesStateMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF656CFF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF25324B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
}

class _StudyHintTile extends StatelessWidget {
  const _StudyHintTile({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final PortalActivity activity;

  @override
  Widget build(BuildContext context) {
    final progress = '${(activity.completionRate * 100).round()}%';
    final nextStep = _nextStepLabel(activity.status);

    return InkWell(
      onTap: () => context.go('/activities/${activity.id}'),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(30),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isPhone = constraints.maxWidth < 680;
            final cover = Container(
              width: isPhone ? double.infinity : 190,
              height: 118,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF3C9), Color(0xFFFFC765)],
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 64,
                color: Color(0xFFB56A25),
              ),
            );

            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${activity.className} · ${activity.dateLabel}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoChip(label: '任务 ${activity.tasks.length} 项'),
                    _InfoChip(label: '完成 $progress'),
                    _InfoChip(label: '老师反馈 ${activity.reviewCount} 条'),
                  ],
                ),
              ],
            );

            final actions = isPhone
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusBadge(status: activity.status),
                      const SizedBox(height: 12),
                      Text(
                        activity.status == ActivityStatus.active
                            ? '点进去后会看到教材、示范音频和提交入口。'
                            : '点进去可以继续查看反馈或等待状态。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              context.go('/activities/${activity.id}'),
                          icon: const Icon(Icons.play_circle_fill_rounded),
                          label: Text(nextStep),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusBadge(status: activity.status),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () =>
                            context.go('/activities/${activity.id}'),
                        icon: const Icon(Icons.play_circle_fill_rounded),
                        label: Text(nextStep),
                      ),
                    ],
                  );

            if (isPhone) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cover,
                  const SizedBox(height: 18),
                  content,
                  const SizedBox(height: 18),
                  actions,
                ],
              );
            }

            return Row(
              children: [
                cover,
                const SizedBox(width: 22),
                Expanded(child: content),
                const SizedBox(width: 22),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }

  String _nextStepLabel(ActivityStatus status) {
    switch (status) {
      case ActivityStatus.completed:
        return '查看反馈';
      case ActivityStatus.reviewPending:
        return '等待点评';
      case ActivityStatus.active:
        return '继续学习';
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ActivityStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ActivityStatus.completed => ('已完成', const Color(0xFF16A34A)),
      ActivityStatus.reviewPending => ('等待老师点评', const Color(0xFFF97316)),
      ActivityStatus.active => ('学习中', const Color(0xFF2563EB)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TopToolButton extends StatelessWidget {
  const _TopToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isPrimary
        ? const Color(0xFFFF8F4D)
        : Colors.white.withValues(alpha: 0.18);
    final foregroundColor = Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(icon, color: foregroundColor, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
