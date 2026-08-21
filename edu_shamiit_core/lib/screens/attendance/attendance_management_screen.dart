import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../constants/app_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/role_provider.dart';
import '../../utils/responsive.dart';
import 'models/attendance_models.dart';
import 'providers/attendance_provider.dart';
import 'widgets/daily_attendance_tab.dart';
import 'widgets/staff_attendance_tab.dart';
import 'widgets/leave_permissions_tab.dart';
import 'widgets/bulk_operations_tab.dart';
import 'widgets/attendance_insights_tab.dart';
import 'widgets/attendance_settings_tab.dart';

class _AttendanceTabDef {
  final int id;
  final String label;
  final IconData icon;
  final Widget view;

  const _AttendanceTabDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.view,
  });
}

class AttendanceManagementScreen extends ConsumerWidget {
  const AttendanceManagementScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    final List<_AttendanceTabDef> availableTabs = [
      const _AttendanceTabDef(id: 0, label: 'Daily Attendance', icon: Icons.calendar_today_rounded, view: DailyAttendanceTab()),
      if (state.isManager)
        const _AttendanceTabDef(id: 1, label: 'Staff Attendance', icon: Icons.badge_outlined, view: StaffAttendanceTab()),
      if (state.isManager)
        const _AttendanceTabDef(id: 2, label: 'Leave & Permissions', icon: Icons.beach_access_rounded, view: LeavePermissionsTab()),
      const _AttendanceTabDef(id: 3, label: 'Bulk Operations', icon: Icons.bolt_rounded, view: BulkOperationsTab()),
      const _AttendanceTabDef(id: 4, label: 'Attendance Insights', icon: Icons.bar_chart_rounded, view: AttendanceInsightsTab()),
      const _AttendanceTabDef(id: 5, label: 'Settings', icon: Icons.settings_outlined, view: AttendanceSettingsTab()),
    ];

    final activeIndex = availableTabs.indexWhere((t) => t.id == state.activeTab);
    final currentStackIndex = activeIndex >= 0 ? activeIndex : 0;

