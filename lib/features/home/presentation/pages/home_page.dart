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
    VoidCallback? onBrandTap;
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
        onBrandTap = () => _showSchoolInfoDialog(context, schoolContext);
        shellActions = [
          K12StatusBadge(
            icon: Icons.rate_review_rounded,
            label: '老师点评',
            color: const Color(0xFFFFB36B),
            foregroundColor: const Color(0xFF8A3F00),
            onTap: () => _showFeedbackDialog(context, summary),
          ),
          if (featureFlags.showGrowthRewards)
            K12StatusBadge(
              icon: dailyCombo > 0
                  ? Icons.local_fire_department_rounded
                  : Icons.workspace_premium_rounded,
              label: dailyCombo > 0 ? '$dailyCombo 连对' : '$dailyStars 星币',
              color: const Color(0xFF9AF07A),
              foregroundColor: const Color(0xFF155B2D),
            ),
        ];
        child = LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1160;
            final useCompactDensity = constraints.maxWidth < 800;
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
                    useCompactDensity: useCompactDensity,
                  );

            return content;
          },
        );
      }
    }

    return TabletShell(
      activeSection: TabletSection.management,
      brandName: schoolContext.displayName,
      brandLogoUrl: schoolContext.logoUrl,
      brandSubtitle: '英语学习',
      onBrandTap: onBrandTap,
      title: '今日英语',
      subtitle: '开始今天的学习',
      actions: shellActions,
      theme: TabletShellTheme.k12Sky,
      child: child,
    );
  }
}

class _EntranceMotion extends StatefulWidget {
  const _EntranceMotion({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

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
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
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

void _showSchoolInfoDialog(BuildContext context, SchoolContext schoolContext) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _SchoolPanel(schoolContext: schoolContext, isCompact: true),
      ),
    ),
  );
}

void _showFeedbackDialog(BuildContext context, PortalSummary summary) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: _FeedbackPanel(summary: summary, isCompact: true),
      ),
    ),
  );
}

void _showScheduleDialog(BuildContext context) {
  const weekItems = [
    ('周一-20', '0节课', false),
    ('周二-21', '0节课', false),
    ('周三-22', '0节课', false),
    ('周四-23', '0节课', false),
    ('周五-24', '0节课', false),
    ('周六-25', '0节课', false),
    ('今日', '0节课', true),
  ];

  _showDashboardContentDialog(
    context,
    title: '我的课表',
    trailing: const [
      _DashboardHeaderChip(icon: Icons.event_available_rounded, label: '约课'),
    ],
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF94B8F3).withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 170,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8FF),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '26年04月',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF2C66D5),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF2C66D5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: weekItems
                      .map(
                        (item) => Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: item.$3
                                  ? const Color(0xFF245BDC)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.$1,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: item.$3
                                            ? Colors.white
                                            : const Color(0xFF1E293B),
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.$2,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: item.$3
                                            ? Colors.white
                                            : const Color(0xFF334155),
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Expanded(
          child: _DashboardEmptyState(
            icon: Icons.note_alt_outlined,
            title: '暂无课程',
          ),
        ),
      ],
    ),
  );
}

void _showTodayTasksDialog(BuildContext context, PortalSummary summary) {
  _showDashboardContentDialog(
    context,
    title: '今日任务',
    trailing: const [
      _DashboardHeaderChip(icon: Icons.calendar_month_rounded, label: '日历'),
      SizedBox(width: 14),
      _DashboardHeaderChip(label: '全部', showChevron: true),
    ],
    child: summary.pendingTasks == 0
        ? const _DashboardEmptyState(
            icon: Icons.note_alt_outlined,
            title: '暂无学习内容',
          )
        : _DashboardTaskList(
            rows: List.generate(
              summary.pendingTasks.clamp(2, 4),
              (index) => _TaskListRowData(
                title: '今日英语练习 ${index + 1}',
                tag: index.isEven ? '录音' : '听说',
                detail: 'Kid\'s Box 精装版 · 第${index + 1}组',
                time: '今天 ${16 + index}:3$index',
                status: index == 0 ? '进行中' : '待开始',
              ),
            ),
          ),
  );
}

void _showReviewCenterDialog(
  BuildContext context, {
  required String activityTitle,
  required String className,
}) {
  final rows = [
    _ReviewCenterRowData(
      title: 'Sing the song',
      tag: '录音',
      belongTo: '$className · $activityTitle',
      teacher: '张嘉琪',
      dateLabel: '04/21\n23:12',
    ),
    _ReviewCenterRowData(
      title: 'Monty\'s phonics',
      tag: '录音',
      belongTo: '$className · $activityTitle',
      teacher: '张嘉琪',
      dateLabel: '04/19\n23:13',
    ),
    _ReviewCenterRowData(
      title: 'Say the chant',
      tag: '录音',
      belongTo: '$className · 3天打卡活动',
      teacher: '张嘉琪',
      dateLabel: '04/14\n22:19',
      highlighted: true,
    ),
    _ReviewCenterRowData(
      title: 'Listen and correct',
      tag: '录音',
      belongTo: '$className · 3天打卡活动',
      teacher: '张嘉琪',
      dateLabel: '04/14\n22:19',
    ),
  ];

  _showDashboardContentDialog(
    context,
    title: '点评中心',
    child: _ReviewCenterTable(rows: rows),
  );
}

void _showTaskCenterDialog(
  BuildContext context, {
  required String activityTitle,
  required String className,
}) {
  final rows = [
    _TaskCenterRowData(
      title: activityTitle,
      target: '$className 周日2:30',
      range: '04月19日-04月23日',
      status: '已过期',
    ),
    _TaskCenterRowData(
      title: '【Kid\'s Box 1 第二版 精装版】3天打卡活动',
      target: '$className 周日2:30',
      range: '04月12日-04月14日',
      status: '已过期',
    ),
    _TaskCenterRowData(
      title: '【Kid\'s Box 1 第二版 精装版】3天打卡活动',
      target: '$className 周日2:30',
      range: '04月05日-04月07日',
      status: '已过期',
    ),
    _TaskCenterRowData(
      title: '【Kid\'s Box 1 第二版 精装版】3天打卡活动',
      target: '$className 周日2:30',
      range: '03月29日-03月31日',
      status: '已过期',
    ),
  ];

  _showDashboardContentDialog(
    context,
    title: '打卡活动    课堂任务',
    trailing: const [
      _DashboardHeaderChip(icon: Icons.filter_alt_outlined, label: '筛选'),
    ],
    child: _TaskCenterTable(rows: rows),
  );
}

