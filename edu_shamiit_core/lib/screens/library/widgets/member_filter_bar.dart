import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/member_provider.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';

class MemberFilterBar extends ConsumerStatefulWidget {
  const MemberFilterBar({super.key});

  @override
  ConsumerState<MemberFilterBar> createState() => _MemberFilterBarState();
}

class _MemberFilterBarState extends ConsumerState<MemberFilterBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(memberProvider).searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberProvider);
    final notifier = ref.read(memberProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    // Dynamic filter options
    final memberTypes = ['All Member Types', ...state.filterOptions.memberTypes];
    final classes = ['All Classes', ...state.filterOptions.classes];
    final statuses = [
      'Status: All',
      'ACTIVE',
      'INACTIVE',
      'SUSPENDED',
      'EXPIRED',
      'EXPIRING_SOON',
    ];
    final membershipFilters = [
      'Membership: All',
      'HAS_ACTIVE_BOOKS',
      'HAS_OVERDUE',
      'HAS_FINES',
    ];

    final statusLabels = {
      'Status: All': 'Status: All',
      'ACTIVE': 'Status: Active',
      'INACTIVE': 'Status: Inactive',
      'SUSPENDED': 'Status: Suspended',
      'EXPIRED': 'Status: Expired',
      'EXPIRING_SOON': 'Status: Expiring Soon',
    };

    final membershipLabels = {
      'Membership: All': 'Membership: All',
      'HAS_ACTIVE_BOOKS': 'Has Active Books',
      'HAS_OVERDUE': 'Has Overdue Books',
      'HAS_FINES': 'Has Unpaid Fines',
    };

    return Container(
      margin: EdgeInsets.fromLTRB(
        isDesktop ? 28 : 16,
        18,
        isDesktop ? 28 : 16,
        14,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1100;

          if (isWide) {
            return Row(
              children: [
                // 1. Search Bar Field (Flex)
                Expanded(
                  flex: 3,
                  child: _buildSearchField(notifier, isDark),
                ),
                const SizedBox(width: 10),

                // 2. Member Types Dropdown
                _buildDropdown(
                  value: state.selectedMemberType,
                  items: memberTypes,
                  onChanged: (val) {
                    if (val != null) notifier.setMemberType(val);
                  },
                  isDark: isDark,
                  width: 160,
                ),
                const SizedBox(width: 8),

                // 3. Classes Dropdown
                _buildDropdown(
                  value: state.selectedClass,
                  items: classes,
                  onChanged: (val) {
                    if (val != null) notifier.setClass(val);
                  },
                  isDark: isDark,
                  width: 135,
                ),
                const SizedBox(width: 8),

                // 4. Status Dropdown
                _buildDropdown(
                  value: state.selectedStatus,
                  items: statuses,
                  labels: statusLabels,
                  onChanged: (val) {
                    if (val != null) notifier.setStatus(val);
                  },
                  isDark: isDark,
                  width: 145,
                ),
                const SizedBox(width: 8),

                // 5. Membership Filter Dropdown
                _buildDropdown(
                  value: state.selectedMembershipFilter,
                  items: membershipFilters,
                  labels: membershipLabels,
                  onChanged: (val) {
                    if (val != null) notifier.setMembershipFilter(val);
                  },
                  isDark: isDark,
                  width: 155,
                ),
                const SizedBox(width: 10),

                // 6. Advanced Filters Modal Trigger
                _buildFiltersButton(context, state, notifier, isDark),
                const SizedBox(width: 8),

                // 7. Reset / Refresh Button
                _buildRefreshButton(notifier, isDark),
              ],
            );
          }

          // Tablet / Mobile View (Stacked Row Layout)
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
                      value: state.selectedMemberType,
                      items: memberTypes,
                      onChanged: (val) {
                        if (val != null) notifier.setMemberType(val);
                      },
                      isDark: isDark,
                      width: 155,
                    ),
                    const SizedBox(width: 8),
                    _buildDropdown(
                      value: state.selectedClass,
                      items: classes,
                      onChanged: (val) {
                        if (val != null) notifier.setClass(val);
                      },
                      isDark: isDark,
                      width: 130,
                    ),
                    const SizedBox(width: 8),
                    _buildDropdown(
                      value: state.selectedStatus,
                      items: statuses,
                      labels: statusLabels,
                      onChanged: (val) {
                        if (val != null) notifier.setStatus(val);
                      },
                      isDark: isDark,
                      width: 140,
                    ),
                    const SizedBox(width: 8),
                    _buildDropdown(
                      value: state.selectedMembershipFilter,
                      items: membershipFilters,
                      labels: membershipLabels,
                      onChanged: (val) {
                        if (val != null) notifier.setMembershipFilter(val);
                      },
                      isDark: isDark,
                      width: 150,
                    ),
                    const SizedBox(width: 8),
                    _buildFiltersButton(context, state, notifier, isDark),
                    const SizedBox(width: 8),
                    _buildRefreshButton(notifier, isDark),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField(MemberNotifier notifier, bool isDark) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: notifier.onSearchChanged,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: 'Search by name, ID, email, roll no., phone...',
          hintStyle: TextStyle(
            fontSize: 12.5,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    notifier.onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    required double width,
    Map<String, String>? labels,
  }) {
    final validValue = items.contains(value) ? value : items.first;

    return Container(
      width: width,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
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
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w500,
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

  Widget _buildFiltersButton(
    BuildContext context,
    MemberState state,
    MemberNotifier notifier,
    bool isDark,
  ) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.tune_rounded, size: 16),
      label: const Text('Filters', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF6366F1),
        side: const BorderSide(color: Color(0xFF6366F1)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () {
        notifier.resetFilters();
        _searchController.clear();
      },
    );
  }

  Widget _buildRefreshButton(MemberNotifier notifier, bool isDark) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
        ),
      ),
      child: IconButton(
        icon: const Icon(Icons.refresh_rounded, size: 18),
        tooltip: 'Reset & Refresh All Filters',
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        onPressed: () {
          _searchController.clear();
          notifier.resetFilters();
          notifier.fetchStats();
        },
      ),
    );
  }
}
