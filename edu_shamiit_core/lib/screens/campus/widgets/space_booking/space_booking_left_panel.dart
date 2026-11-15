import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/space_booking_provider.dart';

class SpaceBookingLeftPanel extends ConsumerStatefulWidget {
  final VoidCallback onOpenBookModal;
  final VoidCallback? onOpenRecurringModal;
  final bool isCompact;

  const SpaceBookingLeftPanel({
    super.key,
    required this.onOpenBookModal,
    this.onOpenRecurringModal,
    this.isCompact = false,
  });

  @override
  ConsumerState<SpaceBookingLeftPanel> createState() => _SpaceBookingLeftPanelState();
}

class _SpaceBookingLeftPanelState extends ConsumerState<SpaceBookingLeftPanel> {
  String _selectedBuilding = 'all';
  String _selectedSpaceType = 'All';
  String _selectedCapacity = 'Any Capacity';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spaceBookingProvider);
    final notifier = ref.read(spaceBookingProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

    return Container(
      width: widget.isCompact ? null : 240,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary Action Button: + Book a Space
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: widget.onOpenBookModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Book a Space',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Navigation Links
          _buildNavItem(
            icon: Icons.assignment_outlined,
            label: 'My Bookings',
            isSelected: state.selectedNav == 'My Bookings',
            badgeCount: null,
            isDark: isDark,
            onTap: () => notifier.setSelectedNav('My Bookings'),
          ),
          _buildNavItem(
            icon: Icons.access_time,
            label: 'Pending Requests',
            isSelected: state.selectedNav == 'Pending Requests',
            badgeCount: state.kpis.pendingBookings,
            badgeColor: isDark ? const Color(0xFF312E81) : const Color(0xFFE0E7FF),
            badgeTextColor: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
            isDark: isDark,
            onTap: () => notifier.setSelectedNav('Pending Requests'),
          ),
          _buildNavItem(
            icon: Icons.check_circle_outline,
            label: 'Approved Bookings',
            isSelected: state.selectedNav == 'Approved Bookings',
            badgeCount: state.kpis.confirmedBookings,
            badgeColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
            badgeTextColor: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
            isDark: isDark,
            onTap: () => notifier.setSelectedNav('Approved Bookings'),
          ),
          _buildNavItem(
            icon: Icons.cancel_outlined,
            label: 'Rejected Bookings',
            isSelected: state.selectedNav == 'Rejected Bookings',
            badgeCount: state.kpis.rejectedBookings,
            badgeColor: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
            badgeTextColor: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
            isDark: isDark,
            onTap: () => notifier.setSelectedNav('Rejected Bookings'),
          ),
          _buildNavItem(
            icon: Icons.sync,
            label: 'Recurring Bookings',
            isSelected: state.selectedNav == 'Recurring Bookings',
            badgeCount: null,
            isDark: isDark,
            onTap: () {
              notifier.setSelectedNav('Recurring Bookings');
              if (widget.onOpenRecurringModal != null) {
                widget.onOpenRecurringModal!();
              }
            },
          ),
          _buildNavItem(
            icon: Icons.calendar_month_outlined,
            label: 'Booking Calendar',
            isSelected: state.selectedNav == 'Booking Calendar',
            badgeCount: null,
            isDark: isDark,
            onTap: () => notifier.setSelectedNav('Booking Calendar'),
          ),
          _buildNavItem(
            icon: Icons.bar_chart_outlined,
            label: 'Usage & Reports',
            isSelected: state.selectedNav == 'Usage & Reports',
            badgeCount: null,
            isDark: isDark,
            onTap: () => notifier.setSelectedNav('Usage & Reports'),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            child: Divider(color: cardBorder, height: 1),
          ),

          // Quick Filters Section Header
          Row(
            children: [
              Icon(Icons.filter_alt_outlined, size: 18, color: textPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quick Filters',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filter: Building
          _buildFilterLabel('Building', textSecondary),
          _buildDropdown(
            value: _selectedBuilding,
            isDark: isDark,
            inputBg: inputBg,
            inputBorder: inputBorder,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Buildings')),
              DropdownMenuItem(value: 'b1', child: Text('B1 - Academic Block')),
              DropdownMenuItem(value: 'b2', child: Text('B2 - Senior Block')),
              DropdownMenuItem(value: 'b3', child: Text('B3 - Library Block')),
              DropdownMenuItem(value: 'b4', child: Text('B4 - Auditorium')),
              DropdownMenuItem(value: 'b5', child: Text('B5 - Admin Block')),
              DropdownMenuItem(value: 'b6', child: Text('B6 - Sports Complex')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedBuilding = val);
            },
          ),
          const SizedBox(height: 12),

          // Filter: Space Type
          _buildFilterLabel('Space Type', textSecondary),
          _buildDropdown(
            value: _selectedSpaceType,
            isDark: isDark,
            inputBg: inputBg,
            inputBorder: inputBorder,
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All Space Types')),
              DropdownMenuItem(value: 'Classroom', child: Text('Classroom')),
              DropdownMenuItem(value: 'Auditorium', child: Text('Auditorium')),
              DropdownMenuItem(value: 'Meeting Room', child: Text('Meeting Room')),
              DropdownMenuItem(value: 'Lab', child: Text('Lab')),
              DropdownMenuItem(value: 'Sports', child: Text('Sports')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedSpaceType = val);
            },
          ),
          const SizedBox(height: 12),

          // Filter: Capacity
          _buildFilterLabel('Capacity', textSecondary),
          _buildDropdown(
            value: _selectedCapacity,
            isDark: isDark,
            inputBg: inputBg,
            inputBorder: inputBorder,
            items: const [
              DropdownMenuItem(value: 'Any Capacity', child: Text('Any Capacity')),
              DropdownMenuItem(value: '1-20', child: Text('1 - 20')),
              DropdownMenuItem(value: '21-40', child: Text('21 - 40')),
              DropdownMenuItem(value: '41-100', child: Text('41 - 100')),
              DropdownMenuItem(value: '100+', child: Text('100+')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedCapacity = val);
            },
          ),
          const SizedBox(height: 12),

          // Filter: Date Range
          _buildFilterLabel('Date Range', textSecondary),
          InkWell(
            onTap: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2025, 1, 1),
                lastDate: DateTime(2028, 12, 31),
                initialDateRange: DateTimeRange(
                  start: state.dateRangeFrom ?? DateTime(2026, 3, 15),
                  end: state.dateRangeTo ?? DateTime(2026, 3, 21),
                ),
              );
              if (range != null) {
                notifier.applyQuickFilters(dateFrom: range.start, dateTo: range.end);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: inputBg,
                border: Border.all(color: inputBorder),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '15 Mar 2026 - 21 Mar 2026',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Apply Filter Button
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: () {
                notifier.applyQuickFilters(
                  buildingId: _selectedBuilding,
                  spaceType: _selectedSpaceType,
                  capacity: _selectedCapacity,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              icon: const Icon(Icons.filter_alt_outlined, size: 16),
              label: const Text(
                'Apply Filter',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required int? badgeCount,
    Color? badgeColor,
    Color? badgeTextColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final selBg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.45) : const Color(0xFFEFF6FF);
    final selText = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A);
    final unselText = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final iconColor = isSelected ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Material(
        color: isSelected ? selBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.5),
            child: Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? selText : unselText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badgeCount != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: badgeColor ?? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeTextColor ?? (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required bool isDark,
    required Color inputBg,
    required Color inputBorder,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
