import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import 'package:edu_shamiit_core/utils/l10n.dart';
import 'package:edu_shamiit_academic/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_academic/core/services/student_api_service.dart';
import 'package:edu_shamiit_core/models/student_models.dart';

class StudentTransport extends ConsumerStatefulWidget {
  const StudentTransport({super.key});

  @override
  ConsumerState<StudentTransport> createState() => _StudentTransportState();
}

class _StudentTransportState extends ConsumerState<StudentTransport> {
  final StudentApiService _apiService = StudentApiService();
  final MapController _mapController = MapController();

  TransportRoute? _transportRoute;
  bool _isLoading = true;
  String? _error;

  // Live Location and Routing
  LatLng? _busLocation;
  LatLng? _studentStopLocation;
  LatLng? _schoolLocation;
  LatLng? _userLocation; // Real GPS location

  // Full route polyline through ALL stops
  List<LatLng> _fullRoutePoints = [];
  // Segment from bus to student stop
  List<LatLng> _busToStudentRoutePoints = [];

  // OSRM-calculated data per stop (distance_km, duration_min from bus)
  List<Map<String, dynamic>> _stopOSRMData = [];

  // Route totals from OSRM
  double? _totalRouteDistanceKm;
  int? _totalRouteDurationMin;

  // Bus to student stop
  double? _distanceLeft;
  int? _timeLeft;

  // Toggle for full route / my route view on map
  bool _showFullRoute = true;

  // Theme Constants
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _success = Color(0xFF16A34A);
  static const Color _orange = Color(0xFFEA580C);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Kick off GPS location fetch in parallel with API data
      final gpsLocationFuture = _getUserLocation();
      final route = await _apiService.getTransportRoute();

      // Wait for GPS too
      final userLoc = await gpsLocationFuture;

