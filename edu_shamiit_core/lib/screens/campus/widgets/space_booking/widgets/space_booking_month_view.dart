import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/space_booking_models.dart';

class SpaceBookingMonthView extends StatelessWidget {
  final DateTime selectedDate;
  final List<SpaceTimelineRoom> rooms;
  final String selectedPurpose;
  final Function(SpaceBookingRequestItem item)? onInspectRequest;
  final Function(DateTime date)? onDayTap;

  const SpaceBookingMonthView({
    super.key,
    required this.selectedDate,
    required this.rooms,
    this.selectedPurpose = 'All',
    this.onInspectRequest,
    this.onDayTap,
  });

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

    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    final startWeekday = (firstDayOfMonth.weekday - 1) % 7; // Monday = 0
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Collect all bookings across rooms
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

    return Column(
      children: [
        // 1. Weekday Header Row
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border(bottom: BorderSide(color: cardBorder)),
          ),
          child: Row(
            children: weekdays.map((w) {
              return Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // 2. 7x5 Month Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.15,
          ),
          itemCount: 35,
          itemBuilder: (context, index) {
            final dayNum = index - startWeekday + 1;
            final isValidDay = dayNum > 0 && dayNum <= daysInMonth;
            final cellDate = isValidDay ? DateTime(selectedDate.year, selectedDate.month, dayNum) : null;

            final isToday = cellDate != null &&
                cellDate.year == DateTime.now().year &&
                cellDate.month == DateTime.now().month &&
                cellDate.day == DateTime.now().day;

            final isSelected = cellDate != null &&
                cellDate.year == selectedDate.year &&
                cellDate.month == selectedDate.month &&
                cellDate.day == selectedDate.day;

            final dayBookings = cellDate != null
                ? allBookings.where((entry) {
                    final SpaceTimelineBooking b = entry['booking'];
                    if (b.startDatetime != null) {
                      return DateUtils.isSameDay(b.startDatetime!, cellDate);
                    }
                    return (b.id.hashCode.abs() % daysInMonth + 1) == dayNum;
                  }).toList()
                : <Map<String, dynamic>>[];

            return InkWell(
              onTap: cellDate != null ? () => onDayTap?.call(cellDate) : null,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isValidDay
                      ? (isSelected
                          ? primaryColor.withValues(alpha: 0.08)
                          : (isDark ? const Color(0xFF1E293B) : Colors.white))
                      : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC)),
                  border: Border.all(color: cardBorder.withValues(alpha: 0.5), width: 0.5),
                ),
                child: isValidDay
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isToday ? primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$dayNum',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isToday
                                        ? Colors.white
                                        : (isSelected ? primaryColor : textPrimary),
                                  ),
                                ),
                              ),
                              if (dayBookings.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${dayBookings.length}',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: Column(
                                children: dayBookings.take(2).map((entry) {
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
                                          bookingDate: DateFormat('d MMM yyyy').format(cellDate!),
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
                                          isRecurring: false,
                                        ));
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(3),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: isDark ? 0.3 : 0.12),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border(left: BorderSide(color: color, width: 2)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${b.title} (${room.roomNumber})',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : color,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          if (dayBookings.length > 2)
                            Text(
                              '+${dayBookings.length - 2} more',
                              style: TextStyle(fontSize: 8.5, color: textSecondary, fontWeight: FontWeight.w600),
                            ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            );
          },
        ),
      ],
    );
  }
}
