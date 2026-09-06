import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import '../providers/request_provider.dart';
import 'request_kpi_cards.dart';

import 'request_filter_bar.dart';
import 'request_table.dart';
import 'request_side_panels.dart';
import 'request_details_drawer.dart';

class RequestTabView extends ConsumerWidget {
  const RequestTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(requestProvider);
    final notifier = ref.read(requestProvider.notifier);
    final isDrawerOpen = state.selectedRequestDetail != null || state.isDetailLoading;

    // Listen for error messages
    ref.listen<RequestState>(requestProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(next.errorMessage!)),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    return Stack(
      children: [
        // Main Content Scrollable
        RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              notifier.fetchKpis(),
              notifier.fetchOptions(),
              notifier.loadRequests(resetPage: true),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 6 Top KPI Metric Cards
                const RequestKpiCards(),

                // 2. Search & Multi-criteria Filter Bar
                const RequestFilterBar(),

                // 3. Two-column Layout: Table (Left) + Side Panels (Right)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1080;

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: Main Enterprise Data Table
                            Expanded(
                              flex: 7,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: isDesktop ? 28 : 16,
                                  right: 16,
                                  bottom: 24,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF131B2E) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: RequestTable(
                                    onViewRequest: (id) {},
                                  ),
                                ),
                              ),
                            ),

                            // Right: Side Panels
                            Padding(
                              padding: EdgeInsets.only(
                                right: isDesktop ? 28 : 16,
                                bottom: 24,
                              ),
                              child: SizedBox(
                                width: 320,
                                child: RequestSidePanels(
                                  onViewRequest: (id) {},
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Stacked view for smaller desktop / tablet
                        return Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF131B2E) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: RequestTable(
                                  onViewRequest: (id) {},
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16),
                              child: RequestSidePanels(
                                onViewRequest: (id) {},
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),


        // Slide-over Request Details Drawer (Overlay)
        if (isDrawerOpen) ...[
          // Backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: () => notifier.closeRequestDetail(),
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),

          // Drawer on the right side
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: RequestDetailsDrawer(
              onClose: () => notifier.closeRequestDetail(),
            ),
          ),
        ],
      ],
    );
  }
}
