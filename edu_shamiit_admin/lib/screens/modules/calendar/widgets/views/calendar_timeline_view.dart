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
                width: 200,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: const Text(
                  'Resource / Driver / Room',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
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
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
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
                      width: 200,
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
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  res.code,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                res.type,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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

                                return Positioned(
                                  left: left,
                                  top: 8,
                                  bottom: 8,
                                  width: width,
                                  child: InkWell(
                                    onTap: () => onEventTap(event),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: event.color.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: event.color, width: 1.5),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            event.title,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${DateFormat('hh:mm a').format(event.startTime)} – ${DateFormat('hh:mm a').format(event.endTime)}',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: event.color),
                                          ),
                                        ],
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
