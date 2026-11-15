import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import '../common/hostel_unified_kpi_card.dart';

class HostelLeaveKPICards extends ConsumerWidget {
  const HostelLeaveKPICards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final kpis = state.leaveKpis;
    final notifier = ref.read(hostelProvider.notifier);

    final isAllSelected = state.leaveStatusFilter == 'All Status' ||
        state.leaveStatusFilter == 'ALL';
    final isApprovedSelected = state.leaveStatusFilter == 'APPROVED';
    final isPendingSelected = state.leaveStatusFilter == 'PENDING';
    final isRejectedSelected = state.leaveStatusFilter == 'REJECTED';
    final isCurrentlyOutSelected = state.leaveStatusFilter == 'CURRENTLY_OUT' ||
        state.leaveStatusFilter == 'EXITED';
    final isDueTodaySelected = state.leaveStatusFilter == 'DUE_TODAY';

    return HostelKpiGrid(
      desktopColumns: 6,
      tabletColumns: 3,
      mobileColumns: 2,
      spacing: 12.0,
      children: [
        HostelUnifiedKpiCard(
          title: 'Total Requests',
          value: '${kpis.totalRequests}',
          subtitle: 'This Month',
          badge: '↑ 12%',
          badgeColor: const Color(0xFF16A34A),
          badgeBg: const Color(0xFFDCFCE7),
          icon: Icons.flight_takeoff_rounded,
          iconColor: const Color(0xFF2563EB),
          isSelected: isAllSelected,
          tooltip: 'All leave and outing requests',
          onTap: () {
            notifier.setLeaveSubTab(0);
            notifier.setLeaveStatusFilter('All Status');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Approved',
          value: '${kpis.approved}',
          subtitle: kpis.approvalRate,
          badge: kpis.approvalRate,
          badgeColor: const Color(0xFF16A34A),
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF16A34A),
          isSelected: isApprovedSelected,
          tooltip: 'Filter approved requests',
          onTap: () {
            notifier.setLeaveSubTab(0);
            notifier.setLeaveStatusFilter('APPROVED');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Pending',
          value: '${kpis.pending}',
          subtitle: kpis.pendingSubtitle,
          badge: kpis.pending > 0 ? '${kpis.pending}' : null,
          badgeColor: const Color(0xFFD97706),
          icon: Icons.access_time_filled_rounded,
          iconColor: const Color(0xFFD97706),
          isSelected: isPendingSelected,
          tooltip: 'Filter pending requests',
          onTap: () {
            notifier.setLeaveSubTab(0);
            notifier.setLeaveStatusFilter('PENDING');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Rejected',
          value: '${kpis.rejected}',
          subtitle: kpis.rejectedRate,
          badge: kpis.rejected > 0 ? '${kpis.rejected}' : null,
          badgeColor: const Color(0xFFDC2626),
          icon: Icons.cancel_rounded,
          iconColor: const Color(0xFFDC2626),
          isSelected: isRejectedSelected,
          tooltip: 'Filter rejected requests',
          onTap: () {
            notifier.setLeaveSubTab(0);
            notifier.setLeaveStatusFilter('REJECTED');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Currently Out',
          value: '${kpis.currentlyOut}',
          subtitle: kpis.currentlyOutSubtitle,
          badge: kpis.currentlyOut > 0 ? '${kpis.currentlyOut}' : null,
          badgeColor: const Color(0xFF9333EA),
          icon: Icons.directions_walk_rounded,
          iconColor: const Color(0xFF9333EA),
          isSelected: isCurrentlyOutSelected,
          tooltip: 'Filter hostellers currently out of campus',
          onTap: () {
            notifier.setLeaveSubTab(0);
            notifier.setLeaveStatusFilter('EXITED');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Due to Return Today',
          value: '${kpis.dueToday}',
          subtitle: kpis.dueTodaySubtitle,
          badge: kpis.dueToday > 0 ? '${kpis.dueToday}' : null,
          badgeColor: const Color(0xFF0284C7),
          icon: Icons.login_rounded,
          iconColor: const Color(0xFF0284C7),
          isSelected: isDueTodaySelected,
          tooltip: 'Filter students due to return today',
          onTap: () {
            notifier.setLeaveSubTab(0);
            notifier.setLeaveStatusFilter('DUE_TODAY');
          },
        ),
      ],
    );
  }
}
