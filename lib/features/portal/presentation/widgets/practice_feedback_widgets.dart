import 'package:flutter/material.dart';

class PracticeAutoAdvanceBanner extends StatelessWidget {
  const PracticeAutoAdvanceBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAFBF1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6F2E2)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF2FA77D),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: const Color(0xFF0F8B6D),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PracticeCompletionShareCard extends StatelessWidget {
  const PracticeCompletionShareCard({
    super.key,
    required this.comboCount,
    required this.earnedStars,
    required this.showGrowthRewards,
    required this.onContactParent,
  });

  final int comboCount;
  final int earnedStars;
  final bool showGrowthRewards;
  final VoidCallback onContactParent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE9FFF0), Color(0xFFDFF7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFB7E8C8), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '这一份已经完成啦',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF166534),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            showGrowthRewards && (comboCount > 0 || earnedStars > 0)
                ? '这次拿到了 $earnedStars 星币，还打出了 $comboCount 次连对，去给家长看看今天的学习成果吧。'
                : '可以把今天的学习成果展示给家长看看了。',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          if (showGrowthRewards) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (earnedStars > 0)
                  _RewardChip(
                    icon: Icons.stars_rounded,
                    label: '$earnedStars 星币',
                  ),
                if (comboCount > 0)
                  _RewardChip(
                    icon: Icons.local_fire_department_rounded,
                    label: '$comboCount 连对',
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onContactParent,
            icon: const Icon(Icons.family_restroom_rounded),
            label: const Text('去联系家长'),
          ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF16A34A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF166534),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
