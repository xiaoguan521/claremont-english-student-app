import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../portal/presentation/widgets/tablet_shell.dart';
import '../../../school/presentation/providers/school_context_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeNotifierProvider);
    final authState = ref.watch(authProvider);
    final currentUserEmail = ref.watch(currentUserEmailProvider);
    final appConfig = ref.watch(appConfigProvider);
    final schoolContext =
        ref.watch(schoolContextProvider).valueOrNull ??
        SchoolContext.fallback();

    return TabletShell(
      activeSection: TabletSection.management,
      brandName: schoolContext.displayName,
      brandLogoUrl: schoolContext.logoUrl,
      brandSubtitle: '英语学习',
      title: '系统设置',
      subtitle: '账号、护眼、隐私和应用支持',
      theme: TabletShellTheme.k12Sky,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 920;
          final leftColumn = Column(
            children: [
              _SettingsHeroCard(
                email: currentUserEmail ?? 'student@claremont.local',
                schoolName: schoolContext.displayName,
                isAuthenticated: authState.isAuthenticated,
              ),
              const SizedBox(height: 16),
              _SettingsSectionCard(
                title: '账号与学校',
                subtitle: '管理学习身份和学校入口',
                icon: Icons.school_rounded,
                accent: const Color(0xFF4AA7FF),
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
                accent: const Color(0xFF6BD85F),
                children: [
                  _SettingsSwitchTile(
                    title: '柔和护眼模式',
                    subtitle: '降低视觉刺激，适合晚上或长时间学习',
                    value: themeState.themeMode != ThemeMode.dark,
                    onChanged: (_) => ref
                        .read(themeNotifierProvider.notifier)
                        .setThemeMode(ThemeMode.light),
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
              const SizedBox(height: 16),
              const _SettingsSectionCard(
                title: '隐私与支持',
                subtitle: '儿童数据、版本和问题反馈',
                icon: Icons.verified_user_rounded,
                accent: Color(0xFFFFB84D),
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
              const SizedBox(height: 16),
              _SettingsSectionCard(
                title: '发布诊断',
                subtitle: appConfig.canUseSupabase
                    ? '当前使用真实学习数据'
                    : '当前处于演示数据模式',
                icon: Icons.science_rounded,
                accent: const Color(0xFF8B5CF6),
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
              const SizedBox(height: 16),
              _LogoutButton(
                isAuthenticated: authState.isAuthenticated,
                onPressed: authState.isAuthenticated
                    ? () async {
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
              padding: const EdgeInsets.only(bottom: 24),
              children: [leftColumn, const SizedBox(height: 16), rightColumn],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 42, child: leftColumn),
              const SizedBox(width: 18),
              Expanded(flex: 58, child: ListView(children: [rightColumn])),
            ],
          );
        },
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
          colors: [Color(0xFFFFFFFF), Color(0xFFEAF8FF)],
        ),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2C84D2),
            blurRadius: 24,
            offset: Offset(0, 14),
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
                    colors: [Color(0xFF8EDBFF), Color(0xFF75E28A)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(width: 16),
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
                            color: const Color(0xFF15325F),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF5A718A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusPill(
                icon: Icons.school_rounded,
                label: schoolName,
                color: const Color(0xFF4AA7FF),
              ),
              _StatusPill(
                icon: isAuthenticated
                    ? Icons.verified_rounded
                    : Icons.login_rounded,
                label: isAuthenticated ? '已登录' : '未登录',
                color: isAuthenticated
                    ? const Color(0xFF34C759)
                    : const Color(0xFFFFB84D),
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
        borderRadius: BorderRadius.circular(30),
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
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF15325F),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
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
          const SizedBox(height: 16),
          ...children.expand((child) sync* {
            yield child;
            if (child != children.last) {
              yield const SizedBox(height: 10);
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
          Icon(icon, color: const Color(0xFF2C5E9E)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF17233F),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF3377D6),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF3377D6)),
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
          const Icon(Icons.visibility_rounded, color: Color(0xFF2C5E9E)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF17233F),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
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
        color: const Color(0xFFF5FBFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0F2FE)),
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
        borderRadius: BorderRadius.circular(22),
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
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF15325F),
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
              ? const Color(0xFFFF8F4D)
              : const Color(0xFF4AA7FF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(isAuthenticated ? Icons.logout_rounded : Icons.login),
        label: Text(isAuthenticated ? '退出当前账号' : '去登录'),
      ),
    );
  }
}
