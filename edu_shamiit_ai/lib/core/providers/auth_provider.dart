import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:edu_shamiit_ai/core/config/app_config.dart';
import 'package:edu_shamiit_ai/core/providers/role_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_ai/core/services/api_service.dart';
import 'package:edu_shamiit_ai/core/services/call_service.dart';

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
        
        // Restore Supabase session for realtime to work
        final supabaseAccessToken = prefs.getString('supabase_access_token');
        final supabaseRefreshToken = prefs.getString('supabase_refresh_token');
        
        final currentSession = Supabase.instance.client.auth.currentSession;
        if (currentSession != null) {
          debugPrint('[AuthProvider] Supabase session automatically restored by SDK');
        } else if (supabaseRefreshToken != null) {
          try {
            final authRes = await Supabase.instance.client.auth.setSession(supabaseRefreshToken);
            debugPrint('[AuthProvider] Supabase session restored for realtime');
            final newSession = authRes.session;
            if (newSession != null) {
              final newRefreshToken = newSession.refreshToken;
              if (newRefreshToken != null) {
                await prefs.setString('supabase_access_token', newSession.accessToken);
                await prefs.setString('supabase_refresh_token', newRefreshToken);
              }
            }
          } catch (e) {
            debugPrint('[AuthProvider] Could not restore Supabase session: $e');
          }
        } else {
          debugPrint('[AuthProvider] Missing Supabase refresh token for active session. Clearing session to force re-login.');
          await _clearSession();
          state = AuthState(isLoading: false);
          return;
        }
        
        state = AuthState(
          isLoading: false,
          isAuthenticated: true,
          role: role,
          token: token,
          userData: userData,
        );
        // Initialize CallService for incoming call listener
        final userId = userData?['id'] as String? ?? '';
        if (userId.isNotEmpty) {
          CallService.instance.initialize(userId, AppConfig.baseUrl);
        }
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
    required UserRole role,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('[AuthProvider] Calling ${AppConfig.apiBaseUrl}/auth/login');

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/login');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'role': role.value,
        }),
      ).timeout(AppConfig.apiTimeout);

      debugPrint('[AuthProvider] Response status: ${response.statusCode}');
      debugPrint('[AuthProvider] Response body: ${response.body}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final token = data['token'] as String;
        final supabaseAccessToken = data['supabase_access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;
        final user = data['user'] as Map<String, dynamic>;
        final roleStr = user['role'] as String? ?? 'unknown';
        final role = UserRoleExtension.fromString(roleStr);

        String? finalSupabaseAccessToken = supabaseAccessToken;
        String? finalSupabaseRefreshToken = refreshToken;
        if (refreshToken != null) {
          try {
            final authRes = await Supabase.instance.client.auth.setSession(refreshToken);
            debugPrint('[AuthProvider] Supabase client session set for realtime');
            final newSession = authRes.session;
            if (newSession != null) {
              finalSupabaseAccessToken = newSession.accessToken;
              finalSupabaseRefreshToken = newSession.refreshToken;
            }
          } catch (e) {
            debugPrint('[AuthProvider] Could not set Supabase session: $e');
          }
        }

        // Persist session
        // Clear API cache before saving new session
        ApiService().clearCache();
        await _saveSession(
          token: token,
          role: role,
          userData: user,
          supabaseAccessToken: finalSupabaseAccessToken,
          supabaseRefreshToken: finalSupabaseRefreshToken,
        );

        // Sync role provider using the provider's own Ref (never disposed)
        ref.read(roleProvider.notifier).setRole(role);

        state = AuthState(
          isLoading: false,
          isAuthenticated: true,
          role: role,
          token: token,
          userData: user,
        );
        // Initialize CallService so incoming calls work from this login
        final userId = user['id'] as String? ?? '';
        if (userId.isNotEmpty) {
          CallService.instance.initialize(userId, AppConfig.baseUrl);
        }
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
    // Dispose CallService incoming listener
    CallService.instance.dispose();
    // Sign out of Supabase client to clean up realtime subscriptions
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    await _clearSession();
    state = AuthState();
  }

  Future<void> _saveSession({
    required String token,
    required UserRole role,
    required Map<String, dynamic> userData,
    String? supabaseAccessToken,
    String? supabaseRefreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_role', role.value);
    await prefs.setString('user_data', jsonEncode(userData));
    await prefs.setString('user_name', userData['full_name'] as String? ?? '');
    if (supabaseAccessToken != null) {
      await prefs.setString('supabase_access_token', supabaseAccessToken);
    }
    if (supabaseRefreshToken != null) {
      await prefs.setString('supabase_refresh_token', supabaseRefreshToken);
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_role');
    await prefs.remove('user_data');
    await prefs.remove('supabase_access_token');
    await prefs.remove('supabase_refresh_token');
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