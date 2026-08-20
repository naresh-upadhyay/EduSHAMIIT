import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_fonts.dart';
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
    final isDesktop = Responsive.isDesktop(context);

    final List<_AttendanceTabDef> availableTabs = [
      const _AttendanceTabDef(id: 0, label: 'Daily Attendance', icon: Icons.checklist_rounded, view: DailyAttendanceTab()),
      if (state.isManager)
        const _AttendanceTabDef(id: 1, label: 'Staff Attendance', icon: Icons.badge_outlined, view: StaffAttendanceTab()),
      if (state.isManager)
        const _AttendanceTabDef(id: 2, label: 'Leave & Permissions', icon: Icons.beach_access_rounded, view: LeavePermissionsTab()),
      const _AttendanceTabDef(id: 3, label: 'Bulk Operations', icon: Icons.flash_on_rounded, view: BulkOperationsTab()),
      const _AttendanceTabDef(id: 4, label: 'Attendance Insights', icon: Icons.insights_rounded, view: AttendanceInsightsTab()),
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

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Column(
        children: [
          // 1. Top Header Bar
          _buildHeaderBar(context, state, notifier, theme),

          // 2. 5 Dynamic Summary Metric KPI Cards
          _buildSummaryKpiCards(state, notifier, isDesktop, theme),

          // 3. Tab Bar (conditionally displays Staff & Leave tabs only if user is a manager)
          _buildTabBar(availableTabs, state, notifier, theme),

          // 4. Tab Views
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
  // 1. HEADER BAR
  // ==========================================================================
  Widget _buildHeaderBar(BuildContext context, AttendanceState state, AttendanceNotifier notifier, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          if (Navigator.of(context).canPop())
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back',
            ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendance Management',
                style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                'Student, staff, period schedules, and leave tracking',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),

          // Reports Action
          OutlinedButton.icon(
            onPressed: () => notifier.setTab(4),
            icon: const Icon(Icons.insights_rounded, size: 16),
            label: const Text('Insights & Reports', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 10),

          // Primary + Take Attendance Button
          ElevatedButton.icon(
            onPressed: () => notifier.setTab(0),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Take Attendance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 2. SUMMARY KPI CARDS
  // ==========================================================================
  Widget _buildSummaryKpiCards(AttendanceState state, AttendanceNotifier notifier, bool isDesktop, ThemeData theme) {
    final stats = state.stats;

    final cards = [
      _buildMetricCard(
        title: 'Overall Attendance',
        value: '${stats.overallRate.toStringAsFixed(0)}%',
        subtitle: 'Today • ${stats.totalStudents} total',
        icon: Icons.pie_chart_rounded,
        color: const Color(0xFF10B981),
        theme: theme,
      ),
      _buildMetricCard(
        title: 'Students Present',
        value: '${stats.presentCount}',
        subtitle: 'Marked on time',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF10B981),
        theme: theme,
      ),
      _buildMetricCard(
        title: 'Students Absent',
        value: '${stats.absentCount}',
        subtitle: 'Unexcused / Illness',
        icon: Icons.cancel_outlined,
        color: const Color(0xFFEF4444),
        theme: theme,
      ),
      _buildMetricCard(
        title: 'Late Entries',
        value: '${stats.lateCount}',
        subtitle: 'Logged after start',
        icon: Icons.access_time_rounded,
        color: const Color(0xFFF59E0B),
        theme: theme,
      ),
      _buildMetricCard(
        title: 'On Leave',
        value: '${stats.onLeaveCount}',
        subtitle: 'Approved applications',
        icon: Icons.beach_access_rounded,
        color: const Color(0xFF8B5CF6),
        theme: theme,
      ),
    ];

    if (isDesktop) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
        ),
      );
    } else {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: cards.map((c) => Container(width: 170, margin: const EdgeInsets.only(right: 10), child: c)).toList(),
        ),
      );
    }
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11), maxLines: 1),
                  Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
                  Text(subtitle, style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 10), maxLines: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // 3. TAB BAR
  // ==========================================================================
  Widget _buildTabBar(List<_AttendanceTabDef> tabs, AttendanceState state, AttendanceNotifier notifier, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
      ),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = state.activeTab == tab.id;

          return InkWell(
            onTap: () => notifier.setTab(tab.id),
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
                children: [
                  Icon(
                    tab.icon,
                    size: 16,
                    color: isSelected ? const Color(0xFF4F46E5) : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFF4F46E5) : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
