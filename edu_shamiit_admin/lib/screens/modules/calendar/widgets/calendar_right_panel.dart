import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';
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

    // Filter schedule dataset dynamically matched with active visible schedules on the board
    final dataset = state.schedules.isNotEmpty ? state.schedules : state.rawSchedules;
    DateTime periodStart;
    DateTime periodEnd;
    String periodLabel;

    switch (state.viewMode) {
      case CalendarViewMode.day:
        periodStart = DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day, 0, 0, 0);
        periodEnd = DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day, 23, 59, 59);
        periodLabel = 'This Day';
        break;
      case CalendarViewMode.threeDay:
        periodStart = DateTime(state.selectedDate.year, state.selectedDate.month, state.selectedDate.day, 0, 0, 0);
        periodEnd = periodStart.add(const Duration(days: 3, microseconds: -1));
        periodLabel = '3 Days';
        break;
      case CalendarViewMode.week:
      case CalendarViewMode.timeline:
      case CalendarViewMode.agenda:
        final monday = state.selectedDate.subtract(Duration(days: state.selectedDate.weekday - 1));
        periodStart = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
        periodEnd = periodStart.add(const Duration(days: 7, microseconds: -1));
        periodLabel = 'This Week';
        break;
      case CalendarViewMode.month:
        periodStart = DateTime(state.selectedDate.year, state.selectedDate.month, 1, 0, 0, 0);
        periodEnd = DateTime(state.selectedDate.year, state.selectedDate.month + 1, 0, 23, 59, 59);
        periodLabel = 'This Month';
        break;
      case CalendarViewMode.year:
        periodStart = DateTime(state.selectedDate.year, 1, 1, 0, 0, 0);
        periodEnd = DateTime(state.selectedDate.year, 12, 31, 23, 59, 59);
        periodLabel = 'This Year';
        break;
    }

    final activePeriodSchedules = dataset.where((s) {
      return s.startTime.isBefore(periodEnd) && s.endTime.isAfter(periodStart);
    }).toList();

    // Build category lookup map from DB
    final Map<String, Map<String, dynamic>> dbCategoryLookup = {};
    for (final cat in state.scheduleCategories) {
      final name = cat['name']?.toString() ?? '';
      if (name.isNotEmpty) {
        dbCategoryLookup[name.toLowerCase()] = cat;
      }
    }

    // Compute REAL dynamic counts for active view period from complete dataset (case-insensitive & trimmed)
    final Map<String, int> counts = {};
    final Map<String, String> displayNames = {};

    for (final s in activePeriodSchedules) {
      final rawKey = (s.scheduleType.isNotEmpty && s.scheduleType.toLowerCase() != 'general')
          ? s.scheduleType
          : (s.category.isNotEmpty ? s.category : s.scheduleType);
      final key = rawKey.trim();
      if (key.isNotEmpty) {
        final lowerKey = key.toLowerCase();
        counts[lowerKey] = (counts[lowerKey] ?? 0) + 1;
        if (!displayNames.containsKey(lowerKey) || key[0] == key[0].toUpperCase()) {
          displayNames[lowerKey] = key;
        }
      }
    }

    // Build categories list ONLY for categories that have count > 0
    final List<Map<String, dynamic>> activeCategories = [];
    counts.forEach((lowerKey, count) {
      if (count > 0) {
        final dbCat = dbCategoryLookup[lowerKey];
        final rawName = displayNames[lowerKey] ?? lowerKey;
        final label = dbCat?['label']?.toString() ?? rawName;
        final hex = dbCat?['color']?.toString();
        activeCategories.add({
          'name': rawName,
          'label': label,
          'count': count,
          'color': _getCategoryColor(lowerKey, hex),
        });
      }
    });

    // Sort categories by count descending
    activeCategories.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'My Schedule',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    periodLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
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

        if (activeCategories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 8),
                Text(
                  'No schedules for $periodLabel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          )
        else
          ...activeCategories.map((cat) {
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
    final currentUser = ref.watch(authProvider).userData;
    final currentUserId = currentUser?['id']?.toString();

    final now = DateTime.now();
    // Filter REAL assigned items from active visible dataset that are IN THE FUTURE from current time
    final dataset = state.schedules.isNotEmpty ? state.schedules : state.rawSchedules;
    final assignedSchedules = dataset.where((s) {
      final isFutureOrCurrent = s.endTime.isAfter(now) || s.startTime.isAfter(now);
      bool isAssigned = false;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final isParticipant = s.participants.any((p) => p.userId == currentUserId);
        final isOrganizer = s.organizerId == currentUserId || s.createdBy == currentUserId;
        isAssigned = isParticipant || isOrganizer;
      } else {
        isAssigned = s.participants.isNotEmpty;
      }
      return isFutureOrCurrent && isAssigned;
    }).toList();

    // Sort ascending by start time so the closest upcoming assignment appears first
    assignedSchedules.sort((a, b) => a.startTime.compareTo(b.startTime));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Assigned to Me',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (assignedSchedules.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${assignedSchedules.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (assignedSchedules.isNotEmpty)
              InkWell(
                onTap: () {
                  notifier.toggleFilterPill('assigned_to_me');
                },
                borderRadius: BorderRadius.circular(4),
                child: Text(
                  'View All (${assignedSchedules.length})',
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

        if (assignedSchedules.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 26,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                const SizedBox(height: 6),
                Text(
                  'No schedules assigned to you',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          )
        else
          ...assignedSchedules.take(4).map((item) {
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

    final now = DateTime.now();
    // Filter REAL schedules with reminders or type Reminder from active visible dataset that are IN THE FUTURE from current time
    final dataset = state.schedules.isNotEmpty ? state.schedules : state.rawSchedules;
    final reminderSchedules = dataset.where((s) {
      final isFutureOrCurrent = s.endTime.isAfter(now) || s.startTime.isAfter(now);
      final isReminder = s.reminders.isNotEmpty ||
          s.scheduleType.toLowerCase() == 'reminder' ||
          s.category.toLowerCase() == 'reminders';
      return isFutureOrCurrent && isReminder;
    }).toList();

    // Sort ascending by start time so the closest upcoming reminder appears first
    reminderSchedules.sort((a, b) => a.startTime.compareTo(b.startTime));

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
                'View All (${reminderSchedules.length})',
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

        if (reminderSchedules.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 26,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                const SizedBox(height: 6),
                Text(
                  'No upcoming reminders',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          )
        else
          ...reminderSchedules.take(4).map((s) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelectSchedule(s),
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
                            color: s.color.withValues(alpha: isDark ? 0.22 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.notifications_active_outlined,
                            size: 18,
                            color: isDark ? Color.lerp(s.color, Colors.white, 0.3)! : s.color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('E, hh:mm a').format(s.startTime),
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

  Color _getCategoryColor(String name, String? hex) {
    if (hex != null && hex.isNotEmpty) {
      return _parseHexColor(hex);
    }
    switch (name.toLowerCase()) {
      case 'meeting':
      case 'meetings':
        return const Color(0xFF8B5CF6);
      case 'class':
      case 'classes':
        return const Color(0xFF10B981);
      case 'exam':
      case 'exams':
        return const Color(0xFFEF4444);
      case 'event':
      case 'events':
      case 'school events':
        return const Color(0xFFF43F5E);
      case 'task':
      case 'tasks':
        return const Color(0xFFF59E0B);
      case 'reminder':
      case 'reminders':
        return const Color(0xFF3B82F6);
      case 'training':
      case 'trainings':
        return const Color(0xFF06B6D4);
      case 'holiday':
      case 'public holidays':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF4F46E5);
    }
  }
}
