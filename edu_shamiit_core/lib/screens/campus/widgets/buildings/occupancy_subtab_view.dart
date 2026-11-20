import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import '../common/campus_pagination_bar.dart';

class OccupancySubtabView extends StatefulWidget {
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
  State<OccupancySubtabView> createState() => _OccupancySubtabViewState();
}

class _OccupancySubtabViewState extends State<OccupancySubtabView> {
  String _searchQuery = '';
  String? _selectedModule;
  int _page = 1;
  int _pageSize = 10;
  int? _sortColIndex = 0;
  bool _sortAsc = true;

  void _handleSort(int colIndex, bool asc) {
    setState(() {
      _sortColIndex = colIndex;
      _sortAsc = asc;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var filtered = widget.occupancyList.where((o) {
      if (_selectedModule != null && _selectedModule!.isNotEmpty && o.referenceModule != _selectedModule) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (o.referenceName ?? '').toLowerCase();
        final incharge = (o.assignedToName ?? '').toLowerCase();
        final purpose = o.assignmentPurpose.toLowerCase();
        final room = (o.roomName ?? '').toLowerCase();
        if (!name.contains(q) && !incharge.contains(q) && !purpose.contains(q) && !room.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sorting
    filtered.sort((a, b) {
      int cmp = 0;
      switch (_sortColIndex) {
        case 0:
          cmp = (a.referenceName ?? '').compareTo(b.referenceName ?? '');
          break;
        case 1:
          cmp = a.referenceModule.compareTo(b.referenceModule);
          break;
        case 2:
          cmp = (a.roomNumber.isNotEmpty ? a.roomNumber : (a.roomName ?? '')).compareTo(b.roomNumber.isNotEmpty ? b.roomNumber : (b.roomName ?? ''));
          break;
        case 3:
          cmp = a.assignmentPurpose.compareTo(b.assignmentPurpose);
          break;
        case 4:
          cmp = (a.assignedToName ?? '').compareTo(b.assignedToName ?? '');
          break;
        case 5:
          cmp = (a.startDate ?? '').compareTo(b.startDate ?? '');
          break;
        case 6:
          cmp = a.status.compareTo(b.status);
          break;
        default:
          cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });

    final totalCount = filtered.length;
    final totalPages = math.max(1, (totalCount / _pageSize).ceil());
    if (_page > totalPages) _page = totalPages;

    final startIndex = (totalCount == 0) ? 0 : (_page - 1) * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalCount);
    final pagedItems = (startIndex < totalCount) ? filtered.sublist(startIndex, endIndex) : <BuildingOccupancyModel>[];

    final totalAllocated = widget.occupancyList.fold<int>(0, (sum, item) => sum + item.currentOccupancy);
    final totalCap = widget.building.totalCapacity;
    final displayOccupied = totalAllocated > 0 ? totalAllocated : widget.building.currentOccupancy;
    final availableCap = math.max(0, totalCap - displayOccupied);
    final occPercent = totalCap > 0 ? ((displayOccupied / totalCap) * 100).toStringAsFixed(1) : '0.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header & Action Row
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Text(
              'Space Allocations (${widget.building.code})',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
            ),
            ElevatedButton.icon(
              onPressed: widget.onAddOccupancy,
              icon: const Icon(Icons.add, size: 14, color: Colors.white),
              label: const Text('Allocate Space', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 2. Compact Metric Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(child: _buildMetricTile('Total Cap', '$totalCap', Icons.group_rounded, const Color(0xFF2563EB), isDark)),
              Container(width: 1, height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              Expanded(child: _buildMetricTile('Occupied', '$displayOccupied', Icons.check_circle_outline, const Color(0xFF059669), isDark)),
              Container(width: 1, height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              Expanded(child: _buildMetricTile('Available', '$availableCap', Icons.event_seat_outlined, const Color(0xFFD97706), isDark)),
              Container(width: 1, height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              Expanded(child: _buildMetricTile('Rate', '$occPercent%', Icons.pie_chart_outline, const Color(0xFF8B5CF6), isDark)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 3. Compact Search & Module Filter Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search entity, incharge or room...',
                      hintStyle: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 15),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (v) => setState(() {
                      _searchQuery = v;
                      _page = 1;
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedModule,
                    hint: const Text('All Modules', style: TextStyle(fontSize: 11.5)),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Modules', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Academics', child: Text('Academics', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Timetable', child: Text('Timetable', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Examinations', child: Text('Examinations', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Hostel', child: Text('Hostel', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Library', child: Text('Library', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Administration', child: Text('Administration', style: TextStyle(fontSize: 11.5))),
                    ],
                    onChanged: (v) => setState(() {
                      _selectedModule = v;
                      _page = 1;
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 4. Occupancy Data Table
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: widget.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                )
              : filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pie_chart_outline, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              'No space allocations found. Click "+ Allocate Space" to assign rooms.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          sortColumnIndex: _sortColIndex,
                          sortAscending: _sortAsc,
                          headingRowColor: WidgetStateProperty.all(
                            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          ),
                          headingRowHeight: 34,
                          dataRowMinHeight: 32,
                          dataRowMaxHeight: 35,
                          columnSpacing: 16,
                          horizontalMargin: 12,
                          columns: [
                            DataColumn(
                              label: const Text('Target Entity', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Module', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Room / Space', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Purpose', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Incharge', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Duration', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Status', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            const DataColumn(
                              label: Text('Actions', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                            ),
                          ],
                          rows: pagedItems.map((item) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    item.referenceName ?? 'General',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.referenceModule,
                                      style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10.5, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item.roomNumber.isNotEmpty ? '${item.roomNumber} - ${item.roomName ?? ''}' : (item.roomName ?? 'Building Common'),
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                                DataCell(
                                  Text(item.assignmentPurpose, style: const TextStyle(fontSize: 11.5)),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_outline, size: 13, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(item.assignedToName ?? 'Unassigned', style: const TextStyle(fontSize: 11.5)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item.startDate != null
                                        ? '${item.startDate!.substring(0, 10)}${item.endDate != null ? ' to ${item.endDate!.substring(0, 10)}' : ' (Ongoing)'}'
                                        : 'Permanent',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF059669).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.status,
                                      style: const TextStyle(color: Color(0xFF059669), fontSize: 10.5, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 15),
                                        tooltip: 'Edit Allocation',
                                        onPressed: () => widget.onEditOccupancy(item),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                                        tooltip: 'Release / Delete Allocation',
                                        onPressed: () => widget.onDeleteOccupancy(item),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
        ),
        const SizedBox(height: 8),

        // Pagination Bar
        CampusPaginationBar(
          currentPage: _page,
          pageSize: _pageSize,
          totalCount: totalCount,
          itemLabel: 'allocations',
          onPageChanged: (p) => setState(() => _page = p),
          onPageSizeChanged: (s) => setState(() {
            _pageSize = s;
            _page = 1;
          }),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}
