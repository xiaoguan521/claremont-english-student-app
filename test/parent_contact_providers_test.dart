import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_starter/features/portal/data/local_cache_repository.dart';
import 'package:flutter_starter/features/portal/data/portal_models.dart';
import 'package:flutter_starter/features/portal/presentation/providers/parent_contact_providers.dart';
import 'package:flutter_starter/features/portal/presentation/providers/portal_providers.dart';

class _FakeLocalCacheRepository implements LocalCacheRepository {
  final Map<String, Map<String, dynamic>> _store;

  _FakeLocalCacheRepository([Map<String, Map<String, dynamic>>? seed])
    : _store = {...?seed};

  @override
  Future<Map<String, dynamic>?> readJson(String key) async => _store[key];

  @override
  Future<Map<String, Map<String, dynamic>>> readJsonMapByPrefix(
    String prefix,
  ) async {
    return {
      for (final entry in _store.entries)
        if (entry.key.startsWith(prefix)) entry.key: entry.value,
    };
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    _store[key] = value;
  }
}

void main() {
  test(
    'parent contact summary builds pending feedback summary from activity',
    () async {
      final cache = _FakeLocalCacheRepository({
        'parent_contact_snapshot_activity-1': <String, dynamic>{
          'completedTasks': 1,
          'earnedStars': 8,
          'comboCount': 2,
          'backgroundSwitchCount': 0,
          'breakReminderCount': 1,
          'updatedAt': DateTime.now()
              .subtract(const Duration(minutes: 5))
              .toIso8601String(),
        },
      });
      final activity = PortalActivity(
        id: 'activity-1',
        title: 'Unit 2 Homework',
        className: '三年级 2 班',
        dateLabel: '今天',
        dueDate: DateTime(2026, 4, 25),
        status: ActivityStatus.active,
        reviewCount: 0,
        inspectCount: 0,
        urgeCount: 0,
        completionRate: 0.5,
        tasks: const [
          PortalTask(
            id: 'task-1',
            title: 'Read it',
            kind: TaskKind.recording,
            reviewStatus: TaskReviewStatus.inProgress,
            previewAsset: 'preview.png',
          ),
          PortalTask(
            id: 'task-2',
            title: 'Say it',
            kind: TaskKind.dubbing,
            reviewStatus: TaskReviewStatus.pendingReview,
            previewAsset: 'preview.png',
          ),
        ],
        submissionFlowStatus: SubmissionFlowStatus.processing,
      );

      final container = ProviderContainer(
        overrides: [
          localCacheRepositoryProvider.overrideWithValue(cache),
          portalActivityByIdProvider.overrideWith(
            (ref, activityId) async => activity,
          ),
        ],
      );
      addTearDown(container.dispose);

      final summary = await container.read(
        parentContactSummaryProvider('activity-1').future,
      );

      expect(summary, isNotNull);
      expect(summary!.isFeedbackPending, isTrue);
      expect(summary.isCachedFallback, isFalse);
      expect(summary.feedbackStatusLabel, contains('稍后'));
      expect(summary.updatedAtLabel, isNotEmpty);
    },
  );

  test(
    'parent contact summary falls back to cached summary when activity fetch fails',
    () async {
      final cache = _FakeLocalCacheRepository({
        'parent_contact_summary_activity-2': const ParentContactSummary(
          activityTitle: 'Cached Homework',
          className: '四年级 1 班',
          dateLabel: '昨天',
          completedTasks: 2,
          totalTasks: 3,
          submissionStatusLabel: '已缓存',
          feedbackStatusLabel: '缓存中的反馈摘要',
          focusAreas: <String>['回看发音'],
          healthSummary: '缓存中的健康摘要',
          earnedStars: 5,
          comboCount: 1,
          backgroundSwitchCount: 0,
          breakReminderCount: 0,
          isCachedFallback: false,
          isFeedbackPending: true,
          updatedAtLabel: '10 分钟前更新',
        ).toMap(),
      });

      final container = ProviderContainer(
        overrides: [
          localCacheRepositoryProvider.overrideWithValue(cache),
          portalActivityByIdProvider.overrideWith((ref, activityId) async {
            throw Exception('network down');
          }),
        ],
      );
      addTearDown(container.dispose);

      final summary = await container.read(
        parentContactSummaryProvider('activity-2').future,
      );

      expect(summary, isNotNull);
      expect(summary!.activityTitle, 'Cached Homework');
      expect(summary.isCachedFallback, isTrue);
    },
  );
}
