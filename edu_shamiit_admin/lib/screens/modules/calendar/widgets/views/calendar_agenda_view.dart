import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';
import '../../models/calendar_models.dart';

class CalendarAgendaView extends ConsumerWidget {
  final DateTime selectedDate;
  final List<ScheduleModel> schedules;
  final Function(ScheduleModel schedule) onEventTap;

  const CalendarAgendaView({
    super.key,
    required this.selectedDate,
    required this.schedules,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(authProvider).userData;
    final currentUserId = currentUser?['id']?.toString();
    final now = DateTime.now();

    if (schedules.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_note_outlined,
                size: 36,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              const SizedBox(height: 10),
              Text(
                'No scheduled events or tasks for this period.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group schedules by normalized date (year, month, day)
    final Map<DateTime, List<ScheduleModel>> groupedByDate = {};
    for (final s in schedules) {
      final dateKey = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      groupedByDate.putIfAbsent(dateKey, () => []).add(s);
    }

    // Sort dates chronologically
    final sortedDates = groupedByDate.keys.toList()..sort((a, b) => a.compareTo(b));

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dayEvents = groupedByDate[date]!
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

        final isToday = DateUtils.isSameDay(date, now);
        final isTomorrow = DateUtils.isSameDay(date, now.add(const Duration(days: 1)));
        final isSelected = DateUtils.isSameDay(date, selectedDate);

        final headerColor = isToday
            ? const Color(0xFF4F46E5)
            : (isTomorrow ? const Color(0xFF10B981) : (isSelected ? const Color(0xFF8B5CF6) : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))));

        String badgeText = '';
        if (isToday) {
          badgeText = 'TODAY';
        } else if (isTomorrow) {
          badgeText = 'TOMORROW';
        } else if (isSelected) {
          badgeText = 'SELECTED DAY';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 20),
            // Date Header Row
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  DateFormat('EEEE, d MMMM yyyy').format(date).toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: headerColor,
                    letterSpacing: 0.5,
                  ),
                ),
                if (badgeText.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: headerColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: headerColor,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  '(${dayEvents.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Event Cards for this date
            ...dayEvents.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onEventTap(e),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time Column
                          SizedBox(
                            width: 105,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('hh:mm a').format(e.startTime),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'to ${DateFormat('hh:mm a').format(e.endTime)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Left Accent Bar
                          Container(
                            width: 4,
                            height: 48,
                            decoration: BoxDecoration(
                              color: e.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Event Information
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                     Expanded(
                                       child: Text(
                                         e.title,
                                         style: TextStyle(
                                           fontSize: 14,
                                           fontWeight: FontWeight.w800,
                                           color: e.status == 'cancelled' ? const Color(0xFFEF4444) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                           decoration: e.status == 'cancelled' ? TextDecoration.lineThrough : null,
                                         ),
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                       ),
                                     ),
                                     const SizedBox(width: 8),

                                     if (e.status == 'cancelled') ...[
                                       Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                         decoration: BoxDecoration(
                                           color: const Color(0xFFEF4444),
                                           borderRadius: BorderRadius.circular(10),
                                         ),
                                         child: const Text(
                                           'CANCELLED',
                                           style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                                         ),
                                       ),
                                       const SizedBox(width: 4),
                                     ],

                                    // Participation Role Badge for logged-in user
                                    if (e.participants.isNotEmpty) ...[
                                      Builder(
                                        builder: (_) {
                                          ScheduleParticipantModel? myP;
                                          if (currentUserId != null && currentUserId.isNotEmpty) {
                                            try {
                                              myP = e.participants.firstWhere((p) => p.userId == currentUserId);
                                            } catch (_) {}
                                          }
                                          final pRole = myP != null
                                              ? myP.participationRole.toLowerCase()
                                              : e.participants.first.participationRole.toLowerCase();
                                          final isReq = pRole == 'required' || pRole == 'mandatory';
                                          final isOpt = pRole == 'optional';
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            margin: const EdgeInsets.only(right: 6),
                                            decoration: BoxDecoration(
                                              color: isReq
                                                  ? const Color(0xFFEF4444)
                                                  : (isOpt ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6)),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isReq ? 'REQ' : (isOpt ? 'OPT' : 'FYI'),
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],

                                    // Schedule Type Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: e.color.withValues(alpha: isDark ? 0.22 : 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        e.scheduleType,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Color.lerp(e.color, Colors.white, 0.4)! : e.color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (e.description != null && e.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    e.description!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (e.locationName != null || e.room != null) ...[
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        e.locationName ?? e.room ?? '',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                    ],
                                    if (e.organizerName != null) ...[
                                      Icon(
                                        Icons.person_outline_rounded,
                                        size: 14,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        e.organizerName!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
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
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
