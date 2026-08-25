import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../constants/app_fonts.dart';
import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';
import '../../classes/services/academic_lookup_helper.dart';

class StaffAttendanceTab extends ConsumerStatefulWidget {
  const StaffAttendanceTab({super.key});

  @override
  ConsumerState<StaffAttendanceTab> createState() => _StaffAttendanceTabState();
}

class _StaffAttendanceTabState extends ConsumerState<StaffAttendanceTab> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AcademicLookupHelper.instance.getActiveLookup('DEPARTMENT');
      if (mounted) {
        ref.read(attendanceProvider.notifier).fetchStaffLookups();
        ref.read(attendanceProvider.notifier).fetchStaffRoster();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Load all departments dynamically from Lookup Key-Value table ('DEPARTMENT'), state, and roster
    final Set<String> deptSet = {};
    final lookupDepts = AcademicLookupHelper.instance.getCachedLookup('DEPARTMENT');
    for (final item in lookupDepts) {
      if (item.label.isNotEmpty && item.label != 'ALL') {
        deptSet.add(item.label);
      }
    }
    for (final d in state.staffAvailableDepartments) {
      if (d.isNotEmpty && d != 'ALL') deptSet.add(d);
    }
    for (final d in state.insightsAvailableDepartments) {
      final name = d['name']?.toString() ?? d['label']?.toString();
      if (name != null && name.isNotEmpty && name != 'ALL' && name != 'All Departments') {
        deptSet.add(name);
      }
    }
    for (final s in state.staffRoster) {
      if (s.department.isNotEmpty && s.department != 'ALL') {
        deptSet.add(s.department);
      }
    }
    if (state.staffDepartmentFilter.isNotEmpty && state.staffDepartmentFilter != 'ALL') {
      deptSet.add(state.staffDepartmentFilter);
    }
    final departments = deptSet.toList()..sort();

    final staffList = state.staffRoster;
    final totalCount = state.staffTotalCount > 0 ? state.staffTotalCount : staffList.length;

    // Compute live stats considering draft changes
    int presentCount = 0;
    int absentCount = 0;
    int lateCount = 0;
    int onLeaveCount = 0;
    int halfDayCount = 0;
    int wfhCount = 0;
    int notMarkedCount = 0;

    for (final s in staffList) {
      final effectiveStatus = state.draftStaffStatuses[s.employeeId] ?? s.status;
      switch (effectiveStatus) {
        case AttendanceStatus.present:
          presentCount++;
          break;
        case AttendanceStatus.absent:
          absentCount++;
          break;
        case AttendanceStatus.late:
          lateCount++;
          break;
        case AttendanceStatus.onLeave:
          onLeaveCount++;
          break;
        case AttendanceStatus.halfDay:
          halfDayCount++;
          break;
        case AttendanceStatus.workFromHome:
          wfhCount++;
          break;
        default:
          notMarkedCount++;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP FILTER & MANAGER SCOPE ACTION BAR
          _buildTopFilterBar(state, notifier, departments, isDark, theme),
          const SizedBox(height: 16),

          // 2. SUMMARY KPI STATS BADGES
          _buildKpiSummaryRow(
            total: totalCount,
            present: presentCount,
            absent: absentCount,
            late: lateCount,
            onLeave: onLeaveCount,
            halfDay: halfDayCount,
            wfh: wfhCount,
            notMarked: notMarkedCount,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // 3. BULK MULTI-SELECTION FLOATING ACTION BAR (if rows selected)
          if (state.selectedStaffIds.isNotEmpty) ...[
            _buildBulkSelectionBar(state, notifier, isDark, theme),
            const SizedBox(height: 14),
          ],

          // 4. ENTERPRISE DATA GRID
          _buildStaffTable(staffList, state, notifier, isDark, theme),
          const SizedBox(height: 16),

          // 5. STICKY BOTTOM SAVE & PAGINATION BAR
          _buildBottomBar(state, notifier, isDark, theme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==========================================================================
  // 1. TOP FILTER & MANAGER SCOPE BAR
  // ==========================================================================
  Widget _buildTopFilterBar(
    AttendanceState state,
    AttendanceNotifier notifier,
    List<String> departments,
    bool isDark,
    ThemeData theme,
  ) {
    final dateStr = DateFormat('dd MMM yyyy, EEE').format(state.selectedDate);
    final isDeptValid = state.staffDepartmentFilter == 'ALL' || departments.contains(state.staffDepartmentFilter);
    final effectiveDept = isDeptValid ? state.staffDepartmentFilter : 'ALL';

    const validStatuses = [
      'ALL',
      'PRESENT',
      'ABSENT',
      'LATE',
      'ON_LEAVE',
      'HALF_DAY',
      'WORK_FROM_HOME',
      'NOT_MARKED',
    ];
    final effectiveStatus = validStatuses.contains(state.staffStatusFilter)
        ? state.staffStatusFilter
        : 'ALL';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Date Navigator, Manager Scope Toggle, Quick Mark All Buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Date Navigator Pill
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left_rounded, size: 20, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                      onPressed: () => notifier.prevDay(),
                      tooltip: 'Previous Day',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
                    ),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: state.selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) notifier.setDate(picked);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                            const SizedBox(width: 8),
                            Text(
                              dateStr,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                      onPressed: () => notifier.nextDay(),
                      tooltip: 'Next Day',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
                    ),
                  ],
                ),
              ),

              // Manager Scope Toggle: "My Direct Reports Only" vs "All Staff"
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // All Staff Option
                    InkWell(
                      onTap: () => notifier.setStaffManagerOnlyFilter(false),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: !state.staffManagerOnlyFilter ? (isDark ? const Color(0xFF334155) : Colors.white) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                          boxShadow: !state.staffManagerOnlyFilter
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.business_rounded,
                              size: 15,
                              color: !state.staffManagerOnlyFilter ? (isDark ? Colors.white : const Color(0xFF0F172A)) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'All Staff',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: !state.staffManagerOnlyFilter ? FontWeight.w700 : FontWeight.w500,
                                color: !state.staffManagerOnlyFilter ? (isDark ? Colors.white : const Color(0xFF0F172A)) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // My Direct Reports Option
                    InkWell(
                      onTap: () => notifier.setStaffManagerOnlyFilter(true),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: state.staffManagerOnlyFilter ? const Color(0xFF4F46E5) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                          boxShadow: state.staffManagerOnlyFilter
                              ? [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.groups_rounded,
                              size: 15,
                              color: state.staffManagerOnlyFilter ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              state.directReportsCount > 0 ? 'My Team (${state.directReportsCount})' : 'My Team (Direct Reports)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: state.staffManagerOnlyFilter ? FontWeight.w700 : FontWeight.w500,
                                color: state.staffManagerOnlyFilter ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bulk Quick-Mark Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => notifier.markAllStaff(AttendanceStatus.present),
                    icon: const Icon(Icons.check_circle_rounded, size: 15),
                    label: const Text('Mark All Present', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => notifier.markAllStaff(AttendanceStatus.absent),
                    icon: const Icon(Icons.cancel_rounded, size: 15),
                    label: const Text('Mark All Absent', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => notifier.markAllStaff(AttendanceStatus.late),
                    icon: const Icon(Icons.access_time_filled_rounded, size: 15),
                    label: const Text('Mark All Late', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'More Actions',
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (val) {
                      if (val == 'ON_LEAVE') notifier.markAllStaff(AttendanceStatus.onLeave);
                      if (val == 'HALF_DAY') notifier.markAllStaff(AttendanceStatus.halfDay);
                      if (val == 'WFH') notifier.markAllStaff(AttendanceStatus.workFromHome);
                      if (val == 'RESET') notifier.resetStaffDrafts();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'ON_LEAVE',
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, size: 15, color: Color(0xFF3B82F6)),
                            SizedBox(width: 8),
                            Text('Mark All On Leave', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'HALF_DAY',
                        child: Row(
                          children: [
                            Icon(Icons.pie_chart_rounded, size: 15, color: Color(0xFF8B5CF6)),
                            SizedBox(width: 8),
                            Text('Mark All Half Day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'WFH',
                        child: Row(
                          children: [
                            Icon(Icons.home_work_rounded, size: 15, color: Color(0xFF06B6D4)),
                            SizedBox(width: 8),
                            Text('Mark All Work From Home', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'RESET',
                        child: Row(
                          children: [
                            Icon(Icons.restart_alt_rounded, size: 15, color: Color(0xFF64748B)),
                            SizedBox(width: 8),
                            Text('Reset All Drafts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Text('More Actions', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Search Input, Department Dropdown, Status Filter Dropdown
          Row(
            children: [
              // Search Input
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (q) => notifier.setStaffSearch(q),
                    style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search staff name, code, designation, department...',
                      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded, size: 17, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 15),
                              onPressed: () {
                                _searchController.clear();
                                notifier.setStaffSearch('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Department Dropdown
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: effectiveDept,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    items: [
                      const DropdownMenuItem(value: 'ALL', child: Text('All Departments', style: TextStyle(fontWeight: FontWeight.w600))),
                      ...departments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontWeight: FontWeight.w600)))),
                    ],
                    onChanged: (val) {
                      if (val != null) notifier.setStaffDepartmentFilter(val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Status Filter Dropdown
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: effectiveStatus,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Statuses', style: TextStyle(fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 'PRESENT', child: Text('Present', style: TextStyle(fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 'ABSENT', child: Text('Absent', style: TextStyle(fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 'LATE', child: Text('Late', style: TextStyle(fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 'ON_LEAVE', child: Text('On Leave', style: TextStyle(fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 'HALF_DAY', child: Text('Half Day', style: TextStyle(fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 'WORK_FROM_HOME', child: Text('Work From Home', style: TextStyle(fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 'NOT_MARKED', child: Text('Not Marked', style: TextStyle(fontWeight: FontWeight.w600))),
                    ],
                    onChanged: (val) {
                      if (val != null) notifier.setStaffStatusFilter(val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 2. SUMMARY KPI STATS BADGES
  // ==========================================================================
  Widget _buildKpiSummaryRow({
    required int total,
    required int present,
    required int absent,
    required int late,
    required int onLeave,
    required int halfDay,
    required int wfh,
    required int notMarked,
    required bool isDark,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatPill('Total Staff: $total', const Color(0xFF64748B), isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          const SizedBox(width: 8),
          _buildStatPill('Present: $present', const Color(0xFF15803D), const Color(0xFFECFDF5)),
          const SizedBox(width: 8),
          _buildStatPill('Absent: $absent', const Color(0xFFB91C1C), const Color(0xFFFEF2F2)),
          const SizedBox(width: 8),
          _buildStatPill('Late: $late', const Color(0xFFB45309), const Color(0xFFFFFBEB)),
          const SizedBox(width: 8),
          _buildStatPill('On Leave: $onLeave', const Color(0xFF1D4ED8), const Color(0xFFEFF6FF)),
          const SizedBox(width: 8),
          _buildStatPill('Half Day: $halfDay', const Color(0xFF6B21A8), const Color(0xFFFAF5FF)),
          const SizedBox(width: 8),
          _buildStatPill('WFH: $wfh', const Color(0xFF0E7490), const Color(0xFFECFEFF)),
          const SizedBox(width: 8),
          if (notMarked > 0)
            _buildStatPill('Not Marked: $notMarked', const Color(0xFF64748B), isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 11.5)),
    );
  }

  // ==========================================================================
  // 3. BULK SELECTION ACTION BAR
  // ==========================================================================
  Widget _buildBulkSelectionBar(
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    final count = state.selectedStaffIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count Selected',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          const Text('Mark Selected As:', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),

          // Quick mark selected
          Wrap(
            spacing: 6,
            children: [
              _buildBulkBtn('Present', const Color(0xFF10B981), () => notifier.markSelectedStaff(AttendanceStatus.present)),
              _buildBulkBtn('Absent', const Color(0xFFEF4444), () => notifier.markSelectedStaff(AttendanceStatus.absent)),
              _buildBulkBtn('Late', const Color(0xFFF59E0B), () => notifier.markSelectedStaff(AttendanceStatus.late)),
              _buildBulkBtn('On Leave', const Color(0xFF3B82F6), () => notifier.markSelectedStaff(AttendanceStatus.onLeave)),
              _buildBulkBtn('WFH', const Color(0xFF06B6D4), () => notifier.markSelectedStaff(AttendanceStatus.workFromHome)),
              _buildBulkBtn('Set Check-In', const Color(0xFF059669), () => _showBulkTimePickerDialog(context, isCheckIn: true, notifier: notifier)),
              _buildBulkBtn('Set Check-Out', const Color(0xFF7C3AED), () => _showBulkTimePickerDialog(context, isCheckIn: false, notifier: notifier)),
            ],
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => notifier.selectAllStaff(false),
            icon: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            label: const Text('Deselect All', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkBtn(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ==========================================================================
  // 4. ENTERPRISE DATA GRID TABLE
  // ==========================================================================
  Widget _buildStaffTable(
    List<StaffAttendanceRowModel> staffList,
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    if (state.isStaffLoading && staffList.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading faculty & staff attendance roster...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    if (staffList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(Icons.badge_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              state.staffManagerOnlyFilter ? 'No direct reports found under your manager profile' : 'No staff members found matching filters',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ],
        ),
      );
    }

    final isAllSelected = staffList.isNotEmpty && staffList.every((s) => state.selectedStaffIds.contains(s.employeeId));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Linear Progress Indicator when re-fetching or filtering in background
            if (state.isStaffLoading)
              const LinearProgressIndicator(
                minHeight: 2.5,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              ),

            // TABLE HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  // Select All Checkbox
                  SizedBox(
                    width: 36,
                    child: Checkbox(
                      value: isAllSelected,
                      onChanged: (val) => notifier.selectAllStaff(val == true),
                      activeColor: const Color(0xFF4F46E5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 70, child: Text('Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  const Expanded(flex: 4, child: Text('Employee Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  const Expanded(flex: 2, child: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  const Expanded(flex: 3, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  const Expanded(flex: 2, child: Text('Check-In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  const Expanded(flex: 2, child: Text('Check-Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  const Expanded(flex: 2, child: Text('Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  const Expanded(flex: 3, child: Text('Remarks / Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),

            // TABLE ROWS
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: staffList.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final emp = staffList[index];
                final isSelected = state.selectedStaffIds.contains(emp.employeeId);
                final currentStatus = state.draftStaffStatuses[emp.employeeId] ?? emp.status;
                final checkIn = state.draftStaffCheckIns[emp.employeeId] ?? emp.checkInTime;
                final checkOut = state.draftStaffCheckOuts[emp.employeeId] ?? emp.checkOutTime;
                final remarks = state.draftStaffRemarks[emp.employeeId] ?? emp.remarks;

                // Duration Calculation
                final durationStr = _calculateWorkingDuration(checkIn, checkOut);

                return Container(
                  color: isSelected
                      ? (isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.5) : const Color(0xFFEEF2FF).withValues(alpha: 0.7))
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Row Checkbox
                      SizedBox(
                        width: 36,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => notifier.toggleStaffSelection(emp.employeeId),
                          activeColor: const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),

                      // Code
                      SizedBox(
                        width: 70,
                        child: Text(
                          emp.employeeCode.isNotEmpty ? emp.employeeCode : 'EMP-${index + 101}',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                        ),
                      ),

                      // Employee Name + Avatar + Designation
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
                              ),
                              child: ClipOval(
                                child: emp.avatarUrl != null
                                    ? Image.network(emp.avatarUrl!, fit: BoxFit.cover)
                                    : Center(
                                        child: Text(
                                          emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'E',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5)),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    emp.fullName,
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        emp.designation,
                                        style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      ),
                                      if (emp.managerName != null && emp.managerName!.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Mgr: ${emp.managerName}',
                                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Department Badge
                      Expanded(
                        flex: 2,
                        child: Text(
                          emp.department.isNotEmpty ? emp.department : 'General',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                        ),
                      ),

                      // Status Dropdown Pill
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildStaffStatusPill(emp, currentStatus, notifier, isDark),
                        ),
                      ),

                      // Separate Check-In Time Button
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildTimePickerPill(
                            context: context,
                            timeStr: checkIn,
                            isCheckIn: true,
                            onTimePicked: (newTime) => notifier.updateStaffCheckInTime(emp.employeeId, newTime),
                            isDark: isDark,
                          ),
                        ),
                      ),

                      // Separate Check-Out Time Button
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildTimePickerPill(
                            context: context,
                            timeStr: checkOut,
                            isCheckIn: false,
                            onTimePicked: (newTime) => notifier.updateStaffCheckOutTime(emp.employeeId, newTime),
                            isDark: isDark,
                          ),
                        ),
                      ),

                      // Working Duration Badge
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              durationStr,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: durationStr == '--' ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)) : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Inline Remarks / Comments Field
                      Expanded(
                        flex: 3,
                        child: _buildStaffRemarksCell(emp, remarks, notifier, isDark),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // STATUS PILL DROPDOWN
  // ==========================================================================
  Widget _buildStaffStatusPill(
    StaffAttendanceRowModel emp,
    AttendanceStatus status,
    AttendanceNotifier notifier,
    bool isDark,
  ) {
    Color bg;
    Color text;
    Color border;
    IconData icon;

    switch (status) {
      case AttendanceStatus.present:
        bg = const Color(0xFFECFDF5);
        text = const Color(0xFF15803D);
        border = const Color(0xFFBBF7D0);
        icon = Icons.check_rounded;
        break;
      case AttendanceStatus.absent:
        bg = const Color(0xFFFEF2F2);
        text = const Color(0xFFB91C1C);
        border = const Color(0xFFFECACA);
        icon = Icons.close_rounded;
        break;
      case AttendanceStatus.late:
        bg = const Color(0xFFFFFBEB);
        text = const Color(0xFFB45309);
        border = const Color(0xFFFDE68A);
        icon = Icons.access_time_filled_rounded;
        break;
      case AttendanceStatus.onLeave:
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        border = const Color(0xFFBFDBFE);
        icon = Icons.calendar_month_rounded;
        break;
      case AttendanceStatus.halfDay:
        bg = const Color(0xFFFAF5FF);
        text = const Color(0xFF6B21A8);
        border = const Color(0xFFE9D5FF);
        icon = Icons.pie_chart_rounded;
        break;
      case AttendanceStatus.workFromHome:
        bg = const Color(0xFFECFEFF);
        text = const Color(0xFF0E7490);
        border = const Color(0xFFA5F3FC);
        icon = Icons.home_work_rounded;
        break;
      default:
        bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        text = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        icon = Icons.remove_rounded;
    }

    return PopupMenuButton<AttendanceStatus>(
      tooltip: 'Change Status for ${emp.fullName}',
      offset: const Offset(0, 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (newStatus) => notifier.updateStaffStatus(emp.employeeId, newStatus),
      itemBuilder: (context) => [
        _buildMenuItem(AttendanceStatus.present, 'Present', Icons.check_rounded, const Color(0xFF10B981)),
        _buildMenuItem(AttendanceStatus.absent, 'Absent', Icons.close_rounded, const Color(0xFFEF4444)),
        _buildMenuItem(AttendanceStatus.late, 'Late', Icons.access_time_filled_rounded, const Color(0xFFF59E0B)),
        _buildMenuItem(AttendanceStatus.onLeave, 'On Leave', Icons.calendar_month_rounded, const Color(0xFF3B82F6)),
        _buildMenuItem(AttendanceStatus.halfDay, 'Half Day', Icons.pie_chart_rounded, const Color(0xFF8B5CF6)),
        _buildMenuItem(AttendanceStatus.workFromHome, 'Work From Home', Icons.home_work_rounded, const Color(0xFF06B6D4)),
        _buildMenuItem(AttendanceStatus.notMarked, 'Reset (Not Marked)', Icons.remove_rounded, const Color(0xFF94A3B8)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status.label, style: TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 11.5)),
            const SizedBox(width: 6),
            Icon(icon, size: 14, color: text),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<AttendanceStatus> _buildMenuItem(AttendanceStatus status, String label, IconData icon, Color color) {
    return PopupMenuItem(
      value: status,
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ==========================================================================
  // SEPARATE CHECK-IN & CHECK-OUT TIME PILLS
  // ==========================================================================
  Widget _buildTimePickerPill({
    required BuildContext context,
    required String? timeStr,
    required bool isCheckIn,
    required ValueChanged<String?> onTimePicked,
    required bool isDark,
  }) {
    final hasTime = timeStr != null && timeStr.isNotEmpty && timeStr != '--';
    final formattedTime = hasTime ? _formatDisplayTime(timeStr) : '--:--';

    return Tooltip(
      message: 'Click to set ${isCheckIn ? "Check-In" : "Check-Out"} Time',
      child: InkWell(
        onTap: () => _showIndividualTimePickerDialog(
          context: context,
          isCheckIn: isCheckIn,
          initialTimeStr: timeStr,
          onTimeSelected: onTimePicked,
        ),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: hasTime
                ? (isCheckIn ? const Color(0xFFECFDF5) : const Color(0xFFEEF2FF))
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: hasTime
                  ? (isCheckIn ? const Color(0xFFA7F3D0) : const Color(0xFFC7D2FE))
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 13,
                color: hasTime
                    ? (isCheckIn ? const Color(0xFF059669) : const Color(0xFF4F46E5))
                    : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 5),
              Text(
                formattedTime,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: hasTime ? FontWeight.w700 : FontWeight.w500,
                  color: hasTime
                      ? (isCheckIn ? const Color(0xFF047857) : const Color(0xFF4338CA))
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // INLINE REMARKS CELL
  // ==========================================================================
  Widget _buildStaffRemarksCell(
    StaffAttendanceRowModel emp,
    String remarks,
    AttendanceNotifier notifier,
    bool isDark,
  ) {
    final hasRemarks = remarks.isNotEmpty && remarks != '-';

    return Tooltip(
      message: hasRemarks ? remarks : 'Click to add a remark/comment',
      child: InkWell(
        onTap: () => _showRemarksEditDialog(
          context: context,
          emp: emp,
          currentRemarks: remarks,
          onRemarksSaved: (val) => notifier.updateStaffRemarks(emp.employeeId, val),
        ),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: hasRemarks ? const Color(0xFF6366F1).withValues(alpha: 0.4) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasRemarks ? Icons.chat_bubble_outline_rounded : Icons.edit_note_rounded,
                size: 13,
                color: hasRemarks ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasRemarks ? remarks : '+ Add remark...',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: hasRemarks ? FontStyle.normal : FontStyle.italic,
                    color: hasRemarks ? (isDark ? Colors.white : const Color(0xFF0F172A)) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // 5. STICKY BOTTOM SAVE & PAGINATION BAR
  // ==========================================================================
  Widget _buildBottomBar(
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    final hasChanges = state.hasUnsavedStaffChanges;
    final totalCount = state.staffTotalCount > 0 ? state.staffTotalCount : state.staffRoster.length;
    final currentPage = state.staffPage;
    final pageSize = state.staffPageSize;
    final calculatedPages = (totalCount / pageSize).ceil();
    final totalPages = state.staffTotalPages > 0
        ? state.staffTotalPages
        : (calculatedPages > 0 ? calculatedPages : 1);

    final startItem = totalCount == 0 ? 0 : ((currentPage - 1) * pageSize) + 1;
    final endItem = (currentPage * pageSize) > totalCount ? totalCount : (currentPage * pageSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          // Left: Showing count
          Text(
            'Showing $startItem to $endItem of $totalCount Faculty & Staff',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),

          // Center: Records Per Page dropdown & Page Navigation Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Records Per Page Selector
              Text(
                'Records per page:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: [10, 25, 50, 100].contains(pageSize) ? pageSize : 10,
                    onChanged: state.isStaffLoading
                        ? null
                        : (val) {
                            if (val != null) notifier.setStaffPageSize(val);
                          },
                    isDense: true,
                    borderRadius: BorderRadius.circular(8),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    items: const [10, 25, 50, 100].map((size) {
                      return DropdownMenuItem<int>(
                        value: size,
                        child: Text('$size'),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Page navigation controls
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                onPressed: (currentPage > 1 && !state.isStaffLoading)
                    ? () => notifier.setStaffPage(currentPage - 1)
                    : null,
                tooltip: 'Previous Page',
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$currentPage / $totalPages',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                onPressed: (currentPage < totalPages && !state.isStaffLoading)
                    ? () => notifier.setStaffPage(currentPage + 1)
                    : null,
                tooltip: 'Next Page',
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
              ),
            ],
          ),

          // Right: Action buttons (Cancel Drafts & Save Staff Attendance)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasChanges) ...[
                OutlinedButton(
                  onPressed: () => notifier.resetStaffDrafts(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel Drafts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
              ],
              ElevatedButton.icon(
                onPressed: state.isSaving ? null : () => notifier.saveStaffAttendance(),
                icon: state.isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 15),
                label: Text(
                  state.isSaving ? 'Saving...' : (hasChanges ? 'Save Staff Attendance (Drafts Pending)' : 'Save Staff Attendance'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasChanges ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TIME PICKER & REMARKS DIALOG HELPERS
  // ==========================================================================
  void _showIndividualTimePickerDialog({
    required BuildContext context,
    required bool isCheckIn,
    required String? initialTimeStr,
    required ValueChanged<String?> onTimeSelected,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => _TimePickerDialog(
        title: isCheckIn ? 'Set Check-In Time' : 'Set Check-Out Time',
        isCheckIn: isCheckIn,
        initialTimeStr: initialTimeStr,
        onTimeSelected: onTimeSelected,
      ),
    );
  }

  void _showBulkTimePickerDialog(
    BuildContext context, {
    required bool isCheckIn,
    required AttendanceNotifier notifier,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => _TimePickerDialog(
        title: isCheckIn ? 'Bulk Set Check-In Time' : 'Bulk Set Check-Out Time',
        isCheckIn: isCheckIn,
        initialTimeStr: null,
        onTimeSelected: (timeStr) {
          if (timeStr != null) {
            if (isCheckIn) {
              notifier.bulkSetStaffCheckIn(timeStr);
            } else {
              notifier.bulkSetStaffCheckOut(timeStr);
            }
          }
        },
      ),
    );
  }

  void _showRemarksEditDialog({
    required BuildContext context,
    required StaffAttendanceRowModel emp,
    required String currentRemarks,
    required ValueChanged<String> onRemarksSaved,
  }) {
    final controller = TextEditingController(text: currentRemarks == '-' ? '' : currentRemarks);

    final presets = [
      '🏢 Official Duty / Field Work',
      '🕒 Approved Late Arrival',
      '🏃 Approved Early Departure',
      '🏠 Remote Work / Approved WFH',
      '🩺 Medical / Doctor Appointment',
      '🏖️ Personal Permission Granted',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          title: Text(
            'Remarks for ${emp.fullName}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick Presets:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: presets.map((p) {
                    return InkWell(
                      onTap: () {
                        controller.text = p;
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(p, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Enter specific remarks or comments here...',
                    hintStyle: const TextStyle(fontSize: 12),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                onRemarksSaved(controller.text.trim());
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Remark'),
            ),
          ],
        );
      },
    );
  }

  String _formatDisplayTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        int hr = int.parse(parts[0]);
        int min = int.parse(parts[1]);
        final ampm = hr >= 12 ? 'PM' : 'AM';
        final displayHr = hr == 0 ? 12 : (hr > 12 ? hr - 12 : hr);
        final displayMin = min.toString().padLeft(2, '0');
        return '$displayHr:$displayMin $ampm';
      }
    } catch (_) {}
    return timeStr;
  }

  String _calculateWorkingDuration(String? checkIn, String? checkOut) {
    if (checkIn == null || checkIn.isEmpty || checkIn == '--') return '--';
    if (checkOut == null || checkOut.isEmpty || checkOut == '--') return 'In Progress';

    try {
      final inParts = checkIn.split(':');
      final outParts = checkOut.split(':');
      if (inParts.length >= 2 && outParts.length >= 2) {
        final inMin = (int.parse(inParts[0]) * 60) + int.parse(inParts[1]);
        final outMin = (int.parse(outParts[0]) * 60) + int.parse(outParts[1]);
        final diff = outMin - inMin;
        if (diff < 0) return '--';
        final hrs = diff ~/ 60;
        final mins = diff % 60;
        return '${hrs}h ${mins.toString().padLeft(2, '0')}m';
      }
    } catch (_) {}
    return '--';
  }
}

// ============================================================================
// TIME PICKER DIALOG WIDGET
// ============================================================================
class _TimePickerDialog extends StatefulWidget {
  final String title;
  final bool isCheckIn;
  final String? initialTimeStr;
  final ValueChanged<String?> onTimeSelected;

  const _TimePickerDialog({
    required this.title,
    required this.isCheckIn,
    required this.initialTimeStr,
    required this.onTimeSelected,
  });

  @override
  State<_TimePickerDialog> createState() => _TimePickerDialogState();
}

class _TimePickerDialogState extends State<_TimePickerDialog> {
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = _parseTimeOfDay(widget.initialTimeStr) ??
        (widget.isCheckIn ? const TimeOfDay(hour: 8, minute: 30) : const TimeOfDay(hour: 16, minute: 30));
  }

  TimeOfDay? _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty || timeStr == '--') return null;
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return null;
  }

  String _formatTo24Hr(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inPresets = [
      const TimeOfDay(hour: 8, minute: 0),
      const TimeOfDay(hour: 8, minute: 30),
      const TimeOfDay(hour: 9, minute: 0),
      const TimeOfDay(hour: 9, minute: 30),
    ];

    final outPresets = [
      const TimeOfDay(hour: 15, minute: 30),
      const TimeOfDay(hour: 16, minute: 0),
      const TimeOfDay(hour: 16, minute: 30),
      const TimeOfDay(hour: 17, minute: 0),
    ];

    final presets = widget.isCheckIn ? inPresets : outPresets;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Selected Time Display Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Selected Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                      const SizedBox(height: 2),
                      Text(
                        _selectedTime.format(context),
                        style: const TextStyle(fontFamily: AppFonts.heading, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                      if (picked != null) setState(() => _selectedTime = picked);
                    },
                    icon: const Icon(Icons.access_time_rounded, size: 15),
                    label: const Text('Custom Picker'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Presets
            const Text('Quick Time Presets:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InkWell(
                  onTap: () => setState(() => _selectedTime = TimeOfDay.now()),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: const Text('⚡ Now (Current Time)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                  ),
                ),
                ...presets.map((p) {
                  final isSelected = p.hour == _selectedTime.hour && p.minute == _selectedTime.minute;
                  return InkWell(
                    onTap: () => setState(() => _selectedTime = p),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                      ),
                      child: Text(
                        p.format(context),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onTimeSelected(null);
            Navigator.of(context).pop();
          },
          child: const Text('Clear Time', style: TextStyle(color: Color(0xFFEF4444))),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onTimeSelected(_formatTo24Hr(_selectedTime));
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Set Time'),
        ),
      ],
    );
  }
}
