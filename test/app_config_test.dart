import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('defaults to mock mode for development builds', () {
      final config = AppConfig.fromValues(
        const <String, String>{},
        isReleaseBuild: false,
      );

      expect(config.dataMode, AppDataMode.mock);
      expect(config.usesMockData, isTrue);
      expect(config.canUseSupabase, isFalse);
    });

    test('allows Supabase mode when required values are present', () {
      final config = AppConfig.fromValues(
        const <String, String>{
          'APP_DATA_MODE': 'supabase',
          'SUPABASE_URL': 'https://example.supabase.co',
          'SUPABASE_ANON_KEY': 'publishable-key',
        },
        isReleaseBuild: true,
      );

      expect(config.dataMode, AppDataMode.supabase);
      expect(config.canUseSupabase, isTrue);
      expect(config.usesMockData, isFalse);
    });

    test('rejects silent mock fallback in release builds', () {
      expect(
        () => AppConfig.fromValues(
          const <String, String>{},
          isReleaseBuild: true,
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('allows release mock only when explicitly marked for QA', () {
      final config = AppConfig.fromValues(
        const <String, String>{'ALLOW_RELEASE_MOCK_DATA': 'true'},
        isReleaseBuild: true,
      );

      expect(config.dataMode, AppDataMode.mock);
    });

    test('rejects release Supabase mode without credentials', () {
      expect(
        () => AppConfig.fromValues(
          const <String, String>{'APP_DATA_MODE': 'supabase'},
          isReleaseBuild: true,
        ),
        throwsA(isA<AppConfigException>()),
      );
    });
  });
}