void _showDashboardContentDialog(
  BuildContext context, {
  required String title,
  List<Widget> trailing = const [],
  required Widget child,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: const Color(0xFFEAF5FF),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(34)),
      child: SizedBox(
        width: 1320,
        height: 720,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      foregroundColor: const Color(0xFF17335F),
                      minimumSize: const Size(58, 58),
                    ),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(dialogContext).textTheme.displaySmall
                          ?.copyWith(
                            color: const Color(0xFF17335F),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  ...trailing,
                ],
              ),
              const SizedBox(height: 18),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showProfileCenterDialog(
  BuildContext context, {
  required String? currentUserEmail,
  required PortalSummary summary,
  required DailyGrowthSummary dailyGrowth,
  required ParentContactSummary? parentSummary,
  required StudentFeatureFlags featureFlags,
}) {
  final displayName = _studentDisplayName(currentUserEmail);
  final stars = _dailyStarCoins(summary, dailyGrowth, parentSummary);
  final actions = [
    ('我的作品', Icons.brush_rounded),
    ('我的习题', Icons.task_alt_rounded),
    ('我的单词', Icons.translate_rounded),
    ('学习成就', Icons.workspace_premium_rounded),
    ('课堂报告', Icons.library_books_rounded),
    ('往期回放', Icons.ondemand_video_rounded),
    ('我的书架', Icons.bookmarks_rounded),
    ('排行榜', Icons.bar_chart_rounded),
    ('家长通', Icons.family_restroom_rounded),
    ('修改密码', Icons.lock_rounded),
    ('帮助中心', Icons.favorite_rounded),
    ('分享APP', Icons.share_rounded),
  ];

  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: const Color(0xFFEAF5FF),
      insetPadding: const EdgeInsets.all(26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(34)),
      child: SizedBox(
        width: 1080,
        height: 640,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDDEAFE),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF6A7EA7),
                                  size: 52,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: const Color(0xFF1E293B),
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '用户名：${currentUserEmail ?? 'student@claremont.local'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: const Color(0xFF334155),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'APP使用截止日期至：2099-12-31',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: const Color(0xFF64748B),
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF65E3D1),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('编辑'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _ProfileMetricItem(
                                  icon: Icons.star_rounded,
                                  color: const Color(0xFFFFD34D),
                                  value: '$stars',
                                  label: featureFlags.showGrowthRewards
                                      ? '星币'
                                      : '积分',
                                ),
                              ),
                              Expanded(
                                child: _ProfileMetricItem(
                                  icon: Icons.local_fire_department_rounded,
                                  color: const Color(0xFFFF8A3D),
                                  value: '${dailyGrowth.bestCombo}',
                                  label: '连对',
                                ),
                              ),
                              Expanded(
                                child: _ProfileMetricItem(
                                  icon: Icons.workspace_premium_rounded,
                                  color: const Color(0xFFFF9E62),
                                  value: '${summary.completedActivities}',
                                  label: '徽章',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFF9F2), Color(0xFFFCEFE0)],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '恭喜获得小白勋章',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: const Color(0xFFB5792B),
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              child: Center(
                                child: Container(
                                  width: 210,
                                  height: 210,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(
                                          0xFFB6C9FF,
                                        ).withValues(alpha: 0.95),
                                        const Color(
                                          0xFF7284D9,
                                        ).withValues(alpha: 0.92),
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.shield_moon_rounded,
                                    color: Colors.white,
                                    size: 116,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Lv.1      Lv.2      Lv.3      Lv.4      Lv.5',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: const Color(0xFF9B6A30),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '还差100星星升级至Lv.2',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: const Color(0xFF9B6A30),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: GridView.builder(
                    itemCount: actions.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 18,
                          childAspectRatio: 0.88,
                        ),
                    itemBuilder: (context, index) {
                      final item = actions[index];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF9DE6FF), Color(0xFF68C9FF)],
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(item.$2, color: Colors.white, size: 34),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.$1,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: const Color(0xFF1E293B),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showMessagesDialog(BuildContext context, PortalSummary summary) {
  const categories = ['学校通知', '班级通知', '任务提醒', '课程提醒', '请假提醒', '好友请求', '其他消息'];
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: const Color(0xFFEAF5FF),
      insetPadding: const EdgeInsets.all(30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: SizedBox(
        width: 1120,
        height: 620,
        child: Row(
          children: [
            Container(
              width: 280,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  bottomLeft: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '消息中心',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...categories.asMap().entries.map((entry) {
                    final selected = entry.key == 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFDCEBFF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        entry.value,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: selected
                              ? const Color(0xFF2160D4)
                              : const Color(0xFF1E293B),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFFBCC8D9),
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '暂无学校通知',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF6B7A90),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '当前待完成任务 ${summary.pendingTasks} 项，新的消息会在这里提醒你。',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showMomentsDialog(
  BuildContext context, {
  required PortalSummary summary,
  required DailyGrowthSummary dailyGrowth,
  required ParentContactSummary? parentSummary,
}) {
  final timeline = [
    '今天完成了 ${dailyGrowth.completedTasks} 句朗读练习',
    '累计获得 ${_dailyStarCoins(summary, dailyGrowth, parentSummary)} 星币奖励',
    if (dailyGrowth.bestCombo > 0) '今天最高连对 ${dailyGrowth.bestCombo} 题',
    '本周已经完成 ${summary.completedActivities} 项作业',
  ];

  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(34),
      child: Container(
        width: 760,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5DB9FF).withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '学习动态',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '把今天和本周的学习节奏整理在这里。',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 22),
            ...timeline.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5FAFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF84D7FF).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFF2E7BEF),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        item,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF1E293B),
                              fontWeight: FontWeight.w800,
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
}

void _showSettingsDialog(BuildContext context, String? currentUserEmail) {
  final rows = [
    ('切换账号', currentUserEmail ?? 'student@claremont.local', true),
    ('当前版本', '5.3.35.230742', false),
    ('发现新版本', '立即更新', true),
    ('语言', '简体中文', true),
    ('护眼模式', '无限制', true),
    ('隐私政策', '', true),
    ('服务使用协议', '', true),
    ('儿童隐私政策', '', true),
    ('上传日志', '', true),
  ];

  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: const Color(0xFFEAF5FF),
      insetPadding: const EdgeInsets.all(34),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: SizedBox(
        width: 980,
        height: 660,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '系统设置',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.$1,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: const Color(0xFF1E293B),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          if (row.$2.isNotEmpty)
                            Text(
                              row.$2,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: row.$1 == '发现新版本'
                                        ? const Color(0xFFD19400)
                                        : const Color(0xFF3B82F6),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          if (row.$3) ...[
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF3B82F6),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WideHomeLayout extends StatefulWidget {
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
  State<_WideHomeLayout> createState() => _WideHomeLayoutState();
}

class _WideHomeLayoutState extends State<_WideHomeLayout> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _WidePageFrame(
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: _EntranceMotion(
                delay: const Duration(milliseconds: 40),
                child: _WideHeroStage(
                  child: _CompactHeroPanel(
                    schoolContext: widget.schoolContext,
                    currentUserEmail: widget.currentUserEmail,
                    highlightedActivityId: widget.highlightedActivityId,
                    highlightedActivityTitle: widget.highlightedActivityTitle,
                    highlightedClassName: widget.highlightedClassName,
                    highlightedDateLabel: widget.highlightedDateLabel,
                    summary: widget.summary,
                    dailyGrowth: widget.dailyGrowth,
                    parentSummary: widget.parentSummary,
                    resumeSummary: widget.resumeSummary,
                    featureFlags: widget.featureFlags,
                    useCompactDensity: false,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 5,
              child: _EntranceMotion(
                delay: const Duration(milliseconds: 110),
                child: _WideSummaryStage(
                  child: _SummaryGrid(
                    summary: widget.summary,
                    dailyGrowth: widget.dailyGrowth,
                    activityId: widget.highlightedActivityId,
                    parentSummary: widget.parentSummary,
                    featureFlags: widget.featureFlags,
                    isCompact: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      _WidePageFrame(
        child: Row(
          children: [
            SizedBox(
              width: 300,
              child: _EntranceMotion(
                delay: const Duration(milliseconds: 80),
                child: _WideSideStage(
                  child: _StudentSidePanel(
                    schoolContext: widget.schoolContext,
                    currentUserEmail: widget.currentUserEmail,
                    highlightedActivityId: widget.highlightedActivityId,
                    summary: widget.summary,
                    dailyGrowth: widget.dailyGrowth,
                    parentSummary: widget.parentSummary,
                    featureFlags: widget.featureFlags,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _EntranceMotion(
                delay: const Duration(milliseconds: 120),
                child: _WideContentStage(
                  showcase: _WideLearningShowcaseArea(
                    summary: widget.summary,
                    highlightedActivityTitle: widget.highlightedActivityTitle,
                    highlightedClassName: widget.highlightedClassName,
                  ),
                  readingRail: const _ReadingShowcaseColumn(),
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    return K12PlayfulDashboardFrame(
      child: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                if (_pageIndex == index) return;
                setState(() {
                  _pageIndex = index;
                });
              },
              children: pages,
            ),
          ),
          const SizedBox(height: 14),
          _WidePageIndicator(
            currentIndex: _pageIndex,
            onPrevious: _pageIndex > 0
                ? () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  )
                : null,
            onNext: _pageIndex < pages.length - 1
                ? () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  )
                : null,
            pageCount: pages.length,
          ),
        ],
      ),
    );
  }
}

class _DashboardHeaderChip extends StatelessWidget {
  const _DashboardHeaderChip({
    this.icon,
    required this.label,
    this.showChevron = false,
  });

  final IconData? icon;
  final String label;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: const Color(0xFFFFC52D), size: 28),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF17335F),
              fontWeight: FontWeight.w900,
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF17335F),
            ),
          ],
        ],
      ),
    );
  }
}

enum _DashboardCoverStyle {
  schedule,
  todayTask,
  review,
  taskCenter,
  gradedReading,
  phonics,
}

class _DashboardIllustration extends StatelessWidget {
  const _DashboardIllustration({
    required this.style,
    required this.accent,
    this.compact = false,
  });

  final _DashboardCoverStyle style;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case _DashboardCoverStyle.schedule:
        return _ScheduleCoverIllustration(accent: accent, compact: compact);
      case _DashboardCoverStyle.todayTask:
        return _TodayTaskCoverIllustration(accent: accent, compact: compact);
      case _DashboardCoverStyle.review:
        return _ReviewCoverIllustration(accent: accent, compact: compact);
      case _DashboardCoverStyle.taskCenter:
        return _TaskCenterCoverIllustration(accent: accent, compact: compact);
      case _DashboardCoverStyle.gradedReading:
        return _GradedReadingCoverIllustration(
          accent: accent,
          compact: compact,
        );
      case _DashboardCoverStyle.phonics:
        return _PhonicsCoverIllustration(accent: accent, compact: compact);
    }
  }
}

class _DashboardSideRibbon extends StatelessWidget {
  const _DashboardSideRibbon({
    required this.label,
    this.compact = false,
    this.width,
    this.radius,
  });

  final String label;
  final bool compact;
  final double? width;
  final double? radius;

  String get _verticalText => label.split('').join('\n');

  @override
  Widget build(BuildContext context) {
    final ribbonWidth = width ?? (compact ? 36 : 42);
    final ribbonRadius = radius ?? 18;
    return Container(
      width: ribbonWidth,
      padding: EdgeInsets.symmetric(
        vertical: compact ? 10 : 12,
        horizontal: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF75C8FF), Color(0xFF4478F5)],
        ),
        borderRadius: BorderRadius.circular(ribbonRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4478F5).withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        _verticalText,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          height: compact ? 1.02 : 1.04,
        ),
      ),
    );
  }
}

