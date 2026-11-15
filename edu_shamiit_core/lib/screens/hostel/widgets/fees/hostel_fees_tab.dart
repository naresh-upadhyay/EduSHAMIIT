import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import 'hostel_fee_kpi_cards.dart';
import 'hostel_fee_filter_bar.dart';
import 'hostel_student_fee_table.dart';
import 'hostel_fee_right_summary.dart';
import 'hostel_student_fee_drawer.dart';

class HostelFeesTab extends ConsumerWidget {
  const HostelFeesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDrawerOpen = state.isFeeDrawerOpen && state.selectedFeeStudentDetail != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isDesktop = screenWidth >= 1180;
        final isTablet = screenWidth >= 700 && screenWidth < 1180;

        return RefreshIndicator(
          onRefresh: () => notifier.loadFeesData(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top 5 KPI Cards matching Screenshot
                const HostelFeeKPICards(),
                const SizedBox(height: 16),

                // 2. Sub-Tabs & Filter Bar
                const HostelFeeFilterBar(),
                const SizedBox(height: 16),

                // 3. Main Data Table + Right Column (Summary Donut / Invoices or 360 Drawer)
                if (state.feesSubTab >= 4)
                  const SizedBox(
                    height: 800,
                    child: HostelStudentFeeTable(),
                  )
                else if (isDesktop)
                  SizedBox(
                    height: 800,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left / Center: Student Fee Roster Table
                        const Expanded(
                          child: HostelStudentFeeTable(),
                        ),
                        const SizedBox(width: 14),

                        // Right Column (width 340)
                        SizedBox(
                          width: 340,
                          child: isDrawerOpen
                              ? const HostelStudentFeeDrawer()
                              : const HostelFeeRightSummary(),
                        ),
                      ],
                    ),
                  )
                else if (isTablet)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 560, child: HostelStudentFeeTable()),
                      const SizedBox(height: 16),
                      if (isDrawerOpen)
                        const SizedBox(height: 650, child: HostelStudentFeeDrawer())
                      else
                        const HostelFeeRightSummary(),
                    ],
                  )
                else
                  // Mobile
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 480, child: HostelStudentFeeTable()),
                      const SizedBox(height: 16),
                      if (isDrawerOpen)
                        const SizedBox(height: 650, child: HostelStudentFeeDrawer())
                      else
                        const HostelFeeRightSummary(),
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
