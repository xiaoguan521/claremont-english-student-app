import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

abstract class AuthRepository {
  Future<bool> login(String email, String password);
  Future<bool> requestPhoneCode(String phone);
  Future<bool> verifyPhoneCode(String phone, String code);
  Future<bool> register(String email, String password);
  Future<void> logout();
  bool get isAuthenticated;
  String? get currentUserEmail;
  Stream<bool> authStateChanges();
}

class MockAuthRepository implements AuthRepository {
  bool _isAuthenticated = false;

  @override
  Future<bool> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    _isAuthenticated = email.isNotEmpty && password.isNotEmpty;
    return _isAuthenticated;
  }

  @override
  Future<bool> requestPhoneCode(String phone) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return phone.trim().length >= 6;
  }

  @override
  Future<bool> verifyPhoneCode(String phone, String code) async {
    await Future.delayed(const Duration(seconds: 1));
    _isAuthenticated = phone.trim().isNotEmpty && code.trim().isNotEmpty;
    return _isAuthenticated;
  }

  @override
  Future<bool> register(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    _isAuthenticated = email.isNotEmpty && password.isNotEmpty;
    return _isAuthenticated;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _isAuthenticated = false;
  }

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  String? get currentUserEmail =>
      _isAuthenticated ? 'demo@classroom.local' : null;

  @override
  Stream<bool> authStateChanges() => Stream<bool>.value(_isAuthenticated);
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> login(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.session != null || response.user != null;
  }

  @override
  Future<bool> requestPhoneCode(String phone) async {
    await _client.auth.signInWithOtp(phone: phone);
    return true;
  }

  @override
  Future<bool> verifyPhoneCode(String phone, String code) async {
    final response = await _client.auth.verifyOTP(
      phone: phone,
      token: code,
      type: OtpType.sms,
    );
    return response.session != null || response.user != null;
  }

  @override
  Future<bool> register(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    return response.user != null;
  }

  @override
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  @override
  bool get isAuthenticated => _client.auth.currentSession != null;

  @override
  String? get currentUserEmail => _client.auth.currentUser?.email;

  @override
  Stream<bool> authStateChanges() {
    return _client.auth.onAuthStateChange.map((event) => event.session != null);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.canUseSupabase) {
    return SupabaseAuthRepository(Supabase.instance.client);
  }
  return MockAuthRepository();
});
