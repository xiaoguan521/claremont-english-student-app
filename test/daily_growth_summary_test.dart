import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_starter/features/portal/data/local_cache_repository.dart';
import 'package:flutter_starter/features/portal/presentation/providers/parent_contact_providers.dart';

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
  test('daily growth summary aggregates snapshots for today widgets', () async {
    final cache = _FakeLocalCacheRepository({
      'parent_contact_snapshot_activity-1': <String, dynamic>{
        'completedTasks': 2,
        'earnedStars': 8,
        'comboCount': 3,
        'backgroundSwitchCount': 1,
        'breakReminderCount': 0,
      },
      'parent_contact_snapshot_activity-2': <String, dynamic>{
        'completedTasks': 1,
        'earnedStars': 5,
        'comboCount': 6,
        'backgroundSwitchCount': 0,
        'breakReminderCount': 1,
      },
      'parent_contact_snapshot_activity-3': <String, dynamic>{
        'completedTasks': 3,
        'earnedStars': 2,
        'comboCount': 4,
        'backgroundSwitchCount': 2,
        'breakReminderCount': 2,
      },
      'unrelated_cache_key': <String, dynamic>{'earnedStars': 999},
    });

    final container = ProviderContainer(
      overrides: [localCacheRepositoryProvider.overrideWithValue(cache)],
    );
    addTearDown(container.dispose);

    final summary = await container.read(dailyGrowthSummaryProvider.future);

    expect(summary.totalStars, 15);
    expect(summary.bestCombo, 6);
    expect(summary.completedTasks, 6);
    expect(summary.breakReminderCount, 3);
    expect(summary.backgroundSwitchCount, 3);
  });
}
