import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

/// Ultra-Fast, Authenticated Client Proxy for the FastAPI GIS Microservice.
///
/// Features:
/// 1. Zero hardcoded API keys on Flutter frontend.
/// 2. Single Source of Truth: Queries FastAPI Backend (`/api/gis/places-on-the-way`).
/// 3. Protected with `ApiService` for automatic JWT Bearer authentication.
/// 4. Bus-Centric Look-Ahead Slicing: Searches near bus location in direction of travel.
/// 5. Supports dynamic look-ahead window expansion & pagination (zoom / further path inspection).
class TomTomService {
  static final TomTomService _instance = TomTomService._internal();
  factory TomTomService() => _instance;
  TomTomService._internal();

  final ApiService _apiService = ApiService();

  /// Search Places on the Way along Route Polyline via Authenticated FastAPI Microservice
  Future<List<Map<String, dynamic>>> searchPlacesOnTheWay({
    required String categoryKey,
    required String queryKeyword,
    required List<LatLng> routePoints,
    required LatLng busLocation,
    double maxRadiusKm = 3.0,
    double offsetKm = 0.0,
    bool aheadOnly = true,
    bool isEmergency = false,
  }) async {
    try {
      final reqBody = {
        'category_key': categoryKey,
        'query_keyword': queryKeyword,
        'route_points': routePoints.map((p) => {'lat': p.latitude, 'lon': p.longitude}).toList(),
        'bus_location': {'lat': busLocation.latitude, 'lon': busLocation.longitude},
        'max_radius_km': maxRadiusKm,
        'offset_km': offsetKm,
        'ahead_only': aheadOnly,
        'is_emergency': isEmergency,
      };

      final data = await _apiService.post('/gis/places-on-the-way', reqBody);
      if (data['success'] == true && data['results'] != null) {
        final results = List<Map<String, dynamic>>.from(data['results']);
        final bool isRedisCached = data['cached'] == true;
        debugPrint("🚀 [Bus-Centric GIS Microservice + Redis] Returned ${results.length} POIs near bus (Cached: $isRedisCached)");
        return results;
      }
    } catch (e) {
      debugPrint("❌ GIS Microservice Error: $e");
    }

    return [];
  }

  /// TomTom Fuzzy Geocoding Search for Location Search bar via Authenticated FastAPI Microservice
  Future<List<Map<String, dynamic>>> fuzzySearch(String query, {LatLng? userLocation}) async {
    if (query.trim().isEmpty) return [];

    try {
      final Map<String, dynamic> params = {'query': query.trim()};
      if (userLocation != null) {
        params['lat'] = userLocation.latitude;
        params['lon'] = userLocation.longitude;
      }

      final data = await _apiService.get('/gis/fuzzy-search', query: params);
      if (data['success'] == true && data['results'] != null) {
        return List<Map<String, dynamic>>.from(data['results']);
      }
    } catch (e) {
      debugPrint("❌ GIS Fuzzy Search Microservice Error: $e");
    }

    return [];
  }
}
