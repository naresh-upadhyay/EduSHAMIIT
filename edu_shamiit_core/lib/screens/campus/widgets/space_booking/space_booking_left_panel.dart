import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/space_booking_provider.dart';

class SpaceBookingLeftPanel extends ConsumerWidget {
  final VoidCallback onOpenBookModal;
  final bool isCompact;

  const SpaceBookingLeftPanel({
    super.key,
    required this.onOpenBookModal,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spaceBookingProvider);
    final notifier = ref.read(spaceBookingProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: isCompact ? null : 240,
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
              onPressed: onOpenBookModal,
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

          // Primary Navigation Links (Clean 3-Section Architecture)
          _buildNavItem(
            icon: Icons.grid_view_rounded,
            label: 'Booking Spaces',
            isSelected: state.selectedNav == 'Booking Spaces' ||
                state.selectedNav == 'Booking Space' ||
                state.selectedNav == 'Booking Calendar',
            badgeCount: null,
            isDark: isDark,
            onTap: () => notifier.setSelectedNav('Booking Spaces'),
          ),
          _buildNavItem(
            icon: Icons.assignment_outlined,
            label: 'Booking Requests',
            isSelected: state.selectedNav == 'Booking Requests' ||
                state.selectedNav == 'Pending Requests' ||
                state.selectedNav == 'Approved Bookings' ||
                state.selectedNav == 'Rejected Bookings' ||
                state.selectedNav == 'My Bookings',
            badgeCount: state.kpis.pendingBookings,
            badgeColor: isDark ? const Color(0xFF312E81) : const Color(0xFFE0E7FF),
            badgeTextColor: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
            isDark: isDark,
            onTap: () => notifier.setSelectedNav('Booking Requests'),
          ),
          _buildNavItem(
            icon: Icons.bar_chart_outlined,
            label: 'Usage & Reports',
            isSelected: state.selectedNav == 'Usage & Reports',
            badgeCount: null,
            isDark: isDark,
            onTap: () => notifier.setSelectedNav('Usage & Reports'),
          ),

          const SizedBox(height: 16),
          Divider(color: cardBorder, height: 1),
          const SizedBox(height: 16),

          // Institutional Capacity Footnote
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 15, color: textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${state.bookableRooms.length} bookable venues active across campus',
                    style: TextStyle(fontSize: 11, color: textSecondary, height: 1.3),
                  ),
                ),
              ],
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
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 9.0),
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
                if (badgeCount != null && badgeCount > 0) ...[
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
}
