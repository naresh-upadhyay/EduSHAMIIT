import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/calendar_models.dart';
import '../providers/calendar_provider.dart';

class CalendarRightPanelWidget extends ConsumerWidget {
  final Function(ScheduleModel schedule) onSelectSchedule;
  final VoidCallback onOpenCreate;

  const CalendarRightPanelWidget({
    super.key,
    required this.onSelectSchedule,
    required this.onOpenCreate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    final notifier = ref.read(calendarProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 1. Mini Month Calendar Picker
          _buildMiniCalendar(context, ref, state, notifier),

          const SizedBox(height: 24),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          const SizedBox(height: 24),

          // 2. Category Counters ("My Schedule")
          _buildCategoryCounters(context, ref, state, notifier),

          const SizedBox(height: 24),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          const SizedBox(height: 24),

          // 3. "Assigned to Me" Task Cards
          _buildAssignedToMeSection(context, ref, state, notifier),

          const SizedBox(height: 24),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          const SizedBox(height: 24),

          // 4. "Upcoming Reminders"
          _buildUpcomingReminders(context, ref, state, notifier),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 1. MINI MONTH CALENDAR
  // --------------------------------------------------------------------------
  Widget _buildMiniCalendar(
      BuildContext context, WidgetRef ref, CalendarState state, CalendarNotifier notifier) {
    final selectedDate = state.selectedDate;
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month Navigation Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () {
                final prevMonth = DateTime(selectedDate.year, selectedDate.month - 1, 1);
                notifier.selectDate(prevMonth);
              },
              icon: Icon(Icons.chevron_left_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(28, 28),
              ),
            ),
            Text(
              DateFormat('MMMM yyyy').format(selectedDate),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            IconButton(
              onPressed: () {
                final nextMonth = DateTime(selectedDate.year, selectedDate.month + 1, 1);
                notifier.selectDate(nextMonth);
              },
              icon: Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(28, 28),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Weekday Column Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekdays.map((w) {
            return SizedBox(
              width: 32,
              child: Text(
                w,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF94A3B8),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),

        // Days Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemCount: startWeekday + daysInMonth,
          itemBuilder: (context, index) {
            if (index < startWeekday) {
              return const SizedBox.shrink();
            }
            final day = index - startWeekday + 1;
            final cellDate = DateTime(selectedDate.year, selectedDate.month, day);
            final isSelected = cellDate.year == selectedDate.year &&
                cellDate.month == selectedDate.month &&
                cellDate.day == selectedDate.day;

            final now = DateTime.now();
            final isToday = cellDate.year == now.year &&
                cellDate.month == now.month &&
                cellDate.day == now.day;

            return InkWell(
              onTap: () => notifier.selectDate(cellDate),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : (isToday ? const Color(0xFF4F46E5).withValues(alpha: 0.25) : Colors.transparent),
                  shape: BoxShape.circle,
                  border: isToday && !isSelected
                      ? Border.all(color: const Color(0xFF4F46E5), width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isToday
                              ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                              : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B))),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 2. MY SCHEDULE CATEGORY SUMMARY
  // --------------------------------------------------------------------------
  Widget _buildCategoryCounters(
      BuildContext context, WidgetRef ref, CalendarState state, CalendarNotifier notifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Compute dynamic count from state.schedules
    final Map<String, int> counts = {};
    for (final s in state.schedules) {
      final key = s.category.isNotEmpty ? s.category : s.scheduleType;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final categories = state.scheduleCategories.isNotEmpty
        ? state.scheduleCategories.take(6).map((cat) {
            final name = cat['name']?.toString() ?? '';
            final label = cat['label']?.toString() ?? name;
            final hex = cat['color']?.toString() ?? '#4F46E5';
            final count = counts[name] ?? (name == 'Meeting' ? 8 : (name == 'Task' ? 5 : (name == 'Event' ? 3 : (name == 'Reminder' ? 4 : 2))));
            return {
              'name': name,
              'label': label,
              'count': count,
              'color': _parseHexColor(hex),
            };
          }).toList()
        : [
            {'name': 'Meeting', 'label': 'Meetings', 'count': counts['Meeting'] ?? 8, 'color': const Color(0xFF8B5CF6)},
            {'name': 'Task', 'label': 'Tasks', 'count': counts['Task'] ?? 5, 'color': const Color(0xFF10B981)},
            {'name': 'Event', 'label': 'Events', 'count': counts['Event'] ?? 3, 'color': const Color(0xFFEF4444)},
            {'name': 'Reminder', 'label': 'Reminders', 'count': counts['Reminder'] ?? 4, 'color': const Color(0xFF3B82F6)},
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Schedule',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            InkWell(
              onTap: () {
                notifier.setCategoryFilter('All');
              },
              borderRadius: BorderRadius.circular(4),
              child: Text(
                'View All',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...categories.map((cat) {
          final isSelected = state.selectedCategory == cat['name'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  final newCat = isSelected ? 'All' : (cat['name'] as String);
                  notifier.setCategoryFilter(newCat);
                },
                borderRadius: BorderRadius.circular(8),
                hoverColor: (cat['color'] as Color).withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: cat['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cat['label'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                                : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                      Text(
                        '${cat['count']}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
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
  }

  // --------------------------------------------------------------------------
  // 3. ASSIGNED TO ME SECTION
  // --------------------------------------------------------------------------
  Widget _buildAssignedToMeSection(
      BuildContext context, WidgetRef ref, CalendarState state, CalendarNotifier notifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter assigned items from state.schedules
    final assignedSchedules = state.schedules.where((s) {
      return s.participants.isNotEmpty ||
          s.scheduleType == 'Task' ||
          s.category == 'Tasks' ||
          s.scheduleType == 'Class';
    }).toList();

    final displayItems = assignedSchedules.isNotEmpty
        ? assignedSchedules
        : [
            ScheduleModel(
              id: 'assigned-1',
              schoolId: '',
              calendarId: '',
              title: 'Review Project Proposal',
              scheduleType: 'Task',
              startTime: DateTime.now().add(const Duration(hours: 4)),
              endTime: DateTime.now().add(const Duration(hours: 5)),
              organizerName: 'Neha Sharma',
              color: const Color(0xFF4F46E5),
            ),
            ScheduleModel(
              id: 'assigned-2',
              schoolId: '',
              calendarId: '',
              title: 'Approve Leave Request',
              scheduleType: 'Task',
              startTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
              endTime: DateTime.now().add(const Duration(days: 1, hours: 3)),
              organizerName: 'Vikram Singh',
              color: const Color(0xFF10B981),
            ),
            ScheduleModel(
              id: 'assigned-3',
              schoolId: '',
              calendarId: '',
              title: 'Training Feedback',
              scheduleType: 'Training',
              startTime: DateTime.now().add(const Duration(days: 2)),
              endTime: DateTime.now().add(const Duration(days: 2, hours: 1)),
              organizerName: 'HR Department',
              color: const Color(0xFFF59E0B),
            ),
            ScheduleModel(
              id: 'assigned-4',
              schoolId: '',
              calendarId: '',
              title: 'Monthly Report Review',
              scheduleType: 'Finance',
              startTime: DateTime.now().add(const Duration(days: 3)),
              endTime: DateTime.now().add(const Duration(days: 3, hours: 1)),
              organizerName: 'Finance Team',
              color: const Color(0xFF06B6D4),
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Assigned to Me',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            InkWell(
              onTap: () {
                notifier.toggleFilterPill('assigned_to_me');
              },
              borderRadius: BorderRadius.circular(4),
              child: Text(
                'View All (${displayItems.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...displayItems.take(4).map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelectSchedule(item),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'By ${item.organizerName ?? "Administrator"}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Due ${DateFormat('E, hh:mm a').format(item.startTime)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF94A3B8),
                              ),
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
  }

  // --------------------------------------------------------------------------
  // 4. UPCOMING REMINDERS SECTION
  // --------------------------------------------------------------------------
  Widget _buildUpcomingReminders(
      BuildContext context, WidgetRef ref, CalendarState state, CalendarNotifier notifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final reminderSchedules = state.schedules.where((s) {
      return s.scheduleType == 'Reminder' || s.category == 'Reminders';
    }).toList();

    final reminders = reminderSchedules.isNotEmpty
        ? reminderSchedules.take(3).map((s) {
            return {
              'schedule': s,
              'title': s.title,
              'time': DateFormat('E, hh:mm a').format(s.startTime),
              'icon': Icons.notifications_active_outlined,
              'color': s.color,
            };
          }).toList()
        : [
            {
              'title': 'Team Standup',
              'time': 'Tomorrow, 09:00 AM',
              'icon': Icons.notifications_active_outlined,
              'color': const Color(0xFF10B981),
            },
            {
              'title': 'Submit Timesheet',
              'time': '30 May, 06:00 PM',
              'icon': Icons.alarm_rounded,
              'color': const Color(0xFF8B5CF6),
            },
            {
              'title': 'System Maintenance',
              'time': '01 Jun, 02:00 AM',
              'icon': Icons.build_circle_outlined,
              'color': const Color(0xFFF59E0B),
            },
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Reminders',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            InkWell(
              onTap: () {
                notifier.setCategoryFilter('Reminder');
              },
              borderRadius: BorderRadius.circular(4),
              child: Text(
                'View All',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...reminders.map((rem) {
          final color = rem['color'] as Color;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (rem['schedule'] is ScheduleModel) {
                    onSelectSchedule(rem['schedule'] as ScheduleModel);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(rem['icon'] as IconData, size: 18, color: isDark ? Color.lerp(color, Colors.white, 0.3)! : color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rem['title'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              rem['time'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
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
  }

  Color _parseHexColor(String hex) {
    try {
      final str = hex.replaceAll('#', '');
      if (str.length == 6) {
        return Color(int.parse('FF$str', radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF4F46E5);
  }
}
