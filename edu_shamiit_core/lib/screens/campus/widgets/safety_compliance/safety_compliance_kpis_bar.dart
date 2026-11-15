import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/safety_compliance_provider.dart';

class SafetyComplianceKpisBar extends ConsumerWidget {
  const SafetyComplianceKpisBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(safetyComplianceProvider);
    final kpis = state.kpis;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cards = [
      _KpiCardData(
        title: 'Safety Compliance',
        value: '${kpis.overallCompliancePct.toStringAsFixed(1)}%',
        badge: '+${kpis.complianceChangePct}%',
        badgeColor: const Color(0xFF10B981),
        icon: Icons.verified_user_rounded,
        iconColor: const Color(0xFF10B981),
        iconBg: const Color(0xFF10B981).withValues(alpha: 0.15),
      ),
      _KpiCardData(
        title: 'Statutory Certificates',
        value: '${kpis.activeCertificates}',
        badge: '${kpis.expiringCertificates} Expiring',
        badgeColor: kpis.expiringCertificates > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
        icon: Icons.article_rounded,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFF2563EB).withValues(alpha: 0.15),
      ),
      _KpiCardData(
        title: 'Safety Inspections',
        value: '${kpis.totalInspections}',
        badge: '${kpis.inspectionsPassedPct.toStringAsFixed(1)}% Passed',
        badgeColor: const Color(0xFF10B981),
        icon: Icons.fact_check_rounded,
        iconColor: const Color(0xFF8B5CF6),
        iconBg: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
      ),
      _KpiCardData(
        title: 'Active Incidents',
        value: '${kpis.openIncidents}',
        badge: kpis.criticalIncidents > 0 ? '${kpis.criticalIncidents} Critical' : '0 Critical',
        badgeColor: kpis.criticalIncidents > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFEF4444),
        iconBg: const Color(0xFFEF4444).withValues(alpha: 0.15),
      ),
      _KpiCardData(
        title: 'Emergency Drills',
        value: '${kpis.drillsConducted}',
        badge: '${kpis.avgEvacuationSeconds.toStringAsFixed(0)}s Avg Evac',
        badgeColor: const Color(0xFF06B6D4),
        icon: Icons.campaign_rounded,
        iconColor: const Color(0xFF06B6D4),
        iconBg: const Color(0xFF06B6D4).withValues(alpha: 0.15),
      ),
      _KpiCardData(
        title: 'SOS Readiness',
        value: 'Ready',
        badge: kpis.sosReadinessStatus,
        badgeColor: const Color(0xFF10B981),
        icon: Icons.shield_rounded,
        iconColor: const Color(0xFFF59E0B),
        iconBg: const Color(0xFFF59E0B).withValues(alpha: 0.15),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        int crossAxisCount = 6;
        if (screenWidth < 420) {
          crossAxisCount = 1;
        } else if (screenWidth < 680) {
          crossAxisCount = 2;
        } else if (screenWidth < 980) {
          crossAxisCount = 3;
        } else if (screenWidth < 1250) {
          crossAxisCount = 4;
        }

        final double cardWidth = (screenWidth - (crossAxisCount - 1) * 12) / crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((data) => SizedBox(
            width: cardWidth,
            child: _buildKpiCard(data, isDark),
          )).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(_KpiCardData data, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
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
              color: data.iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, size: 20, color: data.iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      data.value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: data.badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        data.badge,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: data.badgeColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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

class _KpiCardData {
  final String title;
  final String value;
  final String badge;
  final Color badgeColor;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  _KpiCardData({
    required this.title,
    required this.value,
    required this.badge,
    required this.badgeColor,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });
}
