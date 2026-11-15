import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import '../common/hostel_unified_kpi_card.dart';

class HostelStudentsKPICards extends ConsumerWidget {
  const HostelStudentsKPICards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final kpis = state.studentsKPIs;

    return HostelKpiGrid(
      desktopColumns: 6,
      tabletColumns: 3,
      mobileColumns: 2,
      spacing: 12.0,
      children: [
        HostelUnifiedKpiCard(
          title: 'Total Hostel Students',
          value: '${kpis.totalStudents}',
          subtitle: 'in ${kpis.hostelsCount} hostels',
          icon: Icons.people_alt_rounded,
          iconColor: const Color(0xFF2563EB),
          isSelected: state.studentsStatusFilter == 'All Status' && state.studentsHostelFilter == 'All Hostels',
          tooltip: 'All enrolled hostel residents',
          onTap: () {
            notifier.setStudentsHostelFilter('All Hostels');
            notifier.setStudentsStatusFilter('All Status');
            notifier.setStudentsFeeStatusFilter('All Status');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Boys Students',
          value: '${kpis.boysCount}',
          subtitle: '${kpis.boysPct}% of residents',
          badge: '${kpis.boysPct}%',
          badgeColor: const Color(0xFF2563EB),
          badgeBg: const Color(0xFFEFF6FF),
          icon: Icons.male_rounded,
          iconColor: const Color(0xFF2563EB),
          tooltip: 'Total male hostellers',
        ),
        HostelUnifiedKpiCard(
          title: 'Girls Students',
          value: '${kpis.girlsCount}',
          subtitle: '${kpis.girlsPct}% of residents',
          badge: '${kpis.girlsPct}%',
          badgeColor: const Color(0xFFDB2777),
          badgeBg: const Color(0xFFFDF2F8),
          icon: Icons.female_rounded,
          iconColor: const Color(0xFFDB2777),
          tooltip: 'Total female hostellers',
        ),
        HostelUnifiedKpiCard(
          title: 'New Admissions',
          value: '${kpis.newAdmissionsMonth}',
          subtitle: 'This Month',
          badge: kpis.newAdmissionsMonth > 0 ? '${kpis.newAdmissionsMonth}' : null,
          badgeColor: const Color(0xFF16A34A),
          badgeBg: const Color(0xFFDCFCE7),
          icon: Icons.person_add_alt_1_rounded,
          iconColor: const Color(0xFF16A34A),
          tooltip: 'New resident admissions this month',
        ),
        HostelUnifiedKpiCard(
          title: 'Pending Dues',
          value: '${kpis.pendingDuesCount}',
          subtitle: 'Students with dues',
          badge: kpis.pendingDuesCount > 0 ? '${kpis.pendingDuesCount}' : null,
          badgeColor: const Color(0xFFDC2626),
          badgeBg: const Color(0xFFFEE2E2),
          icon: Icons.receipt_long_rounded,
          iconColor: const Color(0xFFDC2626),
          isSelected: state.studentsFeeStatusFilter == 'Pending' || state.studentsFeeStatusFilter == 'Overdue',
          tooltip: 'View students with fee balance',
          onTap: () {
            notifier.setStudentsFeeStatusFilter('Pending');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Leave / Outing',
          value: '${kpis.currentlyOutCount}',
          subtitle: 'Currently Out',
          badge: kpis.currentlyOutCount > 0 ? '${kpis.currentlyOutCount}' : null,
          badgeColor: const Color(0xFF7C3AED),
          badgeBg: const Color(0xFFEDE9FE),
          icon: Icons.exit_to_app_rounded,
          iconColor: const Color(0xFF7C3AED),
          tooltip: 'Switch to Leave & Outing tab',
          onTap: () {
            notifier.selectTab(5);
          },
        ),
      ],
    );
  }
}
