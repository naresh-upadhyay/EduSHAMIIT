import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformBridge {
  static const MethodChannel _channel = MethodChannel('com.shamiit.sms_gateway/channel');
  static const EventChannel _eventChannel = EventChannel('com.shamiit.sms_gateway/events');

  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Stream<Map<String, dynamic>> get nativeEvents {
    if (!isAndroid) return const Stream.empty();
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) return Map<String, dynamic>.from(event);
      return <String, dynamic>{};
    });
  }

  static Future<String> getUniqueDeviceId() async {
    if (!isAndroid) return 'SMS-DEV-HOST';
    try {
      return await _channel.invokeMethod<String>('getUniqueDeviceId') ?? 'SMS-UNKNOWN';
    } catch (_) {
      return 'SMS-FALLBACK';
    }
  }

  static Future<bool> isEmulator() async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isEmulator') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getPermissionSnapshot() async {
    if (!isAndroid) {
      return {
        'send_sms': false,
        'receive_sms': false,
        'read_phone_state': false,
        'read_contacts': false,
        'post_notifications': false,
        'all_core_granted': false,
      };
    }
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getPermissionSnapshot');
      return Map<String, dynamic>.from(res ?? {});
    } catch (_) {
      return {'all_core_granted': false};
    }
  }

  static Future<Map<String, dynamic>> requestCorePermissions() async {
    if (!isAndroid) return getPermissionSnapshot();
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('requestCorePermissions');
      return Map<String, dynamic>.from(res ?? {});
    } catch (_) {
      return getPermissionSnapshot();
    }
  }

  static Future<Map<String, dynamic>> requestContactsPermission() async {
    if (!isAndroid) return getPermissionSnapshot();
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('requestContactsPermission');
      return Map<String, dynamic>.from(res ?? {});
    } catch (_) {
      return getPermissionSnapshot();
    }
  }

  static Future<bool> openAppSettings() async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> startGatewayService() async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('startGatewayService') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopGatewayService() async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('stopGatewayService') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> discoverSims() async {
    if (!isAndroid) return [];
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('discoverSims');
      return res?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    } catch (e) {
      debugPrint('discoverSims error: $e');
      return [];
    }
  }

  static Future<bool> setSimUsageMode(int subscriptionId, String usageMode) async {
    if (!isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('setSimUsageMode', {
            'subscription_id': subscriptionId,
            'usage_mode': usageMode,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getLocalSettings() async {
    if (!isAndroid) return {};
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getLocalSettings');
      return Map<String, dynamic>.from(res ?? {});
    } catch (_) {
      return {};
    }
  }

  static Future<bool> saveLocalSettings(Map<String, dynamic> settings) async {
    if (!isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('saveLocalSettings', settings) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> sendNativeSms({
    required String recipient,
    required String messageBody,
    int? subscriptionId,
    bool deliveryReportRequested = true,
    String applicationSource = 'SMS Gateway App',
    String? referenceId,
    String priority = 'NORMAL',
    String? messageUuid,
  }) async {
    if (!isAndroid) {
      return {
        'success': false,
        'status': 'FAILED',
        'error': 'Native SmsManager is only available on Android hardware.',
      };
    }
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('sendNativeSms', {
        'recipient': recipient,
        'message_body': messageBody,
        'subscription_id': subscriptionId,
        'delivery_report_requested': deliveryReportRequested,
        'application_source': applicationSource,
        'reference_id': referenceId,
        'priority': priority,
        'message_uuid': messageUuid,
      });
      return Map<String, dynamic>.from(res ?? {});
    } catch (e) {
      return {'success': false, 'status': 'FAILED', 'error': e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> getLocalMessages({
    String? status,
    String? direction,
    int? simSlot,
    String? search,
    int limit = 100,
    int offset = 0,
  }) async {
    if (!isAndroid) return [];
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('getLocalMessages', {
        'status': status,
        'direction': direction,
        'sim_slot': simSlot,
        'search': search,
        'limit': limit,
        'offset': offset,
      });
      return res?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getLocalStats() async {
    if (!isAndroid) return {};
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getLocalStats');
      return Map<String, dynamic>.from(res ?? {});
    } catch (_) {
      return {};
    }
  }

  static Future<List<Map<String, dynamic>>> getLocalEvents({int limit = 25}) async {
    if (!isAndroid) return [];
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('getLocalEvents', {'limit': limit});
      return res?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getContacts({String? query}) async {
    if (!isAndroid) return [];
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('getContacts', {'query': query});
      return res?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getDiagnostics() async {
    if (!isAndroid) {
      return {
        'device_id': 'SMS-DEV-HOST',
        'device_model': 'Host Workstation',
        'android_version': 'Non-Android',
        'battery_level': 100,
        'is_charging': false,
        'battery_optimization_disabled': true,
        'internet_connected': true,
        'network_type': 'Host Network',
        'uptime_seconds': 0,
        'service_running': false,
        'pending_uploads_count': 0,
        'pending_jobs_count': 0,
        'database_size_bytes': 0,
        'keystore_backed': false,
        'has_device_token': false,
        'permissions': {'all_core_granted': false},
        'sim_count': 0,
        'sims': [],
      };
    }
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getDiagnostics');
      return Map<String, dynamic>.from(res ?? {});
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> syncNow() async {
    if (!isAndroid) return {'success': true, 'uploaded': 0};
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('syncNow');
      return Map<String, dynamic>.from(res ?? {});
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> cleanupLocalStorage(int retentionDays) async {
    if (!isAndroid) return {'deleted_count': 0, 'database_size_bytes': 0};
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('cleanupLocalStorage', {
        'retention_days': retentionDays,
      });
      return Map<String, dynamic>.from(res ?? {});
    } catch (_) {
      return {'deleted_count': 0, 'database_size_bytes': 0};
    }
  }

  static Future<void> saveCredentials({
    String? authToken,
    String? deviceToken,
    String? deviceId,
    String? schoolId,
  }) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('saveCredentials', {
        'auth_token': authToken,
        'device_token': deviceToken,
        'device_id': deviceId,
        'school_id': schoolId,
      });
    } catch (_) {}
  }

  static Future<void> clearCredentials() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('clearCredentials');
    } catch (_) {}
  }
}
