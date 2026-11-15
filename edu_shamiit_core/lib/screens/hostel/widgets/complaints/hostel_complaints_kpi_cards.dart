import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import '../common/hostel_unified_kpi_card.dart';

class HostelComplaintsKPICards extends ConsumerWidget {
  const HostelComplaintsKPICards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final kpis = state.complaintKpis;
    final notifier = ref.read(hostelProvider.notifier);

    return HostelKpiGrid(
      desktopColumns: 6,
      tabletColumns: 3,
      mobileColumns: 2,
      spacing: 12.0,
      children: [
        HostelUnifiedKpiCard(
          title: 'Total Complaints',
          value: '${kpis.totalComplaints}',
          subtitle: kpis.totalSubtitle,
          badge: kpis.totalTrend,
          badgeColor: const Color(0xFF16A34A),
          badgeBg: const Color(0xFFDCFCE7),
          icon: Icons.error_outline_rounded,
          iconColor: const Color(0xFFEF4444),
          isSelected: state.complaintsSubtab == 'All Complaints',
          tooltip: 'All registered complaints',
          onTap: () {
            notifier.setComplaintsSubtab('All Complaints');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Resolved',
          value: '${kpis.resolved}',
          subtitle: kpis.resolutionRate,
          badge: kpis.resolutionRate,
          badgeColor: const Color(0xFF16A34A),
          icon: Icons.check_circle_outline_rounded,
          iconColor: const Color(0xFF16A34A),
          isSelected: state.complaintsSubtab == 'Resolved',
          tooltip: 'Filter resolved complaints',
          onTap: () {
            notifier.setComplaintsSubtab('Resolved');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Pending',
          value: '${kpis.pending}',
          subtitle: kpis.pendingPercentage,
          badge: kpis.pendingPercentage,
          badgeColor: const Color(0xFFEA580C),
          icon: Icons.access_time_rounded,
          iconColor: const Color(0xFFEA580C),
          isSelected: state.complaintsSubtab == 'Pending',
          tooltip: 'Filter pending complaints',
          onTap: () {
            notifier.setComplaintsSubtab('Pending');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Overdue',
          value: '${kpis.overdue}',
          subtitle: kpis.overduePercentage,
          badge: kpis.overduePercentage,
          badgeColor: const Color(0xFFDC2626),
          icon: Icons.report_problem_rounded,
          iconColor: const Color(0xFFDC2626),
          isSelected: state.complaintsSubtab == 'Overdue',
          tooltip: 'Filter overdue complaints',
          onTap: () {
            notifier.setComplaintsSubtab('Overdue');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'High Priority',
          value: '${kpis.highPriority}',
          subtitle: kpis.highPrioritySubtitle,
          badge: kpis.highPriority > 0 ? '${kpis.highPriority}' : null,
          badgeColor: const Color(0xFF9333EA),
          icon: Icons.headset_mic_rounded,
          iconColor: const Color(0xFF9333EA),
          isSelected: state.complaintsSubtab == 'High Priority',
          tooltip: 'Filter high priority complaints',
          onTap: () {
            notifier.setComplaintsSubtab('High Priority');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Maintenance Related',
          value: '${kpis.maintenanceRelated}',
          subtitle: kpis.maintenancePercentage,
          badge: kpis.maintenancePercentage,
          badgeColor: const Color(0xFF0284C7),
          icon: Icons.build_rounded,
          iconColor: const Color(0xFF0284C7),
          isSelected: state.complaintsSubtab == 'Maintenance',
          tooltip: 'Filter maintenance issues',
          onTap: () {
            notifier.setComplaintsSubtab('Maintenance');
          },
        ),
      ],
    );
  }
}
