import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../models/live_class_models.dart';
import '../providers/live_class_management_provider.dart';
import '../utils/live_class_theme.dart';
import '../widgets/live_class_stat_card.dart';
import '../widgets/manual_attendance_dialog.dart';

class AttendanceTab extends ConsumerStatefulWidget {
  const AttendanceTab({super.key});

  @override
  ConsumerState<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends ConsumerState<AttendanceTab> {
  String _selectedSubnav = 'Class Attendance';
  String _activeStatusFilter = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  // Selected dropdown filters
  String _selectedClass = 'Class 10 - A';
  String _selectedSubject = 'Mathematics';
  String _selectedDate = 'Tue, 21 Jan 2025';
  String _selectedSession = '08:00 AM - 08:45 AM';

  // Rule checkboxes
  bool _ruleMinDuration = true;
  bool _ruleJoinLeave = true;
  bool _ruleEngagement = true;

  // Theme helper getters
  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get cardBg => isDark ? const Color(0xFF13182C) : Colors.white;
  Color get cardBorder => isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0);
  Color get cardDivider => isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get headerRowBg => isDark ? const Color(0xFF1A2238) : const Color(0xFFF8FAFC);
  Color get inputBg => isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get selectedRowBg => isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showOverrideDialog(AttendanceItem item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ManualAttendanceDialog(student: item),
    );
  }

  void _triggerAutoMark() {
    final state = ref.read(liveClassManagementProvider);
    final activeClass = state.joinDashboard?.activeSession;
    if (activeClass != null) {
      ref.read(liveClassManagementProvider.notifier).autoCalculateAttendance(activeClass.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto-marking attendance from connection segments...')),
      );
    } else {
      ref.read(liveClassManagementProvider.notifier).refreshAttendance();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto-marked attendance successfully for current session.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveClassManagementProvider);
    final dashboard = state.attendanceDashboard;
    final allAttendance = state.attendanceList;

    // Filter by status tab
    final filteredList = allAttendance.where((item) {
      if (_activeStatusFilter == 'All') return true;
      if (_activeStatusFilter == 'Present' && item.status.toLowerCase() == 'present') return true;
      if (_activeStatusFilter == 'Absent' && item.status.toLowerCase() == 'absent') return true;
      if (_activeStatusFilter == 'Late' && item.status.toLowerCase() == 'late') return true;
      if (_activeStatusFilter == 'Not Joined' && (item.status.toLowerCase() == 'not_joined' || item.status.toLowerCase() == 'not joined')) return true;
      return false;
    }).toList();

    final presentCount = allAttendance.where((e) => e.status.toLowerCase() == 'present').length;
    final absentCount = allAttendance.where((e) => e.status.toLowerCase() == 'absent').length;
    final lateCount = allAttendance.where((e) => e.status.toLowerCase() == 'late').length;
    final notJoinedCount = allAttendance.where((e) => e.status.toLowerCase() == 'not_joined').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top KPI Row (7 Cards matching Image 3)
          _buildKpiRow(dashboard),
          const SizedBox(height: 16),

          // 2. Main Middle Workspace (Subnav + Center Table + Right Summary & Trend)
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 950;
              final isMedium = constraints.maxWidth < 1250;

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHorizontalSubnav(),
                    const SizedBox(height: 12),
                    _buildAttendanceTableSection(
                      filteredList,
                      allAttendance.length,
                      presentCount,
                      absentCount,
                      lateCount,
                      notJoinedCount,
                    ),
                    const SizedBox(height: 12),
                    _buildRightPanel(dashboard, presentCount, absentCount, lateCount, notJoinedCount),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: isMedium ? 180 : 200,
                    child: _buildLeftSubnav(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 7,
                    child: _buildAttendanceTableSection(
                      filteredList,
                      allAttendance.length,
                      presentCount,
                      absentCount,
                      lateCount,
                      notJoinedCount,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: isMedium ? 5 : 4,
                    child: _buildRightPanel(dashboard, presentCount, absentCount, lateCount, notJoinedCount),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // 3. Bottom Row: Quick Actions, Auto Rules, Export & Reports
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 950) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildQuickActionsCard(),
                    const SizedBox(height: 12),
                    _buildAutoRulesCard(),
                    const SizedBox(height: 12),
                    _buildExportReportsCard(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildQuickActionsCard(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _buildAutoRulesCard(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _buildExportReportsCard(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalSubnav() {
    final items = [
      (Icons.how_to_reg_outlined, 'Class Attendance'),
      (Icons.person_outline_rounded, 'Student Attendance'),
      (Icons.menu_book_outlined, 'Subject Attendance'),
      (Icons.calendar_today_outlined, 'Daily Attendance'),
      (Icons.date_range_outlined, 'Weekly / Monthly'),
      (Icons.description_outlined, 'Attendance Reports'),
      (Icons.notification_important_outlined, 'Absence & Follow-up'),
      (Icons.settings_outlined, 'Attendance Settings'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mark Attendance triggered for selected session.')),
                );
              },
              icon: const Icon(Icons.fact_check_outlined, size: 14),
              label: const Text('Mark', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(width: 8),
            ...items.map((item) {
              final isSelected = _selectedSubnav == item.$2;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  avatar: Icon(
                    item.$1,
                    size: 14,
                    color: isSelected ? Colors.white : textSecondary,
                  ),
                  label: Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF1D4ED8),
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  checkmarkColor: Colors.white,
                  showCheckmark: false,
                  onSelected: (val) {
                    setState(() => _selectedSubnav = item.$2);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(AttendanceDashboardData? data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1500) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 175,
                  child: LiveClassStatCard(
                    title: 'Total Sessions',
                    value: '${data?.totalSessions ?? 248}',
                    icon: Icons.assignment_outlined,
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 195,
                  child: LiveClassStatCard(
                    title: 'Attendance Marked',
                    value: '${data?.attendanceMarked ?? 236} (${data?.attendanceMarkedPct ?? 95.2}%)',
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 180,
                  child: LiveClassStatCard(
                    title: 'Total Participants',
                    value: '${data?.totalParticipants ?? '9,842'}',
                    icon: Icons.groups_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 185,
                  child: LiveClassStatCard(
                    title: 'Present',
                    value: '${data?.presentCount ?? '9,121'} (${data?.presentPct ?? 92.7}%)',
                    icon: Icons.how_to_reg_rounded,
                    iconColor: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 175,
                  child: LiveClassStatCard(
                    title: 'Absent',
                    value: '${data?.absentCount ?? '721'} (${data?.absentPct ?? 7.3}%)',
                    icon: Icons.person_off_rounded,
                    iconColor: const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 175,
                  child: LiveClassStatCard(
                    title: 'Avg. Attendance',
                    value: '${data?.avgAttendancePct ?? 92.7}%',
                    icon: Icons.bar_chart_rounded,
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 165,
                  child: LiveClassStatCard(
                    title: 'This Week',
                    value: '${data?.thisWeekPct ?? 92.9}%',
                    subtitle: '+1.4%',
                    icon: Icons.trending_up_rounded,
                    iconColor: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          );
        }
        return Row(
          children: [
            Expanded(
              child: LiveClassStatCard(
                title: 'Total Sessions',
                value: '${data?.totalSessions ?? 248}',
                icon: Icons.assignment_outlined,
                iconColor: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'Attendance Marked',
                value: '${data?.attendanceMarked ?? 236} (${data?.attendanceMarkedPct ?? 95.2}%)',
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'Total Participants',
                value: '${data?.totalParticipants ?? '9,842'}',
                icon: Icons.groups_rounded,
                iconColor: const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'Present',
                value: '${data?.presentCount ?? '9,121'} (${data?.presentPct ?? 92.7}%)',
                icon: Icons.how_to_reg_rounded,
                iconColor: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'Absent',
                value: '${data?.absentCount ?? '721'} (${data?.absentPct ?? 7.3}%)',
                icon: Icons.person_off_rounded,
                iconColor: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'Avg. Attendance',
                value: '${data?.avgAttendancePct ?? 92.7}%',
                icon: Icons.bar_chart_rounded,
                iconColor: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LiveClassStatCard(
                title: 'This Week',
                value: '${data?.thisWeekPct ?? 92.9}%',
                subtitle: '+1.4%',
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFF10B981),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeftSubnav() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mark Attendance triggered for selected session.')),
              );
            },
            icon: const Icon(Icons.fact_check_outlined, size: 16),
            label: const Text('Mark Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: cardDivider),
          const SizedBox(height: 10),
          _buildSubnavItem(Icons.how_to_reg_outlined, 'Class Attendance'),
          _buildSubnavItem(Icons.person_outline_rounded, 'Student Attendance'),
          _buildSubnavItem(Icons.menu_book_outlined, 'Subject Attendance'),
          _buildSubnavItem(Icons.calendar_today_outlined, 'Daily Attendance'),
          _buildSubnavItem(Icons.date_range_outlined, 'Weekly / Monthly'),
          _buildSubnavItem(Icons.description_outlined, 'Attendance Reports'),
          _buildSubnavItem(Icons.notification_important_outlined, 'Absence & Follow-up'),
          _buildSubnavItem(Icons.settings_outlined, 'Attendance Settings'),
        ],
      ),
    );
  }

  Widget _buildSubnavItem(IconData icon, String label) {
    final isSelected = _selectedSubnav == label;

    return InkWell(
      onTap: () {
        setState(() => _selectedSubnav = label);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF)) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: const Color(0xFF3B82F6), width: 1) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF3B82F6) : textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? (isDark ? Colors.white : const Color(0xFF1D4ED8)) : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTableSection(
    List<AttendanceItem> list,
    int totalCount,
    int presentCount,
    int absentCount,
    int lateCount,
    int notJoinedCount,
  ) {
    final state = ref.watch(liveClassManagementProvider);
    final meta = state.dropdownMeta;
    final classes = meta?.classes ?? [];
    final subjects = meta?.subjects ?? [];
    final sessions = meta?.sessions ?? [];
    final classNames = <String>['All Classes'];
    for (final c in classes) {
      final t = c.name.trim();
      if (t.isNotEmpty && !classNames.contains(t)) classNames.add(t);
    }
    final subjectNames = <String>['All Subjects'];
    for (final s in subjects) {
      final t = s.name.trim();
      if (t.isNotEmpty && !subjectNames.contains(t)) subjectNames.add(t);
    }
    final sessionNames = <String>['All Sessions'];
    for (final s in sessions) {
      final t = (s.timeStr.isNotEmpty ? s.timeStr : s.title).trim();
      if (t.isNotEmpty && !sessionNames.contains(t)) sessionNames.add(t);
    }

    final activeSess = state.conductSessionData?.activeSession ?? state.joinDashboard?.activeSession;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Dropdowns Row: Class, Subject, Date, Session
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildHeaderFilterDropdown(
                    'Class:',
                    classNames.contains(_selectedClass) ? _selectedClass : classNames.first,
                    classNames,
                    (v) => setState(() => _selectedClass = v!),
                  ),
                  const SizedBox(width: 12),
                  _buildHeaderFilterDropdown(
                    'Subject:',
                    subjectNames.contains(_selectedSubject) ? _selectedSubject : subjectNames.first,
                    subjectNames,
                    (v) => setState(() => _selectedSubject = v!),
                  ),
                  const SizedBox(width: 12),
                  _buildHeaderFilterDropdown(
                    'Date:',
                    _selectedDate,
                    ['Tue, 21 Jan 2025', 'Wed, 22 Jan 2025', 'Today'],
                    (v) => setState(() => _selectedDate = v!),
                    icon: Icons.calendar_today_rounded,
                  ),
                  const SizedBox(width: 12),
                  _buildHeaderFilterDropdown(
                    'Session:',
                    sessionNames.contains(_selectedSession) ? _selectedSession : sessionNames.first,
                    sessionNames,
                    (v) {
                      setState(() => _selectedSession = v!);
                      final match = sessions.where((s) => (s.timeStr.isNotEmpty ? s.timeStr : s.title) == v).firstOrNull;
                      ref.read(liveClassManagementProvider.notifier).setAttendanceSessionFilter(match?.id);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Selected Class Session Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF047857) : const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeSess != null
                            ? '${activeSess.className} - ${activeSess.sectionName} : ${activeSess.subject}'
                            : 'Class 10 - A : Mathematics',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                      const SizedBox(height: 2),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 11, color: textSecondary),
                            const SizedBox(width: 4),
                            Text('Tue, 21 Jan 2025', style: TextStyle(fontSize: 11, color: textSecondary)),
                            const SizedBox(width: 10),
                            Icon(Icons.schedule_outlined, size: 11, color: textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              activeSess != null
                                  ? '${activeSess.timeStr.isNotEmpty ? activeSess.timeStr : "Live Session"} (${activeSess.durationMinutes} min)'
                                  : '08:00 AM - 08:45 AM (45 min)',
                              style: TextStyle(fontSize: 11, color: textSecondary),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.person_outline, size: 11, color: textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              (ref.watch(authProvider).userData?['full_name'] as String?)?.trim().isNotEmpty == true
                                  ? (ref.watch(authProvider).userData!['full_name'] as String).trim()
                                  : 'Instructor',
                              style: TextStyle(fontSize: 11, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF065F46) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                      SizedBox(width: 4),
                      Text(
                        'Live Class (Completed)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Status Filter Tabs + Search + Auto Mark (Responsive with LayoutBuilder)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 880;
              final tabs = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatusTab('All', totalCount),
                    const SizedBox(width: 6),
                    _buildStatusTab('Present', presentCount),
                    const SizedBox(width: 6),
                    _buildStatusTab('Absent', absentCount),
                    const SizedBox(width: 6),
                    _buildStatusTab('Late', lateCount),
                    const SizedBox(width: 6),
                    _buildStatusTab('Not Joined', notJoinedCount),
                  ],
                ),
              );

              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 170,
                    height: 32,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) {
                        ref.read(liveClassManagementProvider.notifier).searchAttendance(v);
                      },
                      style: TextStyle(fontSize: 11, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search student...',
                        hintStyle: TextStyle(fontSize: 11, color: textSecondary),
                        prefixIcon: Icon(Icons.search, size: 14, color: textSecondary),
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: cardBorder),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildBulkActionsDropdown(),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _triggerAutoMark,
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 13),
                    label: const Text('Auto Mark', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tabs,
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: actions,
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: tabs),
                    const SizedBox(width: 8),
                    actions,
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),

          // Attendance Table Header + Rows wrapped in responsive horizontal scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 940,
              child: Column(
                children: [
                  // Attendance Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: headerRowBg,
                    child: Row(
                      children: [
                        SizedBox(width: 24, child: Icon(Icons.check_box_outline_blank, size: 16, color: textSecondary)),
                        const SizedBox(width: 8),
                        SizedBox(width: 70, child: Text('Roll No.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                        const SizedBox(width: 8),
                        SizedBox(width: 170, child: Text('Student Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                        const SizedBox(width: 8),
                        SizedBox(width: 110, child: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                        const SizedBox(width: 8),
                        SizedBox(width: 90, child: Text('Join Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                        const SizedBox(width: 8),
                        SizedBox(width: 90, child: Text('Leave Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                        const SizedBox(width: 8),
                        SizedBox(width: 70, child: Text('Duration', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                        const SizedBox(width: 8),
                        SizedBox(width: 100, child: Text('Participation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                        const SizedBox(width: 8),
                        SizedBox(width: 110, child: Text('Remarks', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                        const SizedBox(width: 8),
                        const SizedBox(width: 36, child: Text('', textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: cardBorder),

                  // Attendance Table Rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.take(10).length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: cardDivider),
                    itemBuilder: (context, index) {
                      final att = list[index];
                      final isPresent = att.status.toLowerCase() == 'present';
                      final isAbsent = att.status.toLowerCase() == 'absent';

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(width: 24, child: Icon(Icons.check_box_outline_blank, size: 16, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: Text(
                                att.rollNo.isNotEmpty ? att.rollNo : '${1001 + index}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 170,
                              child: Text(
                                att.studentName,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status Badge
                            SizedBox(
                              width: 110,
                              child: Row(
                                children: [
                                  _buildStatusBadge(att.status),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Join Time
                            SizedBox(
                              width: 90,
                              child: Text(
                                att.joinTime.isNotEmpty ? att.joinTime : '—',
                                style: TextStyle(fontSize: 11, color: isPresent ? (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)) : textSecondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Leave Time
                            SizedBox(
                              width: 90,
                              child: Text(
                                att.leaveTime.isNotEmpty ? att.leaveTime : '—',
                                style: TextStyle(fontSize: 11, color: isPresent ? (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)) : textSecondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Duration
                            SizedBox(
                              width: 70,
                              child: Text(
                                att.duration.isNotEmpty ? att.duration : '—',
                                style: TextStyle(fontSize: 11, color: isPresent ? (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)) : textSecondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Participation
                            SizedBox(
                              width: 100,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.signal_cellular_alt_rounded,
                                    size: 14,
                                    color: isPresent ? const Color(0xFF10B981) : textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isPresent ? '${att.participationPct}%' : '0%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isPresent ? textPrimary : textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Remarks
                            SizedBox(
                              width: 110,
                              child: Text(
                                att.remarks.isNotEmpty ? att.remarks : (isAbsent ? 'Not Joined' : '—'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isAbsent ? const Color(0xFFEF4444) : textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Edit action icon
                            SizedBox(
                              width: 36,
                              child: IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showOverrideDialog(att),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Pagination Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: cardBorder)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Showing 1 - ${list.take(10).length} of $totalCount students',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                        Row(
                          children: [
                            _buildPageButton(
                              '<',
                              false,
                              onTap: state.attendancePage > 1
                                  ? () => ref.read(liveClassManagementProvider.notifier).setAttendancePage(state.attendancePage - 1)
                                  : null,
                            ),
                            for (int p = 1; p <= math.min(state.attendanceTotalPages, 5); p++)
                              _buildPageButton(
                                '$p',
                                p == state.attendancePage,
                                onTap: () => ref.read(liveClassManagementProvider.notifier).setAttendancePage(p),
                              ),
                            if (state.attendanceTotalPages > 5) ...[
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('...', style: TextStyle(color: textSecondary))),
                              _buildPageButton(
                                '${state.attendanceTotalPages}',
                                state.attendancePage == state.attendanceTotalPages,
                                onTap: () => ref.read(liveClassManagementProvider.notifier).setAttendancePage(state.attendanceTotalPages),
                              ),
                            ],
                            _buildPageButton(
                              '>',
                              false,
                              onTap: state.attendancePage < state.attendanceTotalPages
                                  ? () => ref.read(liveClassManagementProvider.notifier).setAttendancePage(state.attendancePage + 1)
                                  : null,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text('Rows per page:', style: TextStyle(fontSize: 11, color: textSecondary)),
                            const SizedBox(width: 6),
                            Text('10', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary)),
                            Icon(Icons.arrow_drop_down, size: 16, color: textSecondary),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFDEF7EC);
    Color fg = const Color(0xFF03543F);
    IconData icon = Icons.check_circle_rounded;
    String label = 'Present';

    switch (status.toLowerCase()) {
      case 'absent':
        bg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFFFDE8E8);
        fg = isDark ? const Color(0xFFF87171) : const Color(0xFF9B1C1C);
        icon = Icons.cancel_rounded;
        label = 'Absent';
        break;
      case 'late':
        bg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF08A);
        fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFF854D0E);
        icon = Icons.schedule_rounded;
        label = 'Late';
        break;
      case 'partial':
        bg = isDark ? const Color(0xFF312E81).withValues(alpha: 0.4) : const Color(0xFFE0E7FF);
        fg = isDark ? const Color(0xFF818CF8) : const Color(0xFF3730A3);
        icon = Icons.timelapse_rounded;
        label = 'Partial';
        break;
      case 'not_joined':
      case 'not joined':
        bg = isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFF3E8FF);
        fg = isDark ? const Color(0xFFC084FC) : const Color(0xFF6B21A8);
        icon = Icons.person_off_rounded;
        label = 'Not Joined';
        break;
      default:
        bg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFDEF7EC);
        fg = isDark ? const Color(0xFF34D399) : const Color(0xFF03543F);
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
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderFilterDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged, {
    IconData? icon,
  }) {
    final uniqueOptions = <String>[];
    for (final opt in options) {
      final trimmed = opt.trim();
      if (trimmed.isNotEmpty && !uniqueOptions.contains(trimmed)) {
        uniqueOptions.add(trimmed);
      }
    }
    final effectiveValue = uniqueOptions.contains(value.trim())
        ? value.trim()
        : (uniqueOptions.isNotEmpty ? uniqueOptions.first : null);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textSecondary),
            const SizedBox(width: 4),
          ],
          Text('$label ', style: TextStyle(fontSize: 11, color: textSecondary)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effectiveValue,
              isDense: true,
              dropdownColor: cardBg,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
              items: uniqueOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String label, int count) {
    final isActive = _activeStatusFilter == label;

    return InkWell(
      onTap: () {
        setState(() => _activeStatusFilter = label);
        ref.read(liveClassManagementProvider.notifier).setAttendanceStatusFilter(
              label == 'All' ? null : label.toUpperCase(),
            );
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? LiveClassTheme.primary(context) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.white : textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBulkActionsDropdown() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: 'Bulk Actions',
          isDense: true,
          dropdownColor: cardBg,
          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155), fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: 'Bulk Actions', child: Text('Bulk Actions')),
            DropdownMenuItem(value: 'all_present', child: Text('Mark Selected Present')),
            DropdownMenuItem(value: 'all_absent', child: Text('Mark Selected Absent')),
          ],
          onChanged: (v) {},
        ),
      ),
    );
  }

  Widget _buildPageButton(String text, bool isActive, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? LiveClassTheme.primary(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isActive ? LiveClassTheme.primary(context) : cardBorder),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? Colors.white : textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel(
    AttendanceDashboardData? dashboard,
    int presentCount,
    int absentCount,
    int lateCount,
    int notJoinedCount,
  ) {
    return Column(
      children: [
        // Class Session Details Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Class Session Details',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  InkWell(
                    onTap: () {},
                    child: const Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 12, color: Color(0xFF2563EB)),
                        SizedBox(width: 4),
                        Text('Edit', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildPanelDetailRow(Icons.groups_outlined, 'Class / Section', 'Class 10 - A'),
              _buildPanelDetailRow(Icons.menu_book_outlined, 'Subject', 'Mathematics'),
              _buildPanelDetailRow(Icons.calendar_today_outlined, 'Date', 'Tue, 21 Jan 2025'),
              _buildPanelDetailRow(Icons.schedule_outlined, 'Time', '08:00 AM - 08:45 AM (45 min)'),
              _buildPanelDetailRow(Icons.person_outline, 'Teacher', (ref.watch(authProvider).userData?['full_name'] as String?)?.trim().isNotEmpty == true ? (ref.watch(authProvider).userData!['full_name'] as String).trim() : 'Instructor'),
              _buildPanelDetailRow(Icons.people_alt_outlined, 'Total Students', '42'),
              _buildPanelDetailRow(Icons.check_circle_outline_rounded, 'Attendance Status', 'Marked (92.7%)', isHighlighted: true),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Attendance Summary Donut Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance Summary',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 76,
                          height: 76,
                          child: CircularProgressIndicator(
                            value: 0.927,
                            strokeWidth: 9,
                            backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '92.7%',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                            ),
                            Text(
                              'Attendance',
                              style: TextStyle(fontSize: 8, color: textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        _buildSummaryLegendRow('Present', '$presentCount (92.7%)', const Color(0xFF10B981)),
                        const SizedBox(height: 4),
                        _buildSummaryLegendRow('Absent', '$absentCount (7.3%)', const Color(0xFFEF4444)),
                        const SizedBox(height: 4),
                        _buildSummaryLegendRow('Late', '$lateCount (0%)', const Color(0xFFF59E0B)),
                        const SizedBox(height: 4),
                        _buildSummaryLegendRow('Not Joined', '$notJoinedCount (0%)', const Color(0xFF8B5CF6)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Attendance Trend (This Class)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attendance Trend (This Class)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  InkWell(
                    onTap: () {},
                    child: const Row(
                      children: [
                        Text('View Report', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                        SizedBox(width: 2),
                        Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: CustomPaint(
                  painter: _AttendanceTrendPainter(),
                  size: const Size(double.infinity, 90),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('15 Jan', style: TextStyle(fontSize: 9, color: textSecondary)),
                  Text('16 Jan', style: TextStyle(fontSize: 9, color: textSecondary)),
                  Text('17 Jan', style: TextStyle(fontSize: 9, color: textSecondary)),
                  Text('20 Jan', style: TextStyle(fontSize: 9, color: textSecondary)),
                  Text('21 Jan', style: TextStyle(fontSize: 9, color: textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPanelDetailRow(IconData icon, String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: textSecondary),
          const SizedBox(width: 6),
          SizedBox(
            width: 95,
            child: Text(label, style: TextStyle(fontSize: 11, color: textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isHighlighted ? const Color(0xFF16A34A) : textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLegendRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: TextStyle(fontSize: 10, color: textSecondary))),
        Text(value, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textPrimary)),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickActionBtn(Icons.check_circle_outline_rounded, 'Mark Present', const Color(0xFF10B981)),
              _buildQuickActionBtn(Icons.cancel_outlined, 'Mark Absent', const Color(0xFFEF4444)),
              _buildQuickActionBtn(Icons.schedule_rounded, 'Mark Late', const Color(0xFFF59E0B)),
              _buildQuickActionBtn(Icons.person_off_outlined, 'Not Joined', const Color(0xFF8B5CF6)),
              _buildQuickActionBtn(Icons.sync_rounded, 'Recalculate', const Color(0xFF2563EB)),
              _buildQuickActionBtn(Icons.file_download_outlined, 'Export', const Color(0xFF0284C7)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Triggered $label for class')),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoRulesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rule_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Auto Attendance Rules',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildRuleCheckbox(
            'Auto-mark from live session participation (≥ 75% duration)',
            _ruleMinDuration,
            (v) => setState(() => _ruleMinDuration = v!),
          ),
          _buildRuleCheckbox(
            'Consider join & leave time',
            _ruleJoinLeave,
            (v) => setState(() => _ruleJoinLeave = v!),
          ),
          _buildRuleCheckbox(
            'Include participation (chat, Q&A, poll)',
            _ruleEngagement,
            (v) => setState(() => _ruleEngagement = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCheckbox(String title, bool value, ValueChanged<bool?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF10B981),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
            ),
          ),
          Icon(Icons.info_outline, size: 13, color: textSecondary),
        ],
      ),
    );
  }

  Widget _buildExportReportsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize_outlined, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Export & Reports',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildExportBtn(Icons.description_outlined, 'Attendance Report')),
              const SizedBox(width: 8),
              Expanded(child: _buildExportBtn(Icons.class_outlined, 'Class-wise Report')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildExportBtn(Icons.person_search_outlined, 'Student-wise Report')),
              const SizedBox(width: 8),
              Expanded(child: _buildExportBtn(Icons.calendar_month_outlined, 'Monthly Summary')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportBtn(IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generating $label...')),
        );
      },
      icon: Icon(icon, size: 14, color: const Color(0xFF2563EB)),
      label: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        side: BorderSide(color: cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

class _AttendanceTrendPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;

    final peakDotPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;

    final points = [
      Offset(size.width * 0.05, size.height * 0.7),
      Offset(size.width * 0.28, size.height * 0.55),
      Offset(size.width * 0.52, size.height * 0.62),
      Offset(size.width * 0.76, size.height * 0.45),
      Offset(size.width * 0.95, size.height * 0.2), // peak 92.7%
    ];

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      if (i == points.length - 1) {
        canvas.drawCircle(p, 5, peakDotPaint);
        canvas.drawCircle(p, 3, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(p, 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
