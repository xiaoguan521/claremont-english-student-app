import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_breakpoints.dart';
import '../../../../core/widgets/adaptive_dialog_scaffold.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../portal/data/portal_models.dart';
import '../../../portal/presentation/providers/portal_providers.dart';
import '../../../portal/presentation/providers/parent_contact_providers.dart';
import '../../../portal/presentation/providers/practice_session_providers.dart';
import '../../../portal/presentation/providers/student_feature_flags_provider.dart';
import '../../../portal/presentation/widgets/tablet_shell.dart';
import '../../../school/presentation/providers/school_context_provider.dart';
import '../../../student/presentation/providers/student_identity_provider.dart';
import '../../../student/presentation/widgets/student_dashboard_dialog_widgets.dart';
import '../../../student/presentation/widgets/student_ui_components.dart';
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
    final selectedStudentId = ref.watch(selectedStudentProfileProvider);
    final studentProfiles = ref.watch(availableStudentProfilesProvider);

    final schoolContext =
        schoolContextAsync.valueOrNull ?? SchoolContext.fallback();
    final availableProfiles =
        studentProfiles.valueOrNull ?? const <StudentIdentityProfile>[];
    StudentIdentityProfile? selectedStudentProfile;
    for (final profile in availableProfiles) {
      if (profile.id == selectedStudentId) {
        selectedStudentProfile = profile;
        break;
      }
    }
    selectedStudentProfile ??= availableProfiles.length == 1
        ? availableProfiles.first
        : null;
    final studentDisplayName =
        selectedStudentProfile?.displayName ??
        _studentDisplayName(currentUserEmail);

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
        shellActions = featureFlags.showGrowthRewards
            ? [
                K12StatusBadge(
                  icon: dailyCombo > 0
                      ? Icons.local_fire_department_rounded
                      : Icons.workspace_premium_rounded,
                  label: dailyCombo > 0 ? '$dailyCombo 连对' : '$dailyStars 星币',
                  color: const Color(0xFF9AF07A),
                  foregroundColor: const Color(0xFF155B2D),
                ),
              ]
            : null;
        child = LayoutBuilder(
          builder: (context, constraints) {
            return _WideHomeLayout(
              schoolContext: schoolContext,
              currentUserEmail: currentUserEmail,
              studentDisplayName: studentDisplayName,
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
  final items = [
    const StudentSchoolDynamicItem(
      icon: Icons.record_voice_over_rounded,
      title: '老师留言',
      content: '今天先完成主线作业，读的时候记得把每个单词尾音读清楚。',
      color: Color(0xFFFFB36B),
    ),
    const StudentSchoolDynamicItem(
      icon: Icons.emoji_events_rounded,
      title: '班级荣誉',
      content: '本班本周已收集 8500 枚星币，继续冲刺年级榜单。',
      color: Color(0xFFFFD447),
    ),
    StudentSchoolDynamicItem(
      icon: Icons.school_rounded,
      title: '学校简介',
      content: schoolContext.welcomeMessage,
      color: schoolContext.primaryColor,
    ),
  ];

  showDialog<void>(
    context: context,
    builder: (context) => AdaptiveDialogScaffold(
      title: '${schoolContext.displayName} 班级动态 · 英语',
      maxDialogWidth: 620,
      maxDialogHeight: 420,
      bodyBuilder: (context, _, __) => StudentSchoolDynamicPanel(
        schoolName: schoolContext.displayName,
        primaryColor: schoolContext.primaryColor,
        items: items,
        isCompact: true,
        showHeading: false,
      ),
    ),
  );
}

void _showTaskCenterDialog(
  BuildContext context, {
  required String activityTitle,
  required String className,
}) {
  final rows = [
    StudentTaskCenterItem(
      title: activityTitle,
      target: '$className 周日2:30',
      range: '04月19日-04月23日',
      status: '可补做',
      actionLabel: '补做',
    ),
    StudentTaskCenterItem(
      title: '【Kid\'s Box 1 第二版 精装版】3天打卡活动',
      target: '$className 周日2:30',
      range: '04月12日-04月14日',
      status: '已点评',
      actionLabel: '查看',
    ),
    StudentTaskCenterItem(
      title: '【Kid\'s Box 1 第二版 精装版】3天打卡活动',
      target: '$className 周日2:30',
      range: '04月05日-04月07日',
      status: '已完成',
      actionLabel: '回看',
    ),
    StudentTaskCenterItem(
      title: '【Kid\'s Box 1 第二版 精装版】3天打卡活动',
      target: '$className 周日2:30',
      range: '03月29日-03月31日',
      status: '已结束',
      actionLabel: '查看',
    ),
  ];

  _showDashboardContentDialog(
    context,
    title: '打卡活动    课堂任务',
    trailing: const [
      _DashboardHeaderChip(icon: Icons.filter_alt_outlined, label: '筛选'),
    ],
    child: StudentTaskCenterFeed(items: rows),
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
    builder: (dialogContext) => AdaptiveDialogScaffold(
      title: title,
      trailing: trailing,
      bodyBuilder: (context, _, __) => child,
    ),
  );
}

void _showProfileCenterDialog(
  BuildContext context, {
  required String? currentUserEmail,
  required String studentDisplayName,
  required String highlightedActivityTitle,
  required String highlightedClassName,
  required PortalSummary summary,
  required DailyGrowthSummary dailyGrowth,
  required ParentContactSummary? parentSummary,
  required StudentFeatureFlags featureFlags,
}) {
  final stars = _dailyStarCoins(summary, dailyGrowth, parentSummary);
  final coinLabel = featureFlags.showGrowthRewards ? '星币' : '积分';

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AdaptiveDialogScaffold(
      title: '个人中心',
      maxDialogWidth: 760,
      maxDialogHeight: 520,
      bodyBuilder: (dialogContext, screenType, dialogSize) {
        final useStacked =
            screenType == AppScreenType.mobile || dialogSize.width < 620;
        final actions = [
          StudentProfileAction(
            icon: Icons.stars_rounded,
            label: coinLabel,
            value: '$stars',
            accent: const Color(0xFFFFC83D),
            onTap: () {
              Navigator.of(dialogContext).pop();
              _showStarCoinLedgerDialog(
                context,
                stars: stars,
                showGrowthRewards: featureFlags.showGrowthRewards,
              );
            },
          ),
          StudentProfileAction(
            icon: Icons.message_rounded,
            label: '消息',
            value: '${summary.pendingTasks} 条提醒',
            accent: const Color(0xFF55BDF6),
            onTap: () {
              Navigator.of(dialogContext).pop();
              context.go('/messages');
            },
          ),
          StudentProfileAction(
            icon: Icons.settings_rounded,
            label: '设置',
            value: '护眼与账号',
            accent: const Color(0xFF70D85B),
            onTap: () {
              Navigator.of(dialogContext).pop();
              _showSettingsDialog(context, currentUserEmail);
            },
          ),
          StudentProfileAction(
            icon: Icons.info_rounded,
            label: '关于',
            value: '版本与隐私',
            accent: const Color(0xFF9D7CFF),
            onTap: () {
              Navigator.of(dialogContext).pop();
              _showAboutStudentDialog(context);
            },
          ),
        ];

        return StudentProfileDialogContent(
          displayName: studentDisplayName,
          emailLabel: currentUserEmail ?? 'student@claremont.local',
          progressLabel:
              '今天完成 ${dailyGrowth.completedTasks} 项 · 最高连对 ${dailyGrowth.bestCombo}',
          actions: actions,
          useStacked: useStacked,
        );
      },
    ),
  );
}

void _showAboutStudentDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AdaptiveDialogScaffold(
      title: '关于',
      maxDialogWidth: 620,
      maxDialogHeight: 420,
      bodyBuilder: (context, _, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F8FF), Color(0xFFF2FFE8)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Color(0xFF2E7BEF),
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '英语打卡',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: const Color(0xFF17335F),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'K12 英语陪伴式学习应用',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
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
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: const [
                StudentInfoLine(title: '当前版本', value: '5.3.35'),
                StudentInfoLine(title: '儿童隐私政策', value: '已配置'),
                StudentInfoLine(title: '服务使用协议', value: '已配置'),
                StudentInfoLine(title: '上传日志', value: '帮助老师排查问题'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void _showSettingsDialog(BuildContext context, String? currentUserEmail) {
  final sections = [
    _SettingsDialogSectionData(
      title: '账号与学校',
      accent: const Color(0xFF4AA7FF),
      icon: Icons.school_rounded,
      items: [
        _SettingsDialogItemData(
          title: '当前账号',
          value: currentUserEmail ?? 'student@claremont.local',
          icon: Icons.person_rounded,
        ),
        const _SettingsDialogItemData(
          title: '学校学习入口',
          value: '已绑定',
          icon: Icons.auto_stories_rounded,
        ),
      ],
    ),
    const _SettingsDialogSectionData(
      title: '学习保护',
      accent: Color(0xFF6BD85F),
      icon: Icons.health_and_safety_rounded,
      items: [
        _SettingsDialogItemData(
          title: '柔和护眼模式',
          value: '已开启',
          icon: Icons.visibility_rounded,
        ),
        _SettingsDialogItemData(
          title: '专注休息提醒',
          value: '20 分钟',
          icon: Icons.timer_rounded,
        ),
      ],
    ),
    const _SettingsDialogSectionData(
      title: '隐私与支持',
      accent: Color(0xFFFFB84D),
      icon: Icons.verified_user_rounded,
      items: [
        _SettingsDialogItemData(
          title: '儿童隐私政策',
          value: '查看',
          icon: Icons.child_care_rounded,
        ),
        _SettingsDialogItemData(
          title: '上传日志',
          value: '帮助排查',
          icon: Icons.cloud_upload_rounded,
        ),
      ],
    ),
  ];

  showDialog<void>(
    context: context,
    builder: (context) => AdaptiveDialogScaffold(
      title: '系统设置',
      maxDialogWidth: 980,
      maxDialogHeight: 660,
      bodyBuilder: (context, screenType, dialogSize) {
        final useGrid =
            screenType != AppScreenType.mobile &&
            dialogSize.width >= 760 &&
            dialogSize.height >= 520;
        final cards = sections
            .map((section) => _SettingsDialogSection(section: section))
            .toList();

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE9F8FF), Color(0xFFFFF6CE)],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      color: Color(0xFF2E7BEF),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '把学习环境调舒服一点',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: const Color(0xFF15325F),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '账号、护眼、隐私和日志支持都在这里。',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFF5A718A),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: useGrid
                  ? GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.7,
                      children: cards,
                    )
                  : ListView.separated(
                      itemCount: cards.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) => cards[index],
                    ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/student-release-lab');
                    },
                    icon: const Icon(Icons.science_rounded),
                    label: const Text('发布诊断'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/settings');
                    },
                    icon: const Icon(Icons.open_in_full_rounded),
                    label: const Text('完整设置'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

class _SettingsDialogSectionData {
  const _SettingsDialogSectionData({
    required this.title,
    required this.accent,
    required this.icon,
    required this.items,
  });

  final String title;
  final Color accent;
  final IconData icon;
  final List<_SettingsDialogItemData> items;
}

class _SettingsDialogItemData {
  const _SettingsDialogItemData({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;
}

class _SettingsDialogSection extends StatelessWidget {
  const _SettingsDialogSection({required this.section});

  final _SettingsDialogSectionData section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: section.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(section.icon, color: section.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF15325F),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...section.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SettingsDialogItem(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

void _showStarCoinLedgerDialog(
  BuildContext context, {
  required int stars,
  required bool showGrowthRewards,
}) {
  final coinLabel = showGrowthRewards ? '星币' : '积分';
  final rows = [
    const StudentStarCoinLedgerRow(
      icon: Icons.play_circle_fill_rounded,
      title: '完成今日主线',
      subtitle: '优先完成老师布置的作业',
      amount: '+50',
      color: Color(0xFFFFB84D),
    ),
    const StudentStarCoinLedgerRow(
      icon: Icons.headphones_rounded,
      title: '听说写玩探索',
      subtitle: '前 10 分钟有奖励，之后不刷币',
      amount: '+10',
      color: Color(0xFF5DB9FF),
    ),
    StudentStarCoinLedgerRow(
      icon: Icons.card_giftcard_rounded,
      title: '魔法商店',
      subtitle: showGrowthRewards ? '兑换头像框和伴学宠物装扮' : '成长奖励开启后开放兑换',
      amount: '消费',
      color: const Color(0xFF8EEA78),
    ),
  ];

  _showDashboardContentDialog(
    context,
    title: '$coinLabel账单',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4CC),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFFF9F1C)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '当前拥有 $stars $coinLabel',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF17335F),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...rows.map(
          (row) =>
              Padding(padding: const EdgeInsets.only(bottom: 10), child: row),
        ),
      ],
    ),
  );
}

class _SettingsDialogItem extends StatelessWidget {
  const _SettingsDialogItem({required this.item});

  final _SettingsDialogItemData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FBFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: const Color(0xFF2C5E9E), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              item.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF3377D6),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideHomeLayout extends StatefulWidget {
  const _WideHomeLayout({
    required this.schoolContext,
    required this.currentUserEmail,
    required this.studentDisplayName,
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
  final String studentDisplayName;
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
    final size = MediaQuery.sizeOf(context);
    final layoutWidth = size.width;
    final layoutHeight = size.height;
    final preferWideRow = layoutWidth >= 720 && layoutHeight < 620;
    final useStackedWide =
        (layoutWidth < 1120 || layoutHeight < 640) && !preferWideRow;
    final useCompactWideDensity = layoutWidth < 980 || layoutHeight < 560;
    final useLowHeightWide = layoutHeight < 700;
    final sidePanelWidth = useStackedWide ? layoutWidth : 300.0;
    final sidePanelWideWidth = responsiveWidthCap(
      layoutWidth,
      fraction: useCompactWideDensity ? 0.22 : 0.24,
      min: useCompactWideDensity ? 220.0 : 260.0,
      max: 320.0,
    );
    final pages = [
      _WidePageFrame(
        child: useStackedWide
            ? Column(
                children: [
                  Expanded(
                    flex: useLowHeightWide ? 62 : 55,
                    child: _EntranceMotion(
                      delay: const Duration(milliseconds: 40),
                      child: _WideHeroStage(
                        child: _UnifiedHeroPanel(
                          schoolContext: widget.schoolContext,
                          studentDisplayName: widget.studentDisplayName,
                          highlightedActivityId: widget.highlightedActivityId,
                          highlightedActivityTitle:
                              widget.highlightedActivityTitle,
                          highlightedClassName: widget.highlightedClassName,
                          highlightedDateLabel: widget.highlightedDateLabel,
                          summary: widget.summary,
                          dailyGrowth: widget.dailyGrowth,
                          parentSummary: widget.parentSummary,
                          resumeSummary: widget.resumeSummary,
                          featureFlags: widget.featureFlags,
                          useCompactDensity: useCompactWideDensity,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: useLowHeightWide ? 8 : 12),
                  Expanded(
                    flex: useLowHeightWide ? 38 : 45,
                    child: _EntranceMotion(
                      delay: const Duration(milliseconds: 110),
                      child: StudentGlassSectionStage(
                        icon: Icons.dashboard_customize_rounded,
                        title: '听说写玩',
                        hint: '自由探索听、说、写、玩',
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
              )
            : Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: _EntranceMotion(
                      delay: const Duration(milliseconds: 40),
                      child: _WideHeroStage(
                        child: _UnifiedHeroPanel(
                          schoolContext: widget.schoolContext,
                          studentDisplayName: widget.studentDisplayName,
                          highlightedActivityId: widget.highlightedActivityId,
                          highlightedActivityTitle:
                              widget.highlightedActivityTitle,
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
                      child: StudentGlassSectionStage(
                        icon: Icons.dashboard_customize_rounded,
                        title: '听说写玩',
                        hint: '自由探索听、说、写、玩',
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
        child: useStackedWide
            ? Column(
                children: [
                  SizedBox(
                    height: useLowHeightWide
                        ? 176
                        : useCompactWideDensity
                        ? 220
                        : 248,
                    width: sidePanelWidth,
                    child: _EntranceMotion(
                      delay: const Duration(milliseconds: 80),
                      child: _WideSideStage(
                        child: _StudentUtilityDock(
                          currentUserEmail: widget.currentUserEmail,
                          studentDisplayName: widget.studentDisplayName,
                          highlightedActivityTitle:
                              widget.highlightedActivityTitle,
                          highlightedClassName: widget.highlightedClassName,
                          summary: widget.summary,
                          dailyGrowth: widget.dailyGrowth,
                          parentSummary: widget.parentSummary,
                          featureFlags: widget.featureFlags,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: useLowHeightWide ? 8 : 12),
                  Expanded(
                    child: _EntranceMotion(
                      delay: const Duration(milliseconds: 120),
                      child: StudentBoundarylessSectionStage(
                        icon: Icons.auto_stories_rounded,
                        title: '学习地图',
                        hint: '补星、拼读、阅读和星币兑换都在这里',
                        child: _WideLearningShowcaseArea(
                          summary: widget.summary,
                          highlightedActivityTitle:
                              widget.highlightedActivityTitle,
                          highlightedClassName: widget.highlightedClassName,
                          compact: useCompactWideDensity,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  SizedBox(
                    width: sidePanelWideWidth,
                    child: _EntranceMotion(
                      delay: const Duration(milliseconds: 80),
                      child: _WideSideStage(
                        child: _StudentUtilityDock(
                          currentUserEmail: widget.currentUserEmail,
                          studentDisplayName: widget.studentDisplayName,
                          highlightedActivityTitle:
                              widget.highlightedActivityTitle,
                          highlightedClassName: widget.highlightedClassName,
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
                      child: StudentBoundarylessSectionStage(
                        icon: Icons.auto_stories_rounded,
                        title: '学习地图',
                        hint: '补星、拼读、阅读和星币兑换都在这里',
                        child: _WideLearningShowcaseArea(
                          summary: widget.summary,
                          highlightedActivityTitle:
                              widget.highlightedActivityTitle,
                          highlightedClassName: widget.highlightedClassName,
                          compact: useCompactWideDensity,
                        ),
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
  const _DashboardHeaderChip({this.icon, required this.label});

  final IconData? icon;
  final String label;

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
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 120;
                      final isUltraNarrow = constraints.maxWidth < 48;
                      return Stack(
                        children: [
                          Positioned(
                            left: isNarrow ? 12 : 16,
                            right: isNarrow ? 12 : 16,
                            top: isNarrow ? 12 : 16,
                            child: Container(
                              height: compact ? 18 : 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE6B0),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          Positioned(
                            left: isNarrow ? 12 : 20,
                            right: isNarrow ? 12 : 24,
                            top: isNarrow
                                ? 34
                                : compact
                                ? 42
                                : 46,
                            child: isUltraNarrow
                                ? Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.92,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.search_rounded,
                                        color: Color(0xFF73B7FF),
                                        size: 12,
                                      ),
                                    ),
                                  )
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: List.generate(
                                            isNarrow ? 2 : 3,
                                            (index) => Padding(
                                              padding: EdgeInsets.only(
                                                bottom: isNarrow ? 6 : 8,
                                              ),
                                              child: Container(
                                                height: isNarrow ? 6 : 7,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFFD89A,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: isNarrow ? 8 : 14),
                                      Container(
                                        width: isNarrow
                                            ? 28
                                            : compact
                                            ? 52
                                            : 62,
                                        height: isNarrow
                                            ? 28
                                            : compact
                                            ? 52
                                            : 62,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.92,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            isNarrow ? 10 : 18,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.search_rounded,
                                          color: const Color(0xFF73B7FF),
                                          size: isNarrow ? 16 : 30,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      );
                    },
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final showHint = constraints.maxWidth >= 720;
        final hintText = currentIndex == 0
            ? '向左滑动看更多'
            : currentIndex == pageCount - 1
            ? '向右滑动返回上一屏'
            : '左右滑动切换内容';

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
            if (showHint) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  hintText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
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
      },
    );
  }
}

class _StudentUtilityDock extends StatelessWidget {
  const _StudentUtilityDock({
    required this.currentUserEmail,
    required this.studentDisplayName,
    required this.highlightedActivityTitle,
    required this.highlightedClassName,
    required this.summary,
    required this.dailyGrowth,
    required this.parentSummary,
    required this.featureFlags,
  });

  final String? currentUserEmail;
  final String studentDisplayName;
  final String highlightedActivityTitle;
  final String highlightedClassName;
  final PortalSummary summary;
  final DailyGrowthSummary dailyGrowth;
  final ParentContactSummary? parentSummary;
  final StudentFeatureFlags featureFlags;

  @override
  Widget build(BuildContext context) {
    final stars = _dailyStarCoins(summary, dailyGrowth, parentSummary);
    final actions = [
      StudentUtilityDockAction(
        icon: Icons.stars_rounded,
        label: featureFlags.showGrowthRewards ? '$stars 星币' : '$stars 积分',
        color: const Color(0xFFFFD447),
        onTap: () => _showProfileCenterDialog(
          context,
          currentUserEmail: currentUserEmail,
          studentDisplayName: studentDisplayName,
          highlightedActivityTitle: highlightedActivityTitle,
          highlightedClassName: highlightedClassName,
          summary: summary,
          dailyGrowth: dailyGrowth,
          parentSummary: parentSummary,
          featureFlags: featureFlags,
        ),
      ),
      StudentUtilityDockAction(
        icon: Icons.message_rounded,
        label: '消息',
        color: const Color(0xFF7DD3FC),
        onTap: () => context.go('/messages'),
      ),
      StudentUtilityDockAction(
        icon: Icons.settings_rounded,
        label: '设置',
        color: const Color(0xFF8EEA78),
        onTap: () => _showSettingsDialog(context, currentUserEmail),
      ),
      StudentUtilityDockAction(
        icon: Icons.info_rounded,
        label: '关于',
        color: const Color(0xFFA78BFA),
        onTap: () => _showAboutStudentDialog(context),
      ),
    ];

    return StudentUtilityDock(
      displayName: studentDisplayName,
      actions: actions,
    );
  }
}

class _WideHeroStage extends StatelessWidget {
  const _WideHeroStage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StudentGlassPanel(
      padding: const EdgeInsets.all(12),
      radius: 34,
      opacity: 0.2,
      child: child,
    );
  }
}

class _WideSideStage extends StatelessWidget {
  const _WideSideStage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _WideLearningShowcaseArea extends StatelessWidget {
  const _WideLearningShowcaseArea({
    required this.summary,
    required this.highlightedActivityTitle,
    required this.highlightedClassName,
    this.compact = false,
  });

  final PortalSummary summary;
  final String highlightedActivityTitle;
  final String highlightedClassName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = compact ? 12.0 : 18.0;
        final cards = [
          StudentLearningMapCard(
            title: '补星计划',
            ribbonLabel: '时光救援',
            statusLabel: summary.pendingTasks > 0 ? '3 天内可补' : '暂无漏补',
            accent: const Color(0xFFFFB84D),
            cover: _DashboardIllustration(
              style: _DashboardCoverStyle.taskCenter,
              accent: const Color(0xFFFFB84D),
              compact: compact,
            ),
            compact: compact,
            onTap: () => _showTaskCenterDialog(
              context,
              activityTitle: highlightedActivityTitle,
              className: highlightedClassName,
            ),
          ),
          StudentLearningMapCard(
            title: '自然拼读',
            ribbonLabel: 'Phonics',
            statusLabel: '字母音闯关',
            accent: const Color(0xFF73B7FF),
            cover: _DashboardIllustration(
              style: _DashboardCoverStyle.phonics,
              accent: const Color(0xFF73B7FF),
              compact: compact,
            ),
            compact: compact,
            onTap: () => context.go('/explore'),
          ),
          StudentLearningMapCard(
            title: '国家地理PM',
            ribbonLabel: '分级阅读',
            statusLabel: '拓展阅读',
            accent: const Color(0xFF87D76A),
            cover: _DashboardIllustration(
              style: _DashboardCoverStyle.gradedReading,
              accent: const Color(0xFF87D76A),
              compact: compact,
            ),
            compact: compact,
            onTap: () => context.go('/explore'),
          ),
          StudentLearningMapCard(
            title: '魔法商店',
            ribbonLabel: '积分兑换',
            statusLabel: '星币盲盒',
            accent: const Color(0xFFFFD447),
            cover: _DashboardIllustration(
              style: _DashboardCoverStyle.todayTask,
              accent: const Color(0xFFFFD447),
              compact: compact,
            ),
            compact: compact,
            onTap: () => context.go('/explore'),
          ),
        ];

        final cardWidth =
            constraints.maxWidth *
            (constraints.maxWidth >= 920
                ? 0.32
                : constraints.maxWidth >= 680
                ? 0.42
                : 0.58);
        final minCardWidth = compact ? 184.0 : 220.0;
        final maxCardWidth = compact ? 280.0 : 360.0;
        final resolvedCardWidth = cardWidth
            .clamp(minCardWidth, maxCardWidth)
            .toDouble();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                SizedBox(width: resolvedCardWidth, child: cards[index]),
                if (index != cards.length - 1) SizedBox(width: spacing),
              ],
              SizedBox(width: constraints.maxWidth * 0.16),
            ],
          ),
        );
      },
    );
  }
}

class _UnifiedHeroPanel extends StatelessWidget {
  const _UnifiedHeroPanel({
    required this.schoolContext,
    required this.studentDisplayName,
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
  final String studentDisplayName;
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
    void openMainline() => context.go('/activities/$highlightedActivityId');

    final completedTasks = dailyGrowth.completedTasks;
    final badgeText = resumeSummary.resumeTaskIndex != null
        ? '继续第 ${resumeSummary.resumeTaskIndex} 句'
        : completedTasks > 0
        ? '已完成 $completedTasks 句'
        : '今天开始闯关';
    final heroSubtitle = summary.pendingTasks > 0
        ? '还有 ${summary.pendingTasks} 项小任务等你完成'
        : '今天的主线任务已经准备好了';
    final metaLabel = '$highlightedClassName · $highlightedDateLabel';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLowHeight = constraints.maxHeight < 190;
        final isUltraLowHeight = constraints.maxHeight < 260;
        final compactDensity = useCompactDensity || isLowHeight;
        final heroTag = 'mainline-activity-$highlightedActivityId';

        if (isUltraLowHeight) {
          return Hero(
            tag: heroTag,
            transitionOnUserGestures: true,
            child: StudentFullCardTap(
              onTap: openMainline,
              borderRadius: 34,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF5DB9FF),
                      Color(0xFF2D8DFF),
                      Color(0xFF69D5FF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.34),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '今日主线',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$studentDisplayName 同学',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: const Color(0xFFFFF5C4),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '先完成今天作业',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 48,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: K12CartoonHeroScene(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Hero(
          tag: heroTag,
          transitionOnUserGestures: true,
          child: StudentFullCardTap(
            onTap: openMainline,
            borderRadius: 34,
            child: Container(
              padding: EdgeInsets.all(compactDensity ? 16 : 22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF5DB9FF),
                    Color(0xFF2D8DFF),
                    Color(0xFF69D5FF),
                  ],
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
                      width: compactDensity ? 88 : 108,
                      height: compactDensity ? 88 : 108,
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
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compactDensity ? 8 : 12),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: isUltraLowHeight
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '$studentDisplayName 同学',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: const Color(0xFFFFF5C4),
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '先完成今天作业',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$studentDisplayName 同学',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                color: const Color(0xFFFFF5C4),
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        SizedBox(
                                          height: compactDensity ? 4 : 6,
                                        ),
                                        Text(
                                          '先完成这份作业',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                height: 1.05,
                                              ),
                                        ),
                                        if (!isLowHeight) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            heroSubtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.94),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                        const Spacer(),
                                        Wrap(
                                          spacing: compactDensity ? 8 : 10,
                                          runSpacing: compactDensity ? 8 : 10,
                                          children: [
                                            K12HeroBadge(
                                              icon: Icons.play_circle_rounded,
                                              label: badgeText,
                                            ),
                                            if (!isLowHeight)
                                              K12HeroBadge(
                                                icon: Icons.class_rounded,
                                                label: metaLabel,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                            ),
                            SizedBox(width: compactDensity ? 8 : 14),
                            SizedBox(
                              width: isUltraLowHeight
                                  ? 48
                                  : compactDensity
                                  ? 86
                                  : 128,
                              child: const AspectRatio(
                                aspectRatio: 1,
                                child: K12CartoonHeroScene(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compactDensity ? 8 : 12),
                      _HeroWholeCardHint(
                        compact: compactDensity,
                        label: resumeSummary.resumeTaskIndex == null
                            ? '点击整张卡片开始今天的任务'
                            : '点击整张卡片继续第 ${resumeSummary.resumeTaskIndex} 句',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroWholeCardHint extends StatelessWidget {
  const _HeroWholeCardHint({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 9 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_rounded,
            color: Colors.white,
            size: compact ? 18 : 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: compact ? 14 : null,
              ),
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
        final tight = constraints.maxWidth < 520 || constraints.maxHeight < 330;
        final spacing = tight
            ? 8.0
            : isCompact
            ? 10.0
            : 12.0;
        final useCompactSummaryStrip = constraints.maxHeight < 190;

        final cards = [
          StudentAbilityActionCard(
            title: '听',
            value: '${summary.inProgressActivities} 段',
            subtitle: '儿歌绘本磨耳朵',
            color: const Color(0xFF5DB9FF),
            icon: Icons.headphones_rounded,
            isCompact: isCompact,
            onTap: () => context.go('/explore?tab=ability'),
          ),
          StudentAbilityActionCard(
            title: '说',
            value: comboCount > 0
                ? '$comboCount 连对'
                : '${summary.pendingTasks} 项',
            subtitle: '情景口语开口练',
            color: const Color(0xFFFFC941),
            icon: Icons.record_voice_over_rounded,
            isCompact: isCompact,
            onTap: () => context.go('/explore?tab=ability'),
          ),
          StudentAbilityActionCard(
            title: '写',
            value: completedTasks > 0 ? '$completedTasks 句' : '作品',
            subtitle: '拍照作品与描红',
            color: const Color(0xFF78E55A),
            icon: Icons.edit_note_rounded,
            isCompact: isCompact,
            onTap: () => context.go('/explore?tab=ability'),
          ),
          StudentAbilityActionCard(
            title: '玩',
            value: featureFlags.showGrowthRewards
                ? dailyStars > 0
                      ? '$dailyStars 星币'
                      : '${summary.completedActivities} 枚'
                : completedTasks > 0
                ? '$completedTasks 句'
                : '${summary.pendingTasks} 项',
            subtitle: '错词小游戏',
            color: const Color(0xFF55D9C5),
            icon: Icons.extension_rounded,
            isCompact: isCompact,
            onTap: () => context.go('/explore?tab=ability'),
          ),
        ];

        if (useCompactSummaryStrip) {
          final compactCards = cards.take(2).toList();
          return Row(
            children: [
              for (var index = 0; index < compactCards.length; index++) ...[
                if (index > 0) SizedBox(width: spacing),
                Expanded(child: compactCards[index]),
              ],
            ],
          );
        }

        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: cards[0]),
                  SizedBox(width: spacing),
                  Expanded(child: cards[1]),
                ],
              ),
            ),
            SizedBox(height: spacing),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: cards[2]),
                  SizedBox(width: spacing),
                  Expanded(child: cards[3]),
                ],
              ),
            ),
          ],
        );
      },
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
