import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_breakpoints.dart';
import '../../../../core/ui/app_ui_tokens.dart';
import '../../../../core/widgets/brand_avatar.dart';

enum TabletSection { teaching, management, explore }

class TabletShellTheme {
  final Color scaffoldBackground;
  final List<Color> backgroundGradient;
  final Color brandChipColor;
  final Color titleChipColor;
  final Color titleChipBorderColor;
  final Color bottomNavColor;
  final Color bottomNavSelectedColor;
  final Color bottomNavSelectedTextColor;
  final Color bottomNavUnselectedColor;
  final Color bottomNavShadowColor;
  final List<Color> decorColors;
  final Color fallbackIconColor;

  const TabletShellTheme({
    required this.scaffoldBackground,
    required this.backgroundGradient,
    required this.brandChipColor,
    required this.titleChipColor,
    required this.titleChipBorderColor,
    required this.bottomNavColor,
    required this.bottomNavSelectedColor,
    required this.bottomNavSelectedTextColor,
    required this.bottomNavUnselectedColor,
    required this.bottomNavShadowColor,
    required this.decorColors,
    required this.fallbackIconColor,
  });

  static const classic = TabletShellTheme(
    scaffoldBackground: Color(0xFFF7F3D9),
    backgroundGradient: [
      Color(0xFF54C58F),
      Color(0xFFB9E36E),
      Color(0xFFFFE7A8),
    ],
    brandChipColor: Color(0x29000000),
    titleChipColor: Color(0x29FFFFFF),
    titleChipBorderColor: Color(0x00FFFFFF),
    bottomNavColor: Color(0xDBFFFFFF),
    bottomNavSelectedColor: Color(0xFFFF8F4D),
    bottomNavSelectedTextColor: Colors.white,
    bottomNavUnselectedColor: Color(0xFF475569),
    bottomNavShadowColor: Color(0x14000000),
    decorColors: [Color(0x1AFFFFFF), Color(0x38FDE68A), Color(0x2E93C5FD)],
    fallbackIconColor: Color(0xFF309A7A),
  );

  static const k12Sky = TabletShellTheme(
    scaffoldBackground: Color(0xFFE8F7FF),
    backgroundGradient: [
      Color(0xFF8EDBFF),
      Color(0xFF63C5FF),
      Color(0xFFB3F07E),
    ],
    brandChipColor: Color(0x2EFFFFFF),
    titleChipColor: Color(0x33FFFFFF),
    titleChipBorderColor: Color(0x7AFFFFFF),
    bottomNavColor: Color(0xE6FFFFFF),
    bottomNavSelectedColor: Color(0xFFFFD447),
    bottomNavSelectedTextColor: Color(0xFF1554A8),
    bottomNavUnselectedColor: Color(0xFF2C5E9E),
    bottomNavShadowColor: Color(0x1F2C84D2),
    decorColors: [Color(0x22FFFFFF), Color(0x55FFE16B), Color(0x448EF58D)],
    fallbackIconColor: Color(0xFF1D72C9),
  );
}

class TabletShell extends StatelessWidget {
  final TabletSection activeSection;
  final String title;
  final String? subtitle;
  final String brandName;
  final String? brandLogoUrl;
  final String? brandSubtitle;
  final VoidCallback? onBrandTap;
  final Widget child;
  final List<Widget>? actions;
  final TabletShellTheme theme;

