import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/device_management_models.dart';
import '../../../services/device_management_api_service.dart';
import '../dialogs/add_device_wizard_dialog.dart';
import '../dialogs/device_details_drawer.dart';
import '../../common/campus_pagination_bar.dart';

/// Enterprise Device Registry Subview for EduSHAMIIT ERP
/// Provides independent filtering, server-side sorting, pagination, multi-selection,
/// full CRUD operations, real-time KPIs, and responsive design across all devices.
class DeviceRegistrySubview extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  final String? schoolId;
  final List<DeviceItemModel>? initialDevices;
  final DeviceManagementKpis? initialKpis;
  final List<String>? initialBuildings;
  final List<String>? initialTypes;

  const DeviceRegistrySubview({
    super.key,
    this.onBackToDashboard,
    this.schoolId,
    this.initialDevices,
    this.initialKpis,
    this.initialBuildings,
    this.initialTypes,
  });

  @override
  State<DeviceRegistrySubview> createState() => _DeviceRegistrySubviewState();
}

class _DeviceRegistrySubviewState extends State<DeviceRegistrySubview> {
  final DeviceManagementApiService _api = DeviceManagementApiService.instance;

  // Loading States
  bool _isLoading = true;
  bool _isKpiLoading = true;

  // Devices & Pagination State
  List<DeviceItemModel> _devices = [];
  int _totalDevices = 0;
  int _currentPage = 1;
  int _pageSize = 10;

  // Sorting State
  String _sortColumn = 'created_at';
  bool _sortAscending = false;

  // Filter State (Completely Isolated from other tabs)
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedBuilding = 'All Buildings';
  String _selectedType = 'All Device Types';
  String _selectedStatus = 'All Status';

  // Dynamic Dropdown Options
  List<String> _buildingOptions = ['All Buildings'];
  List<String> _typeOptions = ['All Device Types'];
  final List<String> _statusOptions = ['All Status', 'Online', 'Offline'];

  // Multi-Selection State
  final Set<String> _selectedDeviceIds = {};

  // KPIs State
  DeviceManagementKpis _kpis = const DeviceManagementKpis();

  // Selected Device for Drawer
  DeviceItemModel? _activeDrawerDevice;

