import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';
import '../../models/calendar_models.dart';
import '../../utils/calendar_layout_engine.dart';

class CalendarDayView extends ConsumerWidget {
  final DateTime selectedDate;
  final List<ScheduleModel> schedules;
  final Function(ScheduleModel event) onEventTap;
  final Function(DateTime date, int hour) onSlotTap;

  const CalendarDayView({
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final endOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

    final daySchedules = schedules.where((s) {
      return (s.startTime.isBefore(endOfDay) && s.endTime.isAfter(startOfDay));
    }).toList();

    // Separate all-day / multi-day / cross-midnight events from same-day hourly events
    final allDayAndMultiDayEvents = daySchedules.where((s) {
      return s.isAllDay ||
          !DateUtils.isSameDay(s.startTime, s.endTime) ||
          s.endTime.difference(s.startTime).inHours >= 24;
    }).toList();

    final hourlyEvents = daySchedules.where((s) {
      return !s.isAllDay &&
          DateUtils.isSameDay(s.startTime, s.endTime) &&
          s.endTime.difference(s.startTime).inHours < 24;
    }).toList();

    return LayoutBuilder(
      builder: (context, outerConstraints) {
    final isMobile = outerConstraints.maxWidth < 500;
    final double ts = (outerConstraints.maxWidth / 550).clamp(0.70, 1.0);
    final hPad = isMobile ? 8.0 : 24.0;
    final timeColWidth = isMobile ? 48.0 : 80.0;

    return Column(
      children: [
        // Day Header Bar
        Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: isMobile ? 6 : 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isMobile
                      ? DateFormat('EEE, d MMM').format(selectedDate)
                      : DateFormat('EEEE, d MMMM yyyy').format(selectedDate),
                  style: TextStyle(
                    fontSize: (14.5 * ts).roundToDouble(),
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.25 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isMobile ? '${daySchedules.length}' : '${daySchedules.length} Schedules Today',
                    style: TextStyle(
                      fontSize: (11 * ts).roundToDouble(),
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),

        // All Day / Multi-Day Banner Row if present
        if (allDayAndMultiDayEvents.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
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
                  width: timeColWidth,
                  child: Text(
                    'All Day',
                    style: TextStyle(
                      fontSize: (11 * ts).roundToDouble(),
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: allDayAndMultiDayEvents.map((e) {
                      final isStart = DateUtils.isSameDay(e.startTime, selectedDate);
                      final isEnd = DateUtils.isSameDay(e.endTime, selectedDate);
                      final timeBadge = e.isAllDay ? 'All Day' : (isStart ? DateFormat('hh:mm a').format(e.startTime) : (isEnd ? 'ends ${DateFormat('hh:mm a').format(e.endTime)}' : 'all day'));

                      return InkWell(
                        onTap: () => onEventTap(e),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? _getDarkSolidCardBg(e.color) : _getLightSolidCardBg(e.color),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: e.color, width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 3, offset: const Offset(0, 1)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 3, height: 12, color: e.color),
                              const SizedBox(width: 6),
                              Text(
                                '${e.title} ($timeBadge)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

        // Hourly Grid
        Expanded(
          child: SingleChildScrollView(
            child: SizedBox(
              height: 24 * 70.0,
              child: Stack(
                children: [
                  Column(
                    children: List.generate(24, (hour) {
                      final timeStr = hour == 0
                          ? '12:00 AM'
                          : hour < 12
                              ? '${hour.toString().padLeft(2, '0')}:00 AM'
                              : hour == 12
                                  ? '12:00 PM'
                                  : '${(hour - 12).toString().padLeft(2, '0')}:00 PM';

                      return InkWell(
                        onTap: () => onSlotTap(selectedDate, hour),
                        child: Container(
                          height: 70.0,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              ),
                            ),
                          ),
                      child: Row(
                            children: [
                              SizedBox(
                                width: timeColWidth,
                                child: Padding(
                                  padding: EdgeInsets.only(left: isMobile ? 4 : 16, top: 8),
                                  child: Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: (11 * ts).roundToDouble(),
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ),
                              const Expanded(child: SizedBox()),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),

                  // Schedules Overlay with Side-by-Side Overlap Engine
                  Positioned.fill(
                    child: Padding(
                    padding: EdgeInsets.only(left: timeColWidth + 10, right: isMobile ? 6 : 20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final availableWidth = constraints.maxWidth;
                          final positioned = CalendarLayoutEngine.computePositionedEvents(
                            hourlyEvents,
                            selectedDate,
                            hourHeight: 70.0,
                            minHeight: 30.0,
                          );

                          return Stack(
                            children: positioned.map((pe) {
                              final event = pe.event;
                              final totalLanes = pe.totalLanes;
                              final laneW = (availableWidth - 2) / totalLanes;
                              final left = (pe.laneIndex * laneW);
                              final width = (laneW - 4.0).clamp(20.0, availableWidth);
                              final height = pe.height;

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

                              final tooltipMsg = '${event.title}\n⏰ ${DateFormat('hh:mm a').format(event.startTime)} – ${DateFormat('hh:mm a').format(event.endTime)}\n📍 ${event.locationName ?? event.room ?? "General"}\n🏷️ Type: ${event.scheduleType}';

                               return Positioned(
                                 top: pe.top,
                                 left: left,
                                 width: width,
                                 height: height,
                                 child: Tooltip(
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
                                           Container(
                                             width: 4,
                                             height: double.infinity,
                                             color: event.color,
                                           ),
                                           Expanded(
                                             child: Padding(
                                               padding: const EdgeInsets.all(8),
                                               child: Column(
                                                 crossAxisAlignment: CrossAxisAlignment.start,
                                                 mainAxisSize: MainAxisSize.min,
                                                 children: [
                                                   Row(
                                                     children: [
                                                    Expanded(
                                                      child: Text(
                                                        event.title,
                                                        style: TextStyle(
                                                          fontSize: (13 * ts).roundToDouble(),
                                                          fontWeight: FontWeight.w800,
                                                          color: titleColor,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (!isMobile && totalLanes <= 2) ...[
                                                      const SizedBox(width: 8),
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
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: isReq
                                                                    ? const Color(0xFFEF4444)
                                                                    : (isOpt ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6)),
                                                                borderRadius: BorderRadius.circular(10),
                                                              ),
                                                              child: Text(
                                                                isReq ? 'REQUIRED' : (isOpt ? 'OPTIONAL' : 'FYI'),
                                                                style: const TextStyle(
                                                                  fontSize: 9,
                                                                  fontWeight: FontWeight.w900,
                                                                  color: Colors.white,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                        const SizedBox(width: 4),
                                                      ],
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: event.color.withValues(alpha: 0.2),
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Text(
                                                          event.scheduleType,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: textTint,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${DateFormat('hh:mm a').format(event.startTime)} – ${DateFormat('hh:mm a').format(event.endTime)}${isMobile ? '' : '  •  ${event.locationName ?? event.room ?? "General"}'}',
                                                  style: TextStyle(
                                                     fontSize: (11.5 * ts).roundToDouble(),
                                                    fontWeight: FontWeight.w600,
                                                    color: textTint,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (event.description != null && height > 75 && totalLanes <= 2) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    event.description!,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
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
                              ),
                            );
                          }).toList(),
                          );
                        },
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
      },
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
}
