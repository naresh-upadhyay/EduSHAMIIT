import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/device_management_models.dart';
import '../../../providers/device_management_provider.dart';

class DeviceLiveControlSubview extends ConsumerStatefulWidget {
  const DeviceLiveControlSubview({super.key});

  @override
  ConsumerState<DeviceLiveControlSubview> createState() =>
      _DeviceLiveControlSubviewState();
}

class _DeviceLiveControlSubviewState
    extends ConsumerState<DeviceLiveControlSubview> {
  final TextEditingController _locationSearchCtrl = TextEditingController();
  final TextEditingController _deviceSearchCtrl = TextEditingController();

  final Set<String> _expandedNodeIds = {
    'Academic Block (A)',
    'b8b4c4de-11e1-4d42-b4ad-27b86c8c823a',
    'First Floor',
    'First Floor (14)',
  };

  double _floorPlanZoom = 1.0;
  bool _deviceInfoExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deviceManagementProvider.notifier).loadLiveControlData();
    });
  }

  @override
  void dispose() {
    _locationSearchCtrl.dispose();
    _deviceSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceManagementProvider);
    final notifier = ref.read(deviceManagementProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1100;
        final isMedium = constraints.maxWidth >= 1100 && constraints.maxWidth < 1400;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP 6-CARD OPERATIONAL KPIS BAR
              _buildLiveControlKpisBar(state.liveControlKpis, isDark),
              const SizedBox(height: 16),

              // 2. SUB-NAVIGATION BAR WITH 5 TABS
              _buildSubNavBar(state, notifier, isDark),
              const SizedBox(height: 16),

              // 3. MAIN 3-COLUMN OPERATIONAL LAYOUT
              if (isCompact)
                // Compact / Mobile: Column layout
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLocationSelectorPanel(state, notifier, isDark, height: 320),
                    const SizedBox(height: 16),
                    _buildCenterControlPanel(state, notifier, isDark, isCompact: true),
                    const SizedBox(height: 16),
                    _buildRightInspectorPanel(state, notifier, isDark),
                  ],
                )
              else if (isMedium)
                // Tablet / Medium Desktop: 2-column + stacked inspector
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 260,
                          child: _buildLocationSelectorPanel(state, notifier, isDark, height: 850),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildCenterControlPanel(state, notifier, isDark, isCompact: false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildRightInspectorPanel(state, notifier, isDark),
                  ],
                )
              else
                // Large Desktop: Exact 3-column reference design
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Location Selector (~250px)
                    SizedBox(
                      width: 250,
                      child: _buildLocationSelectorPanel(state, notifier, isDark, height: 920),
                    ),
                    const SizedBox(width: 16),

                    // Center Column: Filter + 8 Device Cards + Floor Plan
                    Expanded(
                      child: _buildCenterControlPanel(state, notifier, isDark, isCompact: false),
                    ),
                    const SizedBox(width: 16),

                    // Right Column: Device Control Panel (~350px)
                    SizedBox(
                      width: 350,
                      child: _buildRightInspectorPanel(state, notifier, isDark),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 1. TOP 6-CARD OPERATIONAL KPIS BAR
  // ===========================================================================
  Widget _buildLiveControlKpisBar(LiveControlKpis kpis, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth > 1200
            ? (constraints.maxWidth - (5 * 12)) / 6
            : constraints.maxWidth > 700
                ? (constraints.maxWidth - (2 * 12)) / 3
                : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              title: 'Online Devices',
              value: '${_formatNum(kpis.onlineDevices)} (${kpis.onlinePercentage.toStringAsFixed(1)}%)',
              icon: Icons.power_settings_new,
              iconColor: const Color(0xFF10B981),
              bgColor: const Color(0xFF10B981).withValues(alpha: 0.12),
              isDark: isDark,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Offline Devices',
              value: '${_formatNum(kpis.offlineDevices)} (${kpis.offlinePercentage.toStringAsFixed(1)}%)',
              icon: Icons.power_off,
              iconColor: const Color(0xFFEF4444),
              bgColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
              isDark: isDark,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Controllable Now',
              value: _formatNum(kpis.controllableNow),
              icon: Icons.layers_outlined,
              iconColor: const Color(0xFF0284C7),
              bgColor: const Color(0xFF0284C7).withValues(alpha: 0.12),
              isDark: isDark,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Active Groups',
              value: _formatNum(kpis.activeGroups),
              icon: Icons.hub_outlined,
              iconColor: const Color(0xFF6366F1),
              bgColor: const Color(0xFF6366F1).withValues(alpha: 0.12),
              isDark: isDark,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Running Automations',
              value: _formatNum(kpis.runningAutomations),
              icon: Icons.bolt,
              iconColor: const Color(0xFF0D9488),
              bgColor: const Color(0xFF0D9488).withValues(alpha: 0.12),
              isDark: isDark,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Active Schedules',
              value: _formatNum(kpis.activeSchedules),
              icon: Icons.calendar_month_outlined,
              iconColor: const Color(0xFF3B82F6),
              bgColor: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              isDark: isDark,
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isDark,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
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

  // ===========================================================================
  // 2. SUB-NAVIGATION BAR (5 HORIZONTAL TABS)
  // ===========================================================================
  Widget _buildSubNavBar(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    final tabs = [
      {'title': 'Device Control', 'icon': Icons.computer},
      {'title': 'Group Control', 'icon': Icons.hub_outlined},
      {'title': 'Location Control', 'icon': Icons.location_on_outlined},
      {'title': 'Scenes & Presets', 'icon': Icons.auto_awesome_outlined},
      {'title': 'Live View (CCTV)', 'icon': Icons.videocam_outlined},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 800;

          final titleWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.touch_app_outlined, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Live Control',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Real-time control and monitoring of campus devices, groups and locations.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );

          final tabsWidget = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tabs.map((t) {
                final isSelected = state.liveControlSubTab == t['title'];
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () => notifier.setLiveControlSubTab(t['title'] as String),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            t['icon'] as IconData,
                            size: 15,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t['title'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleWidget,
                const SizedBox(height: 10),
                tabsWidget,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleWidget),
              const SizedBox(width: 16),
              tabsWidget,
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 3. LEFT COLUMN: LOCATION SELECTOR PANEL
  // ===========================================================================
  Widget _buildLocationSelectorPanel(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark, {
    required double height,
  }) {
    final query = _locationSearchCtrl.text.trim().toLowerCase();

    // Default canonical hierarchy if network data is pending
    final hierarchy = state.locationsHierarchy;
    final buildings = hierarchy?.children ?? [
      const LocationHierarchyNode(
        id: '2af829b6-81a4-469a-a91a-71f2bd390fc4',
        name: 'Academic Block (A)',
        code: 'AC-A',
        type: 'building',
        deviceCount: 38,
        children: [
          LocationHierarchyNode(
            id: '3d6c8096-d7b4-4f98-bc3d-c41d924d4d3d',
            name: 'Ground Floor (12)',
            code: 'GF',
            type: 'floor',
            deviceCount: 12,
            children: [
              LocationHierarchyNode(id: '5e6fc8b4-7148-483c-9a91-557a7cf93718', name: 'G001 (Reception)', code: 'G001', type: 'room'),
              LocationHierarchyNode(id: '3d6c8096-d7b4-4f98-bc3d-c41d924d4002', name: 'G002 (Grade 1)', code: 'G002', type: 'room'),
            ],
          ),
          LocationHierarchyNode(
            id: 'b8b4c4de-11e1-4d42-b4ad-27b86c8c823a',
            name: 'First Floor (14)',
            code: '1F',
            type: 'floor',
            deviceCount: 14,
            children: [
              LocationHierarchyNode(id: '4a504056-6e58-46c3-b93c-75fabdae57ac', name: 'A1-101 (Classroom)', code: 'A1-101', type: 'room'),
              LocationHierarchyNode(id: 'e740e824-ee65-4fc6-8e91-4807b158c89e', name: 'A1-102 (Classroom)', code: 'A1-102', type: 'room'),
              LocationHierarchyNode(id: '7a9cd5c9-de76-419f-9c80-8c4fe5d973aa', name: 'A1-103 (Classroom)', code: 'A1-103', type: 'room'),
              LocationHierarchyNode(id: '773252f5-a846-4a96-b909-6e1ef1389557', name: 'A1-104 (Classroom)', code: 'A1-104', type: 'room'),
            ],
          ),
          LocationHierarchyNode(
            id: '5122b423-c027-42b0-8e96-5b131b0ed94e',
            name: 'Second Floor (10)',
            code: '2F',
            type: 'floor',
            deviceCount: 10,
            children: [
              LocationHierarchyNode(id: '5122b423-c027-42b0-8e96-5b131b0ed001', name: '201 (Grade 4)', code: '201', type: 'room'),
              LocationHierarchyNode(id: '5122b423-c027-42b0-8e96-5b131b0ed002', name: '202 (Grade 4)', code: '202', type: 'room'),
            ],
          ),
        ],
      ),
      const LocationHierarchyNode(id: 'bldg-admin', name: 'Admin Block', code: 'ADM', type: 'building', deviceCount: 18),
      const LocationHierarchyNode(id: 'bldg-ac-b', name: 'Academic Block (B)', code: 'AC-B', type: 'building', deviceCount: 36),
      const LocationHierarchyNode(id: 'bldg-lab', name: 'Laboratories Block', code: 'LAB', type: 'building', deviceCount: 24),
      const LocationHierarchyNode(id: 'bldg-lib', name: 'Library Block', code: 'LIB', type: 'building', deviceCount: 8),
      const LocationHierarchyNode(id: 'bldg-aud', name: 'Auditorium Block', code: 'AUD', type: 'building', deviceCount: 4),
      const LocationHierarchyNode(id: 'bldg-spt', name: 'Sports Complex', code: 'SPT', type: 'building', deviceCount: 6),
    ];

    return Container(
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location Selector',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          // Search input
          TextField(
            controller: _locationSearchCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search building, floor, room...',
              hintStyle: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              prefixIcon: const Icon(Icons.search, size: 16),
              prefixIconConstraints: const BoxConstraints(minWidth: 32),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            ),
          ),
          const SizedBox(height: 12),
          // Tree structure
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTreeRootNode(hierarchy?.name ?? 'Greenwood High School', isDark),
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: buildings.map((bldg) {
                        final bldgMatches = query.isEmpty ||
                            bldg.name.toLowerCase().contains(query) ||
                            bldg.children.any((f) =>
                                f.name.toLowerCase().contains(query) ||
                                f.children.any((r) => r.name.toLowerCase().contains(query)));

                        if (!bldgMatches) return const SizedBox.shrink();

                        final isExpanded = _expandedNodeIds.contains(bldg.name) ||
                            _expandedNodeIds.contains(bldg.id) ||
                            query.isNotEmpty;

                        return _buildTreeBuildingNode(
                          title: bldg.name,
                          isDark: isDark,
                          isExpanded: isExpanded,
                          onTap: () {
                            setState(() {
                              if (_expandedNodeIds.contains(bldg.name) || _expandedNodeIds.contains(bldg.id)) {
                                _expandedNodeIds.remove(bldg.name);
                                _expandedNodeIds.remove(bldg.id);
                              } else {
                                _expandedNodeIds.add(bldg.name);
                                _expandedNodeIds.add(bldg.id);
                              }
                            });
                            if (bldg.children.isNotEmpty) {
                              final firstFloor = bldg.children.first;
                              notifier.selectLiveControlLocation(
                                buildingId: bldg.id,
                                floorId: firstFloor.id,
                                roomId: null,
                                clearRoom: true,
                              );
                            }
                          },
                          children: bldg.children.map((floor) {
                            final floorMatches = query.isEmpty ||
                                floor.name.toLowerCase().contains(query) ||
                                floor.children.any((r) => r.name.toLowerCase().contains(query));

                            if (!floorMatches) return const SizedBox.shrink();

                            final isFloorSelected = (state.liveControlFloorId == floor.id ||
                                    (floor.code.isNotEmpty && state.liveControlFloorId.contains(floor.code))) &&
                                state.liveControlRoomId == null;

                            return _buildTreeFloorNode(
                              name: floor.name.contains('(') ? floor.name : '${floor.name} (${floor.deviceCount > 0 ? floor.deviceCount : floor.children.length})',
                              isDark: isDark,
                              isSelected: isFloorSelected,
                              onTap: () {
                                setState(() {
                                  if (_expandedNodeIds.contains(floor.id) || _expandedNodeIds.contains(floor.name)) {
                                    _expandedNodeIds.remove(floor.id);
                                    _expandedNodeIds.remove(floor.name);
                                  } else {
                                    _expandedNodeIds.add(floor.id);
                                    _expandedNodeIds.add(floor.name);
                                  }
                                });
                                notifier.selectLiveControlLocation(
                                  buildingId: bldg.id,
                                  floorId: floor.id,
                                  roomId: null,
                                  clearRoom: true,
                                );
                              },
                              children: floor.children.map((room) {
                                if (query.isNotEmpty && !room.name.toLowerCase().contains(query)) {
                                  return const SizedBox.shrink();
                                }
                                final isRoomSelected = state.liveControlRoomId == room.id ||
                                    state.liveControlRoomId == room.code ||
                                    (room.code.isNotEmpty && state.liveControlRoomId != null && state.liveControlRoomId!.contains(room.code));

                                return _buildTreeRoomNode(
                                  name: room.name,
                                  isDark: isDark,
                                  isSelected: isRoomSelected,
                                  onTap: () => notifier.selectLiveControlLocation(
                                    buildingId: bldg.id,
                                    floorId: floor.id,
                                    roomId: room.id,
                                  ),
                                );
                              }).toList(),
                            );
                          }).toList(),
                        );
                      }).toList(),
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

  Widget _buildTreeRootNode(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.school_outlined, size: 16, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeBuildingNode({
    required String title,
    required bool isDark,
    required bool isExpanded,
    required VoidCallback onTap,
    List<Widget>? children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 16,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.apartment,
                    size: 14,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isExpanded ? FontWeight.w600 : FontWeight.normal,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded && children != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTreeFloorNode({
    required String name,
    required bool isDark,
    required bool isSelected,
    required VoidCallback onTap,
    List<Widget>? children,
  }) {
    final hasChildren = children != null && children.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    hasChildren ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 14,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.layers_outlined,
                    size: 13,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : (isDark ? Colors.white : const Color(0xFF334155)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasChildren)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTreeRoomNode({
    required String name,
    required bool isDark,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                Icons.meeting_room_outlined,
                size: 13,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? Colors.white : const Color(0xFF334155)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. CENTER COLUMN: CONTROLS, DEVICE CARDS, & 2D FLOOR PLAN
  // ===========================================================================
  Widget _buildCenterControlPanel(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark, {
    required bool isCompact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4.1 Filter Row + Search + Sort + View toggle
        _buildCenterFilterBar(state, notifier, isDark),
        const SizedBox(height: 12),

        // 4.2 Multi-selection Action Bar (Operations after selection)
        if (state.liveControlSelectedDeviceIds.isNotEmpty) ...[
          _buildMultiSelectActionBar(state, notifier, isDark),
          const SizedBox(height: 12),
        ],

        // 4.3 Devices Grid or Table View based on view mode toggle
        if (state.isLiveControlGridMode)
          _buildDeviceCardsGrid(state, notifier, isDark, isCompact: isCompact)
        else
          _buildDeviceTableView(state, notifier, isDark),
        const SizedBox(height: 12),

        // 4.4 Database Pagination Controls Footer
        _buildLiveControlPagination(state, notifier, isDark),
        const SizedBox(height: 16),

        // 4.5 2D Interactive Floor Plan View
        _buildFloorPlanSection(state, notifier, isDark),
      ],
    );
  }

  Widget _buildCenterFilterBar(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    final themePrimary = Theme.of(context).colorScheme.primary;

    // Dynamic Device Types from loaded categories
    final dynamicTypes = state.typesCategories.isNotEmpty
        ? state.typesCategories
        : const [
            'All Device Types',
            'Lighting',
            'HVAC (AC)',
            'Projector',
            'Fan',
            'Power & Switches',
            'CCTV',
            'Smart Door',
            'Audio / Speaker',
          ];

    // Dynamic Groups from loaded groups
    final dynamicGroups = ['All Groups', ...state.groupsList.map((g) => g.name)];

    const statusItems = ['All Status', 'Online', 'Offline'];

    const sortOptions = [
      {'label': 'Device Name', 'value': 'device_name'},
      {'label': 'Device Code', 'value': 'device_code'},
      {'label': 'Device Type', 'value': 'device_type'},
      {'label': 'Room Number', 'value': 'room_number'},
      {'label': 'Status', 'value': 'status'},
      {'label': 'Power State', 'value': 'power_state'},
    ];

    final isAllSelected = state.liveControlDevices.isNotEmpty &&
        state.liveControlSelectedDeviceIds.length == state.liveControlDevices.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Select All Checkbox Tool
          InkWell(
            onTap: () => notifier.toggleLiveControlSelectAll(),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isAllSelected ? themePrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isAllSelected
                            ? themePrimary
                            : (isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                        width: 1.5,
                      ),
                    ),
                    child: isAllSelected
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Select All',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filter 1: Device Type (Dynamic)
          _buildFilterDropdown(
            value: state.liveControlTypeFilter,
            items: dynamicTypes,
            onChanged: (val) => notifier.setLiveControlFilters(type: val),
            isDark: isDark,
          ),

          // Filter 2: Groups (Dynamic)
          _buildFilterDropdown(
            value: state.liveControlGroupFilter,
            items: dynamicGroups,
            onChanged: (val) => notifier.setLiveControlFilters(group: val),
            isDark: isDark,
          ),

          // Filter 3: Status
          _buildFilterDropdown(
            value: state.liveControlStatusFilter,
            items: statusItems,
            onChanged: (val) => notifier.setLiveControlFilters(status: val),
            isDark: isDark,
          ),

          // Database Sort Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sort,
                  size: 14,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                DropdownButtonHideUnderline(
                  child: AppSearchableDropdown<String>.fromMenuItems(
                    value: sortOptions.any((o) => o['value'] == state.liveControlSortBy)
                        ? state.liveControlSortBy
                        : 'device_name',
                    isDense: true,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    items: sortOptions.map((item) {
                      return DropdownMenuItem<String>(
                        value: item['value'],
                        child: Text(item['label']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        notifier.setLiveControlSorting(val, state.liveControlSortOrder);
                      }
                    },
                  ),
                ),
                InkWell(
                  onTap: () => notifier.setLiveControlSorting(
                    state.liveControlSortBy,
                    state.liveControlSortOrder == 'asc' ? 'desc' : 'asc',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      state.liveControlSortOrder == 'asc'
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 14,
                      color: themePrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search box
          SizedBox(
            width: 200,
            child: TextField(
              controller: _deviceSearchCtrl,
              onSubmitted: (val) => notifier.setLiveControlFilters(search: val),
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search devices...',
                hintStyle: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.search, size: 16),
                prefixIconConstraints: const BoxConstraints(minWidth: 32),
                suffixIcon: _deviceSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          _deviceSearchCtrl.clear();
                          notifier.setLiveControlFilters(search: '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              ),
            ),
          ),

          // View Mode Toggles
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => notifier.setLiveControlViewMode(true),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: state.isLiveControlGridMode
                          ? themePrimary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.grid_view,
                      size: 16,
                      color: state.isLiveControlGridMode
                          ? Colors.white
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => notifier.setLiveControlViewMode(false),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: !state.isLiveControlGridMode
                          ? themePrimary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.format_list_bulleted,
                      size: 16,
                      color: !state.isLiveControlGridMode
                          ? Colors.white
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectActionBar(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    final themePrimary = Theme.of(context).colorScheme.primary;
    final count = state.liveControlSelectedDeviceIds.length;
    final total = state.liveControlTotal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: themePrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: themePrimary.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, color: themePrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                '$count of $total devices selected',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                onPressed: () => notifier.bulkExecuteLiveControl(
                  commandType: 'turn_on',
                  payload: {'power': true},
                ),
                icon: const Icon(Icons.power_settings_new, size: 14),
                label: const Text('Turn ON All', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => notifier.bulkExecuteLiveControl(
                  commandType: 'turn_off',
                  payload: {'power': false},
                ),
                icon: const Icon(Icons.power_off, size: 14),
                label: const Text('Turn OFF All', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => notifier.bulkExecuteLiveControl(
                  commandType: 'set_brightness',
                  payload: {'brightness': 80},
                ),
                icon: const Icon(Icons.light_mode, size: 14),
                label: const Text('Set 80% Brightness', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              OutlinedButton(
                onPressed: () => notifier.clearLiveControlSelection(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Deselect All', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveControlPagination(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    final total = state.liveControlTotal;
    final page = state.liveControlPage;
    final pageSize = state.liveControlPageSize;
    final totalPages = state.liveControlTotalPages;

    final startIdx = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final endIdx = (page * pageSize > total) ? total : page * pageSize;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Left: Showing X-Y of Z devices + Rows per page
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Showing $startIdx - $endIdx of $total devices',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rows per page:',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<int>.fromMenuItems(
                        value: pageSize,
                        isDense: true,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: const [10, 20, 50, 100].map((size) {
                          return DropdownMenuItem<int>(
                            value: size,
                            child: Text('$size'),
                          );
                        }).toList(),
                        onChanged: (newSize) {
                          if (newSize != null) {
                            notifier.setLiveControlPageSize(newSize);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right: Page navigation controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page, size: 18),
                tooltip: 'First Page',
                onPressed: page > 1 ? () => notifier.setLiveControlPage(1) : null,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                disabledColor: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                tooltip: 'Previous Page',
                onPressed: page > 1 ? () => notifier.setLiveControlPage(page - 1) : null,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                disabledColor: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page $page of ${totalPages < 1 ? 1 : totalPages}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                tooltip: 'Next Page',
                onPressed: page < totalPages ? () => notifier.setLiveControlPage(page + 1) : null,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                disabledColor: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 18),
                tooltip: 'Last Page',
                onPressed: page < totalPages ? () => notifier.setLiveControlPage(totalPages) : null,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                disabledColor: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTableView(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    final devices = state.liveControlDevices;
    final themePrimary = Theme.of(context).colorScheme.primary;

    if (devices.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          'No controllable devices found.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      );
    }

    final isAllSelected = devices.isNotEmpty &&
        devices.every((d) => state.liveControlSelectedDeviceIds.contains(d.id));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 780),
          child: DataTable(
            showCheckboxColumn: false, // Ensures exactly ONE custom checkbox - NO double checkbox!
            headingRowHeight: 42,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 56,
            horizontalMargin: 12,
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            ),
            columns: [
              // Checkbox column
              DataColumn(
                label: InkWell(
                  onTap: () => notifier.toggleLiveControlSelectAll(),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isAllSelected ? themePrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isAllSelected
                            ? themePrimary
                            : (isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                        width: 1.5,
                      ),
                    ),
                    child: isAllSelected
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              DataColumn(
                label: _buildSortableHeader('Device Name', 'device_name', state, notifier, isDark),
              ),
              DataColumn(
                label: _buildSortableHeader('Code', 'device_code', state, notifier, isDark),
              ),
              DataColumn(
                label: _buildSortableHeader('Type', 'device_type', state, notifier, isDark),
              ),
              DataColumn(
                label: _buildSortableHeader('Room / Location', 'room_number', state, notifier, isDark),
              ),
              DataColumn(
                label: _buildSortableHeader('Status', 'status', state, notifier, isDark),
              ),
              DataColumn(
                label: _buildSortableHeader('Power', 'power_state', state, notifier, isDark),
              ),
              const DataColumn(
                label: Text('Quick Live Control', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const DataColumn(
                label: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
            rows: devices.map((device) {
              final isChecked = state.liveControlSelectedDeviceIds.contains(device.id);
              final isSelected = state.selectedLiveDeviceId == device.id;
              return DataRow(
                selected: isSelected,
                color: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (isSelected) {
                    return themePrimary.withValues(alpha: 0.12);
                  }
                  if (isChecked) {
                    return themePrimary.withValues(alpha: 0.06);
                  }
                  return null;
                }),
                onSelectChanged: (_) => notifier.selectLiveControlDevice(device),
                cells: [
                  DataCell(
                    InkWell(
                      onTap: () => notifier.toggleLiveControlSelectDevice(device.id),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: isChecked ? themePrimary : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isChecked
                                ? themePrimary
                                : (isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                            width: 1.5,
                          ),
                        ),
                        child: isChecked
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDeviceTypeIcon(device.deviceTypeName, device.deviceTypeCode),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            device.deviceName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      device.deviceCode,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: themePrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        device.deviceTypeName,
                        style: TextStyle(fontSize: 11, color: themePrimary, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      device.buildingName.isNotEmpty
                          ? '${device.roomNumber} (${device.buildingName} > ${device.floorName})'
                          : device.roomNumber,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DataCell(
                    _buildOnlineStatusBadge(device.isOnline ? 'Online' : 'Offline', isDark),
                  ),
                  DataCell(
                    _buildPowerSwitchOrStatus(device, notifier, isDark),
                  ),
                  DataCell(
                    SizedBox(
                      width: 160,
                      child: _buildInlineQuickControl(device, notifier, isDark),
                    ),
                  ),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      tooltip: 'Inspect Device',
                      onPressed: () => notifier.selectLiveControlDevice(device),
                      color: isSelected ? themePrimary : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSortableHeader(
    String title,
    String columnKey,
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    final isSorted = state.liveControlSortBy == columnKey;
    final isAsc = state.liveControlSortOrder == 'asc';

    return InkWell(
      onTap: () => notifier.setLiveControlSorting(columnKey),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSorted ? FontWeight.bold : FontWeight.w600,
                color: isSorted
                    ? Theme.of(context).colorScheme.primary
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isSorted
                  ? (isAsc ? Icons.arrow_upward : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 13,
              color: isSorted
                  ? Theme.of(context).colorScheme.primary
                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineStatusBadge(String status, bool isDark) {
    final isOnline = status.toLowerCase() == 'online';
    final color = isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineQuickControl(
    LiveControlDeviceItem device,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    final type = device.deviceTypeName;

    if (type.contains('Light')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.light_mode, size: 14, color: isDark ? Colors.amber[300] : Colors.amber[700]),
          const SizedBox(width: 4),
          Text('${device.brightness}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      );
    } else if (type.contains('AC') || type.contains('HVAC')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.ac_unit, size: 14, color: Color(0xFF0284C7)),
          const SizedBox(width: 4),
          Text('${device.temperature.toStringAsFixed(0)}°C', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      );
    } else if (type.contains('Switch')) {
      return Text(
        '${device.channels.length} ch active',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      );
    } else if (type.contains('Projector')) {
      return Text(
        '${device.currentState['input'] ?? 'HDMI 1'}',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      );
    }
    return Text(
      device.powerState ? 'Active' : 'Standby',
      style: TextStyle(
        fontSize: 11,
        color: device.powerState ? const Color(0xFF10B981) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    final currentVal = items.contains(value) ? value : items.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<String>.fromMenuItems(
          value: currentVal,
          onChanged: onChanged,
          isDense: true,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4.2 DEVICE CARDS GRID
  // ===========================================================================
  Widget _buildDeviceCardsGrid(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark, {
    required bool isCompact,
  }) {
    final devices = state.liveControlDevices;

    if (devices.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other_outlined,
              size: 36,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 8),
            Text(
              'No controllable devices found in this selected space.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            if (state.liveControlRoomId != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  notifier.selectLiveControlLocation(
                    buildingId: state.liveControlBuildingId,
                    floorId: state.liveControlFloorId,
                    roomId: null,
                    clearRoom: true,
                  );
                },
                icon: const Icon(Icons.apartment, size: 14),
                label: const Text('View All Floor Devices', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate columns: 4 on desktop, 2 on medium, 1 on small mobile
        final crossAxisCount = constraints.maxWidth > 850
            ? 4
            : (constraints.maxWidth > 480 ? 2 : 1);
        final cardWidth = (constraints.maxWidth - ((crossAxisCount - 1) * 12)) / crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: devices.map((device) {
            final isSelected = state.selectedLiveDeviceId == device.id;
            return SizedBox(
              width: cardWidth,
              child: _buildIndividualDeviceCard(
                device: device,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () => notifier.selectLiveControlDevice(device),
                notifier: notifier,
                state: state,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildIndividualDeviceCard({
    required LiveControlDeviceItem device,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
    required DeviceManagementNotifier notifier,
    required DeviceManagementState state,
  }) {
    final isChecked = state.liveControlSelectedDeviceIds.contains(device.id);
    final themePrimary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? themePrimary
                : (isChecked ? themePrimary.withValues(alpha: 0.7) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            width: isSelected ? 2 : (isChecked ? 1.5 : 1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: themePrimary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Row: Checkbox + Device Icon + Title + Status Pill + Toggle Switch
            Row(
              children: [
                InkWell(
                  onTap: () => notifier.toggleLiveControlSelectDevice(device.id),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isChecked ? themePrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isChecked
                            ? themePrimary
                            : (isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                        width: 1.5,
                      ),
                    ),
                    child: isChecked
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                _buildDeviceTypeIcon(device.deviceTypeName, device.deviceTypeCode),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.deviceName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        device.roomNumber,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildPowerSwitchOrStatus(device, notifier, isDark),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 10),

            // Capability-specific Interactive Bottom Controls
            _buildDeviceBottomControl(device, notifier, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTypeIcon(String typeName, String typeCode) {
    IconData icon = Icons.devices;
    Color color = const Color(0xFF2563EB);
    Color bg = const Color(0xFF2563EB).withValues(alpha: 0.12);

    if (typeName.contains('Light')) {
      icon = Icons.lightbulb_outlined;
      color = const Color(0xFFF59E0B);
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
    } else if (typeName.contains('AC') || typeName.contains('HVAC')) {
      icon = Icons.ac_unit;
      color = const Color(0xFF0284C7);
      bg = const Color(0xFF0284C7).withValues(alpha: 0.12);
    } else if (typeName.contains('Projector')) {
      icon = Icons.videocam_outlined;
      color = const Color(0xFF3B82F6);
      bg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
    } else if (typeName.contains('Fan')) {
      icon = Icons.toys_outlined;
      color = const Color(0xFF0D9488);
      bg = const Color(0xFF0D9488).withValues(alpha: 0.12);
    } else if (typeName.contains('Switch')) {
      icon = Icons.power_outlined;
      color = const Color(0xFF6366F1);
      bg = const Color(0xFF6366F1).withValues(alpha: 0.12);
    } else if (typeName.contains('CCTV') || typeName.contains('Camera')) {
      icon = Icons.videocam;
      color = const Color(0xFF2563EB);
      bg = const Color(0xFF2563EB).withValues(alpha: 0.12);
    } else if (typeName.contains('Door') || typeName.contains('Access')) {
      icon = Icons.meeting_room_outlined;
      color = const Color(0xFF0284C7);
      bg = const Color(0xFF0284C7).withValues(alpha: 0.12);
    } else if (typeName.contains('Audio') || typeName.contains('Speaker')) {
      icon = Icons.volume_up;
      color = const Color(0xFF3B82F6);
      bg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _buildPowerSwitchOrStatus(
    LiveControlDeviceItem device,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    if (device.deviceTypeName.contains('Door')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: device.isLocked
              ? const Color(0xFFEF4444).withValues(alpha: 0.15)
              : const Color(0xFF10B981).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          device.isLocked ? 'Locked' : 'Unlocked',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: device.isLocked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          ),
        ),
      );
    }

    if (device.deviceTypeName.contains('CCTV')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Online',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF10B981),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: device.powerState ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          device.powerState ? 'On' : 'Off',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: device.powerState ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 2),
        SizedBox(
          height: 24,
          child: Transform.scale(
            scale: 0.8,
            child: Switch(
              value: device.powerState,
              activeThumbColor: const Color(0xFF10B981),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (val) {
                notifier.executeLiveDeviceCommand(
                  deviceId: device.id,
                  commandType: 'set_power',
                  payload: {'power': val},
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceBottomControl(
    LiveControlDeviceItem device,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    final name = device.deviceTypeName;

    // 1. Lighting: Slider for brightness
    if (name.contains('Light')) {
      final bright = device.brightness;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Brightness',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Text(
                '$bright%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: const Color(0xFF2563EB),
              inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              thumbColor: const Color(0xFF2563EB),
            ),
            child: Slider(
              value: bright.toDouble(),
              min: 0,
              max: 100,
              onChanged: (val) {
                notifier.executeLiveDeviceCommand(
                  deviceId: device.id,
                  commandType: 'set_brightness',
                  payload: {'brightness': val.round()},
                );
              },
            ),
          ),
        ],
      );
    }

    // 2. HVAC (AC): Quick Temp buttons [-] 24°C [+] | Cool
    if (name.contains('AC') || name.contains('HVAC')) {
      final temp = device.temperature;
      final mode = device.mode;

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '$temp°C | $mode',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              _buildCompactButton(
                icon: Icons.remove,
                onTap: () {
                  if (temp > 16) {
                    notifier.executeLiveDeviceCommand(
                      deviceId: device.id,
                      commandType: 'set_temperature',
                      payload: {'temperature': temp - 1},
                    );
                  }
                },
                isDark: isDark,
              ),
              const SizedBox(width: 4),
              _buildCompactButton(
                icon: Icons.add,
                onTap: () {
                  if (temp < 30) {
                    notifier.executeLiveDeviceCommand(
                      deviceId: device.id,
                      commandType: 'set_temperature',
                      payload: {'temperature': temp + 1},
                    );
                  }
                },
                isDark: isDark,
              ),
            ],
          ),
        ],
      );
    }

    // 3. Projector: Input Selector
    if (name.contains('Projector')) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Input: ${device.input}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<String>(
            initialValue: device.input,
            tooltip: 'Select Input',
            onSelected: (val) {
              notifier.executeLiveDeviceCommand(
                deviceId: device.id,
                commandType: 'set_input',
                payload: {'input': val},
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'HDMI 1', child: Text('HDMI 1')),
              const PopupMenuItem(value: 'HDMI 2', child: Text('HDMI 2')),
              const PopupMenuItem(value: 'Type-C', child: Text('Type-C')),
              const PopupMenuItem(value: 'Wireless Display', child: Text('Wireless Display')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.settings_input_hdmi, size: 12),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 14),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 4. Fan: Speed selector
    if (name.contains('Fan')) {
      final speed = device.fanSpeed;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Speed: $speed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<String>(
            initialValue: speed,
            tooltip: 'Fan Speed',
            onSelected: (val) {
              notifier.executeLiveDeviceCommand(
                deviceId: device.id,
                commandType: 'set_fan_speed',
                payload: {'fan_speed': val},
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Low', child: Text('Low')),
              const PopupMenuItem(value: 'Medium', child: Text('Medium')),
              const PopupMenuItem(value: 'High', child: Text('High')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.toys_outlined, size: 12),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 14),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 5. Smart Switch: Channels 1 2 3 4
    if (name.contains('Switch')) {
      final activeChannels = device.channels;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Channels',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [1, 2, 3, 4].map((ch) {
              final isActive = activeChannels.contains(ch);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () {
                    final nextChannels = List<int>.from(activeChannels);
                    if (isActive) {
                      nextChannels.remove(ch);
                    } else {
                      nextChannels.add(ch);
                    }
                    notifier.executeLiveDeviceCommand(
                      deviceId: device.id,
                      commandType: 'set_channels',
                      payload: {'channels': nextChannels},
                    );
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$ch',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    }

    // 6. CCTV: Live View button
    if (name.contains('CCTV') || name.contains('Camera')) {
      return SizedBox(
        width: double.infinity,
        height: 26,
        child: OutlinedButton.icon(
          onPressed: () => _showCctvLiveViewDialog(device),
          icon: const Icon(Icons.play_arrow, size: 14),
          label: const Text('Live View', style: TextStyle(fontSize: 11)),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: const Color(0xFF2563EB),
            side: const BorderSide(color: Color(0xFF2563EB)),
          ),
        ),
      );
    }

    // 7. Access Door: Unlock and Lock buttons
    if (name.contains('Door')) {
      final isLocked = device.isLocked;
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 26,
              child: OutlinedButton(
                onPressed: () {
                  notifier.executeLiveDeviceCommand(
                    deviceId: device.id,
                    commandType: 'set_lock',
                    payload: {'status': 'unlocked'},
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                ),
                child: const Text('Unlock', style: TextStyle(fontSize: 11)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 26,
              child: ElevatedButton(
                onPressed: () {
                  notifier.executeLiveDeviceCommand(
                    deviceId: device.id,
                    commandType: 'set_lock',
                    payload: {'status': 'locked'},
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: isLocked ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Lock', style: TextStyle(fontSize: 11)),
              ),
            ),
          ),
        ],
      );
    }

    // 8. Audio / Speaker: Volume Slider
    if (name.contains('Audio') || name.contains('Speaker')) {
      final vol = device.volume;
      return Row(
        children: [
          const Icon(Icons.volume_down, size: 14, color: Color(0xFF64748B)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                activeTrackColor: const Color(0xFF2563EB),
                inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                thumbColor: const Color(0xFF2563EB),
              ),
              child: Slider(
                value: vol.toDouble(),
                min: 0,
                max: 100,
                onChanged: (val) {
                  notifier.executeLiveDeviceCommand(
                    deviceId: device.id,
                    commandType: 'set_volume',
                    payload: {'volume': val.round()},
                  );
                },
              ),
            ),
          ),
          Text(
            '$vol%',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    return const SizedBox(height: 10);
  }

  Widget _buildCompactButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Icon(icon, size: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
      ),
    );
  }

  // ===========================================================================
  // 4.3 2D ARCHITECTURAL FLOOR PLAN VIEW (Academic Block A - First Floor)
  // ===========================================================================
  Widget _buildFloorPlanSection(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Open Full Plan button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.map_outlined, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getFloorPlanTitle(state),
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
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showFullFloorPlanDialog(state),
                icon: const Icon(Icons.fullscreen, size: 15),
                label: const Text('Open Full Plan', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Floor plan canvas + Legend
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2D Drawing Canvas
              Expanded(
                flex: 4,
                child: Container(
                  height: 290,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Zoom & Layer floating controls on left
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildPlanToolButton(Icons.add, () {
                                setState(() => _floorPlanZoom = (_floorPlanZoom + 0.1).clamp(0.8, 2.0));
                              }, isDark),
                              const Divider(height: 1, thickness: 1),
                              _buildPlanToolButton(Icons.remove, () {
                                setState(() => _floorPlanZoom = (_floorPlanZoom - 0.1).clamp(0.8, 2.0));
                              }, isDark),
                              const Divider(height: 1, thickness: 1),
                              _buildPlanToolButton(Icons.crop_free, () {
                                setState(() => _floorPlanZoom = 1.0);
                              }, isDark),
                              const Divider(height: 1, thickness: 1),
                              _buildPlanToolButton(Icons.layers_outlined, () {}, isDark),
                            ],
                          ),
                        ),
                      ),

                      // Floor Plan Architectural Polygons Canvas
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return _buildArchitecturalFloorPlan(
                              w: constraints.maxWidth,
                              h: constraints.maxHeight,
                              state: state,
                              notifier: notifier,
                              isDark: isDark,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Legend column on right
              SizedBox(
                width: 145,
                child: _buildFloorPlanLegend(isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanToolButton(IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        child: Icon(icon, size: 14, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
      ),
    );
  }

  String _getFloorPlanTitle(DeviceManagementState state) {
    String bldgName = 'Academic Block (A)';
    String floorName = 'First Floor';
    String? roomCode;

    if (state.locationsHierarchy != null) {
      for (final b in state.locationsHierarchy!.children) {
        final isCurBldg = b.id == state.liveControlBuildingId ||
            (state.liveControlBuildingId == null && b.name.contains('Academic Block (A)'));
        if (isCurBldg) {
          bldgName = b.name;
        }
        for (final f in b.children) {
          if (f.id == state.liveControlFloorId || (state.liveControlFloorId.contains(f.code) && f.code.isNotEmpty)) {
            bldgName = b.name;
            floorName = f.name;
            if (state.liveControlRoomId != null) {
              for (final r in f.children) {
                if (r.id == state.liveControlRoomId || r.code == state.liveControlRoomId) {
                  roomCode = r.code;
                  break;
                }
              }
            }
            break;
          }
        }
      }
    }

    if (state.floorPlanAsset != null && state.floorPlanAsset!.title.isNotEmpty) {
      final t = state.floorPlanAsset!.title;
      if (t.contains('–')) {
        final parts = t.split('–');
        if (parts.isNotEmpty) bldgName = parts[0].trim();
        if (parts.length > 1) {
          floorName = parts[1].replaceAll('Architectural Plan', '').replaceAll('Floor Plan', '').trim();
        }
      }
    }

    return 'Floor Plan – $bldgName > $floorName${roomCode != null ? " ($roomCode)" : ""}';
  }

  List<IconData> _getIconsForRoom(String roomId, String roomCode, DeviceManagementState state) {
    final icons = <IconData>{};
    for (final dev in state.liveControlDevices) {
      if (dev.roomId == roomId || dev.roomNumber == roomCode) {
        final cat = dev.systemCategory.toLowerCase();
        final name = dev.deviceName.toLowerCase();
        if (cat.contains('light') || name.contains('light') || name.contains('classro')) {
          icons.add(Icons.lightbulb_outlined);
        } else if (cat.contains('hvac') || cat.contains('ac') || name.contains('ac')) {
          icons.add(Icons.ac_unit);
        } else if (cat.contains('cctv') || cat.contains('cam') || name.contains('cctv')) {
          icons.add(Icons.videocam);
        } else if (cat.contains('proj') || name.contains('proj')) {
          icons.add(Icons.cast);
        } else if (cat.contains('fan') || name.contains('fan')) {
          icons.add(Icons.toys_outlined);
        } else if (cat.contains('door') || name.contains('door') || name.contains('lock')) {
          icons.add(Icons.meeting_room_outlined);
        } else if (cat.contains('power') || name.contains('plug') || name.contains('smart')) {
          icons.add(Icons.power_settings_new);
        } else if (cat.contains('audio') || name.contains('sound') || name.contains('speak')) {
          icons.add(Icons.volume_up_outlined);
        }
      }
    }
    for (final m in state.floorPlanMarkers) {
      if (m.roomId == roomId) {
        final type = m.deviceType.toLowerCase();
        if (type.contains('light')) icons.add(Icons.lightbulb_outlined);
        if (type.contains('hvac') || type.contains('ac')) icons.add(Icons.ac_unit);
        if (type.contains('cctv')) icons.add(Icons.videocam);
        if (type.contains('proj')) icons.add(Icons.cast);
        if (type.contains('audio')) icons.add(Icons.volume_up_outlined);
      }
    }
    if (icons.isEmpty) {
      return const [Icons.sensors, Icons.lightbulb_outlined];
    }
    return icons.take(2).toList();
  }

  Widget _buildArchitecturalFloorPlan({
    required double w,
    required double h,
    required DeviceManagementState state,
    required DeviceManagementNotifier notifier,
    required bool isDark,
  }) {
    final rooms = (state.floorPlanAsset?.roomsLayout != null &&
            state.floorPlanAsset!.roomsLayout.isNotEmpty)
        ? state.floorPlanAsset!.roomsLayout
        : const [
            FloorPlanRoomLayout(
              roomId: 'A1-101',
              code: 'A1-101',
              name: 'Classroom',
              x: 0.02,
              y: 0.06,
              w: 0.22,
              h: 0.38,
            ),
            FloorPlanRoomLayout(
              roomId: 'A1-102',
              code: 'A1-102',
              name: 'Classroom',
              x: 0.26,
              y: 0.06,
              w: 0.22,
              h: 0.38,
            ),
            FloorPlanRoomLayout(
              roomId: 'A1-103',
              code: 'A1-103',
              name: 'Classroom',
              x: 0.50,
              y: 0.06,
              w: 0.22,
              h: 0.38,
            ),
            FloorPlanRoomLayout(
              roomId: 'A1-104',
              code: 'A1-104',
              name: 'Classroom',
              x: 0.74,
              y: 0.06,
              w: 0.22,
              h: 0.38,
            ),
            FloorPlanRoomLayout(
              roomId: 'corridor-1',
              code: 'Corridor',
              name: 'Corridor',
              x: 0.02,
              y: 0.46,
              w: 0.94,
              h: 0.08,
            ),
            FloorPlanRoomLayout(
              roomId: 'A1-105',
              code: 'A1-105',
              name: 'Classroom',
              x: 0.02,
              y: 0.56,
              w: 0.30,
              h: 0.38,
            ),
            FloorPlanRoomLayout(
              roomId: 'A1-106',
              code: 'A1-106',
              name: 'Classroom',
              x: 0.34,
              y: 0.56,
              w: 0.30,
              h: 0.38,
            ),
            FloorPlanRoomLayout(
              roomId: 'A1-107',
              code: 'A1-107',
              name: 'Classroom',
              x: 0.66,
              y: 0.56,
              w: 0.30,
              h: 0.38,
            ),
          ];

    return Stack(
      children: rooms.map((room) {
        if (room.code.toLowerCase() == 'corridor') {
          return Positioned(
            left: w * room.x,
            top: h * room.y,
            width: w * room.w,
            height: h * room.h,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Text(
                'Corridor',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }

        final isHighlighted = state.liveControlRoomId != null &&
            (state.liveControlRoomId == room.roomId ||
             state.liveControlRoomId == room.code ||
             (room.code.isNotEmpty && state.liveControlRoomId!.contains(room.code)));

        final icons = _getIconsForRoom(room.roomId, room.code, state);

        return _buildRoomBox(
          x: w * room.x,
          y: h * room.y,
          width: w * room.w,
          height: h * room.h,
          roomCode: room.code,
          roomName: room.name,
          isHighlighted: isHighlighted,
          isDark: isDark,
          icons: icons,
          onTap: () => notifier.selectLiveControlLocation(
            buildingId: state.liveControlBuildingId,
            floorId: state.liveControlFloorId,
            roomId: room.roomId,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRoomBox({
    required double x,
    required double y,
    required double width,
    required double height,
    required String roomCode,
    required String roomName,
    required bool isHighlighted,
    required bool isDark,
    required List<IconData> icons,
    required VoidCallback onTap,
  }) {
    final borderColor = isHighlighted
        ? const Color(0xFF0D9488)
        : (isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8));

    final fillColor = isHighlighted
        ? (isDark
            ? const Color(0xFF0F766E).withValues(alpha: 0.35)
            : const Color(0xFFCCFBF1).withValues(alpha: 0.7))
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    return Positioned(
      left: x,
      top: y,
      width: width,
      height: height,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: fillColor,
            border: Border.all(
              color: borderColor,
              width: isHighlighted ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                roomCode,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isHighlighted
                      ? const Color(0xFF0F766E)
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
              Text(
                roomName,
                style: TextStyle(
                  fontSize: 8.5,
                  color: isHighlighted
                      ? const Color(0xFF0F766E)
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: icons.map((ic) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      ic,
                      size: 11,
                      color: isHighlighted
                          ? const Color(0xFF0D9488)
                          : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloorPlanLegend(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Legend',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        _buildLegendStatusRow('Online (Controllable)', const Color(0xFF10B981), isDark),
        _buildLegendStatusRow('Offline', const Color(0xFF94A3B8), isDark),
        _buildLegendStatusRow('Attention / Alert', const Color(0xFFF59E0B), isDark),
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 8),
        _buildLegendIconRow('Lighting', Icons.lightbulb_outlined, isDark),
        _buildLegendIconRow('HVAC (AC)', Icons.ac_unit, isDark),
        _buildLegendIconRow('Projector', Icons.videocam_outlined, isDark),
        _buildLegendIconRow('Fan', Icons.toys_outlined, isDark),
        _buildLegendIconRow('CCTV', Icons.videocam, isDark),
        _buildLegendIconRow('Access Door', Icons.meeting_room_outlined, isDark),
        _buildLegendIconRow('Audio / Speaker', Icons.volume_up, isDark),
        _buildLegendIconRow('Smart Switch', Icons.power_outlined, isDark),
      ],
    );
  }

  Widget _buildLegendStatusRow(String label, Color dotColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendIconRow(String label, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: const Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. RIGHT COLUMN: DEVICE CONTROL PANEL & INSPECTOR (~350px)
  // ===========================================================================
  Widget _buildRightInspectorPanel(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    final selectedDev = state.selectedLiveDevice;
    if (selectedDev == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: const Center(child: Text('Select a device to view controls')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Device Control Panel title + expand icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.tune, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Device Control Panel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 16),
                tooltip: 'Popout Controls',
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Device Identity Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                _buildDeviceTypeIcon(selectedDev.deviceTypeName, selectedDev.deviceTypeCode),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${selectedDev.deviceName} – ${selectedDev.roomNumber}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${selectedDev.buildingName} > ${selectedDev.floorName} > ${selectedDev.roomNumber}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selectedDev.isOnline
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: selectedDev.isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        selectedDev.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: selectedDev.isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4 Segmented Tabs: Control, Status, Usage, Logs
          _buildInspectorTabs(state, notifier, isDark),
          const SizedBox(height: 16),

          // Tab Body
          if (state.liveControlRightTab == 'Control')
            _buildInspectorControlTab(selectedDev, notifier, isDark)
          else if (state.liveControlRightTab == 'Status')
            _buildInspectorStatusTab(selectedDev, state.liveDeviceDetails, isDark)
          else if (state.liveControlRightTab == 'Usage')
            _buildInspectorUsageTab(selectedDev, isDark)
          else
            _buildInspectorLogsTab(state.liveDeviceDetails, isDark),

          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 14),

          // Collapsible Device Information Section
          _buildDeviceInfoSection(selectedDev, isDark),
        ],
      ),
    );
  }

  Widget _buildInspectorTabs(
    DeviceManagementState state,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    final tabs = ['Control', 'Status', 'Usage', 'Logs'];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: tabs.map((t) {
          final isSelected = state.liveControlRightTab == t;
          return Expanded(
            child: InkWell(
              onTap: () => notifier.setLiveControlRightTab(t),
              borderRadius: BorderRadius.circular(7),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  t,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInspectorControlTab(
    LiveControlDeviceItem device,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Power Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Power',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Row(
              children: [
                Text(
                  device.powerState ? 'On' : 'Off',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: device.powerState ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 6),
                Switch(
                  value: device.powerState,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (val) {
                    notifier.executeLiveDeviceCommand(
                      deviceId: device.id,
                      commandType: 'set_power',
                      payload: {'power': val},
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Mode Segment (5 Modes with icons: Cool, Heat, Fan, Dry, Auto)
        Text(
          'Mode',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        _buildModeButtons(device, notifier, isDark),
        const SizedBox(height: 14),

        // Temperature Row: [-] 24°C [+] (Set Range 16-30°C)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Temperature',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    'Set Range: 16°C – 30°C',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTempAdjustButton(
                  icon: Icons.remove,
                  onTap: () {
                    if (device.temperature > 16) {
                      notifier.executeLiveDeviceCommand(
                        deviceId: device.id,
                        commandType: 'set_temperature',
                        payload: {'temperature': device.temperature - 1},
                      );
                    }
                  },
                  isDark: isDark,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${device.temperature}°C',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                _buildTempAdjustButton(
                  icon: Icons.add,
                  onTap: () {
                    if (device.temperature < 30) {
                      notifier.executeLiveDeviceCommand(
                        deviceId: device.id,
                        commandType: 'set_temperature',
                        payload: {'temperature': device.temperature + 1},
                      );
                    }
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Fan Speed & Swing Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fan Speed',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        value: ['Low', 'Medium', 'High'].contains(device.fanSpeed)
                            ? device.fanSpeed
                            : 'Medium',
                        isExpanded: true,
                        isDense: true,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        onChanged: (val) {
                          if (val != null) {
                            notifier.executeLiveDeviceCommand(
                              deviceId: device.id,
                              commandType: 'set_fan_speed',
                              payload: {'fan_speed': val},
                            );
                          }
                        },
                        items: ['Low', 'Medium', 'High'].map((s) {
                          return DropdownMenuItem(value: s, child: Text(s));
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Swing',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        device.swing ? 'On' : 'Off',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: device.swing ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Switch(
                        value: device.swing,
                        activeThumbColor: const Color(0xFF10B981),
                        onChanged: (val) {
                          notifier.executeLiveDeviceCommand(
                            deviceId: device.id,
                            commandType: 'set_swing',
                            payload: {'swing': val},
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Quick Presets (Classroom 24°C, Meeting 22°C, Energy Save 26°C, Custom)
        Text(
          'Quick Presets',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        _buildQuickPresetsRow(device, notifier, isDark),
        const SizedBox(height: 14),

        // Other Actions (Schedule, Add to Group, Create Rule, Scene / Preset)
        Text(
          'Other Actions',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        _buildOtherActionsGrid(isDark),
      ],
    );
  }

  Widget _buildModeButtons(
    LiveControlDeviceItem device,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    final modes = [
      {'name': 'Cool', 'icon': Icons.ac_unit},
      {'name': 'Heat', 'icon': Icons.wb_sunny_outlined},
      {'name': 'Fan', 'icon': Icons.toys_outlined},
      {'name': 'Dry', 'icon': Icons.water_drop_outlined},
      {'name': 'Auto', 'icon': Icons.brightness_auto_outlined},
    ];

    return Row(
      children: modes.map((m) {
        final isSelected = device.mode.toLowerCase() == (m['name'] as String).toLowerCase();
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () {
                notifier.executeLiveDeviceCommand(
                  deviceId: device.id,
                  commandType: 'set_mode',
                  payload: {'mode': m['name']},
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      m['icon'] as IconData,
                      size: 15,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      m['name'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTempAdjustButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Icon(icon, size: 16, color: isDark ? Colors.white : const Color(0xFF0F172A)),
      ),
    );
  }

  Widget _buildQuickPresetsRow(
    LiveControlDeviceItem device,
    DeviceManagementNotifier notifier,
    bool isDark,
  ) {
    final presets = [
      {'name': 'Classroom', 'temp': '24°C'},
      {'name': 'Meeting', 'temp': '22°C'},
      {'name': 'Energy Save', 'temp': '26°C'},
      {'name': 'Custom', 'temp': ''},
    ];

    return Row(
      children: presets.map((p) {
        final isSelected = device.quickPreset == p['name'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () {
                notifier.executeLiveDeviceCommand(
                  deviceId: device.id,
                  commandType: 'quick_preset',
                  payload: {'preset': p['name']},
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      p['name'] as String,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((p['temp'] as String).isNotEmpty)
                      Text(
                        p['temp'] as String,
                        style: TextStyle(
                          fontSize: 8.5,
                          color: isSelected
                              ? Colors.white70
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOtherActionsGrid(bool isDark) {
    final actions = [
      {'label': 'Schedule', 'icon': Icons.calendar_month_outlined},
      {'label': 'Add to Group', 'icon': Icons.group_add_outlined},
      {'label': 'Create Rule', 'icon': Icons.bolt},
      {'label': 'Scene / Preset', 'icon': Icons.auto_awesome_outlined},
    ];

    return Row(
      children: actions.map((act) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      act['icon'] as IconData,
                      size: 15,
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      act['label'] as String,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Inspector Status Tab
  Widget _buildInspectorStatusTab(
    LiveControlDeviceItem device,
    LiveControlDeviceDetails? details,
    bool isDark,
  ) {
    return Column(
      children: [
        _buildInfoRow('Connection', 'MQTT Online (Mosquitto)', isDark),
        _buildInfoRow('Uptime', '14 days 6 hours', isDark),
        _buildInfoRow('Signal (RSSI)', '-58 dBm (Strong)', isDark),
        _buildInfoRow('Topic', device.mqttTopic, isDark),
        _buildInfoRow('Firmware', 'v2.4.12 Enterprise', isDark),
        _buildInfoRow('Rated Power', '${device.ratedPowerWatts.toInt()} Watts', isDark),
      ],
    );
  }

  // Inspector Usage Tab
  Widget _buildInspectorUsageTab(LiveControlDeviceItem device, bool isDark) {
    return Column(
      children: [
        _buildInfoRow('Power Load Now', '1.8 kW', isDark),
        _buildInfoRow('Today Usage', '14.2 kWh', isDark),
        _buildInfoRow('Operating Hours', '6.5 hrs today', isDark),
        _buildInfoRow('Estimated Cost', '\$2.14', isDark),
        _buildInfoRow('Efficiency Rating', 'Class A+++ Energy Star', isDark),
      ],
    );
  }

  // Inspector Logs Tab
  Widget _buildInspectorLogsTab(
    LiveControlDeviceDetails? details,
    bool isDark,
  ) {
    final logs = details?.recentLogs ?? [];
    if (logs.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text(
          'No recent command logs.',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      );
    }

    return Column(
      children: logs.take(6).map((log) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 10, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.commandType,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      log.payload.toString(),
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                log.status,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Device Information Accordion
  Widget _buildDeviceInfoSection(LiveControlDeviceItem device, bool isDark) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _deviceInfoExpanded = !_deviceInfoExpanded),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 15, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Text(
                    'Device Information',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Icon(
                _deviceInfoExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 16,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ],
          ),
        ),
        if (_deviceInfoExpanded) ...[
          const SizedBox(height: 10),
          _buildInfoRow('Device ID', device.deviceCode, isDark),
          _buildInfoRow('Type / Profile', '${device.deviceTypeName} / ${device.profileName}', isDark),
          _buildInfoRow('IP Address', device.ipAddress, isDark),
          _buildInfoRow('MAC Address', device.macAddress, isDark),
          _buildInfoRow('Status', 'Online (Controllable)', isDark, isGreenStatus: true),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {bool isGreenStatus = false}) {
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
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isGreenStatus
                    ? const Color(0xFF10B981)
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Dialogs
  void _showCctvLiveViewDialog(LiveControlDeviceItem device) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 650,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.videocam, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${device.deviceName} – Live Stream (${device.roomNumber})',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 320,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam, color: Colors.white54, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              'Live RTSP Stream: ${device.deviceCode}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '1080p @ 30 FPS • Bitrate 2.4 Mbps • Low Latency H.264',
                              style: TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                              SizedBox(width: 4),
                              Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'PTZ Controls: Pan 120° | Tilt 45° | Zoom 1.0x',
                        style: TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('Close Stream'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
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

  void _showFullFloorPlanDialog(DeviceManagementState state) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 1000,
            height: 650,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Full Architectural ${_getFloorPlanTitle(state)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildArchitecturalFloorPlan(
                          w: constraints.maxWidth,
                          h: constraints.maxHeight,
                          state: state,
                          notifier: ref.read(deviceManagementProvider.notifier),
                          isDark: isDark,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatNum(num n) {
    final str = n.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }
}
