import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/portal_models.dart';
import '../../../school/presentation/providers/school_context_provider.dart';
import '../providers/portal_providers.dart';
import '../providers/practice_session_providers.dart';
import '../widgets/tablet_shell.dart';

class ActivitiesPage extends ConsumerWidget {
  const ActivitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allActivitiesAsync = ref.watch(portalActivitiesProvider);
    final activitiesAsync = ref.watch(activitiesForSelectedDateProvider);
    final summaryAsync = ref.watch(selectedDatePortalSummaryProvider);
    final selectedDateAsync = ref.watch(visibleActivityDateProvider);
    final calendarDatesAsync = ref.watch(activityCalendarDatesProvider);
    final today = ref.watch(todayActivityDateProvider);
    final schoolContext =
        ref.watch(schoolContextProvider).valueOrNull ??
        SchoolContext.fallback();

    final subtitle = summaryAsync.maybeWhen(
      data: (summary) {
        final selectedDate = selectedDateAsync.valueOrNull;
        if (selectedDate == null) {
          return '老师已经把今天的英语任务准备好了';
        }
        final prefix = _isSameDay(selectedDate, today)
            ? '今天'
            : _formatDateLabel(selectedDate);
        return '$prefix有 ${summary.totalActivities} 份作业 | 已完成 ${summary.completedActivities} 份';
      },
      orElse: () => '老师已经把今天的英语任务准备好了',
    );

