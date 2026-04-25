import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/app_event_log_repository.dart';
import '../../data/portal_repository.dart';
import '../../data/queued_submission_storage.dart';
import '../../data/sync_queue_repository.dart';

class SyncQueueStatus {
  const SyncQueueStatus({required this.items, this.lastUpdatedAt});

  final List<SyncQueueItem> items;
  final DateTime? lastUpdatedAt;

  int get pendingCount => items
      .where((item) => item.status != SyncQueueItemStatus.completed)
      .length;

  int pendingCountForActivity(String activityId) => items
      .where(
        (item) =>
            item.activityId == activityId &&
            item.status != SyncQueueItemStatus.completed,
      )
      .length;
}

class ActivitySyncQueueSummary {
  const ActivitySyncQueueSummary({
    this.pendingCount = 0,
    this.syncingCount = 0,
    this.failedCount = 0,
  });

  final int pendingCount;
  final int syncingCount;
  final int failedCount;

  int get totalVisibleCount => pendingCount + syncingCount + failedCount;

  bool get hasVisibleItems => totalVisibleCount > 0;
}

class SyncQueueController extends StateNotifier<AsyncValue<SyncQueueStatus>> {
  SyncQueueController(this._repository, this._eventLogRepository)
    : super(const AsyncValue.loading()) {
    _load();
  }

  final SyncQueueRepository _repository;
  final AppEventLogRepository _eventLogRepository;
  static const Uuid _uuid = Uuid();
  bool _isProcessing = false;

