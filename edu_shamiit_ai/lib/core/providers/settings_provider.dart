import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import 'api_provider.dart';
import 'cache_provider.dart';
import 'auth_provider.dart';

/// Model class for user settings
class UserSettings {
  bool pushNotifications;
  bool smsAlerts;
  bool emailReports;
  bool aiPersonalization;
  bool biometricLogin;
  bool darkMode;
  String language;

  UserSettings({
    this.pushNotifications = true,
    this.smsAlerts = true,
    this.emailReports = false,
    this.aiPersonalization = true,
    this.biometricLogin = true,
    this.darkMode = false,
    this.language = 'English',
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      pushNotifications: json['pushNotifications'] ?? true,
      smsAlerts: json['smsAlerts'] ?? true,
      emailReports: json['emailReports'] ?? false,
      aiPersonalization: json['aiPersonalization'] ?? true,
      biometricLogin: json['biometricLogin'] ?? true,
      darkMode: json['darkMode'] ?? false,
      language: json['language'] ?? 'English',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pushNotifications': pushNotifications,
      'smsAlerts': smsAlerts,
      'emailReports': emailReports,
      'aiPersonalization': aiPersonalization,
      'biometricLogin': biometricLogin,
      'darkMode': darkMode,
      'language': language,
    };
  }

  UserSettings copyWith({
    bool? pushNotifications,
    bool? smsAlerts,
    bool? emailReports,
    bool? aiPersonalization,
    bool? biometricLogin,
    bool? darkMode,
    String? language,
  }) {
    return UserSettings(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      smsAlerts: smsAlerts ?? this.smsAlerts,
      emailReports: emailReports ?? this.emailReports,
      aiPersonalization: aiPersonalization ?? this.aiPersonalization,
      biometricLogin: biometricLogin ?? this.biometricLogin,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
    );
  }
}

/// State class for settings provider
class SettingsState {
  final bool isLoading;
  final UserSettings? settings;
  final String? error;

  SettingsState({
    this.isLoading = false,
    this.settings,
    this.error,
  });

  SettingsState copyWith({
    bool? isLoading,
    UserSettings? settings,
    String? error,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      settings: settings ?? this.settings,
      error: error,
    );
  }
}

/// Notifier class for settings management
class SettingsNotifier extends StateNotifier<SettingsState> {
  final ApiService _apiService;
  final CacheService _cacheService;

  SettingsNotifier(this._apiService, this._cacheService, {bool skipLoad = false})
      : super(SettingsState(isLoading: !skipLoad)) {
    if (!skipLoad) {
      loadSettings();
    }
  }

  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // First try to load from cache
      final cachedSettings = await _cacheService.get('user_settings');
      if (cachedSettings != null) {
        state = state.copyWith(
          isLoading: false,
          settings: UserSettings.fromJson(cachedSettings),
        );
      }

      // Then fetch from API
      final response = await _apiService.get('/student/settings');
      if (response['success'] == true) {
        final settings = UserSettings.fromJson(response['data']);
        // Cache the settings
        await _cacheService.set('user_settings', settings.toJson());
        state = state.copyWith(
          isLoading: false,
          settings: settings,
        );
      } else if (cachedSettings == null) {
        state = state.copyWith(
          isLoading: false,
          error: response['message'] ?? 'Failed to load settings',
        );
      }
    } catch (e) {
      if (state.settings == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load settings: $e',
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<bool> updateSetting(String key, dynamic value) async {
    if (state.settings == null) return false;

    final updatedSettings = state.settings!.copyWith();
    switch (key) {
      case 'pushNotifications':
        updatedSettings.pushNotifications = value;
        break;
      case 'smsAlerts':
        updatedSettings.smsAlerts = value;
        break;
      case 'emailReports':
        updatedSettings.emailReports = value;
        break;
      case 'aiPersonalization':
        updatedSettings.aiPersonalization = value;
        break;
      case 'biometricLogin':
        updatedSettings.biometricLogin = value;
        break;
      case 'darkMode':
        updatedSettings.darkMode = value;
        break;
      case 'language':
        updatedSettings.language = value;
        break;
      default:
        return false;
    }

    state = state.copyWith(settings: updatedSettings);

    // Save to cache
    await _cacheService.set('user_settings', updatedSettings.toJson());

    // Sync with server
    try {
      final response =
          await _apiService.put('/student/settings', {key: value});
      return response['success'] == true;
    } catch (e) {
      return false; // Optimistic update succeeded, but sync failed
    }
  }

  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    try {
      final response = await _apiService.post('/student/change-password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      return response['success'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> logout() async {
    try {
      final response = await _apiService.post('/student/logout', {});
      if (response['success'] == true) {
        // Clear cached settings
        await _cacheService.remove('user_settings');
        state = SettingsState(isLoading: false);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// Provider for user settings
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    // Watch authentication state. When user logs in/out, this provider is recreated.
    final isAuthenticated = ref.watch(authProvider.select((s) => s.isAuthenticated));
    
    final apiService = ref.watch(apiServiceProvider);
    final cacheService = ref.watch(cacheServiceProvider);
    
    if (!isAuthenticated) {
      return SettingsNotifier(apiService, cacheService, skipLoad: true);
    }
    
    return SettingsNotifier(apiService, cacheService);
  },
);
