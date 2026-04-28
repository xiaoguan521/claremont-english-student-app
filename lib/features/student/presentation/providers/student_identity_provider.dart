import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

const _selectedStudentProfileIdKey = 'selected_student_profile_id';

class StudentIdentityProfile {
  const StudentIdentityProfile({
    required this.id,
    required this.displayName,
    required this.subtitle,
    this.avatarUrl = '',
  });

  final String id;
  final String displayName;
  final String subtitle;
  final String avatarUrl;
}

class SelectedStudentProfileNotifier extends StateNotifier<String?> {
  SelectedStudentProfileNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_selectedStudentProfileIdKey);
  }

  Future<void> select(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedStudentProfileIdKey, profileId);
    state = profileId;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedStudentProfileIdKey);
    state = null;
  }
}

final selectedStudentProfileProvider =
    StateNotifierProvider<SelectedStudentProfileNotifier, String?>((ref) {
      return SelectedStudentProfileNotifier();
    });

final availableStudentProfilesProvider =
    FutureProvider<List<StudentIdentityProfile>>((ref) async {
      final currentEmail = ref.watch(currentUserEmailProvider);
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId != null) {
        final profiles = await _fetchProfiles(client, userId);
        if (profiles.isNotEmpty) {
          return profiles;
        }
      }

      return [
        StudentIdentityProfile(
          id: userId ?? 'current-student',
          displayName: _studentDisplayName(currentEmail),
          subtitle: currentEmail ?? '默认学生账号',
        ),
      ];
    });

final studentIdentitySelectionRequiredProvider = FutureProvider<bool>((
  ref,
) async {
  final selectedId = ref.watch(selectedStudentProfileProvider);
  final profiles = await ref.watch(availableStudentProfilesProvider.future);
  if (profiles.length <= 1) {
    return false;
  }
  if (selectedId == null || selectedId.isEmpty) {
    return true;
  }
  return !profiles.any((profile) => profile.id == selectedId);
});

Future<List<StudentIdentityProfile>> _fetchProfiles(
  SupabaseClient client,
  String userId,
) async {
  try {
    final response = await client
        .from('student_profiles')
        .select('id, display_name, class_name, avatar_url')
        .eq('guardian_user_id', userId)
        .eq('status', 'active');
    return List<Map<String, dynamic>>.from(response)
        .map(
          (row) => StudentIdentityProfile(
            id: (row['id'] as String?) ?? '',
            displayName:
                (row['display_name'] as String?)?.trim().isNotEmpty == true
                ? (row['display_name'] as String).trim()
                : '小同学',
            subtitle: (row['class_name'] as String?)?.trim().isNotEmpty == true
                ? (row['class_name'] as String).trim()
                : '英语学习账号',
            avatarUrl: (row['avatar_url'] as String?)?.trim() ?? '',
          ),
        )
        .where((profile) => profile.id.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
}

String _studentDisplayName(String? email) {
  if (email == null || email.trim().isEmpty) {
    return '小同学';
  }
  final local = email.split('@').first.trim();
  if (local.isEmpty) {
    return '小同学';
  }
  if (local.length <= 6) {
    return local;
  }
  return '${local.substring(0, 6)}同学';
}