    Widget content;
    if (activitiesAsync.isLoading ||
        summaryAsync.isLoading ||
        selectedDateAsync.isLoading ||
        calendarDatesAsync.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (activitiesAsync.hasError ||
        summaryAsync.hasError ||
        selectedDateAsync.hasError ||
        calendarDatesAsync.hasError) {
      content = const _ActivitiesStateMessage(
        title: '作业还没有加载出来',
        message: '请稍后重试，或者联系老师确认班级是否已绑定。',
      );
    } else {
      final activities =
          activitiesAsync.valueOrNull ?? const <PortalActivity>[];
      final allActivities =
          allActivitiesAsync.valueOrNull ?? const <PortalActivity>[];
      final summary =
          summaryAsync.valueOrNull ??
          const PortalSummary(
            activeClasses: 0,
            totalActivities: 0,
            completedActivities: 0,
            inProgressActivities: 0,
            pendingTasks: 0,
          );
      final selectedDate = selectedDateAsync.valueOrNull ?? today;
      final calendarDates = calendarDatesAsync.valueOrNull ?? <DateTime>[today];
      final activityCountByDate = <DateTime, int>{};
      for (final activity in allActivities) {
        final dueDate = activity.dueDate;
        if (dueDate == null) {
          continue;
        }
        final normalized = DateTime(dueDate.year, dueDate.month, dueDate.day);
        activityCountByDate.update(
          normalized,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }

      content = LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 760;
          final isLandscapePhone =
              constraints.maxWidth > constraints.maxHeight &&
              constraints.maxWidth < 1100;
          final visualScale = isLandscapePhone
              ? _activityLandscapeVisualScale(
                  constraints.maxWidth,
                  constraints.maxHeight,
                )
              : 1.0;
          final textScale = isLandscapePhone
              ? (MediaQuery.textScalerOf(context).scale(1) * visualScale).clamp(
                  0.82,
                  1.0,
                )
              : MediaQuery.textScalerOf(context).scale(1);
          final isShortViewport = constraints.maxHeight < 760;
          final list = activities.isEmpty
              ? _ActivitiesStateMessage(
                  title: _isSameDay(selectedDate, today)
                      ? '今天还没有新的作业'
                      : '${_formatDateLabel(selectedDate)}没有布置作业',
                  message: _isSameDay(selectedDate, today)
                      ? '你可以切到前几天看看有没有漏掉的作业要补做。'
                      : '可以切换到别的日期，看看前后几天的作业安排。',
                )
              : ListView.separated(
                  shrinkWrap: isPhone,
                  primary: !isPhone,
                  physics: isPhone
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(),
                  itemCount: activities.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 18),
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    return _ActivityRow(
                      activity: activity,
                      visualScale: visualScale,
                    );
                  },
                );

          if (isLandscapePhone) {
            final designWidth = constraints.maxWidth < 980
                ? 980.0
                : constraints.maxWidth;
            final designHeight = constraints.maxHeight.clamp(320.0, 460.0);
            final railWidth = (designWidth * 0.22).clamp(176.0, 236.0);
            final gap = designWidth < 900 ? 10.0 : 14.0;
            final landscapeList = activities.isEmpty
                ? list
                : Scrollbar(
                    thumbVisibility: true,
                    radius: const Radius.circular(999),
                    child: list,
                  );

            final content = MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: SizedBox(
                width: designWidth,
                height: designHeight,
                child: Column(
                  children: [
                    _HomeworkCalendarStrip(
                      dates: calendarDates,
                      selectedDate: selectedDate,
                      today: today,
                      activityCountByDate: activityCountByDate,
                      visualScale: visualScale,
                      onSelectDate: (date) =>
                          ref
                                  .read(selectedActivityDateProvider.notifier)
                                  .state =
                              date,
                    ),
                    SizedBox(height: 14 * visualScale),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: railWidth * visualScale,
                            child: SingleChildScrollView(
                              child: _ActionRail(
                                summary: summary,
                                selectedDate: selectedDate,
                                today: today,
                                isCompact: true,
                                visualScale: visualScale,
                                onResetToToday: !_isSameDay(selectedDate, today)
                                    ? () =>
                                          ref
                                                  .read(
                                                    selectedActivityDateProvider
                                                        .notifier,
                                                  )
                                                  .state =
                                              today
                                    : null,
                              ),
                            ),
                          ),
                          SizedBox(width: gap * visualScale),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(
                                (designWidth < 900 ? 14 : 18) * visualScale,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _isSameDay(selectedDate, today)
                                                  ? '今天'
                                                  : _formatDateLabel(
                                                      selectedDate,
                                                    ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    color: const Color(
                                                      0xFF1E293B,
                                                    ),
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12 * visualScale,
                                          vertical: 8 * visualScale,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF2E4),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: Text(
                                          '${activities.length} 份作业',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                color: const Color(0xFFFF8F4D),
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16 * visualScale),
                                  Expanded(child: landscapeList),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );

            return SizedBox.expand(
              child: Align(
                alignment: Alignment.topLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: content,
                ),
              ),
            );
          }

          if (isPhone) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _HomeworkCalendarStrip(
                    dates: calendarDates,
                    selectedDate: selectedDate,
                    today: today,
                    activityCountByDate: activityCountByDate,
                    onSelectDate: (date) =>
                        ref.read(selectedActivityDateProvider.notifier).state =
                            date,
                  ),
                  const SizedBox(height: 16),
                  _ActionRail(
                    summary: summary,
                    selectedDate: selectedDate,
                    today: today,
                    isCompact: true,
                    onResetToToday: !_isSameDay(selectedDate, today)
                        ? () =>
                              ref
                                      .read(
                                        selectedActivityDateProvider.notifier,
                                      )
                                      .state =
                                  today
                        : null,
                  ),
                  const SizedBox(height: 16),
                  list,
                ],
              ),
            );
          }

          return Column(
            children: [
              _HomeworkCalendarStrip(
                dates: calendarDates,
                selectedDate: selectedDate,
                today: today,
                activityCountByDate: activityCountByDate,
                onSelectDate: (date) =>
                    ref.read(selectedActivityDateProvider.notifier).state =
                        date,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 248,
                      child: SingleChildScrollView(
                        child: _ActionRail(
                          summary: summary,
                          selectedDate: selectedDate,
                          today: today,
                          isCompact: isShortViewport,
                          onResetToToday: !_isSameDay(selectedDate, today)
                              ? () =>
                                    ref
                                            .read(
                                              selectedActivityDateProvider
                                                  .notifier,
                                            )
                                            .state =
                                        today
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(child: list),
                  ],
                ),
              ),
            ],
          );
        },
      );
    }

    return TabletShell(
      activeSection: TabletSection.teaching,
      brandName: schoolContext.displayName,
      brandLogoUrl: schoolContext.logoUrl,
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
  const _ActionRail({
    required this.summary,
    required this.selectedDate,
    required this.today,
    this.isCompact = false,
    this.visualScale = 1,
    this.onResetToToday,
  });

  final PortalSummary summary;
  final DateTime selectedDate;
  final DateTime today;
  final bool isCompact;
  final double visualScale;
  final VoidCallback? onResetToToday;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(selectedDate, today);
    final taskLabel = '${summary.totalActivities} 份作业';
    final pendingLabel = '${summary.pendingTasks} 项待补做';
    final completedLabel = '${summary.completedActivities} 份已完成';

    return Container(
      padding: EdgeInsets.all((isCompact ? 14 : 18) * visualScale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          _RailAction(
            icon: Icons.fact_check_outlined,
            label: isToday ? '今日作业' : _formatDateLabel(selectedDate),
            value: taskLabel,
            isCompact: isCompact,
            visualScale: visualScale,
          ),
          SizedBox(height: (isCompact ? 10 : 14) * visualScale),
          _RailAction(
            icon: Icons.pending_actions_outlined,
            label: isToday ? '待完成' : '待补作业',
            value: pendingLabel,
            isCompact: isCompact,
            visualScale: visualScale,
          ),
          SizedBox(height: (isCompact ? 10 : 14) * visualScale),
          _RailAction(
            icon: Icons.workspace_premium_outlined,
            label: '已完成',
            value: completedLabel,
            isCompact: isCompact,
            visualScale: visualScale,
          ),
          SizedBox(height: (isCompact ? 10 : 14) * visualScale),
          _StudyHintTile(
            title: isToday ? '今天先完成今天的作业' : '漏掉的作业也可以补做',
            subtitle: isToday
                ? '想补做前几天的内容，可以在上面的日期条里切换。'
                : '这一天的作业会单独显示，做完后再切回今天继续。',
            accent: isToday ? const Color(0xFF4FAE7F) : const Color(0xFFFF9B55),
            visualScale: visualScale,
          ),
          if (onResetToToday != null) ...[
            SizedBox(height: (isCompact ? 10 : 14) * visualScale),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onResetToToday,
                icon: const Icon(Icons.today_rounded),
                label: const Text('回到今天'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeworkCalendarStrip extends StatelessWidget {
  const _HomeworkCalendarStrip({
    required this.dates,
    required this.selectedDate,
    required this.today,
    required this.activityCountByDate,
    required this.onSelectDate,
    this.visualScale = 1,
  });

  final List<DateTime> dates;
  final DateTime selectedDate;
  final DateTime today;
  final Map<DateTime, int> activityCountByDate;
  final ValueChanged<DateTime> onSelectDate;
  final double visualScale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108 * visualScale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = _isSameDay(date, selectedDate);
          final isToday = _isSameDay(date, today);
          final count = activityCountByDate[date] ?? 0;

          return InkWell(
            onTap: () => onSelectDate(date),
            borderRadius: BorderRadius.circular(26),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 104 * visualScale,
              padding: EdgeInsets.symmetric(
                horizontal: 14 * visualScale,
                vertical: 12 * visualScale,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1E7D66)
                    : Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(26),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1E7D66).withValues(alpha: 0.2),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isToday ? '今天' : _weekdayLabel(date),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.9)
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${date.month}/${date.day}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF1E293B),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    count > 0 ? '$count 份作业' : '暂无作业',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.88)
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => SizedBox(width: 12 * visualScale),
        itemCount: dates.length,
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
    this.isCompact = false,
    this.visualScale = 1,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isCompact;
  final double visualScale;

  @override
  Widget build(BuildContext context) {
    final iconSize = (isCompact ? 22.0 : 24.0) * visualScale;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: const Color(0xFF25324B),
      fontWeight: FontWeight.w800,
    );
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF64748B),
      fontWeight: FontWeight.w700,
    );

    return Container(
      constraints: BoxConstraints(
        minHeight: (isCompact ? 76 : 92) * visualScale,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: (isCompact ? 14 : 16) * visualScale,
        vertical: (isCompact ? 12 : 0) * visualScale,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4FAE7F), size: iconSize),
          SizedBox(width: (isCompact ? 10 : 12) * visualScale),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: titleStyle),
                SizedBox(height: (isCompact ? 2 : 4) * visualScale),
                Text(value, style: valueStyle),
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
    this.visualScale = 1,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final double visualScale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompactPadding(context) * visualScale),
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
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

  double isCompactPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < 980 ? 16 : 18;
  }
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _formatDateLabel(DateTime date) => '${date.month}月${date.day}日';

