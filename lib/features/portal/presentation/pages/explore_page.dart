import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../home/presentation/widgets/k12_dashboard_widgets.dart';
import '../../../student/presentation/widgets/student_ui_components.dart';
import '../../../student/presentation/widgets/student_page_gestures.dart';
import '../providers/student_feature_flags_provider.dart';
import '../widgets/tablet_shell.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key, this.initialTab});

  final String? initialTab;

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  late PageController _landscapePageController;

  @override
  void initState() {
    super.initState();
    _landscapePageController = _createLandscapePageController();
  }

  @override
  void didUpdateWidget(covariant ExplorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _landscapePageController.dispose();
      _landscapePageController = _createLandscapePageController();
    }
  }

  @override
  void dispose() {
    _landscapePageController.dispose();
    super.dispose();
  }

  PageController _createLandscapePageController() {
    return PageController(
      viewportFraction: 0.9,
      initialPage: widget.initialTab == 'ability' ? 1 : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final featureFlags = ref.watch(studentFeatureFlagsProvider);
    return StudentPageGestures(
      onSwipeBack: () => context.go('/home'),
      child: TabletShell(
        activeSection: TabletSection.explore,
        title: '学习地图',
        subtitle: '补做、自然拼读、分级阅读和星币兑换都在这里',
        theme: TabletShellTheme.k12Sky,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isPhone = constraints.maxWidth < 720;
            final isLandscapePhone =
                isPhone && constraints.maxWidth > constraints.maxHeight;
            if (!featureFlags.showFunZonePromos) {
              return K12PlayfulDashboardFrame(
                padding: EdgeInsets.all(isPhone ? 14 : 20),
                child: const _ExploreFallbackState(),
              );
            }
            final mapItems = [
              _ExploreMapItem(
                title: '补星计划',
                ribbonLabel: '3天内可补',
                description: '找回最近三天没完成的作业，不让星星掉队。',
                accent: const Color(0xFFFFB84D),
                icon: Icons.history_toggle_off_rounded,
                actionLabel: '去补做',
                onTap: () => context.go('/activities'),
              ),
              _ExploreMapItem(
                title: '自然拼读',
                ribbonLabel: 'Phonics',
                description: '从字母音、拼读规则到高频词，循序闯关。',
                accent: const Color(0xFF73B7FF),
                icon: Icons.abc_rounded,
                actionLabel: '开始闯关',
                onTap: () => context.go('/explore/phonics'),
              ),
              _ExploreMapItem(
                title: '国家地理 PM',
                ribbonLabel: '分级阅读',
                description: '用真实图片和短篇阅读，拓展英语输入。',
                accent: const Color(0xFF87D76A),
                icon: Icons.public_rounded,
                actionLabel: '去阅读',
                onTap: () => context.go('/explore/national-geographic'),
              ),
              _ExploreMapItem(
                title: '魔法商店',
                ribbonLabel: '星币兑换',
                description: featureFlags.showGrowthRewards
                    ? '用星币兑换头像框、徽章和伴学宠物装扮。'
                    : '成长奖励开启后，星币会在这里消费。',
                accent: const Color(0xFFFFD447),
                icon: Icons.card_giftcard_rounded,
                actionLabel: '看看奖励',
                onTap: () => context.go('/explore/magic-shop'),
              ),
            ];

            final gymItems = [
              _AbilityGymItem(
                title: '听',
                subtitle: '儿歌和绘本原声',
                icon: Icons.headphones_rounded,
                color: const Color(0xFF5DB9FF),
                onTap: () => context.go('/explore/listen'),
              ),
              _AbilityGymItem(
                title: '说',
                subtitle: 'AI 情景对话',
                icon: Icons.record_voice_over_rounded,
                color: const Color(0xFFFFC941),
                onTap: () => context.go('/explore/speak'),
              ),
              _AbilityGymItem(
                title: '写',
                subtitle: '作品上传和描红',
                icon: Icons.edit_note_rounded,
                color: const Color(0xFF78E55A),
                onTap: () => context.go('/explore/write'),
              ),
              _AbilityGymItem(
                title: '玩',
                subtitle: '错词小游戏',
                icon: Icons.extension_rounded,
                color: const Color(0xFF55D9C5),
                onTap: () => context.go('/explore/play'),
              ),
            ];

            return K12PlayfulDashboardFrame(
              padding: EdgeInsets.all(isPhone ? 14 : 20),
              child: isLandscapePhone
                  ? PageView(
                      controller: _landscapePageController,
                      children: _landscapePhonePages(
                        context: context,
                        mapItems: mapItems,
                        gymItems: gymItems,
                      ),
                    )
                  : isPhone
                  ? SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _phoneSections(
                          context: context,
                          mapItems: mapItems,
                          gymItems: gymItems,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          flex: 58,
                          child: Row(
                            children: [
                              const Expanded(flex: 36, child: _ExploreHero()),
                              const SizedBox(width: 18),
                              Expanded(
                                flex: 64,
                                child: _LearningMapGrid(items: mapItems),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          flex: 42,
                          child: _AbilityGymGrid(items: gymItems),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _landscapePhonePages({
    required BuildContext context,
    required List<_ExploreMapItem> mapItems,
    required List<_AbilityGymItem> gymItems,
  }) {
    final mapPage = Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        children: [
          const Expanded(flex: 34, child: _ExploreHero()),
          const SizedBox(width: 14),
          Expanded(flex: 66, child: _LearningMapGrid(items: mapItems)),
        ],
      ),
    );
    final abilityPage = Padding(
      padding: const EdgeInsets.only(left: 14),
      child: _AbilityGymGrid(items: gymItems),
    );
    return [mapPage, abilityPage];
  }

  List<Widget> _phoneSections({
    required BuildContext context,
    required List<_ExploreMapItem> mapItems,
    required List<_AbilityGymItem> gymItems,
  }) {
    const heroSection = SizedBox(height: 320, child: _ExploreHero());
    final mapSection = _LearningMapGrid(items: mapItems, isPhone: true);
    final abilitySection = SizedBox(
      height: 330,
      child: _AbilityGymGrid(items: gymItems, isPhone: true),
    );
    final sections = [
      heroSection,
      const SizedBox(height: 16),
      mapSection,
      const SizedBox(height: 16),
      abilitySection,
    ];
    if (widget.initialTab != 'ability') {
      return sections;
    }
    return [
      abilitySection,
      const SizedBox(height: 16),
      heroSection,
      const SizedBox(height: 16),
      mapSection,
    ];
  }
}

class _ExploreHero extends StatelessWidget {
  const _ExploreHero();

  @override
  Widget build(BuildContext context) {
    return StudentBoundarylessSectionStage(
      title: '学习地图',
      icon: Icons.auto_stories_rounded,
      hint: '主线之外的拓展学习',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D8DFF), Color(0xFF69D5FF)],
          ),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2D8DFF).withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今天先完成主线，再来这里探索',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '学习地图负责长期路线：历史补做、自然拼读、分级阅读、积分兑换。听说写玩则负责短时兴趣练习。',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const Spacer(),
            Text(
              '完成主线后再来探索，左右滑动即可切换学习区域。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreFallbackState extends StatelessWidget {
  const _ExploreFallbackState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: StudentGlassPanel(
          padding: const EdgeInsets.all(22),
          radius: 34,
          opacity: 0.22,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF5FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF2E7BEF),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '拓展乐园稍后开放',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF17335F),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '为了保持今天的学习节奏，先去完成主线作业。自然拼读、分级阅读和小游戏会在开放后回到这里。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearningMapGrid extends StatelessWidget {
  const _LearningMapGrid({required this.items, this.isPhone = false});

  final List<_ExploreMapItem> items;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = isPhone ? 12.0 : 16.0;
        if (isPhone) {
          return Column(
            children: items
                .map(
                  (item) => Padding(
                    padding: EdgeInsets.only(bottom: spacing),
                    child: _ExploreMapCard(item: item, compact: isPhone),
                  ),
                )
                .toList(),
          );
        }

        return GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: constraints.maxWidth < 760 ? 2 : 4,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: constraints.maxWidth < 760 ? 1.35 : 0.98,
          children: items.map((item) => _ExploreMapCard(item: item)).toList(),
        );
      },
    );
  }
}

