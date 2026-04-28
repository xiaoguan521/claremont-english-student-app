import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/ui/app_ui_tokens.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../portal/presentation/widgets/tablet_shell.dart';
import '../../../school/presentation/providers/school_context_provider.dart';
import '../../../student/presentation/providers/student_identity_provider.dart';
import '../../../student/presentation/widgets/student_page_gestures.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eyeComfortEnabled = ref.watch(eyeComfortModeProvider);
    final authState = ref.watch(authProvider);
    final currentUserEmail = ref.watch(currentUserEmailProvider);
    final appConfig = ref.watch(appConfigProvider);
    final schoolContext =
        ref.watch(schoolContextProvider).valueOrNull ??
        SchoolContext.fallback();

    return StudentPageGestures(
      onSwipeBack: () => context.go('/home'),
      child: TabletShell(
        activeSection: TabletSection.management,
        brandName: schoolContext.displayName,
        brandLogoUrl: schoolContext.logoUrl,
        brandSubtitle: '英语学习',
        title: '系统设置',
        subtitle: '账号、护眼、隐私和应用支持',
        theme: TabletShellTheme.k12Sky,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow =
                constraints.maxWidth <
                AppUiTokens.studentSettingsCompactBreakpoint;
            final leftColumn = Column(
              children: [
                _SettingsHeroCard(
                  email: currentUserEmail ?? 'student@claremont.local',
                  schoolName: schoolContext.displayName,
                  isAuthenticated: authState.isAuthenticated,
                ),
                const SizedBox(height: AppUiTokens.spaceMd),
                _SettingsSectionCard(
                  title: '账号与学校',
                  subtitle: '管理学习身份和学校入口',
                  icon: Icons.school_rounded,
                  accent: AppUiTokens.studentAccentBlue,
                  children: [
                    _SettingsActionTile(
                      title: '当前账号',
                      value: currentUserEmail ?? '未登录',
                      icon: Icons.person_rounded,
                    ),
                    _SettingsActionTile(
                      title: '学校学习入口',
                      value: schoolContext.displayName,
                      icon: Icons.auto_stories_rounded,
                    ),
                    _SettingsActionTile(
                      title: '切换学校',
                      value: '重新选择',
                      icon: Icons.swap_horiz_rounded,
                      onTap: () => context.go('/school-select'),
                    ),
                  ],
                ),
              ],
            );

            final rightColumn = Column(
              children: [
                _SettingsSectionCard(
                  title: '学习保护',
                  subtitle: '把学习节奏调得更适合孩子',
                  icon: Icons.health_and_safety_rounded,
                  accent: AppUiTokens.studentAccentGreen,
                  children: [
                    _SettingsSwitchTile(
                      title: '柔和护眼模式',
                      subtitle: '降低视觉刺激，适合晚上或长时间学习',
                      value: eyeComfortEnabled,
                      onChanged: (value) => ref
                          .read(eyeComfortModeProvider.notifier)
                          .setEnabled(value),
                    ),
                    const _SettingsActionTile(
                      title: '专注休息提醒',
                      value: '20 分钟提醒',
                      icon: Icons.timer_rounded,
                    ),
                    const _SettingsActionTile(
                      title: '麦克风权限',
                      value: '用于跟读录音',
                      icon: Icons.mic_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: AppUiTokens.spaceMd),
                const _SettingsSectionCard(
                  title: '隐私与支持',
                  subtitle: '儿童数据、版本和问题反馈',
                  icon: Icons.verified_user_rounded,
                  accent: AppUiTokens.studentAccentYellow,
                  children: [
                    _SettingsActionTile(
                      title: '儿童隐私政策',
                      value: '查看',
                      icon: Icons.child_care_rounded,
                    ),
                    _SettingsActionTile(
                      title: '服务使用协议',
                      value: '查看',
                      icon: Icons.description_rounded,
                    ),
                    _SettingsActionTile(
                      title: '上传日志',
                      value: '帮助老师排查问题',
                      icon: Icons.cloud_upload_rounded,
                    ),
                    _SettingsActionTile(
                      title: '当前版本',
                      value: '1.0.0+1',
                      icon: Icons.info_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: AppUiTokens.spaceMd),
                _SettingsSectionCard(
                  title: '发布诊断',
                  subtitle: appConfig.canUseSupabase
                      ? '当前使用真实学习数据'
                      : '当前处于演示数据模式',
                  icon: Icons.science_rounded,
                  accent: AppUiTokens.studentAccentPurple,
                  children: [
                    _SettingsActionTile(
                      title: '数据模式',
                      value: appConfig.dataMode == AppDataMode.supabase
                          ? 'Supabase'
                          : 'Mock',
                      icon: Icons.storage_rounded,
                    ),
                    _SettingsActionTile(
                      title: '学生端发布实验室',
                      value: '内部诊断',
                      icon: Icons.tune_rounded,
                      onTap: () => context.go('/student-release-lab'),
                    ),
                  ],
                ),
                const SizedBox(height: AppUiTokens.spaceMd),
                _LogoutButton(
                  isAuthenticated: authState.isAuthenticated,
                  onPressed: authState.isAuthenticated
                      ? () async {
                          await ref
                              .read(selectedStudentProfileProvider.notifier)
                              .clear();
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) {
                            context.go('/login');
                          }
                        }
                      : () => context.go('/login'),
                ),
              ],
            );

            if (isNarrow) {
              return ListView(
                padding: const EdgeInsets.only(bottom: AppUiTokens.spaceXl),
                children: [
                  leftColumn,
                  const SizedBox(height: AppUiTokens.spaceMd),
                  rightColumn,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: AppUiTokens.studentPrimaryPaneFlex,
                  child: leftColumn,
                ),
                const SizedBox(width: AppUiTokens.spaceLg - 2),
                Expanded(
                  flex: AppUiTokens.studentSecondaryPaneFlex,
                  child: ListView(children: [rightColumn]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingsHeroCard extends StatelessWidget {
  const _SettingsHeroCard({
    required this.email,
    required this.schoolName,
    required this.isAuthenticated,
  });

  final String email;
  final String schoolName;
  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, AppUiTokens.studentPanelBlue],
        ),
        borderRadius: BorderRadius.circular(AppUiTokens.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        boxShadow: const [
          BoxShadow(
            color: AppUiTokens.studentHeroShadow,
            blurRadius: AppUiTokens.spaceXl,
            offset: Offset(0, AppUiTokens.spaceMd - 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppUiTokens.studentAvatarBlue,
                      AppUiTokens.studentAccentGreen,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppUiTokens.space2xl),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(width: AppUiTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'student 同学',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppUiTokens.studentInk,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: AppUiTokens.spaceXs - 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppUiTokens.studentMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUiTokens.radiusMd),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusPill(
                icon: Icons.school_rounded,
                label: schoolName,
                color: AppUiTokens.studentAccentBlue,
              ),
              _StatusPill(
                icon: isAuthenticated
                    ? Icons.verified_rounded
                    : Icons.login_rounded,
                label: isAuthenticated ? '已登录' : '未登录',
                color: isAuthenticated
                    ? AppUiTokens.studentSuccess
                    : AppUiTokens.studentAccentYellow,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppUiTokens.radiusLg + 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppUiTokens.radiusSm),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: AppUiTokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppUiTokens.studentInk,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppUiTokens.space2xs - 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppUiTokens.studentMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUiTokens.spaceMd),
          ...children.expand((child) sync* {
            yield child;
            if (child != children.last) {
              yield const SizedBox(height: AppUiTokens.spaceSm - 2);
            }
          }),
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _SettingsTileSurface(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppUiTokens.studentAccentBlue),
          const SizedBox(width: AppUiTokens.spaceSm),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppUiTokens.studentInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppUiTokens.spaceSm - 2),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppUiTokens.studentAccentBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppUiTokens.spaceXs - 2),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppUiTokens.studentAccentBlue,
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsTileSurface(
      child: Row(
        children: [
          const Icon(
            Icons.visibility_rounded,
            color: AppUiTokens.studentAccentBlue,
          ),
          const SizedBox(width: AppUiTokens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppUiTokens.studentInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppUiTokens.space2xs - 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppUiTokens.studentMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SettingsTileSurface extends StatelessWidget {
  const _SettingsTileSurface({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surface = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppUiTokens.studentTileSoft,
        borderRadius: BorderRadius.circular(AppUiTokens.radiusMd),
        border: Border.all(color: AppUiTokens.studentTileBorder),
      ),
      child: child,
    );

    if (onTap == null) {
      return surface;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppUiTokens.radiusMd),
        child: surface,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppUiTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppUiTokens.spaceXs - 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppUiTokens.studentInk,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.isAuthenticated, required this.onPressed});

  final bool isAuthenticated;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: isAuthenticated
              ? AppUiTokens.studentAccentOrange
              : AppUiTokens.studentAccentBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppUiTokens.spaceMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUiTokens.spaceXl),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(isAuthenticated ? Icons.logout_rounded : Icons.login),
        label: Text(isAuthenticated ? '退出当前账号' : '去登录'),
      ),
    );
  }
}
