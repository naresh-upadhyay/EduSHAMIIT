import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import '../providers/circulation_provider.dart';
import 'circulation_kpi_cards.dart';
import 'circulation_quick_issue_return_card.dart';
import 'circulation_filter_search_card.dart';
import 'circulation_side_panels.dart';
import 'circulation_table.dart';
import 'circulation_details_drawer.dart';

class CirculationTabView extends ConsumerWidget {
  const CirculationTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(circulationProvider);
    final notifier = ref.read(circulationProvider.notifier);
    final isDesktop = Responsive.isDesktop(context);


    // Toast/SnackBar feedback
    ref.listen<CirculationState>(circulationProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
        notifier.clearNotifications();
      } else if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        notifier.clearNotifications();
      }
    });

    return Stack(
      children: [
        // Main Scrollable Page
        RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              notifier.fetchStats(),
              notifier.fetchActivities(),
              notifier.fetchOverdueSummary(),
              notifier.fetchTransactions(resetPage: true),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 6 KPI Cards Row
                const CirculationKpiCards(),


                // 3. Middle Section: Quick Cards + Filters + Side Panels
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 28 : 16,
                    vertical: 8,
                  ),
                  child: isDesktop
                      ? const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left & Center Column: Quick Issue/Return & Search/Filters
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  CirculationQuickIssueReturnCard(),
                                  SizedBox(height: 14),
                                  CirculationFilterSearchCard(),
                                ],
                              ),
                            ),
                            SizedBox(width: 14),

                            // Middle Right Column: Raise Request & Scan Cards
                            Expanded(
                              flex: 3,
                              child: CirculationQuickActionCards(),
                            ),
                            SizedBox(width: 14),

                            // Far Right Column: Today's Activity + Overdue + Quick Actions
                            Expanded(
                              flex: 3,
                              child: CirculationRightPanel(),
                            ),
                          ],
                        )
                      : const Column(
                          children: [
                            CirculationQuickIssueReturnCard(),
                            SizedBox(height: 12),
                            CirculationFilterSearchCard(),
                            SizedBox(height: 12),
                            CirculationQuickActionCards(),
                            SizedBox(height: 12),
                            CirculationRightPanel(),
                          ],
                        ),
                ),

                // 4. Main Circulation Transactions Table
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 28 : 16,
                    14,
                    isDesktop ? 28 : 16,
                    36,
                  ),
                  child: const CirculationTable(),
                ),
              ],
            ),
          ),
        ),

        // Slide-over Details Drawer
        if (state.isDrawerOpen)
          Positioned.fill(
            child: Stack(
              children: [
                // Backdrop
                GestureDetector(
                  onTap: () => notifier.closeDrawer(),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
                // Drawer from right
                const Align(
                  alignment: Alignment.centerRight,
                  child: CirculationDetailsDrawer(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