  @override
  void initState() {
    super.initState();
    if (widget.initialDevices != null) {
      _devices = List.from(widget.initialDevices!);
      _totalDevices = _devices.length;
      _isLoading = false;
    }
    if (widget.initialKpis != null) {
      _kpis = widget.initialKpis!;
      _isKpiLoading = false;
    }
    if (widget.initialBuildings != null) {
      _buildingOptions = List.from(widget.initialBuildings!);
    }
    if (widget.initialTypes != null) {
      _typeOptions = List.from(widget.initialTypes!);
    }

    if (widget.initialDevices == null) {
      _loadInitialData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadKpis(),
      _loadFilterOptions(),
      _loadDevices(),
    ]);
  }

  Future<void> _loadKpis() async {
    setState(() => _isKpiLoading = true);
    try {
      final kpiData = await _api.getRegistryKpis(schoolId: widget.schoolId);
      if (mounted) {
        setState(() {
          _kpis = kpiData;
          _isKpiLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isKpiLoading = false);
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      final overview = await _api.getOverview();
      if (overview.isNotEmpty && mounted) {
        final bldList = overview['buildings_breakdown'] as List? ?? [];
        final bldNames = <String>['All Buildings'];
        for (var b in bldList) {
          if (b is Map && b['name'] != null) {
            bldNames.add(b['name'].toString());
          }
        }

        final typeList = overview['devices_by_type'] as List? ?? [];
        final typeNames = <String>['All Device Types'];
        for (var t in typeList) {
          if (t is Map && t['type_name'] != null) {
            typeNames.add(t['type_name'].toString());
          }
        }

        setState(() {
          _buildingOptions = bldNames;
          _typeOptions = typeNames;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final bldFilter = (_selectedBuilding == 'All Buildings') ? null : _selectedBuilding;
      final typeFilter = (_selectedType == 'All Device Types') ? null : _selectedType;
      final statusFilter = (_selectedStatus == 'All Status') ? null : _selectedStatus.toLowerCase();

      final res = await _api.listDevices(
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        buildingId: bldFilter,
        typeCode: typeFilter,
        status: statusFilter,
        page: _currentPage,
        pageSize: _pageSize,
        sortBy: _sortColumn,
        sortOrder: _sortAscending ? 'asc' : 'desc',
      );

      if (mounted) {
        final rawList = res['devices'] as List? ?? [];
        final list = rawList
            .map((e) => DeviceItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        setState(() {
          _devices = list;
          _totalDevices = (res['total'] as num?)?.toInt() ?? list.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
      _currentPage = 1;
    });
    if (widget.initialDevices != null) {
      _sortLocalDevices();
    } else {
      _loadDevices();
    }
  }

  void _sortLocalDevices() {
    setState(() {
      _devices.sort((a, b) {
        int cmp = 0;
        switch (_sortColumn) {
          case 'device_name':
            cmp = a.deviceName.compareTo(b.deviceName);
            break;
          case 'device_code':
            cmp = a.deviceCode.compareTo(b.deviceCode);
            break;
          case 'type_name':
            cmp = a.typeName.compareTo(b.typeName);
            break;
          case 'location_path':
            cmp = a.locationDisplay.compareTo(b.locationDisplay);
            break;
          case 'ip_address':
            cmp = (a.ipAddress ?? '').compareTo(b.ipAddress ?? '');
            break;
          case 'status':
            cmp = (a.isOnline ? 1 : 0).compareTo(b.isOnline ? 1 : 0);
            break;
          default:
            cmp = a.deviceName.compareTo(b.deviceName);
        }
        return _sortAscending ? cmp : -cmp;
      });
    });
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
      _currentPage = 1;
    });
    if (widget.initialDevices != null) {
      if (val.trim().isEmpty) {
        setState(() {
          _devices = List.from(widget.initialDevices!);
          _totalDevices = _devices.length;
        });
      } else {
        final q = val.toLowerCase();
        setState(() {
          _devices = widget.initialDevices!.where((d) {
            return d.deviceName.toLowerCase().contains(q) ||
                d.deviceCode.toLowerCase().contains(q) ||
                (d.ipAddress != null && d.ipAddress!.contains(q));
          }).toList();
          _totalDevices = _devices.length;
        });
      }
    } else {
      _loadDevices();
    }
  }

  void _onBuildingChanged(String? val) {
    if (val == null) return;
    setState(() {
      _selectedBuilding = val;
      _currentPage = 1;
    });
    _loadDevices();
  }

  void _onTypeChanged(String? val) {
    if (val == null) return;
    setState(() {
      _selectedType = val;
      _currentPage = 1;
    });
    _loadDevices();
  }

  void _onStatusChanged(String? val) {
    if (val == null) return;
    setState(() {
      _selectedStatus = val;
      _currentPage = 1;
    });
    _loadDevices();
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedBuilding = 'All Buildings';
      _selectedType = 'All Device Types';
      _selectedStatus = 'All Status';
      _currentPage = 1;
    });
    if (widget.initialDevices != null) {
      setState(() {
        _devices = List.from(widget.initialDevices!);
        _totalDevices = _devices.length;
      });
    } else {
      _loadDevices();
    }
  }

  void _toggleSelectAllOnPage() {
    setState(() {
      final pageIds = _devices.map((d) => d.id).toSet();
      if (_selectedDeviceIds.containsAll(pageIds)) {
        _selectedDeviceIds.removeAll(pageIds);
      } else {
        _selectedDeviceIds.addAll(pageIds);
      }
    });
  }

  void _toggleSelectDevice(String id) {
    setState(() {
      if (_selectedDeviceIds.contains(id)) {
        _selectedDeviceIds.remove(id);
      } else {
        _selectedDeviceIds.add(id);
      }
    });
  }

  // --- CRUD: Create Device ---
  void _openAddDeviceWizard() {
    showDialog(
      context: context,
      builder: (ctx) => AddDeviceWizardDialog(
        onSaved: () {
          _loadDevices();
          _loadKpis();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device registered successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }

  // --- CRUD: Delete Device ---
  Future<void> _confirmDeleteDevice(DeviceItemModel device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${device.deviceName}?'),
        content: Text(
          'Are you sure you want to remove ${device.deviceName} (${device.deviceCode}) from the device registry? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await _api.deleteDevice(device.id);
      if (mounted) {
        if (res['success'] == true) {
          _selectedDeviceIds.remove(device.id);
          _loadDevices();
          _loadKpis();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Device "${device.deviceName}" deleted successfully.'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Failed to delete device.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // --- CRUD: Bulk Delete ---
  Future<void> _confirmBulkDelete() async {
    final count = _selectedDeviceIds.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count Selected Devices?'),
        content: Text(
          'Are you sure you want to delete these $count selected devices from the campus database? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All Selected'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await _api.bulkDeleteDevices(_selectedDeviceIds.toList());
      if (mounted) {
        if (res['success'] == true) {
          setState(() => _selectedDeviceIds.clear());
          _loadDevices();
          _loadKpis();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count devices removed successfully.'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Failed to delete selected devices.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // --- Bulk Commands (Turn ON / Turn OFF / Reboot) ---
  Future<void> _executeBulkCommand(String commandType, Map<String, dynamic> payload) async {
    final count = _selectedDeviceIds.length;
    if (count == 0) return;

    final res = await _api.executeBulkCommand(_selectedDeviceIds.toList(), commandType, payload);
    if (mounted) {
      if (res['success'] == true) {
        _loadDevices();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bulk $commandType executed on $count devices.'),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to execute command.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- Reboot Single Device ---
  Future<void> _rebootDevice(DeviceItemModel device) async {
    final res = await _api.rebootDevice(device.id);
    if (mounted) {
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reboot command sent to "${device.deviceName}".'),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to reboot device.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- Toggle Power State Single Device ---
  Future<void> _togglePower(DeviceItemModel device) async {
    final newPower = !device.powerState;
    final res = await _api.executeCommand(
      device.id,
      newPower ? 'turn_on' : 'turn_off',
      {'power': newPower},
    );
    if (mounted && res['success'] == true) {
      _loadDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;
            final isTablet = constraints.maxWidth >= 768 && constraints.maxWidth < 1150;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header with Title & Action Button
                  _buildHeader(isDark, isMobile),
                  const SizedBox(height: 14),

                  // 2. Real-Time Fleet KPIs (Stored Procedure Driven)
                  _buildKpiSection(isDark, isMobile, isTablet),
                  const SizedBox(height: 14),

                  // 3. Independent Filters Bar
                  _buildFilterBar(isDark, isMobile),
                  const SizedBox(height: 10),

                  // 4. Active Filters Badges Strip
                  if (_hasActiveFilters()) ...[
                    _buildActiveFilterChips(isDark),
                    const SizedBox(height: 10),
                  ],

                  // 5. Sticky Batch Selection Action Toolbar
                  if (_selectedDeviceIds.isNotEmpty) ...[
                    _buildBatchActionToolbar(isDark, isMobile),
                    const SizedBox(height: 10),
                  ],

                  // 6. Data Grid Card
                  _buildGridCard(isDark, constraints.maxWidth),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),

        // Device Details Slide Drawer (when active)
        if (_activeDrawerDevice != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _activeDrawerDevice = null),
              child: Container(
                color: Colors.black45,
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {}, // Prevent tap through
                  child: SizedBox(
                    width: math.min(MediaQuery.of(context).size.width * 0.85, 480),
                    height: double.infinity,
                    child: DeviceDetailsDrawer(
                      device: _activeDrawerDevice!,
                      onClose: () => setState(() => _activeDrawerDevice = null),
                      onTogglePower: () => _togglePower(_activeDrawerDevice!),
                      onReboot: () => _rebootDevice(_activeDrawerDevice!),
                      onDelete: () {
                        final d = _activeDrawerDevice!;
                        setState(() => _activeDrawerDevice = null);
                        _confirmDeleteDevice(d);
                      },
                      onUpdateDevice: (updatedData) async {
                        final sm = ScaffoldMessenger.of(context);
                        final devId = _activeDrawerDevice!.id;
                        final ok = await _api.updateDevice(devId, updatedData);
                        if (ok && mounted) {
                          _loadDevices();
                          setState(() => _activeDrawerDevice = null);
                          sm.showSnackBar(
                            const SnackBar(
                              content: Text('Device updated successfully.'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================================
  // HEADER
  // ============================================================================
  Widget _buildHeader(bool isDark, bool isMobile) {
    return Row(
      children: [
        if (widget.onBackToDashboard != null) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: widget.onBackToDashboard,
            tooltip: 'Back to Dashboard',
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Campus Device Registry & Fleet Control',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Full registry of all $_totalDevices connected campus devices across all blocks and floors',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh Registry',
          onPressed: () {
            _loadKpis();
            _loadDevices();
          },
        ),
        const SizedBox(width: 8),
        // Single "+" icon on Add Device (Zero double ++)
        ElevatedButton.icon(
          onPressed: _openAddDeviceWizard,
          icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
          label: const Text(
            'Add Device',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // REAL-TIME FLEET KPIS (Stored Procedure fn_get_device_registry_kpis)
  // ============================================================================
  Widget _buildKpiSection(bool isDark, bool isMobile, bool isTablet) {
    if (_isKpiLoading) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final kpiCards = [
      _buildKpiCard(
        title: 'Total Devices',
        value: '${_kpis.totalDevices}',
        subtitle: 'Registered in campus',
        icon: Icons.devices_rounded,
        color: const Color(0xFF2563EB),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Online Fleet',
        value: '${_kpis.online}',
        subtitle: '${_kpis.onlinePercentage.toStringAsFixed(1)}% Operational',
        icon: Icons.wifi_rounded,
        color: const Color(0xFF10B981),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Offline / Attention',
        value: '${_kpis.offline}',
        subtitle: _kpis.offline > 0 ? 'Requires inspection' : 'All systems active',
        icon: Icons.wifi_off_rounded,
        color: _kpis.offline > 0 ? const Color(0xFFEF4444) : const Color(0xFF64748B),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Device Types',
        value: '${_kpis.deviceTypes}',
        subtitle: 'Hardware categories',
        icon: Icons.category_rounded,
        color: const Color(0xFF8B5CF6),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Campus Coverage',
        value: '${_kpis.buildingsCount} Blocks',
        subtitle: '${_kpis.floorsCount} Floors • ${_kpis.roomsCount} Rooms',
        icon: Icons.domain_rounded,
        color: const Color(0xFF06B6D4),
        isDark: isDark,
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kpiCards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, index) => SizedBox(width: 170, child: kpiCards[index]),
        ),
      );
    } else if (isTablet) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: kpiCards.map((c) => SizedBox(width: 190, child: c)).toList(),
      );
    }

    return Row(
      children: kpiCards.map((c) => Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: c,
      ))).toList(),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
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
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // FILTER BAR
  // ============================================================================
  Widget _buildFilterBar(bool isDark, bool isMobile) {
    final searchField = SizedBox(
      height: 38,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: 'Search device (name, code, IP, MAC, room)...',
          hintStyle: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2563EB)),
          ),
        ),
      ),
    );

    final bldDropdown = _buildDropdown(
      value: _selectedBuilding,
      options: _buildingOptions,
      onChanged: _onBuildingChanged,
      icon: Icons.business_rounded,
      isDark: isDark,
    );

    final typeDropdown = _buildDropdown(
      value: _selectedType,
      options: _typeOptions,
      onChanged: _onTypeChanged,
      icon: Icons.category_outlined,
      isDark: isDark,
    );

    final statusDropdown = _buildDropdown(
      value: _selectedStatus,
      options: _statusOptions,
      onChanged: _onStatusChanged,
      icon: Icons.toggle_on_outlined,
      isDark: isDark,
    );

    final clearBtn = OutlinedButton.icon(
      onPressed: _hasActiveFilters() ? _clearAllFilters : null,
      icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
      label: const Text('Clear', style: TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: bldDropdown),
                    const SizedBox(width: 8),
                    Expanded(child: statusDropdown),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: typeDropdown),
                    const SizedBox(width: 8),
                    clearBtn,
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(flex: 3, child: searchField),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: bldDropdown),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: typeDropdown),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: statusDropdown),
                const SizedBox(width: 10),
                clearBtn,
              ],
            ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    required IconData icon,
    required bool isDark,
  }) {
    final validValue = options.contains(value) ? value : options.first;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validValue,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onChanged: onChanged,
          items: options.map((opt) {
            return DropdownMenuItem<String>(
              value: opt,
              child: Row(
                children: [
                  Icon(icon, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      opt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _selectedBuilding != 'All Buildings' ||
        _selectedType != 'All Device Types' ||
        _selectedStatus != 'All Status';
  }

  // ============================================================================
  // ACTIVE FILTER BADGES STRIP
  // ============================================================================
  Widget _buildActiveFilterChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            'Active Filters:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 8),
          if (_searchQuery.isNotEmpty)
            _buildFilterChip('Search: "$_searchQuery"', () {
              _searchController.clear();
              _onSearchChanged('');
            }, isDark),
          if (_selectedBuilding != 'All Buildings')
            _buildFilterChip('Building: $_selectedBuilding', () => _onBuildingChanged('All Buildings'), isDark),
          if (_selectedType != 'All Device Types')
            _buildFilterChip('Type: $_selectedType', () => _onTypeChanged('All Device Types'), isDark),
          if (_selectedStatus != 'All Status')
            _buildFilterChip('Status: $_selectedStatus', () => _onStatusChanged('All Status'), isDark),
          const SizedBox(width: 4),
          InkWell(
            onTap: _clearAllFilters,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                'Reset All',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDeleted,
            child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // STICKY BATCH SELECTION ACTION TOOLBAR
  // ============================================================================
  Widget _buildBatchActionToolbar(bool isDark, bool isMobile) {
    final count = _selectedDeviceIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E3A8A).withOpacity(0.4) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3B82F6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18),
          const SizedBox(width: 8),
          Text(
            '$count Selected',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E3A8A),
            ),
          ),
          const Spacer(),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _executeBulkCommand('turn_on', {'power': true}),
                  icon: const Icon(Icons.power_settings_new_rounded, size: 14, color: Color(0xFF10B981)),
                  label: const Text('Turn ON', style: TextStyle(fontSize: 12, color: Color(0xFF10B981))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _executeBulkCommand('turn_off', {'power': false}),
                  icon: const Icon(Icons.power_off_rounded, size: 14, color: Color(0xFFEF4444)),
                  label: const Text('Turn OFF', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _executeBulkCommand('reboot', {}),
                  icon: const Icon(Icons.restart_alt_rounded, size: 14, color: Color(0xFFF59E0B)),
                  label: const Text('Reboot', style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF59E0B)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _confirmBulkDelete,
                  icon: const Icon(Icons.delete_forever_rounded, size: 14, color: Colors.white),
                  label: const Text('Delete Selected', style: TextStyle(fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _selectedDeviceIds.clear()),
                  child: const Text('Deselect', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // DATA GRID CARD
  // ============================================================================
  Widget _buildGridCard(bool isDark, double maxWidth) {
    final isAllSelected = _devices.isNotEmpty && _devices.every((d) => _selectedDeviceIds.contains(d.id));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Body with Horizontal Scroll
          _isLoading
              ? Container(
                  height: 320,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2.5),
                )
              : _devices.isEmpty
                  ? _buildEmptyState(isDark)
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: math.max(maxWidth - 32, 1100)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTableHeader(isDark, isAllSelected),
                            ..._devices.map((d) => _buildDeviceRow(d, isDark)),
                          ],
                        ),
                      ),
                    ),

          // Divider
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),

          // 7. Powerful & Premium Pagination Footer
          CampusPaginationBar(
            currentPage: _currentPage,
            pageSize: _pageSize,
            totalCount: _totalDevices,
            itemLabel: 'devices',
            pageSizes: const [10, 25, 50, 100],
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              _loadDevices();
            },
            onPageSizeChanged: (newSize) {
              setState(() {
                _pageSize = newSize;
                _currentPage = 1;
              });
              _loadDevices();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isDark, bool isAllSelected) {
    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Container(
      height: 42,
      color: headerBg,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // SINGLE Header Checkbox (Zero Double Checkboxes)
          SizedBox(
            width: 28,
            child: Checkbox(
              value: isAllSelected,
              tristate: true,
              onChanged: (_) => _toggleSelectAllOnPage(),
              activeColor: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 8),

          // Device Name (Width: 190, sortable)
          SizedBox(
            width: 190,
            child: _buildSortableHeaderCell('Device Name', 'device_name', isDark),
          ),
          const SizedBox(width: 8),

          // Device Code (Width: 140, sortable)
          SizedBox(
            width: 140,
            child: _buildSortableHeaderCell('Device Code', 'device_code', isDark),
          ),
          const SizedBox(width: 8),

          // Type (Width: 120, sortable)
          SizedBox(
            width: 120,
            child: _buildSortableHeaderCell('Type', 'type_name', isDark),
          ),
          const SizedBox(width: 8),

          // Location (Width: 230, sortable)
          SizedBox(
            width: 230,
            child: _buildSortableHeaderCell('Location', 'location_path', isDark),
          ),
          const SizedBox(width: 8),

          // IP / MAC (Width: 140, sortable)
          SizedBox(
            width: 140,
            child: _buildSortableHeaderCell('IP / MAC', 'ip_address', isDark),
          ),
          const SizedBox(width: 8),

          // Power (Width: 140)
          SizedBox(
            width: 140,
            child: Text(
              'Power',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Status (Width: 110, sortable)
          SizedBox(
            width: 110,
            child: _buildSortableHeaderCell('Status', 'status', isDark),
          ),
          const SizedBox(width: 8),

          // Actions (Width: 110)
          SizedBox(
            width: 110,
            child: Text(
              'Actions',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortableHeaderCell(String title, String column, bool isDark) {
    final isSelected = _sortColumn == column;
    return InkWell(
      onTap: () => _onSort(column),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isSelected
                ? (_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 14,
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceRow(DeviceItemModel d, bool isDark) {
    final isSelected = _selectedDeviceIds.contains(d.id);
    final rowBg = isSelected
        ? (isDark ? const Color(0xFF1E3A8A).withOpacity(0.3) : const Color(0xFFEFF6FF))
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // SINGLE Row Checkbox (Zero Double Checkboxes)
          SizedBox(
            width: 28,
            child: Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelectDevice(d.id),
              activeColor: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 8),

          // Device Name + Type Icon
          SizedBox(
            width: 190,
            child: InkWell(
              onTap: () => setState(() => _activeDrawerDevice = d),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getTypeColor(d.typeCode).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _getTypeIcon(d.typeCode),
                      size: 16,
                      color: _getTypeColor(d.typeCode),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          d.deviceName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          d.operationalStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: d.isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Device Code
          SizedBox(
            width: 140,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Text(
                  d.deviceCode,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Type
          SizedBox(
            width: 120,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getTypeColor(d.typeCode).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  d.typeName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getTypeColor(d.typeCode),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Location
          SizedBox(
            width: 230,
            child: Text(
              d.locationDisplay.isNotEmpty ? d.locationDisplay : 'Unmapped Location',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // IP / MAC
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  d.ipAddress ?? '—',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (d.macAddress != null && d.macAddress!.isNotEmpty)
                  Text(
                    d.macAddress!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Power State & Toggle
          SizedBox(
            width: 140,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${d.ratedPowerWatts.toInt()} W',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: d.powerState,
                    onChanged: (_) => _togglePower(d),
                    activeColor: const Color(0xFF10B981),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status
          SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: d.isOnline
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : const Color(0xFF64748B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: d.isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      d.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: d.isOnline ? const Color(0xFF10B981) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Actions
          SizedBox(
            width: 110,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  tooltip: 'Control & Telemetry',
                  color: const Color(0xFF2563EB),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => setState(() => _activeDrawerDevice = d),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 18),
                  tooltip: 'Options',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onSelected: (val) {
                    if (val == 'details') {
                      setState(() => _activeDrawerDevice = d);
                    } else if (val == 'reboot') {
                      _rebootDevice(d);
                    } else if (val == 'delete') {
                      _confirmDeleteDevice(d);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reboot',
                      child: Row(
                        children: [
                          Icon(Icons.restart_alt_rounded, size: 16, color: Color(0xFFF59E0B)),
                          SizedBox(width: 8),
                          Text('Reboot Hardware'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Device', style: TextStyle(color: Colors.red)),
                        ],
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
  // EMPTY STATE
  // ============================================================================
  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.devices_other_rounded,
              size: 36,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No Devices Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _hasActiveFilters()
                ? 'No campus devices match your current filters. Try resetting the filters.'
                : 'No devices have been registered yet in the campus fleet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          if (_hasActiveFilters())
            ElevatedButton.icon(
              onPressed: _clearAllFilters,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Clear All Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _openAddDeviceWizard,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add First Device'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // ICON & COLOR HELPERS
  // ============================================================================
  Color _getTypeColor(String typeCode) {
    switch (typeCode.toLowerCase()) {
      case 'hvac':
      case 'ac':
        return const Color(0xFF0284C7);
      case 'lighting':
        return const Color(0xFFEAB308);
      case 'projector':
      case 'display':
        return const Color(0xFF8B5CF6);
      case 'fan':
        return const Color(0xFF10B981);
      case 'access_control':
      case 'door':
        return const Color(0xFFF97316);
      case 'cctv':
      case 'security':
        return const Color(0xFFEF4444);
      case 'audio':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getTypeIcon(String typeCode) {
    switch (typeCode.toLowerCase()) {
      case 'hvac':
      case 'ac':
        return Icons.ac_unit_rounded;
      case 'lighting':
        return Icons.lightbulb_outline_rounded;
      case 'projector':
        return Icons.videocam_outlined;
      case 'display':
        return Icons.tv_rounded;
      case 'fan':
        return Icons.mode_fan_off_outlined;
      case 'access_control':
      case 'door':
        return Icons.door_front_door_outlined;
      case 'cctv':
      case 'security':
        return Icons.videocam_rounded;
      case 'audio':
        return Icons.volume_up_outlined;
      default:
        return Icons.devices_other_rounded;
    }
  }
}
