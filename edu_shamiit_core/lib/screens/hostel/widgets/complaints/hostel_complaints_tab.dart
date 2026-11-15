import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import 'hostel_complaints_kpi_cards.dart';
import 'hostel_complaints_filter_bar.dart';
import 'hostel_complaints_table.dart';
import 'hostel_complaint_detail_drawer.dart';

class HostelComplaintsTab extends ConsumerStatefulWidget {
  const HostelComplaintsTab({super.key});

  @override
  ConsumerState<HostelComplaintsTab> createState() => _HostelComplaintsTabState();
}

class _HostelComplaintsTabState extends ConsumerState<HostelComplaintsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hostelProvider.notifier).loadComplaintsData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isDrawerOpen = state.isComplaintDrawerOpen && state.selectedComplaintDetail != null;

        return Stack(
          children: [
            // Main Content Area with Pull-to-refresh
            RefreshIndicator(
              onRefresh: () => notifier.refreshComplaints(),
              child: const SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 18, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. KPI Metric Summary Cards (Matching Screenshot)
                    HostelComplaintsKPICards(),
                    SizedBox(height: 18),

                    // 2. Filter & Subtab Bar (All Complaints, My Complaints, etc. + Search & Dropdowns)
                    HostelComplaintsFilterBar(),
                    SizedBox(height: 18),

                    // 3. Main Data Table
                    HostelComplaintsTable(),
                  ],
                ),
              ),
            ),

            // Modal Slide-Over Detail Drawer for all screen sizes
            if (isDrawerOpen) ...[
              // Backdrop scrim for smaller screens (< 900px)
              if (screenWidth < 900)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => notifier.closeComplaintDrawer(),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: Material(
                  elevation: 16,
                  color: Colors.transparent,
                  child: Container(
                    width: screenWidth > 540 ? 460 : screenWidth * 0.95,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(-4, 0),
                        ),
                      ],
                    ),
                    child: const HostelComplaintDetailDrawer(),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