  const TabletShell({
    required this.activeSection,
    required this.title,
    required this.child,
    this.subtitle,
    this.brandName = '',
    this.brandLogoUrl,
    this.brandSubtitle,
    this.onBrandTap,
    this.actions,
    this.theme = TabletShellTheme.classic,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.backgroundGradient,
          ),
        ),
        child: Stack(
          children: [
            _BackgroundDecor(theme: theme),
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
                            ? AppUiTokens.spaceMd
                            : AppUiTokens.spaceXl,
                        isLandscapePhone
                            ? isTightLandscapePhone
                                  ? 8
                                  : 10
                            : isCompact
                            ? 14
                            : AppUiTokens.spaceMd,
                        isLandscapePhone
                            ? isTightLandscapePhone
                                  ? 10
                                  : 14
                            : isCompact
                            ? AppUiTokens.spaceMd
                            : AppUiTokens.spaceXl,
                        isLandscapePhone
                            ? isTightLandscapePhone
                                  ? 6
                                  : 8
                            : isCompact
                            ? 14
                            : 14,
                      ),
                      child: Column(
                        children: [
                          _TopBar(
                            title: title,
                            subtitle: subtitle,
                            brandName: brandName,
                            brandLogoUrl: brandLogoUrl,
                            brandSubtitle: brandSubtitle,
                            onBrandTap: onBrandTap,
                            actions: actions,
                            isCompact: isCompact,
                            isLandscapePhone: isLandscapePhone,
                            theme: theme,
                          ),
                          SizedBox(
                            height: isLandscapePhone
                                ? isTightLandscapePhone
                                      ? 6
                                      : 10
                                : isCompact
                                ? 14
                                : 14,
                          ),
                          Expanded(child: child),
                          if (showBottomNav) ...[
                            SizedBox(
                              height: isLandscapePhone
                                  ? 8
                                  : isCompact
                                  ? AppUiTokens.spaceSm
                                  : AppUiTokens.spaceLg - 2,
                            ),
                            _BottomSectionNav(
                              activeSection: activeSection,
                              isCompact: isCompact,
                              isLandscapePhone: isLandscapePhone,
                              theme: theme,
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
  final VoidCallback? onBrandTap;
  final List<Widget>? actions;
  final bool isCompact;
  final bool isLandscapePhone;
  final TabletShellTheme theme;

  const _TopBar({
    required this.title,
    required this.brandName,
    this.brandLogoUrl,
    this.subtitle,
    this.brandSubtitle,
    this.onBrandTap,
    this.actions,
    required this.isCompact,
    required this.isLandscapePhone,
    required this.theme,
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
    final brandChipChild = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscapePhone
            ? tightLandscapePhone
                  ? 8
                  : 10
            : isCompact
            ? 10
            : 14,
        vertical: isLandscapePhone
            ? tightLandscapePhone
                  ? 6
                  : 8
            : isCompact
            ? 8
            : 10,
      ),
      decoration: BoxDecoration(
        color: theme.brandChipColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.titleChipBorderColor.withValues(alpha: 0.5),
        ),
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
                  ? 36
                  : 38,
              borderRadius: 14,
              backgroundColor: Colors.white,
              fallbackIcon: Icons.auto_stories_rounded,
              fallbackIconColor: theme.fallbackIconColor,
            ),
          ),
          SizedBox(
            width: isLandscapePhone ? (tightLandscapePhone ? 6 : 8) : 10,
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
                          : 18,
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
          if (onBrandTap != null) ...[
            SizedBox(width: isLandscapePhone ? 6 : 10),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ],
        ],
      ),
    );

    final brandChip = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isLandscapePhone
            ? tightLandscapePhone
                  ? 184
                  : 220
            : 320,
      ),
      child: onBrandTap == null
          ? brandChipChild
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onBrandTap,
                borderRadius: BorderRadius.circular(24),
                child: brandChipChild,
              ),
            ),
    );

    final titleChip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscapePhone && tightLandscapePhone
            ? 10
            : isCompact
            ? 12
            : 16,
        vertical: isLandscapePhone && tightLandscapePhone
            ? 8
            : isCompact
            ? 10
            : 11,
      ),
      decoration: BoxDecoration(
        color: theme.titleChipColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.titleChipBorderColor, width: 1.4),
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
              : 20,
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
        const SizedBox(width: 12),
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
  final TabletShellTheme theme;

  const _BottomSectionNav({
    required this.activeSection,
    required this.isCompact,
    required this.isLandscapePhone,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final responsiveMaxWidth = constraints.maxWidth.isFinite
              ? responsiveWidthCap(
                  constraints.maxWidth,
                  fraction: 0.96,
                  min: 280.0,
                  max: 560.0,
                )
              : 560.0;
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: responsiveMaxWidth),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscapePhone
                    ? 10
                    : isCompact
                    ? AppUiTokens.spaceSm
                    : AppUiTokens.spaceLg - 2,
                vertical: isLandscapePhone
                    ? 8
                    : isCompact
                    ? 10
                    : AppUiTokens.spaceSm,
              ),
              decoration: BoxDecoration(
                color: theme.bottomNavColor,
                borderRadius: BorderRadius.circular(AppUiTokens.radiusXl + 2),
                border: Border.all(
                  color: theme.titleChipBorderColor.withValues(alpha: 0.6),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.bottomNavShadowColor,
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
                    theme: theme,
                  ),
                  SizedBox(width: isCompact ? 8 : 12),
                  _NavChip(
                    label: '首页',
                    icon: Icons.dashboard_customize_rounded,
                    selected: activeSection == TabletSection.management,
                    onTap: () => context.go('/home'),
                    theme: theme,
                  ),
                  SizedBox(width: isCompact ? 8 : 12),
                  _NavChip(
                    label: '更多',
                    icon: Icons.stars_rounded,
                    selected: activeSection == TabletSection.explore,
                    onTap: () => context.go('/explore'),
                    theme: theme,
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

class _NavChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final TabletShellTheme theme;

  const _NavChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.theme,
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
            color: selected ? theme.bottomNavSelectedColor : Colors.transparent,
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
                color: selected
                    ? theme.bottomNavSelectedTextColor
                    : theme.bottomNavUnselectedColor,
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
                  color: selected
                      ? theme.bottomNavSelectedTextColor
                      : theme.bottomNavUnselectedColor,
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
  const _BackgroundDecor({required this.theme});

  final TabletShellTheme theme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          left: -60,
          child: _Blob(size: 280, color: theme.decorColors[0]),
        ),
        Positioned(
          right: -30,
          top: 90,
          child: _Blob(size: 220, color: theme.decorColors[1]),
        ),
        Positioned(
          left: 90,
          bottom: 80,
          child: _Blob(size: 180, color: theme.decorColors[2]),
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
