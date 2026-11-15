class AppConstants {
  static const String appTitle = 'EduSHAMIIT Payment Bridge';
  static const String defaultServerUrl = 'http://10.0.2.2:8000/api/v1/payment-bridge';
  static const String defaultLocalServerUrl = 'http://127.0.0.1:8000/api/v1/payment-bridge';
  static const String defaultDeviceId = 'PB-AND-001';
  static const String defaultSchoolId = '33333333-3333-3333-3333-333333333333';
  static const String defaultInstitution = 'Greenwood High School';

  static const String prefsServerUrlKey = 'pref_server_url';
  static const String prefsDeviceIdKey = 'pref_device_id';
  static const String prefsSchoolIdKey = 'pref_school_id';
  static const String prefsInstitutionKey = 'pref_institution';
  static const String prefsAutoStartKey = 'pref_auto_start';
  static const String prefsSyncIntervalKey = 'pref_sync_interval';
  static const String prefsRetryIntervalKey = 'pref_retry_interval';
  static const String prefsDupWindowKey = 'pref_dup_window';
}
