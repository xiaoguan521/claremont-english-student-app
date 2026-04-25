import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/theme_provider.dart';

class StudentFeatureFlags {
  const StudentFeatureFlags({
    this.showGrowthRewards = true,
    this.showEnhancedHealthInsights = true,
    this.showFunZonePromos = true,
  });

  final bool showGrowthRewards;
  final bool showEnhancedHealthInsights;
  final bool showFunZonePromos;

  StudentFeatureFlags copyWith({
    bool? showGrowthRewards,
    bool? showEnhancedHealthInsights,
    bool? showFunZonePromos,
  }) {
    return StudentFeatureFlags(
      showGrowthRewards: showGrowthRewards ?? this.showGrowthRewards,
      showEnhancedHealthInsights:
          showEnhancedHealthInsights ?? this.showEnhancedHealthInsights,
      showFunZonePromos: showFunZonePromos ?? this.showFunZonePromos,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'showGrowthRewards': showGrowthRewards,
      'showEnhancedHealthInsights': showEnhancedHealthInsights,
      'showFunZonePromos': showFunZonePromos,
    };
  }

  factory StudentFeatureFlags.fromMap(
    Map<String, dynamic> map, {
    required StudentFeatureFlags fallback,
  }) {
    return StudentFeatureFlags(
      showGrowthRewards:
          map['showGrowthRewards'] as bool? ?? fallback.showGrowthRewards,
      showEnhancedHealthInsights:
          map['showEnhancedHealthInsights'] as bool? ??
          fallback.showEnhancedHealthInsights,
      showFunZonePromos:
          map['showFunZonePromos'] as bool? ?? fallback.showFunZonePromos,
    );
  }
}

const _studentFeatureFlagsKey = 'student_feature_flags_override_v1';

final studentFeatureFlagDefaultsProvider = Provider<StudentFeatureFlags>((ref) {
  return const StudentFeatureFlags(
    showGrowthRewards: bool.fromEnvironment(
      'STUDENT_SHOW_GROWTH_REWARDS',
      defaultValue: true,
    ),
    showEnhancedHealthInsights: bool.fromEnvironment(
      'STUDENT_SHOW_ENHANCED_HEALTH_INSIGHTS',
      defaultValue: true,
    ),
    showFunZonePromos: bool.fromEnvironment(
      'STUDENT_SHOW_FUN_ZONE_PROMOS',
      defaultValue: true,
    ),
  );
});

class StudentFeatureFlagsController extends StateNotifier<StudentFeatureFlags> {
  StudentFeatureFlagsController(this._prefs, StudentFeatureFlags defaults)
    : super(_restore(_prefs, defaults));

  final SharedPreferences _prefs;

  static StudentFeatureFlags _restore(
    SharedPreferences prefs,
    StudentFeatureFlags defaults,
  ) {
    return StudentFeatureFlags(
      showGrowthRewards:
          prefs.getBool('${_studentFeatureFlagsKey}_showGrowthRewards') ??
          defaults.showGrowthRewards,
      showEnhancedHealthInsights:
          prefs.getBool(
            '${_studentFeatureFlagsKey}_showEnhancedHealthInsights',
          ) ??
          defaults.showEnhancedHealthInsights,
      showFunZonePromos:
          prefs.getBool('${_studentFeatureFlagsKey}_showFunZonePromos') ??
          defaults.showFunZonePromos,
    );
  }

  Future<void> update(StudentFeatureFlags next) async {
    await _prefs.setBool(
      '${_studentFeatureFlagsKey}_showGrowthRewards',
      next.showGrowthRewards,
    );
    await _prefs.setBool(
      '${_studentFeatureFlagsKey}_showEnhancedHealthInsights',
      next.showEnhancedHealthInsights,
    );
    await _prefs.setBool(
      '${_studentFeatureFlagsKey}_showFunZonePromos',
      next.showFunZonePromos,
    );
    state = next;
  }

  Future<void> resetToDefaults(StudentFeatureFlags defaults) async {
    await _prefs.remove('${_studentFeatureFlagsKey}_showGrowthRewards');
    await _prefs.remove(
      '${_studentFeatureFlagsKey}_showEnhancedHealthInsights',
    );
    await _prefs.remove('${_studentFeatureFlagsKey}_showFunZonePromos');
    state = defaults;
  }
}

final studentFeatureFlagsControllerProvider =
    StateNotifierProvider<StudentFeatureFlagsController, StudentFeatureFlags>((
      ref,
    ) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final defaults = ref.watch(studentFeatureFlagDefaultsProvider);
      return StudentFeatureFlagsController(prefs, defaults);
    });

final studentFeatureFlagsProvider = Provider<StudentFeatureFlags>((ref) {
  return ref.watch(studentFeatureFlagsControllerProvider);
});
