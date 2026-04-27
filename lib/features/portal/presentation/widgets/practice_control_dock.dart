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
      duration: const Duration(milliseconds: 220),
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
            const Color(0xFFFFF7E8).withValues(alpha: 0.9),
          ],
        ),
        borderRadius: dockRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.82),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF123A63).withValues(alpha: 0.1),
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
                        color: const Color(0xFF16213A),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!compact && subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
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
