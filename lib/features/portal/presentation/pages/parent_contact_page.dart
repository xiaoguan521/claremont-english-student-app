import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_models.dart';
import '../../data/portal_repository.dart';
import '../../data/queued_submission_storage.dart';
import '../../../school/presentation/providers/school_context_provider.dart';
import '../providers/parent_contact_providers.dart';
import '../providers/portal_providers.dart';
import '../providers/student_feature_flags_provider.dart';
import '../providers/sync_queue_providers.dart';
import '../widgets/tablet_shell.dart';

class ParentContactPage extends ConsumerStatefulWidget {
  const ParentContactPage({required this.activityId, super.key});

  final String activityId;

  @override
  ConsumerState<ParentContactPage> createState() => _ParentContactPageState();
}

class _ParentContactPageState extends ConsumerState<ParentContactPage> {
  Timer? _reviewRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(syncQueueStatusProvider.notifier)
          .processPendingUploads(
            portalRepository: ref.read(portalRepositoryProvider),
            submissionStorage: ref.read(queuedSubmissionStorageProvider),
            onActivitySynced: (activityId) {
              ref.invalidate(portalActivityByIdProvider(activityId));
              ref.invalidate(parentContactSummaryProvider(activityId));
              ref.invalidate(portalActivitiesProvider);
              ref.invalidate(dailyGrowthSummaryProvider);
            },
          );
    });
  }

  @override
  void dispose() {
    _reviewRefreshTimer?.cancel();
    super.dispose();
  }

  void _syncReviewRefresh(PortalActivity? activity) {
    final shouldRefresh =
        activity != null &&
        (activity.submissionFlowStatus == SubmissionFlowStatus.queued ||
            activity.submissionFlowStatus == SubmissionFlowStatus.processing ||
            (activity.submissionFlowStatus == SubmissionFlowStatus.completed &&
                !activity.hasTeacherReviewedResult));

    if (!shouldRefresh) {
      _reviewRefreshTimer?.cancel();
      _reviewRefreshTimer = null;
      return;
    }

    if (_reviewRefreshTimer != null) {
      return;
    }

    _reviewRefreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) {
        return;
      }
      ref.invalidate(portalActivityByIdProvider(widget.activityId));
      ref.invalidate(parentContactSummaryProvider(widget.activityId));
      ref.invalidate(portalActivitiesProvider);
      ref.invalidate(dailyGrowthSummaryProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(
      parentContactSummaryProvider(widget.activityId),
    );
    final activity = ref
        .watch(portalActivityByIdProvider(widget.activityId))
        .valueOrNull;
    final pendingSyncCount = ref.watch(
      syncQueuePendingCountProvider(widget.activityId),
    );
    final featureFlags = ref.watch(studentFeatureFlagsProvider);
    final schoolContext =
        ref.watch(schoolContextProvider).valueOrNull ??
        SchoolContext.fallback();

    return TabletShell(
      activeSection: TabletSection.teaching,
      brandName: schoolContext.displayName,
      brandLogoUrl: schoolContext.logoUrl,
      brandSubtitle: '学校学习入口',
      title: '联系家长',
      subtitle: pendingSyncCount > 0 ? '最新学习记录还在继续整理中' : '把今天的学习情况清楚告诉家长',
      child: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _ParentContactMessage(
          title: '家长摘要暂时打不开',
          message: '请稍后再试，或者先回到作业页继续今天的学习任务。',
        ),
        data: (summary) {
          _syncReviewRefresh(activity);
          if (summary == null) {
            return _ParentContactMessage(
              title: pendingSyncCount > 0 ? '学习摘要正在整理中' : '还没有找到今天的学习摘要',
              message: pendingSyncCount > 0
                  ? '这份作业的最新记录还在继续同步，稍后回来就能看到更完整的学习情况。'
                  : '这份作业可能还没有形成可展示的学习摘要，可以先回到任务页继续完成今天的学习。',
            );
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroSummaryCard(summary: summary),
                if (summary.isCachedFallback ||
                    summary.isFeedbackPending ||
                    pendingSyncCount > 0) ...[
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: '当前状态',
                    icon: Icons.info_rounded,
                    accent: const Color(0xFF0EA5E9),
                    child: Text(
                      summary.isCachedFallback
                          ? '当前展示的是最近一次保存在本机上的学习摘要，等网络恢复后会自动更新。'
                          : pendingSyncCount > 0
                          ? '最新学习记录还在继续同步，家长现在先看到的是已经整理出来的部分内容。'
                          : '当前以过程摘要为主，老师反馈或 AI 结果返回后，这里会继续补充。页面会自动刷新，不需要反复退出重进。',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isPhone = constraints.maxWidth < 860;
                    final progressCard = _InfoCard(
                      title: '今天完成了什么',
                      icon: Icons.task_alt_rounded,
                      accent: const Color(0xFF16A34A),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${summary.completedTasks}/${summary.totalTasks} 句已完成',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            summary.submissionStatusLabel,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: const Color(0xFF334155),
                                  fontWeight: FontWeight.w700,
                                  height: 1.45,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _ProgressLine(
                            completed: summary.completedTasks,
                            total: summary.totalTasks,
                          ),
                        ],
                      ),
                    );
                    final feedbackCard = _InfoCard(
                      title: '结果和反馈',
                      icon: Icons.rate_review_rounded,
                      accent: const Color(0xFF2563EB),
                      child: Text(
                        summary.feedbackStatusLabel,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                      ),
                    );
                    final healthCard = _InfoCard(
                      title: '健康提醒',
                      icon: Icons.visibility_rounded,
                      accent: const Color(0xFFF97316),
                      child: Text(
                        summary.healthSummary,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                      ),
                    );

                    if (isPhone) {
                      return Column(
                        children: [
                          progressCard,
                          const SizedBox(height: 14),
                          feedbackCard,
                          const SizedBox(height: 14),
                          healthCard,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: progressCard),
                        const SizedBox(width: 14),
                        Expanded(child: feedbackCard),
                        const SizedBox(width: 14),
                        Expanded(child: healthCard),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isPhone = constraints.maxWidth < 860;
                    final rewardCard = _InfoCard(
                      title: '学习表现',
                      icon: Icons.star_rounded,
                      accent: const Color(0xFFF59E0B),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _MetricChip(
                                label: '星币 +${summary.earnedStars}',
                                accent: const Color(0xFFF59E0B),
                                icon: Icons.star_rounded,
                              ),
                              _MetricChip(
                                label: '连对 ${summary.comboCount}',
                                accent: const Color(0xFFEF4444),
                                icon: Icons.local_fire_department_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            summary.earnedStars > 0
                                ? '今天的过程奖励已经累计下来了，孩子每完成一步都会得到及时正反馈。'
                                : '今天的过程奖励还在积累中，完成更多句子后会形成更明显的正反馈。',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: const Color(0xFF334155),
                                  fontWeight: FontWeight.w700,
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    );
                    final trustCard = _InfoCard(
                      title: '专注与保护',
                      icon: Icons.shield_rounded,
                      accent: const Color(0xFF0EA5E9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _MetricChip(
                                label: '切后台 ${summary.backgroundSwitchCount} 次',
                                accent: const Color(0xFF0EA5E9),
                                icon: Icons.open_in_new_rounded,
                              ),
                              _MetricChip(
                                label: '休息提醒 ${summary.breakReminderCount} 次',
                                accent: const Color(0xFF16A34A),
                                icon: Icons.visibility_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '这些记录帮助家长判断孩子今天学习时是否保持专注，以及系统有没有及时提醒休息。',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: const Color(0xFF334155),
                                  fontWeight: FontWeight.w700,
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    );

                    final cards = <Widget>[
                      if (featureFlags.showGrowthRewards) rewardCard,
                      if (featureFlags.showEnhancedHealthInsights) trustCard,
                    ];
                    if (cards.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    if (isPhone) {
                      return Column(
                        children: [
                          for (
                            var index = 0;
                            index < cards.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(height: 14),
                            cards[index],
                          ],
                        ],
                      );
                    }

                    if (cards.length == 1) {
                      return cards.first;
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards.first),
                        const SizedBox(width: 14),
                        Expanded(child: cards.last),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _InfoCard(
                  title: '建议家长关注',
                  icon: Icons.favorite_rounded,
                  accent: const Color(0xFFE11D48),
                  child: summary.focusAreas.isEmpty
                      ? Text(
                          '今天的关键反馈还在整理中，可以先鼓励孩子把剩余句子完成。',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: const Color(0xFF334155),
                                fontWeight: FontWeight.w700,
                                height: 1.45,
                              ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: summary.focusAreas
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '• ',
                                        style: TextStyle(
                                          color: Color(0xFFE11D48),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          item,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                color: const Color(0xFF334155),
                                                fontWeight: FontWeight.w700,
                                                height: 1.45,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  const _HeroSummaryCard({required this.summary});

  final ParentContactSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5DB9FF), Color(0xFF2D8DFF), Color(0xFF69D5FF)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.activityTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${summary.className} · ${summary.dateLabel}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            summary.isCachedFallback
                ? '当前先展示最近一次保存在本机上的学习摘要，网络恢复后会继续更新。'
                : summary.isFeedbackPending
                ? '今天的英语作业进展已经整理好了，家长可以先查看完成情况，老师反馈和 AI 结果会继续补充。'
                : '今天的英语作业进展已经整理好了，家长可以直接查看完成情况和需要继续关注的地方。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.96),
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroStatChip(
                label: '已完成 ${summary.completedTasks}/${summary.totalTasks}',
              ),
              _HeroStatChip(label: summary.updatedAtLabel),
              _HeroStatChip(label: '星币 +${summary.earnedStars}'),
              _HeroStatChip(label: '连对 ${summary.comboCount}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.accent,
    required this.icon,
  });

  final String label;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF16A34A)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          total == 0
              ? '今天还没有句子任务'
              : completed >= total
              ? '今天的句子任务已经全部完成'
              : '还剩 ${total - completed} 句待完成',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ParentContactMessage extends StatelessWidget {
  const _ParentContactMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
