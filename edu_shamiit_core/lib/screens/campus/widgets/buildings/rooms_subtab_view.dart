import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import '../../services/campus_lookup_helper.dart';
import '../common/campus_pagination_bar.dart';

class RoomsSubtabView extends StatefulWidget {
  final BuildingModel building;
  final List<RoomModel> rooms;
  final List<BuildingFloorModel> floors;
  final bool isLoading;
  final int viewMode; // 0: Table, 1: Grid
  final ValueChanged<int> onViewModeChanged;
  final String searchQuery;
  final ValueChanged<String> onSearch;
  final String? filterFloorId;
  final ValueChanged<String?> onFilterFloor;
  final String? filterRoomType;
  final ValueChanged<String?> onFilterRoomType;
  final String? filterStatus;
  final ValueChanged<String?> onFilterStatus;
  final VoidCallback onClearFilters;
  final VoidCallback onAddRoom;
  final VoidCallback onBulkCreate;
  final ValueChanged<RoomModel> onInspectRoom;
  final ValueChanged<RoomModel> onEditRoom;
  final ValueChanged<RoomModel> onManageEquipment;
  final ValueChanged<RoomModel> onDeleteRoom;

  // Pagination & Sorting props
  final int totalRoomsCount;
  final int currentPage;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final String? sortBy;
  final String? sortOrder;
  final void Function(String columnKey, bool ascending)? onSortChanged;

  const RoomsSubtabView({
    super.key,
    required this.building,
    required this.rooms,
    required this.floors,
    this.isLoading = false,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.searchQuery,
    required this.onSearch,
    this.filterFloorId,
    required this.onFilterFloor,
    this.filterRoomType,
    required this.onFilterRoomType,
    this.filterStatus,
    required this.onFilterStatus,
    required this.onClearFilters,
    required this.onAddRoom,
    required this.onBulkCreate,
    required this.onInspectRoom,
    required this.onEditRoom,
    required this.onManageEquipment,
    required this.onDeleteRoom,
    this.totalRoomsCount = 0,
    this.currentPage = 1,
    this.pageSize = 10,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.sortBy,
    this.sortOrder,
    this.onSortChanged,
  });

  @override
  State<RoomsSubtabView> createState() => _RoomsSubtabViewState();
}

