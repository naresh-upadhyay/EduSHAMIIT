import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';
import '../../models/calendar_models.dart';
import '../../utils/calendar_layout_engine.dart';

class CalendarWeekViewWidget extends ConsumerWidget {
  final DateTime selectedDate;
  final List<ScheduleModel> schedules;
  final Function(ScheduleModel event) onEventTap;
  final Function(DateTime date, int hour) onSlotTap;

  const CalendarWeekViewWidget({
    super.key,
    required this.selectedDate,
    required this.schedules,
    required this.onEventTap,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider).userData;
    final currentUserId = currentUser?['id']?.toString();
    final weekDays = _getWeekDays(selectedDate);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter schedules for the current week
    final weekStart = DateTime(weekDays.first.year, weekDays.first.month, weekDays.first.day);
    final weekEnd = DateTime(weekDays.last.year, weekDays.last.month, weekDays.last.day, 23, 59, 59);
    final weekSchedules = schedules.where((s) {
      return (s.startTime.isBefore(weekEnd) && s.endTime.isAfter(weekStart));
    }).toList();

    // Separate all-day / multi-day / cross-midnight events from same-day hourly events
    final allDayAndMultiDayEvents = weekSchedules.where((s) {
      return s.isAllDay ||
          !DateUtils.isSameDay(s.startTime, s.endTime) ||
          s.endTime.difference(s.startTime).inHours >= 24;
    }).toList();

    final hourlyEvents = weekSchedules.where((s) {
      return !s.isAllDay &&
          DateUtils.isSameDay(s.startTime, s.endTime) &&
          s.endTime.difference(s.startTime).inHours < 24;
    }).toList();

    return Column(
      children: [
        // 1. Week Header Row (Mon..Sun)
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 70,
                child: Center(
                  child: Text(
                    'GMT+5:30',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
              ...weekDays.map((day) {
                final isToday = day.year == DateTime.now().year &&
                    day.month == DateTime.now().month &&
                    day.day == DateTime.now().day;
                final isSelectedDay = day.year == selectedDate.year &&
                    day.month == selectedDate.month &&
                    day.day == selectedDate.day;

                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(day),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isToday
                                ? const Color(0xFF4F46E5)
                                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF4F46E5)
                                : (isSelectedDay ? const Color(0xFF4F46E5).withValues(alpha: 0.25) : Colors.transparent),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isToday
                                    ? Colors.white
                                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
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

        // 2. All-Day / Multi-Day Events Banner Row
        if (allDayAndMultiDayEvents.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 70,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, left: 12),
                    child: Text(
                      'All Day',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                ...weekDays.map((day) {
                  final dayAllDay = allDayAndMultiDayEvents.where((e) => isEventOnDay(e, day)).toList();

                  return Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: dayAllDay.map((e) {
                          final isStart = DateUtils.isSameDay(e.startTime, day);
                          final isEnd = DateUtils.isSameDay(e.endTime, day);
                          final timeBadge = e.isAllDay ? 'All Day' : (isStart ? DateFormat('hh:mm a').format(e.startTime) : (isEnd ? 'ends ${DateFormat('hh:mm a').format(e.endTime)}' : 'all day'));

                          return InkWell(
                            onTap: () => onEventTap(e),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark ? _getDarkSolidCardBg(e.color) : _getLightSolidCardBg(e.color),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: e.color, width: 1.5),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 3, offset: const Offset(0, 1)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(width: 3, height: 12, color: e.color),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${e.title} ($timeBadge)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                  );
                }),
              ],
            ),
          ),

        // 3. 24-Hour Scrollable Grid Stage
        Expanded(
          child: SingleChildScrollView(
            child: SizedBox(
              height: 24 * 60.0, // 60px per hour
              child: Stack(
                children: [
                  // Hour Grid Background Lines
                  Column(
                    children: List.generate(24, (hour) {
                      final displayHour = hour == 0
                          ? '12:00 AM'
                          : hour < 12
                              ? '${hour.toString().padLeft(2, '0')}:00 AM'
                              : hour == 12
                                  ? '12:00 PM'
                                  : '${(hour - 12).toString().padLeft(2, '0')}:00 PM';

                      return SizedBox(
                        height: 60.0,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8, top: 4),
                                child: Text(
                                  displayHour,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ),
                            ...weekDays.map((day) {
                              return Expanded(
                                child: InkWell(
                                  onTap: () => onSlotTap(day, hour),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                          width: 1,
                                        ),
                                        left: BorderSide(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                  ),

                  // Red Current Time Line Indicator
                  _buildCurrentTimeIndicator(context, weekDays),

                  // Schedules Render Overlay with Side-by-Side Overlap Engine
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 70),
                      child: Row(
                        children: weekDays.map((day) {
                          // Filter same-day hourly events specifically for this day
                          final dayEvents = hourlyEvents.where((e) => DateUtils.isSameDay(e.startTime, day)).toList();

                          return Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final colWidth = constraints.maxWidth;
                                final positioned = CalendarLayoutEngine.computePositionedEvents(
                                  dayEvents,
                                  day,
                                  hourHeight: 60.0,
                                  minHeight: 24.0,
                                );

                                return Stack(
                                    children: positioned.map((pe) {
                                    final laneW = (colWidth - 2) / pe.totalLanes;
                                    final left = 1.0 + (pe.laneIndex * laneW);
                                    final width = (laneW - 2.0).clamp(10.0, colWidth);

                                    return Positioned(
                                      top: pe.top,
                                      left: left,
                                      width: width,
                                      height: pe.height,
                                      child: _buildEventCard(context, pe.event, pe.height, pe.totalLanes, currentUserId),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentTimeIndicator(BuildContext context, List<DateTime> weekDays) {
    final now = DateTime.now();
    final todayIndex = weekDays.indexWhere((d) =>
        d.year == now.year && d.month == now.month && d.day == now.day);

    if (todayIndex == -1) return const SizedBox.shrink();

    final minutesFromMidnight = now.hour * 60 + now.minute;
    final topPosition = (minutesFromMidnight / 60.0) * 60.0;

    return Positioned(
      top: topPosition,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 70,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                DateFormat('hh:mm a').format(now),
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                const Divider(color: Color(0xFFEF4444), height: 1, thickness: 2),
                Positioned(
                  left: (todayIndex * (MediaQuery.of(context).size.width - 70) / 7),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, ScheduleModel event, double height, int totalLanes, String? currentUserId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeSpan = '${DateFormat('hh:mm a').format(event.startTime)} – ${DateFormat('hh:mm a').format(event.endTime)}';

    // Google Calendar Solid Opaque Card Fills
    final cardBg = isDark
        ? _getDarkSolidCardBg(event.color)
        : _getLightSolidCardBg(event.color);

    final borderColor = isDark
        ? event.color.withValues(alpha: 0.5)
        : _getLightBorderColor(event.color);

    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textTint = isDark
        ? Color.lerp(event.color, Colors.white, 0.55)!
        : _getDarkerAccent(event.color);

    final tooltipMsg = '${event.title}\n⏰ $timeSpan\n📍 ${event.locationName ?? event.room ?? "General"}\n🏷️ Type: ${event.scheduleType}';

    return Tooltip(
      message: tooltipMsg,
      waitDuration: const Duration(milliseconds: 250),
      showDuration: const Duration(seconds: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      textStyle: const TextStyle(fontSize: 12, color: Colors.white, height: 1.4, fontWeight: FontWeight.w600),
      child: InkWell(
        onTap: () => onEventTap(event),
        borderRadius: BorderRadius.circular(8),
        child: Container(
        margin: const EdgeInsets.only(bottom: 2, right: 1),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Solid 4px Left Accent Bar
            Container(
              width: 4,
              height: double.infinity,
              color: event.color,
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: totalLanes > 1 ? 4 : 8,
                  vertical: height < 40 ? 2 : 5,
                ),
                child: height < 36
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${DateFormat('hh:mm a').format(event.startTime)} ${event.title}',
                              style: TextStyle(
                                fontSize: totalLanes > 2 ? 8.5 : 9.5,
                                fontWeight: FontWeight.w800,
                                color: event.status == 'cancelled' ? const Color(0xFFEF4444) : titleColor,
                                decoration: event.status == 'cancelled' ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeSpan,
                            style: TextStyle(
                              fontSize: totalLanes > 2 ? 8.5 : 9.5,
                              fontWeight: FontWeight.w700,
                              color: textTint,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Flexible(
                            child: Text(
                              event.title,
                              style: TextStyle(
                                fontSize: totalLanes > 2 ? 9.5 : 11.5,
                                fontWeight: FontWeight.w800,
                                color: event.status == 'cancelled' ? const Color(0xFFEF4444) : titleColor,
                                decoration: event.status == 'cancelled' ? TextDecoration.lineThrough : null,
                                letterSpacing: -0.2,
                                height: 1.15,
                              ),
                              maxLines: height > 75 ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (height > 60 && totalLanes <= 2 && (event.locationName != null || event.organizerName != null || event.room != null)) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (event.virtualMeetingUrl != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(Icons.videocam_rounded, size: 12, color: textTint),
                                  ),
                                Expanded(
                                  child: Text(
                                    event.locationName ?? event.room ?? event.organizerName ?? '',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: textTint,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (event.participants.isNotEmpty) ...[
                                  Builder(
                                    builder: (_) {
                                      ScheduleParticipantModel? myP;
                                      if (currentUserId != null && currentUserId.isNotEmpty) {
                                        try {
                                          myP = event.participants.firstWhere((p) => p.userId == currentUserId);
                                        } catch (_) {}
                                      }
                                      final pRole = myP != null
                                          ? myP.participationRole.toLowerCase()
                                          : event.participants.first.participationRole.toLowerCase();
                                      final isReq = pRole == 'required' || pRole == 'mandatory';
                                      final isOpt = pRole == 'optional';
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isReq
                                              ? const Color(0xFFEF4444)
                                              : (isOpt ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6)),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isReq ? 'REQ' : (isOpt ? 'OPT' : 'FYI'),
                                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.people_alt_rounded, size: 11, color: textTint),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Color _getLightSolidCardBg(Color c) {
    final argb = c.toARGB32();
    if (argb == const Color(0xFF4F46E5).toARGB32()) return const Color(0xFFEEF2FF);
    if (argb == const Color(0xFF10B981).toARGB32()) return const Color(0xFFECFDF5);
    if (argb == const Color(0xFF3B82F6).toARGB32()) return const Color(0xFFE0F2FE);
    if (argb == const Color(0xFFF59E0B).toARGB32()) return const Color(0xFFFEF3C7);
    if (argb == const Color(0xFFEF4444).toARGB32()) return const Color(0xFFFEE2E2);
    if (argb == const Color(0xFF8B5CF6).toARGB32()) return const Color(0xFFF3E8FF);
    if (argb == const Color(0xFF06B6D4).toARGB32()) return const Color(0xFFE0F7FA);
    if (argb == const Color(0xFFA855F7).toARGB32()) return const Color(0xFFF3E8FF);
    if (argb == const Color(0xFFF43F5E).toARGB32()) return const Color(0xFFFFE4E6);
    return Color.lerp(c, Colors.white, 0.88)!;
  }

  Color _getDarkSolidCardBg(Color c) {
    final argb = c.toARGB32();
    if (argb == const Color(0xFF4F46E5).toARGB32()) return const Color(0xFF1E1B4B);
    if (argb == const Color(0xFF10B981).toARGB32()) return const Color(0xFF064E3B);
    if (argb == const Color(0xFF3B82F6).toARGB32()) return const Color(0xFF0C4A6E);
    if (argb == const Color(0xFFF59E0B).toARGB32()) return const Color(0xFF451A03);
    if (argb == const Color(0xFFEF4444).toARGB32()) return const Color(0xFF4C0519);
    if (argb == const Color(0xFF8B5CF6).toARGB32()) return const Color(0xFF2E1065);
    if (argb == const Color(0xFF06B6D4).toARGB32()) return const Color(0xFF164E63);
    if (argb == const Color(0xFFA855F7).toARGB32()) return const Color(0xFF3B0764);
    if (argb == const Color(0xFFF43F5E).toARGB32()) return const Color(0xFF4C0519);
    return const Color(0xFF1E293B);
  }

  Color _getLightBorderColor(Color c) {
    return Color.lerp(c, Colors.white, 0.5)!;
  }

  Color _getDarkerAccent(Color c) {
    return Color.lerp(c, const Color(0xFF0F172A), 0.3)!;
  }

  List<DateTime> _getWeekDays(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));
  }

  bool isEventOnDay(ScheduleModel event, DateTime day) {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);

    return (event.startTime.isBefore(endOfDay) && event.endTime.isAfter(startOfDay));
  }
}
