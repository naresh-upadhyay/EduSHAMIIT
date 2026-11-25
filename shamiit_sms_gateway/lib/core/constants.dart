import 'package:flutter/foundation.dart';

class AppConstants {
  static const String appTitle = 'SHAMIIT SMS GATEWAY';
  static const String companyName = 'SHAMIIT Innovation and Technologies LLP';
  static const String tagline = 'Imagine Beyond Imagination';
  static const String appVersion = '1.0.0';

  // Live Cloud & Local API Hosts
  static const String liveServerBaseUrl = 'https://eduapi.shamiit.com';
  static const String liveSmsApiBaseUrl = 'https://eduapi.shamiit.com/api/v1';

  // Local Development URLs (for emulator / local PC testing)
  static const String localServerBaseUrlAndroid = 'http://10.0.2.2:8082';
  static const String localServerBaseUrlLoopback = 'http://127.0.0.1:8082';
  static const String defaultEmulatorApiUrl = 'http://10.0.2.2:8082/api/v1';
  static const String defaultLoopbackApiUrl = 'http://127.0.0.1:8082/api/v1';

  // SharedPreferences Keys (matching native SyncEngine keys)
  static const String prefsServerUrlKey = 'sms_pref_server_url';
  static const String prefsDeviceIdKey = 'sms_pref_device_id';
  static const String prefsDeviceTokenKey = 'sms_pref_device_token';
  static const String prefsSchoolIdKey = 'sms_pref_school_id';
  static const String prefsInstitutionKey = 'sms_pref_institution';
  static const String prefsUserTokenKey = 'sms_pref_user_token';
  static const String prefsUserEmailKey = 'sms_pref_user_email';
  static const String prefsUserNameKey = 'sms_pref_user_name';
  static const String prefsUserRoleKey = 'sms_pref_user_role';
  static const String prefsUserPhotoKey = 'sms_pref_user_photo';
  static const String prefsIsLoggedInKey = 'sms_pref_is_logged_in';
  static const String prefsDarkModeKey = 'sms_pref_dark_mode';
  static const String prefsNotifyFailedKey = 'sms_pref_notify_failed';
  static const String prefsNotifyInboundKey = 'sms_pref_notify_inbound';
  static const String prefsNotifySimChangeKey = 'sms_pref_notify_sim_change';

  static bool isEmulator = false;

  static String getDefaultApiUrl({bool forceLive = false}) {
    if (forceLive) return liveSmsApiBaseUrl;
    if (kIsWeb) return defaultLoopbackApiUrl;
    return isEmulator ? defaultEmulatorApiUrl : liveSmsApiBaseUrl;
  }
}
