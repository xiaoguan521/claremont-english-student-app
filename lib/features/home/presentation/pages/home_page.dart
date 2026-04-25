import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../portal/data/portal_models.dart';
import '../../../portal/presentation/providers/portal_providers.dart';
import '../../../portal/presentation/providers/parent_contact_providers.dart';
import '../../../portal/presentation/providers/practice_session_providers.dart';
import '../../../portal/presentation/providers/student_feature_flags_provider.dart';
import '../../../portal/presentation/widgets/tablet_shell.dart';
import '../../../school/presentation/providers/school_context_provider.dart';
import '../widgets/k12_dashboard_widgets.dart';
import '../widgets/k12_playful_widgets.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightedActivityAsync = ref.watch(highlightedActivityProvider);
    final summaryAsync = ref.watch(portalSummaryProvider);
    final dailyGrowthAsync = ref.watch(dailyGrowthSummaryProvider);
    final schoolContextAsync = ref.watch(schoolContextProvider);
    final currentUserEmail = ref.watch(currentUserEmailProvider);
    final featureFlags = ref.watch(studentFeatureFlagsProvider);

    final schoolContext =
        schoolContextAsync.valueOrNull ?? SchoolContext.fallback();

    Widget child;
    List<Widget>? shellActions;
    if (highlightedActivityAsync.isLoading ||
        summaryAsync.isLoading ||
        dailyGrowthAsync.isLoading) {
      child = const Center(child: CircularProgressIndicator());
    } else if (highlightedActivityAsync.hasError ||
        summaryAsync.hasError ||
        dailyGrowthAsync.hasError) {
      child = const _StateMessage(
        title: '学习任务暂时没有同步成功',
        message: '请检查网络或稍后再试。',
      );
    } else {
      final highlightedActivity = highlightedActivityAsync.valueOrNull;
      final summary = summaryAsync.valueOrNull;
      final dailyGrowth = dailyGrowthAsync.valueOrNull;

      if (highlightedActivity == null ||
          summary == null ||
          dailyGrowth == null) {
        child = const _StateMessage(
          title: '今天还没有新任务',
          message: '老师发布作业后，这里会第一时间提醒你。',
        );
      } else {
        final parentSummaryAsync = ref.watch(
          parentContactSummaryProvider(highlightedActivity.id),
        );
        final practiceSession = ref.watch(
          practiceSessionProvider(highlightedActivity.id),
        );
        final parentSummary = parentSummaryAsync.valueOrNull;
        final dailyStars = _dailyStarCoins(summary, dailyGrowth, parentSummary);
        final dailyCombo = dailyGrowth.bestCombo;
        final resumeSummary = _homeResumeSummary(
          highlightedActivity,
          practiceSession,
        );
        shellActions = featureFlags.showGrowthRewards
            ? [
                K12StatusBadge(
                  icon: Icons.local_fire_department_rounded,
                  label: dailyCombo > 0 ? '今日连对 $dailyCombo' : '准备闯关',
                  color: const Color(0xFFFFE36B),
                  foregroundColor: const Color(0xFF8A4F00),
                ),
                K12StatusBadge(
                  icon: Icons.workspace_premium_rounded,
                  label: '$dailyStars 星币',
                  color: const Color(0xFF9AF07A),
                  foregroundColor: const Color(0xFF155B2D),
                ),
              ]
            : null;
        child = LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 800;
            final isWide = constraints.maxWidth >= 1160;
            final isLandscapePhone =
                constraints.maxWidth > constraints.maxHeight && !isTablet;
            final content = isWide
                ? _WideHomeLayout(
                    schoolContext: schoolContext,
                    currentUserEmail: currentUserEmail,
                    highlightedActivityId: highlightedActivity.id,
                    highlightedActivityTitle: highlightedActivity.title,
                    highlightedClassName: highlightedActivity.className,
                    highlightedDateLabel: highlightedActivity.dateLabel,
                    summary: summary,
                    dailyGrowth: dailyGrowth,
                    parentSummary: parentSummary,
                    resumeSummary: resumeSummary,
                    featureFlags: featureFlags,
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
                    dailyGrowth: dailyGrowth,
                    parentSummary: parentSummary,
                    resumeSummary: resumeSummary,
                    featureFlags: featureFlags,
                    maxWidth: constraints.maxWidth,
                    maxHeight: constraints.maxHeight,
                  )
                : !isTablet
                ? _PhoneHomeLayout(
                    schoolContext: schoolContext,
                    currentUserEmail: currentUserEmail,
                    highlightedActivityId: highlightedActivity.id,
                    highlightedActivityTitle: highlightedActivity.title,
                    highlightedClassName: highlightedActivity.className,
                    highlightedDateLabel: highlightedActivity.dateLabel,
                    summary: summary,
                    dailyGrowth: dailyGrowth,
                    parentSummary: parentSummary,
                    resumeSummary: resumeSummary,
                    featureFlags: featureFlags,
                  )
                : _CompactHomeLayout(
                    schoolContext: schoolContext,
                    currentUserEmail: currentUserEmail,
                    highlightedActivityId: highlightedActivity.id,
                    highlightedActivityTitle: highlightedActivity.title,
                    highlightedClassName: highlightedActivity.className,
                    highlightedDateLabel: highlightedActivity.dateLabel,
                    summary: summary,
                    dailyGrowth: dailyGrowth,
                    parentSummary: parentSummary,
                    resumeSummary: resumeSummary,
                    featureFlags: featureFlags,
                  );

            if (isLandscapePhone) {
              return content;
            }

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
      brandLogoUrl: schoolContext.logoUrl,
      brandSubtitle: '学校学习入口',
      title: 'English Home',
      subtitle: schoolContext.welcomeMessage,
      actions: shellActions,
      theme: TabletShellTheme.k12Sky,
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

class _EntranceMotion extends StatefulWidget {
  const _EntranceMotion({
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.08),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<_EntranceMotion> createState() => _EntranceMotionState();
}

class _EntranceMotionState extends State<_EntranceMotion> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (!mounted) return;
      setState(() {
        _visible = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : widget.offset,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: _visible ? 1 : 0.96,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
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
    required this.dailyGrowth,
    required this.parentSummary,
    required this.resumeSummary,
    required this.featureFlags,
    required this.maxWidth,
    required this.maxHeight,
  });

  final SchoolContext schoolContext;
  final String? currentUserEmail;
  final String highlightedActivityId;
  final String highlightedActivityTitle;
  final String highlightedClassName;
  final String highlightedDateLabel;
  final PortalSummary summary;
  final DailyGrowthSummary dailyGrowth;
  final ParentContactSummary? parentSummary;
  final _HomeResumeSummary resumeSummary;
  final StudentFeatureFlags featureFlags;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final visualScale = _landscapePhoneVisualScale(maxWidth, maxHeight);
    final textScale = (MediaQuery.textScalerOf(context).scale(1) * visualScale)
        .clamp(0.82, 1.0);
    final displayName = _studentDisplayName(currentUserEmail);
    final isTabletLandscape = maxWidth >= 800;
    final gap = (maxWidth * (isTabletLandscape ? 0.016 : 0.02))
        .clamp(10.0, 16.0)
        .toDouble();
    final sideWidth = (maxWidth * (isTabletLandscape ? 0.32 : 0.54))
        .clamp(236.0, 360.0)
        .toDouble();
    final boardWidth = (maxWidth * (isTabletLandscape ? 0.54 : 0.72))
        .clamp(320.0, 620.0)
        .toDouble();
    final railWidth = (maxWidth * (isTabletLandscape ? 0.3 : 0.5))
        .clamp(220.0, 340.0)
        .toDouble();
    final boardHeight = (maxHeight * (isTabletLandscape ? 0.8 : 0.86))
        .clamp(320.0, 460.0)
        .toDouble();

    final content = MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: K12PlayfulDashboardFrame(
        padding: EdgeInsets.all(18 * visualScale),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _EntranceMotion(
                delay: const Duration(milliseconds: 40),
                child: _FeatureTopBar(
                  showFunZonePromos: featureFlags.showFunZonePromos,
                  isCompact: !isTabletLandscape,
                  visualScale: visualScale,
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
              ),
              SizedBox(height: 12 * visualScale),
              SizedBox(
                height: boardHeight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: sideWidth,
                        child: _EntranceMotion(
                          delay: const Duration(milliseconds: 120),
                          offset: const Offset(-0.06, 0),
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
                              SizedBox(height: gap),
                              Expanded(
                                flex: 2,
                                child: _LandscapeShortcutPanel(
                                  highlightedActivityId: highlightedActivityId,
                                  featureFlags: featureFlags,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: gap),
                      SizedBox(
                        width: boardWidth,
                        child: _EntranceMotion(
                          delay: const Duration(milliseconds: 180),
                          child: _LandscapeTaskBoard(
                            schoolContext: schoolContext,
                            highlightedActivityId: highlightedActivityId,
                            highlightedActivityTitle: highlightedActivityTitle,
                            highlightedClassName: highlightedClassName,
                            highlightedDateLabel: highlightedDateLabel,
                            summary: summary,
                            dailyGrowth: dailyGrowth,
                            parentSummary: parentSummary,
                            resumeSummary: resumeSummary,
                            featureFlags: featureFlags,
                          ),
                        ),
                      ),
                      SizedBox(width: gap),
                      SizedBox(
                        width: railWidth,
                        child: _EntranceMotion(
                          delay: const Duration(milliseconds: 240),
                          offset: const Offset(0.06, 0),
                          child: _LandscapeReadingRail(
                            schoolContext: schoolContext,
                            highlightedActivityId: highlightedActivityId,
                            summary: summary,
                            dailyGrowth: dailyGrowth,
                            parentSummary: parentSummary,
                            featureFlags: featureFlags,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return content;
  }
}

class _FeatureTopBar extends StatelessWidget {
  const _FeatureTopBar({
    required this.onOpenFeature,
    this.showFunZonePromos = true,
    this.isCompact = false,
    this.visualScale = 1,
  });

  final void Function(
    String title,
    String description,
    Color accent,
    IconData icon,
  )
  onOpenFeature;
  final bool showFunZonePromos;
  final bool isCompact;
  final double visualScale;

  @override
  Widget build(BuildContext context) {
    if (!showFunZonePromos) {
      return const SizedBox.shrink();
    }
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final useWrap = constraints.maxWidth >= 800;
        final spacing = (isCompact ? 8 : 10) * visualScale;
        final bubbles = items
            .map(
              (item) => _FeatureBubble(
                title: item.$1,
                accent: item.$3,
                icon: item.$4,
                compact: isCompact,
                visualScale: visualScale,
                onTap: () => onOpenFeature(item.$1, item.$2, item.$3, item.$4),
              ),
            )
            .toList();

        return Align(
          alignment: useWrap ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: useWrap ? null : double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: (isCompact ? 10 : 16) * visualScale,
              vertical: (isCompact ? 8 : 10) * visualScale,
            ),
            decoration: k12PlasticPanelDecoration(
              accent: const Color(0xFF6AC5FF),
              radius: 26,
              fillColor: Colors.white.withValues(alpha: 0.82),
            ),
            child: useWrap
                ? Wrap(
                    alignment: WrapAlignment.end,
                    spacing: spacing,
                    runSpacing: spacing,
                    children: bubbles,
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < bubbles.length; i++) ...[
                          if (i > 0) SizedBox(width: spacing),
                          bubbles[i],
                        ],
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _FeatureBubble extends StatelessWidget {
  const _FeatureBubble({
    required this.title,
    required this.accent,
    required this.icon,
    required this.onTap,
    this.compact = false,
    this.visualScale = 1,
  });

  final String title;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;
  final double visualScale;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: (compact ? 82 : 94) * visualScale,
        padding: EdgeInsets.symmetric(
          horizontal: (compact ? 6 : 8) * visualScale,
          vertical: (compact ? 8 : 10) * visualScale,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.92),
              accent.withValues(alpha: 0.72),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: (compact ? 36 : 42) * visualScale,
              height: (compact ? 36 : 42) * visualScale,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: (compact ? 18 : 22) * visualScale,
              ),
            ),
            SizedBox(height: (compact ? 6 : 8) * visualScale),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF334155),
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(
                    color: Color(0x55FFFFFF),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
                fontSize: compact ? 11 * visualScale : null,
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
    required this.dailyGrowth,
    required this.parentSummary,
    required this.resumeSummary,
    required this.featureFlags,
  });

  final SchoolContext schoolContext;
  final String? currentUserEmail;
  final String highlightedActivityId;
  final String highlightedActivityTitle;
  final String highlightedClassName;
  final String highlightedDateLabel;
  final PortalSummary summary;
  final DailyGrowthSummary dailyGrowth;
  final ParentContactSummary? parentSummary;
  final _HomeResumeSummary resumeSummary;
  final StudentFeatureFlags featureFlags;

  @override
  Widget build(BuildContext context) {
    return K12PlayfulDashboardFrame(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _EntranceMotion(
            delay: const Duration(milliseconds: 40),
            child: _HeroCard(
              schoolContext: schoolContext,
              currentUserEmail: currentUserEmail,
              highlightedActivityId: highlightedActivityId,
              highlightedActivityTitle: highlightedActivityTitle,
              highlightedClassName: highlightedClassName,
              highlightedDateLabel: highlightedDateLabel,
              summary: summary,
              dailyGrowth: dailyGrowth,
              parentSummary: parentSummary,
              resumeSummary: resumeSummary,
              featureFlags: featureFlags,
              isCompact: true,
            ),
          ),
          const SizedBox(height: 16),
          _EntranceMotion(
            delay: const Duration(milliseconds: 120),
            child: _SummaryGrid(
              summary: summary,
              dailyGrowth: dailyGrowth,
              activityId: highlightedActivityId,
              parentSummary: parentSummary,
              featureFlags: featureFlags,
              isCompact: true,
            ),
          ),
          const SizedBox(height: 16),
          _EntranceMotion(
            delay: const Duration(milliseconds: 180),
            child: _QuickActionsColumn(activityId: highlightedActivityId),
          ),
          const SizedBox(height: 16),
          _EntranceMotion(
            delay: const Duration(milliseconds: 240),
            child: _FeedbackPanel(summary: summary, isCompact: true),
          ),
          const SizedBox(height: 16),
          _EntranceMotion(
            delay: const Duration(milliseconds: 300),
            child: _SchoolPanel(schoolContext: schoolContext, isCompact: true),
          ),
        ],
      ),
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
      decoration: k12PlasticPanelDecoration(accent: const Color(0xFF6AC5FF)),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
  const _LandscapeShortcutPanel({
    required this.highlightedActivityId,
    required this.featureFlags,
  });

  final String highlightedActivityId;
  final StudentFeatureFlags featureFlags;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxHeight < 150 ? 4 : 2;
        final childAspectRatio = crossAxisCount == 4
            ? (constraints.maxWidth / constraints.maxHeight) * 1.1
            : (constraints.maxWidth / constraints.maxHeight) * 1.55;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: k12PlasticPanelDecoration(
            accent: const Color(0xFFFFC941),
          ),
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
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
                icon: featureFlags.showFunZonePromos
                    ? Icons.stars_rounded
                    : Icons.fact_check_rounded,
                label: featureFlags.showFunZonePromos ? '更多' : '任务',
                accent: const Color(0xFFF3C14B),
                onTap: () => context.go(
                  featureFlags.showFunZonePromos ? '/explore' : '/activities',
                ),
              ),
            ],
          ),
        );
      },
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
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w800,
                  ),
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
    required this.dailyGrowth,
    required this.parentSummary,
    required this.resumeSummary,
    required this.featureFlags,
  });

  final SchoolContext schoolContext;
  final String highlightedActivityId;
  final String highlightedActivityTitle;
  final String highlightedClassName;
  final String highlightedDateLabel;
  final PortalSummary summary;
  final DailyGrowthSummary dailyGrowth;
  final ParentContactSummary? parentSummary;
  final _HomeResumeSummary resumeSummary;
  final StudentFeatureFlags featureFlags;

  @override
  Widget build(BuildContext context) {
    final completedTasks = dailyGrowth.completedTasks;
    final primaryActionLabel = resumeSummary.resumeTaskIndex == null
        ? '开始今日任务'
        : '继续第 ${resumeSummary.resumeTaskIndex} 句';
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrowBoard = constraints.maxWidth < 560;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: k12PlasticPanelDecoration(
            accent: const Color(0xFF6AC5FF),
            radius: 34,
          ),
          child: isNarrowBoard
              ? Column(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _LandscapePrimaryTaskCard(
                        schoolContext: schoolContext,
                        highlightedActivityId: highlightedActivityId,
                        highlightedActivityTitle: highlightedActivityTitle,
                        highlightedClassName: highlightedClassName,
                        highlightedDateLabel: highlightedDateLabel,
                        primaryActionLabel: primaryActionLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 5,
                      child: Column(
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
                          const SizedBox(height: 12),
                          Expanded(
                            child: _LandscapeFeatureCard(
                              title: '点评中心',
                              subtitle: '完成作业后回来查看点评',
                              value: '${summary.completedActivities}',
                              accent: const Color(0xFFFF8F4D),
                              icon: Icons.rate_review_rounded,
                              onTap: () => context.go(
                                '/activities/$highlightedActivityId',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _LandscapeFeatureCard(
                              title: '任务中心',
                              subtitle: resumeSummary.resumeTaskIndex != null
                                  ? '从第 ${resumeSummary.resumeTaskIndex} 句继续今天的学习'
                                  : '还有这些内容等你完成',
                              value: completedTasks > 0
                                  ? '$completedTasks 句'
                                  : '${summary.pendingTasks}',
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
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _LandscapePrimaryTaskCard(
                        schoolContext: schoolContext,
                        highlightedActivityId: highlightedActivityId,
                        highlightedActivityTitle: highlightedActivityTitle,
                        highlightedClassName: highlightedClassName,
                        highlightedDateLabel: highlightedDateLabel,
                        primaryActionLabel: primaryActionLabel,
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
                                    onTap: () => context.go(
                                      '/activities/$highlightedActivityId',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _LandscapeFeatureCard(
                              title: '任务中心',
                              subtitle: resumeSummary.resumeTaskIndex != null
                                  ? '从第 ${resumeSummary.resumeTaskIndex} 句继续今天的学习'
                                  : '还有这些内容等你完成',
                              value: completedTasks > 0
                                  ? '$completedTasks 句'
                                  : '${summary.pendingTasks}',
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
      },
    );
  }
}

class _LandscapePrimaryTaskCard extends StatelessWidget {
  const _LandscapePrimaryTaskCard({
    required this.schoolContext,
    required this.highlightedActivityId,
    required this.highlightedActivityTitle,
    required this.highlightedClassName,
    required this.highlightedDateLabel,
    required this.primaryActionLabel,
  });

  final SchoolContext schoolContext;
  final String highlightedActivityId;
  final String highlightedActivityTitle;
  final String highlightedClassName;
  final String highlightedDateLabel;
  final String primaryActionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
            onPressed: () => context.go('/activities/$highlightedActivityId'),
            child: Text(primaryActionLabel),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: const Color(0xFF1E293B),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF1E293B),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
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
    required this.dailyGrowth,
    required this.parentSummary,
    required this.featureFlags,
  });

  final SchoolContext schoolContext;
  final String highlightedActivityId;
  final PortalSummary summary;
  final DailyGrowthSummary dailyGrowth;
  final ParentContactSummary? parentSummary;
  final StudentFeatureFlags featureFlags;

  @override
  Widget build(BuildContext context) {
    final completedTasks = dailyGrowth.completedTasks;
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
          decoration: k12PlasticPanelDecoration(
            accent: const Color(0xFFFFC941),
            radius: 26,
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
                  completedTasks > 0
                      ? featureFlags.showGrowthRewards
                            ? '今天已经完成 $completedTasks 句练习，继续保持。'
                            : '今天已经完成 $completedTasks 句练习，继续巩固。'
                      : '今天还有 ${summary.pendingTasks} 项任务等你完成。',
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
      color: Colors.white.withValues(alpha: 0.92),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
    required this.dailyGrowth,
    required this.parentSummary,
    required this.resumeSummary,
    required this.featureFlags,
  });

  final SchoolContext schoolContext;
  final String? currentUserEmail;
  final String highlightedActivityId;
  final String highlightedActivityTitle;
  final String highlightedClassName;
  final String highlightedDateLabel;
  final PortalSummary summary;
  final DailyGrowthSummary dailyGrowth;
  final ParentContactSummary? parentSummary;
  final _HomeResumeSummary resumeSummary;
  final StudentFeatureFlags featureFlags;

  @override
  Widget build(BuildContext context) {
    return K12PlayfulDashboardFrame(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _EntranceMotion(
                  delay: const Duration(milliseconds: 40),
                  child: _HeroCard(
                    schoolContext: schoolContext,
                    currentUserEmail: currentUserEmail,
                    highlightedActivityId: highlightedActivityId,
                    highlightedActivityTitle: highlightedActivityTitle,
                    highlightedClassName: highlightedClassName,
                    highlightedDateLabel: highlightedDateLabel,
                    summary: summary,
                    dailyGrowth: dailyGrowth,
                    parentSummary: parentSummary,
                    resumeSummary: resumeSummary,
                    featureFlags: featureFlags,
                  ),
                ),
                const SizedBox(height: 18),
                _EntranceMotion(
                  delay: const Duration(milliseconds: 120),
                  child: _QuickActionsRow(activityId: highlightedActivityId),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            flex: 5,
            child: Column(
              children: [
                _EntranceMotion(
                  delay: const Duration(milliseconds: 180),
                  child: _SummaryGrid(
                    summary: summary,
                    dailyGrowth: dailyGrowth,
                    activityId: highlightedActivityId,
                    parentSummary: parentSummary,
                    featureFlags: featureFlags,
                  ),
                ),
                const SizedBox(height: 18),
                _EntranceMotion(
                  delay: const Duration(milliseconds: 240),
                  child: _FeedbackPanel(summary: summary),
                ),
                const SizedBox(height: 18),
                _EntranceMotion(
                  delay: const Duration(milliseconds: 300),
                  child: _SchoolPanel(schoolContext: schoolContext),
                ),
              ],
            ),
          ),
        ],
      ),
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
    required this.dailyGrowth,
    required this.parentSummary,
    required this.resumeSummary,
    required this.featureFlags,
  });

  final SchoolContext schoolContext;
  final String? currentUserEmail;
  final String highlightedActivityId;
  final String highlightedActivityTitle;
  final String highlightedClassName;
  final String highlightedDateLabel;
  final PortalSummary summary;
  final DailyGrowthSummary dailyGrowth;
  final ParentContactSummary? parentSummary;
  final _HomeResumeSummary resumeSummary;
  final StudentFeatureFlags featureFlags;

  @override
  Widget build(BuildContext context) {
    return K12PlayfulDashboardFrame(
      child: Column(
        children: [
          _EntranceMotion(
            delay: const Duration(milliseconds: 40),
            child: _HeroCard(
              schoolContext: schoolContext,
              currentUserEmail: currentUserEmail,
              highlightedActivityId: highlightedActivityId,
              highlightedActivityTitle: highlightedActivityTitle,
              highlightedClassName: highlightedClassName,
              highlightedDateLabel: highlightedDateLabel,
              summary: summary,
              dailyGrowth: dailyGrowth,
              parentSummary: parentSummary,
              resumeSummary: resumeSummary,
              featureFlags: featureFlags,
            ),
          ),
          const SizedBox(height: 18),
          _EntranceMotion(
            delay: const Duration(milliseconds: 120),
            child: _SummaryGrid(
              summary: summary,
              dailyGrowth: dailyGrowth,
              activityId: highlightedActivityId,
              parentSummary: parentSummary,
              featureFlags: featureFlags,
            ),
          ),
          const SizedBox(height: 18),
          _EntranceMotion(
            delay: const Duration(milliseconds: 180),
            child: _QuickActionsRow(activityId: highlightedActivityId),
          ),
          const SizedBox(height: 18),
          _EntranceMotion(
            delay: const Duration(milliseconds: 240),
            child: _FeedbackPanel(summary: summary),
          ),
          const SizedBox(height: 18),
          _EntranceMotion(
            delay: const Duration(milliseconds: 300),
            child: _SchoolPanel(schoolContext: schoolContext),
          ),
        ],
      ),
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
    required this.dailyGrowth,
    required this.parentSummary,
    required this.resumeSummary,
    required this.featureFlags,
    this.isCompact = false,
  });

  final SchoolContext schoolContext;
  final String? currentUserEmail;
  final String highlightedActivityId;
  final String highlightedActivityTitle;
  final String highlightedClassName;
  final String highlightedDateLabel;
  final PortalSummary summary;
  final DailyGrowthSummary dailyGrowth;
  final ParentContactSummary? parentSummary;
  final _HomeResumeSummary resumeSummary;
  final StudentFeatureFlags featureFlags;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final displayName = _studentDisplayName(currentUserEmail);
    final dailyStars = _dailyStarCoins(summary, dailyGrowth, parentSummary);
    final comboCount = dailyGrowth.bestCombo;
    final completedPracticeTasks = dailyGrowth.completedTasks;
    final showGrowthRewards = featureFlags.showGrowthRewards;
    final resumeText = resumeSummary.resumeTaskIndex == null
        ? null
        : '上次做到第 ${resumeSummary.resumeTaskIndex} 句，回来继续闯关吧。';
    final heroScene = SizedBox(
      width: isCompact ? double.infinity : 180,
      height: isCompact ? 164 : 180,
      child: const K12CartoonHeroScene(),
    );
    final schedulePanel = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const K12PlayToken(
                icon: Icons.calendar_month_rounded,
                label: "Today's Schedule",
                color: Color(0xFFFFE36B),
                foregroundColor: Color(0xFF7A4A00),
              ),
              if (showGrowthRewards)
                K12PlayToken(
                  icon: Icons.stars_rounded,
                  label: '$dailyStars 星币',
                  color: const Color(0xFFFFC941),
                  foregroundColor: const Color(0xFF7A4A00),
                ),
            ],
          ),
          const SizedBox(height: 14),
          K12HeroScheduleLine(
            icon: Icons.auto_stories_rounded,
            accent: const Color(0xFFFFD44E),
            title: '主线任务',
            content: highlightedActivityTitle,
          ),
          const SizedBox(height: 10),
          K12HeroScheduleLine(
            icon: Icons.groups_rounded,
            accent: const Color(0xFF74E55D),
            title: '班级课堂',
            content: '$highlightedClassName · $highlightedDateLabel',
          ),
          const SizedBox(height: 10),
          K12HeroScheduleLine(
            icon: Icons.emoji_events_rounded,
            accent: const Color(0xFF80DEFF),
            title: '成长目标',
            content:
                resumeText ??
                (completedPracticeTasks > 0
                    ? '今天已经完成 $completedPracticeTasks 句练习，继续冲刺新的英语徽章。'
                    : showGrowthRewards
                    ? '今天先完成主线任务，解锁新的英语徽章。'
                    : '今天先完成主线任务，继续巩固今天的英语学习内容。'),
          ),
        ],
      ),
    );

    final headline = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $displayName',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFFFFF5C4),
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'English Adventure Dashboard',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          resumeText != null
              ? '你已经把上次的进度找回来了，继续完成 $highlightedActivityTitle。'
              : showGrowthRewards && comboCount > 0
              ? '你刚刚已经连对 $comboCount 题啦，继续完成 $highlightedActivityTitle。'
              : showGrowthRewards
              ? '卡通化课程表、星币激励和成长徽章都准备好了，今天先完成 $highlightedActivityTitle。'
              : '今天的主线任务已经准备好了，先完成 $highlightedActivityTitle。',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.94),
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFE36B),
            foregroundColor: const Color(0xFF195AB6),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          onPressed: () => context.go('/activities/$highlightedActivityId'),
          icon: const Icon(Icons.play_circle_fill_rounded),
          label: Text(
            resumeSummary.resumeTaskIndex == null
                ? '开始今日作业'
                : '继续第 ${resumeSummary.resumeTaskIndex} 句',
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.72),
              width: 1.8,
            ),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          onPressed: () => context.go('/activities'),
          icon: const Icon(Icons.menu_book_rounded),
          label: const Text('查看全部作业'),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5DB9FF), Color(0xFF2D8DFF), Color(0xFF69D5FF)],
        ),
        borderRadius: BorderRadius.circular(38),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.34),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D8DFF).withValues(alpha: 0.26),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -12,
            right: -8,
            child: K12DecorBubble(
              diameter: 110,
              colors: [Color(0xFFFFE36E), Color(0xFFFFBB3E)],
            ),
          ),
          Positioned(
            right: 28,
            top: 72,
            child: Transform.rotate(
              angle: -0.18,
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
          ),
          if (isCompact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headline,
                const SizedBox(height: 16),
                heroScene,
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    K12HeroBadge(
                      icon: Icons.school_rounded,
                      label: schoolContext.welcomeTitle,
                    ),
                    K12HeroBadge(
                      icon: Icons.groups_rounded,
                      label: highlightedClassName,
                    ),
                    K12HeroBadge(
                      icon: Icons.workspace_premium_rounded,
                      label: '${summary.completedActivities} 枚成就徽章',
                    ),
                    if (showGrowthRewards && comboCount > 0)
                      K12HeroBadge(
                        icon: Icons.local_fire_department_rounded,
                        label: '连对 $comboCount',
                      ),
                    if (resumeSummary.resumeTaskIndex != null)
                      K12HeroBadge(
                        icon: Icons.play_circle_rounded,
                        label: '继续第 ${resumeSummary.resumeTaskIndex} 句',
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                schedulePanel,
                const SizedBox(height: 18),
                actions,
                const SizedBox(height: 14),
                _AccountPanel(
                  currentUserEmail: currentUserEmail,
                  summary: summary,
                  dailyGrowth: dailyGrowth,
                  parentSummary: parentSummary,
                  featureFlags: featureFlags,
                  isCompact: true,
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: headline),
                          const SizedBox(width: 18),
                          heroScene,
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          K12HeroBadge(
                            icon: Icons.school_rounded,
                            label: schoolContext.welcomeTitle,
                          ),
                          K12HeroBadge(
                            icon: Icons.groups_rounded,
                            label: highlightedClassName,
                          ),
                          K12HeroBadge(
                            icon: Icons.calendar_today_rounded,
                            label: highlightedDateLabel,
                          ),
                          K12HeroBadge(
                            icon: Icons.workspace_premium_rounded,
                            label: '${summary.completedActivities} 枚成就徽章',
                          ),
                          if (showGrowthRewards && comboCount > 0)
                            K12HeroBadge(
                              icon: Icons.local_fire_department_rounded,
                              label: '连对 $comboCount',
                            ),
                          if (resumeSummary.resumeTaskIndex != null)
                            K12HeroBadge(
                              icon: Icons.play_circle_rounded,
                              label: '继续第 ${resumeSummary.resumeTaskIndex} 句',
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      schedulePanel,
                      const SizedBox(height: 18),
                      actions,
                    ],
                  ),
                ),
                const SizedBox(width: 22),
                _AccountPanel(
                  currentUserEmail: currentUserEmail,
                  summary: summary,
                  dailyGrowth: dailyGrowth,
                  parentSummary: parentSummary,
                  featureFlags: featureFlags,
                ),
              ],
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
    required this.dailyGrowth,
    required this.parentSummary,
    required this.featureFlags,
    this.isCompact = false,
  });

  final String? currentUserEmail;
  final PortalSummary summary;
  final DailyGrowthSummary dailyGrowth;
  final ParentContactSummary? parentSummary;
  final StudentFeatureFlags featureFlags;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final displayName = _studentDisplayName(currentUserEmail);
    final starCoins = _dailyStarCoins(summary, dailyGrowth, parentSummary);
    final comboCount = dailyGrowth.bestCombo;
    return Container(
      width: isCompact ? double.infinity : 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.36),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFEB8A), Color(0xFFFFC243)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: 1.6,
                  ),
                ),
                child: const Icon(
                  Icons.sentiment_very_satisfied_rounded,
                  color: Color(0xFF1760B8),
                  size: 38,
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
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Personal Dashboard',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFF5F8FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currentUserEmail ?? '还没有绑定账号信息',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.94),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (featureFlags.showGrowthRewards)
                K12RewardChip(
                  icon: Icons.stars_rounded,
                  label: '$starCoins 星币',
                  color: const Color(0xFFFFE36B),
                  foregroundColor: const Color(0xFF7A4A00),
                ),
              K12RewardChip(
                icon: Icons.workspace_premium_rounded,
                label: '${summary.completedActivities} 徽章',
                color: const Color(0xFF9CF277),
                foregroundColor: const Color(0xFF135E2A),
              ),
              if (featureFlags.showGrowthRewards && comboCount > 0)
                K12RewardChip(
                  icon: Icons.local_fire_department_rounded,
                  label: '连对 $comboCount',
                  color: const Color(0xFFFFB36B),
                  foregroundColor: const Color(0xFF8A3F00),
                ),
            ],
          ),
          SizedBox(height: isCompact ? 16 : 18),
          if (!isCompact) const SizedBox(height: 6),
          K12MiniMetric(
            label: '本周已完成',
            value: '${summary.completedActivities}',
          ),
          const SizedBox(height: 12),
          K12MiniMetric(
            label: '进行中的作业',
            value: '${summary.inProgressActivities}',
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.summary,
    required this.dailyGrowth,
    required this.activityId,
    required this.parentSummary,
    required this.featureFlags,
    this.isCompact = false,
  });

  final PortalSummary summary;
  final DailyGrowthSummary dailyGrowth;
  final String activityId;
  final ParentContactSummary? parentSummary;
  final StudentFeatureFlags featureFlags;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final dailyStars = _dailyStarCoins(summary, dailyGrowth, parentSummary);
    final comboCount = dailyGrowth.bestCombo;
    final completedTasks = dailyGrowth.completedTasks;
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = isCompact ? 10.0 : 12.0;
        final cardsPerRow = constraints.maxWidth >= 340 ? 2 : 1;
        final itemWidth = cardsPerRow == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing) / cardsPerRow;

        final cards = [
          _SummaryCard(
            title: 'Reading Lab',
            value: '${summary.inProgressActivities} 节',
            subtitle: '课本跟读和朗读训练',
            color: const Color(0xFF5DB9FF),
            icon: Icons.auto_stories_rounded,
            isCompact: isCompact,
            onTap: () => context.go('/activities'),
          ),
          _SummaryCard(
            title: featureFlags.showFunZonePromos
                ? 'Word Quest'
                : 'Homework Hub',
            value: featureFlags.showFunZonePromos
                ? '${summary.totalActivities} 组'
                : '${summary.totalActivities} 份',
            subtitle: featureFlags.showFunZonePromos
                ? '背单词和拼读小游戏'
                : '先完成老师布置的主线任务',
            color: const Color(0xFFFFC941),
            icon: featureFlags.showFunZonePromos
                ? Icons.translate_rounded
                : Icons.fact_check_rounded,
            isCompact: isCompact,
            onTap: () => context.go(
              featureFlags.showFunZonePromos ? '/explore' : '/activities',
            ),
          ),
          _SummaryCard(
            title: 'Speaking Fun',
            value: comboCount > 0
                ? '$comboCount 连对'
                : '${summary.pendingTasks} 项',
            subtitle: '开口练习和配音闯关',
            color: const Color(0xFF78E55A),
            icon: Icons.record_voice_over_rounded,
            isCompact: isCompact,
            onTap: () => context.go('/activities/$activityId'),
          ),
          _SummaryCard(
            title: featureFlags.showGrowthRewards
                ? 'Badge House'
                : 'Task Board',
            value: featureFlags.showGrowthRewards
                ? dailyStars > 0
                      ? '$dailyStars 星币'
                      : '${summary.completedActivities} 枚'
                : completedTasks > 0
                ? '$completedTasks 句'
                : '${summary.pendingTasks} 项',
            subtitle: featureFlags.showGrowthRewards
                ? completedTasks > 0
                      ? '今天已完成 $completedTasks 句练习'
                      : '收集星币和成就徽章'
                : '继续今天的主线任务和句子闯关',
            color: const Color(0xFF55D9C5),
            icon: featureFlags.showGrowthRewards
                ? Icons.workspace_premium_rounded
                : Icons.checklist_rounded,
            isCompact: isCompact,
            onTap: () => context.go('/activities'),
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: itemWidth, child: card))
              .toList(),
        );
      },
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: EdgeInsets.all(isCompact ? 16 : 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.98),
              color.withValues(alpha: 0.82),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.68),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -10,
              right: -4,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: isCompact ? 48 : 54,
                  height: isCompact ? 48 : 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF195AB6),
                    size: isCompact ? 24 : 28,
                  ),
                ),
                SizedBox(width: isCompact ? 12 : 14),
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
                          color: const Color(0xFF114178),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF124D7A),
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF114178),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
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
        decoration: k12PlasticPanelDecoration(accent: accent, radius: 28),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
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
      decoration: k12PlasticPanelDecoration(
        accent: const Color(0xFFFFC941),
        radius: 30,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
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
      decoration: k12PlasticPanelDecoration(
        accent: const Color(0xFF78E55A),
        radius: 30,
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

int _dailyStarCoins(
  PortalSummary summary,
  DailyGrowthSummary dailyGrowth,
  ParentContactSummary? parentSummary,
) {
  final snapshotStars = dailyGrowth.totalStars > 0
      ? dailyGrowth.totalStars
      : (parentSummary?.earnedStars ?? 0);
  if (snapshotStars > 0) {
    return snapshotStars;
  }
  return summary.completedActivities * 12 +
      summary.inProgressActivities * 4 +
      summary.pendingTasks * 2;
}

class _HomeResumeSummary {
  const _HomeResumeSummary({this.resumeTaskIndex});

  final int? resumeTaskIndex;
}

_HomeResumeSummary _homeResumeSummary(
  PortalActivity activity,
  PracticeSessionState session,
) {
  final completedTaskIds = <String>{
    for (final task in activity.tasks)
      if (task.reviewStatus == TaskReviewStatus.checked) task.id,
    for (final entry in session.taskStates.entries)
      if (entry.value.isCompleted) entry.key,
  };
  if (completedTaskIds.length >= activity.tasks.length) {
    return const _HomeResumeSummary();
  }
  final focusedTaskId = session.focusedTaskId;
  if (focusedTaskId == null) {
    return const _HomeResumeSummary();
  }
  final index = activity.tasks.indexWhere((task) => task.id == focusedTaskId);
  if (index < 0) {
    return const _HomeResumeSummary();
  }
  return _HomeResumeSummary(resumeTaskIndex: index + 1);
}

double _landscapePhoneVisualScale(double maxWidth, double maxHeight) {
  final heightScale = (maxHeight / 430).clamp(0.8, 1.0);
  final widthScale = (maxWidth / 920).clamp(0.9, 1.0);
  return (heightScale * widthScale).clamp(0.8, 1.0);
}
