import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import 'hostel_students_kpi_cards.dart';
import 'hostel_students_filter_bar.dart';
import 'hostel_students_table.dart';
import 'hostel_student_details_drawer.dart';

class HostelStudentsTab extends ConsumerWidget {
  const HostelStudentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isDesktop = screenWidth >= 1050;
        final isTablet = screenWidth >= 700 && screenWidth < 1050;

        return RefreshIndicator(
          onRefresh: () => notifier.loadStudentsData(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top 6 KPI Cards matching Screenshot
                const HostelStudentsKPICards(),
                const SizedBox(height: 16),

                // 2. Search & Filter Bar with Add Student button
                const HostelStudentsFilterBar(),
                const SizedBox(height: 16),

                // 3. Data Grid + Right Details Drawer
                if (isDesktop)
                  // Desktop Side-by-Side: Table (Expanded) + Details Drawer (360)
                  const SizedBox(
                    height: 780,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left / Center Data Grid
                        Expanded(
                          child: HostelStudentsTable(),
                        ),
                        SizedBox(width: 14),

                        // Right 360 Details Drawer
                        SizedBox(
                          width: 360,
                          child: HostelStudentDetailsDrawer(),
                        ),
                      ],
                    ),
                  )
                else if (isTablet)
                  // Tablet Layout
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 600, child: HostelStudentsTable()),
                      if (state.selectedStudentDetail != null) ...[
                        const SizedBox(height: 16),
                        const SizedBox(height: 700, child: HostelStudentDetailsDrawer()),
                      ],
                    ],
                  )
                else
                  // Mobile Layout: Stacked
                  Column(
                    children: [
                      const SizedBox(height: 520, child: HostelStudentsTable()),
                      if (state.selectedStudentDetail != null) ...[
                        const SizedBox(height: 16),
                        const SizedBox(height: 680, child: HostelStudentDetailsDrawer()),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
