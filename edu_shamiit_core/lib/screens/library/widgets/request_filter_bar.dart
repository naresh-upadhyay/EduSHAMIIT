import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import '../providers/request_provider.dart';
import 'dialogs/premium_date_range_dialog.dart';

class RequestFilterBar extends ConsumerStatefulWidget {
  const RequestFilterBar({super.key});

  @override
  ConsumerState<RequestFilterBar> createState() => _RequestFilterBarState();
}

class _RequestFilterBarState extends ConsumerState<RequestFilterBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestProvider);
    final notifier = ref.read(requestProvider.notifier);
    final options = state.options;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    // Sync search controller if cleared externally
    if (state.searchQuery.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    final hasActiveFilters = state.searchQuery.isNotEmpty ||
        state.selectedType != 'ALL' ||
        state.selectedStatus != 'ALL' ||
        state.selectedPriority != 'ALL' ||
        state.selectedRole != 'ALL' ||
        state.dateRange != null;

    return Container(
      margin: EdgeInsets.fromLTRB(
        isDesktop ? 28 : 16,
        0,
        isDesktop ? 28 : 16,
        14,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Subtabs (All, My Requests, Needs Review, Assigned to Me)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSubtabChip(
                  label: 'All Requests',
                  count: state.kpis.totalRequests > 0 ? state.kpis.totalRequests : null,
                  isActive: state.activeSubtab == 'ALL',
                  isDark: isDark,
                  onTap: () => notifier.setSubtab('ALL'),
                ),
                const SizedBox(width: 8),
                _buildSubtabChip(
                  label: 'My Requests',
                  isActive: state.activeSubtab == 'MY_REQUESTS',
                  isDark: isDark,
                  onTap: () => notifier.setSubtab('MY_REQUESTS'),
                ),
                const SizedBox(width: 8),
                _buildSubtabChip(
                  label: 'Needs Review',
                  count: state.kpis.newRequests > 0 ? state.kpis.newRequests : null,
                  countBg: const Color(0xFFEFF6FF),
                  countColor: const Color(0xFF2563EB),
                  isActive: state.activeSubtab == 'NEEDS_REVIEW',
                  isDark: isDark,
                  onTap: () => notifier.setSubtab('NEEDS_REVIEW'),
                ),
                const SizedBox(width: 8),
                _buildSubtabChip(
                  label: 'Assigned to Me',
                  isActive: state.activeSubtab == 'ASSIGNED_TO_ME',
                  isDark: isDark,
                  onTap: () => notifier.setSubtab('ASSIGNED_TO_ME'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Row 2: Search Box & Dropdown Filters
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1100;

              if (isWide) {
                return Row(
                  children: [
                    // Search Bar
                    Expanded(
                      flex: 3,
                      child: _buildSearchBox(notifier, isDark),
                    ),
                    const SizedBox(width: 10),

                    // Request Type Dropdown
                    _buildDropdown(
                      label: 'Type',
                      value: state.selectedType,
                      items: {'ALL', ...options.requestTypes}.toList(),
                      isDark: isDark,
                      onChanged: (val) => notifier.setTypeFilter(val ?? 'ALL'),
                    ),
                    const SizedBox(width: 10),

                    // Status Dropdown
                    _buildDropdown(
                      label: 'Status',
                      value: state.selectedStatus,
                      items: options.statuses.map((e) => e.toUpperCase()).toSet().toList(),
                      isDark: isDark,
                      onChanged: (val) => notifier.setStatusFilter(val ?? 'ALL'),
                    ),
                    const SizedBox(width: 10),

                    // Priority Dropdown
                    _buildDropdown(
                      label: 'Priority',
                      value: state.selectedPriority,
                      items: options.priorities.map((e) => e.toUpperCase()).toSet().toList(),
                      isDark: isDark,
                      onChanged: (val) => notifier.setPriorityFilter(val ?? 'ALL'),
                    ),
                    const SizedBox(width: 10),

                    // Role Dropdown
                    _buildDropdown(
                      label: 'Role',
                      value: state.selectedRole,
                      items: {'ALL', ...options.roles.where((e) => e.toUpperCase() != 'ALL')}.toList(),
                      isDark: isDark,
                      onChanged: (val) => notifier.setRoleFilter(val ?? 'ALL'),
                    ),
                    const SizedBox(width: 10),

                    // Date Range Button
                    _buildDateRangeButton(context, state, notifier, isDark),

                    // Clear Filters Icon
                    if (hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Reset Filters',
                        icon: const Icon(Icons.filter_alt_off_rounded, color: Color(0xFFEF4444), size: 20),
                        onPressed: () {
                          _searchController.clear();
                          notifier.resetFilters();
                        },
                      ),
                    ],
                  ],
                );
              } else {
                // Multi-line wrap for smaller screens
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSearchBox(notifier, isDark),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildDropdown(
                          label: 'Type',
                          value: state.selectedType,
                          items: {'ALL', ...options.requestTypes}.toList(),
                          isDark: isDark,
                          onChanged: (val) => notifier.setTypeFilter(val ?? 'ALL'),
                        ),
                        _buildDropdown(
                          label: 'Status',
                          value: state.selectedStatus,
                          items: options.statuses.map((e) => e.toUpperCase()).toSet().toList(),
                          isDark: isDark,
                          onChanged: (val) => notifier.setStatusFilter(val ?? 'ALL'),
                        ),
                        _buildDropdown(
                          label: 'Priority',
                          value: state.selectedPriority,
                          items: options.priorities.map((e) => e.toUpperCase()).toSet().toList(),
                          isDark: isDark,
                          onChanged: (val) => notifier.setPriorityFilter(val ?? 'ALL'),
                        ),
                        _buildDropdown(
                          label: 'Role',
                          value: state.selectedRole,
                          items: {'ALL', ...options.roles.where((e) => e.toUpperCase() != 'ALL')}.toList(),
                          isDark: isDark,
                          onChanged: (val) => notifier.setRoleFilter(val ?? 'ALL'),
                        ),

                        _buildDateRangeButton(context, state, notifier, isDark),
                        if (hasActiveFilters)
                          TextButton.icon(
                            icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFFEF4444)),
                            label: const Text('Reset', style: TextStyle(color: Color(0xFFEF4444))),
                            onPressed: () {
                              _searchController.clear();
                              notifier.resetFilters();
                            },
                          ),
                      ],
                    ),
                  ],
                );

              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubtabChip({
    required String label,
    int? count,
    Color? countBg,
    Color? countColor,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? const Color(0xFF6366F1) : const Color(0xFF1E293B))
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? Colors.white
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.2)
                        : (countBg ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? Colors.white
                          : (countColor ?? (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155))),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox(RequestNotifier notifier, bool isDark) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: notifier.setSearchQuery,
        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Search by title, type, member, ID, department...',
          hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400),
          prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF94A3B8)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    notifier.setSearchQuery('');
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
    required String label,
    required String value,
    required List<String> items,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    // Format display string
    String display(String item) {
      if (item.toUpperCase() == 'ALL') return '$label: All';
      return item.replaceAll('_', ' ');
    }

    final sanitizedItems = items.toSet().toList();
    final sanitizedValue = sanitizedItems.contains(value)
        ? value
        : (sanitizedItems.firstWhere((e) => e.toUpperCase() == value.toUpperCase(), orElse: () => sanitizedItems.isNotEmpty ? sanitizedItems.first : 'ALL'));


    return Container(
      height: 40,
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
          value: sanitizedValue,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF334155),
            fontWeight: FontWeight.w500,
          ),
          items: sanitizedItems.map((e) {
            return DropdownMenuItem<String>(
              value: e,
              child: Text(display(e)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDateRangeButton(BuildContext context, RequestState state, RequestNotifier notifier, bool isDark) {
    final hasDateRange = state.dateRange != null;
    final formatter = DateFormat('dd MMM yyyy');
    final labelText = hasDateRange
        ? '${formatter.format(state.dateRange!.start)} - ${formatter.format(state.dateRange!.end)}'
        : 'Date Range';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final result = await PremiumDateRangeDialog.show(
            context,
            initialStartDate: state.dateRange?.start,
            initialEndDate: state.dateRange?.end,
          );
          if (result != null) {
            if (result.isCleared || (result.start == null && result.end == null)) {
              notifier.setDateRange(null);
            } else if (result.start != null && result.end != null) {
              notifier.setDateRange(DateTimeRange(start: result.start!, end: result.end!));
            }
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: hasDateRange
                ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasDateRange
                  ? const Color(0xFF93C5FD)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: hasDateRange ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Text(
                labelText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: hasDateRange ? FontWeight.w600 : FontWeight.w500,
                  color: hasDateRange
                      ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF))
                      : (isDark ? Colors.white : const Color(0xFF334155)),
                ),
              ),
              if (hasDateRange) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => notifier.setDateRange(null),
                  child: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF2563EB)),
                ),
              ] else ...[
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
