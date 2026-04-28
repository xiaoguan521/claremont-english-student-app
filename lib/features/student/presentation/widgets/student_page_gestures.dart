import 'package:flutter/material.dart';

class StudentPageGestures extends StatelessWidget {
  const StudentPageGestures({
    super.key,
    required this.child,
    this.onSwipeBack,
    this.onRefresh,
    this.swipeVelocityThreshold = -520,
  });

  final Widget child;
  final VoidCallback? onSwipeBack;
  final Future<void> Function()? onRefresh;
  final double swipeVelocityThreshold;

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (onRefresh != null) {
      content = RefreshIndicator(
        onRefresh: onRefresh!,
        edgeOffset: 8,
        child: content,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: onSwipeBack == null
          ? null
          : (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < swipeVelocityThreshold) {
                onSwipeBack!();
              }
            },
      child: content,
    );
  }
}