  Future<void> _load() async {
    try {
      final items = await _repository.listItems();
      state = AsyncValue.data(
        SyncQueueStatus(items: items, lastUpdatedAt: DateTime.now()),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<SyncQueueItem> enqueue({
    required String activityId,
    required String taskId,
    required String attemptUuid,
    required String clientSubmissionId,
    required String fileName,
    required int sizeBytes,
    String? mimeType,
    String? localPath,
  }) async {
    final queueItem = SyncQueueItem(
      queueItemId: _uuid.v4(),
      activityId: activityId,
      taskId: taskId,
      attemptUuid: attemptUuid,
      clientSubmissionId: clientSubmissionId,
      fileName: fileName,
      sizeBytes: sizeBytes,
      createdAt: DateTime.now(),
      mimeType: mimeType,
      localPath: localPath,
    );
    final savedItem = await _repository.enqueue(queueItem);
    await _eventLogRepository.append(
      'sync_queue_enqueued',
      payload: <String, Object?>{
        'activityId': activityId,
        'taskId': taskId,
        'queueItemId': savedItem.queueItemId,
      },
    );
    await _load();
    return savedItem;
  }

  Future<SyncQueueItem?> markStatus(
    String queueItemId, {
    required SyncQueueItemStatus status,
    String? lastError,
  }) async {
    final item = await _repository.updateItem(
      queueItemId,
      status: status,
      lastError: lastError,
    );
    await _load();
    return item;
  }

  Future<void> refresh() => _load();

  Future<void> processPendingUploads({
    required PortalRepository portalRepository,
    required QueuedSubmissionStorage submissionStorage,
    required void Function(String activityId) onActivitySynced,
  }) async {
    if (_isProcessing) {
      return;
    }

    _isProcessing = true;

    try {
      final queuedItems = await _repository.listItems();
      final candidates =
          queuedItems
              .where(
                (item) =>
                    item.status == SyncQueueItemStatus.pending ||
                    item.status == SyncQueueItemStatus.failed,
              )
              .toList()
            ..sort((left, right) => left.createdAt.compareTo(right.createdAt));

      for (final item in candidates) {
        await _repository.updateItem(
          item.queueItemId,
          status: SyncQueueItemStatus.syncing,
          lastError: null,
        );
        await _load();

        final localPath = item.localPath;
        if (localPath == null || localPath.trim().isEmpty) {
          await _repository.updateItem(
            item.queueItemId,
            status: SyncQueueItemStatus.failed,
            lastError: 'missing_local_path',
          );
          await _eventLogRepository.append(
            'sync_queue_missing_local_path',
            payload: <String, Object?>{
              'activityId': item.activityId,
              'taskId': item.taskId,
              'queueItemId': item.queueItemId,
            },
          );
          continue;
        }

        final file = File(localPath);
        if (!await file.exists()) {
          await _repository.updateItem(
            item.queueItemId,
            status: SyncQueueItemStatus.failed,
            lastError: 'missing_local_file',
          );
          await _eventLogRepository.append(
            'sync_queue_missing_local_file',
            payload: <String, Object?>{
              'activityId': item.activityId,
              'taskId': item.taskId,
              'queueItemId': item.queueItemId,
            },
          );
          continue;
        }

        try {
          final fileBytes = await file.readAsBytes();
          final reviewResult = await portalRepository.uploadAudioSubmission(
            activityId: item.activityId,
            fileBytes: fileBytes,
            fileName: item.fileName,
            sizeBytes: item.sizeBytes,
            mimeType: item.mimeType,
          );

          if (reviewResult.status == AiReviewDispatchStatus.failed) {
            throw Exception(reviewResult.message ?? 'review_dispatch_failed');
          }

          await _repository.updateItem(
            item.queueItemId,
            status: SyncQueueItemStatus.completed,
            lastError: null,
          );
          await _eventLogRepository.append(
            'sync_queue_completed',
            payload: <String, Object?>{
              'activityId': item.activityId,
              'taskId': item.taskId,
              'queueItemId': item.queueItemId,
            },
          );
          await submissionStorage.deleteIfExists(localPath);
          onActivitySynced(item.activityId);
        } catch (error) {
          await _repository.updateItem(
            item.queueItemId,
            status: SyncQueueItemStatus.failed,
            lastError: error.toString(),
          );
          await _eventLogRepository.append(
            'sync_queue_failed',
            payload: <String, Object?>{
              'activityId': item.activityId,
              'taskId': item.taskId,
              'queueItemId': item.queueItemId,
              'error': error.toString(),
            },
          );
        }
      }
    } finally {
      _isProcessing = false;
      await _load();
    }
  }
}

final syncQueueStatusProvider =
    StateNotifierProvider<SyncQueueController, AsyncValue<SyncQueueStatus>>((
      ref,
    ) {
      final repository = ref.watch(syncQueueRepositoryProvider);
      final eventLogRepository = ref.watch(appEventLogRepositoryProvider);
      return SyncQueueController(repository, eventLogRepository);
    });

final syncQueuePendingCountProvider = Provider.family<int, String>((
  ref,
  activityId,
) {
  final status = ref.watch(syncQueueStatusProvider);
  return status.maybeWhen(
    data: (value) => value.pendingCountForActivity(activityId),
    orElse: () => 0,
  );
});

final activitySyncQueueSummaryProvider =
    Provider.family<ActivitySyncQueueSummary, String>((ref, activityId) {
      final status = ref.watch(syncQueueStatusProvider);
      return status.maybeWhen(
        data: (value) {
          var pendingCount = 0;
          var syncingCount = 0;
          var failedCount = 0;

          for (final item in value.items) {
            if (item.activityId != activityId) {
              continue;
            }
            switch (item.status) {
              case SyncQueueItemStatus.pending:
                pendingCount += 1;
              case SyncQueueItemStatus.syncing:
                syncingCount += 1;
              case SyncQueueItemStatus.completed:
                break;
              case SyncQueueItemStatus.failed:
                failedCount += 1;
            }
          }

          return ActivitySyncQueueSummary(
            pendingCount: pendingCount,
            syncingCount: syncingCount,
            failedCount: failedCount,
          );
        },
        orElse: ActivitySyncQueueSummary.new,
      );
    });
