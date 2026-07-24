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

  final String _registrationNo = "UP16 ET 1234";
  final String _busNumber = "UP16 ET 1234";
  final String _startTime = "06:20";
  String _currentLocationName = "Sector 63 Bus Stop";
  String _nextStopName = "Sector 71 Crossing";

  final double _totalDistanceKm = 12.6;
  final double _coveredDistanceKm = 7.4;
  final int _elapsedMinutes = 18;
  final int _totalTimeMinutes = 35;

  // Selected stop index for checklist updating (Right side card)
  int _selectedStopIndexForChecklist = 4;

  // Tab controllers & pointers
  late TabController _studentTabController;
  int _activeStopTab = 0; // 0 = All, 1 = Upcoming, 2 = Completed
  int _currentStopIndex = 4; // default Noida Sector 71 Crossing
  int _expandedStopIndex = 4;

  // Map settings
  String _mapType = "Standard"; // Standard, Satellite, Terrain
  bool _showTraffic = true;
  double _zoomLevel = 13.5;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // Timer for GPS simulation
  Timer? _telemetryTimer;
  double _busPositionRatio = 0.38;
  List<LatLng> _routePoints = [];

  // Bulk selection maps
  final Map<String, bool> _selectedStudents = {};

  // ─── RICH DEFAULT SAMPLE DATA ──────────────────────────────────────────

  final List<Map<String, dynamic>> _sampleStops = [
    {
      "id": "s0",
      "stop_name": "Sector 62 Community Center",
      "latitude": 28.6298,
      "longitude": 77.3705,
      "stop_order": 1,
      "estimated_arrival": "06:45 AM",
      "status": "completed",
      "actual_arrival": "06:44 AM"
    },
    {
      "id": "s1",
      "stop_name": "Fortune Residency",
      "latitude": 28.6275,
      "longitude": 77.3735,
      "stop_order": 2,
      "estimated_arrival": "06:52 AM",
      "status": "completed",
      "actual_arrival": "06:51 AM"
    },
    {
      "id": "s2",
      "stop_name": "Sector 63 Bus Stop",
      "latitude": 28.6250,
      "longitude": 77.3760,
      "stop_order": 3,
      "estimated_arrival": "06:58 AM",
      "status": "completed",
      "actual_arrival": "06:57 AM"
    },
    {
      "id": "s3",
      "stop_name": "Sunrise Apartments",
      "latitude": 28.6225,
      "longitude": 77.3785,
      "stop_order": 4,
      "estimated_arrival": "07:03 AM",
      "status": "completed",
      "actual_arrival": "07:04 AM"
    },
    {
      "id": "s4",
      "stop_name": "Sector 71 Crossing",
      "latitude": 28.6200,
      "longitude": 77.3810,
      "stop_order": 5,
      "estimated_arrival": "07:07 AM",
      "status": "pending",
      "actual_arrival": null
    },
    {
      "id": "s5",
      "stop_name": "Sector 72 Metro Station",
      "latitude": 28.6175,
      "longitude": 77.3835,
      "stop_order": 6,
      "estimated_arrival": "07:13 AM",
      "status": "pending",
      "actual_arrival": null
    },
    {
      "id": "s6",
      "stop_name": "Greenfield International School",
      "latitude": 28.6150,
      "longitude": 77.3860,
      "stop_order": 7,
      "estimated_arrival": "07:20 AM",
      "status": "pending",
      "actual_arrival": null
    },
    {
      "id": "s7",
      "stop_name": "ATS Village",
      "latitude": 28.6125,
      "longitude": 77.3885,
      "stop_order": 8,
      "estimated_arrival": "07:28 AM",
      "status": "pending",
      "actual_arrival": null
    },
    {
      "id": "s8",
      "stop_name": "Amrapali Silicon City",
      "latitude": 28.6100,
      "longitude": 77.3910,
      "stop_order": 9,
      "estimated_arrival": "07:34 AM",
      "status": "pending",
      "actual_arrival": null
    },
    {
      "id": "s9",
      "stop_name": "Greenfield School",
      "latitude": 28.6075,
      "longitude": 77.3935,
      "stop_order": 10,
      "estimated_arrival": "07:45 AM",
      "status": "pending",
      "actual_arrival": null
    },
  ];

  final List<Map<String, dynamic>> _sampleStudents = [
    {
      "id": "tp1",
      "full_name": "Asrav Sharma",
      "class_name": "9-A",
      "roll_number": "12",
      "phone": "9876543210",
      "avatar_url": "https://randomuser.me/api/portraits/men/32.jpg",
      "stop_id": "s4",
      "status": "yet_to_pick"
    },
    {
      "id": "tp2",
      "full_name": "Diya Singh",
      "class_name": "9-B",
      "roll_number": "25",
      "phone": "9876543211",
      "avatar_url": "https://randomuser.me/api/portraits/women/44.jpg",
      "stop_id": "s4",
      "status": "yet_to_pick"
    },
    {
      "id": "tp3",
      "full_name": "Rohan Verma",
      "class_name": "9-A",
      "roll_number": "31",
      "phone": "9876543212",
      "avatar_url": "https://randomuser.me/api/portraits/men/85.jpg",
      "stop_id": "s4",
      "status": "yet_to_pick"
    },
    {
      "id": "tp4",
      "full_name": "Sneha Gupta",
      "class_name": "8-C",
      "roll_number": "18",
      "phone": "9876543213",
      "avatar_url": "https://randomuser.me/api/portraits/women/12.jpg",
      "stop_id": "s4",
      "status": "yet_to_pick"
    },
    {
      "id": "tp5",
      "full_name": "Karan Yadav",
      "class_name": "9-B",
      "roll_number": "07",
      "phone": "9876543214",
      "avatar_url": "https://randomuser.me/api/portraits/men/22.jpg",
      "stop_id": "s4",
      "status": "yet_to_pick"
    },
    // On Board students
    {
      "id": "ob1",
      "full_name": "Aarav Patel",
      "class_name": "8-A",
      "roll_number": "05",
      "phone": "9876543220",
      "avatar_url": "https://randomuser.me/api/portraits/men/33.jpg",
      "stop_id": "s1",
      "status": "picked"
    },
    {
      "id": "ob2",
      "full_name": "Myra Kapoor",
      "class_name": "7-B",
      "roll_number": "14",
      "phone": "9876543221",
      "avatar_url": "https://randomuser.me/api/portraits/women/45.jpg",
      "stop_id": "s2",
      "status": "picked"
    },
    {
      "id": "ob3",
      "full_name": "Ananya Goel",
      "class_name": "9-C",
      "roll_number": "02",
      "phone": "9876543222",
      "avatar_url": "https://randomuser.me/api/portraits/women/46.jpg",
      "stop_id": "s2",
      "status": "picked"
    },
    {
      "id": "ob4",
      "full_name": "Vivaan Sen",
      "class_name": "8-B",
      "roll_number": "11",
      "phone": "9876543223",
      "avatar_url": "https://randomuser.me/api/portraits/men/34.jpg",
      "stop_id": "s3",
      "status": "picked"
    },
    // Dropped students
    {
      "id": "dr1",
      "full_name": "Aryan Gupta",
      "class_name": "10-A",
      "roll_number": "08",
      "phone": "9876543230",
      "avatar_url": "https://randomuser.me/api/portraits/men/37.jpg",
      "stop_id": "s0",
      "status": "dropped"
    },
    {
      "id": "dr2",
      "full_name": "Shanaya Kapoor",
      "class_name": "9-A",
      "roll_number": "22",
      "phone": "9876543231",
      "avatar_url": "https://randomuser.me/api/portraits/women/48.jpg",
      "stop_id": "s0",
      "status": "dropped"
    },
  ];

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
    _startRealGpsSpeedometer();
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

  // ─── INITIALIZATION & SYNC ──────────────────────────────────────────────

  Future<void> _initializeDashboard() async {
    debugPrint("[DRIVER_DASH] _initializeDashboard: Starting...");

    // Fetch routes (non-critical — don't let this block trip loading)
    try {
      final routesRes =
          await ApiService().get('/transport/driver/routes', useCache: false);
      if (routesRes['success'] == true) {
        _routes = routesRes['data'] ?? [];
        if (_routes.isNotEmpty) {
          _selectedRouteId = _routes[0]['id'];
        }
      }
    } catch (e) {
      debugPrint("[DRIVER_DASH] Routes fetch failed (non-critical): $e");
    }

    // Fetch active trip + state (critical — retry up to 3 times)
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            "[DRIVER_DASH] _checkActiveTrip attempt $attempt/$maxRetries");
        await _checkActiveTrip();
        if (_stops.isNotEmpty) {
          debugPrint(
              "[DRIVER_DASH] Data loaded successfully on attempt $attempt");
          break;
        }
      } catch (e) {
        debugPrint("[DRIVER_DASH] Attempt $attempt failed: $e");
      }

      if (_stops.isEmpty && attempt < maxRetries) {
        debugPrint("[DRIVER_DASH] Waiting 1.5s before retry...");
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
      }
    }

    // Final state update
    if (!mounted) return;
    if (_stops.isEmpty) {
      debugPrint(
          "[DRIVER_DASH] All retries exhausted. Falling back to sample data.");
      setState(() {
        _stops = List.from(_sampleStops);
        _students = List.from(_sampleStudents);
        _routePoints =
            _stops.map((s) => LatLng(s['latitude'], s['longitude'])).toList();
        _syncCurrentStopIndex();
        _syncSelectedMap();
        _isInitialLoading = false;
      });
    } else {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _checkActiveTrip() async {
    try {
      debugPrint("[DRIVER_DASH] _checkActiveTrip: Fetching active trip...");
      final activeRes = await ApiService()
          .get('/transport/driver/trips/active', useCache: false);
      debugPrint(
          "[DRIVER_DASH] _checkActiveTrip: Response = ${'success=${activeRes['success']}, hasData=${activeRes['data'] != null}'}");
      if (activeRes['success'] == true && activeRes['data'] != null) {
        _activeTrip = activeRes['data'];
        _isTripActive = true;
        _isTripPaused = _activeTrip!['status'] == 'paused';
        _selectedRouteId = _activeTrip!['transport_route_id'];
        debugPrint(
            "[DRIVER_DASH] _checkActiveTrip: Active trip ID = ${_activeTrip!['id']}, transport_route_id = $_selectedRouteId");

        await _loadTripState(_activeTrip!['id']);
        _startTelemetryBroadcasting();
      } else {
        debugPrint(
            "[DRIVER_DASH] _checkActiveTrip: No active trip found, using hardcoded sample data");
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

        debugPrint(
            "[DRIVER_DASH] _loadTripState: Got ${stopsFromDb.length} stops, ${studentsFromDb.length} students from DB");
        if (stopsFromDb.isNotEmpty) {
          debugPrint(
              "[DRIVER_DASH] _loadTripState: First stop = ${stopsFromDb[0]['stop_name']}, status = ${stopsFromDb[0]['status']}");
        }

        // Preserve transport_route_id from the active trip before overwriting
        final preservedTransportRouteId = _selectedRouteId;

        setState(() {
          _tripState = data;
          _activeTrip = data['trip'];
          // Restore transport_route_id which is NOT in the state endpoint response
          if (_activeTrip != null && preservedTransportRouteId != null) {
            _activeTrip!['transport_route_id'] = preservedTransportRouteId;
          }

          if (stopsFromDb.isNotEmpty) {
            _stops =
                stopsFromDb.map((s) => Map<String, dynamic>.from(s)).toList();
            debugPrint(
                "[DRIVER_DASH] _loadTripState: Replaced _stops with ${_stops.length} DB stops");
          } else {
            debugPrint(
                "[DRIVER_DASH] _loadTripState: WARNING - stopsFromDb is EMPTY, keeping hardcoded stops!");
          }
          if (studentsFromDb.isNotEmpty) {
            _students = studentsFromDb
                .map((s) => Map<String, dynamic>.from(s))
                .toList();
            debugPrint(
                "[DRIVER_DASH] _loadTripState: Replaced _students with ${_students.length} DB students");
          } else {
            debugPrint(
                "[DRIVER_DASH] _loadTripState: WARNING - studentsFromDb is EMPTY, keeping hardcoded students!");
          }

          _routePoints = _stops.map((s) {
            final lat = (s['latitude'] as num?)?.toDouble() ?? 28.6280;
            final lng = (s['longitude'] as num?)?.toDouble() ?? 77.3780;
            return LatLng(lat, lng);
          }).toList();

          _syncCurrentStopIndex();
          _syncSelectedMap();
        });
      } else {
        debugPrint(
            "[DRIVER_DASH] _loadTripState: API returned null/failed, keeping hardcoded data!");
      }
    } catch (e, st) {
      debugPrint("[DRIVER_DASH] Error loading trip state: $e");
      debugPrint("[DRIVER_DASH] Stack: $st");
    }
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

  // ─── TELEMETRY AND MAPPING ──────────────────────────────────────────────

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
          "speed": 35.5,
          "heading": 90.0,
          "accuracy_m": 5.0,
          "live_status": "on_route",
          "students_on_board": _getOnBoardCount()
        };

        if (_activeTrip != null) {
          await ApiService().post(
              '/transport/driver/trips/${_activeTrip!['id']}/location',
              payload);
        }

        setState(() {
          _busPositionRatio = (_currentStopIndex / _routePoints.length) + 0.03;
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
    return LatLng(lat, lng);
  }

  String _getMapTileUrl() {
    if (_mapType == "Satellite") {
      return "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}";
    } else if (_mapType == "Terrain") {
      return "https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png";
    }
    return "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
  }

  // Real GPS & Sensor Telemetry State
  double _currentSpeedKmh = 0.0;
  double _vehicleHeading = 0.0;
  bool _isAutoRerouting = false;
  StreamSubscription<Position>? _gpsPositionSubscription;
  LatLng? _lastGpsPosition;
  DateTime? _lastGpsTimestamp;

  void _startRealGpsSpeedometer() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
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
    final bool isOverSpeed = _currentSpeedKmh > 50.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))
        ],
        border: Border.all(
            color: isOverSpeed ? Colors.redAccent : const Color(0xFFE2E8F0),
            width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isOverSpeed
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentSpeedKmh.round().toString(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isOverSpeed
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF4F46E5),
                    ),
                  ),
                  const Text(
                    "KM/H",
                    style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "GPS LIVE SENSOR",
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _currentSpeedKmh > 0 ? "In Motion" : "Vehicle Stopped",
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B)),
              ),
            ],
          )
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

  void _onSearchChanged(String value) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final query = value.trim();
      try {
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5');
        final res = await http.get(url, headers: {
          'User-Agent': 'EduSHAMIIT-DriverApp/1.0',
        }).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final List<dynamic> data = jsonDecode(res.body);
          if (mounted) {
            setState(() {
              _searchResults = data
                  .map<Map<String, dynamic>>((e) => {
                        'display_name': e['display_name'] ?? '',
                        'lat': double.parse(e['lat'].toString()),
                        'lon': double.parse(e['lon'].toString()),
                        'name': e['name'] ??
                            e['display_name']?.toString().split(',').first ??
                            '',
                      })
                  .toList();
            });
          }
        }
      } catch (e) {
        debugPrint("Autocomplete search error: $e");
      }
    });
  }

  void _selectSearchSuggestion(Map<String, dynamic> item) {
    final lat = item['lat'] as double;
    final lon = item['lon'] as double;
    final displayName = item['display_name'] as String;
    final targetLoc = LatLng(lat, lon);

    _searchController.text = item['name'] ?? displayName.split(',').first;

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

    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5');
      final res = await http.get(url, headers: {
        'User-Agent': 'EduSHAMIIT-DriverApp/1.0',
      }).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          final first = data.first;
          final lat = double.parse(first['lat']);
          final lon = double.parse(first['lon']);
          final displayName = first['display_name'] ?? query;

          final targetLoc = LatLng(lat, lon);
          setState(() {
            _searchedMarkerLoc = targetLoc;
            _searchedLocationName = displayName;
            _isSearchingLocation = false;
            _showDestinationCard = true;
          });

          _mapController.move(targetLoc, 15.0);
          return;
        }
      }
    } catch (e) {
      debugPrint("Error geocoding location: $e");
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

    // Bus location
    const busLoc = LatLng(28.6298, 77.3705);

    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
          '${busLoc.longitude},${busLoc.latitude};'
          '${_searchedMarkerLoc!.longitude},${_searchedMarkerLoc!.latitude}'
          '?overview=full&geometries=geojson');

      final res = await http.get(url).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final distanceMeters = (route['distance'] as num).toDouble();
          final durationSecs = (route['duration'] as num).toDouble();
          final coords = route['geometry']['coordinates'] as List<dynamic>;

          final List<LatLng> polyline = coords.map<LatLng>((c) {
            final lon = (c[0] as num).toDouble();
            final lat = (c[1] as num).toDouble();
            return LatLng(lat, lon);
          }).toList();

          setState(() {
            _navigationPolylinePoints = polyline;
            _navDistanceKm =
                double.parse((distanceMeters / 1000.0).toStringAsFixed(1));
            _navDurationMins = (durationSecs / 60.0).round();
            _isNavigating = true;
            _isCalculatingRoute = false;
            _showDestinationCard = false;
          });

          _fitMapToBounds(busLoc, _searchedMarkerLoc!);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    "Navigation started: $_navDistanceKm km ($_navDurationMins mins)"),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("OSRM routing error: $e");
    }

    // Fallback straight-line polyline if OSRM is unreachable
    setState(() {
      _navigationPolylinePoints = [busLoc, _searchedMarkerLoc!];
      final distKm = _calculateDistanceKm(busLoc.latitude, busLoc.longitude,
          _searchedMarkerLoc!.latitude, _searchedMarkerLoc!.longitude);
      _navDistanceKm = double.parse(distKm.toStringAsFixed(1));
      _navDurationMins = (_navDistanceKm * 2.5).round();
      _isNavigating = true;
      _isCalculatingRoute = false;
      _showDestinationCard = false;
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
          final title = item['name'] as String? ?? 'Location';
          final address = item['display_name'] as String? ?? '';
          return ListTile(
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
          );
        },
      ),
    );
  }

  Widget _buildDestinationInfoCard(LatLng busLoc) {
    if (_searchedMarkerLoc == null) return const SizedBox();
    final distKm = _calculateDistanceKm(busLoc.latitude, busLoc.longitude,
            _searchedMarkerLoc!.latitude, _searchedMarkerLoc!.longitude)
        .toStringAsFixed(1);

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on,
                  color: Color(0xFF4F46E5), size: 24),
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
                        fontSize: 14,
                        color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _searchedLocationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.straighten,
                          size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text("~$distKm km away",
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569))),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_isCalculatingRoute)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Color(0xFF4F46E5)),
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                onPressed: _calculateDirections,
                icon: const Icon(Icons.navigation, size: 16),
                label: const Text("Get Directions",
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
              onPressed: () {
                setState(() {
                  _showDestinationCard = false;
                  _searchedMarkerLoc = null;
                  _isNavigating = false;
                  _navigationPolylinePoints = [];
                });
              },
            )
          ],
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

  Future<void> _startTrip() async {
    setState(() {
      _isTripActive = true;
      _isTripPaused = false;
    });

    try {
      if (_selectedRouteId != null) {
        final payload = {"route_id": _selectedRouteId!, "trip_type": "pickup"};
        final res =
            await ApiService().post('/transport/driver/trips/start', payload);
        if (res['success'] == true && res['data'] != null) {
          _activeTrip = res['data'];
          await _loadTripState(_activeTrip!['id']);
        }
      }
    } catch (e) {
      debugPrint("Error starting trip in db: $e");
    }

    _startTelemetryBroadcasting();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("🚌 Noida Route 101 live simulation started!"),
          backgroundColor: Colors.green),
    );
  }

  Future<void> _togglePauseTrip() async {
    setState(() {
      _isTripPaused = !_isTripPaused;
      if (_isTripPaused) {
        _telemetryTimer?.cancel();
      } else {
        _startTelemetryBroadcasting();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(_isTripPaused ? "⏸ Route Paused." : "▶ Route Resumed."),
          backgroundColor: Colors.amber),
    );
  }

  Future<void> _endTrip() async {
    setState(() {
      _isTripActive = false;
      _activeTrip = null;
      _telemetryTimer?.cancel();
      for (var s in _stops) {
        s['status'] = 'pending';
      }
      for (var st in _students) {
        st['status'] = 'yet_to_pick';
      }
      _syncCurrentStopIndex();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("🏁 Trip completed and ended successfully!"),
          backgroundColor: Colors.indigo),
    );
  }

  Future<void> _completeStopAtIndex(int index) async {
    if (index >= _stops.length) return;
    debugPrint(
        "[DRIVER_DASH] _completeStopAtIndex: Completing stop $index (${_stops[index]['stop_name']})");
    setState(() {
      _stops[index]['status'] = 'completed';
      _syncCurrentStopIndex();
    });

    try {
      if (_activeTrip != null) {
        final stopId = _stops[index]['id'];
        debugPrint(
            "[DRIVER_DASH] _completeStopAtIndex: POST /stops/$stopId/complete");
        await ApiService().post(
            '/transport/driver/trips/${_activeTrip!['id']}/stops/$stopId/complete',
            {});
        debugPrint("[DRIVER_DASH] _completeStopAtIndex: SUCCESS");
      } else {
        debugPrint(
            "[DRIVER_DASH] _completeStopAtIndex: WARNING - _activeTrip is NULL, not persisting!");
      }
    } catch (e) {
      debugPrint("[DRIVER_DASH] Error completing stop: $e");
    }
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

    debugPrint(
        "[DRIVER_DASH] _updateStudentStatusBulk: Updating ${targetIds.length} students to '$status'");
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

    try {
      if (_activeTrip != null) {
        final payload = {
          "students": targetIds
              .map((id) => {
                    "student_id": id,
                    "status": status,
                    if (status == 'dropped') "drop_stop_id": selectedStopId
                  })
              .toList()
        };
        debugPrint(
            "[DRIVER_DASH] _updateStudentStatusBulk: POST /students/status with ${(payload['students'] as List).length} entries");
        await ApiService().post(
            '/transport/driver/trips/${_activeTrip!['id']}/students/status',
            payload);
        debugPrint("[DRIVER_DASH] _updateStudentStatusBulk: SUCCESS");
      } else {
        debugPrint(
            "[DRIVER_DASH] _updateStudentStatusBulk: WARNING - _activeTrip is NULL, not persisting!");
      }
    } catch (e) {
      debugPrint("[DRIVER_DASH] Error updating students: $e");
    }
  }

  Future<void> _autoCompletePreviousStoppages(int targetStopIndex) async {
    List<int> uncompletedIndices = [];
    for (int i = 0; i < targetStopIndex; i++) {
      if (i < _stops.length && _stops[i]['status'] != 'completed') {
        uncompletedIndices.add(i);
      }
    }

    if (uncompletedIndices.isEmpty) return;

    debugPrint(
        "[DRIVER_DASH] Auto-completing previous uncompleted stops up to index $targetStopIndex: $uncompletedIndices");
    setState(() {
      for (int i in uncompletedIndices) {
        _stops[i]['status'] = 'completed';
      }
      _syncCurrentStopIndex();
    });

    if (_activeTrip != null) {
      for (int i in uncompletedIndices) {
        try {
          final stopId = _stops[i]['id'];
          debugPrint(
              "[DRIVER_DASH] Syncing auto-completed stop $i ($stopId) to DB");
          await ApiService().post(
              '/transport/driver/trips/${_activeTrip!['id']}/stops/$stopId/complete',
              {});
        } catch (e) {
          debugPrint("[DRIVER_DASH] Error auto-completing stop $i: $e");
        }
      }
    }
  }

  Future<void> _markAllStudentsStatusAtCurrentStop(String status) async {
    final currentStudents = _getStudentsAtSelectedStop();
    debugPrint(
        "[DRIVER_DASH] _markAllStudentsStatusAtCurrentStop: Marking ${currentStudents.length} students as '$status' at stop $_selectedStopIndexForChecklist");
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

    try {
      if (_activeTrip != null) {
        final payload = {
          "students": currentStudents
              .map((s) => {"student_id": s['id'], "status": status})
              .toList()
        };
        debugPrint(
            "[DRIVER_DASH] _markAllStudentsStatusAtCurrentStop: POST /students/status + /stops/complete");
        await ApiService().post(
            '/transport/driver/trips/${_activeTrip!['id']}/students/status',
            payload);
        await ApiService().post(
            '/transport/driver/trips/${_activeTrip!['id']}/stops/${_stops[_selectedStopIndexForChecklist]['id']}/complete',
            {});
        debugPrint(
            "[DRIVER_DASH] _markAllStudentsStatusAtCurrentStop: SUCCESS");
      } else {
        debugPrint(
            "[DRIVER_DASH] _markAllStudentsStatusAtCurrentStop: WARNING - _activeTrip is NULL!");
      }
    } catch (e) {
      debugPrint("[DRIVER_DASH] Error performing batch stop complete: $e");
    }
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
      if (_activeTrip != null) {
        final stopId = _stops[index]['id'];
        await ApiService().post(
            '/transport/driver/trips/${_activeTrip!['id']}/stops/$stopId/eta',
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
    if (_stops.isEmpty || _selectedStopIndexForChecklist >= _stops.length)
      return [];
    final selectedStopId = _stops[_selectedStopIndexForChecklist]['id'];
    return _students
        .where((s) =>
            s['stop_id'] == selectedStopId && s['status'] == 'yet_to_pick')
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.all(8.0),
                child: const Icon(Icons.directions_bus,
                    color: Color(0xFF4F46E5), size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("EduSHAMIIT ERP",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B))),
                  Text("Driver App",
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 24),
              _buildHeaderRouteDropdown(),
            ],
          ),
          Row(
            children: [
              Container(
                width: 260,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _searchLocation,
                  decoration: InputDecoration(
                    hintText: _isSearchingLocation
                        ? "Searching location..."
                        : "Search location on map...",
                    hintStyle:
                        const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: _isSearchingLocation
                        ? const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF4F46E5)),
                            ),
                          )
                        : const Icon(Icons.search,
                            size: 18, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Badge(
                  label: Text("3"),
                  child: Icon(Icons.notifications_none_outlined,
                      color: Color(0xFF475569)),
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => context.go('/admin/my-profile'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4.0, vertical: 4.0),
                  child: Row(
                    children: [
                      _buildUserAvatar(avatarUrl, driverName, radius: 18),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(driverName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF1E293B))),
                          Text("Driver • $_busNumber",
                              style: const TextStyle(
                                  color: Color(0xFF64748B), fontSize: 10)),
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
  }

  Widget _buildHeaderRouteDropdown() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 45),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Route: Noida Route 101 (Morning)",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B)),
            ),
            SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: "101",
          child: Text("Noida Route 101 (Morning)",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
      onSelected: (val) {
        _startTrip();
      },
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
      if (width < 950) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSingleWrapStat("Bus", _registrationNo, "AC School Bus",
                Icons.directions_bus, const Color(0xFF4F46E5), width),
            _buildSingleWrapStat("Start Time", _startTime, "On Time",
                Icons.access_time, Colors.amber.shade700, width),
            _buildSingleWrapStat("Location", _currentLocationName, "Live",
                Icons.my_location, Colors.green, width),
            _buildSingleWrapStat("Next Stop", _nextStopName, "ETA: 3 min",
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
              value: _registrationNo,
              subtitle: "AC School Bus",
              icon: Icons.directions_bus,
              iconColor: const Color(0xFF4F46E5)),
          buildStatCard(
              label: "Start Time",
              value: _startTime,
              subtitle: "On Time",
              icon: Icons.access_time,
              iconColor: Colors.amber.shade700),
          buildStatCard(
              label: "Current Location",
              value: _currentLocationName,
              subtitle: "Live",
              icon: Icons.my_location,
              iconColor: Colors.green),
          buildStatCard(
              label: "Next Stop",
              value: _nextStopName,
              subtitle: "ETA: 3 min",
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
    final markers = <Marker>[];

    for (int i = 0; i < _routePoints.length; i++) {
      final point = _routePoints[i];
      final isStart = i == 0;
      final isEnd = i == _routePoints.length - 1;

      markers.add(
        Marker(
          point: point,
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () {
              _showStopStudentsPopup(_stops[i], i);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isStart)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text("Start",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  )
                else if (isEnd)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text("End",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: isStart
                        ? Colors.green
                        : isEnd
                            ? Colors.red
                            : const Color(0xFF4F46E5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4)
                    ],
                  ),
                  width: 18,
                  height: 18,
                  child: Center(
                    child: Text(
                      isStart || isEnd ? "" : "$i",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    markers.add(
      Marker(
        point: busLoc,
        width: 44,
        height: 44,
        child: Transform.rotate(
          angle: _vehicleHeading * math.pi / 180,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))
              ],
            ),
            child: const Icon(Icons.directions_bus_rounded,
                color: Colors.black87, size: 22),
          ),
        ),
      ),
    );

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4)
                    ],
                  ),
                  child: Text(
                    _searchedLocationName.length > 20
                        ? "${_searchedLocationName.substring(0, 20)}..."
                        : _searchedLocationName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(Icons.location_on,
                    color: Colors.redAccent, size: 28),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 520,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFFF1F5F9), blurRadius: 6, offset: Offset(0, 3))
          ]),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: busLoc,
              initialZoom: _zoomLevel,
            ),
            children: [
              TileLayer(
                urlTemplate: _getMapTileUrl(),
                userAgentPackageName: "com.edushamiit.admin",
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
              if (_navigationPolylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _navigationPolylinePoints,
                      strokeWidth: 6.0,
                      color: const Color(0xFF2563EB),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: markers,
              ),
            ],
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 280,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4)
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: _searchLocation,
                    decoration: InputDecoration(
                      hintText: _isSearchingLocation
                          ? "Searching location..."
                          : "Search location on map...",
                      hintStyle: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8)),
                      prefixIcon: _isSearchingLocation
                          ? const Padding(
                              padding: EdgeInsets.all(10.0),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF4F46E5)),
                              ),
                            )
                          : const Icon(Icons.search,
                              size: 16, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty) _buildAutocompleteDropdown(),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4)
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _buildMapSidebarControl(
                          Icons.traffic,
                          "Traffic",
                          _showTraffic,
                          () => setState(() => _showTraffic = !_showTraffic)),
                      _buildMapSidebarControl(
                          Icons.layers,
                          "Satellite",
                          _mapType == "Satellite",
                          () => setState(() => _mapType = "Satellite")),
                      _buildMapSidebarControl(
                          Icons.terrain,
                          "Terrain",
                          _mapType == "Terrain",
                          () => setState(() => _mapType = "Terrain")),
                      _buildMapSidebarControl(
                          Icons.map,
                          "Standard",
                          _mapType == "Standard",
                          () => setState(() => _mapType = "Standard")),
                    ],
                  ),
                )
              ],
            ),
          ),
          Positioned(
            left: 14,
            bottom: 64,
            child: _buildSpeedometerHud(),
          ),
          if (_isNavigating) _buildActiveNavigationBanner(),
          if (_showDestinationCard && !_isNavigating)
            _buildDestinationInfoCard(busLoc),
          Positioned(
            left: 12,
            bottom: 12,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF334155),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onPressed: () {
                _mapController.move(busLoc, 14.0);
              },
              icon: const Icon(Icons.my_location, size: 14),
              label: const Text("Re-center",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 50,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4)
                ],
              ),
              child: Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: () {
                      _zoomLevel = (_zoomLevel + 1).clamp(10, 18);
                      _mapController.move(busLoc, _zoomLevel);
                    },
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                  Container(
                      height: 1, color: const Color(0xFFF1F5F9), width: 20),
                  IconButton(
                    icon: const Icon(Icons.remove, size: 16),
                    onPressed: () {
                      _zoomLevel = (_zoomLevel - 1).clamp(10, 18);
                      _mapController.move(busLoc, _zoomLevel);
                    },
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ],
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
          Row(
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
          ),
          const SizedBox(height: 16),

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
              _buildTableFooterTotal(Icons.directions_bus_outlined, "On Board",
                  "${_getOnBoardCount()}"),
              _buildTableFooterTotal(Icons.cancel_presentation_outlined,
                  "Yet to Pick", "${_getYetToPickCount()}"),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStopRowContainer(int index, Map<String, dynamic> s) {
    final isCompleted = s['status'] == "completed";
    final isCurrent = index == _currentStopIndex;
    final isSelected = index == _selectedStopIndexForChecklist;

    // Pick / Drop Count Logic
    // FUTURE STOPS SHOW 0/0 PICK/DROP COUNT
    String pickDropStr = "0 / 0";
    if (index <= _currentStopIndex) {
      final pickedAtStop = _students
          .where((st) =>
              st['stop_id'] == s['id'] &&
              (st['status'] == 'picked' || st['status'] == 'dropped'))
          .length;
      final droppedAtStop = _students
          .where((st) =>
              st['status'] == 'dropped' &&
              (st['drop_stop_id'] == s['id'] ||
                  (st['drop_stop_id'] == null && st['stop_id'] == s['id'])))
          .length;
      pickDropStr = "$pickedAtStop / $droppedAtStop";
    }

    // Number of students belonging to this stoppage
    final studentsAtStopCount =
        _students.where((st) => st['stop_id'] == s['id']).length;
    final String studentsCountStr = "$studentsAtStopCount";

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

    if (url != null && url.isNotEmpty && !url.contains("randomuser.me")) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url),
        child: Text(
          displayText,
          style: TextStyle(
              fontSize: radius * 0.7,
              color: Colors.white,
              fontWeight: FontWeight.bold),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.wifi, color: Colors.green, size: 16),
              SizedBox(width: 6),
              Text("Connected",
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              SizedBox(width: 16),
              Icon(Icons.gps_fixed, color: Colors.green, size: 16),
              SizedBox(width: 6),
              Text("GPS: Signal Strong",
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isTripActive ? Colors.red : const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                onPressed: _isTripActive ? _endTrip : _startTrip,
                icon: Icon(_isTripActive
                    ? Icons.stop_circle_outlined
                    : Icons.play_arrow_rounded),
                label: Text(_isTripActive ? "End Route" : "Start Route",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              if (_isTripActive) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isTripPaused ? const Color(0xFF10B981) : Colors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _togglePauseTrip,
                  icon: Icon(_isTripPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(_isTripPaused ? "Resume" : "Pause Route",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(
                      color: _emergencyAlertActive
                          ? Colors.red
                          : Colors.red.shade300,
                      width: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isTripActive ? _triggerEmergency : null,
                icon: const Icon(Icons.warning_amber_rounded, size: 16),
                label: const Text("Emergency SOS",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF4F46E5), width: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isTripActive ? _triggerDeviation : null,
                icon: const Icon(Icons.alt_route, size: 16),
                label: const Text("Route Deviation",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          )
        ],
      ),
    );
  }
}
