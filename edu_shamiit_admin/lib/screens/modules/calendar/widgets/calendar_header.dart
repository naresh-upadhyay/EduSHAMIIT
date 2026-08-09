import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import '../models/calendar_models.dart';
import '../providers/calendar_provider.dart';

class CalendarHeaderWidget extends ConsumerWidget {
  final VoidCallback onCreateSchedule;
  final Function(String type) onSelectScheduleType;

  const CalendarHeaderWidget({
    super.key,
    required this.onCreateSchedule,
    required this.onSelectScheduleType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    final notifier = ref.read(calendarProvider.notifier);
    final isDesktop = Responsive.isDesktop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isMobile = !isDesktop && MediaQuery.sizeOf(context).width < 600;
    final double ts = (MediaQuery.sizeOf(context).width / 700).clamp(0.78, 1.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 24, vertical: isMobile ? 8 : 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Title & Search Bar on Mobile / Desktop
          Row(
            children: [
              Text(
                'Calendar',
                style: TextStyle(
                fontSize: (24 * ts).roundToDouble(),
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 16),

                // Institution / Calendar Quick Dropdown if multiple
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Live Sync Active',
                        style: TextStyle(
                          fontSize: (12 * ts).roundToDouble(),
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Quick Search Input
              if (isDesktop)
                Container(
                  width: 320,
                  height: 40,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    onChanged: notifier.setSearchQuery,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search events, people, rooms, tasks...',
                      hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      suffixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Ctrl + K',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.only(top: 8),
                    ),
                  ),
                ),

              // Create Schedule Primary Button with Dropdown Menu
              _buildCreateScheduleButton(context, ref),

            ],
          ),

          SizedBox(height: isMobile ? 8 : 14),

          // Row 2: Date Navigation Controls & View Modes
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Navigation buttons: Today < > Date Range
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: isMobile ? 30 : 38,
                      child: OutlinedButton(
                        onPressed: notifier.goToToday,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16),
                          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        ),
                        child: Text(
                          'Today',
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 4 : 8),

                    SizedBox(
                      width: isMobile ? 30 : 38,
                      height: isMobile ? 30 : 38,
                      child: IconButton(
                        onPressed: notifier.previousPeriod,
                        icon: Icon(Icons.chevron_left_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.transparent),
                          ),
                        ),
                        tooltip: 'Previous period',
                      ),
                    ),
                    SizedBox(width: isMobile ? 2 : 4),

