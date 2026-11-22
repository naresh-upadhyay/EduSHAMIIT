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
          final screenHeight = constraints.maxHeight;
          final isDesktop = screenWidth >= 1180;
          final isTablet = screenWidth >= 700 && screenWidth < 1180;
          final canUseExpanded = isDesktop && screenHeight >= 680;

          // 1. Enterprise Desktop Layout (Pinned Bars + Stretched Work Area - Zero Scroll Contention)
          if (canUseExpanded) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const StaffSalaryHeaderBar(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: StaffSalaryKPICards(),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: StaffSalaryFilterBar(),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Expanded(
                          child: StaffSalaryTable(),
                        ),
                        if (state.subTab < 4 && (isDrawerOpen || state.isRightSummaryVisible)) ...[
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 350,
                            child: isDrawerOpen
                                ? const StaffSalaryDrawer()
                                : const StaffSalaryRightSummary(),
                          ),
                        ] else if (state.subTab < 4) ...[
                          const SizedBox(width: 8),
                          _buildSummaryToggle(context, notifier),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // 2. Responsive Scrollable Layout for Tablets, Mobile & Compact Heights
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StaffSalaryHeaderBar(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => notifier.loadAllData(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const StaffSalaryKPICards(),
                        const SizedBox(height: 14),
                        const StaffSalaryFilterBar(),
                        const SizedBox(height: 14),
                        if (isDesktop)
                          SizedBox(
                            height: 720,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Expanded(child: StaffSalaryTable()),
                                if (state.subTab < 4 && (isDrawerOpen || state.isRightSummaryVisible)) ...[
                                  const SizedBox(width: 14),
                                  SizedBox(
                                    width: 340,
                                    child: isDrawerOpen ? const StaffSalaryDrawer() : const StaffSalaryRightSummary(),
                                  ),
                                ] else if (state.subTab < 4) ...[
                                  const SizedBox(width: 8),
                                  _buildSummaryToggle(context, notifier),
                                ],
                              ],
                            ),
                          )
                        else if (isTablet)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 580, child: StaffSalaryTable()),
                              const SizedBox(height: 16),
                              if (isDrawerOpen)
                                const SizedBox(height: 650, child: StaffSalaryDrawer())
                              else if (state.isRightSummaryVisible)
                                const StaffSalaryRightSummary(),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 520, child: StaffSalaryTable()),
                              const SizedBox(height: 14),
                              if (isDrawerOpen)
                                const SizedBox(height: 620, child: StaffSalaryDrawer())
                              else if (state.isRightSummaryVisible)
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

  Widget _buildSummaryToggle(BuildContext context, StaffSalaryNotifier notifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: IconButton(
        icon: const Icon(Icons.analytics_outlined, size: 20),
        tooltip: 'Show Summary Analytics Panel',
        onPressed: () => notifier.toggleRightSummary(),
      ),
    );
  }
}
