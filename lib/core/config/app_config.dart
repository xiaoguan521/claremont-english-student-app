import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppDataMode { mock, supabase }

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

  static AppConfig fromEnv() {
    Map<String, String> env = const {};
    try {
      env = dotenv.env;
    } catch (_) {
      env = const {};
    }

    final modeValue = env['APP_DATA_MODE']?.trim().toLowerCase() ?? 'mock';
    final url =
        env['SUPABASE_URL']?.trim() ??
        env['NEXT_PUBLIC_SUPABASE_URL']?.trim() ??
        '';
    final publishableKey =
        env['SUPABASE_ANON_KEY']?.trim() ??
        env['NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY']?.trim() ??
        '';

    return AppConfig(
      dataMode: modeValue == 'supabase'
          ? AppDataMode.supabase
          : AppDataMode.mock,
      supabaseUrl: url,
      supabasePublishableKey: publishableKey,
    );
  }
}

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnv());
