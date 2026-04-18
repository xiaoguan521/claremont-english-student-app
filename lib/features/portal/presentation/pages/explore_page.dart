import 'package:flutter/material.dart';

import '../widgets/tablet_shell.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return TabletShell(
      activeSection: TabletSection.explore,
      title: '拓展空间',
      subtitle: '平板学习中心',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(30),
        ),
        child: GridView.count(
          crossAxisCount: 5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: const [
            _ExploreCard(
              title: '快乐听',
              color: Color(0xFF6EC4FF),
              icon: Icons.podcasts_rounded,
            ),
            _ExploreCard(
              title: '视频配音',
              color: Color(0xFFFA7EC8),
              icon: Icons.mic_external_on_rounded,
            ),
            _ExploreCard(
              title: 'AI自习室',
              color: Color(0xFF8BB7FF),
              icon: Icons.smart_toy_rounded,
            ),
            _ExploreCard(
              title: '练口语',
              color: Color(0xFFFFA53A),
              icon: Icons.record_voice_over_rounded,
            ),
            _ExploreCard(
              title: '作品秀场',
              color: Color(0xFF8FB7FF),
              icon: Icons.collections_bookmark_rounded,
            ),
            _ExploreCard(
              title: '背单词',
              color: Color(0xFFFFD47F),
              icon: Icons.spellcheck_rounded,
            ),
            _ExploreCard(
              title: '分级阅读',
              color: Color(0xFFFFB3C8),
              icon: Icons.library_books_rounded,
            ),
            _ExploreCard(
              title: '自然拼读',
              color: Color(0xFFA8E58F),
              icon: Icons.auto_stories_rounded,
            ),
            _ExploreCard(
              title: '错题本',
              color: Color(0xFFFFD1D6),
              icon: Icons.edit_note_rounded,
            ),
            _ExploreCard(
              title: '积分兑换',
              color: Color(0xFF7DE0F1),
              icon: Icons.workspace_premium_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;

  const _ExploreCard({
    required this.title,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const Spacer(),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
