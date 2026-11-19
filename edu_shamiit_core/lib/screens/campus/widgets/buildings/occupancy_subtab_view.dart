import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/campus_models.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = widget.occupancyList.where((o) {
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
              'Space Allocation & Occupancy (${widget.building.code})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
            ),
            ElevatedButton.icon(
              onPressed: widget.onAddOccupancy,
              icon: const Icon(Icons.add, size: 15, color: Colors.white),
              label: const Text('Allocate Space', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2. Mini KPI Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 650;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: isCompact
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildMetricTile('Total Capacity', '$totalCap', Icons.group_rounded, const Color(0xFF2563EB), isDark)),
                            Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            Expanded(child: _buildMetricTile('Occupied', '$displayOccupied', Icons.check_circle_outline, const Color(0xFF059669), isDark)),
                          ],
                        ),
                        Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        Row(
                          children: [
                            Expanded(child: _buildMetricTile('Available', '$availableCap', Icons.event_seat_outlined, const Color(0xFFD97706), isDark)),
                            Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            Expanded(child: _buildMetricTile('Occupancy Rate', '$occPercent%', Icons.pie_chart_outline, const Color(0xFF8B5CF6), isDark)),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildMetricTile('Total Capacity', '$totalCap', Icons.group_rounded, const Color(0xFF2563EB), isDark)),
                        Container(width: 1, height: 36, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        Expanded(child: _buildMetricTile('Occupied', '$displayOccupied', Icons.check_circle_outline, const Color(0xFF059669), isDark)),
                        Container(width: 1, height: 36, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        Expanded(child: _buildMetricTile('Available', '$availableCap', Icons.event_seat_outlined, const Color(0xFFD97706), isDark)),
                        Container(width: 1, height: 36, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        Expanded(child: _buildMetricTile('Occupancy Rate', '$occPercent%', Icons.pie_chart_outline, const Color(0xFF8B5CF6), isDark)),
                      ],
                    ),
            );
          },
        ),
        const SizedBox(height: 14),

        // 3. Search & Module Filter Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search entity, incharge or room...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 38,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedModule,
                    hint: const Text('All Modules', style: TextStyle(fontSize: 12.5)),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Modules', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Academics', child: Text('Academics', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Timetable', child: Text('Timetable', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Examinations', child: Text('Examinations', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Hostel', child: Text('Hostel', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Library', child: Text('Library', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Administration', child: Text('Administration', style: TextStyle(fontSize: 12.5))),
                    ],
                    onChanged: (v) => setState(() => _selectedModule = v),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. Occupancy Data Table
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
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
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pie_chart_outline, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            const SizedBox(height: 10),
                            Text(
                              'No space allocations found. Click "+ Allocate Space" to assign rooms.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          ),
                          headingRowHeight: 44,
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 52,
                          columnSpacing: 20,
                          horizontalMargin: 16,
                          columns: const [
                            DataColumn(label: Text('Target Entity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Module', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Room / Space', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Purpose', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Assigned Incharge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Duration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                          ],
                          rows: filtered.map((item) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    item.referenceName ?? 'General',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.referenceModule,
                                      style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item.roomNumber.isNotEmpty ? '${item.roomNumber} - ${item.roomName ?? ''}' : (item.roomName ?? 'Building Common'),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(item.assignmentPurpose, style: const TextStyle(fontSize: 12)),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_outline, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(item.assignedToName ?? 'Unassigned', style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item.startDate != null
                                        ? '${item.startDate!.substring(0, 10)}${item.endDate != null ? ' to ${item.endDate!.substring(0, 10)}' : ' (Ongoing)'}'
                                        : 'Permanent',
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF059669).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.status,
                                      style: const TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        tooltip: 'Edit Allocation',
                                        onPressed: () => widget.onEditOccupancy(item),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                        tooltip: 'Release / Delete Allocation',
                                        onPressed: () => widget.onDeleteOccupancy(item),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
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
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            const SizedBox(height: 1),
            Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A))),
          ],
        ),
      ],
    );
  }
}
