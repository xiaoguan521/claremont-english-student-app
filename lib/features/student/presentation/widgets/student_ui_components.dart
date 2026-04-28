import 'package:flutter/material.dart';

import '../../../../core/ui/app_ui_tokens.dart';

class StudentGlassPanel extends StatelessWidget {
  const StudentGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppUiTokens.spaceMd),
    this.radius = AppUiTokens.radiusXl,
    this.opacity = 0.2,
    this.showBorder = true,
    this.showDecor = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;
  final bool showBorder;
  final bool showDecor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: opacity + 0.06),
            const Color(0xFFEAF8FF).withValues(alpha: opacity + 0.42),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: showBorder
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.52),
                width: 1.4,
              )
            : null,
      ),
      child: Stack(
        children: [
          if (showDecor) ...[
            Positioned(
              right: -26,
              top: -28,
              child: _StudentDecorOrb(
                diameter: 112,
                color: const Color(0xFFFFDB63).withValues(alpha: 0.14),
              ),
            ),
            Positioned(
              left: -34,
              bottom: -42,
              child: _StudentDecorOrb(
                diameter: 132,
                color: const Color(0xFF8FEA74).withValues(alpha: 0.12),
              ),
            ),
          ],
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class StudentSectionPill extends StatelessWidget {
  const StudentSectionPill({
    super.key,
    required this.icon,
    required this.label,
    this.compact = false,
    this.backgroundColor,
    this.foregroundColor = const Color(0xFF1E293B),
  });

  final IconData icon;
  final String label;
  final bool compact;
  final Color? backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(AppUiTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF3369D7), size: compact ? 18 : 20),
          const SizedBox(width: AppUiTokens.spaceXs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 15 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class StudentFullCardTap extends StatefulWidget {
  const StudentFullCardTap({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = AppUiTokens.radiusXl,
  });

  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  @override
  State<StudentFullCardTap> createState() => _StudentFullCardTapState();
}

class _StudentFullCardTapState extends State<StudentFullCardTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) {
            if (!mounted) return;
            setState(() {
              _pressed = value;
            });
          },
          borderRadius: BorderRadius.circular(widget.borderRadius),
          splashColor: Colors.white.withValues(alpha: 0.16),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: widget.child,
        ),
      ),
    );
  }
}

