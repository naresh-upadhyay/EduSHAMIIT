import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_ai/core/config/app_config.dart';

/// API service for communicating with Python FastAPI backend
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();
  
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
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint')
          .replace(queryParameters: query);
      final response = await _client
          .get(uri, headers: await _headers)
          .timeout(AppConfig.apiTimeout);
      final data = _handleResponse(response);
      _cache[cacheKey] = data;
      return data;
    } catch (e) {
      if (_cache.containsKey(cacheKey)) return _cache[cacheKey];
      throw ApiException('GET request failed: $e');
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
      throw ApiException('POST request failed: $e');
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
      throw ApiException('PUT request failed: $e');
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
      throw ApiException('DELETE request failed: $e');
    }
  }

  /// Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty
          ? {}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException('Unauthorized: Please login again');
    } else if (response.statusCode == 403) {
      throw ApiException('Forbidden: Access denied');
    } else if (response.statusCode == 404) {
      throw ApiException('Resource not found');
    } else {
      throw ApiException('Server error: ${response.statusCode}');
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
  String toString() => 'ApiException: $message';
}
