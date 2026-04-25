import 'package:flutter/material.dart';

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
  final (background, accent, icon) = switch (theme) {
    FeedbackBottomSheetTheme.success => (
      const Color(0xFFEAFBF1),
      const Color(0xFF16A34A),
      Icons.check_rounded,
    ),
    FeedbackBottomSheetTheme.error => (
      const Color(0xFFFFF1F2),
      const Color(0xFFDC2626),
      Icons.priority_high_rounded,
    ),
    FeedbackBottomSheetTheme.celebration => (
      const Color(0xFFFFF7E8),
      const Color(0xFFF59E0B),
      Icons.emoji_events_rounded,
    ),
  };

  return showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF334155),
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
              if (badgeLabel != null && badgeLabel.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        badgeIcon ?? Icons.star_rounded,
                        size: 18,
                        color: accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        badgeLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(buttonLabel),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
