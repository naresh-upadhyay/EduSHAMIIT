import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/student_fee_provider.dart';
import 'widgets/fees/student_fee_header_bar.dart';
import 'widgets/fees/student_fee_kpi_cards.dart';
import 'widgets/fees/student_fee_filter_bar.dart';
import 'widgets/fees/student_fee_table.dart';
import 'widgets/fees/student_fee_drawer.dart';
import 'widgets/fees/student_fee_right_summary.dart';

class StudentFeeManagementScreen extends ConsumerWidget {
  const StudentFeeManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studentFeeProvider);
    final notifier = ref.read(studentFeeProvider.notifier);
    final isDrawerOpen = state.isDrawerOpen && state.selectedStudentDetail != null;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isDesktop = screenWidth >= 1180;
          final isTablet = screenWidth >= 700 && screenWidth < 1180;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Bar with Title, Subtitle, and Academic Year
              const StudentFeeHeaderBar(),

              // 2. Body
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => notifier.loadAllData(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top 4 KPI Cards
                        const StudentFeeKPICards(),
                        const SizedBox(height: 16),

                        // Sub-Tabs & Filter Bar
                        const StudentFeeFilterBar(),
                        const SizedBox(height: 16),

                        // Main Data Table + Right Column (Summary Donut or 360 Drawer)
                        if (state.subTab >= 4)
                          const SizedBox(
                            height: 800,
                            child: StudentFeeTable(),
                          )
                        else if (isDesktop)
                          SizedBox(
                            height: 800,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(
                                  child: StudentFeeTable(),
                                ),
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 360,
                                  child: isDrawerOpen
                                      ? const StudentFeeDrawer()
                                      : const StudentFeeRightSummary(),
                                ),
                              ],
                            ),
                          )
                        else if (isTablet)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 560, child: StudentFeeTable()),
                              const SizedBox(height: 16),
                              if (isDrawerOpen)
                                const SizedBox(height: 650, child: StudentFeeDrawer())
                              else
                                const StudentFeeRightSummary(),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 480, child: StudentFeeTable()),
                              const SizedBox(height: 16),
                              if (isDrawerOpen)
                                const SizedBox(height: 650, child: StudentFeeDrawer())
                              else
                                const StudentFeeRightSummary(),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
