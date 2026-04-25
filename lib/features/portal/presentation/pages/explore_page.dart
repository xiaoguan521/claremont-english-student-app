import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../home/presentation/widgets/k12_dashboard_widgets.dart';
import '../../../home/presentation/widgets/k12_playful_widgets.dart';
import '../providers/student_feature_flags_provider.dart';
import '../widgets/tablet_shell.dart';

class ExplorePage extends ConsumerWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureFlags = ref.watch(studentFeatureFlagsProvider);
    return TabletShell(
      activeSection: TabletSection.explore,
      title: 'Fun Zone',
      subtitle: featureFlags.showFunZonePromos
          ? '拓展功能会陆续开放，英语乐园正在准备更多惊喜'
          : '当前版本先聚焦主线作业，拓展功能会按计划逐步开放',
      theme: TabletShellTheme.k12Sky,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 720;
          const items = [
            _UpcomingItem(
              title: '快乐听',
              description: '跟着有趣音频完成轻松听力练习。',
              accent: Color(0xFF62B7FF),
              icon: Icons.podcasts_rounded,
            ),
            _UpcomingItem(
              title: '视频配音',
              description: '用短视频练节奏、语调和表达。',
              accent: Color(0xFFFF85C2),
              icon: Icons.mic_external_on_rounded,
            ),
            _UpcomingItem(
              title: 'AI 自习室',
              description: '根据你的学习情况推荐专项练习。',
              accent: Color(0xFFFFB347),
              icon: Icons.smart_toy_rounded,
            ),
            _UpcomingItem(
              title: '背单词',
              description: '用小游戏方式记住今天的新单词。',
              accent: Color(0xFF77D49A),
              icon: Icons.spellcheck_rounded,
            ),
          ];

          return K12PlayfulDashboardFrame(
            padding: EdgeInsets.all(isPhone ? 16 : 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!featureFlags.showFunZonePromos)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isPhone ? 18 : 24),
                      decoration: k12PlasticPanelDecoration(
                        accent: const Color(0xFF6AC5FF),
                        radius: 34,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '拓展乐园稍后开放',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: const Color(0xFF1E293B),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '当前版本先保证每天的英语主线作业稳定完成。等主线体验全部跑稳后，背单词、配音、听力和 AI 自习室会按计划逐步开放。',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: const Color(0xFF475569),
                                  fontWeight: FontWeight.w700,
                                  height: 1.45,
                                ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => context.go('/activities'),
                            icon: const Icon(Icons.play_circle_fill_rounded),
                            label: const Text('先去完成主线作业'),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isPhone ? 18 : 24),
                      decoration: k12PlasticPanelDecoration(
                        accent: const Color(0xFF6AC5FF),
                        radius: 34,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF5DB9FF),
                            Color(0xFF2D8DFF),
                            Color(0xFF69D5FF),
                          ],
                        ),
                      ),
                      child: isPhone
                          ? const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ExploreHeroCopy(),
                                SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 150,
                                  child: K12CartoonHeroScene(),
                                ),
                                SizedBox(height: 16),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    K12StatusBadge(
                                      icon: Icons.tips_and_updates_rounded,
                                      label: '4 个功能排队上线',
                                      color: Color(0xFFFFE36B),
                                      foregroundColor: Color(0xFF8A4F00),
                                      margin: EdgeInsets.zero,
                                    ),
                                    K12StatusBadge(
                                      icon: Icons.auto_awesome_rounded,
                                      label: '更多 AI 英语玩法',
                                      color: Color(0xFF9AF07A),
                                      foregroundColor: Color(0xFF155B2D),
                                      margin: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : const Row(
                              children: [
                                Expanded(child: _ExploreHeroCopy()),
                                SizedBox(width: 24),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      width: 180,
                                      height: 180,
                                      child: K12CartoonHeroScene(),
                                    ),
                                    SizedBox(height: 12),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        K12StatusBadge(
                                          icon: Icons.tips_and_updates_rounded,
                                          label: '4 个功能排队上线',
                                          color: Color(0xFFFFE36B),
                                          foregroundColor: Color(0xFF8A4F00),
                                          margin: EdgeInsets.zero,
                                        ),
                                        K12StatusBadge(
                                          icon: Icons.auto_awesome_rounded,
                                          label: '更多 AI 英语玩法',
                                          color: Color(0xFF9AF07A),
                                          foregroundColor: Color(0xFF155B2D),
                                          margin: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  if (featureFlags.showFunZonePromos) ...[
                    const SizedBox(height: 18),
                    if (isPhone)
                      Column(
                        children: items
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _UpcomingCard(item: item),
                              ),
                            )
                            .toList(),
                      )
                    else
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: constraints.maxWidth < 980 ? 2 : 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: constraints.maxWidth < 980
                            ? 1.25
                            : 1.05,
                        children: items
                            .map((item) => _UpcomingCard(item: item))
                            .toList(),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UpcomingItem {
  final String title;
  final String description;
  final Color accent;
  final IconData icon;

  const _UpcomingItem({
    required this.title,
    required this.description,
    required this.accent,
    required this.icon,
  });
}

class _UpcomingCard extends StatelessWidget {
  final _UpcomingItem item;

  const _UpcomingCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: k12PlasticPanelDecoration(
        accent: item.accent,
        radius: 28,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            item.accent.withValues(alpha: 0.96),
            item.accent.withValues(alpha: 0.78),
          ],
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(item.icon, color: const Color(0xFF195AB6), size: 28),
          ),
          const SizedBox(height: 18),
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF103F77),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF124D7A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          const K12PlayToken(
            icon: Icons.hourglass_top_rounded,
            label: '即将开放',
            color: Color(0xFFFFED8E),
            foregroundColor: Color(0xFF8A4F00),
          ),
        ],
      ),
    );
  }
}

class _ExploreHeroCopy extends StatelessWidget {
  const _ExploreHeroCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'English Fun Zone',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '这里会陆续开放背单词、配音、听力和 AI 自习室等趣味英语玩法。当前建议先完成老师布置的主线作业。',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.95),
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            const K12HeroBadge(icon: Icons.stars_rounded, label: '趣味拓展内容'),
            const K12HeroBadge(
              icon: Icons.workspace_premium_rounded,
              label: '成长奖励联动',
            ),
            FilledButton.icon(
              onPressed: () => context.go('/activities'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFE36B),
                foregroundColor: const Color(0xFF195AB6),
              ),
              icon: const Icon(Icons.play_circle_fill_rounded),
              label: const Text('去做今日作业'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/home'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
              ),
              icon: const Icon(Icons.home_rounded),
              label: const Text('回首页'),
            ),
          ],
        ),
      ],
    );
  }
}
