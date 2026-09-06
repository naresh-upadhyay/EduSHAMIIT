import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/book_provider.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';

class BookKpiCards extends ConsumerWidget {
  const BookKpiCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookProvider);
    final notifier = ref.read(bookProvider.notifier);
    final stats = state.stats;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);
    final formatter = NumberFormat('#,###');

    final cards = [
      _KpiCardItem(
        label: 'Total Books',
        value: formatter.format(stats.totalTitles),
        subtitle: 'All library books',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF6366F1), // Royal Indigo / Purple
        filterType: 'ALL',
        isSelected: state.selectedAvailability == 'ALL',
      ),
      _KpiCardItem(
        label: 'Available Books',
        value: formatter.format(stats.availableBooks),
        subtitle: 'Currently available',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF10B981), // Emerald
        filterType: 'AVAILABLE',
        isSelected: state.selectedAvailability == 'AVAILABLE',
      ),
      _KpiCardItem(
        label: 'Issued Books',
        value: formatter.format(stats.issuedBooks),
        subtitle: 'Currently issued',
        icon: Icons.auto_stories_rounded,
        color: const Color(0xFF3B82F6), // Sky Blue
        filterType: 'ISSUED',
        isSelected: state.selectedAvailability == 'FULLY_ISSUED',
      ),
      _KpiCardItem(
        label: 'Overdue Books',
        value: formatter.format(stats.overdueBooks),
        subtitle: 'Not returned on time',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFEF4444), // Coral Red
        filterType: 'OVERDUE',
        isSelected: state.selectedAvailability == 'OVERDUE',
      ),
      _KpiCardItem(
        label: 'Total Copies',
        value: formatter.format(stats.totalCopies),
        subtitle: 'All book copies',
        icon: Icons.folder_open_rounded,
        color: const Color(0xFFF59E0B), // Amber / Gold
        filterType: 'LOW',
        isSelected: false,
      ),
    ];


    return Container(
      margin: EdgeInsets.fromLTRB(
        isDesktop ? 28 : 16,
        20,
        isDesktop ? 28 : 16,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // If wide enough (e.g. desktop >= 960px), display 5 cards in single row
          if (width >= 960) {
            return Row(
              children: cards.map((item) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _buildCard(context, item, notifier, isDark),
                  ),
                );
              }).toList(),
            );
          }

          // Otherwise horizontal scroll to prevent overflow on smaller screens
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: cards.map((item) {
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildCard(context, item, notifier, isDark),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    _KpiCardItem item,
    BookNotifier notifier,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => notifier.filterByKpi(item.filterType),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isSelected
                ? item.color.withOpacity(0.8)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            width: item.isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: item.isSelected
                  ? item.color.withOpacity(0.08)
                  : Colors.black.withOpacity(isDark ? 0.2 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Icon in soft rounded container
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: item.color.withOpacity(isDark ? 0.16 : 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: item.color.withOpacity(0.2)),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(width: 12),
            // Right: Metric info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCardItem {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String filterType;
  final bool isSelected;

  const _KpiCardItem({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.filterType,
    required this.isSelected,
  });
}
