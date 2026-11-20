class DashboardData {
  final String appName;
  final String runningStatus;
  final bool isListenerActive;
  final DashboardMetrics metrics;
  final SystemStatus systemStatus;
  final List<ActivityItem> todayActivity;

  DashboardData({
    required this.appName,
    required this.runningStatus,
    required this.isListenerActive,
    required this.metrics,
    required this.systemStatus,
    required this.todayActivity,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      appName: json['app_name'] ?? 'EduSHAMIIT Payment Bridge',
      runningStatus: json['running_status'] ?? 'Running',
      isListenerActive: json['payment_listener_active'] ?? true,
      metrics: DashboardMetrics.fromJson(json['metrics'] ?? {}),
      systemStatus: SystemStatus.fromJson(json['system_status'] ?? {}),
      todayActivity: (json['today_activity'] as List<dynamic>? ?? [])
          .map((e) => ActivityItem.fromJson(e))
          .toList(),
    );
  }

  factory DashboardData.empty({String status = 'Offline', bool isConnected = false}) {
    return DashboardData(
      appName: 'EduSHAMIIT Payment Bridge',
      runningStatus: status,
      isListenerActive: false,
      metrics: DashboardMetrics(
        notificationsToday: 0,
        matchedPayments: 0,
        unmatchedPayments: 0,
        lastSync: isConnected ? 'Just now' : 'Offline',
        lastSyncTime: isConnected ? 'Live' : 'Never',
      ),
      systemStatus: SystemStatus(
        notificationAccess: 'Permission Required',
        monitoredUpiApps: '0 Apps',
        backendConnection: isConnected ? 'Connected' : 'Disconnected',
        deviceRegistration: 'Registered',
        dataSync: isConnected ? 'Up to Date' : 'Offline',
      ),
      todayActivity: [],
    );
  }

  // When offline or fallback, never return fake business numbers (42, 38, 2, Seema, Mohan)
  factory DashboardData.fallback() => DashboardData.empty(status: 'Offline', isConnected: false);

  factory DashboardData.mock() => DashboardData.empty(status: 'Offline', isConnected: false);
}

class DashboardMetrics {
  final int notificationsToday;
  final int matchedPayments;
  final int unmatchedPayments;
  final String lastSync;
  final String lastSyncTime;

  DashboardMetrics({
    required this.notificationsToday,
    required this.matchedPayments,
    required this.unmatchedPayments,
    required this.lastSync,
    required this.lastSyncTime,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      notificationsToday: (json['notifications_today'] as num?)?.toInt() ?? 0,
      matchedPayments: (json['matched_payments'] as num?)?.toInt() ?? 0,
      unmatchedPayments: (json['unmatched_payments'] as num?)?.toInt() ?? 0,
      lastSync: json['last_sync'] ?? 'Offline',
      lastSyncTime: json['last_sync_time'] ?? 'Never',
    );
  }
}

class SystemStatus {
  final String notificationAccess;
  final String monitoredUpiApps;
  final String backendConnection;
  final String deviceRegistration;
  final String dataSync;

  SystemStatus({
    required this.notificationAccess,
    required this.monitoredUpiApps,
    required this.backendConnection,
    required this.deviceRegistration,
    required this.dataSync,
  });

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    return SystemStatus(
      notificationAccess: json['notification_access'] ?? 'Granted',
      monitoredUpiApps: json['monitored_upi_apps'] ?? '0 Apps',
      backendConnection: json['backend_connection'] ?? 'Offline',
      deviceRegistration: json['device_registration'] ?? 'Registered',
      dataSync: json['data_sync'] ?? 'Offline',
    );
  }
}

class ActivityItem {
  final String id;
  final String title;
  final String subtitle;
  final String time;
  final String iconType; // SUCCESS, WARNING, REVIEW, IGNORED

  ActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.iconType,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      time: json['time'] ?? '',
      iconType: json['icon_type'] ?? 'SUCCESS',
    );
  }
}
