import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_models.dart';

class CalendarAgendaView extends StatelessWidget {
  final List<ScheduleModel> schedules;
  final Function(ScheduleModel schedule) onEventTap;

  const CalendarAgendaView({
    super.key,
    required this.schedules,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Group schedules by Today, Tomorrow, This Week, Next Week
    final todayEvents = schedules.where((s) =>
        s.startTime.year == now.year &&
        s.startTime.month == now.month &&
        s.startTime.day == now.day).toList();

    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowEvents = schedules.where((s) =>
        s.startTime.year == tomorrow.year &&
        s.startTime.month == tomorrow.month &&
        s.startTime.day == tomorrow.day).toList();

    final thisWeekEvents = schedules.where((s) =>
        s.startTime.isAfter(tomorrow) &&
        s.startTime.isBefore(now.add(const Duration(days: 7)))).toList();

    final upcomingEvents = schedules.where((s) =>
        s.startTime.isAfter(now.add(const Duration(days: 7)))).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildAgendaSection(context, 'TODAY', todayEvents, const Color(0xFF4F46E5)),
        const SizedBox(height: 24),
        _buildAgendaSection(context, 'TOMORROW', tomorrowEvents, const Color(0xFF10B981)),
        const SizedBox(height: 24),
        _buildAgendaSection(context, 'THIS WEEK', thisWeekEvents, const Color(0xFFF59E0B)),
        if (upcomingEvents.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildAgendaSection(context, 'UPCOMING', upcomingEvents, const Color(0xFF64748B)),
        ],
      ],
    );
  }

  Widget _buildAgendaSection(BuildContext context, String header, List<ScheduleModel> events, Color headerColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              header,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: headerColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${events.length})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'No scheduled events or tasks for this period.',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          )
        else
          ...events.map((e) {
            return InkWell(
              onTap: () => onEventTap(e),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time column
                    SizedBox(
                      width: 100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('hh:mm a').format(e.startTime),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'to ${DateFormat('hh:mm a').format(e.endTime)}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),

                    // Color bar indicator
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: e.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Main info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                e.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: e.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  e.scheduleType,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: e.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (e.description != null)
                            Text(
                              e.description!,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (e.locationName != null || e.room != null) ...[
                                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  e.locationName ?? e.room ?? '',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 16),
                              ],
                              if (e.organizerName != null) ...[
                                const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  e.organizerName!,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