class _CoverCloud extends StatelessWidget {
  const _CoverCloud({
    required this.width,
    required this.height,
    required this.opacity,
  });

  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(height),
      ),
    );
  }
}

class _ScheduleCoverIllustration extends StatelessWidget {
  const _ScheduleCoverIllustration({
    required this.accent,
    required this.compact,
  });

  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 16,
          top: 16,
          child: _CoverCloud(
            width: compact ? 56 : 72,
            height: 24,
            opacity: 0.65,
          ),
        ),
        Positioned(
          right: 18,
          top: 28,
          child: _CoverCloud(
            width: compact ? 42 : 54,
            height: 18,
            opacity: 0.55,
          ),
        ),
        Positioned(
          left: compact ? 34 : 54,
          right: compact ? 34 : 54,
          bottom: compact ? 8 : 10,
          child: Transform.rotate(
            angle: -0.12,
            child: Container(
              height: compact ? 86 : 108,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: accent.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 76;
                    final stripWidth = isNarrow ? 18.0 : 26.0;
                    final stripHeight = isNarrow ? 8.0 : 10.0;
                    final stripGap = isNarrow ? 6.0 : 8.0;
                    final columnGap = isNarrow ? 8.0 : 12.0;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(
                              4,
                              (index) => Padding(
                                padding: EdgeInsets.only(bottom: stripGap),
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD8E8FF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: columnGap),
                        Column(
                          children: [
                            _CoverColorStrip(
                              color: const Color(0xFFFFB657),
                              width: stripWidth,
                              height: stripHeight,
                            ),
                            SizedBox(height: stripGap),
                            _CoverColorStrip(
                              color: const Color(0xFF6DD8A7),
                              width: stripWidth,
                              height: stripHeight,
                            ),
                            SizedBox(height: stripGap),
                            _CoverColorStrip(
                              color: const Color(0xFF73B7FF),
                              width: stripWidth,
                              height: stripHeight,
                            ),
                            SizedBox(height: stripGap),
                            _CoverColorStrip(
                              color: const Color(0xFFFF8DA1),
                              width: stripWidth,
                              height: stripHeight,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverColorStrip extends StatelessWidget {
  const _CoverColorStrip({
    required this.color,
    this.width = 26,
    this.height = 10,
  });

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _TodayTaskCoverIllustration extends StatelessWidget {
  const _TodayTaskCoverIllustration({
    required this.accent,
    required this.compact,
  });

  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 16,
          top: 14,
          child: _CoverCloud(
            width: compact ? 56 : 72,
            height: 24,
            opacity: 0.6,
          ),
        ),
        Positioned(
          right: 22,
          top: 18,
          child: _CoverCloud(
            width: compact ? 46 : 60,
            height: 18,
            opacity: 0.52,
          ),
        ),
        Positioned(
          left: compact ? 34 : 48,
          right: compact ? 34 : 48,
          bottom: compact ? 16 : 18,
          child: Container(
            height: compact ? 92 : 110,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: compact ? 70 : 86,
                      height: compact ? 56 : 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5D7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Color(0xFFFFB657),
                        size: 38,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 12,
                    child: Transform.rotate(
                      angle: -0.34,
                      child: Container(
                        width: 10,
                        height: compact ? 54 : 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFA63D),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 10,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xFF73B7FF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewCoverIllustration extends StatelessWidget {
  const _ReviewCoverIllustration({required this.accent, required this.compact});

  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 18,
          right: 18,
          bottom: 10,
          child: Container(
            height: compact ? 26 : 32,
            decoration: BoxDecoration(
              color: const Color(0xFFC7EDFF).withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Positioned(
          left: compact ? 26 : 34,
          right: compact ? 26 : 34,
          bottom: compact ? 18 : 22,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final leftWidth = constraints.maxWidth < 92
                  ? constraints.maxWidth * 0.42
                  : (compact ? 40.0 : 48.0);
              final rightWidth = constraints.maxWidth < 92
                  ? constraints.maxWidth * 0.26
                  : (compact ? 26.0 : 30.0);

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: leftWidth,
                    height: compact ? 28 : 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC287),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Container(
                    width: rightWidth,
                    height: compact ? 54 : 62,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA54A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Positioned(
          left: compact ? 54 : 74,
          right: compact ? 54 : 74,
          bottom: compact ? 32 : 34,
          child: Column(
            children: [
              Container(
                width: compact ? 78 : 92,
                height: compact ? 78 : 92,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD36F),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 14,
                      child: Container(
                        height: compact ? 18 : 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFF26334F),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(22),
                            bottom: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      top: 34,
                      child: Container(
                        height: compact ? 28 : 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF2C6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 38,
                      child: Container(
                        width: compact ? 14 : 16,
                        height: compact ? 14 : 16,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      top: 38,
                      child: Container(
                        width: compact ? 14 : 16,
                        height: compact ? 14 : 16,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      top: 42,
                      child: Container(
                        width: compact ? 6 : 7,
                        height: compact ? 6 : 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF243B73),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      top: 42,
                      child: Container(
                        width: compact ? 6 : 7,
                        height: compact ? 6 : 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF243B73),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: compact ? 120 : 144,
                height: compact ? 42 : 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.rate_review_rounded,
                  color: Color(0xFFFF8F4D),
                  size: 30,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskCenterCoverIllustration extends StatelessWidget {
  const _TaskCenterCoverIllustration({
    required this.accent,
    required this.compact,
  });

  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 18,
          top: 18,
          child: _CoverCloud(
            width: compact ? 48 : 62,
            height: 20,
            opacity: 0.58,
          ),
        ),
        Positioned(
          right: 20,
          top: 16,
          child: _CoverCloud(
            width: compact ? 40 : 50,
            height: 16,
            opacity: 0.46,
          ),
        ),
        Positioned(
          left: compact ? 40 : 54,
          right: compact ? 40 : 54,
          bottom: compact ? 16 : 18,
          child: Container(
            height: compact ? 92 : 108,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4DE),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.14),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 16,
                  right: 16,
                  top: 16,
                  child: Container(
                    height: compact ? 18 : 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE6B0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 24,
                  top: compact ? 42 : 46,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: List.generate(
                            3,
                            (index) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                height: 7,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFD89A),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        width: compact ? 52 : 62,
                        height: compact ? 52 : 62,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF73B7FF),
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GradedReadingCoverIllustration extends StatelessWidget {
  const _GradedReadingCoverIllustration({
    required this.accent,
    required this.compact,
  });

  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 12,
          child: _CoverCloud(
            width: compact ? 44 : 58,
            height: 18,
            opacity: 0.6,
          ),
        ),
        Positioned(
          left: compact ? 14 : 18,
          right: compact ? 14 : 18,
          bottom: compact ? 18 : 22,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  height: compact ? 62 : 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8F1A5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Color(0xFF3E7B2E),
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: compact ? 74 : 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE06C),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.book_rounded,
                    color: Color(0xFF8A6200),
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: compact ? 56 : 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB0BD),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.import_contacts_rounded,
                    color: Color(0xFF99445B),
                    size: 30,
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

class _PhonicsCoverIllustration extends StatelessWidget {
  const _PhonicsCoverIllustration({
    required this.accent,
    required this.compact,
  });

  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 16,
          top: 12,
          child: _CoverCloud(
            width: compact ? 38 : 50,
            height: 18,
            opacity: 0.56,
          ),
        ),
        Positioned(
          right: 14,
          top: 18,
          child: Container(
            width: compact ? 34 : 42,
            height: compact ? 34 : 42,
            decoration: const BoxDecoration(
              color: Color(0xFFFFD562),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Color(0xFF8A6200),
              size: 22,
            ),
          ),
        ),
        Positioned(
          left: compact ? 18 : 24,
          right: compact ? 18 : 24,
          bottom: compact ? 18 : 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 5,
                child: _LetterBlock(
                  letter: 'A',
                  color: const Color(0xFF6FD2FF),
                  height: compact ? 88 : 106,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 5,
                child: _LetterBlock(
                  letter: 'B',
                  color: const Color(0xFF91E16B),
                  height: compact ? 72 : 88,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 6,
                child: _LetterBlock(
                  letter: 'C',
                  color: const Color(0xFFFFC35E),
                  height: compact ? 96 : 114,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LetterBlock extends StatelessWidget {
  const _LetterBlock({
    required this.letter,
    required this.color,
    required this.height,
  });

  final String letter;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          letter,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2F8FF), Color(0xFFEAF4FF)],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB8CFF8).withValues(alpha: 0.2),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, size: 54, color: const Color(0xFFBCC8D9)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF7A879B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskListRowData {
  const _TaskListRowData({
    required this.title,
    required this.tag,
    required this.detail,
    required this.time,
    required this.status,
  });

  final String title;
  final String tag;
  final String detail;
  final String time;
  final String status;
}

class _DashboardTaskList extends StatelessWidget {
  const _DashboardTaskList({required this.rows});

  final List<_TaskListRowData> rows;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final row = rows[index];
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE9B6), Color(0xFFFFD06A)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFFCC7B00),
                  size: 38,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: const Color(0xFF1E293B),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF7E78D8)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            row.tag,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: const Color(0xFF645BD1),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            row.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    row.time,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF17335F),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      row.status,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF2C66D5),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewCenterRowData {
  const _ReviewCenterRowData({
    required this.title,
    required this.tag,
    required this.belongTo,
    required this.teacher,
    required this.dateLabel,
    this.highlighted = false,
  });

  final String title;
  final String tag;
  final String belongTo;
  final String teacher;
  final String dateLabel;
  final bool highlighted;
}

class _ReviewCenterTable extends StatelessWidget {
  const _ReviewCenterTable({required this.rows});

  final List<_ReviewCenterRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children:
                [
                  const SizedBox(width: 370, child: Text('点评内容')),
                  const SizedBox(width: 24),
                  const Expanded(child: Text('所属')),
                  const SizedBox(width: 32),
                  const SizedBox(width: 140, child: Text('点评老师')),
                  const SizedBox(width: 28),
                  const SizedBox(width: 140, child: Text('点评时间')),
                  const SizedBox(width: 28),
                  const SizedBox(width: 76, child: Text('操作')),
                ].map((widget) {
                  if (widget is Text) {
                    return DefaultTextStyle.merge(
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF17335F),
                        fontWeight: FontWeight.w900,
                      ),
                      child: widget,
                    );
                  }
                  return widget;
                }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final row = rows[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 370,
                      child: Row(
                        children: [
                          Container(
                            width: 112,
                            height: 84,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFF3C7), Color(0xFFFFD783)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.music_note_rounded,
                              size: 40,
                              color: Color(0xFFCC7B00),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: const Color(0xFF1E293B),
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFF7E78D8),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    row.tag,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: const Color(0xFF645BD1),
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Text(
                        row.belongTo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF1F315B),
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    SizedBox(
                      width: 140,
                      child: Text(
                        row.teacher,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF1F315B),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 28),
                    SizedBox(
                      width: 140,
                      child: Text(
                        row.dateLabel,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF1F315B),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 28),
                    SizedBox(
                      width: 76,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.manage_search_rounded,
                                color: Color(0xFF304B86),
                                size: 40,
                              ),
                              Text(
                                '查看',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: const Color(0xFF5A6577),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                          if (row.highlighted)
                            Positioned(
                              right: 12,
                              top: 2,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF4A3D),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TaskCenterRowData {
  const _TaskCenterRowData({
    required this.title,
    required this.target,
    required this.range,
    required this.status,
  });

  final String title;
  final String target;
  final String range;
  final String status;
}

class _TaskCenterTable extends StatelessWidget {
  const _TaskCenterTable({required this.rows});

  final List<_TaskCenterRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children:
                [
                  const SizedBox(width: 380, child: Text('详情')),
                  const SizedBox(width: 32),
                  const SizedBox(width: 300, child: Text('对象')),
                  const SizedBox(width: 32),
                  const SizedBox(width: 240, child: Text('状态')),
                  const Spacer(),
                  const SizedBox(width: 76, child: Text('操作')),
                ].map((widget) {
                  if (widget is Text) {
                    return DefaultTextStyle.merge(
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF17335F),
                        fontWeight: FontWeight.w900,
                      ),
                      child: widget,
                    );
                  }
                  return widget;
                }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final row = rows[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 380,
                      child: Row(
                        children: [
                          Container(
                            width: 112,
                            height: 84,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFF5D2), Color(0xFFFFD27C)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.edit_calendar_rounded,
                              size: 42,
                              color: Color(0xFFCC7B00),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              row.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: const Color(0xFF1F315B),
                                    fontWeight: FontWeight.w900,
                                    height: 1.35,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    SizedBox(
                      width: 300,
                      child: Text(
                        row.target,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF1F315B),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    SizedBox(
                      width: 240,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.range,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: const Color(0xFF1F315B),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            row.status,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: const Color(0xFF9AA3AF),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 76,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.manage_search_rounded,
                            color: Color(0xFF304B86),
                            size: 40,
                          ),
                          Text(
                            '查看',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: const Color(0xFF5A6577),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WidePageFrame extends StatelessWidget {
  const _WidePageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: child,
    );
  }
}

class _WidePageIndicator extends StatelessWidget {
  const _WidePageIndicator({
    required this.currentIndex,
    required this.onPrevious,
    required this.onNext,
    required this.pageCount,
  });

  final int currentIndex;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final dots = List<Widget>.generate(pageCount, (index) {
      final isActive = index == currentIndex;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: isActive ? 26 : 10,
        height: 10,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFFD34D)
              : Colors.white.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filled(
          onPressed: onPrevious,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
          ),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        const SizedBox(width: 12),
        ...dots.expand((dot) => [dot, const SizedBox(width: 8)]).toList()
          ..removeLast(),
        const SizedBox(width: 12),
        Text(
          currentIndex == 0
              ? '向左滑动看更多'
              : currentIndex == pageCount - 1
              ? '向右滑动返回上一屏'
              : '左右滑动切换内容',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filled(
          onPressed: onNext,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
          ),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _StudentSidePanel extends StatelessWidget {
  const _StudentSidePanel({
    required this.schoolContext,
    required this.currentUserEmail,
    required this.highlightedActivityId,
    required this.summary,
    required this.dailyGrowth,
    required this.parentSummary,
    required this.featureFlags,
  });

  final SchoolContext schoolContext;
  final String? currentUserEmail;
  final String highlightedActivityId;
  final PortalSummary summary;
  final DailyGrowthSummary dailyGrowth;
  final ParentContactSummary? parentSummary;
  final StudentFeatureFlags featureFlags;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 12,
          child: _ProfileCenterCard(
            currentUserEmail: currentUserEmail,
            summary: summary,
            dailyGrowth: dailyGrowth,
            parentSummary: parentSummary,
            featureFlags: featureFlags,
            onTap: () => _showProfileCenterDialog(
              context,
              currentUserEmail: currentUserEmail,
              summary: summary,
              dailyGrowth: dailyGrowth,
              parentSummary: parentSummary,
              featureFlags: featureFlags,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          flex: 8,
          child: _HomeUtilityGrid(
            currentUserEmail: currentUserEmail,
            highlightedActivityId: highlightedActivityId,
            summary: summary,
            dailyGrowth: dailyGrowth,
            parentSummary: parentSummary,
            schoolContext: schoolContext,
            featureFlags: featureFlags,
          ),
        ),
      ],
    );
  }
}

class _ProfileCenterCard extends StatelessWidget {
  const _ProfileCenterCard({
    required this.currentUserEmail,
    required this.summary,
    required this.dailyGrowth,
    required this.parentSummary,
    required this.featureFlags,
    required this.onTap,
  });

  final String? currentUserEmail;
  final PortalSummary summary;
  final DailyGrowthSummary dailyGrowth;
  final ParentContactSummary? parentSummary;
  final StudentFeatureFlags featureFlags;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = _studentDisplayName(currentUserEmail);
    final stars = _dailyStarCoins(summary, dailyGrowth, parentSummary);
    final combo = dailyGrowth.bestCombo;
    final badgeCount = summary.completedActivities;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTight =
                constraints.maxHeight < 290 || constraints.maxWidth < 300;

            return Container(
              padding: EdgeInsets.all(isTight ? 12 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.88),
                    const Color(0xFFF4FBFF).withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.76),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6CC7FF).withValues(alpha: 0.16),
                    blurRadius: 16,
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
                        padding: EdgeInsets.symmetric(
                          horizontal: isTight ? 14 : 18,
                          vertical: isTight ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF77C7FF), Color(0xFF477AF6)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF4D85F8,
                              ).withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          '个人中心',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: isTight ? 18 : null,
                              ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: const Color(0xFF6B8ED6).withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                  SizedBox(height: isTight ? 8 : 14),
                  Row(
                    children: [
                      Container(
                        width: isTight ? 50 : 62,
                        height: isTight ? 50 : 62,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFDDEAFE), Color(0xFFBFD7FF)],
                          ),
                          borderRadius: BorderRadius.circular(
                            isTight ? 16 : 22,
                          ),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          color: const Color(0xFF667AA8),
                          size: isTight ? 30 : 42,
                        ),
                      ),
                      SizedBox(width: isTight ? 10 : 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: const Color(0xFF1E293B),
                                          fontWeight: FontWeight.w900,
                                          fontSize: isTight ? 20 : 24,
                                        ),
                                  ),
                                ),
                                Container(
                                  width: isTight ? 20 : 22,
                                  height: isTight ? 20 : 22,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF5348),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${summary.pendingTasks}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isTight ? 2 : 6),
                            Text(
                              currentUserEmail ?? 'student@claremont.local',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w700,
                                    fontSize: isTight ? 12 : null,
                                  ),
                            ),
                            SizedBox(height: isTight ? 2 : 4),
                            Text(
                              '点开查看成长档案',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFF7B91AC),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isTight ? 10 : 14),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTight ? 8 : 10,
                      vertical: isTight ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF8FF),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ProfileMetricItem(
                            icon: Icons.star_rounded,
                            color: const Color(0xFFFFD34D),
                            value: '$stars',
                            label: featureFlags.showGrowthRewards ? '星币' : '积分',
                            isCompact: isTight,
                          ),
                        ),
                        Expanded(
                          child: _ProfileMetricItem(
                            icon: Icons.local_fire_department_rounded,
                            color: const Color(0xFFFF8A3D),
                            value: '$combo',
                            label: '连对',
                            isCompact: isTight,
                          ),
                        ),
                        Expanded(
                          child: _ProfileMetricItem(
                            icon: Icons.workspace_premium_rounded,
                            color: const Color(0xFFFF9E62),
                            value: '$badgeCount',
                            label: '徽章',
                            isCompact: isTight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileMetricItem extends StatelessWidget {
  const _ProfileMetricItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.isCompact = false,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: isCompact ? 36 : 48,
          height: isCompact ? 36 : 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: isCompact ? 20 : 28),
        ),
        SizedBox(height: isCompact ? 6 : 10),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
            fontSize: isCompact ? 20 : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
            fontSize: isCompact ? 11 : null,
          ),
        ),
      ],
    );
  }
}

class _HomeUtilityGrid extends StatelessWidget {
  const _HomeUtilityGrid({
    required this.currentUserEmail,
    required this.highlightedActivityId,
    required this.summary,
    required this.dailyGrowth,
    required this.parentSummary,
    required this.schoolContext,
    required this.featureFlags,
  });

  final String? currentUserEmail;
  final String highlightedActivityId;
  final PortalSummary summary;
  final DailyGrowthSummary dailyGrowth;
  final ParentContactSummary? parentSummary;
  final SchoolContext schoolContext;
  final StudentFeatureFlags featureFlags;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        '消息',
        Icons.mark_chat_read_rounded,
        const Color(0xFF68A7FF),
        () => _showMessagesDialog(context, summary),
      ),
      (
        '动态',
        Icons.auto_awesome_rounded,
        const Color(0xFFFF7E68),
        () => _showMomentsDialog(
          context,
          summary: summary,
          dailyGrowth: dailyGrowth,
          parentSummary: parentSummary,
        ),
      ),
      (
        '设置',
        Icons.settings_rounded,
        const Color(0xFF54C58F),
        () => _showSettingsDialog(context, currentUserEmail),
      ),
      (
        '家长通',
        Icons.family_restroom_rounded,
        const Color(0xFFFFB36B),
        () => context.go('/activities/$highlightedActivityId/parent-contact'),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.84),
            const Color(0xFFF4FBFF).withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: schoolContext.primaryColor.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.55,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return _HomeUtilityButton(
            title: item.$1,
            icon: item.$2,
            color: item.$3,
            onTap: item.$4,
          );
        },
      ),
    );
  }
}

class _HomeUtilityButton extends StatelessWidget {
  const _HomeUtilityButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
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
    this.useCompactDensity = false,
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
  final bool useCompactDensity;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = useCompactDensity ? 12.0 : 16.0;
        return K12PlayfulDashboardFrame(
          padding: EdgeInsets.all(useCompactDensity ? 14 : 18),
          child: Column(
            children: [
              Expanded(
                flex: useCompactDensity ? 42 : 44,
                child: _EntranceMotion(
                  delay: const Duration(milliseconds: 40),
                  child: _CompactHeroPanel(
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
                    useCompactDensity: useCompactDensity,
                  ),
                ),
              ),
              SizedBox(height: gap),
              Expanded(
                flex: useCompactDensity ? 34 : 32,
                child: _EntranceMotion(
                  delay: const Duration(milliseconds: 120),
                  child: _CompactDashboardGrid(
                    summary: summary,
                    dailyGrowth: dailyGrowth,
                    activityId: highlightedActivityId,
                    parentSummary: parentSummary,
                    featureFlags: featureFlags,
                    useCompactDensity: useCompactDensity,
                  ),
                ),
              ),
              SizedBox(height: gap),
              Expanded(
                flex: useCompactDensity ? 24 : 24,
                child: _EntranceMotion(
                  delay: const Duration(milliseconds: 200),
                  child: _CompactFooterRow(
                    highlightedActivityTitle: highlightedActivityTitle,
                    highlightedClassName: highlightedClassName,
                    summary: summary,
                    useCompactDensity: useCompactDensity,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactHeroPanel extends StatelessWidget {
  const _CompactHeroPanel({
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
    required this.useCompactDensity,
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
  final bool useCompactDensity;

  @override
  Widget build(BuildContext context) {
    final displayName = _studentDisplayName(currentUserEmail);
    final dailyStars = _dailyStarCoins(summary, dailyGrowth, parentSummary);
    final completedTasks = dailyGrowth.completedTasks;
    final showGrowthRewards = featureFlags.showGrowthRewards;
    final badgeText = resumeSummary.resumeTaskIndex != null
        ? '继续第 ${resumeSummary.resumeTaskIndex} 句'
        : completedTasks > 0
        ? '已完成 $completedTasks 句'
        : '今天开始闯关';
    final heroSubtitle = summary.pendingTasks > 0
        ? '还有 ${summary.pendingTasks} 项小任务等你完成'
        : '今天的主线任务已经准备好了';
    final metaLabel = '$highlightedClassName · $highlightedDateLabel';

    return Container(
      padding: EdgeInsets.all(useCompactDensity ? 18 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5DB9FF), Color(0xFF2D8DFF), Color(0xFF69D5FF)],
        ),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.34),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D8DFF).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -8,
            right: -6,
            child: Container(
              width: useCompactDensity ? 88 : 108,
              height: useCompactDensity ? 88 : 108,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFFE36E), Color(0xFFFFBB3E)],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '今日主线',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (showGrowthRewards)
                    K12PlayToken(
                      icon: Icons.stars_rounded,
                      label: '$dailyStars 星币',
                      color: const Color(0xFFFFE36B),
                      foregroundColor: const Color(0xFF7A4A00),
                    ),
                ],
              ),
              SizedBox(height: useCompactDensity ? 10 : 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$displayName 同学',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: const Color(0xFFFFF5C4),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '先完成这份作业',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            heroSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.94),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              K12HeroBadge(
                                icon: Icons.play_circle_rounded,
                                label: badgeText,
                              ),
                              K12HeroBadge(
                                icon: Icons.class_rounded,
                                label: metaLabel,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: useCompactDensity ? 8 : 14),
                    SizedBox(
                      width: useCompactDensity ? 102 : 128,
                      child: const AspectRatio(
                        aspectRatio: 1,
                        child: K12CartoonHeroScene(),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: useCompactDensity ? 10 : 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFE36B),
                        foregroundColor: const Color(0xFF195AB6),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: useCompactDensity ? 12 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () =>
                          context.go('/activities/$highlightedActivityId'),
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      label: Text(
                        resumeSummary.resumeTaskIndex == null
                            ? '开始作业'
                            : '继续第 ${resumeSummary.resumeTaskIndex} 句',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () => context.go('/activities'),
                    icon: const Icon(Icons.menu_book_rounded),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactDashboardGrid extends StatelessWidget {
  const _CompactDashboardGrid({
    required this.summary,
    required this.dailyGrowth,
    required this.activityId,
    required this.parentSummary,
    required this.featureFlags,
    required this.useCompactDensity,
  });

  final PortalSummary summary;
  final DailyGrowthSummary dailyGrowth;
  final String activityId;
  final ParentContactSummary? parentSummary;
  final StudentFeatureFlags featureFlags;
  final bool useCompactDensity;

  @override
  Widget build(BuildContext context) {
    final dailyStars = _dailyStarCoins(summary, dailyGrowth, parentSummary);
    final cards = [
      (
        'Reading',
        '${summary.inProgressActivities}',
        Icons.auto_stories_rounded,
        const Color(0xFF5DB9FF),
        () => context.go('/activities'),
      ),
      (
        'Word',
        '${summary.totalActivities}',
        featureFlags.showFunZonePromos
            ? Icons.translate_rounded
            : Icons.fact_check_rounded,
        const Color(0xFFFFC941),
        () => context.go(
          featureFlags.showFunZonePromos ? '/explore' : '/activities',
        ),
      ),
      (
        'Speak',
        dailyGrowth.bestCombo > 0
            ? '${dailyGrowth.bestCombo}'
            : '${summary.pendingTasks}',
        Icons.record_voice_over_rounded,
        const Color(0xFF78E55A),
        () => context.go('/activities/$activityId'),
      ),
      (
        featureFlags.showGrowthRewards ? 'Badges' : 'Tasks',
        featureFlags.showGrowthRewards
            ? '$dailyStars'
            : '${dailyGrowth.completedTasks > 0 ? dailyGrowth.completedTasks : summary.pendingTasks}',
        featureFlags.showGrowthRewards
            ? Icons.workspace_premium_rounded
            : Icons.checklist_rounded,
        const Color(0xFF55D9C5),
        () => context.go('/activities'),
      ),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: useCompactDensity ? 10 : 12,
        mainAxisSpacing: useCompactDensity ? 10 : 12,
        childAspectRatio: useCompactDensity ? 1.16 : 1.28,
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        return _CompactGridCard(
          title: card.$1,
          value: card.$2,
          icon: card.$3,
          color: card.$4,
          onTap: card.$5,
          useCompactDensity: useCompactDensity,
        );
      },
    );
  }
}

class _CompactGridCard extends StatelessWidget {
  const _CompactGridCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.useCompactDensity,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool useCompactDensity;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: EdgeInsets.all(useCompactDensity ? 14 : 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.98),
              color.withValues(alpha: 0.82),
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 1.6,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: useCompactDensity ? 42 : 46,
              height: useCompactDensity ? 42 : 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF195AB6),
                size: useCompactDensity ? 22 : 24,
              ),
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: const Color(0xFF114178),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF114178),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactFooterRow extends StatelessWidget {
  const _CompactFooterRow({
    required this.highlightedActivityTitle,
    required this.highlightedClassName,
    required this.summary,
    required this.useCompactDensity,
  });

  final String highlightedActivityTitle;
  final String highlightedClassName;
  final PortalSummary summary;
  final bool useCompactDensity;

  @override
  Widget build(BuildContext context) {
    final gap = useCompactDensity ? 10.0 : 12.0;
    return Row(
      children: [
        Expanded(
          child: _CompactFooterCard(
            title: '点评中心',
            subtitle: '查看老师刚批完的录音和口语点评',
            icon: Icons.rate_review_rounded,
            accent: const Color(0xFFFF8F4D),
            coverStyle: _DashboardCoverStyle.review,
            onTap: () => _showReviewCenterDialog(
              context,
              activityTitle: highlightedActivityTitle,
              className: highlightedClassName,
            ),
            useCompactDensity: useCompactDensity,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _CompactFooterCard(
            title: '任务中心',
            subtitle: summary.pendingTasks > 0
                ? '还有 ${summary.pendingTasks} 项等你完成'
                : '查看历史打卡活动和课堂任务',
            icon: Icons.checklist_rounded,
            accent: const Color(0xFF78E55A),
            coverStyle: _DashboardCoverStyle.taskCenter,
            onTap: () => _showTaskCenterDialog(
              context,
              activityTitle: highlightedActivityTitle,
              className: highlightedClassName,
            ),
            useCompactDensity: useCompactDensity,
          ),
        ),
      ],
    );
  }
}

class _CompactFooterCard extends StatelessWidget {
  const _CompactFooterCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.coverStyle,
    required this.onTap,
    required this.useCompactDensity,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final _DashboardCoverStyle coverStyle;
  final VoidCallback onTap;
  final bool useCompactDensity;

  String get _ribbonLabel {
    switch (coverStyle) {
      case _DashboardCoverStyle.review:
        return '点评中心';
      case _DashboardCoverStyle.taskCenter:
        return '任务中心';
      case _DashboardCoverStyle.schedule:
        return '课程计划';
      case _DashboardCoverStyle.todayTask:
        return '今日任务';
      case _DashboardCoverStyle.gradedReading:
        return '分级阅读';
      case _DashboardCoverStyle.phonics:
        return '自然拼读';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: k12PlasticPanelDecoration(accent: accent, radius: 24),
        child: Column(
          children: [
            SizedBox(
              height: useCompactDensity ? 134 : 156,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.22),
                      accent.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.82),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: -7,
                      top: 14,
                      child: _DashboardSideRibbon(
                        label: _ribbonLabel,
                        compact: useCompactDensity,
                      ),
                    ),
                    Positioned(
                      left: -8,
                      bottom: -14,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      top: 14,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(icon, color: accent, size: 30),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        child: _DashboardIllustration(
                          style: coverStyle,
                          accent: accent,
                          compact: useCompactDensity,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: useCompactDensity ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideHeroStage extends StatelessWidget {
  const _WideHeroStage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.28),
            const Color(0xFFE7F7FF).withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.56),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFFFFDB63).withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -18,
            bottom: -28,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF8FD8FF).withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _WideSummaryStage extends StatelessWidget {
  const _WideSummaryStage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.24),
            const Color(0xFFEFF9FF).withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.58),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.64),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.dashboard_customize_rounded,
                        color: Color(0xFF3369D7),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '今日进度',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF1E293B),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '看看今天学到哪里了',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF547089),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _WideSideStage extends StatelessWidget {
  const _WideSideStage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.3),
            const Color(0xFFE8F7FF).withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.56),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -26,
            top: -24,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF8FD8FF).withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -18,
            bottom: -28,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: const Color(0xFFB4F06D).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _WideLearningShowcaseArea extends StatelessWidget {
  const _WideLearningShowcaseArea({
    required this.summary,
    required this.highlightedActivityTitle,
    required this.highlightedClassName,
  });

  final PortalSummary summary;
  final String highlightedActivityTitle;
  final String highlightedClassName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 36,
          child: _WideShowcaseCard(
            title: '今日课表',
            ribbonLabel: '课程计划',
            accent: const Color(0xFF73B7FF),
            coverStyle: _DashboardCoverStyle.schedule,
            onTap: () => _showScheduleDialog(context),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 64,
          child: Column(
            children: [
              Expanded(
                flex: 58,
                child: Row(
                  children: [
                    Expanded(
                      child: _WideShowcaseCard(
                        title: '今日任务',
                        ribbonLabel: '今日任务',
                        accent: const Color(0xFFFFC941),
                        coverStyle: _DashboardCoverStyle.todayTask,
                        onTap: () => _showTodayTasksDialog(context, summary),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _WideShowcaseCard(
                        title: '点评中心',
                        ribbonLabel: '点评中心',
                        accent: const Color(0xFFFF8F4D),
                        coverStyle: _DashboardCoverStyle.review,
                        badgeLabel: '3',
                        onTap: () => _showReviewCenterDialog(
                          context,
                          activityTitle: highlightedActivityTitle,
                          className: highlightedClassName,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                flex: 42,
                child: _WideShowcaseCard(
                  title: '任务中心',
                  ribbonLabel: '任务中心',
                  accent: const Color(0xFF78E55A),
                  coverStyle: _DashboardCoverStyle.taskCenter,
                  onTap: () => _showTaskCenterDialog(
                    context,
                    activityTitle: highlightedActivityTitle,
                    className: highlightedClassName,
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

class _WideShowcaseCard extends StatelessWidget {
  const _WideShowcaseCard({
    required this.title,
    required this.ribbonLabel,
    required this.accent,
    required this.coverStyle,
    required this.onTap,
    this.badgeLabel,
  });

  final String title;
  final String ribbonLabel;
  final Color accent;
  final _DashboardCoverStyle coverStyle;
  final VoidCallback onTap;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: k12PlasticPanelDecoration(accent: accent, radius: 30),
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.14),
                      accent.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: -8,
                      top: 18,
                      child: _DashboardSideRibbon(
                        label: ribbonLabel,
                        width: 46,
                        radius: 20,
                      ),
                    ),
                    if (badgeLabel != null)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF5348,
                            ).withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            badgeLabel!,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 10,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                        child: _DashboardIllustration(
                          style: coverStyle,
                          accent: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideContentStage extends StatelessWidget {
  const _WideContentStage({required this.showcase, required this.readingRail});

  final Widget showcase;
  final Widget readingRail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.24),
            const Color(0xFFF0FAFF).withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.58),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -42,
            bottom: -64,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFF8FEA74).withValues(alpha: 0.11),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -34,
            top: -26,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFFFDB63).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.64),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_stories_rounded,
                            color: Color(0xFF3369D7),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '今日学习地图',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: const Color(0xFF1E293B),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '课程、任务、点评与阅读都在这里',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF547089),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(flex: 74, child: showcase),
                    const SizedBox(width: 18),
                    SizedBox(width: 228, child: readingRail),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadingShowcaseColumn extends StatelessWidget {
  const _ReadingShowcaseColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: _ReadingShowcaseCard(
            ribbonLabel: '分级阅读',
            title: '国家地理PM',
            accent: const Color(0xFF87D76A),
            coverStyle: _DashboardCoverStyle.gradedReading,
            onTap: () => context.go('/explore'),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          flex: 6,
          child: _ReadingShowcaseCard(
            ribbonLabel: '自然拼读',
            title: '自然拼读',
            accent: const Color(0xFF73B7FF),
            coverStyle: _DashboardCoverStyle.phonics,
            onTap: () => context.go('/explore'),
          ),
        ),
      ],
    );
  }
}

class _ReadingShowcaseCard extends StatelessWidget {
  const _ReadingShowcaseCard({
    required this.ribbonLabel,
    required this.title,
    required this.accent,
    required this.coverStyle,
    required this.onTap,
  });

  final String ribbonLabel;
  final String title;
  final Color accent;
  final _DashboardCoverStyle coverStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: k12PlasticPanelDecoration(accent: accent, radius: 28),
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.13),
                      accent.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: -8,
                      top: 16,
                      child: _DashboardSideRibbon(
                        label: ribbonLabel,
                        width: 44,
                        radius: 18,
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 10,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
                        child: _DashboardIllustration(
                          style: coverStyle,
                          accent: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w900,
                  height: 1.04,
                ),
              ),
            ),
          ],
        ),
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
            title: '阅读',
            value: '${summary.inProgressActivities} 节',
            subtitle: '课本跟读',
            color: const Color(0xFF5DB9FF),
            icon: Icons.auto_stories_rounded,
            isCompact: isCompact,
            onTap: () => context.go('/activities'),
          ),
          _SummaryCard(
            title: featureFlags.showFunZonePromos ? '单词' : '作业',
            value: featureFlags.showFunZonePromos
                ? '${summary.totalActivities} 组'
                : '${summary.totalActivities} 份',
            subtitle: featureFlags.showFunZonePromos ? '背词拼读' : '主线任务',
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
            title: '口语',
            value: comboCount > 0
                ? '$comboCount 连对'
                : '${summary.pendingTasks} 项',
            subtitle: '开口练习',
            color: const Color(0xFF78E55A),
            icon: Icons.record_voice_over_rounded,
            isCompact: isCompact,
            onTap: () => context.go('/activities/$activityId'),
          ),
          _SummaryCard(
            title: featureFlags.showGrowthRewards ? '奖励' : '任务',
            value: featureFlags.showGrowthRewards
                ? dailyStars > 0
                      ? '$dailyStars 星币'
                      : '${summary.completedActivities} 枚'
                : completedTasks > 0
                ? '$completedTasks 句'
                : '${summary.pendingTasks} 项',
            subtitle: featureFlags.showGrowthRewards
                ? completedTasks > 0
                      ? '已完成 $completedTasks 句'
                      : '星币徽章'
                : '继续主线',
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
                        maxLines: 1,
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
