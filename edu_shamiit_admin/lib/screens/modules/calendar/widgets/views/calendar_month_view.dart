import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_models.dart';

class CalendarMonthView extends StatelessWidget {
  final DateTime selectedDate;
  final List<ScheduleModel> schedules;
  final Function(ScheduleModel schedule) onEventTap;
  final Function(DateTime dateTime, int hour) onSlotTap;

  const CalendarMonthView({
    super.key,
    required this.selectedDate,
    required this.schedules,
    required this.onEventTap,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    final startWeekday = (firstDayOfMonth.weekday - 1) % 7; // Monday = 0
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    bool isEventOnDay(ScheduleModel s, DateTime day) {
      final startDay = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      final endDay = DateTime(s.endTime.year, s.endTime.month, s.endTime.day);
      final targetDay = DateTime(day.year, day.month, day.day);

      return (targetDay.isAtSameMomentAs(startDay) || targetDay.isAfter(startDay)) &&
             (targetDay.isAtSameMomentAs(endDay) || targetDay.isBefore(endDay));
    }

    return Column(
      children: [
        // Weekday Headers
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            children: weekdays.map((w) {
              return Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // 7x5 Month Grid
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.2,
            ),
            itemCount: 35, // 5 weeks
            itemBuilder: (context, index) {
              final dayNum = index - startWeekday + 1;
              final isValidDay = dayNum > 0 && dayNum <= daysInMonth;
              final cellDate = isValidDay ? DateTime(selectedDate.year, selectedDate.month, dayNum) : null;

              final isToday = cellDate != null &&
                  cellDate.year == DateTime.now().year &&
                  cellDate.month == DateTime.now().month &&
                  cellDate.day == DateTime.now().day;

              final dayEvents = cellDate != null
                  ? schedules.where((s) => isEventOnDay(s, cellDate)).toList()
                  : <ScheduleModel>[];

              return InkWell(
                onTap: cellDate != null ? () => onSlotTap(cellDate, 9) : null,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isValidDay
                        ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Day Number Badge
                      if (isValidDay)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isToday ? const Color(0xFF4F46E5) : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$dayNum',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                    color: isToday
                                        ? Colors.white
                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                            ),
                            if (dayEvents.isNotEmpty)
                              Text(
                                '${dayEvents.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF94A3B8),
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 2),

                      // Schedule Chips
                      Expanded(
                        child: ListView(
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            ...dayEvents.take(2).map((event) {
                              final textTint = isDark
                                  ? Color.lerp(event.color, Colors.white, 0.45)!
                                  : event.color;

                              return InkWell(
                                onTap: () => onEventTap(event),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? event.color.withValues(alpha: 0.28)
                                        : event.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isDark
                                          ? event.color.withValues(alpha: 0.75)
                                          : event.color.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    '${DateFormat('hh:mm').format(event.startTime)} ${event.title}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: textTint,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }),
                            if (dayEvents.length > 2)
                              Padding(
                                padding: const EdgeInsets.only(top: 1, left: 4),
                                child: Text(
                                  '+${dayEvents.length - 2} more',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
