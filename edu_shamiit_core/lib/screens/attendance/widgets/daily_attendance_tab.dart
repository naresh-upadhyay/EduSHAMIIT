import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../constants/app_fonts.dart';
import '../../../../utils/responsive.dart';
import '../models/attendance_models.dart';
import '../../classes/models/class_models.dart';
import '../providers/attendance_provider.dart';
import 'dialogs/attendance_override_dialog.dart';
import 'dialogs/attendance_confirmation_dialog.dart';
import 'drawers/student_attendance_drawer.dart';

class DailyAttendanceTab extends ConsumerStatefulWidget {
  final Function(AttendanceStudentRowModel student)? onSelectStudent;

  const DailyAttendanceTab({Key? key, this.onSelectStudent}) : super(key: key);

  @override
  ConsumerState<DailyAttendanceTab> createState() => _DailyAttendanceTabState();
}

class _DailyAttendanceTabState extends ConsumerState<DailyAttendanceTab> {
  final TextEditingController _searchController = TextEditingController();
  AttendanceStudentRowModel? _selectedDrawerStudent;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);
    final isDesktop = Responsive.isDesktop(context);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Content Area
        Expanded(
          flex: 7,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Filters Bar (Date, Class, Section, Mode)
                _buildTopFilterBar(state, notifier, isDesktop, theme),
                const SizedBox(height: 14),

                // 2. Mode Notification Banner
                if (state.selectedMode == AttendanceMode.allDay) _buildAllDayLockBanner(state, theme),
                const SizedBox(height: 14),

                // 3. Class Context Info Pill
                _buildClassContextPill(state, theme),
                const SizedBox(height: 16),

                // 4. Action Bar (Search + Quick Mark Buttons)
                _buildActionBar(state, notifier, isDesktop, theme),
                const SizedBox(height: 16),

                // 5. Student Attendance Table
                _buildStudentRosterTable(state, notifier, theme),
                const SizedBox(height: 16),

                // 6. Bottom Sticky Save Bar & Pagination
                _buildBottomSaveAndPaginationBar(state, notifier, theme),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),

        // Right Sidebar (Desktop only)
        if (isDesktop && _selectedDrawerStudent == null)
          Container(
            width: 320,
            padding: const EdgeInsets.only(top: 16, right: 20, left: 10, bottom: 20),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: theme.dividerColor.withOpacity(0.08))),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDaySummaryCard(state, theme),
                  const SizedBox(height: 18),
                  _buildTodaysScheduleCard(state, notifier, theme),
                  const SizedBox(height: 18),
                  _buildQuickActionsCard(state, notifier, theme),
                ],
              ),
            ),
          ),

        // Student Detail Side Drawer (if student clicked)
        if (_selectedDrawerStudent != null)
          StudentAttendanceDrawer(
            student: _selectedDrawerStudent!,
            dateStr: state.displayDateString,
            schedules: state.schedulesToday,
            onClose: () => setState(() => _selectedDrawerStudent = null),
          ),
      ],
    );
  }

  // ==========================================================================
  // 1. TOP FILTER BAR
  // ==========================================================================
  Widget _buildTopFilterBar(AttendanceState state, AttendanceNotifier notifier, bool isDesktop, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Date Navigator
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  onPressed: () => notifier.prevDay(),
                  tooltip: 'Previous Day',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                ),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: state.selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) notifier.setDate(picked);
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 6),
                      Text(
                        state.displayDateString,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  onPressed: () => notifier.nextDay(),
                  tooltip: 'Next Day',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                ),
                if (!state.isToday)
                  TextButton(
                    onPressed: () => notifier.setToday(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(40, 36),
                    ),
                    child: const Text('Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),

          // Class Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor.withOpacity(0.12)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.selectedClassId,
                hint: const Text('Select Class', style: TextStyle(fontSize: 13)),
                items: state.availableClasses.map((c) {
                  return DropdownMenuItem<String>(
                    value: c.id,
                    child: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) notifier.setClass(val);
                },
              ),
            ),
          ),

          // Section Dropdown
          if (state.selectedClassId != null) ...[
            Builder(
              builder: (context) {
                final currentClass = state.availableClasses.firstWhere(
                  (c) => c.id == state.selectedClassId,
                  orElse: () => state.availableClasses.first,
                );
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor.withOpacity(0.12)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: state.selectedSectionId,
                      hint: const Text('All Sections', style: TextStyle(fontSize: 13)),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Sections', style: TextStyle(fontSize: 13)),
                        ),
                        ...currentClass.sections.map((s) {
                          return DropdownMenuItem<String?>(
                            value: s.id,
                            child: Text('Section ${s.name}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          );
                        }),
                      ],
                      onChanged: (val) => notifier.setSection(val),
                    ),
                  ),
                );
              },
            ),
          ],

          // Attendance Mode Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AttendanceMode>(
                value: state.selectedMode,
                icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF2563EB)),
                items: AttendanceMode.values.map((m) {
                  return DropdownMenuItem<AttendanceMode>(
                    value: m,
                    child: Row(
                      children: [
                        if (m == AttendanceMode.allDay)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF2563EB)),
                          ),
                        Text(
                          m.label,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) notifier.setMode(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 2. ALL-DAY LOCK BANNER
  // ==========================================================================
  Widget _buildAllDayLockBanner(AttendanceState state, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_rounded, color: Color(0xFF16A34A), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '🔒 All-day attendance applied • Saving attendance will automatically propagate and lock all scheduled periods today.',
              style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 3. CLASS CONTEXT PILL
  // ==========================================================================
  Widget _buildClassContextPill(AttendanceState state, ThemeData theme) {
    final className = state.availableClasses.firstWhere((c) => c.id == state.selectedClassId, orElse: () => AcademicClassModel(id: '', name: 'Class', code: '', stage: '')).name;
    final total = state.stats.totalStudents;
    final present = state.stats.studentsPresent;
    final absent = state.stats.studentsAbsent;
    final lateCount = state.stats.lateEntries;
    final onLeave = state.stats.onLeave;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$className • Total: $total | Present: $present | Absent: $absent | Late: $lateCount | On Leave: $onLeave',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  // ==========================================================================
  // 4. ACTION BAR (Search + Quick Mark Buttons)
  // ==========================================================================
  Widget _buildActionBar(AttendanceState state, AttendanceNotifier notifier, bool isDesktop, ThemeData theme) {
    return Row(
      children: [
        // Search Field
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => notifier.setSearch(val),
              decoration: InputDecoration(
                hintText: 'Search by student name, roll no, admission no...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          notifier.setSearch('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Quick Mark Buttons
        OutlinedButton.icon(
          onPressed: () => notifier.markAll(AttendanceStatus.present),
          icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF10B981)),
          label: const Text('Mark All Present', style: TextStyle(fontSize: 12, color: Color(0xFF10B981))),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => notifier.markAll(AttendanceStatus.absent),
          icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
          label: const Text('Mark All Absent', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => notifier.markAll(AttendanceStatus.late),
          icon: const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFFF59E0B)),
          label: const Text('Mark All Late', style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B))),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // 5. STUDENT ROSTER TABLE
  // ==========================================================================
  Widget _buildStudentRosterTable(AttendanceState state, AttendanceNotifier notifier, ThemeData theme) {
    if (state.isLoading) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (state.roster.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: const Column(
          children: [
            Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No students found for selected class/section', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final isAllSelected = state.roster.isNotEmpty && state.selectedStudentIds.length == state.roster.length;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
              child: Row(
                children: [
                  Checkbox(
                    value: isAllSelected,
                    onChanged: (val) => notifier.selectAllStudents(val ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(width: 60, child: Text('Roll No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const Expanded(flex: 3, child: Text('Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const Expanded(flex: 4, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const Expanded(flex: 2, child: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const Expanded(flex: 2, child: Text('Last Updated', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const Divider(height: 1),

            // Student Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.roster.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final student = state.roster[index];
                final currentStatus = state.draftStatuses[student.studentId] ?? student.status;
                final isSelected = state.selectedStudentIds.contains(student.studentId);

                return InkWell(
                  onTap: () {
                    setState(() => _selectedDrawerStudent = student);
                    widget.onSelectStudent?.call(student);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => notifier.toggleStudentSelection(student.studentId),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        const SizedBox(width: 8),

                        // Roll Number
                        SizedBox(
                          width: 60,
                          child: Text(
                            student.rollNumber.isNotEmpty ? student.rollNumber : '-',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),

                        // Student Info (Avatar + Name)
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: const Color(0xFF4F46E5).withOpacity(0.12),
                                backgroundImage: student.avatarUrl != null ? NetworkImage(student.avatarUrl!) : null,
                                child: student.avatarUrl == null
                                    ? Text(
                                        student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : 'S',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Adm: ${student.admissionNumber}',
                                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Compact Interactive Status Buttons: [P] [A] [L] [O] [H] [-]
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              _buildCompactStatusButton(student, AttendanceStatus.present, currentStatus, notifier),
                              const SizedBox(width: 4),
                              _buildCompactStatusButton(student, AttendanceStatus.absent, currentStatus, notifier),
                              const SizedBox(width: 4),
                              _buildCompactStatusButton(student, AttendanceStatus.late, currentStatus, notifier),
                              const SizedBox(width: 4),
                              _buildCompactStatusButton(student, AttendanceStatus.onLeave, currentStatus, notifier),
                              const SizedBox(width: 4),
                              _buildCompactStatusButton(student, AttendanceStatus.halfDay, currentStatus, notifier),
                              const SizedBox(width: 4),
                              _buildCompactStatusButton(student, AttendanceStatus.notMarked, currentStatus, notifier),
                            ],
                          ),
                        ),

                        // Remarks
                        Expanded(
                          flex: 2,
                          child: student.remarks.isNotEmpty
                              ? Text(student.remarks, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis)
                              : Text('-', style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5))),
                        ),

                        // Last Updated
                        Expanded(
                          flex: 2,
                          child: student.lastUpdatedAt != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${student.lastUpdatedAt!.hour.toString().padLeft(2, '0')}:${student.lastUpdatedAt!.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    Text(student.updatedByName ?? 'Teacher', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                                  ],
                                )
                              : const Text('-', style: TextStyle(fontSize: 11)),
                        ),

                        // Row Menu ⋮
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, size: 18),
                          onSelected: (val) {
                            if (val == 'view') {
                              setState(() => _selectedDrawerStudent = student);
                            } else if (val == 'override') {
                              _showOverrideDialog(student, currentStatus, notifier);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'view', child: Text('View Details & History')),
                            const PopupMenuItem(value: 'override', child: Text('Override Lock with Reason')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatusButton(
    AttendanceStudentRowModel student,
    AttendanceStatus status,
    AttendanceStatus currentStatus,
    AttendanceNotifier notifier,
  ) {
    final isSelected = currentStatus == status;

    return InkWell(
      onTap: () {
        if (student.isLocked) {
          _showOverrideDialog(student, status, notifier);
        } else {
          notifier.updateStudentStatus(student.studentId, status);
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? status.color : status.backgroundColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? status.color : status.borderColor,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: status.color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          status.code,
          style: TextStyle(
            color: isSelected ? Colors.white : status.color,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  void _showOverrideDialog(AttendanceStudentRowModel student, AttendanceStatus targetStatus, AttendanceNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AttendanceOverrideDialog(
        student: student,
        targetStatus: targetStatus,
        onConfirm: (reason) {
          notifier.overrideStudentRecord(
            recordId: student.id,
            recordType: 'DAILY',
            newStatus: targetStatus,
            reason: reason,
          );
        },
      ),
    );
  }

  // ==========================================================================
  // 6. BOTTOM STICKY SAVE & PAGINATION BAR
  // ==========================================================================
  Widget _buildBottomSaveAndPaginationBar(AttendanceState state, AttendanceNotifier notifier, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Selected Count / Roster Count
          Text(
            '${state.selectedStudentIds.length} of ${state.totalCount} Students Selected',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),

          // Pagination Controls
          Row(
            children: [
              Text(
                'Page ${state.page} of ${state.totalPages}',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: state.page > 1 ? () => notifier.setPage(state.page - 1) : null,
                tooltip: 'Previous Page',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: state.page < state.totalPages ? () => notifier.setPage(state.page + 1) : null,
                tooltip: 'Next Page',
              ),
            ],
          ),

          // Save Button
          Row(
            children: [
              if (state.hasUnsavedChanges)
                TextButton(
                  onPressed: () => notifier.resetDrafts(),
                  child: const Text('Cancel Changes'),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: state.isSaving
                    ? null
                    : () {
                        final className = state.availableClasses.firstWhere((c) => c.id == state.selectedClassId, orElse: () => AcademicClassModel(id: '', name: 'Class', code: '', stage: '')).name;
                        showDialog(
                          context: context,
                          builder: (context) => AttendanceConfirmationDialog(
                            dateStr: state.displayDateString,
                            className: className,
                            sectionName: state.selectedSectionId ?? 'A',
                            modeName: state.selectedMode.label,
                            totalCount: state.roster.length,
                            presentCount: state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.present).length,
                            absentCount: state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.absent).length,
                            lateCount: state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.late).length,
                            onLeaveCount: state.roster.where((s) => (state.draftStatuses[s.studentId] ?? s.status) == AttendanceStatus.onLeave).length,
                            onConfirm: () => notifier.saveDailyAttendance(),
                          ),
                        );
                      },
                icon: state.isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_outline_rounded, size: 16),
                label: Text(state.isSaving ? 'Saving...' : 'Save Attendance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // RIGHT SIDEBAR: DAY SUMMARY DONUT CARD
  // ==========================================================================
  Widget _buildDaySummaryCard(AttendanceState state, ThemeData theme) {
    final pct = state.stats.overallAttendancePct;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Day Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('$pct%', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Donut / Breakdown Gauge
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: pct / 100.0,
                    strokeWidth: 10,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$pct%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Text('Present', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          _buildLegendRow('Present', state.stats.studentsPresent, const Color(0xFF10B981)),
          const SizedBox(height: 6),
          _buildLegendRow('Absent', state.stats.studentsAbsent, const Color(0xFFEF4444)),
          const SizedBox(height: 6),
          _buildLegendRow('Late', state.stats.lateEntries, const Color(0xFFF59E0B)),
          const SizedBox(height: 6),
          _buildLegendRow('On Leave', state.stats.onLeave, const Color(0xFF8B5CF6)),
          const SizedBox(height: 6),
          _buildLegendRow('Not Marked', state.stats.notMarked, const Color(0xFF9CA3AF)),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String label, int count, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  // ==========================================================================
  // RIGHT SIDEBAR: TODAY'S SCHEDULE CARD
  // ==========================================================================
  Widget _buildTodaysScheduleCard(AttendanceState state, AttendanceNotifier notifier, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Today's Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('${state.schedulesToday.length} Periods', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          if (state.schedulesToday.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text('No timetable periods scheduled', style: TextStyle(fontSize: 11, color: Colors.grey))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.schedulesToday.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final s = state.schedulesToday[idx];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 26,
                        decoration: BoxDecoration(color: s.subjectColor, borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${s.periodLabel} • ${s.subjectName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            Text('${s.timeRange} | ${s.teacherName}', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      if (s.isLocked)
                        const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF2563EB))
                      else if (s.isCompleted)
                        const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // RIGHT SIDEBAR: QUICK ACTIONS CARD
  // ==========================================================================
  Widget _buildQuickActionsCard(AttendanceState state, AttendanceNotifier notifier, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          _buildQuickActionButton(Icons.schedule_rounded, 'By Period Attendance', () => notifier.setMode(AttendanceMode.byPeriod)),
          const SizedBox(height: 8),
          _buildQuickActionButton(Icons.beach_access_rounded, 'Mark On Leave', () => notifier.setTab(2)),
          const SizedBox(height: 8),
          _buildQuickActionButton(Icons.bolt_rounded, 'Bulk Edit Roster', () => notifier.setTab(3)),
          const SizedBox(height: 8),
          _buildQuickActionButton(Icons.insights_rounded, 'Attendance Analytics', () => notifier.setTab(4)),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5).withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF4F46E5)),
          ],
        ),
      ),
    );
  }
}
