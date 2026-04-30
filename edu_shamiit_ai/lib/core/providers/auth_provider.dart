import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:edu_shamiit_ai/core/config/app_config.dart';
import 'package:edu_shamiit_ai/core/providers/role_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_ai/core/services/api_service.dart';

/// Auth provider state — no longer holds a Supabase User object,
/// just the fields we get back from the FastAPI /api/auth/login response.
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final UserRole role;
  final String? token;
  final Map<String, dynamic>? userData;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
    this.role = UserRole.unknown,
    this.token,
    this.userData,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    UserRole? role,
    String? token,
    Map<String, dynamic>? userData,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
      role: role ?? this.role,
      token: token ?? this.token,
      userData: userData ?? this.userData,
    );
  }
}

/// Auth provider notifier — calls FastAPI backend for login.
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  AuthNotifier(this.ref) : super(AuthState());

  /// Try to restore session from SharedPreferences on app start.
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final roleStr = prefs.getString('user_role');
      final userDataStr = prefs.getString('user_data');

      if (token != null && roleStr != null) {
        final role = UserRoleExtension.fromString(roleStr);
        Map<String, dynamic>? userData;
        if (userDataStr != null) {
          userData = jsonDecode(userDataStr) as Map<String, dynamic>;
        }
        state = AuthState(
          isLoading: false,
          isAuthenticated: true,
          role: role,
          token: token,
          userData: userData,
        );
        return;
      }
    } catch (e) {
      // ignore restore errors
    }
    state = AuthState(isLoading: false);
  }

  /// Sign in by calling FastAPI POST /api/auth/login
  Future<bool> signIn({
    required String email,
    required String password,
    required WidgetRef ref,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('[AuthProvider] Calling ${AppConfig.apiBaseUrl}/auth/login');

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/login');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(AppConfig.apiTimeout);

      debugPrint('[AuthProvider] Response status: ${response.statusCode}');
      debugPrint('[AuthProvider] Response body: ${response.body}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final token = data['token'] as String;
        final user = data['user'] as Map<String, dynamic>;
        final roleStr = user['role'] as String? ?? 'unknown';
        final role = UserRoleExtension.fromString(roleStr);

        // Persist session
        // Clear API cache before saving new session
        ApiService().clearCache();
        await _saveSession(token: token, role: role, userData: user);

        // Sync role provider
        ref.read(roleProvider.notifier).setRole(role);

        state = AuthState(
          isLoading: false,
          isAuthenticated: true,
          role: role,
          token: token,
          userData: user,
        );
        return true;
      }

      // Server returned an error
      final detail = body['detail'] as String? ?? 'Login failed';
      state = state.copyWith(error: detail, isLoading: false);
      return false;
    } catch (e) {
      debugPrint('[AuthProvider] Exception: $e');
      state = state.copyWith(
        error: 'Connection error: ${e.toString()}',
        isLoading: false,
      );
      return false;
    }
  }

  /// Sign out — clears local session.
  Future<void> signOut() async {
    // Clear API cache
    ApiService().clearCache();
    await _clearSession();
    state = AuthState();
  }

  Future<void> _saveSession({
    required String token,
    required UserRole role,
    required Map<String, dynamic> userData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_role', role.value);
    await prefs.setString('user_data', jsonEncode(userData));
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_role');
    await prefs.remove('user_data');
  }

  /// Get stored role (static helper for splash screen).
  static Future<UserRole> getStoredRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString('user_role');
    if (roleStr != null) return UserRoleExtension.fromString(roleStr);
    return UserRole.unknown;
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});