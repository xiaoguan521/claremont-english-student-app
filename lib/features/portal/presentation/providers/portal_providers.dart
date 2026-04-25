import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_cache_repository.dart';
import '../../data/portal_models.dart';
import '../../data/portal_repository.dart';
import '../../../school/presentation/providers/school_context_provider.dart';

const _portalActivitiesCacheKey = 'portal_activities_cache_v1';

final portalActivitiesProvider = FutureProvider<List<PortalActivity>>((
  ref,
) async {
  final repository = ref.watch(portalRepositoryProvider);
  final cacheRepository = ref.watch(localCacheRepositoryProvider);
  final schoolContext = ref.watch(schoolContextProvider);
  final schoolId = schoolContext.valueOrNull?.schoolId;

  final cachedActivities = await _readCachedActivities(cacheRepository);

  try {
    final activities = await repository.fetchActivities(schoolId: schoolId);
    await cacheRepository.writeJson(_portalActivitiesCacheKey, {
      'activities': activities.map((activity) => activity.toMap()).toList(),
    });
    return activities;
  } catch (_) {
    return cachedActivities;
  }
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
  final dates =
      activities
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

final highlightedActivityProvider = FutureProvider<PortalActivity?>((
  ref,
) async {
  final activities = await ref.watch(portalActivitiesProvider.future);
  final today = ref.watch(todayActivityDateProvider);
  final todayActivities = _activitiesForDate(
    activities,
    selectedDate: today,
    today: today,
  );
  final visibleActivities = todayActivities.isNotEmpty
      ? todayActivities
      : activities;
  if (activities.isEmpty) {
    return null;
  }
  visibleActivities.sort(_activityPriorityCompare);
  return visibleActivities.first;
});

final portalActivityByIdProvider =
    FutureProvider.family<PortalActivity?, String>((ref, activityId) async {
      final repository = ref.watch(portalRepositoryProvider);
      final cacheRepository = ref.watch(localCacheRepositoryProvider);
      final schoolContext = ref.watch(schoolContextProvider);
      final schoolId = schoolContext.valueOrNull?.schoolId;
      try {
        final activity = await repository.fetchActivityById(
          activityId,
          schoolId: schoolId,
        );
        if (activity != null) {
          final cachedActivities = await _readCachedActivities(cacheRepository);
          final nextActivities = [
            for (final item in cachedActivities)
              if (item.id != activity.id) item,
            activity,
          ];
          await cacheRepository.writeJson(_portalActivitiesCacheKey, {
            'activities': nextActivities
                .map((cachedActivity) => cachedActivity.toMap())
                .toList(),
          });
        }
        return activity;
      } catch (_) {
        final cachedActivities = await _readCachedActivities(cacheRepository);
        for (final activity in cachedActivities) {
          if (activity.id == activityId) {
            return activity;
          }
        }
        return null;
      }
    });

final portalSummaryProvider = FutureProvider<PortalSummary>((ref) async {
  final activities = await ref.watch(portalActivitiesProvider.future);
  final today = ref.watch(todayActivityDateProvider);
  return _buildSummary(
    _activitiesForDate(activities, selectedDate: today, today: today),
  );
});

final selectedDatePortalSummaryProvider = FutureProvider<PortalSummary>((
  ref,
) async {
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

DateTime _normalizeDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

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
  }).toList()..sort(_activityPriorityCompare);
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

Future<List<PortalActivity>> _readCachedActivities(
  LocalCacheRepository cacheRepository,
) async {
  final cachedMap = await cacheRepository.readJson(_portalActivitiesCacheKey);
  if (cachedMap == null) {
    return const [];
  }
  final rows = cachedMap['activities'] as List<dynamic>? ?? const <dynamic>[];
  return rows
      .whereType<Map>()
      .map((item) => PortalActivity.fromMap(item.cast<String, dynamic>()))
      .toList();
}
