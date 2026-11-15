import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';
import '../dialogs/transfer_hostel_student_dialog.dart';
import '../dialogs/release_bed_dialog.dart';
import '../dialogs/checkout_hostel_student_dialog.dart';

class HostelStudentsTable extends ConsumerWidget {
  const HostelStudentsTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final roster = state.studentsRoster;
    final pagination = state.studentsPagination;
    final allSelected = roster.isNotEmpty &&
        roster.every((s) => state.selectedStudentRosterIds.contains(s.admissionId));

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
          // Loading Indicator Bar
          if (state.isStudentsLoading)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),

          // Scrollable Table Grid
          Expanded(
            child: roster.isEmpty && !state.isStudentsLoading
                ? _buildEmptyState(context, isDark)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                          child: SingleChildScrollView(
                            child: DataTable(
                              sortColumnIndex: _getStudentsSortColumnIndex(state.studentsSortBy),
                              sortAscending: state.studentsSortOrder == 'ASC',
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
                                      tristate: state.selectedStudentRosterIds.isNotEmpty && !allSelected,
                                      onChanged: (val) {
                                        notifier.toggleSelectAllStudents(val == true);
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
                                  onSort: (_, __) => notifier.setStudentsSort('student_name'),
                                  label: const Text(
                                    'Student Name',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                  ),
                                ),
                                DataColumn(
                                  onSort: (_, __) => notifier.setStudentsSort('roll_no'),
                                  label: const Text(
                                    'Roll No',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                  ),
                                ),
                                DataColumn(
                                  onSort: (_, __) => notifier.setStudentsSort('class'),
                                  label: const Text(
                                    'Class',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                  ),
                                ),
                                DataColumn(
                                  onSort: (_, __) => notifier.setStudentsSort('hostel'),
                                  label: const Text(
                                    'Hostel',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                  ),
                                ),
                                DataColumn(
                                  onSort: (_, __) => notifier.setStudentsSort('room'),
                                  label: const Text(
                                    'Room',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                  ),
                                ),
                                DataColumn(
                                  onSort: (_, __) => notifier.setStudentsSort('bed_no'),
                                  label: const Text(
                                    'Bed No',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                  ),
                                ),
                                DataColumn(
                                  onSort: (_, __) => notifier.setStudentsSort('status'),
                                  label: const Text(
                                    'Status',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                  ),
                                ),
                                DataColumn(
                                  onSort: (_, __) => notifier.setStudentsSort('fee_status'),
                                  label: const Text(
                                    'Fee Status',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                  ),
                                ),
                                const DataColumn(
                                  label: Text(
                                    'Actions',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                              rows: List<DataRow>.generate(roster.length, (index) {
                                final student = roster[index];
                                final isSelected = student.admissionId == state.selectedStudentId ||
                                    student.id == state.selectedStudentId;
                                final isChecked = state.selectedStudentRosterIds.contains(student.admissionId);

                                return DataRow(
                                  selected: isSelected,
                                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                                    if (isSelected) {
                                      return isDark
                                          ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
                                          : const Color(0xFFEFF6FF);
                                    }
                                    if (index.isOdd) {
                                      return isDark
                                          ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                                          : const Color(0xFFFBFCFD);
                                    }
                                    return null;
                                  }),
                                  onSelectChanged: (_) {
                                    notifier.selectStudent(student.admissionId);
                                  },
                                  cells: [
                                    // Checkbox
                                    DataCell(
                                      SizedBox(
                                        width: 24,
                                        child: Checkbox(
                                          value: isChecked,
                                          onChanged: (_) {
                                            notifier.toggleSelectStudent(student.admissionId);
                                          },
                                        ),
                                      ),
                                    ),
                                    // Row Number
                                    DataCell(
                                      Text(
                                        '${(pagination.page - 1) * pagination.pageSize + index + 1}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    // Photo Avatar
                                    DataCell(
                                      _buildAvatar(student),
                                    ),
                                    // Student Name + Guardian Subtext
                                    DataCell(
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student.studentName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? const Color(0xFF2563EB)
                                                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                            ),
                                          ),
                                          if (student.guardianRelation.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              student.guardianRelation,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Roll No
                                    DataCell(
                                      Text(
                                        student.rollNo,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    // Class
                                    DataCell(
                                      Text(
                                        student.className,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    // Hostel
                                    DataCell(
                                      Text(
                                        student.hostelName,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    // Room
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          student.roomNumber,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Bed No
                                    DataCell(
                                      Text(
                                        student.bedNo,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    // Status Pill Badge
                                    DataCell(
                                      _buildStatusPill(student.status, isDark),
                                    ),
                                    // Fee Status Pill Badge
                                    DataCell(
                                      _buildFeeStatusPill(student.feeStatus, isDark),
                                    ),
                                    // Actions: View, Edit, More
                                    DataCell(
                                      _buildActionsRow(context, student, notifier, isDark),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Pagination & Footer Bar
          _buildPaginationBar(pagination, notifier, isDark, currentCount: roster.length),
        ],
      ),
    );
  }

  Widget _buildAvatar(HostelStudentRosterItem student) {
    final initials = student.studentName.isNotEmpty ? student.studentName[0].toUpperCase() : 'S';
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFF059669),
      const Color(0xFFD97706),
      const Color(0xFFDC2626),
    ];
    final color = colors[student.studentName.hashCode.abs() % colors.length];

    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withValues(alpha: 0.15),
      backgroundImage: student.photoUrl != null && student.photoUrl!.startsWith('http')
          ? NetworkImage(student.photoUrl!)
          : null,
      child: student.photoUrl == null || !student.photoUrl!.startsWith('http')
          ? Text(
              initials,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            )
          : null,
    );
  }

  Widget _buildStatusPill(String status, bool isDark) {
    Color bg;
    Color text;
    Color dot;

    switch (status.toLowerCase()) {
      case 'active':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        dot = const Color(0xFF16A34A);
        break;
      case 'leave':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        dot = const Color(0xFFF59E0B);
        break;
      case 'awaiting':
      case 'awaiting allocation':
        bg = const Color(0xFFDBEAFE);
        text = const Color(0xFF1D4ED8);
        dot = const Color(0xFF2563EB);
        break;
      case 'checked out':
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF475569);
        dot = const Color(0xFF94A3B8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeStatusPill(String feeStatus, bool isDark) {
    Color bg;
    Color text;

    switch (feeStatus.toLowerCase()) {
      case 'paid':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        break;
      case 'pending':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFB91C1C);
        break;
      case 'partial':
        bg = const Color(0xFFFFEDD5);
        text = const Color(0xFFC2410C);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF475569);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        feeStatus,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  Widget _buildActionsRow(
    BuildContext context,
    HostelStudentRosterItem student,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Eye (View)
        IconButton(
          icon: const Icon(Icons.visibility_outlined, size: 18),
          color: const Color(0xFF2563EB),
          tooltip: 'View 360 Student Profile',
          splashRadius: 18,
          onPressed: () {
            notifier.selectStudent(student.admissionId);
          },
        ),
        // Edit (Transfer Room)
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          color: const Color(0xFF64748B),
          tooltip: 'Transfer Room / Bed',
          splashRadius: 18,
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => TransferHostelStudentDialog(student: student),
            );
          },
        ),
        // More (...)
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
          splashRadius: 18,
          tooltip: 'More Student Options',
          onSelected: (val) {
            if (val == 'view') {
              notifier.selectStudent(student.admissionId);
            } else if (val == 'transfer') {
              showDialog(
                context: context,
                builder: (ctx) => TransferHostelStudentDialog(student: student),
              );
            } else if (val == 'release') {
              showDialog(
                context: context,
                builder: (ctx) => ReleaseBedDialog(student: student),
              );
            } else if (val == 'checkout') {
              showDialog(
                context: context,
                builder: (ctx) => CheckoutHostelStudentDialog(student: student),
              );
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.person_search_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('View 360 Details', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'transfer',
              child: Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Change Room', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'release',
              child: Row(
                children: [
                  Icon(Icons.bed_outlined, size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Text('Release Bed', style: TextStyle(fontSize: 13, color: Color(0xFFD97706))),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'checkout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 16, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Text('Check Out Student', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 12),
            Text(
              'No Hostel Students Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'No students match your active filters or search criteria.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBar(
    HostelStudentRosterPagination pagination,
    HostelNotifier notifier,
    bool isDark, {
    int currentCount = 0,
  }) {
    final effectiveTotal = pagination.totalRecords > 0 ? pagination.totalRecords : currentCount;
    final start = effectiveTotal == 0
        ? 0
        : (pagination.page - 1) * pagination.pageSize + 1;
    final end = (pagination.page * pagination.pageSize) > effectiveTotal
        ? effectiveTotal
        : (pagination.page * pagination.pageSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;
          final pageControls = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: pagination.hasPrev
                    ? () => notifier.setStudentsPage(pagination.page - 1)
                    : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Previous', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              // Page indicators
              ...List.generate(pagination.totalPages.clamp(1, 5), (i) {
                final pageNum = i + 1;
                final isCurrent = pageNum == pagination.page;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => notifier.setStudentsPage(pageNum),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFF2563EB)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFF2563EB)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$pageNum',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent
                                ? Colors.white
                                : (isDark ? Colors.white : const Color(0xFF334155)),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: pagination.hasNext
                    ? () => notifier.setStudentsPage(pagination.page + 1)
                    : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Next', style: TextStyle(fontSize: 12)),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Showing $start-$end of $effectiveTotal students',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
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
                'Showing $start-$end of $effectiveTotal students',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              pageControls,
            ],
          );
        },
      ),
    );
  }

  int? _getStudentsSortColumnIndex(String? sortBy) {
    switch (sortBy) {
      case 'student_name':
        return 3;
      case 'roll_no':
        return 4;
      case 'class':
        return 5;
      case 'hostel':
        return 6;
      case 'room':
        return 7;
      case 'bed_no':
        return 8;
      case 'status':
        return 9;
      case 'fee_status':
        return 10;
      default:
        return null;
    }
  }
}
