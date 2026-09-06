import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/book_provider.dart';
import 'dialogs/advanced_filter_dialog.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';

class BookFilterBar extends ConsumerStatefulWidget {
  const BookFilterBar({super.key});

  @override
  ConsumerState<BookFilterBar> createState() => _BookFilterBarState();
}

class _BookFilterBarState extends ConsumerState<BookFilterBar> {
  late TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: ref.read(bookProvider).searchQuery);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookProvider);
    final notifier = ref.read(bookProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    // Sync search text field if cleared externally
    if (_searchCtrl.text != state.searchQuery && state.searchQuery.isEmpty) {
      _searchCtrl.clear();
    }

    final categories = ['All Categories', ...state.filterOptions.categories];
    final authors = ['All Authors', ...state.filterOptions.authors];
    final publishers = ['All Publishers', ...state.filterOptions.publishers];

    final hasActiveAdvancedFilters = state.selectedLanguage != null ||
        state.selectedBookType != null ||
        state.selectedRack != null ||
        state.yearMin != null ||
        state.yearMax != null;

    return Container(
      margin: EdgeInsets.fromLTRB(
        isDesktop ? 28 : 16,
        18,
        isDesktop ? 28 : 16,
        14,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1150;

          if (isWide) {
            return Row(
              children: [
                // 1. Search Bar Field (Flex)
                Expanded(
                  flex: 3,
                  child: _buildSearchField(notifier, isDark),
                ),
                const SizedBox(width: 10),

                // 2. Categories Dropdown
                _buildDropdown(
                  value: state.selectedCategory,
                  items: categories,
                  onChanged: (val) {
                    if (val != null) notifier.setCategory(val);
                  },
                  isDark: isDark,
                  width: 145,
                ),
                const SizedBox(width: 8),

                // 3. Authors Dropdown
                _buildDropdown(
                  value: state.selectedAuthor,
                  items: authors,
                  onChanged: (val) {
                    if (val != null) notifier.setAuthor(val);
                  },
                  isDark: isDark,
                  width: 135,
                ),
                const SizedBox(width: 8),

                // 4. Publishers Dropdown
                _buildDropdown(
                  value: state.selectedPublisher,
                  items: publishers,
                  onChanged: (val) {
                    if (val != null) notifier.setPublisher(val);
                  },
                  isDark: isDark,
                  width: 140,
                ),
                const SizedBox(width: 8),

                // 5. Status Dropdown
                _buildDropdown(
                  value: state.selectedStatus,
                  items: const ['ALL', 'ACTIVE', 'ARCHIVED'],
                  labels: {
                    'ALL': 'Status: All',
                    'ACTIVE': 'Status: Active',
                    'ARCHIVED': 'Status: Archived',
                  },
                  onChanged: (val) {
                    if (val != null) notifier.setStatus(val);
                  },
                  isDark: isDark,
                  width: 130,
                ),
                const SizedBox(width: 8),

                // 6. Availability Dropdown
                _buildDropdown(
                  value: state.selectedAvailability,
                  items: const [
                    'ALL',
                    'AVAILABLE',
                    'FULLY_ISSUED',
                    'PARTIALLY_AVAILABLE',
                    'RESERVED',
                    'OVERDUE',
                    'LOST',
                    'DAMAGED'
                  ],
                  labels: {
                    'ALL': 'Availability: All',
                    'AVAILABLE': 'Available Only',
                    'FULLY_ISSUED': 'Fully Issued',
                    'PARTIALLY_AVAILABLE': 'Partially Available',
                    'RESERVED': 'Reserved',
                    'OVERDUE': 'Overdue Only',
                    'LOST': 'Lost Copies',
                    'DAMAGED': 'Damaged Copies',
                  },
                  onChanged: (val) {
                    if (val != null) notifier.setAvailability(val);
                  },
                  isDark: isDark,
                  width: 150,
                ),
                const SizedBox(width: 8),

                // 7. Advanced Filters Button
                OutlinedButton.icon(
                  icon: Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: hasActiveAdvancedFilters ? const Color(0xFF6366F1) : (isDark ? Colors.white : const Color(0xFF334155)),
                  ),
                  label: Text(
                    hasActiveAdvancedFilters ? 'Filters (Active)' : 'Filters',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: hasActiveAdvancedFilters ? FontWeight.w700 : FontWeight.w500,
                      color: hasActiveAdvancedFilters ? const Color(0xFF6366F1) : (isDark ? Colors.white : const Color(0xFF334155)),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                    backgroundColor: hasActiveAdvancedFilters ? const Color(0xFF6366F1).withOpacity(0.08) : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    side: BorderSide(
                      color: hasActiveAdvancedFilters
                          ? const Color(0xFF6366F1)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const AdvancedFilterDialog(),
                    );
                  },
                ),

                const SizedBox(width: 8),

                // 8. Refresh Button (Right end of row)
                IconButton(
                  tooltip: 'Refresh Books',
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    notifier.loadStats();
                    notifier.loadFilterOptions();
                    notifier.loadBooks();
                  },
                ),
              ],
            );
          }

          // Responsive layout for narrower screens / mobile / tablet
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchField(notifier, isDark),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildDropdown(
                      value: state.selectedCategory,
                      items: categories,
                      onChanged: (val) {
                        if (val != null) notifier.setCategory(val);
                      },
                      isDark: isDark,
                      width: 145,
                    ),
                    const SizedBox(width: 8),
                    _buildDropdown(
                      value: state.selectedAuthor,
                      items: authors,
                      onChanged: (val) {
                        if (val != null) notifier.setAuthor(val);
                      },
                      isDark: isDark,
                      width: 135,
                    ),
                    const SizedBox(width: 8),
                    _buildDropdown(
                      value: state.selectedPublisher,
                      items: publishers,
                      onChanged: (val) {
                        if (val != null) notifier.setPublisher(val);
                      },
                      isDark: isDark,
                      width: 140,
                    ),
                    const SizedBox(width: 8),
                    _buildDropdown(
                      value: state.selectedStatus,
                      items: const ['ALL', 'ACTIVE', 'ARCHIVED'],
                      labels: {
                        'ALL': 'Status: All',
                        'ACTIVE': 'Status: Active',
                        'ARCHIVED': 'Status: Archived',
                      },
                      onChanged: (val) {
                        if (val != null) notifier.setStatus(val);
                      },
                      isDark: isDark,
                      width: 130,
                    ),
                    const SizedBox(width: 8),
                    _buildDropdown(
                      value: state.selectedAvailability,
                      items: const [
                        'ALL',
                        'AVAILABLE',
                        'FULLY_ISSUED',
                        'PARTIALLY_AVAILABLE',
                        'RESERVED',
                        'OVERDUE',
                        'LOST',
                        'DAMAGED'
                      ],
                      labels: {
                        'ALL': 'Availability: All',
                        'AVAILABLE': 'Available Only',
                        'FULLY_ISSUED': 'Fully Issued',
                        'PARTIALLY_AVAILABLE': 'Partially Available',
                        'RESERVED': 'Reserved',
                        'OVERDUE': 'Overdue Only',
                        'LOST': 'Lost Copies',
                        'DAMAGED': 'Damaged Copies',
                      },
                      onChanged: (val) {
                        if (val != null) notifier.setAvailability(val);
                      },
                      isDark: isDark,
                      width: 150,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Filters'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        showDialog(context: context, builder: (_) => const AdvancedFilterDialog());
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh_rounded, size: 19),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.all(10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        notifier.loadStats();
                        notifier.loadFilterOptions();
                        notifier.loadBooks();
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField(BookNotifier notifier, bool isDark) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (val) => notifier.setSearch(val),
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: 'Search by title, author, ISBN, barcode...',
          hintStyle: TextStyle(
            fontSize: 12.5,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    _searchCtrl.clear();
                    notifier.setSearch('');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    Map<String, String>? labels,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    double width = 140,
  }) {
    final validValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : null);

    return Container(
      width: width,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validValue,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          items: items.map((item) {
            final display = labels != null ? (labels[item] ?? item) : item;
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
