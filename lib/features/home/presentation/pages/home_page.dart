import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../portal/presentation/providers/portal_providers.dart';
import '../../../portal/presentation/widgets/tablet_shell.dart';
import '../../../school/presentation/providers/school_context_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightedActivityAsync = ref.watch(highlightedActivityProvider);
    final summaryAsync = ref.watch(portalSummaryProvider);
    final schoolContextAsync = ref.watch(schoolContextProvider);
    final currentUserEmail = ref.watch(currentUserEmailProvider);

    final schoolContext =
        schoolContextAsync.valueOrNull ?? SchoolContext.fallback();

    Widget child;
    if (highlightedActivityAsync.isLoading || summaryAsync.isLoading) {
      child = const Center(child: CircularProgressIndicator());
    } else if (highlightedActivityAsync.hasError || summaryAsync.hasError) {
      child = const _StateMessage(
        title: '学习任务暂时没有同步成功',
        message: '请检查网络或稍后再试。',
      );
    } else {
      final highlightedActivity = highlightedActivityAsync.valueOrNull;
      final summary = summaryAsync.valueOrNull;

      if (highlightedActivity == null || summary == null) {
        child = const _StateMessage(
          title: '今天还没有新任务',
          message: '老师发布作业后，这里会第一时间提醒你。',
        );
      } else {
        child = LayoutBuilder(
          builder: (context, constraints) {
            final isPhone = constraints.maxWidth < 700;
            final isWide = constraints.maxWidth >= 1160;
            final isLandscapePhone =
                constraints.maxWidth > constraints.maxHeight &&
                constraints.maxWidth < 1100;
            final content = isWide
                ? _WideHomeLayout(
                    schoolContext: schoolContext,
                    currentUserEmail: currentUserEmail,
                    highlightedActivityId: highlightedActivity.id,
                    highlightedActivityTitle: highlightedActivity.title,
                    highlightedClassName: highlightedActivity.className,
                    highlightedDateLabel: highlightedActivity.dateLabel,
                    summary: summary,
                  )
                : isLandscapePhone
                ? _LandscapePhoneHomeLayout(
                    schoolContext: schoolContext,
                    currentUserEmail: currentUserEmail,
                    highlightedActivityId: highlightedActivity.id,
                    highlightedActivityTitle: highlightedActivity.title,
                    highlightedClassName: highlightedActivity.className,
                    highlightedDateLabel: highlightedActivity.dateLabel,
                    summary: summary,
                  )
                : isPhone
                ? _PhoneHomeLayout(
                    schoolContext: schoolContext,
                    currentUserEmail: currentUserEmail,
                    highlightedActivityId: highlightedActivity.id,
                    highlightedActivityTitle: highlightedActivity.title,
                    highlightedClassName: highlightedActivity.className,
                    highlightedDateLabel: highlightedActivity.dateLabel,
                    summary: summary,
                  )
                : _CompactHomeLayout(
                    schoolContext: schoolContext,
                    currentUserEmail: currentUserEmail,
                    highlightedActivityId: highlightedActivity.id,
                    highlightedActivityTitle: highlightedActivity.title,
                    highlightedClassName: highlightedActivity.className,
                    highlightedDateLabel: highlightedActivity.dateLabel,
                    summary: summary,
                  );

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: content,
              ),
            );
          },
        );
      }
    }

    return TabletShell(
      activeSection: TabletSection.management,
      brandName: schoolContext.displayName,
      brandSubtitle: '学校学习入口',
      title: '今日任务',
      subtitle: schoolContext.welcomeMessage,
      child: child,
    );
  }
}

void _showComingSoonSheet(
  BuildContext context, {
  required String title,
  required String description,
  required Color accent,
  required IconData icon,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: accent, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/activities');
              },
              icon: const Icon(Icons.play_circle_fill_rounded),
              label: const Text('先去完成作业'),
            ),
          ],
        ),
      );
    },
  );
}

class _LandscapePhoneHomeLayout extends StatelessWidget {
  const _LandscapePhoneHomeLayout({
    required this.schoolContext,
    required this.currentUserEmail,
    required this.highlightedActivityId,
    required this.highlightedActivityTitle,
    required this.highlightedClassName,
    required this.highlightedDateLabel,
    required this.summary,
  });

