import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_starter/features/portal/data/app_event_log_repository.dart';
import 'package:flutter_starter/features/portal/data/local_cache_repository.dart';

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
    'app event log repository stores event payloads with timestamps',
    () async {
      final cache = _FakeLocalCacheRepository();
      final repository = LocalAppEventLogRepository(cache);

      await repository.append(
        'submission_succeeded',
        payload: <String, Object?>{'activityId': 'activity-1', 'stars': 8},
      );

      final entries = await repository.readRecent();

      expect(entries, hasLength(1));
      final first = entries.first;
      expect(first.eventName, 'submission_succeeded');
      expect(first.payload, <String, Object?>{
        'activityId': 'activity-1',
        'stars': 8,
      });
      expect(first.timestamp, isA<DateTime>());
    },
  );

  test('app event log repository keeps only the latest 80 entries', () async {
    final cache = _FakeLocalCacheRepository();
    final repository = LocalAppEventLogRepository(cache);

    for (var index = 0; index < 82; index++) {
      await repository.append(
        'event_$index',
        payload: <String, Object?>{'index': index},
      );
    }

    final entries = await repository.readRecent(limit: 80);

    expect(entries, hasLength(80));
    expect(entries.first.eventName, 'event_2');
    expect(entries.last.eventName, 'event_81');
  });

  test('app event log repository can clear all entries', () async {
    final cache = _FakeLocalCacheRepository();
    final repository = LocalAppEventLogRepository(cache);

    await repository.append('sync_queue_completed');
    await repository.clear();

    expect(await repository.readRecent(), isEmpty);
    expect(await cache.readJson('student_app_event_log_v1'), isNull);
  });
}
