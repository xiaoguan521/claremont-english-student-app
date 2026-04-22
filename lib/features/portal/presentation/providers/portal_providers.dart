import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_models.dart';
import '../../data/portal_repository.dart';
import '../../../school/presentation/providers/school_context_provider.dart';

final portalActivitiesProvider = FutureProvider<List<PortalActivity>>((ref) {
  final repository = ref.watch(portalRepositoryProvider);
  final schoolContext = ref.watch(schoolContextProvider);
  final schoolId = schoolContext.valueOrNull?.schoolId;
  return repository.fetchActivities(schoolId: schoolId);
});

final todayActivityDateProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final selectedActivityDateProvider = StateProvider<DateTime?>((ref) => null);

final activityCalendarDatesProvider = FutureProvider<List<DateTime>>((
  ref,
) async {
  final activities = await ref.watch(portalActivitiesProvider.future);
  final today = ref.watch(todayActivityDateProvider);
  final dates = activities
      .map((activity) => activity.dueDate)
      .whereType<DateTime>()
      .map(_normalizeDate)
      .toSet()
      .toList()
    ..sort();

  if (!dates.any((date) => _isSameDate(date, today))) {
    dates.add(today);
    dates.sort();
  }

  return dates;
});

final visibleActivityDateProvider = FutureProvider<DateTime>((ref) async {
  final selectedDate = ref.watch(selectedActivityDateProvider);
  final today = ref.watch(todayActivityDateProvider);
  final dates = await ref.watch(activityCalendarDatesProvider.future);

  if (selectedDate != null) {
    return _normalizeDate(selectedDate);
  }
  if (dates.any((date) => _isSameDate(date, today))) {
    return today;
  }
  return today;
});

final activitiesForSelectedDateProvider = FutureProvider<List<PortalActivity>>((
  ref,
) async {
  final activities = await ref.watch(portalActivitiesProvider.future);
  final selectedDate = await ref.watch(visibleActivityDateProvider.future);
  final today = ref.watch(todayActivityDateProvider);
  return _activitiesForDate(
    activities,
    selectedDate: selectedDate,
    today: today,
  );
});

final highlightedActivityProvider = FutureProvider<PortalActivity>((ref) async {
  final activities = await ref.watch(portalActivitiesProvider.future);
  final today = ref.watch(todayActivityDateProvider);
  final todayActivities = _activitiesForDate(
    activities,
    selectedDate: today,
    today: today,
  );
  final visibleActivities = todayActivities.isNotEmpty ? todayActivities : activities;
  if (activities.isEmpty) {
    throw StateError('暂无打卡活动');
  }
  visibleActivities.sort(_activityPriorityCompare);
  return visibleActivities.first;
});

final portalActivityByIdProvider =
    FutureProvider.family<PortalActivity?, String>((ref, activityId) async {
      final repository = ref.watch(portalRepositoryProvider);
      final schoolContext = ref.watch(schoolContextProvider);
      final schoolId = schoolContext.valueOrNull?.schoolId;
      return repository.fetchActivityById(activityId, schoolId: schoolId);
    });

final portalSummaryProvider = FutureProvider<PortalSummary>((ref) async {
  final activities = await ref.watch(portalActivitiesProvider.future);
  final today = ref.watch(todayActivityDateProvider);
  return _buildSummary(
    _activitiesForDate(activities, selectedDate: today, today: today),
  );
});

final selectedDatePortalSummaryProvider = FutureProvider<PortalSummary>((ref) async {
  final activities = await ref.watch(activitiesForSelectedDateProvider.future);
  return _buildSummary(activities);
});

PortalSummary _buildSummary(List<PortalActivity> activities) {
  final totalClasses = activities.length;
  final completedActivities = activities
      .where((item) => item.status == ActivityStatus.completed)
      .length;
  final inProgressActivities = activities
      .where((item) => item.status != ActivityStatus.completed)
      .length;
  final pendingTasks = activities.fold<int>(0, (sum, item) {
    switch (item.submissionFlowStatus) {
      case SubmissionFlowStatus.notStarted:
      case SubmissionFlowStatus.failed:
        return sum + item.tasks.length;
      case SubmissionFlowStatus.queued:
      case SubmissionFlowStatus.processing:
      case SubmissionFlowStatus.completed:
        return sum;
    }
  });

  return PortalSummary(
    activeClasses: totalClasses,
    totalActivities: activities.length,
    completedActivities: completedActivities,
    inProgressActivities: inProgressActivities,
    pendingTasks: pendingTasks,
  );
}

DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

List<PortalActivity> _activitiesForDate(
  List<PortalActivity> activities, {
  required DateTime selectedDate,
  required DateTime today,
}) {
  return activities.where((activity) {
    final dueDate = activity.dueDate;
    if (dueDate == null) {
      return _isSameDate(selectedDate, today);
    }
    return _isSameDate(_normalizeDate(dueDate), selectedDate);
  }).toList()
    ..sort(_activityPriorityCompare);
}

int _activityPriorityCompare(PortalActivity left, PortalActivity right) {
  const statusOrder = {
    ActivityStatus.active: 0,
    ActivityStatus.reviewPending: 1,
    ActivityStatus.completed: 2,
  };

  final leftStatus = statusOrder[left.status] ?? 99;
  final rightStatus = statusOrder[right.status] ?? 99;
  if (leftStatus != rightStatus) {
    return leftStatus.compareTo(rightStatus);
  }

  final leftDue = left.dueDate;
  final rightDue = right.dueDate;
  if (leftDue != null && rightDue != null) {
    final dueCompare = leftDue.compareTo(rightDue);
    if (dueCompare != 0) {
      return dueCompare;
    }
  }

  return left.title.compareTo(right.title);
}

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
