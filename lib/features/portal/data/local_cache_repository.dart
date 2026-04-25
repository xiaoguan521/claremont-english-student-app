import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/theme_provider.dart';

abstract class LocalCacheRepository {
  Future<Map<String, dynamic>?> readJson(String key);

  Future<Map<String, Map<String, dynamic>>> readJsonMapByPrefix(String prefix);

  Future<void> writeJson(String key, Map<String, dynamic> value);

  Future<void> remove(String key);
}

class SharedPrefsLocalCacheRepository implements LocalCacheRepository {
  const SharedPrefsLocalCacheRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<Map<String, dynamic>?> readJson(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
    } catch (_) {
      await remove(key);
    }
    return null;
  }

  @override
  Future<Map<String, Map<String, dynamic>>> readJsonMapByPrefix(
    String prefix,
  ) async {
    final results = <String, Map<String, dynamic>>{};
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(prefix)) {
        continue;
      }
      final value = await readJson(key);
      if (value != null) {
        results[key] = value;
      }
    }
    return results;
  }

  @override
  Future<void> writeJson(String key, Map<String, dynamic> value) {
    return _prefs.setString(key, jsonEncode(value));
  }

  @override
  Future<void> remove(String key) {
    return _prefs.remove(key);
  }
}

final localCacheRepositoryProvider = Provider<LocalCacheRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPrefsLocalCacheRepository(prefs);
});
