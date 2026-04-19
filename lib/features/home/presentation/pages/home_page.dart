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
            final isWide = constraints.maxWidth >= 1160;
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
      actions: const [
        _ActionPill(icon: Icons.notifications_active_rounded, label: '提醒'),
        SizedBox(width: 12),
        _ActionPill(icon: Icons.account_circle_rounded, label: '我的'),
      ],
      child: child,
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
              _SummaryGrid(summary: summary),
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
        _SummaryGrid(summary: summary),
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schoolContext.welcomeTitle,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
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
                      onPressed: () =>
                          context.go('/activities/$highlightedActivityId'),
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      label: const Text('开始学习'),
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
          Container(
            width: 220,
            height: 240,
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
                const Spacer(),
                _MiniMetric(
                  label: '本周已完成',
                  value: '${summary.completedActivities}',
                ),
                const SizedBox(height: 12),
                _MiniMetric(
                  label: '进行中的作业',
                  value: '${summary.inProgressActivities}',
                ),
              ],
            ),
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
  const _SummaryGrid({required this.summary});

  final PortalSummary summary;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.38,
      children: [
        _SummaryCard(
          title: '今日任务',
          value: '${summary.totalActivities}',
          subtitle: '老师已布置的作业',
          color: const Color(0xFF65A9FF),
          icon: Icons.menu_book_rounded,
        ),
        _SummaryCard(
          title: '已完成',
          value: '${summary.completedActivities}',
          subtitle: '可以去查看老师反馈',
          color: const Color(0xFF33B28C),
          icon: Icons.verified_rounded,
        ),
        _SummaryCard(
          title: '进行中',
          value: '${summary.inProgressActivities}',
          subtitle: '还可以继续学习',
          color: const Color(0xFFFF9B55),
          icon: Icons.auto_mode_rounded,
        ),
        _SummaryCard(
          title: '待完成',
          value: '${summary.pendingTasks}',
          subtitle: '优先完成这些小任务',
          color: const Color(0xFF8B5CF6),
          icon: Icons.pending_actions_rounded,
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
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
            title: '老师反馈',
            subtitle: '完成后可以在这里看点评',
            accent: const Color(0xFF8B5CF6),
            icon: Icons.rate_review_rounded,
            onTap: () => context.go('/activities/$activityId'),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _QuickActionCard(
            title: '我的练习',
            subtitle: '去看看还可以学习什么内容',
            accent: const Color(0xFF31B08D),
            icon: Icons.explore_rounded,
            onTap: () => context.go('/explore'),
          ),
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
  const _FeedbackPanel({required this.summary});

  final PortalSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
            title: '优先完成待处理任务',
            subtitle: '还有 ${summary.pendingTasks} 项小任务等你完成。',
          ),
          const SizedBox(height: 12),
          _FeedbackLine(
            icon: Icons.workspace_premium_rounded,
            title: '已完成的作业可以查看点评',
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
            color: const Color(0xFFE8F0FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: const Color(0xFF2F67F6)),
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
  const _SchoolPanel({required this.schoolContext});

  final SchoolContext schoolContext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
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