                    SizedBox(
                      width: isMobile ? 30 : 38,
                      height: isMobile ? 30 : 38,
                      child: IconButton(
                        onPressed: notifier.nextPeriod,
                        icon: Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.transparent),
                          ),
                        ),
                        tooltip: 'Next period',
                      ),
                    ),
                    const SizedBox(width: 14),

                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: state.selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          notifier.selectDate(picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: isMobile ? 30 : 38,
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.formattedDateRange,
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(width: isMobile ? 8 : 24),

                // Right Group: View Switcher (Day, Week, Month, Agenda, Timeline) & Filters
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // View Switcher Segment
                    Container(
                      height: isMobile ? 30 : 38,
                      padding: EdgeInsets.all(isMobile ? 2 : 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.transparent),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildViewTab(context, ref, CalendarViewMode.day, 'Day', isMobile),
                          _buildViewTab(context, ref, CalendarViewMode.week, 'Week', isMobile),
                          _buildViewTab(context, ref, CalendarViewMode.month, 'Month', isMobile),
                          if (!isMobile) ...[
                            _buildViewTab(context, ref, CalendarViewMode.agenda, 'Agenda', isMobile),
                            _buildViewTab(context, ref, CalendarViewMode.timeline, 'Timeline', isMobile),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Filters Button
                    SizedBox(
                      height: isMobile ? 30 : 38,
                      child: isMobile
                          ? IconButton(
                              onPressed: () => _showFilterDialog(context, ref),
                              icon: Icon(
                                Icons.filter_list_rounded,
                                size: 18,
                                color: state.selectedCategory != 'All' || state.selectedPriority != 'All'
                                    ? const Color(0xFF818CF8)
                                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                              ),
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: state.selectedCategory != 'All' || state.selectedPriority != 'All'
                                        ? const Color(0xFF4F46E5)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                ),
                              ),
                              tooltip: 'Filters',
                            )
                          : OutlinedButton.icon(
                              onPressed: () => _showFilterDialog(context, ref),
                              icon: Icon(Icons.filter_list_rounded, size: 16, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                              label: Text(
                                state.selectedCategory != 'All' || state.selectedPriority != 'All' || state.selectedStatus != 'All'
                                    ? 'Filters (Active)'
                                    : 'Filters',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: state.selectedCategory != 'All' || state.selectedPriority != 'All'
                                      ? const Color(0xFF818CF8)
                                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                side: BorderSide(
                                  color: state.selectedCategory != 'All' || state.selectedPriority != 'All'
                                      ? const Color(0xFF4F46E5)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewTab(BuildContext context, WidgetRef ref, CalendarViewMode mode, String label, bool isMobile) {
    final state = ref.watch(calendarProvider);
    final isSelected = state.viewMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => ref.read(calendarProvider.notifier).setViewMode(mode),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 14, vertical: isMobile ? 4 : 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 11 : 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateScheduleButton(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);

    return PopupMenuButton<String>(
      onSelected: (type) {
        if (type == 'custom' || type == 'general') {
          onCreateSchedule();
        } else {
          onSelectScheduleType(type);
        }
      },
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> items = [];

        if (state.scheduleCategories.isNotEmpty) {
          for (final cat in state.scheduleCategories) {
            final name = cat['name']?.toString() ?? '';
            final label = cat['label']?.toString() ?? name;
            final hex = cat['color']?.toString() ?? '#4F46E5';
            items.add(_buildPopupItem(name, label, Icons.event_note_rounded, _parseHexColor(hex)));
          }
        }

        items.add(const PopupMenuDivider());
        items.add(
          const PopupMenuItem<String>(
            value: 'custom',
            child: Row(
              children: [
                Icon(Icons.add_rounded, size: 18, color: Color(0xFF4F46E5)),
                SizedBox(width: 10),
                Text(
                  'Custom Schedule',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                ),
              ],
            ),
          ),
        );

        return items;
      },

      child: Builder(
        builder: (context) {
          final isMobileBtn = MediaQuery.sizeOf(context).width < 600;
          return Container(
            height: 38,
            padding: EdgeInsets.symmetric(horizontal: isMobileBtn ? 10 : 16),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                if (!isMobileBtn) ...[
                  const SizedBox(width: 6),
                  const Text(
                    'Create Schedule',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, String title, IconData icon, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref) {
    final state = ref.read(calendarProvider);
    final notifier = ref.read(calendarProvider.notifier);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.filter_list_rounded, color: Color(0xFF4F46E5)),
              SizedBox(width: 8),
              Text('Calendar Filters', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          content: Consumer(
            builder: (context, ref, _) {
              return SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Schedule Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: state.selectedCategory,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Categories')),
                        ...state.scheduleCategories.map((cat) {
                          final name = cat['name']?.toString() ?? '';
                          final label = cat['label']?.toString() ?? name;
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(label),
                          );
                        }),
                      ],

                      onChanged: (val) {
                        if (val != null) {
                          notifier.setCategoryFilter(val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text('Priority Level', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: state.selectedPriority,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Priorities')),
                        DropdownMenuItem(value: 'high', child: Text('High Priority Only')),
                        DropdownMenuItem(value: 'normal', child: Text('Normal Priority')),
                        DropdownMenuItem(value: 'low', child: Text('Low Priority')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          notifier.setPriorityFilter(val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text('Schedule Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: state.selectedStatus,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'confirmed', child: Text('Confirmed & Approved')),
                        DropdownMenuItem(value: 'pending', child: Text('Pending Approval')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          notifier.setStatusFilter(val);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                notifier.setCategoryFilter('All');
                notifier.setPriorityFilter('All');
                notifier.setStatusFilter('All');
                Navigator.pop(ctx);
              },
              child: const Text('Reset Filters', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
              child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
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
