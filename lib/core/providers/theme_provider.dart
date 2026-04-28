import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../constants/colors.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

part 'theme_provider.freezed.dart';

@freezed
class ThemeState with _$ThemeState {
  const factory ThemeState({
    required ThemeMode themeMode,
    required ColorSeed colorSeed,
  }) = _ThemeState;
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier(this.prefs, this.ref)
    : super(
        ThemeState(
          themeMode:
              ThemeMode.values[prefs.getInt(_themeModeKey) ??
                  1], // Default to light mode
          colorSeed: ColorSeed.values[prefs.getInt(_colorSeedKey) ?? 3],
        ),
      );

  final SharedPreferences prefs;
  final Ref ref;
  static const _themeModeKey = 'theme_mode';
  static const _colorSeedKey = 'color_seed';

  Future<void> setThemeMode(ThemeMode mode) async {
    // Only save to preferences if user is authenticated
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      await prefs.setInt(_themeModeKey, mode.index);
    }
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setColorSeed(ColorSeed seed) async {
    // Only save to preferences if user is authenticated
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      await prefs.setInt(_colorSeedKey, seed.index);
    }
    state = state.copyWith(colorSeed: seed);
  }
}

class EyeComfortModeNotifier extends StateNotifier<bool> {
  EyeComfortModeNotifier(this.prefs)
    : super(prefs.getBool(_eyeComfortModeKey) ?? false);

  final SharedPreferences prefs;
  static const _eyeComfortModeKey = 'eye_comfort_mode';

  Future<void> setEnabled(bool enabled) async {
    await prefs.setBool(_eyeComfortModeKey, enabled);
    state = enabled;
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs, ref);
});

final eyeComfortModeProvider =
    StateNotifierProvider<EyeComfortModeNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return EyeComfortModeNotifier(prefs);
    });
