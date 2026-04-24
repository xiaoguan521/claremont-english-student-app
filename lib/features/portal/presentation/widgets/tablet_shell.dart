import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/brand_avatar.dart';

enum TabletSection { teaching, management, explore }

class TabletShell extends StatelessWidget {
  final TabletSection activeSection;
  final String title;
  final String? subtitle;
  final String brandName;
  final String? brandLogoUrl;
  final String? brandSubtitle;
  final Widget child;
  final List<Widget>? actions;

  const TabletShell({
    required this.activeSection,
    required this.title,
    required this.child,
    this.subtitle,
    this.brandName = '',
    this.brandLogoUrl,
    this.brandSubtitle,
    this.actions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
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
                  final screenSize = constraints.biggest;
                  final isLandscapePhone =
                      constraints.maxWidth > constraints.maxHeight &&
                      constraints.maxHeight < 640;
                  final isCompact =
                      constraints.maxWidth < 640 || isLandscapePhone;
                  final isTightLandscapePhone =
                      isLandscapePhone && constraints.maxHeight < 430;
                  final shellScale = _shellUiScale(screenSize);
                  final textScale =
                      (mediaQuery.textScaler.scale(1) * shellScale).clamp(
                        0.84,
                        1.0,
                      );
                  final showBottomNav = !isLandscapePhone;
                  return MediaQuery(
                    data: mediaQuery.copyWith(
                      textScaler: TextScaler.linear(textScale),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isLandscapePhone
                            ? isTightLandscapePhone
                                  ? 10
                                  : 14
                            : isCompact
                            ? 16
                            : 28,
                        isLandscapePhone
                            ? isTightLandscapePhone
                                  ? 8
                                  : 10
                            : isCompact
                            ? 14
                            : 22,
                        isLandscapePhone
                            ? isTightLandscapePhone
                                  ? 10
                                  : 14
                            : isCompact
                            ? 16
                            : 28,
                        isLandscapePhone
                            ? isTightLandscapePhone
                                  ? 6
                                  : 8
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
                            brandLogoUrl: brandLogoUrl,
                            brandSubtitle: brandSubtitle,
                            actions: actions,
                            isCompact: isCompact,
                            isLandscapePhone: isLandscapePhone,
                          ),
                          SizedBox(
                            height: isLandscapePhone
                                ? isTightLandscapePhone
                                      ? 6
                                      : 10
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
  final String? brandLogoUrl;
  final String? brandSubtitle;
  final List<Widget>? actions;
  final bool isCompact;
  final bool isLandscapePhone;

  const _TopBar({
    required this.title,
    required this.brandName,
    this.brandLogoUrl,
    this.subtitle,
    this.brandSubtitle,
    this.actions,
    required this.isCompact,
    required this.isLandscapePhone,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final tightLandscapePhone = isLandscapePhone && size.height < 430;
    final primaryBrandText = brandName.trim().isNotEmpty
        ? brandName.trim()
        : (brandSubtitle?.trim() ?? '');
    final secondaryBrandText = brandName.trim().isNotEmpty
        ? brandSubtitle?.trim()
        : null;
    final brandChip = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isLandscapePhone
            ? tightLandscapePhone
                  ? 184
                  : 220
            : 360,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLandscapePhone
              ? tightLandscapePhone
                    ? 8
                    : 10
              : isCompact
              ? 12
              : 16,
          vertical: isLandscapePhone
              ? tightLandscapePhone
                    ? 6
                    : 8
              : isCompact
              ? 10
              : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: BrandAvatar(
                logoUrl: brandLogoUrl?.trim() ?? '',
                size: isLandscapePhone
                    ? tightLandscapePhone
                          ? 30
                          : 34
                    : isCompact
                    ? 40
                    : 42,
                borderRadius: 14,
                backgroundColor: Colors.white,
                fallbackIcon: Icons.auto_stories_rounded,
                fallbackIconColor: const Color(0xFF309A7A),
              ),
            ),
            SizedBox(
              width: isLandscapePhone ? (tightLandscapePhone ? 6 : 8) : 12,
            ),
            if (primaryBrandText.isNotEmpty)
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      primaryBrandText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: isLandscapePhone
                            ? tightLandscapePhone
                                  ? 13
                                  : 15
                            : isCompact
                            ? 16
                            : null,
                      ),
                    ),
                    if (secondaryBrandText != null &&
                        secondaryBrandText.isNotEmpty &&
                        !isLandscapePhone)
                      Text(
                        secondaryBrandText,
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
      ),
    );

    final titleChip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscapePhone && tightLandscapePhone
            ? 12
            : isCompact
            ? 14
            : 18,
        vertical: isLandscapePhone && tightLandscapePhone
            ? 10
            : isCompact
            ? 12
            : 14,
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
          fontSize: isLandscapePhone && tightLandscapePhone
              ? 15
              : isCompact
              ? 18
              : null,
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

    if (isLandscapePhone) {
      return Row(
        children: [
          brandChip,
          const Spacer(),
          if ((actions?.isNotEmpty ?? false))
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(children: actions!),
              ),
            ),
        ],
      );
    }

    return Row(
      children: [
        brandChip,
        const SizedBox(width: 18),
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
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 640;
    final isTightLandscapePhone = size.width > size.height && size.height < 430;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: EdgeInsets.symmetric(
            horizontal: isTightLandscapePhone
                ? 8
                : isCompact
                ? 10
                : 16,
            vertical: isTightLandscapePhone
                ? 8
                : isCompact
                ? 10
                : 12,
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
                size: isTightLandscapePhone
                    ? 16
                    : isCompact
                    ? 18
                    : 20,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
              SizedBox(
                width: isTightLandscapePhone
                    ? 4
                    : isCompact
                    ? 6
                    : 8,
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? Colors.white : const Color(0xFF475569),
                  fontWeight: FontWeight.w800,
                  fontSize: isTightLandscapePhone
                      ? 12
                      : isCompact
                      ? 14
                      : null,
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

double _shellUiScale(Size size) {
  if (size.shortestSide >= 600) {
    return 1;
  }

  if (size.width > size.height) {
    final heightScale = (size.height / 430).clamp(0.82, 1.0);
    final widthScale = (size.width / 900).clamp(0.9, 1.0);
    return (heightScale * widthScale).clamp(0.82, 1.0);
  }

  return (size.width / 390).clamp(0.9, 1.0);
}
