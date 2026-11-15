import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/device_management_models.dart';
import '../../../providers/device_management_provider.dart';
import '../dialogs/map_device_location_dialog.dart';
import '../dialogs/move_device_location_dialog.dart';
import '../dialogs/floor_plan_fullscreen_dialog.dart';

class DeviceLocationsMappingSubview extends ConsumerStatefulWidget {
  const DeviceLocationsMappingSubview({super.key});

  @override
  ConsumerState<DeviceLocationsMappingSubview> createState() => _DeviceLocationsMappingSubviewState();
}

class _DeviceLocationsMappingSubviewState extends ConsumerState<DeviceLocationsMappingSubview> {
  final TextEditingController _treeSearchController = TextEditingController();
  final TextEditingController _deviceSearchController = TextEditingController();
  final Set<String> _selectedDeviceIds = {};

  // Accordion expansion states for Right Panel
  bool _isRoomsExpanded = false;
  bool _isGroupsExpanded = false;
  bool _isAutomationsExpanded = false;
  bool _isScenesExpanded = false;
  bool _isAnalyticsExpanded = false;

  // Zoom / Pan state for inline floor plan view
  double _floorPlanZoom = 1.0;

  final List<String> _subTabs = [
    'Location Hierarchy',
    'Device Mapping',
    'Location Map',
    'Floor Plan',
    'Coverage & Utilization',
  ];

  final List<String> _deviceTypeFilters = [
    'All Device Types',
    'CCTV',
    'Lighting',
    'HVAC (AC)',
    'Projector',
    'Access Point',
    'Audio / Speaker',
    'Fan',
  ];

  final List<String> _groupFilters = [
    'All Groups',
    'Classroom Lighting - Block A',
    'Classroom Fleet (B1)',
    'Campus HVAC Fleet',
    'AV & Auditorium Systems',
    'Security Perimeter Fleet',
  ];

  final List<String> _profileFilters = [
    'All Profiles',
    'Default Profile',
    'PTZ Control Profile',
    'High Security (24x7)',
    'Energy Saver',
  ];