      if (route != null) {
        // Resolve bus location
        LatLng? busLoc;
        if (route.liveLatitude != null && route.liveLongitude != null) {
          busLoc = LatLng(route.liveLatitude!, route.liveLongitude!);
        } else if (route.stops.isNotEmpty) {
          final firstStop = route.stops.first;
          if (firstStop.latitude != null && firstStop.longitude != null) {
            busLoc = LatLng(firstStop.latitude!, firstStop.longitude!);
          }
        }

        // Resolve student stop location
        LatLng? studentStopLoc;
        if (route.myStopRaw != null &&
            route.myStopRaw!['latitude'] != null &&
            route.myStopRaw!['longitude'] != null) {
          studentStopLoc = LatLng(
            double.tryParse(route.myStopRaw!['latitude'].toString()) ?? 28.6212,
            double.tryParse(route.myStopRaw!['longitude'].toString()) ?? 77.3610,
          );
        } else {
          for (var stop in route.stops) {
            if (stop.stopName == route.studentStopName) {
              if (stop.latitude != null && stop.longitude != null) {
                studentStopLoc = LatLng(stop.latitude!, stop.longitude!);
              }
              break;
            }
          }
        }
        studentStopLoc ??= const LatLng(28.6212, 77.3610);

        // School = last stop
        LatLng? schoolLoc;
        if (route.stops.isNotEmpty) {
          final lastStop = route.stops.last;
          if (lastStop.latitude != null && lastStop.longitude != null) {
            schoolLoc = LatLng(lastStop.latitude!, lastStop.longitude!);
          }
        }
        schoolLoc ??= const LatLng(28.6242, 77.3635);

        setState(() {
          _transportRoute = route;
          _busLocation = busLoc ?? const LatLng(28.6210, 77.3605);
          _studentStopLocation = studentStopLoc;
          _schoolLocation = schoolLoc;
          _userLocation = userLoc;
          _isLoading = false;
        });

        // Fetch OSRM routes: full route through all stops + bus-to-student segment
        _fetchAllOSRMData();
      } else {
        setState(() {
          _isLoading = false;
          _error = 'No transport route assigned';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  /// Get user's real GPS location from device sensor
  Future<LatLng?> _getUserLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get actual position from device sensor
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('GPS Location Error: $e');
      return null;
    }
  }

  /// Fetch all OSRM data:
  /// 1. Full route polyline through all stops (for drawing the complete route line)
  /// 2. Bus → each stop distance/duration (for real ETA per stop)
  /// 3. Bus → student stop segment
  Future<void> _fetchAllOSRMData() async {
    if (_transportRoute == null) return;

    final stops = _transportRoute!.stops;
    if (stops.isEmpty) return;

    // Build list of waypoints: bus location → all stops in order
    final List<LatLng> waypoints = [];
    if (_busLocation != null) {
      waypoints.add(_busLocation!);
    }
    for (final stop in stops) {
      if (stop.latitude != null && stop.longitude != null) {
        waypoints.add(LatLng(stop.latitude!, stop.longitude!));
      }
    }

    if (waypoints.length < 2) return;

    // 1. Fetch full route polyline through all waypoints
    _fetchFullRoutePolyline(waypoints);

    // 2. Fetch bus → student stop segment
    if (_busLocation != null && _studentStopLocation != null) {
      _fetchBusToStudentRoute(_busLocation!, _studentStopLocation!);
    }

    // 3. Fetch OSRM table: bus → each stop distance/duration
    _fetchOSRMTable(waypoints);
  }

  /// Fetch the full polyline route through all stops from OSRM
  Future<void> _fetchFullRoutePolyline(List<LatLng> waypoints) async {
    try {
      final coordsStr = waypoints
          .map((w) => '${w.longitude},${w.latitude}')
          .join(';');
      final url =
          'https://router.project-osrm.org/route/v1/driving/$coordsStr?overview=full&geometries=geojson&steps=true';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          final points = coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();

          final double totalDistM = double.tryParse(data['routes'][0]['distance'].toString()) ?? 0;
          final double totalDurS = double.tryParse(data['routes'][0]['duration'].toString()) ?? 0;

          // Extract per-leg data from OSRM legs
          final legs = data['routes'][0]['legs'] as List? ?? [];
          final List<Map<String, dynamic>> perStopData = [];
          double cumulativeDistM = 0;
          double cumulativeDurS = 0;

          for (int i = 0; i < legs.length; i++) {
            cumulativeDistM += double.tryParse(legs[i]['distance'].toString()) ?? 0;
            cumulativeDurS += double.tryParse(legs[i]['duration'].toString()) ?? 0;

            perStopData.add({
              'stop_index': i, // index in stops list
              'leg_distance_km': (double.tryParse(legs[i]['distance'].toString()) ?? 0) / 1000.0,
              'leg_duration_min': ((double.tryParse(legs[i]['duration'].toString()) ?? 0) / 60.0).round(),
              'cumulative_distance_km': cumulativeDistM / 1000.0,
              'cumulative_duration_min': (cumulativeDurS / 60.0).round(),
            });
          }

          setState(() {
            _fullRoutePoints = points;
            _totalRouteDistanceKm = totalDistM / 1000.0;
            _totalRouteDurationMin = (totalDurS / 60.0).round();
            _stopOSRMData = perStopData;
          });
        }
      }
    } catch (e) {
      debugPrint('OSRM full route error: $e');
      // Fallback: straight line through waypoints
      setState(() {
        _fullRoutePoints = waypoints;
      });
    }
  }

  /// Fetch bus → student stop route segment with distance/duration
  Future<void> _fetchBusToStudentRoute(LatLng busLoc, LatLng studentStopLoc) async {
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/${busLoc.longitude},${busLoc.latitude};${studentStopLoc.longitude},${studentStopLoc.latitude}?overview=full&geometries=geojson';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          final points = coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();

          final double distM = double.tryParse(data['routes'][0]['distance'].toString()) ?? 0;
          final double durS = double.tryParse(data['routes'][0]['duration'].toString()) ?? 0;

          setState(() {
            _busToStudentRoutePoints = points;
            _distanceLeft = distM / 1000.0;
            _timeLeft = (durS / 60.0).round();
          });
        }
      }
    } catch (e) {
      debugPrint('OSRM bus→student error: $e');
      setState(() {
        _busToStudentRoutePoints = [busLoc, studentStopLoc];
      });
    }
  }

  /// Fetch OSRM table API for quick distance/duration matrix
  Future<void> _fetchOSRMTable(List<LatLng> waypoints) async {
    // The full route already gives us per-leg data via _fetchFullRoutePolyline
    // This method is kept as a placeholder for further optimization if needed
  }

  String _getEstimatedArrival() {
    if (_timeLeft != null) {
      final arrivalTime = DateTime.now().add(Duration(minutes: _timeLeft!));
      final hour = arrivalTime.hour > 12
          ? arrivalTime.hour - 12
          : (arrivalTime.hour == 0 ? 12 : arrivalTime.hour);
      final minute = arrivalTime.minute.toString().padLeft(2, '0');
      final amPm = arrivalTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $amPm';
    }
    return _transportRoute?.arrivalTimeStr ?? '07:45 AM';
  }

  /// Get ETA string for a given stop index (based on OSRM cumulative duration from bus)
  String _getStopETA(int stopIndex) {
    if (_stopOSRMData.isNotEmpty && stopIndex < _stopOSRMData.length) {
      final mins = _stopOSRMData[stopIndex]['cumulative_duration_min'] as int? ?? 0;
      final arrivalTime = DateTime.now().add(Duration(minutes: mins));
      final hour = arrivalTime.hour > 12
          ? arrivalTime.hour - 12
          : (arrivalTime.hour == 0 ? 12 : arrivalTime.hour);
      final minute = arrivalTime.minute.toString().padLeft(2, '0');
      final amPm = arrivalTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $amPm';
    }
    return '';
  }

  /// Get leg distance text for a stop
  String _getStopLegDistance(int stopIndex) {
    if (_stopOSRMData.isNotEmpty && stopIndex < _stopOSRMData.length) {
      final km = _stopOSRMData[stopIndex]['cumulative_distance_km'] as double? ?? 0;
      return '${km.toStringAsFixed(1)} km';
    }
    return '';
  }

  /// Get leg duration text for a stop
  String _getStopLegDuration(int stopIndex) {
    if (_stopOSRMData.isNotEmpty && stopIndex < _stopOSRMData.length) {
      final mins = _stopOSRMData[stopIndex]['cumulative_duration_min'] as int? ?? 0;
      return '$mins min';
    }
    return '';
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  void _centerOnBus() {
    if (_busLocation != null) {
      _mapController.move(_busLocation!, 14.5);
    }
  }

  void _fitFullRoute() {
    final List<LatLng> allPoints = [];
    if (_busLocation != null) allPoints.add(_busLocation!);
    if (_userLocation != null) allPoints.add(_userLocation!);
    if (_studentStopLocation != null) allPoints.add(_studentStopLocation!);
    if (_schoolLocation != null) allPoints.add(_schoolLocation!);
    for (final s in (_transportRoute?.stops ?? [])) {
      if (s.latitude != null && s.longitude != null) {
        allPoints.add(LatLng(s.latitude!, s.longitude!));
      }
    }
    if (allPoints.isEmpty) return;

    double minLat = allPoints.first.latitude, maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude, maxLng = allPoints.first.longitude;
    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    // Rough zoom calc
    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;
    final range = latRange > lngRange ? latRange : lngRange;
    double zoom = 14.0;
    if (range > 0.1) {
      zoom = 11.0;
    } else if (range > 0.05) {
      zoom = 12.0;
    } else if (range > 0.02) {
      zoom = 13.0;
    } else if (range > 0.01) {
      zoom = 13.5;
    }
    _mapController.move(LatLng(centerLat, centerLng), zoom);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary, size: 20),
          onPressed: () => safeGoBack(context, '/student/dashboard'),
        ),
        title: Text(
          'Transport',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PulsingDot(),
                SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions_bus_filled_rounded, size: 64, color: _textSecondary),
                      const SizedBox(height: 16),
                      Text(_error!, style: GoogleFonts.inter(fontSize: 16, color: _textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAll,
                        style: ElevatedButton.styleFrom(backgroundColor: _primary),
                        child: Text('Retry'.tr(ref)),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // My Bus Top Card
                      _buildMyBusHeaderCard(isDesktop),
                      const SizedBox(height: 20),

                      // Responsive content layout
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  _buildMapWidget(),
                                  const SizedBox(height: 20),
                                  _buildMyStopCard(),
                                  const SizedBox(height: 20),
                                  _buildLiveUpdatesCard(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 1,
                              child: Column(
                                children: [
                                  _buildEstimatedArrivalCard(),
                                  const SizedBox(height: 20),
                                  _buildProgressIndicatorsCard(),
                                  const SizedBox(height: 20),
                                  _buildRouteOverviewCard(),
                                  const SizedBox(height: 20),
                                  _buildHelpCard(),
                                  const SizedBox(height: 20),
                                  _buildSafetyFirstCard(),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _buildEstimatedArrivalCard(),
                            const SizedBox(height: 16),
                            _buildMapWidget(),
                            const SizedBox(height: 16),
                            _buildProgressIndicatorsCard(),
                            const SizedBox(height: 16),
                            _buildMyStopCard(),
                            const SizedBox(height: 16),
                            _buildRouteOverviewCard(),
                            const SizedBox(height: 16),
                            _buildLiveUpdatesCard(),
                            const SizedBox(height: 16),
                            _buildHelpCard(),
                            const SizedBox(height: 16),
                            _buildSafetyFirstCard(),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }

  // --- MY BUS HEADER CARD ---
  Widget _buildMyBusHeaderCard(bool isDesktop) {
    final driverName = _transportRoute?.driverName ?? 'Ramesh Kumar';
    final driverPhone = _transportRoute?.driverPhone ?? '9876543210';
    final vehicleNum = _transportRoute?.busNumber ?? 'UP16 ET 1234';
    final routeName = _transportRoute?.routeName ?? 'Route 101 (Morning)';

    final content = [
      // Bus Details
      Expanded(
        flex: isDesktop ? 3 : 1,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.directions_bus_rounded, color: _primary, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(6)),
                    child: Text('My Bus', style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  Text(vehicleNum, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
                  Text(routeName, style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
      if (!isDesktop) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),

      // Driver details
      Expanded(
        flex: isDesktop ? 2 : 1,
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFF1F5F9),
              child: Icon(Icons.person_rounded, color: _textSecondary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Driver', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                  Text(driverName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse('tel:$driverPhone')),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_rounded, color: _primary, size: 12),
                        const SizedBox(width: 4),
                        Text(driverPhone, style: GoogleFonts.inter(fontSize: 11, color: _primary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (!isDesktop) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),

      // Attendant details
      Expanded(
        flex: isDesktop ? 2 : 1,
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFF1F5F9),
              child: Icon(Icons.supervised_user_circle_rounded, color: _textSecondary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Bus Attendant', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                  Text('Suresh Yadav', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse('tel:9876509876')),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_rounded, color: _primary, size: 12),
                        const SizedBox(width: 4),
                        Text('9876509876', style: GoogleFonts.inter(fontSize: 11, color: _primary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (!isDesktop) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),

      // Status details
      Expanded(
        flex: isDesktop ? 2 : 1,
        child: Column(
          crossAxisAlignment: isDesktop ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Bus Status', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: _success, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('ON ROUTE', style: GoogleFonts.inter(color: _success, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Updated just now', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _loadAll,
                  child: const Icon(Icons.refresh_rounded, size: 11, color: _primary),
                ),
              ],
            ),
          ],
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: isDesktop
          ? SizedBox(
              height: 72,
              child: Row(
                children: [
                  content[0],
                  const VerticalDivider(width: 32, thickness: 1),
                  content[1],
                  const VerticalDivider(width: 32, thickness: 1),
                  content[2],
                  const VerticalDivider(width: 32, thickness: 1),
                  content[3],
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content[0],
                content[1],
                content[2],
                content[3],
                content[4],
                content[5],
                content[6],
              ],
            ),
    );
  }

  // --- LIVE MAP WIDGET ---
  Widget _buildMapWidget() {
    final centerPos = _busLocation ?? const LatLng(28.6180, 77.3860);
    final routeToShow = _showFullRoute ? _fullRoutePoints : _busToStudentRoutePoints;

    return Container(
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // OSM Map
            FlutterMap(
              mapController: _mapController as dynamic,
              options: MapOptions(
                initialCenter: centerPos as dynamic,
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'edu.shamiit.academic',
                ),
                // Route polyline
                if (routeToShow.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routeToShow as dynamic,
                        strokeWidth: 4.5,
                        color: _showFullRoute ? _primary : _orange,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    // ---- ALL STOP MARKERS ----
                    if (_showFullRoute && _transportRoute != null)
                      for (int i = 0; i < _transportRoute!.stops.length; i++)
                        if (_transportRoute!.stops[i].latitude != null &&
                            _transportRoute!.stops[i].longitude != null)
                          Marker(
                            point: LatLng(
                              _transportRoute!.stops[i].latitude!,
                              _transportRoute!.stops[i].longitude!,
                            ) as dynamic,
                            width: 80,
                            height: 50,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (_transportRoute!.stops[i].stopName == _transportRoute!.studentStopName)
                                        ? _primary
                                        : Colors.white,
                                    border: Border.all(
                                      color: (_transportRoute!.stops[i].stopName == _transportRoute!.studentStopName)
                                          ? _primary
                                          : _textSecondary,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${i + 1}',
                                    style: GoogleFonts.inter(
                                      color: (_transportRoute!.stops[i].stopName == _transportRoute!.studentStopName)
                                          ? Colors.white
                                          : _textPrimary,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Icon(
                                  (_transportRoute!.stops[i].stopName == _transportRoute!.studentStopName)
                                      ? Icons.location_on_rounded
                                      : Icons.circle,
                                  color: (_transportRoute!.stops[i].stopName == _transportRoute!.studentStopName)
                                      ? _primary
                                      : _textSecondary,
                                  size: (_transportRoute!.stops[i].stopName == _transportRoute!.studentStopName)
                                      ? 22
                                      : 10,
                                ),
                              ],
                            ),
                          ),

                    // ---- MY STOP MARKER (always show) ----
                    if (!_showFullRoute && _studentStopLocation != null)
                      Marker(
                        point: _studentStopLocation! as dynamic,
                        width: 80,
                        height: 65,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'My Stop',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.location_on_rounded, color: _primary, size: 24),
                          ],
                        ),
                      ),

                    // ---- SCHOOL MARKER ----
                    if (_schoolLocation != null)
                      Marker(
                        point: _schoolLocation! as dynamic,
                        width: 80,
                        height: 65,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'School',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.school_rounded, color: Color(0xFFDC2626), size: 24),
                          ],
                        ),
                      ),

                    // ---- STUDENT (USER) REAL LOCATION ----
                    if (_userLocation != null)
                      Marker(
                        point: _userLocation! as dynamic,
                        width: 80,
                        height: 65,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0EA5E9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'You',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.person_pin_circle_rounded, color: Color(0xFF0EA5E9), size: 28),
                          ],
                        ),
                      ),

                    // ---- BUS MARKER ----
                    if (_busLocation != null)
                      Marker(
                        point: _busLocation! as dynamic,
                        width: 80,
                        height: 65,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: _orange, width: 1.5),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                              ),
                              child: Text(
                                _timeLeft != null ? '$_timeLeft min' : '...',
                                style: GoogleFonts.inter(color: _orange, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.directions_bus_filled_rounded, color: _orange, size: 28),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Top Status Badge Overlay
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
                ),
                child: Row(
                  children: [
                    const PulsingDot(),
                    const SizedBox(width: 6),
                    Text('Live Tracking', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: _textPrimary)),
                    const SizedBox(width: 4),
                    Text(
                      _userLocation != null ? '• GPS Active' : '• Bus on the way',
                      style: GoogleFonts.inter(fontSize: 10, color: _success, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            // Route toggle button (top right)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRouteToggle('Full Route', _showFullRoute, () {
                      setState(() => _showFullRoute = true);
                      Future.delayed(const Duration(milliseconds: 100), _fitFullRoute);
                    }),
                    _buildRouteToggle('My Route', !_showFullRoute, () {
                      setState(() => _showFullRoute = false);
                      if (_busLocation != null && _studentStopLocation != null) {
                        final cLat = (_busLocation!.latitude + _studentStopLocation!.latitude) / 2;
                        final cLng = (_busLocation!.longitude + _studentStopLocation!.longitude) / 2;
                        _mapController.move(LatLng(cLat, cLng), 14.5);
                      }
                    }),
                  ],
                ),
              ),
            ),

            // Map controls
            Positioned(
              bottom: 12,
              left: 12,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'center_loc',
                    onPressed: _userLocation != null
                        ? () => _mapController.move(_userLocation!, 15.0)
                        : _centerOnBus,
                    backgroundColor: Colors.white,
                    foregroundColor: _textPrimary,
                    child: Icon(_userLocation != null ? Icons.gps_fixed_rounded : Icons.my_location_rounded, size: 18),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'fit_route',
                    onPressed: _fitFullRoute,
                    backgroundColor: Colors.white,
                    foregroundColor: _textPrimary,
                    child: const Icon(Icons.zoom_out_map_rounded, size: 18),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'zoom_in',
                    onPressed: _zoomIn,
                    backgroundColor: Colors.white,
                    foregroundColor: _textPrimary,
                    child: const Icon(Icons.add, size: 18),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'zoom_out',
                    onPressed: _zoomOut,
                    backgroundColor: Colors.white,
                    foregroundColor: _textPrimary,
                    child: const Icon(Icons.remove, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteToggle(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : _textSecondary,
          ),
        ),
      ),
    );
  }

  // --- ESTIMATED ARRIVAL CARD ---
  Widget _buildEstimatedArrivalCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Estimated Arrival at Your Stop', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            _getEstimatedArrival(),
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 12, color: _textSecondary),
              const SizedBox(width: 4),
              Text(
                _timeLeft != null ? 'In $_timeLeft minutes • ${_distanceLeft?.toStringAsFixed(1) ?? "..."} km away' : 'Calculating...',
                style: GoogleFonts.inter(fontSize: 11, color: _textSecondary),
              ),
            ],
          ),
          if (_userLocation != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.gps_fixed_rounded, size: 12, color: Color(0xFF0EA5E9)),
                const SizedBox(width: 4),
                Text(
                  'Your GPS: ${_userLocation!.latitude.toStringAsFixed(4)}, ${_userLocation!.longitude.toStringAsFixed(4)}',
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF0EA5E9)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- PROGRESS INDICATORS CARD ---
  Widget _buildProgressIndicatorsCard() {
    final distanceLeftText = _distanceLeft != null
        ? '${_distanceLeft!.toStringAsFixed(1)} km'
        : 'Calculating...';
    final timeLeftText = _timeLeft != null
        ? '$_timeLeft min'
        : 'Calculating...';

    // Progress bar calculations using OSRM data
    final double distLeft = _distanceLeft ?? 0;
    final double totalDist = _totalRouteDistanceKm ?? 1.0;
    double progressDist = 1.0 - (distLeft / (totalDist > 0 ? totalDist : 1.0));
    if (progressDist < 0.0) progressDist = 0.0;
    if (progressDist > 1.0) progressDist = 1.0;

    final int timeL = _timeLeft ?? 0;
    final int totalTime = _totalRouteDurationMin ?? 1;
    double progressTime = 1.0 - (timeL / (totalTime > 0 ? totalTime : 1.0));
    if (progressTime < 0.0) progressTime = 0.0;
    if (progressTime > 1.0) progressTime = 1.0;

    // Next stop: find the nearest upcoming stop from OSRM data
    String nextStopName = _transportRoute?.nextStop ?? '';
    String nextStopDistText = '';
    String nextStopTimeText = '';
    if (_stopOSRMData.isNotEmpty && _transportRoute != null) {
      // Find next stop that hasn't been passed (first stop with >0 leg_duration)
      for (int i = 0; i < min(_stopOSRMData.length, _transportRoute!.stops.length); i++) {
        final dur = _stopOSRMData[i]['cumulative_duration_min'] as int? ?? 0;
        if (dur > 0) {
          nextStopName = _transportRoute!.stops[i].stopName;
          nextStopDistText = '${(_stopOSRMData[i]['cumulative_distance_km'] as double? ?? 0).toStringAsFixed(1)} km away';
          nextStopTimeText = '$dur min';
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Distance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Distance to Your Stop', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w500)),
              Text(distanceLeftText, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressDist,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(_primary),
            ),
          ),
          const SizedBox(height: 16),

          // Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Time to Your Stop', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w500)),
              Text(timeLeftText, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _success)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressTime,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(_success),
            ),
          ),
          const SizedBox(height: 16),

          // Next Stop
          if (nextStopName.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                    child: const Icon(Icons.location_on_rounded, color: _primary, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Next Stop', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                        Text(nextStopName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
                        if (nextStopDistText.isNotEmpty)
                          Text('$nextStopDistText • $nextStopTimeText', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.map_rounded, size: 14),
            label: Text('View Full Route on Map', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () {
              setState(() => _showFullRoute = true);
              Future.delayed(const Duration(milliseconds: 100), _fitFullRoute);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: const BorderSide(color: _primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // --- MY STOP & PROGRESS STEPPER ---
  Widget _buildMyStopCard() {
    final stopName = _transportRoute?.myStopRaw != null
        ? (_transportRoute!.myStopRaw!['stop_name'] ?? 'Your Stop')
        : 'Your Stop';
    final pickupTime = _transportRoute?.myStopRaw != null
        ? (_transportRoute!.myStopRaw!['pickup_time'] ?? '--')
        : '--';
    final order = _transportRoute?.myStopRaw != null
        ? (_transportRoute!.myStopRaw!['stop_order'] ?? 1)
        : 1;

    final distanceToStopText = _distanceLeft != null
        ? '${_distanceLeft!.toStringAsFixed(1)} km'
        : 'Calculating...';

    final estimatedTimeText = _timeLeft != null
        ? '$_timeLeft min'
        : 'Calculating...';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.home_work_rounded, color: _primary, size: 18),
              const SizedBox(width: 8),
              Text('My Stop', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stopName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
                    const SizedBox(height: 2),
                    Text('Scheduled Pickup: $pickupTime', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                child: Text('Stop #$order', style: GoogleFonts.inter(color: _primary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bus Distance', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                    const SizedBox(height: 2),
                    Text(distanceToStopText, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ETA (OSRM)', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                    const SizedBox(height: 2),
                    Text(estimatedTimeText, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _success)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Arrival', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                    const SizedBox(height: 2),
                    Text(_getEstimatedArrival(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Stepper progress timeline with OSRM ETA per stop
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_transportRoute != null)
                  ...() {
                    final List<Widget> stepWidgets = [];
                    final stops = _transportRoute!.stops;
                    final studentStopName = _transportRoute!.studentStopName;

                    int studentStopIndex = -1;
                    for (int i = 0; i < stops.length; i++) {
                      if (stops[i].stopName == studentStopName) {
                        studentStopIndex = i;
                        break;
                      }
                    }
                    if (studentStopIndex == -1) {
                      studentStopIndex = stops.length > 3 ? 3 : 0;
                    }

                    for (int i = 0; i < stops.length; i++) {
                      final stop = stops[i];
                      final isStudentStop = i == studentStopIndex;
                      final isCompleted = i < studentStopIndex;

                      String title = stop.stopName;
                      if (title.length > 15) {
                        title = '${title.substring(0, 12)}...';
                      }

                      // Use OSRM-calculated ETA for this stop
                      final osrmEta = _getStopETA(i);
                      final osrmDist = _getStopLegDistance(i);
                      final displayTime = osrmEta.isNotEmpty ? osrmEta : (stop.arrivalTime ?? '');

                      stepWidgets.add(
                        _buildStepItem(
                          title,
                          displayTime,
                          osrmDist,
                          isCompleted,
                          stop.stopOrder ?? (i + 1),
                          isActive: isStudentStop,
                        ),
                      );

                      if (i < stops.length - 1) {
                        // Show leg duration between this stop and next
                        final legDur = _getStopLegDuration(i);
                        stepWidgets.add(_buildStepLine(isCompleted, legDur));
                      }
                    }
                    return stepWidgets;
                  }()
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String title, String time, String distance, bool isCompleted, int order, {bool isActive = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? _success
                : isActive
                    ? _primary
                    : const Color(0xFFF1F5F9),
            border: isActive ? Border.all(color: Colors.white, width: 2) : null,
            boxShadow: isActive ? [BoxShadow(color: _primary.withValues(alpha: 0.4), blurRadius: 6)] : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : Text(
                    '$order',
                    style: GoogleFonts.inter(
                      color: isActive ? Colors.white : _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? _primary : _textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(time, style: GoogleFonts.inter(fontSize: 8, color: _success, fontWeight: FontWeight.w600)),
        if (distance.isNotEmpty)
          Text(distance, style: GoogleFonts.inter(fontSize: 7, color: _textSecondary)),
      ],
    );
  }

  Widget _buildStepLine(bool isCompleted, String legDuration) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 2,
          margin: const EdgeInsets.only(bottom: 30),
          color: isCompleted ? _success : const Color(0xFFE2E8F0),
        ),
      ],
    );
  }

  // --- ROUTE OVERVIEW CARD ---
  Widget _buildRouteOverviewCard() {
    final distanceStr = _totalRouteDistanceKm != null
        ? '${_totalRouteDistanceKm!.toStringAsFixed(1)} km'
        : 'Calculating...';
    final totalStops = _transportRoute?.stops.length.toString() ?? '0';
    final totalDuration = _totalRouteDurationMin != null
        ? '$_totalRouteDurationMin min'
        : 'Calculating...';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Route Overview (OSRM)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 14),
          _buildRouteOverviewItem(Icons.straighten_rounded, 'Total Route Distance', distanceStr),
          const SizedBox(height: 12),
          _buildRouteOverviewItem(Icons.alt_route_rounded, 'Total Stops', totalStops),
          const SizedBox(height: 12),
          _buildRouteOverviewItem(Icons.av_timer_rounded, 'Total Travel Time', totalDuration),
          if (_distanceLeft != null) ...[
            const SizedBox(height: 12),
            _buildRouteOverviewItem(Icons.near_me_rounded, 'Bus → Your Stop', '${_distanceLeft!.toStringAsFixed(1)} km'),
          ],
          if (_timeLeft != null) ...[
            const SizedBox(height: 12),
            _buildRouteOverviewItem(Icons.timer_rounded, 'ETA to Your Stop', '$_timeLeft min'),
          ],
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () {
              setState(() => _showFullRoute = true);
              Future.delayed(const Duration(milliseconds: 100), _fitFullRoute);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: const BorderSide(color: _primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Show Full Route on Map →', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteOverviewItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _textSecondary),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
        const Spacer(),
        Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
      ],
    );
  }

  // --- LIVE UPDATES CARD ---
  Widget _buildLiveUpdatesCard() {
    // Live updates from real-time data

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined, color: _primary, size: 18),
              const SizedBox(width: 8),
              Text('Live Updates', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          if (_timeLeft != null)
            _buildLiveUpdateItem(
              _getEstimatedArrival(),
              'Bus will reach your stop (${_transportRoute?.studentStopName ?? "Your Stop"}) in $_timeLeft min',
            ),
          if (_totalRouteDistanceKm != null) ...[
            const SizedBox(height: 12),
            _buildLiveUpdateItem(
              'Route',
              'Total route: ${_totalRouteDistanceKm!.toStringAsFixed(1)} km, ${_totalRouteDurationMin ?? "..."} min',
            ),
          ],
          if (_userLocation != null) ...[
            const SizedBox(height: 12),
            _buildLiveUpdateItem(
              'GPS',
              'Your location detected: ${_userLocation!.latitude.toStringAsFixed(4)}, ${_userLocation!.longitude.toStringAsFixed(4)}',
            ),
          ],
          const SizedBox(height: 14),
          TextButton(
            onPressed: _loadAll,
            child: Text('Refresh All Data →', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveUpdateItem(String time, String message) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(time, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _textSecondary)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(message, style: GoogleFonts.inter(fontSize: 11, color: _textPrimary)),
        ),
      ],
    );
  }

  // --- SAFETY FIRST CARD ---
  Widget _buildSafetyFirstCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: _success, size: 18),
              const SizedBox(width: 8),
              Text('Safety First', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          _buildSafetyTip('Reach your stop 5 minutes early.'),
          _buildSafetyTip('Stand in a safe zone while waiting.'),
          _buildSafetyTip('Do not run towards the bus.'),
          _buildSafetyTip('Wear your ID card while boarding.'),
          _buildSafetyTip('Need help? Contact school transport incharge.'),
          const SizedBox(height: 12),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_walk_rounded, size: 36, color: _primary),
                SizedBox(width: 12),
                Icon(Icons.school_rounded, size: 36, color: _primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 12, color: _success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(fontSize: 10, color: _textPrimary)),
          ),
        ],
      ),
    );
  }

  // --- HELP CARD ---
  Widget _buildHelpCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Need Help?', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 4),
          Text('Contact Transport Incharge', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.phone, size: 14, color: Colors.white),
            label: Text('0120-4567890', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () => launchUrl(Uri.parse('tel:0120-4567890')),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.error_outline_rounded, size: 14),
            label: Text('Raise an Issue', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Issue raised successfully. Transport desk will contact you.')),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF16A34A),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
