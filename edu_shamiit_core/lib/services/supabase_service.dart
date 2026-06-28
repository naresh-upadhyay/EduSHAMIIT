import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// Supabase service for authentication and database operations
class SupabaseService {
  static SupabaseClient? _client;
  static bool _isInitialized = false;

  /// Initialize Supabase client
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: true,
        ),
      );
      _client = Supabase.instance.client;
      _isInitialized = true;
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Supabase: $e');
      rethrow;
    }
  }

  /// Get Supabase client instance
  static SupabaseClient get client {
    if (!_isInitialized || _client == null) {
      throw Exception('Supabase not initialized. Call initialize() first.');
    }
    return _client!;
  }

  /// Get Auth client
  static GoTrueClient get auth => client.auth;

  /// Get current user
  static User? get currentUser => client.auth.currentUser;

  /// Get current session
  static Session? get currentSession => client.auth.currentSession;

  /// Check if user is authenticated
  static bool get isAuthenticated =>
      currentUser != null && currentSession != null;

  /// Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  /// Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  static Future<void> signOut() async {
    await auth.signOut();
    _isInitialized = false;
    _client = null;
  }

  /// Refresh session
  static Future<AuthResponse> refreshSession() async {
    return await auth.refreshSession();
  }

  /// Get access token
  static String? get accessToken => currentSession?.accessToken;

  /// Stream auth state changes
  static Stream<AuthState> get authStateChanges => auth.onAuthStateChange;
}
