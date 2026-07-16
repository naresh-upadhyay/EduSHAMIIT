import 'package:flutter/foundation.dart' show kIsWeb;
import 'app_config_host.dart';

/// Application configuration constants
class AppConfig {
  static String contactEmail = 'support@schoolerp.com';
  static String contactPhone = '+91 98765 43210';
  static String contactAddress = 'School ERP Solutions Pvt. Ltd., Plot No. 123, Tech Park, Sector 62, Noida, Uttar Pradesh - 201309, India';
  static String liveChatInfo = 'Available in the application';
  static String footerDesc = 'An all-in-one school management system designed to simplify administration, improve communication and enhance overall efficiency.';
  static String footerCopyright = '© 2025 School ERP. All rights reserved.';
  static List<FooterLink> footerQuickLinks = [
    FooterLink(label: 'Home', url: '/'),
    FooterLink(label: 'Features', url: '/#features'),
    FooterLink(label: 'Modules', url: '/#modules'),
    FooterLink(label: 'Pricing', url: '/#pricing'),
    FooterLink(label: 'About Us', url: '/#about'),
    FooterLink(label: 'Contact Us', url: '/contact'),
    FooterLink(label: 'FAQ', url: '/faq'),
    FooterLink(label: 'Help Center', url: '/help-center'),
  ];
  static List<FooterLink> footerModules = [
    FooterLink(label: 'Student Management', url: '/'),
    FooterLink(label: 'Attendance Management', url: '/'),
    FooterLink(label: 'Examination Management', url: '/'),
    FooterLink(label: 'Fee Management', url: '/'),
    FooterLink(label: 'Transport Management', url: '/'),
    FooterLink(label: 'Library Management', url: '/'),
  ];
  static List<FooterLink> footerSupport = [
    FooterLink(label: 'Help Center', url: '/help-center'),
    FooterLink(label: 'User Guides', url: '/user-guides'),
    FooterLink(label: 'FAQ\'s', url: '/faq'),
    FooterLink(label: 'Privacy Policy', url: '/privacy-policy'),
    FooterLink(label: 'Terms & Conditions', url: '/terms-conditions'),
  ];
  static List<FooterSocialLink> footerSocialLinks = [
    FooterSocialLink(platform: 'facebook', url: 'https://facebook.com'),
    FooterSocialLink(platform: 'instagram', url: 'https://instagram.com'),
    FooterSocialLink(platform: 'email', url: 'mailto:support@schoolerp.com'),
    FooterSocialLink(platform: 'youtube', url: 'https://youtube.com'),
  ];
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
      'https://eduapi.shamiit.com';
  static const String _productionSupabaseUrl =
      'https://eduapi.shamiit.com';

  // ─── API Configuration ───────────────────────────────────────────────────
  /// Base URL for the backend API
  static String get baseUrl {
    if (_isProduction) return _productionApiUrl;
    return 'http://$_host:8082';
  }

  /// API base URL with /api prefix
  static String get apiBaseUrl => '$baseUrl/api';

  /// Supabase URL — uses cloud Supabase in production, local Kong in dev
  static String get supabaseUrl {
    if (_isProduction) return _productionSupabaseUrl;
    return 'http://$_host:8000';
  }

  /// Resolves media/document/image URLs dynamically depending on whether running in production or dev.
  static String resolveUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return '';
    try {
      final uri = Uri.parse(rawUrl);
      if (!uri.hasScheme) return rawUrl;

      if (_isProduction) {
        final internalHosts = [
          'kong',
          'supabase-kong',
          '127.0.0.1',
          'localhost',
          'eduapi.shamiit.com'
        ];
        if (internalHosts.contains(uri.host)) {
          final prodUri = Uri.parse(_productionApiUrl);
          return uri.replace(
            scheme: prodUri.scheme,
            host: prodUri.host,
            port: prodUri.port == 80 || prodUri.port == 443 ? null : prodUri.port,
          ).toString();
        }
        // Force HTTPS for production API calls
        if (uri.host == 'eduapi.shamiit.com' && uri.scheme == 'http') {
          return uri.replace(scheme: 'https').toString();
        }
        return rawUrl;
      } else {
        final internalHosts = [
          'kong',
          'supabase-kong',
          '127.0.0.1',
          'localhost'
        ];
        if (internalHosts.contains(uri.host)) {
          int targetPort = 8082; // Default to local Nginx gateway
          if (uri.path.contains('/storage/v1/')) {
            targetPort = 8082; // Route storage requests through Nginx to prevent CORS issues
          } else if (uri.port != 0 && uri.port != 80 && uri.port != 443) {
            targetPort = uri.port;
          }
          return uri.replace(
            scheme: 'http',
            host: _host,
            port: targetPort,
          ).toString();
        }
        return rawUrl;
      }
    } catch (e) {
      return rawUrl;
    }
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

class FooterLink {
  final String label;
  final String url;
  FooterLink({required this.label, required this.url});

  Map<String, dynamic> toJson() => {'label': label, 'url': url};
  factory FooterLink.fromJson(Map<String, dynamic> json) {
    return FooterLink(
      label: json['label'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

class FooterSocialLink {
  final String platform;
  final String url;
  FooterSocialLink({required this.platform, required this.url});

  Map<String, dynamic> toJson() => {'platform': platform, 'url': url};
  factory FooterSocialLink.fromJson(Map<String, dynamic> json) {
    return FooterSocialLink(
      platform: json['platform'] ?? '',
      url: json['url'] ?? '',
    );
  }
}