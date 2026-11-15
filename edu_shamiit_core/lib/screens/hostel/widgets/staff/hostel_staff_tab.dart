import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import 'hostel_staff_kpi_cards.dart';
import 'hostel_staff_filter_bar.dart';
import 'hostel_staff_table.dart';
import 'hostel_staff_details_drawer.dart';

class HostelStaffTab extends ConsumerWidget {
  const HostelStaffTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isDesktop = screenWidth >= 1180;
        final isTablet = screenWidth >= 700 && screenWidth < 1180;
        final isDrawerOpen = state.isStaffDrawerOpen && state.selectedStaffDetail != null;

        return RefreshIndicator(
          onRefresh: () => notifier.loadStaffData(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top 6 KPI Cards matching Screenshot
                const HostelStaffKPICards(),
                const SizedBox(height: 16),

                // 2. Search & Filter Bar with Add Staff button
                const HostelStaffFilterBar(),
                const SizedBox(height: 16),

                // 3. Data Grid + Right Details Drawer
                if (isDesktop)
                  // Desktop Side-by-Side: Table (Expanded) + Details Drawer (360)
                  SizedBox(
                    height: 780,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left / Center Data Grid
                        const Expanded(
                          child: HostelStaffTable(),
                        ),
                        if (isDrawerOpen) ...[
                          const SizedBox(width: 14),
                          // Right 360 Details Drawer matching screenshot
                          const SizedBox(
                            width: 360,
                            child: HostelStaffDetailsDrawer(),
                          ),
                        ],
                      ],
                    ),
                  )
                else if (isTablet)
                  // Tablet Layout
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 600, child: HostelStaffTable()),
                      if (isDrawerOpen) ...[
                        const SizedBox(height: 16),
                        const SizedBox(height: 700, child: HostelStaffDetailsDrawer()),
                      ],
                    ],
                  )
                else
                  // Mobile Layout: Stacked
                  Column(
                    children: [
                      const SizedBox(height: 520, child: HostelStaffTable()),
                      if (isDrawerOpen) ...[
                        const SizedBox(height: 16),
                        const SizedBox(height: 680, child: HostelStaffDetailsDrawer()),
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
