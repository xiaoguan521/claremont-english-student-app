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
      backgroundColor: const Color(0xFFF7F3D9),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF54C58F), Color(0xFFB9E36E), Color(0xFFFFE7A8)],
          ),
        ),
        child: Stack(
          children: [
            const _BackgroundDecor(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isLandscapePhone =
                      constraints.maxWidth > constraints.maxHeight &&
                      constraints.maxHeight < 640;
                  final isCompact =
                      constraints.maxWidth < 640 || isLandscapePhone;
                  final showBottomNav = !isLandscapePhone;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      isLandscapePhone
                          ? 14
                          : isCompact
                          ? 16
                          : 28,
                      isLandscapePhone
                          ? 10
                          : isCompact
                          ? 14
                          : 22,
                      isLandscapePhone
                          ? 14
                          : isCompact
                          ? 16
                          : 28,
                      isLandscapePhone
                          ? 8
                          : isCompact
                          ? 14
                          : 18,
                    ),
                    child: Column(
                      children: [
                        _TopBar(
                          title: title,
                          subtitle: subtitle,
                          brandName: brandName,
                          brandSubtitle: brandSubtitle,
                          actions: actions,
                          isCompact: isCompact,
                          isLandscapePhone: isLandscapePhone,
                        ),
                        SizedBox(
                          height: isLandscapePhone
                              ? 10
                              : isCompact
                              ? 14
                              : 20,
                        ),
                        Expanded(child: child),
                        if (showBottomNav) ...[
                          SizedBox(
                            height: isLandscapePhone
                                ? 8
                                : isCompact
                                ? 12
                                : 18,
                          ),
                          _BottomSectionNav(
                            activeSection: activeSection,
                            isCompact: isCompact,
                            isLandscapePhone: isLandscapePhone,
                          ),
                        ],
                      ],
                    ),
                  );
                },
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
  final bool isCompact;
  final bool isLandscapePhone;

  const _TopBar({
    required this.title,
    required this.brandName,
    this.subtitle,
    this.brandSubtitle,
    this.actions,
    required this.isCompact,
    required this.isLandscapePhone,
  });

  @override
  Widget build(BuildContext context) {
    final brandChip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isCompact ? 40 : 42,
            height: isCompact ? 40 : 42,
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
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  brandName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: isCompact ? 16 : null,
                  ),
                ),
                if (brandSubtitle != null)
                  Text(
                    brandSubtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final titleChip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 18,
        vertical: isCompact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: isCompact ? 18 : null,
        ),
      ),
    );

    if (isCompact && !isLandscapePhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          brandChip,
          if ((actions?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: actions!),
          ],
          const SizedBox(height: 10),
          titleChip,
        ],
      );
    }

    return Row(
      children: [
        brandChip,
        SizedBox(width: isLandscapePhone ? 12 : 18),
        titleChip,
        const Spacer(),
        ...?actions,
      ],
    );
  }
}

class _BottomSectionNav extends StatelessWidget {
  final TabletSection activeSection;
  final bool isCompact;
  final bool isLandscapePhone;

  const _BottomSectionNav({
    required this.activeSection,
    required this.isCompact,
    required this.isLandscapePhone,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: EdgeInsets.symmetric(
          horizontal: isLandscapePhone
              ? 10
              : isCompact
              ? 12
              : 18,
          vertical: isLandscapePhone
              ? 8
              : isCompact
              ? 10
              : 12,
        ),
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
            SizedBox(width: isCompact ? 8 : 12),
            _NavChip(
              label: '首页',
              icon: Icons.dashboard_customize_rounded,
              selected: activeSection == TabletSection.management,
              onTap: () => context.go('/home'),
            ),
            SizedBox(width: isCompact ? 8 : 12),
            _NavChip(
              label: '更多',
              icon: Icons.stars_rounded,
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
    final isCompact = MediaQuery.sizeOf(context).width < 640;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 16,
            vertical: isCompact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFF8F4D) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isCompact ? 18 : 20,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
              SizedBox(width: isCompact ? 6 : 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? Colors.white : const Color(0xFF475569),
                  fontWeight: FontWeight.w800,
                  fontSize: isCompact ? 14 : null,
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
