import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/utils/download_helper.dart';
import '../../providers/hostel_provider.dart';
import '../../services/hostel_lookup_helper.dart';
import 'assign_hostel_staff_dialog.dart';

class HostelStaffFilterBar extends ConsumerStatefulWidget {
  const HostelStaffFilterBar({super.key});

  @override
  ConsumerState<HostelStaffFilterBar> createState() => _HostelStaffFilterBarState();
}

class _HostelStaffFilterBarState extends ConsumerState<HostelStaffFilterBar> {
  late TextEditingController _searchController;

  static const List<String> _hostels = [
    'All Hostels',
    'Boys Hostel A',
    'Boys Hostel B',
    'Girls Hostel A',
    'Girls Hostel B',
  ];

  static const List<String> _roles = [
    'All Roles',
    'Warden',
    'Caretaker',
    'Security',
    'Housekeeping',
    'Maintenance',
    'Mess Coordinator',
  ];

  static const List<String> _statuses = [
    'All Status',
    'Active',
    'On Leave',
    'Pending',
  ];

  List<String> _dynamicRoles = _roles;
  List<String> _dynamicStatuses = _statuses;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: ref.read(hostelProvider).staffSearch);
    HostelLookupHelper.instance.getLookupLabels('HOSTEL_STAFF_ROLE').then((labels) {
      if (mounted && labels.isNotEmpty) {
        setState(() => _dynamicRoles = ['All Roles', ...labels]);
      }
    }).catchError((_) {});
    HostelLookupHelper.instance.getLookupLabels('HOSTEL_STAFF_STATUS').then((labels) {
      if (mounted && labels.isNotEmpty) {
        setState(() => _dynamicStatuses = ['All Status', ...labels]);
      }
    }).catchError((_) {});
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

    // Synchronize search controller if state is reset externally
    if (_searchController.text != state.staffSearch && state.staffSearch.isEmpty) {
      _searchController.text = '';
    }

    final dynamicHostels = ['All Hostels', ...state.structureTree.map((b) => b.name)];
    final hostels = dynamicHostels.length > 1 ? dynamicHostels : _hostels;
    final currentHostelVal = hostels.contains(state.staffHostelFilter) ? state.staffHostelFilter : 'All Hostels';

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Only use single-row layout if width is wide enough to avoid any RenderFlex overflow (>= 1260)
        final isSingleRow = width >= 1260;

        if (isSingleRow) {
          return Row(
            children: [
              // Search input
              Expanded(
                flex: 3,
                child: _buildSearchField(isDark, notifier),
              ),
              const SizedBox(width: 10),

              // Hostels Dropdown
              _buildDropdown(
                value: currentHostelVal,
                items: hostels,
                onChanged: (val) {
                  if (val != null) notifier.setStaffHostelFilter(val);
                },
                isDark: isDark,
                width: 140,
              ),
              const SizedBox(width: 8),

              // Roles Dropdown
              _buildDropdown(
                value: state.staffRoleFilter,
                items: _dynamicRoles,
                onChanged: (val) {
                  if (val != null) notifier.setStaffRoleFilter(val);
                },
                isDark: isDark,
                width: 120,
              ),
              const SizedBox(width: 8),

              // Status Dropdown
              _buildDropdown(
                value: state.staffStatusFilter,
                items: _dynamicStatuses,
                onChanged: (val) {
                  if (val != null) notifier.setStaffStatusFilter(val);
                },
                isDark: isDark,
                width: 115,
              ),
              const SizedBox(width: 8),

              // Joined Date Picker Button
              _buildDatePickerButton(context, state, notifier, isDark),
              const SizedBox(width: 8),

              // More Filters Button (Interactive Dialog)
              _buildMoreFiltersButton(context, state, notifier, isDark),
              const SizedBox(width: 12),

              // + Add Staff Button
              _buildAddStaffButton(context),
              const SizedBox(width: 8),

              // ... More options button
              _buildMoreOptionsButton(context, state, notifier, isDark),
            ],
          );
        }

        // Two-row responsive layout for laptops, tablets, and screens < 1260px (ZERO overflow)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Search + Add Staff + More Options
            Row(
              children: [
                Expanded(
                  child: _buildSearchField(isDark, notifier),
                ),
                const SizedBox(width: 8),
                _buildAddStaffButton(context),
                const SizedBox(width: 8),
                _buildMoreOptionsButton(context, state, notifier, isDark),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Scrollable / Wrap Filter Controls
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDropdown(
                    value: currentHostelVal,
                    items: hostels,
                    onChanged: (val) {
                      if (val != null) notifier.setStaffHostelFilter(val);
                    },
                    isDark: isDark,
                    width: 140,
                  ),
                  const SizedBox(width: 8),
                  _buildDropdown(
                    value: state.staffRoleFilter,
                    items: _dynamicRoles,
                    onChanged: (val) {
                      if (val != null) notifier.setStaffRoleFilter(val);
                    },
                    isDark: isDark,
                    width: 120,
                  ),
                  const SizedBox(width: 8),
                  _buildDropdown(
                    value: state.staffStatusFilter,
                    items: _dynamicStatuses,
                    onChanged: (val) {
                      if (val != null) notifier.setStaffStatusFilter(val);
                    },
                    isDark: isDark,
                    width: 115,
                  ),
                  const SizedBox(width: 8),
                  _buildDatePickerButton(context, state, notifier, isDark),
                  const SizedBox(width: 8),
                  _buildMoreFiltersButton(context, state, notifier, isDark),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchField(bool isDark, HostelNotifier notifier) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: 'Search by name, role, contact, hostel...',
          hintStyle: TextStyle(
            fontSize: 12.5,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    notifier.setStaffSearch('');
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          isDense: true,
        ),
        onChanged: (val) {
          setState(() {});
          notifier.setStaffSearch(val.trim());
        },
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    required double width,
  }) {
    return Container(
      width: width,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<String>.fromMenuItems(
          value: items.contains(value) ? value : items.first,
          isDense: true,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF334155),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
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

  Widget _buildDatePickerButton(BuildContext context, HostelState state, HostelNotifier notifier, bool isDark) {
    final hasDate = state.staffJoinedDateFilter != null;
    final dateText = hasDate
        ? '${state.staffJoinedDateFilter!.day}/${state.staffJoinedDateFilter!.month}/${state.staffJoinedDateFilter!.year}'
        : 'Joined Date';

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: state.staffJoinedDateFilter ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          notifier.setStaffJoinedDateFilter(picked);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasDate
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: hasDate ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              dateText,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: hasDate
                    ? const Color(0xFF2563EB)
                    : (isDark ? Colors.white : const Color(0xFF334155)),
              ),
            ),
            const SizedBox(width: 4),
            if (hasDate)
              InkWell(
                onTap: () => notifier.setStaffJoinedDateFilter(null),
                child: const Icon(Icons.close, size: 14, color: Color(0xFF2563EB)),
              )
            else
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreFiltersButton(BuildContext context, HostelState state, HostelNotifier notifier, bool isDark) {
    return InkWell(
      onTap: () => _openMoreFiltersDialog(context, state, notifier, isDark),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 15,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              'More Filters',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMoreFiltersDialog(BuildContext context, HostelState state, HostelNotifier notifier, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        String shift = 'All Shifts';
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 8),
                  Text('More Staff Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Filter by Shift Timings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    AppSearchableDropdownFormField<String>.fromMenuItems(
                      initialValue: shift,
                      isDense: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All Shifts', child: Text('All Shifts')),
                        DropdownMenuItem(value: '6:00 AM - 10:00 PM', child: Text('General (6:00 AM - 10:00 PM)')),
                        DropdownMenuItem(value: '6:00 AM - 2:00 PM', child: Text('Morning Shift (6:00 AM - 2:00 PM)')),
                        DropdownMenuItem(value: '2:00 PM - 10:00 PM', child: Text('Evening Shift (2:00 PM - 10:00 PM)')),
                        DropdownMenuItem(value: '10:00 PM - 6:00 AM', child: Text('Night Shift (10:00 PM - 6:00 AM)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => shift = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Quick Role Filters', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Warden', 'Caretaker', 'Security', 'Housekeeping', 'Maintenance'].map((r) {
                        final isSelected = state.staffRoleFilter == r;
                        return ChoiceChip(
                          label: Text(r, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2563EB),
                          onSelected: (selected) {
                            notifier.setStaffRoleFilter(selected ? r : 'All Roles');
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
                    _searchController.clear();
                    notifier.setStaffSearch('');
                    notifier.setStaffHostelFilter('All Hostels');
                    notifier.setStaffRoleFilter('All Roles');
                    notifier.setStaffStatusFilter('All Status');
                    notifier.setStaffJoinedDateFilter(null);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Reset All'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: () {
                    if (shift != 'All Shifts') {
                      notifier.setStaffSearch(shift);
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Apply Filters', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAddStaffButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => const AssignHostelStaffDialog(),
        );
      },
      icon: const Icon(Icons.add, size: 17, color: Colors.white),
      label: const Text(
        'Add Staff',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildMoreOptionsButton(
    BuildContext context,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return PopupMenuButton<String>(
      tooltip: 'More Options',
      icon: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 18,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
      onSelected: (val) async {
        if (val == 'refresh') {
          await notifier.loadStaffData();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Staff data refreshed successfully'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else if (val == 'export_csv') {
          final url = '/api/hostel/staff/export?academic_year=${Uri.encodeComponent(state.selectedAcademicYear)}';
          final filename = 'hostel_staff_all_${DateTime.now().millisecondsSinceEpoch}.csv';
          await getDownloadHelper().downloadFile(url, filename);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Exported all staff to $filename'),
                backgroundColor: const Color(0xFF16A34A),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else if (val == 'reset_filters') {
          _searchController.clear();
          notifier.setStaffSearch('');
          notifier.setStaffHostelFilter('All Hostels');
          notifier.setStaffRoleFilter('All Roles');
          notifier.setStaffStatusFilter('All Status');
          notifier.setStaffJoinedDateFilter(null);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All filters reset to default'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 16, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Refresh Staff Data', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'export_csv',
          child: Row(
            children: [
              Icon(Icons.download_rounded, size: 16, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Text('Export All Staff (CSV)', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'reset_filters',
          child: Row(
            children: [
              Icon(Icons.filter_alt_off_outlined, size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 8),
              Text('Reset All Filters', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
