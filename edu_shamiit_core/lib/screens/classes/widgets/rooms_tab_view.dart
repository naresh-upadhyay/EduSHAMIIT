import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/class_models.dart';
import '../providers/class_provider.dart';
import '../services/academic_lookup_helper.dart';
import 'dialogs/create_edit_room_dialog.dart';
import 'dialogs/archive_confirmation_dialog.dart';

class RoomsTabView extends ConsumerWidget {
  const RoomsTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(classProvider);
    final notifier = ref.read(classProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1000;

        return Column(
          children: [
            // 1. KPI Cards Dashboard
            _buildKpiDashboard(context, state, isDark),

            // 2. Multi-Filter and Search Toolbar
            _buildFilterToolbar(context, state, notifier, isDark),

            // 3. Main Content: Table/Floor Grid + Sidebar
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.rooms.isEmpty
                      ? _buildEmptyState(context, isDark, notifier)
                      : isCompact
                          ? _buildMobileLayout(context, state, notifier, isDark)
                          : _buildDesktopLayout(context, state, notifier, isDark),
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // 1. KPI CARDS ROW
  // =========================================================================
  Widget _buildKpiDashboard(BuildContext context, ClassState state, bool isDark) {
    final stats = state.stats;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVerySmall = constraints.maxWidth < 540;
        final isSmall = constraints.maxWidth < 950;
        final hPadding = constraints.maxWidth < 600 ? 14.0 : 24.0;
        final vPadding = constraints.maxWidth < 600 ? 10.0 : 16.0;

        final cards = [
          _buildKpiCard(
            title: 'Total Rooms',
            value: '${stats.totalRooms}',
            subtitle: '${stats.totalRoomCapacity} Total Seats',
            icon: Icons.meeting_room_rounded,
            color: const Color(0xFF4F46E5),
            isDark: isDark,
            isCompact: isVerySmall,
          ),
          _buildKpiCard(
            title: 'Available Now',
            value: '${stats.availableRooms}',
            subtitle: 'Ready for assignment',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
            isCompact: isVerySmall,
          ),
          _buildKpiCard(
            title: 'In Use / Occupied',
            value: '${stats.inUseRooms}',
            subtitle: 'Active sections / spaces',
            icon: Icons.groups_rounded,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            isCompact: isVerySmall,
          ),
          _buildKpiCard(
            title: 'Maintenance',
            value: '${stats.maintenanceRooms}',
            subtitle: 'Under repair / cleaning',
            icon: Icons.build_circle_rounded,
            color: const Color(0xFFEF4444),
            isDark: isDark,
            isCompact: isVerySmall,
          ),
        ];

        return Container(
          padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: isSmall
              ? Column(
                  children: [
                    Row(children: [Expanded(child: cards[0]), SizedBox(width: isVerySmall ? 8 : 12), Expanded(child: cards[1])]),
                    SizedBox(height: isVerySmall ? 8 : 12),
                    Row(children: [Expanded(child: cards[2]), SizedBox(width: isVerySmall ? 8 : 12), Expanded(child: cards[3])]),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 14),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 14),
                    Expanded(child: cards[2]),
                    const SizedBox(width: 14),
                    Expanded(child: cards[3]),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    bool isCompact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 16,
        vertical: isCompact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 7 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: isCompact ? 18 : 22),
          ),
          SizedBox(width: isCompact ? 8 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isCompact ? 10.5 : 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isCompact ? 10 : 11,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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

  // =========================================================================
  // 2. FILTER & SEARCH TOOLBAR
  // =========================================================================
  Widget _buildFilterToolbar(BuildContext context, ClassState state, ClassNotifier notifier, bool isDark) {
    final lookupHelper = AcademicLookupHelper.instance;
    final activeTypes = lookupHelper.getCachedLookup('ROOM_TYPE');
    final activeBuildings = lookupHelper.getCachedLookup('CAMPUS_BUILDING');
    final activeFloors = lookupHelper.getCachedLookup('BUILDING_FLOOR');
    final activeStatuses = lookupHelper.getCachedLookup('ROOM_STATUS');

    final buildings = ['ALL', ...activeBuildings.map((b) => b.label)];
    final floors = ['ALL', ...activeFloors.map((f) => f.label)];
    final roomTypes = ['ALL', ...activeTypes.map((t) => t.label)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWrap = constraints.maxWidth < 950;

          final searchWidget = Container(
            height: 38,
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
            child: TextField(
              onChanged: notifier.setRoomSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search rooms, codes, buildings...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
            ),
          );

          final typeDropdown = _buildSmallDropdown(
            value: roomTypes.contains(state.roomTypeFilter) ? state.roomTypeFilter : 'ALL',
            items: roomTypes,
            labelPrefix: 'Type: ',
            isDark: isDark,
            onChanged: (v) {
              if (v != null) notifier.setRoomTypeFilter(v);
            },
          );

          final buildingDropdown = _buildSmallDropdown(
            value: buildings.contains(state.roomBuildingFilter) ? state.roomBuildingFilter : 'ALL',
            items: buildings,
            labelPrefix: 'Building: ',
            isDark: isDark,
            onChanged: (v) {
              if (v != null) notifier.setRoomBuildingFilter(v);
            },
          );

          final floorDropdown = _buildSmallDropdown(
            value: floors.contains(state.roomFloorFilter) ? state.roomFloorFilter : 'ALL',
            items: floors,
            labelPrefix: 'Floor: ',
            isDark: isDark,
            onChanged: (v) {
              if (v != null) notifier.setRoomFloorFilter(v);
            },
          );

          final statusItems = ['ALL', ...activeStatuses.map((s) => s.code)];
          final statusDropdown = Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: statusItems.contains(state.roomStatusFilter) ? state.roomStatusFilter : 'ALL',
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('Status: All')),
                  ...activeStatuses.map((s) => DropdownMenuItem(
                        value: s.code,
                        child: Text('Status: ${s.label}'),
                      )),
                ],
                onChanged: (v) {
                  if (v != null) notifier.setRoomStatusFilter(v);
                },
              ),
            ),
          );

          final viewToggle = Container(
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewModeButton(
                  icon: Icons.table_rows_rounded,
                  label: 'Table',
                  isSelected: state.roomViewMode == 'TABLE',
                  onTap: () => notifier.setRoomViewMode('TABLE'),
                  isDark: isDark,
                ),
                _buildViewModeButton(
                  icon: Icons.grid_view_rounded,
                  label: 'Floor Map',
                  isSelected: state.roomViewMode == 'FLOOR',
                  onTap: () => notifier.setRoomViewMode('FLOOR'),
                  isDark: isDark,
                ),
              ],
            ),
          );

          if (isWrap) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: searchWidget),
                    const SizedBox(width: 10),
                    viewToggle,
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      typeDropdown,
                      const SizedBox(width: 8),
                      buildingDropdown,
                      const SizedBox(width: 8),
                      floorDropdown,
                      const SizedBox(width: 8),
                      statusDropdown,
                    ],
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              searchWidget,
              const SizedBox(width: 12),
              typeDropdown,
              const SizedBox(width: 8),
              buildingDropdown,
              const SizedBox(width: 8),
              floorDropdown,
              const SizedBox(width: 8),
              statusDropdown,
              const Spacer(),
              viewToggle,
            ],
          );
        },
      ),
    );
  }

  Widget _buildSmallDropdown({
    required String value,
    required List<String> items,
    required String labelPrefix,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          items: items.map((it) {
            final display = it == 'ALL' ? 'All' : it;
            return DropdownMenuItem(
              value: it,
              child: Text('$labelPrefix$display'),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildViewModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF4F46E5) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? (isDark ? Colors.white : const Color(0xFF4F46E5))
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 3. DESKTOP LAYOUT (TABLE + CONDITIONAL RIGHT SIDEBAR)
  // =========================================================================
  Widget _buildDesktopLayout(BuildContext context, ClassState state, ClassNotifier notifier, bool isDark) {
    final hasSelectedRoom = state.selectedRoom != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebarWidth = (constraints.maxWidth * 0.32).clamp(340.0, 420.0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Room Table / Grid (Fills full width or shares with sidebar)
            Expanded(
              child: state.roomViewMode == 'FLOOR'
                  ? _buildFloorLayoutView(context, state, notifier, isDark)
                  : _buildRoomsTable(context, state, notifier, isDark),
            ),

            // Right Sidebar Detail Panel (Opens when a room is clicked)
            if (hasSelectedRoom)
              Container(
                width: sidebarWidth,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: Border(
                    left: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: _buildRoomSidebarDetail(context, state, notifier, isDark),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context, ClassState state, ClassNotifier notifier, bool isDark) {
    final hasSelectedRoom = state.selectedRoom != null;
    final mainContent = state.roomViewMode == 'FLOOR'
        ? _buildFloorLayoutView(context, state, notifier, isDark)
        : _buildRoomsTable(context, state, notifier, isDark);

    if (!hasSelectedRoom) {
      return mainContent;
    }

    return Stack(
      children: [
        mainContent,
        // Semi-transparent backdrop for dismissing
        Positioned.fill(
          child: GestureDetector(
            onTap: () => notifier.clearSelectedRoom(),
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
        ),
        // Slide-in Drawer from Right
        Align(
          alignment: Alignment.centerRight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final drawerWidth = (constraints.maxWidth * 0.88).clamp(280.0, 420.0);
              return Container(
                width: drawerWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(-4, 0),
                    ),
                  ],
                ),
                child: _buildRoomSidebarDetail(context, state, notifier, isDark),
              );
            },
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // ROOMS TABLE VIEW
  // =========================================================================
  Widget _buildRoomsTable(BuildContext context, ClassState state, ClassNotifier notifier, bool isDark) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: MaterialStateProperty.all(
                        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      ),
                      headingTextStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                      dataRowMinHeight: 58,
                      dataRowMaxHeight: 64,
                      horizontalMargin: 20,
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('ROOM NAME & CODE')),
                        DataColumn(label: Text('TYPE')),
                        DataColumn(label: Text('LOCATION')),
                        DataColumn(label: Text('CAPACITY & FACILITIES')),
                        DataColumn(label: Text('CURRENT STATUS')),
                        DataColumn(label: Text('ACTIONS')),
                      ],
              rows: state.rooms.map((room) {
                final isSelected = state.selectedRoom?.id == room.id;

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) => notifier.selectRoom(room),
                  color: MaterialStateProperty.resolveWith((states) {
                    if (isSelected) {
                      return const Color(0xFF4F46E5).withOpacity(0.08);
                    }
                    return null;
                  }),
                  cells: [
                    // Name & Code
                    DataCell(
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _getRoomTypeColor(room.type).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getRoomTypeIcon(room.type),
                              color: _getRoomTypeColor(room.type),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                room.name,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                room.code,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Type
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getRoomTypeColor(room.type).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _getRoomTypeColor(room.type).withOpacity(0.25)),
                        ),
                        child: Text(
                          room.type,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _getRoomTypeColor(room.type),
                          ),
                        ),
                      ),
                    ),

                    // Building & Floor
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            room.building,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            room.floor,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Capacity & Facilities
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people_alt_outlined, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                '${room.capacity} seats',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          if (room.facilities.isNotEmpty) ...[
                            Text(
                              room.facilities.take(2).join(', ') + (room.facilities.length > 2 ? ' +${room.facilities.length - 2}' : ''),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Live Status
                    DataCell(
                      _buildRoomStatusBadge(room, isDark),
                    ),

                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: const Color(0xFF64748B),
                            tooltip: 'Edit Room',
                            onPressed: () => _showEditDialog(context, room, state, notifier),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: const Color(0xFFEF4444),
                            tooltip: 'Archive Room',
                            onPressed: () => _showArchiveDialog(context, room, notifier),
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
),

        // Pagination Bar
        _buildPaginationBar(context, state, notifier, isDark),
      ],
    );
  }

  // =========================================================================
  // 4. FLOOR MAP VIEW MODE
  // =========================================================================
  Widget _buildFloorLayoutView(BuildContext context, ClassState state, ClassNotifier notifier, bool isDark) {
    // Group rooms by building and floor
    final Map<String, Map<String, List<AcademicRoomModel>>> grouped = {};

    for (var r in state.rooms) {
      grouped.putIfAbsent(r.building, () => {});
      grouped[r.building]!.putIfAbsent(r.floor, () => []);
      grouped[r.building]![r.floor]!.add(r);
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: grouped.entries.map((bEntry) {
        final buildingName = bEntry.key;
        final floorsMap = bEntry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(
                    bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.apartment_rounded, color: Color(0xFF4F46E5), size: 20),
                    const SizedBox(width: 10),
                    Text(
                      buildingName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: floorsMap.entries.map((fEntry) {
                    final floorName = fEntry.key;
                    final roomsOnFloor = fEntry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4F46E5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                floorName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${roomsOnFloor.length} rooms)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: roomsOnFloor.map((room) {
                            final isSelected = state.selectedRoom?.id == room.id;

                            return InkWell(
                              onTap: () => notifier.selectRoom(room),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 220,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF4F46E5).withOpacity(0.1)
                                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF4F46E5)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          room.code,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF4F46E5),
                                          ),
                                        ),
                                        _buildSmallStatusDot(room),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      room.name,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${room.type} • ${room.capacity} seats',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // =========================================================================
  // 5. RIGHT SIDEBAR DETAIL PANEL
  // =========================================================================
  Widget _buildRoomSidebarDetail(BuildContext context, ClassState state, ClassNotifier notifier, bool isDark) {
    final room = state.selectedRoom!;
    final detail = state.selectedRoomDetail ?? room;
    final typeColor = _getRoomTypeColor(room.type);
    final typeIcon = _getRoomTypeIcon(room.type);

    return Column(
      children: [
        // Sidebar Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: typeColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      room.type,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: typeColor,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        tooltip: 'Edit Room',
                        onPressed: () => _showEditDialog(context, room, state, notifier),
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        splashRadius: 16,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 17),
                        tooltip: 'Archive Room',
                        onPressed: () => _showArchiveDialog(context, room, notifier),
                        color: const Color(0xFFEF4444),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        splashRadius: 16,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        tooltip: 'Close details',
                        onPressed: () => notifier.clearSelectedRoom(),
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        splashRadius: 16,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Room Hero Profile
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: typeColor.withOpacity(0.3)),
                    ),
                    child: Icon(typeIcon, color: typeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Code: ${room.code} • ${room.building} (${room.floor})',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildRoomStatusBadge(room, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Scrollable Room Details
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Metric Stat Highlights Grid (2x2)
                _buildMetricsGrid(detail, isDark),
                const SizedBox(height: 20),

                // 2. Assigned Sections (Class Utilization)
                _buildAssignedSectionsSection(detail, isDark),
                const SizedBox(height: 20),

                // 3. Equipped Facilities & Amenities
                _buildFacilitiesSection(detail, isDark),
                const SizedBox(height: 20),

                // 4. Physical Space Specifications
                _buildSpecificationsCard(detail, isDark),
                const SizedBox(height: 20),

                // 5. Description & Operational Notes
                if (detail.description != null && detail.description!.trim().isNotEmpty) ...[
                  _buildDescriptionCard(detail, isDark),
                  const SizedBox(height: 20),
                ],

                // 6. Audit Information
                _buildAuditInfo(detail, isDark),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // Bottom Action Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showEditDialog(context, room, state, notifier),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Edit Room Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(AcademicRoomModel detail, bool isDark) {
    return Column(
      children: [
        // Row 1: Total Capacity and Assigned Sections (Same Height)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Total Capacity',
                  value: '${detail.capacity} Seats',
                  icon: Icons.event_seat_rounded,
                  color: const Color(0xFF4F46E5),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  title: 'Assigned Sections',
                  value: '${detail.assignedSections.length} Sections',
                  icon: Icons.class_rounded,
                  color: const Color(0xFF8B5CF6),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Row 2: Location / Floor and Active Students (Same Height)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Location / Floor',
                  value: detail.floor,
                  subtitle: detail.building,
                  icon: Icons.apartment_rounded,
                  color: const Color(0xFF06B6D4),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  title: 'Active Students',
                  value: '${detail.totalStudentsSeated} Enrolled',
                  subtitle: '${detail.capacityUtilization.toStringAsFixed(0)}% Seating Utilized',
                  icon: Icons.school_rounded,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignedSectionsSection(AcademicRoomModel detail, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ASSIGNED SECTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${detail.assignedSections.length} Batches',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (detail.assignedSections.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(Icons.meeting_room_outlined, size: 28, color: isDark ? Colors.white38 : Colors.grey),
                const SizedBox(height: 6),
                Text(
                  'No sections currently assigned to this room.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'Assign this room to batches in the Sections tab.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: detail.assignedSections.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final sec = detail.assignedSections[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${sec.className ?? 'Class'} - Section ${sec.name}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            sec.status.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            sec.classTeacher != null ? sec.classTeacher!.fullName : 'No Class Teacher',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.people_alt_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          '${sec.studentsCount} / ${sec.capacity} Enrolled Students',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
    );
  }

  Widget _buildFacilitiesSection(AcademicRoomModel detail, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EQUIPPED FACILITIES & AMENITIES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        if (detail.facilities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Text(
              'No specialized facilities recorded.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: detail.facilities.map((fac) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getFacilityIcon(fac), size: 14, color: const Color(0xFF4F46E5)),
                    const SizedBox(width: 6),
                    Text(
                      fac,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSpecificationsCard(AcademicRoomModel detail, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ROOM SPECIFICATIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildSpecRow('Room Category', detail.type, isDark),
          _buildSpecRow('Building Block', detail.building, isDark),
          _buildSpecRow('Floor Level', detail.floor, isDark),
          _buildSpecRow('Room Identifier', detail.code, isDark),
          _buildSpecRow('Seating Capacity', '${detail.capacity} Seats', isDark),
          _buildSpecRow('Current Status', detail.status.replaceAll('_', ' '), isDark, isLast: true),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String val, bool isDark, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Text(
            val,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(AcademicRoomModel detail, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF4F46E5)),
              const SizedBox(width: 6),
              Text(
                'OPERATIONAL NOTES & DESCRIPTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            detail.description ?? '',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditInfo(AcademicRoomModel detail, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            detail.createdAt != null
                ? 'Created: ${detail.createdAt!.day}/${detail.createdAt!.month}/${detail.createdAt!.year}'
                : '',
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
          Text(
            detail.updatedAt != null
                ? 'Updated: ${detail.updatedAt!.day}/${detail.updatedAt!.month}/${detail.updatedAt!.year}'
                : '',
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFacilityIcon(String fac) {
    final lower = fac.toLowerCase();
    if (lower.contains('projector') || lower.contains('screen')) return Icons.videocam_rounded;
    if (lower.contains('smart') || lower.contains('board') || lower.contains('whiteboard')) return Icons.developer_board_rounded;
    if (lower.contains('ac') || lower.contains('air') || lower.contains('conditioning')) return Icons.ac_unit_rounded;
    if (lower.contains('computer') || lower.contains('pc') || lower.contains('laptop')) return Icons.computer_rounded;
    if (lower.contains('audio') || lower.contains('speaker') || lower.contains('mic') || lower.contains('sound')) return Icons.volume_up_rounded;
    if (lower.contains('microscope') || lower.contains('lab') || lower.contains('specimen') || lower.contains('fume')) return Icons.biotech_rounded;
    if (lower.contains('wifi') || lower.contains('internet') || lower.contains('lan')) return Icons.wifi_rounded;
    if (lower.contains('pottery') || lower.contains('easel') || lower.contains('art')) return Icons.palette_rounded;
    return Icons.check_circle_outline_rounded;
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================

  Widget _buildRoomStatusBadge(AcademicRoomModel room, bool isDark) {
    final status = room.status.trim();
    final upper = status.toUpperCase().replaceAll('_', ' ');

    Color bg;
    Color border;
    Color textCol;
    IconData icon;

    if (upper.contains('MAINT') || upper.contains('REPAIR') || upper.contains('OUT OF SERVICE')) {
      bg = isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
      border = const Color(0xFFF87171);
      textCol = const Color(0xFFDC2626);
      icon = Icons.build_rounded;
    } else if (upper.contains('IN USE') || upper.contains('OCCUPIED')) {
      bg = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
      border = const Color(0xFFFCD34D);
      textCol = const Color(0xFFD97706);
      icon = Icons.groups_rounded;
    } else if (upper.contains('RESERV')) {
      bg = isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF);
      border = const Color(0xFFA5B4FC);
      textCol = const Color(0xFF4F46E5);
      icon = Icons.bookmark_rounded;
    } else if (upper.contains('AVAIL') || upper.contains('ACTIVE') || upper.contains('READY') || upper.contains('IN SERVICE')) {
      bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
      border = const Color(0xFF6EE7B7);
      textCol = const Color(0xFF059669);
      icon = Icons.check_circle_rounded;
    } else {
      bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      border = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
      textCol = isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
      icon = Icons.info_outline_rounded;
    }

    final lookupHelper = AcademicLookupHelper.instance;
    final cachedStatuses = lookupHelper.getCachedLookup('ROOM_STATUS');
    final match = cachedStatuses.where((s) => s.code.toUpperCase() == status.toUpperCase() || s.label.toUpperCase() == status.toUpperCase()).firstOrNull;
    final displayLabel = match?.label ?? (status.isEmpty ? 'AVAILABLE' : status.replaceAll('_', ' '));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textCol),
          const SizedBox(width: 4),
          Text(
            displayLabel.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textCol),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStatusDot(AcademicRoomModel room) {
    Color dotColor;
    final upper = room.status.toUpperCase().replaceAll('_', ' ');
    if (upper.contains('MAINT') || upper.contains('REPAIR') || upper.contains('OUT OF SERVICE')) {
      dotColor = const Color(0xFFDC2626);
    } else if (upper.contains('IN USE') || upper.contains('OCCUPIED')) {
      dotColor = const Color(0xFFD97706);
    } else if (upper.contains('RESERV')) {
      dotColor = const Color(0xFF4F46E5);
    } else if (upper.contains('AVAIL') || upper.contains('ACTIVE') || upper.contains('READY')) {
      dotColor = const Color(0xFF059669);
    } else {
      dotColor = const Color(0xFF64748B);
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildPaginationBar(BuildContext context, ClassState state, ClassNotifier notifier, bool isDark) {
    final startItem = state.totalCount == 0 ? 0 : (state.page - 1) * state.pageSize + 1;
    final endItem = (state.page * state.pageSize) > state.totalCount ? state.totalCount : (state.page * state.pageSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;

          final recordsInfo = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Showing $startItem - $endItem of ${state.totalCount} rooms',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Per page:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: [10, 25, 50, 100].contains(state.pageSize) ? state.pageSize : 10,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        items: const [
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 25, child: Text('25')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                          DropdownMenuItem(value: 100, child: Text('100')),
                        ],
                        onChanged: (v) {
                          if (v != null) notifier.setPageSize(v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );

          final pageNav = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: state.page > 1 ? () => notifier.setPage(1) : null,
                icon: const Icon(Icons.first_page, size: 18),
                tooltip: 'First Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
              ),
              IconButton(
                onPressed: state.page > 1 ? () => notifier.setPage(state.page - 1) : null,
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: 'Previous Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Page ${state.page} of ${state.totalPages > 0 ? state.totalPages : 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                onPressed: state.page < state.totalPages ? () => notifier.setPage(state.page + 1) : null,
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: 'Next Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
              ),
              IconButton(
                onPressed: state.page < state.totalPages ? () => notifier.setPage(state.totalPages) : null,
                icon: const Icon(Icons.last_page, size: 18),
                tooltip: 'Last Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                recordsInfo,
                const SizedBox(height: 8),
                pageNav,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              recordsInfo,
              pageNav,
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, ClassNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.meeting_room_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 14),
            Text(
              'No rooms or facilities found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search criteria or add new rooms.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, AcademicRoomModel room, ClassState state, ClassNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => CreateEditRoomDialog(
        existingRoom: room,
        availableBuildings: state.availableBuildings,
        availableFloors: state.availableFloors,
        onSave: (payload) => notifier.updateRoom(
          room.id,
          name: payload['name'],
          code: payload['code'],
          type: payload['type'],
          building: payload['building'],
          floor: payload['floor'],
          capacity: payload['capacity'],
          facilities: List<String>.from(payload['facilities'] ?? []),
          status: payload['status'],
          description: payload['description'],
        ),
      ),
    );
  }

  void _showArchiveDialog(BuildContext context, AcademicRoomModel room, ClassNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => ArchiveConfirmationDialog(
        title: 'Archive Room',
        itemName: '${room.name} (${room.code})',
        onConfirm: (force) => notifier.archiveRoom(room.id, force: force),
      ),
    );
  }

  Color _getRoomTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'laboratory':
        return const Color(0xFF06B6D4); // Cyan
      case 'computer lab':
        return const Color(0xFF8B5CF6); // Purple
      case 'auditorium':
        return const Color(0xFFF59E0B); // Amber
      case 'library':
        return const Color(0xFF10B981); // Emerald
      case 'staff room':
        return const Color(0xFF6366F1); // Indigo
      case 'activity room':
        return const Color(0xFFEC4899); // Pink
      default:
        return const Color(0xFF4F46E5); // Blue/Indigo
    }
  }

  IconData _getRoomTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'laboratory':
        return Icons.science_rounded;
      case 'computer lab':
        return Icons.computer_rounded;
      case 'auditorium':
        return Icons.theater_comedy_rounded;
      case 'library':
        return Icons.local_library_rounded;
      case 'staff room':
        return Icons.coffee_rounded;
      case 'activity room':
        return Icons.palette_rounded;
      default:
        return Icons.meeting_room_rounded;
    }
  }
}
