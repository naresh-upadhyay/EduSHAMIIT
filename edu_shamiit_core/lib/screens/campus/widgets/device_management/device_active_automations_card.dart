import 'package:flutter/material.dart';
import '../../models/device_management_models.dart';

class DeviceActiveAutomationsCard extends StatelessWidget {
  final List<ActiveAutomationItem> automations;
  final VoidCallback onViewAll;

  const DeviceActiveAutomationsCard({
    super.key,
    required this.automations,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultList = automations.isNotEmpty
        ? automations
        : [
            const ActiveAutomationItem(
              id: '1',
              name: 'Auto off lights (Unoccupied)',
              description: 'Turn off classroom lights after 2 minutes of no occupancy',
              triggerType: 'occupancy',
              isActive: true,
            ),
            const ActiveAutomationItem(
              id: '2',
              name: 'AC Schedule (Academic Hours)',
              description: 'Run AC from 08:00 AM - 05:00 PM (Mon - Fri)',
              triggerType: 'schedule',
              isActive: true,
            ),
            const ActiveAutomationItem(
              id: '3',
              name: 'Low Power Mode (After Hours)',
              description: 'Reduce non-critical device power after 08:00 PM',
              triggerType: 'schedule',
              isActive: true,
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
                const Icon(Icons.auto_mode_rounded, color: Color(0xFF2563EB), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Active Automations (128)',
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

          // 3 Automations List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: defaultList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = defaultList[index];
                IconData icon = Icons.check_circle_outline_rounded;
                Color iconColor = const Color(0xFF16A34A);

                if (item.triggerType == 'schedule') {
                  if (item.name.contains('AC')) {
                    icon = Icons.calendar_month_outlined;
                    iconColor = const Color(0xFF0284C7);
                  } else {
                    icon = Icons.bolt_rounded;
                    iconColor = const Color(0xFFD97706);
                  }
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 16, color: iconColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              item.description,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
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
