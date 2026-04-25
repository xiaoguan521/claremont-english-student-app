import 'package:flutter/material.dart';

class K12StatusBadge extends StatelessWidget {
  const K12StatusBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.foregroundColor,
    this.margin = const EdgeInsets.only(left: 10),
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color foregroundColor;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foregroundColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class K12PlayToken extends StatelessWidget {
  const K12PlayToken({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foregroundColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class K12RewardChip extends StatelessWidget {
  const K12RewardChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class K12CartoonHeroScene extends StatelessWidget {
  const K12CartoonHeroScene({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: Container(
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0x330D58B9),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const Positioned(
          left: 6,
          top: 18,
          child: K12FloatingSticker(
            icon: Icons.star_rounded,
            color: Color(0xFFFFD447),
            angle: -0.16,
          ),
        ),
        const Positioned(
          right: 8,
          top: 8,
          child: K12FloatingSticker(
            icon: Icons.workspace_premium_rounded,
            color: Color(0xFF96F06F),
            angle: 0.18,
          ),
        ),
        const Positioned(
          right: 18,
          top: 58,
          child: K12FloatingSticker(
            icon: Icons.monetization_on_rounded,
            color: Color(0xFFFFE26D),
            angle: 0.12,
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 164,
            height: 160,
            child: Stack(
              children: [
                Positioned(
                  left: 52,
                  top: 12,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE28A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.86),
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 12,
                          top: 22,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1C4B95),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 22,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1C4B95),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 21,
                          bottom: 15,
                          child: Icon(
                            Icons.sentiment_very_satisfied_rounded,
                            color: Color(0xFF1C4B95),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 42,
                  top: 64,
                  child: Container(
                    width: 82,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF72D0FF), Color(0xFF2E8EFF)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.82),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  top: 82,
                  child: Transform.rotate(
                    angle: -0.18,
                    child: Container(
                      width: 42,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFEF95), Color(0xFFFFC44C)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: Color(0xFF195AB6),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 22,
                  top: 88,
                  child: Transform.rotate(
                    angle: 0.14,
                    child: Container(
                      width: 12,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFD447), Color(0xFFFF8F4D)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 18,
                  top: 74,
                  child: Transform.rotate(
                    angle: 0.14,
                    child: Container(
                      width: 16,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CD37E),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(4),
                          bottomLeft: Radius.circular(2),
                          bottomRight: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 46,
                  bottom: 4,
                  child: Transform.rotate(
                    angle: 0.06,
                    child: Container(
                      width: 74,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D6CC7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
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

class K12FloatingSticker extends StatelessWidget {
  const K12FloatingSticker({
    super.key,
    required this.icon,
    required this.color,
    required this.angle,
  });

  final IconData icon;
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.86),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF195AB6), size: 22),
      ),
    );
  }
}
