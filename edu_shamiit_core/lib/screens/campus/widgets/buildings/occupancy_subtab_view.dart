import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/campus_models.dart';
import '../../providers/campus_provider.dart';
import '../dialogs/assign_class_section_dialog.dart';

class OccupancySubtabView extends ConsumerStatefulWidget {
  final BuildingModel building;
  final List<BuildingOccupancyModel> occupancyList;
  final List<RoomModel> rooms;
  final bool isLoading;
  final VoidCallback onAddOccupancy;
  final ValueChanged<BuildingOccupancyModel> onEditOccupancy;
  final ValueChanged<BuildingOccupancyModel> onDeleteOccupancy;

  const OccupancySubtabView({
    super.key,
    required this.building,
    required this.occupancyList,
    required this.rooms,
    this.isLoading = false,
    required this.onAddOccupancy,
    required this.onEditOccupancy,
    required this.onDeleteOccupancy,
  });

  @override
  ConsumerState<OccupancySubtabView> createState() => _OccupancySubtabViewState();
}

class _OccupancySubtabViewState extends ConsumerState<OccupancySubtabView> {
  String _searchQuery = '';
  String _selectedStatusFilter = 'ALL'; // ALL, OCCUPIED_NOW, AVAILABLE_NOW, SCHEDULED_TODAY, MAINTENANCE
  String? _selectedFloorId;
  String? _selectedRoomType;

  late DateTime _selectedDate;
  BuildingOccupancyModel? _selectedRoom;

  @override
  void initState() {
    super.initState();
    try {
      final campusState = ref.read(campusProvider);
      if (campusState.selectedOccupancyDate != null) {
        _selectedDate = DateTime.parse(campusState.selectedOccupancyDate!);
      } else {
        _selectedDate = DateTime.now();
      }
    } catch (_) {
      _selectedDate = DateTime.now();
    }
  }

  void _onDateChanged(DateTime newDate) {
    setState(() => _selectedDate = newDate);
    final dateStr = DateFormat('yyyy-MM-dd').format(newDate);
    ref.read(campusProvider.notifier).setOccupancyDate(dateStr);
  }

