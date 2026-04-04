import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:edu_shamiit_ai/core/services/supabase_service.dart';
import 'package:edu_shamiit_ai/core/providers/role_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auth provider state
class AuthState {
  final User? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final UserRole role;

  AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
    this.role = UserRole.unknown,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    UserRole? role,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
      role: role ?? this.role,
    );
  }
}

/// Auth provider notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  /// Initialize auth state from stored session
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    
    try {
      // Check if Supabase is initialized
      if (SupabaseService.isAuthenticated) {
        final user = SupabaseService.currentUser;
        if (user != null) {
          // Fetch user role from profile
          final role = await _fetchUserRole(user.id);
          await _saveUserData(user.id, role);
          
          state = state.copyWith(
            user: user,
            isAuthenticated: true,
            role: role,
            isLoading: false,
          );
          return;
        }
      }
      
      // No active session
      state = AuthState(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  /// Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
    required WidgetRef ref,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await SupabaseService.signIn(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        // Fetch user role
        final role = await _fetchUserRole(response.user!.id);
        await _saveUserData(response.user!.id, role);
        
        // Update role provider
        ref.read(roleProvider.notifier).setRole(role);
        
        state = state.copyWith(
          user: response.user,
          isAuthenticated: true,
          role: role,
          isLoading: false,
        );
        return true;
      }
      
      state = state.copyWith(
        error: 'Login failed',
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await SupabaseService.signOut();
      await _clearUserData();
      state = AuthState();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Fetch user role from profile
  Future<UserRole> _fetchUserRole(String userId) async {
    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      
      if (response['role'] != null) {
        return UserRoleExtension.fromString(response['role']);
      }
    } catch (e) {
      // Error fetching role
    }
    return UserRole.unknown;
  }

  /// Save user data to local storage
  Future<void> _saveUserData(String userId, UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('user_role', role.value);
  }

  /// Clear user data from local storage
  Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_role');
  }

  /// Get stored user role
  static Future<UserRole> getStoredRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString('user_role');
    if (roleStr != null) {
      return UserRoleExtension.fromString(roleStr);
    }
    return UserRole.unknown;
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});