  final SchoolContext schoolContext;
  final String? currentUserEmail;
  final String highlightedActivityId;
  final String highlightedActivityTitle;
  final String highlightedClassName;
  final String highlightedDateLabel;
  final PortalSummary summary;

  @override
  Widget build(BuildContext context) {
    final displayName = _studentDisplayName(currentUserEmail);
    return SizedBox(
      height: 418,
      child: Column(
        children: [
          _FeatureTopBar(
            onOpenFeature: (title, description, accent, icon) {
              _showComingSoonSheet(
                context,
                title: title,
                description: description,
                accent: accent,
                icon: icon,
              );
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 236,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _LandscapeStudentCard(
                          displayName: displayName,
                          currentUserEmail: currentUserEmail,
                          summary: summary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        flex: 2,
                        child: _LandscapeShortcutPanel(
                          highlightedActivityId: highlightedActivityId,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 5,
                  child: _LandscapeTaskBoard(
                    schoolContext: schoolContext,
                    highlightedActivityId: highlightedActivityId,
                    highlightedActivityTitle: highlightedActivityTitle,
                    highlightedClassName: highlightedClassName,
                    highlightedDateLabel: highlightedDateLabel,
                    summary: summary,
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 252,
                  child: _LandscapeReadingRail(
                    schoolContext: schoolContext,
                    highlightedActivityId: highlightedActivityId,
                    summary: summary,
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

class _FeatureTopBar extends StatelessWidget {
  const _FeatureTopBar({required this.onOpenFeature});

  final void Function(
    String title,
    String description,
    Color accent,
    IconData icon,
  )
  onOpenFeature;

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        '背单词',
        '单词乐园正在准备中，后面会用小游戏帮你记住今天的新单词。',
        Color(0xFFFFC533),
        Icons.translate_rounded,
      ),
      (
        '视频配音',
        '视频配音正在准备中，后面会把动画里的句子做成跟读练习。',
        Color(0xFFFF8C5A),
        Icons.ondemand_video_rounded,
      ),
      (
        '快乐听',
        '快乐听正在准备中，后面会给你更多有趣的听力素材。',
        Color(0xFF6EA8FF),
        Icons.headphones_rounded,
      ),
      (
        '练口语',
        '练口语正在准备中，后面会给你更多闯关式口语练习。',
        Color(0xFFFFB255),
        Icons.record_voice_over_rounded,
      ),
      (
        '创作作品',
        '创作作品正在准备中，以后你可以在这里保存自己的朗读作品。',
        Color(0xFF71D49A),
        Icons.wb_sunny_rounded,
      ),
    ];

    return Row(
      children: [
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 8,
            children: items
                .map(
                  (item) => _FeatureBubble(
                    title: item.$1,
                    accent: item.$3,
                    icon: item.$4,
                    onTap: () =>
                        onOpenFeature(item.$1, item.$2, item.$3, item.$4),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _FeatureBubble extends StatelessWidget {
  const _FeatureBubble({
    required this.title,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF334155),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneHomeLayout extends StatelessWidget {
  const _PhoneHomeLayout({
    required this.schoolContext,
    required this.currentUserEmail,
    required this.highlightedActivityId,
    required this.highlightedActivityTitle,
    required this.highlightedClassName,
    required this.highlightedDateLabel,
    required this.summary,
  });

  final SchoolContext schoolContext;
  final String? currentUserEmail;
  final String highlightedActivityId;
  final String highlightedActivityTitle;
  final String highlightedClassName;
  final String highlightedDateLabel;
  final PortalSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeroCard(
          schoolContext: schoolContext,
          currentUserEmail: currentUserEmail,
          highlightedActivityId: highlightedActivityId,
          highlightedActivityTitle: highlightedActivityTitle,
          highlightedClassName: highlightedClassName,
          highlightedDateLabel: highlightedDateLabel,
          summary: summary,
          isCompact: true,
        ),
        const SizedBox(height: 16),
        _SummaryGrid(
          summary: summary,
          activityId: highlightedActivityId,
          isCompact: true,
        ),
        const SizedBox(height: 16),
        _QuickActionsColumn(activityId: highlightedActivityId),
        const SizedBox(height: 16),
        _FeedbackPanel(summary: summary, isCompact: true),
        const SizedBox(height: 16),
        _SchoolPanel(schoolContext: schoolContext, isCompact: true),
      ],
    );
  }
}

class _LandscapeStudentCard extends StatelessWidget {
  const _LandscapeStudentCard({
    required this.displayName,
    required this.currentUserEmail,
    required this.summary,
  });

  final String displayName;
  final String? currentUserEmail;
  final PortalSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2FB98B).withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF72B8FF).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '个人中心',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF2B6CB0),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8FD2FF), Color(0xFF6EE7C8)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1E293B),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentUserEmail ?? '学生账号',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _LandscapeMetric(
                  icon: Icons.stars_rounded,
                  color: const Color(0xFFF5B019),
                  value: '${summary.totalActivities}',
                  label: '任务',
                ),
              ),
              Expanded(
                child: _LandscapeMetric(
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFFF8F4D),
                  value: '${summary.pendingTasks}',
                  label: '待做',
                ),
              ),
              Expanded(
                child: _LandscapeMetric(
                  icon: Icons.workspace_premium_rounded,
                  color: const Color(0xFF55C38A),
                  value: '${summary.completedActivities}',
                  label: '完成',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LandscapeMetric extends StatelessWidget {
  const _LandscapeMetric({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LandscapeShortcutPanel extends StatelessWidget {
  const _LandscapeShortcutPanel({required this.highlightedActivityId});

  final String highlightedActivityId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
      ),
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: [
          _LandscapeShortcutButton(
            icon: Icons.menu_book_rounded,
            label: '作业',
            accent: const Color(0xFF72B8FF),
            onTap: () => context.go('/activities'),
          ),
          _LandscapeShortcutButton(
            icon: Icons.rate_review_rounded,
            label: '反馈',
            accent: const Color(0xFFFF8F4D),
            onTap: () => context.go('/activities/$highlightedActivityId'),
          ),
          _LandscapeShortcutButton(
            icon: Icons.notifications_active_rounded,
            label: '提醒',
            accent: const Color(0xFF55C38A),
            onTap: () => _showComingSoonSheet(
              context,
              title: '学习提醒',
              description: '学习提醒正在准备中，以后老师发来消息会先在这里提醒你。',
              accent: const Color(0xFF55C38A),
              icon: Icons.notifications_active_rounded,
            ),
          ),
          _LandscapeShortcutButton(
            icon: Icons.stars_rounded,
            label: '更多',
            accent: const Color(0xFFF3C14B),
            onTap: () => context.go('/explore'),
          ),
        ],
      ),
    );
  }
}

class _LandscapeShortcutButton extends StatelessWidget {
  const _LandscapeShortcutButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF334155),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandscapeTaskBoard extends StatelessWidget {
  const _LandscapeTaskBoard({
    required this.schoolContext,
    required this.highlightedActivityId,
    required this.highlightedActivityTitle,
    required this.highlightedClassName,
    required this.highlightedDateLabel,
    required this.summary,
  });

  final SchoolContext schoolContext;
  final String highlightedActivityId;
  final String highlightedActivityTitle;
  final String highlightedClassName;
  final String highlightedDateLabel;
  final PortalSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(34),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    schoolContext.primaryColor.withValues(alpha: 0.88),
                    schoolContext.secondaryColor.withValues(alpha: 0.9),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.assignment_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '今日主线',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '今天先完成这份作业',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    highlightedActivityTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$highlightedClassName · $highlightedDateLabel',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: schoolContext.primaryColor,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: () =>
                        context.go('/activities/$highlightedActivityId'),
                    child: const Text('开始今日任务'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _LandscapeFeatureCard(
                          title: '今日任务',
                          subtitle: '点进去继续完成今天的学习',
                          value: '${summary.totalActivities}',
                          accent: const Color(0xFF73B7FF),
                          icon: Icons.auto_stories_rounded,
                          onTap: () => context.go('/activities'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LandscapeFeatureCard(
                          title: '点评中心',
                          subtitle: '完成作业后回来查看点评',
                          value: '${summary.completedActivities}',
                          accent: const Color(0xFFFF8F4D),
                          icon: Icons.rate_review_rounded,
                          onTap: () =>
                              context.go('/activities/$highlightedActivityId'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _LandscapeFeatureCard(
                    title: '任务中心',
                    subtitle: '还有这些内容等你完成',
                    value: '${summary.pendingTasks}',
                    accent: const Color(0xFF59C38C),
                    icon: Icons.checklist_rounded,
                    onTap: () => context.go('/activities'),
                    isWide: true,
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

class _LandscapeFeatureCard extends StatelessWidget {
  const _LandscapeFeatureCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
    required this.icon,
    required this.onTap,
    this.isWide = false,
  });

  final String title;
  final String subtitle;
  final String value;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEFF7FF),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isWide
              ? Row(
                  children: [
                    _LandscapeFeatureBadge(icon: icon, accent: accent),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: const Color(0xFF1E293B),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _LandscapeFeatureBadge(icon: icon, accent: accent),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            value,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1E293B),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LandscapeFeatureBadge extends StatelessWidget {
  const _LandscapeFeatureBadge({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: accent, size: 28),
    );
  }
}

class _LandscapeReadingRail extends StatelessWidget {
  const _LandscapeReadingRail({
    required this.schoolContext,
    required this.highlightedActivityId,
    required this.summary,
  });

  final SchoolContext schoolContext;
  final String highlightedActivityId;
  final PortalSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _LandscapeShelfCard(
            title: '课本跟读',
            subtitle: '点进去继续今天的课本阅读',
            accent: const Color(0xFF71B7FF),
            icon: Icons.auto_stories_rounded,
            onTap: () => context.go('/activities/$highlightedActivityId'),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _LandscapeShelfCard(
            title: '自然拼读',
            subtitle: '回到任务页继续朗读练习',
            accent: const Color(0xFF55C38A),
            icon: Icons.record_voice_over_rounded,
            onTap: () => context.go('/activities'),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: schoolContext.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.lightbulb_rounded,
                  color: schoolContext.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '今天还有 ${summary.pendingTasks} 项任务等你完成。',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LandscapeShelfCard extends StatelessWidget {
  const _LandscapeShelfCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.8),
                      accent.withValues(alpha: 0.45),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const Spacer(),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.title, required this.message});

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

class _WideHomeLayout extends StatelessWidget {
  const _WideHomeLayout({
    required this.schoolContext,
    required this.currentUserEmail,
    required this.highlightedActivityId,
    required this.highlightedActivityTitle,
    required this.highlightedClassName,
    required this.highlightedDateLabel,
    required this.summary,
  });

  final SchoolContext schoolContext;
  final String? currentUserEmail;
  final String highlightedActivityId;
  final String highlightedActivityTitle;
  final String highlightedClassName;
  final String highlightedDateLabel;
  final PortalSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _HeroCard(
                schoolContext: schoolContext,
                currentUserEmail: currentUserEmail,
                highlightedActivityId: highlightedActivityId,
                highlightedActivityTitle: highlightedActivityTitle,
                highlightedClassName: highlightedClassName,
                highlightedDateLabel: highlightedDateLabel,
                summary: summary,
              ),
              const SizedBox(height: 18),
              _QuickActionsRow(activityId: highlightedActivityId),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _SummaryGrid(summary: summary, activityId: highlightedActivityId),
              const SizedBox(height: 18),
              _FeedbackPanel(summary: summary),
              const SizedBox(height: 18),
              _SchoolPanel(schoolContext: schoolContext),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactHomeLayout extends StatelessWidget {
  const _CompactHomeLayout({
    required this.schoolContext,
    required this.currentUserEmail,
    required this.highlightedActivityId,
    required this.highlightedActivityTitle,
    required this.highlightedClassName,
    required this.highlightedDateLabel,
    required this.summary,
  });

  final SchoolContext schoolContext;
  final String? currentUserEmail;
  final String highlightedActivityId;
  final String highlightedActivityTitle;
  final String highlightedClassName;
  final String highlightedDateLabel;
  final PortalSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeroCard(
          schoolContext: schoolContext,
          currentUserEmail: currentUserEmail,
          highlightedActivityId: highlightedActivityId,
          highlightedActivityTitle: highlightedActivityTitle,
          highlightedClassName: highlightedClassName,
          highlightedDateLabel: highlightedDateLabel,
          summary: summary,
        ),
        const SizedBox(height: 18),
        _SummaryGrid(summary: summary, activityId: highlightedActivityId),
        const SizedBox(height: 18),
        _QuickActionsRow(activityId: highlightedActivityId),
        const SizedBox(height: 18),
        _FeedbackPanel(summary: summary),
        const SizedBox(height: 18),
        _SchoolPanel(schoolContext: schoolContext),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.schoolContext,
    required this.currentUserEmail,
    required this.highlightedActivityId,
    required this.highlightedActivityTitle,
    required this.highlightedClassName,
    required this.highlightedDateLabel,
    required this.summary,
    this.isCompact = false,
  });

  final SchoolContext schoolContext;
  final String? currentUserEmail;
  final String highlightedActivityId;
  final String highlightedActivityTitle;
  final String highlightedClassName;
  final String highlightedDateLabel;
  final PortalSummary summary;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [schoolContext.primaryColor, schoolContext.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: schoolContext.primaryColor.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schoolContext.welcomeTitle,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '今天优先完成 $highlightedActivityTitle，完成后就能看到老师的新反馈。',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _HeroBadge(
                      icon: Icons.groups_rounded,
                      label: highlightedClassName,
                    ),
                    _HeroBadge(
                      icon: Icons.calendar_today_rounded,
                      label: highlightedDateLabel,
                    ),
                    _HeroBadge(
                      icon: Icons.pending_actions_rounded,
                      label: '待完成 ${summary.pendingTasks} 项',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: schoolContext.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () =>
                          context.go('/activities/$highlightedActivityId'),
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      label: const Text('开始今日作业'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white70),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () => context.go('/activities'),
                      icon: const Icon(Icons.menu_book_rounded),
                      label: const Text('查看全部作业'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _AccountPanel(
                  currentUserEmail: currentUserEmail,
                  summary: summary,
                  isCompact: true,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schoolContext.welcomeTitle,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '今天优先完成 $highlightedActivityTitle，完成后就能看到老师的新反馈。',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _HeroBadge(
                            icon: Icons.groups_rounded,
                            label: highlightedClassName,
                          ),
                          _HeroBadge(
                            icon: Icons.calendar_today_rounded,
                            label: highlightedDateLabel,
                          ),
                          _HeroBadge(
                            icon: Icons.pending_actions_rounded,
                            label: '待完成 ${summary.pendingTasks} 项',
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: schoolContext.primaryColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 16,
                              ),
                            ),
                            onPressed: () => context.go(
                              '/activities/$highlightedActivityId',
                            ),
                            icon: const Icon(Icons.play_circle_fill_rounded),
                            label: const Text('开始今日作业'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white70),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                            ),
                            onPressed: () => context.go('/activities'),
                            icon: const Icon(Icons.menu_book_rounded),
                            label: const Text('查看全部作业'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 22),
                _AccountPanel(
                  currentUserEmail: currentUserEmail,
                  summary: summary,
                ),
              ],
            ),
    );
  }
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel({
    required this.currentUserEmail,
    required this.summary,
    this.isCompact = false,
  });

  final String? currentUserEmail;
  final PortalSummary summary;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isCompact ? double.infinity : 220,
      height: isCompact ? null : 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '我的账号',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            currentUserEmail ?? '还没有绑定账号信息',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.94),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: isCompact ? 18 : 0),
          if (!isCompact) const Spacer(),
          _MiniMetric(label: '本周已完成', value: '${summary.completedActivities}'),
          const SizedBox(height: 12),
          _MiniMetric(
            label: '进行中的作业',
            value: '${summary.inProgressActivities}',
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
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
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.summary,
    required this.activityId,
    this.isCompact = false,
  });

  final PortalSummary summary;
  final String activityId;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: isCompact ? 10 : 12,
      runSpacing: isCompact ? 10 : 12,
      children: [
        _SummaryCard(
          title: '今日任务',
          value: '${summary.totalActivities}',
          subtitle: '去完成今天的作业',
          color: const Color(0xFF65A9FF),
          icon: Icons.menu_book_rounded,
          isCompact: isCompact,
          onTap: () => context.go('/activities'),
        ),
        _SummaryCard(
          title: '已完成',
          value: '${summary.completedActivities}',
          subtitle: '去查看老师反馈',
          color: const Color(0xFF33B28C),
          icon: Icons.verified_rounded,
          isCompact: isCompact,
          onTap: () => context.go('/activities/$activityId'),
        ),
        _SummaryCard(
          title: '进行中',
          value: '${summary.inProgressActivities}',
          subtitle: '继续当前进度',
          color: const Color(0xFFFF9B55),
          icon: Icons.auto_mode_rounded,
          isCompact: isCompact,
          onTap: () => context.go('/activities'),
        ),
        _SummaryCard(
          title: '待完成',
          value: '${summary.pendingTasks}',
          subtitle: '优先完成这些任务',
          color: const Color(0xFF7B8CFF),
          icon: Icons.pending_actions_rounded,
          isCompact: isCompact,
          onTap: () => context.go('/activities'),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
    this.isCompact = false,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final width = isCompact ? 164.0 : 200.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: width,
        padding: EdgeInsets.all(isCompact ? 14 : 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: isCompact ? 42 : 48,
              height: isCompact ? 42 : 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: isCompact ? 22 : 24),
            ),
            SizedBox(width: isCompact ? 12 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            title: '今日任务',
            subtitle: '去继续完成今天的学习安排',
            accent: const Color(0xFF73B7FF),
            icon: Icons.fact_check_rounded,
            onTap: () => context.go('/activities'),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _QuickActionCard(
            title: '查看反馈',
            subtitle: '完成作业后回来看老师的点评',
            accent: const Color(0xFFFF8F4D),
            icon: Icons.rate_review_rounded,
            onTap: () => context.go('/activities/$activityId'),
          ),
        ),
      ],
    );
  }
}

class _QuickActionsColumn extends StatelessWidget {
  const _QuickActionsColumn({required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _QuickActionCard(
          title: '今日任务',
          subtitle: '去继续完成今天的学习安排',
          accent: const Color(0xFF73B7FF),
          icon: Icons.fact_check_rounded,
          onTap: () => context.go('/activities'),
        ),
        const SizedBox(height: 12),
        _QuickActionCard(
          title: '查看反馈',
          subtitle: '完成作业后回来看老师的点评',
          accent: const Color(0xFFFF8F4D),
          icon: Icons.rate_review_rounded,
          onTap: () => context.go('/activities/$activityId'),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
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
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
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
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({required this.summary, this.isCompact = false});

  final PortalSummary summary;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '老师反馈',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _FeedbackLine(
            icon: Icons.mark_chat_unread_rounded,
            title: '先完成今天的作业',
            subtitle: '还有 ${summary.pendingTasks} 项小任务等你完成。',
          ),
          const SizedBox(height: 12),
          _FeedbackLine(
            icon: Icons.workspace_premium_rounded,
            title: '完成后回来查看反馈',
            subtitle: '本周已经完成 ${summary.completedActivities} 项作业。',
          ),
        ],
      ),
    );
  }
}

class _FeedbackLine extends StatelessWidget {
  const _FeedbackLine({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF2E4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: const Color(0xFFFF8F4D)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SchoolPanel extends StatelessWidget {
  const _SchoolPanel({required this.schoolContext, this.isCompact = false});

  final SchoolContext schoolContext;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '我的学校',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            schoolContext.displayName,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: schoolContext.primaryColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            schoolContext.welcomeMessage,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '先完成老师布置的作业，更多拓展内容会在后续逐步开放。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _studentDisplayName(String? email) {
  if (email == null || email.trim().isEmpty) {
    return '小同学';
  }
  final local = email.split('@').first.trim();
  if (local.isEmpty) {
    return '小同学';
  }
  if (local.length <= 6) {
    return local;
  }
  return '${local.substring(0, 6)}同学';
}