    // Listen for error and success messages
    ref.listen<AttendanceState>(attendanceProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final scaffoldBg = isDark ? const Color(0xFF090D1A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Header Bar (Title, Date Navigator Pill, Profile, Actions)
          _buildHeaderBar(context, ref, state, notifier, isDark, theme),

          // 2. 5 Dynamic Summary Metric KPI Cards
          _buildSummaryKpiCards(state, notifier, isDesktop, isDark, theme),

          // 3. Underline Tab Navigation Bar (Left Aligned)
          _buildTabBar(availableTabs, state, notifier, isDark, theme),

          // 4. Tab Views (Main Content Area)
          Expanded(
            child: IndexedStack(
              index: currentStackIndex,
              children: availableTabs.map((t) => t.view).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 1. HEADER BAR (Fully Responsive for Desktop, Tablet, Split-Screen & Mobile)
  // ==========================================================================
  Widget _buildHeaderBar(
    BuildContext context,
    WidgetRef ref,
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    final dateStr = DateFormat('dd MMM yyyy, EEE').format(state.selectedDate);
    final authState = ref.watch(authProvider);
    final userName = authState.userData?['full_name']?.toString() ??
        authState.userData?['name']?.toString() ??
        'Administrator';
    final userRole = authState.userData?['role_name']?.toString() ??
        authState.userData?['role']?.toString() ??
        (authState.role != UserRole.unknown ? authState.role.name : 'Staff');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 1050;
          final isVeryCompact = constraints.maxWidth < 700;

          // Date Navigator Pill Widget: < 21 Aug 2026, Fri >
          final datePickerPill = Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left_rounded, size: 18, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                  onPressed: () => notifier.prevDay(),
                  tooltip: 'Previous Day',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 32),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 5),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                  onPressed: () => notifier.nextDay(),
                  tooltip: 'Next Day',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 32),
                ),
              ],
            ),
          );

          // User Profile Widget (Adaptive Avatar + Name)
          final profileWidget = isCompact
              ? Tooltip(
                  message: '$userName ($userRole)',
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3), width: 1.5),
                      color: const Color(0xFFEEF2FF),
                    ),
                    child: Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4F46E5), fontSize: 13),
                      ),
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3), width: 1.5),
                        color: const Color(0xFFEEF2FF),
                      ),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4F46E5), fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          userRole,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                );

          // Action Buttons: Take Attendance & Reports
          final actionButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<String>(
                tooltip: 'Take Attendance Options',
                onSelected: (val) {
                  if (val == 'daily') notifier.setTab(0);
                  if (val == 'staff') notifier.setTab(1);
                  if (val == 'bulk') notifier.setTab(3);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'daily',
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF4F46E5)),
                        SizedBox(width: 10),
                        Text('Mark Daily Class Attendance', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  if (state.isManager)
                    const PopupMenuItem(
                      value: 'staff',
                      child: Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 16, color: Color(0xFF4F46E5)),
                          SizedBox(width: 10),
                          Text('Mark Staff Attendance', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'bulk',
                    child: Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF4F46E5)),
                        SizedBox(width: 10),
                        Text('Bulk Operations', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                      if (!isCompact) ...[
                        const SizedBox(width: 6),
                        const Text(
                          'Take Attendance',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => notifier.setTab(4),
                icon: const Icon(Icons.bar_chart_rounded, size: 15, color: Color(0xFF4F46E5)),
                label: isCompact
                    ? const SizedBox.shrink()
                    : Text(
                        'Reports',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12, vertical: 7),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          );

          if (isVeryCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (Navigator.of(context).canPop())
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Back',
                        ),
                      ),
                    Expanded(
                      child: Text(
                        'Attendance Management',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    profileWidget,
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      datePickerPill,
                      const SizedBox(width: 8),
                      actionButtons,
                    ],
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              if (Navigator.of(context).canPop())
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Attendance Management',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w800,
                        fontSize: isCompact ? 17 : 20,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (!isCompact) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Take and manage attendance for all users and subject-wise student attendance.',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              datePickerPill,
              const SizedBox(width: 10),
              profileWidget,
              const SizedBox(width: 10),
              actionButtons,
            ],
          );
        },
      ),
    );
  }

  // ==========================================================================
  // 2. SUMMARY KPI CARDS (Dynamic calculations from FastAPI stats)
  // ==========================================================================
  Widget _buildSummaryKpiCards(
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDesktop,
    bool isDark,
    ThemeData theme,
  ) {
    final stats = state.stats;
    final total = stats.totalStudents;
    final present = stats.presentCount;
    final absent = stats.absentCount;
    final lateCount = stats.lateCount;
    final onLeave = stats.onLeaveCount;

    final overallPct = total > 0 ? ((present / total) * 100).toStringAsFixed(1) : (stats.overallAttendancePct > 0 ? stats.overallAttendancePct.toStringAsFixed(1) : '0.0');
    final presentPct = total > 0 ? ((present / total) * 100).toStringAsFixed(1) : '0.0';
    final absentPct = total > 0 ? ((absent / total) * 100).toStringAsFixed(1) : '0.0';
    final latePct = total > 0 ? ((lateCount / total) * 100).toStringAsFixed(1) : '0.0';
    final leavePct = total > 0 ? ((onLeave / total) * 100).toStringAsFixed(1) : '0.0';

    final formatter = NumberFormat('#,###');

    final cards = [
      _buildMetricCard(
        title: 'Overall Attendance (Today)',
        value: '$overallPct%',
        subtitle: 'Present: ${formatter.format(present)} / ${formatter.format(total)}',
        icon: Icons.people_alt_rounded,
        iconColor: const Color(0xFF6366F1),
        iconBgColor: const Color(0xFFEEF2FF),
        isDark: isDark,
      ),
      _buildMetricCard(
        title: 'Students Present',
        value: formatter.format(present),
        subtitle: '$presentPct% of Total',
        icon: Icons.person_pin_rounded,
        iconColor: const Color(0xFF10B981),
        iconBgColor: const Color(0xFFECFDF5),
        isDark: isDark,
      ),
      _buildMetricCard(
        title: 'Students Absent',
        value: formatter.format(absent),
        subtitle: '$absentPct% of Total',
        icon: Icons.person_off_rounded,
        iconColor: const Color(0xFFEF4444),
        iconBgColor: const Color(0xFFFEF2F2),
        isDark: isDark,
      ),
      _buildMetricCard(
        title: 'Late Entries',
        value: formatter.format(lateCount),
        subtitle: '$latePct% of Total',
        icon: Icons.access_time_filled_rounded,
        iconColor: const Color(0xFFF59E0B),
        iconBgColor: const Color(0xFFFFFBEB),
        isDark: isDark,
      ),
      _buildMetricCard(
        title: 'On Leave',
        value: formatter.format(onLeave),
        subtitle: '$leavePct% of Total',
        icon: Icons.calendar_month_rounded,
        iconColor: const Color(0xFF3B82F6),
        iconBgColor: const Color(0xFFEFF6FF),
        isDark: isDark,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1150) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
            ),
          );
        } else {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: cards.map((c) => Container(width: 210, margin: const EdgeInsets.only(right: 10), child: c)).toList(),
            ),
          );
        }
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? iconColor.withValues(alpha: 0.15) : iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 3. TAB BAR (Starts directly from the left edge)
  // ==========================================================================
  Widget _buildTabBar(
    List<_AttendanceTabDef> tabs,
    AttendanceState state,
    AttendanceNotifier notifier,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: tabs.map((tab) {
              final isSelected = state.activeTab == tab.id;

              return InkWell(
                onTap: () => notifier.setTab(tab.id),
                splashColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                highlightColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        size: 16,
                        color: isSelected
                            ? const Color(0xFF4F46E5)
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF4F46E5)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
