import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notice_provider.dart';

class NoticePaginationBar extends ConsumerWidget {
  const NoticePaginationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(noticeProvider);
    final notifier = ref.read(noticeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.totalRecords == 0) return const SizedBox.shrink();

    final start = ((state.currentPage - 1) * state.pageSize) + 1;
    final end = (start + state.pageSize - 1).clamp(1, state.totalRecords);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          // Left: Showing X-Y of Z notices
          Text(
            'Showing $start-$end of ${state.totalRecords} notices',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),

          // Middle: Items per page dropdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Items per page:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: state.pageSize,
                    onChanged: (val) {
                      if (val != null) notifier.setPageSize(val);
                    },
                    isDense: true,
                    borderRadius: BorderRadius.circular(6),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    items: const [10, 25, 50, 100].map((s) {
                      return DropdownMenuItem<int>(
                        value: s,
                        child: Text('$s'),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          // Right: Page navigation buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Prev Button
              IconButton(
                onPressed: state.currentPage > 1 ? () => notifier.setPage(state.currentPage - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.all(6),
                ),
              ),
              const SizedBox(width: 6),

              // Page Numbers
              ..._buildPageButtons(state.currentPage, state.totalPages, isDark, notifier),

              const SizedBox(width: 6),
              // Next Button
              IconButton(
                onPressed: state.currentPage < state.totalPages ? () => notifier.setPage(state.currentPage + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  padding: const EdgeInsets.all(6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageButtons(int current, int total, bool isDark, NoticeNotifier notifier) {
    final widgets = <Widget>[];
    if (total <= 1) {
      widgets.add(_buildPageButton(1, true, isDark, () {}));
      return widgets;
    }

    final pages = <int>[];
    if (total <= 7) {
      for (int i = 1; i <= total; i++) {
        pages.add(i);
      }
    } else {
      pages.add(1);
      if (current > 3) pages.add(-1); // ellipsis
      final start = (current - 1).clamp(2, total - 1);
      final end = (current + 1).clamp(2, total - 1);
      for (int i = start; i <= end; i++) {
        if (!pages.contains(i)) pages.add(i);
      }
      if (current < total - 2) pages.add(-2); // ellipsis
      if (!pages.contains(total)) pages.add(total);
    }

    for (final p in pages) {
      if (p < 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text('...', style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
          ),
        );
      } else {
        widgets.add(_buildPageButton(p, p == current, isDark, () => notifier.setPage(p)));
      }
    }

    return widgets;
  }

  Widget _buildPageButton(int page, bool isSelected, bool isDark, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
            ),
          ),
        ),
      ),
    );
  }
}
