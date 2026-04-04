import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:edu_shamiit_ai/core/config/app_config.dart';
import 'package:edu_shamiit_ai/core/services/supabase_service.dart';

/// API service for communicating with Python FastAPI backend
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();
  
  /// Get headers with authorization
  Map<String, String> get _headers {
    final token = SupabaseService.accessToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// GET request
  Future<Map<String, dynamic>> get(String endpoint, {Map<String, dynamic>? query}) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint').replace(queryParameters: query);
      final response = await _client.get(uri, headers: _headers).timeout(AppConfig.apiTimeout);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('GET request failed: $e');
    }
  }

  /// POST request
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      final response = await _client.post(
        uri,
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(AppConfig.apiTimeout);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('POST request failed: $e');
    }
  }

  /// PUT request
  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      final response = await _client.put(
        uri,
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(AppConfig.apiTimeout);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('PUT request failed: $e');
    }
  }

  /// DELETE request
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
      final response = await _client.delete(uri, headers: _headers).timeout(AppConfig.apiTimeout);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('DELETE request failed: $e');
    }
  }

  /// Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty ? {} : jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
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
      final response = await _client.get(uri).timeout(AppConfig.connectionTimeout);
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