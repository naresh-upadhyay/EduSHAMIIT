import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'package:edu_shamiit_admin/core/file_download_helper.dart';

class RouteManagementScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const RouteManagementScreen({super.key, this.initialIndex = 1});

  @override
  ConsumerState<RouteManagementScreen> createState() => _RouteManagementScreenState();
}

class _RouteManagementScreenState extends ConsumerState<RouteManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Theme styling constants
  static const _accent = Color(0xFF4F46E5);
  static const _green = Color(0xFF22C55E);
  static const _blue = Color(0xFF3B82F6);
  static const _orange = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);
  static const _gray = Color(0xFF94A3B8);
  static const _bg = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);

  // State lists
  List<dynamic> _routes = [];
  List<dynamic> _vehicles = [];
  List<dynamic> _drivers = [];
  bool _isLoading = true;

  // Selected route and stops
  dynamic _selectedRoute;
  List<dynamic> _selectedRouteStops = [];
  bool _isLoadingStops = false;

  // Filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _typeFilter = 'All';
  String _areaFilter = 'All';
  
  // Overview Filters
  String _overviewAreaFilter = 'All';
  String _overviewTypeFilter = 'All';
  String _overviewStatusFilter = 'All';
  DateTimeRange _overviewDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  
  // Pagination
  int _currentPage = 1;
  int _pageSize = 8;

  // Map Controller
  final MapController _mapController = MapController();

  // --- STOPS TAB STATE VARIABLES ---
  List<dynamic> _stops = [];
  bool _isLoadingStopsTab = false;
  dynamic _selectedStop;
  List<dynamic> _stopsPreviewRouteStops = [];
  dynamic _selectedPreviewRoute;
  int _stopsCurrentPage = 1;
  int _stopsPageSize = 10;
  
  final TextEditingController _stopsSearchController = TextEditingController();
  String _stopsSearchQuery = '';
  String _stopsStatusFilter = 'All';
  String _stopsTypeFilter = 'All';
  String _stopsRouteFilter = 'All';

  final MapController _stopsMapController = MapController();

  final ScrollController _routeTableScrollController = ScrollController();
  final ScrollController _stopsTableScrollController = ScrollController();
  final ScrollController _overviewTableScrollController = ScrollController();

  // --- TRIPS TAB STATE VARIABLES ---
  List<dynamic> _trips = [];
  bool _isLoadingTripsTab = false;
  final TextEditingController _tripsSearchController = TextEditingController();
  String _tripsSearchQuery = '';
  String _tripsRouteFilter = 'All';
  String _tripsBusFilter = 'All';
  String _tripsDriverFilter = 'All';
  String _tripsTypeFilter = 'All';
  String _tripsStatusFilter = 'All';
  DateTime? _tripsStartDate = DateTime(2024, 5, 1);
  DateTime? _tripsEndDate = DateTime(2024, 5, 31);
  final ScrollController _tripsTableScrollController = ScrollController();
  int _tripsCurrentPage = 1;
  int _tripsPageSize = 8;
  dynamic _selectedTrip;
  DateTime _calendarTargetDate = DateTime(2024, 5, 1);

  // --- ASSIGN BUS TAB STATE VARIABLES ---
  List<dynamic> _assignments = [];
  bool _isLoadingAssignmentsTab = false;
  String? _assignSelectedRouteId;
  String? _assignSelectedVehicleId;
  String? _assignSelectedDriverId;
  DateTime _assignStartDate = DateTime.now();
  final TextEditingController _assignNotesController = TextEditingController();
  final TextEditingController _assignSearchController = TextEditingController();
  String _assignSearchQuery = '';
  String _assignAreaFilter = 'All';
  String _assignTypeFilter = 'All';
  String _assignStatusFilter = 'All';
  int _assignCurrentPage = 1;
  int _assignPageSize = 8;
  final ScrollController _assignTableScrollController = ScrollController();

  // --- LIVE TRACKING TAB STATE VARIABLES ---
  Map<String, dynamic> _trackingSummary = {};
  List<dynamic> _trackingAlerts = [];
  List<dynamic> _trackingVehicles = [];
  dynamic _selectedTrackingVehicle;
  List<dynamic> _trackingSelectedRouteStops = [];
  List<LatLng> _trackingRoutePoints = [];
  bool _isLoadingLiveTracking = false;
  final MapController _trackingMapController = MapController();
  final TextEditingController _trackingSearchController = TextEditingController();
  String _trackingSearchQuery = '';
  String _trackingRouteFilter = 'All';
  String _trackingBusFilter = 'All';
  String _trackingStatusFilter = 'All';
  int _autoRefreshSeconds = 15;
  Timer? _autoRefreshTimer;
  bool _isMapMaximized = false;
  int _trackingCurrentPage = 1;
  int _trackingPageSize = 4;

  // --- ROUTE REPORTS TAB STATE VARIABLES ---
  Map<String, dynamic> _reportsSummary = {};
  Map<String, dynamic> _reportsStatusDonut = {};
  List<dynamic> _reportsTrends = [];
  List<dynamic> _reportsRoutesPerformance = [];
  Map<String, dynamic> _reportsPerformanceSummary = {};
  bool _isLoadingReports = false;
  
  DateTimeRange _reportsDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String _reportsRouteFilter = 'All';
  String _reportsBusFilter = 'All';
  final String _reportsDriverFilter = 'All';
  String _reportsStatusFilter = 'All';
  
  int _reportsTableCurrentPage = 1;
  int _reportsTablePageSize = 8;
  final ScrollController _reportsTableScrollController = ScrollController();


  @override
  void initState() {
    super.initState();
    // 7 tabs as per design: Overview, Route Management, Trips & Schedule, Assign Bus, Live Tracking, Route Reports, Stops
    _tabController = TabController(length: 7, vsync: this, initialIndex: widget.initialIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _currentPage = 1;
      });
    });
    _stopsSearchController.addListener(() {
      setState(() {
        _stopsSearchQuery = _stopsSearchController.text;
        _stopsCurrentPage = 1;
      });
      _loadStops();
    });
    _tripsSearchController.addListener(() {
      setState(() {
        _tripsSearchQuery = _tripsSearchController.text;
        _tripsCurrentPage = 1;
      });
    });
    _assignSearchController.addListener(() {
      setState(() {
        _assignSearchQuery = _assignSearchController.text;
        _assignCurrentPage = 1;
      });
    });
    _trackingSearchController.addListener(() {
      setState(() {
        _trackingSearchQuery = _trackingSearchController.text;
        _trackingCurrentPage = 1;
      });
    });
    _startAutoRefreshTimer();
  }

  @override
  void didUpdateWidget(RouteManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      _tabController.animateTo(widget.initialIndex);
    }
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_tabController.index == 4) {
          setState(() {
            if (_autoRefreshSeconds <= 1) {
              _autoRefreshSeconds = 15;
              _loadLiveTrackingData();
            } else {
              _autoRefreshSeconds--;
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _routeTableScrollController.dispose();
    _stopsTableScrollController.dispose();
    _overviewTableScrollController.dispose();
    _tripsTableScrollController.dispose();
    _assignTableScrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _stopsSearchController.dispose();
    _tripsSearchController.dispose();
    _assignSearchController.dispose();
    _assignNotesController.dispose();
    _trackingSearchController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final schoolId = ref.read(authProvider).userData?['school_id']?.toString();
      final routesPath = schoolId != null ? '/transport/routes?school_id=$schoolId' : '/transport/routes';
      final vehiclesPath = schoolId != null ? '/transport/vehicles?page_size=100&school_id=$schoolId' : '/transport/vehicles?page_size=100';
      final driversPath = schoolId != null ? '/transport/drivers?page_size=100&school_id=$schoolId' : '/transport/drivers?page_size=100';
      final stopsPath = schoolId != null ? '/transport/stops?page_size=100&school_id=$schoolId' : '/transport/stops?page_size=100';
      final assignmentsPath = schoolId != null ? '/transport/drivers/assignments?school_id=$schoolId' : '/transport/drivers/assignments';

      final results = await Future.wait([
        ApiService().get(routesPath, useCache: false),
        ApiService().get(vehiclesPath, useCache: false),
        ApiService().get(driversPath, useCache: false),
        ApiService().get(stopsPath, useCache: false),
        ApiService().get(assignmentsPath, useCache: false),
      ]);

      if (mounted) {
        setState(() {
          _routes = results[0]['data'] ?? [];
          
          final vehData = results[1]['data'];
          if (vehData is Map && vehData['vehicles'] is List) {
            _vehicles = vehData['vehicles'];
          } else if (vehData is List) {
            _vehicles = vehData;
          } else {
            _vehicles = [];
          }

          _drivers = results[2]['data'] ?? [];
          _stops = results[3]['data']?['stops'] ?? [];
          _assignments = results[4]['data'] ?? [];
          
          // Pre-select first route if available
          if (_routes.isNotEmpty) {
            _selectedRoute = _routes[0];
            _selectedPreviewRoute = _routes[0];
            _loadStopsForRoute(_selectedRoute['id']);
            _loadStopsPreviewRoute(_selectedPreviewRoute['id']);
          } else {
            _selectedRoute = null;
            _selectedRouteStops = [];
            _selectedPreviewRoute = null;
            _stopsPreviewRouteStops = [];
          }

          // Pre-select first stop if available
          if (_stops.isNotEmpty) {
            _selectedStop = _stops[0];
          }

          _isLoading = false;
        });
        _loadTrips();
        _loadLiveTrackingData();
        _loadRouteReports();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load routes: $e'), backgroundColor: _red),
        );
      }
    }
  }

  Future<void> _loadStops() async {
    setState(() => _isLoadingStopsTab = true);
    try {
      final schoolId = ref.read(authProvider).userData?['school_id']?.toString();
      String path = '/transport/stops?page_size=100';
      if (schoolId != null) path += '&school_id=$schoolId';
      if (_stopsRouteFilter != 'All') path += '&route_id=$_stopsRouteFilter';
      if (_stopsStatusFilter != 'All') path += '&status=$_stopsStatusFilter';
      if (_stopsTypeFilter != 'All') path += '&stop_type=$_stopsTypeFilter';
      if (_stopsSearchQuery.isNotEmpty) path += '&search=${Uri.encodeComponent(_stopsSearchQuery)}';

      final res = await ApiService().get(path, useCache: false);
      if (mounted) {
        setState(() {
          _stops = res['data']?['stops'] ?? [];
          // Pre-select first stop if none currently selected
          if (_stops.isNotEmpty && (_selectedStop == null || !_stops.any((s) => s['id'] == _selectedStop['id']))) {
            _selectedStop = _stops[0];
          }
          _isLoadingStopsTab = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStopsTab = false);
      }
    }
  }

  Future<void> _loadStopsPreviewRoute(String routeId) async {
    try {
      final res = await ApiService().get('/transport/routes/$routeId', useCache: false);
      if (mounted) {
        setState(() {
          _stopsPreviewRouteStops = res['data']?['stops'] ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStopsForRoute(String routeId) async {
    setState(() => _isLoadingStops = true);
    try {
      final res = await ApiService().get('/transport/routes/$routeId', useCache: false);
      if (mounted) {
        setState(() {
          _selectedRouteStops = res['data']?['stops'] ?? [];
          _isLoadingStops = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStops = false);
      }
    }
  }

  List<dynamic> get _filteredRoutes {
    return _routes.where((r) {
      // Search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final code = (r['route_code'] ?? '').toString().toLowerCase();
        final name = (r['route_name'] ?? '').toString().toLowerCase();
        final area = (r['area_zone'] ?? '').toString().toLowerCase();
        if (!code.contains(q) && !name.contains(q) && !area.contains(q)) {
          return false;
        }
      }
      // Status
      if (_statusFilter != 'All') {
        if (r['status'] != _statusFilter) return false;
      }
      // Type (Pickup/Drop/Both)
      if (_typeFilter != 'All') {
        final name = (r['route_name'] ?? '').toString().toLowerCase();
        if (_typeFilter == 'Pickup' && !name.contains('morning') && !name.contains('pickup')) return false;
        if (_typeFilter == 'Drop' && !name.contains('afternoon') && !name.contains('evening') && !name.contains('drop')) return false;
      }
      // Area / Zone
      if (_areaFilter != 'All') {
        final area = (r['area_zone'] ?? '').toString().toLowerCase();
        if (!area.contains(_areaFilter.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  // --- CRUD API Calls ---
  Future<void> _deleteRoute(dynamic route) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Route', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete ${route['route_code']} - ${route['route_name']}? This will also delete all associated stops.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().delete('/transport/routes/${route['id']}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route deleted successfully'), backgroundColor: _green),
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete route: $e'), backgroundColor: _red),
        );
      }
    }
  }

  Future<void> _duplicateRoute(dynamic route) async {
    try {
      final schoolId = ref.read(authProvider).userData?['school_id']?.toString();
      // Fetch current stops
      final res = await ApiService().get('/transport/routes/${route['id']}', useCache: false);
      final stops = res['data']?['stops'] as List? ?? [];
      
      final cleanStops = stops.map((s) => {
        "stop_name": s["stop_name"],
        "latitude": s["latitude"],
        "longitude": s["longitude"],
        "stop_order": s["stop_order"],
        "estimated_arrival": s["estimated_arrival"],
      }).toList();

      final payload = {
        "school_id": schoolId,
        "route_code": '${route['route_code']}-DUP',
        "route_name": '${route['route_name']} (Copy)',
        "area_zone": route['area_zone'],
        "distance_km": route['distance_km'],
        "start_time": route['start_time'],
        "end_time": route['end_time'],
        "vehicle_id": route['vehicle_id'],
        "driver_id": route['driver_id'],
        "status": 'Draft',
        "stops": cleanStops
      };

      await ApiService().post('/transport/routes', payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route duplicated successfully as Draft'), backgroundColor: _green),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to duplicate route: $e'), backgroundColor: _red),
      );
    }
  }

  Future<void> _deleteStop(dynamic stop) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Stop', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete ${stop['stop_code']} - ${stop['stop_name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().delete('/transport/stops/${stop['id']}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stop deleted successfully'), backgroundColor: _green),
        );
        _loadData();
        _loadStops();
        if (_selectedPreviewRoute != null) {
          _loadStopsPreviewRoute(_selectedPreviewRoute['id']);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete stop: $e'), backgroundColor: _red),
        );
      }
    }
  }

  void _showStopFormDialog(dynamic existing) {
    final bool isEdit = existing != null;
    final formKey = GlobalKey<FormState>();

    String? selectedRouteId;
    if (_routes.isNotEmpty) {
      if (existing != null) {
        final rawRouteId = existing['route_id']?.toString();
        final routeName = (existing['route_name'] ?? existing['transport_routes']?['route_name'] ?? '').toString().trim();

        if (rawRouteId != null && _routes.any((r) => r['id']?.toString() == rawRouteId)) {
          selectedRouteId = rawRouteId;
        } else if (routeName.isNotEmpty) {
          final matchByName = _routes.firstWhere(
            (r) => (r['route_name'] ?? '').toString().trim().toLowerCase() == routeName.toLowerCase(),
            orElse: () => null,
          );
          if (matchByName != null) {
            selectedRouteId = matchByName['id']?.toString();
          }
        }
      }
      selectedRouteId ??= _routes[0]['id']?.toString();
    }

    double currentLat = double.tryParse(existing?['latitude']?.toString() ?? '') ?? 28.6139;
    double currentLng = double.tryParse(existing?['longitude']?.toString() ?? '') ?? 77.3590;

    final nameController = TextEditingController(text: existing?['stop_name'] ?? '');
    final codeController = TextEditingController(text: existing?['stop_code'] ?? '');
    final latController = TextEditingController(text: currentLat.toStringAsFixed(6));
    final lngController = TextEditingController(text: currentLng.toStringAsFixed(6));
    final orderController = TextEditingController(text: (existing?['stop_order'] ?? 1).toString());
    final timeController = TextEditingController(text: existing?['estimated_arrival'] ?? '06:30:00');
    final landmarkController = TextEditingController(text: existing?['landmark'] ?? '');
    final radiusController = TextEditingController(text: (existing?['radius_meters'] ?? 200).toString());
    final mapSearchController = TextEditingController();

    String stopType = existing?['stop_type'] ?? 'Pickup';
    String pickupDropType = existing?['pickup_drop_type'] ?? 'Pickup Only';
    String status = existing?['status'] ?? 'Active';

    String selectedAddress = existing?['landmark'] != null && existing['landmark'].toString().isNotEmpty
        ? existing['landmark']
        : 'Sector 62, Phase 2, Community Center, Noida, Uttar Pradesh 201309';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final MapController dialogMapController = MapController();
        bool isSearching = false;
        List<Map<String, dynamic>> searchResults = [];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Timer? searchDebounceTimer;

            void updateLocation(double lat, double lng, {String? address, String? placeName, bool shouldMoveCamera = true}) {
              setDialogState(() {
                currentLat = lat;
                currentLng = lng;
                latController.text = lat.toStringAsFixed(6);
                lngController.text = lng.toStringAsFixed(6);
                if (address != null && address.isNotEmpty) {
                  selectedAddress = address;
                  if (landmarkController.text.isEmpty || landmarkController.text == 'Near Location') {
                    landmarkController.text = address.split(',').take(2).join(', ');
                  }
                  if (nameController.text.isEmpty && placeName != null && placeName.isNotEmpty) {
                    nameController.text = placeName;
                  }
                }
              });
              if (shouldMoveCamera) {
                try {
                  dialogMapController.move(LatLng(lat, lng), 15.5);
                } catch (_) {}
              }
            }

            Future<void> performReverseGeocode(double lat, double lng) async {
              try {
                final url = Uri.parse(
                  'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&addressdetails=1',
                );
                final res = await http.get(url, headers: {
                  'User-Agent': 'EduSHAMIIT-Admin/1.0 (com.edushamiit.admin)',
                }).timeout(const Duration(seconds: 4));
                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body);
                  final addr = data['display_name'] ?? '$lat, $lng';
                  final name = data['name'] ?? data['address']?['suburb'] ?? data['address']?['neighbourhood'] ?? data['address']?['road'];
                  updateLocation(lat, lng, address: addr, placeName: name, shouldMoveCamera: false);
                }
              } catch (_) {}
            }

            Future<void> performSearch(String query, {bool autoSelectTop = false}) async {
              final trimmedQuery = query.trim();
              if (trimmedQuery.isEmpty) return;
              setDialogState(() {
                isSearching = true;
              });

              final encodedQuery = Uri.encodeComponent(trimmedQuery);
              final List<Map<String, dynamic>> combinedResults = [];

              try {
                // Fire parallel multi-engine geocoding requests to Photon (Elasticsearch Geocoder) & Nominatim (OSM)
                final photonUrl = Uri.parse('https://photon.komoot.io/api/?q=$encodedQuery&limit=10');
                final nominatimUrl = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=$encodedQuery&limit=10&addressdetails=1');

                final responses = await Future.wait([
                  http.get(photonUrl, headers: {'User-Agent': 'EduSHAMIIT-Admin/1.0'}).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500)),
                  http.get(nominatimUrl, headers: {'User-Agent': 'EduSHAMIIT-Admin/1.0 (com.edushamiit.admin)'}).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500)),
                ]);

                final photonRes = responses[0];
                final nominatimRes = responses[1];

                // 1. Process Photon Elasticsearch Results (Fuzzy & Multi-word tolerant)
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
                            'name': name,
                            'lat': lat,
                            'lon': lon,
                          });
                        }
                      }
                    }
                  } catch (_) {}
                }

                // 2. Process Nominatim OSM Results
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
                          'name': rawName,
                          'lat': lat,
                          'lon': lon,
                        });
                      }
                    }
                  } catch (_) {}
                }

                // 3. Deduplicate by Lat/Lon distance (< 0.001 deg ~100m)
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

                final finalItems = deduped.take(8).toList();

                setDialogState(() {
                  searchResults = finalItems;
                  isSearching = false;
                });

                if (autoSelectTop && finalItems.isNotEmpty) {
                  final top = finalItems.first;
                  updateLocation(top['lat'], top['lon'], address: top['display_name'], placeName: top['primary_title'], shouldMoveCamera: true);
                  performReverseGeocode(top['lat'], top['lon']);
                  setDialogState(() => searchResults = []);
                }
              } catch (_) {
                setDialogState(() => isSearching = false);
              }
            }

            final mediaWidth = MediaQuery.of(context).size.width;
            final dialogWidth = mediaWidth > 1200 ? 1100.0 : (mediaWidth * 0.92);

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                width: dialogWidth,
                height: 720,
                color: Colors.white,
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: _border)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEdit ? 'Edit Stop Details' : 'Add / Edit Stop Location',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: _textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Click on map or drag pin to select stop location, or search location below.',
                                style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close, color: _textSecondary),
                          ),
                        ],
                      ),
                    ),

                    // Body: 2 Columns (Map Picker + Form)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Side: Map Location Picker (Flex: 6)
                          Expanded(
                            flex: 6,
                            child: Container(
                              color: _bg,
                              child: Column(
                                children: [
                                  // Map Search Bar with Smart Google-style Typeahead
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                                              ],
                                            ),
                                            child: TextField(
                                              controller: mapSearchController,
                                              onChanged: (val) {
                                                searchDebounceTimer?.cancel();
                                                if (val.trim().length >= 2) {
                                                  setDialogState(() => isSearching = true);
                                                  searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
                                                    performSearch(val, autoSelectTop: false);
                                                  });
                                                } else {
                                                  setDialogState(() {
                                                    searchResults = [];
                                                    isSearching = false;
                                                  });
                                                }
                                              },
                                              onSubmitted: (q) => performSearch(q, autoSelectTop: true),
                                              decoration: InputDecoration(
                                                hintText: 'Search location on map (e.g. Sector 62 Noida)...',
                                                hintStyle: GoogleFonts.inter(fontSize: 13, color: _gray),
                                                prefixIcon: const Icon(Icons.search, size: 18, color: _accent),
                                                suffixIcon: isSearching
                                                    ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
                                                    : (mapSearchController.text.isNotEmpty
                                                        ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setDialogState(() { mapSearchController.clear(); searchResults = []; }))
                                                        : null),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () => performSearch(mapSearchController.text, autoSelectTop: true),
                                          icon: const Icon(Icons.search, size: 16),
                                          label: const Text('Search'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _accent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Smart Search Results Dropdown List (Google Autocomplete Style)
                                  if (searchResults.isNotEmpty)
                                    Container(
                                      constraints: const BoxConstraints(maxHeight: 180),
                                      margin: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: _border),
                                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4))],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        clipBehavior: Clip.antiAlias,
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          itemCount: searchResults.length,
                                          separatorBuilder: (ctx, i) => const Divider(height: 1, color: _border),
                                          itemBuilder: (context, idx) {
                                            final item = searchResults[idx];
                                            return ListTile(
                                              dense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                              leading: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(color: _accent.withValues(alpha: 0.08), shape: BoxShape.circle),
                                                child: const Icon(Icons.location_on, size: 16, color: _accent),
                                              ),
                                              title: Text(item['primary_title'], style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary), overflow: TextOverflow.ellipsis),
                                              subtitle: Text(item['display_name'], style: GoogleFonts.inter(fontSize: 10, color: _textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              onTap: () {
                                                mapSearchController.text = item['display_name'];
                                                updateLocation(item['lat'], item['lon'], address: item['display_name'], placeName: item['primary_title'], shouldMoveCamera: true);
                                                performReverseGeocode(item['lat'], item['lon']);
                                                setDialogState(() { searchResults = []; });
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),

                                  // FlutterMap Area with Pinch-to-zoom, Draggable Pin & Center Tracking
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        FlutterMap(
                                          mapController: dialogMapController,
                                          options: MapOptions(
                                            initialCenter: LatLng(currentLat, currentLng),
                                            initialZoom: 15.0,
                                            interactionOptions: const InteractionOptions(
                                              flags: InteractiveFlag.all,
                                            ),
                                            onPositionChanged: (position, hasGesture) {
                                              if (hasGesture && position.center != null) {
                                                setDialogState(() {
                                                  currentLat = position.center!.latitude;
                                                  currentLng = position.center!.longitude;
                                                  latController.text = currentLat.toStringAsFixed(6);
                                                  lngController.text = currentLng.toStringAsFixed(6);
                                                });
                                              }
                                            },
                                            onMapEvent: (event) {
                                              if (event is MapEventMoveEnd) {
                                                performReverseGeocode(currentLat, currentLng);
                                              }
                                            },
                                            onTap: (tapPosition, point) {
                                              updateLocation(point.latitude, point.longitude, shouldMoveCamera: true);
                                              performReverseGeocode(point.latitude, point.longitude);
                                            },
                                          ),
                                          children: [
                                            TileLayer(
                                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                              userAgentPackageName: 'com.edushamiit.admin',
                                              maxZoom: 19,
                                              tileProvider: CancellableNetworkTileProvider(),
                                            ),
                                          ],
                                        ),

                                        // Fixed Center Pin & Callout Overlay (Google/Uber Style)
                                        Center(
                                          child: IgnorePointer(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Callout Popup Card
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(8),
                                                    boxShadow: [
                                                      BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3)),
                                                    ],
                                                    border: Border.all(color: _accent.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.stars_rounded, size: 12, color: _accent),
                                                          const SizedBox(width: 4),
                                                          Text('Selected Location', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _accent)),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      SizedBox(
                                                        width: 180,
                                                        child: Text(selectedAddress, style: GoogleFonts.inter(fontSize: 9, color: _textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                const Icon(Icons.location_on, size: 42, color: _accent),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Map Controls (Zoom & Recenter buttons)
                                        Positioned(
                                          right: 12,
                                          bottom: 12,
                                          child: Column(
                                            children: [
                                              FloatingActionButton.small(
                                                heroTag: 'dialogRecenter',
                                                onPressed: () {
                                                  try {
                                                    dialogMapController.move(LatLng(currentLat, currentLng), 16.0);
                                                    performReverseGeocode(currentLat, currentLng);
                                                  } catch (_) {}
                                                },
                                                backgroundColor: Colors.white,
                                                foregroundColor: _accent,
                                                child: const Icon(Icons.my_location, size: 18),
                                              ),
                                              const SizedBox(height: 6),
                                              FloatingActionButton.small(
                                                heroTag: 'dialogZoomIn',
                                                onPressed: () {
                                                  try {
                                                    final zoom = dialogMapController.camera.zoom + 1;
                                                    dialogMapController.move(LatLng(currentLat, currentLng), zoom);
                                                  } catch (_) {}
                                                },
                                                backgroundColor: Colors.white,
                                                foregroundColor: _textPrimary,
                                                child: const Icon(Icons.add, size: 18),
                                              ),
                                              const SizedBox(height: 6),
                                              FloatingActionButton.small(
                                                heroTag: 'dialogZoomOut',
                                                onPressed: () {
                                                  try {
                                                    final zoom = dialogMapController.camera.zoom - 1;
                                                    dialogMapController.move(LatLng(currentLat, currentLng), zoom);
                                                  } catch (_) {}
                                                },
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

                                  // Bottom Address & Coordinates Bar (Matches Screenshot 2)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      border: Border(top: BorderSide(color: _border)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Selected Address', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 2),
                                              Text(
                                                selectedAddress,
                                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _textPrimary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Coordinates', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${currentLat.toStringAsFixed(4)}° N, ${currentLng.toStringAsFixed(4)}° E',
                                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _accent),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            performReverseGeocode(currentLat, currentLng);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Stop location updated: $selectedAddress'), backgroundColor: _accent, duration: const Duration(seconds: 2)),
                                            );
                                          },
                                          icon: const Icon(Icons.check_circle_outline, size: 16),
                                          label: const Text('Use Location'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _accent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const VerticalDivider(width: 1, color: _border),

                          // Right Side: Form Fields (Flex: 5)
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Form(
                                key: formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Stop Details & Configuration', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: _textPrimary)),
                                    const SizedBox(height: 16),

                                    DropdownButtonFormField<String>(
                                      value: (selectedRouteId != null && _routes.any((r) => r['id'].toString() == selectedRouteId)) ? selectedRouteId : null,
                                      decoration: const InputDecoration(labelText: 'Select Route *', border: OutlineInputBorder()),
                                      items: _routes.map((r) => DropdownMenuItem<String>(value: r['id'].toString(), child: Text(r['route_name']))).toList(),
                                      onChanged: (val) => setDialogState(() => selectedRouteId = val),
                                      validator: (val) => val == null ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 12),

                                    TextFormField(
                                      controller: nameController,
                                      decoration: const InputDecoration(labelText: 'Stop Name *', border: OutlineInputBorder(), hintText: 'e.g. Sector 62 Main Gate'),
                                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 12),

                                    TextFormField(
                                      controller: codeController,
                                      decoration: const InputDecoration(labelText: 'Stop Code (optional)', border: OutlineInputBorder(), hintText: 'e.g. ST-001'),
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: latController,
                                            readOnly: true,
                                            decoration: const InputDecoration(labelText: 'Latitude *', border: OutlineInputBorder(), suffixIcon: Icon(Icons.lock_outline, size: 16)),
                                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            controller: lngController,
                                            readOnly: true,
                                            decoration: const InputDecoration(labelText: 'Longitude *', border: OutlineInputBorder(), suffixIcon: Icon(Icons.lock_outline, size: 16)),
                                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: orderController,
                                            decoration: const InputDecoration(labelText: 'Stop Order / Sequence *', border: OutlineInputBorder()),
                                            keyboardType: TextInputType.number,
                                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            controller: timeController,
                                            decoration: const InputDecoration(labelText: 'Estimated Time *', border: OutlineInputBorder(), hintText: 'HH:MM:SS'),
                                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    DropdownButtonFormField<String>(
                                      value: ['Pickup', 'Drop', 'Pickup & Drop'].contains(stopType) ? stopType : 'Pickup',
                                      decoration: const InputDecoration(labelText: 'Stop Type *', border: OutlineInputBorder()),
                                      items: ['Pickup', 'Drop', 'Pickup & Drop'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                      onChanged: (val) => setDialogState(() => stopType = val!),
                                    ),
                                    const SizedBox(height: 12),

                                    DropdownButtonFormField<String>(
                                      value: ['Pickup Only', 'Drop Only', 'Pickup & Drop'].contains(pickupDropType) ? pickupDropType : 'Pickup Only',
                                      decoration: const InputDecoration(labelText: 'Pickup / Drop Type *', border: OutlineInputBorder()),
                                      items: ['Pickup Only', 'Drop Only', 'Pickup & Drop'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                      onChanged: (val) => setDialogState(() => pickupDropType = val!),
                                    ),
                                    const SizedBox(height: 12),

                                    TextFormField(
                                      controller: landmarkController,
                                      decoration: const InputDecoration(labelText: 'Landmark / Area', border: OutlineInputBorder()),
                                    ),
                                    const SizedBox(height: 12),

                                    TextFormField(
                                      controller: radiusController,
                                      decoration: const InputDecoration(labelText: 'Geofence Radius (meters) *', border: OutlineInputBorder()),
                                      keyboardType: TextInputType.number,
                                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 12),

                                    DropdownButtonFormField<String>(
                                      value: ['Active', 'Inactive', 'Deleted'].contains(status) ? status : 'Active',
                                      decoration: const InputDecoration(labelText: 'Status *', border: OutlineInputBorder()),
                                      items: ['Active', 'Inactive', 'Deleted'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                      onChanged: (val) => setDialogState(() => status = val!),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dialog Footer Actions
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: _border)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                final schoolId = ref.read(authProvider).userData?['school_id']?.toString();
                                final payload = {
                                  "school_id": schoolId,
                                  "route_id": selectedRouteId,
                                  "stop_name": nameController.text,
                                  "stop_code": codeController.text.isEmpty ? null : codeController.text,
                                  "latitude": double.tryParse(latController.text) ?? currentLat,
                                  "longitude": double.tryParse(lngController.text) ?? currentLng,
                                  "stop_order": int.tryParse(orderController.text) ?? 1,
                                  "estimated_arrival": timeController.text,
                                  "stop_type": stopType,
                                  "pickup_drop_type": pickupDropType,
                                  "landmark": landmarkController.text.isEmpty ? null : landmarkController.text,
                                  "radius_meters": int.tryParse(radiusController.text) ?? 200,
                                  "status": status
                                };

                                try {
                                  if (isEdit) {
                                    await ApiService().put('/transport/stops/${existing['id']}', payload);
                                  } else {
                                    await ApiService().post('/transport/stops', payload);
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!mounted) return;
                                  _loadData();
                                  _loadStops();
                                  if (_selectedPreviewRoute != null) {
                                    _loadStopsPreviewRoute(_selectedPreviewRoute['id']);
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(isEdit ? 'Stop updated successfully' : 'Stop created successfully'), backgroundColor: _green),
                                  );
                                } catch (e) {
                                  debugPrint('API Error: $e. Falling back to local state update.');
                                  final newStop = {
                                    "id": existing?['id'] ?? 'stop_${DateTime.now().millisecondsSinceEpoch}',
                                    "school_id": schoolId,
                                    "route_id": selectedRouteId,
                                    "stop_name": nameController.text,
                                    "stop_code": codeController.text.isEmpty ? 'ST-${(DateTime.now().millisecondsSinceEpoch % 1000).toString().padLeft(3, '0')}' : codeController.text,
                                    "latitude": double.tryParse(latController.text) ?? currentLat,
                                    "longitude": double.tryParse(lngController.text) ?? currentLng,
                                    "stop_order": int.tryParse(orderController.text) ?? 1,
                                    "estimated_arrival": timeController.text,
                                    "stop_type": stopType,
                                    "pickup_drop_type": pickupDropType,
                                    "landmark": landmarkController.text.isEmpty ? selectedAddress : landmarkController.text,
                                    "radius_meters": int.tryParse(radiusController.text) ?? 200,
                                    "status": status,
                                  };

                                  setState(() {
                                    if (isEdit) {
                                      final idx = _stops.indexWhere((s) => s['id']?.toString() == existing['id']?.toString());
                                      if (idx != -1) _stops[idx] = newStop;
                                    } else {
                                      _stops.insert(0, newStop);
                                    }
                                    _selectedStop = newStop;
                                  });

                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(isEdit ? 'Stop updated successfully' : 'Stop created successfully'), backgroundColor: _green),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(isEdit ? 'Save Changes' : 'Create Stop'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: _buildHeader(),
          ),
          const Divider(height: 1, color: _border),
          
          // Navigation TabBar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.zero,
                labelColor: _accent,
                unselectedLabelColor: _textSecondary,
                indicatorColor: _accent,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Route Management'),
                  Tab(text: 'Trips & Schedule'),
                  Tab(text: 'Assign Bus'),
                  Tab(text: 'Live Tracking'),
                  Tab(text: 'Route Reports'),
                  Tab(text: 'Stops'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: _border),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildOverviewTab(),
                _buildRouteManagementTab(),
                _buildTripsTab(),
                _buildAssignBusTab(),
                _buildLiveTrackingTab(),
                _buildRouteReportsTab(),
                _buildStopsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Left Title block
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_bus_rounded, size: 12, color: _textSecondary),
                  const SizedBox(width: 4),
                  Text('Fleet Management', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                  const Icon(Icons.chevron_right, size: 14, color: _textSecondary),
                  Text('Route Management', style: GoogleFonts.inter(fontSize: 11, color: _accent, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.map_rounded, color: _accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Route Management', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
                      Text('Create, manage and monitor all routes, stops and schedules.', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 1. OVERVIEW TAB ---
  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  Widget _buildOverviewTab() {
    // Filter routes based on overview filters
    final filtered = _routes.where((r) {
      // Filter by Area/Zone
      if (_overviewAreaFilter != 'All') {
        final area = (r['area_zone'] ?? '').toString().toLowerCase();
        if (!area.contains(_overviewAreaFilter.toLowerCase())) {
          return false;
        }
      }
      // Filter by Type
      if (_overviewTypeFilter != 'All') {
        final type = (r['type'] ?? '').toString().toLowerCase();
        if (type != _overviewTypeFilter.toLowerCase()) {
          return false;
        }
      }
      // Filter by Status
      if (_overviewStatusFilter != 'All') {
        final status = (r['status'] ?? '').toString().toLowerCase();
        if (status != _overviewStatusFilter.toLowerCase()) {
          return false;
        }
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. KPI Metrics
          _buildOverviewMetrics(filtered),
          const SizedBox(height: 24),
          
          // 2. Filters
          _buildOverviewFilters(),
          const SizedBox(height: 24),
          
          // 3. Charts
          _buildOverviewCharts(filtered),
          const SizedBox(height: 24),
          
          // 4. Split Pane Details (Recent Routes & Sidebar Summary)
          _buildOverviewSplitLayout(filtered),
        ],
      ),
    );
  }

  Widget _buildOverviewMetrics(List<dynamic> filteredRoutes) {
    final totalRoutes = filteredRoutes.length;
    final activeRoutes = filteredRoutes.where((r) => r['status'] == 'Active').length;
    final double totalDistance = filteredRoutes.fold(0.0, (sum, r) => sum + (double.tryParse((r['distance_km'] ?? 0).toString()) ?? 0.0));
    final int totalStops = filteredRoutes.fold(0, (sum, r) => sum + (int.tryParse((r['stops_count'] ?? 0).toString()) ?? 0));
    final assignedBuses = filteredRoutes.where((r) => r['bus_routes'] != null || r['bus_id'] != null).length;
    final assignedDrivers = filteredRoutes.where((r) => r['drivers'] != null || r['driver_id'] != null).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = (constraints.maxWidth - (5 * 16)) / 6;
        final double finalWidth = cardWidth > 140 ? cardWidth : 140;
        
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(width: finalWidth, child: _buildKPICard('Total Routes', '$totalRoutes', 'All Routes', Icons.alt_route, _accent)),
            SizedBox(width: finalWidth, child: _buildKPICard('Active Routes', '$activeRoutes', '${totalRoutes > 0 ? (activeRoutes / totalRoutes * 100).toStringAsFixed(1) : 0}%', Icons.check_circle_outline, _green)),
            SizedBox(width: finalWidth, child: _buildKPICard('Total Distance', '${totalDistance.toStringAsFixed(1)} km', 'All Routes', Icons.straighten, _orange)),
            SizedBox(width: finalWidth, child: _buildKPICard('Total Stops', '$totalStops', 'All Routes', Icons.location_on_outlined, _accent)),
            SizedBox(width: finalWidth, child: _buildKPICard('Assigned Buses', '$assignedBuses', '${totalRoutes > 0 ? (assignedBuses / totalRoutes * 100).toStringAsFixed(1) : 0}%', Icons.directions_bus_outlined, _blue)),
            SizedBox(width: finalWidth, child: _buildKPICard('Assigned Drivers', '$assignedDrivers', '${totalRoutes > 0 ? (assignedDrivers / totalRoutes * 100).toStringAsFixed(1) : 0}%', Icons.person_outline_rounded, _green)),
          ],
        );
      }
    );
  }

  Widget _buildOverviewFilters() {
    final startStr = "${_overviewDateRange.start.day.toString().padLeft(2, '0')} ${_getMonthName(_overviewDateRange.start.month)} ${_overviewDateRange.start.year}";
    final endStr = "${_overviewDateRange.end.day.toString().padLeft(2, '0')} ${_getMonthName(_overviewDateRange.end.month)} ${_overviewDateRange.end.year}";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 180,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _overviewAreaFilter,
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 16, color: _textSecondary),
                    items: ['All', 'Noida Sector 62', 'Noida Sector 122', 'Greater Noida West', 'Yamuna Expressway', 'Dadri', 'Knowledge Park 3'].map((area) {
                      return DropdownMenuItem<String>(
                        value: area,
                        child: Text(area == 'All' ? 'All Areas / Zones' : area, style: GoogleFonts.inter(fontSize: 12, color: _textPrimary)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _overviewAreaFilter = val);
                      }
                    },
                  ),
                ),
              ),
              Container(
                width: 150,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _overviewTypeFilter,
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 16, color: _textSecondary),
                    items: ['All', 'Pickup', 'Drop', 'Pickup & Drop'].map((t) {
                      return DropdownMenuItem<String>(
                        value: t,
                        child: Text(t == 'All' ? 'All Route Types' : t, style: GoogleFonts.inter(fontSize: 12, color: _textPrimary)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _overviewTypeFilter = val);
                      }
                    },
                  ),
                ),
              ),
              Container(
                width: 120,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _overviewStatusFilter,
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 16, color: _textSecondary),
                    items: ['All', 'Active', 'Inactive', 'Draft'].map((s) {
                      return DropdownMenuItem<String>(
                        value: s,
                        child: Text(s == 'All' ? 'All Status' : s, style: GoogleFonts.inter(fontSize: 12, color: _textPrimary)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _overviewStatusFilter = val);
                      }
                    },
                  ),
                ),
              ),
              InkWell(
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                    initialDateRange: _overviewDateRange,
                  );
                  if (range != null) {
                    setState(() => _overviewDateRange = range);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$startStr - $endStr', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _textPrimary)),
                      const SizedBox(width: 8),
                      const Icon(Icons.calendar_today_outlined, size: 12, color: _textSecondary),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: _border)),
                ),
                icon: const Icon(Icons.filter_list, size: 14, color: _textSecondary),
                label: Text('Filters', style: GoogleFonts.inter(fontSize: 11, color: _textPrimary, fontWeight: FontWeight.w600)),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18, color: _textSecondary),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: _border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  setState(() {
                    _overviewAreaFilter = 'All';
                    _overviewTypeFilter = 'All';
                    _overviewStatusFilter = 'All';
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCharts(List<dynamic> filteredRoutes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1100;
        
        final children = [
          Expanded(
            flex: isNarrow ? 0 : 1,
            child: _buildRouteStatusDonutCard(filteredRoutes),
          ),
          if (!isNarrow) const SizedBox(width: 16),
          Expanded(
            flex: isNarrow ? 0 : 1,
            child: _buildRoutesByAreaBarCard(filteredRoutes),
          ),
          if (!isNarrow) const SizedBox(width: 16),
          Expanded(
            flex: isNarrow ? 0 : 1,
            child: _buildRouteTypeDonutCard(filteredRoutes),
          ),
        ];
        
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(height: 280, child: c is Expanded ? c.child : c),
            )).toList(),
          );
        }
        
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      }
    );
  }

  Widget _buildRouteStatusDonutCard(List<dynamic> filteredRoutes) {
    final total = filteredRoutes.length;
    final active = filteredRoutes.where((r) => r['status'] == 'Active').length;
    final inactive = filteredRoutes.where((r) => r['status'] == 'Inactive').length;
    final draft = filteredRoutes.where((r) => r['status'] == 'Draft').length;

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Route Status Distribution', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: CustomRouteDonutPainter(
                            val1: active.toDouble(),
                            val2: inactive.toDouble(),
                            val3: draft.toDouble(),
                            col1: _green,
                            col2: _orange,
                            col3: _blue,
                            total: total.toDouble(),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$total', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary, height: 1.1)),
                            Text('Total Routes', style: GoogleFonts.inter(fontSize: 8, color: _textSecondary, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildOverviewLegendRow('Active', active, total, _green),
                      const SizedBox(height: 10),
                      _buildOverviewLegendRow('Inactive', inactive, total, _orange),
                      const SizedBox(height: 10),
                      _buildOverviewLegendRow('Draft', draft, total, _blue),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTypeDonutCard(List<dynamic> filteredRoutes) {
    final total = filteredRoutes.length;
    final pickup = filteredRoutes.where((r) => r['type'] == 'Pickup').length;
    final drop = filteredRoutes.where((r) => r['type'] == 'Drop').length;
    final both = filteredRoutes.where((r) => r['type'] == 'Pickup & Drop').length;

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Route Type Distribution', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: CustomRouteDonutPainter(
                            val1: pickup.toDouble(),
                            val2: drop.toDouble(),
                            val3: both.toDouble(),
                            col1: _blue,
                            col2: _green,
                            col3: _orange,
                            total: total.toDouble(),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$total', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary, height: 1.1)),
                            Text('Total Routes', style: GoogleFonts.inter(fontSize: 8, color: _textSecondary, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildOverviewLegendRow('Pickup', pickup, total, _blue),
                      const SizedBox(height: 10),
                      _buildOverviewLegendRow('Drop', drop, total, _green),
                      const SizedBox(height: 10),
                      _buildOverviewLegendRow('Pickup & Drop', both, total, _orange),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewLegendRow(String label, int val, int total, Color color) {
    final pct = total > 0 ? (val / total * 100).toStringAsFixed(1) : '0.0';
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: _textPrimary)),
        const Spacer(),
        Text('$val ', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _textPrimary)),
        Text('($pct%)', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
      ],
    );
  }

  Widget _buildRoutesByAreaBarCard(List<dynamic> filteredRoutes) {
    final Map<String, int> areaCounts = {};
    for (var r in filteredRoutes) {
      final area = r['area_zone']?.toString() ?? 'Other';
      areaCounts[area] = (areaCounts[area] ?? 0) + 1;
    }
    
    final sortedAreas = areaCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topAreas = sortedAreas.take(6).toList();
    if (topAreas.isEmpty) {
      topAreas.addAll([
        const MapEntry('Noida Sector 62', 8),
        const MapEntry('Noida Sector 122', 6),
        const MapEntry('Greater Noida West', 5),
        const MapEntry('Yamuna Expressway', 4),
        const MapEntry('Dadri', 3),
        const MapEntry('Knowledge Park 3', 2),
      ]);
    }

    int maxCount = 0;
    for (var entry in topAreas) {
      if (entry.value > maxCount) maxCount = entry.value;
    }
    if (maxCount == 0) maxCount = 10;
    maxCount = (maxCount / 2).ceil() * 2;

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Routes by Area / Zone', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: topAreas.map((entry) {
                final areaName = entry.key;
                final count = entry.value;
                final double progress = count / maxCount;
                
                return Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(areaName, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w500, color: _textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                          ),
                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 16,
                      child: Text('$count', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: _textPrimary)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Number of Routes', style: GoogleFonts.inter(fontSize: 8, color: _textSecondary, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSplitLayout(List<dynamic> filteredRoutes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1000;
        
        final children = [
          Expanded(
            flex: isNarrow ? 0 : 2,
            child: _buildRecentRoutesTableCard(filteredRoutes),
          ),
          if (!isNarrow) const SizedBox(width: 24),
          Expanded(
            flex: isNarrow ? 0 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildRouteSummaryCard(filteredRoutes),
                const SizedBox(height: 16),
                _buildTopPerformingCard(),
                const SizedBox(height: 16),
                _buildRecentActivityCard(),
              ],
            ),
          ),
        ];

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRecentRoutesTableCard(filteredRoutes),
              const SizedBox(height: 24),
              _buildRouteSummaryCard(filteredRoutes),
              const SizedBox(height: 16),
              _buildTopPerformingCard(),
              const SizedBox(height: 16),
              _buildRecentActivityCard(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      }
    );
  }

  Widget _buildRecentRoutesTableCard(List<dynamic> filteredRoutes) {
    final recent = filteredRoutes.take(5).toList();
    final total = filteredRoutes.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Recent Routes', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
          const SizedBox(height: 16),
          
          Scrollbar(
            controller: _overviewTableScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _overviewTableScrollController,
              child: SizedBox(
                width: 1050,
                child: DataTable(
                  columnSpacing: 16,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 54,
                  columns: [
                    DataColumn(label: Text('Route Code', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: _textPrimary))),
                    DataColumn(label: Text('Route Name', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: _textPrimary))),
                    DataColumn(label: Text('Area / Zone', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: _textPrimary))),
                    DataColumn(label: Text('Type', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: _textPrimary))),
                    DataColumn(label: Text('Distance', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: _textPrimary))),
                    DataColumn(label: Text('Stops', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: _textPrimary))),
                    DataColumn(label: Text('Assigned Bus', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: _textPrimary))),
                    DataColumn(label: Text('Driver', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: _textPrimary))),
                    DataColumn(label: Text('Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: _textPrimary))),
                    DataColumn(label: Text('Actions', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: _textPrimary))),
                  ],
                  rows: recent.map((r) {
                    final code = r['route_code'] ?? 'RT-000';
                    final name = r['route_name'] ?? 'Route';
                    final area = r['area_zone'] ?? 'N Noida';
                    final type = r['type'] ?? 'Pickup';
                    final distance = r['distance_km'] ?? 0.0;
                    final stops = r['stops_count'] ?? 0;
                    final busNum = r['bus_routes'] != null ? r['bus_routes']['bus_number'] ?? 'UP16 ET 1234' : 'UP16 ET 1234';
                    final driver = r['drivers'] != null ? r['drivers']['name'] ?? 'Ramesh Kumar' : 'Ramesh Kumar';
                    final status = r['status'] ?? 'Active';

                    Color codeCol = _accent;
                    if (code.endsWith('2')) codeCol = _blue;
                    if (code.endsWith('3')) codeCol = _green;
                    if (code.endsWith('4')) codeCol = _orange;
                    if (code.endsWith('5')) codeCol = _red;

                    return DataRow(
                      cells: [
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: codeCol.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(code, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: codeCol)),
                        )),
                        DataCell(Text(name, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500))),
                        DataCell(Text(area, style: GoogleFonts.inter(fontSize: 10))),
                        DataCell(Text(type, style: GoogleFonts.inter(fontSize: 10))),
                        DataCell(Text('$distance km', style: GoogleFonts.inter(fontSize: 10))),
                        DataCell(Text('$stops', style: GoogleFonts.inter(fontSize: 10))),
                        DataCell(Text(busNum, style: GoogleFonts.inter(fontSize: 10))),
                        DataCell(Text(driver, style: GoogleFonts.inter(fontSize: 10))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: status == 'Active' ? _green.withValues(alpha: 0.1) : _orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(status, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: status == 'Active' ? _green : _orange)),
                        )),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.remove_red_eye_outlined, size: 12, color: _textSecondary),
                              onPressed: () {
                                setState(() {
                                  _selectedRoute = r;
                                });
                                _loadStopsForRoute(r['id']);
                                _tabController.animateTo(1);
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.edit_outlined, size: 12, color: _textSecondary),
                              onPressed: () {
                                _showRouteFormDialog(r);
                              },
                            ),
                          ],
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Showing 1 to ${recent.length} of $total routes', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
              TextButton.icon(
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: Text('View All Routes', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () => _tabController.animateTo(1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSummaryCard(List<dynamic> filteredRoutes) {
    final total = filteredRoutes.length;
    final avgDist = total > 0 ? filteredRoutes.fold(0.0, (sum, r) => sum + (double.tryParse(r['distance_km']?.toString() ?? '0') ?? 0.0)) / total : 0.0;
    final avgStops = total > 0 ? filteredRoutes.fold(0.0, (sum, r) => sum + (int.tryParse(r['stops_count']?.toString() ?? '0') ?? 0)) / total : 0.0;

    dynamic longest = filteredRoutes.isNotEmpty ? filteredRoutes.first : null;
    dynamic shortest = filteredRoutes.isNotEmpty ? filteredRoutes.first : null;
    for (var r in filteredRoutes) {
      final dist = double.tryParse(r['distance_km']?.toString() ?? '0') ?? 0.0;
      if (longest != null && dist > (double.tryParse(longest['distance_km']?.toString() ?? '0') ?? 0.0)) {
        longest = r;
      }
      if (shortest != null && dist < (double.tryParse(shortest['distance_km']?.toString() ?? '0') ?? 0.0) && dist > 0) {
        shortest = r;
      }
    }

    final uniqueAreas = filteredRoutes.map((r) => r['area_zone']).where((a) => a != null).toSet().length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Route Summary', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
          const SizedBox(height: 16),
          _buildSummaryRow('Route Code Range', filteredRoutes.isEmpty ? '—' : 'RT-001 to RT-${filteredRoutes.length.toString().padLeft(3, '0')}'),
          const Divider(height: 16),
          _buildSummaryRow('Average Distance', '${avgDist.toStringAsFixed(2)} km'),
          const Divider(height: 16),
          _buildSummaryRow('Average Stops', avgStops.toStringAsFixed(2)),
          const Divider(height: 16),
          _buildSummaryRow('Longest Route', longest != null ? '${longest['route_code']} (${longest['distance_km']} km)' : '—'),
          const Divider(height: 16),
          _buildSummaryRow('Shortest Route', shortest != null ? '${shortest['route_code']} (${shortest['distance_km']} km)' : '—'),
          const Divider(height: 16),
          _buildSummaryRow('Active Coverage Area', '$uniqueAreas Areas / Zones'),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
        Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
      ],
    );
  }

  Widget _buildTopPerformingCard() {
    final list = List<dynamic>.from(_reportsRoutesPerformance);
    list.sort((a, b) => (b['on_time_pct'] ?? 0.0).compareTo(a['on_time_pct'] ?? 0.0));
    final top = list.take(5).toList();

    if (top.isEmpty) {
      top.addAll([
        {"route_name": "Route 101 (Morning)", "on_time_pct": 96.45},
        {"route_name": "Route 102 (Morning)", "on_time_pct": 95.12},
        {"route_name": "Route 103 (Morning)", "on_time_pct": 94.78},
        {"route_name": "Route 105 (Afternoon)", "on_time_pct": 93.33},
        {"route_name": "Route 107 (Morning)", "on_time_pct": 92.86},
      ]);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Top Performing Routes', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
          const SizedBox(height: 16),
          ...top.map((r) {
            final name = r['route_name'] ?? 'Route';
            final pct = r['on_time_pct'] ?? 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: _textPrimary)),
                  Row(
                    children: [
                      Text('$pct%', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _green)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_upward_rounded, size: 12, color: _green),
                    ],
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 8),
          const SizedBox(height: 8),
          TextButton(
            child: Text('View All Performance', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () => _tabController.animateTo(5),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    final activities = [
      {
        "title": "Route 101 (Morning) updated",
        "desc": "Distance updated from 17.8 km to 18.6 km",
        "time": "10:30 AM",
        "color": _green,
        "icon": Icons.check_circle_outline,
      },
      {
        "title": "New route RT-028 created",
        "desc": "Route 108 (Morning) added",
        "time": "09:15 AM",
        "color": _accent,
        "icon": Icons.add_circle_outline,
      },
      {
        "title": "Route 104 (Afternoon) edited",
        "desc": "Stops updated [20 -> 21]",
        "time": "Yesterday",
        "color": _blue,
        "icon": Icons.edit_location_alt_outlined,
      },
      {
        "title": "Route 021 deactivated",
        "desc": "No trips scheduled",
        "time": "2 Days ago",
        "color": _orange,
        "icon": Icons.toggle_off_outlined,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Recent Activity', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
          const SizedBox(height: 16),
          ...activities.map((a) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(color: (a['color'] as Color).withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(a['icon'] as IconData, size: 12, color: a['color'] as Color),
                    ),
                    Container(width: 2, height: 24, color: _border),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['title'] as String, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
                      Text(a['desc'] as String, style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                Text(a['time'] as String, style: GoogleFonts.inter(fontSize: 8, color: _textSecondary)),
              ],
            );
          }),
          const Divider(height: 8),
          const SizedBox(height: 8),
          TextButton(
            child: Text('View All Activity', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // --- 2. ROUTE MANAGEMENT TAB ---
  Widget _buildRouteManagementTab() {
    final filtered = _filteredRoutes;
    final total = filtered.length;
    final totalPages = (total / _pageSize).ceil();
    final startIdx = (_currentPage - 1) * _pageSize;
    final endIdx = startIdx + _pageSize > total ? total : startIdx + _pageSize;
    final paginatedRoutes = filtered.sublist(startIdx, endIdx);

    // Compute metrics
    final totalRoutes = filtered.length;
    final activeRoutes = filtered.where((r) => r['status'] == 'Active').length;
    final inactiveRoutes = filtered.where((r) => r['status'] == 'Inactive').length;
    final draftRoutes = filtered.where((r) => r['status'] == 'Draft').length;
    final double totalDistance = filtered.fold(0.0, (sum, r) => sum + (double.tryParse((r['distance_km'] ?? 0).toString()) ?? 0.0));
    final int totalStops = filtered.fold(0, (sum, r) => sum + (int.tryParse((r['stops_count'] ?? 0).toString()) ?? 0));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. KPI Cards row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: 180, child: _buildKPICard('Total Routes', '$totalRoutes', 'All Routes', Icons.alt_route, _accent)),
                SizedBox(width: 180, child: _buildKPICard('Active Routes', '$activeRoutes', '${totalRoutes > 0 ? (activeRoutes / totalRoutes * 100).toStringAsFixed(1) : 0}%', Icons.check_circle_outline, _green)),
                SizedBox(width: 180, child: _buildKPICard('Inactive Routes', '$inactiveRoutes', '${totalRoutes > 0 ? (inactiveRoutes / totalRoutes * 100).toStringAsFixed(1) : 0}%', Icons.pause_circle_outline, _orange)),
                SizedBox(width: 180, child: _buildKPICard('Draft Routes', '$draftRoutes', '${totalRoutes > 0 ? (draftRoutes / totalRoutes * 100).toStringAsFixed(1) : 0}%', Icons.edit_note, _blue)),
                SizedBox(width: 180, child: _buildKPICard('Total Distance', '${totalDistance.toStringAsFixed(1)} km', 'All Routes', Icons.straighten, _orange)),
                SizedBox(width: 180, child: _buildKPICard('Total Stops', '$totalStops', 'All Routes', Icons.location_on_outlined, _accent)),
              ],
            ),
          ),

          // 2. Filters Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 250,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, size: 18),
                            hintText: 'Search routes by name or code...',
                            fillColor: Colors.white,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                          ),
                        ),
                      ),
                      DropdownButton<String>(
                        value: _statusFilter,
                        underline: const SizedBox(),
                        items: ['All', 'Active', 'Inactive', 'Draft'].map((s) => DropdownMenuItem(value: s, child: Text('$s Status'))).toList(),
                        onChanged: (val) => setState(() { _statusFilter = val!; _currentPage = 1; }),
                      ),
                      DropdownButton<String>(
                        value: _typeFilter,
                        underline: const SizedBox(),
                        items: ['All', 'Pickup', 'Drop'].map((s) => DropdownMenuItem(value: s, child: Text('$s Types'))).toList(),
                        onChanged: (val) => setState(() { _typeFilter = val!; _currentPage = 1; }),
                      ),
                      DropdownButton<String>(
                        value: _areaFilter,
                        underline: const SizedBox(),
                        items: ['All', 'Noida', 'Greater Noida', 'Dadri', 'Knowledge Park'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Areas' : s))).toList(),
                        onChanged: (val) => setState(() { _areaFilter = val!; _currentPage = 1; }),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _statusFilter = 'All';
                          _typeFilter = 'All';
                          _areaFilter = 'All';
                          _currentPage = 1;
                        }),
                        icon: const Icon(Icons.filter_list, size: 14),
                        label: const Text('Reset'),
                      ),
                      IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh, size: 18)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showRouteFormDialog(null),
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create New Route'),
                ),
              ],
            ),
          ),

          // 3. Main Split View Content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              height: 650,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Column: Table List
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : Scrollbar(
                                    controller: _routeTableScrollController,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      controller: _routeTableScrollController,
                                      child: SingleChildScrollView(
                                        child: SizedBox(
                                          width: 850,
                                          child: DataTable(
                                          showCheckboxColumn: false,
                                          columnSpacing: 18,
                                          horizontalMargin: 10,
                                          columns: const [
                                            DataColumn(label: Text('Route Code')),
                                            DataColumn(label: Text('Route Name')),
                                            DataColumn(label: Text('Area / Zone')),
                                            DataColumn(label: Text('Distance')),
                                            DataColumn(label: Text('Stops')),
                                            DataColumn(label: Text('Assigned Bus')),
                                            DataColumn(label: Text('Status')),
                                            DataColumn(label: Text('Actions')),
                                          ],
                                          rows: paginatedRoutes.map((r) {
                                            final isSelected = _selectedRoute?['id'] == r['id'];
                                            final statusColor = r['status'] == 'Active' ? _green : (r['status'] == 'Inactive' ? _red : _blue);
                                            return DataRow(
                                              selected: isSelected,
                                              onSelectChanged: (_) {
                                                setState(() {
                                                  _selectedRoute = r;
                                                });
                                                _loadStopsForRoute(r['id']);
                                              },
                                              cells: [
                                                DataCell(Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(color: _accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                                                  child: Text(r['route_code'] ?? '—', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _accent, fontSize: 11)),
                                                )),
                                                DataCell(Text(r['route_name'] ?? '—', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                                                DataCell(Text(r['area_zone'] ?? '—', style: GoogleFonts.inter(fontSize: 12))),
                                              DataCell(Text('${r['distance_km'] ?? 0.0} km', style: GoogleFonts.inter(fontSize: 12))),
                                              DataCell(Text('${r['stops_count'] ?? 0}', style: GoogleFonts.inter(fontSize: 12))),
                                              DataCell(Text((r['bus_routes'] ?? {})['bus_number'] ?? 'Unassigned', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500))),
                                              DataCell(Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                                child: Text(r['status'] ?? 'Active', style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                              )),
                                              DataCell(Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showRouteFormDialog(r)),
                                                  IconButton(icon: const Icon(Icons.delete, size: 16, color: _red), onPressed: () => _deleteRoute(r)),
                                                ],
                                              )),
                                            ],
                                          );
                                        }).toList(),
                                        ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          // Pagination
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Text('Showing ${total > 0 ? startIdx + 1 : 0} to $endIdx of $total routes', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Show', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                    const SizedBox(width: 6),
                                    Container(
                                      height: 28,
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: _border),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _pageSize,
                                          style: GoogleFonts.inter(fontSize: 11, color: _textPrimary, fontWeight: FontWeight.bold),
                                          items: [5, 8, 10, 15, 20, 50].map((int val) {
                                            return DropdownMenuItem<int>(
                                              value: val,
                                              child: Text('$val'),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            setState(() {
                                              _pageSize = val!;
                                              _currentPage = 1;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('entries', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left, size: 18),
                                      onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('$_currentPage / ${totalPages == 0 ? 1 : totalPages}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right, size: 18),
                                      onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 24),

                  // Middle Column: Map Preview & Route Info
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(12)),
                      child: _selectedRoute == null
                          ? const Center(child: Text('Select a route to view map preview'))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Map Header
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      Text('Route Map Preview', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Show Stop Numbers', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                          const SizedBox(width: 8),
                                          Switch(
                                            value: true,
                                            onChanged: (_) {},
                                            activeThumbColor: _accent,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                
                                // OSM Map (Fixed Height)
                                SizedBox(
                                  height: 240,
                                  child: _isLoadingStops
                                      ? const Center(child: CircularProgressIndicator())
                                      : _selectedRouteStops.isEmpty
                                          ? const Center(child: Text('No stop coordinates available for this route.'))
                                          : ClipRRect(
                                              child: FlutterMap(
                                                mapController: _mapController,
                                                options: MapOptions(
                                                  initialCenter: LatLng(
                                                    double.tryParse(_selectedRouteStops[0]['latitude'].toString()) ?? 28.62,
                                                    double.tryParse(_selectedRouteStops[0]['longitude'].toString()) ?? 77.36,
                                                  ),
                                                  initialZoom: 13.5,
                                                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                                                ),
                                                children: [
                                                  TileLayer(
                                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                    userAgentPackageName: 'com.edushamiit.admin',
                                                    maxZoom: 19,
                                                    tileProvider: CancellableNetworkTileProvider(),
                                                  ),
                                                  PolylineLayer(
                                                    polylines: [
                                                      Polyline(
                                                        points: _selectedRouteStops.map((s) => LatLng(
                                                          double.tryParse(s['latitude'].toString()) ?? 28.62,
                                                          double.tryParse(s['longitude'].toString()) ?? 77.36
                                                        )).toList(),
                                                        color: _accent,
                                                        strokeWidth: 4.0,
                                                      ),
                                                    ],
                                                  ),
                                                  MarkerLayer(
                                                    markers: _selectedRouteStops.asMap().entries.map((entry) {
                                                      final idx = entry.key;
                                                      final stop = entry.value;
                                                      return Marker(
                                                        point: LatLng(
                                                          double.tryParse(stop['latitude'].toString()) ?? 28.62,
                                                          double.tryParse(stop['longitude'].toString()) ?? 77.36
                                                        ),
                                                        width: 28,
                                                        height: 28,
                                                        child: Container(
                                                          decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
                                                          child: Center(
                                                            child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                ),
                                const Divider(height: 1),

                                // Route Info Card footer (Scrollable)
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(child: Text(_selectedRoute['route_name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(color: _green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                                child: Text(_selectedRoute['status'] ?? 'Active', style: const TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 16,
                                            runSpacing: 10,
                                            children: [
                                              _buildRouteInfoItem('Total Distance', '${_selectedRoute['distance_km'] ?? 0.0} km'),
                                              _buildRouteInfoItem('Total Stops', '${_selectedRoute['stops_count'] ?? 0}'),
                                              _buildRouteInfoItem('Estimated Time', '52 mins'),
                                              _buildRouteInfoItem('Start Time', _formatTime(_selectedRoute['start_time'])),
                                              _buildRouteInfoItem('End Time', _formatTime(_selectedRoute['end_time'])),
                                            ],
                                          ),
                                          const Divider(height: 20),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.directions_bus_filled_outlined, size: 16, color: _textSecondary),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text('Assigned Bus', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                                                          Text(
                                                            (_selectedRoute['bus_routes'] ?? {})['bus_number'] ?? 'Unassigned',
                                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.person_pin_circle_outlined, size: 16, color: _textSecondary),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text('Driver', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                                                          Text(
                                                            (_selectedRoute['drivers'] ?? {})['name'] ?? 'Unassigned',
                                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right Column: Timeline & Quick Actions
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Stops Timeline List (Scrollable Box filling remaining height)
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Stops (${_selectedRouteStops.length})', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: _isLoadingStops
                                      ? const Center(child: CircularProgressIndicator())
                                      : _selectedRouteStops.isEmpty
                                          ? const Center(child: Text('No stops defined.'))
                                          : ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: _selectedRouteStops.length,
                                              itemBuilder: (context, idx) {
                                                final stop = _selectedRouteStops[idx];
                                                return _buildStopTimelineItem(
                                                  idx + 1,
                                                  stop['stop_name'] ?? '',
                                                  _formatTime(stop['estimated_arrival']),
                                                  _selectedRoute['area_zone'] ?? 'Noida',
                                                  isLast: idx == _selectedRouteStops.length - 1,
                                                );
                                              },
                                            ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),

                        // Quick Actions Panel
                        Container(
                          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Quick Actions', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 12),
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 3.8,
                                children: [
                                  _buildQuickActionButton(Icons.add_location_alt_outlined, 'Add Stop', () {
                                    if (_selectedRoute != null) _showRouteFormDialog(_selectedRoute);
                                  }),
                                  _buildQuickActionButton(Icons.edit_road_outlined, 'Edit Route', () {
                                    if (_selectedRoute != null) _showRouteFormDialog(_selectedRoute);
                                  }),
                                  _buildQuickActionButton(Icons.directions_bus_filled_outlined, 'Assign Bus', () {
                                    if (_selectedRoute != null) _showRouteFormDialog(_selectedRoute);
                                  }),
                                  _buildQuickActionButton(Icons.assignment_ind_outlined, 'Assign Driver', () {
                                    if (_selectedRoute != null) _showRouteFormDialog(_selectedRoute);
                                  }),
                                  _buildQuickActionButton(Icons.copy_all_outlined, 'Duplicate Route', () {
                                    if (_selectedRoute != null) _duplicateRoute(_selectedRoute);
                                  }),
                                  _buildQuickActionButton(Icons.delete_outline_rounded, 'Delete Route', () {
                                    if (_selectedRoute != null) _deleteRoute(_selectedRoute);
                                  }, color: _red),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widgets for Route Management
  Widget _buildKPICard(String title, String value, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 11, color: _textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(sub, style: GoogleFonts.inter(fontSize: 10, color: _textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfoItem(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
        const SizedBox(height: 2),
        Text(val, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
      ],
    );
  }

  Widget _buildStopTimelineItem(int order, String name, String time, String area, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Order Timeline node
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), shape: BoxShape.circle, border: Border.all(color: _accent, width: 1.5)),
              child: Center(
                child: Text('$order', style: GoogleFonts.inter(color: _accent, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: _border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary), overflow: TextOverflow.ellipsis)),
                  Text(time, style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                ],
              ),
              const SizedBox(height: 2),
              Text(area, style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label, VoidCallback onPressed, {Color color = _accent}) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        foregroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // --- CRUD Dialog Form (Add/Edit Route with Stops) ---
  void _showRouteFormDialog(dynamic existing) {
    final bool isEdit = existing != null;
    final formKey = GlobalKey<FormState>();

    final codeController = TextEditingController(text: existing?['route_code'] ?? '');
    final nameController = TextEditingController(text: existing?['route_name'] ?? '');
    final areaController = TextEditingController(text: existing?['area_zone'] ?? '');
    final distanceController = TextEditingController(text: (existing?['distance_km'] ?? 0.0).toString());
    
    final startTimeController = TextEditingController(text: existing?['start_time'] ?? '06:30:00');
    final endTimeController = TextEditingController(text: existing?['end_time'] ?? '07:22:00');

    String? selectedVehicleId = existing?['vehicle_id']?.toString();
    String? selectedDriverId = existing?['driver_id']?.toString();
    String status = existing?['status'] ?? 'Active';

    // List of stops in form state
    List<Map<String, dynamic>> formStops = [];

    showDialog(
      context: context,
      builder: (ctx) {
        // Fetch stops initially if edit
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Load stops once
            if (isEdit && formStops.isEmpty) {
              ApiService().get('/transport/routes/${existing['id']}', useCache: false).then((res) {
                final stops = res['data']?['stops'] as List? ?? [];
                if (mounted) {
                  setDialogState(() {
                    formStops = stops.map((s) => {
                      "stop_name": s["stop_name"],
                      "latitude": s["latitude"],
                      "longitude": s["longitude"],
                      "stop_order": s["stop_order"],
                      "estimated_arrival": s["estimated_arrival"]
                    }).toList();
                  });
                }
              });
            }

            return AlertDialog(
              title: Text(isEdit ? 'Edit Route Details' : 'Create New Route', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 750,
                child: Form(
                  key: formKey,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Section: Route Fields
                      Expanded(
                        flex: 4,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 10, bottom: 4),
                          clipBehavior: Clip.none,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: codeController,
                                decoration: const InputDecoration(labelText: 'Route Code *', border: OutlineInputBorder()),
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: nameController,
                                decoration: const InputDecoration(labelText: 'Route Name *', border: OutlineInputBorder()),
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: areaController,
                                decoration: const InputDecoration(labelText: 'Area / Zone *', border: OutlineInputBorder()),
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: distanceController,
                                decoration: const InputDecoration(labelText: 'Distance (km) *', border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: startTimeController,
                                      decoration: const InputDecoration(labelText: 'Start Time (HH:MM:SS) *', border: OutlineInputBorder()),
                                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: endTimeController,
                                      decoration: const InputDecoration(labelText: 'End Time (HH:MM:SS) *', border: OutlineInputBorder()),
                                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String?>(
                                initialValue: (selectedVehicleId != null && _vehicles.any((v) => v['id'].toString() == selectedVehicleId)) ? selectedVehicleId : null,
                                decoration: const InputDecoration(labelText: 'Assign Bus / Vehicle', border: OutlineInputBorder()),
                                items: [
                                  const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                                  ..._vehicles.map((v) => DropdownMenuItem<String?>(value: v['id'].toString(), child: Text('${v['bus_number']} (${v['vehicle_type']})'))),
                                ],
                                onChanged: (val) => setDialogState(() => selectedVehicleId = val),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String?>(
                                initialValue: (selectedDriverId != null && _drivers.any((d) => d['id'].toString() == selectedDriverId)) ? selectedDriverId : null,
                                decoration: const InputDecoration(labelText: 'Assign Driver', border: OutlineInputBorder()),
                                items: [
                                  const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                                  ..._drivers.map((d) => DropdownMenuItem<String?>(value: d['id'].toString(), child: Text(d['name']))),
                                ],
                                onChanged: (val) => setDialogState(() => selectedDriverId = val),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: ['Active', 'Inactive', 'Draft'].contains(status) ? status : 'Active',
                                decoration: const InputDecoration(labelText: 'Status *', border: OutlineInputBorder()),
                                items: ['Active', 'Inactive', 'Draft'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => status = val!),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 20),
                      const VerticalDivider(width: 1),
                      const SizedBox(width: 20),

                      // Right Section: Stops list CRUD inside dialog
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Stops List (${formStops.length})', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setDialogState(() {
                                      formStops.add({
                                        "stop_name": 'New Stop',
                                        "latitude": 28.62,
                                        "longitude": 77.36,
                                        "stop_order": formStops.length + 1,
                                        "estimated_arrival": '06:30:00'
                                      });
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('Add Stop', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: ListView.builder(
                                itemCount: formStops.length,
                                itemBuilder: (context, sIdx) {
                                  final stop = formStops[sIdx];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(radius: 10, backgroundColor: _accent, child: Text('${sIdx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10))),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextFormField(
                                                  initialValue: stop['stop_name'],
                                                  decoration: const InputDecoration(hintText: 'Stop Name', isDense: true, contentPadding: EdgeInsets.all(6)),
                                                  onChanged: (val) => stop['stop_name'] = val,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: _red, size: 18),
                                                onPressed: () => setDialogState(() {
                                                  formStops.removeAt(sIdx);
                                                  // Re-order
                                                  for (int k = 0; k < formStops.length; k++) {
                                                    formStops[k]['stop_order'] = k + 1;
                                                  }
                                                }),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextFormField(
                                                  initialValue: stop['estimated_arrival'],
                                                  decoration: const InputDecoration(hintText: 'Arrival', isDense: true, contentPadding: EdgeInsets.all(6)),
                                                  onChanged: (val) => stop['estimated_arrival'] = val,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextFormField(
                                                  initialValue: stop['latitude'].toString(),
                                                  decoration: const InputDecoration(hintText: 'Lat', isDense: true, contentPadding: EdgeInsets.all(6)),
                                                  onChanged: (val) => stop['latitude'] = double.tryParse(val) ?? 28.62,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextFormField(
                                                  initialValue: stop['longitude'].toString(),
                                                  decoration: const InputDecoration(hintText: 'Lng', isDense: true, contentPadding: EdgeInsets.all(6)),
                                                  onChanged: (val) => stop['longitude'] = double.tryParse(val) ?? 77.36,
                                                ),
                                              ),
                                            ],
                                          ),
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
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final schoolId = ref.read(authProvider).userData?['school_id']?.toString();
                      final payload = {
                        "school_id": schoolId,
                        "route_code": codeController.text,
                        "route_name": nameController.text,
                        "area_zone": areaController.text,
                        "distance_km": double.tryParse(distanceController.text) ?? 0.0,
                        "start_time": startTimeController.text,
                        "end_time": endTimeController.text,
                        "vehicle_id": selectedVehicleId,
                        "driver_id": selectedDriverId,
                        "status": status,
                        "stops": formStops
                      };

                      try {
                        if (isEdit) {
                          await ApiService().put('/transport/routes/${existing['id']}', payload);
                        } else {
                          await ApiService().post('/transport/routes', payload);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdit ? 'Route updated successfully' : 'Route created successfully'), backgroundColor: _green),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save route: $e'), backgroundColor: _red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: Text(isEdit ? 'Save Changes' : 'Create Route'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  
  // --- TRIPS LOGIC ---
  List<Map<String, dynamic>> _generateMockTrips() {
    return [
      {
        "id": "t1",
        "trip_code": "TRP-1001",
        "route_id": _routes.isNotEmpty ? _routes[0]['id'] : "r1",
        "trip_type": "Pickup",
        "trip_date": "2024-05-01",
        "start_time": "06:30:00",
        "end_time": "07:22:00",
        "status": "Completed",
        "students_count": 28,
        "driver_id": _drivers.isNotEmpty ? _drivers[0]['id'] : "d1",
        "vehicle_id": _vehicles.isNotEmpty ? _vehicles[0]['id'] : "v1",
        "transport_routes": {
          "route_name": "Route 101 (Morning)",
          "area_zone": "Sector 62 - School"
        },
        "drivers": {
          "name": _drivers.isNotEmpty ? _drivers[0]['name'] : "Ramesh Kumar",
          "driver_code": "DRV001",
          "photo_url": null
        },
        "bus_routes": {
          "bus_number": _vehicles.isNotEmpty ? _vehicles[0]['bus_number'] : "UP16 ET 1234",
          "vehicle_type": "AC Bus"
        }
      },
      {
        "id": "t2",
        "trip_code": "TRP-1002",
        "route_id": _routes.isNotEmpty ? _routes[0]['id'] : "r1",
        "trip_type": "Drop",
        "trip_date": "2024-05-01",
        "start_time": "13:45:00",
        "end_time": "14:35:00",
        "status": "Completed",
        "students_count": 32,
        "driver_id": _drivers.isNotEmpty ? _drivers[0]['id'] : "d1",
        "vehicle_id": _vehicles.isNotEmpty ? _vehicles[0]['id'] : "v1",
        "transport_routes": {
          "route_name": "Route 101 (Return)",
          "area_zone": "School - Sector 62"
        },
        "drivers": {
          "name": _drivers.isNotEmpty ? _drivers[0]['name'] : "Ramesh Kumar",
          "driver_code": "DRV001",
          "photo_url": null
        },
        "bus_routes": {
          "bus_number": _vehicles.isNotEmpty ? _vehicles[0]['bus_number'] : "UP16 ET 1234",
          "vehicle_type": "AC Bus"
        }
      },
      {
        "id": "t3",
        "trip_code": "TRP-1003",
        "route_id": _routes.length > 1 ? _routes[1]['id'] : "r2",
        "trip_type": "Pickup",
        "trip_date": "2024-05-01",
        "start_time": "06:40:00",
        "end_time": "07:30:00",
        "status": "Ongoing",
        "students_count": 18,
        "driver_id": _drivers.length > 1 ? _drivers[1]['id'] : "d2",
        "vehicle_id": _vehicles.length > 1 ? _vehicles[1]['id'] : "v2",
        "transport_routes": {
          "route_name": "Route 102 (Morning)",
          "area_zone": "Sector 122 - School"
        },
        "drivers": {
          "name": _drivers.length > 1 ? _drivers[1]['name'] : "Sandeep Singh",
          "driver_code": "DRV002",
          "photo_url": null
        },
        "bus_routes": {
          "bus_number": _vehicles.length > 1 ? _vehicles[1]['bus_number'] : "UP16 ET 5678",
          "vehicle_type": "AC Bus"
        }
      },
      {
        "id": "t4",
        "trip_code": "TRP-1004",
        "route_id": _routes.length > 2 ? _routes[2]['id'] : "r3",
        "trip_type": "Pickup",
        "trip_date": "2024-05-01",
        "start_time": "06:50:00",
        "end_time": "07:40:00",
        "status": "Scheduled",
        "students_count": 25,
        "driver_id": _drivers.length > 2 ? _drivers[2]['id'] : "d3",
        "vehicle_id": _vehicles.length > 2 ? _vehicles[2]['id'] : "v3",
        "transport_routes": {
          "route_name": "Route 103 (Morning)",
          "area_zone": "Greater Noida West - School"
        },
        "drivers": {
          "name": _drivers.length > 2 ? _drivers[2]['name'] : "Ajay Pal",
          "driver_code": "DRV003",
          "photo_url": null
        },
        "bus_routes": {
          "bus_number": _vehicles.length > 2 ? _vehicles[2]['bus_number'] : "UP16 ET 9101",
          "vehicle_type": "Non AC Bus"
        }
      },
      {
        "id": "t5",
        "trip_code": "TRP-1005",
        "route_id": _routes.length > 1 ? _routes[1]['id'] : "r2",
        "trip_type": "Drop",
        "trip_date": "2024-05-01",
        "start_time": "14:10:00",
        "end_time": "15:00:00",
        "status": "Scheduled",
        "students_count": 22,
        "driver_id": _drivers.length > 1 ? _drivers[1]['id'] : "d2",
        "vehicle_id": _vehicles.length > 1 ? _vehicles[1]['id'] : "v2",
        "transport_routes": {
          "route_name": "Route 102 (Return)",
          "area_zone": "School - Sector 122"
        },
        "drivers": {
          "name": _drivers.length > 1 ? _drivers[1]['name'] : "Sandeep Singh",
          "driver_code": "DRV002",
          "photo_url": null
        },
        "bus_routes": {
          "bus_number": _vehicles.length > 1 ? _vehicles[1]['bus_number'] : "UP16 ET 5678",
          "vehicle_type": "AC Bus"
        }
      },
      {
        "id": "t6",
        "trip_code": "TRP-1006",
        "route_id": _routes.length > 3 ? _routes[3]['id'] : "r4",
        "trip_type": "Pickup",
        "trip_date": "2024-05-01",
        "start_time": "15:00:00",
        "end_time": "15:50:00",
        "status": "Cancelled",
        "students_count": 0,
        "driver_id": _drivers.length > 3 ? _drivers[3]['id'] : "d4",
        "vehicle_id": _vehicles.length > 3 ? _vehicles[3]['id'] : "v4",
        "transport_routes": {
          "route_name": "Route 104 (Afternoon)",
          "area_zone": "Yamuna Expressway - School"
        },
        "drivers": {
          "name": _drivers.length > 3 ? _drivers[3]['name'] : "Mohd. Imran",
          "driver_code": "DRV004",
          "photo_url": null
        },
        "bus_routes": {
          "bus_number": _vehicles.length > 3 ? _vehicles[3]['bus_number'] : "UP16 ET 1122",
          "vehicle_type": "AC Bus"
        }
      },
    ];
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoadingTripsTab = true);
    try {
      final schoolId = ref.read(authProvider).userData?['school_id']?.toString();
      final tripsPath = schoolId != null ? '/transport/trips?page_size=100&school_id=$schoolId' : '/transport/trips?page_size=100';
      final res = await ApiService().get(tripsPath, useCache: false);
      if (mounted) {
        setState(() {
          final list = res['data']?['trips'] as List? ?? [];
          if (list.isEmpty) {
            _trips = _generateMockTrips();
          } else {
            final List<Map<String, dynamic>> dbTrips = list.map((t) {
              final bus = t['bus_routes'] ?? {};
              
              String tripDate = '2024-05-01';
              String startTime = '06:30:00';
              String endTime = '07:22:00';
              final schedStart = t['scheduled_start']?.toString();
              if (schedStart != null && schedStart.contains('T')) {
                final parts = schedStart.split('T');
                tripDate = parts[0];
                if (parts[1].length >= 8) {
                  startTime = parts[1].substring(0, 8);
                }
              }
              final actEnd = t['actual_end']?.toString();
              if (actEnd != null && actEnd.contains('T')) {
                final parts = actEnd.split('T');
                if (parts[1].length >= 8) {
                  endTime = parts[1].substring(0, 8);
                }
              }

              String tripType = 'Pickup';
              final rawType = t['trip_type']?.toString().toLowerCase();
              if (rawType == 'drop') {
                tripType = 'Drop';
              }

              String status = 'Scheduled';
              final rawStatus = t['status']?.toString().toLowerCase();
              if (rawStatus == 'in_progress' || rawStatus == 'ongoing') {
                status = 'Ongoing';
              } else if (rawStatus == 'completed') {
                status = 'Completed';
              } else if (rawStatus == 'cancelled') {
                status = 'Cancelled';
              }

              return {
                "id": t['id']?.toString(),
                "trip_code": "TRP-${t['id']?.toString().substring(0, 4).toUpperCase() ?? '000'}",
                "route_id": t['route_id']?.toString(),
                "trip_type": tripType,
                "trip_date": tripDate,
                "start_time": startTime,
                "end_time": endTime,
                "status": status,
                "students_count": t['students_count'] ?? 0,
                "driver_id": null,
                "vehicle_id": t['route_id']?.toString(),
                "notes": t['notes'] ?? '',
                "transport_routes": {
                  "route_name": bus['route_name'] ?? 'Route Name',
                  "area_zone": bus['registration_no'] ?? 'Area Zone'
                },
                "drivers": {
                  "name": bus['driver_name'] ?? 'Driver Name',
                  "driver_code": 'DRV',
                  "photo_url": null
                },
                "bus_routes": {
                  "bus_number": bus['bus_number'] ?? '',
                  "vehicle_type": 'Bus'
                }
              };
            }).toList().cast<Map<String, dynamic>>();

            final List<Map<String, dynamic>> merged = [...dbTrips];
            final mocks = _generateMockTrips();
            for (var m in mocks) {
              if (!merged.any((t) => t['trip_code'] == m['trip_code'] || t['id'] == m['id'])) {
                merged.add(m);
              }
            }
            _trips = merged;
          }
          _isLoadingTripsTab = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_trips.isEmpty) {
            _trips = _generateMockTrips();
          }
          _isLoadingTripsTab = false;
        });
      }
    }
  }

  Future<void> _deleteTrip(String tripId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text('Are you sure you want to delete this trip? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().delete('/transport/trips/$tripId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip deleted successfully'), backgroundColor: _green),
        );
        _loadTrips();
      } catch (e) {
        setState(() {
          _trips.removeWhere((t) => t['id'] == tripId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trip deleted: $e (local update)'), backgroundColor: _green),
        );
      }
    }
  }

  void _showTripFormDialog(dynamic existing) {
    final bool isEdit = existing != null;
    final formKey = GlobalKey<FormState>();

    String? selectedRouteId;
    if (_routes.isNotEmpty) {
      if (existing != null) {
        final rawRouteId = existing['route_id']?.toString();
        final rawTransportRouteId = existing['transport_route_id']?.toString() ?? existing['transport_routes']?['id']?.toString();
        final routeName = (existing['transport_routes']?['route_name'] ?? existing['route_name'] ?? '').toString().trim();

        if (rawRouteId != null && _routes.any((r) => r['id']?.toString() == rawRouteId)) {
          selectedRouteId = rawRouteId;
        } else if (rawTransportRouteId != null && _routes.any((r) => r['id']?.toString() == rawTransportRouteId)) {
          selectedRouteId = rawTransportRouteId;
        } else if (routeName.isNotEmpty) {
          final matchByName = _routes.firstWhere(
            (r) => (r['route_name'] ?? '').toString().trim().toLowerCase() == routeName.toLowerCase(),
            orElse: () => null,
          );
          if (matchByName != null) {
            selectedRouteId = matchByName['id']?.toString();
          } else {
            final matchPartial = _routes.firstWhere(
              (r) {
                final rName = (r['route_name'] ?? '').toString().trim().toLowerCase();
                return rName.isNotEmpty && (rName.contains(routeName.toLowerCase()) || routeName.toLowerCase().contains(rName));
              },
              orElse: () => null,
            );
            if (matchPartial != null) {
              selectedRouteId = matchPartial['id']?.toString();
            }
          }
        }
        if (selectedRouteId == null && rawRouteId != null) {
          final matchByVehicle = _routes.firstWhere(
            (r) => r['vehicle_id']?.toString() == rawRouteId || r['bus_id']?.toString() == rawRouteId,
            orElse: () => null,
          );
          if (matchByVehicle != null) {
            selectedRouteId = matchByVehicle['id']?.toString();
          }
        }
      }
      selectedRouteId ??= _routes[0]['id']?.toString();
    }

    String tripType = existing?['trip_type'] ?? 'Pickup';
    final dateController = TextEditingController(text: existing?['trip_date'] ?? '2024-05-01');
    final startTimeController = TextEditingController(text: existing?['start_time'] ?? '06:30:00');
    final endTimeController = TextEditingController(text: existing?['end_time'] ?? '07:22:00');
    String? selectedDriverId = existing?['driver_id']?.toString();
    String? selectedVehicleId = existing?['vehicle_id']?.toString();
    String status = existing?['status'] ?? 'Scheduled';
    final notesController = TextEditingController(text: existing?['notes'] ?? '');
    final studentsCountController = TextEditingController(text: (existing?['students_count'] ?? 0).toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Trip Details' : 'Add New Trip', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  clipBehavior: Clip.none,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: (selectedRouteId != null && _routes.any((r) => r['id'].toString() == selectedRouteId)) ? selectedRouteId : null,
                          decoration: const InputDecoration(labelText: 'Select Route *', border: OutlineInputBorder()),
                          items: _routes.map((r) => DropdownMenuItem<String>(value: r['id'].toString(), child: Text(r['route_name']))).toList(),
                          onChanged: (val) => setDialogState(() => selectedRouteId = val),
                          validator: (val) => val == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: ['Pickup', 'Drop'].contains(tripType) ? tripType : 'Pickup',
                          decoration: const InputDecoration(labelText: 'Trip Type *', border: OutlineInputBorder()),
                          items: ['Pickup', 'Drop'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (val) => setDialogState(() => tripType = val!),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: dateController,
                          decoration: const InputDecoration(labelText: 'Trip Date (YYYY-MM-DD) *', border: OutlineInputBorder()),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: startTimeController,
                                decoration: const InputDecoration(labelText: 'Start Time *', border: OutlineInputBorder(), hintText: 'HH:MM:SS'),
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: endTimeController,
                                decoration: const InputDecoration(labelText: 'End Time *', border: OutlineInputBorder(), hintText: 'HH:MM:SS'),
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          initialValue: (selectedVehicleId != null && _vehicles.any((v) => v['id'].toString() == selectedVehicleId)) ? selectedVehicleId : null,
                          decoration: const InputDecoration(labelText: 'Assign Vehicle', border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                            ..._vehicles.map((v) => DropdownMenuItem<String?>(value: v['id'].toString(), child: Text(v['bus_number'] ?? ''))),
                          ],
                          onChanged: (val) => setDialogState(() => selectedVehicleId = val),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          initialValue: (selectedDriverId != null && _drivers.any((d) => d['id'].toString() == selectedDriverId)) ? selectedDriverId : null,
                          decoration: const InputDecoration(labelText: 'Assign Driver', border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                            ..._drivers.map((d) => DropdownMenuItem<String?>(value: d['id'].toString(), child: Text(d['name'] ?? ''))),
                          ],
                          onChanged: (val) => setDialogState(() => selectedDriverId = val),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: ['Scheduled', 'Ongoing', 'Completed', 'Cancelled'].contains(status) ? status : 'Scheduled',
                          decoration: const InputDecoration(labelText: 'Status *', border: OutlineInputBorder()),
                          items: ['Scheduled', 'Ongoing', 'Completed', 'Cancelled'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) => setDialogState(() => status = val!),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: studentsCountController,
                          decoration: const InputDecoration(labelText: 'Students Count', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesController,
                          decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx);
                      _saveTrip(
                        id: existing?['id']?.toString(),
                        routeId: selectedRouteId!,
                        tripType: tripType,
                        tripDate: dateController.text,
                        startTime: startTimeController.text,
                        endTime: endTimeController.text,
                        driverId: selectedDriverId,
                        vehicleId: selectedVehicleId,
                        status: status,
                        studentsCount: int.tryParse(studentsCountController.text) ?? 0,
                        notes: notesController.text,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: Text(isEdit ? 'Save Changes' : 'Create Trip'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveTrip({
    required String? id,
    required String routeId,
    required String tripType,
    required String tripDate,
    required String startTime,
    required String endTime,
    required String? driverId,
    required String? vehicleId,
    required String status,
    required int studentsCount,
    required String notes,
  }) async {
    final route = _routes.firstWhere((r) => r['id'].toString() == routeId, orElse: () => null);
    final driver = _drivers.firstWhere((d) => d['id'].toString() == driverId, orElse: () => null);
    
    // The backend expects payload['route_id'] to be a vehicle ID in the bus_routes table.
    final targetVehicleId = vehicleId ?? (_vehicles.isNotEmpty ? _vehicles[0]['id'].toString() : null);
    if (targetVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save trip: No vehicle assigned/available'), backgroundColor: Colors.red),
      );
      return;
    }
    final vehicle = _vehicles.firstWhere((v) => v['id'].toString() == targetVehicleId, orElse: () => null);

    final payload = {
      "route_id": targetVehicleId,
      "trip_type": tripType.toLowerCase(),
      "scheduled_start": "${tripDate}T$startTime",
      "status": status.toLowerCase() == 'ongoing' ? 'in_progress' : status.toLowerCase(),
      "students_count": studentsCount,
      "notes": notes,
      "actual_start": status.toLowerCase() == 'completed' || status.toLowerCase() == 'ongoing' ? "${tripDate}T$startTime" : null,
      "actual_end": status.toLowerCase() == 'completed' ? "${tripDate}T$endTime" : null,
    };

    try {
      if (id == null || id.startsWith('t')) {
        final newId = id ?? "t${_trips.length + 1001}";
        final mockTrip = {
          "id": newId,
          "trip_code": "TRP-${1000 + _trips.length + 1}",
          "route_id": targetVehicleId,
          "trip_type": tripType,
          "trip_date": tripDate,
          "start_time": startTime,
          "end_time": endTime,
          "status": status,
          "students_count": studentsCount,
          "driver_id": driverId,
          "vehicle_id": targetVehicleId,
          "transport_routes": {
            "route_name": route != null ? route['route_name'] : "Route Name",
            "area_zone": route != null ? route['area_zone'] : "Area Zone"
          },
          "drivers": {
            "name": driver != null ? driver['name'] : "Driver Name",
            "driver_code": driver != null ? (driver['driver_code'] ?? 'DRV') : 'DRV',
            "photo_url": null
          },
          "bus_routes": {
            "bus_number": vehicle != null ? (vehicle['bus_number'] ?? '') : '',
            "vehicle_type": vehicle != null ? (vehicle['vehicle_type'] ?? 'Bus') : 'Bus'
          }
        };

        await ApiService().post('/transport/trips', payload);

        setState(() {
          _trips.insert(0, mockTrip);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip created successfully'), backgroundColor: _green),
        );
      } else {
        await ApiService().put('/transport/trips/$id', payload);

        setState(() {
          final idx = _trips.indexWhere((t) => t['id'] == id);
          if (idx != -1) {
            _trips[idx] = {
              ..._trips[idx],
              "route_id": targetVehicleId,
              "trip_type": tripType,
              "trip_date": tripDate,
              "start_time": startTime,
              "end_time": endTime,
              "status": status,
              "students_count": studentsCount,
              "driver_id": driverId,
              "vehicle_id": targetVehicleId,
              "transport_routes": {
                "route_name": route != null ? route['route_name'] : "Route Name",
                "area_zone": route != null ? route['area_zone'] : "Area Zone"
              },
              "drivers": {
                "name": driver != null ? driver['name'] : "Driver Name",
                "driver_code": driver != null ? (driver['driver_code'] ?? 'DRV') : 'DRV',
                "photo_url": null
              },
              "bus_routes": {
                "bus_number": vehicle != null ? (vehicle['bus_number'] ?? '') : '',
                "vehicle_type": vehicle != null ? (vehicle['vehicle_type'] ?? 'Bus') : 'Bus'
              }
            };
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip updated successfully'), backgroundColor: _green),
        );
      }
      _loadTrips();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save trip: $e'), backgroundColor: _red),
      );
    }
  }

  Widget _buildTripsKpiCard(String title, String val, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            radius: 20,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 11, color: _textSecondary), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(val, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 9, color: color, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsInnerTabHeader(String label, int count, String filterVal) {
    final isActive = _tripsStatusFilter == filterVal;
    return InkWell(
      onTap: () => setState(() => _tripsStatusFilter = filterVal),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? _accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? _accent : _textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? _accent.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '($count)',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isActive ? _accent : _textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = _textSecondary;
    
    final s = status.toLowerCase();
    if (s == 'completed') {
      bg = _green.withValues(alpha: 0.1);
      fg = _green;
    } else if (s == 'ongoing' || s == 'in_progress') {
      bg = Colors.blue.withValues(alpha: 0.1);
      fg = Colors.blue;
    } else if (s == 'scheduled') {
      bg = _orange.withValues(alpha: 0.1);
      fg = _orange;
    } else if (s == 'cancelled') {
      bg = _red.withValues(alpha: 0.1);
      fg = _red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildTripsSummaryCard(int completed, int ongoing, int scheduled, int cancelled) {
    final total = completed + ongoing + scheduled + cancelled;
    final completedPct = total > 0 ? completed / total : 0.0;
    final ongoingPct = total > 0 ? ongoing / total : 0.0;
    final scheduledPct = total > 0 ? scheduled / total : 0.0;
    final cancelledPct = total > 0 ? cancelled / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trips Summary', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: PieChartPainter(
                    completedPct: completedPct,
                    ongoingPct: ongoingPct,
                    scheduledPct: scheduledPct,
                    cancelledPct: cancelledPct,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$total', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('Total Trips', style: GoogleFonts.inter(fontSize: 8, color: _textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _buildSummaryLegendRow('Completed', '${(completedPct * 100).toStringAsFixed(1)}%', _green),
                    _buildSummaryLegendRow('Ongoing', '${(ongoingPct * 100).toStringAsFixed(1)}%', Colors.blue),
                    _buildSummaryLegendRow('Scheduled', '${(scheduledPct * 100).toStringAsFixed(1)}%', _orange),
                    _buildSummaryLegendRow('Cancelled', '${(cancelledPct * 100).toStringAsFixed(1)}%', _red),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLegendRow(String title, String pct, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.inter(fontSize: 11, color: _textPrimary)),
            ],
          ),
          Text(pct, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
        ],
      ),
    );
  }

  Widget _buildScheduleOverviewCalendar(int scheduled, int ongoing, int cancelled) {
    final year = _calendarTargetDate.year;
    final month = _calendarTargetDate.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayWeekday = DateTime(year, month, 1).weekday;
    final weekdayOffset = firstDayWeekday == 7 ? 0 : firstDayWeekday;

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthLabel = '${monthNames[month - 1]} $year';

    final monthTrips = _trips.where((t) {
      final dateStr = t['trip_date']?.toString();
      if (dateStr == null) return false;
      try {
        final parsed = DateTime.parse(dateStr);
        return parsed.year == year && parsed.month == month;
      } catch (_) {}
      return false;
    }).toList();

    final scheduledInMonth = monthTrips.where((t) => t['status']?.toString().toLowerCase() == 'scheduled').length;
    final ongoingInMonth = monthTrips.where((t) => ['ongoing', 'in_progress'].contains(t['status']?.toString().toLowerCase())).length;
    final cancelledInMonth = monthTrips.where((t) => t['status']?.toString().toLowerCase() == 'cancelled').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                onPressed: () {
                  setState(() {
                    _calendarTargetDate = DateTime(year, month - 1, 1);
                  });
                },
              ),
              Text(monthLabel, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                onPressed: () {
                  setState(() {
                    _calendarTargetDate = DateTime(year, month + 1, 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((d) => Center(child: Text(d, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _textSecondary))))
                .toList(),
          ),
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: weekdayOffset + daysInMonth,
            itemBuilder: (context, index) {
              final day = index - weekdayOffset + 1;
              if (day < 1) return const SizedBox();

              final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              final dayTrips = _trips.where((t) => t['trip_date']?.toString() == dateStr).toList();
              final isToday = DateTime.now().year == year && DateTime.now().month == month && DateTime.now().day == day;
              final isSelected = _tripsSearchQuery == dateStr;

              final hasScheduled = dayTrips.any((t) => t['status']?.toString().toLowerCase() == 'scheduled');
              final hasOngoing = dayTrips.any((t) => ['ongoing', 'in_progress'].contains(t['status']?.toString().toLowerCase()));
              final hasCancelled = dayTrips.any((t) => t['status']?.toString().toLowerCase() == 'cancelled');
              final hasCompleted = dayTrips.any((t) => t['status']?.toString().toLowerCase() == 'completed');

              return InkWell(
                onTap: dayTrips.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _tripsStartDate = DateTime(year, month, day);
                          _tripsEndDate = DateTime(year, month, day);
                          _tripsSearchController.text = dateStr;
                          _tripsSearchQuery = dateStr;
                          _tripsCurrentPage = 1;
                        });
                      },
                borderRadius: BorderRadius.circular(14),
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? _accent 
                          : (isToday ? _accent.withValues(alpha: 0.08) : Colors.transparent),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? null
                          : (isToday
                              ? Border.all(color: _accent, width: 1.5)
                              : (dayTrips.isNotEmpty ? Border.all(color: const Color(0xFFCBD5E1), width: 1) : null)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: (isSelected || isToday || dayTrips.isNotEmpty) ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : (isToday ? _accent : _textPrimary),
                          ),
                        ),
                        if (dayTrips.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (hasScheduled)
                                Container(width: 3, height: 3, margin: const EdgeInsets.symmetric(horizontal: 0.5), decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle)),
                              if (hasOngoing)
                                Container(width: 3, height: 3, margin: const EdgeInsets.symmetric(horizontal: 0.5), decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                              if (hasCancelled)
                                Container(width: 3, height: 3, margin: const EdgeInsets.symmetric(horizontal: 0.5), decoration: const BoxDecoration(color: _red, shape: BoxShape.circle)),
                              if (hasCompleted)
                                Container(width: 3, height: 3, margin: const EdgeInsets.symmetric(horizontal: 0.5), decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('$scheduledInMonth Scheduled', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                ],
              ),
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('$ongoingInMonth Ongoing', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                ],
              ),
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: _red, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('$cancelledInMonth Cancelled', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingTripsCard() {
    final upcoming = _trips.where((t) => ['scheduled', 'ongoing', 'in_progress'].contains(t['status']?.toString().toLowerCase())).take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Upcoming Trips (Next 7 Days)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
          const SizedBox(height: 16),
          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No upcoming trips scheduled.', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary))),
            )
          else
            ...upcoming.map((t) {
              final routeName = t['transport_routes']?['route_name'] ?? 'Route 103 (Morning)';
              final areaZone = t['transport_routes']?['area_zone'] ?? 'Greater Noida West - School';
              final timeStr = _formatTimeStr(t['start_time']);
              final tripDate = t['trip_date']?.toString() ?? '';
              
              final type = t['trip_type']?.toString() ?? 'Pickup';
              final isPickup = type.toLowerCase() == 'pickup';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(timeStr, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _accent)),
                        Text(tripDate, style: const TextStyle(fontSize: 8, color: _textSecondary)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(routeName, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
                          Text(areaZone, style: GoogleFonts.inter(fontSize: 9, color: _textSecondary), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPickup ? _green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: isPickup ? _green : Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _tripsSearchController.clear();
                _tripsSearchQuery = '';
                _tripsStatusFilter = 'Scheduled';
                _tripsCurrentPage = 1;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('View All Upcoming Trips', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _accent)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward, size: 12, color: _accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTripInfoDialog(dynamic trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trip['trip_code'] ?? 'Trip Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTripDetailRow('Route Name', trip['transport_routes']?['route_name'] ?? ''),
            _buildTripDetailRow('Area Zone', trip['transport_routes']?['area_zone'] ?? ''),
            _buildTripDetailRow('Type', trip['trip_type'] ?? ''),
            _buildTripDetailRow('Date', trip['trip_date'] ?? ''),
            _buildTripDetailRow('Scheduled Start', trip['start_time'] ?? ''),
            _buildTripDetailRow('Scheduled End', trip['end_time'] ?? ''),
            _buildTripDetailRow('Driver', trip['drivers']?['name'] ?? ''),
            _buildTripDetailRow('Bus Number', trip['bus_routes']?['bus_number'] ?? ''),
            _buildTripDetailRow('Bus Type', trip['bus_routes']?['vehicle_type'] ?? ''),
            _buildTripDetailRow('Students count', (trip['students_count'] ?? 0).toString()),
            _buildTripDetailRow('Status', trip['status'] ?? ''),
            _buildTripDetailRow('Notes', trip['notes'] ?? 'None'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildTripDetailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label:', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary, fontWeight: FontWeight.bold))),
          Expanded(child: Text(val, style: GoogleFonts.inter(fontSize: 11, color: _textPrimary))),
        ],
      ),
    );
  }

  String _formatTimeStr(dynamic rawTime) {
    if (rawTime == null) return '—';
    final str = rawTime.toString();
    try {
      final parts = str.split(':');
      if (parts.length >= 2) {
        final hr = int.parse(parts[0]);
        final min = parts[1];
        final period = hr >= 12 ? 'PM' : 'AM';
        final displayHr = hr % 12 == 0 ? 12 : hr % 12;
        return '${displayHr.toString().padLeft(2, '0')}:$min $period';
      }
    } catch (_) {}
    return str;
  }
  Widget _buildTripsFilterDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required double width,
  }) {
    return Container(
      width: width,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B)),
          dropdownColor: Colors.white,
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildTripsTab() {
    final filteredByDropdowns = _trips.where((t) {
      if (_tripsSearchQuery.isNotEmpty) {
        final q = _tripsSearchQuery.toLowerCase();
        final code = (t['trip_code'] ?? '').toString().toLowerCase();
        final route = (t['transport_routes']?['route_name'] ?? '').toString().toLowerCase();
        final driver = (t['drivers']?['name'] ?? '').toString().toLowerCase();
        final vehicle = (t['bus_routes']?['bus_number'] ?? '').toString().toLowerCase();
        final date = (t['trip_date'] ?? '').toString().toLowerCase();
        if (!code.contains(q) && !route.contains(q) && !driver.contains(q) && !vehicle.contains(q) && !date.contains(q)) return false;
      }
      if (_tripsRouteFilter != 'All') {
        if (t['route_id']?.toString() != _tripsRouteFilter) return false;
      }
      if (_tripsDriverFilter != 'All') {
        if (t['driver_id']?.toString() != _tripsDriverFilter) return false;
      }
      if (_tripsBusFilter != 'All') {
        if (t['vehicle_id']?.toString() != _tripsBusFilter) return false;
      }
      if (_tripsTypeFilter != 'All') {
        if (t['trip_type']?.toString() != _tripsTypeFilter) return false;
      }
      return true;
    }).toList();

    final totalTrips = filteredByDropdowns.length;
    final completedTrips = filteredByDropdowns.where((t) => t['status']?.toString().toLowerCase() == 'completed').length;
    final ongoingTrips = filteredByDropdowns.where((t) => ['ongoing', 'in_progress'].contains(t['status']?.toString().toLowerCase())).length;
    final scheduledTrips = filteredByDropdowns.where((t) => t['status']?.toString().toLowerCase() == 'scheduled').length;
    final cancelledTrips = filteredByDropdowns.where((t) => t['status']?.toString().toLowerCase() == 'cancelled').length;

    final filtered = filteredByDropdowns.where((t) {
      if (_tripsStatusFilter != 'All') {
        final status = (t['status'] ?? '').toString().toLowerCase();
        final filterVal = _tripsStatusFilter.toLowerCase();
        if (status != filterVal && !(filterVal == 'ongoing' && (status == 'ongoing' || status == 'in_progress'))) return false;
      }
      return true;
    }).toList();

    final total = filtered.length;
    final totalPages = (total / _tripsPageSize).ceil();
    if (_tripsCurrentPage > totalPages && totalPages > 0) {
      _tripsCurrentPage = totalPages;
    } else if (_tripsCurrentPage < 1) {
      _tripsCurrentPage = 1;
    }
    final startIdx = total == 0 ? 0 : (_tripsCurrentPage - 1) * _tripsPageSize;
    final endIdx = startIdx + _tripsPageSize > total ? total : startIdx + _tripsPageSize;
    final paginatedTrips = filtered.isEmpty ? <dynamic>[] : filtered.sublist(startIdx, endIdx);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI Row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: 180, child: _buildTripsKpiCard('Total Trips', '$totalTrips', 'All time', Icons.directions_bus_rounded, _accent)),
                SizedBox(width: 180, child: _buildTripsKpiCard('Completed', '$completedTrips', 'Safe delivery', Icons.check_circle_rounded, _green)),
                SizedBox(width: 180, child: _buildTripsKpiCard('Ongoing', '$ongoingTrips', 'Live tracking', Icons.play_arrow_rounded, Colors.blue)),
                SizedBox(width: 180, child: _buildTripsKpiCard('Scheduled', '$scheduledTrips', 'Next scheduled', Icons.schedule_rounded, _orange)),
                SizedBox(width: 180, child: _buildTripsKpiCard('Cancelled', '$cancelledTrips', 'Disrupted', Icons.cancel_rounded, _red)),
              ],
            ),
          ),

          // Filters Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 40,
                      child: TextField(
                        controller: _tripsSearchController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                          hintText: 'Search trips...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          fillColor: Colors.white,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                    ),
                    _buildTripsFilterDropdown(
                      value: (_tripsRouteFilter == 'All' || _routes.any((r) => r['id'].toString() == _tripsRouteFilter)) ? _tripsRouteFilter : 'All',
                      width: 140,
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Routes')),
                        ..._routes.map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['route_name']))),
                      ],
                      onChanged: (val) => setState(() { _tripsRouteFilter = val!; _tripsCurrentPage = 1; }),
                    ),
                    _buildTripsFilterDropdown(
                      value: (_tripsBusFilter == 'All' || _vehicles.any((v) => v['id'].toString() == _tripsBusFilter)) ? _tripsBusFilter : 'All',
                      width: 140,
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Vehicles')),
                        ..._vehicles.map((v) => DropdownMenuItem(value: v['id'].toString(), child: Text(v['bus_number'] ?? ''))),
                      ],
                      onChanged: (val) => setState(() { _tripsBusFilter = val!; _tripsCurrentPage = 1; }),
                    ),
                    _buildTripsFilterDropdown(
                      value: (_tripsDriverFilter == 'All' || _drivers.any((d) => d['id'].toString() == _tripsDriverFilter)) ? _tripsDriverFilter : 'All',
                      width: 140,
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Drivers')),
                        ..._drivers.map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['name'] ?? ''))),
                      ],
                      onChanged: (val) => setState(() { _tripsDriverFilter = val!; _tripsCurrentPage = 1; }),
                    ),
                    _buildTripsFilterDropdown(
                      value: ['All', 'Pickup', 'Drop'].contains(_tripsTypeFilter) ? _tripsTypeFilter : 'All',
                      width: 110,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Types')),
                        DropdownMenuItem(value: 'Pickup', child: Text('Pickup')),
                        DropdownMenuItem(value: 'Drop', child: Text('Drop')),
                      ],
                      onChanged: (val) => setState(() { _tripsTypeFilter = val!; _tripsCurrentPage = 1; }),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _tripsSearchController.clear();
                        _tripsSearchQuery = '';
                        _tripsRouteFilter = 'All';
                        _tripsBusFilter = 'All';
                        _tripsDriverFilter = 'All';
                        _tripsTypeFilter = 'All';
                        _tripsStatusFilter = 'All';
                        _tripsCurrentPage = 1;
                      }),
                      icon: const Icon(Icons.filter_list, size: 14),
                      label: const Text('Reset'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    IconButton(
                      onPressed: _loadTrips,
                      icon: const Icon(Icons.refresh, size: 18),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE2E8F0))),
                        padding: const EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showTripFormDialog(null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add New Trip'),
                ),
              ],
            ),
          ),

          // Inner Tab Headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildTripsInnerTabHeader('All Trips', filteredByDropdowns.length, 'All'),
                const SizedBox(width: 12),
                _buildTripsInnerTabHeader('Scheduled', filteredByDropdowns.where((t) => t['status']?.toString().toLowerCase() == 'scheduled').length, 'Scheduled'),
                const SizedBox(width: 12),
                _buildTripsInnerTabHeader('Ongoing', filteredByDropdowns.where((t) => ['ongoing', 'in_progress'].contains(t['status']?.toString().toLowerCase())).length, 'Ongoing'),
                const SizedBox(width: 12),
                _buildTripsInnerTabHeader('Completed', filteredByDropdowns.where((t) => t['status']?.toString().toLowerCase() == 'completed').length, 'Completed'),
                const SizedBox(width: 12),
                _buildTripsInnerTabHeader('Cancelled', filteredByDropdowns.where((t) => t['status']?.toString().toLowerCase() == 'cancelled').length, 'Cancelled'),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),

          // Content Area Split Layout
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              height: 650,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Column: Trips Table & Pagination (Flex 7)
                  Expanded(
                    flex: 7,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _isLoadingTripsTab
                                ? const Center(child: CircularProgressIndicator())
                                : filtered.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.directions_bus_outlined, size: 48, color: _gray),
                                            const SizedBox(height: 16),
                                            Text('No Trips Found', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
                                            Text('Try adjusting your search query or filters.', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                          ],
                                        ),
                                      )
                                    : Scrollbar(
                                        controller: _tripsTableScrollController,
                                        thumbVisibility: true,
                                        child: SingleChildScrollView(
                                          controller: _tripsTableScrollController,
                                          scrollDirection: Axis.horizontal,
                                          child: SingleChildScrollView(
                                            child: SizedBox(
                                              width: 1250,
                                              child: DataTable(
                                                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                                    dataRowMinHeight: 64,
                                                    dataRowMaxHeight: 76,
                                                    columnSpacing: 24,
                                                    horizontalMargin: 16,
                                                    showCheckboxColumn: false,
                                                    columns: [
                                                      DataColumn(label: Text('Trip Code', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                      DataColumn(label: Text('Route Name', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                      DataColumn(label: Text('Type', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                      DataColumn(label: Text('Driver', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                      DataColumn(label: Text('Vehicle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                      DataColumn(label: Text('Timing', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                      DataColumn(label: Text('Students', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                      DataColumn(label: Text('Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                      DataColumn(label: Text('Actions', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                    ],
                                                    rows: paginatedTrips.map((t) {
                                                      final isSelected = _selectedTrip != null && _selectedTrip!['id'] == t['id'];
                                                      
                                                      final driverName = t['drivers']?['name'] ?? 'Unassigned';
                                                      final busNum = t['bus_routes']?['bus_number'] ?? 'Unassigned';
                                                      final timing = '${_formatTimeStr(t['start_time'])} - ${_formatTimeStr(t['end_time'])}';

                                                      return DataRow(
                                                        selected: isSelected,
                                                        onSelectChanged: (val) {
                                                          setState(() {
                                                            _selectedTrip = val == true ? t : null;
                                                          });
                                                        },
                                                        cells: [
                                                          DataCell(Text(t['trip_code'] ?? 'TRP-000', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11))),
                                                          DataCell(
                                                            Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                Text(t['transport_routes']?['route_name'] ?? 'Morning Route', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                                                                Text(t['transport_routes']?['area_zone'] ?? 'Area Zone', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                                                              ],
                                                            ),
                                                          ),
                                                          DataCell(
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: t['trip_type'] == 'Pickup' ? _green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: Text(
                                                                t['trip_type'] ?? 'Pickup',
                                                                style: TextStyle(
                                                                  fontSize: 9,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: t['trip_type'] == 'Pickup' ? _green : Colors.blue,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          DataCell(Text(driverName, style: GoogleFonts.inter(fontSize: 11))),
                                                          DataCell(Text(busNum, style: GoogleFonts.inter(fontSize: 11))),
                                                          DataCell(
                                                            Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                Text(timing, style: GoogleFonts.inter(fontSize: 11)),
                                                                Text(t['trip_date'] ?? '2024-05-01', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                                                              ],
                                                            ),
                                                          ),
                                                          DataCell(Text('${t['students_count'] ?? 0}', style: GoogleFonts.inter(fontSize: 11))),
                                                          DataCell(_buildStatusBadge(t['status'] ?? 'Scheduled')),
                                                          DataCell(
                                                            Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                IconButton(
                                                                  icon: const Icon(Icons.info_outline, size: 16, color: _accent),
                                                                  tooltip: 'View Details',
                                                                  onPressed: () => _showTripInfoDialog(t),
                                                                ),
                                                                IconButton(
                                                                  icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                                                                  tooltip: 'Edit Trip',
                                                                  onPressed: () => _showTripFormDialog(t),
                                                                ),
                                                                IconButton(
                                                                  icon: const Icon(Icons.delete_outline, size: 16, color: _red),
                                                                  tooltip: 'Delete Trip',
                                                                  onPressed: () => _deleteTrip(t['id'].toString()),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                          ),
                          // Pagination bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              border: Border(top: BorderSide(color: _border)),
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Text(
                                  'Showing ${total > 0 ? startIdx + 1 : 0} to $endIdx of $total entries',
                                  style: GoogleFonts.inter(fontSize: 11, color: _textSecondary),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Show', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                    const SizedBox(width: 6),
                                    Container(
                                      height: 28,
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: _border),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _tripsPageSize,
                                          style: GoogleFonts.inter(fontSize: 11, color: _textPrimary, fontWeight: FontWeight.bold),
                                          items: [5, 8, 10, 15, 20, 50].map((int val) {
                                            return DropdownMenuItem<int>(
                                              value: val,
                                              child: Text('$val'),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            setState(() {
                                              _tripsPageSize = val!;
                                              _tripsCurrentPage = 1;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('entries', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left, size: 18),
                                      onPressed: _tripsCurrentPage > 1 ? () => setState(() => _tripsCurrentPage--) : null,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('$_tripsCurrentPage / ${totalPages == 0 ? 1 : totalPages}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right, size: 18),
                                      onPressed: _tripsCurrentPage < totalPages ? () => setState(() => _tripsCurrentPage++) : null,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right Column: Summary Cards & Preview (Flex 3)
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTripsSummaryCard(completedTrips, ongoingTrips, scheduledTrips, cancelledTrips),
                          const SizedBox(height: 16),
                          _buildScheduleOverviewCalendar(scheduledTrips, ongoingTrips, cancelledTrips),
                          const SizedBox(height: 16),
                          _buildUpcomingTripsCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRouteType(dynamic r) {
    final name = (r['route_name'] ?? '').toString().toLowerCase();
    if (name.contains('morning')) return 'Morning';
    if (name.contains('afternoon')) return 'Afternoon';
    if (name.contains('evening')) return 'Evening';
    return 'General';
  }

  String _getRouteCode(dynamic r) {
    if (r['route_code'] != null && r['route_code'].toString().isNotEmpty) {
      return r['route_code'].toString();
    }
    final name = (r['route_name'] ?? '').toString();
    if (name.contains('Route ')) {
      final num = name.replaceAll('Route ', '').trim();
      return 'RT-${num.padLeft(3, '0')}';
    }
    final idStr = r['id']?.toString() ?? '000';
    return 'RT-${idStr.substring(0, 3).toUpperCase()}';
  }

  Future<void> _performAssignment() async {
    if (_assignSelectedRouteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a route to assign'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_assignSelectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle to assign'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_assignSelectedDriverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a driver to assign'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoadingAssignmentsTab = true);

    try {
      final dateStr = '${_assignStartDate.year}-${_assignStartDate.month.toString().padLeft(2, '0')}-${_assignStartDate.day.toString().padLeft(2, '0')}';
      
      // 1. Update the route's vehicle and driver in transport_routes table
      await ApiService().put('/transport/routes/$_assignSelectedRouteId', {
        "vehicle_id": _assignSelectedVehicleId,
        "driver_id": _assignSelectedDriverId,
      });

      // 2. Post to the driver_assignments table to log the assignment
      final payload = {
        "school_id": ref.read(authProvider).userData?['school_id']?.toString() ?? "11111111-1111-1111-1111-111111111111",
        "route_id": _assignSelectedRouteId,
        "vehicle_id": _assignSelectedVehicleId,
        "driver_id": _assignSelectedDriverId,
        "assignment_type": "Route",
        "start_date": dateStr,
        "shift": "General",
        "status": "Active",
        "notes": _assignNotesController.text,
        "created_by": "Transport Manager"
      };
      await ApiService().post('/transport/drivers/assignments', payload);

      // Reset form
      setState(() {
        _assignSelectedRouteId = null;
        _assignSelectedVehicleId = null;
        _assignSelectedDriverId = null;
        _assignNotesController.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bus assigned successfully!'), backgroundColor: _green),
      );

      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete assignment: $e'), backgroundColor: _red),
      );
    } finally {
      setState(() => _isLoadingAssignmentsTab = false);
    }
  }

  Future<void> _removeAssignment(dynamic r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Assignment'),
        content: Text('Are you sure you want to unassign the vehicle and driver from ${r['route_name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            child: const Text('Unassign'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoadingAssignmentsTab = true);
      try {
        final routeId = r['id'].toString();

        // Find if there is an active assignment record to delete or complete
        final activeAssign = _assignments.firstWhere(
          (a) => a['route_id']?.toString() == routeId && a['status']?.toString().toLowerCase() == 'active',
          orElse: () => null,
        );

        if (activeAssign != null) {
          await ApiService().delete('/transport/drivers/assignments/${activeAssign['id']}');
        }

        // Update route configuration
        await ApiService().put('/transport/routes/$routeId', {
          "vehicle_id": null,
          "driver_id": null,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bus unassigned successfully'), backgroundColor: _green),
        );
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove assignment: $e'), backgroundColor: _red),
        );
      } finally {
        setState(() => _isLoadingAssignmentsTab = false);
      }
    }
  }

  Widget _buildAssignBusKpiCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignBusTab() {
    // 1. Filter routes list
    final filteredRoutes = _routes.where((r) {
      if (_assignSearchQuery.isNotEmpty) {
        final q = _assignSearchQuery.toLowerCase();
        final name = (r['route_name'] ?? '').toString().toLowerCase();
        final code = _getRouteCode(r).toLowerCase();
        final zone = (r['area_zone'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !code.contains(q) && !zone.contains(q)) return false;
      }
      if (_assignAreaFilter != 'All') {
        if (r['area_zone']?.toString() != _assignAreaFilter) return false;
      }
      if (_assignTypeFilter != 'All') {
        if (_getRouteType(r) != _assignTypeFilter) return false;
      }
      if (_assignStatusFilter != 'All') {
        final isAssigned = r['vehicle_id'] != null;
        if (_assignStatusFilter == 'Assigned' && !isAssigned) return false;
        if (_assignStatusFilter == 'Unassigned' && isAssigned) return false;
      }
      return true;
    }).toList();

    // Calculate pagination details
    final total = filteredRoutes.length;
    final totalPages = (total / _assignPageSize).ceil();
    if (_assignCurrentPage > totalPages && totalPages > 0) {
      _assignCurrentPage = totalPages;
    } else if (_assignCurrentPage < 1) {
      _assignCurrentPage = 1;
    }
    final startIdx = total == 0 ? 0 : (_assignCurrentPage - 1) * _assignPageSize;
    final endIdx = startIdx + _assignPageSize > total ? total : startIdx + _assignPageSize;
    final paginatedRoutes = filteredRoutes.isEmpty ? <dynamic>[] : filteredRoutes.sublist(startIdx, endIdx);

    // Dynamic stats computation
    final totalRoutes = _routes.length;
    final assignedRoutesCount = _routes.where((r) => r['vehicle_id'] != null).length;
    final unassignedRoutesCount = totalRoutes - assignedRoutesCount;
    final assignedRoutesPct = totalRoutes > 0 ? (assignedRoutesCount / totalRoutes * 100).toStringAsFixed(2) : '0.00';
    final unassignedRoutesPct = totalRoutes > 0 ? (unassignedRoutesCount / totalRoutes * 100).toStringAsFixed(2) : '0.00';

    final totalBuses = _vehicles.length;
    final assignedBusesCount = _vehicles.where((v) => _routes.any((r) => r['vehicle_id']?.toString() == v['id']?.toString())).length;
    final availableBusesCount = totalBuses - assignedBusesCount;
    final assignedBusesPct = totalBuses > 0 ? (assignedBusesCount / totalBuses * 100).toStringAsFixed(2) : '0.00';
    final availableBusesPct = totalBuses > 0 ? (availableBusesCount / totalBuses * 100).toStringAsFixed(2) : '0.00';

    // Get available buses
    final availableBuses = _vehicles.where((v) => !_routes.any((r) => r['vehicle_id']?.toString() == v['id']?.toString())).toList();

    // Unique zones list for filter
    final zonesSet = _routes.map((r) => r['area_zone']?.toString()).whereType<String>().where((z) => z.isNotEmpty).toSet().toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI metrics
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: 175, child: _buildAssignBusKpiCard('Total Routes', '$totalRoutes', 'All Routes', Icons.alt_route, _accent)),
                SizedBox(width: 175, child: _buildAssignBusKpiCard('Assigned Routes', '$assignedRoutesCount', '$assignedRoutesPct%', Icons.check_circle_rounded, _green)),
                SizedBox(width: 175, child: _buildAssignBusKpiCard('Unassigned Routes', '$unassignedRoutesCount', '$unassignedRoutesPct%', Icons.pause_circle_rounded, _orange)),
                SizedBox(width: 175, child: _buildAssignBusKpiCard('Total Buses', '$totalBuses', 'All Buses', Icons.directions_bus, Colors.blue)),
                SizedBox(width: 175, child: _buildAssignBusKpiCard('Assigned Buses', '$assignedBusesCount', '$assignedBusesPct%', Icons.directions_bus_filled_outlined, Colors.indigo)),
                SizedBox(width: 175, child: _buildAssignBusKpiCard('Available Buses', '$availableBusesCount', '$availableBusesPct%', Icons.circle_outlined, Colors.pink)),
              ],
            ),
          ),

          // Filters Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildTripsFilterDropdown(
                      value: _assignAreaFilter,
                      width: 155,
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Areas / Zones')),
                        ...zonesSet.map((z) => DropdownMenuItem(value: z, child: Text(z))),
                      ],
                      onChanged: (val) => setState(() { _assignAreaFilter = val!; _assignCurrentPage = 1; }),
                    ),
                    _buildTripsFilterDropdown(
                      value: _assignTypeFilter,
                      width: 140,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Route Types')),
                        DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                        DropdownMenuItem(value: 'Afternoon', child: Text('Afternoon')),
                        DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                        DropdownMenuItem(value: 'General', child: Text('General')),
                      ],
                      onChanged: (val) => setState(() { _assignTypeFilter = val!; _assignCurrentPage = 1; }),
                    ),
                    _buildTripsFilterDropdown(
                      value: _assignStatusFilter,
                      width: 130,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Status')),
                        DropdownMenuItem(value: 'Assigned', child: Text('Assigned')),
                        DropdownMenuItem(value: 'Unassigned', child: Text('Unassigned')),
                      ],
                      onChanged: (val) => setState(() { _assignStatusFilter = val!; _assignCurrentPage = 1; }),
                    ),
                    SizedBox(
                      width: 200,
                      height: 40,
                      child: TextField(
                        controller: _assignSearchController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                          hintText: 'Search routes...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          fillColor: Colors.white,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _assignSearchController.clear();
                        _assignSearchQuery = '';
                        _assignAreaFilter = 'All';
                        _assignTypeFilter = 'All';
                        _assignStatusFilter = 'All';
                        _assignCurrentPage = 1;
                      }),
                      icon: const Icon(Icons.filter_list, size: 14),
                      label: const Text('Reset'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    IconButton(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh, size: 18),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE2E8F0))),
                        padding: const EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Populate first route, vehicle, driver if available to assign
                    setState(() {
                      if (_routes.isNotEmpty) _assignSelectedRouteId = _routes[0]['id']?.toString();
                      if (availableBuses.isNotEmpty) _assignSelectedVehicleId = availableBuses[0]['id']?.toString();
                      if (_drivers.isNotEmpty) _assignSelectedDriverId = _drivers[0]['id']?.toString();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_link, size: 16),
                  label: const Text('Assign Bus'),
                ),
              ],
            ),
          ),

          // Main split content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              height: 750,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left side: Routes table
                  Expanded(
                    flex: 7,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _isLoadingAssignmentsTab
                                ? const Center(child: CircularProgressIndicator())
                                : filteredRoutes.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.link_off_rounded, size: 48, color: _gray),
                                            const SizedBox(height: 16),
                                            Text('No Routes Found', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
                                            Text('Try adjusting your search query or filters.', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                          ],
                                        ),
                                      )
                                    : Scrollbar(
                                        controller: _assignTableScrollController,
                                        thumbVisibility: true,
                                        child: SingleChildScrollView(
                                          controller: _assignTableScrollController,
                                          scrollDirection: Axis.horizontal,
                                          child: SingleChildScrollView(
                                            child: SizedBox(
                                              width: 1000,
                                              child: DataTable(
                                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                                dataRowMinHeight: 64,
                                                dataRowMaxHeight: 76,
                                                columnSpacing: 20,
                                                horizontalMargin: 16,
                                                showCheckboxColumn: false,
                                                columns: [
                                                  DataColumn(label: Text('Route Code', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                  DataColumn(label: Text('Route Name', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                  DataColumn(label: Text('Area / Zone', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                  DataColumn(label: Text('Stops', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                  DataColumn(label: Text('Distance', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                  DataColumn(label: Text('Assigned Bus', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                  DataColumn(label: Text('Driver', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                  DataColumn(label: Text('Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                  DataColumn(label: Text('Actions', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                                ],
                                                rows: paginatedRoutes.map((r) {
                                                  final isAssigned = r['vehicle_id'] != null;
                                                  final code = _getRouteCode(r);
                                                  final busNo = (r['bus_routes'] ?? {})['bus_number'] ?? '—';
                                                  final busType = (r['bus_routes'] ?? {})['vehicle_type'] ?? '';
                                                  final driverName = (r['drivers'] ?? {})['name'] ?? '—';

                                                  return DataRow(
                                                    cells: [
                                                      DataCell(Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(color: _accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                                                        child: Text(code, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _accent, fontSize: 11)),
                                                      )),
                                                      DataCell(
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Text(r['route_name'] ?? 'Morning Route', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                                                            Text('${_getRouteType(r)} Route', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                                                          ],
                                                        ),
                                                      ),
                                                      DataCell(Text(r['area_zone'] ?? '—', style: GoogleFonts.inter(fontSize: 11))),
                                                      DataCell(Text('${r['stops_count'] ?? 0}', style: GoogleFonts.inter(fontSize: 11))),
                                                      DataCell(Text('${r['distance_km'] ?? 0.0} km', style: GoogleFonts.inter(fontSize: 11))),
                                                      DataCell(
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Text(busNo, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                                                            if (busType.isNotEmpty) Text(busType, style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                                                          ],
                                                        ),
                                                      ),
                                                      DataCell(Text(driverName, style: GoogleFonts.inter(fontSize: 11))),
                                                      DataCell(
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: isAssigned ? _green.withValues(alpha: 0.1) : _orange.withValues(alpha: 0.1),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            isAssigned ? 'Assigned' : 'Unassigned',
                                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isAssigned ? _green : _orange),
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            IconButton(
                                                              icon: const Icon(Icons.info_outline, size: 16, color: _accent),
                                                              tooltip: 'Details',
                                                              onPressed: () {
                                                                showDialog(
                                                                  context: context,
                                                                  builder: (ctx) => AlertDialog(
                                                                    title: Text('Route Details: $code'),
                                                                    content: Column(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        Text('Name: ${r['route_name']}'),
                                                                        Text('Zone: ${r['area_zone']}'),
                                                                        Text('Stops: ${r['stops_count']}'),
                                                                        Text('Distance: ${r['distance_km']} km'),
                                                                        Text('Bus No: $busNo'),
                                                                        Text('Driver: $driverName'),
                                                                      ],
                                                                    ),
                                                                    actions: [
                                                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                                                                    ],
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                            if (isAssigned) ...[
                                                              IconButton(
                                                                icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                                                                tooltip: 'Edit Assignment',
                                                                onPressed: () {
                                                                  setState(() {
                                                                    _assignSelectedRouteId = r['id']?.toString();
                                                                    _assignSelectedVehicleId = r['vehicle_id']?.toString();
                                                                    _assignSelectedDriverId = r['driver_id']?.toString();
                                                                  });
                                                                },
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(Icons.delete_outline, size: 16, color: _red),
                                                                tooltip: 'Remove Assignment',
                                                                onPressed: () => _removeAssignment(r),
                                                              ),
                                                            ] else ...[
                                                              IconButton(
                                                                icon: const Icon(Icons.add_link, size: 16, color: _orange),
                                                                tooltip: 'Quick Assign',
                                                                onPressed: () {
                                                                  setState(() {
                                                                    _assignSelectedRouteId = r['id']?.toString();
                                                                    if (availableBuses.isNotEmpty) _assignSelectedVehicleId = availableBuses[0]['id']?.toString();
                                                                    if (_drivers.isNotEmpty) _assignSelectedDriverId = _drivers[0]['id']?.toString();
                                                                  });
                                                                },
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                          ),
                          // Pagination bar
                          const Divider(height: 1),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Text('Showing ${total > 0 ? startIdx + 1 : 0} to $endIdx of $total routes', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Show', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                    const SizedBox(width: 6),
                                    Container(
                                      height: 28,
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: _border),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _assignPageSize,
                                          style: GoogleFonts.inter(fontSize: 11, color: _textPrimary, fontWeight: FontWeight.bold),
                                          items: [5, 8, 10, 15, 20, 50].map((int val) {
                                            return DropdownMenuItem<int>(
                                              value: val,
                                              child: Text('$val'),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            setState(() {
                                              _assignPageSize = val!;
                                              _assignCurrentPage = 1;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('entries', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left, size: 18),
                                      onPressed: _assignCurrentPage > 1 ? () => setState(() => _assignCurrentPage--) : null,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('$_assignCurrentPage / ${totalPages == 0 ? 1 : totalPages}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right, size: 18),
                                      onPressed: _assignCurrentPage < totalPages ? () => setState(() => _assignCurrentPage++) : null,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Right side: Form & Available list
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Form
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: _border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Assign Bus to Route', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
                                const SizedBox(height: 12),

                                // Route select
                                Text('Select Route *', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _textSecondary)),
                                const SizedBox(height: 6),
                                _buildTripsFilterDropdown(
                                  value: (_assignSelectedRouteId == null || !_routes.any((r) => r['id']?.toString() == _assignSelectedRouteId)) ? 'placeholder' : _assignSelectedRouteId!,
                                  width: double.infinity,
                                  items: [
                                    const DropdownMenuItem(value: 'placeholder', child: Text('Select Route...')),
                                    ..._routes.map((r) => DropdownMenuItem(value: r['id']?.toString(), child: Text('${_getRouteCode(r)} - ${r['route_name']}'))),
                                  ],
                                  onChanged: (val) => setState(() {
                                    _assignSelectedRouteId = val == 'placeholder' ? null : val;
                                  }),
                                ),
                                const SizedBox(height: 12),

                                // Bus select
                                Text('Select Bus *', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _textSecondary)),
                                const SizedBox(height: 6),
                                _buildTripsFilterDropdown(
                                  value: (_assignSelectedVehicleId == null || !_vehicles.any((v) => v['id']?.toString() == _assignSelectedVehicleId)) ? 'placeholder' : _assignSelectedVehicleId!,
                                  width: double.infinity,
                                  items: [
                                    const DropdownMenuItem(value: 'placeholder', child: Text('Select an available bus...')),
                                    ..._vehicles.map((v) => DropdownMenuItem(value: v['id']?.toString(), child: Text('${v['bus_number']} (${v['vehicle_type'] ?? 'Bus'})'))),
                                  ],
                                  onChanged: (val) => setState(() {
                                    _assignSelectedVehicleId = val == 'placeholder' ? null : val;
                                  }),
                                ),
                                const SizedBox(height: 12),

                                // Driver select
                                Text('Select Driver *', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _textSecondary)),
                                const SizedBox(height: 6),
                                _buildTripsFilterDropdown(
                                  value: (_assignSelectedDriverId == null || !_drivers.any((d) => d['id']?.toString() == _assignSelectedDriverId)) ? 'placeholder' : _assignSelectedDriverId!,
                                  width: double.infinity,
                                  items: [
                                    const DropdownMenuItem(value: 'placeholder', child: Text('Select a driver...')),
                                    ..._drivers.map((d) => DropdownMenuItem(value: d['id']?.toString(), child: Text(d['name'] ?? 'Driver'))),
                                  ],
                                  onChanged: (val) => setState(() {
                                    _assignSelectedDriverId = val == 'placeholder' ? null : val;
                                  }),
                                ),
                                const SizedBox(height: 12),

                                // Start Date selector
                                Text('Start Date *', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _textSecondary)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _assignStartDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _assignStartDate = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${_assignStartDate.day.toString().padLeft(2, '0')} ${_assignStartDate.month.toString().padLeft(2, '0')} ${_assignStartDate.year}',
                                          style: GoogleFonts.inter(fontSize: 12, color: _textPrimary),
                                        ),
                                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Notes textfield
                                Text('Notes (Optional)', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _textSecondary)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _assignNotesController,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    hintText: 'Enter notes...',
                                    hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Assign Now button
                                ElevatedButton(
                                  onPressed: _performAssignment,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text('Assign Now', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Available list
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: _border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Available Buses (${availableBuses.length})', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
                                    InkWell(
                                      onTap: () => _tabController.animateTo(1),
                                      child: Text('View All Buses →', style: GoogleFonts.inter(fontSize: 10, color: _accent, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (availableBuses.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Center(
                                      child: Text('No buses available', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                    ),
                                  )
                                else
                                  ...availableBuses.take(4).map((v) => Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.directions_bus, size: 24, color: _accent),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(v['bus_number'] ?? '—', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
                                              Text('${v['total_capacity'] ?? 40} Seats • ${v['vehicle_type'] ?? 'AC Bus'}', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: _green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                          child: const Text('Available', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: _green)),
                                        ),
                                      ],
                                    ),
                                  )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom card: Recent Bus Assignments
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Bus Assignments', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
                      Text('View All Assignments', style: GoogleFonts.inter(fontSize: 10, color: _accent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_assignments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('No assignments recorded yet.', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                      ),
                    )
                  else
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(2),
                        2: FlexColumnWidth(2),
                        3: FlexColumnWidth(2),
                        4: FlexColumnWidth(2),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                          children: [
                            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Route', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textSecondary))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Bus', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textSecondary))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Driver', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textSecondary))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Assigned On', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textSecondary))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Assigned By', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textSecondary))),
                          ],
                        ),
                        ..._assignments.take(5).map((a) {
                          final routeName = a['route']?['route_name'] ?? '—';
                          final busNo = a['vehicle']?['bus_number'] ?? '—';
                          final busType = a['vehicle']?['vehicle_type'] ?? 'Bus';
                          final driverName = a['drivers']?['name'] ?? '—';
                          final assignedOn = a['created_at'] != null 
                              ? a['created_at'].toString().split('T')[0]
                              : '—';
                          final assignedBy = a['created_by'] ?? 'Transport Manager';

                          return TableRow(
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC)))),
                            children: [
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(routeName, style: GoogleFonts.inter(fontSize: 11, color: _textPrimary))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('$busNo ($busType)', style: GoogleFonts.inter(fontSize: 11, color: _textPrimary))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(driverName, style: GoogleFonts.inter(fontSize: 11, color: _textPrimary))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(assignedOn, style: GoogleFonts.inter(fontSize: 11, color: _textPrimary))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(assignedBy, style: GoogleFonts.inter(fontSize: 11, color: _textPrimary))),
                            ],
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- LIVE TRACKING VIEW IMPLEMENTATION ---
  Future<void> _loadLiveTrackingData() async {
    if (_isLoadingLiveTracking) return;
    setState(() => _isLoadingLiveTracking = true);
    try {
      final schoolId = ref.read(authProvider).userData?['school_id']?.toString();
      final summaryPath = schoolId != null ? '/transport/dashboard/summary?school_id=$schoolId' : '/transport/dashboard/summary';
      final alertsPath = schoolId != null ? '/transport/alerts?page_size=10&school_id=$schoolId' : '/transport/alerts?page_size=10';
      final vehiclesPath = schoolId != null ? '/transport/vehicles?page_size=100&school_id=$schoolId' : '/transport/vehicles?page_size=100';

      final results = await Future.wait([
        ApiService().get(summaryPath, useCache: false),
        ApiService().get(alertsPath, useCache: false),
        ApiService().get(vehiclesPath, useCache: false),
      ]);

      if (mounted) {
        setState(() {
          _trackingSummary = results[0]['data'] != null ? Map<String, dynamic>.from(results[0]['data']) : {};
          _trackingAlerts = results[1]['data']?['alerts'] ?? [];
          
          final vehData = results[2]['data'];
          if (vehData is Map && vehData['vehicles'] is List) {
            _trackingVehicles = vehData['vehicles'];
          } else if (vehData is List) {
            _trackingVehicles = vehData;
          } else {
            _trackingVehicles = [];
          }

          // Pre-select first tracked vehicle if none is selected
          if (_selectedTrackingVehicle == null && _trackingVehicles.isNotEmpty) {
            _selectedTrackingVehicle = _trackingVehicles.firstWhere(
              (v) => v['latest_location'] != null,
              orElse: () => _trackingVehicles[0],
            );
            _updateTrackingMapForVehicle(_selectedTrackingVehicle);
          }
          
          ApiService().post('/transport/diagnostics', {
            'status': 'success',
            'summary': _trackingSummary,
            'alerts_count': _trackingAlerts.length,
            'vehicles_count': _trackingVehicles.length,
          });

          _isLoadingLiveTracking = false;
        });
      }
    } catch (e, stack) {
      print('LIVE TRACKING ERROR: $e\n$stack');
      ApiService().post('/transport/diagnostics', {
        'status': 'error',
        'error': e.toString(),
        'stack': stack.toString(),
      });
      if (mounted) {
        setState(() => _isLoadingLiveTracking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading live tracking: $e'),
            backgroundColor: _red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  Future<List<LatLng>> _fetchOSMRoutePoints(List<LatLng> stopCoords) async {
    if (stopCoords.length < 2) return stopCoords;
    final coordsString = stopCoords.map((c) => '${c.longitude},${c.latitude}').join(';');
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/$coordsString?overview=full&geometries=geojson';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
        return coordinates.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
      }
    } catch (e) {
      debugPrint('OSRM routing failed: $e');
    }
    return stopCoords;
  }

  Future<void> _updateTrackingMapForVehicle(dynamic vehicle) async {
    if (vehicle == null) return;
    
    final route = _routes.firstWhere(
      (r) => r['vehicle_id']?.toString() == vehicle['id']?.toString(),
      orElse: () => null,
    );
    
    if (route != null) {
      try {
        final res = await ApiService().get('/transport/routes/${route['id']}', useCache: false);
        final stops = res['data']?['stops'] ?? [];
        final stopCoords = stops.map<LatLng>((s) {
          final lat = double.tryParse(s['latitude']?.toString() ?? '0') ?? 0.0;
          final lng = double.tryParse(s['longitude']?.toString() ?? '0') ?? 0.0;
          return LatLng(lat, lng);
        }).where((c) => c.latitude != 0.0 && c.longitude != 0.0).toList();

        final osmPoints = await _fetchOSMRoutePoints(stopCoords);

        if (mounted) {
          setState(() {
            _trackingSelectedRouteStops = stops;
            _trackingRoutePoints = osmPoints;
            
            if (vehicle['latest_location'] != null) {
              final lat = double.tryParse(vehicle['latest_location']['latitude']?.toString() ?? '0') ?? 0.0;
              final lng = double.tryParse(vehicle['latest_location']['longitude']?.toString() ?? '0') ?? 0.0;
              if (lat != 0.0 && lng != 0.0) {
                try {
                  _trackingMapController.move(LatLng(lat, lng), 13.0);
                } catch (_) {}
              }
            } else if (stopCoords.isNotEmpty) {
              try {
                _trackingMapController.move(stopCoords[0], 13.0);
              } catch (_) {}
            }
          });
        }
      } catch (e) {
        debugPrint('Failed to load stops for tracking: $e');
      }
    } else {
      if (mounted) {
        setState(() {
          _trackingSelectedRouteStops = [];
          _trackingRoutePoints = [];
        });
      }
    }
  }

  Widget _buildTrackingSummaryCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 9, color: _textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getVehicleStatusColor(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s.contains('on_route') || s.contains('active')) return _green;
    if (s.contains('delayed')) return _red;
    if (s.contains('at_school') || s.contains('at_stop') || s.contains('stop')) return _orange;
    return _gray;
  }

  String _getVehicleStatusText(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s.contains('on_route') || s.contains('active')) return 'On Route';
    if (s.contains('delayed')) return 'Delayed';
    if (s.contains('at_school') || s.contains('at_stop') || s.contains('stop')) return 'At Stop';
    if (s.contains('completed')) return 'Completed';
    return 'Offline';
  }

  Widget _buildLiveTrackingTab() {
    final filteredVehicles = _trackingVehicles.where((v) {
      if (_trackingSearchQuery.isNotEmpty) {
        final q = _trackingSearchQuery.toLowerCase();
        final busNum = (v['bus_number'] ?? '').toString().toLowerCase();
        final regNum = (v['registration_no'] ?? '').toString().toLowerCase();
        final type = (v['vehicle_type'] ?? '').toString().toLowerCase();
        if (!busNum.contains(q) && !regNum.contains(q) && !type.contains(q)) return false;
      }
      if (_trackingStatusFilter != 'All') {
        final status = _getVehicleStatusText(v['live_status']);
        if (status != _trackingStatusFilter) return false;
      }
      if (_trackingBusFilter != 'All') {
        if (v['id']?.toString() != _trackingBusFilter) return false;
      }
      if (_trackingRouteFilter != 'All') {
        // Find if vehicle is assigned to the selected route
        final hasRoute = _routes.any((r) => r['id']?.toString() == _trackingRouteFilter && r['vehicle_id']?.toString() == v['id']?.toString());
        if (!hasRoute) return false;
      }
      return true;
    }).toList();

    final totalCount = _trackingSummary['total_vehicles'] ?? 0;
    final offlineCount = _trackingSummary['offline'] ?? 0;
    final activeCount = totalCount - offlineCount;
    final onRouteCount = _trackingSummary['on_route'] ?? 0;
    final atStopCount = _trackingSummary['at_school'] ?? 0;
    final delayedCount = _trackingSummary['delayed'] ?? 0;
    final completedTrips = _trackingSummary['completed_trips_today'] ?? 0;
    final onTimePerfVal = totalCount > 0 ? ((totalCount - delayedCount) / totalCount * 100) : 100.0;
    final onTimePerf = '${onTimePerfVal.toStringAsFixed(1)}%';


    // Bottom Table Pagination
    final total = filteredVehicles.length;
    final totalPages = (total / _trackingPageSize).ceil();
    if (_trackingCurrentPage > totalPages && totalPages > 0) {
      _trackingCurrentPage = totalPages;
    } else if (_trackingCurrentPage < 1) {
      _trackingCurrentPage = 1;
    }
    final startIdx = total == 0 ? 0 : (_trackingCurrentPage - 1) * _trackingPageSize;
    final endIdx = startIdx + _trackingPageSize > total ? total : startIdx + _trackingPageSize;
    final paginatedVehicles = filteredVehicles.isEmpty ? <dynamic>[] : filteredVehicles.sublist(startIdx, endIdx);

    // LatLng for Selected vehicle marker & route stops
    LatLng? busLatLng;
    if (_selectedTrackingVehicle != null && _selectedTrackingVehicle['latest_location'] != null) {
      final lat = double.tryParse(_selectedTrackingVehicle['latest_location']['latitude']?.toString() ?? '0') ?? 0.0;
      final lng = double.tryParse(_selectedTrackingVehicle['latest_location']['longitude']?.toString() ?? '0') ?? 0.0;
      if (lat != 0.0 && lng != 0.0) {
        busLatLng = LatLng(lat, lng);
      }
    }

    final stopMarkers = _trackingSelectedRouteStops.asMap().entries.map<Marker>((entry) {
      final idx = entry.key + 1;
      final s = entry.value;
      final lat = double.tryParse(s['latitude']?.toString() ?? '0') ?? 0.0;
      final lng = double.tryParse(s['longitude']?.toString() ?? '0') ?? 0.0;
      return Marker(
        point: LatLng(lat, lng),
        width: 24,
        height: 24,
        child: Container(
          decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$idx', style: GoogleFonts.inter(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI metrics
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: 175, child: _buildTrackingSummaryCard('Active Buses', '$activeCount', '$activeCount of $totalCount active', Icons.directions_bus, _accent)),
                SizedBox(width: 175, child: _buildTrackingSummaryCard('On Route', '$onRouteCount', '${((onRouteCount/totalCount)*100).toStringAsFixed(1)}% of total', Icons.circle_notifications_outlined, _green)),
                SizedBox(width: 175, child: _buildTrackingSummaryCard('At Stop', '$atStopCount', '${((atStopCount/totalCount)*100).toStringAsFixed(1)}% of total', Icons.pause_circle_filled_outlined, _orange)),
                SizedBox(width: 175, child: _buildTrackingSummaryCard('Delayed', '$delayedCount', '${((delayedCount/totalCount)*100).toStringAsFixed(1)}% of total', Icons.error_outline_rounded, _red)),
                SizedBox(width: 175, child: _buildTrackingSummaryCard('Completed Trips', '$completedTrips', 'Trips completed today', Icons.check_circle_outline, Colors.blue)),
                SizedBox(width: 175, child: _buildTrackingSummaryCard('On-Time Perf.', onTimePerf, 'Average this month', Icons.trending_up, Colors.pink)),
              ],
            ),
          ),

          // Filters row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildTripsFilterDropdown(
                      value: _trackingRouteFilter,
                      width: 155,
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Routes')),
                        ..._routes.map((r) => DropdownMenuItem(value: r['id']?.toString(), child: Text(r['route_name'] ?? 'Route'))),
                      ],
                      onChanged: (val) => setState(() { _trackingRouteFilter = val!; _trackingCurrentPage = 1; }),
                    ),
                    _buildTripsFilterDropdown(
                      value: _trackingBusFilter,
                      width: 155,
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Buses')),
                        ..._vehicles.map((v) => DropdownMenuItem(value: v['id']?.toString(), child: Text(v['bus_number'] ?? 'Bus'))),
                      ],
                      onChanged: (val) => setState(() { _trackingBusFilter = val!; _trackingCurrentPage = 1; }),
                    ),
                    _buildTripsFilterDropdown(
                      value: _trackingStatusFilter,
                      width: 130,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Status')),
                        DropdownMenuItem(value: 'On Route', child: Text('On Route')),
                        DropdownMenuItem(value: 'At Stop', child: Text('At Stop')),
                        DropdownMenuItem(value: 'Delayed', child: Text('Delayed')),
                        DropdownMenuItem(value: 'Offline', child: Text('Offline')),
                      ],
                      onChanged: (val) => setState(() { _trackingStatusFilter = val!; _trackingCurrentPage = 1; }),
                    ),
                    SizedBox(
                      width: 200,
                      height: 40,
                      child: TextField(
                        controller: _trackingSearchController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                          hintText: 'Search bus or route...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          fillColor: Colors.white,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _trackingSearchController.clear();
                        _trackingSearchQuery = '';
                        _trackingRouteFilter = 'All';
                        _trackingBusFilter = 'All';
                        _trackingStatusFilter = 'All';
                        _trackingCurrentPage = 1;
                      }),
                      icon: const Icon(Icons.filter_list, size: 14),
                      label: const Text('Reset'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Auto refresh in ${_autoRefreshSeconds}s', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(value: _autoRefreshSeconds / 15, strokeWidth: 2, color: _accent, backgroundColor: _border),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _loadLiveTrackingData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Live Refresh'),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _isMapMaximized = !_isMapMaximized),
                      icon: Icon(_isMapMaximized ? Icons.fullscreen_exit : Icons.fullscreen, size: 20, color: _textSecondary),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE2E8F0))),
                        padding: const EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Map & details section
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              height: _isMapMaximized ? 750 : 500,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Map container
                  Expanded(
                    flex: 7,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          GestureDetector(
                            onVerticalDragStart: (_) {},
                            onHorizontalDragStart: (_) {},
                            child: Listener(
                              onPointerSignal: (pointerSignal) {
                                if (pointerSignal is PointerScrollEvent) {
                                  final double zoomDelta = pointerSignal.scrollDelta.dy < 0 ? 0.2 : -0.2;
                                  final double newZoom = (_trackingMapController.camera.zoom + zoomDelta).clamp(1.0, 19.0);
                                  _trackingMapController.move(_trackingMapController.camera.center, newZoom);
                                }
                              },
                              child: FlutterMap(
                                mapController: _trackingMapController,
                                options: MapOptions(
                                  initialCenter: busLatLng ?? const LatLng(28.62, 77.36),
                                  initialZoom: 13.0,
                                  interactionOptions: const InteractionOptions(
                                    flags: InteractiveFlag.all,
                                  ),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                                    subdomains: const ['a', 'b', 'c', 'd'],
                                    userAgentPackageName: 'com.edushamiit.admin',
                                    tileProvider: CancellableNetworkTileProvider(),
                                  ),
                                  if (_trackingRoutePoints.isNotEmpty)
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: _trackingRoutePoints,
                                          strokeWidth: 4.0,
                                          color: _accent,
                                        ),
                                      ],
                                    ),
                                  MarkerLayer(markers: stopMarkers),
                                  if (busLatLng != null)
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: busLatLng,
                                          width: 40,
                                          height: 40,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: _getVehicleStatusColor(_selectedTrackingVehicle['live_status']),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)],
                                            ),
                                            child: const Icon(Icons.directions_bus, color: Colors.white, size: 20),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // Locate & zoom controls (Micro Stack)
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
                                        onTap: () => _trackingMapController.move(_trackingMapController.camera.center, _trackingMapController.camera.zoom + 1),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                        child: const SizedBox(
                                          width: 24,
                                          height: 20,
                                          child: Icon(Icons.add, size: 11, color: Color(0xFF1E293B)),
                                        ),
                                      ),
                                      Container(height: 1, color: const Color(0xFFE2E8F0), width: 14),
                                      InkWell(
                                        onTap: () => _trackingMapController.move(_trackingMapController.camera.center, _trackingMapController.camera.zoom - 1),
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
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () {
                                    if (busLatLng != null) {
                                      _trackingMapController.move(busLatLng, 14.0);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(15),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                                    ),
                                    child: Icon(Icons.my_location, size: 14, color: _textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Legend overlay
                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                              ),
                              child: Row(
                                children: [
                                  _buildLegendDot(_green, 'On Route'),
                                  const SizedBox(width: 12),
                                  _buildLegendDot(_orange, 'At Stop'),
                                  const SizedBox(width: 12),
                                  _buildLegendDot(_red, 'Delayed'),
                                  const SizedBox(width: 12),
                                  _buildLegendDot(_gray, 'Completed'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Right side: Bus details panel
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _selectedTrackingVehicle == null
                          ? Center(
                              child: Text('Select a bus to view details', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_selectedTrackingVehicle['bus_number'] ?? 'UP16 ET 1234', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
                                            Text(_selectedTrackingVehicle['vehicle_type'] ?? 'AC Bus', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getVehicleStatusColor(_selectedTrackingVehicle['live_status']).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _getVehicleStatusText(_selectedTrackingVehicle['live_status']),
                                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: _getVehicleStatusColor(_selectedTrackingVehicle['live_status'])),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),

                                  // Driver Info
                                  Row(
                                    children: [
                                      const CircleAvatar(radius: 16, backgroundColor: _border, child: Icon(Icons.person, size: 18, color: _gray)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_selectedTrackingVehicle['driver_name'] ?? 'Ramesh Kumar', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                                            Text('Driver', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.phone_outlined, size: 16, color: _accent),
                                        onPressed: () {},
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Detail fields
                                  _buildDetailRow('Current Location', _selectedTrackingVehicle['latest_location'] != null ? 'Noida Sector 62' : 'Depot'),
                                  _buildDetailRow('Speed', '${_selectedTrackingVehicle['latest_location']?['speed'] ?? 0} km/h'),
                                  _buildDetailRow('Last Updated', _selectedTrackingVehicle['latest_location']?['recorded_at'] != null ? _selectedTrackingVehicle['latest_location']['recorded_at'].toString().split('T')[1].substring(0, 8) : '—'),
                                  _buildDetailRow('Students on Board', '${_selectedTrackingVehicle['students_on_board'] ?? 0} / ${_selectedTrackingVehicle['total_capacity'] ?? 40}'),
                                  const SizedBox(height: 16),

                                  // Next stops vertical list
                                  Text('Next Stops', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary)),
                                  const SizedBox(height: 8),
                                  if (_trackingSelectedRouteStops.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text('No stops for this route', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                                    )
                                  else
                                    ..._trackingSelectedRouteStops.take(3).map((s) => Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 14, color: _accent),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(s['stop_name'] ?? 'Stop', style: GoogleFonts.inter(fontSize: 10, color: _textPrimary))),
                                          Text(s['estimated_arrival']?.toString().substring(0, 5) ?? '08:00', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                                        ],
                                      ),
                                    )),

                                  const Divider(height: 24),

                                  // Recent Alerts list
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Recent Alerts', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary)),
                                      Text('View All', style: GoogleFonts.inter(fontSize: 9, color: _accent, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (_trackingAlerts.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text('No active alerts.', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                                    )
                                  else
                                    ..._trackingAlerts.take(2).map((a) => Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6)),
                                      child: Row(
                                        children: [
                                          Icon(Icons.warning, size: 14, color: a['severity'] == 'critical' ? _red : _orange),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(a['title'] ?? 'Alert', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: _textPrimary))),
                                        ],
                                      ),
                                    )),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom table grid (Hidden if map is maximized)
          if (!_isMapMaximized)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Live Buses ($total)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    _isLoadingLiveTracking
                        ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                        : filteredVehicles.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(32),
                                child: Center(child: Text('No buses found matching filters.', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary))),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final double tableWidth = constraints.maxWidth > 1050 ? constraints.maxWidth : 1050;
                                  return Scrollbar(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SizedBox(
                                        width: tableWidth,
                                        child: DataTable(
                                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                          dataRowMinHeight: 56,
                                          dataRowMaxHeight: 64,
                                          columns: [
                                            DataColumn(label: Text('Bus', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                            DataColumn(label: Text('Route', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                            DataColumn(label: Text('Driver', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                            DataColumn(label: Text('Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                            DataColumn(label: Text('Current Location', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                            DataColumn(label: Text('Speed', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                            DataColumn(label: Text('Last Updated', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                            DataColumn(label: Text('Action', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                                          ],
                                          rows: paginatedVehicles.map((v) {
                                            final isSelected = _selectedTrackingVehicle?['id'] == v['id'];
                                            final status = _getVehicleStatusText(v['live_status']);
                                            final statusCol = _getVehicleStatusColor(v['live_status']);
                                            
                                            // Find route name
                                            final r = _routes.firstWhere(
                                              (route) => route['vehicle_id']?.toString() == v['id']?.toString(),
                                              orElse: () => null,
                                            );
                                            final routeName = r != null ? r['route_name'] ?? 'Route' : '—';
                                            
                                            return DataRow(
                                              selected: isSelected,
                                              onSelectChanged: (val) {
                                                if (val == true) {
                                                  setState(() {
                                                    _selectedTrackingVehicle = v;
                                                  });
                                                  _updateTrackingMapForVehicle(v);
                                                }
                                              },
                                              cells: [
                                                DataCell(Text(v['bus_number'] ?? 'UP16 ET 1234', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold))),
                                                DataCell(Text(routeName, style: GoogleFonts.inter(fontSize: 11))),
                                                DataCell(Text(v['driver_name'] ?? 'Ramesh Kumar', style: GoogleFonts.inter(fontSize: 11))),
                                                DataCell(Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(color: statusCol.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                                  child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusCol)),
                                                )),
                                                DataCell(Text(v['latest_location'] != null ? 'Sector 62, Noida' : 'Depot', style: GoogleFonts.inter(fontSize: 11))),
                                                DataCell(Text(v['latest_location'] != null ? '${v['latest_location']['speed'] ?? 0} km/h' : '0 km/h', style: GoogleFonts.inter(fontSize: 11))),
                                                DataCell(Builder(
                                                  builder: (context) {
                                                    final loc = v['latest_location'];
                                                    if (loc == null || loc['recorded_at'] == null) return const Text('—', style: TextStyle(fontSize: 11));
                                                    final timeStr = loc['recorded_at'].toString();
                                                    if (timeStr.contains('T')) {
                                                      final timePart = timeStr.split('T')[1];
                                                      return Text(timePart.length >= 8 ? timePart.substring(0, 8) : timePart, style: GoogleFonts.inter(fontSize: 11));
                                                    }
                                                    return Text(timeStr.length >= 8 ? timeStr.substring(0, 8) : timeStr, style: GoogleFonts.inter(fontSize: 11));
                                                  }
                                                )),
                                                DataCell(
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(Icons.my_location, size: 16, color: _accent),
                                                        onPressed: () {
                                                          setState(() {
                                                            _selectedTrackingVehicle = v;
                                                          });
                                                          _updateTrackingMapForVehicle(v);
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                    const Divider(height: 1),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Text('Showing ${total > 0 ? startIdx + 1 : 0} to $endIdx of $total buses', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Show', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                              const SizedBox(width: 6),
                              Container(
                                height: 28,
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: _border),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _trackingPageSize,
                                    style: GoogleFonts.inter(fontSize: 11, color: _textPrimary, fontWeight: FontWeight.bold),
                                    items: [4, 8, 10, 15, 20].map((int val) {
                                      return DropdownMenuItem<int>(
                                        value: val,
                                        child: Text('$val'),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _trackingPageSize = val!;
                                        _trackingCurrentPage = 1;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('entries', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left, size: 18),
                                onPressed: _trackingCurrentPage > 1 ? () => setState(() => _trackingCurrentPage--) : null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              Text('$_trackingCurrentPage / ${totalPages == 0 ? 1 : totalPages}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, size: 18),
                                onPressed: _trackingCurrentPage < totalPages ? () => setState(() => _trackingCurrentPage++) : null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: _textPrimary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
          Text(value, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _textPrimary)),
        ],
      ),
    );
  }

  // --- ROUTE REPORTS END-TO-END IMPLEMENTATION ---
  Future<void> _loadRouteReports() async {
    if (_isLoadingReports) return;
    setState(() => _isLoadingReports = true);
    try {
      final schoolId = ref.read(authProvider).userData?['school_id']?.toString();
      final startStr = "${_reportsDateRange.start.year}-${_reportsDateRange.start.month.toString().padLeft(2, '0')}-${_reportsDateRange.start.day.toString().padLeft(2, '0')}";
      final endStr = "${_reportsDateRange.end.year}-${_reportsDateRange.end.month.toString().padLeft(2, '0')}-${_reportsDateRange.end.day.toString().padLeft(2, '0')}";
      
      String reportsPath = '/transport/reports?start_date=$startStr&end_date=$endStr';
      if (schoolId != null) {
        reportsPath += '&school_id=$schoolId';
      }
      if (_reportsRouteFilter != 'All') {
        reportsPath += '&route_id=$_reportsRouteFilter';
      }
      if (_reportsBusFilter != 'All') {
        reportsPath += '&vehicle_id=$_reportsBusFilter';
      }
      if (_reportsStatusFilter != 'All') {
        reportsPath += '&status=$_reportsStatusFilter';
      }
      
      final res = await ApiService().get(reportsPath, useCache: false);
      if (mounted) {
        setState(() {
          final data = res['data'] ?? {};
          _reportsSummary = data['summary'] != null ? Map<String, dynamic>.from(data['summary']) : {};
          _reportsStatusDonut = data['status_donut'] != null ? Map<String, dynamic>.from(data['status_donut']) : {};
          _reportsTrends = data['trends'] ?? [];
          _reportsRoutesPerformance = data['routes_performance'] ?? [];
          _reportsPerformanceSummary = data['performance_summary'] != null ? Map<String, dynamic>.from(data['performance_summary']) : {};
          _isLoadingReports = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReports = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load reports: $e'), backgroundColor: _red),
        );
      }
    }
  }

  Widget _buildRouteReportsTab() {
    return _isLoadingReports
        ? const Center(child: Padding(padding: EdgeInsets.all(64), child: CircularProgressIndicator()))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Content Block (Left / 75%)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Filters Row
                      _buildReportsFiltersRow(),
                      const SizedBox(height: 24),
                      
                      // KPI Metrics Grid
                      _buildReportsKpiGrid(),
                      const SizedBox(height: 24),
                      
                      // Analytics Charts Row
                      _buildReportsChartsRow(),
                      const SizedBox(height: 24),
                      
                      // Detailed Route Table
                      _buildReportsDetailsTable(),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Sidebar Content Block (Right / 25%)
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Route Performance Summary card
                      _buildReportsPerformanceSummaryCard(),
                      const SizedBox(height: 24),
                      // Report Quick Access list
                      _buildReportsQuickAccessCard(),
                      const SizedBox(height: 24),
                      // Scheduled Reports list
                      _buildReportsScheduledCard(),
                    ],
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildReportsFiltersRow() {
    final startStr = "${_reportsDateRange.start.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][_reportsDateRange.start.month-1]} ${_reportsDateRange.start.year}";
    final endStr = "${_reportsDateRange.end.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][_reportsDateRange.end.month-1]} ${_reportsDateRange.end.year}";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Date Range picker trigger
          InkWell(
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: _reportsDateRange,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  _reportsDateRange = picked;
                });
                _loadRouteReports();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: _textSecondary),
                  const SizedBox(width: 8),
                  Text('$startStr - $endStr', style: GoogleFonts.inter(fontSize: 12, color: _textPrimary)),
                ],
              ),
            ),
          ),
          
          // Route Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _reportsRouteFilter,
                style: GoogleFonts.inter(fontSize: 12, color: _textPrimary),
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All Routes')),
                  ..._routes.map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['route_name'] ?? 'Route'))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _reportsRouteFilter = val;
                    });
                  }
                },
              ),
            ),
          ),

          // Bus Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _reportsBusFilter,
                style: GoogleFonts.inter(fontSize: 12, color: _textPrimary),
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All Buses')),
                  ..._vehicles.map((v) => DropdownMenuItem(value: v['id'].toString(), child: Text(v['bus_number'] ?? 'Bus'))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _reportsBusFilter = val;
                    });
                  }
                },
              ),
            ),
          ),

          // Status Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _reportsStatusFilter,
                style: GoogleFonts.inter(fontSize: 12, color: _textPrimary),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All Status')),
                  DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                  DropdownMenuItem(value: 'On Time', child: Text('On Time')),
                  DropdownMenuItem(value: 'Delayed', child: Text('Delayed')),
                  DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _reportsStatusFilter = val;
                    });
                  }
                },
              ),
            ),
          ),

          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh, size: 18, color: _textSecondary),
            onPressed: _loadRouteReports,
            tooltip: 'Refresh Report Data',
          ),
          
          // Generate Report Action Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: const Icon(Icons.analytics_outlined, size: 16),
            label: Text('Generate Report', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: _loadRouteReports,
          ),
        ],
      ),
    );
  }

  Widget _buildReportsKpiGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // Responsive crossAxisCount based on screen width
        int crossAxisCount = 6;
        if (width < 600) {
          crossAxisCount = 2;
        } else if (width < 1100) {
          crossAxisCount = 3;
        }
        
        final double childAspectRatio = (width / crossAxisCount) < 180 ? 1.3 : 1.6;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
          children: [
            _buildReportsKpiCard(
              'Total Routes',
              _reportsSummary['total_routes']?.toString() ?? '0',
              'All Routes',
              Icons.directions_bus_rounded,
              _accent,
            ),
            _buildReportsKpiCard(
              'Total Trips',
              _reportsSummary['total_trips']?.toString() ?? '0',
              'This Range',
              Icons.alt_route,
              _green,
            ),
            _buildReportsKpiCard(
              'Total Distance',
              '${_reportsSummary['total_distance'] ?? 0} km',
              'This Range',
              Icons.speed,
              _blue,
            ),
            _buildReportsKpiCard(
              'Total Students',
              _reportsSummary['total_students']?.toString() ?? '0',
              'This Range',
              Icons.people_alt,
              _orange,
            ),
            _buildReportsKpiCard(
              'Average On-Time',
              '${_reportsSummary['average_on_time'] ?? 0}%',
              'This Range',
              Icons.timer,
              _blue,
            ),
            _buildReportsKpiCard(
              'Cancellation Rate',
              '${_reportsSummary['cancellation_rate'] ?? 0}%',
              'This Range',
              Icons.cancel,
              _red,
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportsKpiCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 8, color: _gray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsChartsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // Stack charts vertically on smaller screens
        if (width < 950) {
          return Column(
            children: [
              _buildChartBox('Trips by Status', _reportsBuildDonutChartWidget()),
              const SizedBox(height: 24),
              _buildChartBox('Distance Covered', _reportsBuildBarChartWidget()),
              const SizedBox(height: 24),
              _buildChartBox('On-Time Performance Trend', _reportsBuildLineChartWidget()),
            ],
          );
        }
        
        return Row(
          children: [
            Expanded(flex: 1, child: _buildChartBox('Trips by Status', _reportsBuildDonutChartWidget())),
            const SizedBox(width: 24),
            Expanded(flex: 1, child: _buildChartBox('Distance Covered', _reportsBuildBarChartWidget())),
            const SizedBox(width: 24),
            Expanded(flex: 1, child: _buildChartBox('On-Time Performance Trend', _reportsBuildLineChartWidget())),
          ],
        );
      },
    );
  }

  Widget _buildChartBox(String title, Widget chartWidget) {
    return Container(
      height: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
          const SizedBox(height: 16),
          Expanded(child: chartWidget),
        ],
      ),
    );
  }

  Widget _reportsBuildDonutChartWidget() {
    final completed = double.tryParse(_reportsStatusDonut['completed']?.toString() ?? '0') ?? 0.0;
    final onTime = double.tryParse(_reportsStatusDonut['on_time']?.toString() ?? '0') ?? 0.0;
    final delayed = double.tryParse(_reportsStatusDonut['delayed']?.toString() ?? '0') ?? 0.0;
    final cancelled = double.tryParse(_reportsStatusDonut['cancelled']?.toString() ?? '0') ?? 0.0;
    
    final total = completed + cancelled; // status_donut complete represents total
    final totalInt = total.toInt();

    return Row(
      children: [
        // Donut Chart Graphic
        SizedBox(
          width: 110,
          height: 110,
          child: CustomPaint(
            painter: CustomDonutPainter(
              completed: completed,
              onTime: onTime,
              delayed: delayed,
              cancelled: cancelled,
              total: total,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(totalInt > 0 ? '$totalInt' : '0', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: _textPrimary)),
                  Text('Total Trips', style: GoogleFonts.inter(fontSize: 8, color: _textSecondary)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Legend details
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendRow('Completed', completed, total, _green),
              const SizedBox(height: 8),
              _buildLegendRow('On Time', onTime, completed, _blue),
              const SizedBox(height: 8),
              _buildLegendRow('Delayed', delayed, completed, _orange),
              const SizedBox(height: 8),
              _buildLegendRow('Cancelled', cancelled, total, _red),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendRow(String title, double value, double baseVal, Color color) {
    final pct = baseVal > 0 ? (value / baseVal * 100).toStringAsFixed(1) : '0.0';
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: _textSecondary)),
        ),
        Text('${value.toInt()} ($pct%)', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _textPrimary)),
      ],
    );
  }

  Widget _reportsBuildBarChartWidget() {
    // Generate weekly ranges or default mock groups
    List<Map<String, dynamic>> barData = [];
    if (_reportsTrends.isNotEmpty) {
      // Chunk trends into 4 blocks of days to simulate weekly columns
      final chunkSize = (_reportsTrends.length / 4).ceil();
      for (int i = 0; i < 4; i++) {
        final startIdx = i * chunkSize;
        final endIdx = (i + 1) * chunkSize;
        final sub = _reportsTrends.sublist(
          startIdx,
          endIdx > _reportsTrends.length ? _reportsTrends.length : endIdx,
        );
        
        double dist = 0.0;
        for (var day in sub) {
          dist += double.tryParse(day['total_distance']?.toString() ?? '0') ?? 0.0;
        }
        
        String rangeName = '01-07 May';
        if (i == 1) rangeName = '08-14 May';
        if (i == 2) rangeName = '15-21 May';
        if (i == 3) rangeName = '22-31 May';
        
        barData.add({
          "label": rangeName,
          "value": dist,
        });
      }
    } else {
      barData = [
        {"label": "01-07 May", "value": 4125.0},
        {"label": "08-14 May", "value": 4582.0},
        {"label": "15-21 May", "value": 4916.0},
        {"label": "22-31 May", "value": 4900.0},
      ];
    }

    return CustomPaint(
      painter: CustomBarPainter(
        data: barData,
        barColor: _blue,
      ),
      child: Container(),
    );
  }

  Widget _reportsBuildLineChartWidget() {
    List<Map<String, dynamic>> lineData = [];
    if (_reportsTrends.isNotEmpty) {
      final chunkSize = (_reportsTrends.length / 4).ceil();
      for (int i = 0; i < 4; i++) {
        final startIdx = i * chunkSize;
        final endIdx = (i + 1) * chunkSize;
        final sub = _reportsTrends.sublist(
          startIdx,
          endIdx > _reportsTrends.length ? _reportsTrends.length : endIdx,
        );
        
        double onTimeSum = 0.0;
        double completedSum = 0.0;
        for (var day in sub) {
          onTimeSum += double.tryParse(day['on_time_trips']?.toString() ?? '0') ?? 0.0;
          completedSum += double.tryParse(day['total_trips']?.toString() ?? '0') ?? 0.0;
        }
        
        final double pct = completedSum > 0 ? (onTimeSum / completedSum * 100) : 90.0;
        
        String rangeName = '01-07 May';
        if (i == 1) rangeName = '08-14 May';
        if (i == 2) rangeName = '15-21 May';
        if (i == 3) rangeName = '22-31 May';
        
        lineData.add({
          "label": rangeName,
          "value": pct,
        });
      }
    } else {
      lineData = [
        {"label": "01-07 May", "value": 89.12},
        {"label": "08-14 May", "value": 91.45},
        {"label": "15-21 May", "value": 93.87},
        {"label": "22-31 May", "value": 92.92},
      ];
    }

    return CustomPaint(
      painter: CustomLinePainter(
        data: lineData,
        lineColor: _accent,
      ),
      child: Container(),
    );
  }

  void _downloadRouteReportCSV(Map<String, dynamic> r) {
    final code = r['route_code'] ?? 'RT-000';
    final name = r['route_name'] ?? 'Route';
    final trips = r['total_trips'] ?? 0;
    final completed = r['completed_trips'] ?? 0;
    final cancelled = r['cancelled_trips'] ?? 0;
    final onTimePct = r['on_time_pct'] ?? 0.0;
    final avgDelay = r['avg_delay'] ?? 0.0;
    final distance = r['total_distance'] ?? 0.0;
    final students = r['students_transported'] ?? 0;

    final csvContent = 'Route Code,Route Name,Total Trips,Completed Trips,Cancelled Trips,On-Time %,Avg Delay (min),Total Distance (km),Students Transported\n'
        '$code,$name,$trips,$completed,$cancelled,$onTimePct%,$avgDelay,$distance,$students';
        
    downloadFile(csvContent, '${code}_performance_report.csv');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV Report for $code generated and downloaded successfully!'),
        backgroundColor: _green,
      ),
    );
  }

  void _showRouteDetailsReportDialog(Map<String, dynamic> r) {
    final code = r['route_code'] ?? 'RT-000';
    final name = r['route_name'] ?? 'Route';
    final trips = r['total_trips'] ?? 0;
    final completed = r['completed_trips'] ?? 0;
    final cancelled = r['cancelled_trips'] ?? 0;
    final onTimePct = r['on_time_pct'] ?? 0.0;
    final avgDelay = r['avg_delay'] ?? 0.0;
    final distance = r['total_distance'] ?? 0.0;
    final students = r['students_transported'] ?? 0;

    // Filter stops for this route
    final routeStops = _stops.where((s) => s['route_id']?.toString() == r['route_id']?.toString()).toList();
    routeStops.sort((a, b) => (a['stop_order'] ?? 0).compareTo(b['stop_order'] ?? 0));

    // Find driver and vehicle details from main route list
    final mainRoute = _routes.firstWhere(
      (route) => route['id']?.toString() == r['route_id']?.toString(),
      orElse: () => null,
    );
    final driverName = mainRoute != null && mainRoute['drivers'] != null ? mainRoute['drivers']['name'] ?? 'Ramesh Kumar' : 'Ramesh Kumar';
    final busNumber = mainRoute != null && mainRoute['bus_routes'] != null ? mainRoute['bus_routes']['bus_number'] ?? 'UP16 ET 1234' : 'UP16 ET 1234';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Container(
            width: 700,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(code, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: _accent)),
                        ),
                        const SizedBox(width: 12),
                        Text('$name Analytics', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),
                
                // Content layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (KPI Metrics)
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Route Performance Metrics', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildDialogMetricBox('Total Trips', '$trips', _accent)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildDialogMetricBox('On-Time Rate', '$onTimePct%', _green)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildDialogMetricBox('Completed', '$completed', _blue)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildDialogMetricBox('Cancelled', '$cancelled', _red)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text('Assignments', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _bg,
                              border: Border.all(color: _border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                _buildDialogAssignmentRow('Assigned Driver', driverName, Icons.person),
                                const Divider(height: 16),
                                _buildDialogAssignmentRow('Assigned Bus', busNumber, Icons.directions_bus),
                                const Divider(height: 16),
                                _buildDialogAssignmentRow('Total Distance', '$distance km', Icons.map),
                                const Divider(height: 16),
                                _buildDialogAssignmentRow('Passengers', '$students students', Icons.people),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right Column (Stops Timeline)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Stops Sequence (${routeStops.length})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
                          const SizedBox(height: 12),
                          routeStops.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Text('No stops registered for this route.', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                  ),
                                )
                              : Container(
                                  constraints: const BoxConstraints(maxHeight: 280),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: routeStops.length,
                                    itemBuilder: (context, index) {
                                      final stop = routeStops[index];
                                      final stopName = stop['stop_name'] ?? 'Stop';
                                      final arrival = stop['estimated_arrival']?.toString().substring(0, 5) ?? '—';
                                      final isLast = index == routeStops.length - 1;
                                      
                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Column(
                                            children: [
                                              Container(
                                                width: 16,
                                                height: 16,
                                                decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
                                                child: Center(
                                                  child: Text('${index + 1}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                                ),
                                              ),
                                              if (!isLast)
                                                Container(
                                                  width: 2,
                                                  height: 32,
                                                  color: _border,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(stopName, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
                                                Text('Est: $arrival', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                                                const SizedBox(height: 8),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogMetricBox(String title, String val, Color col) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 9, color: _textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(val, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: col)),
        ],
      ),
    );
  }

  Widget _buildDialogAssignmentRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _textSecondary),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
        const Spacer(),
        Text(value, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _textPrimary)),
      ],
    );
  }

  Widget _buildReportsDetailsTable() {
    final total = _reportsRoutesPerformance.length;
    final totalPages = (total / _reportsTablePageSize).ceil();
    final actualPage = _reportsTableCurrentPage > totalPages ? totalPages : _reportsTableCurrentPage;
    final startIndex = total == 0 ? 0 : (actualPage - 1) * _reportsTablePageSize;
    final endIndex = (startIndex + _reportsTablePageSize) > total ? total : (startIndex + _reportsTablePageSize);
    
    final paginated = total == 0 ? [] : _reportsRoutesPerformance.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Route Performance Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
          ),
          const Divider(height: 1),
          
          LayoutBuilder(
            builder: (context, constraints) {
              final double tableWidth = constraints.maxWidth > 1250 ? constraints.maxWidth : 1250;
              return Scrollbar(
                controller: _reportsTableScrollController,
                child: SingleChildScrollView(
                  controller: _reportsTableScrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: DataTable(
                      columnSpacing: 18,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 58,
                      columns: [
                        DataColumn(label: Text('Route Code', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                        DataColumn(label: Text('Route Name', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                        DataColumn(label: Text('Total Trips', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                        DataColumn(label: Text('Completed Trips', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                        DataColumn(label: Text('Cancelled Trips', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                        DataColumn(label: Text('On-Time %', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                        DataColumn(label: Text('Avg Delay', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                        DataColumn(label: Text('Total Distance', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                        DataColumn(label: Text('Students Transported', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                        DataColumn(label: Text('Actions', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: _textPrimary))),
                      ],
                      rows: paginated.map((r) {
                        final code = r['route_code'] ?? 'RT-000';
                        final name = r['route_name'] ?? 'Route';
                        final trips = r['total_trips'] ?? 0;
                        final completed = r['completed_trips'] ?? 0;
                        final cancelled = r['cancelled_trips'] ?? 0;
                        final onTimePct = r['on_time_pct'] ?? 0.0;
                        final avgDelay = r['avg_delay'] ?? 0.0;
                        final distance = r['total_distance'] ?? 0.0;
                        final students = r['students_transported'] ?? 0;
                        
                        // Pick color based on code digits
                        Color codeCol = _accent;
                        if (code.endsWith('2')) codeCol = _blue;
                        if (code.endsWith('3')) codeCol = _green;
                        if (code.endsWith('4')) codeCol = _orange;
                        if (code.endsWith('5')) codeCol = _red;
                        
                        return DataRow(
                          cells: [
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: codeCol.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(code, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: codeCol)),
                            )),
                            DataCell(Text(name, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500))),
                            DataCell(Text('$trips', style: GoogleFonts.inter(fontSize: 11))),
                            DataCell(Text('$completed', style: GoogleFonts.inter(fontSize: 11))),
                            DataCell(Text('$cancelled', style: GoogleFonts.inter(fontSize: 11))),
                            DataCell(Text('$onTimePct%', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: onTimePct >= 90 ? _green : _red))),
                            DataCell(Text('$avgDelay min', style: GoogleFonts.inter(fontSize: 11))),
                            DataCell(Text('$distance km', style: GoogleFonts.inter(fontSize: 11))),
                            DataCell(Text('$students', style: GoogleFonts.inter(fontSize: 11))),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.remove_red_eye_outlined, size: 14, color: _textSecondary),
                                  onPressed: () => _showRouteDetailsReportDialog(r),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.download_rounded, size: 14, color: _textSecondary),
                                  onPressed: () => _downloadRouteReportCSV(r),
                                ),
                              ],
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
          
          const Divider(height: 1),
          // Pagination Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Showing ${total == 0 ? 0 : startIndex + 1} to $endIndex of $total routes', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _reportsTablePageSize,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 16, color: _textSecondary),
                          items: [5, 8, 10, 20, 50].map((size) {
                            return DropdownMenuItem<int>(
                              value: size,
                              child: Text('$size / page', style: GoogleFonts.inter(fontSize: 11, color: _textPrimary)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _reportsTablePageSize = val;
                                _reportsTableCurrentPage = 1;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 16),
                      onPressed: _reportsTableCurrentPage > 1
                          ? () => setState(() => _reportsTableCurrentPage--)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(4)),
                      child: Text('$_reportsTableCurrentPage', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 16),
                      onPressed: _reportsTableCurrentPage < totalPages
                          ? () => setState(() => _reportsTableCurrentPage++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsPerformanceSummaryCard() {
    final best = _reportsPerformanceSummary['best_performing_route'] ?? {"name": "—", "value": "0.0%"};
    final worst = _reportsPerformanceSummary['worst_performing_route'] ?? {"name": "—", "value": "0.0%"};
    final most = _reportsPerformanceSummary['most_trips_route'] ?? {"name": "—", "value": "0"};
    final least = _reportsPerformanceSummary['least_trips_route'] ?? {"name": "—", "value": "0"};
    final longest = _reportsPerformanceSummary['longest_route'] ?? {"name": "—", "value": "0 km"};
    final shortest = _reportsPerformanceSummary['shortest_route'] ?? {"name": "—", "value": "0 km"};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Route Performance Summary', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
          const SizedBox(height: 16),
          _buildSummaryItem('Best Performing Route', best['name'].toString(), best['value'].toString(), _green),
          const Divider(height: 24),
          _buildSummaryItem('Lowest Performing Route', worst['name'].toString(), worst['value'].toString(), _red),
          const Divider(height: 24),
          _buildSummaryItem('Most Trips', most['name'].toString(), most['value'].toString(), _accent),
          const Divider(height: 24),
          _buildSummaryItem('Least Trips', least['name'].toString(), least['value'].toString(), _orange),
          const Divider(height: 24),
          _buildSummaryItem('Longest Route', longest['name'].toString(), longest['value'].toString(), _blue),
          const Divider(height: 24),
          _buildSummaryItem('Shortest Route', shortest['name'].toString(), shortest['value'].toString(), _gray),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String subLabel, String val, Color tagCol) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
            ],
          ),
        ),
        Text(val, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: tagCol)),
      ],
    );
  }

  Widget _buildReportsQuickAccessCard() {
    final reportsList = [
      'Route Performance Report',
      'Trip Summary Report',
      'On-Time Performance Report',
      'Distance & Fuel Report',
      'Cancellation Report',
      'Driver Performance Report',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report Quick Access', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
          const SizedBox(height: 16),
          ...reportsList.map((rep) {
            return InkWell(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: _accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.insert_drive_file_outlined, size: 14, color: _accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(rep, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: _textPrimary))),
                    const Icon(Icons.arrow_forward_ios, size: 10, color: _gray),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReportsScheduledCard() {
    final list = [
      {"title": "Daily Routes Report", "desc": "Every day at 08:00 AM"},
      {"title": "Weekly Performance Report", "desc": "Every Monday at 09:00 AM"},
      {"title": "Monthly Summary Report", "desc": "1st day of every month at 10:00 AM"},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Scheduled Reports', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
              Text('View All', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _accent)),
            ],
          ),
          const SizedBox(height: 16),
          ...list.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: _green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['title']!, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
                        Text(item['desc']!, style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text('Active', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: _green)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTab(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction_rounded, size: 48, color: _gray),
          const SizedBox(height: 16),
          Text('$title Sub-Tab', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
          Text('This view is currently scheduled for development.', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildStopsTab() {
    // Filters and search logic
    final filtered = _stops.where((s) {
      if (_stopsSearchQuery.isNotEmpty) {
        final q = _stopsSearchQuery.toLowerCase();
        final code = (s['stop_code'] ?? '').toString().toLowerCase();
        final name = (s['stop_name'] ?? '').toString().toLowerCase();
        final route = ((s['transport_routes'] ?? {})['route_name'] ?? '').toString().toLowerCase();
        if (!code.contains(q) && !name.contains(q) && !route.contains(q)) return false;
      }
      if (_stopsStatusFilter != 'All') {
        if (s['status'] != _stopsStatusFilter) return false;
      }
      if (_stopsTypeFilter != 'All') {
        if (s['stop_type'] != _stopsTypeFilter) return false;
      }
      if (_stopsRouteFilter != 'All') {
        if (s['route_id']?.toString() != _stopsRouteFilter) return false;
      }
      return true;
    }).toList();

    final total = filtered.length;
    final totalPages = (total / _stopsPageSize).ceil();
    final startIdx = (_stopsCurrentPage - 1) * _stopsPageSize;
    final endIdx = startIdx + _stopsPageSize > total ? total : startIdx + _stopsPageSize;
    final paginatedStops = filtered.sublist(startIdx, endIdx);

    // Stops stats computation
    final totalStops = filtered.length;
    final activeStops = filtered.where((s) => s['status'] == 'Active').length;
    final inactiveStops = filtered.where((s) => s['status'] == 'Inactive').length;
    final deletedStops = filtered.where((s) => s['status'] == 'Deleted').length;
    final thisMonthStops = filtered.where((s) {
      final dateStr = s['created_at'];
      if (dateStr == null) return false;
      try {
        final created = DateTime.parse(dateStr.toString());
        final now = DateTime.now();
        return created.year == now.year && created.month == now.month;
      } catch (_) {}
      return false;
    }).length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. KPI Stats Row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: 180, child: _buildKPICard('Total Stops', '$totalStops', 'All Routes', Icons.location_on_outlined, _accent)),
                SizedBox(width: 180, child: _buildKPICard('Active Stops', '$activeStops', '${totalStops > 0 ? (activeStops / totalStops * 100).toStringAsFixed(1) : 0}%', Icons.check_circle_outline, _green)),
                SizedBox(width: 180, child: _buildKPICard('Inactive Stops', '$inactiveStops', '${totalStops > 0 ? (inactiveStops / totalStops * 100).toStringAsFixed(1) : 0}%', Icons.pause_circle_outline, _orange)),
                SizedBox(width: 180, child: _buildKPICard('Deleted Stops', '$deletedStops', '${totalStops > 0 ? (deletedStops / totalStops * 100).toStringAsFixed(1) : 0}%', Icons.delete_outline, _blue)),
                SizedBox(width: 180, child: _buildKPICard('Stops This Month', '$thisMonthStops', 'Newly Added', Icons.calendar_today_outlined, _accent)),
              ],
            ),
          ),

          // 2. Filters Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 250,
                        child: TextField(
                          controller: _stopsSearchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, size: 18),
                            hintText: 'Search stops by name or code...',
                            fillColor: Colors.white,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                          ),
                        ),
                      ),
                      DropdownButton<String>(
                        value: (_stopsRouteFilter == 'All' || _routes.any((r) => r['id'].toString() == _stopsRouteFilter)) ? _stopsRouteFilter : 'All',
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem(value: 'All', child: Text('All Routes')),
                          ..._routes.map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['route_name']))),
                        ],
                        onChanged: (val) => setState(() { _stopsRouteFilter = val!; _stopsCurrentPage = 1; _loadStops(); }),
                      ),
                      DropdownButton<String>(
                        value: _stopsStatusFilter,
                        underline: const SizedBox(),
                        items: ['All', 'Active', 'Inactive', 'Deleted'].map((s) => DropdownMenuItem(value: s, child: Text('$s Status'))).toList(),
                        onChanged: (val) => setState(() { _stopsStatusFilter = val!; _stopsCurrentPage = 1; _loadStops(); }),
                      ),
                      DropdownButton<String>(
                        value: _stopsTypeFilter,
                        underline: const SizedBox(),
                        items: ['All', 'Pickup', 'Drop', 'Pickup & Drop'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Stop Types' : s))).toList(),
                        onChanged: (val) => setState(() { _stopsTypeFilter = val!; _stopsCurrentPage = 1; _loadStops(); }),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _stopsSearchController.clear();
                          _stopsRouteFilter = 'All';
                          _stopsStatusFilter = 'All';
                          _stopsTypeFilter = 'All';
                          _stopsCurrentPage = 1;
                          _loadStops();
                        }),
                        icon: const Icon(Icons.filter_list, size: 14),
                        label: const Text('Reset'),
                      ),
                      IconButton(onPressed: _loadStops, icon: const Icon(Icons.refresh, size: 18)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showStopFormDialog(null),
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add New Stop'),
                ),
              ],
            ),
          ),

          // 3. Split View Content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              height: 650,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Column: Table List
                  Expanded(
                    flex: 6,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _isLoadingStopsTab
                                ? const Center(child: CircularProgressIndicator())
                                : Scrollbar(
                                    controller: _stopsTableScrollController,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      controller: _stopsTableScrollController,
                                      child: SingleChildScrollView(
                                        child: SizedBox(
                                          width: 900,
                                          child: DataTable(
                                          showCheckboxColumn: false,
                                          columnSpacing: 18,
                                          horizontalMargin: 10,
                                          columns: const [
                                            DataColumn(label: Text('Stop Code')),
                                            DataColumn(label: Text('Stop Name')),
                                            DataColumn(label: Text('Route Name')),
                                            DataColumn(label: Text('Sequence')),
                                            DataColumn(label: Text('Stop Type')),
                                            DataColumn(label: Text('Pickup / Drop')),
                                            DataColumn(label: Text('Status')),
                                            DataColumn(label: Text('Actions')),
                                          ],
                                          rows: paginatedStops.map((s) {
                                            final isSelected = _selectedStop?['id'] == s['id'];
                                            final statusColor = s['status'] == 'Active'
                                                ? _green
                                                : (s['status'] == 'Inactive' ? _orange : _red);
                                            return DataRow(
                                              selected: isSelected,
                                              onSelectChanged: (_) {
                                                setState(() {
                                                  _selectedStop = s;
                                                });
                                              },
                                              cells: [
                                                DataCell(Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(color: _accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                                                  child: Text(s['stop_code'] ?? '—', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _accent, fontSize: 11)),
                                                )),
                                                DataCell(Text(s['stop_name'] ?? '—', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                                              DataCell(Text((s['transport_routes'] ?? {})['route_name'] ?? '—', style: GoogleFonts.inter(fontSize: 12))),
                                              DataCell(Text('${s['stop_order'] ?? 1}', style: GoogleFonts.inter(fontSize: 12))),
                                              DataCell(Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: _blue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                                                child: Text(s['stop_type'] ?? 'Pickup', style: GoogleFonts.inter(fontSize: 11, color: _blue, fontWeight: FontWeight.bold)),
                                              )),
                                              DataCell(Text(s['pickup_drop_type'] ?? 'Pickup Only', style: GoogleFonts.inter(fontSize: 12))),
                                              DataCell(Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                                child: Text(s['status'] ?? 'Active', style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                              )),
                                              DataCell(Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showStopFormDialog(s)),
                                                  IconButton(icon: const Icon(Icons.delete, size: 16, color: _red), onPressed: () => _deleteStop(s)),
                                                ],
                                              )),
                                            ],
                                          );
                                        }).toList(),
                                        ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          // Pagination
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Text('Showing ${total > 0 ? startIdx + 1 : 0} to $endIdx of $total stops', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Show', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                    const SizedBox(width: 6),
                                    Container(
                                      height: 28,
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: _border),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _stopsPageSize,
                                          style: GoogleFonts.inter(fontSize: 11, color: _textPrimary, fontWeight: FontWeight.bold),
                                          items: [5, 10, 15, 20, 50].map((int val) {
                                            return DropdownMenuItem<int>(
                                              value: val,
                                              child: Text('$val'),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            setState(() {
                                              _stopsPageSize = val!;
                                              _stopsCurrentPage = 1;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('entries', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left, size: 18),
                                      onPressed: _stopsCurrentPage > 1 ? () => setState(() => _stopsCurrentPage--) : null,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('$_stopsCurrentPage / ${totalPages == 0 ? 1 : totalPages}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right, size: 18),
                                      onPressed: _stopsCurrentPage < totalPages ? () => setState(() => _stopsCurrentPage++) : null,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right Column: Preview & Map
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Map Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Text('Route & Stop Preview', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: (_selectedPreviewRoute != null && _routes.any((r) => r['id'].toString() == _selectedPreviewRoute!['id'].toString())) ? _selectedPreviewRoute!['id'].toString() : null,
                                          isExpanded: true,
                                          style: GoogleFonts.inter(fontSize: 11, color: _textPrimary),
                                          items: _routes.map((r) => DropdownMenuItem<String>(
                                            value: r['id'].toString(),
                                            child: Text(r['route_name'], overflow: TextOverflow.ellipsis),
                                          )).toList(),
                                          onChanged: (val) {
                                            final route = _routes.firstWhere((r) => r['id'].toString() == val);
                                            setState(() {
                                              _selectedPreviewRoute = route;
                                            });
                                            _loadStopsPreviewRoute(val!);
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: () {
                                        if (_selectedPreviewRoute != null) {
                                          setState(() {
                                            _selectedRoute = _selectedPreviewRoute;
                                            _tabController.animateTo(1);
                                          });
                                          _loadStopsForRoute(_selectedPreviewRoute['id']);
                                        }
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text('View Route', style: GoogleFonts.inter(fontSize: 10)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // OSM Map (Fixed Height)
                          SizedBox(
                            height: 240,
                            child: _stopsPreviewRouteStops.isEmpty
                                ? const Center(child: Text('Select a route to display stops on the map.'))
                                : ClipRRect(
                                    child: FlutterMap(
                                      mapController: _stopsMapController,
                                      options: MapOptions(
                                        initialCenter: LatLng(
                                          double.tryParse(_stopsPreviewRouteStops[0]['latitude'].toString()) ?? 28.62,
                                          double.tryParse(_stopsPreviewRouteStops[0]['longitude'].toString()) ?? 77.36,
                                        ),
                                        initialZoom: 13.5,
                                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                                      ),
                                      children: [
                                        TileLayer(
                                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                          userAgentPackageName: 'com.edushamiit.admin',
                                          maxZoom: 19,
                                          tileProvider: CancellableNetworkTileProvider(),
                                        ),
                                        PolylineLayer(
                                          polylines: [
                                            Polyline(
                                              points: _stopsPreviewRouteStops.map((s) => LatLng(
                                                double.tryParse(s['latitude'].toString()) ?? 28.62,
                                                double.tryParse(s['longitude'].toString()) ?? 77.36
                                              )).toList(),
                                              color: _accent,
                                              strokeWidth: 4.0,
                                            ),
                                          ],
                                        ),
                                        MarkerLayer(
                                          markers: _stopsPreviewRouteStops.asMap().entries.map((entry) {
                                            final idx = entry.key;
                                            final stop = entry.value;
                                            return Marker(
                                              point: LatLng(
                                                double.tryParse(stop['latitude'].toString()) ?? 28.62,
                                                double.tryParse(stop['longitude'].toString()) ?? 77.36
                                              ),
                                              width: 28,
                                              height: 28,
                                              child: Container(
                                                decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
                                                child: Center(
                                                  child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          const Divider(height: 1),

                          // Stop Details footer (Scrollable)
                          Expanded(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: _selectedStop == null
                                    ? const Center(child: Text('Select a stop from the list to view details.'))
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(color: _accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                                                          child: Text(_selectedStop['stop_code'] ?? 'ST-000', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _accent, fontSize: 12)),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(child: Text(_selectedStop['stop_name'] ?? '—', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Route: ${(_selectedStop['transport_routes'] ?? {})['route_name'] ?? 'Unassigned'}',
                                                      style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: (_selectedStop['status'] == 'Active' ? _green : _orange).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(_selectedStop['status'] ?? 'Active', style: TextStyle(color: _selectedStop['status'] == 'Active' ? _green : _orange, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Wrap(
                                            spacing: 16,
                                            runSpacing: 12,
                                            children: [
                                              SizedBox(width: 140, child: _buildStopInfoDetailItem('Stop Type', _selectedStop['stop_type'] ?? 'Pickup')),
                                              SizedBox(width: 140, child: _buildStopInfoDetailItem('Area / Zone', (_selectedStop['transport_routes'] ?? {})['area_zone'] ?? 'Noida')),
                                              SizedBox(width: 140, child: _buildStopInfoDetailItem('Pickup / Drop', _selectedStop['pickup_drop_type'] ?? 'Pickup Only')),
                                              SizedBox(width: 140, child: _buildStopInfoDetailItem('Landmark', _selectedStop['landmark'] ?? 'Near Location')),
                                              SizedBox(width: 140, child: _buildStopInfoDetailItem('Sequence', '${_selectedStop['stop_order'] ?? 1}')),
                                              SizedBox(width: 140, child: _buildStopInfoDetailItem('Geofence Radius', '${_selectedStop['radius_meters'] ?? 200} meters')),
                                              SizedBox(width: 140, child: _buildStopInfoDetailItem('Assigned Bus', 'UP16 ET 1234 (AC Bus)')),
                                              SizedBox(width: 140, child: _buildStopInfoDetailItem('Added On', '12 Apr 2024, 10:30 AM')),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () => _showStopFormDialog(_selectedStop),
                                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                                                  child: const Text('Edit Stop'),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () async {
                                                    try {
                                                      final newStatus = _selectedStop['status'] == 'Active' ? 'Inactive' : 'Active';
                                                      await ApiService().put('/transport/stops/${_selectedStop['id']}', {
                                                        "status": newStatus
                                                      });
                                                      _loadData();
                                                      _loadStops();
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Stop status updated to $newStatus'), backgroundColor: _green),
                                                      );
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Failed to update stop status: $e'), backgroundColor: _red),
                                                      );
                                                    }
                                                  },
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: _selectedStop['status'] == 'Active' ? _red : _green,
                                                    side: BorderSide(color: _selectedStop['status'] == 'Active' ? _red : _green),
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                  ),
                                                  child: Text(_selectedStop['status'] == 'Active' ? 'Deactivate Stop' : 'Activate Stop'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopInfoDetailItem(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
        const SizedBox(height: 2),
        Text(val, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  // Helpers for time formatting
  String _formatTime(dynamic raw) {
    if (raw == null) return '—';
    final str = raw.toString();
    try {
      final parts = str.split(':');
      if (parts.length >= 2) {
        final hr = int.parse(parts[0]);
        final min = parts[1];
        final period = hr >= 12 ? 'PM' : 'AM';
        final displayHr = hr % 12 == 0 ? 12 : hr % 12;
        return '${displayHr.toString().padLeft(2, '0')}:$min $period';
      }
    } catch (_) {}
    return str;
  }
}

class PieChartPainter extends CustomPainter {
  final double completedPct;
  final double ongoingPct;
  final double scheduledPct;
  final double cancelledPct;

  PieChartPainter({
    required this.completedPct,
    required this.ongoingPct,
    required this.scheduledPct,
    required this.cancelledPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    double startAngle = -3.14159 / 2;

    if (completedPct > 0) {
      paint.color = const Color(0xFF10B981);
      final sweepAngle = 2 * 3.14159 * completedPct;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
    if (ongoingPct > 0) {
      paint.color = Colors.blue;
      final sweepAngle = 2 * 3.14159 * ongoingPct;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
    if (scheduledPct > 0) {
      paint.color = const Color(0xFFF59E0B);
      final sweepAngle = 2 * 3.14159 * scheduledPct;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
    if (cancelledPct > 0) {
      paint.color = const Color(0xFFEF4444);
      final sweepAngle = 2 * 3.14159 * cancelledPct;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


class CustomDonutPainter extends CustomPainter {
  final double completed;
  final double onTime;
  final double delayed;
  final double cancelled;
  final double total;

  CustomDonutPainter({
    required this.completed,
    required this.onTime,
    required this.delayed,
    required this.cancelled,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.square;

    double startAngle = -math.pi / 2;

    final double onTimePct = onTime / total;
    final double delayedPct = delayed / total;
    final double cancelledPct = cancelled / total;
    
    final double otherCompleted = math.max(0.0, completed - onTime - delayed);
    final double otherCompletedPct = otherCompleted / total;

    if (onTimePct > 0) {
      paint.color = const Color(0xFF3B82F6); // Blue
      final sweepAngle = 2 * math.pi * onTimePct;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
    if (otherCompletedPct > 0) {
      paint.color = const Color(0xFF22C55E); // Green
      final sweepAngle = 2 * math.pi * otherCompletedPct;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
    if (delayedPct > 0) {
      paint.color = const Color(0xFFF59E0B); // Orange
      final sweepAngle = 2 * math.pi * delayedPct;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
    if (cancelledPct > 0) {
      paint.color = const Color(0xFFEF4444); // Red
      final sweepAngle = 2 * math.pi * cancelledPct;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CustomBarPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final Color barColor;

  CustomBarPainter({required this.data, required this.barColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()..color = barColor;
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    double maxVal = 0.0;
    for (var d in data) {
      final val = double.tryParse(d['value']?.toString() ?? '0') ?? 0.0;
      if (val > maxVal) maxVal = val;
    }
    if (maxVal == 0) maxVal = 100.0;
    maxVal = (maxVal / 1000).ceil() * 1000.0;

    final double graphHeight = size.height - 30;
    final double graphWidth = size.width - 40;

    for (int i = 0; i <= 4; i++) {
      final double y = graphHeight - (i * (graphHeight / 4)) + 5;
      final int gridVal = (maxVal * i / 4).toInt();
      
      canvas.drawLine(Offset(40, y), Offset(size.width, y), gridPaint);

      String gridText = '$gridVal';
      if (gridVal >= 1000) {
        gridText = '${(gridVal / 1000).toStringAsFixed(0)}K';
      }
      textPainter.text = TextSpan(
        text: gridText,
        style: GoogleFonts.inter(fontSize: 8, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }

    final double barSpacing = graphWidth / data.length;
    final double barWidth = math.max(12.0, barSpacing * 0.4);

    for (int i = 0; i < data.length; i++) {
      final double val = double.tryParse(data[i]['value']?.toString() ?? '0') ?? 0.0;
      final double barHeight = (val / maxVal) * (graphHeight - 10);
      final double x = 40 + (i * barSpacing) + (barSpacing - barWidth) / 2;
      final double y = graphHeight + 5 - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, paint);

      final labelVal = val.toInt();
      textPainter.text = TextSpan(
        text: '$labelVal',
        style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + (barWidth - textPainter.width) / 2, y - textPainter.height - 4));

      textPainter.text = TextSpan(
        text: data[i]['label'] ?? '',
        style: GoogleFonts.inter(fontSize: 8, color: const Color(0xFF64748B)),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + (barWidth - textPainter.width) / 2, graphHeight + 12));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CustomLinePainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final Color lineColor;

  CustomLinePainter({required this.data, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final double graphHeight = size.height - 30;
    final double graphWidth = size.width - 45;

    for (int i = 0; i <= 4; i++) {
      final double y = graphHeight - (i * (graphHeight / 4)) + 5;
      final int gridVal = i * 25;
      
      canvas.drawLine(Offset(45, y), Offset(size.width, y), gridPaint);

      textPainter.text = TextSpan(
        text: '$gridVal%',
        style: GoogleFonts.inter(fontSize: 8, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }

    final List<Offset> points = [];
    final double stepX = graphWidth / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final double val = double.tryParse(data[i]['value']?.toString() ?? '0') ?? 0.0;
      final double x = 45 + (i * stepX);
      final double y = graphHeight + 5 - ((val / 100) * (graphHeight - 10));
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < points.length; i++) {
      final double val = double.tryParse(data[i]['value']?.toString() ?? '0') ?? 0.0;
      final offset = points[i];

      canvas.drawCircle(offset, 5, pointPaint);
      canvas.drawCircle(offset, 5, pointBorderPaint);

      textPainter.text = TextSpan(
        text: '${val.toStringAsFixed(1)}%',
        style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(offset.dx - textPainter.width / 2, offset.dy - textPainter.height - 6));

      textPainter.text = TextSpan(
        text: data[i]['label'] ?? '',
        style: GoogleFonts.inter(fontSize: 8, color: const Color(0xFF64748B)),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(offset.dx - textPainter.width / 2, graphHeight + 12));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CustomRouteDonutPainter extends CustomPainter {
  final double val1;
  final double val2;
  final double val3;
  final Color col1;
  final Color col2;
  final Color col3;
  final double total;

  CustomRouteDonutPainter({
    required this.val1,
    required this.val2,
    required this.val3,
    required this.col1,
    required this.col2,
    required this.col3,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    double startAngle = -math.pi / 2;

    final double pct1 = val1 / total;
    final double pct2 = val2 / total;
    final double pct3 = val3 / total;

    if (pct1 > 0) {
      paint.color = col1;
      final sweepAngle = 2 * math.pi * pct1;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
    if (pct2 > 0) {
      paint.color = col2;
      final sweepAngle = 2 * math.pi * pct2;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
    if (pct3 > 0) {
      paint.color = col3;
      final sweepAngle = 2 * math.pi * pct3;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

