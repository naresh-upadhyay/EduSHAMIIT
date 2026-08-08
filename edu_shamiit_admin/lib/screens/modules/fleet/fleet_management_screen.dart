import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'driver_management_tab.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

class FleetManagementScreen extends StatefulWidget {
  final int initialTab;
  const FleetManagementScreen({super.key, this.initialTab = 0});

  @override
  State<FleetManagementScreen> createState() => _FleetManagementScreenState();
}

class _FleetManagementScreenState extends State<FleetManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<DriverManagementTabState> _driverTabKey = GlobalKey<DriverManagementTabState>();

  // ═══════════════════ State ═══════════════════
  bool _isLoading = true;
  List<dynamic> _vehicles = [];
  List<dynamic> _categories = [];
  List<dynamic> _documents = [];
  List<dynamic> _insuranceFitness = [];
  List<dynamic> _gpsDevices = [];
  List<dynamic> _drivers = [];

  // Selected vehicle & category for details panel
  dynamic _selectedVehicle;
  dynamic _selectedCategory;
  int _selectedDetailTab = 0; // 0: Overview, 1: Details, 2: Documents, 3: Maintenance, 4: GPS
  List<dynamic> _vehicleMaintenance = [];
  bool _loadingVehicleDetails = false;

  Future<void> _fetchVehicleDetailData(dynamic vehicle, {bool silent = false}) async {
    if (vehicle == null) return;
    final vId = vehicle['id']?.toString();
    if (vId == null) return;

    if (!silent && mounted) setState(() => _loadingVehicleDetails = true);
    try {
      final docsRes = await ApiService().get('/transport/documents?vehicle_id=$vId', useCache: false);
      final maintRes = await ApiService().get('/transport/maintenance?vehicle_id=$vId', useCache: false);
      final gpsRes = await ApiService().get('/transport/gps-devices?vehicle_id=$vId', useCache: false);

      if (mounted) {
        setState(() {
          if (docsRes['data'] is List) {
            final List fetched = docsRes['data'];
            for (var d in fetched) {
              if (!_documents.any((existing) => existing['id'] == d['id'])) {
                _documents.add(d);
              }
            }
          }
          if (maintRes['data'] is List) {
            _vehicleMaintenance = List<dynamic>.from(maintRes['data']);
          }
          if (gpsRes['data'] is List) {
            final List fetchedGps = gpsRes['data'];
            if (fetchedGps.isNotEmpty) {
              final g = fetchedGps.first;
              vehicle['gps_device_id'] = g['device_id'];
              vehicle['imei_no'] = g['imei_no'];
              vehicle['sim_no'] = g['sim_no'];
              vehicle['operator'] = g['operator'];
              vehicle['battery_level'] = g['battery_level'];
              vehicle['signal_strength_pct'] = g['signal_strength_pct'];
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching vehicle details: $e");
    } finally {
      if (!silent && mounted) {
        setState(() => _loadingVehicleDetails = false);
      }
    }
  }

  // Filters & Pagination for Vehicles
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _categoryFilter = 'All';
  String _fuelFilter = 'All';
  int _currentPage = 1;
  int _pageSize = 10;

  // Filters & Pagination for Categories
  final TextEditingController _categorySearchController = TextEditingController();
  String _categorySearchQuery = '';
  String _categoryStatusFilter = 'All';
  String _categoryFuelFilter = 'All';
  String _categoryTransmissionFilter = 'All';
  int _categoryCurrentPage = 1;
  int _categoryPageSize = 10;

  // Filters & Pagination for Documents
  final TextEditingController _docSearchController = TextEditingController();
  String _docSearchQuery = '';
  String _docStatusFilter = 'All';
  String _docTypeFilter = 'All';
  String _selectedVehicleFilter = 'All';
  int _docCurrentPage = 1;
  int _docPageSize = 10;
  dynamic _selectedDocument;

  // Filters & Pagination for GPS Devices
  final TextEditingController _gpsSearchController = TextEditingController();
  String _gpsSearchQuery = '';
  String _gpsStatusFilter = 'All';
  String _gpsProviderFilter = 'All';
  String _gpsVehicleFilter = 'All';
  int _gpsCurrentPage = 1;
  int _gpsPageSize = 10;
  dynamic _selectedGpsDevice;

  // ═══════════════════ Theme Tokens ═══════════════════
  static const _accent = Color(0xFF4F46E5); // indigo/purple accent
  static const _green = Color(0xFF22C55E);
  static const _blue = Color(0xFF3B82F6);
  static const _orange = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);
  static const _gray = Color(0xFF94A3B8);
  static const _bg = Color(0xFFF8FAFC);
  static const _cardBg = Colors.white;
  static const _border = Color(0xFFE2E8F0);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);

  @override
  final Set<int> _loadedTabs = {};

  @override
  void initState() {
    super.initState();
    // 4 Tabs
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _tabController.addListener(() {
      if (mounted) {
        _loadTabIfNeeded(_tabController.index, forceReload: true);
        if (kIsWeb && !_tabController.indexIsChanging) {
          try {
            html.window.history.replaceState(null, '', '/admin/fleet?tab=${_tabController.index}');
            html.window.dispatchEvent(html.CustomEvent('tab_changed'));
          } catch (_) {}
        }
        setState(() {});
      }
    });
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    _categorySearchController.addListener(() {
      setState(() => _categorySearchQuery = _categorySearchController.text);
    });
    _docSearchController.addListener(() {
      setState(() => _docSearchQuery = _docSearchController.text);
    });
    _gpsSearchController.addListener(() {
      setState(() => _gpsSearchQuery = _gpsSearchController.text);
    });
    _loadTabIfNeeded(widget.initialTab.clamp(0, 3), forceReload: true);
  }

  @override
  void didUpdateWidget(FleetManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _tabController.animateTo(widget.initialTab.clamp(0, 3));
      _loadTabIfNeeded(widget.initialTab.clamp(0, 3));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _categorySearchController.dispose();
    _docSearchController.dispose();
    _gpsSearchController.dispose();
    super.dispose();
  }

  // ═══════════════════ Data Fetching ═══════════════════
  Future<void> _loadAll({bool showLoading = false}) async {
    _loadedTabs.clear();
    await _loadTabIfNeeded(_tabController.index, forceReload: true);
    if (_tabController.index != 2) {
      await _loadTabIfNeeded(2, forceReload: true);
    }
  }

  Future<void> _loadTabIfNeeded(int tabIndex, {bool forceReload = false}) async {
    if (!mounted) return;
    if (!forceReload && _loadedTabs.contains(tabIndex)) return;

    setState(() => _isLoading = true);
    try {
      switch (tabIndex) {
        case 0: // Overview
        case 1: // Vehicles
          final res = await ApiService().get('/transport/vehicles?page_size=100', useCache: false);
          final raw = res['data'];
          if (raw is Map && raw['vehicles'] is List) {
            _vehicles = raw['vehicles'] as List;
          } else if (raw is List) {
            _vehicles = raw;
          } else {
            _vehicles = [];
          }
          try {
            final catRes = await ApiService().get('/transport/categories', useCache: false);
            final catRaw = catRes['data'];
            _categories = (catRaw is List) ? catRaw : [];
          } catch (_) {}
          try {
            final docRes = await ApiService().get('/transport/documents', useCache: false);
            final docRaw = docRes['data'];
            _documents = (docRaw is List) ? docRaw : [];
          } catch (_) {}
          try {
            final drvRes = await ApiService().get('/transport/drivers', useCache: false);
            final drvRaw = drvRes['data'];
            if (drvRaw is List) _drivers = drvRaw;
          } catch (_) {}
          if (_vehicles.isNotEmpty) {
            final match = _vehicles.firstWhere(
              (v) => v['id'] == _selectedVehicle?['id'],
              orElse: () => null,
            );
            _selectedVehicle = match ?? _vehicles.first;
          }
          break;
        case 2: // Categories
          final res = await ApiService().get('/transport/categories', useCache: false);
          final raw = res['data'];
          _categories = (raw is List) ? raw : [];
          try {
            final vehRes = await ApiService().get('/transport/vehicles?page_size=100', useCache: false);
            final vehRaw = vehRes['data'];
            if (vehRaw is Map && vehRaw['vehicles'] is List) {
              _vehicles = vehRaw['vehicles'] as List;
            } else if (vehRaw is List) {
              _vehicles = vehRaw;
            }
          } catch (_) {}
          if (_categories.isNotEmpty) {
            final match = _categories.firstWhere(
              (c) => c['id'] == _selectedCategory?['id'],
              orElse: () => null,
            );
            _selectedCategory = match ?? _categories.first;
          }
          break;
        case 3: // Documents
          final res = await ApiService().get('/transport/documents', useCache: false);
          final raw = res['data'];
          _documents = (raw is List) ? raw : [];
          if (_documents.isNotEmpty) {
            final match = _documents.firstWhere(
              (d) => d['id'] == _selectedDocument?['id'],
              orElse: () => null,
            );
            _selectedDocument = match ?? _documents.first;
          }
          break;
        case 4: // GPS Devices
          final res = await ApiService().get('/transport/gps-devices', useCache: false);
          final raw = res['data'];
          _gpsDevices = (raw is List) ? raw : [];
          if (_gpsDevices.isNotEmpty) {
            final match = _gpsDevices.firstWhere(
              (dev) => dev['id'] == _selectedGpsDevice?['id'],
              orElse: () => null,
            );
            _selectedGpsDevice = match ?? _gpsDevices.first;
          }
          break;
      }
      _loadedTabs.add(tabIndex);
    } catch (e) {
      debugPrint('Error loading fleet tab $tabIndex: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════ Dynamic Categories & Filtered Lists ═══════════════════
  List<String> get _dynamicCategoryOptions {
    final list = <String>[];
    for (var c in _categories) {
      if (c is Map) {
        final status = (c['status'] ?? 'Active').toString().toLowerCase();
        if (status != 'active') continue; // Only active categories visible in dropdowns
        final name = c['name']?.toString().trim();
        if (name != null && name.isNotEmpty && !list.contains(name)) {
          list.add(name);
        }
      }
    }
    if (list.isEmpty) {
      list.addAll(['AC Bus (52 Seater)', 'Non AC Bus (60 Seater)', 'Mini Bus (32 Seater)', 'Tempo Traveller (17 Seater)', 'Electric Bus (40 Seater)']);
    }
    return list;
  }

  int _getCategoryVehicleCount(dynamic c) {
    if (c == null) return 0;
    if (c is Map) {
      if (c['total_vehicles'] is int) return c['total_vehicles'] as int;
      if (c['vehicle_count'] is int) return c['vehicle_count'] as int;
      if (c['total_vehicles'] != null) {
        final parsed = int.tryParse(c['total_vehicles'].toString());
        if (parsed != null) return parsed;
      }
    }
    final catId = c['id']?.toString();
    final catCode = c['category_code']?.toString().toLowerCase().trim();
    final catName = c['name']?.toString().toLowerCase().trim();

    return _vehicles.where((v) {
      if (v == null || v is! Map) return false;
      final vCatId = v['category_id']?.toString();
      final vCatCode = (v['category_code'] ?? v['category'])?.toString().toLowerCase().trim();
      final vType = (v['vehicle_type'] ?? v['type'])?.toString().toLowerCase().trim();
      final vCatName = v['category_name']?.toString().toLowerCase().trim();

      if (catId != null && catId.isNotEmpty && vCatId == catId) return true;
      if (catCode != null && catCode.isNotEmpty && vCatCode == catCode) return true;
      if (vType != null && vType.isNotEmpty && (catName != null && vType == catName || catCode != null && vType == catCode)) return true;
      if (vCatName != null && vCatName.isNotEmpty && catName != null && vCatName == catName) return true;

      return false;
    }).length;
  }

  bool _vehicleMatchesStatus(dynamic v, String filter) {
    if (filter == 'All') return true;
    final liveStatus = (v['live_status'] ?? '').toString().toLowerCase().trim();
    final status = (v['status'] ?? '').toString().toLowerCase().trim();
    final f = filter.toLowerCase().trim();

    if (f == 'on_route' || f == 'on route') {
      return liveStatus == 'on_route' ||
          liveStatus == 'on route' ||
          liveStatus == 'in_transit';
    } else if (f == 'at_school' || f == 'at school') {
      return liveStatus == 'at_school' ||
          liveStatus == 'at school';
    } else if (f == 'returning') {
      return liveStatus == 'returning' ||
          liveStatus == 'on_return';
    } else if (f == 'delayed') {
      return liveStatus == 'delayed';
    } else if (f == 'offline') {
      return liveStatus == 'offline' ||
          liveStatus == 'inactive' ||
          status == 'inactive' ||
          status == 'offline';
    } else if (f == 'in maintenance') {
      return liveStatus == 'in_maintenance' ||
          liveStatus == 'maintenance' ||
          liveStatus == 'idle' ||
          status == 'in maintenance' ||
          status == 'maintenance' ||
          status == 'in_maintenance';
    }

    final normalizedF = f.replaceAll(' ', '_');
    return liveStatus == f ||
        liveStatus == normalizedF ||
        status == f ||
        status == normalizedF;
  }

  List<dynamic> get _filteredVehicles {
    return _vehicles.where((v) {
      final matchesSearch = _searchQuery.isEmpty ||
          (v['registration_no'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (v['bus_number'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (v['driver_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (v['route_name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (v['chassis_no'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (v['model'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _vehicleMatchesStatus(v, _statusFilter);

      final matchesCategory = _categoryFilter == 'All' ||
          v['category_id']?.toString() == _categoryFilter ||
          (v['vehicle_type'] ?? '').toString().toLowerCase().trim() == _categoryFilter.toLowerCase().trim() ||
          (v['category_name'] ?? '').toString().toLowerCase().trim() == _categoryFilter.toLowerCase().trim() ||
          (v['category_code'] ?? '').toString().toLowerCase().trim() == _categoryFilter.toLowerCase().trim() ||
          (v['category'] ?? '').toString().toLowerCase().trim() == _categoryFilter.toLowerCase().trim();

      final matchesFuel = _fuelFilter == 'All' ||
          (v['fuel_type'] ?? '').toString().toLowerCase() == _fuelFilter.toLowerCase();

      return matchesSearch && matchesStatus && matchesCategory && matchesFuel;
    }).toList();
  }


  List<dynamic> get _filteredCategories {
    return _categories.where((c) {
      final matchesSearch = _categorySearchQuery.isEmpty ||
          (c['name'] ?? '').toLowerCase().contains(_categorySearchQuery.toLowerCase()) ||
          (c['category_code'] ?? '').toLowerCase().contains(_categorySearchQuery.toLowerCase());

      final matchesStatus = _categoryStatusFilter == 'All' ||
          (c['status'] ?? '').toLowerCase() == _categoryStatusFilter.toLowerCase();

      final matchesFuel = _categoryFuelFilter == 'All' ||
          (c['fuel_type'] ?? '').toLowerCase() == _categoryFuelFilter.toLowerCase();

      final matchesTransmission = _categoryTransmissionFilter == 'All' ||
          (c['transmission'] ?? '').toLowerCase() == _categoryTransmissionFilter.toLowerCase();

      return matchesSearch && matchesStatus && matchesFuel && matchesTransmission;
    }).toList();
  }

  List<dynamic> get _filteredDocuments {
    return _documents.where((doc) {
      final matchesSearch = _docSearchQuery.isEmpty ||
          (doc['document_name'] ?? '').toLowerCase().contains(_docSearchQuery.toLowerCase()) ||
          (doc['document_type'] ?? '').toLowerCase().contains(_docSearchQuery.toLowerCase()) ||
          (doc['document_no'] ?? '').toLowerCase().contains(_docSearchQuery.toLowerCase()) ||
          (doc['remarks'] ?? '').toLowerCase().contains(_docSearchQuery.toLowerCase()) ||
          (doc['provider'] ?? '').toLowerCase().contains(_docSearchQuery.toLowerCase());

      final matchesStatus = _docStatusFilter == 'All' ||
          (doc['status'] ?? '').toLowerCase() == _docStatusFilter.toLowerCase();

      final matchesType = _docTypeFilter == 'All' ||
          (doc['document_type'] ?? '').toLowerCase() == _docTypeFilter.toLowerCase();

      final matchesVehicle = _selectedVehicleFilter == 'All' ||
          doc['vehicle_id']?.toString() == _selectedVehicleFilter ||
          doc['vehicle_no']?.toString() == _selectedVehicleFilter ||
          doc['registration_no']?.toString() == _selectedVehicleFilter ||
          doc['bus_routes']?['id']?.toString() == _selectedVehicleFilter ||
          doc['bus_routes']?['registration_no']?.toString() == _selectedVehicleFilter ||
          doc['bus_routes']?['bus_number']?.toString() == _selectedVehicleFilter ||
          _vehicles.any((veh) =>
              veh['id']?.toString() == _selectedVehicleFilter &&
              (doc['vehicle_id']?.toString() == veh['id']?.toString() ||
               doc['vehicle_id']?.toString() == veh['registration_no']?.toString() ||
               doc['bus_routes']?['registration_no'] == veh['registration_no'] ||
               doc['bus_routes']?['bus_number'] == veh['bus_number']));

      return matchesSearch && matchesStatus && matchesType && matchesVehicle;
    }).toList();
  }

  List<dynamic> get _filteredGpsDevices {
    return _gpsDevices.where((dev) {
      final matchesSearch = _gpsSearchQuery.isEmpty ||
          (dev['device_id'] ?? '').toLowerCase().contains(_gpsSearchQuery.toLowerCase()) ||
          (dev['imei_no'] ?? '').toLowerCase().contains(_gpsSearchQuery.toLowerCase()) ||
          (dev['sim_no'] ?? '').toLowerCase().contains(_gpsSearchQuery.toLowerCase()) ||
          (dev['model'] ?? '').toLowerCase().contains(_gpsSearchQuery.toLowerCase()) ||
          (dev['bus_routes']?['registration_no'] ?? '').toLowerCase().contains(_gpsSearchQuery.toLowerCase()) ||
          (dev['bus_routes']?['bus_number'] ?? '').toLowerCase().contains(_gpsSearchQuery.toLowerCase());

      final matchesStatus = _gpsStatusFilter == 'All' ||
          (_gpsStatusFilter == 'Online' && dev['status'] == 'Active') ||
          (_gpsStatusFilter == 'Offline' && dev['status'] == 'Offline') ||
          (_gpsStatusFilter == 'Issues' && dev['status'] == 'Faulty');

      final matchesProvider = _gpsProviderFilter == 'All' ||
          dev['operator'] == _gpsProviderFilter;

      final matchesVehicle = _gpsVehicleFilter == 'All' ||
          dev['bus_routes']?['vehicle_type'] == _gpsVehicleFilter;

      return matchesSearch && matchesStatus && matchesProvider && matchesVehicle;
    }).toList();
  }

  // ═══════════════════ BUILD ═══════════════════
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w >= 1100;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: _accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildTabBar(),
            const SizedBox(height: 20),
            _buildTabContent(isDesktop),
          ],
        ),
      ),
    );
  }

  // ─────── HEADER ───────
  Widget _buildHeader() {
    String title = 'Overview';
    String desc = 'Get a real-time overview of your entire fleet operations and performance.';
    Widget actions = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: _textSecondary),
          const SizedBox(width: 8),
          Text(
            'Today, 26 May 2024',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 16, color: _textSecondary),
        ],
      ),
    );

    if (_tabController.index == 1) {
      title = 'Fleet Management';
      desc = 'Manage and monitor all vehicles in your fleet.';
      actions = Row(
        children: [
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: const Text('Import Vehicles'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textPrimary,
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showAddVehicleDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Vehicle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      );
    } else if (_tabController.index == 2) {
      title = 'Vehicle Categories';
      desc = 'Create, update and manage vehicle categories for your fleet.';
      actions = ElevatedButton.icon(
        onPressed: () => _showAddCategoryDialog(),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Add Category'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
    } else if (_tabController.index == 3) {
      title = 'Vehicle Documents';
      desc = 'Manage all documents related to vehicles and track expiry dates.';
      actions = Row(
        children: [
          ElevatedButton.icon(
            onPressed: () => _showAddDocumentDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Document'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _cardBg,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedVehicleFilter,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary),
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('Select Vehicle: All')),
                  ..._vehicles.map((v) {
                    final reg = v['registration_no'] ?? v['bus_number'] ?? 'Vehicle';
                    return DropdownMenuItem(value: v['id'].toString(), child: Text(reg));
                  }),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedVehicleFilter = val!;
                    _docCurrentPage = 1;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.more_vert, color: _textSecondary),
            onPressed: () {},
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                    fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary),
              ),
              const SizedBox(height: 4),
              if (_tabController.index == 3) ...[
                Row(
                  children: [
                    Text('Fleet Management', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, size: 12, color: _textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Vehicle Documents', 
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500)
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(
                desc,
                style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
              ),
            ],
          ),
        ),
        actions,
      ],
    );
  }

  // ─────── TAB BAR ───────
  Widget _buildTabBar() {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: TabBar(
          controller: _tabController,
          onTap: (index) {
            if (_tabController.index != index) {
              _tabController.animateTo(index);
            }
            if (kIsWeb) {
              try {
                html.window.history.replaceState(null, '', '/admin/fleet?tab=$index');
                html.window.dispatchEvent(html.CustomEvent('tab_changed'));
              } catch (_) {}
            }
            setState(() {});
          },
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: EdgeInsets.zero,
          labelColor: const Color(0xFF4F46E5), // Indigo 600
          unselectedLabelColor: const Color(0xFF475569), // Slate 600
          indicatorColor: const Color(0xFF4F46E5),
          indicatorWeight: 2.5,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: [
            _buildTabItem(Icons.grid_view_outlined, 'Overview'),
            _buildTabItem(Icons.directions_bus_outlined, 'Vehicles'),
            _buildTabItem(Icons.directions_bus_outlined, 'Vehicle Categories'),
            _buildTabItem(Icons.description_outlined, 'Vehicle Documents'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(IconData icon, String text) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  // ─────── TAB CONTENT ───────
  Widget _buildTabContent(bool isDesktop) {
    switch (_tabController.index) {
      case 0:
        return _buildOverviewTabContent();
      case 1:
        return _buildVehiclesTab(isDesktop);
      case 2:
        return _buildCategoriesTab(isDesktop);
      case 3:
        return _buildDocumentsTab();
      default:
        return Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text(
              'This sub-module is fully integrated into the administrative console.',
              style: GoogleFonts.inter(color: _textSecondary),
            ),
          ),
        );
    }
  }

  // ═══════════════════ 1. OVERVIEW TAB ═══════════════════
  Widget _buildOverviewTabContent() {
    return Column(
      children: [
        _buildOverviewTopRowKPIs(),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            if (w < 1000) {
              return Column(
                children: [
                  _buildFleetUtilizationCard(),
                  const SizedBox(height: 20),
                  _buildVehicleStatusLineChartCard(),
                  const SizedBox(height: 20),
                  _buildAlertsNotificationsCard(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildFleetUtilizationCard()),
                const SizedBox(width: 20),
                Expanded(child: _buildVehicleStatusLineChartCard()),
                const SizedBox(width: 20),
                Expanded(child: _buildAlertsNotificationsCard()),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            if (w < 1000) {
              return Column(
                children: [
                  _buildFuelSummaryCard(),
                  const SizedBox(height: 20),
                  _buildTopVehiclesDistanceCard(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildFuelSummaryCard()),
                const SizedBox(width: 20),
                Expanded(child: _buildTopVehiclesDistanceCard()),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            if (w < 1000) {
              return Column(
                children: [
                  _buildMaintenanceOverviewCard(),
                  const SizedBox(height: 20),
                  _buildCostOverviewCard(),
                  const SizedBox(height: 20),
                  _buildQuickActionsGridCard(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildMaintenanceOverviewCard()),
                const SizedBox(width: 20),
                Expanded(child: _buildCostOverviewCard()),
                const SizedBox(width: 20),
                Expanded(child: _buildQuickActionsGridCard()),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildOverviewTopRowKPIs() {
    final active = _vehicles.where((v) => v['live_status'] == 'on_route').length;
    final maintenance = _vehicles.where((v) => v['live_status'] == 'idle').length;
    final inactive = _vehicles.where((v) => v['live_status'] == 'offline').length;

    return Row(
      children: [
        Expanded(child: _buildOverviewKpiCard('Total Vehicles', '${_vehicles.length}', Colors.indigo, Icons.directions_bus, 'All Vehicles')),
        const SizedBox(width: 12),
        Expanded(child: _buildOverviewKpiCard('Active Vehicles', '$active', Colors.green, Icons.check_circle_outline, _pct(active, _vehicles.length))),
        const SizedBox(width: 12),
        Expanded(child: _buildOverviewKpiCard('Under Maintenance', '$maintenance', Colors.orange, Icons.build_outlined, _pct(maintenance, _vehicles.length))),
        const SizedBox(width: 12),
        Expanded(child: _buildOverviewKpiCard('Out of Service', '$inactive', Colors.red, Icons.bus_alert_outlined, _pct(inactive, _vehicles.length))),
      ],
    );
  }

  Widget _buildOverviewKpiCard(String label, String value, Color color, IconData icon, String sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                'View all',
                style: GoogleFonts.inter(fontSize: 10, color: _blue, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11, color: _textSecondary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sub,
                  style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFleetUtilizationCard() {
    return Container(
      height: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fleet Utilization', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 120, height: 120,
                          child: CircularProgressIndicator(
                            value: 0.75,
                            strokeWidth: 16,
                            backgroundColor: _red.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(_green),
                          ),
                        ),
                        Text('75%', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendRow('In Use', '42 (75%)', _green),
                    const SizedBox(height: 8),
                    _legendRow('Idle', '8 (14.29%)', _orange),
                    const SizedBox(height: 8),
                    _legendRow('Maintenance', '4 (7.14%)', _accent),
                    const SizedBox(height: 8),
                    _legendRow('Out of Service', '2 (3.57%)', _red),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
            Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
          ],
        ),
      ],
    );
  }

  Widget _buildVehicleStatusLineChartCard() {
    return Container(
      height: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Vehicles Status', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
                child: Text('Last 7 Days', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: CustomPaint(
              painter: _LineChartPainter(),
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsNotificationsCard() {
    return Container(
      height: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alerts & Notifications', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 12),
          _alertItem('3 vehicles insurance expired', 'Renewal required', '30 mins ago', _red, Icons.warning_amber),
          _alertItem('2 vehicles fitness certificate expired', 'Update fitness certificate', '1 hour ago', _orange, Icons.description),
          _alertItem('4 vehicles are due for maintenance', 'Check maintenance schedule', '2 hours ago', _blue, Icons.build),
          _alertItem('1 GPS device offline', 'Device not reporting', '3 hours ago', _gray, Icons.wifi_off),
          const Spacer(),
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text('View all alerts', style: GoogleFonts.inter(fontSize: 12, color: _blue, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertItem(String title, String sub, String time, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary), overflow: TextOverflow.ellipsis),
                Text(sub, style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
              ],
            ),
          ),
          Text(time, style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildFuelSummaryCard() {
    return Container(
      height: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Fuel Summary', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
              Text('This Month', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 120, height: 120,
                          child: CircularProgressIndicator(
                            value: 0.81,
                            strokeWidth: 16,
                            backgroundColor: _blue.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(_green),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('3,240 L', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('Total Fuel', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendRow('Diesel', '2,650 L (81.79%)', _green),
                    const SizedBox(height: 8),
                    _legendRow('Petrol', '450 L (13.89%)', _orange),
                    const SizedBox(height: 8),
                    _legendRow('CNG', '140 L (4.32%)', _blue),
                  ],
                ),
              ],
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text('View fuel report', style: GoogleFonts.inter(fontSize: 12, color: _blue, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsSummaryCard() {
    return Container(
      height: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Trips Summary', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
              Text('Today', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _tripGridItem('Total Trips', '128', _blue, Icons.map),
                _tripGridItem('Completed Trips', '112', _green, Icons.check_circle),
                _tripGridItem('Ongoing Trips', '12', _orange, Icons.trending_up),
                _tripGridItem('Cancelled Trips', '4', _red, Icons.cancel),
              ],
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text('View trips & schedule', style: GoogleFonts.inter(fontSize: 12, color: _blue, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripGridItem(String label, String val, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(val, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
                Text(label, style: GoogleFonts.inter(fontSize: 9, color: _textSecondary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopVehiclesDistanceCard() {
    return Container(
      height: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Top Vehicles by Distance', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
              Text('This Month', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          _topVehicleRow('1.', 'UP16 ET 1234', '2,350 km', 0.9),
          _topVehicleRow('2.', 'UP16 ET 5678', '2,120 km', 0.8),
          _topVehicleRow('3.', 'UP16 ET 9101', '1,980 km', 0.7),
          _topVehicleRow('4.', 'UP16 ET 1122', '1,750 km', 0.6),
          _topVehicleRow('5.', 'UP16 ET 3344', '1,420 km', 0.5),
          const Spacer(),
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text('View full report', style: GoogleFonts.inter(fontSize: 12, color: _blue, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topVehicleRow(String index, String reg, String val, double pct) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Text(index, style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(reg, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
                    Text(val, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _textPrimary)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: _border,
                    valueColor: const AlwaysStoppedAnimation<Color>(_green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceOverviewCard() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Maintenance Overview', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
              Text('This Month', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _maintenanceStatItem('Total Maintenance', '12', _blue)),
              Expanded(child: _maintenanceStatItem('Completed', '8 (66.67%)', _green)),
              Expanded(child: _maintenanceStatItem('In Progress', '2 (16.67%)', _orange)),
              Expanded(child: _maintenanceStatItem('Pending', '2 (16.67%)', _red)),
            ],
          ),
          const Spacer(),
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text('View maintenance', style: GoogleFonts.inter(fontSize: 12, color: _blue, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _maintenanceStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
        ),
      ],
    );
  }

  Widget _buildCostOverviewCard() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cost Overview', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
              Text('This Month', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _costOverviewItem('Total Cost', '₹ 2,48,560', _accent, '100%'),
              _costOverviewItem('Fuel Cost', '₹ 1,62,450', _green, '65.29%'),
              _costOverviewItem('Maintenance Cost', '₹ 54,120', _blue, '21.76%'),
              _costOverviewItem('Other Cost', '₹ 32,000', _orange, '12.95%'),
            ],
          ),
          const Spacer(),
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text('View detailed report', style: GoogleFonts.inter(fontSize: 12, color: _blue, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _costOverviewItem(String label, String val, Color color, String pct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
        const SizedBox(height: 2),
        Text(val, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
        const SizedBox(height: 2),
        Text(pct, style: GoogleFonts.inter(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildQuickActionsGridCard() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 12),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.2,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _quickActionMiniItem('Add Vehicle', Icons.add_circle_outline, _accent, () => _showAddVehicleDialog()),
                    _quickActionMiniItem('Add Category', Icons.category_outlined, _blue, () => _showAddCategoryDialog()),
                    _quickActionMiniItem('Add Document', Icons.note_add_outlined, Colors.teal, () => _showAddDocumentDialog()),
                    _quickActionMiniItem('Add Service', Icons.build_outlined, _orange, () => _showAddServiceRecordDialog(_selectedVehicle)),
                    _quickActionMiniItem('Import Vehicles', Icons.file_upload_outlined, Colors.indigo, () {}),
                    _quickActionMiniItem('View Reports', Icons.analytics_outlined, _accent, () {}),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionMiniItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 13, color: color),
      label: Flexible(
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: _textPrimary, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  // ═══════════════════ 2. VEHICLES TAB ═══════════════════
  Widget _buildVehiclesTab(bool isDesktop) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildVehiclesTopKPIRow(),
              const SizedBox(height: 20),
              _buildVehiclesFilterBar(),
              const SizedBox(height: 20),
              _buildVehiclesTable(),
            ],
          ),
        ),
        if (isDesktop && _selectedVehicle != null) ...[
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: _buildDetailsPane(),
          ),
        ],
      ],
    );
  }

  Widget _buildVehiclesTopKPIRow() {
    final totalVehicles = _vehicles.length;
    final active = _vehicles.where((v) => _vehicleMatchesStatus(v, 'On Route') || _vehicleMatchesStatus(v, 'Arrived')).length;
    final maintenance = _vehicles.where((v) => _vehicleMatchesStatus(v, 'In Maintenance')).length;
    final inactive = _vehicles.where((v) => _vehicleMatchesStatus(v, 'Offline')).length;
    final totalSeats = _vehicles.fold<int>(0, (sum, v) => sum + (v['total_capacity'] as int? ?? 52));

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        if (maxW >= 950) {
          return Row(
            children: [
              Expanded(child: _buildKpiCardMini('Total Vehicles', '$totalVehicles', Icons.directions_bus_rounded, const Color(0xFF4F46E5), '100% Fleet')),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCardMini('Active Vehicles', '$active', Icons.directions_bus_filled_rounded, const Color(0xFF10B981), _pct(active, totalVehicles))),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCardMini('In Maintenance', maintenance.toString().padLeft(2, '0'), Icons.build_circle_rounded, const Color(0xFFF59E0B), _pct(maintenance, totalVehicles))),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCardMini('Inactive Vehicles', inactive.toString().padLeft(2, '0'), Icons.bus_alert_rounded, const Color(0xFF64748B), _pct(inactive, totalVehicles))),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCardMini('Avg Utilization', '78.45%', Icons.speed_rounded, const Color(0xFF10B981), 'This Month')),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCardMini('Total Capacity', NumberFormat('#,###').format(totalSeats), Icons.airline_seat_recline_normal_rounded, const Color(0xFF8B5CF6), 'Seats Total')),
            ],
          );
        } else {
          final double cardW = (maxW - 24) / 3;
          final double finalW = cardW > 160 ? cardW : 160;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(width: finalW, child: _buildKpiCardMini('Total Vehicles', '$totalVehicles', Icons.directions_bus_rounded, const Color(0xFF4F46E5), '100% Fleet')),
              SizedBox(width: finalW, child: _buildKpiCardMini('Active Vehicles', '$active', Icons.directions_bus_filled_rounded, const Color(0xFF10B981), _pct(active, totalVehicles))),
              SizedBox(width: finalW, child: _buildKpiCardMini('In Maintenance', maintenance.toString().padLeft(2, '0'), Icons.build_circle_rounded, const Color(0xFFF59E0B), _pct(maintenance, totalVehicles))),
              SizedBox(width: finalW, child: _buildKpiCardMini('Inactive Vehicles', inactive.toString().padLeft(2, '0'), Icons.bus_alert_rounded, const Color(0xFF64748B), _pct(inactive, totalVehicles))),
              SizedBox(width: finalW, child: _buildKpiCardMini('Avg Utilization', '78.45%', Icons.speed_rounded, const Color(0xFF10B981), 'This Month')),
              SizedBox(width: finalW, child: _buildKpiCardMini('Total Capacity', NumberFormat('#,###').format(totalSeats), Icons.airline_seat_recline_normal_rounded, const Color(0xFF8B5CF6), 'Seats Total')),
            ],
          );
        }
      },
    );
  }

  Widget _buildKpiCardMini(String title, String value, IconData icon, Color color, String badgeText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclesFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;
          final searchWidget = SizedBox(
            height: 38,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search bus number, registration no., driver...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          );

          final refreshButton = IconButton(
            onPressed: () => _loadAll(showLoading: true),
            icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF64748B)),
            tooltip: 'Refresh Vehicles Data',
          );

          final dropdowns = [
            _buildDropdown('All Status', _statusFilter, ['All', 'On Route', 'Arrived', 'Returning', 'Delayed', 'Offline', 'In Maintenance'], (val) {
              setState(() => _statusFilter = val ?? 'All');
            }, width: 140),
            _buildDropdown('All Categories', _categoryFilter, ['All', ..._dynamicCategoryOptions], (val) {
              setState(() => _categoryFilter = val ?? 'All');
            }, width: 150),
            _buildDropdown('All Fuel Types', _fuelFilter, ['All', 'Diesel', 'Petrol', 'CNG', 'Electric'], (val) {
              setState(() => _fuelFilter = val ?? 'All');
            }, width: 140),
            SizedBox(
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _statusFilter = 'All';
                    _categoryFilter = 'All';
                    _fuelFilter = 'All';
                    _currentPage = 1;
                  });
                },
                icon: const Icon(Icons.filter_list_rounded, size: 15),
                label: const Text('Reset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEEF2FF),
                  foregroundColor: const Color(0xFF4F46E5),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            refreshButton,
          ];

          if (isWide) {
            return Row(
              children: [
                Expanded(child: searchWidget),
                const SizedBox(width: 10),
                ...dropdowns.expand((w) => [w, const SizedBox(width: 10)]).toList()..removeLast(),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchWidget,
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: dropdowns,
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildVehiclesTable() {
    final list = _filteredVehicles;
    final total = list.length;
    final start = (_currentPage - 1) * _pageSize;
    final paginated = list.skip(start).take(_pageSize).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1100),
              child: DataTable(
                horizontalMargin: 16,
                columnSpacing: 24,
                headingRowHeight: 46,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 64,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('Bus Number')),
                DataColumn(label: Text('Registration No.')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Fuel')),
                DataColumn(label: Text('Capacity')),
                DataColumn(label: Text('Live Status')),
                DataColumn(label: Text('Last Updated')),
                DataColumn(label: Text('Actions')),
              ],
              rows: paginated.map((v) {
                final isSel = _selectedVehicle?['id'] == v['id'];
                return DataRow(
                  selected: isSel,
                  onSelectChanged: (_) {
                    setState(() {
                      _selectedVehicle = v;
                    });
                    _fetchVehicleDetailData(v);
                  },
                  cells: [
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.directions_bus_filled_outlined, size: 14, color: _accent),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            v['bus_number'] ?? '—',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )),
                    DataCell(Text(v['registration_no'] ?? '—')),
                    DataCell(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v['vehicle_type'] ?? 'Bus', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                        Text('${v['total_capacity'] ?? 52} Seats', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                      ],
                    )),
                    DataCell(_buildStatusBadge(v['live_status'] ?? 'offline')),
                    DataCell(_buildFuelIndicator(v['fuel_level_pct'])),
                    DataCell(Text('${v['total_capacity'] ?? 52}')),
                    DataCell(_buildSpeedBadge(v['speed_kmh'])),
                    DataCell(Text(_formatRelativeTime(v['updated_at']))),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.pin_drop_outlined, size: 16), onPressed: () {}),
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _showEditVehicleDialog(v)),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 16),
                          tooltip: 'More actions',
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showEditVehicleDialog(v);
                            } else if (val == 'delete') {
                              _deleteVehicleDialog(v);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 16, color: _textPrimary),
                                  SizedBox(width: 8),
                                  Text('Edit Vehicle'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 16, color: _red),
                                  SizedBox(width: 8),
                                  Text('Delete Vehicle', style: TextStyle(color: _red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
          ),
          const Divider(height: 1),
          _buildPaginationBar(total),
        ],
      ),
    );
  }

  Widget _buildFuelIndicator(int? fuelPct) {
    if (fuelPct == null) return const Text('—', style: TextStyle(color: _textSecondary));
    Color c = _green;
    if (fuelPct < 20) {
      c = _red;
    } else if (fuelPct < 50) {
      c = _orange;
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.battery_3_bar, color: c, size: 14),
          const SizedBox(width: 4),
          Text('$fuelPct%', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary)),
        ],
      ),
    );
  }

  Widget _buildSpeedBadge(int? speed) {
    Widget badge;
    if (speed == null || speed == 0) {
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: _blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Text('0 km/h', style: GoogleFonts.inter(fontSize: 11, color: _blue, fontWeight: FontWeight.w600)),
      );
    } else {
      Color c = _green;
      if (speed > 50) c = _red;
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Text('$speed km/h', style: GoogleFonts.inter(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
      );
    }
    return FittedBox(fit: BoxFit.scaleDown, child: badge);
  }

  Widget _buildStatusBadge(String status) {
    Color c = _gray;
    String label = 'Offline';
    if (status == 'on_route') {
      c = _green;
      label = 'On Route';
    } else if (status == 'at_school') {
      c = _blue;
      label = 'Arrived';
    } else if (status == 'returning') {
      c = _orange;
      label = 'Returning';
    } else if (status == 'delayed') {
      c = _red;
      label = 'Delayed';
    } else if (status == 'idle') {
      c = _orange;
      label = 'In Maintenance';
    } else if (status == 'inactive') {
      c = _red;
      label = 'Inactive';
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: GoogleFonts.inter(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildLiveStatusBadge(String? liveStatus) {
    Color c = _gray;
    String txt = 'Offline';
    if (liveStatus == 'on_route') {
      c = _green;
      txt = 'On Route';
    } else if (liveStatus == 'at_school') {
      c = _blue;
      txt = 'Arrived';
    } else if (liveStatus == 'returning') {
      c = _orange;
      txt = 'Returning';
    } else if (liveStatus == 'delayed') {
      c = _red;
      txt = 'Delayed';
    } else if (liveStatus == 'idle') {
      c = _orange;
      txt = 'In Maintenance';
    }
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(txt, style: GoogleFonts.inter(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildPaginationBar(int total) {
    final maxPage = (total / _pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Text(
            'Showing ${min((_currentPage - 1) * _pageSize + 1, total)} to ${min(_currentPage * _pageSize, total)} of $total vehicles',
            style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          ),
          Text('$_currentPage / ${max(1, maxPage)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < maxPage ? () => setState(() => _currentPage++) : null,
          ),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _pageSize,
            items: [5, 10, 20, 50].map((s) => DropdownMenuItem(value: s, child: Text('$s / page'))).toList(),
            onChanged: (val) {
              setState(() {
                _pageSize = val ?? 10;
                _currentPage = 1;
              });
            },
          ),
        ],
      ),
    );
  }

  // ─────── VEHICLE DETAILS PANEL (RIGHT SIDE) ───────
  Widget _buildDetailsPane() {
    final v = _selectedVehicle!;
    final loc = v['latest_location'] ?? {};

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pane Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: _bg,
                    child: const Icon(Icons.directions_bus, color: _accent, size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(v['registration_no'] ?? '—', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                          const SizedBox(width: 8),
                          _buildLiveStatusBadge(v['live_status']),
                        ],
                      ),
                      Text('${v['vehicle_type'] ?? 'AC Bus'} • ${v['total_capacity'] ?? 52} Seats', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedVehicle = null)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Details Tabs
          _buildDetailsTabs(),
          const Divider(height: 1),
          // Tab View Content
          _buildDetailsTabContent(v, loc),
          const Divider(height: 1),
          // Actions footer
          _buildDetailsActionsFooter(v),
        ],
      ),
    );
  }

  Widget _buildDetailsTabs() {
    final tabs = ['Overview', 'Details', 'Documents', 'Maintenance'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final isSel = _selectedDetailTab == idx;
          return InkWell(
            onTap: () {
              setState(() => _selectedDetailTab = idx);
              if (idx == 3 && _selectedVehicle != null) {
                _fetchVehicleDetailData(_selectedVehicle);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isSel ? _accent : Colors.transparent, width: 2)),
              ),
              child: Text(tabs[idx], style: GoogleFonts.inter(fontSize: 13, fontWeight: isSel ? FontWeight.w600 : FontWeight.normal, color: isSel ? _accent : _textSecondary)),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDetailsTabContent(dynamic v, Map loc) {
    if (_selectedDetailTab == 0) {
      // OVERVIEW
      Map<String, dynamic>? findDoc(List<String> kws) {
        for (var kw in kws) {
          for (var doc in _documents) {
            final vId = doc['vehicle_id']?.toString();
            final matchesVeh = vId == v['id']?.toString() ||
                vId == v['registration_no']?.toString() ||
                (doc['bus_routes'] != null && (
                  doc['bus_routes']['id']?.toString() == v['id']?.toString() ||
                  doc['bus_routes']['registration_no'] == v['registration_no'] ||
                  doc['bus_routes']['bus_number'] == v['bus_number']
                ));
            if (!matchesVeh) continue;

            final name = (doc['document_name'] ?? doc['document_type'] ?? '').toString().toLowerCase();
            final type = (doc['document_type'] ?? '').toString().toLowerCase();
            if (name.contains(kw.toLowerCase()) || type.contains(kw.toLowerCase())) {
              return Map<String, dynamic>.from(doc);
            }
          }
        }
        return null;
      }

      Map<String, String> evalDocInfo(Map<String, dynamic>? doc) {
        if (doc == null) {
          return {'expiry': 'Not Present', 'status': 'Not Present', 'doc_no': 'Not Present'};
        }
        final rawExp = doc['expiry_date']?.toString();
        final formattedExp = _formatDate(rawExp);
        String status = (doc['status'] ?? 'Valid').toString();

        if (rawExp != null && rawExp.trim().isNotEmpty) {
          try {
            final dt = DateTime.parse(rawExp.trim());
            if (dt.isBefore(DateTime.now())) {
              status = 'Expired';
            }
          } catch (_) {}
        }

        final docNo = (doc['document_no'] ?? doc['policy_no'] ?? doc['puc_no'] ?? 'Not Present').toString();
        return {'expiry': formattedExp, 'status': status, 'doc_no': docNo};
      }

      final insDoc = findDoc(['insurance']);
      final fitDoc = findDoc(['fitness']);
      final polDoc = findDoc(['pollution', 'puc']);
      final permitDoc = findDoc(['permit']);
      final rcDoc = findDoc(['registration', 'rc']);

      final insInfo = evalDocInfo(insDoc);
      final fitInfo = evalDocInfo(fitDoc);
      final polInfo = evalDocInfo(polDoc);
      final permitInfo = evalDocInfo(permitDoc);
      final rcInfo = evalDocInfo(rcDoc);

      final chassisNo = rcDoc != null && (rcDoc['document_no'] ?? '').toString().isNotEmpty
          ? rcDoc['document_no'].toString()
          : (v['chassis_no'] ?? '—');

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailRow('Registration No.', v['registration_no'] ?? '—'),
            _buildDetailRow('Chassis No.', chassisNo),
            _buildDetailRow('Engine No.', v['engine_no'] ?? 'ENG12345678'),
            _buildDetailRow('Vehicle Category', v['vehicle_type'] ?? 'AC Bus'),
            _buildDetailRow('Fuel Type', v['fuel_type'] ?? 'Diesel'),
            _buildDetailRow('Model / Make', v['model'] ?? 'TATA Marcopolo'),
            _buildDetailRow('Manufacturing Year', '${v['year_of_mfg'] ?? 2021}'),
            _buildDetailRow('Color', v['color'] ?? 'Yellow'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Insurance Valid Till', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                Row(
                  children: [
                    Text(insInfo['expiry']!, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary)),
                    const SizedBox(width: 6),
                    _buildValidTag(insInfo['status']!),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Fitness Valid Till', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                Row(
                  children: [
                    Text(fitInfo['expiry']!, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary)),
                    const SizedBox(width: 6),
                    _buildValidTag(fitInfo['status']!),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pollution Valid Till', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                Row(
                  children: [
                    Text(polInfo['expiry']!, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary)),
                    const SizedBox(width: 6),
                    _buildValidTag(polInfo['status']!),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildDetailRow('PUC No.', polInfo['doc_no']!),
            _buildDetailRow('Permit No.', permitInfo['doc_no']!),
            _buildDetailRow('Capacity', '${v['total_capacity'] ?? 52} Seats'),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: [
                _buildTrackingMiniCard('Live Speed', '${v['speed_kmh'] ?? 32} km/h', Icons.speed, _green),
                _buildTrackingMiniCard('Current Location', v['next_stop'] ?? 'Sector 62, Noida', Icons.pin_drop, _green),
                _buildTrackingMiniCard('Next Stop', v['next_stop'] ?? 'Botanical Garden', Icons.directions_bus, _blue, sub: 'ETA: ${v['next_stop_eta'] ?? '10:32 AM'}'),
                _buildTrackingMiniCard('Students Onboard', '${v['students_on_board'] ?? 28} / ${v['total_capacity'] ?? 52}', Icons.people, Colors.purple),
              ],
            ),
          ],
        ),
      );
    } else if (_selectedDetailTab == 1) {
      // DETAILS (TECHNICAL SPECS)
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Technical & Vehicle Specs', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
            const SizedBox(height: 12),
            _buildDetailRow('Bus Number', v['bus_number'] ?? 'BUS-${v['id']}'),
            _buildDetailRow('Seating Capacity', '${v['total_capacity'] ?? 52} Seats'),
            _buildDetailRow('Luggage Capacity', v['luggage_capacity'] ?? '500 L'),
            _buildDetailRow('Fuel Tank Capacity', v['fuel_tank_capacity'] ?? '150 Liters'),
            _buildDetailRow('Transmission', v['transmission'] ?? 'Manual'),
            _buildDetailRow('Odometer Reading', '${v['odometer_km'] ?? 45280} km'),
            _buildDetailRow('Speed Governor', v['speed_governor'] ?? 'Fitted (Max 60 km/h)'),
            _buildDetailRow('CCTV Cameras', v['cctv_installed'] ?? '4 HD Cameras (Active)'),
            _buildDetailRow('Emergency SOS Button', v['panic_button'] ?? 'Installed & Working'),
            _buildDetailRow('First Aid Kit Expiry', v['first_aid_expiry'] ?? '12 Dec 2026'),
            _buildDetailRow('Fire Extinguisher Expiry', v['fire_extinguisher_expiry'] ?? '15 Jan 2027'),
            _buildDetailRow('Last Serviced Date', v['last_serviced_date'] ?? '10 May 2024'),
            _buildDetailRow('Ownership', v['ownership_type'] ?? 'School Owned'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: _accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All safety standards & RTO compliance regulations verified for student transport.',
                      style: GoogleFonts.inter(fontSize: 11, color: _accent, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (_selectedDetailTab == 2) {
      // DOCUMENTS
      final vehicleDocs = _documents.where((d) {
        final vId = d['vehicle_id']?.toString();
        final matchesVeh = vId == v['id']?.toString() ||
            vId == v['registration_no']?.toString() ||
            (d['vehicle_number'] != null && d['vehicle_number'].toString().toLowerCase() == (v['registration_no'] ?? '').toString().toLowerCase()) ||
            (d['vehicle_no'] != null && d['vehicle_no'].toString().toLowerCase() == (v['registration_no'] ?? '').toString().toLowerCase()) ||
            (d['bus_routes'] != null && (
              d['bus_routes']['id']?.toString() == v['id']?.toString() ||
              d['bus_routes']['registration_no'] == v['registration_no'] ||
              d['bus_routes']['bus_number'] == v['bus_number']
            ));
        return matchesVeh;
      }).toList();

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Vehicle Documents (${vehicleDocs.length})', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
                ElevatedButton.icon(
                  onPressed: () => _showAddDocumentDialog(v),
                  icon: const Icon(Icons.upload_file, size: 14),
                  label: const Text('Add Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (vehicleDocs.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
                child: Column(
                  children: [
                    const Icon(Icons.folder_open, size: 36, color: _textSecondary),
                    const SizedBox(height: 8),
                    Text('No documents uploaded for this vehicle yet.', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddDocumentDialog(v),
                      icon: const Icon(Icons.upload_file, size: 14),
                      label: const Text('Upload Document'),
                      style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              )
            else
              ...vehicleDocs.map((doc) => _buildVehicleDocItem(
                doc['document_name'] ?? doc['document_type'] ?? 'Document',
                (doc['document_no'] ?? doc['policy_no'] ?? '—').toString(),
                (doc['status'] ?? 'Valid').toString(),
                _formatDate(doc['expiry_date']),
                Icons.insert_drive_file,
              )),
          ],
        ),
      );
    } else if (_selectedDetailTab == 3) {
      // MAINTENANCE
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Maintenance History', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
                ElevatedButton.icon(
                  onPressed: () => _showAddServiceRecordDialog(v),
                  icon: const Icon(Icons.build_outlined, size: 14),
                  label: const Text('Add Service'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loadingVehicleDetails)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_vehicleMaintenance.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
                child: Column(
                  children: [
                    const Icon(Icons.build_circle_outlined, size: 36, color: _textSecondary),
                    const SizedBox(height: 8),
                    Text('No maintenance records logged for this vehicle yet.', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddServiceRecordDialog(v),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Add Service Record'),
                      style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              )
            else
              ..._vehicleMaintenance.map((m) {
                final statusStr = (m['status'] ?? 'Completed').toString();
                Color sColor = _green;
                if (statusStr.toLowerCase().contains('progress')) {
                  sColor = _blue;
                } else if (statusStr.toLowerCase().contains('scheduled')) {
                  sColor = _orange;
                }

                return _buildMaintenanceHistoryCard(
                  item: m,
                  vehicle: v,
                  type: (m['service_type'] ?? 'Maintenance Service').toString(),
                  date: _formatDate(m['service_date']),
                  garage: (m['vendor_workshop'] ?? 'Authorized Workshop').toString(),
                  cost: '₹${m['cost'] ?? 0}',
                  odometer: '${m['odometer_km'] ?? 0} km',
                  status: statusStr,
                  statusColor: sColor,
                );
              }),
          ],
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildVehicleDocItem(String name, String docNo, String status, String expiry, IconData icon) {
    final isValid = status.toLowerCase() == 'valid';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: _accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
                Text('Doc No: $docNo • Expiry: $expiry', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isValid ? _green.withValues(alpha: 0.1) : _orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(fontSize: 10, color: isValid ? _green : _orange, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceHistoryCard({
    required dynamic item,
    required dynamic vehicle,
    required String type,
    required String date,
    required String garage,
    required String cost,
    required String odometer,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(type, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
              ),
              Text(cost, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _accent)),
              if (item != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 16),
                  tooltip: 'Actions',
                  onSelected: (val) async {
                    if (val == 'edit') {
                      _showEditServiceRecordDialog(item, vehicle);
                    } else if (val == 'delete') {
                      _deleteServiceRecordDialog(item, vehicle);
                    } else if (val == 'Completed' || val == 'In Progress' || val == 'Scheduled') {
                      _updateMaintenanceStatus(item, vehicle, val);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Text('Change Status:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textSecondary)),
                    ),
                    const PopupMenuItem(value: 'Completed', child: Text('Mark as Completed')),
                    const PopupMenuItem(value: 'In Progress', child: Text('Mark as In Progress')),
                    const PopupMenuItem(value: 'Scheduled', child: Text('Mark as Scheduled')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16, color: _textPrimary),
                          SizedBox(width: 8),
                          Text('Edit Record'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: _red),
                          SizedBox(width: 8),
                          Text('Delete Record', style: TextStyle(color: _red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('$garage • $date', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Odometer: $odometer', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
              InkWell(
                onTap: item != null ? () => _showStatusPickerModal(item, vehicle) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(status, style: GoogleFonts.inter(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                      if (item != null) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 14, color: statusColor),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateMaintenanceStatus(dynamic item, dynamic vehicle, String newStatus) async {
    try {
      if (item is Map) {
        setState(() {
          item['status'] = newStatus;
        });
      }
      await ApiService().put('/transport/maintenance/${item['id']}', {
        'status': newStatus,
      });
      await _fetchVehicleDetailData(vehicle, silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  void _showStatusPickerModal(dynamic item, dynamic vehicle) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change Maintenance Status', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: _green),
                title: const Text('Completed'),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateMaintenanceStatus(item, vehicle, 'Completed');
                },
              ),
              ListTile(
                leading: const Icon(Icons.autorenew, color: _blue),
                title: const Text('In Progress'),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateMaintenanceStatus(item, vehicle, 'In Progress');
                },
              ),
              ListTile(
                leading: const Icon(Icons.schedule, color: _orange),
                title: const Text('Scheduled'),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateMaintenanceStatus(item, vehicle, 'Scheduled');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditServiceRecordDialog(dynamic item, dynamic vehicle) {
    final formKey = GlobalKey<FormState>();
    final typeCtrl = TextEditingController(text: item['service_type'] ?? '');
    final vendorCtrl = TextEditingController(text: item['vendor_workshop'] ?? '');
    final costCtrl = TextEditingController(text: '${item['cost'] ?? 0}');
    final odoCtrl = TextEditingController(text: '${item['odometer_km'] ?? 0}');
    String status = item['status'] ?? 'Completed';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Service Record', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: typeCtrl,
                        decoration: const InputDecoration(labelText: 'Service Type / Work Done'),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: vendorCtrl,
                        decoration: const InputDecoration(labelText: 'Workshop / Garage Vendor'),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: costCtrl,
                              decoration: const InputDecoration(labelText: 'Cost (₹)'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: odoCtrl,
                              decoration: const InputDecoration(labelText: 'Odometer (km)'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Service Status'),
                        items: ['Completed', 'In Progress', 'Scheduled'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) => setDialogState(() => status = val!),
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
                      try {
                        if (item is Map) {
                          setState(() {
                            item['service_type'] = typeCtrl.text.trim();
                            item['vendor_workshop'] = vendorCtrl.text.trim();
                            item['cost'] = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                            item['odometer_km'] = int.tryParse(odoCtrl.text.trim()) ?? 0;
                            item['status'] = status;
                          });
                        }
                        await ApiService().put('/transport/maintenance/${item['id']}', {
                          'service_type': typeCtrl.text.trim(),
                          'vendor_workshop': vendorCtrl.text.trim(),
                          'cost': double.tryParse(costCtrl.text.trim()) ?? 0.0,
                          'odometer_km': int.tryParse(odoCtrl.text.trim()) ?? 0,
                          'status': status,
                        });
                        await _fetchVehicleDetailData(vehicle, silent: true);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Service record updated successfully.')),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error updating: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteServiceRecordDialog(dynamic item, dynamic vehicle) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Delete Maintenance Log', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete service record "${item['service_type']}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (item is Map) {
                    setState(() {
                      _vehicleMaintenance.removeWhere((m) => m['id'] == item['id']);
                    });
                  }
                  await ApiService().delete('/transport/maintenance/${item['id']}');
                  await _fetchVehicleDetailData(vehicle, silent: true);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Service record deleted successfully.')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildValidTag(String status) {
    final sLower = status.toLowerCase();
    final isValid = sLower == 'valid' || sLower.contains('active');
    final isNotPresent = sLower.contains('not present') || sLower.contains('missing') || sLower == '—';

    final Color badgeColor = isValid
        ? _green
        : (isNotPresent ? Colors.orange : _red);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(fontSize: 9, color: badgeColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDriverRow(String name, String phone) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Assigned Driver', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
        Row(
          children: [
            const CircleAvatar(radius: 10, backgroundColor: _border, child: Icon(Icons.person, size: 10)),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
                Text(phone, style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.call, size: 14, color: _accent),
              onPressed: () {},
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRouteRow(String routeName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Assigned Route', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
        Row(
          children: [
            Text(routeName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 14, color: _accent),
              onPressed: () {},
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrackingMiniCard(String label, String value, IconData icon, Color color, {String? sub}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary), overflow: TextOverflow.ellipsis),
                Text(label, style: GoogleFonts.inter(fontSize: 9, color: _textSecondary), overflow: TextOverflow.ellipsis),
                if (sub != null)
                  Text(sub, style: GoogleFonts.inter(fontSize: 9, color: color, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
          Text(val, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary)),
        ],
      ),
    );
  }

  Widget _buildDetailsActionsFooter(dynamic v) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _detailsFooterBtn(Icons.map_outlined, 'View on Map', () => _showLiveTrackingMapDialog(v)),
          _detailsFooterBtn(Icons.edit_outlined, 'Edit Vehicle', () => _showEditVehicleDialog(v)),
          _detailsFooterBtn(Icons.person_outline, 'Assign Driver', () => _showAssignDriverDialog(v)),
          _detailsFooterBtn(Icons.route_outlined, 'Assign Route', () => _showAssignRouteDialog(v)),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (val) {
              if (val == 'maintenance') {
                _showAddServiceRecordDialog(v);
              } else if (val == 'document') {
                _showAddDocumentDialog();
              } else if (val == 'delete') {
                _deleteVehicleDialog(v);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'maintenance', child: Row(children: [Icon(Icons.build_outlined, size: 16), SizedBox(width: 8), Text('Schedule Maintenance')])),
              const PopupMenuItem(value: 'document', child: Row(children: [Icon(Icons.upload_file_outlined, size: 16), SizedBox(width: 8), Text('Upload Document')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: _red), SizedBox(width: 8), Text('Delete Vehicle', style: TextStyle(color: _red))])),
            ],
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  const Icon(Icons.more_horiz, size: 18, color: _accent),
                  const SizedBox(height: 4),
                  Text('More', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAssignDriverDialog(dynamic v) {
    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedDriverName = v['driver_name'];
        String? selectedDriverPhone = v['driver_phone'];
        return AlertDialog(
          title: Text('Assign Driver to ${v['registration_no']}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: FutureBuilder<Map<String, dynamic>>(
            future: ApiService().get('/transport/drivers?page_size=100'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
              }
              final raw = snapshot.data?['data'];
              final driversList = (raw is List) ? raw : [];
              if (driversList.isEmpty) {
                return const Text('No drivers available. Please add drivers in Driver Management first.');
              }
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<dynamic>(
                        decoration: const InputDecoration(labelText: 'Select Driver'),
                        value: driversList.firstWhere(
                          (d) => (d['full_name'] ?? d['name']) == selectedDriverName,
                          orElse: () => driversList.first,
                        ),
                        items: driversList.map((d) {
                          final name = d['full_name'] ?? d['name'] ?? 'Driver';
                          final phone = d['phone_number'] ?? d['phone'] ?? '';
                          return DropdownMenuItem(value: d, child: Text('$name ($phone)'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedDriverName = val['full_name'] ?? val['name'];
                              selectedDriverPhone = val['phone_number'] ?? val['phone'];
                            });
                          }
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService().put('/transport/vehicles/${v['id']}', {
                    'driver_name': selectedDriverName,
                    'driver_phone': selectedDriverPhone,
                  });
                  _loadAll();
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Driver $selectedDriverName assigned to vehicle ${v['registration_no']}')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
              child: const Text('Assign Driver'),
            ),
          ],
        );
      },
    );
  }

  void _showAssignRouteDialog(dynamic v) {
    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedRouteName = v['route_name'];
        return AlertDialog(
          title: Text('Assign Route to ${v['registration_no']}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: FutureBuilder<Map<String, dynamic>>(
            future: ApiService().get('/transport/routes?page_size=100'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
              }
              final raw = snapshot.data?['data'];
              final routesList = (raw is List) ? raw : [];
              if (routesList.isEmpty) {
                return const Text('No routes available. Please create routes in Route Management first.');
              }
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<dynamic>(
                        decoration: const InputDecoration(labelText: 'Select Route'),
                        value: routesList.firstWhere(
                          (r) => (r['name'] ?? r['route_name']) == selectedRouteName,
                          orElse: () => routesList.first,
                        ),
                        items: routesList.map((r) {
                          final name = r['name'] ?? r['route_name'] ?? 'Route';
                          final code = r['route_code'] ?? '';
                          return DropdownMenuItem(value: r, child: Text('$name ($code)'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedRouteName = val['name'] ?? val['route_name'];
                            });
                          }
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService().put('/transport/vehicles/${v['id']}', {
                    'route_name': selectedRouteName,
                  });
                  _loadAll();
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Route $selectedRouteName assigned to vehicle ${v['registration_no']}')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
              child: const Text('Assign Route'),
            ),
          ],
        );
      },
    );
  }

  void _showAddServiceRecordDialog(dynamic v) {
    final formKey = GlobalKey<FormState>();
    final typeCtrl = TextEditingController(text: 'Routine Oil & Filter Change');
    final vendorCtrl = TextEditingController(text: 'Tata Motors Authorized Service Center');
    final costCtrl = TextEditingController(text: '12400');
    final odoCtrl = TextEditingController(text: '45000');
    String status = 'Completed';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add Service Record – ${v['registration_no']}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: typeCtrl,
                        decoration: const InputDecoration(labelText: 'Service Type / Work Done'),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: vendorCtrl,
                        decoration: const InputDecoration(labelText: 'Workshop / Garage Vendor'),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: costCtrl,
                              decoration: const InputDecoration(labelText: 'Cost (₹)'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: odoCtrl,
                              decoration: const InputDecoration(labelText: 'Odometer (km)'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Service Status'),
                        items: ['Completed', 'In Progress', 'Scheduled'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) => setDialogState(() => status = val!),
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
                      try {
                        final postRes = await ApiService().post('/transport/maintenance', {
                          'vehicle_id': v['id'],
                          'service_type': typeCtrl.text.trim(),
                          'vendor_workshop': vendorCtrl.text.trim(),
                          'cost': double.tryParse(costCtrl.text.trim()) ?? 0.0,
                          'odometer_km': int.tryParse(odoCtrl.text.trim()) ?? 0,
                          'status': status,
                        });
                        if (postRes['data'] != null && postRes['data'] is Map) {
                          setState(() {
                            _vehicleMaintenance.insert(0, postRes['data']);
                          });
                        }
                        await _fetchVehicleDetailData(v, silent: true);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Service record logged successfully.')),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error saving: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: const Text('Save Record'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Widget _detailsFooterBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Icon(icon, size: 18, color: _accent),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════ 3. VEHICLE CATEGORIES TAB ═══════════════════
  Widget _buildCategoriesTab(bool isDesktop) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildCategoriesKPIs(),
              const SizedBox(height: 20),
              _buildCategoriesFilterBar(),
              const SizedBox(height: 20),
              _buildCategoriesTable(),
            ],
          ),
        ),
        if (isDesktop && _selectedCategory != null) ...[
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: _buildCategoryDetailsPane(),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoriesKPIs() {
    final totalCats = _categories.length;
    final active = _categories.where((c) => c['status'] == 'Active').length;
    final inactive = _categories.where((c) => c['status'] == 'Inactive').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        if (maxW >= 950) {
          return Row(
            children: [
              Expanded(child: _buildKpiCardMini('Total Categories', '$totalCats', Icons.category_rounded, const Color(0xFF4F46E5), 'All Categories')),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCardMini('Active Categories', '$active', Icons.check_circle_rounded, const Color(0xFF10B981), _pct(active, totalCats))),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiCardMini('Inactive Categories', '$inactive', Icons.pause_circle_filled_rounded, const Color(0xFFEF4444), _pct(inactive, totalCats))),
            ],
          );
        } else {
          final double cardW = (maxW - 24) / 3;
          final double finalW = cardW > 160 ? cardW : 160;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(width: finalW, child: _buildKpiCardMini('Total Categories', '$totalCats', Icons.category_rounded, const Color(0xFF4F46E5), 'All Categories')),
              SizedBox(width: finalW, child: _buildKpiCardMini('Active Categories', '$active', Icons.check_circle_rounded, const Color(0xFF10B981), _pct(active, totalCats))),
              SizedBox(width: finalW, child: _buildKpiCardMini('Inactive Categories', '$inactive', Icons.pause_circle_filled_rounded, const Color(0xFFEF4444), _pct(inactive, totalCats))),
            ],
          );
        }
      },
    );
  }

  Widget _buildCategoriesFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;
          final searchWidget = SizedBox(
            height: 38,
            child: TextField(
              controller: _categorySearchController,
              decoration: InputDecoration(
                hintText: 'Search categories by name or type...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          );

          final dropdowns = [
            _buildDropdown('All Status', _categoryStatusFilter, ['All', 'Active', 'Inactive'], (val) {
              setState(() => _categoryStatusFilter = val ?? 'All');
            }, width: 130),
            _buildDropdown('All Fuel Types', _categoryFuelFilter, ['All', 'Diesel', 'Petrol', 'CNG', 'Electric'], (val) {
              setState(() => _categoryFuelFilter = val ?? 'All');
            }, width: 140),
            _buildDropdown('All Transmissions', _categoryTransmissionFilter, ['All', 'Manual', 'Automatic'], (val) {
              setState(() => _categoryTransmissionFilter = val ?? 'All');
            }, width: 150),
            SizedBox(
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _categorySearchController.clear();
                    _categoryStatusFilter = 'All';
                    _categoryFuelFilter = 'All';
                    _categoryTransmissionFilter = 'All';
                    _categoryCurrentPage = 1;
                  });
                },
                icon: const Icon(Icons.filter_list_rounded, size: 15),
                label: const Text('Reset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEEF2FF),
                  foregroundColor: const Color(0xFF4F46E5),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF475569)),
              onPressed: _loadAll,
            ),
          ];

          if (isWide) {
            return Row(
              children: [
                Expanded(child: searchWidget),
                const SizedBox(width: 10),
                ...dropdowns.expand((w) => [w, const SizedBox(width: 10)]).toList()..removeLast(),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchWidget,
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: dropdowns,
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildCategoriesTable() {
    final list = _filteredCategories;
    final total = list.length;
    final start = (_categoryCurrentPage - 1) * _categoryPageSize;
    final paginated = list.skip(start).take(_categoryPageSize).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1100),
              child: DataTable(
                horizontalMargin: 16,
                columnSpacing: 24,
                headingRowHeight: 46,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 64,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('Category Name')),
                DataColumn(label: Text('Category Code')),
                DataColumn(label: Text('Vehicle Type')),
                DataColumn(label: Text('Fuel Type')),
                DataColumn(label: Text('Transmission')),
                DataColumn(label: Text('Seating Capacity')),
                DataColumn(label: Text('Luggage Capacity')),
                DataColumn(label: Text('Total Vehicles')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: paginated.map((c) {
                final isSel = _selectedCategory?['id'] == c['id'];
                final count = _getCategoryVehicleCount(c);
                return DataRow(
                  selected: isSel,
                  onSelectChanged: (_) {
                    setState(() {
                      _selectedCategory = c;
                    });
                  },
                  cells: [
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.category_outlined, size: 14, color: _accent),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['name'] ?? '—', style: GoogleFonts.inter(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                              if (c['description'] != null)
                                Text(c['description'], style: GoogleFonts.inter(fontSize: 10, color: _textSecondary), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    )),
                    DataCell(Text(c['category_code'] ?? '—')),
                    DataCell(Text(c['vehicle_type'] ?? 'Bus')),
                    DataCell(Text(c['fuel_type'] ?? 'Diesel')),
                    DataCell(Text(c['transmission'] ?? 'Manual')),
                    DataCell(Text('${c['capacity'] ?? 52}')),
                    DataCell(Text(c['luggage_capacity'] ?? '500 L')),
                    DataCell(Text('$count')),
                    DataCell(_buildCatStatusBadge(c['status'] ?? 'Active')),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _showEditCategoryDialog(c)),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 16),
                          tooltip: 'More actions',
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showEditCategoryDialog(c);
                            } else if (val == 'delete') {
                              _deleteCategoryDialog(c);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 16, color: _textPrimary),
                                  SizedBox(width: 8),
                                  Text('Edit Category'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 16, color: _red),
                                  SizedBox(width: 8),
                                  Text('Delete Category', style: TextStyle(color: _red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
          ),
          const Divider(height: 1),
          _buildCategoryPaginationBar(total),
        ],
      ),
    );
  }

  Widget _buildCatStatusBadge(String status) {
    Color c = status.toLowerCase() == 'active' ? _green : _red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: GoogleFonts.inter(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildCategoryPaginationBar(int total) {
    final maxPage = (total / _categoryPageSize).ceil();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Text(
            'Showing ${min((_categoryCurrentPage - 1) * _categoryPageSize + 1, total)} to ${min(_categoryCurrentPage * _categoryPageSize, total)} of $total categories',
            style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _categoryCurrentPage > 1 ? () => setState(() => _categoryCurrentPage--) : null,
          ),
          Text('$_categoryCurrentPage / ${max(1, maxPage)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _categoryCurrentPage < maxPage ? () => setState(() => _categoryCurrentPage++) : null,
          ),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _categoryPageSize,
            items: [5, 10, 20, 50].map((s) => DropdownMenuItem(value: s, child: Text('$s / page'))).toList(),
            onChanged: (val) {
              setState(() {
                _categoryPageSize = val ?? 10;
                _categoryCurrentPage = 1;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDetailsPane() {
    final c = _selectedCategory!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pane Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: _bg,
                    child: const Icon(Icons.category, color: _accent, size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(c['name'] ?? '—', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                          const SizedBox(width: 8),
                          _buildCatStatusBadge(c['status'] ?? 'Active'),
                        ],
                      ),
                      Text('Code: ${c['category_code'] ?? '—'}', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedCategory = null)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Category Details Tab Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Description', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
                const SizedBox(height: 6),
                Text(
                  c['description'] ?? 'No description provided.',
                  style: GoogleFonts.inter(fontSize: 12, color: _textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                _buildDetailRow('Vehicle Type', c['vehicle_type'] ?? 'Bus'),
                _buildDetailRow('Fuel Type', c['fuel_type'] ?? 'Diesel'),
                _buildDetailRow('Transmission', c['transmission'] ?? 'Manual'),
                _buildDetailRow('Seating Capacity', '${c['capacity'] ?? 52} Seats'),
                _buildDetailRow('Luggage Capacity', c['luggage_capacity'] ?? '500 L'),
                _buildDetailRow('Total Vehicles', '${_getCategoryVehicleCount(c)}'),
                _buildDetailRow('Status', c['status'] ?? 'Active'),
                _buildDetailRow('Created On', _formatDateTime(c['created_at'])),
                _buildDetailRow('Created By', c['created_by'] ?? 'Transport Manager'),
                _buildDetailRow('Last Updated', _formatDateTime(c['updated_at'])),
                _buildDetailRow('Updated By', c['updated_by'] ?? 'Transport Manager'),
              ],
            ),
          ),
          const Divider(height: 1),
          // Quick actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Actions', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showEditCategoryDialog(c),
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text('Edit Category'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteCategoryDialog(c),
                        icon: const Icon(Icons.delete_outline, size: 14),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _red,
                          side: const BorderSide(color: _red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
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

  String _parseIsoUtc(dynamic dtStr) {
    if (dtStr == null || dtStr.toString().isEmpty) return '';
    String s = dtStr.toString().trim();
    if (!s.endsWith('Z') && !s.contains('+') && !s.contains('-', 10)) {
      s = '${s}Z';
    }
    return s;
  }

  String _formatDateTime(dynamic dtStr) {
    if (dtStr == null || dtStr.toString().isEmpty) return '—';
    try {
      final s = _parseIsoUtc(dtStr);
      final dt = DateTime.parse(s).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      final year = dt.year;
      final hourInt = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final hour = hourInt.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$day $month $year $hour:$min $ampm';
    } catch (_) {
      return dtStr.toString();
    }
  }

  String _formatRelativeTime(dynamic dtStr) {
    if (dtStr == null || dtStr.toString().isEmpty) return '—';
    try {
      final s = _parseIsoUtc(dtStr);
      final dt = DateTime.parse(s).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.isNegative || diff.inSeconds < 45) return 'Just now';
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 30) return '${diff.inDays}d ago';
      final months = diff.inDays ~/ 30;
      if (months < 12) return '${months}mo ago';
      return '${diff.inDays ~/ 365}y ago';
    } catch (_) {
      return '—';
    }
  }

  // ═══════════════════ 4. VEHICLE DOCUMENTS TAB ═══════════════════
  // ═══════════════════ 4. VEHICLE DOCUMENTS TAB ═══════════════════
  Widget _buildDocumentsTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isDesktop = availableWidth >= 1100;
        
        // Stats calculation
        final totalDocs = _documents.length;
        final validDocs = _documents.where((d) => (d['status'] ?? '').toLowerCase() == 'valid').length;
        final expiringSoonDocs = _documents.where((d) => (d['status'] ?? '').toLowerCase() == 'expiring soon' || (d['status'] ?? '').toLowerCase() == 'expiring_soon').length;
        final expiredDocs = _documents.where((d) => (d['status'] ?? '').toLowerCase() == 'expired').length;
        
        final thisMonthDocs = _documents.where((d) {
          final dateStr = d['uploaded_on'] ?? d['created_at'];
          if (dateStr == null) return false;
          try {
            final date = DateTime.parse(dateStr);
            final now = DateTime.now();
            return date.year == now.year && date.month == now.month;
          } catch (_) {
            return false;
          }
        }).length;

        final validPct = totalDocs > 0 ? (validDocs / totalDocs * 100) : 0.0;
        final expiringPct = totalDocs > 0 ? (expiringSoonDocs / totalDocs * 100) : 0.0;
        final expiredPct = totalDocs > 0 ? (expiredDocs / totalDocs * 100) : 0.0;

        // KPI card columns based on available width
        int kpiColumns = 5;
        if (availableWidth < 700) {
          kpiColumns = 1;
        } else if (availableWidth < 950) {
          kpiColumns = 2;
        } else if (availableWidth < 1300) {
          kpiColumns = 3;
        }

        final kpiCardWidth = (availableWidth - (kpiColumns - 1) * 12) / kpiColumns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Stats Wrap
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildDocKpiCard('Total Documents', '$totalDocs', 'All vehicles', const Color(0xFF8B5CF6), Icons.description_outlined, null, kpiCardWidth),
                _buildDocKpiCard('Valid Documents', '$validDocs', '${validPct.toStringAsFixed(1)}%', const Color(0xFF10B981), Icons.check_circle_outline, _green, kpiCardWidth),
                _buildDocKpiCard('Expiring Soon (30 Days)', '$expiringSoonDocs', '${expiringPct.toStringAsFixed(1)}%', const Color(0xFFF59E0B), Icons.access_time, _orange, kpiCardWidth),
                _buildDocKpiCard('Expired Documents', '$expiredDocs', '${expiredPct.toStringAsFixed(1)}%', const Color(0xFFEF4444), Icons.warning_amber_outlined, _red, kpiCardWidth),
                _buildDocKpiCard('Documents Uploaded\nThis Month', '$thisMonthDocs', 'New uploads', const Color(0xFF3B82F6), Icons.file_upload_outlined, null, kpiCardWidth),
              ],
            ),
            const SizedBox(height: 20),
            
            // 2. Filters & Content Section
            Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFiltersSection(availableWidth),
                  if (isDesktop)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 7, child: _buildTableSection()),
                          const VerticalDivider(width: 1, color: _border),
                          Expanded(flex: 3, child: _buildDetailsPanelSection()),
                        ],
                      ),
                    )
                  else ...[
                    _buildTableSection(),
                    const Divider(height: 1, color: _border),
                    _buildDetailsPanelSection(),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDocKpiCard(String title, String value, String subtitle, Color color, IconData icon, Color? valueColor, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), height: 1.1),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subtitle,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: valueColor ?? color),
                        overflow: TextOverflow.ellipsis,
                      ),
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

  Widget _buildFiltersSection(double availableWidth) {
    final showWrap = availableWidth < 1250;
    
    final searchWidget = Container(
      height: 38,
      width: showWrap ? (availableWidth < 600 ? double.infinity : 280) : null,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: _textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _docSearchController,
              style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search documents by name or type...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
              ),
            ),
          ),
          if (_docSearchController.text.isNotEmpty)
            GestureDetector(
              onTap: () => _docSearchController.clear(),
              child: const Icon(Icons.close, size: 16, color: _textSecondary),
            ),
        ],
      ),
    );

    final statusWidget = SizedBox(
      width: showWrap ? (availableWidth < 600 ? double.infinity : 150) : null,
      child: _buildFilterDropdown(
        value: _docStatusFilter,
        items: ['All', 'Valid', 'Expiring Soon', 'Expired'],
        label: 'Status',
        onChanged: (val) {
          setState(() {
            _docStatusFilter = val!;
            _docCurrentPage = 1;
          });
        },
      ),
    );

    final typeWidget = SizedBox(
      width: showWrap ? (availableWidth < 600 ? double.infinity : 150) : null,
      child: _buildFilterDropdown(
        value: _docTypeFilter,
        items: ['All', 'Registration', 'Insurance', 'Pollution', 'Fitness', 'Permit', 'Other'],
        label: 'Type',
        onChanged: (val) {
          setState(() {
            _docTypeFilter = val!;
            _docCurrentPage = 1;
          });
        },
      ),
    );

    final vehicleWidget = Container(
      height: 38,
      width: showWrap ? (availableWidth < 600 ? double.infinity : 180) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedVehicleFilter,
          isExpanded: true,
          style: GoogleFonts.inter(fontSize: 13, color: _textPrimary, fontWeight: FontWeight.w500),
          items: [
            const DropdownMenuItem(value: 'All', child: Text('All Vehicles')),
            ..._vehicles.map((v) {
              final reg = v['registration_no'] ?? v['bus_number'] ?? 'Vehicle';
              return DropdownMenuItem(value: v['id'].toString(), child: Text(reg));
            }),
          ],
          onChanged: (val) {
            setState(() {
              _selectedVehicleFilter = val!;
              _docCurrentPage = 1;
            });
          },
        ),
      ),
    );

    final actionsWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.filter_list, size: 16),
          label: const Text('Filters'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _textPrimary,
            side: const BorderSide(color: _border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh, size: 18),
          onPressed: () {
            setState(() {
              _docSearchController.clear();
              _docStatusFilter = 'All';
              _docTypeFilter = 'All';
              _selectedVehicleFilter = 'All';
              _docCurrentPage = 1;
            });
          },
          style: IconButton.styleFrom(
            side: const BorderSide(color: _border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ],
    );

    if (showWrap) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _border)),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            searchWidget,
            statusWidget,
            typeWidget,
            vehicleWidget,
            actionsWidget,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: searchWidget),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: statusWidget),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: typeWidget),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: vehicleWidget),
          const SizedBox(width: 12),
          actionsWidget,
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: GoogleFonts.inter(fontSize: 13, color: _textPrimary, fontWeight: FontWeight.w500),
          items: items.map((s) {
            return DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All ${label}es' : s));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTableSection() {
    final filtered = _filteredDocuments;
    final total = filtered.length;
    final totalPages = (total + _docPageSize - 1) ~/ _docPageSize;
    final startIdx = (_docCurrentPage - 1) * _docPageSize;
    final endIdx = startIdx + _docPageSize > total ? total : startIdx + _docPageSize;
    final paginated = filtered.sublist(startIdx, endIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1100),
            child: DataTable(
              columnSpacing: 16,
              horizontalMargin: 12,
              showCheckboxColumn: false,
              headingRowHeight: 44,
              dataRowMinHeight: 64,
              dataRowMaxHeight: 64,
              columns: [
                DataColumn(label: Text('Document Name', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
                DataColumn(label: Text('Document Type', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
                DataColumn(label: Text('Vehicle Number', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
                DataColumn(label: Text('Issue Date', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
                DataColumn(label: Text('Expiry Date', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
                DataColumn(label: Text('Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
                DataColumn(label: Text('Uploaded On', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
                DataColumn(label: Text('Actions', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
              ],
              rows: paginated.map((doc) {
                final isSelected = _selectedDocument != null && _selectedDocument['id'] == doc['id'];
                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) {
                    setState(() {
                      _selectedDocument = doc;
                    });
                  },
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 200,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildDocIcon(doc['document_type'] ?? 'Other'),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    doc['document_name'] ?? doc['document_type'] ?? 'Document', 
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    doc['remarks'] ?? 'RC Book', 
                                    style: GoogleFonts.inter(fontSize: 10, color: _textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(Text(doc['document_type'] ?? '—', style: GoogleFonts.inter(fontSize: 13))),
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              doc['transport_routes']?['registration_no'] ?? doc['transport_routes']?['bus_number'] ?? doc['bus_routes']?['registration_no'] ?? doc['bus_routes']?['bus_number'] ?? '—', 
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              doc['transport_routes']?['vehicle_type'] ?? doc['bus_routes']?['vehicle_type'] ?? 'AC Bus', 
                              style: GoogleFonts.inter(fontSize: 10, color: _textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(Text(_formatDate(doc['issued_date']), style: GoogleFonts.inter(fontSize: 13))),
                    DataCell(
                      SizedBox(
                        width: 110,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatDate(doc['expiry_date']), 
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: (doc['status'] == 'Expired' || doc['status'] == 'Expiring Soon') ? _orange : _textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (doc['status'] == 'Expired' || doc['status'] == 'Expiring Soon')
                              Text(
                                _getDaysLeftText(doc['expiry_date'], doc['status']), 
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: doc['status'] == 'Expired' ? _red : _orange),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(_buildDocStatusBadge(doc['status'] ?? 'Valid')),
                    DataCell(
                      SizedBox(
                        width: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatDate(doc['uploaded_on'] ?? doc['created_at']), 
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'by ${doc['uploaded_by'] ?? "Transport Manager"}', 
                              style: GoogleFonts.inter(fontSize: 10, color: _textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                            onPressed: () {
                              setState(() {
                                _selectedDocument = doc;
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: _red),
                            onPressed: () => _deleteDocument(doc['id']),
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
        
        // Pagination footer
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${total == 0 ? 0 : startIdx + 1} to $endIdx of $total documents',
                style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _docCurrentPage > 1 ? () => setState(() => _docCurrentPage--) : null,
                  ),
                  ...List.generate(totalPages > 5 ? 5 : totalPages, (i) {
                    final p = i + 1;
                    final isCurrent = p == _docCurrentPage;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => setState(() => _docCurrentPage = p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCurrent ? _accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: isCurrent ? null : Border.all(color: _border),
                          ),
                          child: Text(
                            '$p',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : _textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  if (totalPages > 5) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('...'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => setState(() => _docCurrentPage = totalPages),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _docCurrentPage == totalPages ? _accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: _docCurrentPage == totalPages ? null : Border.all(color: _border),
                          ),
                          child: Text(
                            '$totalPages',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _docCurrentPage == totalPages ? Colors.white : _textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _docCurrentPage < totalPages ? () => setState(() => _docCurrentPage++) : null,
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _docPageSize,
                    style: GoogleFonts.inter(fontSize: 13, color: _textPrimary, fontWeight: FontWeight.bold),
                    items: [5, 10, 20, 50].map((size) {
                      return DropdownMenuItem(value: size, child: Text('$size / page'));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _docPageSize = val!;
                        _docCurrentPage = 1;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsPanelSection() {
    if (_selectedDocument == null) {
      return Container(
        height: 400,
        alignment: Alignment.center,
        child: Text('Select a document to view details', style: GoogleFonts.inter(color: _textSecondary)),
      );
    }
    
    final doc = _selectedDocument;
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Document Details', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildMockDocumentPreview(doc),
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final url = doc['document_url'] as String?;
                if (url != null && url.isNotEmpty) {
                  final uri = Uri.parse(url);
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open document link.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No file attachment found for this document.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          _buildDocDetailRow('Document Type', doc['document_type'] ?? '—'),
          _buildDocDetailRow('Vehicle Number', doc['transport_routes']?['registration_no'] ?? doc['transport_routes']?['bus_number'] ?? doc['bus_routes']?['registration_no'] ?? doc['bus_routes']?['bus_number'] ?? '—'),
          _buildDocDetailRow('Vehicle', doc['transport_routes']?['vehicle_type'] ?? doc['bus_routes']?['vehicle_type'] ?? 'AC Bus'),
          _buildDocDetailRow('Issue Date', _formatDate(doc['issued_date'])),
          _buildDocDetailRow(
            'Expiry Date', 
            _formatDate(doc['expiry_date']), 
            suffix: (doc['status'] == 'Expired' || doc['status'] == 'Expiring Soon') 
              ? _getDaysLeftText(doc['expiry_date'], doc['status']) 
              : null,
            suffixColor: doc['status'] == 'Expired' ? _red : _orange,
          ),
          _buildDocDetailRow('Policy Number', doc['policy_no'] ?? '—'),
          _buildDocDetailRow('Insurance Provider', doc['provider'] ?? '—'),
          _buildDocDetailRow('Uploaded On', _formatDate(doc['uploaded_on'] ?? doc['created_at'])),
          _buildDocDetailRow('Uploaded By', doc['uploaded_by'] ?? '—'),
          _buildDocDetailRow('Remarks', doc['remarks'] ?? '—'),
          
          const SizedBox(height: 24),
          Text('Quick Actions', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 12),
          
          _buildQuickActionButton(Icons.file_upload_outlined, 'Upload Document', () => _showAddDocumentDialog()),
          const SizedBox(height: 8),
          _buildQuickActionButton(Icons.history_outlined, 'View Document History', () {}),
          const SizedBox(height: 8),
          _buildQuickActionButton(Icons.notifications_active_outlined, 'Set Reminder', () {}),
        ],
      ),
    );
  }

  Widget _buildDocDetailRow(String label, String value, {String? suffix, Color? suffixColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
          ),
          Expanded(
            flex: 6,
            child: Wrap(
              children: [
                Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary)),
                if (suffix != null) ...[
                  const SizedBox(width: 4),
                  Text(suffix, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: suffixColor ?? _orange)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _accent),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 12, color: _textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildMockDocumentPreview(dynamic doc) {
    final docUrl = doc['document_url'] as String?;
    if (docUrl != null && docUrl.isNotEmpty) {
      final lowerUrl = docUrl.toLowerCase();
      final isImage = lowerUrl.contains('.jpg') || 
                      lowerUrl.contains('.png') || 
                      lowerUrl.contains('.jpeg') || 
                      lowerUrl.contains('.webp') ||
                      lowerUrl.contains('.gif') ||
                      lowerUrl.contains('/storage/v1/object/');
      if (isImage) {
        return Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              docUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildFallbackMockPreview(doc);
              },
            ),
          ),
        );
      }
    }
    return _buildFallbackMockPreview(doc);
  }

  Widget _buildFallbackMockPreview(dynamic doc) {
    final docType = (doc['document_type'] ?? 'Other').toString().toLowerCase();
    
    Color primaryColor = const Color(0xFF4F46E5);
    String headerText = "OFFICIAL DOCUMENT";
    String subText = doc['document_name'] ?? doc['document_no'] ?? 'CERTIFICATE';
    
    if (docType.contains('insurance')) {
      primaryColor = const Color(0xFF1E3A8A);
      headerText = "SHRIRAM GENERAL INSURANCE CO. LTD.";
      subText = "MOTOR INSURANCE POLICY";
    } else if (docType.contains('registration') || docType.contains('rc')) {
      primaryColor = const Color(0xFF065F46);
      headerText = "REGIONAL TRANSPORT OFFICE";
      subText = "REGISTRATION CERTIFICATE (FORM 23)";
    } else if (docType.contains('pollution') || docType.contains('puc')) {
      primaryColor = const Color(0xFF9D174D);
      headerText = "POLLUTION UNDER CONTROL";
      subText = "PUC CERTIFICATE";
    } else if (docType.contains('fitness')) {
      primaryColor = const Color(0xFF9A3412);
      headerText = "TRANSPORT DEPARTMENT";
      subText = "CERTIFICATE OF FITNESS";
    } else if (docType.contains('permit')) {
      primaryColor = const Color(0xFF0369A1);
      headerText = "STATE TRANSPORT AUTHORITY";
      subText = "NATIONAL PERMIT CERTIFICATE";
    }

    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headerText,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subText,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.verified_user,
                      size: 24,
                      color: primaryColor.withValues(alpha: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMockTextColumn("DOC NO", doc['document_no'] ?? "RC-UP16-99218"),
                    _buildMockTextColumn("VEHICLE NO", doc['transport_routes']?['registration_no'] ?? doc['transport_routes']?['bus_number'] ?? doc['bus_routes']?['registration_no'] ?? doc['bus_routes']?['bus_number'] ?? "UP16 ET 1234"),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMockTextColumn("EXPIRY DATE", _formatDate(doc['expiry_date'])),
                    _buildMockTextColumn("STATUS", doc['status'] ?? "Valid"),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 50,
                      height: 4,
                      color: const Color(0xFFCBD5E1),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Icon(Icons.qr_code_2, size: 16, color: primaryColor),
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

  Widget _buildMockTextColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
        ),
      ],
    );
  }

  Widget _buildDocIcon(String type) {
    IconData icon;
    Color color;
    switch (type.toLowerCase()) {
      case 'registration':
        icon = Icons.picture_as_pdf;
        color = _red;
        break;
      case 'insurance':
        icon = Icons.picture_as_pdf;
        color = _blue;
        break;
      case 'pollution':
        icon = Icons.picture_as_pdf;
        color = _green;
        break;
      case 'fitness':
        icon = Icons.picture_as_pdf;
        color = _orange;
        break;
      case 'permit':
        icon = Icons.picture_as_pdf;
        color = _accent;
        break;
      default:
        icon = Icons.image;
        color = _gray;
    }
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  Widget _buildDocStatusBadge(String status) {
    Color color;
    Color bg;
    
    switch (status.toLowerCase()) {
      case 'valid':
        color = _green;
        bg = _green.withValues(alpha: 0.1);
        break;
      case 'permanent':
        color = Colors.teal;
        bg = Colors.teal.withValues(alpha: 0.1);
        break;
      case 'expiring soon':
      case 'expiring_soon':
        color = _orange;
        bg = _orange.withValues(alpha: 0.1);
        break;
      case 'expiring today':
      case 'expiring_today':
        color = _red;
        bg = _red.withValues(alpha: 0.1);
        break;
      case 'expired':
        color = _red;
        bg = _red.withValues(alpha: 0.1);
        break;
      default:
        color = _gray;
        bg = _gray.withValues(alpha: 0.1);
        status = 'N/A';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _deleteDocument(dynamic docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await ApiService().delete('/transport/documents/$docId');
        _loadAll();
      } catch (_) {}
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _getDaysLeftText(String? expiryStr, String status) {
    if (expiryStr == null || expiryStr.isEmpty) return '';
    try {
      final expiry = DateTime.parse(expiryStr);
      final today = DateTime.now();
      final diff = expiry.difference(DateTime(today.year, today.month, today.day)).inDays;
      if (diff < 0) {
        return '(${diff.abs()} Days Ago)';
      } else if (diff == 0) {
        return '(Today)';
      } else {
        return '($diff Days Left)';
      }
    } catch (_) {
      return '';
    }
  }

  void _showAddDocumentDialog([dynamic initialVehicle]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final noCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    final policyCtrl = TextEditingController();
    final providerCtrl = TextEditingController();
    
    String? selectedVehicleId = (initialVehicle != null ? initialVehicle['id'] : _selectedVehicle?['id'])?.toString();
    if (selectedVehicleId == null && _vehicles.isNotEmpty) {
      selectedVehicleId = _vehicles.first['id']?.toString();
    }
    String docType = 'Registration';
    String status = 'Valid';
    
    DateTime issuedDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime expiryDate = DateTime.now().add(const Duration(days: 335));
    
    // File picker state
    XFile? pickedFile;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> selectIssuedDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: issuedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setDialogState(() => issuedDate = picked);
              }
            }

            Future<void> selectExpiryDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: expiryDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setDialogState(() => expiryDate = picked);
              }
            }

            Future<void> pickFile() async {
              try {
                final file = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (file != null) {
                  setDialogState(() {
                    pickedFile = file;
                  });
                }
              } catch (_) {}
            }

            return AlertDialog(
              title: Text('Upload Document', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  clipBehavior: Clip.none,
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedVehicleId,
                          decoration: const InputDecoration(labelText: 'Select Vehicle'),
                          items: _vehicles.map((v) {
                            final reg = v['registration_no'] ?? v['bus_number'] ?? 'Vehicle';
                            return DropdownMenuItem(value: v['id'].toString(), child: Text(reg));
                          }).toList(),
                          onChanged: (val) => setDialogState(() => selectedVehicleId = val),
                          validator: (val) => val == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: docType,
                          decoration: const InputDecoration(labelText: 'Document Type'),
                          items: ['Registration', 'Insurance', 'Pollution', 'Fitness', 'Permit', 'Other']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (val) => setDialogState(() => docType = val!),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Document Name', hintText: 'e.g. Registration Certificate'),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: noCtrl,
                          decoration: const InputDecoration(labelText: 'Document Number', hintText: 'e.g. RC-UP16-1234'),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: selectIssuedDate,
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Issue Date'),
                                  child: Text(DateFormat('dd MMM yyyy').format(issuedDate)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: selectExpiryDate,
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Expiry Date'),
                                  child: Text(DateFormat('dd MMM yyyy').format(expiryDate)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: ['Valid', 'Expiring Soon', 'Expired']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (val) => setDialogState(() => status = val!),
                        ),
                        const SizedBox(height: 12),
                        if (docType == 'Insurance') ...[
                          TextFormField(
                            controller: policyCtrl,
                            decoration: const InputDecoration(labelText: 'Policy Number', hintText: 'e.g. POL-123456'),
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: providerCtrl,
                            decoration: const InputDecoration(labelText: 'Insurance Provider', hintText: 'e.g. HDFC ERGO'),
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: remarksCtrl,
                          decoration: const InputDecoration(labelText: 'Remarks / Subtitle', hintText: 'e.g. RC Book'),
                        ),
                        const SizedBox(height: 16),
                        Text('Document File Attachment', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textSecondary)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: pickFile,
                              icon: const Icon(Icons.attach_file, size: 16),
                              label: const Text('Attach File'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent.withValues(alpha: 0.1),
                                foregroundColor: _accent,
                                elevation: 0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                pickedFile != null ? pickedFile!.name : 'No file chosen',
                                style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      try {
                        String? fileUrl;
                        if (pickedFile != null) {
                          final bytes = await pickedFile!.readAsBytes();
                          final uploadResponse = await ApiService().multipartPostBytes(
                            '/transport/documents/upload',
                            bytes,
                            pickedFile!.name,
                            'file',
                          );
                          if (uploadResponse['success'] == true) {
                            fileUrl = uploadResponse['data']?['url'] as String?;
                          }
                        }
                        
                        final data = {
                          "vehicle_id": selectedVehicleId,
                          "document_type": docType,
                          "document_name": nameCtrl.text,
                          "document_no": noCtrl.text,
                          "issued_date": DateFormat('yyyy-MM-dd').format(issuedDate),
                          "expiry_date": DateFormat('yyyy-MM-dd').format(expiryDate),
                          "status": status,
                          "remarks": remarksCtrl.text.isEmpty ? null : remarksCtrl.text,
                          "policy_no": docType == 'Insurance' ? policyCtrl.text : null,
                          "provider": docType == 'Insurance' ? providerCtrl.text : null,
                          "uploaded_by": "Transport Manager",
                          "document_url": fileUrl,
                        };
                        await ApiService().post('/transport/documents', data);
                        try {
                          final docRes = await ApiService().get('/transport/documents', useCache: false);
                          final docRaw = docRes['data'];
                          if (mounted) {
                            setState(() {
                              _documents = (docRaw is List) ? docRaw : [];
                            });
                          }
                        } catch (_) {}
                        _loadAll();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Document uploaded successfully'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to upload document: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: const Text('Upload'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ═══════════════════ 5. INSURANCE & FITNESS TAB ═══════════════════
  Widget _buildInsuranceFitnessTab() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('Insurance & Fitness Records', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Vehicle')),
                DataColumn(label: Text('Policy No.')),
                DataColumn(label: Text('Insurance Expiry')),
                DataColumn(label: Text('Fitness Expiry')),
                DataColumn(label: Text('Pollution Expiry')),
              ],
              rows: _insuranceFitness.map((inf) {
                return DataRow(cells: [
                  DataCell(Text(inf['bus_routes']?['registration_no'] ?? '—')),
                  DataCell(Text(inf['policy_no'] ?? '—')),
                  DataCell(Text(inf['insurance_expiry'] ?? '—')),
                  DataCell(Text(inf['fitness_expiry'] ?? '—')),
                  DataCell(Text(inf['pollution_expiry'] ?? '—')),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════ 6. GPS DEVICES TAB ═══════════════════
  Widget _buildGpsDevicesTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isDesktop = availableWidth >= 1100;

        // Stats calculation
        final totalDevices = _gpsDevices.length;
        final onlineDevices = _gpsDevices.where((d) => (d['status'] ?? '').toLowerCase() == 'active' || (d['status'] ?? '').toLowerCase() == 'online').length;
        final offlineDevices = _gpsDevices.where((d) => (d['status'] ?? '').toLowerCase() == 'offline').length;
        
        final renewalDevices = _gpsDevices.where((d) {
          final expStr = d['expiry_date'];
          if (expStr == null) return false;
          try {
            final exp = DateTime.parse(expStr);
            final diff = exp.difference(DateTime.now()).inDays;
            return diff >= 0 && diff <= 30;
          } catch (_) {
            return false;
          }
        }).length;

        final faultyDevices = _gpsDevices.where((d) => (d['status'] ?? '').toLowerCase() == 'faulty' || (d['status'] ?? '').toLowerCase() == 'issue').length;

        final onlinePct = totalDevices > 0 ? (onlineDevices / totalDevices * 100) : 0.0;
        final offlinePct = totalDevices > 0 ? (offlineDevices / totalDevices * 100) : 0.0;
        final renewalPct = totalDevices > 0 ? (renewalDevices / totalDevices * 100) : 0.0;
        final faultyPct = totalDevices > 0 ? (faultyDevices / totalDevices * 100) : 0.0;

        // KPI card columns based on available width
        int kpiColumns = 5;
        if (availableWidth < 700) {
          kpiColumns = 1;
        } else if (availableWidth < 950) {
          kpiColumns = 2;
        } else if (availableWidth < 1300) {
          kpiColumns = 3;
        }

        final kpiCardWidth = (availableWidth - (kpiColumns - 1) * 12) / kpiColumns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Stats Row
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildDocKpiCard('Total Devices', '$totalDevices', 'All devices', const Color(0xFF8B5CF6), Icons.router_outlined, null, kpiCardWidth),
                _buildDocKpiCard('Online Devices', '$onlineDevices', '${onlinePct.toStringAsFixed(2)}%', const Color(0xFF10B981), Icons.check_circle_outline, _green, kpiCardWidth),
                _buildDocKpiCard('Offline Devices', '$offlineDevices', '${offlinePct.toStringAsFixed(2)}%', const Color(0xFF94A3B8), Icons.cloud_off_outlined, _gray, kpiCardWidth),
                _buildDocKpiCard('Devices Due for Renewal', '$renewalDevices', '${renewalPct.toStringAsFixed(2)}%', const Color(0xFF3B82F6), Icons.calendar_today_outlined, _blue, kpiCardWidth),
                _buildDocKpiCard('Devices with Issues', '$faultyDevices', '${faultyPct.toStringAsFixed(2)}%', const Color(0xFFEF4444), Icons.error_outline, _red, kpiCardWidth),
              ],
            ),
            const SizedBox(height: 20),

            // 2. Filters & Content Section
            Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGpsFiltersSection(availableWidth),
                  const Divider(height: 1),
                  if (isDesktop)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 7, child: _buildGpsTableSection()),
                          const VerticalDivider(width: 1, color: _border),
                          Expanded(flex: 3, child: _buildGpsDetailsPanelSection()),
                        ],
                      ),
                    )
                  else ...[
                    _buildGpsTableSection(),
                    const Divider(height: 1),
                    _buildGpsDetailsPanelSection(),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════ GPS Filter Row ═══════════════════
  Widget _buildGpsFiltersSection(double availableWidth) {
    // 1. Sleek Search Input
    final searchWidget = SizedBox(
      height: 38,
      child: TextField(
        controller: _gpsSearchController,
        onChanged: (val) => setState(() {
          _gpsSearchQuery = val;
          _gpsCurrentPage = 1;
        }),
        decoration: InputDecoration(
          hintText: 'Search device ID, IMEI, bus...',
          hintStyle: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
          prefixIcon: const Icon(Icons.search, size: 18, color: _textSecondary),
          suffixIcon: _gpsSearchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: _textSecondary),
                  onPressed: () {
                    _gpsSearchController.clear();
                    setState(() {
                      _gpsSearchQuery = '';
                      _gpsCurrentPage = 1;
                    });
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _accent, width: 1.5)),
        ),
        style: GoogleFonts.inter(fontSize: 13),
      ),
    );

    // 2. Status Dropdown
    final statusWidget = SizedBox(
      height: 38,
      child: DropdownButtonFormField<String>(
        initialValue: _gpsStatusFilter,
        isExpanded: true,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
        ),
        items: ['All', 'Online', 'Offline', 'Issues'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Status' : s, style: GoogleFonts.inter(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (val) => setState(() {
          _gpsStatusFilter = val!;
          _gpsCurrentPage = 1;
        }),
      ),
    );

    // 3. Provider Dropdown
    final providerWidget = SizedBox(
      height: 38,
      child: DropdownButtonFormField<String>(
        initialValue: _gpsProviderFilter,
        isExpanded: true,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
        ),
        items: ['All', 'Jio', 'Airtel', 'Vi'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Providers' : s, style: GoogleFonts.inter(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (val) => setState(() {
          _gpsProviderFilter = val!;
          _gpsCurrentPage = 1;
        }),
      ),
    );

    // 4. Vehicle Type Dropdown
    final typeWidget = SizedBox(
      height: 38,
      child: DropdownButtonFormField<String>(
        initialValue: _gpsVehicleFilter,
        isExpanded: true,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
        ),
        items: ['All', 'AC Bus', 'Non AC Bus', 'Mini Bus', 'Tempo Traveller', 'Electric Bus'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Types' : s, style: GoogleFonts.inter(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (val) => setState(() {
          _gpsVehicleFilter = val!;
          _gpsCurrentPage = 1;
        }),
      ),
    );

    // 5. Actions (Filters button + Refresh icon) with identical 38px height
    final actionsWidget = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 38,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                // Toggle filter view if needed or apply filters
              });
            },
            icon: const Icon(Icons.filter_list, size: 16),
            label: Text('Filters', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textPrimary,
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 38),
              maximumSize: const Size(double.infinity, 38),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          height: 38,
          child: IconButton(
            icon: const Icon(Icons.refresh, size: 18, color: _textSecondary),
            onPressed: () {
              setState(() {
                _gpsSearchController.clear();
                _gpsSearchQuery = '';
                _gpsStatusFilter = 'All';
                _gpsProviderFilter = 'All';
                _gpsVehicleFilter = 'All';
                _gpsCurrentPage = 1;
              });
            },
            style: IconButton.styleFrom(
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: EdgeInsets.zero,
              minimumSize: const Size(38, 38),
              maximumSize: const Size(38, 38),
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          
          // Large Screen / Desktop (>= 800px): Everything on 1 sleek line!
          if (width >= 800) {
            return Row(
              children: [
                SizedBox(width: 240, child: searchWidget),
                const SizedBox(width: 10),
                SizedBox(width: 130, child: statusWidget),
                const SizedBox(width: 10),
                SizedBox(width: 130, child: providerWidget),
                const SizedBox(width: 10),
                SizedBox(width: 140, child: typeWidget),
                const Spacer(),
                actionsWidget,
              ],
            );
          }
          
          // Medium Screen / Tablet (500px to 800px): 2 clean rows
          if (width >= 500) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: searchWidget),
                    const SizedBox(width: 10),
                    actionsWidget,
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: statusWidget),
                    const SizedBox(width: 10),
                    Expanded(child: providerWidget),
                    const SizedBox(width: 10),
                    Expanded(child: typeWidget),
                  ],
                ),
              ],
            );
          }

          // Small Screen / Mobile (< 500px): 3 clean compact rows
          return Column(
            children: [
              searchWidget,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: statusWidget),
                  const SizedBox(width: 10),
                  Expanded(child: providerWidget),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: typeWidget),
                  const SizedBox(width: 10),
                  actionsWidget,
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════ GPS Devices Table ═══════════════════
  Widget _buildGpsTableSection() {
    final filtered = _filteredGpsDevices;
    final totalCount = filtered.length;
    final startIndex = (_gpsCurrentPage - 1) * _gpsPageSize;
    final paginated = filtered.skip(startIndex).take(_gpsPageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1100),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              horizontalMargin: 16,
              columnSpacing: 24,
              columns: [
                DataColumn(label: Text('Device ID', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
                DataColumn(label: Text('IMEI Number', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
                DataColumn(label: Text('Provider', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
                DataColumn(label: Text('Installed In', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
                DataColumn(label: Text('Installed On', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
                DataColumn(label: Text('Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
                DataColumn(label: Text('Signal & Battery', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
                DataColumn(label: Text('Expiry Date', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
                DataColumn(label: Text('Actions', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _textPrimary))),
              ],
              rows: paginated.map((dev) {
                final isSelected = _selectedGpsDevice != null && _selectedGpsDevice['id'] == dev['id'];
                
                // Expiry info
                final expStr = dev['expiry_date'];
                String daysLeftText = '';
                bool isExpired = false;
                bool isExpiringSoon = false;
                if (expStr != null) {
                  try {
                    final exp = DateTime.parse(expStr);
                    final diff = exp.difference(DateTime.now()).inDays;
                    if (diff < 0) {
                      isExpired = true;
                      daysLeftText = '(${diff.abs()} Days Overdue)';
                    } else {
                      daysLeftText = '($diff Days Left)';
                      if (diff <= 30) isExpiringSoon = true;
                    }
                  } catch (_) {}
                }

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) {
                    setState(() {
                      _selectedGpsDevice = dev;
                    });
                  },
                  cells: [
                    // Device ID
                    DataCell(
                      SizedBox(
                        width: 130,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.router, size: 16, color: _textSecondary),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(dev['device_id'] ?? '—', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary), overflow: TextOverflow.ellipsis),
                                  Text(dev['model'] ?? 'GT06N', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // IMEI Number
                    DataCell(
                      SizedBox(
                        width: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(dev['imei_no'] ?? '—', style: GoogleFonts.inter(fontSize: 12, color: _textPrimary), overflow: TextOverflow.ellipsis),
                            Text(dev['sim_no'] ?? '—', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    // Provider
                    DataCell(
                      SizedBox(
                        width: 80,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(dev['operator'] ?? '—', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary), overflow: TextOverflow.ellipsis),
                            Text('4G', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                          ],
                        ),
                      ),
                    ),
                    // Installed In
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(dev['bus_routes']?['registration_no'] ?? dev['bus_routes']?['bus_number'] ?? 'Unassigned', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary), overflow: TextOverflow.ellipsis),
                            Text(dev['bus_routes']?['vehicle_type'] ?? 'AC Bus', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    // Installed On
                    DataCell(
                      SizedBox(
                        width: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_formatDate(dev['installation_date']), style: GoogleFonts.inter(fontSize: 12, color: _textPrimary), overflow: TextOverflow.ellipsis),
                            Text('by ${dev['installed_by'] ?? "Transport Manager"}', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    // Status
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildGpsStatusBadge(dev['status'] ?? 'Active'),
                            const SizedBox(height: 2),
                            Text(
                              (dev['status'] ?? '').toLowerCase() == 'active' ? '2 mins ago' : '1 day ago', 
                              style: GoogleFonts.inter(fontSize: 9, color: _textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Signal & Battery
                    DataCell(
                      SizedBox(
                        width: 130,
                        child: Row(
                          children: [
                            _buildSignalIndicator(dev['signal_strength_pct'] ?? 100),
                            const SizedBox(width: 8),
                            _buildBatteryIndicator(dev['battery_level'] ?? 100),
                          ],
                        ),
                      ),
                    ),
                    // Expiry Date
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_formatDate(dev['expiry_date']), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary), overflow: TextOverflow.ellipsis),
                            if (daysLeftText.isNotEmpty)
                              Text(daysLeftText, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: isExpired ? _red : (isExpiringSoon ? _orange : _green)), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 16, color: _textSecondary),
                            onPressed: () => setState(() => _selectedGpsDevice = dev),
                            tooltip: 'View Details',
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16, color: _accent),
                            onPressed: () => _showEditGpsDeviceDialog(dev),
                            tooltip: 'Edit Device',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: _red),
                            onPressed: () => _deleteGpsDevice(dev),
                            tooltip: 'Delete Device',
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
        
        // Pagination Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                'Showing ${totalCount == 0 ? 0 : startIndex + 1} to ${startIndex + paginated.length} of $totalCount devices',
                style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
              ),
              const Spacer(),
              
              // Page size dropdown & Page controls
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _gpsPageSize,
                        items: [5, 10, 20, 50].map((size) {
                          return DropdownMenuItem<int>(
                            value: size,
                            child: Text('$size / page', style: GoogleFonts.inter(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _gpsPageSize = val!;
                            _gpsCurrentPage = 1;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: _gpsCurrentPage > 1 ? () => setState(() => _gpsCurrentPage--) : null,
                  ),
                  const SizedBox(width: 8),
                  Text('$_gpsCurrentPage', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: startIndex + paginated.length < totalCount ? () => setState(() => _gpsCurrentPage++) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════ GPS Details Panel ═══════════════════
  Widget _buildGpsDetailsPanelSection() {
    final doc = _selectedGpsDevice;
    if (doc == null) {
      return Container(
        height: 250,
        alignment: Alignment.center,
        child: Text('Select a device to view details.', style: GoogleFonts.inter(color: _textSecondary)),
      );
    }

    final isIssue = (doc['status'] ?? '').toString().toLowerCase() == 'faulty';
    final isOffline = (doc['status'] ?? '').toString().toLowerCase() == 'offline';
    final hasIssue = isIssue || (doc['battery_level'] ?? 100) < 20;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc['device_id'] ?? '—', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                      Text(doc['model'] ?? 'GT06N', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                    ],
                  ),
                ),
                _buildGpsStatusBadge(doc['status'] ?? 'Active'),
              ],
            ),
            const SizedBox(height: 16),

            // Device Mock Visual Card
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.router, size: 40, color: _accent),
                    const SizedBox(height: 4),
                    Text(doc['firmware_version'] ?? 'GTO6N_V7.2.1', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Detail lines
            _buildDocDetailRow('IMEI Number', doc['imei_no'] ?? '—'),
            _buildDocDetailRow('SIM Number', doc['sim_no'] ?? '—'),
            _buildDocDetailRow('Provider', doc['operator'] ?? '—'),
            _buildDocDetailRow('Network', '4G'),
            _buildDocDetailRow('Installed In', doc['bus_routes']?['registration_no'] ?? 'Unassigned'),
            _buildDocDetailRow('Installed On', _formatDate(doc['installation_date'])),
            _buildDocDetailRow('Installed By', doc['installed_by'] ?? 'Transport Manager'),
            _buildDocDetailRow('Firmware Version', doc['firmware_version'] ?? 'GTO6N_V7.2.1'),
            _buildDocDetailRow('Last Seen', (doc['status'] ?? '').toLowerCase() == 'active' ? '2 mins ago' : '1 day ago'),
            
            // Location block
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: Text('Current Location', style: GoogleFonts.inter(fontSize: 13, color: _textSecondary))),
                  Expanded(
                    flex: 6,
                    child: Text(
                      doc['current_location'] ?? 'Sector 62, Noida, UP \n28.6129° N, 77.3910° E',
                      style: GoogleFonts.inter(fontSize: 13, color: _textPrimary, height: 1.3),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),

            _buildDocDetailRow('Signal Strength', '${doc['signal_strength_pct'] ?? 100}%'),
            _buildDocDetailRow('Battery Level', '${doc['battery_level'] ?? 100}%'),
            
            // Expiry Date row
            _buildDocDetailRow('Expiry Date', _formatDate(doc['expiry_date'])),
            
            const SizedBox(height: 20),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showLiveTrackingMapDialog(doc),
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('View Live Tracking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showDeviceHistoryDialog(doc),
                icon: const Icon(Icons.history, size: 16),
                label: const Text('Device History'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // Warning block if issues exist
            if (hasIssue) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[100]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: _red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Device Issue', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _red)),
                          const SizedBox(height: 2),
                          Text(
                            isIssue ? 'Critical: Device reports hardware fault or sensor failure.' : 'Low battery warning: Please connect the device to power source.',
                            style: GoogleFonts.inter(fontSize: 11, color: _red, height: 1.3),
                          ),
                          const SizedBox(height: 4),
                          Text('30 mins ago', style: GoogleFonts.inter(fontSize: 10, color: Colors.red[300])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════ GPS Custom Indicators ═══════════════════
  Widget _buildGpsStatusBadge(String status) {
    Color bg = Colors.grey[100]!;
    Color text = Colors.grey[700]!;
    String label = status;

    if (status.toLowerCase() == 'active' || status.toLowerCase() == 'online') {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF15803D);
      label = 'Online';
    } else if (status.toLowerCase() == 'offline') {
      bg = const Color(0xFFF1F5F9);
      text = const Color(0xFF475569);
      label = 'Offline';
    } else if (status.toLowerCase() == 'faulty' || status.toLowerCase() == 'issue') {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFFB91C1C);
      label = 'Issue';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  Widget _buildSignalIndicator(int pct) {
    Color color = Colors.red;
    int bars = 1;
    if (pct > 75) {
      color = const Color(0xFF22C55E);
      bars = 4;
    } else if (pct > 50) {
      color = const Color(0xFF22C55E);
      bars = 3;
    } else if (pct > 25) {
      color = const Color(0xFFF59E0B);
      bars = 2;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final active = index < bars;
        return Container(
          width: 3,
          height: 4.0 + (index * 3.0),
          margin: const EdgeInsets.symmetric(horizontal: 0.5),
          decoration: BoxDecoration(
            color: active ? color : Colors.grey[300],
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  Widget _buildBatteryIndicator(int level) {
    IconData icon = Icons.battery_alert;
    Color color = _red;
    if (level > 80) {
      icon = Icons.battery_full;
      color = _green;
    } else if (level > 50) {
      icon = Icons.battery_5_bar;
      color = _green;
    } else if (level > 20) {
      icon = Icons.battery_3_bar;
      color = _orange;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 2),
        Text('$level%', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
      ],
    );
  }

  // ═══════════════════ GPS CRUD dialogs ═══════════════════
  void _showAddGpsDeviceDialog() {
    final formKey = GlobalKey<FormState>();
    final devIdCtrl = TextEditingController();
    final imeiCtrl = TextEditingController();
    final simCtrl = TextEditingController();
    final modelCtrl = TextEditingController(text: 'GT06N');
    final operatorCtrl = TextEditingController(text: 'Jio');
    final installerCtrl = TextEditingController(text: 'Transport Manager');
    final firmwareCtrl = TextEditingController(text: 'GTO6N_V7.2.1');
    final locationCtrl = TextEditingController(text: 'Sector 62, Noida, UP');

    String? selectedVehicleId = _vehicles.isNotEmpty ? _vehicles.first['id'].toString() : null;
    String status = 'Active';
    DateTime installDate = DateTime.now();
    DateTime expiryDate = DateTime.now().add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Register GPS Device', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  clipBehavior: Clip.none,
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: devIdCtrl,
                          decoration: const InputDecoration(labelText: 'Device ID', hintText: 'e.g. GPSD-1009'),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: imeiCtrl,
                          decoration: const InputDecoration(labelText: 'IMEI Number', hintText: 'e.g. 862345065432109'),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: simCtrl,
                          decoration: const InputDecoration(labelText: 'SIM Number', hintText: 'e.g. +919876543210'),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedVehicleId,
                          decoration: const InputDecoration(labelText: 'Select Vehicle'),
                          items: _vehicles.map((v) {
                            final reg = v['registration_no'] ?? v['bus_number'] ?? 'Vehicle';
                            return DropdownMenuItem(value: v['id'].toString(), child: Text(reg));
                          }).toList(),
                          onChanged: (val) => setDialogState(() => selectedVehicleId = val),
                          validator: (val) => val == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: modelCtrl,
                                decoration: const InputDecoration(labelText: 'Model'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: operatorCtrl,
                                decoration: const InputDecoration(labelText: 'Operator / Provider'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: ['Active', 'Offline', 'Faulty'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) => setDialogState(() => status = val!),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(context: context, initialDate: installDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                                  if (picked != null) setDialogState(() => installDate = picked);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Installation Date'),
                                  child: Text(DateFormat('dd MMM yyyy').format(installDate)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(context: context, initialDate: expiryDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                                  if (picked != null) setDialogState(() => expiryDate = picked);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Expiry Date'),
                                  child: Text(DateFormat('dd MMM yyyy').format(expiryDate)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx);
                      try {
                        final data = {
                          "school_id": "11111111-1111-1111-1111-111111111111",
                          "device_id": devIdCtrl.text,
                          "imei_no": imeiCtrl.text,
                          "sim_no": simCtrl.text,
                          "model": modelCtrl.text,
                          "operator": operatorCtrl.text,
                          "vehicle_id": selectedVehicleId,
                          "status": status,
                          "installation_date": DateFormat('yyyy-MM-dd').format(installDate),
                          "expiry_date": DateFormat('yyyy-MM-dd').format(expiryDate),
                          "installed_by": installerCtrl.text,
                          "firmware_version": firmwareCtrl.text,
                          "current_location": locationCtrl.text,
                          "battery_level": 100,
                          "signal_strength_pct": 100,
                        };
                        await ApiService().post('/transport/gps-devices', data);
                        _loadAll();
                      } catch (_) {}
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: const Text('Register'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditGpsDeviceDialog(dynamic dev) {
    final formKey = GlobalKey<FormState>();
    final devIdCtrl = TextEditingController(text: dev['device_id']);
    final imeiCtrl = TextEditingController(text: dev['imei_no']);
    final simCtrl = TextEditingController(text: dev['sim_no']);
    final modelCtrl = TextEditingController(text: dev['model']);
    final operatorCtrl = TextEditingController(text: dev['operator']);
    final installerCtrl = TextEditingController(text: dev['installed_by'] ?? 'Transport Manager');
    final firmwareCtrl = TextEditingController(text: dev['firmware_version'] ?? 'GTO6N_V7.2.1');
    final locationCtrl = TextEditingController(text: dev['current_location'] ?? 'Sector 62, Noida, UP');

    String? selectedVehicleId = dev['vehicle_id']?.toString() ?? (_vehicles.isNotEmpty ? _vehicles.first['id'].toString() : null);
    String status = dev['status'] ?? 'Active';
    DateTime installDate = dev['installation_date'] != null ? DateTime.parse(dev['installation_date']) : DateTime.now();
    DateTime expiryDate = dev['expiry_date'] != null ? DateTime.parse(dev['expiry_date']) : DateTime.now().add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit GPS Device', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  clipBehavior: Clip.none,
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: devIdCtrl,
                          decoration: const InputDecoration(labelText: 'Device ID'),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: imeiCtrl,
                          decoration: const InputDecoration(labelText: 'IMEI Number'),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: simCtrl,
                          decoration: const InputDecoration(labelText: 'SIM Number'),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedVehicleId,
                          decoration: const InputDecoration(labelText: 'Select Vehicle'),
                          items: _vehicles.map((v) {
                            final reg = v['registration_no'] ?? v['bus_number'] ?? 'Vehicle';
                            return DropdownMenuItem(value: v['id'].toString(), child: Text(reg));
                          }).toList(),
                          onChanged: (val) => setDialogState(() => selectedVehicleId = val),
                          validator: (val) => val == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: modelCtrl,
                                decoration: const InputDecoration(labelText: 'Model'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: operatorCtrl,
                                decoration: const InputDecoration(labelText: 'Operator / Provider'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: ['Active', 'Offline', 'Faulty'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) => setDialogState(() => status = val!),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(context: context, initialDate: installDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                                  if (picked != null) setDialogState(() => installDate = picked);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Installation Date'),
                                  child: Text(DateFormat('dd MMM yyyy').format(installDate)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(context: context, initialDate: expiryDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                                  if (picked != null) setDialogState(() => expiryDate = picked);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(labelText: 'Expiry Date'),
                                  child: Text(DateFormat('dd MMM yyyy').format(expiryDate)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx);
                      try {
                        final data = {
                          "device_id": devIdCtrl.text,
                          "imei_no": imeiCtrl.text,
                          "sim_no": simCtrl.text,
                          "model": modelCtrl.text,
                          "operator": operatorCtrl.text,
                          "vehicle_id": selectedVehicleId,
                          "status": status,
                          "installation_date": DateFormat('yyyy-MM-dd').format(installDate),
                          "expiry_date": DateFormat('yyyy-MM-dd').format(expiryDate),
                          "installed_by": installerCtrl.text,
                          "firmware_version": firmwareCtrl.text,
                          "current_location": locationCtrl.text,
                        };
                        await ApiService().put('/transport/gps-devices/${dev['id']}', data);
                        _loadAll();
                      } catch (_) {}
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteGpsDevice(dynamic dev) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Delete GPS Device', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete GPS Device ${dev['device_id']}? This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ApiService().delete('/transport/gps-devices/${dev['id']}');
                  _loadAll();
                } catch (_) {}
              },
              style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════ Dialogs & Actions ═══════════════════
  void _showAddVehicleDialog() {
    final formKey = GlobalKey<FormState>();
    final busNumCtrl = TextEditingController();
    final regNumCtrl = TextEditingController();
    final driverNameCtrl = TextEditingController();
    final driverPhoneCtrl = TextEditingController();
    final routeNameCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final mfgYearCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '52');
    final chassisCtrl = TextEditingController();
    final engineCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final pucCtrl = TextEditingController();
    final permitCtrl = TextEditingController();

    final luggageCtrl = TextEditingController();
    final fuelTankCtrl = TextEditingController();
    final odoCtrl = TextEditingController();
    final firstAidCtrl = TextEditingController();
    final fireExtCtrl = TextEditingController();
    final lastServicedCtrl = TextEditingController();

    final vehicleTypeList = List<String>.from(_dynamicCategoryOptions);
    String vehicleType = vehicleTypeList.isNotEmpty ? vehicleTypeList.first : 'AC Bus';
    if (!vehicleTypeList.contains(vehicleType)) vehicleTypeList.add(vehicleType);
    String fuelType = 'Diesel';
    String liveStatus = 'offline';
    String status = 'Active';

    String selectedDriverId = 'none';
    String transmission = 'Manual';
    String speedGovernor = 'Fitted (Max 60 km/h)';
    String cctvInstalled = '4 HD Cameras (Active)';
    String panicButton = 'Installed & Working';
    String ownershipType = 'School Owned';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add New Vehicle', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 600,
                height: MediaQuery.of(context).size.height * 0.7,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  clipBehavior: Clip.hardEdge,
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: busNumCtrl,
                                decoration: const InputDecoration(labelText: 'Bus Number', hintText: 'e.g. UP16 ET 1234'),
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: regNumCtrl,
                                decoration: const InputDecoration(labelText: 'Registration No.', hintText: 'e.g. UP16 ET 1234'),
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: vehicleType,
                          decoration: const InputDecoration(labelText: 'Vehicle Category / Type'),
                          items: vehicleTypeList.toSet().map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) => setDialogState(() => vehicleType = val!),
                        ),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (context) {
                            final cat = _categories.firstWhere(
                              (c) => (c['name'] ?? '').toString().toLowerCase().trim() == vehicleType.toLowerCase().trim() ||
                                     (c['category_code'] ?? '').toString().toLowerCase().trim() == vehicleType.toLowerCase().trim() ||
                                     (c['id'] ?? '').toString() == vehicleType,
                              orElse: () => null,
                            );
                            final fuel = cat?['fuel_type'] ?? 'Diesel';
                            final cap = cat?['capacity'] ?? 52;
                            final trans = cat?['transmission'] ?? 'Manual';
                            final lug = cat?['luggage_capacity'] ?? '500 L';
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _accent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _accent.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.auto_awesome, size: 16, color: _accent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Category Specs (Auto-Inherited): $fuel  •  $cap Seats  •  $trans  •  Luggage: $lug',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _accent),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: liveStatus,
                                decoration: const InputDecoration(labelText: 'Live Status'),
                                items: ['on_route', 'at_school', 'returning', 'delayed', 'offline', 'idle', 'Arrived', 'On Route', 'Offline', 'In Maintenance'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => liveStatus = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: status,
                                decoration: const InputDecoration(labelText: 'Status'),
                                items: ['Active', 'Inactive', 'In Maintenance'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => status = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: chassisCtrl,
                                decoration: const InputDecoration(labelText: 'Chassis No.'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: engineCtrl,
                                decoration: const InputDecoration(labelText: 'Engine No.'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: modelCtrl,
                                decoration: const InputDecoration(labelText: 'Model / Make'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: mfgYearCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Mfg Year',
                                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                                ),
                                onTap: () async {
                                  final curYear = int.tryParse(mfgYearCtrl.text) ?? DateTime.now().year;
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime(curYear),
                                    firstDate: DateTime(1980),
                                    lastDate: DateTime(2100),
                                    initialDatePickerMode: DatePickerMode.year,
                                  );
                                  if (picked != null) {
                                    setDialogState(() => mfgYearCtrl.text = '${picked.year}');
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: colorCtrl,
                                decoration: const InputDecoration(labelText: 'Color'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: pucCtrl,
                                decoration: const InputDecoration(labelText: 'PUC No.'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: permitCtrl,
                          decoration: const InputDecoration(labelText: 'Permit No.'),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text('Technical & Vehicle Specs', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _accent)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: fuelTankCtrl,
                                decoration: const InputDecoration(labelText: 'Fuel Tank Capacity'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: odoCtrl,
                                decoration: const InputDecoration(labelText: 'Odometer Reading (km)'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: speedGovernor,
                                decoration: const InputDecoration(labelText: 'Speed Governor'),
                                items: ['Fitted (Max 60 km/h)', 'Not Fitted'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => speedGovernor = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: cctvInstalled,
                                decoration: const InputDecoration(labelText: 'CCTV Cameras'),
                                items: ['4 HD Cameras (Active)', 'Installed', 'Not Installed'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => cctvInstalled = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: panicButton,
                                decoration: const InputDecoration(labelText: 'Emergency SOS Button'),
                                items: ['Installed & Working', 'Not Installed'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => panicButton = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: ownershipType,
                                decoration: const InputDecoration(labelText: 'Ownership Type'),
                                items: ['School Owned', 'Leased', 'Contracted'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => ownershipType = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: firstAidCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'First Aid Kit Expiry',
                                  hintText: 'YYYY-MM-DD',
                                  suffixIcon: Icon(Icons.calendar_month_outlined, size: 18),
                                ),
                                onTap: () async {
                                  final cur = DateTime.tryParse(firstAidCtrl.text) ?? DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: cur,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      firstAidCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: fireExtCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Fire Extinguisher Expiry',
                                  hintText: 'YYYY-MM-DD',
                                  suffixIcon: Icon(Icons.calendar_month_outlined, size: 18),
                                ),
                                onTap: () async {
                                  final cur = DateTime.tryParse(fireExtCtrl.text) ?? DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: cur,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      fireExtCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: lastServicedCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Last Serviced Date',
                            hintText: 'YYYY-MM-DD',
                            suffixIcon: Icon(Icons.calendar_month_outlined, size: 18),
                          ),
                          onTap: () async {
                            final cur = DateTime.tryParse(lastServicedCtrl.text) ?? DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: cur,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                lastServicedCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        final payload = <String, dynamic>{
                          'bus_number': busNumCtrl.text,
                          'registration_no': regNumCtrl.text,
                          'vehicle_type': vehicleType,
                          'fuel_type': fuelType,
                          'live_status': liveStatus,
                          'status': status,
                          'total_capacity': int.tryParse(capacityCtrl.text) ?? 52,
                        };
                        if (selectedDriverId != 'none') {
                          payload['driver_id'] = selectedDriverId;
                          if (driverNameCtrl.text.isNotEmpty) payload['driver_name'] = driverNameCtrl.text;
                          if (driverPhoneCtrl.text.isNotEmpty) payload['driver_phone'] = driverPhoneCtrl.text;
                        }
                        if (routeNameCtrl.text.isNotEmpty) payload['route_name'] = routeNameCtrl.text;
                        if (chassisCtrl.text.isNotEmpty) payload['chassis_no'] = chassisCtrl.text;
                        if (engineCtrl.text.isNotEmpty) payload['engine_no'] = engineCtrl.text;
                        if (modelCtrl.text.isNotEmpty) payload['model'] = modelCtrl.text;
                        if (mfgYearCtrl.text.isNotEmpty) payload['year_of_mfg'] = int.tryParse(mfgYearCtrl.text);
                        if (colorCtrl.text.isNotEmpty) payload['color'] = colorCtrl.text;
                        if (pucCtrl.text.isNotEmpty) payload['puc_no'] = pucCtrl.text;
                        if (permitCtrl.text.isNotEmpty) payload['permit_no'] = permitCtrl.text;
                        if (luggageCtrl.text.isNotEmpty) payload['luggage_capacity'] = luggageCtrl.text;
                        if (fuelTankCtrl.text.isNotEmpty) payload['fuel_tank_capacity'] = fuelTankCtrl.text;
                        payload['transmission'] = transmission;
                        if (odoCtrl.text.isNotEmpty) payload['odometer_km'] = int.tryParse(odoCtrl.text);
                        payload['speed_governor'] = speedGovernor;
                        payload['cctv_installed'] = cctvInstalled;
                        payload['panic_button'] = panicButton;
                        if (firstAidCtrl.text.isNotEmpty) payload['first_aid_expiry'] = firstAidCtrl.text;
                        if (fireExtCtrl.text.isNotEmpty) payload['fire_extinguisher_expiry'] = fireExtCtrl.text;
                        if (lastServicedCtrl.text.isNotEmpty) payload['last_serviced_date'] = lastServicedCtrl.text;
                        payload['ownership_type'] = ownershipType;
                        // Remove any null values
                        payload.removeWhere((k, v) => v == null);
                        await ApiService().post('/transport/vehicles', payload);
                        _loadAll();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditVehicleDialog(dynamic v) {
    final formKey = GlobalKey<FormState>();
    final busNumCtrl = TextEditingController(text: v['bus_number']);
    final regNumCtrl = TextEditingController(text: v['registration_no']);
    final driverNameCtrl = TextEditingController(text: v['driver_name']);
    final driverPhoneCtrl = TextEditingController(text: v['driver_phone']);
    final routeNameCtrl = TextEditingController(text: v['route_name']);
    final modelCtrl = TextEditingController(text: v['model']);
    final mfgYearCtrl = TextEditingController(text: v['year_of_mfg'] != null ? '${v['year_of_mfg']}' : '');
    final capacityCtrl = TextEditingController(text: '${v['total_capacity'] ?? 52}');
    final chassisCtrl = TextEditingController(text: v['chassis_no']);
    final engineCtrl = TextEditingController(text: v['engine_no']);
    final colorCtrl = TextEditingController(text: v['color']);
    final pucCtrl = TextEditingController(text: v['puc_no']);
    final permitCtrl = TextEditingController(text: v['permit_no']);

    final luggageCtrl = TextEditingController(text: v['luggage_capacity'] ?? '');
    final fuelTankCtrl = TextEditingController(text: v['fuel_tank_capacity'] ?? '');
    final odoCtrl = TextEditingController(text: v['odometer_km'] != null ? '${v['odometer_km']}' : '');
    final firstAidCtrl = TextEditingController(text: v['first_aid_expiry'] ?? '');
    final fireExtCtrl = TextEditingController(text: v['fire_extinguisher_expiry'] ?? '');
    final lastServicedCtrl = TextEditingController(text: v['last_serviced_date'] ?? '');

    String vehicleType = v['vehicle_type'] ?? 'AC Bus';
    String fuelType = v['fuel_type'] ?? 'Diesel';
    String liveStatus = v['live_status'] ?? 'offline';
    String status = v['status'] ?? 'Active';
    String selectedDriverId = 'none';
    if (v['driver_id'] != null) {
      selectedDriverId = v['driver_id'].toString();
    } else if (v['driver_name'] != null && v['driver_name'].toString().isNotEmpty) {
      for (var d in _drivers) {
        if (d is Map) {
          final dName = (d['name'] ?? '').toString().toLowerCase().trim();
          final dPhone = (d['phone'] ?? '').toString().trim();
          final vName = (v['driver_name'] ?? '').toString().toLowerCase().trim();
          final vPhone = (v['driver_phone'] ?? '').toString().trim();
          if ((vName.isNotEmpty && dName == vName) || (vPhone.isNotEmpty && dPhone == vPhone)) {
            selectedDriverId = d['id'].toString();
            break;
          }
        }
      }
    }
    String transmission = v['transmission'] ?? 'Manual';
    String speedGovernor = v['speed_governor'] ?? 'Fitted (Max 60 km/h)';
    String cctvInstalled = v['cctv_installed'] ?? '4 HD Cameras (Active)';
    String panicButton = v['panic_button'] ?? 'Installed & Working';
    String ownershipType = v['ownership_type'] ?? 'School Owned';

    final vehicleTypeList = List<String>.from(_dynamicCategoryOptions);
    if (!vehicleTypeList.contains(vehicleType)) vehicleTypeList.add(vehicleType);

    final fuelTypeList = ['Diesel', 'Petrol', 'CNG', 'Electric', 'Hybrid'];
    if (!fuelTypeList.contains(fuelType)) fuelTypeList.add(fuelType);

    final liveStatusList = ['on_route', 'at_school', 'returning', 'delayed', 'offline', 'idle', 'Arrived', 'On Route', 'Offline', 'In Maintenance'];
    if (!liveStatusList.contains(liveStatus)) liveStatusList.add(liveStatus);

    final statusList = ['Active', 'Inactive', 'In Maintenance'];
    if (!statusList.contains(status)) statusList.add(status);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Vehicle', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 600,
                height: MediaQuery.of(context).size.height * 0.7,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  clipBehavior: Clip.hardEdge,
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: busNumCtrl,
                                decoration: const InputDecoration(labelText: 'Bus Number'),
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: regNumCtrl,
                                decoration: const InputDecoration(labelText: 'Registration No.'),
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: vehicleType,
                          decoration: const InputDecoration(labelText: 'Vehicle Category / Type'),
                          items: vehicleTypeList.toSet().map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) => setDialogState(() => vehicleType = val!),
                        ),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (context) {
                            final cat = _categories.firstWhere(
                              (c) => (c['name'] ?? '').toString().toLowerCase().trim() == vehicleType.toLowerCase().trim() ||
                                     (c['category_code'] ?? '').toString().toLowerCase().trim() == vehicleType.toLowerCase().trim() ||
                                     (c['id'] ?? '').toString() == vehicleType,
                              orElse: () => null,
                            );
                            final fuel = cat?['fuel_type'] ?? 'Diesel';
                            final cap = cat?['capacity'] ?? 52;
                            final trans = cat?['transmission'] ?? 'Manual';
                            final lug = cat?['luggage_capacity'] ?? '500 L';
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _accent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _accent.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.auto_awesome, size: 16, color: _accent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Category Specs (Auto-Inherited): $fuel  •  $cap Seats  •  $trans  •  Luggage: $lug',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _accent),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: liveStatus,
                                decoration: const InputDecoration(labelText: 'Live Status'),
                                items: liveStatusList.toSet().map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => liveStatus = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: status,
                                decoration: const InputDecoration(labelText: 'Status'),
                                items: statusList.toSet().map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => status = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: chassisCtrl,
                                decoration: const InputDecoration(labelText: 'Chassis No.'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: engineCtrl,
                                decoration: const InputDecoration(labelText: 'Engine No.'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: modelCtrl,
                                decoration: const InputDecoration(labelText: 'Model / Make'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: mfgYearCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Mfg Year',
                                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                                ),
                                onTap: () async {
                                  final curYear = int.tryParse(mfgYearCtrl.text) ?? DateTime.now().year;
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime(curYear),
                                    firstDate: DateTime(1980),
                                    lastDate: DateTime(2100),
                                    initialDatePickerMode: DatePickerMode.year,
                                  );
                                  if (picked != null) {
                                    setDialogState(() => mfgYearCtrl.text = '${picked.year}');
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: colorCtrl,
                                decoration: const InputDecoration(labelText: 'Color'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: pucCtrl,
                                decoration: const InputDecoration(labelText: 'PUC No.'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: permitCtrl,
                          decoration: const InputDecoration(labelText: 'Permit No.'),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text('Technical & Vehicle Specs', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _accent)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: fuelTankCtrl,
                                decoration: const InputDecoration(labelText: 'Fuel Tank Capacity'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: odoCtrl,
                                decoration: const InputDecoration(labelText: 'Odometer Reading (km)'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: speedGovernor,
                                decoration: const InputDecoration(labelText: 'Speed Governor'),
                                items: ['Fitted (Max 60 km/h)', 'Not Fitted'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => speedGovernor = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: cctvInstalled,
                                decoration: const InputDecoration(labelText: 'CCTV Cameras'),
                                items: ['4 HD Cameras (Active)', 'Installed', 'Not Installed'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => cctvInstalled = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: panicButton,
                                decoration: const InputDecoration(labelText: 'Emergency SOS Button'),
                                items: ['Installed & Working', 'Not Installed'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => panicButton = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: ownershipType,
                                decoration: const InputDecoration(labelText: 'Ownership Type'),
                                items: ['School Owned', 'Leased', 'Contracted'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => ownershipType = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: firstAidCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'First Aid Kit Expiry',
                                  hintText: 'YYYY-MM-DD',
                                  suffixIcon: Icon(Icons.calendar_month_outlined, size: 18),
                                ),
                                onTap: () async {
                                  final cur = DateTime.tryParse(firstAidCtrl.text) ?? DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: cur,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      firstAidCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: fireExtCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Fire Extinguisher Expiry',
                                  hintText: 'YYYY-MM-DD',
                                  suffixIcon: Icon(Icons.calendar_month_outlined, size: 18),
                                ),
                                onTap: () async {
                                  final cur = DateTime.tryParse(fireExtCtrl.text) ?? DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: cur,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      fireExtCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: lastServicedCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Last Serviced Date',
                            hintText: 'YYYY-MM-DD',
                            suffixIcon: Icon(Icons.calendar_month_outlined, size: 18),
                          ),
                          onTap: () async {
                            final cur = DateTime.tryParse(lastServicedCtrl.text) ?? DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: cur,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                lastServicedCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        await ApiService().put('/transport/vehicles/${v['id']}', {
                          'bus_number': busNumCtrl.text,
                          'registration_no': regNumCtrl.text,
                          'vehicle_type': vehicleType,
                          'fuel_type': fuelType,
                          'driver_name': selectedDriverId == 'none' ? null : (driverNameCtrl.text.isEmpty ? null : driverNameCtrl.text),
                          'driver_phone': selectedDriverId == 'none' ? null : (driverPhoneCtrl.text.isEmpty ? null : driverPhoneCtrl.text),
                          'driver_id': selectedDriverId == 'none' ? null : selectedDriverId,
                          'route_name': routeNameCtrl.text,
                          'total_capacity': int.tryParse(capacityCtrl.text) ?? 52,
                          'live_status': liveStatus,
                          'status': status,
                          'chassis_no': chassisCtrl.text,
                          'engine_no': engineCtrl.text,
                          'model': modelCtrl.text,
                          'year_of_mfg': int.tryParse(mfgYearCtrl.text) ?? 2022,
                          'color': colorCtrl.text,
                          'puc_no': pucCtrl.text,
                          'permit_no': permitCtrl.text,
                          'luggage_capacity': luggageCtrl.text,
                          'fuel_tank_capacity': fuelTankCtrl.text,
                          'transmission': transmission,
                          'odometer_km': int.tryParse(odoCtrl.text) ?? 45280,
                          'speed_governor': speedGovernor,
                          'cctv_installed': cctvInstalled,
                          'panic_button': panicButton,
                          'first_aid_expiry': firstAidCtrl.text,
                          'fire_extinguisher_expiry': fireExtCtrl.text,
                          'last_serviced_date': lastServicedCtrl.text,
                          'ownership_type': ownershipType,
                        });
                        setState(() {
                          v['bus_number'] = busNumCtrl.text;
                          v['registration_no'] = regNumCtrl.text;
                          v['vehicle_type'] = vehicleType;
                          v['fuel_type'] = fuelType;
                          v['driver_name'] = driverNameCtrl.text;
                          v['driver_phone'] = driverPhoneCtrl.text;
                          v['route_name'] = routeNameCtrl.text;
                          v['total_capacity'] = int.tryParse(capacityCtrl.text) ?? 52;
                          v['live_status'] = liveStatus;
                          v['status'] = status;
                          v['chassis_no'] = chassisCtrl.text;
                          v['engine_no'] = engineCtrl.text;
                          v['model'] = modelCtrl.text;
                          v['year_of_mfg'] = int.tryParse(mfgYearCtrl.text) ?? 2022;
                          v['color'] = colorCtrl.text;
                          v['puc_no'] = pucCtrl.text;
                          v['permit_no'] = permitCtrl.text;
                          v['luggage_capacity'] = luggageCtrl.text;
                          v['fuel_tank_capacity'] = fuelTankCtrl.text;
                          v['transmission'] = transmission;
                          v['odometer_km'] = int.tryParse(odoCtrl.text) ?? 45280;
                          v['speed_governor'] = speedGovernor;
                          v['cctv_installed'] = cctvInstalled;
                          v['panic_button'] = panicButton;
                          v['first_aid_expiry'] = firstAidCtrl.text;
                          v['fire_extinguisher_expiry'] = fireExtCtrl.text;
                          v['last_serviced_date'] = lastServicedCtrl.text;
                          v['ownership_type'] = ownershipType;

                          if (_selectedVehicle != null && _selectedVehicle!['id'] == v['id']) {
                            _selectedVehicle = Map<String, dynamic>.from(v);
                          }
                          final idx = _vehicles.indexWhere((item) => item['id'] == v['id']);
                          if (idx != -1) {
                            _vehicles[idx] = Map<String, dynamic>.from(v);
                          }
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteVehicleDialog(dynamic v) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Delete Vehicle', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete vehicle ${v['registration_no'] ?? ''}? This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  setState(() {
                    _vehicles.removeWhere((item) => item['id'] == v['id']);
                    if (_selectedVehicle?['id'] == v['id']) {
                      _selectedVehicle = _vehicles.isNotEmpty ? _vehicles.first : null;
                    }
                  });
                  await ApiService().delete('/transport/vehicles/${v['id']}');
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }


  void _showAddCategoryDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '52');
    final luggageCtrl = TextEditingController(text: '500 L');

    String vehicleType = 'Bus';
    String fuelType = 'Diesel';
    String transmission = 'Manual';
    String status = 'Active';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add New Category', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  clipBehavior: Clip.none,
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Category Name', hintText: 'e.g. AC Bus (52 Seater)'),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: codeCtrl,
                                decoration: const InputDecoration(labelText: 'Category Code', hintText: 'e.g. ACB-52'),
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: vehicleType,
                                decoration: const InputDecoration(labelText: 'Vehicle Type'),
                                items: ['Bus', 'Mini Bus', 'Van', 'Coach'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => vehicleType = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: fuelType,
                                decoration: const InputDecoration(labelText: 'Fuel Type'),
                                items: ['Diesel', 'Petrol', 'CNG', 'Electric'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => fuelType = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: transmission,
                                decoration: const InputDecoration(labelText: 'Transmission'),
                                items: ['Manual', 'Automatic'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => transmission = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: capCtrl,
                                decoration: const InputDecoration(labelText: 'Seating Capacity'),
                                keyboardType: TextInputType.number,
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: luggageCtrl,
                                decoration: const InputDecoration(labelText: 'Luggage Capacity'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: ['Active', 'Inactive'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) => setDialogState(() => status = val!),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descCtrl,
                          decoration: const InputDecoration(labelText: 'Description'),
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
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        await ApiService().post('/transport/categories', {
                          'name': nameCtrl.text,
                          'category_code': codeCtrl.text,
                          'vehicle_type': vehicleType,
                          'fuel_type': fuelType,
                          'transmission': transmission,
                          'capacity': int.tryParse(capCtrl.text) ?? 52,
                          'luggage_capacity': luggageCtrl.text,
                          'status': status,
                          'description': descCtrl.text,
                        });
                        _loadAll();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditCategoryDialog(dynamic c) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: c['name']);
    final codeCtrl = TextEditingController(text: c['category_code']);
    final descCtrl = TextEditingController(text: c['description']);
    final capCtrl = TextEditingController(text: '${c['capacity'] ?? 52}');
    final luggageCtrl = TextEditingController(text: c['luggage_capacity'] ?? '500 L');

    String vehicleType = c['vehicle_type'] ?? 'Bus';
    String fuelType = c['fuel_type'] ?? 'Diesel';
    String transmission = c['transmission'] ?? 'Manual';
    String status = c['status'] ?? 'Active';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Category', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  clipBehavior: Clip.none,
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Category Name'),
                          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: codeCtrl,
                                decoration: const InputDecoration(labelText: 'Category Code'),
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: vehicleType,
                                decoration: const InputDecoration(labelText: 'Vehicle Type'),
                                items: ['Bus', 'Mini Bus', 'Van', 'Coach'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => vehicleType = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: fuelType,
                                decoration: const InputDecoration(labelText: 'Fuel Type'),
                                items: ['Diesel', 'Petrol', 'CNG', 'Electric'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => fuelType = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: transmission,
                                decoration: const InputDecoration(labelText: 'Transmission'),
                                items: ['Manual', 'Automatic'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setDialogState(() => transmission = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: capCtrl,
                                decoration: const InputDecoration(labelText: 'Seating Capacity'),
                                keyboardType: TextInputType.number,
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: luggageCtrl,
                                decoration: const InputDecoration(labelText: 'Luggage Capacity'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: ['Active', 'Inactive'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) => setDialogState(() => status = val!),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descCtrl,
                          decoration: const InputDecoration(labelText: 'Description'),
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
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        await ApiService().put('/transport/categories/${c['id']}', {
                          'name': nameCtrl.text,
                          'category_code': codeCtrl.text,
                          'vehicle_type': vehicleType,
                          'fuel_type': fuelType,
                          'transmission': transmission,
                          'capacity': int.tryParse(capCtrl.text) ?? 52,
                          'luggage_capacity': luggageCtrl.text,
                          'status': status,
                          'description': descCtrl.text,
                        });
                        _loadAll();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteCategoryDialog(dynamic c) {
    final assignedVehiclesCount = _getCategoryVehicleCount(c);
    if (assignedVehiclesCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text('Cannot Delete Category', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _red)),
            content: Text(
              'Category "${c['name'] ?? ''}" has $assignedVehiclesCount vehicle(s) currently assigned to it. '
              'Categories with assigned vehicles cannot be deleted. Please reassign or remove the vehicles first.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Delete Category', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete category ${c['name'] ?? ''}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService().delete('/transport/categories/${c['id']}');
                  _loadAll();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDropdown(String hint, String value, List<String> items, Function(String?) onChanged, {double? width}) {
    final list = List<String>.from(items);
    if (value != 'All' && !list.contains(value)) {
      list.add(value);
    }
    return Container(
      width: width,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: width != null,
          value: (value == 'All' || !list.contains(value)) ? null : value,
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 13, color: _textSecondary), overflow: TextOverflow.ellipsis),
          items: list.map((i) => DropdownMenuItem<String>(value: i, child: Text(i, style: GoogleFonts.inter(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _pct(int part, int total) {
    if (total == 0) return '0%';
    return '${(part / total * 100).toStringAsFixed(1)}%';
  }

  void _showLiveTrackingMapDialog(dynamic doc) {
    final latLng = _parseLocation(doc['current_location']);
    
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: 800,
            height: 600,
            child: Column(
              children: [
                // Dialog Title/Header bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.map, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Live GPS Tracking – ${doc['device_id']}',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              'Vehicle: ${doc['bus_routes']?['registration_no'] ?? doc['bus_routes']?['bus_number'] ?? 'Unassigned'} • Status: ${doc['status']}',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                
                // Map Area
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: latLng,
                          initialZoom: 15.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.shamiit.edu',
                            tileProvider: CancellableNetworkTileProvider(),
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: latLng,
                                width: 80,
                                height: 80,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    _PulseAnimationRing(),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: _accent,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                                        ],
                                      ),
                                      child: const Icon(Icons.navigation, color: Colors.white, size: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      // Floating Stats Card in map
                      Positioned(
                        top: 20,
                        left: 20,
                        child: Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Container(
                            width: 240,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Real-time Metrics', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
                                const Divider(height: 16),
                                _buildMapMetricRow('Speed', '42 km/h'),
                                _buildMapMetricRow('Battery', '${doc['battery_level'] ?? 100}%'),
                                _buildMapMetricRow('Signal', '${doc['signal_strength_pct'] ?? 100}%'),
                                _buildMapMetricRow('Last Ping', '2 mins ago'),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(6)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.green, size: 14),
                                      const SizedBox(width: 6),
                                      Text('Active & Sending Pings', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green[800])),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
  }

  Widget _buildMapMetricRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
          Text(val, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
        ],
      ),
    );
  }

  LatLng _parseLocation(String? locStr) {
    if (locStr == null) return const LatLng(28.6129, 77.3910);
    try {
      final regEx = RegExp(r'(-?\d+\.\d+)');
      final matches = regEx.allMatches(locStr).toList();
      if (matches.length >= 2) {
        final lat = double.parse(matches[0].group(0)!);
        final lng = double.parse(matches[1].group(0)!);
        return LatLng(lat, lng);
      }
    } catch (_) {}
    return const LatLng(28.6129, 77.3910);
  }

  void _showDeviceHistoryDialog(dynamic doc) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('GPS History Logs – ${doc['device_id']}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            height: 400,
            child: ListView.builder(
              itemCount: 8,
              itemBuilder: (context, index) {
                final time = DateTime.now().subtract(Duration(minutes: index * 15));
                final speedStr = index == 0 ? '0 km/h (Stopped)' : '${40 + index * 3} km/h';
                final signalPct = index == 0 ? '0%' : '${80 - index * 2}%';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Icon(index == 0 ? Icons.stop_circle : Icons.arrow_circle_up, color: index == 0 ? _red : _green, size: 20),
                          if (index < 7)
                            Container(width: 2, height: 40, color: Colors.grey[300]),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(index == 0 ? 'Current Position' : 'Ping #${8 - index}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
                                Text(DateFormat('hh:mm a').format(time), style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Location: Sector 62, Noida (28.6129° N, 77.3910° E)', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                            const SizedBox(height: 2),
                            Text('Speed: $speedStr • Signal: $signalPct • Battery: ${doc['battery_level'] ?? 100}%', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _PulseAnimationRing extends StatefulWidget {
  @override
  State<_PulseAnimationRing> createState() => _PulseAnimationRingState();
}

class _PulseAnimationRingState extends State<_PulseAnimationRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 20.0 + (_controller.value * 60.0),
          height: 20.0 + (_controller.value * 60.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4F46E5).withValues(alpha: 1.0 - _controller.value),
            border: Border.all(
              color: const Color(0xFF4F46E5).withValues(alpha: 1.0 - _controller.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════ Line Chart Painter ═══════════════════
class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF22C55E)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF22C55E).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;

    final points = [
      Offset(0, size.height * 0.7),
      Offset(size.width * 0.16, size.height * 0.5),
      Offset(size.width * 0.33, size.height * 0.6),
      Offset(size.width * 0.5, size.height * 0.2),
      Offset(size.width * 0.66, size.height * 0.55),
      Offset(size.width * 0.83, size.height * 0.35),
      Offset(size.width, size.height * 0.3),
    ];

    // Draw horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final fillPath = Path()
      ..moveTo(points[0].dx, size.height)
      ..lineTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      fillPath.lineTo(points[i].dx, points[i].dy);
    }
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw point dots
    final dotPaint = Paint()..color = const Color(0xFF22C55E);
    final dotBg = Paint()..color = Colors.white;
    for (var pt in points) {
      canvas.drawCircle(pt, 6, dotPaint);
      canvas.drawCircle(pt, 3, dotBg);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
