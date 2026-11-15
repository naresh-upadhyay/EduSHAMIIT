import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/hostel_provider.dart';
import '../../services/hostel_lookup_helper.dart';
import 'dialogs/raise_complaint_dialog.dart';

class HostelComplaintsFilterBar extends ConsumerStatefulWidget {
  const HostelComplaintsFilterBar({super.key});

  @override
  ConsumerState<HostelComplaintsFilterBar> createState() => _HostelComplaintsFilterBarState();
}

class _HostelComplaintsFilterBarState extends ConsumerState<HostelComplaintsFilterBar> {
  late final TextEditingController _searchController;
  Timer? _debounce;

  static const List<String> _subtabs = [
    'All Complaints',
    'My Complaints',
    'Pending',
    'Overdue',
    'Resolved',
    'High Priority',
    'Maintenance',
    'Room Related',
    'Facility Related',
  ];

  static const List<String> _categories = [
    'All Categories',
    'Plumbing',
    'Electrical',
    'Housekeeping',
    'Furniture',
    'AC/Heating',
    'Pest Control',
    'Food & Mess',
    'Security',
    'Internet/WiFi',
    'Other',
  ];

  static const List<String> _priorities = [
    'All Priorities',
    'Low',
    'Medium',
    'High',
    'Urgent',
    'Critical',
  ];

  static const List<String> _statuses = [
    'All Status',
    'Open',
    'In Progress',
    'Pending',
    'Resolved',
    'Completed',
    'Rejected',
    'Canceled',
  ];

  List<String> _dynamicCategories = _categories;
  List<String> _dynamicPriorities = _priorities;
  List<String> _dynamicStatuses = _statuses;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    HostelLookupHelper.instance.getLookupLabels('HOSTEL_COMPLAINT_CATEGORY').then((labels) {
      if (mounted && labels.isNotEmpty) {
        setState(() => _dynamicCategories = ['All Categories', ...labels]);
      }
    }).catchError((_) {});
    HostelLookupHelper.instance.getLookupLabels('HOSTEL_COMPLAINT_PRIORITY').then((labels) {
      if (mounted && labels.isNotEmpty) {
        setState(() => _dynamicPriorities = ['All Priorities', ...labels]);
      }
    }).catchError((_) {});
    HostelLookupHelper.instance.getLookupLabels('HOSTEL_COMPLAINT_STATUS').then((labels) {
      if (mounted && labels.isNotEmpty) {
        setState(() => _dynamicStatuses = ['All Status', ...labels]);
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(hostelProvider.notifier).setComplaintsSearch(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Collect hostel list from structureTree
    final List<String> hostelOptions = ['All Hostels'];
    for (final b in state.structureTree) {
      if (!hostelOptions.contains(b.name)) {
        hostelOptions.add(b.name);
      }
    }
    if (!hostelOptions.contains('Boys Hostel A')) hostelOptions.add('Boys Hostel A');
    if (!hostelOptions.contains('Girls Hostel B')) hostelOptions.add('Girls Hostel B');

    // Date range display text
    final String dateRangeText = state.complaintsDateRange != null
        ? '${DateFormat('dd MMM').format(state.complaintsDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(state.complaintsDateRange!.end)}'
        : 'Filter Dates';

    final subtabsWidget = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _subtabs.map((tab) {
          final isSelected = state.complaintsSubtab == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () {
                notifier.setComplaintsSubtab(tab);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );

    final raiseButton = ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (ctx) => const RaiseComplaintDialog(),
        );
      },
      icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
      label: const Text(
        'Raise Complaint',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final moreButton = PopupMenuButton<String>(
      tooltip: 'More actions',
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.more_horiz_rounded, size: 18, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
      ),
      onSelected: (val) {
        if (val == 'REFRESH') {
          notifier.loadComplaintsData();
        } else if (val == 'EXPORT') {
          notifier.exportComplaintsCsv();
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'REFRESH',
          child: Row(
            children: [
              Icon(Icons.refresh_rounded, size: 18),
              SizedBox(width: 10),
              Text('Refresh Complaints'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'EXPORT',
          child: Row(
            children: [
              Icon(Icons.download_rounded, size: 18),
              SizedBox(width: 10),
              Text('Export to CSV'),
            ],
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Sub-filter Tabs Row + Action Buttons (Responsive)
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 620;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  subtabsWidget,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: raiseButton),
                      const SizedBox(width: 8),
                      moreButton,
                    ],
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: subtabsWidget),
                const SizedBox(width: 12),
                raiseButton,
                const SizedBox(width: 8),
                moreButton,
              ],
            );
          },
        ),

        const SizedBox(height: 14),

        // 2. Comprehensive Search and Filter Bar Row
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search Input Box
              SizedBox(
                width: 280,
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by title, description, student, room, complaint no...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                  ),
                ),
              ),

              // Hostel Dropdown
              _buildDropdown(
                value: state.complaintsHostelFilter,
                items: hostelOptions,
                onChanged: (val) {
                  if (val != null) notifier.setComplaintsHostel(val);
                },
                isDark: isDark,
              ),

              // Category Dropdown
              _buildDropdown(
                value: state.complaintsCategoryFilter,
                items: _dynamicCategories,
                onChanged: (val) {
                  if (val != null) notifier.setComplaintsCategory(val);
                },
                isDark: isDark,
              ),

              // Priority Dropdown
              _buildDropdown(
                value: state.complaintsPriorityFilter,
                items: _dynamicPriorities,
                onChanged: (val) {
                  if (val != null) notifier.setComplaintsPriority(val);
                },
                isDark: isDark,
              ),

              // Status Dropdown
              _buildDropdown(
                value: state.complaintsStatusFilter,
                items: _dynamicStatuses,
                onChanged: (val) {
                  if (val != null) notifier.setComplaintsStatus(val);
                },
                isDark: isDark,
              ),

              // Date Range Picker (Leave & Outing style)
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(now.year - 2),
                    lastDate: DateTime(now.year + 2),
                    initialDateRange: state.complaintsDateRange ??
                        DateTimeRange(
                          start: now.subtract(const Duration(days: 30)),
                          end: now,
                        ),
                  );
                  if (picked != null) {
                    notifier.setComplaintsDateRange(picked);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        dateRangeText,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                      if (state.complaintsDateRange != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => notifier.setComplaintsDateRange(null),
                          child: const Icon(Icons.close, size: 14, color: Color(0xFF64748B)),
                        ),
                      ] else ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
                      ],
                    ],
                  ),
                ),
              ),

              // More Filters Button
              OutlinedButton.icon(
                onPressed: () {
                  // Reset all filters to defaults
                  _searchController.clear();
                  notifier.setComplaintsSearch('');
                  notifier.setComplaintsHostel('All Hostels');
                  notifier.setComplaintsCategory('All Categories');
                  notifier.setComplaintsPriority('All Priorities');
                  notifier.setComplaintsStatus('All Status');
                  notifier.setComplaintsSubtab('All Complaints');
                  notifier.setComplaintsDateRange(null);
                },
                icon: const Icon(Icons.filter_list_rounded, size: 15, color: Color(0xFF64748B)),
                label: Text(
                  'Reset Filters',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    final effectiveValue = items.contains(value) ? value : items.first;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
          isDense: true,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          items: items.map((opt) {
            return DropdownMenuItem<String>(
              value: opt,
              child: Text(opt),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
