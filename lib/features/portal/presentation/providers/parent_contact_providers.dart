import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_cache_repository.dart';
import '../../data/portal_models.dart';
import 'portal_providers.dart';

class ParentContactSummary {
  const ParentContactSummary({
    required this.activityTitle,
    required this.className,
    required this.dateLabel,
    required this.completedTasks,
    required this.totalTasks,
    required this.submissionStatusLabel,
    required this.feedbackStatusLabel,
    required this.focusAreas,
    required this.healthSummary,
    required this.earnedStars,
    required this.comboCount,
    required this.backgroundSwitchCount,
    required this.breakReminderCount,
    required this.isCachedFallback,
    required this.isFeedbackPending,
    required this.updatedAtLabel,
  });

  final String activityTitle;
  final String className;
  final String dateLabel;
  final int completedTasks;
  final int totalTasks;
  final String submissionStatusLabel;
  final String feedbackStatusLabel;
  final List<String> focusAreas;
  final String healthSummary;
  final int earnedStars;
  final int comboCount;
  final int backgroundSwitchCount;
  final int breakReminderCount;
  final bool isCachedFallback;
  final bool isFeedbackPending;
  final String updatedAtLabel;

  ParentContactSummary copyWith({
    bool? isCachedFallback,
    bool? isFeedbackPending,
    String? updatedAtLabel,
  }) {
    return ParentContactSummary(
      activityTitle: activityTitle,
      className: className,
      dateLabel: dateLabel,
      completedTasks: completedTasks,
      totalTasks: totalTasks,
      submissionStatusLabel: submissionStatusLabel,
      feedbackStatusLabel: feedbackStatusLabel,
      focusAreas: focusAreas,
      healthSummary: healthSummary,
      earnedStars: earnedStars,
      comboCount: comboCount,
      backgroundSwitchCount: backgroundSwitchCount,
      breakReminderCount: breakReminderCount,
      isCachedFallback: isCachedFallback ?? this.isCachedFallback,
      isFeedbackPending: isFeedbackPending ?? this.isFeedbackPending,
      updatedAtLabel: updatedAtLabel ?? this.updatedAtLabel,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'activityTitle': activityTitle,
      'className': className,
      'dateLabel': dateLabel,
      'completedTasks': completedTasks,
      'totalTasks': totalTasks,
      'submissionStatusLabel': submissionStatusLabel,
      'feedbackStatusLabel': feedbackStatusLabel,
      'focusAreas': focusAreas,
      'healthSummary': healthSummary,
      'earnedStars': earnedStars,
      'comboCount': comboCount,
      'backgroundSwitchCount': backgroundSwitchCount,
      'breakReminderCount': breakReminderCount,
      'isCachedFallback': isCachedFallback,
      'isFeedbackPending': isFeedbackPending,
      'updatedAtLabel': updatedAtLabel,
    };
  }

