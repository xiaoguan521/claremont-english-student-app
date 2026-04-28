import 'package:flutter/material.dart';

import '../../../../core/ui/app_ui_tokens.dart';

enum FeedbackBottomSheetTheme { success, error, celebration }

Future<void> showFeedbackBottomSheet(
  BuildContext context, {
  required FeedbackBottomSheetTheme theme,
  required String title,
  required String message,
  String buttonLabel = '继续',
  String? badgeLabel,
  IconData? badgeIcon,
  VoidCallback? onContinue,
}) {
  final (background, accent, icon, mascotLabel) = switch (theme) {
    FeedbackBottomSheetTheme.success => (
      const Color(0xFFEAFBF1),
      const Color(0xFF16A34A),
      Icons.check_rounded,
      'Nice!',
    ),
    FeedbackBottomSheetTheme.error => (
      const Color(0xFFFFF1F2),
      const Color(0xFFDC2626),
      Icons.priority_high_rounded,
      'Try',
    ),
    FeedbackBottomSheetTheme.celebration => (
      const Color(0xFFFFF7E8),
      const Color(0xFFF59E0B),
      Icons.emoji_events_rounded,
      'Wow!',
    ),
  };

  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.94, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: value,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                background,
                Colors.white.withValues(alpha: 0.96),
                background,
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.2),
                blurRadius: 28,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Stack(
              children: [
                Positioned(
                  right: -24,
                  top: 10,
                  child: _FeedbackDecorBubble(
                    size: 92,
                    color: accent.withValues(alpha: 0.12),
                  ),
                ),
                Positioned(
                  right: 54,
                  bottom: 76,
                  child: _FeedbackDecorBubble(
                    size: 28,
                    color: accent.withValues(alpha: 0.16),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(
                            AppUiTokens.radiusPill,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _FeedbackMascotBurst(
                          accent: accent,
                          icon: icon,
                          label: mascotLabel,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: accent,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                message,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: const Color(0xFF334155),
                                      fontWeight: FontWeight.w700,
                                      height: 1.4,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (badgeLabel != null && badgeLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppUiTokens.radiusPill,
                          ),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              badgeIcon ?? Icons.star_rounded,
                              size: 20,
                              color: accent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              badgeLabel,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onContinue?.call();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(58),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppUiTokens.radiusPill,
                            ),
                          ),
                          textStyle: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        child: Text(buttonLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _FeedbackMascotBurst extends StatelessWidget {
  const _FeedbackMascotBurst({
    required this.accent,
    required this.icon,
    required this.label,
  });

  final Color accent;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -2,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppUiTokens.radiusPill),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, accent.withValues(alpha: 0.2)],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(icon, color: accent, size: 32),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackDecorBubble extends StatelessWidget {
  const _FeedbackDecorBubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
