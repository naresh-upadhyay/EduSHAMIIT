import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import '../common/hostel_unified_kpi_card.dart';

class HostelStaffKPICards extends ConsumerWidget {
  const HostelStaffKPICards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final kpis = state.staffKPIs;

    final isAllSelected = state.staffRoleFilter == 'All Roles' &&
        state.staffStatusFilter == 'All Status';
    final isWardenSelected = state.staffRoleFilter == 'Warden';
    final isCaretakerSelected = state.staffRoleFilter == 'Caretaker';
    final isSecuritySelected = state.staffRoleFilter == 'Security';
    final isOnLeaveSelected = state.staffStatusFilter == 'On Leave';
    final isPendingSelected = state.staffStatusFilter == 'Pending';

    return HostelKpiGrid(
      desktopColumns: 6,
      tabletColumns: 3,
      mobileColumns: 2,
      spacing: 12.0,
      children: [
        HostelUnifiedKpiCard(
          title: 'Total Staff',
          value: '${kpis.totalStaff}',
          subtitle: 'All hostel staff',
          icon: Icons.people_alt_rounded,
          iconColor: const Color(0xFF2563EB),
          isSelected: isAllSelected,
          tooltip: 'View all hostel staff members',
          onTap: () {
            notifier.setStaffRoleFilter('All Roles');
            notifier.setStaffStatusFilter('All Status');
            notifier.setStaffHostelFilter('All Hostels');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Wardens',
          value: '${kpis.wardensCount}',
          subtitle: '${kpis.wardensBoys} Boys | ${kpis.wardensGirls} Girls',
          badge: kpis.wardensCount > 0 ? '${kpis.wardensCount}' : null,
          badgeColor: const Color(0xFF2563EB),
          icon: Icons.shield_outlined,
          iconColor: const Color(0xFF2563EB),
          isSelected: isWardenSelected,
          tooltip: 'Filter by Wardens',
          onTap: () => notifier.setStaffRoleFilter('Warden'),
        ),
        HostelUnifiedKpiCard(
          title: 'Care Takers',
          value: '${kpis.caretakersCount}',
          subtitle: 'Room supervisors',
          badge: kpis.caretakersCount > 0 ? '${kpis.caretakersCount}' : null,
          badgeColor: const Color(0xFFDB2777),
          icon: Icons.badge_outlined,
          iconColor: const Color(0xFFDB2777),
          isSelected: isCaretakerSelected,
          tooltip: 'Filter by Care Takers',
          onTap: () => notifier.setStaffRoleFilter('Caretaker'),
        ),
        HostelUnifiedKpiCard(
          title: 'Support Staff',
          value: '${kpis.supportCount}',
          subtitle: 'Cleaners, Security, Others',
          badge: kpis.supportCount > 0 ? '${kpis.supportCount}' : null,
          badgeColor: const Color(0xFF16A34A),
          icon: Icons.build_rounded,
          iconColor: const Color(0xFF16A34A),
          isSelected: isSecuritySelected,
          tooltip: 'Filter by Support Staff & Security',
          onTap: () => notifier.setStaffRoleFilter('Security'),
        ),
        HostelUnifiedKpiCard(
          title: 'On Leave',
          value: '${kpis.onLeaveCount}',
          subtitle: 'Currently on leave',
          badge: kpis.onLeaveCount > 0 ? '${kpis.onLeaveCount}' : null,
          badgeColor: const Color(0xFFDC2626),
          icon: Icons.calendar_month_outlined,
          iconColor: const Color(0xFFDC2626),
          isSelected: isOnLeaveSelected,
          tooltip: 'Filter staff currently on leave',
          onTap: () => notifier.setStaffStatusFilter('On Leave'),
        ),
        HostelUnifiedKpiCard(
          title: 'Pending Assignments',
          value: '${kpis.pendingAssignmentsCount}',
          subtitle: 'Require attention',
          badge: kpis.pendingAssignmentsCount > 0 ? '${kpis.pendingAssignmentsCount}' : null,
          badgeColor: const Color(0xFFD97706),
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFD97706),
          isSelected: isPendingSelected,
          tooltip: 'Filter pending staff assignments',
          onTap: () => notifier.setStaffStatusFilter('Pending'),
        ),
      ],
    );
  }
}
