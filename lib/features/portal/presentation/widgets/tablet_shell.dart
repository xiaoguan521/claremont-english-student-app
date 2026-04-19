import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum TabletSection { teaching, management, explore }

class TabletShell extends StatelessWidget {
  final TabletSection activeSection;
  final String title;
  final String? subtitle;
  final String brandName;
  final String? brandSubtitle;
  final Widget child;
  final List<Widget>? actions;

  const TabletShell({
    required this.activeSection,
    required this.title,
    required this.child,
    this.subtitle,
    this.brandName = '英语打卡',
    this.brandSubtitle,
    this.actions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF7DF),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4ABB87), Color(0xFF93D56D), Color(0xFFF4E9B7)],
          ),
        ),
        child: Stack(
          children: [
            const _BackgroundDecor(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
                child: Column(
                  children: [
                    _TopBar(
                      title: title,
                      subtitle: subtitle,
                      brandName: brandName,
                      brandSubtitle: brandSubtitle,
                      actions: actions,
                    ),
                    const SizedBox(height: 20),
                    Expanded(child: child),
                    const SizedBox(height: 18),
                    _BottomSectionNav(activeSection: activeSection),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String brandName;
  final String? brandSubtitle;
  final List<Widget>? actions;

  const _TopBar({
    required this.title,
    required this.brandName,
    this.subtitle,
    this.brandSubtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Color(0xFF309A7A),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brandName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (brandSubtitle != null)
                    Text(
                      brandSubtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Spacer(),
        ...?actions,
      ],
    );
  }
}

class _BottomSectionNav extends StatelessWidget {
  final TabletSection activeSection;

  const _BottomSectionNav({required this.activeSection});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NavChip(
              label: '作业',
              icon: Icons.menu_book_rounded,
              selected: activeSection == TabletSection.teaching,
              onTap: () => context.go('/activities'),
            ),
            const SizedBox(width: 12),
            _NavChip(
              label: '首页',
              icon: Icons.dashboard_customize_rounded,
              selected: activeSection == TabletSection.management,
              onTap: () => context.go('/home'),
            ),
            const SizedBox(width: 12),
            _NavChip(
              label: '我的',
              icon: Icons.extension_rounded,
              selected: activeSection == TabletSection.explore,
              onTap: () => context.go('/explore'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2F67F6) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? Colors.white : const Color(0xFF475569),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundDecor extends StatelessWidget {
  const _BackgroundDecor();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -60,
          child: _Blob(size: 280, color: Colors.white.withValues(alpha: 0.10)),
        ),
        Positioned(
          right: -30,
          top: 90,
          child: _Blob(
            size: 220,
            color: const Color(0xFFFDE68A).withValues(alpha: 0.22),
          ),
        ),
        Positioned(
          left: 90,
          bottom: 80,
          child: _Blob(
            size: 180,
            color: const Color(0xFF93C5FD).withValues(alpha: 0.18),
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.42),
      ),
    );
  }
}
