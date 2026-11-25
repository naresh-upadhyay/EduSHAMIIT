import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/download_helper.dart';
import '../models/hostel_models.dart';
import '../providers/hostel_provider.dart';
import 'dialogs/add_edit_room_dialog.dart';
import 'dialogs/add_edit_bed_dialog.dart';
import 'dialogs/assign_student_dialog.dart';
import 'dialogs/bulk_generate_rooms_dialog.dart';

class HostelCenterTable extends ConsumerStatefulWidget {
  const HostelCenterTable({super.key});

  @override
  ConsumerState<HostelCenterTable> createState() => _HostelCenterTableState();
}

class _HostelCenterTableState extends ConsumerState<HostelCenterTable> {
  bool _isGridView = false;
  final Set<String> _selectedRoomIds = <String>{};
  String _sortColumn = 'room_number';
  bool _sortAscending = true;

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  List<HostelRoomItem> _applySort(List<HostelRoomItem> list) {
    final sorted = List<HostelRoomItem>.from(list);
    sorted.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case 'room_number':
          cmp = a.roomNumber.compareTo(b.roomNumber);
          break;
        case 'room_type':
          cmp = a.roomType.compareTo(b.roomType);
          break;
        case 'capacity':
          cmp = (a.capacity ?? 0).compareTo(b.capacity ?? 0);
          break;
        case 'occupied':
          cmp = (a.occupied ?? 0).compareTo(b.occupied ?? 0);
          break;
        case 'status':
          cmp = a.status.compareTo(b.status);
          break;
        case 'facilities':
          cmp = a.facilities.length.compareTo(b.facilities.length);
          break;
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  Future<void> _exportToCsv(List<HostelRoomItem> rooms) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('Room Number,Room Type,Capacity,Occupied,Status,Building,Floor,Monthly Fee');
      for (final r in rooms) {
        final fee = r.monthlyFee;
        buffer.writeln(
          '"${r.roomNumber}","${r.roomType}",${r.capacity ?? 0},${r.occupied ?? 0},"${r.status}","${r.buildingName}","${r.floorName}",$fee',
        );
      }
      final bytes = utf8.encode(buffer.toString());
      final filename = 'hostel_rooms_${DateTime.now().millisecondsSinceEpoch}.csv';
      await getDownloadHelper().downloadBytes(bytes, filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${rooms.length} rooms to $filename'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export CSV: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleBulkAction(
    String action,
    HostelNotifier notifier,
    List<HostelRoomItem> rooms,
  ) async {
    if (action == 'bulk_generate') {
      showDialog(
        context: context,
        builder: (ctx) => BulkGenerateRoomsDialog(
          buildingId: ref.read(hostelProvider).selectedBuildingId ?? '',
          floorId: ref.read(hostelProvider).selectedFloorId ?? '',
        ),
      );
      return;
    }

    if (_selectedRoomIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select one or more rooms using the checkboxes.'),
          backgroundColor: Color(0xFFEAB308),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (action == 'delete_selected') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Selected Rooms'),
          content: Text(
            'Are you sure you want to delete ${_selectedRoomIds.length} selected room(s)? This will remove associated beds and equipment.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      int count = 0;
      for (final id in _selectedRoomIds) {
        final ok = await notifier.service.deleteRoom(id);
        if (ok) count++;
      }
      setState(() => _selectedRoomIds.clear());
      notifier.showSuccess('Deleted $count room(s) successfully');
      notifier.refreshAll();
      return;
    }

    if (action == 'mark_available' || action == 'mark_clean') {
      int count = 0;
      for (final id in _selectedRoomIds) {
        final res = await notifier.service.saveRoom({'id': id, 'status': 'AVAILABLE'});
        if (res['success'] == true) count++;
      }
      setState(() => _selectedRoomIds.clear());
      notifier.showSuccess('Marked $count room(s) as Available');
      notifier.refreshAll();
      return;
    }

    if (action == 'mark_maintenance') {
      final occupiedRooms = rooms.where((r) => _selectedRoomIds.contains(r.id) && (r.occupied ?? 0) > 0).toList();
      if (occupiedRooms.isNotEmpty) {
        final totalOccupants = occupiedRooms.fold<int>(0, (sum, r) => sum + (r.occupied ?? 0));
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Text('Occupants In Selected Rooms'),
              ],
            ),
            content: Text(
              '${occupiedRooms.length} of the selected rooms currently have active occupants ($totalOccupants resident(s)). '
              'Switching these rooms to Maintenance will block these rooms for future allocations.\n\n'
              'Are you sure you wish to mark them under maintenance?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Proceed & Mark Maintenance', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }

      int count = 0;
      for (final id in _selectedRoomIds) {
        final res = await notifier.service.saveRoom({'id': id, 'status': 'MAINTENANCE'});
        if (res['success'] == true) count++;
      }
      setState(() => _selectedRoomIds.clear());
      notifier.showSuccess('Marked $count room(s) as Under Maintenance');
      notifier.refreshAll();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rooms = _applySort(state.rooms);
    final pagination = state.pagination;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Search & Filter Bar
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Search Input
                SizedBox(
                  width: 260,
                  height: 38,
                  child: TextField(
                    onChanged: (val) => notifier.setSearchQuery(val),
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      hintText: 'Search room number, type, building, floor...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                ),

                // Hostels Dropdown
                _buildDropdown(
                  value: state.hostelFilter,
                  items: ['All Hostels', ...state.filterOptions.hostels.map((h) => h['name'] as String)],
                  onChanged: (val) => notifier.setHostelFilter(val ?? 'All Hostels'),
                  isDark: isDark,
                ),

                // Floors Dropdown
                _buildDropdown(
                  value: state.floorFilter,
                  items: ['All Floors', ...state.filterOptions.floors.map((f) => f['name'] as String)],
                  onChanged: (val) => notifier.setFloorFilter(val ?? 'All Floors'),
                  isDark: isDark,
                ),

                // Room Types Dropdown
                _buildDropdown(
                  value: state.roomTypeFilter,
                  items: ['All Room Types', ...state.filterOptions.roomTypes],
                  onChanged: (val) => notifier.setRoomTypeFilter(val ?? 'All Room Types'),
                  isDark: isDark,
                ),

                // Status Dropdown
                _buildDropdown(
                  value: state.statusFilter,
                  items: ['All Status', ...state.filterOptions.statuses],
                  onChanged: (val) => notifier.setStatusFilter(val ?? 'All Status'),
                  isDark: isDark,
                ),

                // Action Buttons: + Add Room & ... More Actions
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AddEditRoomDialog(
                        preselectedBuildingId: state.selectedBuildingId,
                        preselectedFloorId: state.selectedFloorId,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text(
                    'Add Room',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

                PopupMenuButton<String>(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.more_horiz, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          'More Actions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  onSelected: (action) {
                    if (action == 'bulk_generate') {
                      showDialog(
                        context: context,
                        builder: (ctx) => BulkGenerateRoomsDialog(
                          buildingId: state.selectedBuildingId ?? '',
                          floorId: state.selectedFloorId ?? '',
                        ),
                      );
                    } else if (action == 'refresh') {
                      notifier.fetchRooms();
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'bulk_generate',
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 16, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Text('Bulk Generate Rooms', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 16, color: Color(0xFF64748B)),
                          SizedBox(width: 8),
                          Text('Refresh Rooms', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

          // 2. Sub-Header: Context Title & Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: LayoutBuilder(
              builder: (context, subConstraints) {
                final isNarrow = subConstraints.maxWidth < 540;
                final controls = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Export Button
                    OutlinedButton.icon(
                      onPressed: () => _exportToCsv(rooms),
                      icon: const Icon(Icons.download_rounded, size: 14, color: Color(0xFF64748B)),
                      label: const Text(
                        'Export',
                        style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bulk Actions
                    PopupMenuButton<String>(
                      tooltip: 'Bulk Actions',
                      onSelected: (action) => _handleBulkAction(action, notifier, rooms),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedRoomIds.isNotEmpty
                              ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                              : Colors.transparent,
                          border: Border.all(
                            color: _selectedRoomIds.isNotEmpty
                                ? const Color(0xFF2563EB)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedRoomIds.isNotEmpty
                                  ? 'Bulk Actions (${_selectedRoomIds.length})'
                                  : 'Bulk Actions',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _selectedRoomIds.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                                color: _selectedRoomIds.isNotEmpty
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF475569),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'mark_available',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                              SizedBox(width: 8),
                              Text('Mark as Available / Clean', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'mark_maintenance',
                          child: Row(
                            children: [
                              Icon(Icons.build_outlined, size: 16, color: Color(0xFFEA580C)),
                              SizedBox(width: 8),
                              Text('Mark as Maintenance', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        if (_selectedRoomIds.isNotEmpty) ...[
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'delete_selected',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete Selected (${_selectedRoomIds.length})',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'bulk_generate',
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 16, color: Color(0xFF2563EB)),
                              SizedBox(width: 8),
                              Text('Bulk Generate Rooms...', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    // View Mode Toggles (List / Grid)
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          // List View Toggle
                          InkWell(
                            onTap: () => setState(() => _isGridView = false),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: !_isGridView
                                    ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: !_isGridView
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                Icons.format_list_bulleted,
                                size: 16,
                                color: !_isGridView ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          // Grid View Toggle
                          InkWell(
                            onTap: () => setState(() => _isGridView = true),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _isGridView
                                    ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: _isGridView
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                Icons.grid_view_rounded,
                                size: 16,
                                color: _isGridView ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${state.contextTitle} (${rooms.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: controls,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${state.contextTitle} (${rooms.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    controls,
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

          // 3. Rooms Table or Grid
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : rooms.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.meeting_room_outlined,
                                size: 48,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No Rooms Found',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Click + Add Room or Bulk Generate to add rooms.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _isGridView
                        ? _buildGridView(context, rooms, state, notifier, isDark)
                        : _buildTableView(context, rooms, state, notifier, isDark),
          ),

          // 4. Bottom Pagination Footer
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: LayoutBuilder(
              builder: (context, footConstraints) {
                final isNarrow = footConstraints.maxWidth < 460;
                final pageControls = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: (pagination['page'] ?? 1) > 1
                          ? () => notifier.setPage((pagination['page'] ?? 1) - 1)
                          : null,
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${pagination['page'] ?? 1}',
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: (pagination['page'] ?? 1) < (pagination['total_pages'] ?? 1)
                          ? () => notifier.setPage((pagination['page'] ?? 1) + 1)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    const Text('Rows: 20', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Showing 1 - ${rooms.length} of ${pagination['total_records'] ?? rooms.length} rooms',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: pageControls,
                      ),
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing 1 - ${rooms.length} of ${pagination['total_records'] ?? rooms.length} rooms',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    pageControls,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortableHeader(String title, String column, double? width, {bool isExpanded = false}) {
    final isSelected = _sortColumn == column;
    final content = InkWell(
      onTap: () => _onSort(column),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              style: _headerStyle,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isSelected
                ? (_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 14,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
          ),
        ],
      ),
    );

    if (isExpanded) {
      return Expanded(child: content);
    }
    return SizedBox(width: width, child: content);
  }

  Widget _buildTableView(
    BuildContext context,
    List<HostelRoomItem> rooms,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = math.max(constraints.maxWidth, 840.0);
        final allSelected = rooms.isNotEmpty && _selectedRoomIds.length == rooms.length;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: ListView.separated(
              itemCount: rooms.length + 1,
              separatorBuilder: (ctx, i) => Divider(
                height: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Table Header Row
                  return Container(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (allSelected) {
                                  _selectedRoomIds.clear();
                                } else {
                                  _selectedRoomIds.addAll(rooms.map((r) => r.id));
                                }
                              });
                            },
                            child: Icon(
                              allSelected
                                  ? Icons.check_box
                                  : (_selectedRoomIds.isNotEmpty
                                      ? Icons.indeterminate_check_box
                                      : Icons.check_box_outline_blank),
                              size: 18,
                              color: _selectedRoomIds.isNotEmpty
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        _buildSortableHeader('Room No.', 'room_number', 95),
                        _buildSortableHeader('Room Type', 'room_type', 130),
                        _buildSortableHeader('Capacity', 'capacity', 90),
                        _buildSortableHeader('Occupied', 'occupied', 90),
                        _buildSortableHeader('Status', 'status', 105),
                        _buildSortableHeader('Facilities', 'facilities', null, isExpanded: true),
                        const SizedBox(width: 90, child: Text('Actions', style: _headerStyle)),
                      ],
                    ),
                  );
                }

                final room = rooms[index - 1];
                final isRowChecked = _selectedRoomIds.contains(room.id);
                final isSelected = state.selectedRoomId == room.id;

                return InkWell(
                  onTap: () => notifier.selectRoom(room.id),
                  hoverColor: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                  child: Container(
                    color: isSelected
                        ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : const Color(0xFFEFF6FF).withValues(alpha: 0.6))
                        : (isRowChecked
                            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                            : Colors.transparent),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (isRowChecked) {
                                  _selectedRoomIds.remove(room.id);
                                } else {
                                  _selectedRoomIds.add(room.id);
                                }
                              });
                            },
                            child: Icon(
                              isRowChecked ? Icons.check_box : Icons.check_box_outline_blank,
                              size: 18,
                              color: isRowChecked ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        // Room No.
                        SizedBox(
                          width: 95,
                          child: Text(
                            room.roomNumber,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                        // Room Type
                        SizedBox(
                          width: 130,
                          child: Text(
                            room.roomType,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        // Capacity
                        SizedBox(
                          width: 90,
                          child: Text(
                            room.capacityLabel,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        // Occupied
                        SizedBox(
                          width: 90,
                          child: Text(
                            room.occupiedLabel,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        // Status Badge
                        SizedBox(
                          width: 105,
                          child: _buildStatusBadge(room.status),
                        ),
                        // Facilities Icons
                        Expanded(
                          child: _buildFacilitiesRow(room),
                        ),
                        // Actions
                        SizedBox(
                          width: 90,
                          child: Row(
                            children: [
                              Tooltip(
                                message: 'View Room Details',
                                child: InkWell(
                                  onTap: () => notifier.selectRoom(room.id),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                              Tooltip(
                                message: 'Edit Room',
                                child: InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AddEditRoomDialog(room: room),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF94A3B8)),
                                tooltip: 'More Room Actions',
                                onSelected: (val) async {
                                  if (val == 'assign_student') {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AssignStudentDialog(preselectedRoomItem: room),
                                    );
                                  } else if (val == 'add_bed') {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AddEditBedDialog(
                                        roomId: room.id,
                                        roomNumber: room.roomNumber,
                                      ),
                                    );
                                  } else if (val == 'edit_room') {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AddEditRoomDialog(room: room),
                                    );
                                  } else if (val == 'delete_room') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text('Delete Room ${room.roomNumber}'),
                                        content: const Text(
                                          'Are you sure you want to delete this room? This will also remove associated beds and allocations.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      await notifier.service.deleteRoom(room.id);
                                      notifier.showSuccess('Room ${room.roomNumber} deleted');
                                      notifier.refreshAll();
                                    }
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'assign_student',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_add_alt_1_outlined, size: 16, color: Color(0xFF2563EB)),
                                        SizedBox(width: 8),
                                        Text('Assign Student', style: TextStyle(fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'add_bed',
                                    child: Row(
                                      children: [
                                        Icon(Icons.single_bed_outlined, size: 16, color: Color(0xFF0D9488)),
                                        SizedBox(width: 8),
                                        Text('Add Bed', style: TextStyle(fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit_room',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                        SizedBox(width: 8),
                                        Text('Edit Room', style: TextStyle(fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: 'delete_room',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                        SizedBox(width: 8),
                                        Text('Delete Room', style: TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
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
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridView(
    BuildContext context,
    List<HostelRoomItem> rooms,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GridView.builder(
            itemCount: rooms.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 290,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, i) {
              final room = rooms[i];
              final isRowChecked = _selectedRoomIds.contains(room.id);
              final isSelectedInInspector = state.selectedRoomId == room.id;

              final capacity = room.capacity ?? 3;
              final occupied = room.occupied ?? 0;
              final pct = capacity > 0 ? (occupied / capacity).clamp(0.0, 1.0) : 0.0;

              return InkWell(
                onTap: () => notifier.selectRoom(room.id),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelectedInInspector
                        ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : const Color(0xFFEFF6FF))
                        : (isDark ? const Color(0xFF0F172A) : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelectedInInspector
                          ? const Color(0xFF2563EB)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isSelectedInInspector ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Row: Checkbox, Room Number, Status Badge, More options
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (isRowChecked) {
                                  _selectedRoomIds.remove(room.id);
                                } else {
                                  _selectedRoomIds.add(room.id);
                                }
                              });
                            },
                            child: Icon(
                              isRowChecked ? Icons.check_box : Icons.check_box_outline_blank,
                              size: 16,
                              color: isRowChecked ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              room.roomNumber,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadge(room.status),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF94A3B8)),
                            tooltip: 'Room Actions',
                            onSelected: (val) async {
                              if (val == 'assign_student') {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AssignStudentDialog(preselectedRoomItem: room),
                                );
                              } else if (val == 'add_bed') {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AddEditBedDialog(roomId: room.id, roomNumber: room.roomNumber),
                                );
                              } else if (val == 'edit_room') {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AddEditRoomDialog(room: room),
                                );
                              } else if (val == 'delete_room') {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('Delete Room ${room.roomNumber}'),
                                    content: const Text('Are you sure? This will delete all beds and records for this room.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await notifier.service.deleteRoom(room.id);
                                  notifier.showSuccess('Room ${room.roomNumber} deleted');
                                  notifier.refreshAll();
                                }
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'assign_student',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_add_alt_1_outlined, size: 16, color: Color(0xFF2563EB)),
                                    SizedBox(width: 8),
                                    Text('Assign Student', style: TextStyle(fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'add_bed',
                                child: Row(
                                  children: [
                                    Icon(Icons.single_bed_outlined, size: 16, color: Color(0xFF0D9488)),
                                    SizedBox(width: 8),
                                    Text('Add Bed', style: TextStyle(fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit_room',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                    SizedBox(width: 8),
                                    Text('Edit Room', style: TextStyle(fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'delete_room',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                    SizedBox(width: 8),
                                    Text('Delete Room', style: TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Room Type & Fee
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              room.roomType,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          Text(
                            '₹${room.monthlyFee.toInt()}/mo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      // Occupancy Progress
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Occupancy',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                '$occupied / $capacity Beds',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 5,
                              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                pct >= 1.0
                                    ? const Color(0xFF16A34A)
                                    : (pct > 0 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Amenities & Quick Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildFacilitiesRow(room),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF64748B)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                tooltip: 'Edit Room',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AddEditRoomDialog(room: room),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward, size: 15, color: Color(0xFF2563EB)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                tooltip: 'Inspect Room',
                                onPressed: () => notifier.selectRoom(room.id),
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
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Color(0xFF64748B),
  );

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    final validItems = items.toSet().toList();
    final actualVal = validItems.contains(value) ? value : validItems.first;

    return Container(
      height: 38,
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<String>.fromMenuItems(
          value: actualVal,
          isDense: true,
          isExpanded: false,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF334155),
          ),
          items: validItems
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFE0F2FE);
    Color text = const Color(0xFF0369A1);
    String label = 'Available';

    switch (status.toUpperCase()) {
      case 'OCCUPIED':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        label = 'Occupied';
        break;
      case 'AVAILABLE':
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF0369A1);
        label = 'Available';
        break;
      case 'OPERATIONAL':
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF0369A1);
        label = 'Operational';
        break;
      case 'MAINTENANCE':
        bg = const Color(0xFFFFEDD5);
        text = const Color(0xFFC2410C);
        label = 'Maintenance';
        break;
      default:
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text),
      ),
    );
  }

  Widget _buildFacilitiesRow(HostelRoomItem room) {
    if (!room.isResidential) {
      // Washroom / Utility amenities
      return const SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop_outlined, size: 14, color: Color(0xFF0284C7)),
            SizedBox(width: 8),
            Icon(Icons.shower_outlined, size: 14, color: Color(0xFF64748B)),
            SizedBox(width: 8),
            Icon(Icons.wc_outlined, size: 14, color: Color(0xFF64748B)),
          ],
        ),
      );
    }

    // Residential room amenities
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hotel_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 2),
              Text('${room.capacity ?? 3}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(width: 8),
          const Icon(Icons.mode_fan_off_outlined, size: 14, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          const Icon(Icons.wifi, size: 14, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          const Icon(Icons.tv, size: 14, color: Color(0xFF64748B)),
        ],
      ),
    );
  }
}
