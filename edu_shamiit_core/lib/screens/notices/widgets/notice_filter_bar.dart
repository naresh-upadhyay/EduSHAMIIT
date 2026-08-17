import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notice_provider.dart';

class NoticeFilterBar extends ConsumerStatefulWidget {
  final VoidCallback? onOpenAdvancedFilters;

  const NoticeFilterBar({
    super.key,
    this.onOpenAdvancedFilters,
  });

  @override
  ConsumerState<NoticeFilterBar> createState() => _NoticeFilterBarState();
}

class _NoticeFilterBarState extends ConsumerState<NoticeFilterBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: ref.read(noticeProvider).searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noticeProvider);
    final notifier = ref.read(noticeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dynamic categories list from state
    final categoriesList = ['All', ...state.categories.map((c) => c.name)];
    if (!categoriesList.contains('General')) categoriesList.add('General');
    if (!categoriesList.contains('Academic')) categoriesList.add('Academic');
    if (!categoriesList.contains('Event')) categoriesList.add('Event');
    if (!categoriesList.contains('Meeting')) categoriesList.add('Meeting');
    if (!categoriesList.contains('Holiday')) categoriesList.add('Holiday');
    if (!categoriesList.contains('Emergency')) categoriesList.add('Emergency');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Search Field + Right-side Controls (Filters, Reset, View Toggle, Refresh)
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Search Box
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: isCompact ? constraints.maxWidth : 280,
                      maxWidth: isCompact ? constraints.maxWidth : 400,
                    ),
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        onChanged: notifier.onSearchChanged,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search title, content, author...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    notifier.onSearchChanged('');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Controls: Filters Drawer + Reset + Toggle View + Refresh
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Filters Drawer Trigger Button
                      OutlinedButton.icon(
                        onPressed: widget.onOpenAdvancedFilters,
                        icon: const Icon(Icons.filter_list_rounded, size: 16),
                        label: const Text('Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: state.hasActiveFilters
                              ? const Color(0xFF4F46E5)
                              : (isDark ? Colors.white : const Color(0xFF334155)),
                          backgroundColor: state.hasActiveFilters
                              ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
                              : Colors.transparent,
                          side: BorderSide(
                            color: state.hasActiveFilters
                                ? const Color(0xFF4F46E5)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Reset Button
                      if (state.hasActiveFilters)
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            notifier.resetFilters();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          child: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      const SizedBox(width: 4),

                      // View Toggle (Table vs Card Mode)
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.format_list_bulleted_rounded,
                                size: 16,
                                color: state.isTableView
                                    ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                                    : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              ),
                              tooltip: 'Table View',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                if (!state.isTableView) notifier.toggleViewMode();
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.grid_view_rounded,
                                size: 16,
                                color: !state.isTableView
                                    ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                                    : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              ),
                              tooltip: 'Card View',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                if (state.isTableView) notifier.toggleViewMode();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Refresh Button
                      IconButton(
                        onPressed: () => notifier.refreshAll(),
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        tooltip: 'Refresh',
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          Builder(
            builder: (context) {
              final audienceList = <String>[
                'All',
                'Entire School',
                'All Teachers',
                'All Students',
                'Parents',
                'Transport Users',
                ...state.roles.map((r) => r.toUpperCase()),
                ...state.classes,
              ].toSet().toList();

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Audience Dropdown
                    _buildDropdown(
                      label: 'Audience',
                      value: audienceList.contains(state.selectedAudience) ? state.selectedAudience : 'All',
                      items: audienceList,
                      onChanged: (val) {
                        if (val != null) notifier.setAudienceFilter(val);
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),

                // Category Dropdown
                _buildDropdown(
                  label: 'Category',
                  value: categoriesList.contains(state.selectedCategory) ? state.selectedCategory : 'All',
                  items: categoriesList.toSet().toList(),
                  onChanged: (val) {
                    if (val != null) notifier.setCategoryFilter(val);
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 8),

                // Priority Dropdown
                _buildDropdown(
                  label: 'Priority',
                  value: state.selectedPriority,
                  items: const ['All', 'Urgent', 'High', 'Normal', 'Low'],
                  onChanged: (val) {
                    if (val != null) notifier.setPriorityFilter(val);
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 8),

                // Status Dropdown
                _buildDropdown(
                  label: 'Status',
                  value: state.selectedStatus,
                  items: const ['All', 'Published', 'Scheduled', 'Draft', 'Expired', 'Archived', 'Pending Approval'],
                  onChanged: (val) {
                    if (val != null) notifier.setStatusFilter(val);
                  },
                  isDark: isDark,
                ),
              ],
            ),
          );
        },
      ),
    ],
  ),
);
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          onChanged: onChanged,
          isDense: true,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text('$label: $item'),
            );
          }).toList(),
        ),
      ),
    );
  }
}
