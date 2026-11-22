import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/space_booking_models.dart';
import '../../providers/space_booking_provider.dart';
import 'space_booking_kpis_bar.dart';
import 'space_booking_left_panel.dart';
import 'space_booking_center_panel.dart';
import 'dialogs/create_edit_booking_dialog.dart';
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

  void _openCreateBookingFromGrid({
    String? roomId,
    String? roomName,
    String? roomType,
    DateTime? date,
    String? startTime,
    String? endTime,
  }) {
    final state = ref.read(spaceBookingProvider);
    final targetDate = date ?? state.selectedDate;
    _openCreateBookingModal(
      item: SpaceBookingRequestItem(
        id: '',
        bookingRef: '',
        title: '',
        purpose: 'Class / Lecture Instruction',
        category: 'Academic',
        priority: 'Normal',
        status: 'Pending',
        isApproved: false,
        bookingDate: DateFormat('yyyy-MM-dd').format(targetDate),
        startTime: startTime ?? '08:00 AM',
        endTime: endTime ?? '09:00 AM',
        formattedSchedule: '${startTime ?? "08:00 AM"} - ${endTime ?? "09:00 AM"}',
        roomId: roomId ?? '',
        roomName: roomName ?? '',
        roomType: roomType ?? '',
        spaceDisplay: (roomName != null && roomName.isNotEmpty) ? '$roomName ($roomType)' : '',
        buildingId: '',
        buildingName: '',
        organizerName: '',
        organizerRole: 'Faculty',
        requestedByDisplay: '',
        attendeeCount: 30,
        isRecurring: false,
      ),
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
          child: BookingDetailsDrawer(
            item: item,
            onEdit: () {
              Navigator.pop(ctx);
              _openCreateBookingModal(item: item);
            },
            onDelete: () {
              Navigator.pop(ctx);
              _handleDeleteBooking(item);
            },
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  void _handleDeleteBooking(SpaceBookingRequestItem item) {
    final notifier = ref.read(spaceBookingProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (item.isRecurring) {
      showDialog(
        context: context,
        builder: (ctx) {
          bool deleteSeries = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Delete Recurring Booking?',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you sure you want to delete "${item.title}" (${item.bookingRef})?',
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                    ),
                    const SizedBox(height: 16),
                    RadioListTile<bool>(
                      value: false,
                      groupValue: deleteSeries,
                      onChanged: (val) => setDialogState(() => deleteSeries = val ?? false),
                      title: const Text('Delete this occurrence only', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(item.formattedSchedule, style: const TextStyle(fontSize: 11.5)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<bool>(
                      value: true,
                      groupValue: deleteSeries,
                      onChanged: (val) => setDialogState(() => deleteSeries = val ?? true),
                      title: const Text('Delete all occurrences in this recurring series', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Cancels all upcoming scheduled sessions in this series', style: TextStyle(fontSize: 11.5)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final ok = await notifier.deleteBooking(item.id, deleteSeries: deleteSeries);
                      if (ok) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(deleteSeries ? 'Recurring series deleted successfully.' : 'Booking deleted successfully.'),
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Delete Booking'),
                  ),
                ],
              );
            },
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Delete Space Booking?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
            content: Text(
              'Are you sure you want to delete "${item.title}" (${item.bookingRef}) scheduled on ${item.formattedSchedule}?',
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final ok = await notifier.deleteBooking(item.id);
                  if (ok) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Booking "${item.title}" deleted successfully.'),
                        backgroundColor: const Color(0xFFEF4444),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Delete Booking'),
              ),
            ],
          );
        },
      );
    }
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
              SpaceBookingKpisBar(
                kpis: state.kpis,
                onCardTap: (category) {
                  final notifier = ref.read(spaceBookingProvider.notifier);
                  if (category == 'All' || category == 'Confirmed' || category == 'Pending' || category == 'Rejected') {
                    notifier.setSelectedNav('Booking Requests');
                    notifier.setStatusFilter(category == 'Confirmed' ? 'Approved' : category);
                  } else if (category == 'Usage') {
                    notifier.setSelectedNav('Booking Spaces');
                  } else if (category == 'Reports') {
                    notifier.setSelectedNav('Usage & Reports');
                  }
                },
              ),
              const SizedBox(height: 16),

              // 2. Main Work Area (Left Navigation Panel + Full-Width Center Grid / Table)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 900;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Navigation & Quick Actions
                        SpaceBookingLeftPanel(
                          isCompact: false,
                          onOpenBookModal: () => _openCreateBookingModal(),
                        ),
                        const SizedBox(width: 16),

                        // Center Column: Full-Width Availability Timeline Grid + Booking Requests Table
                        Expanded(
                          child: SpaceBookingCenterPanel(
                            onInspectRequest: (item) => _openDetailsDrawer(item),
                            onEditRequest: (item) => _openCreateBookingModal(item: item),
                            onDeleteRequest: (item) => _handleDeleteBooking(item),
                            onCreateBooking: _openCreateBookingFromGrid,
                          ),
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
                        ),
                        const SizedBox(height: 16),
                        SpaceBookingCenterPanel(
                          onInspectRequest: (item) => _openDetailsDrawer(item),
                          onEditRequest: (item) => _openCreateBookingModal(item: item),
                          onDeleteRequest: (item) => _handleDeleteBooking(item),
                          onCreateBooking: _openCreateBookingFromGrid,
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