  factory ParentContactSummary.fromMap(Map<String, dynamic> map) {
    return ParentContactSummary(
      activityTitle: map['activityTitle'] as String? ?? '今日英语作业',
      className: map['className'] as String? ?? '当前班级',
      dateLabel: map['dateLabel'] as String? ?? '今天',
      completedTasks: (map['completedTasks'] as num?)?.toInt() ?? 0,
      totalTasks: (map['totalTasks'] as num?)?.toInt() ?? 0,
      submissionStatusLabel: map['submissionStatusLabel'] as String? ?? '',
      feedbackStatusLabel: map['feedbackStatusLabel'] as String? ?? '',
      focusAreas: (map['focusAreas'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
      healthSummary: map['healthSummary'] as String? ?? '',
      earnedStars: (map['earnedStars'] as num?)?.toInt() ?? 0,
      comboCount: (map['comboCount'] as num?)?.toInt() ?? 0,
      backgroundSwitchCount:
          (map['backgroundSwitchCount'] as num?)?.toInt() ?? 0,
      breakReminderCount: (map['breakReminderCount'] as num?)?.toInt() ?? 0,
      isCachedFallback: map['isCachedFallback'] as bool? ?? false,
      isFeedbackPending: map['isFeedbackPending'] as bool? ?? false,
      updatedAtLabel: map['updatedAtLabel'] as String? ?? '刚刚更新',
    );
  }
}

class ParentContactPracticeSnapshot {
  const ParentContactPracticeSnapshot({
    this.completedTasks = 0,
    this.earnedStars = 0,
    this.comboCount = 0,
    this.backgroundSwitchCount = 0,
    this.breakReminderCount = 0,
    this.updatedAt,
  });

  final int completedTasks;
  final int earnedStars;
  final int comboCount;
  final int backgroundSwitchCount;
  final int breakReminderCount;
  final DateTime? updatedAt;

  factory ParentContactPracticeSnapshot.fromMap(Map<String, dynamic> map) {
    return ParentContactPracticeSnapshot(
      completedTasks: (map['completedTasks'] as num?)?.toInt() ?? 0,
      earnedStars: (map['earnedStars'] as num?)?.toInt() ?? 0,
      comboCount: (map['comboCount'] as num?)?.toInt() ?? 0,
      backgroundSwitchCount:
          (map['backgroundSwitchCount'] as num?)?.toInt() ?? 0,
      breakReminderCount: (map['breakReminderCount'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? ''),
    );
  }
}

class DailyGrowthSummary {
  const DailyGrowthSummary({
    required this.totalStars,
    required this.bestCombo,
    required this.completedTasks,
    required this.breakReminderCount,
    required this.backgroundSwitchCount,
  });

  final int totalStars;
  final int bestCombo;
  final int completedTasks;
  final int breakReminderCount;
  final int backgroundSwitchCount;
}

final dailyGrowthSummaryProvider = FutureProvider<DailyGrowthSummary>((
  ref,
) async {
  final cacheRepository = ref.watch(localCacheRepositoryProvider);
  final snapshots = await cacheRepository.readJsonMapByPrefix(
    'parent_contact_snapshot_',
  );

  var totalStars = 0;
  var bestCombo = 0;
  var completedTasks = 0;
  var breakReminderCount = 0;
  var backgroundSwitchCount = 0;

  for (final map in snapshots.values) {
    final snapshot = ParentContactPracticeSnapshot.fromMap(map);
    totalStars += snapshot.earnedStars;
    completedTasks += snapshot.completedTasks;
    breakReminderCount += snapshot.breakReminderCount;
    backgroundSwitchCount += snapshot.backgroundSwitchCount;
    if (snapshot.comboCount > bestCombo) {
      bestCombo = snapshot.comboCount;
    }
  }

  return DailyGrowthSummary(
    totalStars: totalStars,
    bestCombo: bestCombo,
    completedTasks: completedTasks,
    breakReminderCount: breakReminderCount,
    backgroundSwitchCount: backgroundSwitchCount,
  );
});

final parentContactSummaryProvider =
    FutureProvider.family<ParentContactSummary?, String>((
      ref,
      activityId,
    ) async {
      final cacheRepository = ref.watch(localCacheRepositoryProvider);
      final cacheKey = 'parent_contact_summary_$activityId';
      final snapshotKey = 'parent_contact_snapshot_$activityId';
      final cachedMap = await cacheRepository.readJson(cacheKey);
      final cachedSummary = cachedMap == null
          ? null
          : ParentContactSummary.fromMap(cachedMap);
      final snapshotMap = await cacheRepository.readJson(snapshotKey);
      final snapshot = snapshotMap == null
          ? const ParentContactPracticeSnapshot()
          : ParentContactPracticeSnapshot.fromMap(snapshotMap);

      try {
        final activity = await ref.watch(
          portalActivityByIdProvider(activityId).future,
        );
        if (activity == null) {
          return cachedSummary;
        }

        final summary = _buildParentContactSummary(
          activity,
          snapshot: snapshot,
        );
        await cacheRepository.writeJson(cacheKey, summary.toMap());
        return summary;
      } catch (_) {
        return cachedSummary?.copyWith(isCachedFallback: true);
      }
    });

ParentContactSummary _buildParentContactSummary(
  PortalActivity activity, {
  required ParentContactPracticeSnapshot snapshot,
}) {
  final checkedTasks = activity.tasks
      .where((task) => task.reviewStatus == TaskReviewStatus.checked)
      .length;
  final completedTasks = checkedTasks > snapshot.completedTasks
      ? checkedTasks
      : snapshot.completedTasks;
  final focusAreas = <String>{
    ...activity.improvementPoints,
    for (final task in activity.tasks) ...?task.review?.improvementPoints,
  }.where((item) => item.trim().isNotEmpty).take(3).toList();

  return ParentContactSummary(
    activityTitle: activity.title,
    className: activity.className,
    dateLabel: activity.dateLabel,
    completedTasks: completedTasks,
    totalTasks: activity.tasks.length,
    submissionStatusLabel: _submissionStatusLabel(
      activity.submissionFlowStatus,
    ),
    feedbackStatusLabel: _feedbackStatusLabel(activity),
    focusAreas: focusAreas,
    healthSummary: _healthSummary(
      completedTasks: completedTasks,
      totalTasks: activity.tasks.length,
      backgroundSwitchCount: snapshot.backgroundSwitchCount,
      breakReminderCount: snapshot.breakReminderCount,
    ),
    earnedStars: snapshot.earnedStars,
    comboCount: snapshot.comboCount,
    backgroundSwitchCount: snapshot.backgroundSwitchCount,
    breakReminderCount: snapshot.breakReminderCount,
    isCachedFallback: false,
    isFeedbackPending: !activity.hasTeacherReviewedResult,
    updatedAtLabel: _updatedAtLabel(snapshot.updatedAt),
  );
}

String _submissionStatusLabel(SubmissionFlowStatus status) {
  switch (status) {
    case SubmissionFlowStatus.notStarted:
      return '今天的作业还没有正式提交。';
    case SubmissionFlowStatus.queued:
      return '作业已记录，正在等待系统继续处理。';
    case SubmissionFlowStatus.processing:
      return '作业已经提交，系统正在整理评审结果。';
    case SubmissionFlowStatus.completed:
      return '今天的作业已经提交完成。';
    case SubmissionFlowStatus.failed:
      return '本次提交需要重新尝试一次。';
  }
}

String _feedbackStatusLabel(PortalActivity activity) {
  if (activity.hasTeacherReviewedResult) {
    return '老师反馈已经返回，可以和孩子一起回看。';
  }
  if (activity.hasAiReview) {
    return 'AI 初评已经返回，老师反馈可能稍后补齐。';
  }
  return '评审结果稍后补齐，现在可以先确认今天的完成情况。';
}

String _healthSummary({
  required int completedTasks,
  required int totalTasks,
  required int backgroundSwitchCount,
  required int breakReminderCount,
}) {
  final completionText = completedTasks >= totalTasks && totalTasks > 0
      ? '今天的学习任务已经完成。'
      : '今天的作业还在进行中。';
  final focusText = backgroundSwitchCount == 0
      ? '作业过程中没有记录到切出应用。'
      : '作业过程中切出应用 $backgroundSwitchCount 次。';
  final breakText = breakReminderCount == 0
      ? '系统暂时还没有触发休息提醒。'
      : '系统已经提醒休息 $breakReminderCount 次。';
  return '$completionText $focusText $breakText';
}

String _updatedAtLabel(DateTime? updatedAt) {
  if (updatedAt == null) {
    return '刚刚更新';
  }
  final now = DateTime.now();
  final difference = now.difference(updatedAt);
  if (difference.inMinutes < 1) {
    return '刚刚更新';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes} 分钟前更新';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours} 小时前更新';
  }
  return '${updatedAt.month}月${updatedAt.day}日更新';
}
