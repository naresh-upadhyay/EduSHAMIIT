import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../../services/tomtom_service.dart';

class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  ConsumerState<DriverDashboardScreen> createState() =>
      _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends ConsumerState<DriverDashboardScreen>
    with SingleTickerProviderStateMixin {
  final bool _isLoading = false;
  bool _isInitialLoading = true;
  List<dynamic> _routes = [];
  Map<String, dynamic>? _activeTrip;
  Map<String, dynamic>? _tripState;
  String? _selectedRouteId;

  // State lists (loaded from DB, falls back to rich sample data)
  List<Map<String, dynamic>> _stops = [];
  List<Map<String, dynamic>> _students = [];

  // Telemetry controls
  bool _isTripActive = false;
  bool _isTripPaused = false;
  bool _emergencyAlertActive = false;
  bool _deviationAlertActive = false;

  Map<String, dynamic>? _selectedRoute;
  String _registrationNo = "";
  String _busNumber = "";
  String _startTime = "";
  String _currentLocationName = "Waiting";
  String _nextStopName = "None Scheduled";

  double _totalDistanceKm = 0.0;
  double _coveredDistanceKm = 0.0;
  int _elapsedMinutes = 0;
  int _totalTimeMinutes = 0;

  // Selected stop index for checklist updating (Right side card)
  int _selectedStopIndexForChecklist = 4;

  // Tab controllers & pointers
  late TabController _studentTabController;
  int _activeStopTab = 0; // 0 = All, 1 = Upcoming, 2 = Completed
  int _currentStopIndex = 4; // default Noida Sector 71 Crossing
  int _expandedStopIndex = 4;

  // Map settings
  String _mapType = "Satellite"; // Satellite by default, Standard, Terrain
  bool _showTraffic = true;
  double _zoomLevel = 13.5;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  bool _showMapTypeMenu = false;
  bool _showPoiFilterMenu = false;
  bool _hideMapControls = false;
  bool _hideBottomControls = false;

  // Custom Map Destination Selection & Locking
  LatLng? _selectedDestinationLatLng;
  String _selectedDestinationName = "";
  double _selectedDestinationDistanceKm = 0.0;
  int _selectedDestinationDurationMins = 0;
  bool _isCustomDestinationLocked = false;
  bool _isGeocodingSelectedPoint = false;
  bool _enableClickToSetDestination = false; // Toggle to prevent unwanted map clicks



  // Timer for GPS simulation
  Timer? _telemetryTimer;
  double _busPositionRatio = 0.38;
  List<LatLng> _routePoints = [];

  // Bulk selection maps
  final Map<String, bool> _selectedStudents = {};

  // ─── DASHBOARD STATE ───────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _studentTabController = TabController(length: 3, vsync: this);
    _studentTabController.addListener(() {
      if (mounted) {
        setState(() {
          _selectedStudents.clear();
        });
      }
    });

    // Start with empty data — will be populated from DB by _initializeDashboard
    _stops = [];
    _students = [];
    _routePoints = [];
    _selectedStopIndexForChecklist = 0;
    _currentStopIndex = 0;
    _expandedStopIndex = 0;
    _isInitialLoading = true;

    _initializeDashboard();
    _requestDeviceLocationPermission();
  }

  @override
  void dispose() {
    _gpsPositionSubscription?.cancel();
    _searchDebounce?.cancel();
    _telemetryTimer?.cancel();
    _studentTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? _lastLoadedTripId;
  String? _lastLoadedRouteId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    String? currentTripId;
    String? currentRouteId;
    try {
      final baseUri = Uri.base;
      currentTripId = baseUri.queryParameters['trip_id'];
      currentRouteId = baseUri.queryParameters['route_id'];
    } catch (_) {}

    if (currentTripId == null || currentTripId.isEmpty) {
      try {
        final uri = GoRouterState.of(context).uri;
        currentTripId = uri.queryParameters['trip_id'];
        currentRouteId = uri.queryParameters['route_id'];
      } catch (_) {}
    }

    if ((currentTripId != null && currentTripId.isNotEmpty && currentTripId != _lastLoadedTripId) ||
        (currentRouteId != null && currentRouteId.isNotEmpty && currentRouteId != _lastLoadedRouteId)) {
      _lastLoadedTripId = currentTripId;
      _lastLoadedRouteId = currentRouteId;
      debugPrint("[DRIVER_DASH] URL parameters changed: trip_id=$currentTripId, route_id=$currentRouteId. Triggering _initializeDashboard...");
      _initializeDashboard();
    }
  }

  // ─── INITIALIZATION & SYNC ──────────────────────────────────────────────

  Future<void> _initializeDashboard() async {
    debugPrint("[DRIVER_DASH] _initializeDashboard: Starting...");

    String? urlTripId;
    String? urlRouteId;
    try {
      final baseUri = Uri.base;
      urlTripId = baseUri.queryParameters['trip_id'];
      urlRouteId = baseUri.queryParameters['route_id'];
    } catch (_) {}

    if (urlTripId == null || urlTripId.isEmpty) {
      try {
        final uri = GoRouterState.of(context).uri;
        urlTripId = uri.queryParameters['trip_id'];
        urlRouteId = uri.queryParameters['route_id'];
      } catch (_) {}
    }

    _lastLoadedTripId = urlTripId;
    _lastLoadedRouteId = urlRouteId;

    debugPrint("[DRIVER_DASH] Found URL parameters: trip_id=$urlTripId, route_id=$urlRouteId");

    // 1. Fetch driver routes
    try {
      final routesRes = await ApiService().get('/transport/driver/routes', useCache: false);
      if (routesRes['success'] == true && routesRes['data'] != null) {
        _routes = routesRes['data'] ?? [];
      }
    } catch (e) {
      debugPrint("[DRIVER_DASH] Routes fetch failed: $e");
    }

    // 2. Resolve target route if urlRouteId specified
    Map<String, dynamic>? targetRoute;
    if (_routes.isNotEmpty) {
      if (urlRouteId != null && urlRouteId.isNotEmpty) {
        targetRoute = _routes.firstWhere(
          (r) => r['id']?.toString() == urlRouteId,
          orElse: () => _routes[0],
        );
      } else {
        final assigned = _routes.where((r) => r['is_assigned'] == true).toList();
        targetRoute = assigned.isNotEmpty ? assigned[0] : _routes[0];
      }
    }

    // 3. Load Trip State
    if (urlTripId != null && urlTripId.isNotEmpty) {
      // Direct deep-link from Calendar Scheduled Trip
      try {
        debugPrint("[DRIVER_DASH] Loading trip state from URL: trip_id=$urlTripId");
        await _loadTripState(urlTripId);
      } catch (e) {
        debugPrint("[DRIVER_DASH] Error loading deep-linked trip: $e");
      }
    } else {
      // By default: Fetch next upcoming scheduled trip on calendar for this driver!
      bool loadedUpcoming = false;
      try {
        final upcomingRes = await ApiService().get('/transport/driver/trips/upcoming', useCache: false);
        if (upcomingRes['success'] == true && upcomingRes['data'] != null) {
          final data = upcomingRes['data'];
          if (data['trip'] != null && data['trip']['id'] != null) {
            await _loadTripState(data['trip']['id'].toString());
            loadedUpcoming = true;
          }
        }
      } catch (e) {
        debugPrint("[DRIVER_DASH] Error fetching upcoming trip: $e");
      }

      // Robust fallback on frontend matching Calendar "Assigned to Me" criteria:
      if (!loadedUpcoming) {
        try {
          final now = DateTime.now();
          final schedRes = await ApiService().get('/schedules', query: {
            'assigned_to_me': 'true',
            'limit': 50,
          }, useCache: false);

          if (schedRes['success'] == true && schedRes['data'] is List) {
            final list = (schedRes['data'] as List).whereType<Map<String, dynamic>>().toList();
            final assignedUpcoming = list.where((s) {
              DateTime? st;
              DateTime? et;
              if (s['start_time'] != null) st = DateTime.tryParse(s['start_time'].toString());
              if (s['end_time'] != null) et = DateTime.tryParse(s['end_time'].toString());
              st = st?.toLocal();
              et = et?.toLocal();

              final isFutureOrCurrent = (et != null && et.isAfter(now)) || (st != null && st.isAfter(now));
              final status = s['status']?.toString().toLowerCase();
              final isNotDone = status != 'completed' && status != 'cancelled';
              return isFutureOrCurrent && isNotDone;
            }).toList();

            if (assignedUpcoming.isNotEmpty) {
              assignedUpcoming.sort((a, b) {
                final stA = DateTime.tryParse(a['start_time']?.toString() ?? '') ?? DateTime.now();
                final stB = DateTime.tryParse(b['start_time']?.toString() ?? '') ?? DateTime.now();
                return stA.compareTo(stB);
              });

              final firstUpcoming = assignedUpcoming.first;
              final targetTripId = firstUpcoming['trip_id']?.toString() ?? firstUpcoming['id']?.toString();
              if (targetTripId != null && targetTripId.isNotEmpty) {
                debugPrint("[DRIVER_DASH] Loaded default upcoming trip from assigned-to-me calendar schedule: $targetTripId");
                await _loadTripState(targetTripId);
                loadedUpcoming = true;
              }
            }
          }
        } catch (e) {
          debugPrint("[DRIVER_DASH] Fallback assigned-to-me check notice: $e");
        }
      }

      if (!loadedUpcoming) {
        await _checkActiveTrip();
        if (_activeTrip == null) {
          // No active trip and no upcoming scheduled trip from DB -> show Waiting state
          _selectedRoute = null;
          _selectedRouteId = null;
          _stops = [];
          _students = [];
          _routePoints = [];
          _registrationNo = "";
          _busNumber = "";
          _startTime = "";
          _currentLocationName = "Waiting";
          _nextStopName = "None Scheduled";
          _totalDistanceKm = 0.0;
          _totalTimeMinutes = 0;
        }
      }
    }

    // Final state update
    if (!mounted) return;
    setState(() {
      _isInitialLoading = false;
    });
  }

  Future<Map<String, dynamic>?> _ensureActiveTrip() async {
    if (_activeTrip != null) return _activeTrip;

    debugPrint("[DRIVER_DASH] _ensureActiveTrip: _activeTrip is null. Starting/Creating trip automatically...");
    await _startTrip();
    return _activeTrip;
  }

  Future<void> _checkActiveTrip() async {
    try {
      debugPrint("[DRIVER_DASH] _checkActiveTrip: Fetching active trip...");
      final activeRes = await ApiService()
          .get('/transport/driver/trips/active', useCache: false);
      debugPrint(
          "[DRIVER_DASH] _checkActiveTrip: Response = ${'success=${activeRes['success']}, hasData=${activeRes['data'] != null}'}");
      if (activeRes['success'] == true && activeRes['data'] != null) {
        final tripData = activeRes['data']['trip'] ?? activeRes['data'];
        if (tripData != null && tripData['id'] != null) {
          await _loadTripState(tripData['id'].toString());
          if (!_isTripPaused && _isTripActive) {
            _startTelemetryBroadcasting();
          }
        }
      } else {
        debugPrint(
            "[DRIVER_DASH] _checkActiveTrip: No active trip found");
      }
    } catch (e, st) {
      debugPrint("[DRIVER_DASH] Error checking active trip: $e");
      debugPrint("[DRIVER_DASH] Stack: $st");
    }
  }

  Future<void> _loadTripState(String tripId) async {
    try {
      debugPrint(
          "[DRIVER_DASH] _loadTripState: Fetching state for trip $tripId...");
      final stateRes = await ApiService()
          .get('/transport/driver/trips/$tripId/state', useCache: false);
      debugPrint(
          "[DRIVER_DASH] _loadTripState: Response = ${'success=${stateRes['success']}'}");
      if (stateRes['success'] == true && stateRes['data'] != null) {
        final data = stateRes['data'];
        final stopsFromDb = data['stops'] as List<dynamic>? ?? [];
        final studentsFromDb = data['students'] as List<dynamic>? ?? [];
        final tripData = data['trip'] as Map<String, dynamic>?;
        final routeData = data['route'] as Map<String, dynamic>?;

        debugPrint(
            "[DRIVER_DASH] _loadTripState: Got ${stopsFromDb.length} stops, ${studentsFromDb.length} students from DB");

        setState(() {
          _tripState = data;
          _activeTrip = tripData;
          int? savedStopIdx;

          if (routeData != null && routeData.isNotEmpty) {
            _selectedRoute = routeData;
            _selectedRouteId = routeData['id']?.toString() ?? _selectedRouteId;
            final busLabel = routeData['registration_no'] ?? routeData['bus_number'] ?? routeData['assigned_bus'] ?? tripData?['registration_no'] ?? 'UP18181';
            _registrationNo = busLabel.toString();
            _busNumber = busLabel.toString();
            _startTime = routeData['start_time']?.toString() ?? '08:00 AM';
            _totalDistanceKm = (routeData['distance_km'] as num?)?.toDouble() ?? 55.13;
            _totalTimeMinutes = (routeData['travel_time_mins'] as num?)?.toInt() ?? 52;
          }

          if (_activeTrip != null) {
            final tripStatus = (_activeTrip!['status'] as String?)?.toLowerCase() ?? 'scheduled';
            final bool allStopsCompleted = stopsFromDb.isNotEmpty && stopsFromDb.every((s) => s['status'] == 'completed');
            final bool isTripDone = (tripStatus == 'completed') || allStopsCompleted;

            _isTripActive = (tripStatus == 'in_progress' || tripStatus == 'paused') && !isTripDone;
            _isTripPaused = (tripStatus == 'paused') && !isTripDone;
            if (isTripDone && _activeTrip != null) {
              _activeTrip!['status'] = 'completed';
            }

            final savedRatio = (_activeTrip!['bus_position_ratio'] as num?)?.toDouble();
            savedStopIdx = (_activeTrip!['current_stop_index'] as num?)?.toInt();
            final savedElapsedSecs = (_activeTrip!['elapsed_seconds'] as num?)?.toInt();
            final savedDist = (_activeTrip!['distance_km'] as num?)?.toDouble();

            if (savedRatio != null && savedRatio > 0) {
              _busPositionRatio = savedRatio;
            }
            if (savedStopIdx != null && savedStopIdx >= 0 && savedStopIdx < stopsFromDb.length) {
              _currentStopIndex = savedStopIdx;
              _selectedStopIndexForChecklist = savedStopIdx;
              _expandedStopIndex = savedStopIdx;
            }
            if (savedElapsedSecs != null && savedElapsedSecs > 0) {
              _elapsedMinutes = (savedElapsedSecs / 60).round();
            }
            if (savedDist != null && savedDist > 0) {
              _coveredDistanceKm = savedDist;
            }
          }

          final bool hasSavedStopIndex = (savedStopIdx != null && savedStopIdx >= 0);

          _stops = stopsFromDb.map((s) => Map<String, dynamic>.from(s)).toList();
          _students = studentsFromDb.map((s) => Map<String, dynamic>.from(s)).toList();

          // Ensure every student has a valid stop_id in _stops
          if (_stops.isNotEmpty && _students.isNotEmpty) {
            for (int i = 0; i < _students.length; i++) {
              final st = _students[i];
              final bool hasValidStop = _stops.any((sp) => sp['id'] == st['stop_id']);
              if (!hasValidStop) {
                st['stop_id'] = _stops[i % _stops.length]['id'];
              }
            }
          }

          final stopCoords = _stops.map((s) {
            final lat = (s['latitude'] as num?)?.toDouble() ?? 28.6280;
            final lng = (s['longitude'] as num?)?.toDouble() ?? 77.3780;
            return LatLng(lat, lng);
          }).toList();

          _routePoints = stopCoords;
          if (!hasSavedStopIndex) {
            _syncCurrentStopIndex();
          } else {
            if (_stops.isNotEmpty && _currentStopIndex < _stops.length) {
              _currentLocationName = _stops[_currentStopIndex]['stop_name'] ?? "";
              if (_currentStopIndex + 1 < _stops.length) {
                _nextStopName = _stops[_currentStopIndex + 1]['stop_name'] ?? "";
              } else {
                _nextStopName = "School Depot";
              }
            }
          }
          _syncSelectedMap();
        });

        _loadOSRMRouteForStops();
      }
    } catch (e, st) {
      debugPrint("[DRIVER_DASH] Error loading trip state: $e");
      debugPrint("[DRIVER_DASH] Stack: $st");
    }
  }

  static final Map<String, List<LatLng>> _localPolylineCache = {};

  Future<List<LatLng>> _fetchOSMRoutePoints(List<LatLng> stopCoords) async {
    if (stopCoords.length < 2) return stopCoords;
    final coordsString = stopCoords.map((c) => '${c.longitude},${c.latitude}').join(';');
    final cacheKey = coordsString;

    // 1. Memory Cache
    if (_localPolylineCache.containsKey(cacheKey) && _localPolylineCache[cacheKey]!.length > 5) {
      return _localPolylineCache[cacheKey]!;
    }

    // 2. FastAPI GIS Backend Proxy (uses Redis 24h caching + fallback mirrors)
    try {
      final res = await ApiService().get('/gis/route-geometry', query: {'waypoints': coordsString});
      if (res['success'] == true && res['coordinates'] != null) {
        final coordsList = res['coordinates'] as List;
        if (coordsList.length > 5) {
          final points = coordsList.map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
          _localPolylineCache[cacheKey] = points;
          return points;
        }
      }
    } catch (e) {
      debugPrint('[Backend GIS Route Geometry] Notice: $e');
    }

    // 3. Direct OSRM Provider Mirrors
    for (final host in [
      'https://router.project-osrm.org',
      'https://routing.openstreetmap.de/routed-car'
    ]) {
      try {
        final url = '$host/route/v1/driving/$coordsString?overview=full&geometries=geojson';
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
          final points = coordinates.map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
          if (points.length > 5) {
            _localPolylineCache[cacheKey] = points;
            return points;
          }
        }
      } catch (e) {
        debugPrint('[OSRM Mirror] $host notice: $e');
      }
    }

    // 4. Stale Cache Fallback
    if (_localPolylineCache.containsKey(cacheKey)) {
      return _localPolylineCache[cacheKey]!;
    }

    return stopCoords;
  }

  Future<void> _loadOSRMRouteForStops() async {
    if (_stops.length < 2) return;
    final stopCoords = _stops.map((s) {
      final lat = (s['latitude'] as num?)?.toDouble() ?? 28.6280;
      final lng = (s['longitude'] as num?)?.toDouble() ?? 77.3780;
      return LatLng(lat, lng);
    }).toList();

    final osmPoints = await _fetchOSMRoutePoints(stopCoords);
    if (mounted) {
      setState(() {
        _routePoints = osmPoints;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitMapToAllStopsAndRoute();
      });
    }
  }

  void _fitMapToAllStopsAndRoute() {
    if (_stops.isEmpty && _routePoints.isEmpty) return;

    final points = <LatLng>[];
    for (final s in _stops) {
      final lat = (s['latitude'] as num?)?.toDouble();
      final lng = (s['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }
    if (_routePoints.isNotEmpty) {
      points.addAll(_routePoints);
    } else {
      points.add(_getBusLocation());
    }

    if (points.isEmpty) return;

    double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final maxSpan = math.max(latSpan, lngSpan);

    double zoom = 13.0;
    if (maxSpan > 0.5) {
      zoom = 10.0;
    } else if (maxSpan > 0.2) {
      zoom = 11.5;
    } else if (maxSpan > 0.1) {
      zoom = 12.5;
    } else if (maxSpan > 0.05) {
      zoom = 13.5;
    } else {
      zoom = 14.5;
    }

    try {
      _mapController.move(LatLng(centerLat, centerLng), zoom);
    } catch (_) {}
  }

  void _syncCurrentStopIndex() {
    _currentStopIndex = 0;
    for (int i = 0; i < _stops.length; i++) {
      if (_stops[i]['status'] == 'pending') {
        _currentStopIndex = i;
        break;
      }
      if (i == _stops.length - 1) {
        _currentStopIndex = i;
      }
    }
    _expandedStopIndex = _currentStopIndex;
    _selectedStopIndexForChecklist = _currentStopIndex;

    if (_stops.isNotEmpty) {
      _currentLocationName = _stops[_currentStopIndex]['stop_name'] ?? "";
      if (_currentStopIndex + 1 < _stops.length) {
        _nextStopName = _stops[_currentStopIndex + 1]['stop_name'] ?? "";
      } else {
        _nextStopName = "School Depot";
      }
    }
  }

  void _syncSelectedMap() {
    _selectedStudents.clear();
    if (_stops.isEmpty) return;
    final currentStudents = _getStudentsAtSelectedStop();
    for (var s in currentStudents) {
      _selectedStudents[s['id']] = true;
    }
  }

  Future<void> _persistTripProgress() async {
    if (_activeTrip == null) return;
    try {
      final busLoc = _getBusLocation();
      final totalStopsCount = _stops.isNotEmpty ? _stops.length : 1;
      final calcRatio = (_currentStopIndex / totalStopsCount).clamp(0.0, 1.0);
      _busPositionRatio = calcRatio;

      final payload = {
        "latitude": busLoc.latitude,
        "longitude": busLoc.longitude,
        "speed": _currentSpeedKmh > 0 ? _currentSpeedKmh : 35.5,
        "heading": _vehicleHeading,
        "accuracy_m": 5.0,
        "live_status": _isTripPaused ? "paused" : "on_route",
        "students_on_board": _getOnBoardCount(),
        "bus_position_ratio": _busPositionRatio,
        "current_stop_index": _currentStopIndex,
        "elapsed_seconds": _elapsedMinutes * 60,
        "distance_km": _coveredDistanceKm,
      };

      await ApiService().post(
          '/transport/driver/trips/${_activeTrip!['id']}/location',
          payload);
      debugPrint(
          "[DRIVER_DASH] _persistTripProgress: Persisted progress to DB (stop_index=$_currentStopIndex, ratio=$_busPositionRatio)");
    } catch (e) {
      debugPrint("[DRIVER_DASH] Error persisting trip progress: $e");
    }
  }

  void _startTelemetryBroadcasting() {
    _telemetryTimer?.cancel();
    _telemetryTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted || !_isTripActive || _isTripPaused) {
        timer.cancel();
        return;
      }

      try {
        final busLoc = _getBusLocation();
        final payload = {
          "latitude": busLoc.latitude,
          "longitude": busLoc.longitude,
          "speed": _currentSpeedKmh > 0 ? _currentSpeedKmh : 35.5,
          "heading": _vehicleHeading,
          "accuracy_m": 5.0,
          "live_status": _isTripPaused ? "paused" : "on_route",
          "students_on_board": _getOnBoardCount(),
          "bus_position_ratio": _busPositionRatio,
          "current_stop_index": _currentStopIndex,
          "elapsed_seconds": _elapsedMinutes * 60,
          "distance_km": _coveredDistanceKm,
        };

        if (_activeTrip != null) {
          await ApiService().post(
              '/transport/driver/trips/${_activeTrip!['id']}/location',
              payload);
        }

        setState(() {
          _busPositionRatio = (_currentStopIndex / (_routePoints.isNotEmpty ? _routePoints.length : 1)) + 0.03;
          if (_busPositionRatio > 1.0) _busPositionRatio = 0.0;
        });
      } catch (e) {
        debugPrint("Error sending location telemetry: $e");
      }
    });
  }

  LatLng _getBusLocation() {
    if (_routePoints.isEmpty) return const LatLng(28.6280, 77.3780);
    if (_routePoints.length == 1) return _routePoints.first;

    final totalSegments = _routePoints.length - 1;
    final currentSegmentFloat = _busPositionRatio * totalSegments;
    final currentSegmentIndex =
        currentSegmentFloat.floor().clamp(0, totalSegments - 1);
    final segmentRatio = currentSegmentFloat - currentSegmentIndex;

    final p1 = _routePoints[currentSegmentIndex];
    final p2 = _routePoints[currentSegmentIndex + 1];

    final lat = p1.latitude + (p2.latitude - p1.latitude) * segmentRatio;
    final lng = p1.longitude + (p2.longitude - p1.longitude) * segmentRatio;

    // Auto-calculate Navigation Compass Bearing (0° - 360° True North)
    final double deltaLat = p2.latitude - p1.latitude;
    final double deltaLng = (p2.longitude - p1.longitude) * math.cos(p1.latitude * math.pi / 180.0);
    if (deltaLat != 0 || deltaLng != 0) {
      _vehicleHeading = (math.atan2(deltaLng, deltaLat) * 180.0 / math.pi + 360.0) % 360.0;
    }

    return LatLng(lat, lng);
  }

  String _getMapTileUrl() {
    if (_mapType == "Satellite") {
      return "https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}";
    } else if (_mapType == "Terrain") {
      return "https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png";
    }
    return "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
  }

  // Real GPS & Sensor Telemetry State
  double _currentSpeedKmh = 0.0;
  double _vehicleHeading = 0.0;
  bool _isAutoRerouting = false;
  bool _hasLocationPermission = false;
  bool _isRequestingPermission = false;
  StreamSubscription<Position>? _gpsPositionSubscription;
  LatLng? _lastGpsPosition;
  DateTime? _lastGpsTimestamp;

  void _requestDeviceLocationPermission() async {
    if (_isRequestingPermission) return;
    _isRequestingPermission = true;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ Device GPS Location Service is turned OFF. Please enable location."),
              backgroundColor: Color(0xFFF59E0B),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        setState(() {
          _hasLocationPermission = true;
        });
        _startRealGpsSpeedometer();
      } else if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showPermissionDeniedDialog();
        }
      }
    } catch (e) {
      debugPrint("Location permission request error: $e");
    } finally {
      _isRequestingPermission = false;
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_disabled, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text("GPS Location Required", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "EduSHAMIIT Driver App requires device location and compass access to track your bus in real-time and orient map navigation.",
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Dismiss", style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
            child: const Text("Open Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _startRealGpsSpeedometer() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      _gpsPositionSubscription?.cancel();
      _gpsPositionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1, // update on 1 meter movement
        ),
      ).listen((Position position) {
        if (!mounted) return;

        double calculatedSpeed = 0.0;
        // Priority 1: Hardware GPS sensor Doppler velocity (m/s)
        if (position.speed > 0) {
          calculatedSpeed = position.speed * 3.6;
        } else if (_lastGpsPosition != null && _lastGpsTimestamp != null) {
          // Priority 2: Real distance (m) over time delta (s) calculation
          final distanceMeters = Geolocator.distanceBetween(
            _lastGpsPosition!.latitude,
            _lastGpsPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          final seconds =
              position.timestamp.difference(_lastGpsTimestamp!).inMilliseconds /
                  1000.0;
          if (seconds > 0.3) {
            calculatedSpeed = (distanceMeters / seconds) * 3.6;
          }
        }

        // Noise filter threshold (under 0.8 km/h is stationary 0 km/h)
        if (calculatedSpeed < 0.8) {
          calculatedSpeed = 0.0;
        }

        // Real Heading calculation
        double heading = position.heading;
        if ((heading == 0 || heading.isNaN) && _lastGpsPosition != null) {
          heading = Geolocator.bearingBetween(
            _lastGpsPosition!.latitude,
            _lastGpsPosition!.longitude,
            position.latitude,
            position.longitude,
          );
        }

        _lastGpsPosition = LatLng(position.latitude, position.longitude);
        _lastGpsTimestamp = position.timestamp;

        setState(() {
          _currentSpeedKmh = double.parse(calculatedSpeed.toStringAsFixed(1));
          if (!heading.isNaN && heading != 0) {
            _vehicleHeading = double.parse(heading.toStringAsFixed(1));
          }
        });

        _checkRouteDeviationAndReroute();
      });
    } catch (e) {
      debugPrint("[SPEEDOMETER] GPS stream setup error: $e");
    }
  }

  void _checkRouteDeviationAndReroute() {
    if (!_isNavigating || _searchedMarkerLoc == null || _isAutoRerouting)
      return;
    if (_navigationPolylinePoints.isEmpty) return;

    final busLoc = _getBusLocation();

    // Find min distance to any point on current polyline
    double minDistanceMeters = double.infinity;
    for (final p in _navigationPolylinePoints) {
      final dist = _calculateDistanceKm(
              busLoc.latitude, busLoc.longitude, p.latitude, p.longitude) *
          1000.0;
      if (dist < minDistanceMeters) {
        minDistanceMeters = dist;
      }
    }

    // If vehicle is > 120 meters off the active route polyline, recalculate optimal path!
    if (minDistanceMeters > 120.0) {
      _recalculateOptimizedRoute(busLoc, _searchedMarkerLoc!);
    }
  }

  Future<void> _recalculateOptimizedRoute(
      LatLng currentPos, LatLng destPos) async {
    if (_isAutoRerouting) return;

    setState(() {
      _isAutoRerouting = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 10),
              Text("Route deviation detected! Recalculating optimal route..."),
            ],
          ),
          backgroundColor: Color(0xFF2563EB),
          duration: Duration(seconds: 3),
        ),
      );
    }

    try {
      final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
          '${currentPos.longitude},${currentPos.latitude};'
          '${destPos.longitude},${destPos.latitude}'
          '?overview=full&geometries=geojson');

      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final distanceMeters = (route['distance'] as num).toDouble();
          final durationSecs = (route['duration'] as num).toDouble();
          final coords = route['geometry']['coordinates'] as List<dynamic>;

          final List<LatLng> newPolyline = coords.map<LatLng>((c) {
            return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();

          setState(() {
            _navigationPolylinePoints = newPolyline;
            _navDistanceKm =
                double.parse((distanceMeters / 1000.0).toStringAsFixed(1));
            _navDurationMins = (durationSecs / 60.0).round();
            _isAutoRerouting = false;
            _deviationAlertActive = true;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Auto reroute error: $e");
    }

    setState(() {
      _isAutoRerouting = false;
    });
  }

  Widget _buildSpeedometerHud() {
    final double currentSpeed = _isTripActive ? (_isTripPaused ? 0.0 : _currentSpeedKmh) : 0.0;
    final String speedText = currentSpeed > 0 ? "${currentSpeed.round()} km/h" : "0 km/h";
    final String statusText = currentSpeed > 0 ? "Live Speed" : "Vehicle Stopped";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: currentSpeed > 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            "$speedText • $statusText",
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  LatLng? _searchedMarkerLoc;
  String _searchedLocationName = "";
  bool _isSearchingLocation = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _searchDebounce;
  bool _showDestinationCard = false;

  // Real OSRM Navigation State
  bool _isCalculatingRoute = false;
  bool _isNavigating = false;
  List<LatLng> _navigationPolylinePoints = [];
  double _navDistanceKm = 0.0;
  int _navDurationMins = 0;

  // POI Places on the Way State
  String? _activePoiCategory;
  List<Map<String, dynamic>> _poiMarkersData = [];
  double _searchCorridorRadiusKm = 2.5;
  bool _isEmergencySearchMode = false;

  // Multi-Route Navigation & Auto-Follow State
  List<List<LatLng>> _navigationRoutePaths = [];
  List<Map<String, dynamic>> _navigationRouteInfos = [];
  int _selectedRouteIndex = 0;
  bool _isAutoFollowVehicle = true;

  // ─── CLICK MAP TO SET & LOCK DESTINATION (REAL OSRM ROAD ROUTE) ─────────
  Future<void> _fetchRoadRouteToDestination(LatLng destination) async {
    final busLoc = _getBusLocation();

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${busLoc.longitude},${busLoc.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&alternatives=true'
      );

      final res = await http.get(url).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final routes = data['routes'] as List? ?? [];
        if (routes.isNotEmpty) {
          final List<List<LatLng>> routePaths = [];
          final List<Map<String, dynamic>> routeInfos = [];

          for (int i = 0; i < routes.length; i++) {
            final route = routes[i];
            final distMeters = (route['distance'] as num).toDouble();
            final durSecs = (route['duration'] as num).toDouble();
            final coords = route['geometry']['coordinates'] as List<dynamic>;

            final polyline = coords.map<LatLng>((c) {
              return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
            }).toList();

            final distKm = double.parse((distMeters / 1000.0).toStringAsFixed(1));
            final durMins = (durSecs / 60.0).round();

            routePaths.add(polyline);
            routeInfos.add({
              'label': i == 0 ? '⚡ Fastest Route' : (i == 1 ? '🌿 Shortest Path' : '🛣️ Alt Route $i'),
              'distance_km': distKm,
              'duration_mins': durMins,
              'summary': (route['legs'] is List && (route['legs'] as List).isNotEmpty) ? (route['legs'][0]['summary'] ?? (i == 0 ? 'Via Highway' : 'Via Local Corridor')) : (i == 0 ? 'Via Highway' : 'Via Local Corridor'),
            });
          }

          if (mounted) {
            setState(() {
              _navigationRoutePaths = routePaths;
              _navigationRouteInfos = routeInfos;
              _selectedRouteIndex = 0;
              if (routePaths.isNotEmpty && routeInfos.isNotEmpty) {
                _navigationPolylinePoints = routePaths[0];
                _navDistanceKm = routeInfos[0]['distance_km'];
                _navDurationMins = routeInfos[0]['duration_mins'];
                _selectedDestinationDistanceKm = routeInfos[0]['distance_km'];
                _selectedDestinationDurationMins = routeInfos[0]['duration_mins'];
              }
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("OSRM Road routing error: $e");
    }
  }

  void _onMapTapped(LatLng point) async {
    if (!_enableClickToSetDestination) return;

    setState(() {
      _selectedDestinationLatLng = point;
      _selectedDestinationName = "Fetching location details...";
      _isGeocodingSelectedPoint = true;
      _isCustomDestinationLocked = false;
    });

    final busLoc = _getBusLocation();
    final dist = _calculateDistanceKm(busLoc.latitude, busLoc.longitude, point.latitude, point.longitude);
    final durationMins = (dist / 25.0 * 60).round().clamp(1, 999);

    String placeName = "Selected Location (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})";
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}');
      final response = await http.get(url, headers: {'User-Agent': 'EduSHAMIIT-DriverApp/1.0'}).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name'] ?? data['name'] ?? "";
        if (displayName.isNotEmpty) {
          placeName = displayName;
          final parts = placeName.split(',');
          if (parts.length >= 2) {
            placeName = "${parts[0].trim()}, ${parts[1].trim()}";
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _selectedDestinationName = placeName;
        _selectedDestinationDistanceKm = dist;
        _selectedDestinationDurationMins = durationMins;
        _isGeocodingSelectedPoint = false;
      });

      // Fetch actual OSRM driving road polyline asynchronously
      _fetchRoadRouteToDestination(point);
    }
  }

  void _lockCustomDestination() async {
    if (_selectedDestinationLatLng == null) return;

    if (_navigationPolylinePoints.isEmpty || _navigationRoutePaths.isEmpty) {
      await _fetchRoadRouteToDestination(_selectedDestinationLatLng!);
    }

    setState(() {
      _isCustomDestinationLocked = true;
      _isTripActive = true;
      _isNavigating = true;
      _selectedRouteIndex = 0;
      _isAutoFollowVehicle = false;
    });

    _mapController.move(_selectedDestinationLatLng!, 16.0);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Destination Locked: $_selectedDestinationName! Navigation active.",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _clearCustomDestination() {
    setState(() {
      _selectedDestinationLatLng = null;
      _isCustomDestinationLocked = false;
      _selectedDestinationName = "";
      _isNavigating = false;
      _navigationPolylinePoints = [];
      _navigationRoutePaths = [];
    });
  }

  Future<void> _searchPlacesOnTheWay(String categoryKey, String queryKeyword) async {
    if (_activePoiCategory == categoryKey) {
      setState(() {
        _activePoiCategory = null;
        _poiMarkersData = [];
      });
      return;
    }

    setState(() {
      _activePoiCategory = categoryKey;
      _isSearchingLocation = true;
      _poiMarkersData = [];
    });

    final searchQuery = categoryKey == 'hospital'
        ? "hospital medical store emergency pharmacy"
        : categoryKey == 'petrol'
            ? "petrol pump fuel station"
            : queryKeyword;

    final double effectiveRadius = _isEmergencySearchMode
        ? math.max(_searchCorridorRadiusKm, 10.0)
        : _searchCorridorRadiusKm;

    final results = await _performTomTomSearchAlongRoute(categoryKey, searchQuery, maxRadiusFromRouteKm: effectiveRadius);

    setState(() {
      _isSearchingLocation = false;
      _poiMarkersData = results;
    });

    if (results.isNotEmpty) {
      _fitMapToAllStopsAndRoute();

      if (mounted) {
        final label = categoryKey == 'hospital' ? 'Emergency Hospitals & Medical Stores' : categoryKey.toUpperCase();
        final modeText = _isEmergencySearchMode ? "(Emergency Wide Search)" : "(Along Route Corridor)";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Found ${results.length} $label $modeText"),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No $categoryKey found along current range (${effectiveRadius.toStringAsFixed(1)} km)"),
            backgroundColor: const Color(0xFFF59E0B),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  double _distanceToSegmentKm(LatLng p, LatLng a, LatLng b) {
    final double latP = p.latitude;
    final double lonP = p.longitude;
    final double latA = a.latitude;
    final double lonA = a.longitude;
    final double latB = b.latitude;
    final double lonB = b.longitude;

    final double avgLatRad = ((latA + latB) / 2.0) * (math.pi / 180.0);
    final double cosLat = math.cos(avgLatRad);

    const double ax = 0.0;
    const double ay = 0.0;
    final double bx = (lonB - lonA) * 111.0 * cosLat;
    final double by = (latB - latA) * 111.0;
    final double px = (lonP - lonA) * 111.0 * cosLat;
    final double py = (latP - latA) * 111.0;

    final double dx = bx - ax;
    final double dy = by - ay;
    final double segmentLenSq = dx * dx + dy * dy;

    if (segmentLenSq == 0.0) {
      return _calculateDistanceKm(latP, lonP, latA, lonA);
    }

    double t = ((px - ax) * dx + (py - ay) * dy) / segmentLenSq;
    t = t.clamp(0.0, 1.0);

    final double closestX = ax + t * dx;
    final double closestY = ay + t * dy;

    final double distX = px - closestX;
    final double distY = py - closestY;

    return math.sqrt(distX * distX + distY * distY);
  }

  double _calculateMinDistanceToPolylineKm(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) {
      return _calculateDistanceKm(point.latitude, point.longitude, polyline[0].latitude, polyline[0].longitude);
    }

    double minDistance = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      final dist = _distanceToSegmentKm(point, polyline[i], polyline[i + 1]);
      if (dist < minDistance) {
        minDistance = dist;
      }
    }
    return minDistance;
  }

  int _getTargetPoiYield(double radiusKm, bool isEmergency) {
    if (isEmergency || radiusKm >= 20.0) return 75;
    if (radiusKm >= 10.0) return 50;
    if (radiusKm >= 5.0) return 35;
    if (radiusKm >= 2.5) return 20;
    return 12;
  }

  Future<List<Map<String, dynamic>>> _performTomTomSearchAlongRoute(
      String categoryKey, String queryKeyword, {double maxRadiusFromRouteKm = 2.0}) async {
    final busLoc = _getBusLocation();

    final List<LatLng> routePointsList = [];
    if (_routePoints.isNotEmpty) {
      routePointsList.addAll(_routePoints);
    }
    if (_navigationRoutePaths.isNotEmpty) {
      for (final path in _navigationRoutePaths) {
        routePointsList.addAll(path);
      }
    }
    if (routePointsList.isEmpty && _stops.isNotEmpty) {
      for (final s in _stops) {
        final lat = (s['latitude'] as num?)?.toDouble() ?? 0.0;
        final lon = (s['longitude'] as num?)?.toDouble() ?? 0.0;
        if (lat != 0.0 && lon != 0.0) {
          routePointsList.add(LatLng(lat, lon));
        }
      }
    }
    if (routePointsList.isEmpty) {
      routePointsList.add(busLoc);
    }

    final double effectiveRadius = _isEmergencySearchMode
        ? math.max(maxRadiusFromRouteKm, 10.0)
        : maxRadiusFromRouteKm;

    // Direct TomTom API Call via FastAPI GIS Microservice & Redis Cache
    final List<Map<String, dynamic>> allPois = await TomTomService().searchPlacesOnTheWay(
      categoryKey: categoryKey,
      queryKeyword: queryKeyword,
      routePoints: routePointsList,
      busLocation: busLoc,
      maxRadiusKm: effectiveRadius,
      isEmergency: _isEmergencySearchMode,
    );

    final List<Map<String, dynamic>> verifiedCandidatePois = [];

    for (final item in allPois) {
      final double lat = (item['lat'] as num).toDouble();
      final double lon = (item['lon'] as num).toDouble();
      final LatLng poiPoint = LatLng(lat, lon);

      final double busDist = _calculateDistanceKm(busLoc.latitude, busLoc.longitude, lat, lon);
      final double polylineDist = _calculateMinDistanceToPolylineKm(poiPoint, routePointsList);

      if (_isEmergencySearchMode) {
        // Emergency Mode: Show ALL facilities within wide radial area around bus location
        if (busDist <= effectiveRadius) {
          item['distance_km'] = busDist;
          item['corridor_dist_km'] = busDist;

          final bool isDuplicate = verifiedCandidatePois.any((existing) {
            final double dLat = ((existing['lat'] as num).toDouble() - lat).abs();
            final double dLon = ((existing['lon'] as num).toDouble() - lon).abs();
            return dLat < 0.0003 && dLon < 0.0003;
          });

          if (!isDuplicate) {
            verifiedCandidatePois.add(item);
          }
        }
      } else {
        // Normal Mode: Show places ALONG THE ROUTE POLYLINE PATH ONLY (max 2.0 km from polyline)
        final double maxPolyDist = math.min(effectiveRadius, 2.0);
        if (polylineDist <= maxPolyDist) {
          item['distance_km'] = busDist;
          item['corridor_dist_km'] = polylineDist;

          final bool isDuplicate = verifiedCandidatePois.any((existing) {
            final double dLat = ((existing['lat'] as num).toDouble() - lat).abs();
            final double dLon = ((existing['lon'] as num).toDouble() - lon).abs();
            return dLat < 0.0003 && dLon < 0.0003;
          });

          if (!isDuplicate) {
            verifiedCandidatePois.add(item);
          }
        }
      }
    }

    if (_isEmergencySearchMode) {
      // Sort Emergency Mode strictly by direct distance to bus
      verifiedCandidatePois.sort((a, b) {
        final double distA = (a['distance_km'] as num).toDouble();
        final double distB = (b['distance_km'] as num).toDouble();
        return distA.compareTo(distB);
      });
      final int targetYield = _getTargetPoiYield(effectiveRadius, _isEmergencySearchMode);
      return verifiedCandidatePois.take(targetYield).toList();
    } else {
      // Sort Normal Mode by proximity to polyline corridor / route progress
      verifiedCandidatePois.sort((a, b) {
        final double polyA = (a['corridor_dist_km'] as num).toDouble();
        final double polyB = (b['corridor_dist_km'] as num).toDouble();
        return polyA.compareTo(polyB);
      });
      // Cap at Top 10 nearest places on the polyline
      return verifiedCandidatePois.take(10).toList();
    }
  }

  Future<List<Map<String, dynamic>>> _performMultiEngineSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    final encodedQuery = Uri.encodeComponent(trimmedQuery);
    final List<Map<String, dynamic>> combinedResults = [];

    try {
      final tomTomPois = await TomTomService().fuzzySearch(trimmedQuery, userLocation: _getBusLocation());
      combinedResults.addAll(tomTomPois);

      final photonUrl = Uri.parse('https://photon.komoot.io/api/?q=$encodedQuery&limit=10');
      final nominatimUrl = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=$encodedQuery&limit=10&addressdetails=1');

      final responses = await Future.wait([
        http.get(photonUrl, headers: {'User-Agent': 'EduSHAMIIT-DriverApp/1.0'}).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500)),
        http.get(nominatimUrl, headers: {'User-Agent': 'EduSHAMIIT-DriverApp/1.0'}).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500)),
      ]);

      final photonRes = responses[0];
      final nominatimRes = responses[1];

      // 1. Process Photon Elasticsearch Results (Fuzzy & Multi-word query support)
      if (photonRes.statusCode == 200 && photonRes.body.isNotEmpty) {
        try {
          final data = jsonDecode(photonRes.body);
          final features = data['features'] as List? ?? [];
          for (final feat in features) {
            final props = feat['properties'] as Map<String, dynamic>? ?? {};
            final coords = feat['geometry']?['coordinates'] as List? ?? [];
            if (coords.length >= 2) {
              final lon = double.tryParse(coords[0].toString()) ?? 0.0;
              final lat = double.tryParse(coords[1].toString()) ?? 0.0;
              final name = (props['name'] ?? '').toString();
              final street = (props['street'] ?? '').toString();
              final district = (props['district'] ?? props['suburb'] ?? '').toString();
              final city = (props['city'] ?? props['town'] ?? props['village'] ?? props['county'] ?? '').toString();
              final state = (props['state'] ?? '').toString();
              final country = (props['country'] ?? '').toString();

              final parts = <String>[];
              if (name.isNotEmpty) parts.add(name);
              if (street.isNotEmpty) parts.add(street);
              if (district.isNotEmpty && district != name) parts.add(district);
              if (city.isNotEmpty && city != name) parts.add(city);
              if (state.isNotEmpty) parts.add(state);
              if (country.isNotEmpty) parts.add(country);

              final fullAddress = parts.join(', ');
              final primaryTitle = name.isNotEmpty ? name : (city.isNotEmpty ? city : (parts.isNotEmpty ? parts.first : trimmedQuery));

              if (lat != 0.0 && lon != 0.0) {
                combinedResults.add({
                  'display_name': fullAddress,
                  'primary_title': primaryTitle,
                  'name': name.isNotEmpty ? name : primaryTitle,
                  'lat': lat,
                  'lon': lon,
                });
              }
            }
          }
        } catch (_) {}
      }

      // 2. Process Nominatim Results
      if (nominatimRes.statusCode == 200 && nominatimRes.body.isNotEmpty) {
        try {
          final List data = jsonDecode(nominatimRes.body);
          for (final e in data) {
            final String rawName = (e['name'] ?? '').toString();
            final String display = (e['display_name'] ?? '').toString();
            final String primaryTitle = rawName.isNotEmpty ? rawName : display.split(',').first;
            final lat = double.tryParse(e['lat'].toString()) ?? 0.0;
            final lon = double.tryParse(e['lon'].toString()) ?? 0.0;

            if (lat != 0.0 && lon != 0.0) {
              combinedResults.add({
                'display_name': display,
                'primary_title': primaryTitle,
                'name': rawName.isNotEmpty ? rawName : primaryTitle,
                'lat': lat,
                'lon': lon,
              });
            }
          }
        } catch (_) {}
      }

      // 3. Deduplicate
      final List<Map<String, dynamic>> deduped = [];
      for (final item in combinedResults) {
        final double lat = item['lat'];
        final double lon = item['lon'];
        final bool isDuplicate = deduped.any((existing) {
          final double dLat = (existing['lat'] - lat).abs();
          final double dLon = (existing['lon'] - lon).abs();
          return dLat < 0.001 && dLon < 0.001;
        });
        if (!isDuplicate) {
          deduped.add(item);
        }
      }

      return deduped.take(8).toList();
    } catch (_) {
      return [];
    }
  }

  void _onSearchChanged(String value) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await _performMultiEngineSearch(value);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    });
  }

  void _selectSearchSuggestion(Map<String, dynamic> item) {
    final lat = item['lat'] as double;
    final lon = item['lon'] as double;
    final displayName = item['display_name'] as String;
    final targetLoc = LatLng(lat, lon);

    _searchController.text = item['name'] ?? item['primary_title'] ?? displayName.split(',').first;

    setState(() {
      _searchedMarkerLoc = targetLoc;
      _searchedLocationName = displayName;
      _searchResults = [];
      _showDestinationCard = true;
    });

    _mapController.move(targetLoc, 15.0);
  }

  Future<void> _searchLocation(String text) async {
    if (text.trim().isEmpty) return;
    final query = text.trim();

    setState(() {
      _isSearchingLocation = true;
      _searchResults = [];
    });

    final results = await _performMultiEngineSearch(query);

    if (results.isNotEmpty) {
      final first = results.first;
      final targetLoc = LatLng(first['lat'], first['lon']);
      final displayName = first['display_name'];

      setState(() {
        _searchedMarkerLoc = targetLoc;
        _searchedLocationName = displayName;
        _isSearchingLocation = false;
        _showDestinationCard = true;
      });

      _mapController.move(targetLoc, 15.0);
      return;
    }

    // Fallback search in stops list
    final lower = query.toLowerCase();
    LatLng? matchedLoc;
    for (final stop in _stops) {
      final sName = (stop['stop_name'] ?? '').toString().toLowerCase();
      if (sName.contains(lower)) {
        final lat = double.tryParse(stop['latitude']?.toString() ?? '');
        final lng = double.tryParse(stop['longitude']?.toString() ?? '');
        if (lat != null && lng != null) {
          matchedLoc = LatLng(lat, lng);
          break;
        }
      }
    }

    setState(() {
      _isSearchingLocation = false;
    });

    if (matchedLoc != null) {
      setState(() {
        _searchedMarkerLoc = matchedLoc;
        _searchedLocationName = query;
        _showDestinationCard = true;
      });
      _mapController.move(matchedLoc, 15.0);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Location '$query' not found. Try searching for cities, landmarks, or addresses."),
            backgroundColor: const Color(0xFFF59E0B),
          ),
        );
      }
    }
  }

  Future<void> _calculateDirections() async {
    if (_searchedMarkerLoc == null) return;
    final busLoc = _getBusLocation(); // Live vehicle position

    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
          '${busLoc.longitude},${busLoc.latitude};'
          '${_searchedMarkerLoc!.longitude},${_searchedMarkerLoc!.latitude}'
          '?overview=full&geometries=geojson&alternatives=true');

      final res = await http.get(url).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final routes = data['routes'] as List? ?? [];
        if (routes.isNotEmpty) {
          final List<List<LatLng>> routePaths = [];
          final List<Map<String, dynamic>> routeInfos = [];

          for (int i = 0; i < routes.length; i++) {
            final route = routes[i];
            final distMeters = (route['distance'] as num).toDouble();
            final durSecs = (route['duration'] as num).toDouble();
            final coords = route['geometry']['coordinates'] as List<dynamic>;

            final polyline = coords.map<LatLng>((c) {
              return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
            }).toList();

            final distKm = double.parse((distMeters / 1000.0).toStringAsFixed(1));
            final durMins = (durSecs / 60.0).round();

            routePaths.add(polyline);
            routeInfos.add({
              'label': i == 0 ? '⚡ Fastest Route' : (i == 1 ? '🌿 Shortest Path' : '🛣️ Alt Route $i'),
              'distance_km': distKm,
              'duration_mins': durMins,
              'summary': (route['legs'] is List && (route['legs'] as List).isNotEmpty) ? (route['legs'][0]['summary'] ?? (i == 0 ? 'Via Highway' : 'Via Local Corridor')) : (i == 0 ? 'Via Highway' : 'Via Local Corridor'),
            });
          }

          setState(() {
            _navigationRoutePaths = routePaths;
            _navigationRouteInfos = routeInfos;
            _selectedRouteIndex = 0;

            if (routePaths.isNotEmpty && routeInfos.isNotEmpty) {
              _navigationPolylinePoints = routePaths[0];
              _navDistanceKm = routeInfos[0]['distance_km'];
              _navDurationMins = routeInfos[0]['duration_mins'];
            }

            _isNavigating = false; // Pre-navigation route selection mode (Google Maps style)
            _isCalculatingRoute = false;
            _showDestinationCard = true;
          });

          _fitMapToBounds(busLoc, _searchedMarkerLoc!);
          return;
        }
      }
    } catch (e) {
      debugPrint("OSRM routing error: $e");
    }

    // Fallback if OSRM is unreachable: vehicle-to-destination polyline + alternative detour
    final directDistanceKm = double.parse(_calculateDistanceKm(busLoc.latitude, busLoc.longitude,
        _searchedMarkerLoc!.latitude, _searchedMarkerLoc!.longitude).toStringAsFixed(1));
    final directMins = math.max(1, (directDistanceKm * 1.8).round());

    final midLat = (busLoc.latitude + _searchedMarkerLoc!.latitude) / 2.0;
    final midLon = (busLoc.longitude + _searchedMarkerLoc!.longitude) / 2.0;

    final primaryPath = [busLoc, LatLng(midLat, midLon), _searchedMarkerLoc!];
    final altPath = [
      busLoc,
      LatLng(midLat + 0.005, midLon - 0.005),
      _searchedMarkerLoc!
    ];

    setState(() {
      _navigationRoutePaths = [primaryPath, altPath];
      _navigationRouteInfos = [
        {'label': '⚡ Direct Route', 'distance_km': directDistanceKm, 'duration_mins': directMins, 'summary': 'Direct Corridor'},
        {'label': '🌿 Eco Detour', 'distance_km': double.parse((directDistanceKm * 1.12).toStringAsFixed(1)), 'duration_mins': (directMins * 1.25).round(), 'summary': 'Service Road'},
      ];
      _selectedRouteIndex = 0;

      _navigationPolylinePoints = primaryPath;
      _navDistanceKm = directDistanceKm;
      _navDurationMins = directMins;

      _isNavigating = false; // Pre-navigation route selection mode
      _isCalculatingRoute = false;
      _showDestinationCard = true;
    });

    _fitMapToBounds(busLoc, _searchedMarkerLoc!);
  }

  void _fitMapToBounds(LatLng p1, LatLng p2) {
    final minLat = math.min(p1.latitude, p2.latitude);
    final maxLat = math.max(p1.latitude, p2.latitude);
    final minLng = math.min(p1.longitude, p2.longitude);
    final maxLng = math.max(p1.longitude, p2.longitude);

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    _mapController.move(LatLng(centerLat, centerLng), 12.0);
  }

  double _calculateDistanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = math.cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  Widget _buildAutocompleteDropdown() {
    return Container(
      width: 280,
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        shrinkWrap: true,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (context, index) {
          final item = _searchResults[index];
          final title = (item['primary_title'] ?? item['name'] ?? 'Location').toString();
          final address = (item['display_name'] ?? '').toString();
          return Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.location_on_outlined,
                  size: 18, color: Color(0xFF4F46E5)),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF1E293B)),
              ),
              subtitle: Text(
                address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
              onTap: () => _selectSearchSuggestion(item),
            ),
          );
        },
      ),
    );
  }

  void _showSmartSearchRangeModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isEmergencySearchMode ? const Color(0xFFFEF2F2) : const Color(0xFFEEF2FF),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isEmergencySearchMode ? Icons.emergency : Icons.tune,
                          color: _isEmergencySearchMode ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Smart Search & Range Filter",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              _isEmergencySearchMode ? "🚨 Emergency Wide Area Search Active" : "Configure corridor radius along active route",
                              style: TextStyle(fontSize: 11, color: _isEmergencySearchMode ? const Color(0xFFEF4444) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),
                  const Text(
                    "Search Radius / Corridor Width:",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [1.0, 2.5, 5.0, 10.0, 20.0].map((r) {
                      final bool isSel = _searchCorridorRadiusKm == r;
                      String label = "${r.toStringAsFixed(r == 1.0 || r == 2.5 ? 1 : 0)} km";
                      if (r == 1.0) label += " (Tight Route)";
                      if (r == 2.5) label += " (Standard)";
                      if (r == 5.0) label += " (Wide)";
                      if (r == 10.0) label += " (Regional)";
                      if (r == 20.0) label += " (Emergency Max)";

                      return ChoiceChip(
                        label: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                        selected: isSel,
                        selectedColor: const Color(0xFF4F46E5),
                        backgroundColor: const Color(0xFFF8FAFC),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _searchCorridorRadiusKm = r);
                            setModalState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isEmergencySearchMode ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _isEmergencySearchMode ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Emergency Override Mode",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              Text(
                                "Ignore strict route corridor & search wide radius for nearest medical/emergency facilities",
                                style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isEmergencySearchMode,
                          activeThumbColor: const Color(0xFFEF4444),
                          onChanged: (val) {
                            setState(() {
                              _isEmergencySearchMode = val;
                              if (val && _searchCorridorRadiusKm < 10.0) {
                                _searchCorridorRadiusKm = 10.0;
                              }
                            });
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isEmergencySearchMode ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.search, size: 18),
                      label: Text(
                        _activePoiCategory != null ? "Apply & Re-search ${_activePoiCategory!.toUpperCase()}" : "Apply Search Settings",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        if (_activePoiCategory != null) {
                          final catKey = _activePoiCategory!;
                          final query = catKey == 'petrol'
                              ? 'petrol pump'
                              : catKey == 'food'
                                  ? 'restaurant'
                                  : catKey == 'hospital'
                                      ? 'hospital'
                                      : catKey == 'mechanic'
                                          ? 'car repair mechanic'
                                          : 'parking';
                          setState(() {
                            _activePoiCategory = null;
                          });
                          _searchPlacesOnTheWay(catKey, query);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPoiCategoryChips() {
    final categories = [
      {'key': 'petrol', 'label': 'Petrol Pump', 'icon': Icons.local_gas_station, 'query': 'petrol pump', 'color': Colors.orange},
      {'key': 'food', 'label': 'Food / Restaurant', 'icon': Icons.restaurant, 'query': 'restaurant', 'color': Colors.redAccent},
      {'key': 'hospital', 'label': 'Hospital', 'icon': Icons.local_hospital, 'query': 'hospital', 'color': Colors.pink},
      {'key': 'mechanic', 'label': 'Mechanic', 'icon': Icons.build, 'query': 'car repair mechanic', 'color': Colors.blue},
      {'key': 'parking', 'label': 'Parking', 'icon': Icons.local_parking, 'query': 'parking', 'color': Colors.purple},
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showSmartSearchRangeModal,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isEmergencySearchMode ? const Color(0xFFEF4444) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isEmergencySearchMode ? Icons.emergency : Icons.tune, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _isEmergencySearchMode ? "🚨 Emergency Radius" : "Range: ${_searchCorridorRadiusKm.toStringAsFixed(1)} km",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ...categories.map((cat) {
              final String key = cat['key'] as String;
              final String label = cat['label'] as String;
              final IconData icon = cat['icon'] as IconData;
              final String query = cat['query'] as String;
              final Color catColor = cat['color'] as Color;
              final bool isSelected = _activePoiCategory == key;

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _searchPlacesOnTheWay(key, query);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? catColor : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? catColor : const Color(0xFFCBD5E1)),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14, color: isSelected ? Colors.white : catColor),
                          const SizedBox(width: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationInfoCard(LatLng busLoc) {
    if (_searchedMarkerLoc == null || !_showDestinationCard) return const SizedBox();

    final directDistKm = _calculateDistanceKm(busLoc.latitude, busLoc.longitude,
            _searchedMarkerLoc!.latitude, _searchedMarkerLoc!.longitude)
        .toStringAsFixed(1);

    return Positioned(
      bottom: 24,
      left: 70,
      right: 70,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Location Title & Details
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.navigation_rounded, color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _searchedLocationName.split(',').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _searchedLocationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.near_me, size: 12, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              "$directDistKm km",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          setState(() {
                            _showDestinationCard = false;
                            _searchedMarkerLoc = null;
                            _isNavigating = false;
                            _navigationRoutePaths = [];
                            _navigationRouteInfos = [];
                          });
                        },
                      ),
                    ],
                  ),

                  // Middle Row: Multi-Route Alternative Selection Chips
                  if (_navigationRouteInfos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      "Select Route Option:",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(_navigationRouteInfos.length, (idx) {
                          final info = _navigationRouteInfos[idx];
                          final bool isSelected = _selectedRouteIndex == idx;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedRouteIndex = idx;
                                    _navigationPolylinePoints = _navigationRoutePaths[idx];
                                    _navDistanceKm = info['distance_km'];
                                    _navDurationMins = info['duration_mins'];
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
                                      width: isSelected ? 2.0 : 1.0,
                                    ),
                                    boxShadow: isSelected
                                        ? const [BoxShadow(color: Color(0x3D2563EB), blurRadius: 8, offset: Offset(0, 3))]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                        size: 14,
                                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 6),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            info['label'],
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                            ),
                                          ),
                                          Text(
                                            "${info['duration_mins']} mins • ${info['distance_km']} km",
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isSelected ? const Color(0xFFDBEAFE) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Bottom Row: Primary Actions (Get Directions / Start Nav)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 3,
                          ),
                          onPressed: () {
                            if (_navigationRoutePaths.isEmpty) {
                              _calculateDirections();
                            } else {
                              setState(() {
                                _isNavigating = true;
                              });
                            }
                          },
                          icon: Icon(_isNavigating ? Icons.navigation : Icons.near_me, size: 18),
                          label: Text(
                            _isCalculatingRoute
                                ? "Calculating Routes..."
                                : (_isNavigating
                                    ? "🚀 ACTIVE DRIVING NAVIGATION"
                                    : "🚀 START NAVIGATION ($_navDurationMins MINS)"),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (_isNavigating) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            backgroundColor: const Color(0xFFFEF2F2),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setState(() {
                              _isNavigating = false;
                              _navigationRoutePaths = [];
                              _navigationRouteInfos = [];
                              _navigationPolylinePoints = [];
                              _showDestinationCard = false;
                            });
                          },
                          icon: const Icon(Icons.stop_circle_outlined, size: 18),
                          label: const Text("Exit Nav", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveNavigationBanner() {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
                color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.turn_right, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Navigating to ${_searchedLocationName.split(',').first}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text("$_navDurationMins mins",
                          style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                      const SizedBox(width: 8),
                      Text("•  $_navDistanceKm km",
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 11)),
                      const SizedBox(width: 8),
                      const Text("•  OSRM Live Road Route",
                          style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                setState(() {
                  _isNavigating = false;
                  _navigationPolylinePoints = [];
                });
              },
              icon: const Icon(Icons.stop_circle_outlined, size: 16),
              label: const Text("Exit Nav",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  // ─── STOPPAGE TAP MARKER POPUP ──────────────────────────────────────────

  void _showStopStudentsPopup(Map<String, dynamic> stop, int stopIndex) {
    final stopStudents =
        _students.where((st) => st['stop_id'] == stop['id']).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stop['stop_name'] ?? "",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("Stop Order: ${stopIndex + 1}  •  Stoppage Details",
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (stopStudents.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text("No students assigned to this stoppage."),
                )
              else ...[
                const Text("Assigned Students list:",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: stopStudents.length,
                    itemBuilder: (context, idx) {
                      final s = stopStudents[idx];
                      return ListTile(
                        leading: _buildUserAvatar(
                            s['avatar_url'], s['full_name'] ?? "",
                            radius: 14),
                        title: Text(s['full_name'] ?? "",
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            "Class ${s['class_name'] ?? ''}  •  Status: ${s['status']}",
                            style: const TextStyle(fontSize: 10)),
                        trailing: TextButton(
                          onPressed: () {
                            setState(() {
                              s['status'] = s['status'] == 'picked'
                                  ? 'yet_to_pick'
                                  : 'picked';
                              _syncSelectedMap();
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                              s['status'] == 'picked' ? "On Board" : "Pick"),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (var s in stopStudents) {
                  s['status'] = 'picked';
                }
                stop['status'] = 'completed';
                _syncCurrentStopIndex();
              });
              Navigator.pop(context);
            },
            child: const Text("Mark All Picked"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // ─── END-TO-END MUTATIONS ────────────────────────────────────────────────

  Future<void> _startTrip({String? tripIdOverride, String? routeIdOverride}) async {
    setState(() {
      _isTripActive = true;
      _isTripPaused = false;
    });

    try {
      final targetRouteId = routeIdOverride ?? _selectedRouteId ?? _activeTrip?['route_id'] ?? _activeTrip?['transport_route_id'];
      final effectiveTripId = tripIdOverride ?? _activeTrip?['id']?.toString() ?? _activeTrip?['schedule_id']?.toString();

      if (targetRouteId != null || effectiveTripId != null) {
        final payload = <String, dynamic>{
          if (targetRouteId != null) "route_id": targetRouteId.toString(),
          "trip_type": "pickup",
          if (effectiveTripId != null) "trip_id": effectiveTripId,
        };
        debugPrint("[DRIVER_DASH] Starting trip with payload: $payload");
        final res = await ApiService().post('/transport/driver/trips/start', payload);
        if (res['success'] == true && res['data'] != null) {
          final startedTrip = res['data'];
          final tripIdToLoad = startedTrip['id'] ?? startedTrip['schedule_id'] ?? effectiveTripId;
          if (tripIdToLoad != null) {
            await _loadTripState(tripIdToLoad.toString());
          }
        }
      }
    } catch (e) {
      debugPrint("Error starting trip in db: $e");
    }

    _startTelemetryBroadcasting();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("🚌 Route trip started! Live tracking active."),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _executeTripAction(String action, [Map<String, dynamic>? payload]) async {
    final trip = await _ensureActiveTrip();
    if (trip == null) return;
    final tripId = trip['id'];
    try {
      debugPrint("[DRIVER_DASH] Executing unified action: '$action'");
      await ApiService().post('/transport/driver/trips/$tripId/action', {
        'action': action,
        'payload': payload ?? {},
      });
    } catch (e) {
      debugPrint("[DRIVER_DASH] Unified action '$action' notice: $e");
    }
  }

  Future<void> _batchSyncStopAndStudents({
    String? stopId,
    List<Map<String, dynamic>>? students,
    int? currentStopIndex,
  }) async {
    final trip = await _ensureActiveTrip();
    if (trip == null) return;
    final tripId = trip['id'];
    final busLoc = _getBusLocation();

    final payload = <String, dynamic>{
      if (stopId != null) "stop_id": stopId,
      if (students != null) "students": students,
      if (currentStopIndex != null) "current_stop_index": currentStopIndex,
      "latitude": busLoc.latitude,
      "longitude": busLoc.longitude,
      "bus_position_ratio": _busPositionRatio,
      "elapsed_seconds": _elapsedMinutes * 60,
      "distance_km": _totalDistanceKm,
      "live_status": _isTripPaused ? "paused" : "on_route",
      "students_on_board": _getOnBoardCount(),
    };

    try {
      debugPrint("[DRIVER_DASH] Unified Atomic batch_sync for trip $tripId");
      final res = await ApiService().post('/transport/driver/trips/$tripId/action', {
        "action": "batch_sync",
        "payload": payload,
      });
      debugPrint("[DRIVER_DASH] Unified Atomic batch_sync SUCCESS");

      final bool allStopsCompleted = _stops.isNotEmpty && _stops.every((s) => s['status'] == 'completed');
      if (allStopsCompleted || res['trip_status'] == 'completed') {
        if (mounted) {
          setState(() {
            _isTripActive = false;
            _isTripPaused = false;
            if (_activeTrip != null) {
              _activeTrip!['status'] = 'completed';
            }
          });
        }
      }
    } catch (e) {
      debugPrint("[DRIVER_DASH] Batch sync notice: $e");
    }
  }

  Future<void> _togglePauseTrip() => _togglePauseResume();

  Future<void> _togglePauseResume() async {
    setState(() {
      _isTripPaused = !_isTripPaused;
    });

    await _executeTripAction(_isTripPaused ? 'pause' : 'resume');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isTripPaused
                ? "⏸ Route Paused. Live location updates frozen."
                : "▶ Route Resumed. Live tracking active."),
            backgroundColor: Colors.amber),
      );
    }
  }

  Future<void> _endTrip() async {
    final bool hasUncompletedStops = _stops.any((s) => s['status'] != 'completed');
    if (hasUncompletedStops) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ Cannot end trip: All route stops must be completed first!"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    _telemetryTimer?.cancel();

    await _executeTripAction('end');

    setState(() {
      _isTripActive = false;
      _isTripPaused = false;
      _activeTrip = null;
      _busPositionRatio = 0.0;
      for (var s in _stops) {
        s['status'] = 'pending';
      }
      for (var st in _students) {
        st['status'] = 'yet_to_pick';
      }
      _syncCurrentStopIndex();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("🏁 Route trip ended! Vehicle is now offline and invisible on map."),
            backgroundColor: Colors.indigo),
      );
    }
  }

  Future<void> _completeStopAtIndex(int index) async {
    if (index >= _stops.length) return;
    debugPrint(
        "[DRIVER_DASH] _completeStopAtIndex: Completing stop $index (${_stops[index]['stop_name']})");
    setState(() {
      _stops[index]['status'] = 'completed';
      _syncCurrentStopIndex();
    });

    final stopId = _stops[index]['id'];
    await _batchSyncStopAndStudents(stopId: stopId, currentStopIndex: _currentStopIndex);
  }

  Future<void> _updateStudentStatusBulk(String status) async {
    final List<String> targetIds = _selectedStudents.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (targetIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Select at least one student"),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (_stops.isEmpty || _selectedStopIndexForChecklist >= _stops.length) return;
    final String selectedStopId = _stops[_selectedStopIndexForChecklist]['id'];
    setState(() {
      for (var st in _students) {
        if (targetIds.contains(st['id'])) {
          st['status'] = status;
          if (status == 'dropped') {
            st['drop_stop_id'] = selectedStopId;
          }
        }
      }
      _syncSelectedMap();
    });

    if (status == 'picked') {
      await _autoCompletePreviousStoppages(_selectedStopIndexForChecklist);
    }

    final studentPayload = targetIds
        .map((id) => {
              "student_id": id,
              "status": status,
              "stop_id": selectedStopId,
              if (status == 'dropped') "drop_stop_id": selectedStopId
            })
        .toList();

    await _batchSyncStopAndStudents(students: studentPayload, currentStopIndex: _currentStopIndex);
  }

  Future<void> _autoCompletePreviousStoppages(int targetStopIndex) async {
    List<int> uncompletedIndices = [];
    for (int i = 0; i < targetStopIndex; i++) {
      if (i < _stops.length && _stops[i]['status'] != 'completed') {
        uncompletedIndices.add(i);
      }
    }

    if (uncompletedIndices.isEmpty) return;

    setState(() {
      for (int i in uncompletedIndices) {
        _stops[i]['status'] = 'completed';
      }
      _syncCurrentStopIndex();
    });

    for (int i in uncompletedIndices) {
      final stopId = _stops[i]['id'];
      await _batchSyncStopAndStudents(stopId: stopId);
    }
  }

  Future<void> _markAllStudentsStatusAtCurrentStop(String status) async {
    if (_stops.isEmpty || _selectedStopIndexForChecklist >= _stops.length) return;
    final currentStudents = _getStudentsAtSelectedStop();
    final currentStopId = _stops[_selectedStopIndexForChecklist]['id'];
    debugPrint(
        "[DRIVER_DASH] _markAllStudentsStatusAtCurrentStop: Marking ${currentStudents.length} students as '$status' at stop $_selectedStopIndexForChecklist ($currentStopId)");
    setState(() {
      for (var st in _students) {
        if (currentStudents.any((cs) => cs['id'] == st['id'])) {
          st['status'] = status;
        }
      }
      _stops[_selectedStopIndexForChecklist]['status'] = 'completed';
      _syncCurrentStopIndex();
      _syncSelectedMap();
    });

    if (status == 'picked') {
      await _autoCompletePreviousStoppages(_selectedStopIndexForChecklist);
    }

    final studentPayload = currentStudents
        .map((s) => {
              "student_id": s['id'],
              "status": status,
              "stop_id": currentStopId,
              if (status == 'dropped') "drop_stop_id": currentStopId
            })
        .toList();

    // 1 single atomic batch sync call completes the stop, updates students, and syncs location!
    await _batchSyncStopAndStudents(
      stopId: currentStopId,
      students: studentPayload,
      currentStopIndex: _currentStopIndex,
    );
  }

  Future<void> _triggerEmergency() async {
    setState(() {
      _emergencyAlertActive = true;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 10),
            Text("SOS SIGNAL ACTIVE",
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
            "Critical SOS notification sent to the Central Admin Panel with your current location."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Dismiss")),
        ],
      ),
    );

    try {
      if (_activeTrip != null) {
        final busLoc = _getBusLocation();
        await ApiService()
            .post('/transport/driver/trips/${_activeTrip!['id']}/emergency', {
          "title": "SOS Emergency Alert",
          "message": "Driver raised emergency alarm",
          "latitude": busLoc.latitude,
          "longitude": busLoc.longitude
        });
      }
    } catch (e) {
      debugPrint("Error sending SOS: $e");
    }
  }

  Future<void> _triggerDeviation() async {
    setState(() {
      _deviationAlertActive = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Route deviation registered."),
          backgroundColor: Colors.orange),
    );

    try {
      if (_activeTrip != null) {
        final busLoc = _getBusLocation();
        await ApiService()
            .post('/transport/driver/trips/${_activeTrip!['id']}/deviation', {
          "message": "Vehicle deviated from Noida Noida Noida route path",
          "latitude": busLoc.latitude,
          "longitude": busLoc.longitude
        });
      }
    } catch (e) {
      debugPrint("Error sending deviation alert: $e");
    }
  }

  // ─── STOPS REORDERING & OSM DIRECTION ENGINE ────────────────────────────

  Future<void> _recalculateETAsWithOSRM() async {
    if (_stops.isEmpty) return;

    try {
      final upcomingStops =
          _stops.where((s) => s['status'] != 'completed').toList();
      if (upcomingStops.length < 2) return;

      final coordsStr = upcomingStops
          .map((s) => "${s['longitude']},${s['latitude']}")
          .join(";");
      final url = Uri.parse(
          "https://router.projectosrm.org/route/v1/driving/$coordsStr?overview=false");

      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final legs = data['routes'][0]['legs'] as List<dynamic>;

          DateTime baseTime = DateTime.now();
          final completedStops =
              _stops.where((s) => s['status'] == 'completed').toList();
          if (completedStops.isNotEmpty) {
            final lastCompleted = completedStops.last;
            final timeStr = lastCompleted['actual_arrival'] ??
                lastCompleted['estimated_arrival'] ??
                "07:00 AM";
            baseTime = _parseTimeOfDay(timeStr);
          }

          int legIndex = 0;
          for (int i = 0; i < _stops.length; i++) {
            if (_stops[i]['status'] == 'completed') continue;

            if (legIndex < legs.length) {
              final durationSec = legs[legIndex]['duration'] as num;
              baseTime = baseTime.add(Duration(
                  seconds: durationSec.toInt() +
                      45)); // leg duration + 45s stop buffer

              final formattedTime = _formatTimeOfDay(baseTime);
              setState(() {
                _stops[i]['estimated_arrival'] = formattedTime;
              });

              if (_activeTrip != null) {
                await ApiService().post(
                    '/transport/driver/trips/${_activeTrip!['id']}/stops/${_stops[i]['id']}/eta',
                    {"estimated_arrival": formattedTime});
              }
              legIndex++;
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text("🚀 Route ETAs re-calculated via OSM Direction API!"),
                backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception("OSRM returned ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("OSRM failed, falling back: $e");
      _recalculateETAsFallback();
    }
  }

  void _recalculateETAsFallback() {
    DateTime baseTime = DateTime.now();
    final completedStops =
        _stops.where((s) => s['status'] == 'completed').toList();
    if (completedStops.isNotEmpty) {
      final lastCompleted = completedStops.last;
      baseTime = _parseTimeOfDay(lastCompleted['actual_arrival'] ??
          lastCompleted['estimated_arrival'] ??
          "07:00 AM");
    }

    for (int i = 0; i < _stops.length; i++) {
      if (_stops[i]['status'] == 'completed') continue;

      baseTime = baseTime.add(const Duration(minutes: 4));
      final formattedTime = _formatTimeOfDay(baseTime);
      setState(() {
        _stops[i]['estimated_arrival'] = formattedTime;
      });

      if (_activeTrip != null) {
        ApiService().post(
            '/transport/driver/trips/${_activeTrip!['id']}/stops/${_stops[i]['id']}/eta',
            {"estimated_arrival": formattedTime});
      }
    }
  }

  DateTime _parseTimeOfDay(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final parts = clean.split(" ");
      final timeParts = parts[0].split(":");
      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      if (parts.length > 1 && parts[1] == "PM" && hour < 12) {
        hour += 12;
      } else if (parts.length > 1 && parts[1] == "AM" && hour == 12) {
        hour = 0;
      }
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      return DateTime.now();
    }
  }

  String _formatTimeOfDay(DateTime dt) {
    final int hour = dt.hour;
    final int minute = dt.minute;
    final String period = hour >= 12 ? "PM" : "AM";
    int displayHour = hour % 12;
    if (displayHour == 0) displayHour = 12;
    final String minStr = minute.toString().padLeft(2, '0');
    final String hrStr = displayHour.toString().padLeft(2, '0');
    return "$hrStr:$minStr $period";
  }

  Future<void> _reorderStops() async {
    setState(() {
      final upcoming = _stops.sublist(_currentStopIndex);
      final completed = _stops.sublist(0, _currentStopIndex);
      _stops = completed + upcoming.reversed.toList();
      _syncCurrentStopIndex();
    });

    if (_activeTrip != null) {
      final stopIds = _stops.map((s) => s['id'] as String).toList();
      await ApiService().post(
          '/transport/driver/trips/${_activeTrip!['id']}/reorder',
          {"stop_ids": stopIds});
      await _recalculateETAsWithOSRM();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Upcoming stops reversed & re-calculated!"),
          backgroundColor: Colors.indigo),
    );
  }

  Future<void> _saveStopETA(int index, String newETA) async {
    setState(() {
      _stops[index]['estimated_arrival'] = newETA;
    });

    try {
      final trip = await _ensureActiveTrip();
      final stopId = _stops[index]['id'];
      if (trip != null && stopId != null) {
        await ApiService().post(
            '/transport/driver/trips/${trip['id']}/stops/$stopId/eta',
            {"estimated_arrival": newETA});
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Stop ETA updated to $newETA in database!"),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint("Error saving stop ETA to DB: $e");
    }
  }

  void _shareETA() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("ETAs synchronized and shared successfully!"),
          backgroundColor: Colors.green),
    );
  }

  List<dynamic> _getStudentsAtSelectedStop() {
    if (_stops.isEmpty || _selectedStopIndexForChecklist >= _stops.length) {
      return [];
    }
    final selectedStop = _stops[_selectedStopIndexForChecklist];
    final selectedStopId = selectedStop['id'];

    // Only return students that still need to be picked at this stop.
    // Students already picked/onboarded should NOT appear in "To Pick".
    return _students
        .where((s) => s['stop_id'] == selectedStopId && s['status'] == 'yet_to_pick')
        .toList();
  }

  int _getOnBoardCount() {
    return _students.where((s) => s['status'] == 'picked').length;
  }

  int _getDroppedCount() {
    return _students.where((s) => s['status'] == 'dropped').length;
  }

  int _getYetToPickCount() {
    return _students.where((s) => s['status'] == 'yet_to_pick').length;
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).userData;
    final driverName = user?['full_name'] ?? "Ramesh Kumar";
    final avatarUrl = user?['avatar_url'];
    final isDesktop = MediaQuery.of(context).size.width > 1100;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isInitialLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  SizedBox(height: 16),
                  Text("Loading trip data...",
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                ],
              ),
            )
          : Column(
              children: [
                _buildHeader(driverName, avatarUrl),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 16.0),
                    child: Column(
                      children: [
                        _buildStatsCardsRow(),
                        const SizedBox(height: 16.0),
                        if (isDesktop) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildMapViewCard()),
                              const SizedBox(width: 16.0),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  children: [
                                    _buildRouteProgressCard(),
                                    const SizedBox(height: 16.0),
                                    _buildQuickActionsCard(),
                                  ],
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  flex: 3, child: _buildRouteStopsTableCard()),
                              const SizedBox(width: 16.0),
                              Expanded(
                                  flex: 2, child: _buildStudentsChecklistCard())
                            ],
                          ),
                        ] else ...[
                          _buildMapViewCard(),
                          const SizedBox(height: 16.0),
                          _buildRouteProgressCard(),
                          const SizedBox(height: 16.0),
                          _buildQuickActionsCard(),
                          const SizedBox(height: 16.0),
                          _buildRouteStopsTableCard(),
                          const SizedBox(height: 16.0),
                          _buildStudentsChecklistCard(),
                        ]
                      ],
                    ),
                  ),
                ),
                _buildBottomControlPanel(),
              ],
            ),
    );
  }

  Widget _buildHeader(String driverName, String? avatarUrl) {
    return LayoutBuilder(builder: (context, constraints) {
      final bool isMobile = constraints.maxWidth < 800;

      if (isMobile) {
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.all(5.0),
                child: const Icon(Icons.directions_bus, color: Color(0xFF4F46E5), size: 18),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildActiveRouteBanner(),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => context.go('/admin/my-profile'),
                borderRadius: BorderRadius.circular(8),
                child: _buildUserAvatar(avatarUrl, driverName, radius: 14),
              ),
            ],
          ),
        );
      }

      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    padding: const EdgeInsets.all(8.0),
                    child: const Icon(Icons.directions_bus, color: Color(0xFF4F46E5), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "EduSHAMIIT ERP",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          "Driver App",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(child: _buildActiveRouteBanner()),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Badge(
                    label: Text("3"),
                    child: Icon(Icons.notifications_none_outlined, color: Color(0xFF475569)),
                  ),
                  onPressed: () {},
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => context.go('/admin/my-profile'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildUserAvatar(avatarUrl, driverName, radius: 18),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                            Text("Driver • $_busNumber", style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                          ],
                        )
                      ],
                    ),
                  ),
                )
              ],
            )
          ],
        ),
      );
    });
  }



  int _calculateDurationMins(dynamic startTime, dynamic endTime) {
    if (startTime == null || endTime == null) return 0;
    try {
      int parseMins(String tStr) {
        tStr = tStr.trim();
        if (tStr.toUpperCase().contains('AM') || tStr.toUpperCase().contains('PM')) {
          final parts = tStr.split(' ');
          final timeParts = parts[0].split(':');
          int h = int.parse(timeParts[0]);
          final m = int.parse(timeParts[1]);
          if (parts[1].toUpperCase() == 'PM' && h < 12) h += 12;
          if (parts[1].toUpperCase() == 'AM' && h == 12) h = 0;
          return h * 60 + m;
        }
        final parts = tStr.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        return h * 60 + m;
      }

      final startM = parseMins(startTime.toString());
      final endM = parseMins(endTime.toString());
      int diff = endM - startM;
      if (diff < 0) diff += 24 * 60;
      return diff;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _selectRoute(Map<String, dynamic> route) async {
    final routeId = route['id']?.toString() ?? '';
    final routeName = route['route_name'] ?? 'Route';
    final shift = route['shift'] ?? 'Morning';

    final busLabel = route['registration_no'] ?? route['bus_number'] ?? route['assigned_bus'] ?? 'UP18181';
    final stTime = route['start_time'] != null ? route['start_time'].toString() : '03:30 PM';
    final dist = (route['distance_km'] as num?)?.toDouble() ?? 55.13;
    
    final calcDuration = _calculateDurationMins(route['start_time'], route['end_time']);
    final duration = calcDuration > 0
        ? calcDuration
        : ((route['travel_time_mins'] as num?)?.toInt() ?? 52);

    setState(() {
      _selectedRouteId = routeId;
      _selectedRoute = route;
      _registrationNo = busLabel.toString();
      _busNumber = busLabel.toString();
      _startTime = stTime;
      _totalDistanceKm = dist;
      _totalTimeMinutes = duration;
    });

    try {
      final stopsRes = await ApiService().get('/transport/stops', query: {'route_id': routeId}, useCache: false);
      if (stopsRes['success'] == true && stopsRes['data'] != null) {
        final rawStops = (stopsRes['data'] is Map ? stopsRes['data']['stops'] : stopsRes['data']) as List<dynamic>? ?? [];
        if (rawStops.isNotEmpty) {
          setState(() {
            _stops = rawStops.map<Map<String, dynamic>>((s) => {
              'id': s['id']?.toString() ?? '',
              'stop_name': s['stop_name'] ?? 'Stoppage',
              'latitude': (s['latitude'] as num?)?.toDouble() ?? 28.62,
              'longitude': (s['longitude'] as num?)?.toDouble() ?? 77.37,
              'stop_order': s['stop_order'] ?? 1,
              'estimated_arrival': s['estimated_arrival'] ?? '03:30 PM',
              'status': 'pending',
              'landmark': s['landmark'],
              'stop_code': s['stop_code'],
            }).toList();
          });
        }
      }

      try {
        final studentsRes = await ApiService().get('/transport/driver/routes/$routeId/students', useCache: false);
        if (studentsRes['success'] == true && studentsRes['data'] != null) {
          final List<dynamic> fetchedStudents = studentsRes['data'];
          if (fetchedStudents.isNotEmpty) {
            setState(() {
              _students = fetchedStudents.map<Map<String, dynamic>>((st) => Map<String, dynamic>.from(st)).toList();
            });
          }
        }
      } catch (_) {}

      setState(() {
        _syncCurrentStopIndex();
        _syncSelectedMap();
      });
      await _loadOSRMRouteForStops();
    } catch (e) {
      debugPrint("Error switching route details: $e");
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.alt_route_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Switched Active Route: $routeName ($shift)",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4F46E5),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildActiveRouteBanner() {
    if (_selectedRoute == null && _tripState?['route'] == null && _activeTrip == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty_rounded, size: 14, color: Color(0xFFF59E0B)),
            const SizedBox(width: 6),
            const Text(
              "No Scheduled Route • Waiting",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 10, color: Color(0xFFD97706)),
                  SizedBox(width: 3),
                  Text(
                    "Standby",
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final routeName = _selectedRoute?['route_name'] ?? _tripState?['route']?['route_name'] ?? 'Assigned Route';
    final shift = _selectedRoute?['shift'] ?? _tripState?['route']?['shift'] ?? '';
    final busLabel = _busNumber.isNotEmpty
        ? _busNumber
        : (_selectedRoute?['bus_number'] ?? _selectedRoute?['registration_no'] ?? _selectedRoute?['assigned_bus'] ?? 'Assigned Bus');

    String statusText = "Ready to Start";
    Color statusColor = const Color(0xFF6366F1);
    Color statusBg = const Color(0xFFEEF2FF);

    final bool isCompleted = _stops.isNotEmpty && _stops.every((s) => s['status'] == 'completed');

    if (isCompleted) {
      statusText = "Completed";
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFECFDF5);
    } else if (_isTripActive && !_isTripPaused) {
      statusText = "In Progress";
      statusColor = const Color(0xFF10B981);
      statusBg = const Color(0xFFECFDF5);
    } else if (_isTripPaused) {
      statusText = "Paused";
      statusColor = const Color(0xFFF59E0B);
      statusBg = const Color(0xFFFFFBEB);
    }

    String displayRouteTitle = routeName;
    if (shift.isNotEmpty && !displayRouteTitle.toLowerCase().contains(shift.toLowerCase())) {
      displayRouteTitle = "$displayRouteTitle ($shift)";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.25)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_bus_rounded, size: 14, color: Color(0xFF4F46E5)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              "$displayRouteTitle • $busLabel",
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCardsRow() {
    Widget buildStatCard({
      required String label,
      required String value,
      required String subtitle,
      required IconData icon,
      required Color iconColor,
    }) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFFF1F5F9),
                    blurRadius: 4,
                    offset: Offset(0, 2))
              ]),
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: subtitle.contains("Time") ||
                          subtitle.contains("Live") ||
                          subtitle.contains("Route")
                      ? Colors.green
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final double width = constraints.maxWidth;
      final bool hasRoute = (_selectedRoute != null || _tripState?['route'] != null || _activeTrip != null);
      final String busVal = _registrationNo.isNotEmpty ? _registrationNo : (hasRoute ? "Assigned Bus" : "No Bus Assigned");
      final String busSub = hasRoute ? (_selectedRoute?['vehicle_type'] ?? "School Bus") : "Waiting for Schedule";
      final String startVal = _startTime.isNotEmpty ? _startTime : "--:--";
      final bool isCompleted = (_activeTrip?['status'] == 'completed') || (_stops.isNotEmpty && _stops.every((s) => s['status'] == 'completed'));
      final String startSub = isCompleted ? "Completed" : (hasRoute ? (_isTripActive ? "In Progress" : "Scheduled") : "No Schedule");
      final String locVal = _stops.isNotEmpty ? _currentLocationName : "Waiting";
      final String locSub = isCompleted ? "Completed" : (_isTripActive ? "Live" : "Standby");
      final String nextVal = isCompleted ? "Depot / End" : (_stops.isNotEmpty ? _nextStopName : "None Scheduled");
      final String nextSub = isCompleted ? "Completed" : (_isTripActive ? "ETA: 3 min" : (hasRoute ? "Ready" : "Waiting"));

      if (width < 950) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSingleWrapStat("Bus", busVal, busSub,
                Icons.directions_bus, const Color(0xFF4F46E5), width),
            _buildSingleWrapStat("Start Time", startVal, startSub,
                Icons.access_time, Colors.amber.shade700, width),
            _buildSingleWrapStat("Location", locVal, locSub,
                Icons.my_location, Colors.green, width),
            _buildSingleWrapStat("Next Stop", nextVal, nextSub,
                Icons.location_on_outlined, Colors.purple, width),
            _buildSingleWrapStat(
                "Distance",
                "${_totalDistanceKm.toStringAsFixed(1)} km",
                "Covered: ${_coveredDistanceKm.toStringAsFixed(1)} km",
                Icons.timeline,
                Colors.blue,
                width),
            _buildSingleWrapStat(
                "Total Time",
                "$_totalTimeMinutes min",
                "Elapsed: $_elapsedMinutes min",
                Icons.timer_outlined,
                Colors.pink,
                width),
          ],
        );
      }

      return Row(
        children: [
          buildStatCard(
              label: "Bus",
              value: busVal,
              subtitle: busSub,
              icon: Icons.directions_bus,
              iconColor: const Color(0xFF4F46E5)),
          buildStatCard(
              label: "Start Time",
              value: startVal,
              subtitle: startSub,
              icon: Icons.access_time,
              iconColor: Colors.amber.shade700),
          buildStatCard(
              label: "Current Location",
              value: locVal,
              subtitle: locSub,
              icon: Icons.my_location,
              iconColor: Colors.green),
          buildStatCard(
              label: "Next Stop",
              value: nextVal,
              subtitle: nextSub,
              icon: Icons.location_on_outlined,
              iconColor: Colors.purple),
          buildStatCard(
              label: "Total Distance",
              value: "${_totalDistanceKm.toStringAsFixed(1)} km",
              subtitle: "Covered: ${_coveredDistanceKm.toStringAsFixed(1)} km",
              icon: Icons.timeline,
              iconColor: Colors.blue),
          buildStatCard(
              label: "Total Time",
              value: "$_totalTimeMinutes min",
              subtitle: "Elapsed: $_elapsedMinutes min",
              icon: Icons.timer_outlined,
              iconColor: Colors.pink),
        ],
      );
    });
  }

  Widget _buildSingleWrapStat(String label, String value, String subtitle,
      IconData icon, Color iconColor, double width) {
    return Container(
      width: (width - 24) / 2,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 8,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, color: iconColor, size: 12),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 8, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMapViewCard() {
    final busLoc = _getBusLocation();

    final List<Marker> markers = [];

    // Render Stoppage Markers
    for (int i = 0; i < _stops.length; i++) {
      final stop = _stops[i];
      final lat = double.tryParse(stop['latitude']?.toString() ?? '') ?? 0.0;
      final lon = double.tryParse(stop['longitude']?.toString() ?? '') ?? 0.0;

      if (lat == 0.0 || lon == 0.0) continue;

      final isStart = i == 0;
      final isEnd = i == _stops.length - 1;
      final stopName = stop['stop_name'] ?? 'Stop #${i + 1}';
      final stopOrder = i + 1;

      markers.add(
        Marker(
          point: LatLng(lat, lon),
          width: 140,
          height: 48,
          child: GestureDetector(
            onTap: () => _showStopStudentsPopup(stop, i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isStart
                        ? Colors.green
                        : isEnd
                            ? Colors.redAccent
                            : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Text(
                    isStart
                        ? "Start: $stopName"
                        : isEnd
                            ? "End: $stopName"
                            : "#$stopOrder: $stopName",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isStart
                        ? Colors.green
                        : isEnd
                            ? Colors.redAccent
                            : const Color(0xFF4F46E5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Real-Vehicle Marker with Radar Aura (Only visible when trip is active)
    if (_isTripActive) {
      markers.add(
        Marker(
        point: busLoc,
        width: 72,
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1.25),
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4), width: 1.5),
                    ),
                  ),
                );
              },
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                boxShadow: const [
                  BoxShadow(color: Color(0x662563EB), blurRadius: 10, spreadRadius: 2),
                ],
              ),
            ),
            Transform.rotate(
              angle: _vehicleHeading * math.pi / 180,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 3,
                      child: Container(
                        width: 12,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: const [BoxShadow(color: Color(0xFF38BDF8), blurRadius: 6)],
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    }

    for (final poi in _poiMarkersData) {
      final lat = (poi['lat'] as num).toDouble();
      final lon = (poi['lon'] as num).toDouble();
      final title = (poi['primary_title'] ?? poi['name'] ?? 'Place').toString();
      final distKm = poi['distance_km'] != null ? "${(poi['distance_km'] as double).toStringAsFixed(1)} km" : "";

      IconData categoryIcon = Icons.place;
      Color categoryColor = Colors.orange;

      if (_activePoiCategory == 'petrol') {
        categoryIcon = Icons.local_gas_station;
        categoryColor = Colors.orange;
      } else if (_activePoiCategory == 'food') {
        categoryIcon = Icons.restaurant;
        categoryColor = Colors.redAccent;
      } else if (_activePoiCategory == 'hospital') {
        categoryIcon = Icons.local_hospital;
        categoryColor = Colors.pink;
      } else if (_activePoiCategory == 'mechanic') {
        categoryIcon = Icons.build;
        categoryColor = Colors.blue;
      } else if (_activePoiCategory == 'parking') {
        categoryIcon = Icons.local_parking;
        categoryColor = Colors.purple;
      }

      final String detourInfo = (poi['detour_text'] ?? '').toString();
      final String badgeSubtitle = detourInfo.isNotEmpty ? "$distKm • $detourInfo" : distKm;

      markers.add(
        Marker(
          point: LatLng(lat, lon),
          width: 160,
          height: 52,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _searchedMarkerLoc = LatLng(lat, lon);
                _searchedLocationName = (poi['display_name'] ?? title).toString();
                _showDestinationCard = true;
              });
              _calculateDirections();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Text(
                    badgeSubtitle.isNotEmpty ? "$title ($badgeSubtitle)" : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(categoryIcon, color: categoryColor, size: 24),
              ],
            ),
          ),
        ),
      );
    }

    if (_searchedMarkerLoc != null) {
      markers.add(
        Marker(
          point: _searchedMarkerLoc!,
          width: 140,
          height: 54,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _showDestinationCard = true;
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Text(
                    _searchedLocationName.length > 20
                        ? "${_searchedLocationName.substring(0, 20)}..."
                        : _searchedLocationName,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(Icons.location_on, color: Colors.redAccent, size: 28),
              ],
            ),
          ),
        ),
      );
    }

    // Render Clickable Route Badges on map canvas
    if (_navigationRoutePaths.isNotEmpty && _navigationRouteInfos.isNotEmpty) {
      for (int rIdx = 0; rIdx < _navigationRoutePaths.length; rIdx++) {
        final path = _navigationRoutePaths[rIdx];
        if (path.length < 2) continue;

        final midIdx = (path.length / 2).floor().clamp(0, path.length - 1);
        final midPoint = path[midIdx];
        final info = rIdx < _navigationRouteInfos.length ? _navigationRouteInfos[rIdx] : {'label': 'Route $rIdx', 'duration_mins': 10, 'distance_km': 5.0};
        final bool isSelected = _selectedRouteIndex == rIdx;

        markers.add(
          Marker(
            point: midPoint,
            width: 130,
            height: 36,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedRouteIndex = rIdx;
                  _navigationPolylinePoints = path;
                  _navDistanceKm = (info['distance_km'] as num).toDouble();
                  _navDurationMins = (info['duration_mins'] as num).toInt();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? Icons.bolt : Icons.alt_route,
                      size: 12,
                      color: isSelected ? Colors.amberAccent : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${info['duration_mins']} mins (${info['distance_km']} km)",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    if (_selectedDestinationLatLng != null) {
      markers.add(
        Marker(
          point: _selectedDestinationLatLng!,
          width: 150,
          height: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isCustomDestinationLocked ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isCustomDestinationLocked ? Icons.lock_rounded : Icons.pin_drop_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isCustomDestinationLocked ? "DESTINATION LOCKED" : "DESTINATION PIN",
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 30),
            ],
          ),
        ),
      );
    }

    if (_isAutoFollowVehicle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isAutoFollowVehicle) {
          _mapController.move(busLoc, _zoomLevel);
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 750;
        final double mapCanvasHeight = isMobile ? 460.0 : 620.0;

        return Container(
          height: mapCanvasHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [BoxShadow(color: Color(0xFFF1F5F9), blurRadius: 8, offset: Offset(0, 4))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: busLoc,
                  initialZoom: _zoomLevel,
                  minZoom: 1.0,
                  maxZoom: 18.5,
                  onTap: (tapPosition, point) => _onMapTapped(point),
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture && _isAutoFollowVehicle) {
                      setState(() {
                        _isAutoFollowVehicle = false;
                      });
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: _getMapTileUrl(),
                    userAgentPackageName: "com.edushamiit.admin",
                    maxNativeZoom: 18,
                    maxZoom: 19,
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 4.0,
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  if (_navigationRoutePaths.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        for (int rIdx = 0; rIdx < _navigationRoutePaths.length; rIdx++)
                          if (rIdx != _selectedRouteIndex)
                            Polyline(
                              points: _navigationRoutePaths[rIdx],
                              strokeWidth: 4.0,
                              color: const Color(0xFF94A3B8),
                            ),
                        Polyline(
                          points: _navigationRoutePaths[_selectedRouteIndex.clamp(0, _navigationRoutePaths.length - 1)],
                          strokeWidth: 6.0,
                          color: const Color(0xFF2563EB),
                          borderColor: const Color(0xFF1E40AF),
                          borderStrokeWidth: 2.0,
                        ),
                      ],
                    )
                  else if (_navigationPolylinePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _navigationPolylinePoints,
                          strokeWidth: 6.0,
                          color: const Color(0xFF2563EB),
                          borderColor: const Color(0xFF1E40AF),
                          borderStrokeWidth: 2.0,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: markers,
                  ),
                ],
              ),

              // Click Map Tap Mode Toggle Pill Button
              if (_selectedDestinationLatLng == null)
                Positioned(
                  left: 12,
                  top: 52,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _enableClickToSetDestination = !_enableClickToSetDestination;
                        if (!_enableClickToSetDestination && !_isCustomDestinationLocked) {
                          _selectedDestinationLatLng = null;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: _enableClickToSetDestination
                            ? const Color(0xFF10B981)
                            : const Color(0xFF0F172A).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _enableClickToSetDestination ? const Color(0xFFA7F3D0) : Colors.white24,
                          width: 1,
                        ),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _enableClickToSetDestination ? Icons.touch_app_rounded : Icons.touch_app_outlined,
                            color: _enableClickToSetDestination ? Colors.white : Colors.amberAccent,
                            size: 12,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _enableClickToSetDestination ? "Tap Map Destination: ON" : "Tap Map Destination: OFF",
                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (_selectedDestinationLatLng != null)
                _buildCustomDestinationOverlayCard(),

              // 1. Top-Left Floating Places Search & POI Filter Toggle
              Positioned(
                left: 12,
                top: 12,
                right: _showMapTypeMenu ? 140 : 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              onSubmitted: _searchLocation,
                              decoration: InputDecoration(
                                hintText: _isSearchingLocation ? "Searching..." : "Search map...",
                                hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                prefixIcon: _isSearchingLocation
                                    ? const Padding(
                                        padding: EdgeInsets.all(9.0),
                                        child: SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                                        ),
                                      )
                                    : const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _showPoiFilterMenu = !_showPoiFilterMenu;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: _showPoiFilterMenu
                                    ? const Color(0xFF2563EB)
                                    : (_activePoiCategory != null ? const Color(0xFF4F46E5) : Colors.white),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _showPoiFilterMenu || _activePoiCategory != null ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                ),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isEmergencySearchMode ? Icons.emergency : Icons.tune_rounded,
                                    size: 14,
                                    color: _showPoiFilterMenu || _activePoiCategory != null ? Colors.white : const Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _activePoiCategory != null
                                        ? _activePoiCategory!.toUpperCase()
                                        : (_isEmergencySearchMode ? "🚨 Emergency" : "Places"),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _showPoiFilterMenu || _activePoiCategory != null ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    _showPoiFilterMenu ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    size: 14,
                                    color: _showPoiFilterMenu || _activePoiCategory != null ? Colors.white : const Color(0xFF64748B),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_showPoiFilterMenu) ...[
                      const SizedBox(height: 6),
                      _buildPoiCategoryChips(),
                    ],

                    if (_searchResults.isNotEmpty) _buildAutocompleteDropdown(),
                  ],
                ),
              ),

              // 2. Top-Right Floating Map Type Layers FAB
              Positioned(
                right: 12,
                top: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _showMapTypeMenu = !_showMapTypeMenu;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _showMapTypeMenu ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.layers_rounded,
                                size: 16,
                                color: _showMapTypeMenu ? Colors.white : const Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _mapType,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _showMapTypeMenu ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_showMapTypeMenu) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: 124,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            _buildMapSidebarControl(
                              Icons.traffic_rounded,
                              "Traffic",
                              _showTraffic,
                              () => setState(() => _showTraffic = !_showTraffic),
                            ),
                            _buildMapSidebarControl(
                              Icons.layers_outlined,
                              "Satellite",
                              _mapType == "Satellite",
                              () => setState(() {
                                _mapType = "Satellite";
                                _showMapTypeMenu = false;
                              }),
                            ),
                            _buildMapSidebarControl(
                              Icons.terrain_rounded,
                              "Terrain",
                              _mapType == "Terrain",
                              () => setState(() {
                                _mapType = "Terrain";
                                _showMapTypeMenu = false;
                              }),
                            ),
                            _buildMapSidebarControl(
                              Icons.map_rounded,
                              "Standard",
                              _mapType == "Standard",
                              () => setState(() {
                                _mapType = "Standard";
                                _showMapTypeMenu = false;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 3. Bottom-Left Compact Speedometer Badge
              Positioned(
                left: 12,
                bottom: 12,
                child: _buildSpeedometerHud(),
              ),

              if (_isNavigating) _buildActiveNavigationBanner(),
              if (_showDestinationCard && !_isNavigating)
                _buildDestinationInfoCard(busLoc),

              // 4. Bottom-Right Floating Controls Column (Re-Center + Micro Zoom + Hide Toggle)
              Positioned(
                right: 10,
                bottom: 10,
                child: _hideMapControls
                    ? InkWell(
                        onTap: () => setState(() => _hideMapControls = false),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          child: const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF2563EB)),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Hide Toggle Button
                          InkWell(
                            onTap: () => setState(() => _hideMapControls = true),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 26,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                              ),
                              child: const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF64748B)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Compact Re-Center Button
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isAutoFollowVehicle = true;
                                _zoomLevel = 18.0;
                              });
                              _mapController.move(busLoc, _zoomLevel);
                            },
                            borderRadius: BorderRadius.circular(15),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: _isAutoFollowVehicle ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                              ),
                              child: Icon(
                                _isAutoFollowVehicle ? Icons.my_location_rounded : Icons.gps_fixed_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Ultra-Micro Zoom Controls (Total: 24px wide x 41px tall)
                          Container(
                            width: 24,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    _zoomLevel = (_zoomLevel + 1.0).clamp(1.0, 18.5);
                                    _mapController.move(busLoc, _zoomLevel);
                                  },
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                  child: const SizedBox(
                                    width: 24,
                                    height: 20,
                                    child: Icon(Icons.add, size: 11, color: Color(0xFF1E293B)),
                                  ),
                                ),
                                Container(height: 1, color: const Color(0xFFE2E8F0), width: 14),
                                InkWell(
                                  onTap: () {
                                    _zoomLevel = (_zoomLevel - 1.0).clamp(1.0, 18.5);
                                    _mapController.move(busLoc, _zoomLevel);
                                  },
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(5)),
                                  child: const SizedBox(
                                    width: 24,
                                    height: 20,
                                    child: Icon(Icons.remove, size: 11, color: Color(0xFF1E293B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomDestinationOverlayCard() {
    if (_selectedDestinationLatLng == null) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      right: 50,
      bottom: 48,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isCustomDestinationLocked ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _isCustomDestinationLocked ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isCustomDestinationLocked ? Icons.lock_rounded : Icons.pin_drop_rounded,
                      color: _isCustomDestinationLocked ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isGeocodingSelectedPoint ? "Locating..." : _selectedDestinationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          "${_selectedDestinationDistanceKm.toStringAsFixed(1)} km • ${_selectedDestinationDurationMins} mins away",
                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isCustomDestinationLocked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                      ),
                      onPressed: _isCustomDestinationLocked ? _clearCustomDestination : _lockCustomDestination,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_isCustomDestinationLocked ? Icons.lock_open_rounded : Icons.navigation_rounded, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            _isCustomDestinationLocked ? "Reset" : "Lock & Go",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: _clearCustomDestination,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteProgressCard() {
    final totalCount = _students.length;
    final pickedCount = _getOnBoardCount() + _getDroppedCount();
    final progressVal =
        totalCount > 0 ? (pickedCount / totalCount).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFF1F5F9), blurRadius: 4, offset: Offset(0, 2))
          ]),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Route Progress",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: progressVal,
                    strokeWidth: 10,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: const Color(0xFF10B981),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("${(progressVal * 100).toInt()}%",
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B))),
                    const Text("Completed",
                        style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildProgressIndicatorRow(Colors.green, "Picked",
              "${_getOnBoardCount() + _getDroppedCount()} Students"),
          const SizedBox(height: 8),
          _buildProgressIndicatorRow(
              Colors.blue, "Dropped", "${_getDroppedCount()} Students"),
          const SizedBox(height: 8),
          _buildProgressIndicatorRow(
              Colors.purple, "On Board", "${_getOnBoardCount()} Students"),
          const SizedBox(height: 8),
          _buildProgressIndicatorRow(
              Colors.grey, "Yet to Pick", "${_getYetToPickCount()} Students"),
        ],
      ),
    );
  }

  Widget _buildProgressIndicatorRow(Color color, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
          ],
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFF1F5F9), blurRadius: 4, offset: Offset(0, 2))
          ]),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Quick Actions",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: [
              _buildQuickActionBtn(
                  Icons.check_box_outlined,
                  Colors.green,
                  "Mark All Picked",
                  "At Current Stop",
                  () => _markAllStudentsStatusAtCurrentStop('picked')),
              _buildQuickActionBtn(
                  Icons.assignment_turned_in_outlined,
                  Colors.blue,
                  "Mark All Dropped",
                  "At Current Stop",
                  () => _markAllStudentsStatusAtCurrentStop('dropped')),
              _buildQuickActionBtn(Icons.reorder, Colors.purple,
                  "Reorder Stops", "Drag to Reorder", _reorderStops),
              _buildQuickActionBtn(Icons.share_outlined, Colors.indigo,
                  "Share ETA", "With School", _shareETA),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn(IconData icon, Color color, String title,
      String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(fontSize: 8, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteStopsTableCard() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFF1F5F9), blurRadius: 4, offset: Offset(0, 2))
          ]),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isMobile = constraints.maxWidth < 650;
              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Route Stops (${_stops.length})",
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B))),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEEF2FF),
                            foregroundColor: const Color(0xFF4F46E5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                          ),
                          onPressed: _reorderStops,
                          icon: const Icon(Icons.reorder, size: 14),
                          label: const Text("Reorder",
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildStopFilterTab(
                              "All (${_stops.length})",
                              _activeStopTab == 0,
                              () => setState(() => _activeStopTab = 0)),
                          _buildStopFilterTab("Upcoming", _activeStopTab == 1,
                              () => setState(() => _activeStopTab = 1)),
                          _buildStopFilterTab("Completed", _activeStopTab == 2,
                              () => setState(() => _activeStopTab = 2)),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Route Stops (${_stops.length})",
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B))),
                  Row(
                    children: [
                      _buildStopFilterTab(
                          "All (${_stops.length})",
                          _activeStopTab == 0,
                          () => setState(() => _activeStopTab = 0)),
                      _buildStopFilterTab("Upcoming", _activeStopTab == 1,
                          () => setState(() => _activeStopTab = 1)),
                      _buildStopFilterTab("Completed", _activeStopTab == 2,
                          () => setState(() => _activeStopTab = 2)),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEF2FF),
                          foregroundColor: const Color(0xFF4F46E5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        onPressed: _reorderStops,
                        icon: const Icon(Icons.reorder, size: 14),
                        label: const Text("Reorder Stops",
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    ],
                  )
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          if (_stops.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.schedule_rounded, size: 32, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Waiting for Scheduled Trips",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "No upcoming route runs are currently scheduled on the calendar.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // HORIZONTAL SCROLL ENVELOPE TO PREVENT SYSTEM SCREEN FROM BREAKING
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 830),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Table Header Row
                    Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom:
                                BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
                      ),
                      child: const Row(
                        children: [
                        SizedBox(
                            width: 50,
                            child: Text("#",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B)))),
                        SizedBox(
                            width: 230,
                            child: Text("Stop Name",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B)))),
                        SizedBox(
                            width: 100,
                            child: Text("Pick / Drop",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B)))),
                        SizedBox(
                            width: 90,
                            child: Text("Students",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B)))),
                        SizedBox(
                            width: 100,
                            child: Text("ETA / Time",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B)))),
                        SizedBox(
                            width: 90,
                            child: Text("Status",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B)))),
                        SizedBox(
                            width: 80,
                            child: Text("Action",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B)))),
                      ],
                    ),
                  ),

                  // REORDERABLE LIST VIEW FOR UPCOMING STOPS
                  SizedBox(
                    width: 830,
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _stops.length,
                      buildDefaultDragHandles:
                          false, // drag handle enabled *only* for upcoming stops
                      onReorder: (oldIdx, newIdx) async {
                        // REORDERING CAN'T HAPPEN FOR COMPLETED STOPS
                        if (oldIdx < _currentStopIndex ||
                            newIdx <= _currentStopIndex) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text("Cannot reorder completed stops!"),
                                backgroundColor: Colors.red),
                          );
                          return;
                        }

                        setState(() {
                          if (newIdx > oldIdx) {
                            newIdx -= 1;
                          }
                          final Map<String, dynamic> item =
                              _stops.removeAt(oldIdx);
                          _stops.insert(newIdx, item);

                          _syncCurrentStopIndex();
                        });

                        try {
                          if (_activeTrip != null) {
                            final stopIds =
                                _stops.map((s) => s['id'] as String).toList();
                            await ApiService().post(
                                '/transport/driver/trips/${_activeTrip!['id']}/reorder',
                                {"stop_ids": stopIds});
                          }
                        } catch (e) {
                          debugPrint("Reorder DB update error: $e");
                        }

                        // ON REORDER ETA AUTOMATICALLY UPDATES WITH OSM DIRECTION API
                        await _recalculateETAsWithOSRM();
                      },
                      itemBuilder: (context, index) {
                        final s = _stops[index];
                        if (!_shouldShowStop(index))
                          return Container(key: ValueKey(s['id']));

                        final isCompleted = s['status'] == "completed";

                        return ReorderableDragStartListener(
                          key: ValueKey(s['id']),
                          index: index,
                          enabled:
                              !isCompleted, // Disabled dragging for completed stops
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedStopIndexForChecklist = index;
                                _expandedStopIndex =
                                    (_expandedStopIndex == index) ? -1 : index;
                                _syncSelectedMap();
                              });
                            },
                            child: Column(
                              children: [
                                _buildStopRowContainer(index, s),
                                if (index == _expandedStopIndex)
                                  _buildStopExpandedDetailsRow(index, s),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTableFooterTotal(Icons.people_outline, "Total Students",
                  "${_students.length}"),
              _buildTableFooterTotal(Icons.check_box_outlined, "Picked",
                  "${_getOnBoardCount() + _getDroppedCount()}"),
              _buildTableFooterTotal(
                  Icons.archive_outlined, "Dropped", "${_getDroppedCount()}"),
              _buildTableFooterTotal(Icons.cancel_presentation_outlined,
                  "Yet to Pick", "${_getYetToPickCount()}"),
            ],
          ),
        ],
      ],
    ),
  );
  }

  Widget _buildStopRowContainer(int index, Map<String, dynamic> s) {
    final isCompleted = s['status'] == "completed";
    final isCurrent = index == _currentStopIndex;
    final isSelected = index == _selectedStopIndexForChecklist;

    // 100% Real Student Count from Database / State for this stop
    final int studentsAtStopCount =
        _students.where((st) => st['stop_id'] == s['id']).length;
    final String studentsCountStr = "$studentsAtStopCount";

    // 100% Real Pick / Drop Count Logic
    int pickedAtStop = _students
        .where((st) =>
            st['stop_id'] == s['id'] &&
            (st['status'] == 'picked' || st['status'] == 'dropped'))
        .length;
    int droppedAtStop = _students
        .where((st) =>
            st['status'] == 'dropped' &&
            (st['drop_stop_id'] == s['id'] ||
                (st['drop_stop_id'] == null && st['stop_id'] == s['id'])))
        .length;

    final String pickDropStr = "$pickedAtStop / $droppedAtStop";

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFFAF5FF)
            : isCurrent
                ? const Color(0xFFF8FAFC)
                : Colors.transparent,
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          // Index and Drag Handle indicator
          SizedBox(
            width: 50,
            child: Row(
              children: [
                if (!isCompleted && _isTripActive)
                  const Icon(Icons.drag_indicator,
                      size: 14, color: Color(0xFF94A3B8))
                else
                  const SizedBox(width: 14),
                const SizedBox(width: 4),
                CircleAvatar(
                  radius: 8,
                  backgroundColor: isCompleted
                      ? Colors.green.shade50
                      : isCurrent
                          ? const Color(0xFFF3E8FF)
                          : const Color(0xFFF1F5F9),
                  child: Text(
                    index == 0
                        ? "S"
                        : index == _stops.length - 1
                            ? "E"
                            : "$index",
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: isCompleted
                          ? Colors.green
                          : isCurrent
                              ? Colors.purple
                              : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stop Name
          SizedBox(
            width: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['stop_name'] ?? "",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    color: isCurrent
                        ? const Color(0xFF6B21A8)
                        : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  index == 0
                      ? "Depot"
                      : index == _stops.length - 1
                          ? "School"
                          : "Pickup Point",
                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),

          // Pick / Drop Count
          SizedBox(
            width: 100,
            child: Text(
              pickDropStr,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.green : const Color(0xFF1E293B)),
            ),
          ),

          // Students count present for stoppage
          SizedBox(
            width: 90,
            child: Text(
              studentsCountStr,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.green : const Color(0xFF1E293B)),
            ),
          ),

          // ETA
          SizedBox(
            width: 100,
            child: Text(s['estimated_arrival'] ?? "",
                style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
          ),

          // Status Box
          SizedBox(
            width: 90,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFFDCFCE7)
                    : isCurrent
                        ? const Color(0xFFF3E8FF)
                        : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.access_time,
                    size: 10,
                    color: isCompleted
                        ? Colors.green
                        : isCurrent
                            ? Colors.purple
                            : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCompleted ? "Completed" : "Upcoming",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isCompleted
                          ? Colors.green
                          : isCurrent
                              ? Colors.purple
                              : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expand Action
          SizedBox(
            width: 80,
            child: Icon(
                index == _expandedStopIndex
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildStopExpandedDetailsRow(int index, Map<String, dynamic> s) {
    final TextEditingController etaEditController =
        TextEditingController(text: s['estimated_arrival'] ?? "07:00 AM");
    final isCompleted = s['status'] == "completed";

    return Container(
      color: const Color(0xFFFAF5FF),
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          const SizedBox(width: 50),
          SizedBox(
            width: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Selected Stop Info",
                    style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold)),
                Text(s['stop_name'] ?? "",
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B21A8))),
                const Text("0.8 km away  •  ETA: 3 min",
                    style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                const Text("Next Stop Point",
                    style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold)),
                Text(
                    index + 1 < _stops.length
                        ? _stops[index + 1]['stop_name']
                        : "School Depot",
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B))),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ETA EDIT ONLY VISIBLE FOR UPCOMING STOPS
          SizedBox(
            width: 220,
            child: !isCompleted
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Update ETA",
                          style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: etaEditController,
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero),
                              ),
                            ),
                            const Icon(Icons.edit_calendar_outlined,
                                size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 28),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {
                          _saveStopETA(index, etaEditController.text);
                        },
                        child: const Text("Save ETA",
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ETA Update Locked",
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("This stop has already been completed.",
                          style: TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
          ),

          const SizedBox(width: 20),
          SizedBox(
            width: 140,
            child: !isCompleted
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMiniActionBtn(
                          Icons.check_box_outlined,
                          Colors.green,
                          "Mark All Picked",
                          () => _markAllStudentsStatusAtCurrentStop('picked')),
                      const SizedBox(height: 6),
                      _buildMiniActionBtn(
                          Icons.archive_outlined,
                          Colors.blue,
                          "Mark All Dropped",
                          () => _markAllStudentsStatusAtCurrentStop('dropped')),
                      const SizedBox(height: 6),
                      _buildMiniActionBtn(
                          Icons.check_circle_outline,
                          Colors.indigo,
                          "Complete Stop",
                          () => _completeStopAtIndex(index)),
                    ],
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Actions Locked",
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("Stoppage tasks completed.",
                          style: TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsChecklistCard() {
    if (_stops.isEmpty || _selectedStopIndexForChecklist >= _stops.length) {
      return Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFFF1F5F9), blurRadius: 4, offset: Offset(0, 2))
            ]),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Students Checklist",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: const [
                  Icon(Icons.schedule_rounded, size: 32, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text("Waiting for Scheduled Trips",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155))),
                  SizedBox(height: 4),
                  Text("No active route run or stop currently selected.",
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final currentStudents = _getStudentsAtSelectedStop();

    // Filter On Board and Dropped students specifically assigned to the selected stop
    final String selectedStopId = _stops[_selectedStopIndexForChecklist]['id'];
    final onBoard = _students.where((s) => s['status'] == 'picked').toList();
    final dropped = _students
        .where((s) =>
            s['status'] == 'dropped' &&
            (s['drop_stop_id'] == selectedStopId ||
                s['stop_id'] == selectedStopId))
        .toList();

    final bool isStopCompleted =
        _stops[_selectedStopIndexForChecklist]['status'] == 'completed';
    int selectedCount = _selectedStudents.values.where((v) => v).length;

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFF1F5F9), blurRadius: 4, offset: Offset(0, 2))
          ]),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Students at Selected Stop",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                    "Stop ${_selectedStopIndexForChecklist + 1} of ${_stops.length}",
                    style: const TextStyle(
                        color: Colors.purple,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _stops[_selectedStopIndexForChecklist]['stop_name'] ??
                            "",
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis),
                    const Text("0.8 km away  •  ETA: 3 min",
                        style:
                            TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("To Pick: ${currentStudents.length}",
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B))),
                  Text("On Board: ${onBoard.length}",
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B))),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _studentTabController,
            labelColor: const Color(0xFF4F46E5),
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            indicatorColor: const Color(0xFF4F46E5),
            tabs: [
              Tab(text: "To Pick (${currentStudents.length})"),
              Tab(text: "On Board (${onBoard.length})"),
              Tab(text: "Dropped (${dropped.length})"),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 250,
            child: TabBarView(
              controller: _studentTabController,
              children: [
                _buildStudentsList(currentStudents,
                    isSelectable: !isStopCompleted, isToPick: true),
                _buildStudentsList(onBoard,
                    isSelectable: !isStopCompleted, isToPick: false),
                _buildStudentsList(dropped,
                    isSelectable: false, isToPick: false),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isStopCompleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "This stoppage is completed. Student boarding and drop-off are locked.",
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
            )
          else if (_studentTabController.index == 0)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _updateStudentStatusBulk('picked'),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Text("Mark $selectedCount Picked",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            )
          else if (_studentTabController.index == 1)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _updateStudentStatusBulk('dropped'),
                icon: const Icon(Icons.archive_outlined, size: 16),
                label: Text("Mark $selectedCount Dropped",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String? url, String name, {double radius = 16}) {
    final initials = name
        .trim()
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();
    final displayText = initials.isNotEmpty
        ? (initials.length > 2 ? initials.substring(0, 2) : initials)
        : "?";

    final hasUrl = url != null && url.trim().isNotEmpty && url.trim() != "null" && url.trim() != "—";

    if (hasUrl) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url.trim()),
      );
    }

    // Choose a color based on the first letter to make it colorful and premium
    final colors = [
      const Color(0xFF4F46E5), // Indigo
      const Color(0xFF0EA5E9), // Sky Blue
      const Color(0xFF10B981), // Emerald Green
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
    ];
    final colorIndex =
        name.isNotEmpty ? (name.codeUnitAt(0) % colors.length) : 0;

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors[colorIndex].withValues(alpha: 0.15),
      child: Text(
        displayText,
        style: TextStyle(
            fontSize: radius * 0.7,
            color: colors[colorIndex],
            fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStudentsList(List<dynamic> students,
      {bool isSelectable = false, bool isToPick = false}) {
    if (students.isEmpty) {
      return const Center(
          child: Text("No students in this tab",
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B))));
    }

    return Column(
      children: [
        if (isSelectable)
          Row(
            children: [
              Checkbox(
                value: _selectedStudents.values.where((v) => v).length ==
                        students.length &&
                    students.isNotEmpty,
                onChanged: (val) {
                  setState(() {
                    for (var s in students) {
                      _selectedStudents[s['id']] = val ?? false;
                    }
                  });
                },
                activeColor: const Color(0xFF4F46E5),
              ),
              const Text("Select All",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569))),
            ],
          ),
        Expanded(
          child: ListView.separated(
            itemCount: students.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final s = students[index];
              final id = s['id']!;
              final stopIndex =
                  _stops.indexWhere((st) => st['id'] == s['stop_id']);

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    if (isSelectable)
                      Checkbox(
                        value: _selectedStudents[id] ?? false,
                        onChanged: (val) {
                          setState(() {
                            _selectedStudents[id] = val ?? false;
                          });
                        },
                        activeColor: const Color(0xFF4F46E5),
                      ),
                    const SizedBox(width: 4),
                    _buildUserAvatar(s['avatar_url'], s['full_name'] ?? "",
                        radius: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s['full_name'] ?? "",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Color(0xFF1E293B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (stopIndex >= 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: const Color(0xFFE9D5FF)),
                                  ),
                                  child: Text(
                                    "Stop #${stopIndex + 1}",
                                    style: const TextStyle(
                                        color: Color(0xFF7E22CE),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stopIndex >= 0
                                ? "${_stops[stopIndex]['stop_name'] ?? ''} • Class ${s['class_name'] ?? ''}"
                                : "Class ${s['class_name'] ?? ''} • Roll ${s['roll_number'] ?? ''}",
                            style: const TextStyle(
                                color: Color(0xFF64748B), fontSize: 9),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(s['phone'] ?? "",
                              style: const TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 9)),
                        ],
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.phone,
                            color: Color(0xFF475569), size: 14),
                        onPressed: () {},
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        padding: EdgeInsets.zero,
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMapSidebarControl(
      IconData icon, String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        color: active ? const Color(0xFFEEF2FF) : Colors.transparent,
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color:
                    active ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildStopFilterTab(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEEF2FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  bool _shouldShowStop(int index) {
    if (_activeStopTab == 0) return true;
    final isCompleted = _stops[index]['status'] == 'completed';
    if (_activeStopTab == 1) return !isCompleted;
    if (_activeStopTab == 2) return isCompleted;
    return true;
  }

  Widget _buildTableFooterTotal(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 8,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.bold)),
            Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B))),
          ],
        )
      ],
    );
  }

  Widget _buildMiniActionBtn(
      IconData icon, Color color, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControlPanel() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: _hideBottomControls ? 4.0 : 6.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 750;

          final statusRow = Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_rounded, color: Color(0xFF059669), size: 10),
                        SizedBox(width: 3),
                        Text("Connected", style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 9)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gps_fixed_rounded, color: Color(0xFF059669), size: 10),
                        SizedBox(width: 3),
                        Text("GPS: Signal Strong", style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _hideBottomControls = !_hideBottomControls),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _hideBottomControls ? "Controls" : "Hide",
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _hideBottomControls ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 14,
                        color: const Color(0xFF475569),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );

          if (_hideBottomControls) {
            return statusRow;
          }

          final bool isCompleted = _stops.isNotEmpty && _stops.every((s) => s['status'] == 'completed');
          final bool hasSched = (_isTripActive || _activeTrip != null || _selectedRoute != null);

          final String startBtnText = isCompleted
              ? "Trip Completed"
              : (_isTripActive
                  ? "End Route"
                  : (hasSched ? "Start Route" : "Waiting for Schedule"));
          final Color startBtnColor = isCompleted
              ? const Color(0xFF059669)
              : (_isTripActive
                  ? const Color(0xFFEF4444)
                  : (hasSched ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8)));
          final IconData startBtnIcon = isCompleted
              ? Icons.check_circle_rounded
              : (_isTripActive
                  ? Icons.stop_circle_rounded
                  : (hasSched ? Icons.play_arrow_rounded : Icons.schedule_rounded));
          final VoidCallback? startBtnAction = isCompleted
              ? null
              : (_isTripActive
                  ? _endTrip
                  : (hasSched ? () => _startTrip() : null));

          if (isMobile) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                statusRow,
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: startBtnColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 1.5,
                          ),
                          onPressed: startBtnAction,
                          icon: Icon(startBtnIcon, size: 14),
                          label: Text(
                            startBtnText,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5),
                          ),
                        ),
                      ),
                    ),
                    if (_isTripActive) ...[
                      const SizedBox(width: 5),
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 32,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isTripPaused ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 1.5,
                            ),
                            onPressed: _togglePauseTrip,
                            icon: Icon(_isTripPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 13),
                            label: Text(_isTripPaused ? "Resume" : "Pause", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 5),
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            backgroundColor: const Color(0xFFFEF2F2),
                            side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isTripActive ? _triggerEmergency : null,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFEF4444)),
                              SizedBox(width: 2),
                              Text("SOS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9.5, color: Color(0xFFEF4444))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              statusRow,
              Row(
                children: [
                  SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: startBtnColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 1.5,
                      ),
                      onPressed: startBtnAction,
                      icon: Icon(startBtnIcon, size: 14),
                      label: Text(startBtnText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5)),
                    ),
                  ),
                  if (_isTripActive) ...[
                    const SizedBox(width: 5),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isTripPaused ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _togglePauseTrip,
                        icon: Icon(_isTripPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 13),
                        label: Text(_isTripPaused ? "Resume" : "Pause", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                    ),
                  ],
                  const SizedBox(width: 5),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isTripActive ? _triggerEmergency : null,
                      icon: const Icon(Icons.warning_amber_rounded, size: 13),
                      label: const Text("Emergency SOS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFF4F46E5), width: 1.2),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isTripActive ? _triggerDeviation : null,
                      icon: const Icon(Icons.alt_route, size: 13),
                      label: const Text("Route Deviation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

