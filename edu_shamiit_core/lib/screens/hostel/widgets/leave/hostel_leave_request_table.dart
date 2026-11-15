import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';

class HostelLeaveRequestTable extends ConsumerWidget {
  final bool onlyCurrentlyOut;
  final String? titleOverride;
  const HostelLeaveRequestTable({super.key, this.onlyCurrentlyOut = false, this.titleOverride});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allRequests = state.leaveRequests;
    final requests = onlyCurrentlyOut
        ? allRequests
            .where((r) =>
                r.status == 'EXITED' ||
                r.status == 'OVERDUE' ||
                (r.actualExitAt != null && r.actualReturnAt == null))
            .toList()
        : allRequests;
    final total = onlyCurrentlyOut ? requests.length : (state.leavePagination['total'] as int? ?? 0);
    final page = state.leavePagination['page'] as int? ?? 1;
    final pageSize = state.leavePagination['page_size'] as int? ?? 10;
    final totalPages = state.leavePagination['total_pages'] as int? ?? 1;

    final startIdx = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final endIdx = total == 0 ? 0 : (startIdx + requests.length - 1).clamp(0, total);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Top Bar: Title & Filter Config
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  titleOverride ?? 'Leave & Outing Requests ($total)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.view_column_rounded, color: Color(0xFF2563EB), size: 20),
                            SizedBox(width: 8),
                            Text('Table Columns Configuration', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        content: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All primary columns are active and aligned with standard hostel regulatory requirements:',
                              style: TextStyle(fontSize: 12.5),
                            ),
                            SizedBox(height: 10),
                            Text('✓ Request ID & Tracking #'),
                            Text('✓ Student Name & Admission ID'),
                            Text('✓ Room & Bed Allocation'),
                            Text('✓ Purpose / Destination'),
                            Text('✓ Out Time & Expected Return'),
                            Text('✓ Approval & Gate Clearance Status'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  color: const Color(0xFF64748B),
                  tooltip: 'Configure Columns',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

          // Table Content / Loading State / Empty State
          if (state.isLeaveLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2.5),
                    SizedBox(height: 12),
                    Text(
                      'Loading movement requests...',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else if (requests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inbox_rounded, size: 28, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No leave or outing requests found.',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try adjusting your search query or filters.',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _getLeaveSortColumnIndex(state.leaveSortBy),
                sortAscending: state.leaveSortOrder.toLowerCase() == 'asc',
                headingRowHeight: 40,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 56,
                horizontalMargin: 16,
                columnSpacing: 18,
                headingRowColor: WidgetStateProperty.all(
                  isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                ),
                columns: [
                  DataColumn(label: SizedBox(width: 24, child: Text('#', style: _getHeaderStyle(isDark)))),
                  DataColumn(label: Text('Student Name', style: _getHeaderStyle(isDark)), onSort: (_, __) => notifier.setLeaveSort('student_name')),
                  DataColumn(label: Text('Hostel', style: _getHeaderStyle(isDark)), onSort: (_, __) => notifier.setLeaveSort('hostel')),
                  DataColumn(label: Text('Room No.', style: _getHeaderStyle(isDark)), onSort: (_, __) => notifier.setLeaveSort('room_number')),
                  DataColumn(label: Text('Type', style: _getHeaderStyle(isDark)), onSort: (_, __) => notifier.setLeaveSort('request_type')),
                  DataColumn(label: Text('From', style: _getHeaderStyle(isDark)), onSort: (_, __) => notifier.setLeaveSort('departure_date')),
                  DataColumn(label: Text('To', style: _getHeaderStyle(isDark)), onSort: (_, __) => notifier.setLeaveSort('expected_return')),
                  DataColumn(label: Text('Duration', style: _getHeaderStyle(isDark)), onSort: (_, __) => notifier.setLeaveSort('duration')),
                  DataColumn(label: Text('Status', style: _getHeaderStyle(isDark)), onSort: (_, __) => notifier.setLeaveSort('status')),
                  DataColumn(label: Text('Requested On', style: _getHeaderStyle(isDark)), onSort: (_, __) => notifier.setLeaveSort('created_at')),
                  DataColumn(label: Text('Actions', style: _getHeaderStyle(isDark))),
                ],
                rows: requests.map((req) {
                  final isSelected = state.selectedLeaveRequest?.id == req.id;
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (_) => notifier.selectLeaveRequest(req),
                    cells: [
                      // 1. #
                      DataCell(
                        Text(
                          '${req.displayIndex}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      // 2. Student Name + Class & Roll No
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: const Color(0xFFEFF6FF),
                              backgroundImage: req.studentAvatar != null ? NetworkImage(req.studentAvatar!) : null,
                              child: req.studentAvatar == null
                                  ? Text(
                                      req.studentName.isNotEmpty ? req.studentName[0] : 'S',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  req.studentName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  req.classSectionDisplay,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 3. Hostel Name
                      DataCell(
                        Text(
                          req.hostelName ?? 'Boys Hostel A',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      // 4. Room No
                      DataCell(
                        Text(
                          req.roomNumber ?? 'A-101',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      // 5. Type Badge
                      DataCell(_buildTypeBadge(req.requestType, isDark)),
                      // 6. From
                      DataCell(
                        Text(
                          req.displayFromDate,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      // 7. To
                      DataCell(
                        Text(
                          req.displayToDate,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      // 8. Duration
                      DataCell(
                        Text(
                          req.displayDuration,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      // 9. Status Chip
                      DataCell(_buildStatusChip(req.status, isDark)),
                      // 10. Requested On
                      DataCell(
                        Text(
                          req.displayRequestedOn,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      // 11. Actions
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility_outlined, size: 16),
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              tooltip: 'View Details',
                              onPressed: () => notifier.selectLeaveRequest(req),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              tooltip: 'Edit Request',
                              onPressed: () => notifier.selectLeaveRequest(req),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 6),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              tooltip: 'More Actions',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onSelected: (val) {
                                if (val == 'view') {
                                  notifier.selectLeaveRequest(req);
                                } else if (val == 'approve') {
                                  _confirmApprove(context, req, notifier, isDark);
                                } else if (val == 'reject') {
                                  _confirmReject(context, req, notifier, isDark);
                                } else if (val == 'delete') {
                                  _confirmDeleteRequest(context, req, notifier, isDark);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Row(
                                    children: [
                                      Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF2563EB)),
                                      SizedBox(width: 8),
                                      Text('View Details'),
                                    ],
                                  ),
                                ),
                                if (req.status == 'PENDING') ...[
                                  const PopupMenuItem(
                                    value: 'approve',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                                        SizedBox(width: 8),
                                        Text('Approve Request'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'reject',
                                    child: Row(
                                      children: [
                                        Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                                        SizedBox(width: 8),
                                        Text('Reject Request'),
                                      ],
                                    ),
                                  ),
                                ],
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                      SizedBox(width: 8),
                                      Text('Delete Request'),
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

          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

          // Table Bottom Pagination Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                Text(
                  'Showing $startIdx - $endIdx of $total requests',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pagination Buttons « < 1 2 3 > »
                    IconButton(
                      icon: const Icon(Icons.first_page_rounded, size: 18),
                      onPressed: page > 1 ? () => notifier.setLeavePage(1) : null,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      onPressed: page > 1 ? () => notifier.setLeavePage(page - 1) : null,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),

                    // Numbered Pages window around current page
                    ...(() {
                      final start = (page - 2).clamp(1, (totalPages - 4).clamp(1, totalPages));
                      final count = (totalPages - start + 1).clamp(1, 5);
                      return List.generate(count, (i) {
                        final p = start + i;
                        final isCurrent = p == page;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: () => notifier.setLeavePage(p),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? const Color(0xFF2563EB)
                                    : isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$p',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                  color: isCurrent
                                      ? Colors.white
                                      : isDark
                                          ? Colors.white
                                          : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                        );
                      });
                    })(),

                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      onPressed: page < totalPages ? () => notifier.setLeavePage(page + 1) : null,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.last_page_rounded, size: 18),
                      onPressed: page < totalPages ? () => notifier.setLeavePage(totalPages) : null,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),

                    const SizedBox(width: 20),

                    // Rows per page selector
                    Text(
                      'Rows per page',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: pageSize,
                          isDense: true,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          items: const [10, 25, 50, 100].map((s) {
                            return DropdownMenuItem<int>(
                              value: s,
                              child: Text('$s'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) notifier.setLeavePageSize(val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type, bool isDark) {
    final isLeave = type.toUpperCase() == 'LEAVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isLeave
            ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF))
            : (isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFF3E8FF)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isLeave ? 'Leave' : 'Outing',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: isLeave
              ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB))
              : (isDark ? const Color(0xFFD8B4FE) : const Color(0xFF9333EA)),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, bool isDark) {
    final s = status.toUpperCase();
    Color bg;
    Color fg;

    switch (s) {
      case 'APPROVED':
        bg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFDCFCE7);
        fg = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
        break;
      case 'PENDING':
      case 'NEW':
      case 'ACTIVE':
      case 'IN_PROGRESS':
        bg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF3C7);
        fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
        break;
      case 'REJECTED':
      case 'OVERDUE':
      case 'OVERDUE_RETURN':
        bg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.5) : const Color(0xFFFEE2E2);
        fg = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
        break;
      case 'EXITED':
        bg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF);
        fg = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
        break;
      case 'RETURNED':
      case 'RESOLVED':
      case 'COMPLETED':
        bg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFDCFCE7);
        fg = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
        break;
      default:
        bg = isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF1F5F9);
        fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    }

    final displayText = s == 'OVERDUE_RETURN' ? 'Overdue' : s[0] + s.substring(1).toLowerCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  TextStyle _getHeaderStyle(bool isDark) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
  );

  int? _getLeaveSortColumnIndex(String? sortBy) {
    switch (sortBy) {
      case 'student_name':
        return 1;
      case 'hostel':
        return 2;
      case 'room_number':
        return 3;
      case 'request_type':
        return 4;
      case 'departure_date':
        return 5;
      case 'expected_return':
        return 6;
      case 'duration':
        return 7;
      case 'status':
        return 8;
      case 'created_at':
      case 'request_number':
        return 9;
      default:
        return null;
    }
  }

  void _confirmDeleteRequest(BuildContext context, dynamic req, HostelNotifier notifier, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Text('Delete Leave / Outing Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to permanently delete request ${req.requestNumber} for ${req.studentName}?',
          style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.deleteLeaveRequest(req.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _confirmApprove(BuildContext context, dynamic req, HostelNotifier notifier, bool isDark) {
    final remarksController = TextEditingController(text: 'Approved by Warden.');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Approve Request (${req.requestNumber})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Student: ${req.studentName} (${req.className})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(labelText: 'Approval Remarks', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.approveLeaveRequest(req.id, remarks: remarksController.text.trim(), version: req.version);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmReject(BuildContext context, dynamic req, HostelNotifier notifier, bool isDark) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Reject Request (${req.requestNumber})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Student: ${req.studentName} (${req.className})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Rejection Reason *', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              notifier.rejectLeaveRequest(req.id, reason: reasonController.text.trim(), version: req.version);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
