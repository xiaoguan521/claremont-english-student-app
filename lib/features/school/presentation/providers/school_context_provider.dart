import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';

const _preferredSchoolSlugKey = 'preferred_school_slug';

class SchoolContext {
  const SchoolContext({
    required this.schoolId,
    required this.slug,
    required this.displayName,
    required this.welcomeTitle,
    required this.welcomeMessage,
    required this.themeKey,
  });

  final String? schoolId;
  final String slug;
  final String displayName;
  final String welcomeTitle;
  final String welcomeMessage;
  final String themeKey;

  Color get primaryColor {
    switch (themeKey) {
      case 'sunrise':
        return const Color(0xFFFF8A65);
      case 'ocean':
        return const Color(0xFF2F67F6);
      case 'berry':
        return const Color(0xFF8B5CF6);
      case 'forest':
      default:
        return const Color(0xFF309A7A);
    }
  }

  Color get secondaryColor {
    switch (themeKey) {
      case 'sunrise':
        return const Color(0xFFFFC46C);
      case 'ocean':
        return const Color(0xFF69C8FF);
      case 'berry':
        return const Color(0xFFE879F9);
      case 'forest':
      default:
        return const Color(0xFF9AD76C);
    }
  }

  factory SchoolContext.fallback([String? slug]) {
    final nextSlug = slug == null || slug.isEmpty ? 'claremont-demo' : slug;
    return SchoolContext(
      schoolId: null,
      slug: nextSlug,
      displayName: '英语打卡',
      welcomeTitle: '欢迎来到英语打卡',
      welcomeMessage: '今天也要完成老师布置的学习任务。',
      themeKey: 'forest',
    );
  }
}

class PreferredSchoolSlugNotifier extends StateNotifier<String?> {
  PreferredSchoolSlugNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_preferredSchoolSlugKey);
  }

  Future<void> setSlug(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredSchoolSlugKey, slug);
    state = slug;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_preferredSchoolSlugKey);
    state = null;
  }
}

final preferredSchoolSlugProvider =
    StateNotifierProvider<PreferredSchoolSlugNotifier, String?>((ref) {
      return PreferredSchoolSlugNotifier();
    });

final schoolContextProvider = FutureProvider<SchoolContext>((ref) async {
  final config = ref.watch(appConfigProvider);
  final preferredSlug = ref.watch(preferredSchoolSlugProvider);

  if (!config.canUseSupabase) {
    return SchoolContext.fallback(preferredSlug);
  }

  final client = Supabase.instance.client;

  if (preferredSlug != null && preferredSlug.isNotEmpty) {
    final preferredContext = await _fetchBySlug(client, preferredSlug);
    if (preferredContext != null) {
      return preferredContext;
    }
  }

  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    return SchoolContext.fallback(preferredSlug);
  }

  final membershipsResponse = await client
      .from('memberships')
      .select('school_id')
      .eq('user_id', userId)
      .eq('status', 'active');

  final schoolIds = List<Map<String, dynamic>>.from(membershipsResponse)
      .map((row) => row['school_id'] as String?)
      .whereType<String>()
      .toSet()
      .toList();

  if (schoolIds.isEmpty) {
    return SchoolContext.fallback(preferredSlug);
  }

  try {
    final configResponse = await client
        .from('school_configs')
        .select(
          'school_id, slug, app_display_name, welcome_title, welcome_message, theme_key',
        )
        .inFilter('school_id', schoolIds)
        .limit(1)
        .maybeSingle();

    if (configResponse != null) {
      final row = Map<String, dynamic>.from(configResponse);
      return _mapSchoolContext(row);
    }
  } catch (_) {
    // Allow the app to keep working before school_configs is migrated remotely.
  }

  final schoolResponse = await client
      .from('schools')
      .select('id, code, name')
      .inFilter('id', schoolIds)
      .limit(1)
      .maybeSingle();

  if (schoolResponse == null) {
    return SchoolContext.fallback(preferredSlug);
  }

  final row = Map<String, dynamic>.from(schoolResponse);
  return SchoolContext(
    schoolId: row['id'] as String?,
    slug: (row['code'] as String?) ?? preferredSlug ?? 'school',
    displayName: (row['name'] as String?) ?? '英语打卡',
    welcomeTitle: '欢迎来到${(row['name'] as String?) ?? '英语打卡'}',
    welcomeMessage: '今天也要认真完成英语学习任务。',
    themeKey: 'forest',
  );
});

Future<SchoolContext?> _fetchBySlug(SupabaseClient client, String slug) async {
  try {
    final response = await client
        .from('school_configs')
        .select(
          'school_id, slug, app_display_name, welcome_title, welcome_message, theme_key',
        )
        .eq('slug', slug)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return _mapSchoolContext(Map<String, dynamic>.from(response));
  } catch (_) {
    return null;
  }
}

SchoolContext _mapSchoolContext(Map<String, dynamic> row) {
  return SchoolContext(
    schoolId: row['school_id'] as String?,
    slug: (row['slug'] as String?) ?? 'school',
    displayName: (row['app_display_name'] as String?) ?? '英语打卡',
    welcomeTitle: (row['welcome_title'] as String?) ?? '欢迎来到英语打卡',
    welcomeMessage: (row['welcome_message'] as String?) ?? '今天也要认真完成英语学习任务。',
    themeKey: (row['theme_key'] as String?) ?? 'forest',
  );
}
