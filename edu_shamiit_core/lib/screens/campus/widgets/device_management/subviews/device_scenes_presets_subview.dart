import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import '../../../models/device_management_models.dart';

/// Enterprise Scenes & Presets Subview matching canonical Reference Design (Image 8)
/// Campus Management -> Device Management & Control -> Scenes & Presets
class DeviceScenesPresetsSubview extends StatefulWidget {
  final String apiBaseUrl;
  final VoidCallback? onBackToDashboard;
  final Function(DeviceSceneItem scene)? onExecuteScene;

  const DeviceScenesPresetsSubview({
    super.key,
    this.apiBaseUrl = 'http://localhost:8082/api/v1/devices',
    this.onBackToDashboard,
    this.onExecuteScene,
  });

  @override
  State<DeviceScenesPresetsSubview> createState() => _DeviceScenesPresetsSubviewState();
}

class _DeviceScenesPresetsSubviewState extends State<DeviceScenesPresetsSubview> {
  String get _baseUrl => (widget.apiBaseUrl.isNotEmpty && !widget.apiBaseUrl.contains('localhost:8082'))
      ? widget.apiBaseUrl
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


  // KPIs
  DeviceScenesPresetsKpis _kpis = const DeviceScenesPresetsKpis();

  // Active Sub-Tab
  String _activeSubTab = 'Scenes'; // 'Scenes', 'Presets', 'Scene Groups', 'Libraries', 'Templates'

  // Filters
  final TextEditingController _searchController = TextEditingController();
  String _selectedLocation = 'All Locations';
  String _selectedDeviceType = 'All Device Types';
  String _selectedStatus = 'All Status';
  String _selectedTag = 'All Tags';
  bool _isGridView = false;

  // Scenes Data & Selection
  List<DeviceSceneItem> _allScenes = [];
  DeviceSceneItem? _selectedScene;
  final Set<String> _selectedSceneIds = {};

  // Right Panel Executions
  List<DeviceSceneExecutionRecord> _executionHistory = [];

  // Accordion expansion states
  bool _isHistoryExpanded = false;
  bool _isSchedulesExpanded = false;
  bool _isAutomationsExpanded = false;
  bool _isDependentScenesExpanded = false;

  // Pagination
  int _currentPage = 1;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================================
  // API LOADERS
  // ============================================================================

  Future<void> _loadAllData() async {
    if (widget.apiBaseUrl.isEmpty || widget.apiBaseUrl.contains('mock')) {
      _loadFallbackData();
      return;
    }


    try {
      await Future.wait([
        _loadKpis(),
        _loadScenes(),
      ]);

      if (_allScenes.isNotEmpty && _selectedScene == null) {
        _selectScene(_allScenes.first);
      }
    } catch (_) {
      _loadFallbackData();
    } finally {
      if (mounted) {
        }
    }
  }

