import 'package:flutter/material.dart';

class K12PlayfulDashboardFrame extends StatelessWidget {
  const K12PlayfulDashboardFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(40);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8EDBFF), Color(0xFF6FC5FF), Color(0xFF63B5FF)],
        ),
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A8DDB).withValues(alpha: 0.24),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            const Positioned(
              top: -18,
              right: -12,
              child: K12DecorBubble(
                diameter: 138,
                colors: [Color(0xFFFFE36E), Color(0xFFFFB940)],
              ),
            ),
            const Positioned(
              left: -30,
              bottom: -40,
              child: K12DecorBubble(
                diameter: 180,
                colors: [Color(0xFF8DF08B), Color(0xFF58C96E)],
              ),
            ),
            const Positioned(
              right: 48,
              bottom: 38,
              child: K12DecorBubble(
                diameter: 42,
                colors: [Color(0xFFFFFFFF), Color(0x88FFFFFF)],
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.26),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.08),
                    ],
                    stops: const [0, 0.35, 1],
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class K12DecorBubble extends StatelessWidget {
  const K12DecorBubble({
    super.key,
    required this.diameter,
    required this.colors,
  });

  final double diameter;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
    );
  }
}

BoxDecoration k12PlasticPanelDecoration({
  Color accent = const Color(0xFF69C6FF),
  double radius = 30,
  Gradient? gradient,
  Color? fillColor,
}) {
  return BoxDecoration(
    color: gradient == null
        ? (fillColor ?? Colors.white.withValues(alpha: 0.9))
        : null,
    gradient: gradient,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.72), width: 1.6),
    boxShadow: [
      BoxShadow(
        color: accent.withValues(alpha: 0.18),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

class K12HeroBadge extends StatelessWidget {
  const K12HeroBadge({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class K12MiniMetric extends StatelessWidget {
  const K12MiniMetric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
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

class K12HeroScheduleLine extends StatelessWidget {
  const K12HeroScheduleLine({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.32),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF2257B1)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFFE9F4FF),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
