import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformBridge {
  static const MethodChannel _channel =
      MethodChannel('com.shamiit.payment_bridge/channel');

  /// Checks if notification access is granted by the user in Android OS.
  /// Never defaults to true when permission is missing!
  static Future<bool> isNotificationAccessGranted() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final bool? granted =
          await _channel.invokeMethod<bool>('isNotificationAccessGranted');
      return granted ?? false;
    } catch (e) {
      debugPrint('isNotificationAccessGranted error: $e');
      return false;
    }
  }

  static Future<bool> hasNotificationAccess() => isNotificationAccessGranted();

  static Future<bool> openNotificationSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final bool? opened =
          await _channel.invokeMethod<bool>('openNotificationSettings');
      return opened ?? false;
    } catch (e) {
      debugPrint('openNotificationSettings error: $e');
      return false;
    }
  }

  static Future<bool> isListenerRunning() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final bool? running =
          await _channel.invokeMethod<bool>('isListenerRunning');
      return running ?? false;
    } catch (e) {
      debugPrint('isListenerRunning error: $e');
      return false;
    }
  }

  static Future<bool> isServiceRunning() => isListenerRunning();
  static Future<bool> isListenerServiceRunning() => isListenerRunning();

  static Future<bool> setListenerActive(bool active) async {
    if (active) {
      return await startListenerService();
    } else {
      return await stopListenerService();
    }
  }

  static Future<bool> startListenerService() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final bool? res =
          await _channel.invokeMethod<bool>('startListenerService');
      return res ?? false;
    } catch (e) {
      debugPrint('startListenerService error: $e');
      return false;
    }
  }

  static Future<bool> stopListenerService() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final bool? res =
          await _channel.invokeMethod<bool>('stopListenerService');
      return res ?? false;
    } catch (e) {
      debugPrint('stopListenerService error: $e');
      return false;
    }
  }

  static Future<String> getUniqueDeviceId() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'PB-DEV-WEB001';
    }
    try {
      final String? id = await _channel.invokeMethod<String>('getUniqueDeviceId');
      return id ?? 'PB-UNKNOWN';
    } catch (e) {
      debugPrint('getUniqueDeviceId error: $e');
      return 'PB-FALLBACK';
    }
  }

  static Future<bool> isDeviceEmulator() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final bool? emu = await _channel.invokeMethod<bool>('isEmulator');
      return emu ?? false;
    } catch (e) {
      debugPrint('isEmulator error: $e');
      return false;
    }
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final bool? isIgnoring =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return isIgnoring ?? false;
    } catch (e) {
      debugPrint('isIgnoringBatteryOptimizations error: $e');
      return false;
    }
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final bool? res =
          await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return res ?? false;
    } catch (e) {
      debugPrint('requestIgnoreBatteryOptimizations error: $e');
      return false;
    }
  }

  static Future<int> getPendingEventsCount() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 0;
    }
    try {
      final diag = await getDiagnostics();
      return (diag['pending_queue_count'] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<Map<String, dynamic>> getDiagnostics() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return {
        'notification_access_granted': false,
        'listener_service_running': false,
        'battery_level': 100,
        'battery_optimization_disabled': false,
        'pending_queue_count': 0,
        'total_events_count': 0,
        'android_version': 'Desktop/Web',
        'device_model': 'Simulator',
        'device_id': 'PB-DEV-WEB001',
        'is_emulator': true,
        'app_version': '1.0.0',
      };
    }
    try {
      final Map<dynamic, dynamic>? res =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getDiagnostics');
      return Map<String, dynamic>.from(res ?? {});
    } catch (e) {
      debugPrint('getDiagnostics error: $e');
      return {
        'notification_access_granted': false,
        'listener_service_running': false,
        'battery_level': 0,
        'android_version': 'Android',
      };
    }
  }

  static Future<Map<String, dynamic>> syncNow() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return {'success': true, 'synced_count': 0};
    }
    try {
      final Map<dynamic, dynamic>? res =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('syncNow');
      return Map<String, dynamic>.from(res ?? {});
    } catch (e) {
      debugPrint('syncNow error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> getMonitoredApps() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return [
        {'name': 'PhonePe', 'package': 'com.phonepe.app', 'enabled': true},
        {
          'name': 'Google Pay',
          'package': 'com.google.android.apps.nbu.paisa.user',
          'enabled': true,
        },
        {'name': 'Paytm', 'package': 'net.one97.paytm', 'enabled': true},
        {'name': 'BHIM UPI', 'package': 'in.org.npci.upiapp', 'enabled': true},
      ];
    }
    try {
      final List<dynamic>? list =
          await _channel.invokeMethod<List<dynamic>>('getMonitoredApps');
      return list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ??
          [];
    } catch (e) {
      debugPrint('getMonitoredApps error: $e');
      return [];
    }
  }

  static Future<bool> setAppMonitored(String package, bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final bool? res = await _channel.invokeMethod<bool>('setAppMonitored', {
        'package': package,
        'enabled': enabled,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('setAppMonitored error: $e');
      return false;
    }
  }

  static Future<bool> simulateNotification({
    required String package,
    required String title,
    required String text,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final Map<dynamic, dynamic>? res =
          await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'simulateNotification',
        {'package': package, 'title': title, 'text': text},
      );
      return res?['success'] == true;
    } catch (e) {
      debugPrint('simulateNotification error: $e');
      return false;
    }
  }

  static Future<bool> setCustomFormat({
    required String package,
    required String type,
    required String regex,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final bool? res = await _channel.invokeMethod<bool>('setCustomFormat', {
        'package': package,
        'type': type,
        'regex': regex,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('setCustomFormat error: $e');
      return false;
    }
  }

  static Future<bool> saveCustomFormatFull({
    required String package,
    String? rulesJson,
    String? amountRegex,
    String? senderRegex,
    String? referenceRegex,
    String? bankRegex,
    String? titleMatchMode,
    String? titleMatchValue,
    String? requiredKeywords,
    String? ignoreKeywords,
    bool? caseSensitive,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final bool? res = await _channel.invokeMethod<bool>('setCustomFormat', {
        'package': package,
        'rules_json': rulesJson,
        'amount_regex': amountRegex,
        'sender_regex': senderRegex,
        'reference_regex': referenceRegex,
        'bank_regex': bankRegex,
        'title_match_mode': titleMatchMode,
        'title_match_value': titleMatchValue,
        'required_keywords': requiredKeywords,
        'ignore_keywords': ignoreKeywords,
        'case_sensitive': caseSensitive,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('saveCustomFormatFull error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getCustomRule(String package) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return {};
    }
    try {
      final Map<dynamic, dynamic>? res =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getCustomFormat', {'package': package});
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      debugPrint('getCustomRule error: $e');
    }
    return {};
  }

  static Future<bool> shareReceiptPdf({
    required String receiptNo,
    required String studentName,
    required String invoiceRef,
    required String feeHead,
    required String paymentMode,
    required String bankUtr,
    required String dateTime,
    required String amount,
    String? baseAmount,
    String? excessAmount,
    String? status,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final bool? res = await _channel.invokeMethod<bool>('shareReceiptPdf', {
        'receipt_no': receiptNo,
        'student_name': studentName,
        'invoice_ref': invoiceRef,
        'fee_head': feeHead,
        'payment_mode': paymentMode,
        'bank_utr': bankUtr,
        'date_time': dateTime,
        'amount': amount,
        'base_amount': baseAmount,
        'excess_amount': excessAmount,
        'status': status,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('shareReceiptPdf error: $e');
      return false;
    }
  }

  static Future<bool> deleteCustomFormat({
    required String package,
    String? type,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final bool? res = await _channel.invokeMethod<bool>('deleteCustomFormat', {
        'package': package,
        'type': type,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('deleteCustomFormat error: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getLocalNotifications() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return [];
    }
    try {
      final List<dynamic>? list =
          await _channel.invokeMethod<List<dynamic>>('getLocalNotifications');
      if (list != null) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('getLocalNotifications error: $e');
    }
    return [];
  }

  static Future<bool> forceRebindListener() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final bool? res = await _channel.invokeMethod<bool>('forceRebindListener');
      return res ?? false;
    } catch (e) {
      debugPrint('forceRebindListener error: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getRawNotifications({int limit = 100}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return [];
    }
    try {
      final List<dynamic>? list =
          await _channel.invokeMethod<List<dynamic>>('getRawNotifications', {'limit': limit});
      if (list != null) {
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('getRawNotifications error: $e');
    }
    return [];
  }

  static Future<bool> clearRawNotifications() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final bool? res = await _channel.invokeMethod<bool>('clearRawNotifications');
      return res ?? false;
    } catch (e) {
      debugPrint('clearRawNotifications error: $e');
      return false;
    }
  }

  static Future<bool> openAutostartSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    try {
      final bool? res = await _channel.invokeMethod<bool>('openAutostartSettings');
      return res ?? false;
    } catch (e) {
      debugPrint('openAutostartSettings error: $e');
      return false;
    }
  }

  static Future<Map<String, String>> getCustomFormats() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return {};
    }
    try {
      final Map<dynamic, dynamic>? res =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getCustomFormats');
      if (res != null) {
        return res.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (e) {
      debugPrint('getCustomFormats error: $e');
    }
    return {};
  }
}
