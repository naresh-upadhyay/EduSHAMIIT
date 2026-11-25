import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class CampusPaginationBar extends StatelessWidget {
  final int currentPage;
  final int pageSize;
  final int totalCount;
  final String itemLabel;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final List<int> pageSizes;

  const CampusPaginationBar({
    super.key,
    required this.currentPage,
    required this.pageSize,
    int? totalCount,
    int? totalItems,
    this.itemLabel = 'records',
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.pageSizes = const [10, 25, 50, 100],
  }) : totalCount = totalCount ?? totalItems ?? 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final totalPages = math.max(1, (totalCount / pageSize).ceil());
    final effectivePage = math.min(currentPage, totalPages);
    final startRecord = totalCount == 0 ? 0 : ((effectivePage - 1) * pageSize) + 1;
    final endRecord = math.min(effectivePage * pageSize, totalCount);

    final textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    // Calculate smart page window (e.g. 1, 2, 3, 4, 5)
    List<int> visiblePages = [];
    if (totalPages <= 5) {
      visiblePages = List.generate(totalPages, (i) => i + 1);
    } else {
      int start = math.max(1, effectivePage - 2);
      int end = math.min(totalPages, start + 4);
      if (end - start < 4) {
        start = math.max(1, end - 4);
      }
      visiblePages = List.generate(end - start + 1, (i) => start + i);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;

          final recordInfo = Text(
            'Showing $startRecord - $endRecord of $totalCount $itemLabel',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          );

          final rowsPerPageSelector = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rows per page:',
                style: TextStyle(fontSize: 12, color: textColor),
              ),
              const SizedBox(width: 8),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                ),
                child: DropdownButtonHideUnderline(
                  child: AppSearchableDropdown<int>.fromMenuItems(
                    value: pageSizes.contains(pageSize) ? pageSize : pageSizes.first,
                    isDense: true,
                    icon: Icon(Icons.arrow_drop_down, size: 18, color: textColor),
                    items: pageSizes.map((s) {
                      return DropdownMenuItem<int>(
                        value: s,
                        child: Text('$s', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) onPageSizeChanged(val);
                    },
                  ),
                ),
              ),
            ],
          );

          final navigationButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // First Page Button
              _IconButton(
                icon: Icons.keyboard_double_arrow_left_rounded,
                tooltip: 'First Page',
                isEnabled: effectivePage > 1,
                onPressed: () => onPageChanged(1),
                borderColor: borderColor,
                isDark: isDark,
              ),
              const SizedBox(width: 4),

              // Previous Page Button
              _IconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous Page',
                isEnabled: effectivePage > 1,
                onPressed: () => onPageChanged(effectivePage - 1),
                borderColor: borderColor,
                isDark: isDark,
              ),
              const SizedBox(width: 6),

              // Page Number Chips
              ...visiblePages.map((p) {
                final isSelected = p == effectivePage;
                return InkWell(
                  onTap: isSelected ? null : () => onPageChanged(p),
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isSelected ? primaryColor : borderColor,
                      ),
                    ),
                    child: Text(
                      '$p',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 6),

              // Next Page Button
              _IconButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next Page',
                isEnabled: effectivePage < totalPages,
                onPressed: () => onPageChanged(effectivePage + 1),
                borderColor: borderColor,
                isDark: isDark,
              ),
              const SizedBox(width: 4),

              // Last Page Button
              _IconButton(
                icon: Icons.keyboard_double_arrow_right_rounded,
                tooltip: 'Last Page',
                isEnabled: effectivePage < totalPages,
                onPressed: () => onPageChanged(totalPages),
                borderColor: borderColor,
                isDark: isDark,
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    recordInfo,
                    rowsPerPageSelector,
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Center(child: navigationButtons),
                ),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              recordInfo,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  rowsPerPageSelector,
                  const SizedBox(width: 16),
                  navigationButtons,
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isEnabled;
  final VoidCallback onPressed;
  final Color borderColor;
  final bool isDark;

  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.isEnabled,
    required this.onPressed,
    required this.borderColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isEnabled
                ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))
                : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.3) : const Color(0xFFF1F5F9).withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: borderColor.withValues(alpha: isEnabled ? 1.0 : 0.4)),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isEnabled
                ? (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155))
                : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
          ),
        ),
      ),
    );
  }
}