class _RoomsSubtabViewState extends State<RoomsSubtabView> {
  int? _sortColIndex = 0;
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _syncSortState();
  }

  @override
  void didUpdateWidget(covariant RoomsSubtabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sortBy != widget.sortBy || oldWidget.sortOrder != widget.sortOrder) {
      _syncSortState();
    }
  }

  void _syncSortState() {
    _sortAsc = (widget.sortOrder ?? 'asc').toLowerCase() == 'asc';
    switch (widget.sortBy) {
      case 'room_number':
        _sortColIndex = 0;
        break;
      case 'name':
        _sortColIndex = 1;
        break;
      case 'room_type':
        _sortColIndex = 2;
        break;
      case 'floor_name':
        _sortColIndex = 3;
        break;
      case 'max_capacity':
        _sortColIndex = 4;
        break;
      case 'assignment_status':
        _sortColIndex = 6;
        break;
      case 'operational_status':
        _sortColIndex = 7;
        break;
      default:
        _sortColIndex = 0;
    }
  }

  void _handleSort(int colIndex, String colKey, bool asc) {
    setState(() {
      _sortColIndex = colIndex;
      _sortAsc = asc;
    });
    widget.onSortChanged?.call(colKey, asc);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    final roomTypes = CampusLookupHelper.instance.getImmediateLabels('ROOM_TYPE');
    final roomStatuses = CampusLookupHelper.instance.getImmediateLabels('ROOM_STATUS');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Compact Controls Row: Search, Dropdowns, View Switcher & Action Buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              // Search Input
              SizedBox(
                width: 180,
                height: 32,
                child: TextField(
                  onChanged: widget.onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search room...',
                    hintStyle: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 15, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),

              // Floor Filter Dropdown
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: (widget.filterFloorId != null && widget.floors.any((f) => f.id == widget.filterFloorId))
                        ? widget.filterFloorId
                        : null,
                    hint: const Text('All Floors', style: TextStyle(fontSize: 11.5)),
                    isDense: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Floors', style: TextStyle(fontSize: 11.5))),
                      ...widget.floors.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, style: const TextStyle(fontSize: 11.5)))),
                    ],
                    onChanged: widget.onFilterFloor,
                  ),
                ),
              ),

              // Room Type Filter Dropdown
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: (widget.filterRoomType != null && roomTypes.contains(widget.filterRoomType))
                        ? widget.filterRoomType
                        : null,
                    hint: const Text('All Types', style: TextStyle(fontSize: 11.5)),
                    isDense: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Types', style: TextStyle(fontSize: 11.5))),
                      ...roomTypes.map((rt) => DropdownMenuItem(value: rt, child: Text(rt, style: const TextStyle(fontSize: 11.5)))),
                    ],
                    onChanged: widget.onFilterRoomType,
                  ),
                ),
              ),

              // Status Filter
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: (widget.filterStatus != null && roomStatuses.contains(widget.filterStatus))
                        ? widget.filterStatus
                        : null,
                    hint: const Text('All Statuses', style: TextStyle(fontSize: 11.5)),
                    isDense: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Statuses', style: TextStyle(fontSize: 11.5))),
                      ...roomStatuses.map((rs) => DropdownMenuItem(value: rs, child: Text(rs, style: const TextStyle(fontSize: 11.5)))),
                    ],
                    onChanged: widget.onFilterStatus,
                  ),
                ),
              ),

              // View Mode Switcher
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.table_rows_rounded, size: 17, color: widget.viewMode == 0 ? primaryColor : const Color(0xFF94A3B8)),
                    tooltip: 'Table View',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => widget.onViewModeChanged(0),
                  ),
                  IconButton(
                    icon: Icon(Icons.grid_view_rounded, size: 17, color: widget.viewMode == 1 ? primaryColor : const Color(0xFF94A3B8)),
                    tooltip: 'Grid View',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => widget.onViewModeChanged(1),
                  ),
                  IconButton(
                    icon: Icon(Icons.view_quilt_rounded, size: 17, color: widget.viewMode == 2 ? primaryColor : const Color(0xFF94A3B8)),
                    tooltip: '2D Spatial Floorplan Grid',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => widget.onViewModeChanged(2),
                  ),
                ],
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onBulkCreate,
                    icon: const Icon(Icons.playlist_add_rounded, size: 14),
                    label: const Text('Bulk Create', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: widget.onAddRoom,
                    icon: const Icon(Icons.add, size: 14, color: Colors.white),
                    label: const Text('Add Room', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Content
        if (widget.isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
        else if (widget.rooms.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.meeting_room_outlined, size: 36, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                const Text('No rooms found matching your filter criteria.', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                TextButton(onPressed: widget.onClearFilters, child: const Text('Clear All Filters')),
              ],
            ),
          )
        else if (widget.viewMode == 0)
          _buildTableView(context)
        else if (widget.viewMode == 1)
          _buildGridView(context)
        else
          _buildSpatialFloorplanView(context),

        // Pagination Bar
        const SizedBox(height: 8),
        CampusPaginationBar(
          currentPage: widget.currentPage,
          pageSize: widget.pageSize,
          totalCount: widget.totalRoomsCount > 0 ? widget.totalRoomsCount : widget.rooms.length,
          itemLabel: 'rooms',
          onPageChanged: widget.onPageChanged,
          onPageSizeChanged: widget.onPageSizeChanged,
        ),
      ],
    );
  }

  Widget _buildTableView(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            sortColumnIndex: _sortColIndex,
            sortAscending: _sortAsc,
            headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            headingRowHeight: 34,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 35,
            columnSpacing: 14,
            horizontalMargin: 12,
            columns: [
              DataColumn(
                label: const Text('Room #', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                onSort: (idx, asc) => _handleSort(idx, 'room_number', asc),
              ),
              DataColumn(
                label: const Text('Room Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                onSort: (idx, asc) => _handleSort(idx, 'name', asc),
              ),
              DataColumn(
                label: const Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                onSort: (idx, asc) => _handleSort(idx, 'room_type', asc),
              ),
              DataColumn(
                label: const Text('Floor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                onSort: (idx, asc) => _handleSort(idx, 'floor_name', asc),
              ),
              DataColumn(
                label: const Text('Capacity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                onSort: (idx, asc) => _handleSort(idx, 'max_capacity', asc),
              ),
              const DataColumn(
                label: Text('Equipment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
              ),
              DataColumn(
                label: const Text('Assignment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                onSort: (idx, asc) => _handleSort(idx, 'assignment_status', asc),
              ),
              DataColumn(
                label: const Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                onSort: (idx, asc) => _handleSort(idx, 'operational_status', asc),
              ),
              const DataColumn(
                label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
              ),
            ],
            rows: widget.rooms.map((room) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      room.roomNumber,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF2563EB)),
                    ),
                    onTap: () => widget.onInspectRoom(room),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(room.name, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: _getRoomTypeColor(room.roomType).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        room.roomType,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: _getRoomTypeColor(room.roomType),
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(room.floorName ?? 'Floor', style: const TextStyle(fontSize: 11.5))),
                  DataCell(Text('${room.currentOccupancy} / ${room.maxCapacity}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        room.equipmentSummary,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      room.assignmentStatus,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: room.assignmentStatus == 'Assigned' ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(room.operationalStatus).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        room.operationalStatus,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(room.operationalStatus),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 15),
                          color: const Color(0xFF2563EB),
                          tooltip: 'Inspect Room',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () => widget.onInspectRoom(room),
                        ),
                        IconButton(
                          icon: const Icon(Icons.build_circle_outlined, size: 15),
                          color: const Color(0xFF8B5CF6),
                          tooltip: 'Manage Equipment',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () => widget.onManageEquipment(room),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          color: const Color(0xFF64748B),
                          tooltip: 'Edit Room',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () => widget.onEditRoom(room),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 15),
                          color: const Color(0xFFEF4444),
                          tooltip: 'Delete Room',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () => widget.onDeleteRoom(room),
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
  }

  Widget _buildGridView(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 180,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: widget.rooms.length,
      itemBuilder: (context, index) {
        final room = widget.rooms[index];
        final occPct = room.maxCapacity > 0 ? (room.currentOccupancy / room.maxCapacity).clamp(0.0, 1.0) : 0.0;

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                    room.roomNumber,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: _getStatusColor(room.operationalStatus).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      room.operationalStatus,
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: _getStatusColor(room.operationalStatus)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                room.name,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${room.roomType} â€¢ ${room.floorName ?? 'Floor'}',
                style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Capacity', style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  Text('${room.currentOccupancy} / ${room.maxCapacity}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: occPct,
                  minHeight: 5,
                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    occPct > 0.9 ? const Color(0xFFEF4444) : (occPct > 0.6 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: () => widget.onInspectRoom(room),
                    child: const Text('View', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => widget.onManageEquipment(room),
                    child: const Text('Equipment', style: TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => widget.onEditRoom(room),
                    child: const Text('Edit', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpatialFloorplanView(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map_rounded, size: 18, color: primaryColor),
              const SizedBox(width: 8),
              const Text(
                '2D Spatial Floorplan Blueprint',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendItem('Available', const Color(0xFF059669)),
                  const SizedBox(width: 8),
                  _buildLegendItem('Occupied', const Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  _buildLegendItem('Maintenance', const Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  _buildLegendItem('Reserved', const Color(0xFFD97706)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              int cols = 4;
              if (constraints.maxWidth < 600) {
                cols = 2;
              } else if (constraints.maxWidth < 950) {
                cols = 3;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.rooms.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 130,
                ),
                itemBuilder: (context, index) {
                  final room = widget.rooms[index];
                  final statusColor = _getStatusColor(room.operationalStatus);

                  return InkWell(
                    onTap: () => widget.onInspectRoom(room),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: isDark ? 0.12 : 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withValues(alpha: 0.6), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  room.roomNumber,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${room.maxCapacity} Cap',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            room.name.isNotEmpty ? room.name : room.roomType,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            room.responsibleDepartment ?? room.roomType,
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  room.operationalStatus,
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: statusColor),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.build_circle_outlined, size: 14),
                                    tooltip: 'Equipment',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                    onPressed: () => widget.onManageEquipment(room),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 14),
                                    tooltip: 'Edit',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                    onPressed: () => widget.onEditRoom(room),
                                  ),
                                ],
                              ),
                            ],
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

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
      ],
    );
  }

  Color _getRoomTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'classroom':
        return const Color(0xFF2563EB);
      case 'laboratory':
        return const Color(0xFF7C3AED);
      case 'faculty office':
      case 'staff room':
        return const Color(0xFF0284C7);
      case 'auditorium':
        return const Color(0xFFD97706);
      case 'seminar hall':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF475569);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return const Color(0xFF059669);
      case 'occupied':
        return const Color(0xFF2563EB);
      case 'under maintenance':
        return const Color(0xFFDC2626);
      case 'reserved':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF64748B);
    }
  }
}
