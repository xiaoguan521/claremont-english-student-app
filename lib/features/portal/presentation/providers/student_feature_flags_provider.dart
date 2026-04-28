import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/theme_provider.dart';

class StudentFeatureFlags {
  const StudentFeatureFlags({
    this.newHomeDashboard = true,
    this.mainlineHeroTransition = true,
    this.abilityGym = true,
    this.learningMapV2 = true,
    this.practiceStageV2 = true,
    this.reviewCenterV2 = true,
    this.parentTrustSpace = true,
    this.showGrowthRewards = true,
    this.showEnhancedHealthInsights = true,
    this.showFunZonePromos = true,
  });

  final bool newHomeDashboard;
  final bool mainlineHeroTransition;
  final bool abilityGym;
  final bool learningMapV2;
  final bool practiceStageV2;
  final bool reviewCenterV2;
  final bool parentTrustSpace;
  final bool showGrowthRewards;
  final bool showEnhancedHealthInsights;
  final bool showFunZonePromos;

  StudentFeatureFlags copyWith({
    bool? newHomeDashboard,
    bool? mainlineHeroTransition,
    bool? abilityGym,
    bool? learningMapV2,
    bool? practiceStageV2,
    bool? reviewCenterV2,
    bool? parentTrustSpace,
    bool? showGrowthRewards,
    bool? showEnhancedHealthInsights,
    bool? showFunZonePromos,
  }) {
    return StudentFeatureFlags(
      newHomeDashboard: newHomeDashboard ?? this.newHomeDashboard,
      mainlineHeroTransition:
          mainlineHeroTransition ?? this.mainlineHeroTransition,
      abilityGym: abilityGym ?? this.abilityGym,
      learningMapV2: learningMapV2 ?? this.learningMapV2,
      practiceStageV2: practiceStageV2 ?? this.practiceStageV2,
      reviewCenterV2: reviewCenterV2 ?? this.reviewCenterV2,
      parentTrustSpace: parentTrustSpace ?? this.parentTrustSpace,
      showGrowthRewards: showGrowthRewards ?? this.showGrowthRewards,
      showEnhancedHealthInsights:
          showEnhancedHealthInsights ?? this.showEnhancedHealthInsights,
      showFunZonePromos: showFunZonePromos ?? this.showFunZonePromos,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'newHomeDashboard': newHomeDashboard,
      'mainlineHeroTransition': mainlineHeroTransition,
      'abilityGym': abilityGym,
      'learningMapV2': learningMapV2,
      'practiceStageV2': practiceStageV2,
      'reviewCenterV2': reviewCenterV2,
      'parentTrustSpace': parentTrustSpace,
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
      newHomeDashboard:
          map['newHomeDashboard'] as bool? ?? fallback.newHomeDashboard,
      mainlineHeroTransition:
          map['mainlineHeroTransition'] as bool? ??
          fallback.mainlineHeroTransition,
      abilityGym: map['abilityGym'] as bool? ?? fallback.abilityGym,
      learningMapV2: map['learningMapV2'] as bool? ?? fallback.learningMapV2,
      practiceStageV2:
          map['practiceStageV2'] as bool? ?? fallback.practiceStageV2,
      reviewCenterV2: map['reviewCenterV2'] as bool? ?? fallback.reviewCenterV2,
      parentTrustSpace:
          map['parentTrustSpace'] as bool? ?? fallback.parentTrustSpace,
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
    newHomeDashboard: bool.fromEnvironment(
      'STUDENT_NEW_HOME_DASHBOARD',
      defaultValue: true,
    ),
    mainlineHeroTransition: bool.fromEnvironment(
      'STUDENT_MAINLINE_HERO_TRANSITION',
      defaultValue: true,
    ),
    abilityGym: bool.fromEnvironment('STUDENT_ABILITY_GYM', defaultValue: true),
    learningMapV2: bool.fromEnvironment(
      'STUDENT_LEARNING_MAP_V2',
      defaultValue: true,
    ),
    practiceStageV2: bool.fromEnvironment(
      'STUDENT_PRACTICE_STAGE_V2',
      defaultValue: true,
    ),
    reviewCenterV2: bool.fromEnvironment(
      'STUDENT_REVIEW_CENTER_V2',
      defaultValue: true,
    ),
    parentTrustSpace: bool.fromEnvironment(
      'STUDENT_PARENT_TRUST_SPACE',
      defaultValue: true,
    ),
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
      newHomeDashboard: _readFlag(prefs, defaults, 'newHomeDashboard'),
      mainlineHeroTransition: _readFlag(
        prefs,
        defaults,
        'mainlineHeroTransition',
      ),
      abilityGym: _readFlag(prefs, defaults, 'abilityGym'),
      learningMapV2: _readFlag(prefs, defaults, 'learningMapV2'),
      practiceStageV2: _readFlag(prefs, defaults, 'practiceStageV2'),
      reviewCenterV2: _readFlag(prefs, defaults, 'reviewCenterV2'),
      parentTrustSpace: _readFlag(prefs, defaults, 'parentTrustSpace'),
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

  static bool _readFlag(
    SharedPreferences prefs,
    StudentFeatureFlags defaults,
    String key,
  ) {
    return prefs.getBool('${_studentFeatureFlagsKey}_$key') ??
        (defaults.toMap()[key] as bool? ?? true);
  }

  Future<void> update(StudentFeatureFlags next) async {
    await _prefs.setBool(
      '${_studentFeatureFlagsKey}_newHomeDashboard',
      next.newHomeDashboard,
    );
    await _prefs.setBool(
      '${_studentFeatureFlagsKey}_mainlineHeroTransition',
      next.mainlineHeroTransition,
    );
    await _prefs.setBool(
      '${_studentFeatureFlagsKey}_abilityGym',
      next.abilityGym,
    );
    await _prefs.setBool(
      '${_studentFeatureFlagsKey}_learningMapV2',
      next.learningMapV2,
    );
    await _prefs.setBool(
      '${_studentFeatureFlagsKey}_practiceStageV2',
      next.practiceStageV2,
    );
    await _prefs.setBool(
      '${_studentFeatureFlagsKey}_reviewCenterV2',
      next.reviewCenterV2,
    );
    await _prefs.setBool(
      '${_studentFeatureFlagsKey}_parentTrustSpace',
      next.parentTrustSpace,
    );
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
    await _prefs.remove('${_studentFeatureFlagsKey}_newHomeDashboard');
    await _prefs.remove('${_studentFeatureFlagsKey}_mainlineHeroTransition');
    await _prefs.remove('${_studentFeatureFlagsKey}_abilityGym');
    await _prefs.remove('${_studentFeatureFlagsKey}_learningMapV2');
    await _prefs.remove('${_studentFeatureFlagsKey}_practiceStageV2');
    await _prefs.remove('${_studentFeatureFlagsKey}_reviewCenterV2');
    await _prefs.remove('${_studentFeatureFlagsKey}_parentTrustSpace');
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
