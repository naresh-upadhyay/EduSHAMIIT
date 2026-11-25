import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import '../../models/hostel_complaint_models.dart';
import 'dialogs/assign_complaint_dialog.dart';
import 'dialogs/update_status_dialog.dart';
import 'dialogs/complaint_feedback_dialog.dart';

class HostelComplaintsTable extends ConsumerWidget {
  const HostelComplaintsTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final complaints = state.complaintsList;
    final pagination = state.complaintsPagination;
    final selectedIds = state.selectedComplaintIds;
    final allSelected = complaints.isNotEmpty && selectedIds.length == complaints.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Table Top Header Bar (Complaints count, Export, Bulk Actions - Responsive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 620;

                final titleWidget = Text(
                  'Complaints (${pagination.totalRecords})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                );

                final actionsWidget = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Export Button
                    OutlinedButton.icon(
                      onPressed: () => notifier.exportComplaintsCsv(),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Export', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    // Bulk Actions Dropdown
                    PopupMenuButton<String>(
                      enabled: selectedIds.isNotEmpty,
                      tooltip: selectedIds.isEmpty ? 'Select complaints to perform bulk actions' : 'Bulk actions',
                      onSelected: (action) => _handleBulkAction(context, ref, action),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'ASSIGN', child: Text('Bulk Assign Staff')),
                        const PopupMenuItem(value: 'MARK_ACTIVE', child: Text('Mark Active')),
                        const PopupMenuItem(value: 'HIGH_PRIORITY', child: Text('Set High Priority')),
                        const PopupMenuItem(value: 'ESCALATE', child: Text('Escalate to Warden')),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selectedIds.isNotEmpty ? 'Bulk Actions (${selectedIds.length})' : 'Bulk Actions',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                    // Refresh / View layout icon
                    IconButton(
                      tooltip: 'Refresh list',
                      onPressed: () => notifier.fetchComplaintsList(),
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      titleWidget,
                      const SizedBox(height: 10),
                      actionsWidget,
                    ],
                  );
                }
                return Row(
                  children: [
                    titleWidget,
                    const Spacer(),
                    actionsWidget,
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // 2. Data Table or Loading / Empty States
          if (state.isComplaintsLoading && complaints.isEmpty)
            _buildLoadingSkeleton(isDark)
          else if (complaints.isEmpty)
            _buildEmptyState(isDark)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 980),
                child: DataTable(
                  sortColumnIndex: _getComplaintsSortColumnIndex(state.complaintsSortBy),
                  sortAscending: state.complaintsSortOrder == 'ASC',
                  horizontalMargin: 16,
                  columnSpacing: 18,
                  headingRowHeight: 44,
                  dataRowMinHeight: 58,
                  dataRowMaxHeight: 64,
                  headingRowColor: WidgetStateProperty.all(
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  ),
                  columns: [
                    DataColumn(
                      label: Checkbox(
                        value: allSelected,
                        onChanged: (val) => notifier.selectAllComplaints(val ?? false),
                      ),
                    ),
                    const DataColumn(label: Text('#', style: _headerStyle)),
                    DataColumn(label: const Text('Title', style: _headerStyle), onSort: (_, asc) => notifier.setComplaintsSort('title', asc ? 'ASC' : 'DESC')),
                    DataColumn(label: const Text('Category', style: _headerStyle), onSort: (_, asc) => notifier.setComplaintsSort('category', asc ? 'ASC' : 'DESC')),
                    DataColumn(label: const Text('Hostel', style: _headerStyle), onSort: (_, asc) => notifier.setComplaintsSort('hostel', asc ? 'ASC' : 'DESC')),
                    DataColumn(label: const Text('Room No.', style: _headerStyle), onSort: (_, asc) => notifier.setComplaintsSort('room_number', asc ? 'ASC' : 'DESC')),
                    DataColumn(label: const Text('Reported By', style: _headerStyle), onSort: (_, asc) => notifier.setComplaintsSort('reported_by', asc ? 'ASC' : 'DESC')),
                    DataColumn(label: const Text('Priority', style: _headerStyle), onSort: (_, asc) => notifier.setComplaintsSort('priority', asc ? 'ASC' : 'DESC')),
                    DataColumn(label: const Text('Status', style: _headerStyle), onSort: (_, asc) => notifier.setComplaintsSort('status', asc ? 'ASC' : 'DESC')),
                    DataColumn(label: const Text('Raised On', style: _headerStyle), onSort: (_, asc) => notifier.setComplaintsSort('created_at', asc ? 'ASC' : 'DESC')),
                    const DataColumn(label: Text('Actions', style: _headerStyle)),
                  ],
                  rows: complaints.map((c) {
                    final isRowSelected = state.selectedComplaintId == c.id;
                    final isChecked = selectedIds.contains(c.id);

                    return DataRow(
                      selected: isRowSelected,
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (isRowSelected) {
                          return isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF);
                        }
                        return null;
                      }),
                      cells: [
                        // Checkbox
                        DataCell(
                          Checkbox(
                            value: isChecked,
                            onChanged: (_) => notifier.toggleComplaintSelection(c.id),
                          ),
                        ),
                        // # Display Index
                        DataCell(
                          Text(
                            '${c.displayIndex}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        // Title with Photo Thumbnail or Icon
                        DataCell(
                          InkWell(
                            onTap: () => notifier.selectComplaint(c.id),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildComplaintThumbnail(c, isDark),
                                const SizedBox(width: 10),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 160),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        c.title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        c.complaintNumber,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Category Pill
                        DataCell(_buildCategoryPill(c.category)),
                        // Hostel Name
                        DataCell(
                          Text(
                            c.hostelName,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        // Room No.
                        DataCell(
                          Text(
                            c.roomNumber ?? '-',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        // Reported By (Name + Class)
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                c.reportedByName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              if (c.reportedByClass != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  c.reportedByClass!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Priority Badge
                        DataCell(_buildPriorityBadge(c.priority)),
                        // Status Pill
                        DataCell(_buildStatusPill(c.status)),
                        // Raised On
                        DataCell(
                          Text(
                            c.raisedOnFormatted,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        // Actions (Eye, Pencil, More)
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'View details',
                                icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                                color: const Color(0xFF64748B),
                                onPressed: () => notifier.selectComplaint(c.id),
                              ),
                              IconButton(
                                tooltip: 'Update status',
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                color: const Color(0xFF64748B),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => UpdateComplaintStatusDialog(complaint: c),
                                  );
                                },
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                                onSelected: (action) => _handleRowAction(context, ref, c, action),
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'ASSIGN', child: Text('Assign Staff')),
                                  const PopupMenuItem(value: 'IN_PROGRESS', child: Text('Mark In Progress')),
                                  const PopupMenuItem(value: 'RESOLVE', child: Text('Mark Resolved')),
                                  const PopupMenuItem(value: 'COMPLETE', child: Text('Complete')),
                                  const PopupMenuItem(value: 'FEEDBACK', child: Text('Submit Rating')),
                                  const PopupMenuItem(value: 'REJECT', child: Text('Reject')),
                                  const PopupMenuItem(value: 'CANCEL', child: Text('Cancel')),
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

          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // 3. Bottom Pagination Bar matching screenshot
          _buildPaginationBar(pagination, notifier, isDark),
        ],
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Color(0xFF64748B),
    letterSpacing: 0.2,
  );

  Widget _buildComplaintThumbnail(HostelComplaintItem c, bool isDark) {
    if (c.thumbnailUrl != null && c.thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          c.thumbnailUrl!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackAvatar(c, isDark),
        ),
      );
    }
    return _buildFallbackAvatar(c, isDark);
  }

  Widget _buildFallbackAvatar(HostelComplaintItem c, bool isDark) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          c.reportedByName.isNotEmpty ? c.reportedByName[0].toUpperCase() : 'C',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPill(String category) {
    Color bg;
    Color fg;

    switch (category.toLowerCase()) {
      case 'plumbing':
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        break;
      case 'electrical':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case 'housekeeping':
        bg = const Color(0xFFFCE7F3);
        fg = const Color(0xFFDB2777);
        break;
      case 'furniture':
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF7C3AED);
        break;
      case 'ac/heating':
        bg = const Color(0xFFCCFBF1);
        fg = const Color(0xFF0D9488);
        break;
      case 'pest control':
        bg = const Color(0xFFFEF9C3);
        fg = const Color(0xFFCA8A04);
        break;
      case 'food & mess':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg;
    Color fg;

    switch (priority.toUpperCase()) {
      case 'CRITICAL':
      case 'URGENT':
      case 'HIGH':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      case 'MEDIUM':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFD97706);
        break;
      default: // LOW
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority[0].toUpperCase() + priority.substring(1).toLowerCase(),
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toUpperCase()) {
      case 'NEW':
      case 'OPEN':
      case 'ACTIVE':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = status == 'ACTIVE' ? 'Active' : 'Open';
        break;
      case 'IN_PROGRESS':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
        label = 'In Progress';
        break;
      case 'ON_HOLD':
      case 'PENDING':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFD97706);
        label = 'Pending';
        break;
      case 'RESOLVED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        label = 'Resolved';
        break;
      case 'COMPLETED':
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF475569);
        label = 'Completed';
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        label = 'Rejected';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildPaginationBar(ComplaintPagination p, HostelNotifier notifier, bool isDark) {
    final startIdx = p.totalRecords == 0 ? 0 : (p.page - 1) * p.pageSize + 1;
    final endIdx = ((p.page - 1) * p.pageSize + p.pageSize).clamp(0, p.totalRecords);

    final rangeText = Text(
      'Showing $startIdx - $endIdx of ${p.totalRecords} complaints',
      style: TextStyle(
        fontSize: 12.5,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
    );

    final pageControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 20),
          onPressed: p.hasPrev ? () => notifier.setComplaintsPage(p.page - 1) : null,
        ),
        ...List.generate(p.totalPages < 1 ? 1 : (p.totalPages > 5 ? 5 : p.totalPages), (i) {
          final pageNum = i + 1;
          final isCurrent = pageNum == p.page;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () => notifier.setComplaintsPage(pageNum),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCurrent ? const Color(0xFF2563EB) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$pageNum',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 20),
          onPressed: p.hasNext ? () => notifier.setComplaintsPage(p.page + 1) : null,
        ),
      ],
    );

    final rowsPerPageSelector = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Rows per page',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: AppSearchableDropdown<int>.fromMenuItems(
              value: p.pageSize,
              items: const [
                DropdownMenuItem(value: 5, child: Text('5')),
                DropdownMenuItem(value: 10, child: Text('10')),
                DropdownMenuItem(value: 25, child: Text('25')),
                DropdownMenuItem(value: 50, child: Text('50')),
              ],
              onChanged: (val) {
                if (val != null) notifier.setComplaintsPageSize(val);
              },
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 800;
          if (isNarrow) {
            return Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                rangeText,
                pageControls,
                rowsPerPageSelector,
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              rangeText,
              pageControls,
              rowsPerPageSelector,
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return Container(
      height: 260,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 2.5),
          SizedBox(height: 12),
          Text('Loading hostel complaints queue...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'No hostel complaints found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try adjusting search filters or raise a new complaint.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  void _handleBulkAction(BuildContext context, WidgetRef ref, String action) {
    final notifier = ref.read(hostelProvider.notifier);
    if (action == 'ASSIGN') {
      final selectedIds = ref.read(hostelProvider).selectedComplaintIds;
      showDialog(
        context: context,
        builder: (ctx) => AssignComplaintDialog(
          complaintId: selectedIds.first,
          isBulk: selectedIds.length > 1,
        ),
      );
    } else if (action == 'MARK_ACTIVE') {
      notifier.bulkComplaintAction('MARK_ACTIVE');
    } else if (action == 'HIGH_PRIORITY') {
      notifier.bulkComplaintAction('CHANGE_PRIORITY', priority: 'HIGH');
    } else if (action == 'ESCALATE') {
      notifier.bulkComplaintAction('ESCALATE');
    }
  }

  void _handleRowAction(BuildContext context, WidgetRef ref, HostelComplaintItem c, String action) {
    final notifier = ref.read(hostelProvider.notifier);
    switch (action) {
      case 'ASSIGN':
        showDialog(
          context: context,
          builder: (ctx) => AssignComplaintDialog(complaintId: c.id, currentAssignee: c.primaryAssigneeName),
        );
        break;
      case 'IN_PROGRESS':
        notifier.updateComplaintStatus(c.id, 'IN_PROGRESS');
        break;
      case 'RESOLVE':
        showDialog(
          context: context,
          builder: (ctx) => UpdateComplaintStatusDialog(complaint: c, initialStatus: 'RESOLVED'),
        );
        break;
      case 'COMPLETE':
        notifier.completeComplaint(c.id);
        break;
      case 'FEEDBACK':
        showDialog(
          context: context,
          builder: (ctx) => ComplaintFeedbackDialog(complaintId: c.id, complaintTitle: c.title),
        );
        break;
      case 'REJECT':
        showDialog(
          context: context,
          builder: (ctx) => UpdateComplaintStatusDialog(complaint: c, initialStatus: 'REJECTED'),
        );
        break;
      case 'CANCEL':
        notifier.cancelComplaint(c.id);
        break;
    }
  }

  int? _getComplaintsSortColumnIndex(String? sortBy) {
    switch (sortBy) {
      case 'title':
        return 2;
      case 'category':
        return 3;
      case 'hostel':
        return 4;
      case 'room_number':
        return 5;
      case 'reported_by':
        return 6;
      case 'priority':
        return 7;
      case 'status':
        return 8;
      case 'created_at':
        return 9;
      default:
        return null;
    }
  }
}
