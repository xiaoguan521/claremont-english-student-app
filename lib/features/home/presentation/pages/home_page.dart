import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../portal/presentation/providers/portal_providers.dart';
import '../../../portal/presentation/widgets/tablet_shell.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightedActivityAsync = ref.watch(highlightedActivityProvider);
    final summaryAsync = ref.watch(portalSummaryProvider);
    final currentUserEmail = ref.watch(currentUserEmailProvider);

    Widget child;
    if (highlightedActivityAsync.isLoading || summaryAsync.isLoading) {
      child = const Center(child: CircularProgressIndicator());
    } else if (highlightedActivityAsync.hasError || summaryAsync.hasError) {
      child = _StateMessage(
        title: '数据加载失败',
        message: '请检查登录状态或稍后重试。',
      );
    } else {
      final highlightedActivity = highlightedActivityAsync.valueOrNull;
      final summary = summaryAsync.valueOrNull;

      if (highlightedActivity == null || summary == null) {
        child = const _StateMessage(title: '暂无活动', message: '老师发布作业后会显示在这里。');
      } else {
        child = LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1180;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: isWide
                    ? _WidePortal(
                        currentUserEmail: currentUserEmail,
                        highlightedActivityId: highlightedActivity.id,
                        activeClasses: summary.activeClasses,
                        reviewPending: summary.reviewPending,
                      )
                    : _CompactPortal(
                        currentUserEmail: currentUserEmail,
                        highlightedActivityId: highlightedActivity.id,
                        activeClasses: summary.activeClasses,
                        reviewPending: summary.reviewPending,
                      ),
              ),
            );
          },
        );
      }
    }

    return TabletShell(
      activeSection: TabletSection.management,
      title: '管理工作台',
      subtitle: '英语 | 平板门户',
      actions: const [
        _ActionPill(icon: Icons.chat_bubble_rounded, label: '消息', badge: true),
        SizedBox(width: 12),
        _ActionPill(icon: Icons.settings_rounded, label: '设置', badge: true),
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

class _WidePortal extends StatelessWidget {
  final String? currentUserEmail;
  final String highlightedActivityId;
  final int activeClasses;
  final int reviewPending;

  const _WidePortal({
    required this.currentUserEmail,
    required this.highlightedActivityId,
    required this.activeClasses,
    required this.reviewPending,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _ProfilePanel(
                currentUserEmail: currentUserEmail,
                activeClasses: activeClasses,
              ),
              const SizedBox(height: 18),
              _PromoPanel(
                title: '活动比赛',
                subtitle: '学校动态 | 小程序',
                accent: const Color(0xFFFF8C74),
                actions: [
                  _MiniActionCard(
                    title: '学校动态',
                    color: const Color(0xFF54B8F0),
                    icon: Icons.campaign_rounded,
                    onTap: () {},
                  ),
                  _MiniActionCard(
                    title: '小程序',
                    color: const Color(0xFF12C59C),
                    icon: Icons.apps_rounded,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 7,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _BigFeatureCard(
                      title: '学员管理',
                      subtitle: '学生档案、分班、学习轨迹',
                      accent: const Color(0xFF73B7FF),
                      icon: Icons.people_alt_rounded,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _BigFeatureCard(
                      title: '我的班级',
                      subtitle: '当前管理 $activeClasses 个班级',
                      accent: const Color(0xFF8FEA6B),
                      icon: Icons.groups_rounded,
                      onTap: () => context.go('/activities'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _DataCenterPanel(
                      title: '数据中心',
                      subtitle: '待点评 $reviewPending 个，点开查看提交趋势',
                      onTap: () => context.go('/activities'),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _StackMenuCard(
                          title: '课程管理',
                          color: const Color(0xFF83B1FF),
                          icon: Icons.auto_stories_rounded,
                          onTap: () =>
                              context.go('/activities/$highlightedActivityId'),
                        ),
                        const SizedBox(height: 18),
                        _StackMenuCard(
                          title: '学员课时',
                          color: const Color(0xFF7DD8E6),
                          icon: Icons.schedule_rounded,
                          onTap: () {},
                        ),
                        const SizedBox(height: 18),
                        _StackMenuCard(
                          title: '约课管理',
                          color: const Color(0xFFA6B6FF),
                          icon: Icons.calendar_month_rounded,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactPortal extends StatelessWidget {
  final String? currentUserEmail;
  final String highlightedActivityId;
  final int activeClasses;
  final int reviewPending;

  const _CompactPortal({
    required this.currentUserEmail,
    required this.highlightedActivityId,
    required this.activeClasses,
    required this.reviewPending,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProfilePanel(
          currentUserEmail: currentUserEmail,
          activeClasses: activeClasses,
        ),
        const SizedBox(height: 18),
        _BigFeatureCard(
          title: '学员管理',
          subtitle: '学生档案、分班、学习轨迹',
          accent: const Color(0xFF73B7FF),
          icon: Icons.people_alt_rounded,
          onTap: () {},
        ),
        const SizedBox(height: 18),
        _BigFeatureCard(
          title: '我的班级',
          subtitle: '当前管理 $activeClasses 个班级',
          accent: const Color(0xFF8FEA6B),
          icon: Icons.groups_rounded,
          onTap: () => context.go('/activities'),
        ),
        const SizedBox(height: 18),
        _DataCenterPanel(
          title: '数据中心',
          subtitle: '待点评 $reviewPending 个，点开查看提交趋势',
          onTap: () => context.go('/activities'),
        ),
        const SizedBox(height: 18),
        _PromoPanel(
          title: '活动比赛',
          subtitle: '学校动态 | 小程序',
          accent: const Color(0xFFFF8C74),
          actions: [
            _MiniActionCard(
              title: '学校动态',
              color: const Color(0xFF54B8F0),
              icon: Icons.campaign_rounded,
              onTap: () {},
            ),
            _MiniActionCard(
              title: '小程序',
              color: const Color(0xFF12C59C),
              icon: Icons.apps_rounded,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.currentUserEmail,
    required this.activeClasses,
  });

  final String? currentUserEmail;
  final int activeClasses;

  @override
  Widget build(BuildContext context) {
    final displayName = _displayNameFromEmail(currentUserEmail);
    final roleLabel = currentUserEmail == null ? '访客模式' : '机构管理员';

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF57A5FF), Color(0xFF3E6EF7)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                '个人中心',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.account_circle_rounded,
                  size: 48,
                  color: Color(0xFF6286E3),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF172554),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    roleLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF4B5563),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (currentUserEmail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      currentUserEmail!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFFE5E7EB), height: 1),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ProfileStat(
                label: '荣誉',
                value: '240',
                icon: Icons.star_border_rounded,
              ),
              _ProfileStat(label: '待办', value: '9', icon: Icons.tune_rounded),
              _ProfileStat(
                label: '班级',
                value: '$activeClasses',
                icon: Icons.workspace_premium_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _displayNameFromEmail(String? email) {
    if (email == null || email.isEmpty) {
      return '访客用户';
    }

    final username = email.split('@').first.trim();
    if (username.isEmpty) {
      return '机构账号';
    }

    return username[0].toUpperCase() + username.substring(1);
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF203A7A), size: 34),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF4B5563),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: const Color(0xFF6B7280),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PromoPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final List<Widget> actions;

  const _PromoPanel({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.78)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(children: actions.map((item) => Expanded(child: item)).toList()),
        ],
      ),
    );
  }
}

class _MiniActionCard extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _MiniActionCard({
    required this.title,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 34),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigFeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  const _BigFeatureCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(34),
      child: _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 184,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.75)],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(child: Icon(icon, size: 96, color: Colors.white)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF172554),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataCenterPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DataCenterPanel({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(34),
      child: _GlassCard(
        child: Container(
          height: 360,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF94E7C1), Color(0xFFE7F6CC)],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Center(
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.32),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 70,
                        height: 90,
                        color: const Color(0xFFF59E0B),
                      ),
                      Positioned(
                        left: 44,
                        bottom: 48,
                        child: Container(
                          width: 46,
                          height: 58,
                          color: const Color(0xFFF87171),
                        ),
                      ),
                      Positioned(
                        right: 44,
                        bottom: 58,
                        child: Container(
                          width: 50,
                          height: 92,
                          color: const Color(0xFF60A5FA),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF4B3B27),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF6B4F34),
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StackMenuCard extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StackMenuCard({
    required this.title,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 34, color: Colors.white),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
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

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool badge;

  const _ActionPill({
    required this.icon,
    required this.label,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (badge)
          Positioned(
            top: 2,
            right: 4,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFFFF4D4F),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
