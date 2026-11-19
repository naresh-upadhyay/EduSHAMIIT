import 'package:flutter/material.dart';
import '../../models/campus_models.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = widget.maintenanceList.where((m) {
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

    final totalCount = widget.maintenanceList.length;
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
              'Maintenance & Repairs (${widget.building.code})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
            ),
            ElevatedButton.icon(
              onPressed: widget.onAddMaintenance,
              icon: const Icon(Icons.add, size: 15, color: Colors.white),
              label: const Text('Log Maintenance Request', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
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
                            Expanded(child: _buildMetricTile('Total Requests', '$totalCount', Icons.assignment_outlined, const Color(0xFF2563EB), isDark)),
                            Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            Expanded(child: _buildMetricTile('Open / Active', '$pendingCount', Icons.pending_actions_outlined, const Color(0xFFD97706), isDark)),
                          ],
                        ),
                        Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        Row(
                          children: [
                            Expanded(child: _buildMetricTile('Completed', '$completedCount', Icons.check_circle_outline, const Color(0xFF059669), isDark)),
                            Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            Expanded(child: _buildMetricTile('Total Cost', '₹${totalCost.toStringAsFixed(0)}', Icons.currency_rupee, const Color(0xFF8B5CF6), isDark)),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildMetricTile('Total Requests', '$totalCount', Icons.assignment_outlined, const Color(0xFF2563EB), isDark)),
                        Container(width: 1, height: 36, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        Expanded(child: _buildMetricTile('Open / Active', '$pendingCount', Icons.pending_actions_outlined, const Color(0xFFD97706), isDark)),
                        Container(width: 1, height: 36, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        Expanded(child: _buildMetricTile('Completed', '$completedCount', Icons.check_circle_outline, const Color(0xFF059669), isDark)),
                        Container(width: 1, height: 36, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        Expanded(child: _buildMetricTile('Total Cost', '₹${totalCost.toStringAsFixed(0)}', Icons.currency_rupee, const Color(0xFF8B5CF6), isDark)),
                      ],
                    ),
            );
          },
        ),
        const SizedBox(height: 14),

        // 3. Search & Filter Bar
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
                      hintText: 'Search issue, code, technician or room...',
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
                    value: _selectedStatus,
                    hint: const Text('All Statuses', style: TextStyle(fontSize: 12.5)),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Statuses', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Pending', child: Text('Pending', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'In Progress', child: Text('In Progress', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Completed', child: Text('Completed', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled', style: TextStyle(fontSize: 12.5))),
                    ],
                    onChanged: (v) => setState(() => _selectedStatus = v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 38,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedPriority,
                    hint: const Text('All Priorities', style: TextStyle(fontSize: 12.5)),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Priorities', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Critical', child: Text('Critical', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'High', child: Text('High', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Low', child: Text('Low', style: TextStyle(fontSize: 12.5))),
                    ],
                    onChanged: (v) => setState(() => _selectedPriority = v),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. Maintenance Data Table
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
                            Icon(Icons.build_circle_outlined, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            const SizedBox(height: 10),
                            Text(
                              'No maintenance records found. Click "+ Log Maintenance Request" to report an issue.',
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
                          dataRowMaxHeight: 54,
                          columnSpacing: 20,
                          horizontalMargin: 16,
                          columns: const [
                            DataColumn(label: Text('Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Issue / Request', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Assigned Staff', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Est / Act Cost', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                          ],
                          rows: filtered.map((item) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    item.requestCode,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: Color(0xFF2563EB)),
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item.description != null && item.description!.isNotEmpty)
                                        Text(
                                          item.description!,
                                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item.roomNumber != null ? 'Room ${item.roomNumber}' : (item.floorName ?? 'Building Common'),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(item.requestType, style: const TextStyle(fontSize: 12)),
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
                                      const Icon(Icons.engineering_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(item.assignedToName ?? 'Unassigned', style: const TextStyle(fontSize: 12)),
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
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        tooltip: 'Edit Request',
                                        onPressed: () => widget.onEditMaintenance(item),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                        tooltip: 'Delete Request',
                                        onPressed: () => widget.onDeleteMaintenance(item),
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

  Widget _buildPriorityChip(String priority) {
    Color color;
    switch (priority.toLowerCase()) {
      case 'critical':
        color = const Color(0xFFDC2626);
        break;
      case 'high':
        color = const Color(0xFFEA580C);
        break;
      case 'medium':
        color = const Color(0xFF2563EB);
        break;
      default:
        color = const Color(0xFF64748B);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed':
        color = const Color(0xFF059669);
        break;
      case 'in progress':
        color = const Color(0xFF2563EB);
        break;
      case 'cancelled':
        color = const Color(0xFF64748B);
        break;
      default:
        color = const Color(0xFFD97706);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 3),
          Icon(Icons.arrow_drop_down, size: 14, color: color),
        ],
      ),
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
