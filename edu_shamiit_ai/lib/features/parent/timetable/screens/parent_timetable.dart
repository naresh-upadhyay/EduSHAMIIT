import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/constants/parent_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/parent_provider.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class ParentTimetable extends ConsumerWidget {
  const ParentTimetable({super.key});

  static const _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedDay = ref.watch(_selectedDayProvider);
    final timetableAsync = ref.watch(parentTimetableProvider(selectedDay));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [ParentColors.primaryDeep, ParentColors.primary],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Timetable'.tr(ref),
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Day Selector ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? ParentColors.darkSurface : ParentColors.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _days.map((day) {
                  final isSelected = day == selectedDay;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        day[0].toUpperCase() + day.substring(1, 3),
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? ParentColors.darkText2
                                  : ParentColors.text2),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: ParentColors.primary,
                      backgroundColor: isDark
                          ? ParentColors.darkBorder
                          : ParentColors.border,
                      onSelected: (_) {
                        ref.read(_selectedDayProvider.notifier).state = day;
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Body ──
          Expanded(
            child: timetableAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(ref, e.toString()),
              data: (data) =>
                  _buildContent(context, ref, data, isDark, selectedDay),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref,
      Map<String, dynamic> data, bool isDark, String selectedDay) {
    final schedule = data['schedule'] as List<dynamic>? ?? [];
    final className = data['class'] ?? '';

    if (schedule.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📅', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'No classes on ${selectedDay[0].toUpperCase()}${selectedDay.substring(1)}'
                  .tr(ref),
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? ParentColors.darkText2 : ParentColors.text2,
              ),
            ),
            if (className.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Class: $className'.tr(ref),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? ParentColors.darkText3 : ParentColors.text3,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ResponsiveContent(
      child: ListView(
        padding:
            Responsive.contentPadding(context).copyWith(top: 16, bottom: 16),
        children: [
          if (className.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Class: $className',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? ParentColors.darkText2 : ParentColors.text2,
                ),
              ),
            ),
          ...schedule.map((item) {
            final period = item as Map<String, dynamic>;
            return _buildPeriodCard(period, isDark);
          }),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(Map<String, dynamic> period, bool isDark) {
    final subject = period['subjects'] as Map<String, dynamic>? ?? {};
    final teacher = period['profiles'] as Map<String, dynamic>? ?? {};
    final subjectName = subject['name'] ?? 'Unknown';
    final subjectIcon = subject['icon'] ?? '📚';
    final subjectColor = subject['color'] ?? '#0D9488';
    final teacherName = teacher['full_name'] ?? '';
    final startTime = period['start_time'] ?? '';
    final endTime = period['end_time'] ?? '';
    final room = period['room'] ?? '';

    // Parse color from hex string
    Color cardColor;
    try {
      final hex = subjectColor.replaceAll('#', '');
      cardColor = Color(int.parse('FF$hex', radix: 32));
    } catch (_) {
      cardColor = ParentColors.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? ParentColors.darkBorder : ParentColors.border,
        ),
      ),
      child: Row(
        children: [
          // Time column
          Column(
            children: [
              Text(
                _formatTime(startTime),
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? ParentColors.darkText : ParentColors.text,
                ),
              ),
              Text(
                _formatTime(endTime),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? ParentColors.darkText3 : ParentColors.text3,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Divider line
          Container(
            width: 3,
            height: 44,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),

          // Subject info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(subjectIcon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subjectName,
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? ParentColors.darkText
                              : ParentColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                if (teacherName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14,
                            color: isDark
                                ? ParentColors.darkText3
                                : ParentColors.text3),
                        const SizedBox(width: 4),
                        Text(
                          teacherName,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? ParentColors.darkText3
                                : ParentColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (room.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.room_outlined,
                            size: 14,
                            color: isDark
                                ? ParentColors.darkText3
                                : ParentColors.text3),
                        const SizedBox(width: 4),
                        Text(
                          room,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? ParentColors.darkText3
                                : ParentColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String time) {
    if (time.isEmpty) return '';
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    } catch (_) {
      return time;
    }
  }

  Widget _buildError(WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: ParentColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load timetable'.tr(ref),
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(error,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(
                parentTimetableProvider(ref.read(_selectedDayProvider))),
            icon: const Icon(Icons.refresh),
            label: Text('Retry'.tr(ref)),
          ),
        ],
      ),
    );
  }
}

/// Provider for the currently selected day.
final _selectedDayProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  final weekday = now.weekday; // 1=Monday ... 6=Saturday, 7=Sunday
  if (weekday >= 1 && weekday <= 6) {
    return ParentTimetable._days[weekday - 1];
  }
  return 'monday';
});
