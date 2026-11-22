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
          final screenHeight = constraints.maxHeight;
          final isDesktop = screenWidth >= 1180;
          final isTablet = screenWidth >= 700 && screenWidth < 1180;
          final canUseExpanded = isDesktop && screenHeight >= 680;

          // 1. Enterprise Desktop Layout (Pinned Bars + Stretched Work Area - Zero Scroll Contention)
          if (canUseExpanded) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const StudentFeeHeaderBar(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: StudentFeeKPICards(),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: StudentFeeFilterBar(),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Expanded(
                          child: StudentFeeTable(),
                        ),
                        if (state.subTab < 6) ...[
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 360,
                            child: isDrawerOpen
                                ? const StudentFeeDrawer()
                                : const StudentFeeRightSummary(),
                          ),
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
              const StudentFeeHeaderBar(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => notifier.loadAllData(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const StudentFeeKPICards(),
                        const SizedBox(height: 14),
                        const StudentFeeFilterBar(),
                        const SizedBox(height: 14),
                        if (isDesktop)
                          SizedBox(
                            height: 720,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Expanded(child: StudentFeeTable()),
                                if (state.subTab < 6) ...[
                                  const SizedBox(width: 14),
                                  SizedBox(
                                    width: 360,
                                    child: isDrawerOpen ? const StudentFeeDrawer() : const StudentFeeRightSummary(),
                                  ),
                                ],
                              ],
                            ),
                          )
                        else if (isTablet)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 580, child: StudentFeeTable()),
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
                              const SizedBox(height: 520, child: StudentFeeTable()),
                              const SizedBox(height: 14),
                              if (isDrawerOpen)
                                const SizedBox(height: 620, child: StudentFeeDrawer())
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
