import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/utils/download_helper.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';
import 'edit_hostel_staff_dialog.dart';
import 'transfer_hostel_staff_dialog.dart';
import 'end_hostel_staff_dialog.dart';

class HostelStaffTable extends ConsumerStatefulWidget {
  const HostelStaffTable({super.key});

  @override
  ConsumerState<HostelStaffTable> createState() => _HostelStaffTableState();
}

class _HostelStaffTableState extends ConsumerState<HostelStaffTable> {
  bool _isGridView = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final roster = state.staffRoster;
    final pagination = state.staffPagination;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Table Top Header Bar
          _buildTableHeader(context, state, notifier, isDark),

          // 2. Loading Indicator Bar
          if (state.isStaffLoading)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),

          // 3. Grid or Table View
          Expanded(
            child: roster.isEmpty && !state.isStaffLoading
                ? _buildEmptyState(context, isDark)
                : _isGridView
                    ? _buildGridView(context, roster, state, notifier, isDark)
                    : _buildTableView(context, roster, state, notifier, isDark),
          ),

          // 4. Pagination Footer Bar
          _buildPaginationFooter(context, pagination, notifier, isDark),
        ],
      ),
    );
  }

  // --- Top Header ---
  Widget _buildTableHeader(BuildContext context, HostelState state, HostelNotifier notifier, bool isDark) {
    final selectedCount = state.selectedStaffAssignmentIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 580;

          final titleWidget = Text(
            'Hostel Staff (${state.staffPagination.totalRecords})',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          );

          final actionsWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Export Button
              OutlinedButton.icon(
                onPressed: () => _exportCsv(context, state),
                icon: const Icon(Icons.download_rounded, size: 15),
                label: Text(
                  selectedCount > 0 ? 'Export ($selectedCount)' : 'Export',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 8),

              // Bulk Actions Dropdown
              PopupMenuButton<String>(
                tooltip: 'Bulk Actions',
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: selectedCount > 0
                        ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                        : Colors.transparent,
                    border: Border.all(
                      color: selectedCount > 0
                          ? const Color(0xFF2563EB)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedCount > 0 ? 'Bulk Actions ($selectedCount)' : 'Bulk Actions',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: selectedCount > 0
                              ? const Color(0xFF2563EB)
                              : (isDark ? Colors.white : const Color(0xFF334155)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: selectedCount > 0
                            ? const Color(0xFF2563EB)
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                onSelected: (val) => _handleBulkAction(context, val, state, notifier),
                itemBuilder: (context) {
                  if (selectedCount == 0) {
                    return [
                      const PopupMenuItem(
                        enabled: false,
                        value: 'none',
                        child: Text(
                          'Select staff members with checkboxes to enable bulk actions',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ];
                  }

                  return [
                    PopupMenuItem(
                      value: 'mark_active',
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                          const SizedBox(width: 8),
                          Text('Mark Selected Active ($selectedCount)', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'mark_on_leave',
                      child: Row(
                        children: [
                          const Icon(Icons.pause_circle_outline, size: 16, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Text('Mark Selected On Leave ($selectedCount)', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'transfer_selected',
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz, size: 16, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Text('Transfer Selected to Hostel...', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'export_selected',
                      child: Row(
                        children: [
                          const Icon(Icons.download_rounded, size: 16, color: Color(0xFF16A34A)),
                          const SizedBox(width: 8),
                          Text('Export Selected to CSV ($selectedCount)', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'clear_selection',
                      child: Row(
                        children: [
                          const Icon(Icons.clear_all, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text('Clear Selection ($selectedCount)', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ];
                },
              ),
              const SizedBox(width: 8),

              // Grid / List toggle icons (Interactive)
              Container(
                height: 32,
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // List view toggle
                    InkWell(
                      onTap: () => setState(() => _isGridView = false),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: !_isGridView
                              ? (isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF))
                              : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                        ),
                        child: Icon(
                          Icons.format_list_bulleted_rounded,
                          size: 16,
                          color: !_isGridView ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                    // Grid view toggle
                    InkWell(
                      onTap: () => setState(() => _isGridView = true),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _isGridView
                              ? (isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF))
                              : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                        ),
                        child: Icon(
                          Icons.grid_view_rounded,
                          size: 16,
                          color: _isGridView ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
                titleWidget,
                const SizedBox(height: 8),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: actionsWidget),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              titleWidget,
              actionsWidget,
            ],
          );
        },
      ),
    );
  }

  // --- Table View ---
  Widget _buildTableView(
    BuildContext context,
    List<HostelStaffRosterItem> roster,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final allSelected = roster.isNotEmpty &&
        roster.every((s) => state.selectedStaffAssignmentIds.contains(s.assignmentId));

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SingleChildScrollView(
              child: DataTable(
                sortColumnIndex: _getStaffSortColumnIndex(state.staffSortBy),
                sortAscending: state.staffSortOrder == 'ASC',
                headingRowHeight: 44,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 56,
                horizontalMargin: 16,
                columnSpacing: 20,
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(
                  isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                ),
                columns: [
                  // Checkbox
                  DataColumn(
                    label: SizedBox(
                      width: 24,
                      child: Checkbox(
                        value: allSelected,
                        tristate: state.selectedStaffAssignmentIds.isNotEmpty && !allSelected,
                        onChanged: (val) {
                          notifier.selectAllStaff(val == true);
                        },
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      '#',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Photo',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    ),
                  ),
                  DataColumn(
                    onSort: (_, __) => notifier.setStaffSort('name'),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Name',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 14,
                          color: state.staffSortBy == 'name' ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                  DataColumn(
                    onSort: (_, __) => notifier.setStaffSort('role'),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Role',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 14,
                          color: state.staffSortBy == 'role' ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                  DataColumn(
                    onSort: (_, __) => notifier.setStaffSort('hostel'),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Hostel',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 14,
                          color: state.staffSortBy == 'hostel' ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                  DataColumn(
                    onSort: (_, __) => notifier.setStaffSort('assigned_area'),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Assigned Area',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 14,
                          color: state.staffSortBy == 'assigned_area' ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                  DataColumn(
                    onSort: (_, __) => notifier.setStaffSort('contact'),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Contact',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 14,
                          color: state.staffSortBy == 'contact' ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                  DataColumn(
                    onSort: (_, __) => notifier.setStaffSort('status'),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 14,
                          color: state.staffSortBy == 'status' ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Actions',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
                rows: roster.asMap().entries.map((entry) {
                  final index = entry.key;
                  final staff = entry.value;
                  final isSelected = state.selectedStaffAssignmentId == staff.assignmentId;
                  final isChecked = state.selectedStaffAssignmentIds.contains(staff.assignmentId);

                  return DataRow(
                    selected: isSelected,
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (isSelected) {
                        return const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.06);
                      }
                      if (index.isOdd) {
                        return isDark ? const Color(0xFF0F172A).withValues(alpha: 0.3) : const Color(0xFFFBFDFF);
                      }
                      return null;
                    }),
                    onSelectChanged: (_) {
                      notifier.selectStaff(staff.assignmentId);
                    },
                    cells: [
                      // Checkbox
                      DataCell(
                        SizedBox(
                          width: 24,
                          child: Checkbox(
                            value: isChecked,
                            onChanged: (_) {
                              notifier.toggleStaffSelection(staff.assignmentId);
                            },
                          ),
                        ),
                      ),
                      // # Number
                      DataCell(
                        Text(
                          '${((state.staffPagination.currentPage - 1) * state.staffPagination.pageSize) + index + 1}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      // Photo
                      DataCell(
                        _buildAvatar(staff.name, staff.photoUrl),
                      ),
                      // Name
                      DataCell(
                        Text(
                          staff.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      // Role Pill
                      DataCell(_buildRoleBadge(staff.role, isDark)),
                      // Hostel
                      DataCell(
                        Text(
                          staff.hostelName,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      // Assigned Area
                      DataCell(
                        Text(
                          staff.assignedArea,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      // Contact
                      DataCell(
                        Text(
                          staff.contact,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      // Status
                      DataCell(_buildStatusBadge(staff.status, isDark)),
                      // Actions
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_red_eye_outlined, size: 17),
                              tooltip: 'View 360 Details',
                              color: const Color(0xFF2563EB),
                              onPressed: () => notifier.selectStaff(staff.assignmentId),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 17),
                              tooltip: 'Edit Assignment',
                              color: const Color(0xFF64748B),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => EditHostelStaffDialog(staff: staff),
                                );
                              },
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 17, color: Color(0xFF64748B)),
                              tooltip: 'Actions',
                              onSelected: (val) async {
                                if (val == 'transfer') {
                                  showDialog(
                                    context: context,
                                    builder: (context) => TransferHostelStaffDialog(staff: staff),
                                  );
                                } else if (val == 'toggle_status') {
                                  final newStatus = staff.status == 'Active' ? 'ON_LEAVE' : 'ACTIVE';
                                  await notifier.updateStaffAssignment(
                                    staff.assignmentId,
                                    {
                                      'assignment_id': staff.assignmentId,
                                      'assignment_status': newStatus,
                                      'duty_status': newStatus == 'ON_LEAVE' ? 'ON_LEAVE' : 'ON_DUTY',
                                    },
                                  );
                                } else if (val == 'end') {
                                  showDialog(
                                    context: context,
                                    builder: (context) => EndHostelStaffDialog(staff: staff),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'transfer',
                                  child: Row(
                                    children: [
                                      Icon(Icons.swap_horiz, size: 16, color: Color(0xFF2563EB)),
                                      SizedBox(width: 8),
                                      Text('Transfer Staff', style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle_status',
                                  child: Row(
                                    children: [
                                      Icon(
                                        staff.status == 'Active' ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                        size: 16,
                                        color: const Color(0xFFD97706),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        staff.status == 'Active' ? 'Mark On Leave' : 'Mark Active',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'end',
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_off_outlined, size: 16, color: Color(0xFFDC2626)),
                                      SizedBox(width: 8),
                                      Text('End Assignment', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                                    ],
                                  ),
                                ),
                              ],
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
    );
  }

  // --- Grid View ---
  Widget _buildGridView(
    BuildContext context,
    List<HostelStaffRosterItem> roster,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = 3;
        if (width < 600) {
          columns = 1;
        } else if (width < 950) {
          columns = 2;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(14),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 220,
          ),
          itemCount: roster.length,
          itemBuilder: (context, index) {
            final staff = roster[index];
            final isSelected = state.selectedStaffAssignmentId == staff.assignmentId;
            final isChecked = state.selectedStaffAssignmentIds.contains(staff.assignmentId);

            return InkWell(
              onTap: () => notifier.selectStaff(staff.assignmentId),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Row: Checkbox, Avatar, Status
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Checkbox(
                            value: isChecked,
                            onChanged: (_) => notifier.toggleStaffSelection(staff.assignmentId),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildAvatar(staff.name, staff.photoUrl),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                staff.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'ID: ${staff.employeeId.isNotEmpty ? staff.employeeId : "HS00${index+1}"}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(staff.status, isDark),
                      ],
                    ),
                    const Divider(height: 16),

                    // Middle Info: Role, Hostel, Area
                    Row(
                      children: [
                        _buildRoleBadge(staff.role, isDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            staff.hostelName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            staff.assignedArea,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            staff.contact,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Bottom Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => notifier.selectStaff(staff.assignmentId),
                          icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                          label: const Text('View 360', style: TextStyle(fontSize: 11.5)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          tooltip: 'Edit',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => EditHostelStaffDialog(staff: staff),
                            );
                          },
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
    );
  }

  // --- Pagination Footer ---
  Widget _buildPaginationFooter(
    BuildContext context,
    HostelStaffRosterPagination pagination,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final start = pagination.totalRecords == 0
        ? 0
        : ((pagination.currentPage - 1) * pagination.pageSize) + 1;
    final end = (pagination.currentPage * pagination.pageSize).clamp(0, pagination.totalRecords);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          final countInfo = Text(
            'Showing $start - $end of ${pagination.totalRecords} staff',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          );

          final paginationControls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous Page
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                tooltip: 'Previous Page',
                onPressed: pagination.hasPrev
                    ? () => notifier.setStaffPage(pagination.currentPage - 1)
                    : null,
                visualDensity: VisualDensity.compact,
              ),

              // Page Pills (1, 2, 3...)
              ...List.generate(pagination.totalPages, (i) {
                final pageNum = i + 1;
                final isCurrent = pageNum == pagination.currentPage;

                return InkWell(
                  onTap: () => notifier.setStaffPage(pageNum),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrent ? const Color(0xFF2563EB) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xFF2563EB)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    child: Text(
                      '$pageNum',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent
                            ? Colors.white
                            : (isDark ? Colors.white : const Color(0xFF334155)),
                      ),
                    ),
                  ),
                );
              }),

              // Next Page
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: 'Next Page',
                onPressed: pagination.hasNext
                    ? () => notifier.setStaffPage(pagination.currentPage + 1)
                    : null,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 12),

              // Rows per page dropdown
              Text(
                'Rows per page',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 72,
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: AppSearchableDropdown<int>.fromMenuItems(
                    value: pagination.pageSize,
                    isDense: true,
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 20, child: Text('20', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 50, child: Text('50', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) notifier.setStaffPageSize(val);
                    },
                  ),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              children: [
                countInfo,
                const SizedBox(height: 6),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: paginationControls),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              countInfo,
              paginationControls,
            ],
          );
        },
      ),
    );
  }

  // --- Avatar & Badges ---
  Widget _buildAvatar(String name, String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 15,
        backgroundImage: NetworkImage(photoUrl),
      );
    }

    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : 'S';
    return CircleAvatar(
      radius: 15,
      backgroundColor: const Color(0xFFEFF6FF),
      child: Text(
        initials,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
      ),
    );
  }

  Widget _buildRoleBadge(String role, bool isDark) {
    Color bg;
    Color fg;
    Color border;

    if (role.toLowerCase().contains('warden')) {
      bg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF);
      fg = const Color(0xFF2563EB);
      border = const Color(0xFFBFDBFE);
    } else if (role.toLowerCase().contains('caretaker')) {
      bg = isDark ? const Color(0xFF581C87).withValues(alpha: 0.3) : const Color(0xFFFAF5FF);
      fg = const Color(0xFF9333EA);
      border = const Color(0xFFE9D5FF);
    } else if (role.toLowerCase().contains('security')) {
      bg = isDark ? const Color(0xFF134E4A).withValues(alpha: 0.3) : const Color(0xFFF0FDFA);
      fg = const Color(0xFF0D9488);
      border = const Color(0xFF99F6E4);
    } else if (role.toLowerCase().contains('housekeeping')) {
      bg = isDark ? const Color(0xFF7C2D12).withValues(alpha: 0.3) : const Color(0xFFFFF7ED);
      fg = const Color(0xFFEA580C);
      border = const Color(0xFFFED7AA);
    } else if (role.toLowerCase().contains('maintenance')) {
      bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
      border = const Color(0xFFCBD5E1);
    } else {
      bg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFFFBEB);
      fg = const Color(0xFFD97706);
      border = const Color(0xFFFDE68A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        role,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bg;
    Color fg;
    Color border;

    if (status.toLowerCase().contains('active')) {
      bg = isDark ? const Color(0xFF14532D).withValues(alpha: 0.3) : const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
      border = const Color(0xFF86EFAC);
    } else if (status.toLowerCase().contains('leave')) {
      bg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      border = const Color(0xFFFDE68A);
    } else {
      bg = isDark ? const Color(0xFF0C4A6E).withValues(alpha: 0.3) : const Color(0xFFE0F2FE);
      fg = const Color(0xFF0284C7);
      border = const Color(0xFFBAE6FD);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.badge_outlined, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'No Hostel Staff Found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your search criteria or assign staff to this hostel.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // --- Bulk Actions Handler ---
  Future<void> _handleBulkAction(
    BuildContext context,
    String action,
    HostelState state,
    HostelNotifier notifier,
  ) async {
    final selectedIds = state.selectedStaffAssignmentIds.toList();
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select staff members using checkboxes first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (action == 'clear_selection') {
      notifier.selectAllStaff(false);
      return;
    }

    if (action == 'mark_active') {
      await notifier.bulkStaffActions(action: 'MARK_ACTIVE', assignmentIds: selectedIds);
    } else if (action == 'mark_on_leave') {
      await notifier.bulkStaffActions(action: 'MARK_ON_LEAVE', assignmentIds: selectedIds);
    } else if (action == 'transfer_selected') {
      _showBulkTransferDialog(context, selectedIds, notifier);
    } else if (action == 'export_selected') {
      _exportSelectedCsv(context, state, selectedIds);
    }
  }

  void _showBulkTransferDialog(BuildContext context, List<String> selectedIds, HostelNotifier notifier) {
    final state = ref.read(hostelProvider);
    final buildings = state.structureTree;
    String? selectedHostelId = buildings.isNotEmpty ? buildings.first.id : null;
    final reasonController = TextEditingController(text: 'Bulk Hostel Transfer');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Transfer ${selectedIds.length} Staff Members'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Select Destination Hostel *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    AppSearchableDropdownFormField<String>.fromMenuItems(
                      initialValue: selectedHostelId,
                      items: buildings.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                      onChanged: (val) => setModalState(() => selectedHostelId = val),
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 14),
                    const Text('Transfer Reason', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: () async {
                    if (selectedHostelId == null) return;
                    Navigator.of(ctx).pop();
                    await notifier.bulkStaffActions(
                      action: 'TRANSFER',
                      assignmentIds: selectedIds,
                      newHostelId: selectedHostelId,
                      reason: reasonController.text.trim(),
                    );
                  },
                  child: const Text('Confirm Bulk Transfer', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportSelectedCsv(BuildContext context, HostelState state, List<String> selectedIds) async {
    try {
      final selectedStaff = state.staffRoster.where((s) => selectedIds.contains(s.assignmentId)).toList();
      final buffer = StringBuffer();
      buffer.writeln('row_num,name,employee_id,role,hostel_name,assigned_area,contact,email,status,shift_timings');
      for (int i = 0; i < selectedStaff.length; i++) {
        final s = selectedStaff[i];
        buffer.writeln('${i + 1},"${s.name}","${s.employeeId}","${s.role}","${s.hostelName}","${s.assignedArea}","${s.contact}","${s.email}","${s.status}","${s.shiftTimings}"');
      }
      final filename = 'hostel_staff_selected_${DateTime.now().millisecondsSinceEpoch}.csv';
      final bytes = utf8.encode(buffer.toString());
      await getDownloadHelper().downloadBytes(bytes, filename);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${selectedStaff.length} selected staff to $filename'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export selected staff: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportCsv(BuildContext context, HostelState state) async {
    final selectedCount = state.selectedStaffAssignmentIds.length;
    if (selectedCount > 0) {
      await _exportSelectedCsv(context, state, state.selectedStaffAssignmentIds.toList());
      return;
    }

    final url = '/api/hostel/staff/export?academic_year=${Uri.encodeComponent(state.selectedAcademicYear)}';
    final filename = 'hostel_staff_${DateTime.now().millisecondsSinceEpoch}.csv';
    try {
      await getDownloadHelper().downloadFile(url, filename);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported hostel staff to $filename'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
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

  int? _getStaffSortColumnIndex(String? sortBy) {
    switch (sortBy) {
      case 'name':
        return 3;
      case 'role':
        return 4;
      case 'hostel':
        return 5;
      case 'assigned_area':
        return 6;
      case 'contact':
        return 7;
      case 'status':
        return 8;
      default:
        return null;
    }
  }
}
