import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/staff_salary_provider.dart';
import 'widgets/salary/staff_salary_header_bar.dart';
import 'widgets/salary/staff_salary_kpi_cards.dart';
import 'widgets/salary/staff_salary_filter_bar.dart';
import 'widgets/salary/staff_salary_table.dart';
import 'widgets/salary/staff_salary_drawer.dart';
import 'widgets/salary/staff_salary_right_summary.dart';

class StaffSalaryManagementScreen extends ConsumerWidget {
  const StaffSalaryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(staffSalaryProvider);
    final notifier = ref.read(staffSalaryProvider.notifier);
    final isDrawerOpen = state.isDrawerOpen && state.selectedStaffDetail != null;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isDesktop = screenWidth >= 1180;
          final isTablet = screenWidth >= 700 && screenWidth < 1180;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Bar with Title, Subtitle, and Month Dropdown
              const StaffSalaryHeaderBar(),

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
                        const StaffSalaryKPICards(),
                        const SizedBox(height: 16),

                        // Sub-Tabs & Filter Bar
                        const StaffSalaryFilterBar(),
                        const SizedBox(height: 16),

                        // Main Data Table + Right Column (Summary Donut or 360 Drawer)
                        if (state.subTab >= 4)
                          const SizedBox(
                            height: 800,
                            child: StaffSalaryTable(),
                          )
                        else if (isDesktop)
                          SizedBox(
                            height: 800,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(
                                  child: StaffSalaryTable(),
                                ),
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 360,
                                  child: isDrawerOpen
                                      ? const StaffSalaryDrawer()
                                      : const StaffSalaryRightSummary(),
                                ),
                              ],
                            ),
                          )
                        else if (isTablet)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 560, child: StaffSalaryTable()),
                              const SizedBox(height: 16),
                              if (isDrawerOpen)
                                const SizedBox(height: 650, child: StaffSalaryDrawer())
                              else
                                const StaffSalaryRightSummary(),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 480, child: StaffSalaryTable()),
                              const SizedBox(height: 16),
                              if (isDrawerOpen)
                                const SizedBox(height: 650, child: StaffSalaryDrawer())
                              else
                                const StaffSalaryRightSummary(),
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
