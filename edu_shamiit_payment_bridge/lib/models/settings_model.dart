class BridgeSettings {
  final int syncIntervalSeconds;
  final int retryIntervalSeconds;
  final int duplicateDetectionWindowMinutes;
  final bool autoStartOnBoot;
  final String serverUrl;
  final String deviceId;
  final String institution;

  BridgeSettings({
    this.syncIntervalSeconds = 30,
    this.retryIntervalSeconds = 60,
    this.duplicateDetectionWindowMinutes = 5,
    this.autoStartOnBoot = true,
    this.serverUrl = 'http://127.0.0.1:8082/api/v1/payment-bridge',
    this.deviceId = 'PB-DEV-WEB001',
    this.institution = 'Shami Innovation Academy',
  });

  factory BridgeSettings.fromJson(Map<String, dynamic> json) {
    return BridgeSettings(
      syncIntervalSeconds: json['sync_interval_seconds'] ?? 30,
      retryIntervalSeconds: json['retry_interval_seconds'] ?? 60,
      duplicateDetectionWindowMinutes: json['duplicate_detection_window_minutes'] ?? 5,
      autoStartOnBoot: json['auto_start_on_boot'] ?? true,
      serverUrl: json['server_url'] ?? 'http://127.0.0.1:8082/api/v1/payment-bridge',
      deviceId: json['device_id'] ?? 'PB-DEV-WEB001',
      institution: json['institution'] ?? 'Shami Innovation Academy',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sync_interval_seconds': syncIntervalSeconds,
      'retry_interval_seconds': retryIntervalSeconds,
      'duplicate_detection_window_minutes': duplicateDetectionWindowMinutes,
      'auto_start_on_boot': autoStartOnBoot,
      'server_url': serverUrl,
    };
  }
}

class MonitoredAppItem {
  final String id;
  final String name;
  final String packageName;
  final bool isEnabled;

  MonitoredAppItem({
    required this.id,
    required this.name,
    required this.packageName,
    required this.isEnabled,
  });

  factory MonitoredAppItem.fromJson(Map<String, dynamic> json) {
    return MonitoredAppItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? json['app_name'] ?? '',
      packageName: json['package'] ?? json['package_name'] ?? '',
      isEnabled: json['enabled'] ?? json['is_enabled'] ?? true,
    );
  }
}
