import 'package:flutter/material.dart';
import '../../models/device_management_models.dart';

class DeviceManagementKpisBar extends StatelessWidget {
  final DeviceManagementKpis kpis;

  const DeviceManagementKpisBar({
    super.key,
    required this.kpis,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cards = [
      _KpiItem(
        title: 'Total Devices',
        value: kpis.totalDevices.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},'),
        icon: Icons.layers_outlined,
        color: const Color(0xFF2563EB),
      ),
      _KpiItem(
        title: 'Online',
        value: '${kpis.online.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} (${kpis.onlinePercentage}%)',
        icon: Icons.check_circle_outline,
        color: const Color(0xFF16A34A),
      ),
      _KpiItem(
        title: 'Offline',
        value: '${kpis.offline} (${(100 - kpis.onlinePercentage).toStringAsFixed(1)}%)',
        icon: Icons.power_settings_new_rounded,
        color: const Color(0xFFDC2626),
      ),
      _KpiItem(
        title: 'Device Types',
        value: '${kpis.deviceTypes}',
        icon: Icons.grid_view_rounded,
        color: const Color(0xFF9333EA),
      ),
      _KpiItem(
        title: 'Locations',
        value: kpis.locationsSummary,
        icon: Icons.apartment_rounded,
        color: const Color(0xFF0891B2),
      ),
      _KpiItem(
        title: 'Automations',
        value: '${kpis.automationsActive} Active',
        icon: Icons.auto_mode_rounded,
        color: const Color(0xFF7C3AED),
      ),
      _KpiItem(
        title: 'Schedules',
        value: '${kpis.schedulesCount}',
        icon: Icons.calendar_month_outlined,
        color: const Color(0xFF0284C7),
      ),
      _KpiItem(
        title: 'Alerts',
        value: '${kpis.alertsCount}',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFD97706),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1150) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: cards.map((c) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SizedBox(width: 120, child: _buildCard(context, c, isDark)),
              )).toList(),
            ),
          );
        }

        return Row(
          children: cards.map((c) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: _buildCard(context, c, isDark),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, _KpiItem item, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(item.icon, color: item.color, size: 15),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _KpiItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
