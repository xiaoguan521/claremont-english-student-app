import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_ui_tokens.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../portal/presentation/providers/parent_contact_providers.dart';
import '../../../portal/presentation/providers/portal_providers.dart';
import '../../../portal/presentation/providers/student_feature_flags_provider.dart';
import '../../../portal/presentation/widgets/tablet_shell.dart';
import '../providers/student_identity_provider.dart';
import '../widgets/student_dashboard_dialog_widgets.dart';
import '../widgets/student_page_gestures.dart';
import '../widgets/student_ui_components.dart';

class StudentProfilePage extends ConsumerWidget {
  const StudentProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(portalSummaryProvider).valueOrNull;
    final dailyGrowth = ref.watch(dailyGrowthSummaryProvider).valueOrNull;
    final activity = ref.watch(highlightedActivityProvider).valueOrNull;
    final flags = ref.watch(studentFeatureFlagsProvider);
    final email = ref.watch(currentUserEmailProvider);
    final selectedId = ref.watch(selectedStudentProfileProvider);
    final profiles =
        ref.watch(availableStudentProfilesProvider).valueOrNull ??
        const <StudentIdentityProfile>[];
    StudentIdentityProfile? selectedProfile;
    for (final profile in profiles) {
      if (profile.id == selectedId) {
        selectedProfile = profile;
        break;
      }
    }
    final displayName = selectedProfile?.displayName ?? _fallbackName(email);
    final parentSummary = activity == null
        ? null
        : ref.watch(parentContactSummaryProvider(activity.id)).valueOrNull;
    final stars = flags.showGrowthRewards
        ? (parentSummary?.earnedStars ?? 0)
        : (dailyGrowth?.completedTasks ?? 0);

    return StudentPageGestures(
      onSwipeBack: () => context.go('/home'),
      child: TabletShell(
        activeSection: TabletSection.management,
        title: '个人中心',
        subtitle: '只保留孩子最常用的工具',
        theme: TabletShellTheme.k12Sky,
        child: Padding(
          padding: const EdgeInsets.all(AppUiTokens.spaceLg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth <
                  AppUiTokens.studentProfileCompactBreakpoint;
              final profileCard = _ProfileOverviewCard(
                displayName: displayName,
                email: email ?? 'student@claremont.local',
                stars: stars,
                completedTasks: dailyGrowth?.completedTasks ?? 0,
                bestCombo: dailyGrowth?.bestCombo ?? 0,
              );
              final tools = _ProfileToolsPanel(
                stars: stars,
                showGrowthRewards: flags.showGrowthRewards,
                pendingMessages: summary?.pendingTasks ?? 0,
                onMessages: () => context.go('/messages'),
                onSettings: () => context.go('/settings'),
                onAbout: () => _showAbout(context),
              );

              if (compact) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: AppUiTokens.studentProfileCompactCardHeight,
                        child: profileCard,
                      ),
                      const SizedBox(height: AppUiTokens.spaceMd),
                      SizedBox(
                        height: AppUiTokens.studentProfileCompactToolsHeight,
                        child: tools,
                      ),
                    ],
                  ),
                );
              }

              return Row(
                children: [
                  Expanded(
                    flex: AppUiTokens.studentPrimaryPaneFlex,
                    child: profileCard,
                  ),
                  const SizedBox(width: AppUiTokens.spaceLg),
                  Expanded(
                    flex: AppUiTokens.studentSecondaryPaneFlex,
                    child: tools,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _fallbackName(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'student同学';
    }
    return '${email.split('@').first}同学';
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于英语打卡'),
        content: const Text('K12 英语陪伴式学习应用。当前演示版已开启学生端首页、作业、点评和个人工具闭环。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道啦'),
          ),
        ],
      ),
    );
  }
}

class _ProfileOverviewCard extends StatelessWidget {
  const _ProfileOverviewCard({
    required this.displayName,
    required this.email,
    required this.stars,
    required this.completedTasks,
    required this.bestCombo,
  });

  final String displayName;
  final String email;
  final int stars;
  final int completedTasks;
  final int bestCombo;