class StudentPrimaryActionBar extends StatelessWidget {
  const StudentPrimaryActionBar({
    super.key,
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppUiTokens.spaceMd,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE36B),
        borderRadius: BorderRadius.circular(AppUiTokens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC53D).withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF195AB6), size: compact ? 18 : 20),
          const SizedBox(width: AppUiTokens.spaceXs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF195AB6),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StudentAbilityActionCard extends StatelessWidget {
  const StudentAbilityActionCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
    this.isCompact = false,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTinyHeight = constraints.maxHeight < 70;
        final tightCard =
            constraints.maxWidth < 210 || constraints.maxHeight < 125;
        final isNarrow =
            tightCard ||
            constraints.maxWidth < 220 ||
            constraints.maxHeight < 90;
        final padding = tightCard
            ? 12.0
            : isCompact
            ? 14.0
            : 18.0;
        final iconSize = tightCard
            ? 40.0
            : isCompact
            ? 46.0
            : 54.0;
        final decorSize = tightCard ? 56.0 : 76.0;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.98),
                  color.withValues(alpha: 0.82),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.68),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -10,
                  right: -4,
                  child: Container(
                    width: decorSize,
                    height: decorSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                if (isTinyHeight)
                  Center(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF114178),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else if (isNarrow)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: tightCard ? 34 : 40,
                            height: tightCard ? 34 : 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.24),
                              borderRadius: BorderRadius.circular(
                                tightCard ? 12 : 14,
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: const Color(0xFF195AB6),
                              size: tightCard ? 18 : 20,
                            ),
                          ),
                          SizedBox(width: tightCard ? 8 : 10),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: const Color(0xFF114178),
                                    fontWeight: FontWeight.w900,
                                    fontSize: tightCard ? 15 : null,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (!tightCard) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF124D7A),
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: tightCard ? 9 : 10,
                          vertical: tightCard ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(
                            tightCard ? 14 : 16,
                          ),
                        ),
                        child: Text(
                          value,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: const Color(0xFF114178),
                                fontWeight: FontWeight.w900,
                                fontSize: tightCard ? 14 : null,
                              ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          icon,
                          color: const Color(0xFF195AB6),
                          size: tightCard
                              ? 21
                              : isCompact
                              ? 24
                              : 28,
                        ),
                      ),
                      SizedBox(
                        width: tightCard
                            ? 10
                            : isCompact
                            ? 12
                            : 14,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: const Color(0xFF114178),
                                    fontWeight: FontWeight.w900,
                                    fontSize: tightCard ? 18 : null,
                                  ),
                            ),
                            if (!tightCard) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: const Color(0xFF124D7A),
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: tightCard ? 6 : 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: tightCard ? 9 : 12,
                          vertical: tightCard ? 7 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(
                            tightCard ? 15 : 18,
                          ),
                        ),
                        child: Text(
                          value,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: const Color(0xFF114178),
                                fontWeight: FontWeight.w900,
                                fontSize: tightCard ? 15 : null,
                              ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StudentGlassSectionStage extends StatelessWidget {
  const StudentGlassSectionStage({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.hint,
    this.opacity = 0.16,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxWidth < 480 || constraints.maxHeight < 320;
        final showHint = hint != null && constraints.maxWidth >= 420;
        final panelPadding = tight ? 12.0 : AppUiTokens.spaceMd;
        final headerBottomGap = tight ? 10.0 : 14.0;

        return StudentGlassPanel(
          padding: EdgeInsets.fromLTRB(
            panelPadding,
            tight ? 12 : 14,
            panelPadding,
            panelPadding,
          ),
          radius: AppUiTokens.radiusXl,
          opacity: opacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, headerBottomGap),
                child: Row(
                  children: [
                    StudentSectionPill(
                      icon: icon,
                      label: title,
                      compact: tight,
                    ),
                    if (showHint) ...[
                      const Spacer(),
                      Flexible(
                        child: Text(
                          hint!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFF547089),
                                fontWeight: FontWeight.w700,
                                fontSize: tight ? 12 : null,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

class StudentBoundarylessSectionStage extends StatelessWidget {
  const StudentBoundarylessSectionStage({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.hint,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLowHeight = constraints.maxHeight < 220;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppUiTokens.spaceMd,
            isLowHeight ? 10 : 14,
            AppUiTokens.spaceMd,
            AppUiTokens.spaceMd,
          ),
          child: Stack(
            children: [
              Positioned(
                left: -42,
                bottom: -64,
                child: _StudentDecorOrb(
                  diameter: 220,
                  color: const Color(0xFF8FEA74).withValues(alpha: 0.11),
                ),
              ),
              Positioned(
                right: -34,
                top: -26,
                child: _StudentDecorOrb(
                  diameter: 180,
                  color: const Color(0xFFFFDB63).withValues(alpha: 0.12),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isLowHeight)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppUiTokens.spaceXs,
                        0,
                        AppUiTokens.spaceXs,
                        14,
                      ),
                      child: Row(
                        children: [
                          StudentSectionPill(icon: icon, label: title),
                          if (hint != null && constraints.maxWidth >= 620) ...[
                            const Spacer(),
                            Flexible(
                              child: Text(
                                hint!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xFF547089),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  Expanded(child: child),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class StudentUtilityDockAction {
  const StudentUtilityDockAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class StudentUtilityDock extends StatelessWidget {
  const StudentUtilityDock({
    super.key,
    required this.displayName,
    required this.actions,
  });

  final String displayName;
  final List<StudentUtilityDockAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth > 420;
        final avatar = Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: horizontal ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEBFF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFF44618F),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF17335F),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );

        if (horizontal) {
          return Row(
            children: [
              Flexible(flex: 2, child: avatar),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: Row(
                  children: actions
                      .map(
                        (action) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _StudentUtilityDockButton(action: action),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            avatar,
            const SizedBox(height: 10),
            Expanded(
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.5,
                children: actions
                    .map((action) => _StudentUtilityDockButton(action: action))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class StudentLearningMapCard extends StatelessWidget {
  const StudentLearningMapCard({
    super.key,
    required this.title,
    required this.ribbonLabel,
    required this.accent,
    required this.cover,
    required this.onTap,
    this.statusLabel,
    this.compact = false,
  });

  final String title;
  final String ribbonLabel;
  final Color accent;
  final Widget cover;
  final VoidCallback onTap;
  final String? statusLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isShort = constraints.maxHeight < 120;
        final showStatusLabel =
            statusLabel != null && !compact && constraints.maxWidth >= 260;
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: _studentPlasticCardDecoration(
                accent: accent,
                radius: 30,
              ),
              child: isShort
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: const Color(0xFF1E293B),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  accent.withValues(alpha: 0.14),
                                  accent.withValues(alpha: 0.05),
                                  Colors.white.withValues(alpha: 0.9),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: -8,
                                  top: compact ? 14 : 18,
                                  child: _StudentSideRibbon(
                                    label: ribbonLabel,
                                    width: compact ? 40 : 46,
                                    radius: compact ? 18 : 20,
                                    compact: compact,
                                  ),
                                ),
                                Positioned(
                                  left: compact ? 14 : 18,
                                  right: compact ? 14 : 18,
                                  bottom: compact ? 8 : 10,
                                  child: Container(
                                    height: compact ? 10 : 14,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.16,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppUiTokens.radiusPill,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      compact ? 14 : 18,
                                      compact ? 12 : 14,
                                      compact ? 14 : 18,
                                      compact ? 14 : 18,
                                    ),
                                    child: cover,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 14 : 18,
                            vertical: compact ? 11 : 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.025),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style:
                                      (compact
                                              ? Theme.of(
                                                  context,
                                                ).textTheme.titleLarge
                                              : Theme.of(
                                                  context,
                                                ).textTheme.headlineMedium)
                                          ?.copyWith(
                                            color: const Color(0xFF1E293B),
                                            fontWeight: FontWeight.w900,
                                          ),
                                ),
                              ),
                              if (showStatusLabel) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(
                                      AppUiTokens.radiusPill,
                                    ),
                                  ),
                                  child: Text(
                                    statusLabel!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: const Color(0xFF1E4F93),
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _StudentSideRibbon extends StatelessWidget {
  const _StudentSideRibbon({
    required this.label,
    this.compact = false,
    this.width,
    this.radius,
  });

  final String label;
  final bool compact;
  final double? width;
  final double? radius;

  String get _verticalText => label.split('').join('\n');

  @override
  Widget build(BuildContext context) {
    final ribbonWidth = width ?? (compact ? 36 : 42);
    final ribbonRadius = radius ?? 18;
    return Container(
      width: ribbonWidth,
      padding: EdgeInsets.symmetric(
        vertical: compact ? 10 : 12,
        horizontal: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF75C8FF), Color(0xFF4478F5)],
        ),
        borderRadius: BorderRadius.circular(ribbonRadius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4478F5).withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        _verticalText,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          height: compact ? 1.05 : 1.12,
          fontSize: compact ? 16 : null,
        ),
      ),
    );
  }
}

BoxDecoration _studentPlasticCardDecoration({
  required Color accent,
  required double radius,
}) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.9),
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

class _StudentUtilityDockButton extends StatelessWidget {
  const _StudentUtilityDockButton({required this.action});

  final StudentUtilityDockAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: action.color, size: 22),
              const SizedBox(height: 4),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF17335F),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentDecorOrb extends StatelessWidget {
  const _StudentDecorOrb({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
