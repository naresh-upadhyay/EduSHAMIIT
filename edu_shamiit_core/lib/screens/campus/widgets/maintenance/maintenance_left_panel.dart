import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/maintenance_provider.dart';

class MaintenanceLeftPanel extends ConsumerStatefulWidget {
  final VoidCallback onOpenRaiseModal;
  final VoidCallback? onOpenPlanModal;
  final VoidCallback? onOpenVendorsModal;

  const MaintenanceLeftPanel({
    super.key,
    required this.onOpenRaiseModal,
    this.onOpenPlanModal,
    this.onOpenVendorsModal,
  });

  @override
  ConsumerState<MaintenanceLeftPanel> createState() => _MaintenanceLeftPanelState();
}

class _MaintenanceLeftPanelState extends ConsumerState<MaintenanceLeftPanel> {
  String _selectedBuilding = 'all';
  String _selectedType = 'All Types';
  String _selectedPriority = 'All Priorities';
  String _selectedStatus = 'All Status';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maintenanceProvider);
    final notifier = ref.read(maintenanceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Primary Action Button: "+ Raise Maintenance Request"
          ElevatedButton.icon(
            onPressed: widget.onOpenRaiseModal,
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text(
              'Raise Maintenance Request',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Navigation Views Card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildNavItem(
                  title: 'All Requests',
                  badge: '${state.kpis.totalRequests}',
                  icon: Icons.calendar_today_outlined,
                  isSelected: state.activeView == 'all',
                  onTap: () => notifier.setActiveView('all'),
                  isDark: isDark,
                ),
                _buildNavItem(
                  title: 'My Requests',
                  badge: '${state.kpis.myRequests}',
                  icon: Icons.person_outline_rounded,
                  isSelected: state.activeView == 'my_requests',
                  onTap: () => notifier.setActiveView('my_requests'),
                  isDark: isDark,
                ),
                _buildNavItem(
                  title: 'Assigned to Me',
                  badge: '${state.kpis.assignedToMe}',
                  icon: Icons.assignment_ind_outlined,
                  isSelected: state.activeView == 'assigned_to_me',
                  onTap: () => notifier.setActiveView('assigned_to_me'),
                  isDark: isDark,
                ),
                _buildNavItem(
                  title: 'Overdue',
                  badge: '${state.kpis.overdue}',
                  badgeColor: const Color(0xFFEF4444),
                  icon: Icons.warning_amber_rounded,
                  isSelected: state.activeView == 'overdue',
                  onTap: () => notifier.setActiveView('overdue'),
                  isDark: isDark,
                ),
                _buildNavItem(
                  title: 'High Priority',
                  badge: '${state.kpis.highPriority}',
                  badgeColor: const Color(0xFFEF4444),
                  icon: Icons.priority_high_rounded,
                  isSelected: state.activeView == 'high_priority',
                  onTap: () => notifier.setActiveView('high_priority'),
                  isDark: isDark,
                ),
                _buildNavItem(
                  title: 'Scheduled Maintenance',
                  badge: '${state.kpis.scheduled}',
                  badgeColor: const Color(0xFF8B5CF6),
                  icon: Icons.schedule_rounded,
                  isSelected: state.activeView == 'scheduled',
                  onTap: () => notifier.setActiveView('scheduled'),
                  isDark: isDark,
                ),
                const Divider(height: 1, thickness: 1),
                _buildNavItem(
                  title: 'Preventive Maintenance',
                  icon: Icons.event_repeat_rounded,
                  isSelected: state.activeView == 'preventive',
                  onTap: () => notifier.setActiveView('preventive'),
                  isDark: isDark,
                ),
                _buildNavItem(
                  title: 'Maintenance Plans',
                  badge: '${state.plans.length}',
                  icon: Icons.fact_check_outlined,
                  isSelected: state.activeView == 'plans',
                  onTap: () => notifier.setActiveView('plans'),
                  isDark: isDark,
                ),
                _buildNavItem(
                  title: 'Assets & Equipment',
                  icon: Icons.inventory_2_outlined,
                  isSelected: state.activeView == 'assets',
                  onTap: () => notifier.setActiveView('assets'),
                  isDark: isDark,
                ),
                _buildNavItem(
                  title: 'Vendors & Contracts',
                  badge: '${state.vendors.length}',
                  icon: Icons.handshake_outlined,
                  isSelected: state.activeView == 'vendors',
                  onTap: () => notifier.setActiveView('vendors'),
                  isDark: isDark,
                ),
                const Divider(height: 1, thickness: 1),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final res = await notifier.generateDuePreventivePlans();
                      final count = res['generated_count'] ?? 0;
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(count > 0 ? '$count due preventive work order(s) generated!' : 'All preventive maintenance plans are up to date!'),
                            backgroundColor: const Color(0xFF059669),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.autorenew_rounded, size: 15),
                    label: const Text('Generate Due Work Orders', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Quick Filters Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      'Quick Filters',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Building filter
                Text('Building', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted)),
                const SizedBox(height: 4),
                _buildDropdown(
                  value: _selectedBuilding,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Buildings')),
                    DropdownMenuItem(value: 'b1', child: Text('B1 - Academic Block')),
                    DropdownMenuItem(value: 'b2', child: Text('B2 - Senior Block')),
                    DropdownMenuItem(value: 'b3', child: Text('B3 - Library Block')),
                    DropdownMenuItem(value: 'b4', child: Text('B4 - Auditorium')),
                  ],
                  onChanged: (val) => setState(() => _selectedBuilding = val ?? 'all'),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),

                // Request Type filter
                Text('Request Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted)),
                const SizedBox(height: 4),
                _buildDropdown(
                  value: _selectedType,
                  items: const [
                    DropdownMenuItem(value: 'All Types', child: Text('All Types')),
                    DropdownMenuItem(value: 'HVAC', child: Text('HVAC (AC)')),
                    DropdownMenuItem(value: 'Electrical', child: Text('Electrical')),
                    DropdownMenuItem(value: 'Plumbing', child: Text('Plumbing')),
                    DropdownMenuItem(value: 'Civil', child: Text('Civil / Building')),
                    DropdownMenuItem(value: 'Furniture', child: Text('Furniture')),
                    DropdownMenuItem(value: 'AV Equipment', child: Text('AV Equipment')),
                    DropdownMenuItem(value: 'Sanitation', child: Text('Sanitation')),
                    DropdownMenuItem(value: 'IT / Network', child: Text('IT / Network')),
                  ],
                  onChanged: (val) => setState(() => _selectedType = val ?? 'All Types'),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),

                // Priority filter
                Text('Priority', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted)),
                const SizedBox(height: 4),
                _buildDropdown(
                  value: _selectedPriority,
                  items: const [
                    DropdownMenuItem(value: 'All Priorities', child: Text('All Priorities')),
                    DropdownMenuItem(value: 'Critical', child: Text('Critical')),
                    DropdownMenuItem(value: 'High', child: Text('High')),
                    DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'Low', child: Text('Low')),
                  ],
                  onChanged: (val) => setState(() => _selectedPriority = val ?? 'All Priorities'),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),

                // Status filter
                Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted)),
                const SizedBox(height: 4),
                _buildDropdown(
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'All Status', child: Text('All Status')),
                    DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'Assigned', child: Text('Assigned')),
                    DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                    DropdownMenuItem(value: 'Scheduled', child: Text('Scheduled')),
                    DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
                    DropdownMenuItem(value: 'Closed', child: Text('Closed')),
                  ],
                  onChanged: (val) => setState(() => _selectedStatus = val ?? 'All Status'),
                  isDark: isDark,
                ),
                const SizedBox(height: 10),

                // Date Range Display & Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Date Range', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted)),
                    if (state.dateRangeStart != null)
                      InkWell(
                        onTap: () => notifier.clearDateRange(),
                        child: const Text(
                          'Clear',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2027),
                      initialDateRange: (state.dateRangeStart != null && state.dateRangeEnd != null)
                          ? DateTimeRange(start: state.dateRangeStart!, end: state.dateRangeEnd!)
                          : DateTimeRange(
                              start: DateTime.now().subtract(const Duration(days: 7)),
                              end: DateTime.now(),
                            ),
                    );
                    if (picked != null) {
                      notifier.setDateRange(picked.start, picked.end);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, size: 15, color: textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (state.dateRangeStart != null && state.dateRangeEnd != null)
                                ? '${DateFormat('dd MMM yyyy').format(state.dateRangeStart!)} - ${DateFormat('dd MMM yyyy').format(state.dateRangeEnd!)}'
                                : 'All Dates (No filter)',
                            style: TextStyle(fontSize: 11.5, color: textPrimary, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (state.dateRangeStart != null)
                          GestureDetector(
                            onTap: () => notifier.clearDateRange(),
                            child: Icon(Icons.close, size: 14, color: textMuted),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Apply Filter Button
                ElevatedButton.icon(
                  onPressed: () {
                    notifier.setBuildingFilter(_selectedBuilding);
                    notifier.setTypeFilter(_selectedType == 'All Types' ? 'All' : _selectedType);
                    notifier.setPriorityFilter(_selectedPriority == 'All Priorities' ? 'All' : _selectedPriority);
                    notifier.setStatusFilter(_selectedStatus == 'All Status' ? 'All' : _selectedStatus);
                  },
                  icon: const Icon(Icons.filter_alt, size: 15, color: Colors.white),
                  label: const Text('Apply Filter', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required String title,
    String? badge,
    Color? badgeColor,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final activeBg = isDark ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFFEFF6FF);
    final activeColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final inactiveColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? activeColor : inactiveColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (badgeColor ?? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor != null ? Colors.white : (isDark ? Colors.white : const Color(0xFF475569)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<T>.fromMenuItems(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        ),
      ),
    );
  }
}
