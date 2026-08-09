import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/calendar_provider.dart';

class CalendarFilterBarWidget extends ConsumerWidget {
  final VoidCallback onAddCalendar;

  const CalendarFilterBarWidget({
    super.key,
    required this.onAddCalendar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    final notifier = ref.read(calendarProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dynamically generated filter chips from database calendars
    final List<_FilterPillData> filterPills = [];

    if (state.calendars.isNotEmpty) {
      for (final cal in state.calendars) {
        filterPills.add(_FilterPillData(
          id: cal.id,
          label: cal.name,
          color: cal.color,
        ));
      }
    } else {
      filterPills.addAll([
        _FilterPillData(id: 'my_schedule', label: 'My Schedule', color: const Color(0xFF4F46E5)),
        _FilterPillData(id: 'assigned_to_me', label: 'Assigned to Me', color: const Color(0xFF10B981)),
        _FilterPillData(id: 'team_schedule', label: 'Team Schedule', color: const Color(0xFF06B6D4)),
        _FilterPillData(id: 'department', label: 'Department', color: const Color(0xFFF59E0B)),
        _FilterPillData(id: 'public_holidays', label: 'Public Holidays', color: const Color(0xFFEF4444)),
      ]);
    }

    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFAFAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 500;
          return Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
            // Left-most Select All / Deselect All Toggle Checkbox Chip
            Builder(
              builder: (context) {
                final bool allSelected = state.calendars.isNotEmpty
                    ? state.calendars.every((c) => state.activeFilterPills.contains(c.id))
                    : state.activeFilterPills.isNotEmpty;

                return Padding(
                  padding: EdgeInsets.only(right: isMobile ? 8 : 18),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        notifier.selectAllCalendars(!allSelected);
                      },
                      borderRadius: BorderRadius.circular(6),
                      hoverColor: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: isMobile ? 4 : 6),
                        decoration: BoxDecoration(
                          color: allSelected
                              ? const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.25 : 0.12)
                              : (isDark ? const Color(0xFF0F172A) : Colors.transparent),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: allSelected
                                ? const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.7 : 0.4)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: isMobile ? 12 : 16,
                              height: isMobile ? 12 : 16,
                              decoration: BoxDecoration(
                                color: allSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF4F46E5), width: 1.5),
                              ),
                              child: allSelected
                                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                                  : null,
                            ),
                            SizedBox(width: isMobile ? 4 : 8),
                            Text(
                              allSelected ? 'Deselect All' : 'Select All',
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 13,
                                fontWeight: FontWeight.w800,
                                color: allSelected
                                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            ...filterPills.map((pill) {
              final isChecked = state.activeFilterPills.contains(pill.id);

              return Padding(
                padding: EdgeInsets.only(right: isMobile ? 8 : 18),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      notifier.toggleFilterPill(pill.id);
                    },
                    borderRadius: BorderRadius.circular(6),
                    hoverColor: pill.color.withValues(alpha: 0.12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: isMobile ? 4 : 6),
                      decoration: BoxDecoration(
                        color: isChecked
                            ? pill.color.withValues(alpha: isDark ? 0.28 : 0.12)
                            : (isDark ? const Color(0xFF0F172A) : Colors.transparent),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isChecked
                              ? pill.color.withValues(alpha: isDark ? 0.75 : 0.4)
                              : (isDark ? const Color(0xFF334155) : Colors.transparent),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: isMobile ? 12 : 16,
                            height: isMobile ? 12 : 16,
                            decoration: BoxDecoration(
                              color: isChecked ? pill.color : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: pill.color, width: 1.5),
                            ),
                            child: isChecked
                                ? const Icon(Icons.check, size: 12, color: Colors.white)
                                : null,
                          ),
                          SizedBox(width: isMobile ? 4 : 8),
                          Text(
                            pill.label,
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 13,
                              fontWeight: FontWeight.w700,
                              color: isChecked
                                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            InkWell(
              onTap: onAddCalendar,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 4 : 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.5 : 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: isMobile ? 14 : 16, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                    if (!isMobile) ...[
                      const SizedBox(width: 4),
                      Text(
                        'Add Calendar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
),
);
}
}

class _FilterPillData {
  final String id;
  final String label;
  final Color color;

  _FilterPillData({required this.id, required this.label, required this.color});
}
