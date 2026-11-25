import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/hostel_provider.dart';
import '../dialogs/add_hostel_student_dialog.dart';

class HostelStudentsFilterBar extends ConsumerStatefulWidget {
  const HostelStudentsFilterBar({super.key});

  @override
  ConsumerState<HostelStudentsFilterBar> createState() => _HostelStudentsFilterBarState();
}

class _HostelStudentsFilterBarState extends ConsumerState<HostelStudentsFilterBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(hostelProvider).studentsSearch,
    );
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

    // Available hostels
    final List<String> hostelOptions = ['All Hostels'];
    for (final b in state.structureTree) {
      if (!hostelOptions.contains(b.name)) {
        hostelOptions.add(b.name);
      }
    }
    if (hostelOptions.length == 1) {
      hostelOptions.addAll(['Boys Hostel A', 'Boys Hostel B', 'Girls Hostel A', 'Girls Hostel B']);
    }

    final List<String> classOptions = ['All Classes'];
    if (state.schoolClasses.isNotEmpty) {
      for (final c in state.schoolClasses) {
        if (!classOptions.contains(c)) {
          classOptions.add(c);
        }
      }
    } else {
      classOptions.addAll(['10 A', '10 B', '11 A', '11 B', '12 A', '12 B']);
    }
    final statusOptions = ['All Status', 'Active', 'Leave', 'Awaiting Allocation', 'Checked Out'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 1150;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchInput(notifier, isDark),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildDropdown(
                      value: state.studentsHostelFilter,
                      items: hostelOptions,
                      icon: Icons.apartment_rounded,
                      width: 155,
                      onChanged: (val) {
                        if (val != null) notifier.setStudentsHostelFilter(val);
                      },
                      isDark: isDark,
                    ),
                    _buildDropdown(
                      value: state.studentsClassFilter,
                      items: classOptions,
                      icon: Icons.school_outlined,
                      width: 130,
                      onChanged: (val) {
                        if (val != null) notifier.setStudentsClassFilter(val);
                      },
                      isDark: isDark,
                    ),
                    _buildDropdown(
                      value: state.studentsStatusFilter,
                      items: statusOptions,
                      icon: Icons.circle_outlined,
                      width: 140,
                      onChanged: (val) {
                        if (val != null) notifier.setStudentsStatusFilter(val);
                      },
                      isDark: isDark,
                    ),
                    _buildDateButton(context, state, notifier, isDark),
                    _buildAddStudentButton(context),
                    _buildMoreActionsMenu(context, notifier, isDark),
                  ],
                ),
              ],
            );
          }

          // Full Desktop Single Row
          return Row(
            children: [
              // Search Input
              Expanded(
                flex: 3,
                child: _buildSearchInput(notifier, isDark),
              ),
              const SizedBox(width: 10),

              // All Hostels Dropdown
              _buildDropdown(
                value: state.studentsHostelFilter,
                items: hostelOptions,
                icon: Icons.apartment_rounded,
                width: 155,
                onChanged: (val) {
                  if (val != null) notifier.setStudentsHostelFilter(val);
                },
                isDark: isDark,
              ),
              const SizedBox(width: 10),

              // All Classes Dropdown
              _buildDropdown(
                value: state.studentsClassFilter,
                items: classOptions,
                icon: Icons.school_outlined,
                width: 130,
                onChanged: (val) {
                  if (val != null) notifier.setStudentsClassFilter(val);
                },
                isDark: isDark,
              ),
              const SizedBox(width: 10),

              // All Status Dropdown
              _buildDropdown(
                value: state.studentsStatusFilter,
                items: statusOptions,
                icon: Icons.circle_outlined,
                width: 140,
                onChanged: (val) {
                  if (val != null) notifier.setStudentsStatusFilter(val);
                },
                isDark: isDark,
              ),
              const SizedBox(width: 10),

              // Date Picker Button
              _buildDateButton(context, state, notifier, isDark),
              const SizedBox(width: 10),

              // More Filters Outline Button
              _buildMoreFiltersButton(context, state, notifier, isDark),
              const SizedBox(width: 12),

              // Primary Action: + Add Hostel Student
              _buildAddStudentButton(context),
              const SizedBox(width: 6),

              // ... Overflow Menu
              _buildMoreActionsMenu(context, notifier, isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchInput(HostelNotifier notifier, bool isDark) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
          hintText: 'Search by name, roll no, room, class...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    notifier.setStudentsSearch('');
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
        onChanged: (val) {
          setState(() {});
          notifier.setStudentsSearch(val.trim());
        },
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    double? width,
  }) {
    final currentValue = items.contains(value) ? value : items.first;

    return Container(
      width: width,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<String>.fromMenuItems(
          value: currentValue,
          isDense: true,
          isExpanded: width != null,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF334155),
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          items: items.map((opt) {
            return DropdownMenuItem<String>(
              value: opt,
              child: Text(
                opt,
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

  Widget _buildDateButton(
    BuildContext context,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
  ) {
    String label = 'Date';
    if (state.selectedDateRange != null) {
      final f = DateFormat('dd MMM');
      label = '${f.format(state.selectedDateRange!.start)} - ${f.format(state.selectedDateRange!.end)}';
    }

    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          initialDateRange: state.selectedDateRange,
          builder: (context, child) {
            return Theme(
              data: isDark ? ThemeData.dark() : ThemeData.light(),
              child: child!,
            );
          },
        );
        if (picked != null) {
          notifier.setStudentsDateRange(picked);
        }
      },
      icon: const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF334155),
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildMoreFiltersButton(
    BuildContext context,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return OutlinedButton.icon(
      onPressed: () {
        _showMoreFiltersModal(context, state, notifier, isDark);
      },
      icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF64748B)),
      label: const Text(
        'More Filters',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF334155),
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showMoreFiltersModal(
    BuildContext context,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        String fee = state.studentsFeeStatusFilter;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: const Text('More Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: StatefulBuilder(
            builder: (c, setLocalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fee Payment Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['All Fees', 'Paid', 'Pending', 'Partial'].map((fOpt) {
                      final sel = fee == fOpt;
                      return ChoiceChip(
                        label: Text(fOpt),
                        selected: sel,
                        onSelected: (val) {
                          setLocalState(() => fee = fOpt);
                        },
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                notifier.setStudentsFeeStatusFilter('All Fees');
                Navigator.of(ctx).pop();
              },
              child: const Text('Reset'),
            ),
            ElevatedButton(
              onPressed: () {
                notifier.setStudentsFeeStatusFilter(fee);
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Apply', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddStudentButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (ctx) => const AddHostelStudentDialog(),
        );
      },
      icon: const Icon(Icons.add, size: 18, color: Colors.white),
      label: const Text(
        'Add Hostel Student',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 38),
        backgroundColor: const Color(0xFF2563EB),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );
  }

  Widget _buildMoreActionsMenu(BuildContext context, HostelNotifier notifier, bool isDark) {
    return PopupMenuButton<String>(
      icon: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: const Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF64748B)),
      ),
      tooltip: 'More actions',
      onSelected: (val) {
        if (val == 'refresh') {
          notifier.loadStudentsData();
        } else if (val == 'export') {
          notifier.exportStudentsCsv();
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh_rounded, size: 16),
              SizedBox(width: 8),
              Text('Refresh Roster', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.download_rounded, size: 16),
              SizedBox(width: 8),
              Text('Export to CSV', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
