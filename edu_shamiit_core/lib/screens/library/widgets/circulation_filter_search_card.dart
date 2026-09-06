import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/circulation_provider.dart';
import 'dialogs/premium_date_range_dialog.dart';
import 'dialogs/advanced_circulation_filters_dialog.dart';

class CirculationFilterSearchCard extends ConsumerStatefulWidget {
  const CirculationFilterSearchCard({super.key});

  @override
  ConsumerState<CirculationFilterSearchCard> createState() => _CirculationFilterSearchCardState();
}

class _CirculationFilterSearchCardState extends ConsumerState<CirculationFilterSearchCard> {
  late TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: ref.read(circulationProvider).searchQuery);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(circulationProvider);
    final notifier = ref.read(circulationProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final searchInFields = state.filterOptions.searchInFields;
    final transactionTypes = state.filterOptions.transactionTypes;
    final statuses = state.filterOptions.statuses;

    final hasDateFilter = state.dateFrom != null && state.dateTo != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            'Filters & Search',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Row 1: Search In + Search Input
          Row(
            children: [
              // Search In Dropdown
              Container(
                width: 140,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: searchInFields.contains(state.searchIn) ? state.searchIn : searchInFields.first,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    items: searchInFields.map((f) => DropdownMenuItem(value: f, child: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) {
                      if (val != null) notifier.setSearchIn(val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Search Text Field
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Search by member, book, ISBN, barcode...',
                      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      suffixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    onChanged: (val) => notifier.setSearchQuery(val),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Transaction Type + Status + Date Range
          Row(
            children: [
              // Transaction Type Dropdown
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: transactionTypes.contains(state.selectedTransactionType) ? state.selectedTransactionType : transactionTypes.first,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        items: transactionTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          if (val != null) notifier.setTransactionType(val);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Status Dropdown
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: statuses.contains(state.selectedStatus) ? state.selectedStatus : statuses.first,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          if (val != null) notifier.setStatus(val);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Premium Date Range Picker Button
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: InkWell(
                    onTap: () async {
                      final result = await PremiumDateRangeDialog.show(
                        context,
                        initialStartDate: state.dateFrom != null ? DateTime.tryParse(state.dateFrom!) : null,
                        initialEndDate: state.dateTo != null ? DateTime.tryParse(state.dateTo!) : null,
                      );
                      if (result != null) {
                        if (result.isCleared) {
                          notifier.setDateRange(null, null);
                        } else if (result.start != null && result.end != null) {
                          notifier.setDateRange(
                            DateFormat('yyyy-MM-dd').format(result.start!),
                            DateFormat('yyyy-MM-dd').format(result.end!),
                          );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: hasDateFilter
                            ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasDateFilter
                              ? const Color(0xFF6366F1)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              hasDateFilter
                                  ? '${DateFormat('dd MMM').format(DateTime.parse(state.dateFrom!))} - ${DateFormat('dd MMM yyyy').format(DateTime.parse(state.dateTo!))}'
                                  : 'Select Date Range',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: hasDateFilter ? FontWeight.w700 : FontWeight.w500,
                                color: hasDateFilter
                                    ? const Color(0xFF6366F1)
                                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                            ),
                          ),
                          if (hasDateFilter) ...[
                            GestureDetector(
                              onTap: () => notifier.setDateRange(null, null),
                              child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF6366F1)),
                            ),
                          ] else ...[
                            Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Bottom Row: More Filters + Reset Button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.filter_list_rounded, size: 14, color: Color(0xFF6366F1)),
                label: const Text('More Filters', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                onPressed: () {
                  AdvancedCirculationFiltersDialog.show(context);
                },
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.restart_alt_rounded, size: 14, color: Color(0xFF64748B)),
                label: const Text('Reset', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                onPressed: () {
                  _searchCtrl.clear();
                  notifier.resetFilters();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

