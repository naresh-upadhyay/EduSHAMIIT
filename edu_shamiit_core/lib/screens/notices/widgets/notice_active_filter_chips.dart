import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/notice_provider.dart';

class NoticeActiveFilterChips extends ConsumerWidget {
  const NoticeActiveFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(noticeProvider);
    final notifier = ref.read(noticeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!state.hasActiveFilters) return const SizedBox.shrink();

    final chips = <Widget>[];

    if (state.searchQuery.isNotEmpty) {
      chips.add(_buildChip(
        label: 'Search: "${state.searchQuery}"',
        onDeleted: () => notifier.onSearchChanged(''),
        isDark: isDark,
      ));
    }

    if (state.selectedAudience != 'All') {
      chips.add(_buildChip(
        label: 'Audience: ${state.selectedAudience}',
        onDeleted: () => notifier.clearAudienceFilter(),
        isDark: isDark,
      ));
    }

    if (state.selectedCategory != 'All') {
      chips.add(_buildChip(
        label: 'Category: ${state.selectedCategory}',
        onDeleted: () => notifier.clearCategoryFilter(),
        isDark: isDark,
      ));
    }

    if (state.selectedPriority != 'All') {
      chips.add(_buildChip(
        label: 'Priority: ${state.selectedPriority}',
        onDeleted: () => notifier.clearPriorityFilter(),
        isDark: isDark,
      ));
    }

    if (state.selectedStatus != 'All') {
      chips.add(_buildChip(
        label: 'Status: ${state.selectedStatus}',
        onDeleted: () => notifier.clearStatusFilter(),
        isDark: isDark,
      ));
    }

    if (state.fromDate != null || state.toDate != null) {
      final df = DateFormat('dd MMM yyyy');
      final dateStr = '${state.fromDate != null ? df.format(state.fromDate!.toLocal()) : 'Any'} - ${state.toDate != null ? df.format(state.toDate!.toLocal()) : 'Any'}';
      chips.add(_buildChip(
        label: 'Date: $dateStr',
        onDeleted: () => notifier.clearDateRange(),
        isDark: isDark,
      ));
    }

    if (state.requiresAck != null) {
      chips.add(_buildChip(
        label: state.requiresAck == true ? 'Requires Acknowledgement' : 'No Acknowledgement',
        onDeleted: () => notifier.clearRequiresAckFilter(),
        isDark: isDark,
      ));
    }

    if (state.hasAttachment != null) {
      chips.add(_buildChip(
        label: state.hasAttachment == true ? 'Has Attachments' : 'No Attachments',
        onDeleted: () => notifier.clearHasAttachmentFilter(),
        isDark: isDark,
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Active filters:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          ...chips,
          TextButton(
            onPressed: () => notifier.resetFilters(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: const Size(40, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Clear All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required VoidCallback onDeleted,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 2, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDeleted,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4F46E5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