class _AbilityGymGrid extends StatelessWidget {
  const _AbilityGymGrid({required this.items, this.isPhone = false});

  final List<_AbilityGymItem> items;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    return StudentGlassSectionStage(
      title: '听说写玩',
      icon: Icons.grid_view_rounded,
      hint: '兴趣驱动的能力健身房',
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: isPhone ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isPhone ? 1.8 : 1.55,
        children: items.map((item) => _AbilityGymCard(item: item)).toList(),
      ),
    );
  }
}

class _ExploreMapItem {
  const _ExploreMapItem({
    required this.title,
    required this.ribbonLabel,
    required this.description,
    required this.accent,
    required this.icon,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String ribbonLabel;
  final String description;
  final Color accent;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onTap;
}

class _ExploreMapCard extends StatelessWidget {
  const _ExploreMapCard({required this.item, this.compact = false});

  final _ExploreMapItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return StudentLearningMapCard(
      title: item.title,
      ribbonLabel: item.ribbonLabel,
      statusLabel: item.actionLabel,
      accent: item.accent,
      compact: compact,
      onTap: item.onTap,
      cover: Container(
        decoration: BoxDecoration(
          color: item.accent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -12,
              top: -14,
              child: Icon(
                item.icon,
                size: compact ? 86 : 108,
                color: item.accent.withValues(alpha: 0.36),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              right: 16,
              child: Text(
                item.description,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF124D7A),
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AbilityGymItem {
  const _AbilityGymItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _AbilityGymCard extends StatelessWidget {
  const _AbilityGymCard({required this.item});

  final _AbilityGymItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                item.color.withValues(alpha: 0.95),
                item.color.withValues(alpha: 0.78),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  item.icon,
                  color: const Color(0xFF195AB6),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF103F77),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF124D7A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
