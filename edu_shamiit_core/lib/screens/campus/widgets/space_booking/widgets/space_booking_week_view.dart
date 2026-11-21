import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/space_booking_models.dart';

class SpaceBookingWeekView extends StatelessWidget {
  final DateTime selectedDate;
  final List<SpaceTimelineRoom> rooms;
  final String selectedPurpose;
  final Function(SpaceBookingRequestItem item)? onInspectRequest;
  final Function(DateTime date, String time)? onSlotTap;

  const SpaceBookingWeekView({
    super.key,
    required this.selectedDate,
    required this.rooms,
    this.selectedPurpose = 'All',
    this.onInspectRequest,
    this.onSlotTap,
  });

  List<DateTime> _getWeekDays(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: (date.weekday - 1) % 7));
    return List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
  }

  int _parseHour(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPM = clean.contains('PM');
      final isAM = clean.contains('AM');
      final digits = clean.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = digits.split(':');
      if (parts.isNotEmpty) {
        int h = int.parse(parts[0]);
        if (isPM && h < 12) h += 12;
        if (isAM && h == 12) h = 0;
        return h;
      }
    } catch (_) {}
    return 9;
  }

  Color _getEventColor(String title, bool isDark) {
    final t = title.toLowerCase();
    if (t.contains('practical') || t.contains('lab') || t.contains('training')) {
      return const Color(0xFF7C3AED);
    }
    if (t.contains('meeting') || t.contains('conference')) {
      return const Color(0xFF10B981);
    }
    if (t.contains('workshop') || t.contains('seminar')) {
      return const Color(0xFFD97706);
    }
    if (t.contains('exam') || t.contains('test')) {
      return const Color(0xFFE11D48);
    }
    if (t.contains('club') || t.contains('cultural') || t.contains('sports')) {
      return const Color(0xFF06B6D4);
    }
    return const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final gridLineColor = isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF1F5F9);

    final weekDays = _getWeekDays(selectedDate);
    final hours = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18];

    // Collect all bookings across all rooms
    final allBookings = <Map<String, dynamic>>[];
    for (final room in rooms) {
      for (final b in room.bookings) {
        if (selectedPurpose != 'All') {
          final p = selectedPurpose.toLowerCase();
          final titleLower = b.title.toLowerCase();
          if (!titleLower.contains(p) && !b.purpose.toLowerCase().contains(p)) {
            continue;
          }
        }
        allBookings.add({
          'booking': b,
          'room': room,
        });
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final timeColWidth = constraints.maxWidth < 600 ? 50.0 : 68.0;

        return Column(
          children: [
            // 1. Week Header Row (Mon..Sun)
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                border: Border(bottom: BorderSide(color: cardBorder)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: timeColWidth,
                    child: Center(
                      child: Text(
                        'Time',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary),
                      ),
                    ),
                  ),
                  ...weekDays.map((day) {
                    final isToday = day.year == DateTime.now().year &&
                        day.month == DateTime.now().month &&
                        day.day == DateTime.now().day;
                    final isSelected = day.year == selectedDate.year &&
                        day.month == selectedDate.month &&
                        day.day == selectedDate.day;

                    return Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(left: BorderSide(color: cardBorder)),
                          color: isSelected
                              ? primaryColor.withValues(alpha: 0.08)
                              : Colors.transparent,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('EEE').format(day),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isToday ? primaryColor : textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isToday ? primaryColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: isToday ? Colors.white : (isSelected ? primaryColor : textPrimary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // 2. Weekly Time Grid Body
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: SingleChildScrollView(
                child: Column(
                  children: hours.map((hour) {
                    final timeLabel = DateFormat('h a').format(DateTime(2026, 1, 1, hour));

                    return Container(
                      height: 58,
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: gridLineColor)),
                      ),
                      child: Row(
                        children: [
                          // Time Label Column
                          SizedBox(
                            width: timeColWidth,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8, top: 4),
                              child: Text(
                                timeLabel,
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textSecondary),
                              ),
                            ),
                          ),

                          // 7 Days Cells
                          ...weekDays.map((day) {
                            final dayStr = DateFormat('yyyy-MM-dd').format(day);
                            final slotBookings = allBookings.where((entry) {
                              final SpaceTimelineBooking b = entry['booking'];
                              final bHour = _parseHour(b.startTime);
                              final sameHour = bHour == hour;
                              if (!sameHour) return false;

                              if (b.bookingDate.isNotEmpty) {
                                if (b.bookingDate == dayStr) return true;
                                final parsed = DateTime.tryParse(b.bookingDate);
                                if (parsed != null && DateUtils.isSameDay(parsed, day)) return true;
                              }
                              if (b.startDatetime != null) {
                                return DateUtils.isSameDay(b.startDatetime!, day);
                              }
                              return false;
                            }).toList();

                            return Expanded(
                              child: InkWell(
                                onTap: () {
                                  if (onSlotTap != null) {
                                    onSlotTap!(day, '${hour.toString().padLeft(2, '0')}:00');
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(left: BorderSide(color: cardBorder)),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: slotBookings.isEmpty
                                      ? null
                                      : SingleChildScrollView(
                                          child: Column(
                                            children: slotBookings.map((entry) {
                                              final SpaceTimelineBooking b = entry['booking'];
                                              final SpaceTimelineRoom room = entry['room'];
                                              final color = _getEventColor(b.title, isDark);

                                              return InkWell(
                                                onTap: () {
                                                  if (onInspectRequest != null) {
                                                    onInspectRequest!(SpaceBookingRequestItem(
                                                      id: b.id,
                                                      bookingRef: b.bookingRef.isNotEmpty ? b.bookingRef : 'SB-${b.id.substring(0, math.min(8, b.id.length))}',
                                                      title: b.title,
                                                      purpose: b.purpose,
                                                      category: 'Academic',
                                                      priority: 'Normal',
                                                      status: b.status,
                                                      isApproved: true,
                                                      bookingDate: b.bookingDate.isNotEmpty
                                                          ? b.bookingDate
                                                          : DateFormat('d MMM yyyy').format(day),
                                                      startTime: b.startTime,
                                                      endTime: b.endTime,
                                                      formattedSchedule: '${b.startTime} - ${b.endTime}',
                                                      roomId: room.roomId,
                                                      roomName: room.roomName,
                                                      roomType: room.roomType,
                                                      spaceDisplay: '${room.roomNumber} - ${room.roomName}',
                                                      buildingId: room.buildingId,
                                                      buildingName: room.buildingName,
                                                      organizerName: b.organizerName,
                                                      organizerRole: b.organizerRole,
                                                      requestedByDisplay: '${b.organizerName} (${b.organizerRole})',
                                                      attendeeCount: room.capacity > 0 ? room.capacity : 30,
                                                      isRecurring: b.isRecurring,
                                                    ));
                                                  }
                                                },
                                                borderRadius: BorderRadius.circular(4),
                                                child: Container(
                                                  margin: const EdgeInsets.only(bottom: 2),
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border(left: BorderSide(color: color, width: 3)),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        b.title,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w700,
                                                          color: isDark ? Colors.white : color,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      Text(
                                                        room.roomNumber,
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
