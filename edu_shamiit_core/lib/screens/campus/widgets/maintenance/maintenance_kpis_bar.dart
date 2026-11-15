import 'package:flutter/material.dart';
import '../../models/maintenance_models.dart';

class MaintenanceKpisBar extends StatelessWidget {
  final MaintenanceKpis kpis;

  const MaintenanceKpisBar({
    super.key,
    required this.kpis,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cards = [
      _buildKpiCard(
        title: 'Total Requests',
        value: '${kpis.totalRequests}',
        subtitle: '↑ ${kpis.totalChangePct.toStringAsFixed(0)}%',
        isSubPositive: true,
        icon: Icons.build_circle_outlined,
        iconColor: const Color(0xFF0284C7),
        iconBgColor: isDark ? const Color(0xFF0284C7).withValues(alpha: 0.2) : const Color(0xFFE0F2FE),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Resolved',
        value: '${kpis.resolved}',
        subtitle: '(${kpis.resolvedPct.toStringAsFixed(1)}%)',
        isSubPositive: true,
        icon: Icons.check_circle_outline_rounded,
        iconColor: const Color(0xFF16A34A),
        iconBgColor: isDark ? const Color(0xFF16A34A).withValues(alpha: 0.2) : const Color(0xFFDCFCE7),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'In Progress',
        value: '${kpis.inProgress}',
        subtitle: '(${kpis.inProgressPct.toStringAsFixed(1)}%)',
        isSubPositive: null,
        icon: Icons.access_time_rounded,
        iconColor: const Color(0xFFF59E0B),
        iconBgColor: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : const Color(0xFFFEF3C7),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Overdue',
        value: '${kpis.overdue}',
        subtitle: '(${kpis.overduePct.toStringAsFixed(1)}%)',
        isSubPositive: false,
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFEF4444),
        iconBgColor: isDark ? const Color(0xFFEF4444).withValues(alpha: 0.2) : const Color(0xFFFEE2E2),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Scheduled',
        value: '${kpis.scheduled}',
        subtitle: '',
        isSubPositive: null,
        icon: Icons.calendar_month_outlined,
        iconColor: const Color(0xFF8B5CF6),
        iconBgColor: isDark ? const Color(0xFF8B5CF6).withValues(alpha: 0.2) : const Color(0xFFEDE9FE),
        isDark: isDark,
      ),
      _buildKpiCard(
        title: 'Avg. Resolution Time',
        value: '${kpis.avgResolutionDays} Days',
        subtitle: '↓ ${kpis.resolutionChangePct.abs().toStringAsFixed(0)}%',
        isSubPositive: true,
        icon: Icons.timelapse_rounded,
        iconColor: const Color(0xFF0284C7),
        iconBgColor: isDark ? const Color(0xFF0284C7).withValues(alpha: 0.2) : const Color(0xFFE0F2FE),
        isDark: isDark,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1050) {
          return Row(
            children: cards.map((c) => Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: c,
            ))).toList(),
          );
        } else {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: cards.map((c) => SizedBox(width: 175, child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: c,
              ))).toList(),
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
  }) {
    Color subColor = const Color(0xFF64748B);
    if (isSubPositive == true) {
      subColor = const Color(0xFF16A34A);
    } else if (isSubPositive == false) {
      subColor = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: subColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
