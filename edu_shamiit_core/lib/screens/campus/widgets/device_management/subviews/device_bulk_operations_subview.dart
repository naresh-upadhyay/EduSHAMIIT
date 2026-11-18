// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import '../../../models/device_management_models.dart';

/// Enterprise Bulk Operations Subview matching canonical Reference Design (Image 8)
/// Campus Management -> Device Management & Control -> Bulk Operations
class DeviceBulkOperationsSubview extends StatefulWidget {
  final String? apiBaseUrl;
  final bool initialIsLoading;
  final BulkOperationOverview? initialOverview;
  final List<BulkTargetDeviceItem>? initialDevices;
  final List<BulkRecentOperationItem>? initialRecentOperations;
  final List<BulkOperationTemplateItem>? initialTemplates;

  const DeviceBulkOperationsSubview({
    super.key,
    this.apiBaseUrl,
    this.initialIsLoading = false,
    this.initialOverview,
    this.initialDevices,
    this.initialRecentOperations,
    this.initialTemplates,
  });

  @override
  State<DeviceBulkOperationsSubview> createState() =>
      _DeviceBulkOperationsSubviewState();
}

class _DeviceBulkOperationsSubviewState
    extends State<DeviceBulkOperationsSubview> {
  String get _baseUrl => (widget.apiBaseUrl != null &&
          !widget.apiBaseUrl!.contains('localhost:8082'))
      ? widget.apiBaseUrl!
      : '${AppConfig.apiBaseUrl}/v1/devices';

  Future<Map<String, String>> _getHeaders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
    } catch (_) {
      return {'Content-Type': 'application/json', 'Accept': 'application/json'};
    }
  }

  bool _isLoading = true;

  // KPI Metrics
  BulkOperationOverview _overview = const BulkOperationOverview();

  // Wizard State
  final int _currentStep =
      1; // 1: Select Targets, 2: Choose Operation, 3: Configure & Execute
  String _selectedTargetTab =
      'Devices'; // 'Devices', 'Groups', 'Locations', 'By Device Type'

  // Target Filters
  String _selectedBuilding = 'All Buildings';
  String _selectedFloor = 'All Floors';
  String _selectedRoom = 'All Rooms';
  String _selectedDeviceType = 'All Types';
  String _selectedStatus = 'All Status';
  String _selectedProfile = 'All Profiles';
  final TextEditingController _searchController = TextEditingController();

  // Cascading Location & Filter Lookup Lists
  List<Map<String, dynamic>> _buildingsList = [];
  List<Map<String, dynamic>> _floorsList = [];
  List<Map<String, dynamic>> _roomsList = [];
  List<Map<String, dynamic>> _deviceTypesList = [];
  List<Map<String, dynamic>> _profilesList = [];
  List<Map<String, dynamic>> _groupsList = [];
  List<Map<String, dynamic>> _scenesList = [];

  String? _selectedBuildingId;
  String? _selectedFloorId;
  String? _selectedRoomId;

  // Sorting & Database Pagination
  String _sortBy = 'device_name';
  String _sortOrder = 'asc';
  int _totalDevicesCount = 0;
  int _totalPages = 1;

  // Selected Devices in Table
  final Set<String> _selectedDeviceIds = {};
  List<BulkTargetDeviceItem> _devices = [];

  // Operation Choice
  String _selectedOperation =
      'Control'; // 'Control', 'Configuration', 'Firmware Update', 'Assign to Group', 'Apply Profile', 'Schedule', 'Run Scene'

  // 1. Control Parameters
  String _controlSubAction =
      'Turn ON'; // 'Turn ON', 'Turn OFF', 'Toggle', 'Set Value'
  double _setValueTemperature = 24.0;
  double _setValueBrightness = 80.0;
  String _setValueFanSpeed = 'Medium';
  bool _controlStaggered = false;

  // 2. Schedule Parameters
  String _scheduleType =
      'One-Time Execution'; // 'One-Time Execution' | 'Recurring Schedule'
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 18, minute: 0);
  String _scheduleRecurrence = 'Daily at scheduled time';
  String _scheduleAction = 'Turn OFF all devices';

  // 3. Configuration Parameters
  String _configHeartbeatInterval = '60s';
  String _configTelemetryFreq = 'Real-time';
  String _configLogLevel = 'Info';
  bool _configEcoMode = true;

  // 4. Firmware Update Parameters
  String _firmwareVersion = 'v2.4.2-stable (Recommended)';
  String _firmwareRolloutStrategy = 'Canary Rollout (10% first)';
  bool _firmwareAutoRollback = true;
  bool _firmwareRebootAfter = true;

  // 5. Assign to Group Parameters
  String _groupAction = 'Add to Group';
  String _targetGroupName = 'Classroom A1 AV Group';

  // 6. Apply Profile Parameters
  String _targetProfileName = 'Default Classroom Standard';
  bool _profileOverwrite = false;

  // 7. Run Scene Parameters
  String _selectedScene = 'Morning Campus Startup';
  String _sceneTransitionSpeed = 'Smooth Fade (3s)';

  // Common Execution Constraints
  bool _applyToSupportedOnly = true;
  bool _skipOffline = true;

  // Bottom Cards Data
  List<BulkRecentOperationItem> _recentOperations = [];
  List<BulkOperationTemplateItem> _templates = [];

  // Pagination
  int _currentPage = 1;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    if (widget.initialOverview != null ||
        widget.initialDevices != null ||
        (widget.apiBaseUrl != null && widget.apiBaseUrl!.contains('mock'))) {
      _isLoading = widget.initialIsLoading;
      if (widget.initialOverview != null) {
        _overview = widget.initialOverview!;
      } else {
        _seedFallbackData();
      }
      if (widget.initialDevices != null) {
        _devices = List.from(widget.initialDevices!);
        _totalDevicesCount = _devices.length;
        _totalPages = 1;
      }
      if (widget.initialRecentOperations != null) {
        _recentOperations = List.from(widget.initialRecentOperations!);
      }
      if (widget.initialTemplates != null) {
        _templates = List.from(widget.initialTemplates!);
      }
    } else {
      _loadInitialData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Cascading Locations (Strict database tables)
      await _fetchCascadingLocations();

      // 2. Fetch Overview KPIs, Recent Ops and Templates
      final headers = await _getHeaders();
      final overviewRes = await http.get(
          Uri.parse('$_baseUrl/bulk-operations/overview'),
          headers: headers);
      if (overviewRes.statusCode == 200) {
        final data = jsonDecode(overviewRes.body) as Map<String, dynamic>;
        if (data['kpis'] != null) {
          _overview = BulkOperationOverview.fromJson(data['kpis']);
        }
        if (data['recent_operations'] is List) {
          _recentOperations = (data['recent_operations'] as List)
              .map((e) => BulkRecentOperationItem.fromJson(e))
              .toList();
        }
        if (data['templates'] is List) {
          _templates = (data['templates'] as List)
              .map((e) => BulkOperationTemplateItem.fromJson(e))
              .toList();
        }
      }

      // 3. Fetch Initial Target Devices from Database
      await _fetchTargetDevices();
    } catch (e) {
      debugPrint('[Bulk Operations Initial Load Error]: $e');
      if (_devices.isEmpty) {
        _seedFallbackData();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// True cascading locations from PostgreSQL fn_bulk_cascading_locations
  Future<void> _fetchCascadingLocations({String? buildingId, String? floorId}) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{};
      if (buildingId != null && buildingId.isNotEmpty) {
        queryParams['building_id'] = buildingId;
      }
      if (floorId != null && floorId.isNotEmpty) {
        queryParams['floor_id'] = floorId;
      }
      final uri = Uri.parse('$_baseUrl/bulk-operations/cascading-locations')
          .replace(queryParameters: queryParams);
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            if (buildingId == null && floorId == null) {
              _buildingsList =
                  List<Map<String, dynamic>>.from(data['buildings'] ?? []);
              _deviceTypesList =
                  List<Map<String, dynamic>>.from(data['device_types'] ?? []);
              _profilesList =
                  List<Map<String, dynamic>>.from(data['profiles'] ?? []);
              _groupsList =
                  List<Map<String, dynamic>>.from(data['groups'] ?? []);
              _scenesList =
                  List<Map<String, dynamic>>.from(data['scenes'] ?? []);
            }
            _floorsList =
                List<Map<String, dynamic>>.from(data['floors'] ?? []);
            _roomsList =
                List<Map<String, dynamic>>.from(data['rooms'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('[Cascading Locations Error]: $e');
    }
  }

  void _onBuildingChanged(String? val) {
    if (val == null || val == _selectedBuilding) return;
    setState(() {
      _selectedBuilding = val;
      if (val == 'All Buildings') {
        _selectedBuildingId = null;
      } else {
        final found = _buildingsList.firstWhere(
          (b) => b['name']?.toString() == val,
          orElse: () => {'id': null},
        );
        _selectedBuildingId = found['id']?.toString();
      }
      _selectedFloor = 'All Floors';
      _selectedFloorId = null;
      _selectedRoom = 'All Rooms';
      _selectedRoomId = null;
      _currentPage = 1;
    });
    _fetchCascadingLocations(buildingId: _selectedBuildingId);
    _fetchTargetDevices();
  }

  void _onFloorChanged(String? val) {
    if (val == null || val == _selectedFloor) return;
    setState(() {
      _selectedFloor = val;
      if (val == 'All Floors') {
        _selectedFloorId = null;
      } else {
        final found = _floorsList.firstWhere(
          (f) => f['name']?.toString() == val,
          orElse: () => {'id': null},
        );
        _selectedFloorId = found['id']?.toString();
      }
      _selectedRoom = 'All Rooms';
      _selectedRoomId = null;
      _currentPage = 1;
    });
    _fetchCascadingLocations(
        buildingId: _selectedBuildingId, floorId: _selectedFloorId);
    _fetchTargetDevices();
  }

  void _onRoomChanged(String? val) {
    if (val == null || val == _selectedRoom) return;
    setState(() {
      _selectedRoom = val;
      if (val == 'All Rooms') {
        _selectedRoomId = null;
      } else {
        final found = _roomsList.firstWhere(
          (r) => r['name']?.toString() == val,
          orElse: () => {'id': null},
        );
        _selectedRoomId = found['id']?.toString();
      }
      _currentPage = 1;
    });
    _fetchTargetDevices();
  }

  void _onDeviceTypeChanged(String? val) {
    if (val == null || val == _selectedDeviceType) return;
    setState(() {
      _selectedDeviceType = val;
      _currentPage = 1;
    });
    _fetchTargetDevices();
  }

  void _onStatusChanged(String? val) {
    if (val == null || val == _selectedStatus) return;
    setState(() {
      _selectedStatus = val;
      _currentPage = 1;
    });
    _fetchTargetDevices();
  }

  void _onProfileChanged(String? val) {
    if (val == null || val == _selectedProfile) return;
    setState(() {
      _selectedProfile = val;
      _currentPage = 1;
    });
    _fetchTargetDevices();
  }

  void _toggleSort(String column) {
    setState(() {
      if (_sortBy == column) {
        _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
      } else {
        _sortBy = column;
        _sortOrder = 'asc';
      }
      _currentPage = 1;
    });
    _fetchTargetDevices();
  }

  List<String> get _buildingDropdownItems {
    final set = <String>{'All Buildings'};
    for (final b in _buildingsList) {
      final name = b['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) set.add(name);
    }
    return set.toList();
  }

  List<String> get _floorDropdownItems {
    final set = <String>{'All Floors'};
    // Cascading rule: show floors only if a specific building is selected
    if (_selectedBuilding != 'All Buildings' && _selectedBuildingId != null) {
      for (final f in _floorsList) {
        final name = f['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) set.add(name);
      }
    }
    return set.toList();
  }

  List<String> get _roomDropdownItems {
    final set = <String>{'All Rooms'};
    // Cascading rule: show rooms only if a specific building is selected
    if (_selectedBuilding != 'All Buildings' && _selectedBuildingId != null) {
      for (final r in _roomsList) {
        final name = r['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) set.add(name);
      }
    }
    return set.toList();
  }

  List<String> get _deviceTypeDropdownItems {
    final set = <String>{'All Types'};
    for (final d in _deviceTypesList) {
      final name = d['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) set.add(name);
    }
    return set.toList();
  }

  List<String> get _statusDropdownItems =>
      const ['All Status', 'Online', 'Offline'];

  List<String> get _profileDropdownItems {
    final set = <String>{'All Profiles'};
    for (final p in _profilesList) {
      final name = p['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) set.add(name);
    }
    return set.toList();
  }

  List<String> get _groupDropdownItems {
    final set = <String>{};
    for (final g in _groupsList) {
      final name = g['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) set.add(name);
    }
    if (set.isEmpty) {
      return const [
        'Classroom A1 AV Group',
        'Academic Block Lighting Core',
        'HVAC Energy Optimization Group',
        'Corridor Safety & Security',
        'Lab Computer & IoT Stations',
        'Auditorium Multimedia Rack',
      ];
    }
    return set.toList();
  }

  List<String> get _targetProfileDropdownItems {
    final set = <String>{};
    for (final p in _profilesList) {
      final name = p['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) set.add(name);
    }
    if (set.isEmpty) {
      return const [
        'Default Classroom Standard',
        'Energy Saver Profile',
        'High Performance Lab Profile',
        'Auditorium Event Setup',
        'Night / Lockdown Profile',
      ];
    }
    return set.toList();
  }

  List<String> get _sceneDropdownItems {
    final set = <String>{};
    for (final s in _scenesList) {
      final name = s['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) set.add(name);
    }
    if (set.isEmpty) {
      return const [
        'Morning Campus Startup',
        'Class In Session Mode',
        'Lunch Break Low Power',
        'Presentation / Movie Mode',
        'Emergency Evacuation Lighting',
        'Campus Night Lockdown',
      ];
    }
    return set.toList();
  }

  void _seedFallbackData() {
    _isLoading = false;
    _overview = const BulkOperationOverview(
      totalDevices: 8742,
      onlineDevices: 8342,
      onlinePercentage: 95.4,
      offlineDevices: 400,
      offlinePercentage: 4.6,
      selectedDevices: 4,
      selectedGroups: 0,
      selectedLocations: 0,
      affectedDevices: 4,
      operationsRunning: 1,
      operationsCompletedToday: 3,
      failedCommands: 0,
    );

    _devices = [
      const BulkTargetDeviceItem(
        id: 'dev-1',
        deviceName: 'Classroom Lights (A1-101)',
        deviceCode: 'LIGHT-A1-101',
        typeName: 'Lighting',
        typeCode: 'lighting',
        location: 'Academic Block (A) > A1-101',
        isOnline: true,
        powerState: true,
      ),
      const BulkTargetDeviceItem(
        id: 'dev-2',
        deviceName: 'Classroom Lights (A1-102)',
        deviceCode: 'LIGHT-A1-102',
        typeName: 'Lighting',
        typeCode: 'lighting',
        location: 'Academic Block (A) > A1-102',
        isOnline: true,
        powerState: true,
      ),
      const BulkTargetDeviceItem(
        id: 'dev-3',
        deviceName: 'Classroom Lights (A1-103)',
        deviceCode: 'LIGHT-A1-103',
        typeName: 'Lighting',
        typeCode: 'lighting',
        location: 'Academic Block (A) > A1-103',
        isOnline: true,
        powerState: true,
      ),
      const BulkTargetDeviceItem(
        id: 'dev-4',
        deviceName: 'Classroom Lights (A1-104)',
        deviceCode: 'LIGHT-A1-104',
        typeName: 'Lighting',
        typeCode: 'lighting',
        location: 'Academic Block (A) > A1-104',
        isOnline: true,
        powerState: true,
      ),
      const BulkTargetDeviceItem(
        id: 'dev-5',
        deviceName: 'AC Unit (A1-101)',
        deviceCode: 'AC-A1-101',
        typeName: 'HVAC (AC)',
        typeCode: 'ac',
        location: 'Academic Block (A) > A1-101',
        isOnline: true,
        powerState: true,
      ),
      const BulkTargetDeviceItem(
        id: 'dev-6',
        deviceName: 'AC Unit (A1-102)',
        deviceCode: 'AC-A1-102',
        typeName: 'HVAC (AC)',
        typeCode: 'ac',
        location: 'Academic Block (A) > A1-102',
        isOnline: true,
        powerState: true,
      ),
      const BulkTargetDeviceItem(
        id: 'dev-7',
        deviceName: 'Projector (A1-101)',
        deviceCode: 'PRJ-A1-101',
        typeName: 'Projector',
        typeCode: 'projector',
        location: 'Academic Block (A) > A1-101',
        isOnline: true,
        powerState: true,
      ),
      const BulkTargetDeviceItem(
        id: 'dev-8',
        deviceName: 'CCTV (Corridor-A1)',
        deviceCode: 'CAM-A1-101',
        typeName: 'CCTV',
        typeCode: 'cctv_camera',
        location: 'Academic Block (A) > Corridor',
        isOnline: true,
        powerState: true,
      ),
    ];

    _selectedDeviceIds.clear();
    _selectedDeviceIds.addAll(['dev-1', 'dev-2', 'dev-3', 'dev-4']);
    _totalDevicesCount = _devices.length;
    _totalPages = 1;

    _recentOperations = [
      const BulkRecentOperationItem(
        id: 'op-1',
        operationCode: 'BLK-2025-0012',
        name: 'Turn OFF (Control)',
        operationType: 'control',
        targetScope: '12 devices (Classroom A1)',
        status: 'Success',
        initiatedBy: 'Admin',
        result: '✓ 12/12 completed',
        totalDevices: 12,
        successfulDevices: 12,
        createdAt: '12 Jan 2025, 02:30 PM',
      ),
      const BulkRecentOperationItem(
        id: 'op-2',
        operationCode: 'BLK-2025-0011',
        name: 'Apply Profile (Default Lighting)',
        operationType: 'apply_profile',
        targetScope: '48 devices (Academic Block)',
        status: 'Success',
        initiatedBy: 'Admin',
        result: '✓ 48/48 completed',
        totalDevices: 48,
        successfulDevices: 48,
        createdAt: '12 Jan 2025, 11:20 AM',
      ),
      const BulkRecentOperationItem(
        id: 'op-3',
        operationCode: 'BLK-2025-0010',
        name: 'Firmware Update (v2.4.1)',
        operationType: 'firmware_update',
        targetScope: '18 devices (CCTV)',
        status: 'In Progress',
        initiatedBy: 'Admin',
        result: '↻ 6/18 completed',
        totalDevices: 18,
        successfulDevices: 6,
        createdAt: '11 Jan 2025, 06:45 PM',
      ),
      const BulkRecentOperationItem(
        id: 'op-4',
        operationCode: 'BLK-2025-0009',
        name: 'Assign to Group (Classroom Lights)',
        operationType: 'assign_group',
        targetScope: '24 devices',
        status: 'Success',
        initiatedBy: 'Admin',
        result: '✓ 24/24 completed',
        totalDevices: 24,
        successfulDevices: 24,
        createdAt: '11 Jan 2025, 09:30 AM',
      ),
    ];

    _templates = [
      const BulkOperationTemplateItem(
        id: 'tmpl-1',
        templateName: 'Turn On All Classroom Lights',
        operationType: 'control',
        targetType: 'by_device_type',
        icon: 'gps_fixed',
        color: '#2563EB',
      ),
      const BulkOperationTemplateItem(
        id: 'tmpl-2',
        templateName: 'Set AC to 24°C (Academic Block)',
        operationType: 'control',
        targetType: 'locations',
        icon: 'tune',
        color: '#0284C7',
      ),
      const BulkOperationTemplateItem(
        id: 'tmpl-3',
        templateName: 'Update CCTV Firmware (v2.4.1)',
        operationType: 'firmware_update',
        targetType: 'by_device_type',
        icon: 'memory',
        color: '#8B5CF6',
      ),
      const BulkOperationTemplateItem(
        id: 'tmpl-4',
        templateName: 'Apply Standard Lighting Profile',
        operationType: 'apply_profile',
        targetType: 'by_device_type',
        icon: 'lightbulb_outline',
        color: '#EAB308',
      ),
    ];

    _buildingsList = [
      {'id': 'b-1', 'name': 'Academic Block (A)', 'code': 'B1'},
      {'id': 'b-2', 'name': 'Science Block (B)', 'code': 'B2'},
      {'id': 'b-3', 'name': 'Admin Block', 'code': 'B3'},
      {'id': 'b-4', 'name': 'Auditorium Block', 'code': 'B4'},
      {'id': 'b-5', 'name': 'Library Block', 'code': 'B5'},
      {'id': 'b-6', 'name': 'Sports Complex', 'code': 'B6'},
    ];
    _floorsList = [
      {'id': 'f-1', 'name': 'Ground Floor', 'building_id': 'b-1'},
      {'id': 'f-2', 'name': 'First Floor', 'building_id': 'b-1'},
      {'id': 'f-3', 'name': 'Second Floor', 'building_id': 'b-1'},
      {'id': 'f-4', 'name': 'Third Floor', 'building_id': 'b-1'},
    ];
    _roomsList = [
      {'id': 'r-1', 'name': 'Room A1-101', 'floor_id': 'f-1', 'building_id': 'b-1'},
      {'id': 'r-2', 'name': 'Room A1-102', 'floor_id': 'f-1', 'building_id': 'b-1'},
      {'id': 'r-3', 'name': 'Room A1-103', 'floor_id': 'f-1', 'building_id': 'b-1'},
      {'id': 'r-4', 'name': 'Room A1-104', 'floor_id': 'f-1', 'building_id': 'b-1'},
    ];
    _deviceTypesList = [
      {'id': 'dt-1', 'name': 'Lighting', 'code': 'lighting'},
      {'id': 'dt-2', 'name': 'HVAC (AC)', 'code': 'hvac'},
      {'id': 'dt-3', 'name': 'Projector', 'code': 'projector'},
      {'id': 'dt-4', 'name': 'CCTV', 'code': 'cctv_camera'},
      {'id': 'dt-5', 'name': 'Fan', 'code': 'fan'},
      {'id': 'dt-6', 'name': 'Smart Plug', 'code': 'smart_plug'},
    ];
    _profilesList = [
      {'id': 'p-1', 'name': 'Classroom Lighting (Block A)'},
      {'id': 'p-2', 'name': 'Eco Air Conditioning (24°C)'},
      {'id': 'p-3', 'name': 'Night Energy Shutdown'},
      {'id': 'p-4', 'name': 'Examination Silence Profile'},
    ];
    _groupsList = [
      {'id': 'g-1', 'name': 'Classroom Lights'},
      {'id': 'g-2', 'name': 'Academic AC Units'},
      {'id': 'g-3', 'name': 'Corridor Security CCTVs'},
      {'id': 'g-4', 'name': 'Auditorium AV Group'},
    ];
    _scenesList = [
      {'id': 's-1', 'name': 'Morning Campus Startup'},
      {'id': 's-2', 'name': 'Night Shutdown'},
      {'id': 's-3', 'name': 'Classroom Mode'},
      {'id': 's-4', 'name': 'Examination Mode'},
    ];
  }

  Future<void> _fetchTargetDevices() async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'page_size': _rowsPerPage.toString(),
        'sort_by': _sortBy,
        'sort_order': _sortOrder,
      };

      if (_selectedBuildingId != null && _selectedBuildingId!.isNotEmpty) {
        queryParams['building_id'] = _selectedBuildingId!;
      } else if (_selectedBuilding != 'All Buildings') {
        queryParams['building'] = _selectedBuilding;
      }

      if (_selectedFloorId != null && _selectedFloorId!.isNotEmpty) {
        queryParams['floor_id'] = _selectedFloorId!;
      } else if (_selectedFloor != 'All Floors') {
        queryParams['floor'] = _selectedFloor;
      }

      if (_selectedRoomId != null && _selectedRoomId!.isNotEmpty) {
        queryParams['room_id'] = _selectedRoomId!;
      } else if (_selectedRoom != 'All Rooms') {
        queryParams['room'] = _selectedRoom;
      }

      if (_selectedDeviceType != 'All Types') {
        queryParams['device_type'] = _selectedDeviceType;
      }

      if (_selectedStatus != 'All Status') {
        queryParams['status'] = _selectedStatus.toLowerCase();
      }

      if (_selectedProfile != 'All Profiles') {
        queryParams['profile'] = _selectedProfile;
      }

      final search = _searchController.text.trim();
      if (search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse('$_baseUrl/bulk-operations/targets')
          .replace(queryParameters: queryParams);
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['devices'] is List) {
          final list = (data['devices'] as List)
              .map((e) => BulkTargetDeviceItem.fromJson(e))
              .toList();
          if (mounted) {
            setState(() {
              _devices = list;
              _totalDevicesCount = data['total'] ?? list.length;
              _totalPages = (data['total_pages'] is int && data['total_pages'] > 0)
                  ? data['total_pages'] as int
                  : math.max(
                      1,
                      ((data['total'] ?? list.length) / _rowsPerPage).ceil());
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('[Fetch Target Devices Error]: $e');
    }
  }

  Map<String, dynamic> _buildCurrentActionConfig() {
    switch (_selectedOperation) {
      case 'Schedule':
        return {
          'schedule_type': _scheduleType,
          'scheduled_date':
              '${_scheduledDate.year}-${_scheduledDate.month.toString().padLeft(2, '0')}-${_scheduledDate.day.toString().padLeft(2, '0')}',
          'scheduled_time':
              '${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}',
          'recurrence': _scheduleType == 'Recurring Schedule'
              ? _scheduleRecurrence
              : 'None',
          'scheduled_action': _scheduleAction,
          'operation_type': _scheduleAction,
        };
      case 'Firmware Update':
        return {
          'firmware_version': _firmwareVersion,
          'rollout_strategy': _firmwareRolloutStrategy,
          'auto_rollback': _firmwareAutoRollback,
          'reboot_after_update': _firmwareRebootAfter,
          'operation_type': 'Firmware OTA Flash',
        };
      case 'Assign to Group':
        return {
          'group_action': _groupAction,
          'group_name': _targetGroupName,
          'operation_type': '$_groupAction: $_targetGroupName',
        };
      case 'Apply Profile':
        return {
          'profile_name': _targetProfileName,
          'overwrite_settings': _profileOverwrite,
          'operation_type': 'Apply Profile: $_targetProfileName',
        };
      case 'Run Scene':
        return {
          'scene_name': _selectedScene,
          'transition_speed': _sceneTransitionSpeed,
          'operation_type': 'Run Scene: $_selectedScene',
        };
      case 'Configuration':
        return {
          'heartbeat_interval': _configHeartbeatInterval,
          'telemetry_frequency': _configTelemetryFreq,
          'log_level': _configLogLevel,
          'eco_mode': _configEcoMode,
          'operation_type': 'Configure Parameters',
        };
      case 'Control':
      default:
        return {
          'operation_type': _controlSubAction,
          if (_controlSubAction == 'Set Value') ...{
            'temperature': _setValueTemperature,
            'brightness': _setValueBrightness,
            'fan_speed': _setValueFanSpeed,
          },
          'staggered_execution': _controlStaggered,
        };
    }
  }

  String _getOperationSummaryText() {
    switch (_selectedOperation) {
      case 'Schedule':
        final timeStr =
            '${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}';
        final dateStr =
            '${_scheduledDate.day} ${_getMonthName(_scheduledDate.month)} ${_scheduledDate.year}';
        return _scheduleType == 'One-Time Execution'
            ? '$_scheduleAction at $timeStr ($dateStr)'
            : '$_scheduleAction (Recurring: $_scheduleRecurrence at $timeStr)';
      case 'Firmware Update':
        return 'OTA Flash to $_firmwareVersion ($_firmwareRolloutStrategy)';
      case 'Assign to Group':
        return '$_groupAction -> $_targetGroupName';
      case 'Apply Profile':
        return 'Apply Profile: $_targetProfileName (${_profileOverwrite ? "Overwrite" : "Merge"})';
      case 'Run Scene':
        return 'Trigger Scene: $_selectedScene ($_sceneTransitionSpeed)';
      case 'Configuration':
        return 'Update Parameters (HB: $_configHeartbeatInterval, Telemetry: $_configTelemetryFreq, Log: $_configLogLevel)';
      case 'Control':
      default:
        if (_controlSubAction == 'Set Value') {
          return 'Set Value (Temp: ${_setValueTemperature.toInt()}°C, Brightness: ${_setValueBrightness.toInt()}%)';
        }
        return '$_controlSubAction (${_controlSubAction == "Turn ON" ? "Power On" : "Power Off"})';
    }
  }

  String _getDetectedTypesSummary() {
    if (_selectedDeviceIds.isEmpty) return 'None (0)';
    final selectedDevs =
        _devices.where((d) => _selectedDeviceIds.contains(d.id)).toList();
    final counts = <String, int>{};
    for (final d in selectedDevs) {
      counts[d.typeName] = (counts[d.typeName] ?? 0) + 1;
    }
    if (counts.isEmpty) return '${_selectedDeviceIds.length} devices';
    return counts.entries.map((e) => '${e.key} (${e.value})').join(', ');
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }

  Future<void> _executeBulkOperation() async {
    final count = _selectedDeviceIds.length;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please select at least one target device from the table.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final actionConfig = _buildCurrentActionConfig();
    final opSummary = _getOperationSummaryText();
    final opCode =
        'BLK-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${(1000 + _recentOperations.length + 1)}';

    // Show live execution modal with real parameters
    _showLiveExecutionModal(
      name: '$_selectedOperation: $opSummary',
      opCode: opCode,
      targetCount: count,
    );

    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$_baseUrl/bulk-operations'),
        headers: headers,
        body: jsonEncode({
          'name': '$_selectedOperation: $opSummary',
          'operation_type':
              _selectedOperation.toLowerCase().replaceAll(' ', '_'),
          'target_type': _selectedTargetTab.toLowerCase().replaceAll(' ', '_'),
          'target_configuration': {
            'device_ids': _selectedDeviceIds.toList(),
            'count': count,
          },
          'action_configuration': actionConfig,
          'execution_configuration': {
            'apply_to_supported_only': _applyToSupportedOnly,
            'skip_offline': _skipOffline,
          },
          'execute_now': true,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final realOpCode = data['operation_code'] ?? opCode;

        final newOp = BulkRecentOperationItem(
          id: data['operation_id'] ?? DateTime.now().toIso8601String(),
          operationCode: realOpCode,
          name: '$_selectedOperation: $opSummary',
          operationType: _selectedOperation.toLowerCase(),
          targetScope: '$_selectedTargetTab ($count devices)',
          status: 'Success',
          initiatedBy: 'Admin',
          result: '✓ $count/$count completed',
          totalDevices: count,
          successfulDevices: count,
          createdAt: 'Just now',
        );

        setState(() {
          _recentOperations.insert(0, newOp);
        });

        await _loadInitialData();
      }
    } catch (_) {}
  }

  void _showLiveExecutionModal({
    String? name,
    String? opCode,
    int? targetCount,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _LiveExecutionProgressDialog(
        operationName:
            name ?? '$_selectedOperation: ${_getOperationSummaryText()}',
        totalDevices: targetCount ?? _selectedDeviceIds.length,
        onDone: () {
          Navigator.of(ctx).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Bulk operation ${opCode ?? "completed"} executed successfully across ${targetCount ?? _selectedDeviceIds.length} devices!'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _showOperationHistoryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _BulkOperationHistoryDialog(
        operations: _recentOperations,
        apiBaseUrl: _baseUrl,
      ),
    );
  }

  void _showCreateBulkOperationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _CreateBulkOperationWizardDialog(
        apiBaseUrl: _baseUrl,
        onOperationCreated: () => _loadInitialData(),
      ),
    );
  }

  void _showSaveAsTemplateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _SaveBulkTemplateDialog(
        operationType: _selectedOperation,
        actionConfig: _buildCurrentActionConfig(),
        apiBaseUrl: _baseUrl,
        onSaved: () {
          _loadInitialData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bulk operation template saved successfully!'),
              backgroundColor: Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top 6 KPI Metric Cards
              _buildKpiMetricsBar(isDark),
              const SizedBox(height: 16),

              // 2. Main Bulk Operations Interactive Wizard Card
              _buildMainBulkOperationsCard(isDark, constraints),
              const SizedBox(height: 16),

              // 3. Bottom Grid: Recent Bulk Operations (Left) & Templates (Right)
              _buildBottomGrid(isDark, constraints),
            ],
          ),
        );
      },
    );
  }

  String _formatNumber(int n) {
    final str = n.toString();
    if (str.length > 3) {
      return '${str.substring(0, str.length - 3)},${str.substring(str.length - 3)}';
    }
    return str;
  }

  // ---------------------------------------------------------------------------
  // 1. Top 6 KPI Metrics Bar
  // ---------------------------------------------------------------------------
  Widget _buildKpiMetricsBar(bool isDark) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final selectedCount = _selectedDeviceIds.length;
    final onlineCount = _overview.onlineDevices;
    final onlinePct = _overview.onlinePercentage;
    final offlineCount = _overview.offlineDevices;
    final offlinePct = _overview.offlinePercentage;
    final groupsCount = _overview.selectedGroups;
    final locationsCount = _overview.selectedLocations;
    final affectedCount =
        selectedCount > 0 ? selectedCount : _overview.affectedDevices;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildKpiCard(
            title: 'Selected Devices',
            value: '$selectedCount',
            icon: Icons.layers_outlined,
            accentColor: primaryColor,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Online',
            value: '${_formatNumber(onlineCount)} ($onlinePct%)',
            icon: Icons.power_settings_new,
            accentColor: const Color(0xFF16A34A),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Offline',
            value: '${_formatNumber(offlineCount)} ($offlinePct%)',
            icon: Icons.power_off,
            accentColor: const Color(0xFFDC2626),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Selected Groups',
            value: '$groupsCount',
            icon: Icons.group_work_outlined,
            accentColor: primaryColor,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Selected Locations',
            value: '$locationsCount',
            icon: Icons.place_outlined,
            accentColor: primaryColor,
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Affected Devices',
            value: '$affectedCount',
            icon: Icons.devices_other_outlined,
            accentColor: primaryColor,
            isDark: isDark,
          ),
        ];

        if (constraints.maxWidth >= 900) {
          return Row(
            children: cards
                .map((c) => Expanded(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: c)))
                .toList(),
          );
        } else {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: cards
                  .map((c) => Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 8),
                      child: c))
                  .toList(),
            ),
          );
        }
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Main Bulk Operations Interactive Wizard Card
  // ---------------------------------------------------------------------------
  Widget _buildMainBulkOperationsCard(bool isDark, BoxConstraints constraints) {
    final isDesktop = constraints.maxWidth >= 1080;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          if (constraints.maxWidth >= 850)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.layers_rounded,
                      color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bulk Operations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Perform mass actions on multiple devices, groups or locations such as control, configuration, firmware update, scheduling, grouping and more.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showOperationHistoryDialog,
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text('Operation History'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showCreateBulkOperationDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create Bulk Operation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.layers_rounded,
                          color: Color(0xFF2563EB), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bulk Operations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Perform mass actions on multiple devices, groups or locations such as control, configuration, firmware update, scheduling, grouping and more.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showOperationHistoryDialog,
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: const Text('Operation History'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showCreateBulkOperationDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create Bulk Operation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 16),

          // 3-Step Stepper Bar
          _buildHorizontalStepperBar(isDark),
          const SizedBox(height: 18),

          // Split 2-Column Work Area
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Step 1 Select Targets
                Expanded(flex: 11, child: _buildSelectTargetsSection(isDark)),
                const SizedBox(width: 18),
                // Right Column: Step 2 & 3 Choose & Configure
                Expanded(flex: 9, child: _buildConfigureSection(isDark)),
              ],
            )
          else
            Column(
              children: [
                _buildSelectTargetsSection(isDark),
                const SizedBox(height: 18),
                _buildConfigureSection(isDark),
              ],
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Horizontal Stepper Bar
  // ---------------------------------------------------------------------------
  Widget _buildHorizontalStepperBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.5)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          children: [
            SizedBox(
              width: 260,
              child: _buildStepItem(
                stepNumber: 1,
                title: 'Select Targets',
                subtitle: 'Choose devices, groups or locations',
                isActive: _currentStep >= 1,
                isDark: isDark,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.chevron_right,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                  size: 18),
            ),
            SizedBox(
              width: 260,
              child: _buildStepItem(
                stepNumber: 2,
                title: 'Choose Operation',
                subtitle: 'Select the bulk action to perform',
                isActive: _currentStep >= 2,
                isDark: isDark,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.chevron_right,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                  size: 18),
            ),
            SizedBox(
              width: 260,
              child: _buildStepItem(
                stepNumber: 3,
                title: 'Configure & Execute',
                subtitle: 'Set parameters and run',
                isActive: _currentStep >= 3,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem({
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          alignment: Alignment.center,
          child: Text(
            '$stepNumber',
            style: TextStyle(
              color: isActive
                  ? Colors.white
                  : (isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // LEFT COLUMN: Step 1 Select Targets
  // ---------------------------------------------------------------------------
  Widget _buildSelectTargetsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
        Row(
          children: [
            const Icon(Icons.checklist_rounded,
                color: Color(0xFF2563EB), size: 18),
            const SizedBox(width: 6),
            Text(
              'Select Targets',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 4 Target Tabs: [Devices], [Groups], [Locations], [By Device Type]
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Row(
            children: [
              _buildTargetTabButton('Devices', Icons.devices, isDark),
              const SizedBox(width: 8),
              _buildTargetTabButton(
                  'Groups', Icons.group_work_outlined, isDark),
              const SizedBox(width: 8),
              _buildTargetTabButton('Locations', Icons.place_outlined, isDark),
              const SizedBox(width: 8),
              _buildTargetTabButton(
                  'By Device Type', Icons.grid_view_outlined, isDark),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Filter Devices Box
        _buildFilterDevicesBox(isDark),
        const SizedBox(height: 12),

        // Operation after multi-selection on grid toolbar
        _buildMultiSelectionActionBar(isDark),

        // Target Devices Table
        _buildTargetDevicesTable(isDark),
      ],
    );
  }

  Widget _buildTargetTabButton(String label, IconData icon, bool isDark) {
    final isSelected = _selectedTargetTab == label;
    return InkWell(
      onTap: () {
        setState(() => _selectedTargetTab = label);
        _fetchTargetDevices();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark
                  ? const Color(0xFF334155).withValues(alpha: 0.5)
                  : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDevicesBox(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.3)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.filter_list_rounded,
                      size: 14,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    'Filter Devices',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 1: Building, Floor, Room, Device Type
              if (!isNarrow)
                Row(
                  children: [
                    Expanded(
                      child: _buildSmallDropdown(
                        label: 'Building',
                        value: _selectedBuilding,
                        items: _buildingDropdownItems,
                        onChanged: _onBuildingChanged,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSmallDropdown(
                        label: 'Floor',
                        value: _selectedFloor,
                        items: _floorDropdownItems,
                        onChanged: _onFloorChanged,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSmallDropdown(
                        label: 'Room / Space',
                        value: _selectedRoom,
                        items: _roomDropdownItems,
                        onChanged: _onRoomChanged,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSmallDropdown(
                        label: 'Device Type',
                        value: _selectedDeviceType,
                        items: _deviceTypeDropdownItems,
                        onChanged: _onDeviceTypeChanged,
                        isDark: isDark,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildSmallDropdown(
                            label: 'Building',
                            value: _selectedBuilding,
                            items: _buildingDropdownItems,
                            onChanged: _onBuildingChanged,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSmallDropdown(
                            label: 'Floor',
                            value: _selectedFloor,
                            items: _floorDropdownItems,
                            onChanged: _onFloorChanged,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSmallDropdown(
                            label: 'Room / Space',
                            value: _selectedRoom,
                            items: _roomDropdownItems,
                            onChanged: _onRoomChanged,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSmallDropdown(
                            label: 'Device Type',
                            value: _selectedDeviceType,
                            items: _deviceTypeDropdownItems,
                            onChanged: _onDeviceTypeChanged,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 8),

              // Row 2: Status, Profile, Search bar
              if (!isNarrow)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildSmallDropdown(
                        label: 'Status',
                        value: _selectedStatus,
                        items: _statusDropdownItems,
                        onChanged: _onStatusChanged,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: _buildSmallDropdown(
                        label: 'Profile',
                        value: _selectedProfile,
                        items: _profileDropdownItems,
                        onChanged: _onProfileChanged,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 6,
                      child: SizedBox(
                        height: 34,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => _fetchTargetDevices(),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search devices by name, ID or tag...',
                            hintStyle: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(Icons.search, size: 16),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 0, horizontal: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF475569)
                                      : const Color(0xFFCBD5E1)),
                            ),
                            filled: true,
                            fillColor:
                                isDark ? const Color(0xFF1E293B) : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildSmallDropdown(
                            label: 'Status',
                            value: _selectedStatus,
                            items: _statusDropdownItems,
                            onChanged: _onStatusChanged,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSmallDropdown(
                            label: 'Profile',
                            value: _selectedProfile,
                            items: _profileDropdownItems,
                            onChanged: _onProfileChanged,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 34,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => _fetchTargetDevices(),
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search devices by name, ID or tag...',
                          hintStyle: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Icon(Icons.search, size: 16),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 0, horizontal: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF475569)
                                    : const Color(0xFFCBD5E1)),
                          ),
                          filled: true,
                          fillColor:
                              isDark ? const Color(0xFF1E293B) : Colors.white,
                        ),
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

  Widget _buildSmallDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    // 1. Strict deduplication preserving insertion order
    final uniqueItems = <String>[];
    for (final it in items) {
      final trimmed = it.trim();
      if (trimmed.isNotEmpty && !uniqueItems.contains(trimmed)) {
        uniqueItems.add(trimmed);
      }
    }
    if (uniqueItems.isEmpty) {
      uniqueItems.add(value.trim().isNotEmpty ? value.trim() : label);
    }
    // 2. Safe effective value resolution
    final effectiveValue = uniqueItems.contains(value.trim())
        ? value.trim()
        : uniqueItems.first;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          items: uniqueItems
              .map((e) => DropdownMenuItem<String>(
                  value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              onChanged(val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSortableHeader(
      String title, String column, int flex, bool isDark) {
    final isSorted = _sortBy == column;
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _toggleSort(column),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSorted
                      ? primaryColor
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isSorted
                  ? (_sortOrder == 'asc'
                      ? Icons.arrow_upward
                      : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 13,
              color: isSorted
                  ? primaryColor
                  : (isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectionActionBar(bool isDark) {
    if (_selectedDeviceIds.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded,
                    size: 16, color: primaryColor),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${_selectedDeviceIds.length} target devices selected',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _executeQuickAction('turn_on'),
                icon: const Icon(Icons.power_settings_new, size: 14),
                label: const Text('Turn ON'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _executeQuickAction('turn_off'),
                icon: const Icon(Icons.power_off, size: 14),
                label: const Text('Turn OFF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _executeQuickAction('toggle'),
                icon: const Icon(Icons.sync_alt, size: 14),
                label: const Text('Toggle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showApplyProfileDialog,
                icon: const Icon(Icons.tune, size: 14),
                label: const Text('Apply Profile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showSetSceneDialog,
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('Run Scene'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedDeviceIds.clear()),
                child: const Text('Clear All',
                    style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _executeQuickAction(String action,
      {Map<String, dynamic>? extraParams}) async {
    if (_selectedDeviceIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Execute Quick Bulk Action ($action)'),
        content: Text(
          'Are you sure you want to apply "$action" to ${_selectedDeviceIds.length} selected devices?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Execute'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final headers = await _getHeaders();
      final payload = {
        'name': 'Quick Bulk Action: $action',
        'operation_type': 'control',
        'target_type': 'devices',
        'target_configuration': {'device_ids': _selectedDeviceIds.toList()},
        'action_configuration': {
          'action': action,
          'parameters': extraParams ?? {},
        },
        'execution_configuration': {'batch_size': 50, 'delay_seconds': 0.2},
      };
      final res = await http.post(
        Uri.parse('$_baseUrl/bulk-operations/execute'),
        headers: headers,
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully executed $action across ${_selectedDeviceIds.length} devices!',
              ),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        }
        await _fetchTargetDevices();
        await _loadInitialData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to execute bulk action: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showApplyProfileDialog() {
    final profileItems = _targetProfileDropdownItems;
    final uniqueProfiles = <String>[];
    for (final p in profileItems) {
      final trimmed = p.trim();
      if (trimmed.isNotEmpty && !uniqueProfiles.contains(trimmed)) {
        uniqueProfiles.add(trimmed);
      }
    }
    if (uniqueProfiles.isEmpty) uniqueProfiles.add('Default Profile');
    String selectedProf = uniqueProfiles.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Apply Profile to Selected Devices'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Target devices: ${_selectedDeviceIds.length}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedProf,
                decoration: const InputDecoration(
                  labelText: 'Select Profile',
                  border: OutlineInputBorder(),
                ),
                items: uniqueProfiles
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDlgState(() => selectedProf = v);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeQuickAction('apply_profile',
                    extraParams: {'profile_name': selectedProf});
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetSceneDialog() {
    final sceneItems = _sceneDropdownItems;
    final uniqueScenes = <String>[];
    for (final s in sceneItems) {
      final trimmed = s.trim();
      if (trimmed.isNotEmpty && !uniqueScenes.contains(trimmed)) {
        uniqueScenes.add(trimmed);
      }
    }
    if (uniqueScenes.isEmpty) uniqueScenes.add('Morning Campus Startup');
    String selectedScn = uniqueScenes.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Run Scene on Selected Devices'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Target devices: ${_selectedDeviceIds.length}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedScn,
                decoration: const InputDecoration(
                  labelText: 'Select Scene',
                  border: OutlineInputBorder(),
                ),
                items: uniqueScenes
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDlgState(() => selectedScn = v);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeQuickAction('run_scene',
                    extraParams: {'scene_name': selectedScn});
              },
              child: const Text('Run Scene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetDevicesTable(bool isDark) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final pagedDevices = _devices;
    final totalCount = _totalDevicesCount;
    final totalPages = _totalPages;
    final int currentPageClamped =
        _currentPage.clamp(1, math.max(1, totalPages)).toInt();
    final startIndex =
        totalCount == 0 ? 0 : (currentPageClamped - 1) * _rowsPerPage;
    final endIndex = math.min(startIndex + pagedDevices.length, totalCount);
    final allOnPageSelected = pagedDevices.isNotEmpty &&
        pagedDevices.every((d) => _selectedDeviceIds.contains(d.id));

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth < 720 ? 720.0 : constraints.maxWidth;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                      border: Border(
                          bottom: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Checkbox(
                            value: allOnPageSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedDeviceIds
                                      .addAll(pagedDevices.map((d) => d.id));
                                } else {
                                  for (var d in pagedDevices) {
                                    _selectedDeviceIds.remove(d.id);
                                  }
                                }
                              });
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildSortableHeader('Device Name', 'device_name', 4, isDark),
                        _buildSortableHeader('Type', 'device_type', 3, isDark),
                        _buildSortableHeader('Location (Building > Room)', 'location', 4, isDark),
                        _buildSortableHeader('Status', 'status', 2, isDark),
                      ],
                    ),
                  ),

                  // Table Rows
                  if (pagedDevices.isEmpty)
                    Container(
                      height: 140,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 28,
                              color: isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8)),
                          const SizedBox(height: 6),
                          Text(
                            'No devices match the applied filters.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pagedDevices.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final dev = pagedDevices[index];
                        final isChecked = _selectedDeviceIds.contains(dev.id);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isChecked) {
                                _selectedDeviceIds.remove(dev.id);
                              } else {
                                _selectedDeviceIds.add(dev.id);
                              }
                            });
                          },
                          child: Container(
                            color: isChecked
                                ? (primaryColor
                                    .withValues(alpha: isDark ? 0.15 : 0.05))
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Checkbox(
                                    value: isChecked,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedDeviceIds.add(dev.id);
                                        } else {
                                          _selectedDeviceIds.remove(dev.id);
                                        }
                                      });
                                    },
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Device Name + Type Icon
                                Expanded(
                                  flex: 4,
                                  child: Row(
                                    children: [
                                      _getDeviceTypeIcon(dev.typeCode),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          dev.deviceName,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Type Name
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    dev.typeName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Location Display
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    dev.location,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Online / Offline Badge
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: dev.isOnline
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFFDC2626),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        dev.isOnline ? 'Online' : 'Offline',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: dev.isOnline
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFFDC2626),
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
                    ),

                  // Table Footer: Selected Count & Database Pagination
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A).withValues(alpha: 0.4)
                          : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(8)),
                      border: Border(
                          top: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0))),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Selected: ${_selectedDeviceIds.length} devices',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (allOnPageSelected) {
                                    for (var d in pagedDevices) {
                                      _selectedDeviceIds.remove(d.id);
                                    }
                                  } else {
                                    for (var d in pagedDevices) {
                                      _selectedDeviceIds.add(d.id);
                                    }
                                  }
                                });
                              },
                              child: Text(
                                allOnPageSelected
                                    ? 'Deselect Page'
                                    : 'Select Page',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () =>
                                  setState(() => _selectedDeviceIds.clear()),
                              child: const Text(
                                'Clear Selection',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Showing ${totalCount == 0 ? 0 : startIndex + 1} - $endIndex of $totalCount devices',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Rows: ',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B))),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _rowsPerPage,
                                    isDense: true,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    items: const [10, 20, 50, 100]
                                        .map((v) => DropdownMenuItem(
                                            value: v, child: Text('$v')))
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          _rowsPerPage = v;
                                          _currentPage = 1;
                                        });
                                        _fetchTargetDevices();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // First Page
                                IconButton(
                                  icon: const Icon(Icons.first_page, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: currentPageClamped > 1
                                      ? () {
                                          setState(() => _currentPage = 1);
                                          _fetchTargetDevices();
                                        }
                                      : null,
                                ),
                                const SizedBox(width: 4),
                                // Prev Page
                                IconButton(
                                  icon: const Icon(Icons.chevron_left, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: currentPageClamped > 1
                                      ? () {
                                          setState(() => _currentPage--);
                                          _fetchTargetDevices();
                                        }
                                      : null,
                                ),
                                const SizedBox(width: 4),
                                // Page numbers
                                ...List.generate(math.min(5, totalPages), (i) {
                                  int pNum = i + 1;
                                  if (totalPages > 5 && currentPageClamped > 3) {
                                    pNum = currentPageClamped - 2 + i;
                                    if (pNum > totalPages) {
                                      pNum = totalPages - 4 + i;
                                    }
                                  }
                                  final isCurrent = pNum == currentPageClamped;
                                  return InkWell(
                                    onTap: () {
                                      setState(() => _currentPage = pNum);
                                      _fetchTargetDevices();
                                    },
                                    child: Container(
                                      margin:
                                          const EdgeInsets.symmetric(horizontal: 2),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isCurrent
                                            ? primaryColor
                                            : (isDark
                                                ? const Color(0xFF334155)
                                                : const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$pNum',
                                        style: TextStyle(
                                          color: isCurrent
                                              ? Colors.white
                                              : (isDark
                                                  ? const Color(0xFFCBD5E1)
                                                  : const Color(0xFF475569)),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(width: 4),
                                // Next Page
                                IconButton(
                                  icon: const Icon(Icons.chevron_right, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: currentPageClamped < totalPages
                                      ? () {
                                          setState(() => _currentPage++);
                                          _fetchTargetDevices();
                                        }
                                      : null,
                                ),
                                const SizedBox(width: 4),
                                // Last Page
                                IconButton(
                                  icon: const Icon(Icons.last_page, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: currentPageClamped < totalPages
                                      ? () {
                                          setState(() => _currentPage = totalPages);
                                          _fetchTargetDevices();
                                        }
                                      : null,
                                ),
                              ],
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
        );
      },
    );
  }

  Widget _getDeviceTypeIcon(String typeCode) {
    switch (typeCode.toLowerCase()) {
      case 'lighting':
      case 'light':
        return const Icon(Icons.lightbulb_rounded,
            size: 14, color: Color(0xFFEAB308));
      case 'ac':
      case 'hvac':
        return const Icon(Icons.ac_unit_rounded,
            size: 14, color: Color(0xFF0284C7));
      case 'fan':
        return const Icon(Icons.mode_fan_off_rounded,
            size: 14, color: Color(0xFF06B6D4));
      case 'projector':
        return const Icon(Icons.videocam_rounded,
            size: 14, color: Color(0xFF8B5CF6));
      case 'cctv_camera':
      case 'cctv':
        return const Icon(Icons.videocam_outlined,
            size: 14, color: Color(0xFFEF4444));
      default:
        return const Icon(Icons.power_rounded,
            size: 14, color: Color(0xFF10B981));
    }
  }

  // ---------------------------------------------------------------------------
  // RIGHT COLUMN: Step 2 (Choose Operation) & Step 3 (Configure Operation)
  // ---------------------------------------------------------------------------
  Widget _buildConfigureSection(bool isDark) {
    final selectedCount = _selectedDeviceIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card 1: (2) Choose Operation
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.4)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xFF2563EB)),
                    alignment: Alignment.center,
                    child: const Text('2',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Choose Operation',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 7 Operation Tiles
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildOperationTile('Control', 'On/Off, Set Value',
                      Icons.power_settings_new, isDark),
                  _buildOperationTile('Configuration', 'Parameters',
                      Icons.settings_outlined, isDark),
                  _buildOperationTile(
                      'Firmware Update', 'OTA Flash', Icons.memory, isDark),
                  _buildOperationTile('Assign to Group', 'Grouping',
                      Icons.group_add_outlined, isDark),
                  _buildOperationTile('Apply Profile', 'Preset Config',
                      Icons.assignment_outlined, isDark),
                  _buildOperationTile('Schedule', 'One-time/Recurring',
                      Icons.calendar_today_outlined, isDark),
                  _buildOperationTile(
                      'Run Scene', 'Preset', Icons.play_circle_outline, isDark),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Card 2: (3) Configure Operation - Control
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.4)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xFF2563EB)),
                    alignment: Alignment.center,
                    child: const Text('3',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Configure Operation – $_selectedOperation',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Dynamic Operation Sub-Form
              if (_selectedOperation == 'Control')
                _buildControlConfigForm(isDark)
              else if (_selectedOperation == 'Schedule')
                _buildScheduleConfigForm(isDark)
              else if (_selectedOperation == 'Configuration')
                _buildParametersConfigForm(isDark)
              else if (_selectedOperation == 'Firmware Update')
                _buildFirmwareUpdateConfigForm(isDark)
              else if (_selectedOperation == 'Assign to Group')
                _buildAssignGroupConfigForm(isDark)
              else if (_selectedOperation == 'Apply Profile')
                _buildApplyProfileConfigForm(isDark)
              else if (_selectedOperation == 'Run Scene')
                _buildRunSceneConfigForm(isDark)
              else
                _buildControlConfigForm(isDark),

              const SizedBox(height: 10),

              // Additional Settings Checkboxes
              const Text('Additional Settings',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _applyToSupportedOnly,
                      onChanged: (v) =>
                          setState(() => _applyToSupportedOnly = v == true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Apply to supported device types only (e.g., Lighting, Smart Plug)',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _skipOffline,
                      onChanged: (v) =>
                          setState(() => _skipOffline = v == true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Skip devices that are offline',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Operation Summary Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF93C5FD).withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 14, color: Color(0xFF2563EB)),
                        SizedBox(width: 6),
                        Text('Operation Summary',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                        'Operation', _getOperationSummaryText(), isDark),
                    _buildSummaryRow('Target Type', _selectedTargetTab, isDark),
                    _buildSummaryRow(
                        'Selected Count', '$selectedCount devices', isDark),
                    _buildSummaryRow('Device Types (Detected)',
                        _getDetectedTypesSummary(), isDark),
                    _buildSummaryRow(
                        'Target Fleet Status',
                        '${_devices.where((d) => _selectedDeviceIds.contains(d.id) && d.isOnline).length} Online, ${_devices.where((d) => _selectedDeviceIds.contains(d.id) && !d.isOnline).length} Offline',
                        isDark),
                    _buildSummaryRow(
                        'Estimated Duration', _getEstimatedDuration(), isDark),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Action Buttons Row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showSaveAsTemplateDialog,
                    icon: const Icon(Icons.bookmark_border_rounded, size: 15),
                    label: const Text('Save as Template'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () =>
                            setState(() => _selectedDeviceIds.clear()),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _executeBulkOperation,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Execute Operation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          elevation: 1,
                        ),
                      ),
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

  Widget _buildOperationTile(
      String name, String sub, IconData icon, bool isDark) {
    final isSelected = _selectedOperation == name;
    return InkWell(
      onTap: () => setState(() => _selectedOperation = name),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : (isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                color:
                    isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption(String label) {
    return InkWell(
      onTap: () => setState(() => _controlSubAction = label),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: label,
            groupValue: _controlSubAction,
            onChanged: (val) => setState(() => _controlSubAction = val!),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getEstimatedDuration() {
    switch (_selectedOperation) {
      case 'Schedule':
        return 'Runs at scheduled time';
      case 'Firmware Update':
        return '~ 2–5 minutes';
      case 'Configuration':
        return '~ 10–20 seconds';
      case 'Assign to Group':
      case 'Apply Profile':
        return '~ 5–10 seconds';
      case 'Run Scene':
        return '~ 3–8 seconds';
      case 'Control':
      default:
        return '~ 2–5 seconds';
    }
  }

  // 1. Control Subform
  Widget _buildControlConfigForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Operation Type',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _buildRadioOption('Turn ON'),
            _buildRadioOption('Turn OFF'),
            _buildRadioOption('Set Value'),
          ],
        ),
        if (_controlSubAction == 'Set Value') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Temperature Stepper
                Row(
                  children: [
                    const SizedBox(
                      width: 125,
                      child: Text('Target Temp:',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w500)),
                    ),
                    Text('${_setValueTemperature.toInt()}°C',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB))),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _setValueTemperature =
                          (_setValueTemperature - 1).clamp(16.0, 30.0)),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _setValueTemperature =
                          (_setValueTemperature + 1).clamp(16.0, 30.0)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Brightness Slider
                Row(
                  children: [
                    const SizedBox(
                      width: 125,
                      child: Text('Brightness:',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w500)),
                    ),
                    Text('${_setValueBrightness.toInt()}%',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEAB308))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _setValueBrightness,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (val) =>
                            setState(() => _setValueBrightness = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Fan Speed Dropdown
                Row(
                  children: [
                    const SizedBox(
                      width: 125,
                      child: Text('Fan Speed:',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w500)),
                    ),
                    Expanded(
                      child: _buildSmallDropdown(
                        label: 'Fan Speed',
                        value: _setValueFanSpeed,
                        items: const ['Low', 'Medium', 'High', 'Auto'],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _setValueFanSpeed = val);
                          }
                        },
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _controlStaggered,
                onChanged: (v) => setState(() => _controlStaggered = v == true),
              ),
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Stagger execution (prevents electrical load surge)',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 2. Schedule Subform
  Widget _buildScheduleConfigForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Schedule Type',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            InkWell(
              onTap: () => setState(() => _scheduleType = 'One-Time Execution'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(
                    value: 'One-Time Execution',
                    groupValue: _scheduleType,
                    onChanged: (val) => setState(() => _scheduleType = val!),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const Text('One-Time Execution',
                      style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            InkWell(
              onTap: () => setState(() => _scheduleType = 'Recurring Schedule'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(
                    value: 'Recurring Schedule',
                    groupValue: _scheduleType,
                    onChanged: (val) => setState(() => _scheduleType = val!),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const Text('Recurring Schedule',
                      style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Execution Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Execution Date',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _scheduledDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _scheduledDate = picked);
                      }
                    },
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_scheduledDate.day} ${_getMonthName(_scheduledDate.month)} ${_scheduledDate.year}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Execution Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Execution Time',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _scheduledTime,
                      );
                      if (picked != null) {
                        setState(() => _scheduledTime = picked);
                      }
                    },
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_scheduleType == 'Recurring Schedule') ...[
          const SizedBox(height: 8),
          const Text('Recurrence Frequency',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          _buildSmallDropdown(
            label: 'Recurrence',
            value: _scheduleRecurrence,
            items: const [
              'Daily at scheduled time',
              'Weekdays (Mon - Fri)',
              'Weekends only (Sat - Sun)',
              'Weekly on Mondays',
              'Monthly on 1st',
            ],
            onChanged: (val) {
              if (val != null) setState(() => _scheduleRecurrence = val);
            },
            isDark: isDark,
          ),
        ],
        const SizedBox(height: 8),
        const Text('Action to Execute on Schedule',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        _buildSmallDropdown(
          label: 'Scheduled Action',
          value: _scheduleAction,
          items: const [
            'Turn OFF all devices',
            'Turn ON default lighting & AC',
            'Set Eco Temperature (24°C)',
            'Apply Night Energy Shutdown Profile',
            'Run Morning Campus Startup Scene',
          ],
          onChanged: (val) {
            if (val != null) setState(() => _scheduleAction = val);
          },
          isDark: isDark,
        ),
      ],
    );
  }

  // 3. Configuration Subform
  Widget _buildParametersConfigForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Heartbeat Interval',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  _buildSmallDropdown(
                    label: 'Heartbeat',
                    value: _configHeartbeatInterval,
                    items: const ['30s', '60s', '120s', '300s', '600s'],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _configHeartbeatInterval = val);
                      }
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Telemetry Frequency',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  _buildSmallDropdown(
                    label: 'Telemetry',
                    value: _configTelemetryFreq,
                    items: const [
                      'Real-time',
                      'Every 5s',
                      'Every 30s',
                      'Every 1m',
                      'Every 5m'
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _configTelemetryFreq = val);
                      }
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Log Level',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B))),
                  const SizedBox(height: 2),
                  _buildSmallDropdown(
                    label: 'Log Level',
                    value: _configLogLevel,
                    items: const ['Info', 'Debug', 'Warning', 'Error'],
                    onChanged: (val) {
                      if (val != null) setState(() => _configLogLevel = val);
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _configEcoMode,
                onChanged: (v) => setState(() => _configEcoMode = v == true),
              ),
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Enable Smart Eco Mode (auto sleep during inactivity)',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 4. Firmware Update Subform
  Widget _buildFirmwareUpdateConfigForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Target Firmware Version',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        _buildSmallDropdown(
          label: 'Firmware Version',
          value: _firmwareVersion,
          items: const [
            'v2.4.2-stable (Recommended)',
            'v2.4.1 (Stable LTS)',
            'v2.5.0-rc2 (Beta Preview)',
            'v2.3.9 (Rollback Archive)',
          ],
          onChanged: (val) {
            if (val != null) setState(() => _firmwareVersion = val);
          },
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        const Text('Rollout Strategy',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        _buildSmallDropdown(
          label: 'Rollout Strategy',
          value: _firmwareRolloutStrategy,
          items: const [
            'Canary Rollout (10% first)',
            'Immediate (All targets at once)',
            'Rolling Batches (15 devices / 2 mins)',
          ],
          onChanged: (val) {
            if (val != null) setState(() => _firmwareRolloutStrategy = val);
          },
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _firmwareAutoRollback,
                onChanged: (v) =>
                    setState(() => _firmwareAutoRollback = v == true),
              ),
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Auto-rollback if device communication fails within 5 mins',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _firmwareRebootAfter,
                onChanged: (v) =>
                    setState(() => _firmwareRebootAfter = v == true),
              ),
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Reboot devices immediately upon flash completion',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 5. Assign to Group Subform
  Widget _buildAssignGroupConfigForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Group Operation',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        _buildSmallDropdown(
          label: 'Group Action',
          value: _groupAction,
          items: const [
            'Add to Group',
            'Move to Group',
            'Remove from Group',
          ],
          onChanged: (val) {
            if (val != null) setState(() => _groupAction = val);
          },
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        const Text('Target Device Group',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        _buildSmallDropdown(
          label: 'Target Group',
          value: _targetGroupName,
          items: _groupDropdownItems,
          onChanged: (val) {
            if (val != null) setState(() => _targetGroupName = val);
          },
          isDark: isDark,
        ),
      ],
    );
  }

  // 6. Apply Profile Subform
  Widget _buildApplyProfileConfigForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Target Control Profile',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        _buildSmallDropdown(
          label: 'Control Profile',
          value: _targetProfileName,
          items: _targetProfileDropdownItems,
          onChanged: (val) {
            if (val != null) setState(() => _targetProfileName = val);
          },
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _profileOverwrite,
                onChanged: (v) => setState(() => _profileOverwrite = v == true),
              ),
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Overwrite custom device overrides with profile defaults',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 7. Run Scene Subform
  Widget _buildRunSceneConfigForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Preset Scene',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        _buildSmallDropdown(
          label: 'Preset Scene',
          value: _selectedScene,
          items: _sceneDropdownItems,
          onChanged: (val) {
            if (val != null) setState(() => _selectedScene = val);
          },
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        const Text('Transition Speed',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        _buildSmallDropdown(
          label: 'Transition Speed',
          value: _sceneTransitionSpeed,
          items: const [
            'Instant (0s)',
            'Smooth Fade (3s)',
            'Gradual Ramp (10s)',
            'Cinematic Slow (30s)',
          ],
          onChanged: (val) {
            if (val != null) setState(() => _sceneTransitionSpeed = val);
          },
          isDark: isDark,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Bottom Grid: Recent Bulk Operations (Left) & Templates (Right)
  // ---------------------------------------------------------------------------
  Widget _buildBottomGrid(bool isDark, BoxConstraints constraints) {
    final isDesktop = constraints.maxWidth >= 900;

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: _buildRecentOperationsCard(isDark)),
          const SizedBox(width: 16),
          Expanded(flex: 5, child: _buildTemplatesCard(isDark)),
        ],
      );
    } else {
      return Column(
        children: [
          _buildRecentOperationsCard(isDark),
          const SizedBox(height: 16),
          _buildTemplatesCard(isDark),
        ],
      );
    }
  }

  Widget _buildRecentOperationsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded,
                        size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Recent Bulk Operations',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _showOperationHistoryDialog,
                child: const Text('View All →',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mini Data Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: 660,
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(3.0),
                  2: FlexColumnWidth(2.5),
                  3: FlexColumnWidth(2.4),
                  4: FlexColumnWidth(1.6),
                  5: FlexColumnWidth(2.0),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0))),
                    ),
                    children: const [
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('Executed On',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('Operation',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('Targets',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('Status',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('Initiated By',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('Result',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  ..._recentOperations.map((op) {
                    final isSuccess = op.status.toLowerCase() == 'success' ||
                        op.status.toLowerCase() == 'completed';
                    return TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFF1F5F9))),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(op.createdAt ?? '12 Jan 2025',
                              style: const TextStyle(fontSize: 10)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(op.name,
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(op.targetScope,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B))),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSuccess
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF0284C7),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  op.status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isSuccess
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(op.initiatedBy,
                              style: const TextStyle(fontSize: 10)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(op.result,
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.bookmark_outline_rounded,
                        size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Bulk Operation Templates',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _showCreateBulkOperationDialog,
                child: const Text('View All →',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _templates.length,
            separatorBuilder: (_, __) => Divider(
                height: 1,
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final tmpl = _templates[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getTemplateIcon(tmpl.icon),
                          size: 14, color: const Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tmpl.templateName,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_arrow_outlined,
                          size: 16, color: Color(0xFF2563EB)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Run Template',
                      onPressed: () async {
                        _showLiveExecutionModal();
                        try {
                          final headers = await _getHeaders();
                          await http.post(
                              Uri.parse(
                                  '$_baseUrl/bulk-operations/templates/${tmpl.id}/execute'),
                              headers: headers);
                          await _loadInitialData();
                        } catch (_) {}
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 15, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          size: 15, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Template Options',
                      onSelected: (val) async {
                        if (val == 'run') {
                          _showLiveExecutionModal();
                          try {
                            final headers = await _getHeaders();
                            await http.post(
                                Uri.parse(
                                    '$_baseUrl/bulk-operations/templates/${tmpl.id}/execute'),
                                headers: headers);
                            await _loadInitialData();
                          } catch (_) {}
                        } else if (val == 'delete') {
                          final scaffold = ScaffoldMessenger.of(context);
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Template'),
                              content: Text(
                                  'Are you sure you want to delete template "${tmpl.templateName}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                      foregroundColor: Colors.white),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            try {
                              final headers = await _getHeaders();
                              await http.delete(
                                  Uri.parse(
                                      '$_baseUrl/bulk-operations/templates/${tmpl.id}'),
                                  headers: headers);
                              if (mounted) {
                                scaffold.showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Template "${tmpl.templateName}" deleted successfully.')),
                                );
                              }
                              await _loadInitialData();
                            } catch (_) {}
                          }
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'run',
                          child: Row(
                            children: [
                              Icon(Icons.play_arrow_outlined,
                                  size: 16, color: Color(0xFF2563EB)),
                              SizedBox(width: 8),
                              Text('Run Template',
                                  style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 16, color: Color(0xFFDC2626)),
                              SizedBox(width: 8),
                              Text('Delete Template',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFDC2626))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getTemplateIcon(String iconName) {
    switch (iconName) {
      case 'gps_fixed':
        return Icons.gps_fixed_rounded;
      case 'tune':
        return Icons.tune_rounded;
      case 'memory':
        return Icons.memory_rounded;
      case 'lightbulb_outline':
        return Icons.lightbulb_outline;
      default:
        return Icons.layers_outlined;
    }
  }
}

// ====================================================================
// MODAL DIALOG 1: Live Execution Progress Dialog
// ====================================================================
class _LiveExecutionProgressDialog extends StatefulWidget {
  final String operationName;
  final int totalDevices;
  final VoidCallback onDone;

  const _LiveExecutionProgressDialog({
    required this.operationName,
    required this.totalDevices,
    required this.onDone,
  });

  @override
  State<_LiveExecutionProgressDialog> createState() =>
      _LiveExecutionProgressDialogState();
}

class _LiveExecutionProgressDialogState
    extends State<_LiveExecutionProgressDialog> {
  double _progress = 0.15;
  int _completed = 1;
  final int _failed = 0;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _startSimulatedProgress();
  }

  void _startSimulatedProgress() async {
    for (int i = 1; i <= widget.totalDevices; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _completed = i;
        _progress = i / (widget.totalDevices == 0 ? 1 : widget.totalDevices);
      });
    }
    if (mounted) {
      setState(() {
        _isFinished = true;
        _progress = 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_rounded,
                    color: Color(0xFF2563EB), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isFinished
                            ? 'Bulk Operation Completed'
                            : 'Executing Bulk Operation...',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.operationName,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress Bar
            LinearProgressIndicator(
              value: _progress,
              backgroundColor:
                  isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(_progress * 100).toInt()}% Dispatched',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$_completed of ${widget.totalDevices} Devices Complete',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary Chips
            Row(
              children: [
                _buildMetricBadge(
                    'Successful', '$_completed', const Color(0xFF16A34A)),
                const SizedBox(width: 8),
                _buildMetricBadge(
                    'Failed', '$_failed', const Color(0xFFDC2626)),
                const SizedBox(width: 8),
                _buildMetricBadge(
                    'Pending',
                    '${widget.totalDevices - _completed}',
                    const Color(0xFF0284C7)),
              ],
            ),
            const SizedBox(height: 18),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _isFinished ? widget.onDone : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
                child: Text(_isFinished ? 'Close' : 'Running...'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBadge(String label, String val, Color col) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: col.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: col, fontWeight: FontWeight.w500)),
            Text(val,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: col)),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// MODAL DIALOG 2: Operation History & Details Dialog
// ====================================================================
class _BulkOperationHistoryDialog extends StatefulWidget {
  final List<BulkRecentOperationItem> operations;
  final String apiBaseUrl;

  const _BulkOperationHistoryDialog(
      {required this.operations, required this.apiBaseUrl});

  @override
  State<_BulkOperationHistoryDialog> createState() =>
      _BulkOperationHistoryDialogState();
}

class _BulkOperationHistoryDialogState
    extends State<_BulkOperationHistoryDialog> {
  late List<BulkRecentOperationItem> _ops;

  @override
  void initState() {
    super.initState();
    _ops = List.from(widget.operations);
    _refreshOperations();
  }

  Future<void> _refreshOperations() async {
    try {
      final res = await http.get(
        Uri.parse('${widget.apiBaseUrl}/bulk-operations?page=1&page_size=50'),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawList = data is Map ? (data['operations'] as List? ?? []) : [];
        if (rawList.isNotEmpty && mounted) {
          setState(() {
            _ops = rawList.map((m) {
              final map = m as Map<String, dynamic>;
              return BulkRecentOperationItem(
                id: map['id']?.toString() ?? '',
                operationCode: map['operation_code']?.toString() ?? 'OP-000',
                name: map['operation_name']?.toString() ?? 'Bulk Operation',
                operationType: map['operation_type']?.toString() ?? 'control',
                targetScope: map['target_type']?.toString() ?? 'Devices',
                totalDevices: (map['total_targets'] as num?)?.toInt() ?? 0,
                successfulDevices: (map['success_count'] as num?)?.toInt() ?? 0,
                status: map['status']?.toString() ?? 'completed',
                result: map['status'] == 'completed'
                    ? '100% Success'
                    : (map['status'] ?? 'Completed'),
                initiatedBy:
                    map['initiated_by_name']?.toString() ?? 'Super Admin',
                createdAt: map['created_at']?.toString(),
              );
            }).toList();
          });
        }
      }
    } catch (_) {}
  }

  void _openDetails(BulkRecentOperationItem op) {
    showDialog(
      context: context,
      builder: (ctx) => _BulkOperationDetailsDialog(
        operationId: op.id,
        operationCode: op.operationCode,
        operationName: op.name,
        apiBaseUrl: widget.apiBaseUrl,
        onActionCompleted: () => _refreshOperations(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 820,
        height: 560,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Bulk Operations Audit & Execution History',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: 'Refresh',
                      onPressed: _refreshOperations,
                    ),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _ops.isEmpty
                  ? const Center(
                      child: Text('No bulk operations recorded yet.',
                          style: TextStyle(color: Color(0xFF64748B))),
                    )
                  : ListView.separated(
                      itemCount: _ops.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final op = _ops[i];
                        final isFailed = op.status == 'failed' ||
                            op.status == 'partially_failed' ||
                            (op.totalDevices > op.successfulDevices &&
                                op.status == 'completed' &&
                                op.successfulDevices < op.totalDevices);
                        final isInProgress = op.status == 'in_progress' ||
                            op.status == 'pending';

                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          onTap: () => _openDetails(op),
                          leading: CircleAvatar(
                            backgroundColor: isInProgress
                                ? const Color(0xFFFEF3C7)
                                : (isFailed
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFEFF6FF)),
                            child: Icon(
                              isInProgress
                                  ? Icons.sync_rounded
                                  : (isFailed
                                      ? Icons.error_outline_rounded
                                      : Icons.layers_rounded),
                              color: isInProgress
                                  ? const Color(0xFFD97706)
                                  : (isFailed
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF2563EB)),
                              size: 18,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text('${op.operationCode} – ${op.name}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isInProgress
                                      ? const Color(0xFFFEF3C7)
                                      : (isFailed
                                          ? const Color(0xFFFEE2E2)
                                          : const Color(0xFFDCFCE7)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  op.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: isInProgress
                                        ? const Color(0xFFB45309)
                                        : (isFailed
                                            ? const Color(0xFFB91C1C)
                                            : const Color(0xFF15803D)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                              'Scope: ${op.targetScope} • ${op.totalDevices} targets • Initiated by ${op.initiatedBy} • ${op.createdAt ?? "Recent"}',
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(op.result,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: isFailed
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF16A34A))),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right,
                                  size: 16, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// MODAL DIALOG 2B: Detailed Operation Inspection Modal
// ====================================================================
class _BulkOperationDetailsDialog extends StatefulWidget {
  final String operationId;
  final String operationCode;
  final String operationName;
  final String apiBaseUrl;
  final VoidCallback onActionCompleted;

  const _BulkOperationDetailsDialog({
    required this.operationId,
    required this.operationCode,
    required this.operationName,
    required this.apiBaseUrl,
    required this.onActionCompleted,
  });

  @override
  State<_BulkOperationDetailsDialog> createState() =>
      _BulkOperationDetailsDialogState();
}

class _BulkOperationDetailsDialogState
    extends State<_BulkOperationDetailsDialog> {
  Map<String, dynamic>? _details;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await http.get(
        Uri.parse(
            '${widget.apiBaseUrl}/bulk-operations/${widget.operationId}'),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _details = data is Map<String, dynamic> ? data : {};
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Failed to load details: ${res.statusCode}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error: $e';
        });
      }
    }
  }

  Future<void> _cancelOperation() async {
    try {
      await http.post(
        Uri.parse(
            '${widget.apiBaseUrl}/bulk-operations/${widget.operationId}/cancel'),
        headers: {'Content-Type': 'application/json'},
      );
      widget.onActionCompleted();
      _fetchDetails();
    } catch (_) {}
  }

  Future<void> _retryFailed() async {
    try {
      await http.post(
        Uri.parse(
            '${widget.apiBaseUrl}/bulk-operations/${widget.operationId}/retry-failed'),
        headers: {'Content-Type': 'application/json'},
      );
      widget.onActionCompleted();
      _fetchDetails();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final op = _details?['operation'] as Map<String, dynamic>? ?? {};
    final items = (_details?['items'] as List?) ?? [];
    final status = op['status']?.toString() ?? 'completed';
    final isFailed = status == 'failed' || status == 'partially_failed';
    final isInProgress = status == 'in_progress' || status == 'pending';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 700,
        height: 520,
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                            onPressed: _fetchDetails,
                            child: const Text('Retry')),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.operationCode} • ${widget.operationName}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Type: ${op['operation_type'] ?? 'Unknown'} • Initiated: ${op['created_at'] ?? 'N/A'}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // KPI mini row
                      Row(
                        children: [
                          _buildMiniBadge(
                              'Total Targets',
                              '${op['total_targets'] ?? items.length}',
                              const Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          _buildMiniBadge(
                              'Success',
                              '${op['success_count'] ?? 0}',
                              const Color(0xFF16A34A)),
                          const SizedBox(width: 8),
                          _buildMiniBadge(
                              'Failures',
                              '${op['failure_count'] ?? 0}',
                              const Color(0xFFDC2626)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Target Items Section
                      const Text(
                        'Target Devices & Status',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: items.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Center(
                                  child: Text('No per-device logs recorded.',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B))),
                                ),
                              )
                            : ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, idx) {
                                  final item =
                                      items[idx] as Map<String, dynamic>;
                                  final itemStatus =
                                      item['status']?.toString() ?? 'completed';
                                  final hasErr = itemStatus == 'failed' ||
                                      (item['error_message'] != null &&
                                          item['error_message']
                                              .toString()
                                              .isNotEmpty);

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6, horizontal: 4),
                                    child: Row(
                                      children: [
                                        Icon(
                                          hasErr
                                              ? Icons.cancel_outlined
                                              : Icons.check_circle_outline,
                                          size: 16,
                                          color: hasErr
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF16A34A),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['device_name']
                                                        ?.toString() ??
                                                    'Device ${idx + 1}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                              if (hasErr)
                                                Text(
                                                  item['error_message']
                                                          ?.toString() ??
                                                      'Execution error',
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          Color(0xFFDC2626)),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          itemStatus.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: hasErr
                                                ? const Color(0xFFDC2626)
                                                : const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      // Action buttons: Cancel / Retry / Close
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isInProgress)
                            ElevatedButton.icon(
                              onPressed: _cancelOperation,
                              icon: const Icon(Icons.cancel, size: 14),
                              label: const Text('Cancel Operation'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white),
                            ),
                          if (isFailed)
                            ElevatedButton.icon(
                              onPressed: _retryFailed,
                              icon: const Icon(Icons.refresh, size: 14),
                              label: const Text('Retry Failed Devices'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white),
                            ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildMiniBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.w600)),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// MODAL DIALOG 3: Create Bulk Operation Wizard Dialog
// ====================================================================
class _CreateBulkOperationWizardDialog extends StatefulWidget {
  final String apiBaseUrl;
  final VoidCallback onOperationCreated;

  const _CreateBulkOperationWizardDialog(
      {required this.apiBaseUrl, required this.onOperationCreated});

  @override
  State<_CreateBulkOperationWizardDialog> createState() =>
      _CreateBulkOperationWizardDialogState();
}

class _CreateBulkOperationWizardDialogState
    extends State<_CreateBulkOperationWizardDialog> {
  final _nameController =
      TextEditingController(text: 'Campus Evening Shutdown');
  String _opType = 'control';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.add_task_rounded, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Create & Schedule Bulk Operation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                  labelText: 'Operation Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _opType,
              decoration: const InputDecoration(
                  labelText: 'Operation Category',
                  border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                    value: 'control', child: Text('Fleet Device Control')),
                DropdownMenuItem(
                    value: 'apply_profile',
                    child: Text('Apply Security / Energy Profile')),
                DropdownMenuItem(
                    value: 'firmware_update',
                    child: Text('Deploy Firmware Update')),
              ],
              onChanged: (v) => setState(() => _opType = v!),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    try {
                      await http.post(
                        Uri.parse('${widget.apiBaseUrl}/bulk-operations'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'name': _nameController.text.trim(),
                          'operation_type': _opType,
                          'target_type': 'devices',
                          'target_configuration': {},
                          'action_configuration': {'action': _opType},
                          'execution_configuration': {'mode': 'immediate'},
                          'execute_now': true,
                        }),
                      );
                      widget.onOperationCreated();
                    } catch (_) {}
                    nav.pop();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white),
                  child: const Text('Execute Now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// MODAL DIALOG 4: Save Bulk Template Dialog
// ====================================================================
class _SaveBulkTemplateDialog extends StatefulWidget {
  final String operationType;
  final Map<String, dynamic> actionConfig;
  final String apiBaseUrl;
  final VoidCallback onSaved;

  const _SaveBulkTemplateDialog({
    required this.operationType,
    required this.actionConfig,
    required this.apiBaseUrl,
    required this.onSaved,
  });

  @override
  State<_SaveBulkTemplateDialog> createState() =>
      _SaveBulkTemplateDialogState();
}

class _SaveBulkTemplateDialogState extends State<_SaveBulkTemplateDialog> {
  final _tmplNameCtrl =
      TextEditingController(text: 'Standard Classroom Protocol');
  final _descCtrl = TextEditingController(
      text: 'Reusable bulk preset for institutional spaces');

  @override
  void dispose() {
    _tmplNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.bookmark_add_outlined, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Save Operation as Template',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _tmplNameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Template Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                  labelText: 'Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    try {
                      await http.post(
                        Uri.parse(
                            '${widget.apiBaseUrl}/bulk-operations/templates'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'template_name': _tmplNameCtrl.text,
                          'description': _descCtrl.text,
                          'operation_type': widget.operationType
                              .toLowerCase()
                              .replaceAll(' ', '_'),
                          'target_type': 'devices',
                          'action_configuration': widget.actionConfig,
                          'icon': 'tune',
                          'color': '#2563EB',
                        }),
                      );
                      widget.onSaved();
                    } catch (_) {}
                    nav.pop();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white),
                  child: const Text('Save Template'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
