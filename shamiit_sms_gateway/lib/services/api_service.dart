import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/platform_bridge.dart';
import '../models/sms_models.dart';
import 'websocket_service.dart';

enum GatewayConnectionState { online, offline, connecting, authError }

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _baseUrl = AppConstants.liveSmsApiBaseUrl;
  String _schoolId = '11111111-1111-1111-1111-111111111111';
  String _institutionName = 'Shami Innovation Academy';
  String _deviceId = '';
  String _authToken = '';
  String _deviceToken = '';
  bool _isEmulator = false;

  GatewayConnectionState connectionState = GatewayConnectionState.connecting;
  DateTime? lastSuccessfulSync;
  DateTime? lastSuccessfulRequest;
  int? lastApiLatencyMs;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isEmulator = await PlatformBridge.isEmulator();
    AppConstants.isEmulator = _isEmulator;

    var storedDeviceId = prefs.getString(AppConstants.prefsDeviceIdKey);
    if (storedDeviceId == null || storedDeviceId.isEmpty) {
      storedDeviceId = await PlatformBridge.getUniqueDeviceId();
      await prefs.setString(AppConstants.prefsDeviceIdKey, storedDeviceId);
    }
    _deviceId = storedDeviceId;

    _schoolId = prefs.getString(AppConstants.prefsSchoolIdKey) ?? '11111111-1111-1111-1111-111111111111';
    _institutionName = prefs.getString(AppConstants.prefsInstitutionKey) ?? 'Shami Innovation Academy';
    _authToken = prefs.getString(AppConstants.prefsUserTokenKey) ?? '';
    _deviceToken = prefs.getString(AppConstants.prefsDeviceTokenKey) ?? '';

    final savedUrl = prefs.getString(AppConstants.prefsServerUrlKey);
    if (savedUrl != null && savedUrl.trim().isNotEmpty) {
      if (savedUrl.toLowerCase().contains('sms.shamiit.com')) {
        // Migrate deprecated placeholder host from older installs to eduapi.shamiit.com
        _baseUrl = AppConstants.liveSmsApiBaseUrl;
        await prefs.setString(AppConstants.prefsServerUrlKey, _baseUrl);
        await PlatformBridge.saveLocalSettings({'server_url': _baseUrl});
      } else {
        _baseUrl = _normalizeApiBase(savedUrl);
      }
    } else {
      _baseUrl = AppConstants.getDefaultApiUrl();
      await prefs.setString(AppConstants.prefsServerUrlKey, _baseUrl);
      await PlatformBridge.saveLocalSettings({'server_url': _baseUrl});
    }

    await PlatformBridge.saveCredentials(
      authToken: _authToken,
      deviceToken: _deviceToken,
      deviceId: _deviceId,
      schoolId: _schoolId,
    );

    if (_authToken.isNotEmpty) {
      registerDeviceWithBackend().catchError((_) => false);
    }
  }

  String _normalizeApiBase(String raw) {
    final clean = raw.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.endsWith('/api/v1')) return clean;
    if (clean.endsWith('/api')) return '${clean}v1'.replaceFirst('/apiv1', '/api/v1');
    return '$clean/api/v1';
  }

  String get displayServerHost {
    try {
      final u = Uri.parse(_baseUrl);
      return '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}';
    } catch (_) {
      return _baseUrl;
    }
  }

  String get baseUrl => _baseUrl;
  String get schoolId => _schoolId;
  String get institutionName => _institutionName;
  String get deviceId => _deviceId;
  String get authToken => _authToken;
  String get deviceToken => _deviceToken;
  bool get isEmulator => _isEmulator;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-School-ID': _schoolId,
        if (_deviceId.isNotEmpty) 'X-Device-ID': _deviceId,
        if (_authToken.isNotEmpty) 'Authorization': 'Bearer $_authToken',
      };

  Future<void> setServerUrl(String newUrl) async {
    if (newUrl.trim().isEmpty) return;
    _baseUrl = _normalizeApiBase(newUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefsServerUrlKey, _baseUrl);
    await PlatformBridge.saveLocalSettings({'server_url': _baseUrl});
    WebSocketService().connect();
  }

  Future<http.Response> _request(String method, String path, {Object? body, Duration timeout = const Duration(seconds: 6)}) async {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final url = '$_baseUrl$cleanPath';
    final sw = Stopwatch()..start();
    try {
      late http.Response res;
      final uri = Uri.parse(url);
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: _headers).timeout(timeout);
          break;
        case 'POST':
          res = await http.post(uri, headers: _headers, body: body).timeout(timeout);
          break;
        case 'PUT':
          res = await http.put(uri, headers: _headers, body: body).timeout(timeout);
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: _headers).timeout(timeout);
          break;
        default:
          throw UnsupportedError(method);
      }
      sw.stop();
      lastApiLatencyMs = sw.elapsedMilliseconds;
      lastSuccessfulRequest = DateTime.now();
      if (res.statusCode == 401 || res.statusCode == 403) {
        connectionState = GatewayConnectionState.authError;
      } else if (res.statusCode < 500) {
        connectionState = GatewayConnectionState.online;
      }
      return res;
    } catch (e) {
      connectionState = GatewayConnectionState.offline;
      rethrow;
    }
  }

  // =========================================================================
  // AUTHENTICATION FLOWS (Inherited from SHAMIIT Payment Bridge / Auth API)
  // =========================================================================
  List<String> _getAuthCandidateUrls(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final list = <String>[];
    try {
      final uri = Uri.parse(_baseUrl);
      final hostBase = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
      list.add('$hostBase/api$cleanPath');
    } catch (_) {}

    if (kIsWeb) {
      list.add('http://127.0.0.1:8082/api$cleanPath');
      list.add('http://localhost:8082/api$cleanPath');
    } else if (_isEmulator || AppConstants.isEmulator) {
      list.add('http://10.0.2.2:8082/api$cleanPath');
      list.add('http://127.0.0.1:8082/api$cleanPath');
    } else {
      list.add('${AppConstants.liveServerBaseUrl}/api$cleanPath');
    }
    return list.toSet().toList();
  }

  Future<Map<String, dynamic>> loginWithPassword({
    required String email,
    required String password,
  }) async {
    dynamic lastError;
    for (final url in _getAuthCandidateUrls('/auth/login')) {
      try {
        final res = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
              body: json.encode({'email': email.trim(), 'password': password}),
            )
            .timeout(const Duration(seconds: 20));
        final data = json.decode(res.body);
        if (res.statusCode == 200 && data['success'] == true) {
          await _processLoginSuccess(data);
          return {'success': true, 'data': data['data']};
        }
        return {'success': false, 'detail': data['detail'] ?? 'Invalid email or password'};
      } catch (e) {
        lastError = e;
      }
    }
    return {'success': false, 'detail': 'Connection error: ${lastError ?? 'Server unreachable'}'};
  }

  Future<Map<String, dynamic>> sendLoginOtp(String email) async {
    dynamic lastError;
    for (final url in _getAuthCandidateUrls('/auth/send-login-otp')) {
      try {
        final res = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'identifier': email.trim()}),
            )
            .timeout(const Duration(seconds: 20));
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

  Future<Map<String, dynamic>> verifyLoginOtp({required String email, required String otp}) async {
    dynamic lastError;
    for (final url in _getAuthCandidateUrls('/auth/verify-login-otp')) {
      try {
        final res = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'identifier': email.trim(), 'otp': otp.trim()}),
            )
            .timeout(const Duration(seconds: 20));
        final data = json.decode(res.body);
        if (res.statusCode == 200 && data['success'] == true) {
          await _processLoginSuccess(data);
          return {'success': true, 'data': data['data']};
        }
        return {'success': false, 'detail': data['detail'] ?? 'Invalid or expired OTP'};
      } catch (e) {
        lastError = e;
      }
    }
    return {'success': false, 'detail': 'Connection error: $lastError'};
  }

  Future<Map<String, dynamic>> sendForgotPasswordOtp(String email) async {
    dynamic lastError;
    for (final url in _getAuthCandidateUrls('/auth/send-otp')) {
      try {
        final res = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'identifier': email.trim()}),
            )
            .timeout(const Duration(seconds: 20));
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

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    dynamic lastError;
    for (final url in _getAuthCandidateUrls('/auth/reset-password')) {
      try {
        final res = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'identifier': email.trim(),
                'otp': otp.trim(),
                'new_password': newPassword,
              }),
            )
            .timeout(const Duration(seconds: 20));
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

    final schoolId = (user['school_id'] ?? responseData['school_id'] ?? _schoolId).toString();
    final userEmail = (user['email'] ?? '').toString();
    final userName = (user['full_name'] ?? 'Gateway Administrator').toString();
    final userRole = (user['role'] ?? 'admin').toString();
    final userPhoto = (user['avatar_url'] ?? user['photo_url'] ?? '').toString();
    var institution = (user['school_name'] ?? responseData['school_name'] ?? '').toString();
    if (institution.isEmpty) institution = 'Shami Innovation Academy';

    _authToken = token;
    _schoolId = schoolId;
    _institutionName = institution;

    await prefs.setString(AppConstants.prefsUserTokenKey, token);
    await prefs.setString(AppConstants.prefsSchoolIdKey, schoolId);
    await prefs.setString(AppConstants.prefsInstitutionKey, institution);
    await prefs.setString(AppConstants.prefsUserEmailKey, userEmail);
    await prefs.setString(AppConstants.prefsUserNameKey, userName);
    await prefs.setString(AppConstants.prefsUserRoleKey, userRole);
    await prefs.setString(AppConstants.prefsUserPhotoKey, userPhoto);
    await prefs.setBool(AppConstants.prefsIsLoggedInKey, true);

    await PlatformBridge.saveCredentials(
      authToken: token,
      deviceId: _deviceId,
      schoolId: schoolId,
    );

    await registerDeviceWithBackend();
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.prefsUserTokenKey) ?? '';
    return token.isNotEmpty || (prefs.getBool(AppConstants.prefsIsLoggedInKey) ?? false);
  }

  Future<Map<String, String>> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(AppConstants.prefsUserNameKey) ?? 'Gateway Admin',
      'email': prefs.getString(AppConstants.prefsUserEmailKey) ?? 'admin@shamiit.com',
      'role': prefs.getString(AppConstants.prefsUserRoleKey) ?? 'Enterprise Admin',
      'institution': prefs.getString(AppConstants.prefsInstitutionKey) ?? _institutionName,
      'photo_url': prefs.getString(AppConstants.prefsUserPhotoKey) ?? '',
    };
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefsUserTokenKey);
    await prefs.setBool(AppConstants.prefsIsLoggedInKey, false);
    _authToken = '';
    await PlatformBridge.clearCredentials();
  }

  // =========================================================================
  // DEVICE REGISTRATION, SYNC & HEARTBEAT
  // =========================================================================
  Future<bool> registerDeviceWithBackend() async {
    try {
      final diag = await PlatformBridge.getDiagnostics();
      final res = await _request(
        'POST',
        '/device/register',
        body: json.encode({
          'device_id': _deviceId,
          'device_name': diag['device_model'] ?? 'Android Gateway',
          'model': diag['model'] ?? 'Android Device',
          'manufacturer': diag['manufacturer'] ?? '',
          'android_version': diag['android_version'] ?? 'Android',
          'app_version': AppConstants.appVersion,
          'school_id': _schoolId,
        }),
      );
      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        final tok = d['device_token'] as String?;
        if (tok != null && tok.isNotEmpty) {
          _deviceToken = tok;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppConstants.prefsDeviceTokenKey, tok);
          await PlatformBridge.saveCredentials(deviceToken: tok, deviceId: _deviceId, schoolId: _schoolId);
        }
        lastSuccessfulSync = DateTime.now();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> renewDeviceToken() async {
    final res = await _request('POST', '/device/token/renew?device_id=$_deviceId');
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && data['device_token'] != null) {
      _deviceToken = data['device_token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefsDeviceTokenKey, _deviceToken);
      await PlatformBridge.saveCredentials(deviceToken: _deviceToken);
    }
    return data;
  }

  Future<bool> setEmergencyDisable(bool disabled) async {
    await PlatformBridge.saveLocalSettings({'emergency_disabled': disabled});
    try {
      final res = await _request('POST', '/device/emergency-disable?disabled=$disabled&device_id=$_deviceId');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> testConnection({String? targetUrl}) async {
    final target = (targetUrl != null && targetUrl.trim().isNotEmpty)
        ? _normalizeApiBase(targetUrl)
        : _baseUrl;
    final sw = Stopwatch()..start();
    try {
      final res = await http
          .get(Uri.parse('$target/sms-gateway/health'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      sw.stop();
      if (res.statusCode == 200) {
        lastApiLatencyMs = sw.elapsedMilliseconds;
        lastSuccessfulRequest = DateTime.now();
        connectionState = GatewayConnectionState.online;
        return true;
      }
      return false;
    } catch (_) {
      connectionState = GatewayConnectionState.offline;
      return false;
    }
  }

  Future<Map<String, dynamic>> syncNow() async {
    final nativeSync = await PlatformBridge.syncNow();
    try {
      final sims = await PlatformBridge.discoverSims();
      final res = await _request(
        'POST',
        '/device/sync',
        body: json.encode({'device_id': _deviceId, 'sims': sims}),
      );
      if (res.statusCode == 200) {
        lastSuccessfulSync = DateTime.now();
        return {...nativeSync, ...json.decode(res.body), 'success': true};
      }
    } catch (_) {}
    return nativeSync;
  }

  // =========================================================================
  // SIM & DEVICE CONFIGURATION
  // =========================================================================
  Future<Map<String, dynamic>> getSimConfiguration() async {
    final localSims = await PlatformBridge.discoverSims();
    final localCfg = await PlatformBridge.getLocalSettings();
    try {
      final res = await _request('GET', '/sms/sim-configuration?device_id=$_deviceId');
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final backendSims = (body['sims'] as List<dynamic>? ?? [])
            .map((e) => SimInfo.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        final resolvedSims = localSims.isNotEmpty
            ? localSims.map(SimInfo.fromMap).toList()
            : backendSims;
        return {
          'sims': resolvedSims,
          'configuration': body['configuration'] ?? localCfg,
        };
      }
    } catch (_) {}
    return {
      'sims': localSims.map(SimInfo.fromMap).toList(),
      'configuration': localCfg,
    };
  }

  Future<Map<String, dynamic>> saveSimConfiguration({
    required List<SimInfo> sims,
    required Map<String, dynamic> configuration,
  }) async {
    for (final s in sims) {
      await PlatformBridge.setSimUsageMode(s.subscriptionId, s.usageMode);
    }
    await PlatformBridge.saveLocalSettings(configuration);

    try {
      final res = await _request(
        'POST',
        '/device/sim-configuration',
        body: json.encode({
          'device_id': _deviceId,
          'sims': sims.map((e) => e.toMap()).toList(),
          ...configuration,
        }),
      );
      if (res.statusCode == 200) {
        lastSuccessfulSync = DateTime.now();
        return json.decode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'success': true, 'offline_saved': true, 'conflicts': []};
  }

  Future<Map<String, dynamic>> getDeviceConfiguration() async {
    final local = await PlatformBridge.getLocalSettings();
    try {
      final res = await _request('GET', '/device/configuration?device_id=$_deviceId');
      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'configuration': local};
  }

  Future<bool> updateDeviceConfiguration(Map<String, dynamic> cfg) async {
    await PlatformBridge.saveLocalSettings(cfg);
    try {
      final res = await _request(
        'PUT',
        '/device/configuration',
        body: json.encode({'device_id': _deviceId, ...cfg}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // =========================================================================
  // SMS SENDING, HISTORY, DETAILS & STATISTICS
  // =========================================================================
  Future<Map<String, dynamic>> submitSms({
    required List<String> recipients,
    required String messageBody,
    int? subscriptionId,
    int? simSlot,
    String priority = 'NORMAL',
    String? scheduledAt,
    String? expiresAt,
    String? templateId,
    Map<String, dynamic>? templateVariables,
    String applicationSource = 'SMS Gateway App',
    String? referenceId,
    bool deliveryReportRequested = true,
  }) async {
    final isScheduled = scheduledAt != null && scheduledAt.trim().isNotEmpty;

    // Scheduled messages always use FastAPI as source of truth
    if (isScheduled) {
      final res = await _request(
        'POST',
        '/sms/send',
        body: json.encode({
          'recipients': recipients,
          'message_body': messageBody,
          'subscription_id': subscriptionId,
          'sim_slot': simSlot,
          'priority': priority,
          'scheduled_at': scheduledAt,
          'expires_at': expiresAt,
          'template_id': templateId,
          'template_variables': templateVariables,
          'application_source': applicationSource,
          'reference_id': referenceId,
          'delivery_report_requested': deliveryReportRequested,
          'device_id': _deviceId,
        }),
      );
      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
      final err = json.decode(res.body);
      throw Exception(err['detail'] ?? 'Failed to schedule SMS');
    }

    // Immediate send: submit to FastAPI to get authoritative message UUIDs if online,
    // and dispatch directly via native Android SmsManager when on Android hardware.
    List<String>? clientUuids;
    if (PlatformBridge.isAndroid) {
      final results = <Map<String, dynamic>>[];
      for (final r in recipients) {
        final nativeRes = await PlatformBridge.sendNativeSms(
          recipient: r,
          messageBody: messageBody,
          subscriptionId: subscriptionId,
          deliveryReportRequested: deliveryReportRequested,
          applicationSource: applicationSource,
          referenceId: referenceId,
          priority: priority,
        );
        results.add(nativeRes);
      }
      clientUuids = results
          .map((e) => e['message_uuid']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      final anyOk = results.any((e) => e['success'] == true);
      final firstErr = results.firstWhere((e) => e['success'] != true, orElse: () => {})['error'];
      try {
        await _request(
          'POST',
          '/device/sync',
          body: json.encode({
            'device_id': _deviceId,
            'outbound_messages': results
                .asMap()
                .entries
                .map((entry) => {
                      'message_uuid': entry.value['message_uuid'],
                      'recipient_number': recipients[entry.key],
                      'message_body': messageBody,
                      'sending_subscription_id': entry.value['subscription_id'] ?? subscriptionId,
                      'sending_sim_slot': entry.value['sim_slot'] ?? simSlot,
                      'carrier_name': entry.value['carrier_name'],
                      'application_source': applicationSource,
                      'reference_id': referenceId,
                      'priority': priority,
                      'status': entry.value['status'] ?? 'SENDING',
                      'failure_reason': entry.value['error'],
                      'delivery_report_requested': deliveryReportRequested,
                    })
                .toList(),
          }),
        );
      } catch (_) {}

      return {
        'success': anyOk,
        'count': results.length,
        'status': anyOk ? 'SENDING' : 'FAILED',
        'message_uuids': clientUuids,
        if (!anyOk) 'error': firstErr ?? 'Failed to send SMS',
      };
    } else {
      final res = await _request(
        'POST',
        '/sms/send',
        body: json.encode({
          'recipients': recipients,
          'message_body': messageBody,
          'subscription_id': subscriptionId,
          'sim_slot': simSlot,
          'priority': priority,
          'expires_at': expiresAt,
          'template_id': templateId,
          'template_variables': templateVariables,
          'application_source': applicationSource,
          'reference_id': referenceId,
          'delivery_report_requested': deliveryReportRequested,
          'device_id': _deviceId,
        }),
      );
      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
      final err = json.decode(res.body);
      throw Exception(err['detail'] ?? 'Failed to send SMS');
    }
  }

  Future<List<SmsMessageRecord>> getSmsHistory({
    String? status,
    String? direction,
    int? simSlot,
    String? application,
    String? search,
    String? startDate,
    String? endDate,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final params = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (status != null && status != 'ALL') 'status': status,
        if (direction != null && direction != 'ALL') 'direction': direction,
        if (simSlot != null) 'sim_slot': simSlot.toString(),
        if (application != null && application != 'ALL') 'application': application,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      };
      final q = Uri(queryParameters: params).query;
      final res = await _request('GET', '/sms/history?$q');
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        final remoteList = items
            .map((e) => SmsMessageRecord.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();

        // Merge any unsynced offline local messages that match active filters
        if (PlatformBridge.isAndroid) {
          final localUnsynced = await PlatformBridge.getLocalMessages(
            status: status,
            direction: direction,
            simSlot: simSlot,
            search: search,
            limit: 50,
            offset: 0,
          );
          final seen = remoteList.map((m) => m.messageUuid).toSet();
          final merged = <SmsMessageRecord>[
            ...localUnsynced
                .map(SmsMessageRecord.fromMap)
                .where((m) => m.syncStatus == 'PENDING' && !seen.contains(m.messageUuid)),
            ...remoteList,
          ];
          return merged;
        }
        return remoteList;
      }
    } catch (_) {}

    final local = await PlatformBridge.getLocalMessages(
      status: status,
      direction: direction,
      simSlot: simSlot,
      search: search,
      limit: limit,
      offset: offset,
    );
    return local.map(SmsMessageRecord.fromMap).toList();
  }

  Future<Map<String, dynamic>> getMessageDetails(String messageUuid) async {
    try {
      final res = await _request('GET', '/sms/messages/$messageUuid');
      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    final local = await PlatformBridge.getLocalMessages(search: messageUuid, limit: 1);
    if (local.isNotEmpty) {
      return {'message': local.first, 'events': []};
    }
    throw Exception('Message details not found');
  }

  Future<SmsStatistics> getSmsStatistics({String timeframe = '24h'}) async {
    try {
      final res = await _request('GET', '/sms/statistics?timeframe=$timeframe&device_id=$_deviceId');
      if (res.statusCode == 200) {
        return SmsStatistics.fromMap(json.decode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}

    final localStats = await PlatformBridge.getLocalStats();
    final localEvents = await PlatformBridge.getLocalEvents(limit: 20);
    return SmsStatistics.fromMap({
      ...localStats,
      'recent_events': localEvents,
    });
  }

  // =========================================================================
  // AUTOMATION RULES & TEMPLATES
  // =========================================================================
  Future<List<AutomationRule>> getAutomationRules() async {
    final res = await _request('GET', '/automation/rules');
    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      return items.map((e) => AutomationRule.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    }
    throw Exception('Failed to load automation rules');
  }

  Future<void> saveAutomationRule({
    String? id,
    required Map<String, dynamic> payload,
  }) async {
    final res = id == null
        ? await _request('POST', '/automation/rules', body: json.encode(payload))
        : await _request('PUT', '/automation/rules/$id', body: json.encode(payload));
    if (res.statusCode >= 400) {
      final err = json.decode(res.body);
      throw Exception(err['detail'] ?? 'Failed to save automation rule');
    }
  }

  Future<void> deleteAutomationRule(String id) async {
    final res = await _request('DELETE', '/automation/rules/$id');
    if (res.statusCode >= 400) throw Exception('Failed to delete rule');
  }

  Future<void> duplicateAutomationRule(String id) async {
    final res = await _request('POST', '/automation/rules/$id/duplicate');
    if (res.statusCode >= 400) throw Exception('Failed to duplicate rule');
  }

  Future<Map<String, dynamic>> testAutomationRule(
    String id, {
    String? recipientNumber,
    Map<String, dynamic>? variables,
  }) async {
    final res = await _request(
      'POST',
      '/automation/rules/$id/test',
      body: json.encode({
        'recipient_number': recipientNumber,
        'variables': variables ?? {},
      }),
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) throw Exception(data['detail'] ?? 'Rule test failed');
    return data;
  }

  Future<List<Map<String, dynamic>>> getRuleExecutions(String id) async {
    final res = await _request('GET', '/automation/rules/$id/executions');
    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return (data['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<List<MessageTemplate>> getTemplates() async {
    final res = await _request('GET', '/templates');
    if (res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];
      return items.map((e) => MessageTemplate.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    }
    throw Exception('Failed to load templates');
  }

  Future<void> saveTemplate({String? id, required Map<String, dynamic> payload}) async {
    final res = id == null
        ? await _request('POST', '/templates', body: json.encode(payload))
        : await _request('PUT', '/templates/$id', body: json.encode(payload));
    if (res.statusCode >= 400) {
      final err = json.decode(res.body);
      throw Exception(err['detail'] ?? 'Failed to save template');
    }
  }

  Future<void> deleteTemplate(String id) async {
    final res = await _request('DELETE', '/templates/$id');
    if (res.statusCode >= 400) throw Exception('Failed to delete template');
  }
}
