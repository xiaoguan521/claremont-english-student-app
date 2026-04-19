import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_models.dart';
import '../../data/portal_repository.dart';

final portalActivitiesProvider = FutureProvider<List<PortalActivity>>((ref) {
  final repository = ref.watch(portalRepositoryProvider);
  return repository.fetchActivities();
});

final highlightedActivityProvider = FutureProvider<PortalActivity>((ref) async {
  final activities = await ref.watch(portalActivitiesProvider.future);
  if (activities.isEmpty) {
    throw StateError('暂无打卡活动');
  }
  return activities.first;
});

final portalActivityByIdProvider =
    FutureProvider.family<PortalActivity?, String>((ref, activityId) async {
      for (final activity in await ref.watch(portalActivitiesProvider.future)) {
        if (activity.id == activityId) return activity;
      }
      return null;
    });

final portalSummaryProvider = FutureProvider<PortalSummary>((ref) async {
  final activities = await ref.watch(portalActivitiesProvider.future);
  final totalClasses = activities.length;
  final completedActivities = activities
      .where((item) => item.status == ActivityStatus.completed)
      .length;
  final inProgressActivities = activities
      .where((item) => item.status != ActivityStatus.completed)
      .length;
  final pendingTasks = activities.fold<int>(
    0,
    (sum, item) =>
        sum +
        item.tasks
            .where((task) => task.reviewStatus != TaskReviewStatus.checked)
            .length,
  );

  return PortalSummary(
    activeClasses: totalClasses,
    totalActivities: activities.length,
    completedActivities: completedActivities,
    inProgressActivities: inProgressActivities,
    pendingTasks: pendingTasks,
  );
});

class PortalSummary {
  const PortalSummary({
    required this.activeClasses,
    required this.totalActivities,
    required this.completedActivities,
    required this.inProgressActivities,
    required this.pendingTasks,
  });

  final int activeClasses;
  final int totalActivities;
  final int completedActivities;
  final int inProgressActivities;
  final int pendingTasks;
}
