import 'package:flutter/foundation.dart';

class AppConstants {
  static const String appTitle = 'SHAMIIT Payment Bridge';

  // Live Cloud API Host
  static const String liveServerBaseUrl = 'https://eduapi.shamiit.com';
  static const String livePaymentBridgeUrl = 'https://eduapi.shamiit.com/api/v1/payment-bridge';

  // Local Development URLs (for emulator / local PC testing)
  static const String localServerBaseUrlAndroid = 'http://10.0.2.2:8082';
  static const String localServerBaseUrlLoopback = 'http://127.0.0.1:8082';
  static const String defaultServerUrl = 'http://10.0.2.2:8082/api/v1/payment-bridge';
  static const String defaultLocalServerUrl = 'http://127.0.0.1:8082/api/v1/payment-bridge';

  // SharedPreferences Keys
  static const String prefsServerUrlKey = 'pref_server_url';
  static const String prefsDeviceIdKey = 'pref_device_id';
  static const String prefsSchoolIdKey = 'pref_school_id';
  static const String prefsInstitutionKey = 'pref_institution';
  static const String prefsUserTokenKey = 'pref_user_token';
  static const String prefsUserEmailKey = 'pref_user_email';
  static const String prefsUserNameKey = 'pref_user_name';
  static const String prefsUserRoleKey = 'pref_user_role';
  static const String prefsUserPhotoKey = 'pref_user_photo';
  static const String prefsIsLoggedInKey = 'pref_is_logged_in';
  static const String prefsAutoStartKey = 'pref_auto_start';
  static const String prefsSyncIntervalKey = 'pref_sync_interval';
  static const String prefsRetryIntervalKey = 'pref_retry_interval';
  static const String prefsDupWindowKey = 'pref_dup_window';

  /// Determines if the device running is an Android emulator
  static bool isEmulator = false;

  /// Returns the base URL for authentication (/api/auth)
  static String getAuthBaseUrl({bool forceLive = false}) {
    if (forceLive) return '$liveServerBaseUrl/api';
    if (kIsWeb) return '$localServerBaseUrlLoopback/api';
    return isEmulator ? '$localServerBaseUrlAndroid/api' : '$liveServerBaseUrl/api';
  }

  /// Returns default payment bridge URL
  static String getDefaultPaymentBridgeUrl({bool forceLive = false}) {
    if (forceLive) return livePaymentBridgeUrl;
    if (kIsWeb) return defaultLocalServerUrl;
    return isEmulator ? defaultServerUrl : livePaymentBridgeUrl;
  }
}
