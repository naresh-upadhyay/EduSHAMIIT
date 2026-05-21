import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/constants/parent_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/parent_provider.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class ParentEvents extends ConsumerWidget {
  const ParentEvents({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final eventsAsync = ref.watch(parentEventsProvider);

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
                    'Events'.tr(ref),
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

          // ── Body ──
          Expanded(
            child: eventsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(ref, e.toString()),
              data: (data) => _buildContent(context, ref, data, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref,
      Map<String, dynamic> data, bool isDark) {
    final events = data['events'] as List<dynamic>? ?? [];

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'No upcoming events'.tr(ref),
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? ParentColors.darkText2 : ParentColors.text2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'School events will appear here'.tr(ref),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? ParentColors.darkText3 : ParentColors.text3,
              ),
            ),
          ],
        ),
      );
    }

    return ResponsiveContent(
      child: ListView(
        padding:
            Responsive.contentPadding(context).copyWith(top: 16, bottom: 16),
        children: [
          Text(
            'Upcoming Events'.tr(ref),
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? ParentColors.darkText : ParentColors.text,
            ),
          ),
          const SizedBox(height: 12),
          ...events.map((e) {
            final event = e as Map<String, dynamic>;
            return _buildEventCard(event, isDark);
          }),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, bool isDark) {
    final title = event['title'] ?? 'Event';
    final description = event['description'] ?? '';
    final startDate = event['start_date'] ?? '';
    final endDate = event['end_date'] ?? '';
    final location = event['location'] ?? '';
    final category = event['category'] ?? 'general';

    final categoryColor = category == 'academic'
        ? Colors.blue
        : category == 'sports'
            ? Colors.green
            : category == 'cultural'
                ? Colors.purple
                : category == 'holiday'
                    ? Colors.orange
                    : ParentColors.primary;

    final categoryIcon = category == 'academic'
        ? '📖'
        : category == 'sports'
            ? '⚽'
            : category == 'cultural'
                ? '🎭'
                : category == 'holiday'
                    ? '🏖️'
                    : '🎉';

    // Parse date for display
    DateTime? startDt;
    DateTime? endDt;
    try {
      if (startDate.isNotEmpty) startDt = DateTime.parse(startDate);
      if (endDate.isNotEmpty) endDt = DateTime.parse(endDate);
    } catch (_) {}

    final dayStr = startDt != null ? '${startDt.day}' : '?';
    final monthStr = startDt != null ? _monthAbbrev(startDt.month) : '';
    final timeStr = startDt != null
        ? '${_formatHour(startDt.hour)}:${startDt.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? ParentColors.darkBorder : ParentColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date badge
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                Text(
                  monthStr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: categoryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dayStr,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: categoryColor,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category + Title
                  Row(
                    children: [
                      Text(categoryIcon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
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

                  // Description
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? ParentColors.darkText2
                            : ParentColors.text2,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Details row
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (timeStr.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time,
                                size: 14,
                                color: isDark
                                    ? ParentColors.darkText3
                                    : ParentColors.text3),
                            const SizedBox(width: 4),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? ParentColors.darkText3
                                    : ParentColors.text3,
                              ),
                            ),
                          ],
                        ),
                      if (location.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 14,
                                color: isDark
                                    ? ParentColors.darkText3
                                    : ParentColors.text3),
                            const SizedBox(width: 4),
                            Text(
                              location,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? ParentColors.darkText3
                                    : ParentColors.text3,
                              ),
                            ),
                          ],
                        ),
                      if (endDt != null && startDt != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_outlined,
                                size: 14,
                                color: isDark
                                    ? ParentColors.darkText3
                                    : ParentColors.text3),
                            const SizedBox(width: 4),
                            Text(
                              _getDateRange(startDt, endDt),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? ParentColors.darkText3
                                    : ParentColors.text3,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthAbbrev(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month];
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12';
    if (hour > 12) return '${hour - 12}';
    return '$hour';
  }

  String _getDateRange(DateTime start, DateTime end) {
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return '${start.day}/${start.month}/${start.year}';
    }
    return '${start.day}/${start.month} - ${end.day}/${end.month}/${end.year}';
  }

  Widget _buildError(WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: ParentColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load events'.tr(ref),
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
            onPressed: () => ref.invalidate(parentEventsProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Retry'.tr(ref)),
          ),
        ],
      ),
    );
  }
}
