import 'package:flutter/material.dart';
import '../../models/space_booking_models.dart';

class SpaceBookingKpisBar extends StatelessWidget {
  final SpaceBookingKpis kpis;
  final Function(String category)? onCardTap;

  const SpaceBookingKpisBar({
    super.key,
    required this.kpis,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cards = [
      _buildKpiCard(
        title: 'Total Bookings',
        value: '${kpis.totalBookings}',
        subtitle: '↑ ${kpis.totalChangePct.toStringAsFixed(0)}%',
        isSubPositive: true,
        icon: Icons.calendar_month_outlined,
        iconColor: const Color(0xFF0284C7),
        iconBgColor: isDark ? const Color(0xFF0284C7).withValues(alpha: 0.2) : const Color(0xFFE0F2FE),
        isDark: isDark,
        onTap: () => onCardTap?.call('All'),
      ),
      _buildKpiCard(
        title: 'Confirmed',
        value: '${kpis.confirmedBookings}',
        subtitle: '(${kpis.confirmedPct.toStringAsFixed(1)}%)',
        isSubPositive: null,
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xFF16A34A),
        iconBgColor: isDark ? const Color(0xFF16A34A).withValues(alpha: 0.2) : const Color(0xFFDCFCE7),
        isDark: isDark,
        onTap: () => onCardTap?.call('Confirmed'),
      ),
      _buildKpiCard(
        title: 'Pending',
        value: '${kpis.pendingBookings}',
        subtitle: '(${kpis.pendingPct.toStringAsFixed(1)}%)',
        isSubPositive: null,
        icon: Icons.access_time,
        iconColor: const Color(0xFFD97706),
        iconBgColor: isDark ? const Color(0xFFD97706).withValues(alpha: 0.2) : const Color(0xFFFEF3C7),
        isDark: isDark,
        onTap: () => onCardTap?.call('Pending'),
      ),
      _buildKpiCard(
        title: 'Rejected',
        value: '${kpis.rejectedBookings}',
        subtitle: '(${kpis.rejectedPct.toStringAsFixed(1)}%)',
        isSubPositive: null,
        icon: Icons.cancel_outlined,
        iconColor: const Color(0xFFDC2626),
        iconBgColor: isDark ? const Color(0xFFDC2626).withValues(alpha: 0.2) : const Color(0xFFFEE2E2),
        isDark: isDark,
        onTap: () => onCardTap?.call('Rejected'),
      ),
      _buildKpiCard(
        title: 'Current Usage',
        value: '${kpis.currentUsageSpaces} Spaces',
        subtitle: '',
        isSubPositive: null,
        icon: Icons.groups_outlined,
        iconColor: const Color(0xFF7C3AED),
        iconBgColor: isDark ? const Color(0xFF7C3AED).withValues(alpha: 0.2) : const Color(0xFFEDE9FE),
        isDark: isDark,
        onTap: () => onCardTap?.call('Usage'),
      ),
      _buildKpiCard(
        title: 'Utilization',
        value: '${kpis.utilizationRate.toStringAsFixed(1)}%',
        subtitle: '↑ ${kpis.utilizationChangePct.toStringAsFixed(1)}%',
        isSubPositive: true,
        icon: Icons.pie_chart_outline,
        iconColor: const Color(0xFF059669),
        iconBgColor: isDark ? const Color(0xFF059669).withValues(alpha: 0.2) : const Color(0xFFD1FAE5),
        isDark: isDark,
        onTap: () => onCardTap?.call('Reports'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1050) {
          return Row(
            children: cards
                .map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: c,
                      ),
                    ))
                .toList(),
          );
        } else {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: cards
                  .map((c) => Container(
                        width: 175,
                        margin: const EdgeInsets.only(right: 10),
                        child: c,
                      ))
                  .toList(),
            ),
          );
        }
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required bool? isSubPositive,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSubPositive == true
                              ? const Color(0xFF16A34A)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }
}
