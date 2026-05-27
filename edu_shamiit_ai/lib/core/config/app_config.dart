/// Application configuration constants
class AppConfig {
  // API Configuration
  static const String baseUrl = 'http://127.0.0.1:80';
  static const String apiBaseUrl = '$baseUrl/api';

  // Supabase Configuration (from backend .env)
  static const String supabaseUrl = 'http://127.0.0.1:8000';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNjAwMDAwMDAwLCJleHAiOjIwMDAwMDAwMDB9.V-Nq7_uazFUYvZFXyq_whGnFkWy4W_3o4k6m04sGc5Q';

  // App Information
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
