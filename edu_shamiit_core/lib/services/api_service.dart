import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// API service for communicating with Python FastAPI backend
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = InterceptorClient();
  
  /// Global callback for 401 Unauthorized responses
  void Function()? onUnauthorized;

  /// Get headers with authorization
  Future<Map<String, String>> get _headers async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  final Map<String, dynamic> _cache = {};
  
  /// Clear in-memory cache
  void clearCache() {
    _cache.clear();
  }

  /// GET request
  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, dynamic>? query, bool useCache = true}) async {
    final cacheKey = '$endpoint${query?.toString() ?? ''}';
    
    // Return cached data immediately if available
    if (useCache && _cache.containsKey(cacheKey)) {
      // Fetch in background to update cache (stale-while-revalidate)
      _fetchAndCache(endpoint, query, cacheKey);
      return _cache[cacheKey];
    }

    return _fetchAndCache(endpoint, query, cacheKey);
  }

  Future<Map<String, dynamic>> _fetchAndCache(String endpoint, Map<String, dynamic>? query, String cacheKey) async {
    try {
      var uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      if (query != null && query.isNotEmpty) {
        final Map<String, String> mergedParams = {...uri.queryParameters};
        query.forEach((key, value) {
          if (value != null) {
            mergedParams[key] = value.toString();
          }
        });
        uri = uri.replace(queryParameters: mergedParams);
      }
      final response = await _client
          .get(uri, headers: await _headers)
          .timeout(AppConfig.apiTimeout);
      final data = _handleResponse(response);
      _cache[cacheKey] = data;
      if (_cache.length > 50) {
        _cache.remove(_cache.keys.first);
      }
      return data;
    } catch (e) {
      if (e is ApiException) rethrow;
      if (_cache.containsKey(cacheKey)) return _cache[cacheKey];
      throw ApiException(e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim());
    }
  }

  /// GET raw string (e.g. for CSV/text downloads)
  Future<String> getString(String endpoint, {Map<String, dynamic>? query}) async {
    try {
      var uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      if (query != null && query.isNotEmpty) {
        final Map<String, String> mergedParams = {...uri.queryParameters};
        query.forEach((key, value) {
          if (value != null) {
            mergedParams[key] = value.toString();
          }
        });
        uri = uri.replace(queryParameters: mergedParams);
      }
      final response = await _client
          .get(uri, headers: await _headers)
          .timeout(AppConfig.apiTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      } else if (response.statusCode == 401) {
        onUnauthorized?.call();
        throw ApiException('Unauthorized: Please login again');
      } else {
        throw ApiException('Server returned error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim());
    }
  }

  /// POST request
  Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      final response = await _client
          .post(
            uri,
            headers: await _headers,
            body: jsonEncode(data),
          )
          .timeout(AppConfig.apiTimeout);
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim());
    }
  }

  /// PUT request
  Future<Map<String, dynamic>> put(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      final response = await _client
          .put(
            uri,
            headers: await _headers,
            body: jsonEncode(data),
          )
          .timeout(AppConfig.apiTimeout);
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim());
    }
  }

  /// PATCH request
  Future<Map<String, dynamic>> patch(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      final response = await _client
          .patch(
            uri,
            headers: await _headers,
            body: jsonEncode(data),
          )
          .timeout(AppConfig.apiTimeout);
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim());
    }
  }

  /// DELETE request
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      final response = await _client
          .delete(uri, headers: await _headers)
          .timeout(AppConfig.apiTimeout);
      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim());
    }
  }

  /// Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      } else if (decoded is List) {
        return {'data': decoded, 'items': decoded};
      }
      return {'data': decoded};
    } else if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException('Unauthorized: Please login again');
    } else {
      String errMsg = 'Server error: ${response.statusCode}';
      try {
        if (response.body.isNotEmpty) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded.containsKey('detail')) {
            errMsg = decoded['detail'].toString();
          } else if (decoded is Map && decoded.containsKey('message')) {
            errMsg = decoded['message'].toString();
          }
        }
      } catch (_) {}
      
      if (response.statusCode == 403) {
        throw ApiException(errMsg.startsWith('Server error:') ? 'Forbidden: Access denied' : errMsg);
      } else if (response.statusCode == 404) {
        throw ApiException(errMsg.startsWith('Server error:') ? 'Resource not found' : errMsg);
      } else {
        throw ApiException(errMsg);
      }
    }
  }

  /// Multipart POST — used for file uploads (avatar, documents)
  Future<Map<String, dynamic>> multipartPost(
      String endpoint, File file, String fieldName, {Map<String, String>? fields}) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final request = http.MultipartRequest('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (fields != null) {
        request.fields.addAll(fields);
      }
      request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));

      final streamedResponse =
          await request.send().timeout(AppConfig.apiTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Multipart POST failed: $e');
    }
  }

  /// Multipart POST using bytes — safe for Web and cross-platform
  Future<Map<String, dynamic>> multipartPostBytes(
      String endpoint, List<int> bytes, String filename, String fieldName, {Map<String, String>? fields}) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final request = http.MultipartRequest('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (fields != null) {
        request.fields.addAll(fields);
      }
      request.files.add(http.MultipartFile.fromBytes(fieldName, bytes, filename: filename));

      final streamedResponse = await request.send().timeout(AppConfig.apiTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Multipart POST (bytes) failed: $e');
    }
  }

  /// Health check
  Future<bool> healthCheck() async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/health');
      final response =
          await _client.get(uri).timeout(AppConfig.connectionTimeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// API Exception
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// A custom HTTP client that intercepts 401 Unauthorized responses to trigger logout
class InterceptorClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (response.statusCode == 401) {
      ApiService().onUnauthorized?.call();
    }
    return response;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
