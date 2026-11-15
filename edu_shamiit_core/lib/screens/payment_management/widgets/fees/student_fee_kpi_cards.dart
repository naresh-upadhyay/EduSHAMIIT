import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/student_fee_provider.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/common/hostel_unified_kpi_card.dart';

class StudentFeeKPICards extends ConsumerWidget {
  const StudentFeeKPICards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studentFeeProvider);
    final notifier = ref.read(studentFeeProvider.notifier);
    final kpis = state.kpis;

    final isAllSelected = state.selectedStatus == 'All Status' && state.subTab == 0;
    final isPaidSelected = state.selectedStatus == 'Paid' || state.subTab == 1;
    final isPartialSelected = state.selectedStatus == 'Partial' || state.subTab == 2;
    final isOverdueSelected = state.selectedStatus == 'Overdue' || state.subTab == 3;

    return HostelKpiGrid(
      desktopColumns: 4,
      tabletColumns: 2,
      mobileColumns: 2,
      spacing: 12.0,
      children: [
        HostelUnifiedKpiCard(
          title: 'Total Billed',
          value: kpis.totalBilledFormatted,
          subtitle: 'Current Academic Year',
          icon: Icons.receipt_long_rounded,
          iconColor: const Color(0xFF2563EB),
          isSelected: isAllSelected,
          tooltip: 'All academic tuition fees billed',
          onTap: () {
            notifier.setStatusFilter('All Status');
            notifier.setSubTab(0);
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Total Collected',
          value: kpis.totalCollectedFormatted,
          subtitle: kpis.collectionRateFormatted,
          badge: kpis.collectionRateFormatted,
          badgeColor: const Color(0xFF16A34A),
          badgeBg: const Color(0xFFDCFCE7),
          icon: Icons.account_balance_wallet_rounded,
          iconColor: const Color(0xFF16A34A),
          isSelected: isPaidSelected,
          tooltip: 'Filter fully paid students',
          onTap: () {
            notifier.setStatusFilter('Paid');
            notifier.setSubTab(1);
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Pending Dues',
          value: kpis.pendingDuesFormatted,
          subtitle: '${kpis.pendingStudentsCount} Students',
          badge: '${kpis.pendingStudentsCount} Students',
          badgeColor: const Color(0xFFD97706),
          badgeBg: const Color(0xFFFFFBEB),
          icon: Icons.pending_actions_rounded,
          iconColor: const Color(0xFFD97706),
          isSelected: isPartialSelected,
          tooltip: 'Filter students with partial or pending dues',
          onTap: () {
            notifier.setStatusFilter('Partial');
            notifier.setSubTab(2);
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Overdue Amount',
          value: kpis.overdueAmountFormatted,
          subtitle: '${kpis.overdueStudentsCount} Overdue',
          badge: '${kpis.overdueStudentsCount} Overdue',
          badgeColor: const Color(0xFFDC2626),
          badgeBg: const Color(0xFFFEE2E2),
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFDC2626),
          isSelected: isOverdueSelected,
          tooltip: 'Filter overdue fee defaulters',
          onTap: () {
            notifier.setStatusFilter('Overdue');
            notifier.setSubTab(3);
          },
        ),
      ],
    );
  }
}
