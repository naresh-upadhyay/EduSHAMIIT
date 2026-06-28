import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for offline caching of API data
/// Provides local storage with TTL (Time To Live) support
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  late SharedPreferences _prefs;

  /// Initialize the cache service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get a cached value by key
  /// Returns null if not found or expired
  T? get<T>(String key, {T? defaultValue}) {
    final data = _prefs.getString(key);
    if (data == null) return defaultValue;

    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      final expiry = decoded['expiry'] as int?;
      
      if (expiry != null && DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(expiry))) {
        // Cache expired
        _prefs.remove(key);
        return defaultValue;
      }

      return decoded['data'] as T? ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Set a cached value with optional TTL
  /// [ttlMinutes] - Time to live in minutes (default: 30 minutes)
  Future<bool> set<T>(String key, T value, {int ttlMinutes = 30}) async {
    try {
      final expiry = DateTime.now().add(Duration(minutes: ttlMinutes)).millisecondsSinceEpoch;
      final data = jsonEncode({
        'data': value,
        'expiry': expiry,
        'cachedAt': DateTime.now().toIso8601String(),
      });
      return await _prefs.setString(key, data);
    } catch (e) {
      return false;
    }
  }

  /// Remove a cached value
  Future<bool> remove(String key) async {
    return await _prefs.remove(key);
  }

  /// Clear all cached data
  Future<bool> clear() async {
    return await _prefs.clear();
  }

  /// Check if a key exists and is not expired
  bool exists(String key) {
    return get(key) != null;
  }

  /// Get all cache keys
  List<String> getKeys() {
    return _prefs.getKeys().toList();
  }

  /// Get cached data with metadata
  Map<String, dynamic>? getWithMetadata(String key) {
    final data = _prefs.getString(key);
    if (data == null) return null;

    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Check if cached data is stale (approaching expiry)
  bool isStale(String key, {int staleMinutes = 5}) {
    final metadata = getWithMetadata(key);
    if (metadata == null) return false;

    final expiry = metadata['expiry'] as int?;
    if (expiry == null) return false;

    final staleThreshold = DateTime.now().add(Duration(minutes: staleMinutes)).millisecondsSinceEpoch;
    return expiry < staleThreshold;
  }

  /// Refresh cache by updating expiry time
  Future<bool> refreshExpiry(String key, {int ttlMinutes = 30}) async {
    final data = getWithMetadata(key);
    if (data == null) return false;

    final value = data['data'];
    return await set(key, value, ttlMinutes: ttlMinutes);
  }
}

/// Cache keys for different data types
class CacheKeys {
  static const String attendance = 'cache_attendance';
  static const String leaveApplications = 'cache_leave_applications';
  static const String libraryData = 'cache_library_data';
  static const String notifications = 'cache_notifications';
  static const String leaderboard = 'cache_leaderboard';
  static const String messages = 'cache_messages';
  static const String exams = 'cache_exams';
  static const String userProfile = 'cache_user_profile';
  static const String courses = 'cache_courses';
  static const String liveClasses = 'cache_live_classes';
  static const String settings = 'cache_settings';
}

/// TTL configurations for different data types
class CacheTTL {
  static const int attendance = 15; // 15 minutes
  static const int leaveApplications = 30; // 30 minutes
  static const int libraryData = 60; // 1 hour
  static const int notifications = 5; // 5 minutes
  static const int leaderboard = 30; // 30 minutes
  static const int messages = 15; // 15 minutes
  static const int exams = 60; // 1 hour
  static const int userProfile = 300; // 5 hours
  static const int courses = 120; // 2 hours
  static const int liveClasses = 10; // 10 minutes
  static const int settings = 300; // 5 hours
}