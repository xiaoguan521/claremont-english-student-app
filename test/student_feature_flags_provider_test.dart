import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/core/providers/theme_provider.dart';
import 'package:flutter_starter/features/portal/presentation/providers/student_feature_flags_provider.dart';

void main() {
  test(
    'student feature flags read persisted overrides from shared prefs',
    () async {
      SharedPreferences.setMockInitialValues({
        'student_feature_flags_override_v1_showGrowthRewards': false,
        'student_feature_flags_override_v1_showEnhancedHealthInsights': true,
        'student_feature_flags_override_v1_showFunZonePromos': false,
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final flags = container.read(studentFeatureFlagsProvider);

      expect(flags.showGrowthRewards, isFalse);
      expect(flags.showEnhancedHealthInsights, isTrue);
      expect(flags.showFunZonePromos, isFalse);
    },
  );

  test(
    'student feature flags controller can persist updates and reset',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        studentFeatureFlagsControllerProvider.notifier,
      );

      await controller.update(
        const StudentFeatureFlags(
          showGrowthRewards: false,
          showEnhancedHealthInsights: false,
          showFunZonePromos: true,
        ),
      );

      expect(
        container.read(studentFeatureFlagsProvider).showGrowthRewards,
        isFalse,
      );
      expect(
        prefs.getBool(
          'student_feature_flags_override_v1_showEnhancedHealthInsights',
        ),
        isFalse,
      );

      await controller.resetToDefaults(
        const StudentFeatureFlags(
          showGrowthRewards: true,
          showEnhancedHealthInsights: true,
          showFunZonePromos: false,
        ),
      );

      final resetFlags = container.read(studentFeatureFlagsProvider);
      expect(resetFlags.showGrowthRewards, isTrue);
      expect(resetFlags.showEnhancedHealthInsights, isTrue);
      expect(resetFlags.showFunZonePromos, isFalse);
      expect(
        prefs.containsKey(
          'student_feature_flags_override_v1_showGrowthRewards',
        ),
        isFalse,
      );
    },
  );
}
