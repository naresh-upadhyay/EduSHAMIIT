import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/staff_salary_provider.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/common/hostel_unified_kpi_card.dart';

class StaffSalaryKPICards extends ConsumerWidget {
  const StaffSalaryKPICards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(staffSalaryProvider);
    final notifier = ref.read(staffSalaryProvider.notifier);
    final kpis = state.kpis;

    final isAllSelected = state.selectedStatus == 'All Status' && state.subTab == 0;
    final isPaidSelected = state.selectedStatus == 'Paid' || state.subTab == 1;
    final isPendingSelected = state.selectedStatus == 'Pending' || state.subTab == 2;
    final isOnHoldSelected = state.selectedStatus == 'On Hold' || state.subTab == 3;

    return HostelKpiGrid(
      desktopColumns: 4,
      tabletColumns: 2,
      mobileColumns: 2,
      spacing: 12.0,
      children: [
        HostelUnifiedKpiCard(
          title: 'Total Monthly Budget',
          value: kpis.totalBudgetFormatted,
          subtitle: 'Active Payroll Cycle',
          icon: Icons.account_balance_rounded,
          iconColor: const Color(0xFF2563EB),
          isSelected: isAllSelected,
          tooltip: 'Total scheduled payroll expenditure',
          onTap: () {
            notifier.setStatusFilter('All Status');
            notifier.setSubTab(0);
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Total Disbursed',
          value: kpis.totalDisbursedFormatted,
          subtitle: kpis.disbursalRateFormatted,
          badge: kpis.disbursalRateFormatted,
          badgeColor: const Color(0xFF16A34A),
          badgeBg: const Color(0xFFDCFCE7),
          icon: Icons.check_circle_outline_rounded,
          iconColor: const Color(0xFF16A34A),
          isSelected: isPaidSelected,
          tooltip: 'Filter staff with salary disbursed',
          onTap: () {
            notifier.setStatusFilter('Paid');
            notifier.setSubTab(1);
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Pending Disbursal',
          value: kpis.pendingDisbursalFormatted,
          subtitle: '${kpis.pendingStaffCount} Staff Members',
          badge: '${kpis.pendingStaffCount} Pending',
          badgeColor: const Color(0xFFD97706),
          badgeBg: const Color(0xFFFFFBEB),
          icon: Icons.pending_actions_rounded,
          iconColor: const Color(0xFFD97706),
          isSelected: isPendingSelected,
          tooltip: 'Filter staff with pending salary payouts',
          onTap: () {
            notifier.setStatusFilter('Pending');
            notifier.setSubTab(2);
          },
        ),
        HostelUnifiedKpiCard(
          title: 'On-Hold / Review',
          value: kpis.onHoldAmountFormatted,
          subtitle: '${kpis.onHoldStaffCount} Staff Members',
          badge: '${kpis.onHoldStaffCount} On Hold',
          badgeColor: const Color(0xFFDC2626),
          badgeBg: const Color(0xFFFEE2E2),
          icon: Icons.pause_circle_outline_rounded,
          iconColor: const Color(0xFFDC2626),
          isSelected: isOnHoldSelected,
          tooltip: 'Filter staff with salary on hold',
          onTap: () {
            notifier.setStatusFilter('On Hold');
            notifier.setSubTab(3);
          },
        ),
      ],
    );
  }
}
