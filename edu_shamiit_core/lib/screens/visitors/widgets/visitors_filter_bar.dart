import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/visitors_provider.dart';
import 'dialogs/visitor_date_range_dialog.dart';
import 'dialogs/visitors_more_filters_dialog.dart';
import 'dialogs/visitor_qr_scanner_dialog.dart';
import 'dialogs/visitor_profiles_gate_pass_dialog.dart';

class VisitorsFilterBar extends ConsumerWidget {
  final VoidCallback onRegisterVisitor;
  final VoidCallback? onMoreFilters;

  const VisitorsFilterBar({
    super.key,
    required this.onRegisterVisitor,
    this.onMoreFilters,
  });

  static const List<String> _visitorTypes = [
    'All Visitor Types',
    'Parent',
    'Official',
    'Vendor',
    'Relative',
    'Delivery',
    'Maintenance',
    'Alumni',
  ];

  static const List<String> _statuses = [
    'All Status',
    'Inside',
    'Checked Out',
    'Overstay',
    'Blocked',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(visitorsProvider);
    final notifier = ref.read(visitorsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final searchWidth = isMobile ? constraints.maxWidth : 280.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 8),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 1. Search Bar
              SizedBox(
                width: searchWidth,
                height: 38,
            child: TextField(
              onChanged: notifier.setSearchQuery,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Search by name, ID, purpose, host, vehicle no...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
              ),
            ),
          ),

          // 2. Location Dropdown
          _buildDropdown(
            value: state.selectedLocation,
            items: state.availableLocations,
            onChanged: (val) {
              if (val != null) notifier.setLocationFilter(val);
            },
            isDark: isDark,
          ),

          // 3. Visitor Type Dropdown
          _buildDropdown(
            value: state.selectedCategory,
            items: _visitorTypes,
            onChanged: (val) {
              if (val != null) notifier.setCategoryFilter(val);
            },
            isDark: isDark,
          ),

          // 4. Status Dropdown
          _buildDropdown(
            value: state.selectedStatus,
            items: _statuses,
            onChanged: (val) {
              if (val != null) notifier.setStatusFilter(val);
            },
            isDark: isDark,
          ),

          // 5. Date Range Selector
          InkWell(
            onTap: () => showVisitorDateRangeDialog(context, ref),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
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
                  const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    state.selectedDateRange,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),

          // 6. More Filters Button
          InkWell(
            onTap: onMoreFilters ??
                () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const VisitorsMoreFiltersDialog(),
                  );
                },
            borderRadius: BorderRadius.circular(8),
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
                  const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    'More Filters',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 7. Register Visitor Primary Blue Button
          ElevatedButton.icon(
            onPressed: onRegisterVisitor,
            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Register Visitor',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          // 8. More Options Menu (3-dots)
          PopupMenuButton<String>(
            tooltip: 'More Actions & Quick Links',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (val) {
              if (val == 'refresh') {
                notifier.fetchVisits();
                notifier.fetchKPIs();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Visitors list and statistics refreshed.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } else if (val == 'scan_pass') {
                showDialog(
                  context: context,
                  builder: (ctx) => const VisitorQrScannerDialog(),
                );
              } else if (val == 'profiles_passes') {
                showDialog(
                  context: context,
                  builder: (ctx) => const VisitorProfilesGatePassDialog(),
                );
              } else if (val == 'reset') {
                notifier.resetFilters();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All filters reset to default.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text('Refresh Grid'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'scan_pass',
                child: Row(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Text('Scan QR Pass'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'profiles_passes',
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 16, color: Color(0xFF0284C7)),
                    SizedBox(width: 8),
                    Text('Visitor Profiles & Passes'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt_rounded, size: 16, color: Color(0xFFEF4444)),
                    SizedBox(width: 8),
                    Text('Reset All Filters'),
                  ],
                ),
              ),
            ],
            child: Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: const Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    final validValue = items.contains(value) ? value : items.first;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validValue,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          onChanged: onChanged,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ),
    );
  }
}
