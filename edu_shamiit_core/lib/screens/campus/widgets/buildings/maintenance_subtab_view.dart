import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import '../common/campus_pagination_bar.dart';

class MaintenanceSubtabView extends StatefulWidget {
  final BuildingModel building;
  final List<BuildingMaintenanceModel> maintenanceList;
  final List<BuildingFloorModel> floors;
  final List<RoomModel> rooms;
  final bool isLoading;
  final VoidCallback onAddMaintenance;
  final ValueChanged<BuildingMaintenanceModel> onEditMaintenance;
  final ValueChanged<BuildingMaintenanceModel> onDeleteMaintenance;
  final void Function(BuildingMaintenanceModel, String) onQuickUpdateStatus;

  const MaintenanceSubtabView({
    super.key,
    required this.building,
    required this.maintenanceList,
    required this.floors,
    required this.rooms,
    this.isLoading = false,
    required this.onAddMaintenance,
    required this.onEditMaintenance,
    required this.onDeleteMaintenance,
    required this.onQuickUpdateStatus,
  });

  @override
  State<MaintenanceSubtabView> createState() => _MaintenanceSubtabViewState();
}

class _MaintenanceSubtabViewState extends State<MaintenanceSubtabView> {
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedPriority;
  int _page = 1;
  int _pageSize = 10;
  int? _sortColIndex = 0;
  bool _sortAsc = false; // default newest first

