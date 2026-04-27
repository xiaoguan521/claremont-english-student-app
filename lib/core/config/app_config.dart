import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppDataMode { mock, supabase }

class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}

class AppConfig {
  const AppConfig({
    required this.dataMode,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  final AppDataMode dataMode;
  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get canUseSupabase =>
      dataMode == AppDataMode.supabase &&
      supabaseUrl.isNotEmpty &&
      supabasePublishableKey.isNotEmpty;

  bool get usesMockData => dataMode == AppDataMode.mock;

  static AppConfig fromEnv({bool isReleaseBuild = kReleaseMode}) {
    Map<String, String> env = const {};
    try {
      env = dotenv.env;
    } catch (_) {
      env = const {};
    }

    return fromValues(env, isReleaseBuild: isReleaseBuild);
  }

  static AppConfig fromValues(
    Map<String, String> env, {
    bool isReleaseBuild = kReleaseMode,
  }) {
    final modeValue = env['APP_DATA_MODE']?.trim().toLowerCase() ?? 'mock';
    final dataMode = modeValue == 'supabase'
        ? AppDataMode.supabase
        : AppDataMode.mock;
    final url =
        env['SUPABASE_URL']?.trim() ??
        env['NEXT_PUBLIC_SUPABASE_URL']?.trim() ??
        '';
    final publishableKey =
        env['SUPABASE_ANON_KEY']?.trim() ??
        env['NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY']?.trim() ??
        '';
    final allowReleaseMock =
        env['ALLOW_RELEASE_MOCK_DATA']?.trim().toLowerCase() == 'true';

    final config = AppConfig(
      dataMode: dataMode,
      supabaseUrl: url,
      supabasePublishableKey: publishableKey,
    );

    if (isReleaseBuild && !allowReleaseMock && config.usesMockData) {
      throw const AppConfigException(
        'Release builds must use APP_DATA_MODE=supabase. '
        'Set ALLOW_RELEASE_MOCK_DATA=true only for internal QA builds.',
      );
    }

    if (isReleaseBuild &&
        dataMode == AppDataMode.supabase &&
        !config.canUseSupabase) {
      throw const AppConfigException(
        'Release Supabase mode requires SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }

    return config;
  }
}

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnv());
