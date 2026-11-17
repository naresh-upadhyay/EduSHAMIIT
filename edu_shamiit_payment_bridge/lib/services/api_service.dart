import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/platform_bridge.dart';
import '../models/dashboard_model.dart';
import '../models/notification_model.dart';
import '../models/transaction_model.dart';
import '../models/settings_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _baseUrl = AppConstants.defaultLocalServerUrl;
  String _schoolId = '';
  String _institutionName = '';
  String _deviceId = '';
  String _authToken = '';
  bool _isEmulator = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Determine if hardware is Android emulator or real phone
    _isEmulator = await PlatformBridge.isDeviceEmulator();
    AppConstants.isEmulator = _isEmulator;

    // Retrieve or auto-generate unique hardware-based device ID
    var storedDeviceId = prefs.getString(AppConstants.prefsDeviceIdKey);
    if (storedDeviceId == null || storedDeviceId.isEmpty || storedDeviceId == 'PB-AND-001') {
      storedDeviceId = await PlatformBridge.getUniqueDeviceId();
      await prefs.setString(AppConstants.prefsDeviceIdKey, storedDeviceId);
    }
    _deviceId = storedDeviceId;

    // Load user/school identity from preferences
    _schoolId = prefs.getString(AppConstants.prefsSchoolIdKey) ?? '';
    _institutionName = prefs.getString(AppConstants.prefsInstitutionKey) ?? '';
    _authToken = prefs.getString(AppConstants.prefsUserTokenKey) ?? '';

    // Smart Server URL resolution
    // If on local emulator or web, connect to 127.0.0.1:8082
    // If on real mobile device, default to live cloud API: https://eduapi.shamiit.com
    var savedUrl = prefs.getString(AppConstants.prefsServerUrlKey);
    if (_isEmulator || kIsWeb) {
      if (savedUrl == null || savedUrl.isEmpty || savedUrl.contains('eduapi.shamiit.com')) {
        savedUrl = 'http://127.0.0.1:8082/api/v1/payment-bridge';
        await prefs.setString(AppConstants.prefsServerUrlKey, savedUrl);
      }
    } else {
      if (savedUrl == null || savedUrl.isEmpty || savedUrl.contains('10.0.2.2') || savedUrl.contains('127.0.0.1') || savedUrl.contains('localhost')) {
        savedUrl = AppConstants.livePaymentBridgeUrl;
        await prefs.setString(AppConstants.prefsServerUrlKey, savedUrl);
      }
    }

    _baseUrl = savedUrl ?? AppConstants.getDefaultPaymentBridgeUrl();

    // If already logged in, automatically ensure device is registered with backend
    if (_authToken.isNotEmpty && _schoolId.isNotEmpty) {
      registerDeviceWithBackend().catchError((e) {
        debugPrint('[ApiService] Auto device registration failed on startup: $e');
        return false;
      });
    }
  }

  void updateConfig({
    String? baseUrl,
    String? schoolId,
    String? institutionName,
    String? deviceId,
    String? authToken,
  }) {
    if (baseUrl != null) _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (schoolId != null) _schoolId = schoolId;
    if (institutionName != null) _institutionName = institutionName;
    if (deviceId != null) _deviceId = deviceId;
    if (authToken != null) _authToken = authToken;
  }

  String get baseUrl => _baseUrl;
  String get schoolId => _schoolId.isNotEmpty ? _schoolId : '11111111-1111-1111-1111-111111111111';
  String get institutionName => _institutionName;
  String get deviceId => _deviceId;
  String get authToken => _authToken;
  bool get isEmulator => _isEmulator;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-School-ID': _schoolId.isNotEmpty ? _schoolId : '11111111-1111-1111-1111-111111111111',
        if (_deviceId.isNotEmpty) 'X-Device-ID': _deviceId,
        if (_authToken.isNotEmpty) 'Authorization': 'Bearer $_authToken',
      };

  List<String> _getCandidateUrls(String pathAndQuery) {
    final cleanPath = pathAndQuery.startsWith('/') ? pathAndQuery : '/$pathAndQuery';
    final list = <String>[];

    if (_isEmulator) {
      list.add('http://127.0.0.1:8082/api/v1/payment-bridge$cleanPath');
      list.add('http://10.0.2.2:8082/api/v1/payment-bridge$cleanPath');
    } else if (kIsWeb) {
      list.add('http://127.0.0.1:8082/api/v1/payment-bridge$cleanPath');
      list.add('http://localhost:8082/api/v1/payment-bridge$cleanPath');
    } else {
      list.add('${AppConstants.livePaymentBridgeUrl}$cleanPath');
      list.add('http://127.0.0.1:8082/api/v1/payment-bridge$cleanPath');
    }
    final primary = '$_baseUrl$cleanPath';
    if (!list.contains(primary)) {
      list.insert(0, primary);
    }
    return list;
  }

  void _onSuccessUrl(String usedUrl) {
    try {
      final uri = Uri.parse(usedUrl);
      final segments = uri.path.split('/');
      if (segments.length >= 4) {
        final newBase = '${uri.scheme}://${uri.host}:${uri.port}${segments.sublist(0, 4).join('/')}';
        if (newBase.contains('/api/v1/payment-bridge') && newBase != _baseUrl) {
          debugPrint('[ApiService] Switching active baseUrl to: $newBase');
          _baseUrl = newBase;
        }
      }
    } catch (_) {}
  }

  Future<http.Response> _getWithFallback(String pathAndQuery, {Duration timeout = const Duration(seconds: 4)}) async {
    final candidates = _getCandidateUrls(pathAndQuery);
    dynamic lastError;
    http.Response? lastResponse;
    for (final url in candidates) {
      try {
        final res = await http.get(Uri.parse(url), headers: _headers).timeout(timeout);
        if (res.statusCode >= 200 && res.statusCode < 400) {
          _onSuccessUrl(url);
          return res;
        }
        lastResponse = res;
      } catch (e) {
        lastError = e;
      }
    }
    if (lastResponse != null) return lastResponse;
    throw lastError ?? Exception('Network connection failed');
  }

  Future<http.Response> _postWithFallback(String pathAndQuery, {Object? body, Duration timeout = const Duration(seconds: 4)}) async {
    final candidates = _getCandidateUrls(pathAndQuery);
    dynamic lastError;
    http.Response? lastResponse;
    for (final url in candidates) {
      try {
        final res = await http.post(Uri.parse(url), headers: _headers, body: body).timeout(timeout);
        if (res.statusCode >= 200 && res.statusCode < 400) {
          _onSuccessUrl(url);
          return res;
        }
        lastResponse = res;
      } catch (e) {
        lastError = e;
      }
    }
    if (lastResponse != null) return lastResponse;
    throw lastError ?? Exception('Network connection failed');
  }

  Future<http.Response> _putWithFallback(String pathAndQuery, {Object? body, Duration timeout = const Duration(seconds: 4)}) async {
    final candidates = _getCandidateUrls(pathAndQuery);
    dynamic lastError;
    http.Response? lastResponse;
    for (final url in candidates) {
      try {
        final res = await http.put(Uri.parse(url), headers: _headers, body: body).timeout(timeout);
        if (res.statusCode >= 200 && res.statusCode < 400) {
          _onSuccessUrl(url);
          return res;
        }
        lastResponse = res;
      } catch (e) {
        lastError = e;
      }
    }
    if (lastResponse != null) return lastResponse;
    throw lastError ?? Exception('Network connection failed');
  }

  // =========================================================================
  // AUTHENTICATION & LOGIN FLOWS
  // =========================================================================

  List<String> _getAuthCandidateUrls(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final list = <String>[];
    if (_isEmulator || AppConstants.isEmulator) {
      list.add('http://127.0.0.1:8082/api$cleanPath');
      list.add('http://10.0.2.2:8082/api$cleanPath');
    } else if (kIsWeb) {
      list.add('http://127.0.0.1:8082/api$cleanPath');
      list.add('http://localhost:8082/api$cleanPath');
    } else {
      list.add('${AppConstants.liveServerBaseUrl}/api$cleanPath');
      list.add('http://127.0.0.1:8082/api$cleanPath');
    }
    final authBase = AppConstants.getAuthBaseUrl();
    final primary = '$authBase$cleanPath';
    if (!list.contains(primary)) {
      list.insert(0, primary);
    }
    final live = '${AppConstants.liveServerBaseUrl}/api$cleanPath';
    if (!list.contains(live)) {
      list.add(live);
    }
    return list;
  }

  /// Executes Password-based login against FastAPI /api/auth/login
  Future<Map<String, dynamic>> loginWithPassword({
    required String email,
    required String password,
  }) async {
    final urlCandidates = _getAuthCandidateUrls('/auth/login');

    dynamic lastError;
    for (final url in urlCandidates) {
      try {
        final res = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: json.encode({
            'email': email.trim(),
            'password': password,
          }),
        ).timeout(const Duration(seconds: 6));

        final data = json.decode(res.body);
        if (res.statusCode == 200 && data['success'] == true) {
          await _processLoginSuccess(data);
          return {'success': true, 'data': data['data']};
        } else {
          return {
            'success': false,
            'detail': data['detail'] ?? 'Invalid email or password',
          };
        }
      } catch (e) {
        lastError = e;
      }
    }
    return {'success': false, 'detail': 'Connection error: ${lastError ?? 'Server unreachable'}'};
  }

  /// Sends one-time passcode to email
  Future<Map<String, dynamic>> sendLoginOtp(String email) async {
    final urlCandidates = _getAuthCandidateUrls('/auth/send-login-otp');
    dynamic lastError;
    for (final url in urlCandidates) {
      try {
        final res = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'identifier': email.trim()}),
        ).timeout(const Duration(seconds: 6));

        final data = json.decode(res.body);
        return {
          'success': res.statusCode == 200 && data['success'] == true,
          'detail': data['detail'] ?? (data['success'] == true ? 'OTP sent successfully' : 'Failed to send OTP'),
        };
      } catch (e) {
        lastError = e;
      }
    }
    return {'success': false, 'detail': 'Connection error: $lastError'};
  }

  /// Verifies OTP code and returns authenticated session
  Future<Map<String, dynamic>> verifyLoginOtp({
    required String email,
    required String otp,
  }) async {
    final urlCandidates = _getAuthCandidateUrls('/auth/verify-login-otp');
    dynamic lastError;
    for (final url in urlCandidates) {
      try {
        final res = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': email.trim(),
            'otp': otp.trim(),
          }),
        ).timeout(const Duration(seconds: 6));

        final data = json.decode(res.body);
        if (res.statusCode == 200 && data['success'] == true) {
          await _processLoginSuccess(data);
          return {'success': true, 'data': data['data']};
        } else {
          return {
            'success': false,
            'detail': data['detail'] ?? 'Invalid or expired OTP',
          };
        }
      } catch (e) {
        lastError = e;
      }
    }
    return {'success': false, 'detail': 'Connection error: $lastError'};
  }

  /// Sends password reset OTP
  Future<Map<String, dynamic>> sendForgotPasswordOtp(String email) async {
    final urlCandidates = _getAuthCandidateUrls('/auth/send-otp');
    dynamic lastError;
    for (final url in urlCandidates) {
      try {
        final res = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'identifier': email.trim()}),
        ).timeout(const Duration(seconds: 6));

        final data = json.decode(res.body);
        return {
          'success': res.statusCode == 200 && data['success'] == true,
          'detail': data['detail'] ?? 'OTP dispatch initiated',
        };
      } catch (e) {
        lastError = e;
      }
    }
    return {'success': false, 'detail': 'Network error: $lastError'};
  }

  /// Resets password with verified OTP
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final urlCandidates = _getAuthCandidateUrls('/auth/reset-password');
    dynamic lastError;
    for (final url in urlCandidates) {
      try {
        final res = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': email.trim(),
            'otp': otp.trim(),
            'new_password': newPassword,
          }),
        ).timeout(const Duration(seconds: 6));

        final data = json.decode(res.body);
        return {
          'success': res.statusCode == 200 && data['success'] == true,
          'detail': data['detail'] ?? 'Password reset successfully',
        };
      } catch (e) {
        lastError = e;
      }
    }
    return {'success': false, 'detail': 'Network error: $lastError'};
  }

  Future<void> _processLoginSuccess(Map<String, dynamic> responseData) async {
    final prefs = await SharedPreferences.getInstance();
    final data = responseData['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = data['user'] as Map<String, dynamic>;

    final schoolId = (user['school_id'] ?? responseData['school_id'] ?? '').toString();
    final userEmail = (user['email'] ?? '').toString();
    final userName = (user['full_name'] ?? 'Authorized User').toString();
    final userRole = (user['role'] ?? 'admin').toString();

    // Cache token and school ID first so subsequent requests are authenticated
    _authToken = token;
    _schoolId = schoolId;

    // Direct extraction of verified institution name from login response
    var institutionName = (user['school_name'] ?? responseData['school_name'] ?? data['school_name'] ?? '').toString();
    if (institutionName.isEmpty && schoolId.isNotEmpty) {
      institutionName = await _fetchSchoolName(schoolId) ?? 'Shami Innovation Academy';
    } else if (institutionName.isEmpty) {
      institutionName = 'Shami Innovation Academy';
    }

    _institutionName = institutionName;

    await prefs.setString(AppConstants.prefsUserTokenKey, token);
    await prefs.setString(AppConstants.prefsSchoolIdKey, schoolId);
    await prefs.setString(AppConstants.prefsInstitutionKey, institutionName);
    await prefs.setString(AppConstants.prefsUserEmailKey, userEmail);
    await prefs.setString(AppConstants.prefsUserNameKey, userName);
    await prefs.setString(AppConstants.prefsUserRoleKey, userRole);
    await prefs.setBool(AppConstants.prefsIsLoggedInKey, true);

    // Register this device automatically with the authenticated school
    await registerDeviceWithBackend();
  }

  Future<String?> _fetchSchoolName(String schoolId) async {
    try {
      final sRes = await _getWithFallback('/school-info?school_id=$schoolId');
      if (sRes.statusCode == 200) {
        final d = json.decode(sRes.body);
        if (d['school_name'] != null && d['school_name'].toString().isNotEmpty) {
          return d['school_name'] as String;
        }
      }
      final res = await _getWithFallback('/devices/me?device_id=$_deviceId');
      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        return d['school_name'] as String?;
      }
    } catch (_) {}
    return 'Shami Innovation Academy';
  }

  Future<bool> registerDeviceWithBackend() async {
    if (_deviceId.isEmpty || _schoolId.isEmpty) return false;
    try {
      final diag = await PlatformBridge.getDiagnostics();
      final body = json.encode({
        'device_id': _deviceId,
        'school_id': _schoolId,
        'device_name': 'EduSHAMIIT Terminal (${_deviceId.substring(0, 6)})',
        'model': diag['device_model'] ?? 'Android Terminal',
        'android_version': diag['android_version'] ?? 'Android',
        'app_version': diag['app_version'] ?? '1.0.0',
      });
      final res = await _postWithFallback('/devices/register', body: body);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] registerDevice error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = '';
    _schoolId = '';
    _institutionName = '';
    await prefs.remove(AppConstants.prefsUserTokenKey);
    await prefs.remove(AppConstants.prefsSchoolIdKey);
    await prefs.remove(AppConstants.prefsInstitutionKey);
    await prefs.remove(AppConstants.prefsUserEmailKey);
    await prefs.remove(AppConstants.prefsUserNameKey);
    await prefs.remove(AppConstants.prefsUserRoleKey);
    await prefs.setBool(AppConstants.prefsIsLoggedInKey, false);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(AppConstants.prefsIsLoggedInKey) ?? false;
    final token = prefs.getString(AppConstants.prefsUserTokenKey);
    return loggedIn && token != null && token.isNotEmpty;
  }

  // =========================================================================
  // PAYMENT BRIDGE BUSINESS ENDPOINTS
  // =========================================================================

  Future<DashboardData> getDashboardData() async {
    try {
      final res = await _getWithFallback('/dashboard');
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return DashboardData.fromJson(data);
      } else {
        throw Exception('Failed to load dashboard data: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] getDashboardData network error: $e');
      throw Exception('Network error: Could not reach the server.');
    }
  }

  Future<NotificationsResult> getNotificationsWithSummary({String status = 'All'}) async {
    try {
      final cleanStatus = status.split(' ').first;
      final res = await _getWithFallback('/notifications?status=$cleanStatus&limit=100');
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> items = data['items'] ?? [];
        final parsedItems = items.map((e) => PaymentNotificationItem.fromJson(e)).toList();
        final summary = data['summary'] as Map<String, dynamic>? ?? {};
        return NotificationsResult(
          items: parsedItems,
          allCount: (summary['all'] as num?)?.toInt() ?? parsedItems.length,
          matchedCount: (summary['matched'] as num?)?.toInt() ?? parsedItems.where((i) => i.isMatched).length,
          unmatchedCount: (summary['unmatched'] as num?)?.toInt() ?? parsedItems.where((i) => i.isUnmatched).length,
          ignoredCount: (summary['ignored'] as num?)?.toInt() ?? parsedItems.where((i) => i.isIgnored).length,
        );
      } else {
        throw Exception('Failed to load notifications: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] getNotifications network error: $e');
      throw Exception('Network error: Could not reach the server.');
    }
  }

  Future<List<PaymentNotificationItem>> getNotifications({String status = 'All'}) async {
    final res = await getNotificationsWithSummary(status: status);
    return res.items;
  }

  Future<Map<String, int>> getTransactionsSummary() async {
    try {
      final res = await _getWithFallback('/transactions/summary');
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return {
          'successful': data['successful'] ?? 0,
          'pending': data['pending'] ?? 0,
          'unmatched': data['unmatched'] ?? 0,
          'refunds': data['refunds'] ?? 0,
        };
      } else {
        throw Exception('Failed to load transaction summary: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] getTransactionsSummary network error: $e');
      throw Exception('Network error: Could not reach the server.');
    }
  }

  Future<List<TransactionItem>> getTransactions({String status = 'All', String? search}) async {
    try {
      var path = '/transactions?status=$status&limit=100';
      if (search != null && search.isNotEmpty) {
        path += '&search=${Uri.encodeComponent(search)}';
      }
      final res = await _getWithFallback(path);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> items = data['items'] ?? [];
        return items.map((e) => TransactionItem.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load transactions: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] getTransactions network error: $e');
      throw Exception('Network error: Could not reach the server.');
    }
  }

  Future<TransactionItem?> getTransactionDetails(String id) async {
    try {
      final res = await _getWithFallback('/transactions/$id');
      if (res.statusCode == 200) {
        return TransactionItem.fromJson(json.decode(res.body));
      } else {
        throw Exception('Failed to load transaction details: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] getTransactionDetails network error: $e');
      throw Exception('Network error: Could not reach the server.');
    }
  }

  Future<BridgeSettings> getSettings() async {
    try {
      final res = await _getWithFallback('/settings');
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
      final res = await _putWithFallback(
        '/settings',
        body: json.encode(settings.toJson()),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] updateSettings error: $e');
      return true;
    }
  }

  Future<List<MonitoredAppItem>> getMonitoredApps() async {
    try {
      final res = await _getWithFallback('/monitored-apps');
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
      final res = await _putWithFallback('/monitored-apps/$appId?is_enabled=$isEnabled');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] toggleMonitoredApp error: $e');
      return true;
    }
  }

  Future<bool> testConnection() async {
    try {
      final res = await _postWithFallback('/sync/test');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] testConnection error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> syncNow() async {
    try {
      final res = await _postWithFallback('/sync');
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