String _weekdayLabel(DateTime date) {
  const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return labels[date.weekday - 1];
}

class _ActivityRow extends ConsumerWidget {
  const _ActivityRow({required this.activity, this.visualScale = 1});

  final PortalActivity activity;
  final double visualScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(practiceSessionProvider(activity.id));
    final progress = _activityLearningProgress(activity, session);
    final nextStep = _nextStepLabel(activity.status, progress);
    final resumeLabel = progress.resumeTaskIndex == null
        ? null
        : '继续第 ${progress.resumeTaskIndex} 句';
    final progressLabel = progress.totalTasks == 0
        ? '今天没有句子任务'
        : '已闯过 ${progress.completedTasks}/${progress.totalTasks} 句';
    final progressMessage = switch ((
      progress.completedTasks,
      progress.totalTasks,
    )) {
      (_, 0) => '老师已经准备好了学习材料，进去看看今天学什么。',
      (final completed, final total) when completed >= total =>
        '这一份已经全部完成，进去看看老师给你的反馈。',
      _ when progress.resumeTaskIndex != null =>
        '上次已经做到第 ${progress.resumeTaskIndex} 句了，回来继续闯关吧。',
      (0, _) => '从第一句开始闯关，跟着示范音频一步步完成。',
      _ => '已经完成一部分了，继续闯关就快全部点亮啦。',
    };