  final List<String> _statusFilters = [
    'All Status',
    'Mapped',
    'Unmapped',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deviceManagementProvider.notifier).loadLocationsMappingData();
    });
  }

  @override
  void dispose() {
    _treeSearchController.dispose();
    _deviceSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceManagementProvider);
    final notifier = ref.read(deviceManagementProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header & KPI Bar
          _buildTopHeaderAndKpis(state, isDark),
          const SizedBox(height: 20),

          // 2. Section Title, Sub-Nav Tabs & Global Action Buttons
          _buildSectionHeaderAndTabs(state, notifier, isDark),
          const SizedBox(height: 16),

          // 3. Sub-Tab Dynamic Content Area
          _buildSubTabContent(state, notifier, isDark),
        ],
      ),
    );
  }

  // ============================================================================
  // SUB-TAB VIEW DISPATCHER
  // ============================================================================
  Widget _buildSubTabContent(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    switch (state.locationActiveSubTab) {
      case 'Device Mapping':
        return _buildDeviceMappingFocusedLayout(state, notifier, isDark);
      case 'Location Map':
        return _buildCampusLocationMapView(state, notifier, isDark);
      case 'Floor Plan':
        return _buildDedicatedFloorPlanStudio(state, notifier, isDark);
      case 'Coverage & Utilization':
        return _buildCoverageUtilizationDashboard(state, notifier, isDark);
      case 'Location Hierarchy':
      default:
        return _buildLocationHierarchySplitLayout(state, notifier, isDark);
    }
  }

  Widget _buildLocationHierarchySplitLayout(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1100) {
          // Stacked responsive layout for narrow viewports
          return Column(
            children: [
              _buildCampusHierarchyPanel(state, notifier, isDark),
              const SizedBox(height: 16),
              _buildCenterSplitPanel(state, notifier, isDark),
              const SizedBox(height: 16),
              _buildRightLocationDetailsPanel(state, notifier, isDark),
            ],
          );
        }

        // Full 3-Column Desktop Layout matching screenshot
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Panel: Campus Location Hierarchy Tree (~270px)
            SizedBox(
              width: 270,
              child: _buildCampusHierarchyPanel(state, notifier, isDark),
            ),
            const SizedBox(width: 16),

            // Center Panel: Split Top (Device Mapping Table) & Bottom (Floor Plan)
            Expanded(
              child: _buildCenterSplitPanel(state, notifier, isDark),
            ),
            const SizedBox(width: 16),

            // Right Panel: Location Details (~310px)
            SizedBox(
              width: 310,
              child: _buildRightLocationDetailsPanel(state, notifier, isDark),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeviceMappingFocusedLayout(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1000) {
          return Column(
            children: [
              _buildCampusHierarchyPanel(state, notifier, isDark),
              const SizedBox(height: 16),
              _buildDeviceMappingTableCard(state, notifier, isDark),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 270,
              child: _buildCampusHierarchyPanel(state, notifier, isDark),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDeviceMappingTableCard(state, notifier, isDark),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCampusLocationMapView(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final buildings = [
      {'id': '2af829b6-81a4-469a-a91a-71f2bd390fc4', 'name': 'Academic Block (A)', 'floors': 4, 'rooms': 14, 'devices': 320, 'online': 312, 'offline': 8, 'coverage': 98.4, 'icon': Icons.school_rounded},
      {'id': 'b102-acad-block-b', 'name': 'Academic Block (B)', 'floors': 3, 'rooms': 12, 'devices': 210, 'online': 208, 'offline': 2, 'coverage': 99.1, 'icon': Icons.apartment_rounded},
      {'id': 'b103-admin-block', 'name': 'Admin Block', 'floors': 2, 'rooms': 8, 'devices': 95, 'online': 93, 'offline': 2, 'coverage': 97.8, 'icon': Icons.business_rounded},
      {'id': 'b104-lab-block', 'name': 'Laboratories Block', 'floors': 3, 'rooms': 16, 'devices': 450, 'online': 435, 'offline': 15, 'coverage': 96.5, 'icon': Icons.science_rounded},
      {'id': 'b105-library-block', 'name': 'Library Block', 'floors': 2, 'rooms': 6, 'devices': 80, 'online': 80, 'offline': 0, 'coverage': 100.0, 'icon': Icons.local_library_rounded},
      {'id': 'b106-hostel-block', 'name': 'Hostel Block', 'floors': 4, 'rooms': 32, 'devices': 180, 'online': 171, 'offline': 9, 'coverage': 95.0, 'icon': Icons.hotel_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.map_rounded, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Campus Location Map & Building Facilities',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Interactive overview of all institution buildings, mapped floor plans, and real-time device health.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.sync_rounded, size: 14),
                label: const Text('Refresh Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => notifier.loadLocationsMappingData(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth < 650 ? 1 : (constraints.maxWidth < 1050 ? 2 : 3);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 215,
                ),
                itemCount: buildings.length,
                itemBuilder: (context, idx) {
                  final b = buildings[idx];
                  final isSelected = state.selectedLocationBuildingId == b['id'];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      notifier.selectLocationFloor(buildingId: b['id'] as String, floorId: 'b8b4c4de-11e1-4d42-b4ad-27b86c8c823a');
                      notifier.setLocationSubTab('Location Hierarchy');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? primaryColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(b['icon'] as IconData, color: primaryColor, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b['name'] as String,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${b['floors']} Floors • ${b['rooms']} Rooms',
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${b['coverage']}% Coverage',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Devices Mapped', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Text(
                                    '${b['devices']}',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                              Flexible(
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 2,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                                        const SizedBox(width: 4),
                                        Text('${b['online']} Online', style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF334155))),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                                        const SizedBox(width: 4),
                                        Text('${b['offline']} Offline', style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF334155))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected ? primaryColor : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                foregroundColor: isSelected ? Colors.white : primaryColor,
                                side: BorderSide(color: isSelected ? Colors.transparent : primaryColor.withValues(alpha: 0.3)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                notifier.selectLocationFloor(buildingId: b['id'] as String, floorId: 'b8b4c4de-11e1-4d42-b4ad-27b86c8c823a');
                                notifier.setLocationSubTab('Location Hierarchy');
                              },
                              child: Text(
                                isSelected ? 'Active Building' : 'Select & View Devices',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDedicatedFloorPlanStudio(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    return _buildFloorPlanViewCard(state, notifier, isDark);
  }

  Widget _buildCoverageUtilizationDashboard(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final kpis = state.locationsKpis;

    final densityRows = [
      {'room': 'Classroom 101', 'floor': 'First Floor (1F)', 'area': '650 sq ft', 'devices': 6, 'density': '1 / 108 sq ft', 'status': 'Optimal', 'statusColor': const Color(0xFF16A34A)},
      {'room': 'Physics Lab 1', 'floor': 'First Floor (1F)', 'area': '920 sq ft', 'devices': 12, 'density': '1 / 76 sq ft', 'status': 'Optimal', 'statusColor': const Color(0xFF16A34A)},
      {'room': 'Seminar Hall A', 'floor': 'Ground Floor (GF)', 'area': '1,400 sq ft', 'devices': 18, 'density': '1 / 77 sq ft', 'status': 'Optimal', 'statusColor': const Color(0xFF16A34A)},
      {'room': 'Admin Server Room', 'floor': 'Ground Floor (GF)', 'area': '320 sq ft', 'devices': 14, 'density': '1 / 22 sq ft', 'status': 'High Density', 'statusColor': const Color(0xFFD97706)},
      {'room': 'Library Reading Hall', 'floor': 'Second Floor (2F)', 'area': '1,800 sq ft', 'devices': 8, 'density': '1 / 225 sq ft', 'status': 'Underutilized', 'statusColor': const Color(0xFF2563EB)},
      {'room': 'Chemistry Lab 2', 'floor': 'Second Floor (2F)', 'area': '850 sq ft', 'devices': 10, 'density': '1 / 85 sq ft', 'status': 'Optimal', 'statusColor': const Color(0xFF16A34A)},
      {'room': 'Computer Lab 3', 'floor': 'Third Floor (3F)', 'area': '1,100 sq ft', 'devices': 32, 'density': '1 / 34 sq ft', 'status': 'High Density', 'statusColor': const Color(0xFFD97706)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.analytics_rounded, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Space Coverage & Device Utilization Analytics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Detailed metrics on Wi-Fi reach, sensor coverage, device density, and space allocation efficiency.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 4 Metric cards
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth < 650 ? 1 : (constraints.maxWidth < 1050 ? 2 : 4);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 2.2,
                children: [
                  _buildCoverageMetricCard('Wi-Fi Coverage', '98.4%', '42 / 44 Rooms Covered', Icons.wifi_rounded, const Color(0xFF16A34A), isDark),
                  _buildCoverageMetricCard('Security Reach', '96.2%', 'All Exits & Corridors', Icons.videocam_rounded, const Color(0xFF2563EB), isDark),
                  _buildCoverageMetricCard('Automation Rate', '91.0%', 'Smart HVAC & Relays', Icons.speed_rounded, const Color(0xFFD97706), isDark),
                  _buildCoverageMetricCard('Space Efficiency', '${kpis.coveragePct.toStringAsFixed(1)}%', '${kpis.locationsWithDevices} Active Spaces', Icons.pie_chart_outline_rounded, primaryColor, isDark),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Room-by-Room Device Density & Utilization Index',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 750),
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 48,
                horizontalMargin: 16,
                columnSpacing: 20,
                headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                headingTextStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                columns: const [
                  DataColumn(label: Text('Room / Space')),
                  DataColumn(label: Text('Floor Location')),
                  DataColumn(label: Text('Floor Area')),
                  DataColumn(label: Text('Mapped Devices')),
                  DataColumn(label: Text('Device Density')),
                  DataColumn(label: Text('Utilization Status')),
                ],
                rows: densityRows.map((r) {
                  return DataRow(
                    cells: [
                      DataCell(Text(r['room'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      DataCell(Text(r['floor'] as String, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(r['area'] as String, style: const TextStyle(fontSize: 12))),
                      DataCell(Text('${r['devices']} devices', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DataCell(Text(r['density'] as String, style: const TextStyle(fontSize: 12))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (r['statusColor'] as Color).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r['status'] as String,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: r['statusColor'] as Color),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverageMetricCard(String title, String val, String sub, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                Text(sub, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black45), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 1. TOP HEADER & KPI BAR
  // ============================================================================
  Widget _buildTopHeaderAndKpis(DeviceManagementState state, bool isDark) {
    final kpis = state.locationsKpis;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1200;

        final headerText = Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.devices_other_rounded, color: Color(0xFF2563EB), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device Management & Control',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Register, organize, monitor and control all campus devices from a single platform.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );

        final cardsList = [
          _buildKpiCard('Buildings', '${kpis.buildings}', Icons.apartment_rounded, const Color(0xFF2563EB), isDark),
          _buildKpiCard('Floors', '${kpis.floors}', Icons.layers_rounded, const Color(0xFF0284C7), isDark),
          _buildKpiCard('Rooms / Spaces', '${kpis.rooms}', Icons.meeting_room_outlined, const Color(0xFF0D9488), isDark),
          _buildKpiCard(
            'Mapped Devices',
            '${_formatNumber(kpis.mappedDevices)} (${kpis.mappedPct.toStringAsFixed(1)}%)',
            Icons.hub_rounded,
            const Color(0xFF16A34A),
            isDark,
            pctColor: const Color(0xFF16A34A),
          ),
          _buildKpiCard(
            'Unmapped Devices',
            '${_formatNumber(kpis.unmappedDevices)} (${kpis.unmappedPct.toStringAsFixed(1)}%)',
            Icons.link_off_rounded,
            const Color(0xFF9333EA),
            isDark,
            pctColor: const Color(0xFF9333EA),
          ),
          _buildKpiCard(
            'Locations with Devices',
            '${kpis.locationsWithDevices} (${kpis.coveragePct.toStringAsFixed(1)}%)',
            Icons.pin_drop_outlined,
            const Color(0xFF2563EB),
            isDark,
            pctColor: const Color(0xFF16A34A),
          ),
        ];

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerText,
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: cardsList),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: headerText),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: cardsList.map((c) => Padding(padding: const EdgeInsets.only(left: 10), child: c)).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }




  Widget _buildKpiCard(String label, String value, IconData icon, Color color, bool isDark, {Color? pctColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF64748B), fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 2. SECTION TITLE, SUB-NAV TABS & GLOBAL ACTIONS
  // ============================================================================
  Widget _buildSectionHeaderAndTabs(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title & Action Buttons Row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_on_outlined, color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Locations & Mapping',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Define campus locations (buildings, floors, rooms, zones) and map devices to the right spaces.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // + Add Location
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Add Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 16),
                ],
              ),
              onPressed: () => _openMapDeviceDialog(context),
            ),
            const SizedBox(width: 8),

            // Import
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.file_upload_outlined, size: 16),
              label: const Text('Import', style: TextStyle(fontSize: 13)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Spatial mapping imported successfully!'), backgroundColor: Colors.green),
                );
              },
            ),
            const SizedBox(width: 8),

            // Export
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Export', style: TextStyle(fontSize: 13)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exporting campus location mapping CSV...'), backgroundColor: Colors.blue),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),

        // SubTabs Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _subTabs.map((tab) {
              final isSelected = state.locationActiveSubTab == tab;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => notifier.setLocationSubTab(tab),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 3. LEFT PANEL: CAMPUS LOCATION HIERARCHY TREE
  // ============================================================================
  Widget _buildCampusHierarchyPanel(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    final tree = state.locationsHierarchy;
    final buildings = tree?.children ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              const Icon(Icons.account_tree_outlined, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Campus Location Hierarchy',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Field
          TextField(
            controller: _treeSearchController,
            decoration: InputDecoration(
              hintText: 'Search building, floor, room...',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 16),
              isDense: true,
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            onChanged: (val) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Root Node: Greenwood High School
          Row(
            children: [
              const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tree?.name ?? 'Greenwood High School',
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
          const SizedBox(height: 8),

          // Buildings list
          ...buildings.map((bldg) => _buildBuildingTreeNode(bldg, state, notifier, isDark)),
        ],
      ),
    );
  }

  Widget _buildBuildingTreeNode(LocationHierarchyNode bldg, DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    final query = _treeSearchController.text.trim().toLowerCase();
    if (query.isNotEmpty && !bldg.name.toLowerCase().contains(query)) {
      final matchChild = bldg.children.any((c) => c.name.toLowerCase().contains(query));
      if (!matchChild) return const SizedBox.shrink();
    }

    final isAcademicBlockA = bldg.name.contains('Academic Block (A)');
    final isExpanded = isAcademicBlockA || query.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                size: 16,
                color: isDark ? Colors.white60 : Colors.black45,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.apartment_rounded, size: 16, color: Color(0xFF0284C7)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  bldg.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 4),
              child: Column(
                children: bldg.children.map((floor) {
                  final isSelected = floor.id == state.selectedLocationFloorId;
                  return InkWell(
                    onTap: () {
                      notifier.selectLocationFloor(
                        floorId: floor.id,
                        buildingId: bldg.id,
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: isSelected ? Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)) : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.layers_rounded,
                            size: 14,
                            color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white60 : Colors.black45),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${floor.name} (${floor.deviceCount})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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

  // ============================================================================
  // 4. CENTER SPLIT PANEL: DEVICE MAPPING TABLE & FLOOR PLAN VIEW
  // ============================================================================
  Widget _buildCenterSplitPanel(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Section: Device Mapping Table
        _buildDeviceMappingTableCard(state, notifier, isDark),
        const SizedBox(height: 16),

        // Bottom Section: Floor Plan View
        _buildFloorPlanViewCard(state, notifier, isDark),
      ],
    );
  }

  Widget _buildDeviceMappingTableCard(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    final details = state.selectedLocationDetails;
    final title = details?.title ?? 'Academic Block (A) > First Floor';
    final devices = state.locationMappedDevices;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Title & Actions
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.layers_outlined, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Device Mapping – $title',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Action Buttons
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.link_rounded, size: 15),
                label: const Text('Map Devices', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: () => _openMapDeviceDialog(context),
              ),
              const SizedBox(width: 8),

              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Bulk Map', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 15),
                  ],
                ),
                onPressed: () => _openBulkMapDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filters Row
          _buildMappingFiltersRow(state, notifier, isDark),
          const SizedBox(height: 12),

          // Bulk Actions Bar for Mapped Devices
          if (_selectedDeviceIds.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedDeviceIds.length} of ${devices.length} devices selected',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.link_off_rounded, size: 14, color: Color(0xFFDC2626)),
                      label: const Text('Unmap Selected', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                      ),
                      onPressed: () async {
                        final count = _selectedDeviceIds.length;
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Unmap Selected Devices?'),
                            content: Text('Are you sure you want to unmap $count selected device(s) from this location?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Unmap', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await notifier.unmapDevices(deviceIds: _selectedDeviceIds.toList());
                          setState(() => _selectedDeviceIds.clear());
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Unmapped $count device(s) successfully!'), backgroundColor: Colors.orange.shade800),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.drive_file_move_outlined, size: 14, color: Color(0xFF0D9488)),
                      label: const Text('Relocate Selected', style: TextStyle(fontSize: 12, color: Color(0xFF0D9488), fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: Color(0xFF99F6E4)),
                      ),
                      onPressed: () {
                        if (devices.isNotEmpty) {
                          final firstSel = devices.firstWhere(
                            (d) => _selectedDeviceIds.contains(d.id),
                            orElse: () => devices.first,
                          );
                          _openMoveDeviceDialog(firstSel);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _selectedDeviceIds.clear()),
                      child: Text('Deselect All', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Devices Table
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 720),
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(40),
                      1: FlexColumnWidth(2.5),
                      2: FlexColumnWidth(1.6),
                      3: FlexColumnWidth(2.2),
                      4: FlexColumnWidth(2.0),
                      5: FixedColumnWidth(110),
                      6: FixedColumnWidth(105),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                  // Header Row
                  TableRow(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Checkbox(
                          value: devices.isNotEmpty && _selectedDeviceIds.length == devices.length,
                          tristate: _selectedDeviceIds.isNotEmpty && _selectedDeviceIds.length < devices.length,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedDeviceIds.addAll(devices.map((d) => d.id));
                              } else {
                                _selectedDeviceIds.clear();
                              }
                            });
                          },
                        ),
                      ),
                      _tableHeaderCell('Device Name ↕', isDark),
                      _tableHeaderCell('Device Type', isDark),
                      _tableHeaderCell('Room / Space', isDark),
                      _tableHeaderCell('Location Path', isDark),
                      _tableHeaderCell('Mapping Status', isDark),
                      _tableHeaderCell('Actions', isDark, align: TextAlign.center),
                    ],
                  ),

                  // Data Rows
                  ...devices.map((dev) => _buildDeviceTableRow(dev, state, notifier, isDark)),
                  if (devices.isEmpty)
                    TableRow(
                      children: [
                        const SizedBox.shrink(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.devices_other_outlined, size: 36, color: isDark ? Colors.white30 : Colors.black26),
                                const SizedBox(height: 8),
                                Text(
                                  'No devices mapped to this location yet.',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Click "+ Map Devices" to assign devices to this floor/room.',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox.shrink(),
                        const SizedBox.shrink(),
                        const SizedBox.shrink(),
                        const SizedBox.shrink(),
                        const SizedBox.shrink(),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
          const SizedBox(height: 12),

          // Pagination Footer
          _buildPaginationFooter(state, notifier, isDark),
        ],
      ),
    );
  }

  Widget _tableHeaderCell(String text, bool isDark, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : const Color(0xFF475569),
        ),
      ),
    );
  }

  TableRow _buildDeviceTableRow(DeviceLocationMappingItem dev, DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    final isSelected = _selectedDeviceIds.contains(dev.id);

    return TableRow(
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF2563EB).withValues(alpha: 0.08)
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Checkbox(
            value: isSelected,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedDeviceIds.add(dev.id);
                } else {
                  _selectedDeviceIds.remove(dev.id);
                }
              });
            },
          ),
        ),

        // Device Name with Type Icon
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(_getIconForType(dev.deviceType), size: 16, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dev.deviceCode,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Device Type
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            dev.deviceType,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF334155)),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Room / Space
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            dev.roomSpace,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF334155)),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Location Path
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            dev.locationPath,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Mapping Status Chip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text(
                    'Mapped',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Actions: Edit pencil & More options
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                color: const Color(0xFF2563EB),
                tooltip: 'Relocate Device',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                visualDensity: VisualDensity.compact,
                splashRadius: 16,
                onPressed: () => _openMoveDeviceDialog(dev),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'unmap', child: Text('Unmap Device')),
                  const PopupMenuItem(value: 'reposition', child: Text('Reposition on Floor Plan')),
                  const PopupMenuItem(value: 'details', child: Text('View Details')),
                ],
                onSelected: (val) {
                  if (val == 'unmap') {
                    notifier.unmapDevices(deviceIds: [dev.id]);
                  } else if (val == 'reposition') {
                    _openFullScreenFloorPlan(context);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMappingFiltersRow(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Dropdown 1: Device Type
            _buildDropdownFilter(
              value: state.locationDeviceTypeFilter,
              items: _deviceTypeFilters,
              onChanged: (val) {
                if (val != null) notifier.setLocationDeviceTypeFilter(val);
              },
              isDark: isDark,
            ),

            // Dropdown 2: Group
            _buildDropdownFilter(
              value: state.locationGroupFilter,
              items: _groupFilters,
              onChanged: (val) {
                if (val != null) notifier.setLocationGroupFilter(val);
              },
              isDark: isDark,
            ),

            // Dropdown 3: Profile
            _buildDropdownFilter(
              value: state.locationProfileFilter,
              items: _profileFilters,
              onChanged: (val) {
                if (val != null) notifier.setLocationProfileFilter(val);
              },
              isDark: isDark,
            ),

            // Dropdown 4: Mapping Status
            _buildDropdownFilter(
              value: state.locationStatusFilter,
              items: _statusFilters,
              onChanged: (val) {
                if (val != null) notifier.setLocationStatusFilter(val);
              },
              isDark: isDark,
            ),

            // Search box
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220, minWidth: 140),
              child: TextField(
                controller: _deviceSearchController,
                decoration: InputDecoration(
                  hintText: 'Search by device name, ID or room...',
                  hintStyle: const TextStyle(fontSize: 11),
                  prefixIcon: const Icon(Icons.search, size: 15),
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onSubmitted: (val) => notifier.setLocationSearch(val),
              ),
            ),

            // Grid & List toggles
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => notifier.setLocationViewMode(true),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.grid_view_rounded, size: 16, color: state.locationIsGridView ? const Color(0xFF2563EB) : Colors.grey),
                    ),
                  ),
                  InkWell(
                    onTap: () => notifier.setLocationViewMode(false),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.view_list_rounded, size: 16, color: !state.locationIsGridView ? const Color(0xFF2563EB) : Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }




  Widget _buildDropdownFilter({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w500),
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    final total = state.locationDevicesTotal;
    final page = state.locationDevicesPage;
    final limit = state.locationDevicesPageSize;
    final startIdx = total == 0 ? 0 : ((page - 1) * limit + 1);
    final devsOnPage = state.locationMappedDevices.length;
    final endIdx = total == 0 ? 0 : (startIdx + devsOnPage - 1);
    String floorName = 'First Floor';
    if (state.selectedLocationDetails?.title != null) {
      final t = state.selectedLocationDetails!.title;
      if (t.contains('–')) {
        floorName = t.split('–').last.trim();
      } else if (t.contains('-')) {
        floorName = t.split('-').last.trim();
      } else if (t.contains('>')) {
        floorName = t.split('>').last.trim();
      } else {
        floorName = t;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Showing $startIdx – $endIdx of $total devices ($floorName)',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Rows per page: 10', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 18),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: page > 1 ? () => notifier.setLocationDevicesPage(page - 1) : null,
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(6)),
                    child: Text('$page', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: endIdx < total ? () => notifier.setLocationDevicesPage(page + 1) : null,
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Text(
                'Showing $startIdx – $endIdx of $total devices ($floorName)',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'Rows per page: 10',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 18),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: page > 1 ? () => notifier.setLocationDevicesPage(page - 1) : null,
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$page', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 18),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: endIdx < total ? () => notifier.setLocationDevicesPage(page + 1) : null,
            ),
          ],
        );
      },
    );
  }




  // ============================================================================
  // 5. BOTTOM SECTION: FLOOR PLAN VIEW
  // ============================================================================
  Widget _buildFloorPlanViewCard(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    final details = state.selectedLocationDetails;
    final title = details?.title ?? 'Academic Block (A) > First Floor';
    final markers = state.floorPlanMarkers;
    final legend = state.floorPlanLegend;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.map_outlined, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Floor Plan View – $title',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Open Full Plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: () => _openFullScreenFloorPlan(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Plan Interactive Graphic Canvas with Tools Overlay and Legend
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 380,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Stack(
                children: [
                  // 1. Rooms Graphic & Markers
                  Positioned.fill(
                    child: Transform.scale(
                      scale: _floorPlanZoom,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final planW = constraints.maxWidth;
                          final planH = constraints.maxHeight;
                          return Stack(
                            children: [
                              ..._buildRoomsArchitecture(isDark, planW, planH),
                              ...markers.map((m) => _buildMarkerPin(m, isDark, planW, planH)),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // 2. Left Zoom / Pan Overlay Controls
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            tooltip: 'Zoom In',
                            onPressed: () => setState(() => _floorPlanZoom = (_floorPlanZoom * 1.15).clamp(0.7, 2.5)),
                          ),
                          const Divider(height: 1),
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            tooltip: 'Zoom Out',
                            onPressed: () => setState(() => _floorPlanZoom = (_floorPlanZoom * 0.85).clamp(0.7, 2.5)),
                          ),
                          const Divider(height: 1),
                          IconButton(
                            icon: const Icon(Icons.fit_screen_outlined, size: 18),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            tooltip: 'Reset',
                            onPressed: () => setState(() => _floorPlanZoom = 1.0),
                          ),
                          const Divider(height: 1),
                          IconButton(
                            icon: const Icon(Icons.layers_outlined, size: 18),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            tooltip: 'Layers',
                            onPressed: () => _openFullScreenFloorPlan(context),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Right Legend Overlay
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Legend', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              const Text('Mapped Device', style: TextStyle(fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                              const SizedBox(width: 5),
                              const Text('Unmapped Device', style: TextStyle(fontSize: 10)),
                            ],
                          ),
                          const Divider(height: 10),
                          _buildLegendItem(Icons.videocam_outlined, 'CCTV (${legend.cctv})', const Color(0xFFDC2626)),
                          _buildLegendItem(Icons.lightbulb_outline_rounded, 'Lighting (${legend.lighting})', const Color(0xFFEAB308)),
                          _buildLegendItem(Icons.ac_unit_rounded, 'HVAC (${legend.hvac})', const Color(0xFF0EA5E9)),
                          _buildLegendItem(Icons.tv_rounded, 'Projector (${legend.projector})', const Color(0xFF8B5CF6)),
                          _buildLegendItem(Icons.wifi_rounded, 'Access Point (${legend.accessPoint})', const Color(0xFF2563EB)),
                          _buildLegendItem(Icons.volume_up_rounded, 'Audio (${legend.audio})', const Color(0xFF10B981)),
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

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  List<Widget> _buildRoomsArchitecture(bool isDark, double w, double h) {
    final borderColor = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
    final roomBg = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : Colors.white;
    final corrBg = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : const Color(0xFFF1F5F9);

    Widget makeRoom(String code, String name, double left, double top, double width, double height, {bool isCorridor = false}) {
      return Positioned(
        left: left * w,
        top: top * h,
        width: width * w,
        height: height * h,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isCorridor ? corrBg : roomBg,
            border: Border.all(color: borderColor, width: 1.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Align(
            alignment: isCorridor ? Alignment.center : Alignment.topLeft,
            child: Text(
              isCorridor ? code : '$code\n$name',
              style: TextStyle(
                fontSize: isCorridor ? 11 : 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ),
        ),
      );
    }

    return [
      // Top Row
      makeRoom('A1-101', 'Classroom', 0.04, 0.06, 0.21, 0.38),
      makeRoom('A1-102', 'Classroom', 0.27, 0.06, 0.21, 0.38),
      makeRoom('A1-103', 'Classroom', 0.50, 0.06, 0.21, 0.38),
      makeRoom('A1-104', 'Classroom', 0.73, 0.06, 0.23, 0.38),

      // Corridor
      makeRoom('Corridor', '', 0.04, 0.46, 0.92, 0.10, isCorridor: true),

      // Bottom Row
      makeRoom('A1-105', 'Lab', 0.04, 0.58, 0.29, 0.38),
      makeRoom('A1-106', 'Lab', 0.35, 0.58, 0.29, 0.38),
      makeRoom('A1-107', 'Smart Class', 0.66, 0.58, 0.30, 0.38),
    ];
  }

  Widget _buildMarkerPin(FloorPlanMarkerModel marker, bool isDark, double w, double h) {
    Color markerColor = const Color(0xFF2563EB);
    final typeLower = marker.deviceType.toLowerCase();
    if (typeLower.contains('cctv')) {
      markerColor = const Color(0xFFDC2626);
    } else if (typeLower.contains('light')) markerColor = const Color(0xFFEAB308);
    else if (typeLower.contains('hvac') || typeLower.contains('ac')) markerColor = const Color(0xFF0EA5E9);
    else if (typeLower.contains('proj')) markerColor = const Color(0xFF8B5CF6);
    else if (typeLower.contains('audio') || typeLower.contains('speaker')) markerColor = const Color(0xFF10B981);
    else if (typeLower.contains('fan')) markerColor = const Color(0xFF14B8A6);

    final left = marker.posX * w - 12;
    final top = marker.posY * h - 12;

    return Positioned(
      left: left,
      top: top,
      child: Tooltip(
        message: '${marker.deviceCode} (${marker.deviceType})',
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: markerColor, width: 1.5),
            boxShadow: [
              BoxShadow(color: markerColor.withValues(alpha: 0.3), blurRadius: 4),
            ],
          ),
          child: Icon(
            _getIconForType(marker.deviceType),
            size: 13,
            color: markerColor,
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 6. RIGHT PANEL: LOCATION DETAILS & ACCORDIONS
  // ============================================================================
  Widget _buildRightLocationDetailsPanel(DeviceManagementState state, DeviceManagementNotifier notifier, bool isDark) {
    final details = state.selectedLocationDetails;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Pop-out icon
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _openFullScreenFloorPlan(context),
                ),
              ],
            ),
          ),

          // Building Image Banner
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 110,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
              ),
              child: Image.network(
                details?.imageUrl ?? 'https://images.unsplash.com/photo-1562774053-701939374585?auto=format&fit=crop&w=600&q=80',
                fit: BoxFit.cover,
                width: double.infinity,
                height: 110,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                  child: Center(
                    child: Icon(Icons.apartment_rounded, size: 40, color: isDark ? Colors.white24 : Colors.black26),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title & Status Chip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details?.title ?? 'Academic Block (A) – First Floor',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Building: ${details?.buildingName ?? "Academic Block (A)"}',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('Active', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Specifications Table / Rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildSpecRow('Location Type', details?.locationType ?? 'Floor', isDark),
                _buildSpecRow('Parent Location', details?.parentLocation ?? 'Academic Block (A)', isDark),
                _buildSpecRow('Floor No.', '${details?.floorNo ?? 1}', isDark),
                _buildSpecRow('Total Rooms / Spaces', '${details?.totalRooms ?? 14}', isDark),
                _buildSpecRow('Mapped Devices', '${details?.mappedDevices ?? 132}', isDark),
                _buildSpecRow('Unmapped Devices', '${details?.unmappedDevices ?? 4}', isDark),
                _buildSpecRow('Groups Assigned', '${details?.groupsAssigned ?? 8}', isDark),
                _buildSpecRow('Profiles in Use', '${details?.profilesInUse ?? 5}', isDark),
                _buildSpecRow('Coverage', '${details?.coveragePct ?? 97.1}%', isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Actions 2x2 Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.link_rounded,
                        label: 'Map Devices',
                        onTap: () => _openMapDeviceDialog(context),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.link_off_rounded,
                        label: 'Unmap Devices',
                        onTap: () {
                          if (state.locationMappedDevices.isNotEmpty) {
                            notifier.unmapDevices(deviceIds: [state.locationMappedDevices.first.id]);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Unmapped device successfully!'), backgroundColor: Colors.orange),
                            );
                          }
                        },
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.map_outlined,
                        label: 'View Floor Plan',
                        onTap: () => _openFullScreenFloorPlan(context),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.add_rounded,
                        label: '+ Add Room / Space',
                        onTap: () => _openAddRoomDialog(context),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Collapsible Accordions
          _buildAccordionItem(
            title: 'Rooms / Spaces (${details?.totalRooms ?? 14})',
            icon: Icons.meeting_room_outlined,
            isExpanded: _isRoomsExpanded,
            onToggle: () => setState(() => _isRoomsExpanded = !_isRoomsExpanded),
            isDark: isDark,
            content: Column(
              children: (details?.rooms ?? []).map((r) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.room_rounded, size: 14, color: Colors.blue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('${r.roomNumber} (${r.name})', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(r.roomType, style: const TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          _buildAccordionItem(
            title: 'Assigned Device Groups (${details?.assignedGroups.length ?? 8})',
            icon: Icons.grid_view_rounded,
            isExpanded: _isGroupsExpanded,
            onToggle: () => setState(() => _isGroupsExpanded = !_isGroupsExpanded),
            isDark: isDark,
            content: Column(
              children: (details?.assignedGroups ?? []).map((g) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.hub_rounded, size: 14, color: Colors.teal),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(g.name, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                      ),
                      Text('${g.deviceCount} devs', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          _buildAccordionItem(
            title: 'Automation & Schedules (${details?.automationsCount ?? 3})',
            icon: Icons.schedule_rounded,
            isExpanded: _isAutomationsExpanded,
            onToggle: () => setState(() => _isAutomationsExpanded = !_isAutomationsExpanded),
            isDark: isDark,
            content: const Column(
              children: [
                ListTile(
                  dense: true,
                  leading: Icon(Icons.bolt, color: Colors.amber, size: 16),
                  title: Text('Auto Off Lights (Unoccupied)', style: TextStyle(fontSize: 11)),
                  subtitle: Text('Triggers after 2 mins inactivity', style: TextStyle(fontSize: 9)),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.ac_unit, color: Colors.lightBlue, size: 16),
                  title: Text('AC Schedule (08:00 AM - 05:00 PM)', style: TextStyle(fontSize: 11)),
                  subtitle: Text('Mon - Fri active profile', style: TextStyle(fontSize: 9)),
                ),
              ],
            ),
          ),

          _buildAccordionItem(
            title: 'Scenes & Presets (${details?.scenesCount ?? 2})',
            icon: Icons.movie_filter_outlined,
            isExpanded: _isScenesExpanded,
            onToggle: () => setState(() => _isScenesExpanded = !_isScenesExpanded),
            isDark: isDark,
            content: const Column(
              children: [
                ListTile(
                  dense: true,
                  leading: Icon(Icons.school, color: Colors.purple, size: 16),
                  title: Text('Lecture Mode', style: TextStyle(fontSize: 11)),
                  subtitle: Text('AC 24°C + Lights 80% + Projector ON', style: TextStyle(fontSize: 9)),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.nature, color: Colors.green, size: 16),
                  title: Text('Eco Night Mode', style: TextStyle(fontSize: 11)),
                  subtitle: Text('All non-essential loads shutdown', style: TextStyle(fontSize: 9)),
                ),
              ],
            ),
          ),

          _buildAccordionItem(
            title: 'Location Analytics',
            icon: Icons.bar_chart_rounded,
            isExpanded: _isAnalyticsExpanded,
            onToggle: () => setState(() => _isAnalyticsExpanded = !_isAnalyticsExpanded),
            isDark: isDark,
            content: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Power utilization: 92.4 kWh today (9% lower than average). Uptime: 99.8%. Zero active fault alarms.',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2563EB)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccordionItem({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required bool isDark,
    required Widget content,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: const Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: isDark ? Colors.white60 : Colors.black45,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: content,
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // DIALOG HANDLERS
  // ============================================================================
  void _openMapDeviceDialog(BuildContext context) {
    final state = ref.read(deviceManagementProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MapDeviceLocationDialog(
        initialBuildingId: state.selectedLocationBuildingId,
        initialFloorId: state.selectedLocationFloorId,
        initialRoomId: state.selectedLocationRoomId,
      ),
    );
  }

  void _openMoveDeviceDialog(DeviceLocationMappingItem dev) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MoveDeviceLocationDialog(device: dev),
    );
  }

  void _openBulkMapDialog(BuildContext context) {
    final state = ref.read(deviceManagementProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MapDeviceLocationDialog(
        initialBuildingId: state.selectedLocationBuildingId,
        initialFloorId: state.selectedLocationFloorId,
        initialRoomId: state.selectedLocationRoomId,
      ),
    );
  }

  void _openFullScreenFloorPlan(BuildContext context) {
    final state = ref.read(deviceManagementProvider);
    showDialog(
      context: context,
      builder: (ctx) => FloorPlanFullScreenDialog(
        floorPlan: state.floorPlanAsset,
        markers: state.floorPlanMarkers,
        legend: state.floorPlanLegend,
        title: state.selectedLocationDetails?.title ?? 'Academic Block (A) – First Floor Architectural Plan',
      ),
    );
  }

  void _openAddRoomDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Room / Space'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: numCtrl, decoration: const InputDecoration(labelText: 'Room Number (e.g. A1-115)')),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Room Name (e.g. Science Activity Room)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Room ${numCtrl.text} created successfully!'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Add Space'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('cctv')) return Icons.videocam_outlined;
    if (t.contains('light')) return Icons.lightbulb_outline_rounded;
    if (t.contains('hvac') || t.contains('ac')) return Icons.ac_unit_rounded;
    if (t.contains('proj')) return Icons.tv_rounded;
    if (t.contains('access_point') || t.contains('point') || t.contains('wifi')) return Icons.wifi_rounded;
    if (t.contains('speaker') || t.contains('audio')) return Icons.volume_up_rounded;
    if (t.contains('fan')) return Icons.mode_fan_off_rounded;
    return Icons.devices_other_rounded;
  }

  String _formatNumber(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write(',');
        count = 0;
      }
    }
    return buffer.toString().split('').reversed.join('');
  }
}
