import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/hostel_provider.dart';
import 'create_leave_outing_dialog.dart';

class HostelLeaveFilterBar extends ConsumerStatefulWidget {
  const HostelLeaveFilterBar({super.key});

  @override
  ConsumerState<HostelLeaveFilterBar> createState() => _HostelLeaveFilterBarState();
}

class _HostelLeaveFilterBarState extends ConsumerState<HostelLeaveFilterBar> {
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _subTabs = [
    'Leave & Outing Requests',
    'Gate Pass',
    'Movement Calendar',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(hostelProvider).leaveSearchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final subtabsRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_subTabs.length, (index) {
          final isSelected = state.leaveSubTab == index;
          return Padding(
            padding: const EdgeInsets.only(right: 24),
            child: InkWell(
              onTap: () => notifier.setLeaveSubTab(index),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  _subTabs[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );

    final newRequestButton = ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const CreateLeaveOutingDialog(),
        );
      },
      icon: const Icon(Icons.add, size: 18, color: Colors.white),
      label: const Text(
        'New Request',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );

    final moreButton = Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_horiz_rounded,
          size: 20,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
        tooltip: 'More Actions',
        padding: const EdgeInsets.all(8),
        onSelected: (val) {
          if (val == 'refresh') {
            notifier.loadLeaveOutingData();
          } else if (val == 'export') {
            notifier.exportLeaveOutingCsv();
          } else if (val == 'reset') {
            _searchController.clear();
            notifier.setLeaveSearchQuery('');
            notifier.setLeaveHostelFilter('All Hostels');
            notifier.setLeaveTypeFilter('All Types');
            notifier.setLeaveStatusFilter('All Status');
            notifier.setLeaveDateRange(null);
            notifier.loadLeaveOutingData();
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(
            value: 'refresh',
            child: Row(
              children: [
                Icon(Icons.refresh_rounded, size: 16),
                SizedBox(width: 8),
                Text('Refresh Requests'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'export',
            child: Row(
              children: [
                Icon(Icons.download_rounded, size: 16),
                SizedBox(width: 8),
                Text('Export to CSV'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'reset',
            child: Row(
              children: [
                Icon(Icons.clear_all_rounded, size: 16),
                SizedBox(width: 8),
                Text('Reset Filters'),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Top Subtabs Row + "+ New Request" button (Responsive)
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 540;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  subtabsRow,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: newRequestButton),
                      const SizedBox(width: 8),
                      moreButton,
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: subtabsRow),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    newRequestButton,
                    const SizedBox(width: 8),
                    moreButton,
                  ],
                ),
              ],
            );
          },
        ),

        if (state.leaveSubTab != 2) ...[
          const SizedBox(height: 16),

        // 2. Filter & Search Controls Row
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Search Input Field
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 260, maxWidth: 340),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => notifier.setLeaveSearch(val),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by student name, roll no., room, reason...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              notifier.setLeaveSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                  ),
                ),
              ),
            ),

            // Dropdown 1: Hostel
            _buildDropdown(
              value: state.leaveHostelFilter,
              items: const ['All Hostels', 'Boys Hostel A', 'Boys Hostel B', 'Girls Hostel A', 'Girls Hostel B'],
              onChanged: (val) {
                if (val != null) notifier.setLeaveHostelFilter(val);
              },
              isDark: isDark,
            ),

            // Dropdown 2: Request Type
            _buildDropdown(
              value: state.leaveTypeFilter,
              items: const ['All Types', 'LEAVE', 'OUTING'],
              onChanged: (val) {
                if (val != null) notifier.setLeaveTypeFilter(val);
              },
              isDark: isDark,
            ),

            // Dropdown 3: Status
            _buildDropdown(
              value: (state.leaveSubTab == 1 &&
                      (state.leaveStatusFilter == 'PENDING' || state.leaveStatusFilter == 'REJECTED'))
                  ? 'All Status'
                  : state.leaveStatusFilter,
              items: state.leaveSubTab == 1
                  ? const ['All Status', 'ACTIVE', 'USED', 'EXPIRED', 'EXITED', 'RETURNED', 'APPROVED']
                  : const ['All Status', 'PENDING', 'APPROVED', 'REJECTED', 'CANCELED', 'EXITED', 'RETURNED', 'OVERDUE'],
              onChanged: (val) {
                if (val != null) notifier.setLeaveStatusFilter(val);
              },
              isDark: isDark,
            ),

            // Date Range Display Selector
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year - 2),
                    lastDate: DateTime(now.year + 2),
                    initialDateRange: state.leaveDateRange ??
                        DateTimeRange(
                          start: now.subtract(const Duration(days: 30)),
                          end: now.add(const Duration(days: 30)),
                        ),
                  );
                  if (picked != null) {
                    notifier.setLeaveDateRange(picked);
                  }
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        state.leaveDateRange != null
                            ? '${DateFormat('dd MMM').format(state.leaveDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(state.leaveDateRange!.end)}'
                            : 'Filter Dates',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                      if (state.leaveDateRange != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => notifier.setLeaveDateRange(null),
                          child: const Icon(Icons.close, size: 14, color: Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // More Filters Button
            OutlinedButton.icon(
              onPressed: () => _showMoreFiltersDialog(context, state, notifier, isDark),
              icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF64748B)),
              label: Text(
                'More Filters',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),

            // Export Button
            OutlinedButton.icon(
              onPressed: () => notifier.exportLeaveOutingCsv(),
              icon: const Icon(Icons.file_download_outlined, size: 16, color: Color(0xFF64748B)),
              label: Text(
                'Export',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        ],
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isDense: true,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF334155),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          items: items.map((it) {
            return DropdownMenuItem<String>(
              value: it,
              child: Text(it),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _showMoreFiltersDialog(
    BuildContext context,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 20),
            SizedBox(width: 8),
            Text('Advanced Leave Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Quick Status Presets', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['PENDING', 'APPROVED', 'EXITED', 'RETURNED', 'OVERDUE'].map((st) {
                  final isSelected = state.leaveStatusFilter == st;
                  return ChoiceChip(
                    label: Text(st, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2563EB),
                    onSelected: (selected) {
                      notifier.setLeaveStatusFilter(selected ? st : 'All Status');
                      Navigator.of(ctx).pop();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Filter by Request Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['LEAVE', 'OUTING'].map((cat) {
                  final isSelected = state.leaveTypeFilter == cat;
                  return ChoiceChip(
                    label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF7C3AED),
                    onSelected: (selected) {
                      notifier.setLeaveTypeFilter(selected ? cat : 'All Types');
                      Navigator.of(ctx).pop();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              notifier.setLeaveTypeFilter('All Types');
              notifier.setLeaveStatusFilter('All Status');
              notifier.setLeaveDateRange(null);
              Navigator.of(ctx).pop();
            },
            child: const Text('Reset All'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
