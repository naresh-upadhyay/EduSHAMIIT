import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import '../../services/campus_lookup_helper.dart';

class RoomsSubtabView extends StatelessWidget {
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
  });

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
        // Controls Row: Search, Dropdowns, View Switcher & Action Buttons
        Container(
          padding: const EdgeInsets.all(12),
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
            alignment: WrapAlignment.spaceBetween,
            children: [
              // Search Input
              SizedBox(
                width: 200,
                child: TextField(
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search room...',
                    hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
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
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),

              // Floor Filter Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: filterFloorId,
                    hint: const Text('All Floors', style: TextStyle(fontSize: 12)),
                    isDense: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Floors', style: TextStyle(fontSize: 12))),
                      ...floors.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, style: const TextStyle(fontSize: 12)))),
                    ],
                    onChanged: onFilterFloor,
                  ),
                ),
              ),

              // Room Type Filter Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: filterRoomType,
                    hint: const Text('All Room Types', style: TextStyle(fontSize: 12)),
                    isDense: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Types', style: TextStyle(fontSize: 12))),
                      ...roomTypes.map((rt) => DropdownMenuItem(value: rt, child: Text(rt, style: const TextStyle(fontSize: 12)))),
                    ],
                    onChanged: onFilterRoomType,
                  ),
                ),
              ),

              // Status Filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: filterStatus,
                    hint: const Text('All Statuses', style: TextStyle(fontSize: 12)),
                    isDense: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Statuses', style: TextStyle(fontSize: 12))),
                      ...roomStatuses.map((rs) => DropdownMenuItem(value: rs, child: Text(rs, style: const TextStyle(fontSize: 12)))),
                    ],
                    onChanged: onFilterStatus,
                  ),
                ),
              ),

              // View Mode Switcher
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.table_rows_rounded, size: 18, color: viewMode == 0 ? primaryColor : const Color(0xFF94A3B8)),
                    tooltip: 'Table View',
                    onPressed: () => onViewModeChanged(0),
                  ),
                  IconButton(
                    icon: Icon(Icons.grid_view_rounded, size: 18, color: viewMode == 1 ? primaryColor : const Color(0xFF94A3B8)),
                    tooltip: 'Grid View',
                    onPressed: () => onViewModeChanged(1),
                  ),
                ],
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: onBulkCreate,
                    icon: const Icon(Icons.playlist_add_rounded, size: 15),
                    label: const Text('Bulk Create', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onAddRoom,
                    icon: const Icon(Icons.add, size: 15, color: Colors.white),
                    label: const Text('Add Room', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        const SizedBox(height: 12),

        // Content
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(50),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
        else if (rooms.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.meeting_room_outlined, size: 40, color: Color(0xFF94A3B8)),
                const SizedBox(height: 10),
                const Text('No rooms found matching your filter criteria.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                TextButton(onPressed: onClearFilters, child: const Text('Clear All Filters')),
              ],
            ),
          )
        else if (viewMode == 0)
          _buildTableView(context)
        else
          _buildGridView(context),
      ],
    );
  }

  Widget _buildTableView(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            headingRowHeight: 44,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 52,
            columnSpacing: 20,
            horizontalMargin: 16,
            columns: const [
              DataColumn(label: Text('Room #', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Room Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Floor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Capacity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Equipment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Assignment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            ],
            rows: rooms.map((room) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      room.roomNumber,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF2563EB)),
                    ),
                    onTap: () => onInspectRoom(room),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(room.name, style: const TextStyle(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: _getRoomTypeColor(room.roomType).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        room.roomType,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getRoomTypeColor(room.roomType),
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(room.floorName ?? 'Floor', style: const TextStyle(fontSize: 12))),
                  DataCell(Text('${room.currentOccupancy} / ${room.maxCapacity}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        room.equipmentSummary,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      room.assignmentStatus,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: room.assignmentStatus == 'Assigned' ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getStatusColor(room.operationalStatus).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        room.operationalStatus,
                        style: TextStyle(
                          fontSize: 11,
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
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          color: const Color(0xFF2563EB),
                          tooltip: 'Inspect Room',
                          onPressed: () => onInspectRoom(room),
                        ),
                        IconButton(
                          icon: const Icon(Icons.build_circle_outlined, size: 16),
                          color: const Color(0xFF8B5CF6),
                          tooltip: 'Manage Equipment',
                          onPressed: () => onManageEquipment(room),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          color: const Color(0xFF64748B),
                          tooltip: 'Edit Room',
                          onPressed: () => onEditRoom(room),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          color: const Color(0xFFEF4444),
                          tooltip: 'Delete Room',
                          onPressed: () => onDeleteRoom(room),
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
        maxCrossAxisExtent: 310,
        mainAxisExtent: 200,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        final occPct = room.maxCapacity > 0 ? (room.currentOccupancy / room.maxCapacity).clamp(0.0, 1.0) : 0.0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
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
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(room.operationalStatus).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      room.operationalStatus,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _getStatusColor(room.operationalStatus)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                room.name,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${room.roomType} • ${room.floorName ?? 'Floor'}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),

              // Capacity Progress
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Capacity', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  Text('${room.currentOccupancy} / ${room.maxCapacity}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: occPct,
                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  color: occPct > 0.9 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  minHeight: 5,
                ),
              ),

              const Spacer(),
              const Divider(height: 1),
              const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${room.equipmentCount} Equipment',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.build_circle_outlined, size: 15),
                        color: const Color(0xFF8B5CF6),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        onPressed: () => onManageEquipment(room),
                      ),
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 15),
                        color: const Color(0xFF2563EB),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        onPressed: () => onInspectRoom(room),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        color: const Color(0xFF64748B),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        onPressed: () => onEditRoom(room),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getRoomTypeColor(String type) {
    if (type.contains('Lab')) return const Color(0xFF8B5CF6);
    if (type.contains('Washroom') || type.contains('Toilet')) return const Color(0xFF06B6D4);
    if (type.contains('Office') || type.contains('Principal')) return const Color(0xFFD97706);
    if (type.contains('Library')) return const Color(0xFF0284C7);
    if (type.contains('Hostel')) return const Color(0xFFEC4899);
    return const Color(0xFF2563EB);
  }

  Color _getStatusColor(String status) {
    if (status == 'Available') return const Color(0xFF10B981);
    if (status == 'Occupied') return const Color(0xFF2563EB);
    if (status == 'Reserved') return const Color(0xFFF59E0B);
    if (status == 'Under Maintenance') return const Color(0xFFEF4444);
    return const Color(0xFF64748B);
  }
}
