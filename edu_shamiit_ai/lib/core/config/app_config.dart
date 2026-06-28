import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:edu_shamiit_ai/core/config/app_config_host.dart';

/// Application configuration constants
class AppConfig {
  // ─── Dynamic host detection ───────────────────────────────────────────────
  // On Flutter Web, reads window.location.hostname so the app works from any
  // device on the LAN (e.g. http://192.168.1.10:63305) not just localhost.
  // On GitHub Pages / production, uses cloud API URL instead.
  static String get _host {
    if (kIsWeb) {
      return getWebHostname();
    }
    return '127.0.0.1';
  }

  /// Returns true when running on GitHub Pages or any production domain
  static bool get _isProduction {
    if (!kIsWeb) return false;
    final host = _host;
    // GitHub Pages, custom domains, or any non-localhost host
    return host != 'localhost' && host != '127.0.0.1' && !host.contains('192.168.');
  }

  // ─── Production Cloud URLs ───────────────────────────────────────────────
  static const String _productionApiUrl =
      'https://edushamiitapi.shamiit.com';
  static const String _productionSupabaseUrl =
      'https://edushamiitapi.shamiit.com';

  // ─── API Configuration ───────────────────────────────────────────────────
  /// Base URL for the backend API
  static String get baseUrl {
    if (_isProduction) return _productionApiUrl;
    return 'http://$_host:80';
  }

  /// API base URL with /api prefix
  static String get apiBaseUrl => '$baseUrl/api';

  /// Supabase URL — uses cloud Supabase in production, local Kong in dev
  static String get supabaseUrl {
    if (_isProduction) return _productionSupabaseUrl;
    return 'http://$_host:8000';
  }

  /// Supabase Anon Key — uses cloud key in production, local key in dev
  static const String _productionSupabaseAnonKey =
      'sb_publishable_OPkfyiUb-oJJ-Y56ZOY2XA_jn1OymYc';
  static const String _localSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNjAwMDAwMDAwLCJleHAiOjIwMDAwMDAwMDB9.V-Nq7_uazFUYvZFXyq_whGnFkWy4W_3o4k6m04sGc5Q';

  static String get supabaseAnonKey {
    if (_isProduction) return _productionSupabaseAnonKey;
    return _localSupabaseAnonKey;
  }

  // ─── Global Constants ────────────────────────────────────────────────────
  static const String appName = 'EduSHAMIIT AI';
  static const String appVersion = '1.0.0';
  static const String aiAssistantName = 'Shami';

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration connectionTimeout = Duration(seconds: 10);

  // Storage Keys
  static const String tokenStorageKey = 'auth_token';
  static const String userStorageKey = 'user_data';
  static const String roleStorageKey = 'user_role';

  // Routes
  static const String splashRoute = '/splash';
  static const String loginRoute = '/login';
  static const String studentDashboardRoute = '/student/dashboard';
  static const String teacherDashboardRoute = '/teacher/dashboard';
  static const String settingsRoute = '/settings';
  static const String aiChatRoute = '/ai-chat';

  // Feature Flags
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  static const bool enableOfflineMode = true;
}