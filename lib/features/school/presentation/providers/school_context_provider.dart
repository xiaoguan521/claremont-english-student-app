import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _preferredSchoolSlugKey = 'preferred_school_slug';

class SchoolContext {
  const SchoolContext({
    required this.schoolId,
    required this.slug,
    required this.schoolName,
    required this.displayName,
    required this.welcomeTitle,
    required this.welcomeMessage,
    required this.themeKey,
    required this.logoUrl,
  });

  final String? schoolId;
  final String slug;
  final String schoolName;
  final String displayName;
  final String welcomeTitle;
  final String welcomeMessage;
  final String themeKey;
  final String logoUrl;

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
    final nextSlug = slug == null || slug.isEmpty ? 'school' : slug;
    return SchoolContext(
      schoolId: null,
      slug: nextSlug,
      schoolName: '',
      displayName: '',
      welcomeTitle: _defaultWelcomeTitle(''),
      welcomeMessage: '今天也要完成老师布置的学习任务。',
      themeKey: 'forest',
      logoUrl: '',
    );
  }

  factory SchoolContext.selectionRequired() {
    return const SchoolContext(
      schoolId: null,
      slug: 'select-school',
      schoolName: '',
      displayName: '',
      welcomeTitle: '请选择你的学校',
      welcomeMessage: '这个账号已绑定多个学校，请先选择今天要进入的学校。',
      themeKey: 'ocean',
      logoUrl: '',
    );
  }
}

String _defaultWelcomeTitle(String brandName) {
  return brandName.isNotEmpty ? '欢迎来到$brandName' : '欢迎使用学习入口';
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

final availableSchoolContextsProvider = FutureProvider<List<SchoolContext>>((
  ref,
) async {
  final preferredSlug = ref.watch(preferredSchoolSlugProvider);

  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    return [SchoolContext.fallback(preferredSlug)];
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
    return [];
  }

  return _fetchAvailableSchools(client, schoolIds);
});

final schoolSelectionRequiredProvider = FutureProvider<bool>((ref) async {
  final preferredSlug = ref.watch(preferredSchoolSlugProvider);
  final options = await ref.watch(availableSchoolContextsProvider.future);

  if (options.length <= 1) {
    return false;
  }

  if (preferredSlug == null || preferredSlug.isEmpty) {
    return true;
  }

  return !options.any((item) => item.slug == preferredSlug);
});

final schoolContextProvider = FutureProvider<SchoolContext>((ref) async {
  final preferredSlug = ref.watch(preferredSchoolSlugProvider);

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
  final options = await ref.watch(availableSchoolContextsProvider.future);
  if (options.isEmpty) {
    return SchoolContext.fallback(preferredSlug);
  }

  if (preferredSlug != null && preferredSlug.isNotEmpty) {
    SchoolContext? matched;
    for (final item in options) {
      if (item.slug == preferredSlug) {
        matched = item;
        break;
      }
    }
    if (matched != null) {
      return matched;
    }
  }

  if (options.length == 1) {
    return options.first;
  }

  return SchoolContext.selectionRequired();
});

Future<SchoolContext?> _fetchBySlug(SupabaseClient client, String slug) async {
  try {
    final response = await client
        .from('school_configs')
        .select(
          'school_id, slug, app_display_name, welcome_title, welcome_message, theme_key, brand_name, logo_url',
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
  final brandName = (row['brand_name'] as String?)?.trim() ?? '';
  final appDisplayName =
      (row['app_display_name'] as String?)?.trim() ?? brandName;
  final displayName = appDisplayName.isNotEmpty ? appDisplayName : brandName;
  final welcomeTitle = (row['welcome_title'] as String?)?.trim();
  final welcomeMessage = (row['welcome_message'] as String?)?.trim();

  return SchoolContext(
    schoolId: row['school_id'] as String?,
    slug: (row['slug'] as String?) ?? 'school',
    schoolName: brandName,
    displayName: displayName,
    welcomeTitle: welcomeTitle == null || welcomeTitle.isEmpty
        ? _defaultWelcomeTitle(displayName)
        : welcomeTitle,
    welcomeMessage: welcomeMessage == null || welcomeMessage.isEmpty
        ? '今天也要认真完成英语学习任务。'
        : welcomeMessage,
    themeKey: (row['theme_key'] as String?) ?? 'forest',
    logoUrl: (row['logo_url'] as String?)?.trim() ?? '',
  );
}

Future<List<SchoolContext>> _fetchAvailableSchools(
  SupabaseClient client,
  List<String> schoolIds,
) async {
  try {
    final response = await client
        .from('school_configs')
        .select(
          'school_id, slug, app_display_name, welcome_title, welcome_message, theme_key, brand_name, logo_url',
        )
        .inFilter('school_id', schoolIds);

    final rows = List<Map<String, dynamic>>.from(response);
    if (rows.isNotEmpty) {
      return rows.map(_mapSchoolContext).toList();
    }
  } catch (_) {
    // Allow the app to keep working before school_configs is migrated remotely.
  }

  final schoolResponse = await client
      .from('schools')
      .select('id, code, name')
      .inFilter('id', schoolIds);

  return List<Map<String, dynamic>>.from(schoolResponse).map((row) {
    final slug = (row['code'] as String?) ?? 'school';
    final schoolName = (row['name'] as String?)?.trim() ?? '';
    return SchoolContext(
      schoolId: row['id'] as String?,
      slug: slug,
      schoolName: schoolName,
      displayName: schoolName,
      welcomeTitle: _defaultWelcomeTitle(schoolName),
      welcomeMessage: '今天也要认真完成英语学习任务。',
      themeKey: 'forest',
      logoUrl: '',
    );
  }).toList();
}
