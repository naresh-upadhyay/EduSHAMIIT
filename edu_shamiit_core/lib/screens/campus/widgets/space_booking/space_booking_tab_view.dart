import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/space_booking_models.dart';
import '../../providers/space_booking_provider.dart';
import 'space_booking_kpis_bar.dart';
import 'space_booking_left_panel.dart';
import 'space_booking_center_panel.dart';
import 'space_booking_right_panel.dart';
import 'dialogs/create_edit_booking_dialog.dart';
import 'dialogs/recurring_booking_dialog.dart';
import 'dialogs/booking_details_drawer.dart';

class SpaceBookingTabView extends ConsumerStatefulWidget {
  const SpaceBookingTabView({super.key});

  @override
  ConsumerState<SpaceBookingTabView> createState() => _SpaceBookingTabViewState();
}

class _SpaceBookingTabViewState extends ConsumerState<SpaceBookingTabView> {
  void _openCreateBookingModal({SpaceBookingRequestItem? item}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateEditBookingDialog(initialItem: item),
    );
  }

  void _openRecurringModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RecurringBookingDialog(),
    );
  }

  void _openDetailsDrawer(SpaceBookingRequestItem item) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'BookingDetails',
      pageBuilder: (ctx, _, __) {
        return Align(
          alignment: Alignment.centerRight,
          child: BookingDetailsDrawer(item: item),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spaceBookingProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: RefreshIndicator(
        onRefresh: () => ref.read(spaceBookingProvider.notifier).loadAll(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top KPI Cards Bar (Total Bookings, Confirmed, Pending, Rejected, Current Usage, Utilization)
              SpaceBookingKpisBar(kpis: state.kpis),
              const SizedBox(height: 16),

              // 2. Main 3-Column Work Area
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1100;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Navigation & Quick Filters
                        SpaceBookingLeftPanel(
                          isCompact: false,
                          onOpenBookModal: () => _openCreateBookingModal(),
                          onOpenRecurringModal: _openRecurringModal,
                        ),
                        const SizedBox(width: 16),

                        // Center Column: Availability Timeline Grid + Booking Requests Table
                        Expanded(
                          child: SpaceBookingCenterPanel(
                            onInspectRequest: (item) => _openDetailsDrawer(item),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Right Column: Book a Space Form + Today's Space Utilization + Quick Actions
                        SpaceBookingRightPanel(
                          isCompact: false,
                          onOpenRecurringModal: _openRecurringModal,
                          onOpenManageApprovals: () {
                            ref.read(spaceBookingProvider.notifier).setSelectedNav('Pending Requests');
                          },
                          onOpenUtilizationReport: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Space Utilization: 72.8% active across 150 campus spaces.")),
                            );
                          },
                        ),
                      ],
                    );
                  } else {
                    // Mobile / narrow responsive layout
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SpaceBookingLeftPanel(
                          isCompact: true,
                          onOpenBookModal: () => _openCreateBookingModal(),
                          onOpenRecurringModal: _openRecurringModal,
                        ),
                        const SizedBox(height: 16),
                        SpaceBookingCenterPanel(
                          onInspectRequest: (item) => _openDetailsDrawer(item),
                        ),
                        const SizedBox(height: 16),
                        SpaceBookingRightPanel(
                          isCompact: true,
                          onOpenRecurringModal: _openRecurringModal,
                          onOpenManageApprovals: () {
                            ref.read(spaceBookingProvider.notifier).setSelectedNav('Pending Requests');
                          },
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