  @override
  Widget build(BuildContext context) {
    return StudentGlassPanel(
      opacity: 0.2,
      padding: const EdgeInsets.all(AppUiTokens.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StudentSectionPill(icon: Icons.person_rounded, label: '我的'),
          const Spacer(),
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.white.withValues(alpha: 0.72),
            child: const Icon(
              Icons.face_rounded,
              size: 52,
              color: AppUiTokens.studentAccentBlue,
            ),
          ),
          const SizedBox(height: AppUiTokens.spaceLg),
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: AppUiTokens.studentInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppUiTokens.spaceXs),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppUiTokens.studentMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppUiTokens.spaceLg),
          Row(
            children: [
              Expanded(
                child: StudentStarCoinLedgerRow(
                  icon: Icons.stars_rounded,
                  title: '$stars 星币',
                  subtitle: '今日学习奖励',
                  amount: '+$stars',
                  color: AppUiTokens.studentAccentYellow,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUiTokens.spaceSm),
          Text(
            '今天完成 $completedTasks 项 · 最佳连对 $bestCombo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppUiTokens.studentAccentBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileToolsPanel extends StatelessWidget {
  const _ProfileToolsPanel({
    required this.stars,
    required this.showGrowthRewards,
    required this.pendingMessages,
    required this.onMessages,
    required this.onSettings,
    required this.onAbout,
  });

  final int stars;
  final bool showGrowthRewards;
  final int pendingMessages;
  final VoidCallback onMessages;
  final VoidCallback onSettings;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final tools = [
      _ProfileTool(Icons.stars_rounded, '星币', '$stars 枚'),
      _ProfileTool(
        Icons.message_rounded,
        '消息',
        '$pendingMessages 条提醒',
        onMessages,
      ),
      _ProfileTool(Icons.settings_rounded, '设置', '护眼与账号', onSettings),
      _ProfileTool(Icons.info_rounded, '关于', '版本与隐私', onAbout),
    ];

    return StudentBoundarylessSectionStage(
      icon: Icons.widgets_rounded,
      title: '工具入口',
      hint: '个人中心不承载学习任务',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth <
              AppUiTokens.studentProfileToolCompactBreakpoint;
          final gridHeight = compact
              ? AppUiTokens.studentProfileCompactToolGridHeight
              : (constraints.maxHeight *
                        AppUiTokens.studentProfileToolGridHeightFactor)
                    .clamp(
                      AppUiTokens.studentProfileToolGridMinHeight,
                      AppUiTokens.studentProfileToolGridMaxHeight,
                    );
          return Column(
            children: [
              SizedBox(
                height: gridHeight,
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: AppUiTokens.spaceMd,
                  mainAxisSpacing: AppUiTokens.spaceMd,
                  childAspectRatio: compact
                      ? AppUiTokens.studentProfileToolGridCompactAspectRatio
                      : AppUiTokens.studentProfileToolGridAspectRatio,
                  children: [
                    for (final tool in tools) _ProfileToolCard(tool: tool),
                  ],
                ),
              ),
              const SizedBox(height: AppUiTokens.spaceMd),
              Expanded(
                child: _StarCoinLedgerPanel(
                  stars: stars,
                  showGrowthRewards: showGrowthRewards,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StarCoinLedgerPanel extends StatelessWidget {
  const _StarCoinLedgerPanel({
    required this.stars,
    required this.showGrowthRewards,
  });

  final int stars;
  final bool showGrowthRewards;

  @override
  Widget build(BuildContext context) {
    final coinLabel = showGrowthRewards ? '星币' : '积分';
    final rows = [
      const StudentStarCoinLedgerRow(
        icon: Icons.play_circle_fill_rounded,
        title: '完成今日主线',
        subtitle: '老师布置的作业是最高收益来源',
        amount: '+50',
        color: AppUiTokens.studentAccentYellow,
      ),
      const StudentStarCoinLedgerRow(
        icon: Icons.headphones_rounded,
        title: '听说写玩探索',
        subtitle: '前 10 分钟获得少量奖励，防止刷币',
        amount: '+10',
        color: AppUiTokens.studentAccentBlue,
      ),
      StudentStarCoinLedgerRow(
        icon: Icons.card_giftcard_rounded,
        title: showGrowthRewards ? '魔法商店消费' : '成长奖励预览',
        subtitle: showGrowthRewards ? '仅兑换虚拟头像框和伴学宠物装扮' : '当前以积分记录成长，不兑换现实物品',
        amount: showGrowthRewards ? '消费' : '记录',
        color: AppUiTokens.studentAccentGreen,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppUiTokens.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppUiTokens.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.66)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppUiTokens.studentAccentYellow,
              ),
              const SizedBox(width: AppUiTokens.spaceXs),
              Expanded(
                child: Text(
                  '$coinLabel账单',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppUiTokens.studentInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$stars $coinLabel',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppUiTokens.studentAccentBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUiTokens.spaceSm),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) => rows[index],
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppUiTokens.spaceXs),
              itemCount: rows.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileToolCard extends StatelessWidget {
  const _ProfileToolCard({required this.tool});

  final _ProfileTool tool;

  @override
  Widget build(BuildContext context) {
    final card = Ink(
      padding: const EdgeInsets.all(AppUiTokens.spaceLg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppUiTokens.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.66)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tool.icon, color: AppUiTokens.studentAccentBlue),
          const Spacer(),
          Text(
            tool.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppUiTokens.studentInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppUiTokens.space2xs),
          Text(
            tool.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppUiTokens.studentMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (tool.onTap == null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppUiTokens.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: card,
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppUiTokens.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: tool.onTap, child: card),
    );
  }
}

class _ProfileTool {
  const _ProfileTool(this.icon, this.title, this.subtitle, [this.onTap]);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}
