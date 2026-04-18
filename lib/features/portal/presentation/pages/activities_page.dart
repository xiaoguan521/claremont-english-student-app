import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/portal_models.dart';
import '../providers/portal_providers.dart';
import '../widgets/tablet_shell.dart';

class ActivitiesPage extends ConsumerWidget {
  const ActivitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(portalActivitiesProvider);
    final summaryAsync = ref.watch(portalSummaryProvider);

    final subtitle = summaryAsync.maybeWhen(
      data: (summary) => '待点评 ${summary.reviewPending} 个 | 待督促 ${summary.studentsToUrge} 人',
      orElse: () => '正在同步远程作业数据',
    );

    Widget content;
    if (activitiesAsync.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (activitiesAsync.hasError) {
      content = const _ActivitiesStateMessage(
        title: '活动加载失败',
        message: '请稍后重试，或检查当前账号是否已绑定班级。',
      );
    } else {
      final activities = activitiesAsync.valueOrNull ?? const <PortalActivity>[];
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: _ActionRail(summaryAsync: summaryAsync),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: activities.isEmpty
                ? const _ActivitiesStateMessage(
                    title: '暂无打卡活动',
                    message: '当前账号下还没有已发布的活动。',
                  )
                : ListView.separated(
                    itemCount: activities.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 18),
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      return _ActivityRow(activity: activity);
                    },
                  ),
          ),
        ],
      );
    }

    return TabletShell(
      activeSection: TabletSection.teaching,
      title: '打卡活动',
      subtitle: subtitle,
      actions: [
        _TopToolButton(icon: Icons.tune_rounded, label: '筛选', onTap: () {}),
        const SizedBox(width: 12),
        _TopToolButton(icon: Icons.search_rounded, label: '搜索', onTap: () {}),
        const SizedBox(width: 12),
        _TopToolButton(
          icon: Icons.add_circle_outline_rounded,
          label: '布置',
          isPrimary: true,
          onTap: () {},
        ),
      ],
      child: content,
    );
  }
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({required this.summaryAsync});

  final AsyncValue<PortalSummary> summaryAsync;

  @override
  Widget build(BuildContext context) {
    final summary = summaryAsync.valueOrNull;
    final classLabel = summary == null ? '同步中' : '${summary.activeClasses}个班级';
    final urgeLabel = summary == null ? '正在统计' : '${summary.studentsToUrge}人待跟进';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          _RailAction(
            icon: Icons.fact_check_outlined,
            label: '一键检查',
            value: classLabel,
          ),
          const SizedBox(height: 14),
          _RailAction(
            icon: Icons.notifications_active_outlined,
            label: '一键督促',
            value: urgeLabel,
          ),
          const SizedBox(height: 14),
          const _PromoTile(
            title: 'AI点评',
            subtitle: '自动生成点评草稿',
            colors: [Color(0xFF1FB5FF), Color(0xFF8A49F8)],
          ),
          const SizedBox(height: 14),
          const _PromoTile(
            title: '活动模板库',
            subtitle: '复制常用打卡模板',
            colors: [Color(0xFF55C5FF), Color(0xFF2F67F6)],
          ),
          const SizedBox(height: 14),
          const _PromoTile(
            title: '我的模板库',
            subtitle: '机构专属任务模板',
            colors: [Color(0xFF3348FF), Color(0xFF00B7FF)],
          ),
        ],
      ),
    );
  }
}

class _ActivitiesStateMessage extends StatelessWidget {
  const _ActivitiesStateMessage({
    required this.title,
    required this.message,
  });

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
  final IconData icon;
  final String label;
  final String value;

  const _RailAction({
    required this.icon,
    required this.label,
    required this.value,
  });

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

class _PromoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Color> colors;

  const _PromoTile({
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final PortalActivity activity;

  const _ActivityRow({required this.activity});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/activities/${activity.id}'),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Container(
              width: 190,
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
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
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
                    activity.className,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _statusBg(activity.status),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _statusLabel(activity.status),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: _statusFg(activity.status),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        activity.dateLabel,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _CountMetric(
                    value: '${activity.reviewCount}个',
                    label: '待点评任务',
                  ),
                  _CountMetric(
                    value: '${activity.inspectCount}个',
                    label: '待检查任务',
                  ),
                  _CountMetric(value: '${activity.urgeCount}人', label: '待督促学员'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusBg(ActivityStatus status) {
    switch (status) {
      case ActivityStatus.active:
        return const Color(0xFFDBEAFE);
      case ActivityStatus.reviewPending:
        return const Color(0xFFFFEDD5);
      case ActivityStatus.completed:
        return const Color(0xFFDCFCE7);
    }
  }

  Color _statusFg(ActivityStatus status) {
    switch (status) {
      case ActivityStatus.active:
        return const Color(0xFF2563EB);
      case ActivityStatus.reviewPending:
        return const Color(0xFFF97316);
      case ActivityStatus.completed:
        return const Color(0xFF16A34A);
    }
  }

  String _statusLabel(ActivityStatus status) {
    switch (status) {
      case ActivityStatus.active:
        return '进行中';
      case ActivityStatus.reviewPending:
        return '待点评';
      case ActivityStatus.completed:
        return '已完成';
    }
  }
}

class _CountMetric extends StatelessWidget {
  final String value;
  final String label;

  const _CountMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: const Color(0xFFF97316),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF334155),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TopToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _TopToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: isPrimary
            ? const Color(0xFF2F67F6)
            : Colors.white.withValues(alpha: 0.9),
        foregroundColor: isPrimary ? Colors.white : const Color(0xFF1E293B),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
