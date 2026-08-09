import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_models.dart';

class CalendarTimelineView extends StatelessWidget {
  final DateTime selectedDate;
  final List<ScheduleModel> schedules;
  final List<CalendarResourceModel> resources;
  final Function(ScheduleModel schedule) onEventTap;

  const CalendarTimelineView({
    super.key,
    required this.selectedDate,
    required this.schedules,
    required this.resources,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use available resources or fallback to core facilities
    final rows = resources.isNotEmpty
        ? resources
        : [
            CalendarResourceModel(id: '1', name: 'Conference Room A', code: 'CONF-A', type: 'meeting_room'),
            CalendarResourceModel(id: '2', name: 'Meeting Room 1', code: 'MR-1', type: 'meeting_room'),
            CalendarResourceModel(id: '3', name: 'Meeting Room 2', code: 'MR-2', type: 'meeting_room'),
            CalendarResourceModel(id: '4', name: 'Room 204 (Math Lab)', code: 'RM-204', type: 'classroom'),
            CalendarResourceModel(id: '5', name: 'Bus UP16 ET 1234', code: 'BUS-101', type: 'bus'),
            CalendarResourceModel(id: '6', name: 'Bus UP16 ET 5678', code: 'BUS-102', type: 'bus'),
          ];

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final double ts = (screenWidth / 700).clamp(0.78, 1.0);

    return Column(
      children: [
        // Timeline Top Axis Header
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: isMobile ? 120 : 200,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Text(
                  'Resource / Driver / Room',
                  style: TextStyle(fontSize: (12 * ts).roundToDouble(), fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(24, (hour) {
                      final hStr = hour < 12
                          ? '${hour.toString().padLeft(2, '0')}:00'
                          : hour == 12
                              ? '12:00'
                              : '${(hour - 12).toString().padLeft(2, '0')}:00 PM';
                      return SizedBox(
                        width: 80,
                        child: Center(
                          child: Text(
                            hStr,
                            style: TextStyle(fontSize: (11 * ts).roundToDouble(), fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Swimlanes
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final res = rows[index];
              final resEvents = schedules.where((s) {
                return s.locationName?.contains(res.name) == true ||
                    s.room?.contains(res.name) == true ||
                    s.title.contains(res.name) == true ||
                    s.resources.any((r) => r.resourceId == res.id || r.resourceName == res.name);
              }).toList();

              return Container(
                height: 72,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    // Resource Y-axis Label
                    Container(
                      width: isMobile ? 120 : 200,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: Border(
                          right: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            res.name,
                            style: TextStyle(
                              fontSize: (13 * ts).roundToDouble(),
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.22 : 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  res.code,
                                  style: TextStyle(
                                    fontSize: (10 * ts).roundToDouble(),
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                res.type,
                                style: TextStyle(
                                  fontSize: (11 * ts).roundToDouble(),
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 24-Hour Swimlane Canvas
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 24 * 80.0,
                          child: Stack(
                            children: [
                              // Vertical hour dividing lines
                              Row(
                                children: List.generate(24, (h) {
                                  return Container(
                                    width: 80,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                      ),
                                    ),
                                  );
                                }),
                              ),

                              // Render Schedule Blocks
                              ...resEvents.map((event) {
                                final startMin = event.startTime.hour * 60 + event.startTime.minute;
                                final endMin = event.endTime.hour * 60 + event.endTime.minute;
                                final durationMin = (endMin - startMin).clamp(30, 24 * 60);
                                final left = (startMin / 60.0) * 80.0;
                                final width = (durationMin / 60.0) * 80.0;
                                final tooltipMsg = '${event.title}\n⏰ ${DateFormat('hh:mm a').format(event.startTime)} – ${DateFormat('hh:mm a').format(event.endTime)}\n📍 ${event.locationName ?? event.room ?? "General"}\n🏷️ Type: ${event.scheduleType}';

                                return Positioned(
                                  left: left,
                                  top: 8,
                                  bottom: 8,
                                  width: width.clamp(16.0, 24 * 80.0),
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
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: event.color.withValues(alpha: isDark ? 0.25 : 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: event.color, width: 1.5),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            event.title,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                          ),
                                          if (width > 55) ...[
                                            const SizedBox(height: 1),
                                            Text(
                                              '${DateFormat('hh:mm a').format(event.startTime)} – ${DateFormat('hh:mm a').format(event.endTime)}',
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Color.lerp(event.color, Colors.white, 0.4)! : event.color,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              softWrap: false,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
