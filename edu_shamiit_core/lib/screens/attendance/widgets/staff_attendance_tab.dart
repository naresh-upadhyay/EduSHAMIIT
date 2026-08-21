import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../constants/app_fonts.dart';
import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';

class StaffAttendanceTab extends ConsumerStatefulWidget {
  const StaffAttendanceTab({Key? key}) : super(key: key);

  @override
  ConsumerState<StaffAttendanceTab> createState() => _StaffAttendanceTabState();
}

class _StaffAttendanceTabState extends ConsumerState<StaffAttendanceTab> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDepartment;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final departments = state.staffRoster.map((e) => e.department).where((d) => d.isNotEmpty).toSet().toList();

    var filteredStaff = state.staffRoster;
    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      filteredStaff = filteredStaff.where((s) => s.fullName.toLowerCase().contains(q) || s.employeeCode.toLowerCase().contains(q) || s.department.toLowerCase().contains(q)).toList();
    }
    if (_selectedDepartment != null) {
      filteredStaff = filteredStaff.where((s) => s.department == _selectedDepartment).toList();
    }

    final total = filteredStaff.length;
    final present = filteredStaff.where((s) => (state.draftStaffStatuses[s.employeeId] ?? s.status) == AttendanceStatus.present).length;
    final absent = filteredStaff.where((s) => (state.draftStaffStatuses[s.employeeId] ?? s.status) == AttendanceStatus.absent).length;
    final onLeave = filteredStaff.where((s) => (state.draftStaffStatuses[s.employeeId] ?? s.status) == AttendanceStatus.onLeave).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Bar
          _buildFilterBar(state, notifier, departments, isDark, theme),
          const SizedBox(height: 16),

          // Header & Stats
          Row(
            children: [
              Text(
                'Faculty & Staff Roster',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 14),
              _buildStatPill('Total Staff: $total', const Color(0xFF64748B), isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
              const SizedBox(width: 8),
              _buildStatPill('Present: $present', const Color(0xFF15803D), const Color(0xFFECFDF5)),
              const SizedBox(width: 8),
              _buildStatPill('Absent: $absent', const Color(0xFFB91C1C), const Color(0xFFFEF2F2)),
              const SizedBox(width: 8),
              _buildStatPill('On Leave: $onLeave', const Color(0xFF1D4ED8), const Color(0xFFEFF6FF)),
            ],
          ),
          const SizedBox(height: 16),

          // Staff Table
          _buildStaffTable(filteredStaff, state, notifier, isDark, theme),
          const SizedBox(height: 16),

          // Bottom Save Bar
          _buildBottomBar(state, notifier, isDark, theme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 11.5)),
    );
  }

  Widget _buildFilterBar(
    AttendanceState state,
    AttendanceNotifier notifier,
    List<String> departments,
    bool isDark,
    ThemeData theme,
  ) {
    final dateStr = DateFormat('dd MMM yyyy, EEE').format(state.selectedDate);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          // Date Navigator Pill
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left_rounded, size: 18, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                  onPressed: () => notifier.prevDay(),
                  tooltip: 'Previous Day',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 36),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    dateStr,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                  onPressed: () => notifier.nextDay(),
                  tooltip: 'Next Day',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 36),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Department Dropdown
          if (departments.isNotEmpty) ...[
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedDepartment,
                  hint: Text('All Departments', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All Departments', style: TextStyle(fontSize: 12))),
                    ...departments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))),
                  ],
                  onChanged: (val) => setState(() => _selectedDepartment = val),
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],

          // Search Field
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search staff name, designation, department, code...',
                  hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.search_rounded, size: 17, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear_rounded, size: 15), onPressed: () => setState(() => _searchController.clear()))
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Quick Mark All Present
          ElevatedButton(
            onPressed: () {
              for (final s in state.staffRoster) {
                notifier.updateStaffStatus(s.employeeId, AttendanceStatus.present);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Mark All Present', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffTable(
    List<StaffAttendanceRowModel> staffList,
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
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
              'No staff members found',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ],
        ),
      );
    }

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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              child: const Row(
                children: [
                  SizedBox(width: 80, child: Text('Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  Expanded(flex: 3, child: Text('Employee Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  Expanded(flex: 2, child: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  Expanded(flex: 3, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  Expanded(flex: 2, child: Text('Check-In / Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  Expanded(flex: 2, child: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: staffList.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final emp = staffList[index];
                final currentStatus = state.draftStaffStatuses[emp.employeeId] ?? emp.status;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          emp.employeeCode.isNotEmpty ? emp.employeeCode : 'EMP-${index + 101}',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                        ),
                      ),
                      Expanded(
                        flex: 3,
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
                                  Text(
                                    emp.designation,
                                    style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          emp.department.isNotEmpty ? emp.department : 'Academic',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildStaffStatusPill(emp, currentStatus, notifier, isDark),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          emp.checkInTime != null ? '${emp.checkInTime} - ${emp.checkOutTime ?? "Pending"}' : '08:30 AM - 04:00 PM',
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          emp.remarks.isNotEmpty ? emp.remarks : '-',
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
        _buildMenuItem(AttendanceStatus.workFromHome, 'Work From Home', Icons.home_work_rounded, const Color(0xFF06B6D4)),
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
            const SizedBox(width: 8),
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

  Widget _buildBottomBar(
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${state.staffRoster.length} Faculty & Staff Members Listed',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => notifier.resetDrafts(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: state.isSaving ? null : () => notifier.saveStaffAttendance(),
                icon: state.isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 15),
                label: Text(state.isSaving ? 'Saving...' : 'Save Staff Attendance', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
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
}
