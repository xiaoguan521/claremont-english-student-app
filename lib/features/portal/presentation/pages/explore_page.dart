import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/tablet_shell.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return TabletShell(
      activeSection: TabletSection.explore,
      title: '更多内容',
      subtitle: '先完成老师布置的作业，拓展功能会陆续开放',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 720;
          final items = const [
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

          return SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(isPhone ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '这些功能正在准备中',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '当前先专注完成老师布置的作业。等这些内容开放后，你会在这里看到正式入口。',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.go('/activities'),
                        icon: const Icon(Icons.play_circle_fill_rounded),
                        label: const Text('去做今日作业'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/home'),
                        icon: const Icon(Icons.home_rounded),
                        label: const Text('回首页'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
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
                      childAspectRatio: constraints.maxWidth < 980 ? 1.35 : 1.1,
                      children: items
                          .map((item) => _UpcomingCard(item: item))
                          .toList(),
                    ),
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
      decoration: BoxDecoration(
        color: item.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: item.accent.withValues(alpha: 0.22)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(item.icon, color: item.accent, size: 28),
          ),
          const SizedBox(height: 18),
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '即将开放',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: item.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
