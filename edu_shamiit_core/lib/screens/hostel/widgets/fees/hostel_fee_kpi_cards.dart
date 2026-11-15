import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import '../common/hostel_unified_kpi_card.dart';

class HostelFeeKPICards extends ConsumerWidget {
  const HostelFeeKPICards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final kpis = state.feesKPIs;

    final isAllSelected = state.feesStatusFilter == 'All Status';
    final isPaidSelected = state.feesStatusFilter == 'Paid';
    final isPartialSelected = state.feesStatusFilter == 'Partial';
    final isOverdueSelected = state.feesStatusFilter == 'Overdue';

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
          tooltip: 'All hostel invoices billed',
          onTap: () {
            notifier.setFeesStatusFilter('All Status');
            notifier.setFeesSubTab(0);
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
          tooltip: 'Filter paid invoices',
          onTap: () {
            notifier.setFeesStatusFilter('Paid');
            notifier.setFeesSubTab(1);
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
          tooltip: 'Filter partial & pending dues',
          onTap: () {
            notifier.setFeesStatusFilter('Partial');
            notifier.setFeesSubTab(2);
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Overdue Amount',
          value: kpis.overdueAmountFormatted,
          subtitle: '${kpis.overdueStudentsCount} Students',
          badge: '${kpis.overdueStudentsCount} Overdue',
          badgeColor: const Color(0xFFDC2626),
          badgeBg: const Color(0xFFFEE2E2),
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFDC2626),
          isSelected: isOverdueSelected,
          tooltip: 'Filter overdue fee defaulters',
          onTap: () {
            notifier.setFeesStatusFilter('Overdue');
            notifier.setFeesSubTab(3);
          },
        ),
      ],
    );
  }
}
