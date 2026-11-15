import 'package:flutter/material.dart';
import '../models/campus_models.dart';

class CampusKpiCards extends StatelessWidget {
  final CampusKpis kpis;

  const CampusKpiCards({
    super.key,
    required this.kpis,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        // On very wide screens, 6 in a row; on medium, 3x2; on small, horizontal scroll
        if (screenWidth > 1150) {
          return Row(
            children: [
              Expanded(child: _buildCard(
                context,
                title: 'Total Buildings',
                value: kpis.totalBuildings.toString(),
                icon: Icons.domain_rounded,
                iconColor: primaryColor,
                iconBgColor: primaryColor.withValues(alpha: 0.12),
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildCard(
                context,
                title: 'Total Floors',
                value: kpis.totalFloors.toString(),
                icon: Icons.layers_rounded,
                iconColor: const Color(0xFF8B5CF6),
                iconBgColor: const Color(0xFFF5F3FF),
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildCard(
                context,
                title: 'Total Rooms',
                value: kpis.totalRooms.toString(),
                icon: Icons.meeting_room_rounded,
                iconColor: const Color(0xFF7C3AED),
                iconBgColor: const Color(0xFFFAF5FF),
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildCard(
                context,
                title: 'Total Capacity',
                value: _formatNumber(kpis.totalCapacity),
                icon: Icons.group_rounded,
                iconColor: const Color(0xFF10B981),
                iconBgColor: const Color(0xFFECFDF5),
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildCard(
                context,
                title: 'Occupied',
                value: '${_formatNumber(kpis.occupiedCapacity)} (${kpis.occupancyRate}%)',
                icon: Icons.assignment_turned_in_rounded,
                iconColor: const Color(0xFF0284C7),
                iconBgColor: const Color(0xFFF0F9FF),
                valueColor: const Color(0xFF059669),
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildCard(
                context,
                title: 'Available',
                value: '${_formatNumber(kpis.availableCapacity)} (${(100.0 - kpis.occupancyRate).toStringAsFixed(1)}%)',
                icon: Icons.chair_rounded,
                iconColor: const Color(0xFFF59E0B),
                iconBgColor: const Color(0xFFFFFBEB),
                valueColor: const Color(0xFFD97706),
              )),
            ],
          );
        } else {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(width: 190, child: _buildCard(
                  context,
                  title: 'Total Buildings',
                  value: kpis.totalBuildings.toString(),
                  icon: Icons.domain_rounded,
                  iconColor: primaryColor,
                  iconBgColor: primaryColor.withValues(alpha: 0.12),
                )),
                const SizedBox(width: 10),
                SizedBox(width: 190, child: _buildCard(
                  context,
                  title: 'Total Floors',
                  value: kpis.totalFloors.toString(),
                  icon: Icons.layers_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBgColor: const Color(0xFFF5F3FF),
                )),
                const SizedBox(width: 10),
                SizedBox(width: 190, child: _buildCard(
                  context,
                  title: 'Total Rooms',
                  value: kpis.totalRooms.toString(),
                  icon: Icons.meeting_room_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  iconBgColor: const Color(0xFFFAF5FF),
                )),
                const SizedBox(width: 10),
                SizedBox(width: 190, child: _buildCard(
                  context,
                  title: 'Total Capacity',
                  value: _formatNumber(kpis.totalCapacity),
                  icon: Icons.group_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBgColor: const Color(0xFFECFDF5),
                )),
                const SizedBox(width: 10),
                SizedBox(width: 220, child: _buildCard(
                  context,
                  title: 'Occupied',
                  value: '${_formatNumber(kpis.occupiedCapacity)} (${kpis.occupancyRate}%)',
                  icon: Icons.assignment_turned_in_rounded,
                  iconColor: const Color(0xFF0284C7),
                  iconBgColor: const Color(0xFFF0F9FF),
                  valueColor: const Color(0xFF059669),
                )),
                const SizedBox(width: 10),
                SizedBox(width: 220, child: _buildCard(
                  context,
                  title: 'Available',
                  value: '${_formatNumber(kpis.availableCapacity)} (${(100.0 - kpis.occupancyRate).toStringAsFixed(1)}%)',
                  icon: Icons.chair_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  iconBgColor: const Color(0xFFFFFBEB),
                  valueColor: const Color(0xFFD97706),
                )),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    Color? valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isDark ? iconColor.withValues(alpha: 0.15) : iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 22),
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
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int val) {
    if (val >= 1000) {
      final s = val.toString();
      final len = s.length;
      return '${s.substring(0, len - 3)},${s.substring(len - 3)}';
    }
    return val.toString();
  }
}