  void _openAssignDialog([BuildingOccupancyModel? preselected]) {
    widget.onAddOccupancy();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AssignClassSectionDialog(
        building: widget.building,
        rooms: widget.rooms,
        preselectedRoom: preselected,
        initialDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
        onSaved: () {
          final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
          ref.read(campusProvider.notifier).loadBuildingOccupancy(widget.building.id, targetDate: dateStr);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final campusState = ref.watch(campusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter occupancy list
    var filtered = widget.occupancyList.where((o) {
      if (_selectedStatusFilter != 'ALL') {
        if (_selectedStatusFilter == 'OCCUPIED_NOW' && o.bookingStatus != 'OCCUPIED_NOW') return false;
        if (_selectedStatusFilter == 'AVAILABLE_NOW' && o.bookingStatus != 'AVAILABLE_NOW') return false;
        if (_selectedStatusFilter == 'SCHEDULED_TODAY' && o.todaySessionsCount == 0) return false;
        if (_selectedStatusFilter == 'MAINTENANCE' && o.bookingStatus != 'MAINTENANCE') return false;
      }
      if (_selectedFloorId != null && _selectedFloorId!.isNotEmpty && _selectedFloorId != 'all') {
        if (o.floorId != _selectedFloorId) return false;
      }
      if (_selectedRoomType != null && _selectedRoomType!.isNotEmpty && _selectedRoomType != 'all') {
        if (o.roomType.toLowerCase() != _selectedRoomType!.toLowerCase()) return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (o.roomName ?? '').toLowerCase();
        final code = (o.roomCode ?? '').toLowerCase();
        final num = o.roomNumber.toLowerCase();
        final floor = (o.floorName ?? '').toLowerCase();
        final title = o.activeTitle.toLowerCase();
        final teacher = o.activeTeacher.toLowerCase();
        final type = o.roomType.toLowerCase();
        if (!name.contains(q) && !code.contains(q) && !num.contains(q) && !floor.contains(q) && !title.contains(q) && !teacher.contains(q) && !type.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Metrics calculation from provider or calculated live
    final metrics = campusState.occupancyMetrics;
    final totalCap = (metrics['total_capacity'] as num?)?.toInt() ?? widget.building.totalCapacity;
    final occupiedCap = (metrics['current_occupancy'] as num?)?.toInt() ?? 0;
    final availableCap = (metrics['available_capacity'] as num?)?.toInt() ?? math.max(0, totalCap - occupiedCap);
    final totalRooms = (metrics['total_rooms'] as num?)?.toInt() ?? widget.occupancyList.length;
    final occupiedRooms = (metrics['occupied_rooms'] as num?)?.toInt() ?? widget.occupancyList.where((r) => r.bookingStatus == 'OCCUPIED_NOW').length;
    final availableRooms = (metrics['available_rooms'] as num?)?.toInt() ?? widget.occupancyList.where((r) => r.bookingStatus == 'AVAILABLE_NOW').length;
    final todaySessions = (metrics['today_total_sessions'] as num?)?.toInt() ?? widget.occupancyList.fold<int>(0, (s, r) => s + r.todaySessionsCount);
    final occRate = (metrics['occupancy_rate'] as num?)?.toDouble() ?? (totalCap > 0 ? (occupiedCap / totalCap * 100) : 0.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1100;
        final showInspector = _selectedRoom != null && !isCompact;
        final hasBoundedHeight = constraints.hasBoundedHeight && constraints.maxHeight.isFinite;

        Widget tableWidget = _buildRoomsTable(filtered, isDark, hasBoundedHeight: hasBoundedHeight);

        Widget contentBody;
        if (widget.isLoading) {
          contentBody = const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          );
        } else if (showInspector) {
          contentBody = Row(
            crossAxisAlignment: hasBoundedHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
            children: [
              // Left / Center Table View
              Expanded(
                child: tableWidget,
              ),

              // Right Room Inspection Drawer Panel (Elevated from Rooms Tab)
              const SizedBox(width: 12),
              SizedBox(
                width: 360,
                child: _buildRoomInspectorPanel(_selectedRoom!, isDark, hasBoundedHeight: hasBoundedHeight),
              ),
            ],
          );
        } else if (_selectedRoom != null && isCompact) {
          contentBody = SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                tableWidget,
                const SizedBox(height: 12),
                _buildRoomInspectorPanel(_selectedRoom!, isDark, hasBoundedHeight: false),
              ],
            ),
          );
        } else {
          contentBody = tableWidget;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // 1. Dynamic Space Booking Header & Date Selector Row
            _buildHeaderRow(context, isDark),
            const SizedBox(height: 10),

            // 2. Real-Time Dynamic Space Booking KPI Cards
            _buildKpiCardsRow(
              totalCap: totalCap,
              totalRooms: totalRooms,
              occupiedCap: occupiedCap,
              occupiedRooms: occupiedRooms,
              availableCap: availableCap,
              availableRooms: availableRooms,
              todaySessions: todaySessions,
              occRate: occRate,
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            // 3. Smart Search & Status Filters Bar
            _buildFilterToolbar(isDark),
            const SizedBox(height: 10),

            // 4. Main Body: Left Table + Right Inspection Drawer
            if (hasBoundedHeight)
              Expanded(child: contentBody)
            else
              contentBody,
          ],
        );
      },
    );
  }

  // =========================================================================
  // 1. HEADER ROW & DATE SELECTOR
  // =========================================================================
  Widget _buildHeaderRow(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.meeting_room_rounded, color: Color(0xFF4F46E5), size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Space Occupancy & Class Allocations',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.building.code,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Real-time space occupancy driven by academic timetable & space booking schedule',
                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),

          // Date Switcher & Assign Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date Controls
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dateQuickChip('Today', DateTime.now(), isDark),
                    _dateQuickChip('Tomorrow', DateTime.now().add(const Duration(days: 1)), isDark),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) _onDateChanged(picked);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd MMM').format(_selectedDate),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // "+ Assign Class / Section" Primary Action
              ElevatedButton.icon(
                onPressed: () => _openAssignDialog(),
                icon: const Icon(Icons.add_task_rounded, size: 14, color: Colors.white),
                label: const Text('Assign Class / Section', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateQuickChip(String label, DateTime dt, bool isDark) {
    final isSelected = DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(dt);
    return InkWell(
      onTap: () => _onDateChanged(dt),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 2. DYNAMIC SPACE BOOKING KPI ROW
  // =========================================================================
  Widget _buildKpiCardsRow({
    required int totalCap,
    required int totalRooms,
    required int occupiedCap,
    required int occupiedRooms,
    required int availableCap,
    required int availableRooms,
    required int todaySessions,
    required double occRate,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              title: 'Building Capacity',
              value: '$totalCap Seats',
              subtitle: '$totalRooms Total Rooms',
              icon: Icons.domain_rounded,
              color: const Color(0xFF3B82F6),
              isDark: isDark,
            ),
          ),
          _divider(isDark),
          Expanded(
            child: _buildMetricTile(
              title: 'Occupied Right Now',
              value: '$occupiedRooms Rooms',
              subtitle: '$occupiedCap Students Active',
              icon: Icons.groups_rounded,
              color: const Color(0xFFF59E0B),
              isDark: isDark,
              isPulsing: occupiedRooms > 0,
            ),
          ),
          _divider(isDark),
          Expanded(
            child: _buildMetricTile(
              title: 'Available Right Now',
              value: '$availableRooms Rooms',
              subtitle: '$availableCap Seats Free',
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),
          ),
          _divider(isDark),
          Expanded(
            child: _buildMetricTile(
              title: 'Sessions Today',
              value: '$todaySessions Sessions',
              subtitle: 'Scheduled Timetable',
              icon: Icons.event_note_rounded,
              color: const Color(0xFF8B5CF6),
              isDark: isDark,
            ),
          ),
          _divider(isDark),
          Expanded(
            child: _buildMetricTile(
              title: 'Live Utilization',
              value: '${occRate.toStringAsFixed(1)}%',
              subtitle: 'Active Capacity Gauge',
              icon: Icons.pie_chart_outline_rounded,
              color: const Color(0xFF06B6D4),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 6), color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    bool isPulsing = false,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isPulsing) ...[
                    const SizedBox(width: 4),
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                  ],
                ],
              ),
              Text(
                title,
                style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 3. FILTER TOOLBAR
  // =========================================================================
  Widget _buildFilterToolbar(bool isDark) {
    final floors = widget.rooms.map((r) => r.floorName).whereType<String>().toSet().toList()..sort();
    final roomTypes = widget.rooms.map((r) => r.roomType).toSet().toList()..sort();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          // Search Box
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: SizedBox(
              height: 32,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search room, class, incharge...',
                  hintStyle: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 15),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
          ),

          // Status Filter Tabs
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _filterTabChip('All Spaces', 'ALL', isDark),
              _filterTabChip('Occupied Now', 'OCCUPIED_NOW', isDark),
              _filterTabChip('Available Now', 'AVAILABLE_NOW', isDark),
              _filterTabChip('Scheduled Today', 'SCHEDULED_TODAY', isDark),
              _filterTabChip('Maintenance', 'MAINTENANCE', isDark),
            ],
          ),

          // Floor and Room Type Dropdowns
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Floor Dropdown
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: AppSearchableDropdown<String>.fromMenuItems(
                    value: _selectedFloorId,
                    hint: Text('All Floors', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Floors')),
                      ...floors.map((f) => DropdownMenuItem(value: f, child: Text(f))),
                    ],
                    onChanged: (v) => setState(() => _selectedFloorId = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Room Type Dropdown
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: AppSearchableDropdown<String>.fromMenuItems(
                    value: _selectedRoomType,
                    hint: Text('All Types', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Types')),
                      ...roomTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                    ],
                    onChanged: (v) => setState(() => _selectedRoomType = v),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterTabChip(String label, String code, bool isDark) {
    final isSelected = _selectedStatusFilter == code;
    return InkWell(
      onTap: () => setState(() => _selectedStatusFilter = code),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 4. MAIN ROOMS DATA TABLE VIEW
  // =========================================================================
  Widget _buildRoomsTable(List<BuildingOccupancyModel> items, bool isDark, {bool hasBoundedHeight = false}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.meeting_room_outlined, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              'No space allocations found',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            Text(
              'Click "+ Assign Class / Section" to allocate timetable sessions to spaces.',
              style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    Widget tableWidget = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              columnSpacing: 18,
              horizontalMargin: 16,
              headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('ROOM / SPACE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('CAPACITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('LIVE STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('CURRENT / UPCOMING SESSION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('TODAY\'S SCHEDULE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
              ],
              rows: items.map((room) {
                final isSelected = _selectedRoom?.roomId == room.roomId;
                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) => setState(() => _selectedRoom = isSelected ? null : room),
                  cells: [
                    // Room Number & Name
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.meeting_room_outlined, size: 15, color: Color(0xFF4F46E5)),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                room.roomName ?? 'Room ${room.roomNumber}',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                              Text(
                                '${room.roomNumber} • ${room.floorName ?? "Ground Floor"}',
                                style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Type
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getRoomTypeColor(room.roomType).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: _getRoomTypeColor(room.roomType).withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          room.roomType,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _getRoomTypeColor(room.roomType)),
                        ),
                      ),
                    ),

                    // Capacity & Area
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${room.maxCapacity} seats',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                          Text(
                            '${room.area > 0 ? room.area.toStringAsFixed(0) : "500"} ${room.areaUnit}',
                            style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),

                    // Live Status Badge
                    DataCell(_buildStatusBadge(room)),

                    // Current / Upcoming Session
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            room.activeTitle.isNotEmpty ? room.activeTitle : 'No session scheduled',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: room.activeTitle.isNotEmpty ? (isDark ? Colors.white : const Color(0xFF0F172A)) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            ),
                          ),
                          if (room.activeTeacher.isNotEmpty)
                            Text(
                              '${room.activeTeacher}${room.activeTimeRange.isNotEmpty ? " • ${room.activeTimeRange}" : ""}',
                              style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                        ],
                      ),
                    ),

                    // Today's Visual Schedule Mini-Timeline Bar
                    DataCell(_buildMiniScheduleTimeline(room, isDark)),

                    // Action Buttons
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 16),
                            tooltip: 'Assign Class / Section',
                            color: const Color(0xFF4F46E5),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            onPressed: () => _openAssignDialog(room),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(isSelected ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16),
                            tooltip: isSelected ? 'Close Inspection' : 'Inspect Specifications & Schedule',
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            onPressed: () => setState(() => _selectedRoom = isSelected ? null : room),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          );

    if (hasBoundedHeight) {
      tableWidget = SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: tableWidget,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: tableWidget,
      ),
    );
  }

