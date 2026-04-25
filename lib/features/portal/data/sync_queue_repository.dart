import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/theme_provider.dart';

enum SyncQueueItemStatus { pending, syncing, completed, failed }

class SyncQueueItem {
  const SyncQueueItem({
    required this.queueItemId,
    required this.activityId,
    required this.taskId,
    required this.attemptUuid,
    required this.clientSubmissionId,
    required this.fileName,
    required this.sizeBytes,
    required this.createdAt,
    this.localPath,
    this.mimeType,
    this.status = SyncQueueItemStatus.pending,
    this.lastError,
  });

  final String queueItemId;
  final String activityId;
  final String taskId;
  final String attemptUuid;
  final String clientSubmissionId;
  final String fileName;
  final int sizeBytes;
  final DateTime createdAt;
  final String? localPath;
  final String? mimeType;
  final SyncQueueItemStatus status;
  final String? lastError;

  SyncQueueItem copyWith({
    String? localPath,
    String? mimeType,
    SyncQueueItemStatus? status,
    String? lastError,
  }) {
    return SyncQueueItem(
      queueItemId: queueItemId,
      activityId: activityId,
      taskId: taskId,
      attemptUuid: attemptUuid,
      clientSubmissionId: clientSubmissionId,
      fileName: fileName,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
      localPath: localPath ?? this.localPath,
      mimeType: mimeType ?? this.mimeType,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'queueItemId': queueItemId,
      'activityId': activityId,
      'taskId': taskId,
      'attemptUuid': attemptUuid,
      'clientSubmissionId': clientSubmissionId,
      'fileName': fileName,
      'sizeBytes': sizeBytes,
      'createdAt': createdAt.toIso8601String(),
      'localPath': localPath,
      'mimeType': mimeType,
      'status': status.name,
      'lastError': lastError,
    };
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      queueItemId: map['queueItemId'] as String? ?? '',
      activityId: map['activityId'] as String? ?? '',
      taskId: map['taskId'] as String? ?? '',
      attemptUuid: map['attemptUuid'] as String? ?? '',
      clientSubmissionId: map['clientSubmissionId'] as String? ?? '',
      fileName: map['fileName'] as String? ?? 'audio.m4a',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      localPath: map['localPath'] as String?,
      mimeType: map['mimeType'] as String?,
      status: SyncQueueItemStatus.values.byName(
        map['status'] as String? ?? SyncQueueItemStatus.pending.name,
      ),
      lastError: map['lastError'] as String?,
    );
  }
}

abstract class SyncQueueRepository {
  Future<List<SyncQueueItem>> listItems();

  Future<SyncQueueItem> enqueue(SyncQueueItem item);

  Future<SyncQueueItem?> updateItem(
    String queueItemId, {
    SyncQueueItemStatus? status,
    String? lastError,
  });
}

class SharedPrefsSyncQueueRepository implements SyncQueueRepository {
  const SharedPrefsSyncQueueRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _storageKey = 'student_app_sync_queue_items';

  @override
  Future<SyncQueueItem> enqueue(SyncQueueItem item) async {
    final items = await listItems();
    final nextItems = [...items, item];
    await _writeItems(nextItems);
    return item;
  }

  @override
  Future<List<SyncQueueItem>> listItems() async {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map((item) => SyncQueueItem.fromMap(item.cast<String, dynamic>()))
          .toList()
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    } catch (_) {
      await _prefs.remove(_storageKey);
      return const [];
    }
  }

  @override
  Future<SyncQueueItem?> updateItem(
    String queueItemId, {
    SyncQueueItemStatus? status,
    String? lastError,
  }) async {
    final items = await listItems();
    SyncQueueItem? updatedItem;
    final nextItems = items.map((item) {
      if (item.queueItemId != queueItemId) {
        return item;
      }
      updatedItem = item.copyWith(status: status, lastError: lastError);
      return updatedItem!;
    }).toList();

    await _writeItems(nextItems);
    return updatedItem;
  }

  Future<void> _writeItems(List<SyncQueueItem> items) {
    final payload = items.map((item) => item.toMap()).toList();
    return _prefs.setString(_storageKey, jsonEncode(payload));
  }
}

final syncQueueRepositoryProvider = Provider<SyncQueueRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPrefsSyncQueueRepository(prefs);
});
