import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../../../constants/app_fonts.dart';
import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';
import 'leave_dialogs.dart';

class LeavePermissionsTab extends ConsumerStatefulWidget {
  const LeavePermissionsTab({super.key});

  @override
  ConsumerState<LeavePermissionsTab> createState() => _LeavePermissionsTabState();
}

class _LeavePermissionsTabState extends ConsumerState<LeavePermissionsTab> {
  final _searchCtrl = TextEditingController();
  final _requestsScrollCtrl = ScrollController();
  final _balancesScrollCtrl = ScrollController();
  final _permsScrollCtrl = ScrollController();
  String _userType = 'ALL';
  String _department = 'ALL';
  String _status = 'ALL';
  String _leaveType = 'ALL';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _balanceViewAsCards = false;
  bool _isSwitchingSubTab = false;
  final Set<String> _selectedRequestIds = <String>{};
  final Set<String> _selectedPermissionIds = <String>{};
  bool _selectAllRequestsAcrossPages = false;
  int _permsPage = 1;
  int _permsPageSize = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(attendanceProvider.notifier);
      await notifier.fetchLeaveDashboard();
      if (mounted) {
        notifier.fetchLeaveBalances(background: true);
        notifier.fetchLeaveTypes();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _requestsScrollCtrl.dispose();
    _balancesScrollCtrl.dispose();
    _permsScrollCtrl.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(attendanceProvider.notifier).setLeaveFilters(
      userType: _userType,
      department: _department,
      status: _status,
      leaveType: _leaveType,
      search: _searchCtrl.text.trim(),
      fromDate: _fromDate,
      toDate: _toDate,
    );
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _userType = 'ALL';
      _department = 'ALL';
      _status = 'ALL';
      _leaveType = 'ALL';
      _fromDate = null;
      _toDate = null;
    });
    ref.read(attendanceProvider.notifier).resetLeaveFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dash = state.leaveDashboard;
    final kpi = dash.kpi;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 1150;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP KPI METRICS BAR (5 Cards)
          _buildKpiMetricsRow(kpi, isDark),
          const SizedBox(height: 16),

          // 2. COMPREHENSIVE FILTER & SEARCH BAR
          _buildFilterBar(isDark),
          const SizedBox(height: 18),

          // 3. DUAL-PANE MAIN LAYOUT
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left 72% Pane
                Expanded(
                  flex: 72,
                  child: _buildLeftPane(state, notifier, isDark),
                ),
                const SizedBox(width: 20),
                // Right 28% Sidebar
                Expanded(
                  flex: 28,
                  child: _buildRightSidebar(state, notifier, isDark),
                ),
              ],
            )
          else ...[
            // Stacked for Medium/Small/Mobile Screens
            _buildLeftPane(state, notifier, isDark),
            const SizedBox(height: 24),
            _buildRightSidebar(state, notifier, isDark),
          ],

          const SizedBox(height: 36),
        ],
      ),
    );
  }

  // ==========================================================================
  // 1. KPI METRICS CARDS ROW (5 Cards)
  // ==========================================================================
  Widget _buildKpiMetricsRow(LeaveDashboardKpiModel kpi, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        int crossAxisCount = 5;
        if (totalWidth < 700) {
          crossAxisCount = 2;
        } else if (totalWidth < 1050) {
          crossAxisCount = 3;
        }

        final cards = [
          _buildKpiCard(
            title: 'Total Leave Requests',
            value: '${kpi.totalRequests}',
            subtitle: 'This Month',
            icon: Icons.assignment_outlined,
            iconColor: const Color(0xFF6366F1),
            bgColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Approved Leaves',
            value: '${kpi.approvedLeaves}',
            subtitle: '${kpi.approvedPercentage.toStringAsFixed(1)}% of Total',
            icon: Icons.check_circle_outline,
            iconColor: const Color(0xFF10B981),
            bgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Pending Requests',
            value: '${kpi.pendingRequests}',
            subtitle: '${kpi.pendingPercentage.toStringAsFixed(1)}% of Total',
            icon: Icons.hourglass_empty_rounded,
            iconColor: const Color(0xFFEF4444),
            bgColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Rejected Leaves',
            value: '${kpi.rejectedLeaves}',
            subtitle: '${kpi.rejectedPercentage.toStringAsFixed(1)}% of Total',
            icon: Icons.cancel_outlined,
            iconColor: const Color(0xFFF59E0B),
            bgColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Cancelled Leaves',
            value: '${kpi.cancelledLeaves}',
            subtitle: '${kpi.cancelledPercentage.toStringAsFixed(1)}% of Total',
            icon: Icons.event_busy_outlined,
            iconColor: const Color(0xFF06B6D4),
            bgColor: const Color(0xFF06B6D4).withValues(alpha: 0.1),
            isDark: isDark,
          ),
        ];

        if (crossAxisCount == 5) {
          return Row(
            children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards.map((c) {
            final w = (totalWidth - ((crossAxisCount - 1) * 10)) / crossAxisCount;
            return SizedBox(width: w, child: c);
          }).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 19,
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
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
  // 2. COMPREHENSIVE FILTER & SEARCH BAR
  // ==========================================================================
  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Input
          SizedBox(
            width: 220,
            height: 38,
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _applyFilters(),
              style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Search by name, ID...',
                hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
              ),
            ),
          ),

          // User Type Dropdown
          _buildFilterDropdown(
            value: _userType,
            hint: 'User Type',
            isDark: isDark,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Users')),
              DropdownMenuItem(value: 'TEACHER', child: Text('Teachers')),
              DropdownMenuItem(value: 'STAFF', child: Text('Staff')),
              DropdownMenuItem(value: 'STUDENT', child: Text('Students')),
            ],
            onChanged: (v) => setState(() => _userType = v ?? 'ALL'),
          ),

          // Department Dropdown
          _buildFilterDropdown(
            value: _department,
            hint: 'Department',
            isDark: isDark,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Departments')),
              DropdownMenuItem(value: 'Mathematics', child: Text('Mathematics')),
              DropdownMenuItem(value: 'English', child: Text('English')),
              DropdownMenuItem(value: 'Science', child: Text('Science')),
              DropdownMenuItem(value: 'Social Studies', child: Text('Social Studies')),
              DropdownMenuItem(value: 'Administration', child: Text('Administration')),
              DropdownMenuItem(value: 'General', child: Text('General')),
            ],
            onChanged: (v) => setState(() => _department = v ?? 'ALL'),
          ),

          // Status Dropdown
          _buildFilterDropdown(
            value: _status,
            hint: 'Status',
            isDark: isDark,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Status')),
              DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
              DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
              DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
              DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'ALL'),
          ),

          // Leave Type Dropdown
          _buildFilterDropdown(
            value: _leaveType,
            hint: 'Leave Type',
            isDark: isDark,
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('All Types')),
              DropdownMenuItem(value: 'Casual Leave', child: Text('Casual Leave')),
              DropdownMenuItem(value: 'Medical Leave', child: Text('Medical Leave')),
              DropdownMenuItem(value: 'Earned Leave', child: Text('Earned Leave')),
              DropdownMenuItem(value: 'Sick Leave', child: Text('Sick Leave')),
              DropdownMenuItem(value: 'Comp Off', child: Text('Comp Off')),
            ],
            onChanged: (v) => setState(() => _leaveType = v ?? 'ALL'),
          ),

          // From Date Picker
          _buildDatePickerPill(
            label: _fromDate != null ? DateFormat('dd MMM yyyy').format(_fromDate!) : 'From Date',
            isDark: isDark,
            icon: Icons.calendar_today,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _fromDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _fromDate = picked);
            },
          ),

          // To Date Picker
          _buildDatePickerPill(
            label: _toDate != null ? DateFormat('dd MMM yyyy').format(_toDate!) : 'To Date',
            isDark: isDark,
            icon: Icons.calendar_today,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _toDate ?? DateTime.now(),
                firstDate: _fromDate ?? DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _toDate = picked);
            },
          ),

          // Reset Button
          TextButton(
            onPressed: _resetFilters,
            child: Text(
              'Reset',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),

          // Apply Filters Button
          ElevatedButton(
            onPressed: _applyFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Apply Filters', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required String hint,
    required bool isDark,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDatePickerPill({
    required String label,
    required bool isDark,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // 3. LEFT PANE (Sub-Navigation Tabs + Data Views + Pagination Footer)
  // ==========================================================================
  Widget _buildLeftPane(AttendanceState state, AttendanceNotifier notifier, bool isDark) {
    final totalRequests = state.leaveDashboard.totalCount > 0
        ? state.leaveDashboard.totalCount
        : (state.leaveDashboard.kpi.totalRequests > 0 ? state.leaveDashboard.kpi.totalRequests : state.leaveRequests.length);

    final totalBalances = state.balancesTotalCount > 0
        ? state.balancesTotalCount
        : (state.employeeLeaveBalances.isNotEmpty ? state.employeeLeaveBalances.length : 0);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Title, Tooltip, Export, Calendar View, Apply Leave
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Leave & Permission Requests',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Manage employee leave requests, permissions, quotas, and approvals',
                      child: Icon(Icons.info_outline, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => notifier.exportLeaveRequestsCsv(),
                      icon: const Icon(Icons.file_download_outlined, size: 15),
                      label: const Text('Export', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showLeaveCalendarDialog(),
                      icon: const Icon(Icons.calendar_month_outlined, size: 15),
                      label: const Text('Calendar View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openApplyLeaveDialog(),
                      icon: const Icon(Icons.add, size: 15, color: Colors.white),
                      label: const Text('Apply Leave', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Sub-Navigation Tabs Bar (Scrollable for Responsiveness)
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSubTabItem('REQUESTS', 'Requests ($totalRequests)', state.leaveSubTab, notifier, isDark),
                  _buildSubTabItem('BALANCES', totalBalances > 0 ? 'Leave Balances ($totalBalances)' : 'Leave Balances', state.leaveSubTab, notifier, isDark),
                  _buildSubTabItem('TYPES', 'Leave Types & Policies', state.leaveSubTab, notifier, isDark),
                  _buildSubTabItem('PERMISSIONS', 'Permissions (Short Leaves)', state.leaveSubTab, notifier, isDark),
                  _buildSubTabItem('WORKFLOW', 'Approval Workflow', state.leaveSubTab, notifier, isDark),
                ],
              ),
            ),
          ),

          // Sub-Tab Views (Frame-Deferred Instant Rendering)
          if (_isSwitchingSubTab)
            _buildGeneralSkeleton(isDark)
          else if (state.leaveSubTab == 'REQUESTS')
            _buildRequestsDataTable(state, notifier, isDark)
          else if (state.leaveSubTab == 'BALANCES')
            _buildBalancesSection(state, notifier, isDark)
          else if (state.leaveSubTab == 'TYPES')
            _buildLeaveTypesGridView(state, notifier, isDark)
          else if (state.leaveSubTab == 'PERMISSIONS')
            _buildPermissionsDataTable(state, notifier, isDark)
          else if (state.leaveSubTab == 'WORKFLOW')
            _buildApprovalWorkflowVisualizer(isDark),
        ],
      ),
    );
  }

  Widget _buildSubTabItem(String key, String title, String currentKey, AttendanceNotifier notifier, bool isDark) {
    final isSelected = key == currentKey;
    return InkWell(
      onTap: () {
        if (key == currentKey) return;
        setState(() {
          _isSwitchingSubTab = true;
        });
        notifier.setLeaveSubTab(key);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isSwitchingSubTab = false;
            });
          }
        });
      },
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
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? const Color(0xFF4F46E5)
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // A. REQUESTS DATA TABLE (Flexible, Full-Width with Horizontal Scroll fallback)
  // --------------------------------------------------------------------------
  Widget _buildRequestsDataTable(AttendanceState state, AttendanceNotifier notifier, bool isDark) {
    final requests = state.leaveRequests;
    final totalCount = state.leaveDashboard.totalCount > 0 ? state.leaveDashboard.totalCount : requests.length;

    if (requests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.event_busy_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('No leave requests match the selected filters', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('Try resetting filters or applying for a new leave request', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    // Pagination bounds calculation
    final startIdx = requests.isEmpty ? 0 : ((state.leavePage - 1) * state.leavePageSize) + 1;
    final endIdx = requests.isEmpty ? 0 : math.min(state.leavePage * state.leavePageSize, totalCount);

    return Column(
      children: [
        if (_selectedRequestIds.isNotEmpty || _selectAllRequestsAcrossPages)
          _buildBatchActionBar(
            selectedCount: _selectAllRequestsAcrossPages ? totalCount : _selectedRequestIds.length,
            totalCount: totalCount,
            onSelectAll: () => setState(() {
              _selectedRequestIds.addAll(requests.map((r) => r.id));
              _selectAllRequestsAcrossPages = true;
            }),
            onClearSelection: () => setState(() {
              _selectedRequestIds.clear();
              _selectAllRequestsAcrossPages = false;
            }),
            onApprove: () => _showBulkActionConfirmationDialog(
              context: context,
              action: 'APPROVE',
              itemTypeLabel: 'leave requests',
              count: _selectAllRequestsAcrossPages ? totalCount : _selectedRequestIds.length,
              onConfirm: (remarks) async {
                final success = await notifier.handleBatchLeaveAction(
                  requestIds: _selectedRequestIds.toList(),
                  selectAll: _selectAllRequestsAcrossPages,
                  action: 'APPROVE',
                  remarks: remarks,
                );
                if (success && mounted) {
                  setState(() {
                    _selectedRequestIds.clear();
                    _selectAllRequestsAcrossPages = false;
                  });
                }
              },
            ),
            onReject: () => _showBulkActionConfirmationDialog(
              context: context,
              action: 'REJECT',
              itemTypeLabel: 'leave requests',
              count: _selectAllRequestsAcrossPages ? totalCount : _selectedRequestIds.length,
              onConfirm: (remarks) async {
                final success = await notifier.handleBatchLeaveAction(
                  requestIds: _selectedRequestIds.toList(),
                  selectAll: _selectAllRequestsAcrossPages,
                  action: 'REJECT',
                  remarks: remarks,
                );
                if (success && mounted) {
                  setState(() {
                    _selectedRequestIds.clear();
                    _selectAllRequestsAcrossPages = false;
                  });
                }
              },
            ),
            onCancel: () => _showBulkActionConfirmationDialog(
              context: context,
              action: 'CANCEL',
              itemTypeLabel: 'leave requests',
              count: _selectAllRequestsAcrossPages ? totalCount : _selectedRequestIds.length,
              onConfirm: (remarks) async {
                final success = await notifier.handleBatchLeaveAction(
                  requestIds: _selectedRequestIds.toList(),
                  selectAll: _selectAllRequestsAcrossPages,
                  action: 'CANCEL',
                  remarks: remarks,
                );
                if (success && mounted) {
                  setState(() {
                    _selectedRequestIds.clear();
                    _selectAllRequestsAcrossPages = false;
                  });
                }
              },
            ),
            isDark: isDark,
            itemTypeLabel: 'leave requests',
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            return ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: Scrollbar(
                controller: _requestsScrollCtrl,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _requestsScrollCtrl,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      showCheckboxColumn: true,
                      horizontalMargin: 12,
                      columnSpacing: 12,
                      headingRowHeight: 44,
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 58,
                      headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                      columns: const [
                        DataColumn(label: SizedBox(width: 85, child: Text('ID', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                        DataColumn(label: SizedBox(width: 155, child: Text('Employee', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                        DataColumn(label: SizedBox(width: 95, child: Text('Department', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                        DataColumn(label: SizedBox(width: 95, child: Text('Leave Type', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                        DataColumn(label: SizedBox(width: 85, child: Text('From Date', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                        DataColumn(label: SizedBox(width: 85, child: Text('To Date', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                        DataColumn(label: SizedBox(width: 45, child: Text('Days', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                        DataColumn(label: SizedBox(width: 85, child: Text('Applied On', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                        DataColumn(label: SizedBox(width: 90, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                        DataColumn(label: SizedBox(width: 105, child: Text('Remarks', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                        DataColumn(label: SizedBox(width: 85, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                      ],
                      rows: requests.map((req) {
                        final isSelected = _selectedRequestIds.contains(req.id);
                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedRequestIds.add(req.id);
                              } else {
                                _selectedRequestIds.remove(req.id);
                              }
                            });
                          },
                          cells: [
                            // Request ID
                            DataCell(
                              InkWell(
                                onTap: () => _openLeaveDrawer(req),
                                child: SizedBox(
                                  width: 85,
                                  child: Text(
                                    req.requestCode.isNotEmpty ? req.requestCode : 'LV-${req.id.length >= 4 ? req.id.substring(0, 4).toUpperCase() : req.id}',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5), decoration: TextDecoration.underline),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            // Employee Avatar + Name + Code
                            DataCell(
                              SizedBox(
                                width: 155,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 13,
                                      backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                      backgroundImage: (req.avatarUrl != null && req.avatarUrl!.isNotEmpty) ? NetworkImage(req.avatarUrl!) : null,
                                      child: (req.avatarUrl == null || req.avatarUrl!.isEmpty)
                                          ? Text(req.applicantName.isNotEmpty ? req.applicantName[0].toUpperCase() : 'A', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)))
                                          : null,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            req.applicantName,
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            req.employeeCode.isNotEmpty ? req.employeeCode : 'EMP',
                                            style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Department
                            DataCell(
                              SizedBox(
                                width: 95,
                                child: Text(
                                  req.department,
                                  style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            // Leave Type Colored Badge
                            DataCell(
                              SizedBox(
                                width: 95,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: req.leaveTypeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      req.leaveType,
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: req.leaveTypeColor),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // From Date
                            DataCell(
                              SizedBox(
                                width: 85,
                                child: Text(DateFormat('dd MMM yyyy').format(req.startDate), style: const TextStyle(fontSize: 11.5), maxLines: 1),
                              ),
                            ),
                            // To Date
                            DataCell(
                              SizedBox(
                                width: 85,
                                child: Text(DateFormat('dd MMM yyyy').format(req.endDate), style: const TextStyle(fontSize: 11.5), maxLines: 1),
                              ),
                            ),
                            // Days Count
                            DataCell(
                              SizedBox(
                                width: 45,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    req.daysCount % 1 == 0 ? '${req.daysCount.toInt()}' : '${req.daysCount}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            // Applied On
                            DataCell(
                              SizedBox(
                                width: 85,
                                child: Text(DateFormat('dd MMM yyyy').format(req.appliedAt), style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)), maxLines: 1),
                              ),
                            ),
                            // Status Badge
                            DataCell(
                              SizedBox(
                                width: 90,
                                child: _buildStatusChip(req.status),
                              ),
                            ),
                            // Remarks
                            DataCell(
                              SizedBox(
                                width: 105,
                                child: Text(
                                  req.remarks ?? req.reason,
                                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            // Actions: View Eye + Popup Menu
                            DataCell(
                              SizedBox(
                                width: 85,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility_outlined, size: 17, color: Color(0xFF4F46E5)),
                                      tooltip: 'View Details',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                      onPressed: () => _openLeaveDrawer(req),
                                    ),
                                    const SizedBox(width: 2),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 17),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                      onSelected: (val) async {
                                        if (val == 'VIEW') {
                                          _openLeaveDrawer(req);
                                        } else if (val == 'APPROVE') {
                                          await notifier.handleLeaveAction(req.id, 'APPROVE');
                                        } else if (val == 'REJECT') {
                                          await notifier.handleLeaveAction(req.id, 'REJECT');
                                        } else if (val == 'CANCEL') {
                                          await notifier.handleLeaveAction(req.id, 'CANCEL');
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(value: 'VIEW', child: Text('View Details')),
                                        if (req.status.toUpperCase() == 'PENDING') ...[
                                          const PopupMenuItem(value: 'APPROVE', child: Text('Approve Leave', style: TextStyle(color: Color(0xFF10B981)))),
                                          const PopupMenuItem(value: 'REJECT', child: Text('Reject Leave', style: TextStyle(color: Color(0xFFEF4444)))),
                                        ],
                                        if (req.status.toUpperCase() == 'APPROVED')
                                          const PopupMenuItem(value: 'CANCEL', child: Text('Cancel Leave', style: TextStyle(color: Color(0xFFF59E0B)))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Pagination Footer (Interactive & Accurate)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text(
                'Showing $startIdx to $endIdx of $totalCount requests',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page Size Dropdown
                  Text('Rows per page:', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  const SizedBox(width: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: state.leavePageSize,
                      isDense: true,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 25, child: Text('25')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                        DropdownMenuItem(value: 100, child: Text('100')),
                      ],
                      onChanged: (v) {
                        if (v != null) notifier.setLeavePageSize(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Previous Page Button
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 18),
                    onPressed: state.leavePage > 1 ? () => notifier.setLeavePage(state.leavePage - 1) : null,
                  ),

                  // Numeric Page Buttons (Smart Window)
                  ..._buildPageNumbers(state.leavePage, state.leaveDashboard.totalPages, (p) => notifier.setLeavePage(p)),

                  // Next Page Button
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    onPressed: state.leavePage < state.leaveDashboard.totalPages ? () => notifier.setLeavePage(state.leavePage + 1) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // B. LEAVE BALANCES SECTION (Flexible Full-Width Grid, Stable Sort & Pagination)
  // --------------------------------------------------------------------------
  Widget _buildGeneralSkeleton(bool isDark) {
    final shimmerColor = isDark ? const Color(0xFF334155).withValues(alpha: 0.35) : const Color(0xFFE2E8F0);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(
          6,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 48,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalancesSkeleton(bool isDark) {
    return _buildGeneralSkeleton(isDark);
  }

  Widget _buildBalancesSection(AttendanceState state, AttendanceNotifier notifier, bool isDark) {
    if (state.isLeaveBalancesLoading && state.employeeLeaveBalances.isEmpty) {
      return _buildBalancesSkeleton(isDark);
    }

    final employees = state.employeeLeaveBalances;
    final totalEmployees = state.balancesTotalCount;

    if (employees.isEmpty && state.leaveBalances.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: const Text('No leave balances found for selected filters', style: TextStyle(fontWeight: FontWeight.w600)),
      );
    }

    // Pagination bounds calculation for balances
    final startIdx = employees.isEmpty ? 0 : ((state.balancesPage - 1) * state.balancesPageSize) + 1;
    final endIdx = employees.isEmpty ? 0 : math.min(state.balancesPage * state.balancesPageSize, totalEmployees);

    return Column(
      children: [
        if (state.isLeaveBalancesLoading)
          const LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
            minHeight: 2.5,
          ),
        // View Mode Toggle Bar (Cards vs Table)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Employee Quotas & Balances (${totalEmployees > 0 ? totalEmployees : employees.length})',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.table_rows_rounded, size: 18, color: !_balanceViewAsCards ? const Color(0xFF4F46E5) : Colors.grey),
                    tooltip: 'Full Width Table View',
                    onPressed: () => setState(() => _balanceViewAsCards = false),
                  ),
                  IconButton(
                    icon: Icon(Icons.grid_view_rounded, size: 18, color: _balanceViewAsCards ? const Color(0xFF4F46E5) : Colors.grey),
                    tooltip: 'Grouped Cards View',
                    onPressed: () => setState(() => _balanceViewAsCards = true),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Main Balances Content (Full Width & Flexible)
        if (_balanceViewAsCards && employees.isNotEmpty)
          _buildEmployeeBalancesCards(employees, notifier, isDark)
        else
          _buildBalancesDataTable(state, notifier, isDark),

        // Pagination Footer for Balances
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text(
                'Showing $startIdx to $endIdx of $totalEmployees employees',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page Size Dropdown
                  Text('Rows per page:', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  const SizedBox(width: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: state.balancesPageSize,
                      isDense: true,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 25, child: Text('25')),
                        DropdownMenuItem(value: 50, child: Text('50')),
                      ],
                      onChanged: (v) {
                        if (v != null) notifier.setBalancesPageSize(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Previous Page Button
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 18),
                    onPressed: state.balancesPage > 1 ? () => notifier.setBalancesPage(state.balancesPage - 1) : null,
                  ),

                  // Numeric Page Buttons
                  ..._buildPageNumbers(state.balancesPage, state.balancesTotalPages, (p) => notifier.setBalancesPage(p)),

                  // Next Page Button
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    onPressed: state.balancesPage < state.balancesTotalPages ? () => notifier.setBalancesPage(state.balancesPage + 1) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeBalancesCards(List<EmployeeLeaveBalanceModel> employees, AttendanceNotifier notifier, bool isDark) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: employees.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final emp = employees[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Employee Info Row
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                    backgroundImage: (emp.avatarUrl != null && emp.avatarUrl!.isNotEmpty) ? NetworkImage(emp.avatarUrl!) : null,
                    child: (emp.avatarUrl == null || emp.avatarUrl!.isEmpty)
                        ? Text(emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'A', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.fullName,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        Text(
                          '${emp.employeeCode.isNotEmpty ? emp.employeeCode : "EMP"} • ${emp.department} • ${emp.role.toUpperCase()}',
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Available: ${emp.totalAvailable.toStringAsFixed(1)} / ${emp.totalAllocated.toStringAsFixed(1)} Days',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Balances Breakdown Chips / Mini Bars (Preserves 100% stable sorting)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: emp.balances.map((b) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: b.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: b.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(b.leaveTypeName, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        const SizedBox(width: 6),
                        Text(
                          '${b.availableDays.toStringAsFixed(1)}/${b.allocatedDays.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: b.color),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => showDialog(context: context, builder: (_) => BalanceAdjustmentDialog(balanceRow: b)),
                          child: Icon(Icons.edit, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalancesDataTable(AttendanceState state, AttendanceNotifier notifier, bool isDark) {
    final balances = state.leaveBalances;
    return LayoutBuilder(
      builder: (context, constraints) {
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: Scrollbar(
            controller: _balancesScrollCtrl,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _balancesScrollCtrl,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  horizontalMargin: 12,
                  columnSpacing: 12,
                  headingRowHeight: 44,
                  dataRowMinHeight: 50,
                  dataRowMaxHeight: 56,
                  headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: SizedBox(width: 170, child: Text('Employee', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                    DataColumn(label: SizedBox(width: 110, child: Text('Department', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                    DataColumn(label: SizedBox(width: 110, child: Text('Leave Type', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                    DataColumn(label: SizedBox(width: 70, child: Text('Allocated', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                    DataColumn(label: SizedBox(width: 65, child: Text('Used', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                    DataColumn(label: SizedBox(width: 65, child: Text('Pending', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                    DataColumn(label: SizedBox(width: 75, child: Text('Available', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                    DataColumn(label: SizedBox(width: 90, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                  ],
                rows: balances.map((b) {
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Text(
                            '${b.fullName} (${b.employeeCode.isNotEmpty ? b.employeeCode : "EMP"})',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Text(b.department, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 130,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: b.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                              child: Text(b.leaveTypeName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: b.color), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                      DataCell(SizedBox(width: 80, child: Text(b.allocatedDays.toStringAsFixed(0), style: const TextStyle(fontSize: 12)))),
                      DataCell(SizedBox(width: 80, child: Text(b.usedDays.toStringAsFixed(1), style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444))))),
                      DataCell(SizedBox(width: 80, child: Text(b.pendingDays.toStringAsFixed(1), style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B))))),
                      DataCell(
                        SizedBox(
                          width: 90,
                          child: Text(b.availableDays.toStringAsFixed(1), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 90,
                          child: ElevatedButton.icon(
                            onPressed: () => showDialog(context: context, builder: (_) => BalanceAdjustmentDialog(balanceRow: b)),
                            icon: const Icon(Icons.tune, size: 13),
                            label: const Text('Adjust', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );
    },
  );
  }

  // --------------------------------------------------------------------------
  // C. LEAVE TYPES & POLICIES VIEW
  // --------------------------------------------------------------------------
  Widget _buildLeaveTypesGridView(AttendanceState state, AttendanceNotifier notifier, bool isDark) {
    final types = state.leaveTypes;
    final shimmerColor = isDark ? const Color(0xFF334155).withValues(alpha: 0.4) : const Color(0xFFE2E8F0);

    if (types.isEmpty && !state.isLeaveTypesLoaded) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 36, width: 220, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: List.generate(4, (_) => Container(
                width: 280,
                height: 160,
                decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(12)),
              )),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Configured Leave Policies (${types.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ElevatedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const LeaveTypeDialog()),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Leave Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: types.map((t) {
              return Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: t.color)),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => showDialog(context: context, builder: (_) => LeaveTypeDialog(initialData: t)),
                        ),
                      ],
                    ),
                    Text('Code: ${t.code} • ${t.category}', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54)),
                    const SizedBox(height: 8),
                    _buildTypeAttribute('Annual Quota', '${t.annualEntitlement} Days'),
                    _buildTypeAttribute('Carry Forward', t.carryForwardAllowed ? 'Up to ${t.maxCarryForward} Days' : 'Not Allowed'),
                    _buildTypeAttribute('Doc Required', t.docRequired ? 'After ${t.docRequiredAfterDays} Days' : 'No'),
                    _buildTypeAttribute('Half-Day Allowed', t.allowHalfDay ? 'Yes' : 'No'),
                    const SizedBox(height: 8),
                    _buildRoleBadges(t.applicableRoles, isDark),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadges(List<String> roles, bool isDark) {
    if (roles.isEmpty || roles.contains('all')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public, size: 12, color: Color(0xFF4F46E5)),
            SizedBox(width: 4),
            Text('All Roles', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
          ],
        ),
      );
    }

    final visibleRoles = roles.take(3).toList();
    final remainingCount = roles.length - visibleRoles.length;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...visibleRoles.map((r) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
          ),
          child: Text(
            r.toUpperCase(),
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6)),
          ),
        )),
        if (remainingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+$remainingCount more',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTypeAttribute(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // D. PERMISSIONS DATA TABLE (Flexible Full Width)
  // --------------------------------------------------------------------------
  Widget _buildPermissionsDataTable(AttendanceState state, AttendanceNotifier notifier, bool isDark) {
    final perms = state.permissionRequests;
    final shimmerColor = isDark ? const Color(0xFF334155).withValues(alpha: 0.4) : const Color(0xFFE2E8F0);

    if (perms.isEmpty && !state.isPermissionRequestsLoaded) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 36, width: 240, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 16),
            ...List.generate(4, (_) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 48,
              decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(8)),
            )),
          ],
        ),
      );
    }

    final totalPerms = perms.length;
    final totalPermsPages = (totalPerms / _permsPageSize).ceil().clamp(1, 9999);
    if (_permsPage > totalPermsPages) _permsPage = totalPermsPages;
    final pStart = perms.isEmpty ? 0 : (_permsPage - 1) * _permsPageSize;
    final pEnd = perms.isEmpty ? 0 : math.min(pStart + _permsPageSize, totalPerms);
    final pagePerms = perms.isEmpty ? <PermissionRequestModel>[] : perms.sublist(pStart, pEnd);

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Permission / Short Leave Requests ($totalPerms)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ElevatedButton.icon(
                onPressed: () => showDialog(context: context, builder: (_) => const PermissionRequestDialog()),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Request Permission', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_selectedPermissionIds.isNotEmpty)
            _buildBatchActionBar(
              selectedCount: _selectedPermissionIds.length,
              totalCount: totalPerms,
              onSelectAll: () => setState(() => _selectedPermissionIds.addAll(perms.map((p) => p.id))),
              onClearSelection: () => setState(() => _selectedPermissionIds.clear()),
              onApprove: () => _showBulkActionConfirmationDialog(
                context: context,
                action: 'APPROVE',
                itemTypeLabel: 'permissions',
                count: _selectedPermissionIds.length,
                onConfirm: (remarks) async {
                  final success = await notifier.handleBatchPermissionAction(
                    permissionIds: _selectedPermissionIds.toList(),
                    action: 'APPROVE',
                    remarks: remarks,
                  );
                  if (success && mounted) {
                    setState(() => _selectedPermissionIds.clear());
                  }
                },
              ),
              onReject: () => _showBulkActionConfirmationDialog(
                context: context,
                action: 'REJECT',
                itemTypeLabel: 'permissions',
                count: _selectedPermissionIds.length,
                onConfirm: (remarks) async {
                  final success = await notifier.handleBatchPermissionAction(
                    permissionIds: _selectedPermissionIds.toList(),
                    action: 'REJECT',
                    remarks: remarks,
                  );
                  if (success && mounted) {
                    setState(() => _selectedPermissionIds.clear());
                  }
                },
              ),
              onCancel: () => _showBulkActionConfirmationDialog(
                context: context,
                action: 'CANCEL',
                itemTypeLabel: 'permissions',
                count: _selectedPermissionIds.length,
                onConfirm: (remarks) async {
                  final success = await notifier.handleBatchPermissionAction(
                    permissionIds: _selectedPermissionIds.toList(),
                    action: 'CANCEL',
                    remarks: remarks,
                  );
                  if (success && mounted) {
                    setState(() => _selectedPermissionIds.clear());
                  }
                },
              ),
              isDark: isDark,
              itemTypeLabel: 'permissions',
            ),
          if (perms.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No permission requests recorded.')))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const minTableWidth = 1000.0;
                final tableWidth = math.max(constraints.maxWidth, minTableWidth);

                return ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: Scrollbar(
                    controller: _permsScrollCtrl,
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: SingleChildScrollView(
                      controller: _permsScrollCtrl,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                      child: DataTable(
                        showCheckboxColumn: true,
                        horizontalMargin: 16,
                        columnSpacing: 18,
                        headingRowHeight: 46,
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 58,
                        headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: SizedBox(width: 100, child: Text('Code', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                          DataColumn(label: SizedBox(width: 180, child: Text('Employee', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                          DataColumn(label: SizedBox(width: 130, child: Text('Type', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                          DataColumn(label: SizedBox(width: 100, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                          DataColumn(label: SizedBox(width: 110, child: Text('Time Range', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                          DataColumn(label: SizedBox(width: 70, child: Text('Duration', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                          DataColumn(label: SizedBox(width: 100, child: Text('Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                          DataColumn(label: SizedBox(width: 85, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))),
                        ],
                        rows: pagePerms.map((p) {
                          final isSelected = _selectedPermissionIds.contains(p.id);
                          return DataRow(
                            selected: isSelected,
                            onSelectChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedPermissionIds.add(p.id);
                                } else {
                                  _selectedPermissionIds.remove(p.id);
                                }
                              });
                            },
                            cells: [
                              DataCell(
                                InkWell(
                                  onTap: () => _openPermissionDrawer(p),
                                  child: SizedBox(
                                    width: 100,
                                    child: Text(
                                      p.requestCode.isNotEmpty ? p.requestCode : (p.id.length > 8 ? p.id.substring(0, 8) : p.id),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF06B6D4), decoration: TextDecoration.underline),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 180,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 13,
                                        backgroundColor: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                                        backgroundImage: (p.avatarUrl != null && p.avatarUrl!.isNotEmpty) ? NetworkImage(p.avatarUrl!) : null,
                                        child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                                            ? Text(p.applicantName.isNotEmpty ? p.applicantName[0].toUpperCase() : 'A', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF06B6D4)))
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(p.applicantName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            Text(
                                              '${p.employeeCode.isNotEmpty ? p.employeeCode : 'EMP'} • ${p.department}',
                                              style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 130,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        p.permissionType.replaceAll('_', ' '),
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF06B6D4)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(SizedBox(width: 100, child: Text(DateFormat('dd MMM yyyy').format(p.permissionDate), style: const TextStyle(fontSize: 12), maxLines: 1))),
                              DataCell(SizedBox(width: 110, child: Text('${_formatTimeClean(p.startTime)} - ${_formatTimeClean(p.endTime)}', style: const TextStyle(fontSize: 12), maxLines: 1))),
                              DataCell(
                                SizedBox(
                                  width: 70,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                    child: Text('${p.durationHours} hrs', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                                  ),
                                ),
                              ),
                              DataCell(SizedBox(width: 100, child: _buildStatusChip(p.status))),
                              DataCell(
                                SizedBox(
                                  width: 85,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility_outlined, size: 17, color: Color(0xFF06B6D4)),
                                        tooltip: 'View Details',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                        onPressed: () => _openPermissionDrawer(p),
                                      ),
                                      const SizedBox(width: 2),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, size: 17),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                        onSelected: (val) async {
                                          if (val == 'VIEW') {
                                            _openPermissionDrawer(p);
                                          } else if (val == 'APPROVE') {
                                            await notifier.handlePermissionAction(permissionId: p.id, action: 'APPROVE');
                                          } else if (val == 'REJECT') {
                                            await notifier.handlePermissionAction(permissionId: p.id, action: 'REJECT');
                                          } else if (val == 'CANCEL') {
                                            await notifier.handlePermissionAction(permissionId: p.id, action: 'CANCEL');
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(value: 'VIEW', child: Text('View Details')),
                                          if (p.status.toUpperCase() == 'PENDING') ...[
                                            const PopupMenuItem(value: 'APPROVE', child: Text('Approve Permission', style: TextStyle(color: Color(0xFF10B981)))),
                                            const PopupMenuItem(value: 'REJECT', child: Text('Reject Permission', style: TextStyle(color: Color(0xFFEF4444)))),
                                          ],
                                          if (p.status.toUpperCase() == 'APPROVED')
                                            const PopupMenuItem(value: 'CANCEL', child: Text('Cancel Permission', style: TextStyle(color: Color(0xFFF59E0B)))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Pagination Footer for Permissions
          if (perms.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Text(
                    'Showing ${totalPerms == 0 ? 0 : pStart + 1} to $pEnd of $totalPerms requests',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Rows per page:', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      const SizedBox(width: 6),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _permsPageSize,
                          isDense: true,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          items: const [
                            DropdownMenuItem(value: 10, child: Text('10')),
                            DropdownMenuItem(value: 25, child: Text('25')),
                            DropdownMenuItem(value: 50, child: Text('50')),
                            DropdownMenuItem(value: 100, child: Text('100')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _permsPageSize = v;
                                _permsPage = 1;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 18),
                        onPressed: _permsPage > 1 ? () => setState(() => _permsPage--) : null,
                      ),
                      ..._buildPageNumbers(_permsPage, totalPermsPages, (p) => setState(() => _permsPage = p)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 18),
                        onPressed: _permsPage < totalPermsPages ? () => setState(() => _permsPage++) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // E. APPROVAL WORKFLOW VISUALIZER
  // --------------------------------------------------------------------------
  Widget _buildApprovalWorkflowVisualizer(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('3-Stage Hierarchical Approval Engine', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Leave applications follow an institutional hierarchy with automatic SLA escalation and instant attendance status sync.',
            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              if (isNarrow) {
                return Column(
                  children: [
                    _buildWorkflowNode(1, 'Applicant Submits', 'Teacher / Staff / Student submits request with reason and proof.', Icons.send_rounded, const Color(0xFF6366F1), isDark),
                    const SizedBox(height: 12),
                    const Icon(Icons.arrow_downward_rounded, color: Colors.grey, size: 24),
                    const SizedBox(height: 12),
                    _buildWorkflowNode(2, 'Reporting Manager Review', 'HOD or Assigned Manager reviews within 24h SLA.', Icons.supervisor_account_rounded, const Color(0xFFF59E0B), isDark),
                    const SizedBox(height: 12),
                    const Icon(Icons.arrow_downward_rounded, color: Colors.grey, size: 24),
                    _buildWorkflowNode(3, 'Attendance Auto-Sync', 'On-Leave status marked across student and staff rosters automatically.', Icons.sync_rounded, const Color(0xFF10B981), isDark),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWorkflowNode(1, 'Applicant Submits', 'Teacher / Staff / Student submits request with reason and proof.', Icons.send_rounded, const Color(0xFF6366F1), isDark),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.grey, size: 24),
                  _buildWorkflowNode(2, 'Reporting Manager Review', 'HOD or Assigned Manager reviews within 24h SLA.', Icons.supervisor_account_rounded, const Color(0xFFF59E0B), isDark),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.grey, size: 24),
                  _buildWorkflowNode(3, 'Attendance Auto-Sync', 'On-Leave status marked across student and staff rosters automatically.', Icons.sync_rounded, const Color(0xFF10B981), isDark),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowNode(int step, String title, String desc, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text('Step $step: $title', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // 4. RIGHT SIDEBAR (4 Specialized Cards with Fixed Clean Donut Chart)
  // ==========================================================================
  Widget _buildRightSidebar(AttendanceState state, AttendanceNotifier notifier, bool isDark) {
    final balances = state.leaveDashboard.balanceSummary;
    final kpi = state.leaveDashboard.kpi;
    final upcoming = state.leaveDashboard.upcomingLeaves;

    return Column(
      children: [
        // Card 1: Leave Balance Summary
        _buildSidebarCard(
          title: 'Leave Balance Summary',
          tooltip: 'Your current academic year leave allocation & balance',
          actionText: 'View Full Balance ->',
          onAction: () => notifier.setLeaveSubTab('BALANCES'),
          isDark: isDark,
          child: balances.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No balances available', style: TextStyle(fontSize: 12))))
              : Column(
                  children: balances.map((b) => _buildBalanceProgressBar(b, isDark)).toList(),
                ),
        ),
        const SizedBox(height: 16),

        // Card 2: Leave Statistics (Clean, Perfectly Centered Donut Chart)
        _buildSidebarCard(
          title: 'Leave Statistics',
          tooltip: 'Distribution of leave applications by status',
          isDark: isDark,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('This Month', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: CustomPaint(
                    painter: _DonutChartPainter(
                      approved: kpi.approvedLeaves.toDouble(),
                      pending: kpi.pendingRequests.toDouble(),
                      rejected: kpi.rejectedLeaves.toDouble(),
                      cancelled: kpi.cancelledLeaves.toDouble(),
                      total: kpi.totalRequests > 0 ? kpi.totalRequests : 1,
                      isDark: isDark,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${kpi.totalRequests}',
                            style: TextStyle(
                              fontSize: 22,
                              fontFamily: AppFonts.heading,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Legend Rows
              _buildChartLegendRow('Approved', kpi.approvedLeaves, kpi.approvedPercentage, const Color(0xFF10B981), isDark),
              _buildChartLegendRow('Pending', kpi.pendingRequests, kpi.pendingPercentage, const Color(0xFFEF4444), isDark),
              _buildChartLegendRow('Rejected', kpi.rejectedLeaves, kpi.rejectedPercentage, const Color(0xFFF59E0B), isDark),
              _buildChartLegendRow('Cancelled', kpi.cancelledLeaves, kpi.cancelledPercentage, const Color(0xFF06B6D4), isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card 3: Quick Actions (6 Grid Tiles)
        _buildSidebarCard(
          title: 'Quick Actions',
          tooltip: 'Fast shortcuts for common leave tasks',
          isDark: isDark,
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.1,
            children: [
              _buildQuickActionTile('Apply Leave', Icons.add_circle_outline, const Color(0xFF4F46E5), () => _openApplyLeaveDialog(), isDark),
              _buildQuickActionTile('Permission Req', Icons.timer_outlined, const Color(0xFF06B6D4), () => showDialog(context: context, builder: (_) => const PermissionRequestDialog()), isDark),
              _buildQuickActionTile('My Balance', Icons.account_balance_wallet_outlined, const Color(0xFF10B981), () => notifier.setLeaveSubTab('BALANCES'), isDark),
              _buildQuickActionTile('Leave Calendar', Icons.calendar_month_outlined, const Color(0xFF8B5CF6), () => _showLeaveCalendarDialog(), isDark),
              _buildQuickActionTile('Leave Policies', Icons.policy_outlined, const Color(0xFFF59E0B), () => notifier.setLeaveSubTab('TYPES'), isDark),
              _buildQuickActionTile('Approval Desk', Icons.how_to_reg_outlined, const Color(0xFFEC4899), () => notifier.setLeaveSubTab('REQUESTS'), isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card 4: Upcoming Leaves
        _buildSidebarCard(
          title: 'Upcoming Leaves',
          tooltip: 'Employees on approved scheduled leave',
          actionText: 'View All ->',
          onAction: () => notifier.setLeaveSubTab('REQUESTS'),
          isDark: isDark,
          child: upcoming.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No upcoming leaves scheduled', style: TextStyle(fontSize: 12, color: Colors.grey))))
              : Column(
                  children: upcoming.map((u) => _buildUpcomingLeaveItem(u, isDark)).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildSidebarCard({
    required String title,
    required String tooltip,
    String? actionText,
    VoidCallback? onAction,
    required Widget child,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: tooltip,
                child: Icon(Icons.info_outline, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: onAction,
                child: Text(
                  actionText,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceProgressBar(LeaveBalanceSummaryItemModel item, bool isDark) {
    final progress = item.allocatedDays > 0 ? (item.availableDays / item.allocatedDays).clamp(0.0, 1.0) : 1.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.leaveTypeName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                '${item.availableDays.toStringAsFixed(1)} / ${item.allocatedDays.toStringAsFixed(0)} left',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: item.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(item.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegendRow(String label, int count, double percentage, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
          ),
          Text(
            '$count (${percentage.toStringAsFixed(1)}%)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile(String title, IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingLeaveItem(UpcomingLeaveItemModel item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
            backgroundImage: (item.avatarUrl != null && item.avatarUrl!.isNotEmpty) ? NetworkImage(item.avatarUrl!) : null,
            child: (item.avatarUrl == null || item.avatarUrl!.isEmpty)
                ? Text(item.employeeName.isNotEmpty ? item.employeeName[0].toUpperCase() : 'A', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.employeeName,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                Text(
                  '${item.leaveType} • ${item.dateRangeFormatted}',
                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    switch (status.toUpperCase()) {
      case 'APPROVED':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF10B981);
        break;
      case 'PENDING':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
        fg = const Color(0xFFEF4444);
        break;
      case 'REJECTED':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFD97706);
        break;
      case 'CANCELLED':
        bg = const Color(0xFF06B6D4).withValues(alpha: 0.15);
        fg = const Color(0xFF0891B2);
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildBatchActionBar({
    required int selectedCount,
    required int totalCount,
    required VoidCallback onSelectAll,
    required VoidCallback onClearSelection,
    required VoidCallback onApprove,
    required VoidCallback onReject,
    required VoidCallback? onCancel,
    required bool isDark,
    required String itemTypeLabel,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : const Color(0xFFBFDBFE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$selectedCount $itemTypeLabel selected',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: onSelectAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Select All ($totalCount)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6)),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: onClearSelection,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: Text('Approve ($selectedCount)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.cancel_rounded, size: 16),
                label: Text('Reject ($selectedCount)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.remove_circle_outline, size: 16),
                  label: Text('Cancel ($selectedCount)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF59E0B),
                    side: const BorderSide(color: Color(0xFFF59E0B)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showBulkActionConfirmationDialog({
    required BuildContext context,
    required String action, // APPROVE, REJECT, CANCEL
    required String itemTypeLabel,
    required int count,
    required Future<void> Function(String? remarks) onConfirm,
  }) {
    final remarksCtrl = TextEditingController();
    Color actionColor = const Color(0xFF10B981);
    IconData actionIcon = Icons.check_circle_rounded;
    if (action == 'REJECT') {
      actionColor = const Color(0xFFEF4444);
      actionIcon = Icons.cancel_rounded;
    } else if (action == 'CANCEL') {
      actionColor = const Color(0xFFF59E0B);
      actionIcon = Icons.remove_circle_outline;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(actionIcon, color: actionColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bulk $action ($count $itemTypeLabel)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to $action $count selected $itemTypeLabel? This action will automatically update leave balances and synchronize records.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: remarksCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Remarks / Reason (Optional)',
                  hintText: 'Enter review remarks or reason...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                final remarks = remarksCtrl.text.trim().isNotEmpty ? remarksCtrl.text.trim() : null;
                await onConfirm(remarks);
              },
              style: FilledButton.styleFrom(backgroundColor: actionColor),
              child: Text('Confirm $action ($count)', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildPageNumbers(int currentPage, int totalPages, ValueChanged<int> onPageSelected) {
    if (totalPages <= 1) {
      return [
        _buildPageBtn(1, true, () {}),
      ];
    }

    final List<Widget> items = [];
    const maxButtons = 5;
    int start = math.max(1, currentPage - 2);
    int end = math.min(totalPages, start + maxButtons - 1);
    if (end - start < maxButtons - 1) {
      start = math.max(1, end - maxButtons + 1);
    }

    if (start > 1) {
      items.add(_buildPageBtn(1, currentPage == 1, () => onPageSelected(1)));
      if (start > 2) {
        items.add(const Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Text('...')));
      }
    }

    for (int p = start; p <= end; p++) {
      items.add(_buildPageBtn(p, currentPage == p, () => onPageSelected(p)));
    }

    if (end < totalPages) {
      if (end < totalPages - 1) {
        items.add(const Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Text('...')));
      }
      items.add(_buildPageBtn(totalPages, currentPage == totalPages, () => onPageSelected(totalPages)));
    }

    return items;
  }

  Widget _buildPageBtn(int page, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$page',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // MODALS & DRAWERS
  // ==========================================================================
  void _openApplyLeaveDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const ApplyLeaveDialog(),
    );
  }

  void _openLeaveDrawer(AttendanceLeaveRequestModel request) {
    Scaffold.of(context).openEndDrawer();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'LeaveDetails',
      pageBuilder: (ctx, _, __) => Align(
        alignment: Alignment.centerRight,
        child: LeaveDetailDrawer(request: request),
      ),
    );
  }

  void _openPermissionDrawer(PermissionRequestModel permission) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'PermissionDetails',
      pageBuilder: (ctx, _, __) => Align(
        alignment: Alignment.centerRight,
        child: PermissionDetailDrawer(permission: permission),
      ),
    );
  }

  String _formatTimeClean(String t) {
    if (t.trim().isEmpty) return '--:--';
    final parts = t.trim().split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return t;
  }

  void _showLeaveCalendarDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const LeaveCalendarViewDialog(),
    );
  }
}

// ============================================================================
// CUSTOM DONUT CHART PAINTER (Flawlessly Centered & Bounded)
// ============================================================================
class _DonutChartPainter extends CustomPainter {
  final double approved;
  final double pending;
  final double rejected;
  final double cancelled;
  final int total;
  final bool isDark;

  _DonutChartPainter({
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.cancelled,
    required this.total,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 16.0;
    final radius = (math.min(size.width, size.height) / 2) - (strokeWidth / 2) - 4;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    canvas.drawCircle(center, radius, basePaint);

    final sum = approved + pending + rejected + cancelled;
    if (sum <= 0) return;

    final slices = [
      {'val': approved, 'color': const Color(0xFF10B981)},
      {'val': pending, 'color': const Color(0xFFEF4444)},
      {'val': rejected, 'color': const Color(0xFFF59E0B)},
      {'val': cancelled, 'color': const Color(0xFF06B6D4)},
    ];

    double startAngle = -math.pi / 2;
    for (final slice in slices) {
      final val = slice['val'] as double;
      final color = slice['color'] as Color;
      if (val <= 0) continue;

      final sweepAngle = (val / sum) * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.approved != approved ||
        oldDelegate.pending != pending ||
        oldDelegate.rejected != rejected ||
        oldDelegate.cancelled != cancelled ||
        oldDelegate.total != total ||
        oldDelegate.isDark != isDark;
  }
}
