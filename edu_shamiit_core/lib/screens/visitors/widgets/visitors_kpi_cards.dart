import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/visitors_provider.dart';
import '../../hostel/widgets/common/hostel_unified_kpi_card.dart';

class VisitorsKPICards extends ConsumerWidget {
  const VisitorsKPICards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(visitorsProvider);
    final notifier = ref.read(visitorsProvider.notifier);
    final kpis = state.kpis;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 20,
            vertical: isMobile ? 8 : 12,
          ),
          child: HostelKpiGrid(
            desktopColumns: 6,
            tabletColumns: 3,
            mobileColumns: 2,
            spacing: 12.0,
            children: [
              HostelUnifiedKpiCard(
                title: 'Total Visitors',
                value: kpis.totalVisitors.toString(),
                subtitle: kpis.totalSubtitle,
                badge: kpis.totalTrend,
                badgeColor: const Color(0xFF7C3AED),
                icon: Icons.groups_rounded,
                iconColor: const Color(0xFF7C3AED),
                isSelected: state.activeTab == 0 && state.selectedStatus == 'All Status' && state.selectedDateRange == 'All Time',
                tooltip: 'All registered visitor logs',
                onTap: () => notifier.applyKpiFilter('All Status'),
              ),
              HostelUnifiedKpiCard(
                title: 'Currently Inside',
                value: kpis.currentlyInside.toString(),
                subtitle: kpis.currentlyInsideSubtitle,
                badge: null,
                badgeColor: const Color(0xFF16A34A),
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF16A34A),
                isSelected: state.selectedStatus == 'Inside',
                tooltip: 'Visitors currently on campus',
                onTap: () => notifier.applyKpiFilter('Inside'),
              ),
              HostelUnifiedKpiCard(
                title: 'Checked In Today',
                value: kpis.checkedInToday.toString(),
                subtitle: kpis.checkedInTodaySubtitle,
                badge: null,
                badgeColor: const Color(0xFF2563EB),
                icon: Icons.north_east_rounded,
                iconColor: const Color(0xFF2563EB),
                isSelected: state.selectedDateRange == 'Today' && state.selectedStatus == 'Checked In',
                tooltip: 'Visitors checked in today',
                onTap: () => notifier.applyKpiFilter('Checked In Today'),
              ),
              HostelUnifiedKpiCard(
                title: 'Checked Out Today',
                value: kpis.checkedOutToday.toString(),
                subtitle: kpis.checkedOutTodaySubtitle,
                badge: null,
                badgeColor: const Color(0xFFEA580C),
                icon: Icons.south_east_rounded,
                iconColor: const Color(0xFFEA580C),
                isSelected: state.selectedStatus == 'Checked Out',
                tooltip: 'Visitors checked out today',
                onTap: () => notifier.applyKpiFilter('Checked Out Today'),
              ),
              HostelUnifiedKpiCard(
                title: 'Overstay',
                value: kpis.overstay.toString(),
                subtitle: kpis.overstaySubtitle,
                badge: null,
                badgeColor: const Color(0xFFDC2626),
                icon: Icons.error_outline_rounded,
                iconColor: const Color(0xFFDC2626),
                isSelected: state.selectedStatus == 'Overstay',
                tooltip: 'Visitors exceeding allowed duration',
                onTap: () => notifier.applyKpiFilter('Overstay'),
              ),
              HostelUnifiedKpiCard(
                title: 'Scheduled Today',
                value: kpis.scheduledToday.toString(),
                subtitle: kpis.scheduledTodaySubtitle,
                badge: null,
                badgeColor: const Color(0xFF9333EA),
                icon: Icons.calendar_month_rounded,
                iconColor: const Color(0xFF9333EA),
                isSelected: state.activeTab == 1,
                tooltip: 'Scheduled visitors for today',
                onTap: () => notifier.setActiveTab(1),
              ),
            ],
          ),
        );
      },
    );
  }
}