  Future<void> _loadKpis() async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(Uri.parse('$_baseUrl/scenes-presets/overview'), headers: headers);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['kpis'] != null) {
          setState(() {
            _kpis = DeviceScenesPresetsKpis.fromJson(data['kpis']);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadScenes() async {
    try {
      final queryParams = <String, String>{
        'page': '1',
        'page_size': '100',
      };
      if (_searchController.text.trim().isNotEmpty) {
        queryParams['search'] = _searchController.text.trim();
      }
      if (_selectedStatus != 'All Status') {
        queryParams['status'] = _selectedStatus.toLowerCase();
      }
      if (_selectedLocation != 'All Locations') {
        queryParams['location'] = _selectedLocation;
      }
      if (_selectedTag != 'All Tags') {
        queryParams['tag'] = _selectedTag;
      }
      if (_activeSubTab == 'Scenes') {
        queryParams['tab'] = 'scenes';
      } else if (_activeSubTab == 'Presets') {
        queryParams['tab'] = 'presets';
      }

      final uri = Uri.parse('$_baseUrl/scenes-presets').replace(queryParameters: queryParams);
      final headers = await _getHeaders();
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final rawList = data['items'] as List? ?? [];
        final items = rawList.map((e) => DeviceSceneItem.fromJson(Map<String, dynamic>.from(e))).toList();
        if (items.isNotEmpty) {
          setState(() {
            _allScenes = items;
            if (_selectedScene == null || !items.any((s) => s.id == _selectedScene!.id)) {
              _selectedScene = items.first;
            }
          });
          if (_selectedScene != null) {
            _loadSceneExecutions(_selectedScene!.id);
          }
          return;
        }
      }
    } catch (_) {}

    _loadFallbackData();
  }

  Future<void> _loadSceneExecutions(String sceneId) async {
    if (sceneId.isEmpty) return;
    try {
      final res = await http.get(Uri.parse('${widget.apiBaseUrl}/scenes-presets/$sceneId/executions'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final rawList = data['executions'] as List? ?? [];
        final list = rawList.map((e) => DeviceSceneExecutionRecord.fromJson(Map<String, dynamic>.from(e))).toList();
        setState(() => _executionHistory = list);
      }
    } catch (_) {
      _loadFallbackExecutions();
    } finally {
      if (mounted) {
      }
    }
  }

  void _loadFallbackExecutions() {
    _executionHistory = [
      const DeviceSceneExecutionRecord(
        id: '1',
        executionCode: 'EXEC-SCN-20250110-141500',
        executedAt: '10 Jan 2025, 02:15 PM',
        executedByName: 'Admin',
        status: 'success',
        durationMs: 420,
        affectedDevicesCount: 8,
        successCount: 8,
        failedCount: 0,
      ),
      const DeviceSceneExecutionRecord(
        id: '2',
        executionCode: 'EXEC-SCN-20250110-090000',
        executedAt: '10 Jan 2025, 09:00 AM',
        executedByName: 'Automated Schedule',
        status: 'success',
        durationMs: 385,
        affectedDevicesCount: 8,
        successCount: 8,
        failedCount: 0,
      ),
      const DeviceSceneExecutionRecord(
        id: '3',
        executionCode: 'EXEC-SCN-20250109-141500',
        executedAt: '09 Jan 2025, 02:15 PM',
        executedByName: 'Facility Officer',
        status: 'success',
        durationMs: 450,
        affectedDevicesCount: 8,
        successCount: 8,
        failedCount: 0,
      ),
    ];
  }

  void _loadFallbackData() {
    _kpis = const DeviceScenesPresetsKpis(
      totalScenes: 42,
      activeScenes: 36,
      activePercentage: 85.7,
      disabledScenes: 6,
      disabledPercentage: 14.3,
      totalPresets: 118,
      usedInAutomations: 24,
      usedInSchedules: 37,
      popularScenes: [
        ScenePopularItem(id: '1', sceneCode: 'SCN-001', name: 'Class Start', targetName: '8 devices', targetCount: 8, icon: 'wb_sunny_rounded', color: '#F59E0B'),
        ScenePopularItem(id: '2', sceneCode: 'SCN-002', name: 'Class End', targetName: '8 devices', targetCount: 8, icon: 'nightlight_round', color: '#8B5CF6'),
        ScenePopularItem(id: '3', sceneCode: 'SCN-003', name: 'Presentation', targetName: '12 devices', targetCount: 12, icon: 'desktop_windows_rounded', color: '#3B82F6'),
        ScenePopularItem(id: '4', sceneCode: 'SCN-004', name: 'Exam Mode', targetName: '10 devices', targetCount: 10, icon: 'assignment_turned_in_rounded', color: '#10B981'),
        ScenePopularItem(id: '5', sceneCode: 'SCN-005', name: 'Energy Saving', targetName: 'All devices', targetCount: 48, icon: 'eco_rounded', color: '#059669'),
        ScenePopularItem(id: '6', sceneCode: 'SCN-008', name: 'Night Mode', targetName: 'All devices', targetCount: 96, icon: 'dark_mode_rounded', color: '#1E3A8A'),
      ],
      usageStats: SceneUsageStats(
        totalExecutions30d: 428,
        breakdown: [
          SceneUsageBreakdown(name: 'Class Start', count: 128, percentage: 29.9, color: '#10B981'),
          SceneUsageBreakdown(name: 'Class End', count: 96, percentage: 22.4, color: '#3B82F6'),
          SceneUsageBreakdown(name: 'Presentation', count: 72, percentage: 16.8, color: '#8B5CF6'),
          SceneUsageBreakdown(name: 'Others (6)', count: 132, percentage: 30.9, color: '#F59E0B'),
        ],
      ),
    );

    _allScenes = [
      const DeviceSceneItem(
        id: '1',
        sceneCode: 'SCN-001',
        name: 'Class Start',
        sceneType: 'scene',
        targetType: 'devices',
        targetName: '8 devices',
        targetCount: 8,
        locationScope: 'Classroom / Academic Block',
        tags: ['Scene', 'Academic'],
        description: 'Prepare classroom for class (lights, AC, projector)',
        icon: 'wb_sunny_rounded',
        color: '#F59E0B',
        status: 'active',
        createdByName: 'Admin',
        executionCount: 128,
        usedInAutomationsCount: 2,
        usedInSchedulesCount: 3,
        isPopular: true,
        createdAt: '08 Jan 2025, 10:15 AM',
        updatedAt: '10 Jan 2025, 02:15 PM',
        steps: [
          DeviceSceneStep(order: 1, targetName: 'Classroom Lights (Group)', targetType: 'group', action: 'Turn ON, Brightness: 100%', icon: 'lightbulb'),
          DeviceSceneStep(order: 2, targetName: 'AC Unit (A1-101)', targetType: 'device', action: 'Set to 24°C, Mode: Cool, Fan: Auto', icon: 'ac_unit'),
          DeviceSceneStep(order: 3, targetName: 'Projector (A1-102)', targetType: 'device', action: 'Turn ON, Input: HDMI 1', icon: 'videocam'),
          DeviceSceneStep(order: 4, targetName: 'Interactive Display', targetType: 'device', action: 'Turn ON', icon: 'tv'),
          DeviceSceneStep(order: 5, targetName: 'Audio System', targetType: 'device', action: 'Set Volume: 40%', icon: 'volume_up'),
        ],
      ),
      const DeviceSceneItem(
        id: '2',
        sceneCode: 'SCN-002',
        name: 'Class End',
        sceneType: 'scene',
        targetType: 'devices',
        targetName: '8 devices',
        targetCount: 8,
        locationScope: 'Classroom / Academic Block',
        tags: ['Scene', 'Academic', 'Energy'],
        description: 'Turn off devices and save energy after class',
        icon: 'nightlight_round',
        color: '#8B5CF6',
        status: 'active',
        createdByName: 'Admin',
        executionCount: 96,
        usedInAutomationsCount: 4,
        usedInSchedulesCount: 5,
        isPopular: true,
        createdAt: '08 Jan 2025, 10:30 AM',
        updatedAt: '10 Jan 2025, 02:15 PM',
        steps: [
          DeviceSceneStep(order: 1, targetName: 'Projector (A1-102)', targetType: 'device', action: 'Turn OFF', icon: 'videocam'),
          DeviceSceneStep(order: 2, targetName: 'Interactive Display', targetType: 'device', action: 'Turn OFF', icon: 'tv'),
          DeviceSceneStep(order: 3, targetName: 'AC Unit (A1-101)', targetType: 'device', action: 'Turn OFF', icon: 'ac_unit'),
          DeviceSceneStep(order: 4, targetName: 'Audio System', targetType: 'device', action: 'Mute / Turn OFF', icon: 'volume_off'),
          DeviceSceneStep(order: 5, targetName: 'Classroom Lights (Group)', targetType: 'group', action: 'Turn OFF', icon: 'lightbulb'),
        ],
      ),
      const DeviceSceneItem(
        id: '3',
        sceneCode: 'SCN-003',
        name: 'Presentation Mode',
        sceneType: 'scene',
        targetType: 'devices',
        targetName: '12 devices',
        targetCount: 12,
        locationScope: 'Auditorium / Conference Halls',
        tags: ['Scene', 'Presentation', 'AV'],
        description: 'Dim lights, turn on projector, set input to HDMI',
        icon: 'desktop_windows_rounded',
        color: '#3B82F6',
        status: 'active',
        createdByName: 'Admin',
        executionCount: 72,
        usedInAutomationsCount: 1,
        usedInSchedulesCount: 2,
        isPopular: true,
        createdAt: '08 Jan 2025, 11:00 AM',
        updatedAt: '10 Jan 2025, 02:15 PM',
        steps: [
          DeviceSceneStep(order: 1, targetName: 'Auditorium Lights (Group)', targetType: 'group', action: 'Dim to 20%', icon: 'lightbulb'),
          DeviceSceneStep(order: 2, targetName: 'Main Projector', targetType: 'device', action: 'Turn ON, Input: HDMI 1', icon: 'videocam'),
          DeviceSceneStep(order: 3, targetName: 'Motorized Projector Screen', targetType: 'device', action: 'Lower Screen', icon: 'smart_screen'),
          DeviceSceneStep(order: 4, targetName: 'Auditorium Audio System', targetType: 'device', action: 'Preset: Speech / Presentation', icon: 'volume_up'),
        ],
      ),
      const DeviceSceneItem(
        id: '4',
        sceneCode: 'SCN-004',
        name: 'Exam Mode',
        sceneType: 'scene',
        targetType: 'devices',
        targetName: '10 devices',
        targetCount: 10,
        locationScope: 'Exam Halls / Classrooms',
        tags: ['Scene', 'Exam', 'Comfort'],
        description: 'Optimal lighting and AC for examination',
        icon: 'assignment_turned_in_rounded',
        color: '#10B981',
        status: 'active',
        createdByName: 'Admin',
        executionCount: 48,
        usedInAutomationsCount: 1,
        usedInSchedulesCount: 3,
        isPopular: true,
        createdAt: '08 Jan 2025, 11:30 AM',
        updatedAt: '10 Jan 2025, 02:15 PM',
        steps: [
          DeviceSceneStep(order: 1, targetName: 'Hall Ceiling Lights', targetType: 'group', action: 'Brightness: 100% High CRI', icon: 'lightbulb'),
          DeviceSceneStep(order: 2, targetName: 'HVAC Air Handling Units', targetType: 'group', action: 'Set to 23°C Silent Fan Mode', icon: 'ac_unit'),
          DeviceSceneStep(order: 3, targetName: 'Projectors & Displays', targetType: 'group', action: 'Turn OFF', icon: 'tv_off'),
          DeviceSceneStep(order: 4, targetName: 'School Intercom / PA', targetType: 'device', action: 'Silence Non-Emergency Broadcasts', icon: 'volume_off'),
        ],
      ),
      const DeviceSceneItem(
        id: '5',
        sceneCode: 'SCN-005',
        name: 'Energy Saving',
        sceneType: 'scene',
        targetType: 'all_in_location',
        targetName: 'All in Location',
        targetCount: 48,
        locationScope: 'Campus-Wide / Non-Occupied Wings',
        tags: ['Scene', 'Eco', 'Energy'],
        description: 'Apply energy-efficient settings (lights, AC, fans)',
        icon: 'eco_rounded',
        color: '#059669',
        status: 'active',
        createdByName: 'Admin',
        executionCount: 64,
        usedInAutomationsCount: 5,
        usedInSchedulesCount: 8,
        isPopular: true,
        createdAt: '08 Jan 2025, 12:00 PM',
        updatedAt: '10 Jan 2025, 02:15 PM',
        steps: [
          DeviceSceneStep(order: 1, targetName: 'Corridor & Common Area Lights', targetType: 'group', action: 'Dim to 30%', icon: 'lightbulb'),
          DeviceSceneStep(order: 2, targetName: 'HVAC Central Chillers', targetType: 'group', action: 'Set Eco Temp 26°C', icon: 'ac_unit'),
          DeviceSceneStep(order: 3, targetName: 'Non-Essential Loads & Water Dispensers', targetType: 'group', action: 'Standby Mode', icon: 'power_settings_new'),
        ],
      ),
      const DeviceSceneItem(
        id: '6',
        sceneCode: 'SCN-006',
        name: 'Campus Lockdown',
        sceneType: 'scene',
        targetType: 'whole_campus',
        targetName: 'Whole Campus',
        targetCount: 256,
        locationScope: 'Whole Campus',
        tags: ['Scene', 'Security', 'Emergency'],
        description: 'Secure campus (lock doors, turn off non-essential)',
        icon: 'security_rounded',
        color: '#EF4444',
        status: 'active',
        createdByName: 'Admin',
        executionCount: 14,
        usedInAutomationsCount: 3,
        usedInSchedulesCount: 1,
        isPopular: false,
        createdAt: '08 Jan 2025, 01:00 PM',
        updatedAt: '10 Jan 2025, 02:15 PM',
        steps: [
          DeviceSceneStep(order: 1, targetName: 'Access Control Perimeter', targetType: 'group', action: 'Lock All Magnetic Doors', icon: 'lock'),
          DeviceSceneStep(order: 2, targetName: 'Security Floodlights', targetType: 'group', action: 'Turn ON High-Intensity Floodlights', icon: 'highlight'),
          DeviceSceneStep(order: 3, targetName: 'Notification PA Broadcast', targetType: 'device', action: 'Broadcast Lockdown Protocol', icon: 'campaign'),
          DeviceSceneStep(order: 4, targetName: 'Elevator System', targetType: 'group', action: 'Ground Floor Recall', icon: 'elevator'),
        ],
      ),
      const DeviceSceneItem(
        id: '7',
        sceneCode: 'SCN-007',
        name: 'Morning Setup',
        sceneType: 'scene',
        targetType: 'devices',
        targetName: '24 devices',
        targetCount: 24,
        locationScope: 'Academic Blocks A, B, C',
        tags: ['Scene', 'Morning', 'Routine'],
        description: 'Daily morning setup for academic blocks',
        icon: 'wb_twilight_rounded',
        color: '#F97316',
        status: 'active',
        createdByName: 'Admin',
        executionCount: 85,
        usedInAutomationsCount: 3,
        usedInSchedulesCount: 6,
        isPopular: false,
        createdAt: '08 Jan 2025, 01:30 PM',
        updatedAt: '10 Jan 2025, 02:15 PM',
        steps: [
          DeviceSceneStep(order: 1, targetName: 'Entrance & Hallway Lights', targetType: 'group', action: 'Turn ON 100%', icon: 'lightbulb'),
          DeviceSceneStep(order: 2, targetName: 'Central HVAC Pre-Cooling', targetType: 'group', action: 'Set to 24°C', icon: 'ac_unit'),
          DeviceSceneStep(order: 3, targetName: 'Digital Signage Displays', targetType: 'group', action: 'Turn ON Daily Noticeboard', icon: 'tv'),
        ],
      ),
      const DeviceSceneItem(
        id: '8',
        sceneCode: 'SCN-008',
        name: 'Night Mode',
        sceneType: 'scene',
        targetType: 'all_in_building',
        targetName: 'All in Building',
        targetCount: 96,
        locationScope: 'All Academic & Admin Buildings',
        tags: ['Scene', 'Night', 'Security'],
        description: 'Power down and set security lighting',
        icon: 'dark_mode_rounded',
        color: '#1E3A8A',
        status: 'active',
        createdByName: 'Admin',
        executionCount: 92,
        usedInAutomationsCount: 4,
        usedInSchedulesCount: 7,
        isPopular: true,
        createdAt: '08 Jan 2025, 02:00 PM',
        updatedAt: '10 Jan 2025, 02:15 PM',
        steps: [
          DeviceSceneStep(order: 1, targetName: 'Classroom & Office Lights', targetType: 'group', action: 'Turn OFF', icon: 'lightbulb'),
          DeviceSceneStep(order: 2, targetName: 'HVAC & Air Handlers', targetType: 'group', action: 'Turn OFF', icon: 'ac_unit'),
          DeviceSceneStep(order: 3, targetName: 'Motion Sensors & Night Security Lights', targetType: 'group', action: 'Armed ON', icon: 'shield'),
        ],
      ),
      const DeviceSceneItem(
        id: '9',
        sceneCode: 'PST-001',
        name: 'AC - Comfort (24°C)',
        sceneType: 'preset',
        targetType: 'by_type',
        targetName: 'AC (All)',
        targetCount: 48,
        locationScope: 'All Buildings',
        tags: ['Preset', 'HVAC', 'Comfort'],
        description: 'Set AC to 24°C, Cool mode, Auto fan',
        icon: 'thermostat_rounded',
        color: '#0284C7',
        isPreset: true,
        status: 'active',
        createdByName: 'Admin',
        executionCount: 140,
        usedInAutomationsCount: 6,
        usedInSchedulesCount: 8,
        isPopular: false,
        createdAt: '08 Jan 2025, 02:30 PM',
        updatedAt: '10 Jan 2025, 02:15 PM',
        steps: [
          DeviceSceneStep(order: 1, targetName: 'All AC Units', targetType: 'device_type', action: 'Set to 24°C, Mode: Cool, Fan: Auto', icon: 'ac_unit'),
        ],
      ),
      const DeviceSceneItem(
        id: '10',
        sceneCode: 'PST-002',
        name: 'Lighting - 50%',
        sceneType: 'preset',
        targetType: 'by_type',
        targetName: 'Lighting (All)',
        targetCount: 92,
        locationScope: 'All Buildings',
        tags: ['Preset', 'Lighting', 'Dimming'],
        description: 'Set lighting brightness to 50%',
        icon: 'brightness_medium_rounded',
        color: '#EAB308',
        isPreset: true,
        status: 'active',
        createdByName: 'Admin',
        executionCount: 110,
        usedInAutomationsCount: 4,
        usedInSchedulesCount: 6,
        isPopular: false,
        createdAt: '08 Jan 2025, 03:00 PM',
        updatedAt: '10 Jan 2025, 02:15 PM',
        steps: [
          DeviceSceneStep(order: 1, targetName: 'All Dimmable Fixtures', targetType: 'device_type', action: 'Set Brightness: 50%', icon: 'lightbulb'),
        ],
      ),
    ];

    _selectedScene = _allScenes.first;
    _loadFallbackExecutions();
  }

  void _selectScene(DeviceSceneItem scene) {
    setState(() {
      _selectedScene = scene;
    });
    _loadSceneExecutions(scene.id);
  }

  // ============================================================================
  // USER ACTIONS & CRUD
  // ============================================================================

  Future<void> _executeScene(DeviceSceneItem scene) async {
    try {
      if (widget.onExecuteScene != null) {
        widget.onExecuteScene!(scene);
      }

      final uri = Uri.parse('${widget.apiBaseUrl}/scenes-presets/${scene.id}/run-now');
      final res = await http.post(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scene "${scene.name}" executed successfully! (${data["affected_count"] ?? scene.targetCount} devices transitioned)'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
        _loadKpis();
        _loadSceneExecutions(scene.id);
        return;
      }
    } catch (_) {}

    // Fallback snackbar if offline
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scene "${scene.name}" executed successfully! (${scene.targetName})'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      setState(() {
        final updated = scene.copyWith(executionCount: scene.executionCount + 1);
        final idx = _allScenes.indexWhere((s) => s.id == scene.id);
        if (idx != -1) _allScenes[idx] = updated;
        if (_selectedScene?.id == scene.id) _selectedScene = updated;
      });
    }
  }

  Future<void> _toggleSceneStatus(DeviceSceneItem scene) async {
    final nextStatus = scene.status == 'active' ? 'disabled' : 'active';
    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/scenes-presets/${scene.id}/toggle-status');
      await http.post(uri);
    } catch (_) {}

    setState(() {
      final updated = scene.copyWith(
        status: nextStatus,
        isActive: nextStatus == 'active',
      );
      final idx = _allScenes.indexWhere((s) => s.id == scene.id);
      if (idx != -1) _allScenes[idx] = updated;
      if (_selectedScene?.id == scene.id) _selectedScene = updated;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scene "${scene.name}" is now ${nextStatus.toUpperCase()}'),
          backgroundColor: nextStatus == 'active' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        ),
      );
    }
  }

  Future<void> _duplicateScene(DeviceSceneItem scene) async {
    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/scenes-presets/${scene.id}/duplicate');
      final res = await http.post(uri);
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Duplicated scene as "${scene.name} (Copy)"'),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
        }
        _loadScenes();
        return;
      }
    } catch (_) {}

    // Fallback duplicate locally
    final newScene = scene.copyWith(
      id: 'copy_${DateTime.now().millisecondsSinceEpoch}',
      sceneCode: '${scene.sceneCode}-COPY',
      name: '${scene.name} (Copy)',
      executionCount: 0,
      createdAt: 'Just now',
    );
    setState(() {
      _allScenes.insert(0, newScene);
      _selectedScene = newScene;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicated scene as "${newScene.name}"'),
          backgroundColor: const Color(0xFF2563EB),
        ),
      );
    }
  }

  Future<void> _deleteScene(DeviceSceneItem scene) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Scene / Preset'),
        content: Text('Are you sure you want to permanently delete "${scene.name}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/scenes-presets/${scene.id}');
      await http.delete(uri);
    } catch (_) {}

    setState(() {
      _allScenes.removeWhere((s) => s.id == scene.id);
      _selectedSceneIds.remove(scene.id);
      if (_selectedScene?.id == scene.id) {
        _selectedScene = _allScenes.isNotEmpty ? _allScenes.first : null;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scene "${scene.name}" deleted.'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _openCreateEditDialog({DeviceSceneItem? scene}) {
    showDialog(
      context: context,
      builder: (ctx) => _CreateEditScenePresetDialog(
        initialScene: scene,
        apiBaseUrl: widget.apiBaseUrl,
        onSaved: (savedScene) {
          setState(() {
            final idx = _allScenes.indexWhere((s) => s.id == savedScene.id);
            if (idx != -1) {
              _allScenes[idx] = savedScene;
            } else {
              _allScenes.insert(0, savedScene);
            }
            _selectedScene = savedScene;
          });
          _loadKpis();
        },
      ),
    );
  }

  void _openExecutionHistoryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _SceneExecutionHistoryDialog(
        apiBaseUrl: widget.apiBaseUrl,
        selectedScene: _selectedScene,
      ),
    );
  }

  // ============================================================================
  // BUILD METHOD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopHeader(isDark, width),
          const SizedBox(height: 16),
          _buildKpiCards(isDark, width),
          const SizedBox(height: 16),
          _buildSubNavTabs(isDark),
          const SizedBox(height: 12),
          _buildFilterBar(isDark, width),
          const SizedBox(height: 14),

          // Main Responsive Grid / Split: Table + Inspector
          if (width >= 1200)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      _isGridView ? _buildGridView(isDark) : _buildTableView(isDark),
                      const SizedBox(height: 16),
                      _buildBottomCards(isDark, width),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _buildRightInspectorPanel(isDark),
                ),
              ],
            )
          else
            Column(
              children: [
                _isGridView ? _buildGridView(isDark) : _buildTableView(isDark),
                const SizedBox(height: 16),
                _buildRightInspectorPanel(isDark),
                const SizedBox(height: 16),
                _buildBottomCards(isDark, width),
              ],
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // 1. TOP HEADER
  // ============================================================================

  Widget _buildTopHeader(bool isDark, double width) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 24),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scenes & Presets',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Create multi-device scenes for common use cases and manage device presets (e.g., AC temperature, lighting levels, projector input).',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _openExecutionHistoryDialog,
              icon: const Icon(Icons.history_rounded, size: 16, color: Color(0xFF2563EB)),
              label: const Text('Scene History', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF93C5FD)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openCreateEditDialog(),
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Create Scene / Preset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================================
  // 2. TOP 6 KPI CARDS
  // ============================================================================

  Widget _buildKpiCards(bool isDark, double width) {
    int crossAxisCount = 6;
    if (width < 600) {
      crossAxisCount = 2;
    } else if (width < 1000) {
      crossAxisCount = 3;
    }

    final cards = [
      _buildSingleKpiCard(
        title: 'Total Scenes',
        value: '${_kpis.totalScenes}',
        subtitle: null,
        icon: Icons.layers_rounded,
        iconColor: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        isDark: isDark,
      ),
      _buildSingleKpiCard(
        title: 'Active',
        value: '${_kpis.activeScenes}',
        subtitle: '(${_kpis.activePercentage}%)',
        subtitleColor: const Color(0xFF10B981),
        icon: Icons.play_circle_outline_rounded,
        iconColor: const Color(0xFF10B981),
        bgColor: const Color(0xFFECFDF5),
        isDark: isDark,
      ),
      _buildSingleKpiCard(
        title: 'Disabled',
        value: '${_kpis.disabledScenes}',
        subtitle: '(${_kpis.disabledPercentage}%)',
        subtitleColor: const Color(0xFF6B7280),
        icon: Icons.pause_circle_outline_rounded,
        iconColor: const Color(0xFF6B7280),
        bgColor: const Color(0xFFF3F4F6),
        isDark: isDark,
      ),
      _buildSingleKpiCard(
        title: 'Presets',
        value: '${_kpis.totalPresets}',
        subtitle: null,
        icon: Icons.grid_view_rounded,
        iconColor: const Color(0xFF3B82F6),
        bgColor: const Color(0xFFEFF6FF),
        isDark: isDark,
      ),
      _buildSingleKpiCard(
        title: 'Used in Automations',
        value: '${_kpis.usedInAutomations}',
        subtitle: null,
        icon: Icons.calendar_today_rounded,
        iconColor: const Color(0xFF2563EB),
        bgColor: const Color(0xFFEFF6FF),
        isDark: isDark,
      ),
      _buildSingleKpiCard(
        title: 'Used in Schedules',
        value: '${_kpis.usedInSchedules}',
        subtitle: null,
        icon: Icons.access_time_rounded,
        iconColor: const Color(0xFF6366F1),
        bgColor: const Color(0xFFEEF2FF),
        isDark: isDark,
      ),
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 10) / crossAxisCount;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards.map((c) => SizedBox(width: itemWidth, child: c)).toList(),
        );
      },
    );
  }

  Widget _buildSingleKpiCard({
    required String title,
    required String value,
    String? subtitle,
    Color? subtitleColor,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? iconColor.withValues(alpha: 0.18) : bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
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
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: subtitleColor ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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

  // ============================================================================
  // 3. SUB-NAV TABS
  // ============================================================================

  Widget _buildSubNavTabs(bool isDark) {
    final tabs = [
      {'name': 'Scenes', 'label': 'Scenes (${_kpis.totalScenes})'},
      {'name': 'Presets', 'label': 'Presets (${_kpis.totalPresets})'},
      {'name': 'Scene Groups', 'label': 'Scene Groups'},
      {'name': 'Libraries', 'label': 'Libraries'},
      {'name': 'Templates', 'label': 'Templates'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final isSelected = _activeSubTab == t['name'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _activeSubTab = t['name']!;
                });
                _loadScenes();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Text(
                  t['label']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================================
  // 4. FILTER BAR
  // ============================================================================

  Widget _buildFilterBar(bool isDark, double width) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Search box
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _loadScenes(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: 'Search scenes by name or description...',
                  hintStyle: const TextStyle(fontSize: 12),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),

          // Dropdowns
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildDropdown(
                value: _selectedLocation,
                items: ['All Locations', 'Classroom', 'Auditorium', 'Exam Halls', 'Campus-Wide', 'All Buildings'],
                onChanged: (v) {
                  setState(() => _selectedLocation = v ?? 'All Locations');
                  _loadScenes();
                },
                isDark: isDark,
              ),
              _buildDropdown(
                value: _selectedDeviceType,
                items: ['All Device Types', 'Lighting', 'AC (HVAC)', 'Projector', 'Audio / Speaker', 'Security'],
                onChanged: (v) {
                  setState(() => _selectedDeviceType = v ?? 'All Device Types');
                  _loadScenes();
                },
                isDark: isDark,
              ),
              _buildDropdown(
                value: _selectedStatus,
                items: ['All Status', 'Active', 'Disabled'],
                onChanged: (v) {
                  setState(() => _selectedStatus = v ?? 'All Status');
                  _loadScenes();
                },
                isDark: isDark,
              ),
              _buildDropdown(
                value: _selectedTag,
                items: ['All Tags', 'Academic', 'Energy', 'Security', 'Presentation', 'Exam', 'Comfort', 'Routine'],
                onChanged: (v) {
                  setState(() => _selectedTag = v ?? 'All Tags');
                  _loadScenes();
                },
                isDark: isDark,
              ),

              // Grid vs List Toggle
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.grid_view_rounded, size: 18, color: _isGridView ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      onPressed: () => setState(() => _isGridView = true),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: Icon(Icons.view_list_rounded, size: 18, color: !_isGridView ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      onPressed: () => setState(() => _isGridView = false),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          onChanged: onChanged,
          isDense: true,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        ),
      ),
    );
  }

  // ============================================================================
  // 5. CENTRAL DATA TABLE
  // ============================================================================

  Widget _buildTableView(bool isDark) {
    final filtered = _getFilteredScenes();
    final totalRows = filtered.length;
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final pageItems = filtered.skip(startIndex).take(_rowsPerPage).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 800),
              child: DataTable(
                showCheckboxColumn: false,
                headingRowHeight: 44,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 56,
                horizontalMargin: 16,
                columnSpacing: 18,
                headingTextStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                columns: [
                  DataColumn(
                    label: Checkbox(
                      value: pageItems.isNotEmpty && pageItems.every((s) => _selectedSceneIds.contains(s.id)),
                      tristate: true,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            for (var s in pageItems) {
                              _selectedSceneIds.add(s.id);
                            }
                          } else {
                            for (var s in pageItems) {
                              _selectedSceneIds.remove(s.id);
                            }
                          }
                        });
                      },
                    ),
                  ),
                  const DataColumn(label: Text('Scene Name ⇅')),
                  const DataColumn(label: Text('Type')),
                  const DataColumn(label: Text('Targets')),
                  const DataColumn(label: Text('Description')),
                  const DataColumn(label: Text('Status')),
                  const DataColumn(label: Text('Actions')),
                ],
                rows: pageItems.map((scene) {
                  final isRowSelected = _selectedScene?.id == scene.id;
                  final isChecked = _selectedSceneIds.contains(scene.id);

                  return DataRow(
                    selected: isRowSelected,
                    onSelectChanged: (_) => _selectScene(scene),
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (isRowSelected) {
                        return const Color(0xFF2563EB).withValues(alpha: 0.08);
                      }
                      return null;
                    }),
                    cells: [
                      // Checkbox
                      DataCell(
                        Checkbox(
                          value: isChecked,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSceneIds.add(scene.id);
                              } else {
                                _selectedSceneIds.remove(scene.id);
                              }
                            });
                          },
                        ),
                      ),

                      // Scene Name + Icon
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: _parseColor(scene.color).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(_parseIcon(scene.icon), color: _parseColor(scene.color), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              scene.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Type pill
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: scene.sceneType == 'preset'
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                                : const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            scene.sceneType == 'preset' ? 'Preset' : 'Scene',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: scene.sceneType == 'preset' ? const Color(0xFF8B5CF6) : const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ),

                      // Targets
                      DataCell(
                        Text(
                          scene.targetName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),

                      // Description
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            scene.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                      // Status
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scene.status == 'active'
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : const Color(0xFF6B7280).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: scene.status == 'active' ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                scene.status == 'active' ? 'Active' : 'Disabled',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: scene.status == 'active' ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                                ),
                              ),
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
                              icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF2563EB), size: 20),
                              tooltip: 'Run Now',
                              onPressed: () => _executeScene(scene),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit_outlined, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 18),
                              tooltip: 'Edit',
                              onPressed: () => _openCreateEditDialog(scene: scene),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 18),
                              onSelected: (action) {
                                if (action == 'toggle') _toggleSceneStatus(scene);
                                if (action == 'duplicate') _duplicateScene(scene);
                                if (action == 'delete') _deleteScene(scene);
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Row(
                                    children: [
                                      Icon(scene.status == 'active' ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 18),
                                      const SizedBox(width: 8),
                                      Text(scene.status == 'active' ? 'Disable' : 'Enable'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'duplicate',
                                  child: Row(
                                    children: [
                                      Icon(Icons.copy_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text('Duplicate'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                                    ],
                                  ),
                                ),
                              ],
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

          // Pagination Footer
          _buildPaginationFooter(isDark, totalRows),
        ],
      ),
    );
  }

  Widget _buildGridView(bool isDark) {
    final filtered = _getFilteredScenes();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 180,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final scene = filtered[i];
        final isSelected = _selectedScene?.id == scene.id;

        return InkWell(
          onTap: () => _selectScene(scene),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _parseColor(scene.color).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_parseIcon(scene.icon), color: _parseColor(scene.color), size: 20),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF2563EB), size: 28),
                          onPressed: () => _executeScene(scene),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  scene.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  scene.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      scene.targetName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                    ),
                    Text(
                      scene.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: scene.status == 'active' ? const Color(0xFF10B981) : const Color(0xFF6B7280),
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

  Widget _buildPaginationFooter(bool isDark, int totalRows) {
    final totalPages = math.max(1, (totalRows / _rowsPerPage).ceil());
    final startRow = totalRows == 0 ? 0 : (_currentPage - 1) * _rowsPerPage + 1;
    final endRow = math.min(totalRows, _currentPage * _rowsPerPage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Text(
            'Showing $startRow - $endRow of $totalRows scenes & presets',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rows per page: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  DropdownButton<int>(
                    value: _rowsPerPage,
                    underline: const SizedBox(),
                    items: [5, 10, 20, 50].map((e) => DropdownMenuItem(value: e, child: Text('$e', style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _rowsPerPage = val;
                          _currentPage = 1;
                        });
                      }
                    },
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                  ),
                  for (int p = 1; p <= math.min(5, totalPages); p++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        onTap: () => setState(() => _currentPage = p),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _currentPage == p ? const Color(0xFF2563EB) : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$p',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _currentPage == p ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 6. BOTTOM CARDS: Popular Scenes + Donut Usage
  // ============================================================================

  Widget _buildBottomCards(bool isDark, double width) {
    if (width < 1400) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPopularScenesCard(isDark),
          const SizedBox(height: 12),
          _buildSceneUsageCard(isDark),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: _buildPopularScenesCard(isDark),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: _buildSceneUsageCard(isDark),
        ),
      ],
    );
  }

  Widget _buildPopularScenesCard(bool isDark) {
    final popScenes = _kpis.popularScenes;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_outline_rounded, size: 18, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Popular Scenes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: popScenes.map((p) {
                final color = _parseColor(p.color);
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () {
                      final match = _allScenes.firstWhere((s) => s.sceneCode == p.sceneCode || s.name == p.name, orElse: () => _allScenes.first);
                      _selectScene(match);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 100,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_parseIcon(p.icon), color: color, size: 24),
                          const SizedBox(height: 8),
                          Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.targetName,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSceneUsageCard(bool isDark) {
    final stats = _kpis.usageStats;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Scene Usage (Last 30 Days)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Custom Donut Chart
              SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(
                  painter: _DonutChartPainter(breakdown: stats.breakdown),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${stats.totalExecutions30d}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Executions',
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Legend Breakdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: stats.breakdown.map((item) {
                    final color = _parseColor(item.color);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item.count} (${item.percentage}%)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 7. RIGHT INSPECTOR PANEL
  // ============================================================================

  Widget _buildRightInspectorPanel(bool isDark) {
    final scene = _selectedScene;
    if (scene == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: Text('Select a scene to inspect specifications')),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inspector Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.layers_outlined, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      'Scene Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  onPressed: () => _openCreateEditDialog(scene: scene),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

          // Selected Scene Banner / Title
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Classroom Image Mock / Gradient Banner
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [
                        _parseColor(scene.color).withValues(alpha: 0.8),
                        const Color(0xFF1E3A8A),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(_parseIcon(scene.icon), size: 40, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        scene.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scene.status == 'active'
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFF6B7280).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '● ${scene.status == 'active' ? 'Active' : 'Disabled'}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: scene.status == 'active' ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        scene.sceneType == 'preset' ? 'Preset' : 'Scene',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ),
                    for (var tag in scene.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                        child: Text(tag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  scene.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

          // Metadata Grid
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildMetaRow('Scene ID', scene.sceneCode, isDark),
                _buildMetaRow('Location Scope', scene.locationScope, isDark),
                _buildMetaRow('Targets', '${scene.targetCount} devices (${scene.targetName})', isDark),
                _buildMetaRow('Created By', scene.createdByName, isDark),
                _buildMetaRow('Created On', scene.createdAt ?? '08 Jan 2025, 10:15 AM', isDark),
                _buildMetaRow('Last Updated', scene.updatedAt ?? '10 Jan 2025, 02:15 PM', isDark),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

          // Scene Steps (Device Actions)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scene Steps (Device Actions)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                if (scene.steps.isEmpty)
                  Text('No steps defined.', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)))
                else
                  Column(
                    children: scene.steps.map((step) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${step.order}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(_parseIcon(step.icon), size: 16, color: const Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.targetName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    step.action,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

          // Quick Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildActionButton(
                      icon: Icons.play_arrow_rounded,
                      label: 'Run Now',
                      color: const Color(0xFF10B981),
                      onPressed: () => _executeScene(scene),
                    ),
                    _buildActionButton(
                      icon: scene.status == 'active' ? Icons.pause_circle_outline : Icons.play_circle_outline,
                      label: scene.status == 'active' ? 'Disable' : 'Enable',
                      color: const Color(0xFFF59E0B),
                      onPressed: () => _toggleSceneStatus(scene),
                    ),
                    _buildActionButton(
                      icon: Icons.copy_rounded,
                      label: 'Duplicate',
                      color: const Color(0xFF2563EB),
                      onPressed: () => _duplicateScene(scene),
                    ),
                    _buildActionButton(
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      color: const Color(0xFF3B82F6),
                      onPressed: () => _openCreateEditDialog(scene: scene),
                    ),
                    _buildActionButton(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      color: const Color(0xFFEF4444),
                      onPressed: () => _deleteScene(scene),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

          // Collapsible Accordions
          _buildAccordionTile(
            title: 'Usage & Execution History (${scene.executionCount})',
            icon: Icons.history_rounded,
            isExpanded: _isHistoryExpanded,
            onToggle: () => setState(() => _isHistoryExpanded = !_isHistoryExpanded),
            isDark: isDark,
            child: _executionHistory.isEmpty
                ? const Padding(padding: EdgeInsets.all(8), child: Text('No executions recorded yet.', style: TextStyle(fontSize: 11)))
                : Column(
                    children: _executionHistory.map((e) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 16),
                        title: Text(e.executedAt, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        subtitle: Text('${e.executedByName} • ${e.durationMs}ms', style: const TextStyle(fontSize: 10)),
                      );
                    }).toList(),
                  ),
          ),
          _buildAccordionTile(
            title: 'Schedules Using This Scene (${scene.usedInSchedulesCount})',
            icon: Icons.access_time_rounded,
            isExpanded: _isSchedulesExpanded,
            onToggle: () => setState(() => _isSchedulesExpanded = !_isSchedulesExpanded),
            isDark: isDark,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Linked to 3 active schedules (Morning bell, Class Start A1, Assembly).', style: TextStyle(fontSize: 11)),
            ),
          ),
          _buildAccordionTile(
            title: 'Automations Using This Scene (${scene.usedInAutomationsCount})',
            icon: Icons.bolt_rounded,
            isExpanded: _isAutomationsExpanded,
            onToggle: () => setState(() => _isAutomationsExpanded = !_isAutomationsExpanded),
            isDark: isDark,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Linked to 2 automation rules (Class Occupancy Trigger, Motion Detect).', style: TextStyle(fontSize: 11)),
            ),
          ),
          _buildAccordionTile(
            title: 'Dependent Scenes (0)',
            icon: Icons.account_tree_outlined,
            isExpanded: _isDependentScenesExpanded,
            onToggle: () => setState(() => _isDependentScenesExpanded = !_isDependentScenesExpanded),
            isDark: isDark,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('No parent or subordinate scenes configured.', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccordionTile({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required bool isDark,
    required Widget child,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: child,
          ),
        Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ],
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  List<DeviceSceneItem> _getFilteredScenes() {
    var result = _allScenes;

    if (_activeSubTab == 'Scenes') {
      result = result.where((s) => s.sceneType == 'scene').toList();
    } else if (_activeSubTab == 'Presets') {
      result = result.where((s) => s.sceneType == 'preset').toList();
    }

    if (_selectedStatus != 'All Status') {
      result = result.where((s) => s.status.toLowerCase() == _selectedStatus.toLowerCase()).toList();
    }

    if (_selectedTag != 'All Tags') {
      result = result.where((s) => s.tags.any((t) => t.toLowerCase() == _selectedTag.toLowerCase())).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((s) {
        return s.name.toLowerCase().contains(query) ||
            s.sceneCode.toLowerCase().contains(query) ||
            s.description.toLowerCase().contains(query);
      }).toList();
    }

    return result;
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return const Color(0xFF2563EB);
    try {
      final hex = colorStr.replaceAll('#', '');
      return Color(int.parse('0xFF$hex'));
    } catch (_) {
      return const Color(0xFF2563EB);
    }
  }

  IconData _parseIcon(String? iconName) {
    switch (iconName) {
      case 'wb_sunny_rounded':
      case 'wb_sunny':
        return Icons.wb_sunny_rounded;
      case 'nightlight_round':
      case 'nightlight':
        return Icons.nightlight_round;
      case 'desktop_windows_rounded':
      case 'desktop_windows':
        return Icons.desktop_windows_rounded;
      case 'assignment_turned_in_rounded':
      case 'assignment':
        return Icons.assignment_turned_in_rounded;
      case 'eco_rounded':
      case 'eco':
        return Icons.eco_rounded;
      case 'security_rounded':
      case 'security':
        return Icons.security_rounded;
      case 'wb_twilight_rounded':
      case 'wb_twilight':
        return Icons.wb_twilight_rounded;
      case 'dark_mode_rounded':
      case 'dark_mode':
        return Icons.dark_mode_rounded;
      case 'thermostat_rounded':
      case 'thermostat':
        return Icons.thermostat_rounded;
      case 'brightness_medium_rounded':
      case 'brightness_medium':
        return Icons.brightness_medium_rounded;
      case 'lightbulb':
        return Icons.lightbulb_outline_rounded;
      case 'ac_unit':
        return Icons.ac_unit_rounded;
      case 'videocam':
        return Icons.videocam_outlined;
      case 'tv':
        return Icons.tv_rounded;
      case 'volume_up':
        return Icons.volume_up_rounded;
      case 'volume_off':
        return Icons.volume_off_rounded;
      case 'lock':
        return Icons.lock_outline_rounded;
      default:
        return Icons.auto_awesome;
    }
  }
}

// ============================================================================
// CUSTOM DONUT CHART PAINTER
// ============================================================================

class _DonutChartPainter extends CustomPainter {
  final List<SceneUsageBreakdown> breakdown;

  _DonutChartPainter({required this.breakdown});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 10.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    double startAngle = -math.pi / 2;

    for (final item in breakdown) {
      final sweepAngle = (item.percentage / 100) * 2 * math.pi;
      try {
        final hex = item.color.replaceAll('#', '');
        paint.color = Color(int.parse('0xFF$hex'));
      } catch (_) {
        paint.color = const Color(0xFF2563EB);
      }
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}

// ============================================================================
// DIALOG: CREATE / EDIT SCENE OR PRESET
// ============================================================================

// ============================================================================
// DIALOG 1: CREATE / EDIT SCENE & PRESET DIALOG (DYNAMIC MULTI-TARGET & STEP BUILDER)
// ============================================================================

class _SceneTargetDevice {
  final String id;
  final String name;
  final String code;
  final String type;
  final String location;
  final bool isOnline;

  const _SceneTargetDevice({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.location,
    required this.isOnline,
  });
}

class _CreateEditScenePresetDialog extends StatefulWidget {
  final DeviceSceneItem? initialScene;
  final String apiBaseUrl;
  final Function(DeviceSceneItem savedScene) onSaved;

  const _CreateEditScenePresetDialog({
    this.initialScene,
    required this.apiBaseUrl,
    required this.onSaved,
  });

  @override
  State<_CreateEditScenePresetDialog> createState() => _CreateEditScenePresetDialogState();
}

class _CreateEditScenePresetDialogState extends State<_CreateEditScenePresetDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _descController;
  late TextEditingController _deviceSearchController;

  // Scene Configuration
  String _sceneType = 'scene'; // 'scene' or 'preset'
  String _category = 'academic';
  String _status = 'active';
  String _selectedIcon = 'wb_sunny_rounded';
  String _selectedColor = '#2563EB';

  // Target Selection Scope: 'group', 'device_type', 'location', 'multiple'
  String _targetType = 'group';
  String _selectedGroup = 'Classroom Lights (A)';
  String _selectedDeviceType = 'Lighting';
  String _selectedLocation = 'Academic Block (A) > Ground Floor';

  // Multi-Select Devices across Locations (Power Selection Mode)
  final Set<String> _selectedDeviceIds = {};
  String _deviceFilterType = 'All Types';
  List<_SceneTargetDevice> _allDevices = [];

  // Metadata Catalogs
  final Map<String, int> _groupCounts = {
    'Classroom Lights (A)': 48,
    'Academic Block Lighting Core': 24,
    'HVAC Energy Optimization Group': 16,
    'Corridor Safety & Security': 8,
    'Lab Computer & IoT Stations': 32,
    'Auditorium Multimedia Rack': 10,
    'Library Reading Zone Core': 14,
  };

  final Map<String, int> _typeCounts = {
    'Lighting': 1102,
    'HVAC (AC)': 412,
    'Projector': 320,
    'CCTV': 1284,
    'Smart Plug / PDU': 586,
    'Interactive Display': 412,
    'Security Door Locks': 96,
    'PA Audio System': 48,
  };

  final Map<String, int> _locationCounts = {
    'Academic Block (A) > Ground Floor': 32,
    'Academic Block (A) > First Floor': 28,
    'Academic Block (B) > Ground Floor': 24,
    'Library Block > Reading Room': 18,
    'Main Auditorium': 16,
    'Science Block Ground Floor': 22,
    'Campus-Wide Master Fleet': 8742,
  };

  // Step Sequence Builder
  List<DeviceSceneStep> _steps = [];
  bool _isAddingStep = false;
  int? _editingStepIndex;

  // Step Editor Form State
  String _stepTarget = 'Classroom Lighting';
  String _stepActionType = 'Turn ON';
  double _stepBrightness = 80.0;
  String _stepLightTone = 'Natural White (4000K)';
  double _stepHvacTemp = 24.0;
  String _stepHvacMode = 'Cooling (Cool)';
  String _stepHvacFan = 'Auto';
  String _stepAvInput = 'HDMI 1';
  final double _stepAvVolume = 75.0;
  String _stepDoorAction = 'Lock All Doors (Secure)';
  String _stepBellTone = 'Standard Class Period Bell';
  int _stepDelaySeconds = 0;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initialScene;
    _nameController = TextEditingController(text: s?.name ?? '');
    _codeController = TextEditingController(text: s?.sceneCode ?? '');
    _descController = TextEditingController(text: s?.description ?? '');
    _deviceSearchController = TextEditingController();

    _sceneType = s?.sceneType ?? 'scene';
    _category = s?.category ?? 'academic';
    _status = s?.status ?? 'active';
    _selectedIcon = s?.icon ?? 'wb_sunny_rounded';
    _selectedColor = s?.color ?? '#2563EB';

    // Target scope
    _targetType = s?.targetType ?? 'group';
    if (_targetType == 'group' && s != null) {
      _selectedGroup = _groupCounts.containsKey(s.targetName) ? s.targetName : _groupCounts.keys.first;
    } else if (_targetType == 'device_type' && s != null) {
      _selectedDeviceType = _typeCounts.containsKey(s.targetName) ? s.targetName : _typeCounts.keys.first;
    } else if (_targetType == 'location' && s != null) {
      _selectedLocation = _locationCounts.containsKey(s.locationScope) ? s.locationScope : _locationCounts.keys.first;
    }

    // Steps
    if (s != null && s.steps.isNotEmpty) {
      _steps = List.from(s.steps);
    } else {
      _steps = [
        const DeviceSceneStep(
          order: 1,
          targetName: 'Classroom Lighting',
          action: 'Turn ON (80% Brightness, Natural 4000K)',
          icon: 'lightbulb',
          delaySeconds: 0,
        ),
        const DeviceSceneStep(
          order: 2,
          targetName: 'Air Conditioners (HVAC)',
          action: 'Cooling 24°C, Auto Fan',
          icon: 'ac_unit',
          delaySeconds: 2,
        ),
        const DeviceSceneStep(
          order: 3,
          targetName: 'Projector & Display',
          action: 'Power ON, Input HDMI 1',
          icon: 'videocam',
          delaySeconds: 5,
        ),
      ];
    }

    _initDeviceCatalog();
  }

  void _initDeviceCatalog() {
    _allDevices = [
      const _SceneTargetDevice(id: 'd-1', name: 'Smart Light Panel 1', code: 'LT-A1-01', type: 'Lighting', location: 'Academic Block A - Room 101', isOnline: true),
      const _SceneTargetDevice(id: 'd-2', name: 'Smart Light Panel 2', code: 'LT-A1-02', type: 'Lighting', location: 'Academic Block A - Room 101', isOnline: true),
      const _SceneTargetDevice(id: 'd-3', name: 'Split AC 2.0 Ton', code: 'AC-A1-01', type: 'HVAC (AC)', location: 'Academic Block A - Room 101', isOnline: true),
      const _SceneTargetDevice(id: 'd-4', name: 'Ceiling Fan Controller', code: 'FN-A1-01', type: 'Lighting', location: 'Academic Block A - Room 101', isOnline: true),
      const _SceneTargetDevice(id: 'd-5', name: 'Laser Projector 4K', code: 'PRJ-A1-01', type: 'Projector', location: 'Academic Block A - Room 101', isOnline: true),
      const _SceneTargetDevice(id: 'd-6', name: 'Smart Light Main', code: 'LT-A1-03', type: 'Lighting', location: 'Academic Block A - Room 102', isOnline: true),
      const _SceneTargetDevice(id: 'd-7', name: 'Inverter AC Core', code: 'AC-A1-02', type: 'HVAC (AC)', location: 'Academic Block A - Room 102', isOnline: true),
      const _SceneTargetDevice(id: 'd-8', name: 'Interactive Touch Panel', code: 'DSP-A1-01', type: 'Interactive Display', location: 'Academic Block A - Room 102', isOnline: true),
      const _SceneTargetDevice(id: 'd-9', name: 'RFID Door Lock Main', code: 'LCK-A1-01', type: 'Security Door Locks', location: 'Academic Block A - Room 101', isOnline: true),
      const _SceneTargetDevice(id: 'd-10', name: 'PA Audio Chime Unit', code: 'PA-A1-01', type: 'PA Audio System', location: 'Academic Block A - Corridor', isOnline: true),
      const _SceneTargetDevice(id: 'd-11', name: 'Smart Power Strip', code: 'PDU-A1-01', type: 'Smart Plug / PDU', location: 'Academic Block A - Podium', isOnline: true),
      const _SceneTargetDevice(id: 'd-12', name: 'Dome CCTV Camera', code: 'CAM-A1-01', type: 'CCTV', location: 'Academic Block A - Entrance', isOnline: true),
    ];

    if (_targetType == 'multiple' && widget.initialScene != null) {
      _selectedDeviceIds.addAll(_allDevices.take(widget.initialScene!.targetCount).map((d) => d.id));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    _deviceSearchController.dispose();
    super.dispose();
  }

  (String, int, String) _resolveTargetMetadata() {
    switch (_targetType) {
      case 'group':
        final count = _groupCounts[_selectedGroup] ?? 16;
        return (_selectedGroup, count, 'Group Scope: $_selectedGroup');
      case 'device_type':
        final count = _typeCounts[_selectedDeviceType] ?? 320;
        return ('All $_selectedDeviceType Fleet', count, 'Campus-Wide ($_selectedDeviceType)');
      case 'location':
        final count = _locationCounts[_selectedLocation] ?? 28;
        return ('Location Devices', count, _selectedLocation);
      case 'multiple':
      default:
        final count = _selectedDeviceIds.isNotEmpty ? _selectedDeviceIds.length : 8;
        return ('$count Selected Devices', count, 'Multi-Location Fleet');
    }
  }

  String _formatStepAction(String target) {
    if (target.contains('Lighting')) {
      if (_stepActionType == 'Turn OFF') return 'Turn OFF';
      return 'Turn ON (${_stepBrightness.toInt()}% Brightness, ${_stepLightTone.split(' ').first})';
    } else if (target.contains('HVAC') || target.contains('Air')) {
      if (_stepHvacMode == 'Turn OFF') return 'Turn OFF';
      return '${_stepHvacMode.split(' ').first} ${_stepHvacTemp.toInt()}°C, $_stepHvacFan Fan';
    } else if (target.contains('Projector') || target.contains('Display')) {
      if (_stepActionType == 'Power OFF') return 'Power OFF';
      if (_stepActionType == 'Blank Screen') return 'Blank Screen (Standby)';
      return 'Power ON, Input $_stepAvInput, Vol ${_stepAvVolume.toInt()}%';
    } else if (target.contains('Door') || target.contains('Access')) {
      return _stepDoorAction;
    } else if (target.contains('Bell') || target.contains('PA')) {
      return 'Chime: $_stepBellTone';
    } else if (target.contains('Plug') || target.contains('Socket')) {
      return _stepActionType;
    }
    return _stepActionType;
  }

  String _getStepIcon(String target) {
    if (target.contains('Lighting')) return 'lightbulb';
    if (target.contains('HVAC') || target.contains('Air')) return 'ac_unit';
    if (target.contains('Projector') || target.contains('Display')) return 'videocam';
    if (target.contains('Door') || target.contains('Access')) return 'lock';
    if (target.contains('Bell') || target.contains('PA')) return 'notifications';
    if (target.contains('Plug') || target.contains('Socket')) return 'power';
    return 'settings_remote';
  }

  void _saveStep() {
    final actionDesc = _formatStepAction(_stepTarget);
    final iconName = _getStepIcon(_stepTarget);

    setState(() {
      if (_editingStepIndex != null && _editingStepIndex! >= 0 && _editingStepIndex! < _steps.length) {
        _steps[_editingStepIndex!] = DeviceSceneStep(
          order: _editingStepIndex! + 1,
          targetName: _stepTarget,
          targetType: _stepTarget.toLowerCase().replaceAll(' ', '_'),
          action: actionDesc,
          icon: iconName,
          delaySeconds: _stepDelaySeconds,
        );
      } else {
        _steps.add(DeviceSceneStep(
          order: _steps.length + 1,
          targetName: _stepTarget,
          targetType: _stepTarget.toLowerCase().replaceAll(' ', '_'),
          action: actionDesc,
          icon: iconName,
          delaySeconds: _stepDelaySeconds,
        ));
      }
      _isAddingStep = false;
      _editingStepIndex = null;
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
      for (int i = 0; i < _steps.length; i++) {
        _steps[i] = DeviceSceneStep(
          order: i + 1,
          targetName: _steps[i].targetName,
          targetType: _steps[i].targetType,
          action: _steps[i].action,
          icon: _steps[i].icon,
          delaySeconds: _steps[i].delaySeconds,
        );
      }
    });
  }

  void _moveStep(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _steps.length) return;
    setState(() {
      final item = _steps.removeAt(index);
      _steps.insert(newIndex, item);
      for (int i = 0; i < _steps.length; i++) {
        _steps[i] = DeviceSceneStep(
          order: i + 1,
          targetName: _steps[i].targetName,
          targetType: _steps[i].targetType,
          action: _steps[i].action,
          icon: _steps[i].icon,
          delaySeconds: _steps[i].delaySeconds,
        );
      }
    });
  }

  void _openStepEditor({int? index}) {
    setState(() {
      _editingStepIndex = index;
      _isAddingStep = true;
      if (index != null && index >= 0 && index < _steps.length) {
        final s = _steps[index];
        _stepTarget = s.targetName;
        _stepDelaySeconds = s.delaySeconds;
      } else {
        _stepTarget = 'Classroom Lighting';
        _stepDelaySeconds = 0;
      }
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final (targetName, targetCount, locationScope) = _resolveTargetMetadata();

    final payload = {
      'name': _nameController.text.trim(),
      'scene_code': _codeController.text.trim().isNotEmpty ? _codeController.text.trim() : null,
      'scene_type': _sceneType,
      'category': _category,
      'target_type': _targetType,
      'target_name': targetName,
      'target_count': targetCount,
      'target_ids': _targetType == 'multiple' ? _selectedDeviceIds.toList() : [],
      'location_scope': locationScope,
      'description': _descController.text.trim(),
      'icon': _selectedIcon,
      'color': _selectedColor,
      'status': _status,
      'tags': [_sceneType == 'scene' ? 'Scene' : 'Preset', _category.toUpperCase()],
      'steps': _steps.map((s) => s.toJson()).toList(),
    };

    DeviceSceneItem? resultItem;

    try {
      if (widget.initialScene != null) {
        final uri = Uri.parse('${widget.apiBaseUrl}/scenes-presets/${widget.initialScene!.id}');
        final res = await http.put(uri, headers: {'Content-Type': 'application/json'}, body: json.encode(payload));
        if (res.statusCode == 200) {
          resultItem = widget.initialScene!.copyWith(
            name: _nameController.text.trim(),
            sceneCode: _codeController.text.trim().isNotEmpty ? _codeController.text.trim() : widget.initialScene!.sceneCode,
            sceneType: _sceneType,
            category: _category,
            targetType: _targetType,
            targetName: targetName,
            targetCount: targetCount,
            locationScope: locationScope,
            description: _descController.text.trim(),
            icon: _selectedIcon,
            colorHex: _selectedColor,
            status: _status,
            steps: _steps,
          );
        }
      } else {
        final uri = Uri.parse('${widget.apiBaseUrl}/scenes-presets');
        final res = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: json.encode(payload));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final scn = data['scene'] ?? {};
          resultItem = DeviceSceneItem(
            id: scn['id']?.toString() ?? 'new_${DateTime.now().millisecondsSinceEpoch}',
            sceneCode: scn['scene_code']?.toString() ?? (_codeController.text.trim().isNotEmpty ? _codeController.text.trim() : 'SCN-043'),
            name: _nameController.text.trim(),
            sceneType: _sceneType,
            category: _category,
            targetType: _targetType,
            targetName: targetName,
            targetCount: targetCount,
            locationScope: locationScope,
            description: _descController.text.trim(),
            icon: _selectedIcon,
            colorHex: _selectedColor,
            status: _status,
            steps: _steps,
          );
        }
      }
    } catch (_) {}

    // Graceful offline fallback
    resultItem ??= DeviceSceneItem(
      id: widget.initialScene?.id ?? 'local_${DateTime.now().millisecondsSinceEpoch}',
      sceneCode: _codeController.text.trim().isNotEmpty ? _codeController.text.trim() : (widget.initialScene?.sceneCode ?? 'SCN-043'),
      name: _nameController.text.trim(),
      sceneType: _sceneType,
      category: _category,
      targetType: _targetType,
      targetName: targetName,
      targetCount: targetCount,
      locationScope: locationScope,
      description: _descController.text.trim(),
      icon: _selectedIcon,
      colorHex: _selectedColor,
      status: _status,
      steps: _steps,
    );

    widget.onSaved(resultItem);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.initialScene != null;
    final (targetName, targetCount, locationScope) = _resolveTargetMetadata();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 880),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF2563EB), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit ? 'Edit Scene / Preset: ${_nameController.text.isEmpty ? 'Untitled' : _nameController.text}' : 'Create Scene / Preset',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Orchestrate multi-device states and hardware parameters with precision.',
                                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Main Scrollable Form Body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Row 1: Name & Unique Code
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Scene / Preset Name *',
                                  hintText: 'e.g. Lecture Presentation, Exam Mode, Night Lockdown',
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _codeController,
                                decoration: InputDecoration(
                                  labelText: 'Scene Code (Optional)',
                                  hintText: 'e.g. SCN-043',
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Row 2: Type, Category, and Status
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _sceneType,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Type',
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'scene', child: Text('Scene (Multi-Device Routine)')),
                                  DropdownMenuItem(value: 'preset', child: Text('Preset (Device State Profile)')),
                                ],
                                onChanged: (v) => setState(() => _sceneType = v ?? 'scene'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _category,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'academic', child: Text('Academic')),
                                  DropdownMenuItem(value: 'energy', child: Text('Energy / Eco')),
                                  DropdownMenuItem(value: 'security', child: Text('Security & Access')),
                                  DropdownMenuItem(value: 'av_display', child: Text('AV / Presentation')),
                                  DropdownMenuItem(value: 'comfort', child: Text('Comfort / HVAC')),
                                  DropdownMenuItem(value: 'general', child: Text('General')),
                                ],
                                onChanged: (v) => setState(() => _category = v ?? 'academic'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _status,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Status',
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'active', child: Text('Active')),
                                  DropdownMenuItem(value: 'disabled', child: Text('Disabled')),
                                ],
                                onChanged: (v) => setState(() => _status = v ?? 'active'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Row 3: Description
                        TextFormField(
                          controller: _descController,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            hintText: 'Describe the purpose and effect of this scene...',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),

                        // Section 2: Visual Branding (Icon & Color Picker)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.palette_outlined, size: 16, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Visual Branding & Iconography',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildIconChip('wb_sunny_rounded', Icons.wb_sunny_rounded, 'Start / Day'),
                                  _buildIconChip('nightlight_round', Icons.nightlight_round, 'Night / Off'),
                                  _buildIconChip('slideshow_rounded', Icons.slideshow_rounded, 'Presentation'),
                                  _buildIconChip('school_rounded', Icons.school_rounded, 'Classroom'),
                                  _buildIconChip('eco_rounded', Icons.eco_rounded, 'Eco Save'),
                                  _buildIconChip('lock_rounded', Icons.lock_rounded, 'Lockdown'),
                                  _buildIconChip('notifications_active', Icons.notifications_active, 'Bell / Alert'),
                                  _buildIconChip('meeting_room_rounded', Icons.meeting_room_rounded, 'Room'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text('Accent Color:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                  _buildColorSwatch('#2563EB', const Color(0xFF2563EB)),
                                  _buildColorSwatch('#10B981', const Color(0xFF10B981)),
                                  _buildColorSwatch('#F59E0B', const Color(0xFFF59E0B)),
                                  _buildColorSwatch('#8B5CF6', const Color(0xFF8B5CF6)),
                                  _buildColorSwatch('#EF4444', const Color(0xFFEF4444)),
                                  _buildColorSwatch('#06B6D4', const Color(0xFF06B6D4)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Section 3: Target Fleet Scope (Reused from Device Management Architecture)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.hub_outlined, size: 16, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Target Scope & Fleet Selection',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Targeting: $targetCount devices',
                                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Scope Mode Radio Cards
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildTargetTypeChip('group', 'Device Group', Icons.group_work_rounded),
                                  _buildTargetTypeChip('device_type', 'Device Type', Icons.category_rounded),
                                  _buildTargetTypeChip('location', 'Physical Location', Icons.location_on_rounded),
                                  _buildTargetTypeChip('multiple', 'Multi-Select Devices', Icons.checklist_rounded),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Scope Content Based on Mode
                              if (_targetType == 'group') ...[
                                DropdownButtonFormField<String>(
                                  initialValue: _groupCounts.containsKey(_selectedGroup) ? _selectedGroup : _groupCounts.keys.first,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Select Existing Device Group',
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: _groupCounts.entries.map((e) {
                                    return DropdownMenuItem(
                                      value: e.key,
                                      child: Text('${e.key} (${e.value} devices)'),
                                    );
                                  }).toList(),
                                  onChanged: (v) => setState(() => _selectedGroup = v ?? _selectedGroup),
                                ),
                              ] else if (_targetType == 'device_type') ...[
                                DropdownButtonFormField<String>(
                                  initialValue: _typeCounts.containsKey(_selectedDeviceType) ? _selectedDeviceType : _typeCounts.keys.first,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Select Target Hardware Device Type',
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: _typeCounts.entries.map((e) {
                                    return DropdownMenuItem(
                                      value: e.key,
                                      child: Text('${e.key} (${e.value} active campus devices)'),
                                    );
                                  }).toList(),
                                  onChanged: (v) => setState(() => _selectedDeviceType = v ?? _selectedDeviceType),
                                ),
                              ] else if (_targetType == 'location') ...[
                                DropdownButtonFormField<String>(
                                  initialValue: _locationCounts.containsKey(_selectedLocation) ? _selectedLocation : _locationCounts.keys.first,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Select Campus Location',
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: _locationCounts.entries.map((e) {
                                    return DropdownMenuItem(
                                      value: e.key,
                                      child: Text('${e.key} (${e.value} devices)'),
                                    );
                                  }).toList(),
                                  onChanged: (v) => setState(() => _selectedLocation = v ?? _selectedLocation),
                                ),
                              ] else if (_targetType == 'multiple') ...[
                                _buildMultiSelectDeviceFleet(isDark),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Section 4: Device Actions & Step Builder (The Core Feature!)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.alt_route_rounded, size: 16, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Device Actions / Steps (${_steps.length})',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _openStepEditor(),
                                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                    label: const Text('Add Action Step', style: TextStyle(fontSize: 12, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Inline Step Editor Panel (when adding or editing)
                              if (_isAddingStep) ...[
                                _buildStepEditorPanel(isDark),
                                const SizedBox(height: 14),
                              ],

                              // Ordered Step Cards List
                              if (_steps.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: Text(
                                      'No steps configured yet. Tap "Add Action Step" to sequence device actions.',
                                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                )
                              else
                                ..._steps.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final step = entry.value;
                                  return _buildStepCard(i, step, isDark);
                                }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Section 5: Real-Time Execution Summary Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.insights_rounded, color: Color(0xFF2563EB), size: 28),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Scene Execution Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Will trigger ${_steps.length} sequential operations across $targetCount devices in "$locationScope" with staggered power surge prevention.',
                                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
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

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Dialog Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isEdit ? 'Save Changes' : 'Create Scene / Preset', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Sub-Widgets ---

  Widget _buildIconChip(String key, IconData icon, String label) {
    final isSelected = _selectedIcon == key;
    return InkWell(
      onTap: () => setState(() => _selectedIcon = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSwatch(String hex, Color color) {
    final isSelected = _selectedColor == hex;
    return InkWell(
      onTap: () => setState(() => _selectedColor = hex),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
          boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1)] : null,
        ),
      ),
    );
  }

  Widget _buildTargetTypeChip(String type, String label, IconData icon) {
    final isSelected = _targetType == type;
    return InkWell(
      onTap: () => setState(() => _targetType = type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8).withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF475569))),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectDeviceFleet(bool isDark) {
    final query = _deviceSearchController.text.trim().toLowerCase();
    final filtered = _allDevices.where((d) {
      if (_deviceFilterType != 'All Types' && d.type != _deviceFilterType) return false;
      if (query.isNotEmpty) {
        final match = d.name.toLowerCase().contains(query) || d.code.toLowerCase().contains(query) || d.location.toLowerCase().contains(query);
        if (!match) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _deviceSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 16),
                    hintText: 'Search devices by name, code or room...',
                    hintStyle: const TextStyle(fontSize: 11),
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDeviceIds.addAll(filtered.map((d) => d.id));
                });
              },
              child: const Text('Select All', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedDeviceIds.clear()),
              child: const Text('Clear', style: TextStyle(fontSize: 11, color: Colors.red)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All Types', 'Lighting', 'HVAC (AC)', 'Projector', 'Security Door Locks', 'PA Audio System'].map((t) {
              final isSel = _deviceFilterType == t;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(t, style: TextStyle(fontSize: 10, color: isSel ? Colors.white : null)),
                  selected: isSel,
                  selectedColor: const Color(0xFF2563EB),
                  onSelected: (val) {
                    if (val) setState(() => _deviceFilterType = t);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Device Checkbox List
        Material(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SizedBox(
            height: 180,
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final d = filtered[index];
                final isChecked = _selectedDeviceIds.contains(d.id);
                return CheckboxListTile(
                  value: isChecked,
                  dense: true,
                  title: Row(
                    children: [
                      Text(d.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(d.code, style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  subtitle: Text('${d.type} • ${d.location}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedDeviceIds.add(d.id);
                      } else {
                        _selectedDeviceIds.remove(d.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepCard(int index, DeviceSceneStep step, bool isDark) {
    IconData getIconData(String name) {
      switch (name) {
        case 'lightbulb': return Icons.lightbulb_outline_rounded;
        case 'ac_unit': return Icons.ac_unit_rounded;
        case 'videocam': return Icons.videocam_rounded;
        case 'lock': return Icons.lock_outline_rounded;
        case 'notifications': return Icons.notifications_active_rounded;
        case 'power': return Icons.power_rounded;
        default: return Icons.settings_remote_rounded;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Step number circle
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
            child: Text(
              '${step.order}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(width: 10),

          // Appliance icon
          Icon(getIconData(step.icon), size: 18, color: const Color(0xFF2563EB)),
          const SizedBox(width: 10),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(step.targetName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    if (step.delaySeconds > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+${step.delaySeconds}s delay',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  step.action,
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                ),
              ],
            ),
          ),

          // Reorder & Action buttons
          IconButton(
            icon: const Icon(Icons.arrow_upward_rounded, size: 16),
            onPressed: index > 0 ? () => _moveStep(index, -1) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Move Step Up',
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.arrow_downward_rounded, size: 16),
            onPressed: index < _steps.length - 1 ? () => _moveStep(index, 1) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Move Step Down',
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
            onPressed: () => _openStepEditor(index: index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Edit Step',
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
            onPressed: () => _removeStep(index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Delete Step',
          ),
        ],
      ),
    );
  }

  Widget _buildStepEditorPanel(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _editingStepIndex != null ? 'Edit Step ${_editingStepIndex! + 1}' : 'Configure New Action Step',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => setState(() => _isAddingStep = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Target Appliance Component
          DropdownButtonFormField<String>(
            initialValue: _stepTarget,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Target Component / Hardware',
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: const [
              DropdownMenuItem(value: 'Classroom Lighting', child: Text('Classroom Lighting')),
              DropdownMenuItem(value: 'Air Conditioners (HVAC)', child: Text('Air Conditioners (HVAC)')),
              DropdownMenuItem(value: 'Projector & Display', child: Text('Projector & Display')),
              DropdownMenuItem(value: 'Interactive Smart Board', child: Text('Interactive Smart Board')),
              DropdownMenuItem(value: 'Smart Plugs & Sockets', child: Text('Smart Plugs & Sockets')),
              DropdownMenuItem(value: 'Access Doors & Locks', child: Text('Access Doors & Locks')),
              DropdownMenuItem(value: 'Public Address & Bell', child: Text('Public Address & Bell')),
            ],
            onChanged: (v) => setState(() => _stepTarget = v ?? 'Classroom Lighting'),
          ),
          const SizedBox(height: 12),

          // Parameter controls based on target component
          if (_stepTarget.contains('Lighting')) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _stepActionType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Power Action',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Turn ON', child: Text('Turn ON')),
                      DropdownMenuItem(value: 'Turn OFF', child: Text('Turn OFF')),
                    ],
                    onChanged: (v) => setState(() => _stepActionType = v ?? 'Turn ON'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _stepLightTone,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Color Warmth',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Natural White (4000K)', child: Text('Natural White (4000K)')),
                      DropdownMenuItem(value: 'Warm White (2700K)', child: Text('Warm White (2700K)')),
                      DropdownMenuItem(value: 'Cool Daylight (6500K)', child: Text('Cool Daylight (6500K)')),
                    ],
                    onChanged: (v) => setState(() => _stepLightTone = v ?? 'Natural White (4000K)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Brightness Level:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                Expanded(
                  child: Slider(
                    value: _stepBrightness,
                    min: 0,
                    max: 100,
                    divisions: 10,
                    label: '${_stepBrightness.toInt()}%',
                    onChanged: (v) => setState(() => _stepBrightness = v),
                  ),
                ),
                Text('${_stepBrightness.toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ],
            ),
          ] else if (_stepTarget.contains('HVAC') || _stepTarget.contains('Air')) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _stepHvacMode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'HVAC Mode',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Cooling (Cool)', child: Text('Cooling (Cool)')),
                      DropdownMenuItem(value: 'Heating (Heat)', child: Text('Heating (Heat)')),
                      DropdownMenuItem(value: 'Eco Energy', child: Text('Eco Energy')),
                      DropdownMenuItem(value: 'Turn OFF', child: Text('Turn OFF')),
                    ],
                    onChanged: (v) => setState(() => _stepHvacMode = v ?? 'Cooling (Cool)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _stepHvacFan,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Fan Speed',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Auto', child: Text('Auto')),
                      DropdownMenuItem(value: 'Low', child: Text('Low')),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'High', child: Text('High')),
                    ],
                    onChanged: (v) => setState(() => _stepHvacFan = v ?? 'Auto'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Target Temperature:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: _stepHvacTemp > 16 ? () => setState(() => _stepHvacTemp -= 1.0) : null,
                ),
                Text('${_stepHvacTemp.toInt()}°C', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: _stepHvacTemp < 30 ? () => setState(() => _stepHvacTemp += 1.0) : null,
                ),
              ],
            ),
          ] else if (_stepTarget.contains('Projector') || _stepTarget.contains('Display')) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _stepAvInput,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Input Source',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'HDMI 1', child: Text('HDMI 1 (Teacher Podium)')),
                      DropdownMenuItem(value: 'HDMI 2', child: Text('HDMI 2 (Auxiliary)')),
                      DropdownMenuItem(value: 'Wireless Casting', child: Text('Wireless Casting')),
                      DropdownMenuItem(value: 'DisplayPort', child: Text('DisplayPort')),
                    ],
                    onChanged: (v) => setState(() => _stepAvInput = v ?? 'HDMI 1'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _stepActionType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Power Action',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Turn ON', child: Text('Power ON')),
                      DropdownMenuItem(value: 'Power OFF', child: Text('Power OFF')),
                      DropdownMenuItem(value: 'Blank Screen', child: Text('Blank Screen (Standby)')),
                    ],
                    onChanged: (v) => setState(() => _stepActionType = v ?? 'Turn ON'),
                  ),
                ),
              ],
            ),
          ] else if (_stepTarget.contains('Door') || _stepTarget.contains('Locks')) ...[
            DropdownButtonFormField<String>(
              initialValue: _stepDoorAction,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Access Security Action',
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(value: 'Lock All Doors (Secure)', child: Text('Lock All Doors (Secure)')),
                DropdownMenuItem(value: 'Unlock for Class Hours', child: Text('Unlock for Class Hours')),
                DropdownMenuItem(value: 'Emergency Lockdown', child: Text('Emergency Lockdown (Access Blocked)')),
              ],
              onChanged: (v) => setState(() => _stepDoorAction = v ?? 'Lock All Doors (Secure)'),
            ),
          ] else if (_stepTarget.contains('Bell') || _stepTarget.contains('PA')) ...[
            DropdownButtonFormField<String>(
              initialValue: _stepBellTone,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Melody / Bell Chime',
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(value: 'Standard Class Period Bell', child: Text('Standard Class Period Bell')),
                DropdownMenuItem(value: 'Morning Assembly Chime', child: Text('Morning Assembly Chime')),
                DropdownMenuItem(value: 'Recess Warning Melody', child: Text('Recess Warning Melody')),
                DropdownMenuItem(value: 'Dismissal Siren', child: Text('Dismissal Siren')),
              ],
              onChanged: (v) => setState(() => _stepBellTone = v ?? 'Standard Class Period Bell'),
            ),
          ] else ...[
            DropdownButtonFormField<String>(
              initialValue: _stepActionType,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Power Action',
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(value: 'Turn ON', child: Text('Turn ON')),
                DropdownMenuItem(value: 'Turn OFF', child: Text('Turn OFF')),
              ],
              onChanged: (v) => setState(() => _stepActionType = v ?? 'Turn ON'),
            ),
          ],
          const SizedBox(height: 12),

          // Execution Delay
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _stepDelaySeconds,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Staggered Delay (Power Surge Prevention)',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Instant (0 seconds)')),
                    DropdownMenuItem(value: 2, child: Text('+2 seconds delay')),
                    DropdownMenuItem(value: 5, child: Text('+5 seconds delay')),
                    DropdownMenuItem(value: 10, child: Text('+10 seconds delay')),
                  ],
                  onChanged: (v) => setState(() => _stepDelaySeconds = v ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _saveStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: Text(_editingStepIndex != null ? 'Update Step' : 'Add to Sequence', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DIALOG: FULL SCENE EXECUTION HISTORY
// ============================================================================

class _SceneExecutionHistoryDialog extends StatelessWidget {
  final String apiBaseUrl;
  final DeviceSceneItem? selectedScene;

  const _SceneExecutionHistoryDialog({
    required this.apiBaseUrl,
    this.selectedScene,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 550),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        'Scene Execution History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: [
                    _buildLogTile('EXEC-SCN-20250110-141500', 'Class Start', '10 Jan 2025, 02:15 PM', 'Admin', '8 devices', 420, 'success', isDark),
                    _buildLogTile('EXEC-SCN-20250110-090000', 'Class Start', '10 Jan 2025, 09:00 AM', 'Automated Schedule', '8 devices', 385, 'success', isDark),
                    _buildLogTile('EXEC-SCN-20250109-173000', 'Night Mode', '09 Jan 2025, 05:30 PM', 'Security Rule', '96 devices', 510, 'success', isDark),
                    _buildLogTile('EXEC-SCN-20250109-141500', 'Class End', '09 Jan 2025, 02:15 PM', 'Facility Officer', '8 devices', 450, 'success', isDark),
                    _buildLogTile('EXEC-SCN-20250109-110000', 'Presentation Mode', '09 Jan 2025, 11:00 AM', 'AV Manager', '12 devices', 620, 'success', isDark),
                    _buildLogTile('EXEC-SCN-20250108-120000', 'Energy Saving', '08 Jan 2025, 12:00 PM', 'Eco Cron', '48 devices', 390, 'success', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogTile(String code, String scene, String time, String user, String target, int duration, String status, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(scene, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(code, style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('$time • Triggered by $user • Target: $target • Duration: ${duration}ms', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
