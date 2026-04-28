import 'package:flutter/material.dart';

import '../../../../core/ui/app_ui_tokens.dart';

class PracticeControlDock extends StatelessWidget {
  const PracticeControlDock({
    super.key,
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.title,
    required this.controls,
    this.subtitle,
    this.helper,
    this.details = const [],
    this.compact = false,
  });

  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final String title;
  final String? subtitle;
  final Widget controls;
  final Widget? helper;
  final List<Widget> details;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dockRadius = BorderRadius.circular(
      compact ? AppUiTokens.radiusMd : AppUiTokens.radiusLg,
    );

    return AnimatedContainer(
      duration: AppUiTokens.motionMedium,
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: EdgeInsets.all(
        compact ? AppUiTokens.spaceSm : AppUiTokens.spaceMd,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.94),
            AppUiTokens.studentPanelWarm.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: dockRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.82),
          width: AppUiTokens.borderWidthMd,
        ),
        boxShadow: [
          BoxShadow(
            color: AppUiTokens.studentDockShadow,
            blurRadius: compact ? 18 : 26,
            offset: Offset(0, compact ? 8 : 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppUiTokens.spaceSm,
                  vertical: AppUiTokens.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppUiTokens.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 17),
                    const SizedBox(width: AppUiTokens.space2xs),
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppUiTokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppUiTokens.studentInk,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!compact && subtitle != null) ...[
                      const SizedBox(height: AppUiTokens.space2xs / 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppUiTokens.studentMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (helper != null) ...[
            const SizedBox(height: AppUiTokens.spaceXs),
            helper!,
          ],
          for (final detail in details) ...[
            const SizedBox(height: AppUiTokens.spaceSm),
            detail,
          ],
          const SizedBox(height: AppUiTokens.spaceSm),
          controls,
        ],
      ),
    );
  }
}
