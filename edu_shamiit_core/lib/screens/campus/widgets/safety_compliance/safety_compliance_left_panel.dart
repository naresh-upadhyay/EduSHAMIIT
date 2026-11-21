import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/safety_compliance_provider.dart';

class SafetyComplianceLeftPanel extends ConsumerWidget {
  final VoidCallback onOpenReportIncident;
  final VoidCallback onOpenLogInspection;
  final VoidCallback? onOpenScheduleDrill;

  const SafetyComplianceLeftPanel({
    super.key,
    required this.onOpenReportIncident,
    required this.onOpenLogInspection,
    this.onOpenScheduleDrill,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(safetyComplianceProvider);
    final notifier = ref.read(safetyComplianceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Primary Action Button: "+ Report Safety Incident"
          ElevatedButton.icon(
            onPressed: onOpenReportIncident,
            icon: const Icon(Icons.warning_amber_rounded,
                size: 18, color: Colors.white),
            label: const Text(
              'Report Safety Incident',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626), // Urgent Red
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),

          // 2. Secondary Action Button: "+ Log Inspection"
          OutlinedButton.icon(
            onPressed: onOpenLogInspection,
            icon: const Icon(Icons.add_task_rounded,
                size: 17, color: Color(0xFF2563EB)),
            label: const Text(
              'Log Safety Inspection',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2563EB)),
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 14),

          // 3. Navigation Views Card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildNavItem(
                  title: 'All Safety Records',
                  icon: Icons.dashboard_outlined,
                  isSelected: state.activeView == 'all',
                  onTap: () => notifier.setActiveView('all'),
                  isDark: isDark,
                ),
                _buildNavItem(
                  title: 'Action Needed Inspections',
                  badge: '${state.kpis.actionNeededInspections}',
                  badgeColor: const Color(0xFFF59E0B),
                  icon: Icons.fact_check_outlined,
                  isSelected: state.activeView == 'overdue_inspections',
                  onTap: () => notifier.setActiveView('overdue_inspections'),
                  isDark: isDark,
                ),
                _buildNavItem(
                  title: 'Active Incidents',
                  badge: '${state.kpis.openIncidents}',
                  badgeColor: const Color(0xFFEF4444),
                  icon: Icons.report_problem_outlined,
                  isSelected: state.activeView == 'critical_incidents',
                  onTap: () => notifier.setActiveView('critical_incidents'),
                  isDark: isDark,
                ),
                _buildNavItem(
                  title: 'Expiring Certificates',
                  badge: '${state.kpis.expiringCertificates}',
                  badgeColor: const Color(0xFFF59E0B),
                  icon: Icons.pending_actions_outlined,
                  isSelected: state.activeView == 'expiring_certs',
                  onTap: () => notifier.setActiveView('expiring_certs'),
                  isDark: isDark,
                ),
                _buildNavItem(
                  title: 'Conducted Drills',
                  badge: '${state.kpis.drillsConducted}',
                  badgeColor: const Color(0xFF06B6D4),
                  icon: Icons.campaign_outlined,
                  isSelected: state.activeView == 'conducted_drills',
                  onTap: () => notifier.setActiveView('conducted_drills'),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Quick Category Filter Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.filter_list_rounded,
                        size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Compliance Domain',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildFilterChip(
                  label: 'All Domains',
                  isSelected: state.selectedCategory == 'All',
                  onTap: () => notifier.setCategory('All'),
                  isDark: isDark,
                ),
                _buildFilterChip(
                  label: 'Fire Safety & NOC',
                  isSelected: state.selectedCategory == 'Fire Safety',
                  onTap: () => notifier.setCategory('Fire Safety'),
                  isDark: isDark,
                ),
                _buildFilterChip(
                  label: 'Electrical Systems',
                  isSelected: state.selectedCategory == 'Electrical Safety',
                  onTap: () => notifier.setCategory('Electrical Safety'),
                  isDark: isDark,
                ),
                _buildFilterChip(
                  label: 'Lab & Chemical Safety',
                  isSelected: state.selectedCategory == 'Lab & Chemical Safety',
                  onTap: () => notifier.setCategory('Lab & Chemical Safety'),
                  isDark: isDark,
                ),
                _buildFilterChip(
                  label: 'Building Stability',
                  isSelected: state.selectedCategory == 'Building Stability',
                  onTap: () => notifier.setCategory('Building Stability'),
                  isDark: isDark,
                ),
                _buildFilterChip(
                  label: 'Sanitation & Water',
                  isSelected:
                      state.selectedCategory == 'Sanitation & Hygiene' ||
                          state.selectedCategory == 'Water Quality',
                  onTap: () => notifier.setCategory('Water Quality'),
                  isDark: isDark,
                ),
                _buildFilterChip(
                  label: 'Lift & Elevator Fitness',
                  isSelected:
                      state.selectedCategory == 'Elevator & Lift Fitness',
                  onTap: () => notifier.setCategory('Elevator & Lift Fitness'),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 5. Emergency SOS Hotlines Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF7F1D1D).withValues(alpha: 0.2)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.emergency_rounded,
                        size: 18, color: Color(0xFFEF4444)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Campus SOS Hotline',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildHotlineRow('Fire Warden', 'Ext. 101', isDark),
                const SizedBox(height: 6),
                _buildHotlineRow('Medical / Nurse', 'Ext. 102', isDark),
                const SizedBox(height: 6),
                _buildHotlineRow('Security Post', 'Ext. 103', isDark),
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
    Color badgeColor = const Color(0xFF2563EB),
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final activeBg = isDark
        ? const Color(0xFF2563EB).withValues(alpha: 0.2)
        : const Color(0xFFEFF6FF);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? const Color(0xFF2563EB) : textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF2563EB) : textPrimary,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                    : const Color(0xFFEFF6FF))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 14,
                color: isSelected ? const Color(0xFF2563EB) : textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? const Color(0xFF2563EB) : textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHotlineRow(String label, String number, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          number,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D),
          ),
        ),
      ],
    );
  }
}