  Widget _buildStatusBadge(BuildingOccupancyModel room) {
    Color bg;
    Color fg;
    String label;

    if (room.bookingStatus == 'OCCUPIED_NOW') {
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      fg = const Color(0xFFD97706);
      label = 'Occupied Now';
    } else if (room.bookingStatus == 'AVAILABLE_NOW') {
      bg = const Color(0xFF10B981).withValues(alpha: 0.12);
      fg = const Color(0xFF059669);
      label = room.todaySessionsCount > 0 ? 'Available Now' : 'Available All Day';
    } else if (room.bookingStatus == 'MAINTENANCE') {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      fg = const Color(0xFFDC2626);
      label = 'Maintenance';
    } else {
      bg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
      fg = const Color(0xFF2563EB);
      label = '${room.todaySessionsCount} Sessions';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }

  Widget _buildMiniScheduleTimeline(BuildingOccupancyModel room, bool isDark) {
    final count = room.todaySessionsCount;
    return Container(
      width: 130,
      height: 18,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Stack(
        children: [
          if (count == 0)
            const Center(
              child: Text('Free All Day', style: TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
            )
          else ...[
            // Draw mini segment blocks for bookings
            Positioned(
              left: 10,
              right: 10,
              top: 3,
              bottom: 3,
              child: Row(
                children: List.generate(math.min(count, 5), (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: index == 0 && room.bookingStatus == 'OCCUPIED_NOW'
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF4F46E5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // 5. RIGHT ROOM INSPECTOR PANEL (ELEVATED FROM ROOMS TAB)
  // =========================================================================
  Widget _buildRoomInspectorPanel(BuildingOccupancyModel room, bool isDark, {bool hasBoundedHeight = false}) {
    final typeColor = _getRoomTypeColor(room.roomType);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Inspector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.meeting_room_rounded, color: typeColor, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.roomName ?? 'Room ${room.roomNumber}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        Text(
                          '${room.roomNumber} • ${room.floorName ?? "Ground Floor"}',
                          style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => setState(() => _selectedRoom = null),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: 'Close Drawer',
                ),
              ],
            ),
          ),

          // Specs & Schedule
          _buildInspectorSpecs(room, isDark, hasBoundedHeight),

          // Bottom Action: "+ Assign Another Session"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openAssignDialog(room),
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: const Text('Assign Session to this Room', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorSpecs(BuildingOccupancyModel room, bool isDark, bool hasBoundedHeight) {
    final specsContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Metrics Grid (2x2)
        Row(
          children: [
            Expanded(child: _buildMetricTileCompact('Seating Capacity', '${room.maxCapacity} seats', Icons.event_seat_rounded, const Color(0xFF4F46E5), isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTileCompact('Today Sessions', '${room.todaySessionsCount} booked', Icons.schedule_rounded, const Color(0xFF10B981), isDark)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildMetricTileCompact('Floor Area', '${room.area > 0 ? room.area.toStringAsFixed(0) : "500"} ${room.areaUnit}', Icons.square_foot_rounded, const Color(0xFFF59E0B), isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTileCompact('Room Type', room.roomType, Icons.category_rounded, const Color(0xFF8B5CF6), isDark)),
          ],
        ),
        const SizedBox(height: 14),

        // 2. Physical Specifications
        Text('PHYSICAL SPECIFICATIONS', style: _headerStyle(isDark)),
        const SizedBox(height: 6),
        _specRow('Doors & Windows', '${room.numDoors} Doors, ${room.numWindows} Windows', isDark),
        _specRow('Accessibility', room.isDifferentlyAbledAccessible ? 'Differently-Abled Friendly' : 'Standard Stairs Only', isDark),
        _specRow('Lift Proximity', room.liftProximity ?? 'Direct Access', isDark),
        _specRow('Emergency Exit', room.emergencyExitProximity ?? 'Nearby Corridor', isDark),
        const SizedBox(height: 14),

        // 3. Equipped Facilities & Amenities
        Text('EQUIPPED FACILITIES', style: _headerStyle(isDark)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: room.facilities.map((f) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text(f, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // 4. Today's Full Chronological Bookings Schedule
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('TODAY\'S TIMETABLE SCHEDULE', style: _headerStyle(isDark)),
            Text('${room.todaySessionsCount} Sessions', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
          ],
        ),
        const SizedBox(height: 8),

        if (room.todayBookings.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No sessions scheduled for this date.\nRoom is fully available.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
              ),
            ),
          )
        else
          Column(
            children: room.todayBookings.map((b) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
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
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 4),
                            Text(
                              '${b['start_time']} - ${b['end_time']}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            b['status']?.toString() ?? 'Confirmed',
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b['title']?.toString() ?? 'Academic Session',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    if (b['organizer_name'] != null)
                      Text(
                        'In-Charge: ${b['organizer_name']} • ${b['attendee_count'] ?? 35} students',
                        style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );

    if (hasBoundedHeight) {
      return Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: specsContent,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(14),
      child: specsContent,
    );
  }

  Widget _buildMetricTileCompact(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                Text(title, style: TextStyle(fontSize: 9.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          Text(value, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  TextStyle _headerStyle(bool isDark) {
    return TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));
  }

  Color _getRoomTypeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('lab')) return const Color(0xFF10B981);
    if (t.contains('computer')) return const Color(0xFF3B82F6);
    if (t.contains('hall') || t.contains('auditorium')) return const Color(0xFF8B5CF6);
    if (t.contains('office') || t.contains('staff')) return const Color(0xFFF59E0B);
    return const Color(0xFF4F46E5);
  }
}
