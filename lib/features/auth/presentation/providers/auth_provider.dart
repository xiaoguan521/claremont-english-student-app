import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'dart:async';
import '../../data/auth_repository.dart';

part 'auth_provider.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState({
    @Default(false) bool isAuthenticated,
    @Default(false) bool isLoading,
    String? error,
  }) = _AuthState;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository)
    : super(AuthState(isAuthenticated: _repository.isAuthenticated)) {
    _subscription = _repository.authStateChanges().listen((isAuthenticated) {
      state = state.copyWith(
        isAuthenticated: isAuthenticated,
        isLoading: false,
        error: null,
      );
    });
  }

  final AuthRepository _repository;
  late final StreamSubscription<bool> _subscription;

  Future<void> login(String email, String password) async {
    state = const AuthState(isLoading: true);

    try {
      final success = await _repository.login(email, password);
      if (success) {
        state = const AuthState(isAuthenticated: true);
      } else {
        state = const AuthState(error: 'Invalid credentials');
      }
    } catch (e) {
      state = AuthState(error: e.toString());
    }
  }

  Future<bool> requestPhoneCode(String phone) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _repository.requestPhoneCode(phone);
      state = state.copyWith(isLoading: false);
      if (!success) {
        state = state.copyWith(error: '验证码发送失败，请检查手机号');
      }
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> verifyPhoneCode(String phone, String code) async {
    state = const AuthState(isLoading: true);

    try {
      final success = await _repository.verifyPhoneCode(phone, code);
      if (success) {
        state = const AuthState(isAuthenticated: true);
      } else {
        state = const AuthState(error: '验证码不正确或已过期');
      }
    } catch (e) {
      state = AuthState(error: e.toString());
    }
  }

  Future<void> register(String email, String password) async {
    state = const AuthState(isLoading: true);

    try {
      final success = await _repository.register(email, password);
      if (success) {
        state = const AuthState(isAuthenticated: true);
      } else {
        state = const AuthState(error: 'Registration failed');
      }
    } catch (e) {
      state = AuthState(error: e.toString());
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(isAuthenticated: false);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

final currentUserEmailProvider = Provider<String?>((ref) {
  ref.watch(authProvider);
  return ref.watch(authRepositoryProvider).currentUserEmail;
});