    return InkWell(
      onTap: () => context.go('/activities/${activity.id}'),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: EdgeInsets.all(22 * visualScale),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(30),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isPhone = constraints.maxWidth < 680;
            final cover = Container(
              width: isPhone ? double.infinity : 190,
              height: 118 * visualScale,
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
                const SizedBox(height: 10),
                Text(
                  progressMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                _ActivityProgressBar(
                  completed: progress.completedTasks,
                  total: progress.totalTasks,
                  resumeTaskIndex: progress.resumeTaskIndex,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoChip(label: '任务 ${activity.tasks.length} 项'),
                    _InfoChip(label: progressLabel),
                    _InfoChip(label: '老师反馈 ${activity.reviewCount} 条'),
                    if (resumeLabel != null) _InfoChip(label: resumeLabel),
                  ],
                ),
              ],
            );

            final actions = isPhone
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatusBadge(status: activity.status),
                      SizedBox(height: 12 * visualScale),
                      Text(
                        progress.isCompleted
                            ? '点进去可以回听录音、看老师反馈，还能继续挑战更高分。'
                            : '点进去就能继续做句子练习、录音和提交。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 12 * visualScale),
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
                      SizedBox(height: 18 * visualScale),
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

  String _nextStepLabel(
    ActivityStatus status,
    _ActivityLearningProgress progress,
  ) {
    switch (status) {
      case ActivityStatus.completed:
        return '查看反馈';
      case ActivityStatus.reviewPending:
        return progress.isCompleted
            ? '查看进度'
            : progress.resumeTaskIndex != null
            ? '继续第 ${progress.resumeTaskIndex} 句'
            : '继续闯关';
      case ActivityStatus.active:
        return progress.resumeTaskIndex != null
            ? '继续第 ${progress.resumeTaskIndex} 句'
            : progress.hasStarted
            ? '继续闯关'
            : '开始闯关';
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
      ActivityStatus.completed => ('今天完成啦', const Color(0xFF16A34A)),
      ActivityStatus.reviewPending => ('等老师来听', const Color(0xFFF97316)),
      ActivityStatus.active => ('正在闯关', const Color(0xFF2563EB)),
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

class _ActivityLearningProgress {
  const _ActivityLearningProgress({
    required this.completedTasks,
    required this.totalTasks,
    this.resumeTaskIndex,
  });

  final int completedTasks;
  final int totalTasks;
  final int? resumeTaskIndex;

  bool get hasStarted => completedTasks > 0 || resumeTaskIndex != null;
  bool get isCompleted => totalTasks > 0 && completedTasks >= totalTasks;
}

_ActivityLearningProgress _activityLearningProgress(
  PortalActivity activity,
  PracticeSessionState session,
) {
  final completedTaskIds = <String>{
    for (final task in activity.tasks)
      if (task.reviewStatus == TaskReviewStatus.checked) task.id,
    for (final entry in session.taskStates.entries)
      if (entry.value.isCompleted) entry.key,
  };

  return _ActivityLearningProgress(
    completedTasks: completedTaskIds.length,
    totalTasks: activity.tasks.length,
    resumeTaskIndex: _resumeTaskIndex(activity, session, completedTaskIds),
  );
}

int? _resumeTaskIndex(
  PortalActivity activity,
  PracticeSessionState session,
  Set<String> completedTaskIds,
) {
  final focusedTaskId = session.focusedTaskId;
  if (focusedTaskId == null ||
      completedTaskIds.length >= activity.tasks.length) {
    return null;
  }
  final index = activity.tasks.indexWhere((task) => task.id == focusedTaskId);
  if (index < 0) {
    return null;
  }
  return index + 1;
}

class _ActivityProgressBar extends StatelessWidget {
  const _ActivityProgressBar({
    required this.completed,
    required this.total,
    this.resumeTaskIndex,
  });

  final int completed;
  final int total;
  final int? resumeTaskIndex;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: progress),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 12,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF2FA77D)),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          total == 0
              ? '等老师布置句子任务'
              : completed >= total
              ? '这一份已经全部点亮啦'
              : completed == 0 && resumeTaskIndex != null
              ? '上次做到第 $resumeTaskIndex 句了，接着继续就好'
              : '再完成 ${total - completed} 句就能完成这份作业',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
    final size = MediaQuery.sizeOf(context);
    final isTightLandscapePhone = size.width > size.height && size.height < 430;
    final backgroundColor = isPrimary
        ? const Color(0xFFFF8F4D)
        : Colors.white.withValues(alpha: 0.18);
    const foregroundColor = Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTightLandscapePhone ? 12 : 16,
          vertical: isTightLandscapePhone ? 9 : 12,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: foregroundColor,
              size: isTightLandscapePhone ? 16 : 18,
            ),
            SizedBox(width: isTightLandscapePhone ? 6 : 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
                fontSize: isTightLandscapePhone ? 13 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _activityLandscapeVisualScale(double maxWidth, double maxHeight) {
  final heightScale = (maxHeight / 430).clamp(0.8, 1.0);
  final widthScale = (maxWidth / 960).clamp(0.9, 1.0);
  return (heightScale * widthScale).clamp(0.8, 1.0);
}
