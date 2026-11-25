import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/visitor_models.dart';
import '../../providers/visitors_provider.dart';
import '../dialogs/appointment_reschedule_dialog.dart';
import '../dialogs/appointment_reject_dialog.dart';
import '../dialogs/scheduled_calendar_dialog.dart';
import '../dialogs/visitors_more_filters_dialog.dart';
import '../dialogs/visitor_date_range_dialog.dart';
import '../dialogs/visitor_restriction_dialog.dart';
import '../dialogs/visitor_upload_document_dialog.dart';
import '../dialogs/visitor_gate_pass_dialog.dart';
import '../../utils/visitor_avatar_helper.dart';
import '../../../../utils/js_helper.dart';

class ScheduledVisitorsTab extends ConsumerStatefulWidget {
  const ScheduledVisitorsTab({super.key});

  @override
  ConsumerState<ScheduledVisitorsTab> createState() => _ScheduledVisitorsTabState();
}

class _ScheduledVisitorsTabState extends ConsumerState<ScheduledVisitorsTab> {
  int _activeDetailTab = 0; // 0: Details, 1: Documents, 2: Visit History
  int _docPage = 1;
  static const int _docPageSize = 5;
  int _historyPage = 1;
  static const int _historyPageSize = 5;
  String? _lastAppointmentId;
  final Set<String> _selectedAppointmentIds = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(visitorsProvider);
    final notifier = ref.read(visitorsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kpis = state.scheduledKpis;
    final appointments = state.appointments;
    final selectedAppt = state.selectedAppointment ?? (appointments.isNotEmpty ? appointments.first : null);
    final detail = state.selectedAppointmentDetail;

    if (selectedAppt != null && selectedAppt.id != _lastAppointmentId) {
      _lastAppointmentId = selectedAppt.id;
      _docPage = 1;
      _historyPage = 1;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: isMobile ? 10 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==================================================================
          // 1. KPI CARDS ROW (5 Cards Matching Screenshot 1)
          // ==================================================================
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount;
              if (constraints.maxWidth > 1150) {
                crossAxisCount = 5;
              } else if (constraints.maxWidth > 750) {
                crossAxisCount = 3;
              } else if (constraints.maxWidth > 480) {
                crossAxisCount = 2;
              } else {
                crossAxisCount = 1;
              }
              final cardWidth = (constraints.maxWidth - ((crossAxisCount - 1) * 10)) / crossAxisCount;
              final cards = [
                _buildKpiCard(
                  context,
                  title: 'Total Scheduled',
                  value: '${kpis.totalScheduled}',
                  subtitle: kpis.totalScheduledSubtitle,
                  icon: Icons.calendar_month_rounded,
                  iconBg: const Color(0xFFF3E8FF),
                  iconColor: const Color(0xFF9333EA),
                  isDark: isDark,
                  onTap: () => notifier.setStatusFilter('All Status'),
                ),
                _buildKpiCard(
                  context,
                  title: 'Today',
                  value: '${kpis.today}',
                  subtitle: kpis.todaySubtitle,
                  icon: Icons.check_circle_rounded,
                  iconBg: const Color(0xFFDCFCE7),
                  iconColor: const Color(0xFF16A34A),
                  isDark: isDark,
                  onTap: () => notifier.setStatusFilter('Today'),
                ),
                _buildKpiCard(
                  context,
                  title: 'This Week',
                  value: '${kpis.thisWeek}',
                  subtitle: kpis.thisWeekSubtitle,
                  icon: Icons.access_time_filled_rounded,
                  iconBg: const Color(0xFFFFEDD5),
                  iconColor: const Color(0xFFEA580C),
                  isDark: isDark,
                  onTap: () => notifier.setStatusFilter('This Week'),
                ),
                _buildKpiCard(
                  context,
                  title: 'Expected Visitors',
                  value: '${kpis.expectedVisitors}',
                  subtitle: kpis.expectedVisitorsSubtitle,
                  icon: Icons.group_rounded,
                  iconBg: const Color(0xFFF3E8FF),
                  iconColor: const Color(0xFF7C3AED),
                  isDark: isDark,
                  onTap: () => notifier.setStatusFilter('Expected'),
                ),
                _buildKpiCard(
                  context,
                  title: 'Pending Approval',
                  value: '${kpis.pendingApproval}',
                  subtitle: kpis.pendingApprovalSubtitle,
                  icon: Icons.cancel_rounded,
                  iconBg: const Color(0xFFFEE2E2),
                  iconColor: const Color(0xFFEF4444),
                  isDark: isDark,
                  onTap: () => notifier.setStatusFilter('Pending'),
                ),
              ];

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
              );
            },
          ),
          const SizedBox(height: 16),

          // ==================================================================
          // 2. SEARCH & FILTER TOOLBAR (Matching Screenshot 1)
          // ==================================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: LayoutBuilder(
              builder: (context, filterConstraints) {
                final isNarrowFilter = filterConstraints.maxWidth < 600;
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search field
                    SizedBox(
                      width: isNarrowFilter ? filterConstraints.maxWidth : 320,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name, purpose, host, location...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (v) => notifier.setSearchQuery(v),
                  ),
                ),

                // All Locations Dropdown
                _buildDropdown(
                  value: const ['All Locations', 'Main Gate', 'Library', 'Science Lab', 'Girls Hostel', 'Boys Hostel', 'Admin Office', 'Auditorium', 'Medical Room'].contains(state.selectedLocation) ? state.selectedLocation : 'All Locations',
                  items: const ['All Locations', 'Main Gate', 'Library', 'Science Lab', 'Girls Hostel', 'Boys Hostel', 'Admin Office', 'Auditorium', 'Medical Room'],
                  isDark: isDark,
                  onChanged: (val) {
                    if (val != null) {
                      notifier.setLocationFilter(val);
                    }
                  },
                ),

                // All Visitor Types Dropdown
                _buildDropdown(
                  value: const ['All Visitor Types', 'Parent', 'Official', 'Vendor', 'Relative', 'Maintenance'].contains(state.selectedCategory) ? state.selectedCategory : 'All Visitor Types',
                  items: const ['All Visitor Types', 'Parent', 'Official', 'Vendor', 'Relative', 'Maintenance'],
                  isDark: isDark,
                  onChanged: (val) {
                    if (val != null) {
                      notifier.setCategoryFilter(val);
                    }
                  },
                ),

                // All Status Dropdown
                _buildDropdown(
                  value: const ['All Status', 'Today', 'This Week', 'Expected', 'Confirmed', 'Pending', 'Completed', 'Blocked', 'Rejected', 'Cancelled'].contains(state.selectedStatus) ? state.selectedStatus : 'All Status',
                  items: const ['All Status', 'Today', 'This Week', 'Expected', 'Confirmed', 'Pending', 'Completed', 'Blocked', 'Rejected', 'Cancelled'],
                  isDark: isDark,
                  onChanged: (val) {
                    if (val != null) {
                      notifier.setStatusFilter(val);
                    }
                  },
                ),

                // Date Range Button (Interactive)
                InkWell(
                  onTap: () => showVisitorDateRangeDialog(context, ref),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          state.selectedDateRange,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),

                // More Filters Button (Interactive)
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const VisitorsMoreFiltersDialog(),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded, size: 15, color: Color(0xFF64748B)),
                  label: const Text('More Filters', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            );
          },
            ),
          ),
          const SizedBox(height: 16),

          // ==================================================================
          // 3. MAIN WORKSPACE: TABLE (7) + RIGHT INSPECTOR (3)
          // ==================================================================
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1050;
              final tableWidget = _buildScheduledTable(context, isDark, state, notifier, selectedAppt);
              final drawerWidget = _buildRightInspector(context, isDark, state, notifier, selectedAppt, detail);

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: tableWidget),
                    const SizedBox(width: 16),
                    SizedBox(width: 380, child: drawerWidget),
                  ],
                );
              } else {
                return Column(
                  children: [
                    tableWidget,
                    const SizedBox(height: 16),
                    drawerWidget,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KPI CARD HELPER
  // ==========================================================================
  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // DROPDOWN HELPER
  // ==========================================================================
  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<String>.fromMenuItems(
          value: items.contains(value) ? value : items.first,
          isDense: true,
          isExpanded: false,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          items: items.map((it) => DropdownMenuItem(value: it, child: Text(it))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ==========================================================================
  // TABLE WIDGET (Matching Screenshot 1)
  // ==========================================================================
  Widget _buildScheduledTable(
    BuildContext context,
    bool isDark,
    VisitorsState state,
    VisitorsNotifier notifier,
    ScheduledAppointmentItem? selectedAppt,
  ) {
    final appointments = state.appointments;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Toolbar Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Scheduled Visitors (${state.appointmentPagination.totalRecords})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Calendar View button
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => ScheduledCalendarDialog(
                          appointments: appointments,
                          onSelectAppointment: (a) => notifier.openAppointmentDetail(a),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calendar_month_outlined, size: 15, color: Color(0xFF2563EB)),
                    label: const Text('Calendar View', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      backgroundColor: const Color(0xFFEFF6FF),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Export button
                  OutlinedButton.icon(
                    onPressed: () async {
                      final api = ref.read(visitorsApiServiceProvider);
                      final bytes = await api.exportVisitsCSV();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Exported ${bytes.length} bytes of scheduled appointments!'),
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.file_download_outlined, size: 15, color: Color(0xFF475569)),
                    label: const Text('Export', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Bulk Actions PopupMenu
                  PopupMenuButton<String>(
                    tooltip: 'Bulk Actions',
                    onSelected: (action) async {
                      if (_selectedAppointmentIds.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select appointments to perform bulk action.')),
                        );
                        return;
                      }
                      if (action == 'approve') {
                        for (final id in _selectedAppointmentIds) {
                          await notifier.approveAppointment(id);
                        }
                        setState(() => _selectedAppointmentIds.clear());
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bulk approval completed.'), backgroundColor: Color(0xFF16A34A)),
                          );
                        }
                      } else if (action == 'reject') {
                        for (final id in _selectedAppointmentIds) {
                          await notifier.rejectAppointment(id, reason: 'Bulk rejection');
                        }
                        setState(() => _selectedAppointmentIds.clear());
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bulk rejection completed.'), backgroundColor: Color(0xFFEF4444)),
                          );
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'approve',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                            SizedBox(width: 8),
                            Text('Bulk Approve'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reject',
                        child: Row(
                          children: [
                            Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFEF4444)),
                            SizedBox(width: 8),
                            Text('Bulk Reject'),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Bulk Actions', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                          SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Columns customization
                  PopupMenuButton<String>(
                    tooltip: 'Customize Columns',
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        enabled: false,
                        child: Text('Toggle Columns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      ...['Photo', 'Visitor Name', 'Type', 'Purpose', 'Location', 'Host', 'Date & Time', 'Status'].map((col) {
                        return CheckedPopupMenuItem<String>(
                          value: col,
                          checked: true,
                          child: Text(col, style: const TextStyle(fontSize: 12.5)),
                        );
                      }),
                    ],
                    onSelected: (_) {},
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.view_column_outlined, size: 18, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

          // Scrollable Table Content with responsive dynamic width
          LayoutBuilder(
            builder: (context, tableConstraints) {
              const minWidth = 1100.0;
              final tableWidth = math.max(tableConstraints.maxWidth, minWidth);
              final extra = tableWidth > minWidth ? (tableWidth - minWidth) : 0.0;
              final nameWidth = 145.0 + (extra * 0.28);
              final purposeWidth = 135.0 + (extra * 0.22);
              final hostWidth = 145.0 + (extra * 0.25);
              final dateTimeWidth = 145.0 + (extra * 0.25);

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // Table Column Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 34,
                              child: Checkbox(
                                value: _selectedAppointmentIds.length == appointments.length && appointments.isNotEmpty,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedAppointmentIds.addAll(appointments.map((a) => a.id));
                                    } else {
                                      _selectedAppointmentIds.clear();
                                    }
                                  });
                                },
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            _buildSortableHeaderCell(
                              title: '#',
                              sortKey: 'created_at',
                              width: 30,
                              currentSortBy: state.appointmentsSortBy,
                              currentSortOrder: state.appointmentsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortAppointments('created_at'),
                            ),
                            SizedBox(width: 44, child: Text('Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B)))),
                            _buildSortableHeaderCell(
                              title: 'Visitor Name',
                              sortKey: 'visitor_name',
                              width: nameWidth,
                              currentSortBy: state.appointmentsSortBy,
                              currentSortOrder: state.appointmentsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortAppointments('visitor_name'),
                            ),
                            _buildSortableHeaderCell(
                              title: 'Type',
                              sortKey: 'visitor_type',
                              width: 80,
                              currentSortBy: state.appointmentsSortBy,
                              currentSortOrder: state.appointmentsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortAppointments('visitor_type'),
                            ),
                            _buildSortableHeaderCell(
                              title: 'Purpose',
                              sortKey: 'purpose',
                              width: purposeWidth,
                              currentSortBy: state.appointmentsSortBy,
                              currentSortOrder: state.appointmentsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortAppointments('purpose'),
                            ),
                            _buildSortableHeaderCell(
                              title: 'Location',
                              sortKey: 'destination',
                              width: 95,
                              currentSortBy: state.appointmentsSortBy,
                              currentSortOrder: state.appointmentsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortAppointments('destination'),
                            ),
                            _buildSortableHeaderCell(
                              title: 'Host / Person to Meet',
                              sortKey: 'host_name',
                              width: hostWidth,
                              currentSortBy: state.appointmentsSortBy,
                              currentSortOrder: state.appointmentsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortAppointments('host_name'),
                            ),
                            _buildSortableHeaderCell(
                              title: 'Date & Time',
                              sortKey: 'scheduled_start_at',
                              width: dateTimeWidth,
                              currentSortBy: state.appointmentsSortBy,
                              currentSortOrder: state.appointmentsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortAppointments('scheduled_start_at'),
                            ),
                            _buildSortableHeaderCell(
                              title: 'Status',
                              sortKey: 'status',
                              width: 90,
                              currentSortBy: state.appointmentsSortBy,
                              currentSortOrder: state.appointmentsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortAppointments('status'),
                            ),
                            SizedBox(width: 115, child: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B)))),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

                      // Table Rows
                      if (appointments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: Text('No scheduled appointments found matching criteria.')),
                        )
                      else
                        ...List.generate(appointments.length, (idx) {
                          final item = appointments[idx];
                          final isSelected = selectedAppt?.id == item.id;
                          final isBlocked = item.status.toLowerCase() == 'blocked' || item.status.toLowerCase() == 'blacklisted';
                          final isConfirmed = item.status.toLowerCase() == 'confirmed' || item.status.toLowerCase() == 'approved';

                          return InkWell(
                            onTap: () => notifier.openAppointmentDetail(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : const Color(0xFFEFF6FF))
                                    : (idx.isEven ? Colors.transparent : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.3) : const Color(0xFFFAFAFA))),
                                border: Border(
                                  bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 34,
                                    child: Checkbox(
                                      value: _selectedAppointmentIds.contains(item.id),
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selectedAppointmentIds.add(item.id);
                                          } else {
                                            _selectedAppointmentIds.remove(item.id);
                                          }
                                        });
                                      },
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 25,
                                    child: Text('${idx + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  ),
                                  SizedBox(
                                    width: 44,
                                    child: VisitorAvatar(
                                      photoUrl: item.photoUrl,
                                      name: item.visitorName,
                                      radius: 15,
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(
                                    width: nameWidth,
                                    child: Text(
                                      item.visitorName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: _buildTypePill(item.visitorType),
                                  ),
                                  SizedBox(
                                    width: purposeWidth,
                                    child: Text(
                                      item.purpose,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 95,
                                    child: Text(
                                      item.location,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(
                                    width: hostWidth,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item.hostName,
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (item.hostSubtitle != null && item.hostSubtitle!.isNotEmpty)
                                          Text(
                                            item.hostSubtitle!,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: dateTimeWidth,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item.scheduledDate.isNotEmpty ? item.scheduledDate : '12 May 2024',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                        ),
                                        Text(
                                          '${item.scheduledStartAt} - ${item.scheduledEndAt}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isBlocked
                                            ? const Color(0xFFFEE2E2)
                                            : (isConfirmed ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isBlocked ? 'Blocked' : (isConfirmed ? 'Confirmed' : 'Pending'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isBlocked
                                              ? const Color(0xFFDC2626)
                                              : (isConfirmed ? const Color(0xFF15803D) : const Color(0xFFD97706)),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 115,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: IconButton(
                                            icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF64748B)),
                                            padding: EdgeInsets.zero,
                                            tooltip: 'View Details',
                                            onPressed: () => notifier.openAppointmentDetail(item),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: IconButton(
                                            icon: const Icon(Icons.edit_calendar_outlined, size: 16, color: Color(0xFF2563EB)),
                                            padding: EdgeInsets.zero,
                                            tooltip: 'Reschedule',
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AppointmentRescheduleDialog(appointment: item),
                                              );
                                            },
                                          ),
                                        ),
                                        SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF64748B)),
                                            padding: EdgeInsets.zero,
                                            onSelected: (val) async {
                                              if (val == 'unblock') {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (dialogCtx) => AlertDialog(
                                                    title: const Row(
                                                      children: [
                                                        Icon(Icons.lock_open_rounded, color: Color(0xFF16A34A)),
                                                        SizedBox(width: 8),
                                                        Text('Unblock Visitor'),
                                                      ],
                                                    ),
                                                    content: Text('Lift security restriction and restore campus access for ${item.visitorName}?'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(dialogCtx, false),
                                                        child: const Text('Cancel'),
                                                      ),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                                                        onPressed: () => Navigator.pop(dialogCtx, true),
                                                        child: const Text('Confirm Unblock', style: TextStyle(color: Colors.white)),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true) {
                                                  await notifier.unblockVisitor(item.visitorId.isNotEmpty ? item.visitorId : item.id);
                                                }
                                              } else if (val == 'checkin') {
                                                final pass = await notifier.checkInAppointment(item.id);
                                                if (pass != null && context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Visitor checked in! Gate Pass ${pass['pass_number'] ?? ''} issued.'),
                                                      backgroundColor: const Color(0xFF16A34A),
                                                    ),
                                                  );
                                                  showDialog(
                                                    context: context,
                                                    builder: (ctx) => VisitorGatePassDialog(
                                                      visitor: VisitorItem(
                                                        id: pass['visit_id']?.toString() ?? item.id,
                                                        visitNumber: pass['pass_number']?.toString() ?? 'GP-2024-001',
                                                        visitorId: item.visitorId.isNotEmpty ? item.visitorId : item.id,
                                                        passReference: pass['pass_number']?.toString() ?? 'GP-2024-001',
                                                        visitorName: pass['visitor_name'] ?? item.visitorName,
                                                        phone: item.phone,
                                                        visitorType: item.visitorType,
                                                        category: item.visitorType,
                                                        purpose: item.purpose,
                                                        hostName: item.hostName,
                                                        location: item.location,
                                                        destination: item.location,
                                                        checkInAt: pass['check_in_at']?.toString() ?? DateTime.now().toIso8601String(),
                                                        status: 'Inside',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } else if (val == 'approve') {
                                                notifier.approveAppointment(item.id);
                                              } else if (val == 'reject') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => AppointmentRejectDialog(appointment: item),
                                                );
                                              } else if (val == 'reschedule') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => AppointmentRescheduleDialog(appointment: item),
                                                );
                                              } else if (val == 'cancel') {
                                                notifier.cancelAppointment(item.id);
                                              } else if (val == 'blacklist') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => VisitorRestrictionDialog(
                                                    initialProfile: VisitorProfileItem(
                                                      id: item.visitorId,
                                                      schoolId: '',
                                                      fullName: item.visitorName,
                                                      phone: item.phone,
                                                      visitorType: item.visitorType,
                                                      photoUrl: item.photoUrl,
                                                      idType: item.idType,
                                                      idNumberMasked: item.idNumberMasked,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            itemBuilder: (ctx) {
                                              final isApptBlocked = item.status.toUpperCase() == 'BLOCKED' || item.status.toLowerCase() == 'blacklisted';
                                              if (isApptBlocked) {
                                                return [
                                                  const PopupMenuItem(
                                                    value: 'unblock',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.lock_open_rounded, size: 16, color: Color(0xFF16A34A)),
                                                        SizedBox(width: 8),
                                                        Text('Unblock Visitor', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                                                      ],
                                                    ),
                                                  ),
                                                  const PopupMenuItem(value: 'cancel', child: Text('Cancel Appointment')),
                                                ];
                                              }
                                              return [
                                                const PopupMenuItem(
                                                  value: 'checkin',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.login_rounded, size: 16, color: Color(0xFF16A34A)),
                                                      SizedBox(width: 8),
                                                      Text('Check In Visitor', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(value: 'approve', child: Text('Approve Appointment')),
                                                const PopupMenuItem(value: 'reject', child: Text('Reject Appointment')),
                                                const PopupMenuItem(value: 'reschedule', child: Text('Reschedule Visit')),
                                                const PopupMenuItem(value: 'cancel', child: Text('Cancel Visit')),
                                                const PopupMenuDivider(),
                                                const PopupMenuItem(
                                                  value: 'blacklist',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.block_rounded, size: 16, color: Color(0xFFDC2626)),
                                                      SizedBox(width: 8),
                                                      Text('Blacklist Visitor', style: TextStyle(color: Color(0xFFDC2626))),
                                                    ],
                                                  ),
                                                ),
                                              ];
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              );
            },
          ),

          // Pagination Bar at Bottom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Showing ${state.appointmentPagination.totalRecords == 0 ? 0 : (state.appointmentPagination.page - 1) * state.appointmentPagination.pageSize + 1} - ${(state.appointmentPagination.page * state.appointmentPagination.pageSize).clamp(0, state.appointmentPagination.totalRecords)} of ${state.appointmentPagination.totalRecords} scheduled visitors',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Pagination controls
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    onPressed: state.appointmentPagination.page > 1
                        ? () => notifier.fetchAppointments(page: state.appointmentPagination.page - 1)
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${state.appointmentPagination.page}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    onPressed: state.appointmentPagination.page < state.appointmentPagination.totalPages
                        ? () => notifier.fetchAppointments(page: state.appointmentPagination.page + 1)
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  Text('Rows per page', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<int>.fromMenuItems(
                        value: [10, 25, 50, 100].contains(state.appointmentPagination.pageSize) ? state.appointmentPagination.pageSize : 10,
                        isDense: true,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        items: const [
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 25, child: Text('25')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                          DropdownMenuItem(value: 100, child: Text('100')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            notifier.fetchAppointments(page: 1, pageSize: val);
                          }
                        },
                      ),
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

  // ==========================================================================
  // TYPE PILL BADGE HELPER
  // ==========================================================================
  Widget _buildTypePill(String type) {
    Color bg;
    Color fg;
    switch (type.toLowerCase()) {
      case 'parent':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1E40AF);
        break;
      case 'official':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        break;
      case 'vendor':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFC2410C);
        break;
      case 'relative':
        bg = const Color(0xFFFCE7F3);
        fg = const Color(0xFFBE185D);
        break;
      case 'maintenance':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg), textAlign: TextAlign.center),
    );
  }

  // ==========================================================================
  // RIGHT-SIDE 360° INSPECTOR DRAWER (Matching Screenshot 1)
  // ==========================================================================
  Widget _buildRightInspector(
    BuildContext context,
    bool isDark,
    VisitorsState state,
    VisitorsNotifier notifier,
    ScheduledAppointmentItem? appt,
    AppointmentDetail360? detail,
  ) {
    if (appt == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: Text('Select an appointment to inspect')),
      );
    }

    final isBlocked = appt.status.toLowerCase() == 'blocked' || appt.status.toLowerCase() == 'blacklisted';
    final isConfirmed = appt.status.toLowerCase() == 'confirmed' || appt.status.toLowerCase() == 'approved';

    List<Map<String, dynamic>> docs = [];
    if (detail != null && detail.documents.isNotEmpty) {
      docs = List<Map<String, dynamic>>.from(detail.documents);
    } else {
      docs = [
        {
          'document_name': '${appt.idType} (${appt.idNumberMasked})',
          'document_type': appt.idType,
          'file_name': '${appt.idType.toLowerCase().replaceAll(' ', '_')}.pdf',
          'status': 'Verified',
          'is_verified': true,
          'uploaded_at': appt.scheduledDate,
        },
        {
          'document_name': 'Appointment Pass',
          'document_type': 'Appointment Pass',
          'file_name': 'appointment_pass_${appt.appointmentNumber}.pdf',
          'status': 'Valid',
          'is_verified': true,
          'uploaded_at': appt.scheduledDate,
        },
      ];
    }

    List<Map<String, dynamic>> hist = [];
    if (detail != null && detail.visitHistory.isNotEmpty) {
      hist = List<Map<String, dynamic>>.from(detail.visitHistory);
    }

    return Column(
      children: [
        // Main Details Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drawer Header with "Edit"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Visitor Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AppointmentRescheduleDialog(appointment: appt),
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                        SizedBox(width: 4),
                        Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Avatar & Name Card
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VisitorAvatar(
                    photoUrl: appt.photoUrl,
                    name: appt.visitorName,
                    radius: 28,
                    fontSize: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                appt.visitorName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isBlocked
                                    ? const Color(0xFFFEE2E2)
                                    : (isConfirmed ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isBlocked ? 'Blocked' : (isConfirmed ? 'Confirmed' : 'Pending'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isBlocked
                                      ? const Color(0xFFDC2626)
                                      : (isConfirmed ? const Color(0xFF15803D) : const Color(0xFFD97706)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildProfileField('Type', appt.visitorType, isDark),
                        _buildProfileField('Phone', appt.phone, isDark),
                        _buildProfileField('Email', appt.email ?? 'rajesh@gmail.com', isDark),
                        _buildProfileField('ID Type', appt.idType, isDark),
                        _buildProfileField('ID Number', appt.idNumberMasked, isDark),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3 Sub-tabs: Details | Documents (${docs.length}) | Visit History (${hist.length})
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSubTab(0, 'Details', _activeDetailTab == 0),
                    _buildSubTab(1, 'Documents (${docs.length})', _activeDetailTab == 1),
                    _buildSubTab(2, 'Visit History (${hist.length})', _activeDetailTab == 2),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              const SizedBox(height: 14),

              // Sub-tab content: Key-value details
              if (_activeDetailTab == 0) ...[
                _buildDetailRow(Icons.flag_outlined, 'Purpose', appt.purpose, isDark),
                _buildDetailRow(Icons.place_outlined, 'Location', appt.location, isDark),
                _buildDetailRow(Icons.person_pin, 'Host', '${appt.hostName} (${appt.hostSubtitle ?? 'Class 10 A'})', isDark),
                _buildDetailRow(Icons.calendar_today_outlined, 'Date', appt.scheduledDate.isNotEmpty ? appt.scheduledDate : '12 May 2024', isDark),
                _buildDetailRow(Icons.access_time, 'Time', '${appt.scheduledStartAt} - ${appt.scheduledEndAt}', isDark),
                _buildDetailRow(Icons.group_outlined, 'Expected Visitors', appt.expectedVisitorsText, isDark),
                _buildDetailRow(Icons.directions_car_outlined, 'Vehicle No.', appt.vehicleNumber ?? 'UP16 AB 1234', isDark),
                _buildDetailRow(Icons.chat_bubble_outline, 'Remarks', appt.remarks ?? 'Discussion about academic progress and future plan.', isDark),
              ] else if (_activeDetailTab == 1) ...[
                _buildDocumentsTab(context, isDark, docs, appt),
              ] else ...[
                _buildVisitHistoryTab(context, isDark, hist, appt),
              ],
              const SizedBox(height: 20),

              // Action Buttons Row 1: Approve (green) & Reject (red)
              if (isBlocked) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.block_rounded, size: 20, color: Color(0xFFDC2626)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Visitor is blocked / blacklisted. This appointment is blocked.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () async {
                    final pass = await notifier.checkInAppointment(appt.id);
                    if (pass != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Visitor checked in! Gate Pass ${pass['pass_number'] ?? ''} issued.'),
                          backgroundColor: const Color(0xFF16A34A),
                        ),
                      );
                      showDialog(
                        context: context,
                        builder: (ctx) => VisitorGatePassDialog(
                          visitor: VisitorItem(
                            id: pass['visit_id']?.toString() ?? appt.id,
                            visitNumber: pass['pass_number']?.toString() ?? 'GP-2024-001',
                            visitorId: appt.visitorId.isNotEmpty ? appt.visitorId : appt.id,
                            passReference: pass['pass_number']?.toString() ?? 'GP-2024-001',
                            visitorName: pass['visitor_name']?.toString() ?? appt.visitorName,
                            phone: appt.phone,
                            visitorType: appt.visitorType,
                            category: appt.visitorType,
                            purpose: appt.purpose,
                            hostName: appt.hostName,
                            location: appt.location,
                            destination: appt.location,
                            checkInAt: pass['check_in_at']?.toString() ?? DateTime.now().toIso8601String(),
                            status: 'Inside',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
                  label: const Text('Check In Visitor (Issue Gate Pass)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => notifier.approveAppointment(appt.id),
                      icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                      label: const Text('Approve', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AppointmentRejectDialog(appointment: appt),
                        );
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.white),
                      label: const Text('Reject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Action Buttons Row 2: Reschedule (blue outline) & Cancel Visit (outline)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AppointmentRescheduleDialog(appointment: appt),
                        );
                      },
                      icon: const Icon(Icons.edit_calendar_outlined, size: 16, color: Color(0xFF2563EB)),
                      label: const Text('Reschedule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE)),
                        backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => notifier.cancelAppointment(appt.id),
                      icon: Icon(Icons.cancel_presentation_outlined, size: 16, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
                      label: Text('Cancel Visit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569))),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileField(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 65,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            ' : ',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTab(int index, String label, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _activeDetailTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          const SizedBox(width: 8),
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            ': ',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab(BuildContext context, bool isDark, List<Map<String, dynamic>> docs, ScheduledAppointmentItem appt) {
    final totalDocs = docs.length;
    final totalPages = (totalDocs / _docPageSize).ceil().clamp(1, 999999);
    final currentPage = _docPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _docPageSize;
    final endIndex = (startIndex + _docPageSize).clamp(0, totalDocs);
    final pagedDocs = docs.isNotEmpty ? docs.sublist(startIndex, endIndex) : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Action Bar with Upload Document Button
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              'Documents (${docs.length})',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => VisitorUploadDocumentDialog(
                    visitorId: appt.visitorId,
                    appointmentId: appt.id,
                    visitorName: appt.visitorName,
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
              label: const Text('Upload Document', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (docs.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.description_outlined, size: 36, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text(
                  'No documents uploaded yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload visitor ID proofs or appointment documents.',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => VisitorUploadDocumentDialog(
                        visitorId: appt.visitorId,
                        appointmentId: appt.id,
                        visitorName: appt.visitorName,
                      ),
                    );
                  },
                  icon: const Icon(Icons.upload_file_rounded, size: 14, color: Colors.white),
                  label: const Text('Upload Document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          )
        else ...[
          ...pagedDocs.map((doc) {
            final docId = doc['id']?.toString();
            final docName = doc['document_name']?.toString() ?? doc['file_name']?.toString() ?? 'Document';
            final docType = doc['document_type']?.toString() ?? 'ID Card';
            final isVerified = doc['is_verified'] == true || doc['status'] == 'Verified' || doc['status'] == 'Valid';
            final status = isVerified ? 'Verified' : 'Pending';
            final fileUrl = doc['file_url']?.toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, size: 24, color: Color(0xFFDC2626)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          docName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                docType,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                              ),
                            ),
                            Text(
                              '• $status',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF64748B)),
                    tooltip: 'Download $docName',
                    onPressed: () {
                      if (fileUrl != null && fileUrl.isNotEmpty) {
                        downloadFileWeb(fileUrl, docName);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Downloading $docName...')),
                      );
                    },
                  ),
                  if (docId != null && docId.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      tooltip: 'Delete $docName',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Document'),
                            content: Text('Are you sure you want to delete "$docName"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          ref.read(visitorsProvider.notifier).deleteDocument(docId, appointmentId: appt.id);
                        }
                      },
                    ),
                ],
              ),
            );
          }),
        ],
        _buildPaginationFooter(
          currentPage: currentPage,
          totalPages: totalPages,
          totalItems: totalDocs,
          startIndex: startIndex,
          endIndex: endIndex,
          itemLabel: 'documents',
          isDark: isDark,
          prevKey: const Key('appt_docs_prev'),
          nextKey: const Key('appt_docs_next'),
          onPageChanged: (newPage) => setState(() => _docPage = newPage),
        ),
      ],
    );
  }

  Widget _buildVisitHistoryTab(BuildContext context, bool isDark, List<Map<String, dynamic>> hist, ScheduledAppointmentItem? appt) {
    if (hist.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.history_rounded, size: 36, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(
              'No previous visit history',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      );
    }

    final totalHist = hist.length;
    final totalPages = (totalHist / _historyPageSize).ceil().clamp(1, 999999);
    final currentPage = _historyPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _historyPageSize;
    final endIndex = (startIndex + _historyPageSize).clamp(0, totalHist);
    final pagedHist = hist.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...pagedHist.map((h) {
          final purpose = h['purpose']?.toString() ?? 'General Visit';
          final status = h['status']?.toString() ?? 'Completed';
          final destination = h['destination']?.toString() ?? 'Main Gate';
          final host = h['host_name']?.toString() ?? '-';
          final checkIn = h['check_in_at']?.toString() ?? h['check_in_time']?.toString() ?? '-';
          final passNumber = h['pass_number']?.toString() ?? h['appointment_number']?.toString() ?? '';

          Color statusColor = const Color(0xFF15803D);
          Color statusBg = const Color(0xFFDCFCE7);
          if (status == 'Inside') {
            statusColor = const Color(0xFF16A34A);
            statusBg = const Color(0xFFDCFCE7);
          } else if (status == 'Overstay') {
            statusColor = const Color(0xFFDC2626);
            statusBg = const Color(0xFFFEE2E2);
          } else if (status == 'Scheduled' || status == 'CONFIRMED' || status == 'APPROVED') {
            statusColor = const Color(0xFF7E22CE);
            statusBg = const Color(0xFFF3E8FF);
          } else {
            statusColor = const Color(0xFF475569);
            statusBg = const Color(0xFFF1F5F9);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        purpose,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        status,
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Destination: $destination • Host: $host',
                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
                if (passNumber.isNotEmpty)
                  Text(
                    'Pass #: $passNumber',
                    style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                Text(
                  'Time: $checkIn',
                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          );
        }),
        _buildPaginationFooter(
          currentPage: currentPage,
          totalPages: totalPages,
          totalItems: totalHist,
          startIndex: startIndex,
          endIndex: endIndex,
          itemLabel: 'visits',
          isDark: isDark,
          prevKey: const Key('appt_history_prev'),
          nextKey: const Key('appt_history_next'),
          onPageChanged: (newPage) => setState(() => _historyPage = newPage),
        ),
      ],
    );
  }

  Widget _buildPaginationFooter({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required int startIndex,
    required int endIndex,
    required String itemLabel,
    required bool isDark,
    required ValueChanged<int> onPageChanged,
    Key? prevKey,
    Key? nextKey,
  }) {
    if (totalItems <= 5) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              '${startIndex + 1}-$endIndex of $totalItems',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: prevKey,
                icon: const Icon(Icons.chevron_left_rounded, size: 17),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                color: currentPage > 1
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  '$currentPage/$totalPages',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                key: nextKey,
                icon: const Icon(Icons.chevron_right_rounded, size: 17),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                color: currentPage < totalPages
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildSortableHeaderCell({
    required String title,
    required String sortKey,
    required double width,
    required String currentSortBy,
    required String currentSortOrder,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final isSorted = currentSortBy.toLowerCase() == sortKey.toLowerCase();
    final isAsc = currentSortOrder.toUpperCase() == 'ASC';
    final baseColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: width,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSorted ? const Color(0xFF2563EB) : baseColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              isSorted
                  ? (isAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 13,
              color: isSorted ? const Color(0xFF2563EB) : const Color(0xFF94A3B8).withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class RelatedScheduledVisitorsDialog extends StatefulWidget {
  final List<dynamic> appointments;
  final ValueChanged<String>? onSelectAppointment;

  const RelatedScheduledVisitorsDialog({
    super.key,
    required this.appointments,
    this.onSelectAppointment,
  });

  @override
  State<RelatedScheduledVisitorsDialog> createState() => _RelatedScheduledVisitorsDialogState();
}

class _RelatedScheduledVisitorsDialogState extends State<RelatedScheduledVisitorsDialog> {
  String _filterQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = widget.appointments.where((a) {
      if (_filterQuery.isEmpty) return true;
      final q = _filterQuery.toLowerCase();
      final name = (a['visitor_name'] ?? '').toString().toLowerCase();
      final purpose = (a['purpose'] ?? '').toString().toLowerCase();
      final host = (a['host_name'] ?? '').toString().toLowerCase();
      final status = (a['status'] ?? '').toString().toLowerCase();
      return name.contains(q) || purpose.contains(q) || host.contains(q) || status.contains(q);
    }).toList();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 650),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.people_alt_outlined, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Related Scheduled Visitors',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Complete appointment history and related visits for this host & visitor',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

            // Search Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: TextField(
                onChanged: (v) => setState(() => _filterQuery = v),
                decoration: InputDecoration(
                  hintText: 'Filter by visitor name, purpose, host, or status...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
              ),
            ),

            // Appointments List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No scheduled appointments match your filter.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      itemBuilder: (context, idx) {
                        final item = filtered[idx];
                        final id = item['id']?.toString() ?? '';
                        final name = item['visitor_name']?.toString() ?? 'Visitor';
                        final purpose = item['purpose']?.toString() ?? 'Appointment';
                        final host = item['host_name']?.toString() ?? '-';
                        final location = item['location']?.toString() ?? item['destination']?.toString() ?? '-';
                        final date = item['scheduled_date']?.toString() ?? item['scheduled_start']?.toString() ?? '-';
                        final status = item['status']?.toString() ?? 'Scheduled';
                        final isConfirmed = status.toLowerCase() == 'confirmed' || status.toLowerCase() == 'approved';
                        final isBlocked = status.toLowerCase() == 'blocked' || status.toLowerCase() == 'blacklisted';

                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            if (widget.onSelectAppointment != null && id.isNotEmpty) {
                              widget.onSelectAppointment!(id);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'V',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2563EB), fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$purpose  •  Host: $host  •  Location: $location',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isBlocked
                                            ? const Color(0xFFFEE2E2)
                                            : (isConfirmed ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isBlocked
                                              ? const Color(0xFFDC2626)
                                              : (isConfirmed ? const Color(0xFF15803D) : const Color(0xFFD97706)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      date,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
