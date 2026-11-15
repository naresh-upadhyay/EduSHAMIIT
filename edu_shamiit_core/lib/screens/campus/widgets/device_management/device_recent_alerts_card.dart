import 'package:flutter/material.dart';
import '../../models/device_management_models.dart';

class DeviceRecentAlertsCard extends StatelessWidget {
  final List<DeviceAlertItem> alerts;
  final VoidCallback onViewAll;

  const DeviceRecentAlertsCard({
    super.key,
    required this.alerts,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultAlerts = [
      _AlertData(
        title: 'Device Offline - Projector-B3-201',
        subtitle: 'No response for 15 minutes',
        time: '10:24 AM',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFDC2626),
      ),
      _AlertData(
        title: 'High Power Usage - Lab-B2',
        subtitle: '22% higher than normal',
        time: '09:48 AM',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFD97706),
      ),
      _AlertData(
        title: 'Device Fault - AC-B4-105',
        subtitle: 'Temperature sensor error',
        time: '09:15 AM',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFD97706),
      ),
      _AlertData(
        title: 'New Device Added - LED-B6-Hall',
        subtitle: 'Registered and online',
        time: '08:52 AM',
        icon: Icons.info_outline_rounded,
        color: const Color(0xFF0284C7),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recent Alerts & Events',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onViewAll,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // 4 Alert Items
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: defaultAlerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = defaultAlerts[index];

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.icon, size: 15, color: item.color),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item.subtitle,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.time,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertData {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color color;

  _AlertData({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.color,
  });
}
