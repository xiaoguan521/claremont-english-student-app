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

final portalActivityByIdProvider = FutureProvider.family<PortalActivity?, String>((
  ref,
  activityId,
) async {
  for (final activity in await ref.watch(portalActivitiesProvider.future)) {
    if (activity.id == activityId) return activity;
  }
  return null;
});

final portalSummaryProvider = FutureProvider<PortalSummary>((ref) async {
  final activities = await ref.watch(portalActivitiesProvider.future);
  final totalReview = activities.fold<int>(
    0,
    (sum, item) => sum + item.reviewCount,
  );
  final totalUrge = activities.fold<int>(
    0,
    (sum, item) => sum + item.urgeCount,
  );
  final totalClasses = activities.length;

  return PortalSummary(
    activeClasses: totalClasses,
    reviewPending: totalReview,
    studentsToUrge: totalUrge,
  );
});

class PortalSummary {
  const PortalSummary({
    required this.activeClasses,
    required this.reviewPending,
    required this.studentsToUrge,
  });

  final int activeClasses;
  final int reviewPending;
  final int studentsToUrge;
}
