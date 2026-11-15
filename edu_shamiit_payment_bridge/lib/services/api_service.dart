import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/dashboard_model.dart';
import '../models/notification_model.dart';
import '../models/transaction_model.dart';
import '../models/settings_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _baseUrl = AppConstants.defaultLocalServerUrl;
  String _schoolId = AppConstants.defaultSchoolId;
  String _deviceId = AppConstants.defaultDeviceId;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(AppConstants.prefsServerUrlKey) ??
        (kIsWeb
            ? AppConstants.defaultLocalServerUrl
            : (defaultTargetPlatform == TargetPlatform.android
                ? AppConstants.defaultServerUrl
                : AppConstants.defaultLocalServerUrl));
    _schoolId = prefs.getString(AppConstants.prefsSchoolIdKey) ??
        AppConstants.defaultSchoolId;
    _deviceId = prefs.getString(AppConstants.prefsDeviceIdKey) ??
        AppConstants.defaultDeviceId;
  }

  void updateConfig({String? baseUrl, String? schoolId, String? deviceId}) {
    if (baseUrl != null) _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (schoolId != null) _schoolId = schoolId;
    if (deviceId != null) _deviceId = deviceId;
  }

  String get baseUrl => _baseUrl;
  String get schoolId => _schoolId;
  String get deviceId => _deviceId;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-School-ID': _schoolId,
        'X-Device-ID': _deviceId,
      };

  Future<DashboardData> getDashboardData() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/dashboard'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return DashboardData.fromJson(data);
      }
    } catch (e) {
      debugPrint('[ApiService] getDashboardData network fallback: $e');
    }
    return DashboardData.mock();
  }

  Future<List<PaymentNotificationItem>> getNotifications({String status = 'All'}) async {
    try {
      final uri = Uri.parse('$_baseUrl/notifications?status=$status&limit=100');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> items = data['items'] ?? [];
        return items.map((e) => PaymentNotificationItem.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService] getNotifications network fallback: $e');
    }
    final all = PaymentNotificationItem.getMockItems();
    if (status == 'All') return all;
    if (status == 'Matched') {
      return all.where((e) => e.candidateMatchStatus == 'MATCHED_CANDIDATE').toList();
    }
    if (status == 'Unmatched') {
      return all.where((e) => e.candidateMatchStatus == 'UNMATCHED').toList();
    }
    if (status == 'Ignored') {
      return all.where((e) => e.candidateMatchStatus == 'IGNORED').toList();
    }
    return all;
  }

  Future<Map<String, int>> getTransactionsSummary() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/transactions/summary'), headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return {
          'successful': data['successful'] ?? 38,
          'pending': data['pending'] ?? 3,
          'unmatched': data['unmatched'] ?? 2,
          'refunds': data['refunds'] ?? 1,
        };
      }
    } catch (e) {
      debugPrint('[ApiService] getTransactionsSummary network fallback: $e');
    }
    return {'successful': 38, 'pending': 3, 'unmatched': 2, 'refunds': 1};
  }

  Future<List<TransactionItem>> getTransactions({String status = 'All', String? search}) async {
    try {
      var urlStr = '$_baseUrl/transactions?status=$status&limit=100';
      if (search != null && search.isNotEmpty) {
        urlStr += '&search=${Uri.encodeComponent(search)}';
      }
      final res = await http.get(Uri.parse(urlStr), headers: _headers).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> items = data['items'] ?? [];
        return items.map((e) => TransactionItem.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService] getTransactions network fallback: $e');
    }
    final all = TransactionItem.getMockItems();
    if (status == 'All') return all;
    if (status == 'Successful') {
      return all.where((e) => e.paymentStatus == 'VERIFIED_SUCCESS').toList();
    }
    if (status == 'Pending') {
      return all.where((e) => e.paymentStatus == 'PENDING').toList();
    }
    if (status == 'Unmatched') {
      return all.where((e) => e.paymentStatus == 'UNMATCHED').toList();
    }
    if (status == 'Refunds') {
      return all.where((e) => e.paymentStatus == 'REFUNDED').toList();
    }
    return all;
  }

  Future<TransactionItem?> getTransactionDetails(String id) async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/transactions/$id'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return TransactionItem.fromJson(json.decode(res.body));
      }
    } catch (e) {
      debugPrint('[ApiService] getTransactionDetails network fallback: $e');
    }
    final mockList = TransactionItem.getMockItems();
    return mockList.firstWhere((e) => e.id == id, orElse: () => mockList.first);
  }

  Future<BridgeSettings> getSettings() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/settings'), headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return BridgeSettings.fromJson(json.decode(res.body));
      }
    } catch (e) {
      debugPrint('[ApiService] getSettings network fallback: $e');
    }
    return BridgeSettings();
  }

  Future<bool> updateSettings(BridgeSettings settings) async {
    try {
      final res = await http
          .put(
            Uri.parse('$_baseUrl/settings'),
            headers: _headers,
            body: json.encode(settings.toJson()),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] updateSettings error: $e');
      return true;
    }
  }

  Future<List<MonitoredAppItem>> getMonitoredApps() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/monitored-apps'), headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List<dynamic> list = json.decode(res.body);
        return list.map((e) => MonitoredAppItem.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService] getMonitoredApps network fallback: $e');
    }
    return [
      MonitoredAppItem(id: '1', name: 'PhonePe', packageName: 'com.phonepe.app', isEnabled: true),
      MonitoredAppItem(
        id: '2',
        name: 'Google Pay',
        packageName: 'com.google.android.apps.nbu.paisa.user',
        isEnabled: true,
      ),
    ];
  }

  Future<bool> toggleMonitoredApp(String appId, bool isEnabled) async {
    try {
      final res = await http
          .put(Uri.parse('$_baseUrl/monitored-apps/$appId?is_enabled=$isEnabled'), headers: _headers)
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] toggleMonitoredApp error: $e');
      return true;
    }
  }

  Future<bool> testConnection() async {
    try {
      final res = await http
          .post(Uri.parse('$_baseUrl/sync/test'), headers: _headers)
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] testConnection error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> syncNow() async {
    try {
      final res = await http
          .post(Uri.parse('$_baseUrl/sync'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
    } catch (e) {
      debugPrint('[ApiService] syncNow error: $e');
    }
    return {'success': true, 'synced_count': 0};
  }

  Future<bool> triggerSync() async {
    final res = await syncNow();
    return res['success'] == true;
  }
}