  void _handleSort(int colIndex, bool asc) {
    setState(() {
      _sortColIndex = colIndex;
      _sortAsc = asc;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var filtered = widget.maintenanceList.where((m) {
      if (_selectedStatus != null && _selectedStatus!.isNotEmpty && m.status != _selectedStatus) {
        return false;
      }
      if (_selectedPriority != null && _selectedPriority!.isNotEmpty && m.priority != _selectedPriority) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = m.title.toLowerCase();
        final code = m.requestCode.toLowerCase();
        final type = m.requestType.toLowerCase();
        final assigned = (m.assignedToName ?? '').toLowerCase();
        final room = (m.roomNumber ?? '').toLowerCase();
        if (!title.contains(q) && !code.contains(q) && !type.contains(q) && !assigned.contains(q) && !room.contains(q)) {
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
          cmp = a.requestCode.compareTo(b.requestCode);
          break;
        case 1:
          cmp = a.title.compareTo(b.title);
          break;
        case 2:
          cmp = (a.roomNumber ?? '').compareTo(b.roomNumber ?? '');
          break;
        case 3:
          cmp = a.requestType.compareTo(b.requestType);
          break;
        case 4:
          cmp = a.priority.compareTo(b.priority);
          break;
        case 5:
          cmp = a.status.compareTo(b.status);
          break;
        case 6:
          cmp = (a.assignedToName ?? '').compareTo(b.assignedToName ?? '');
          break;
        case 7:
          cmp = a.estimatedCost.compareTo(b.estimatedCost);
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
    final pagedItems = (startIndex < totalCount) ? filtered.sublist(startIndex, endIndex) : <BuildingMaintenanceModel>[];

    final pendingCount = widget.maintenanceList.where((m) => m.status == 'Pending' || m.status == 'In Progress').length;
    final completedCount = widget.maintenanceList.where((m) => m.status == 'Completed').length;
    final totalCost = widget.maintenanceList.fold<double>(0.0, (sum, m) => sum + (m.actualCost > 0 ? m.actualCost : m.estimatedCost));

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
              'Maintenance & Work Orders (${widget.building.code})',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
            ),
            ElevatedButton.icon(
              onPressed: widget.onAddMaintenance,
              icon: const Icon(Icons.build_rounded, size: 14, color: Colors.white),
              label: const Text('Log Request', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
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

        // 2. Compact KPI Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(child: _buildMetricTile('Total Tickets', '${widget.maintenanceList.length}', Icons.confirmation_number_outlined, const Color(0xFF2563EB), isDark)),
              Container(width: 1, height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              Expanded(child: _buildMetricTile('Pending', '$pendingCount', Icons.pending_actions_outlined, const Color(0xFFDC2626), isDark)),
              Container(width: 1, height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              Expanded(child: _buildMetricTile('Completed', '$completedCount', Icons.task_alt_outlined, const Color(0xFF059669), isDark)),
              Container(width: 1, height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              Expanded(child: _buildMetricTile('Est Cost', '₹${totalCost.toStringAsFixed(0)}', Icons.payments_outlined, const Color(0xFF8B5CF6), isDark)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 3. Compact Search & Filter Row
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
                      hintText: 'Search title, code, staff...',
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
                  child: AppSearchableDropdown<String?>.fromMenuItems(
                    value: _selectedStatus,
                    hint: const Text('All Statuses', style: TextStyle(fontSize: 11.5)),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Statuses', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Pending', child: Text('Pending', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'In Progress', child: Text('In Progress', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Completed', child: Text('Completed', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled', style: TextStyle(fontSize: 11.5))),
                    ],
                    onChanged: (v) => setState(() {
                      _selectedStatus = v;
                      _page = 1;
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: DropdownButtonHideUnderline(
                  child: AppSearchableDropdown<String?>.fromMenuItems(
                    value: _selectedPriority,
                    hint: const Text('All Priorities', style: TextStyle(fontSize: 11.5)),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Priorities', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Critical', child: Text('Critical', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'High', child: Text('High', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Low', child: Text('Low', style: TextStyle(fontSize: 11.5))),
                    ],
                    onChanged: (v) => setState(() {
                      _selectedPriority = v;
                      _page = 1;
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 4. Maintenance Data Table
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
                            Icon(Icons.build_circle_outlined, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              'No maintenance records found. Click "+ Log Request" to report an issue.',
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
                          columnSpacing: 14,
                          horizontalMargin: 12,
                          columns: [
                            DataColumn(
                              label: const Text('Code', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Issue / Request', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Location', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Type', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Priority', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Status', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Assigned Staff', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Est / Act Cost', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
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
                                    item.requestCode,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: Color(0xFF2563EB)),
                                  ),
                                ),
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 160),
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item.roomNumber != null ? 'Room ${item.roomNumber}' : (item.floorName ?? 'Building Common'),
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                                DataCell(
                                  Text(item.requestType, style: const TextStyle(fontSize: 11.5)),
                                ),
                                DataCell(
                                  _buildPriorityChip(item.priority),
                                ),
                                DataCell(
                                  PopupMenuButton<String>(
                                    tooltip: 'Quick Update Status',
                                    onSelected: (val) => widget.onQuickUpdateStatus(item, val),
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: 'Pending', child: Text('Pending')),
                                      PopupMenuItem(value: 'In Progress', child: Text('In Progress')),
                                      PopupMenuItem(value: 'Completed', child: Text('Completed')),
                                      PopupMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                                    ],
                                    child: _buildStatusChip(item.status),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.engineering_outlined, size: 13, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(item.assignedToName ?? 'Unassigned', style: const TextStyle(fontSize: 11.5)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '₹${item.estimatedCost.toStringAsFixed(0)} / ₹${item.actualCost.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 15),
                                        tooltip: 'Edit Request',
                                        onPressed: () => widget.onEditMaintenance(item),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                                        tooltip: 'Delete Request',
                                        onPressed: () => widget.onDeleteMaintenance(item),
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
          itemLabel: 'requests',
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

  Widget _buildPriorityChip(String priority) {
    Color color;
    switch (priority.toLowerCase()) {
      case 'critical':
        color = const Color(0xFFEF4444);
        break;
      case 'high':
        color = const Color(0xFFF97316);
        break;
      case 'medium':
        color = const Color(0xFFF59E0B);
        break;
      case 'low':
        color = const Color(0xFF10B981);
        break;
      default:
        color = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed':
        color = const Color(0xFF10B981);
        break;
      case 'in progress':
        color = const Color(0xFF2563EB);
        break;
      case 'cancelled':
        color = const Color(0xFF64748B);
        break;
      case 'pending':
      default:
        color = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(status, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 3),
          Icon(Icons.arrow_drop_down, size: 14, color: color),
        ],
      ),
    );
  }
}
