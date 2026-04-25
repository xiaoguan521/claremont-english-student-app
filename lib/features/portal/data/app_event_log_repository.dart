import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_cache_repository.dart';

class AppEventLogEntry {
  const AppEventLogEntry({
    required this.eventName,
    required this.payload,
    required this.timestamp,
  });

  final String eventName;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'eventName': eventName,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AppEventLogEntry.fromMap(Map<String, dynamic> map) {
    return AppEventLogEntry(
      eventName: map['eventName'] as String? ?? 'unknown_event',
      payload:
          (map['payload'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      timestamp:
          DateTime.tryParse(map['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

abstract class AppEventLogRepository {
  Future<void> append(
    String eventName, {
    Map<String, Object?> payload = const <String, Object?>{},
  });

  Future<List<AppEventLogEntry>> readRecent({int limit = 30});

  Future<void> clear();
}

class LocalAppEventLogRepository implements AppEventLogRepository {
  const LocalAppEventLogRepository(this._cache);

  static const _storageKey = 'student_app_event_log_v1';
  static const _maxEntries = 80;

  final LocalCacheRepository _cache;

  @override
  Future<void> append(
    String eventName, {
    Map<String, Object?> payload = const <String, Object?>{},
  }) async {
    final entries = await readRecent(limit: _maxEntries);
    final nextEntries = [
      ...entries,
      AppEventLogEntry(
        eventName: eventName,
        payload: payload.cast<String, dynamic>(),
        timestamp: DateTime.now(),
      ),
    ];
    final trimmed = nextEntries.length <= _maxEntries
        ? nextEntries
        : nextEntries.sublist(nextEntries.length - _maxEntries);
    await _cache.writeJson(_storageKey, <String, dynamic>{
      'entries': trimmed.map((entry) => entry.toMap()).toList(),
    });
  }

  @override
  Future<List<AppEventLogEntry>> readRecent({int limit = 30}) async {
    final existing = await _cache.readJson(_storageKey);
    final entries =
        (existing?['entries'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (item) => AppEventLogEntry.fromMap(item.cast<String, dynamic>()),
            )
            .toList();
    if (entries.length <= limit) {
      return entries;
    }
    return entries.sublist(entries.length - limit);
  }

  @override
  Future<void> clear() {
    return _cache.remove(_storageKey);
  }
}

final appEventLogRepositoryProvider = Provider<AppEventLogRepository>((ref) {
  final cache = ref.watch(localCacheRepositoryProvider);
  return LocalAppEventLogRepository(cache);
});

final appEventLogEntriesProvider = FutureProvider<List<AppEventLogEntry>>((
  ref,
) async {
  final repository = ref.watch(appEventLogRepositoryProvider);
  return repository.readRecent();
});
