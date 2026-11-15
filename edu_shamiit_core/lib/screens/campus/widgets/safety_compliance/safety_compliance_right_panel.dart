import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/safety_compliance_models.dart';
import '../../providers/safety_compliance_provider.dart';

class SafetyComplianceRightPanel extends ConsumerWidget {
  final VoidCallback onOpenScheduleDrill;
  final VoidCallback onOpenAddCertificate;
  final VoidCallback onOpenReportIncident;
  final double? width;

  const SafetyComplianceRightPanel({
    super.key,
    required this.onOpenScheduleDrill,
    required this.onOpenAddCertificate,
    required this.onOpenReportIncident,
    this.width,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(safetyComplianceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Live SOS Readiness Card
          _buildSosReadinessCard(state.kpis, isDark),
          const SizedBox(height: 14),

          // 2. Upcoming Certificate Expiry Alerts
          _buildUpcomingCertificatesCard(state.certificates.records, isDark),
          const SizedBox(height: 14),

          // 3. Quick Actions 2x2 Grid
          _buildQuickActionsCard(ref, isDark),
        ],
      ),
    );
  }

  Widget _buildSosReadinessCard(SafetyComplianceKpis kpis, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SOS Readiness',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ONLINE',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildStatusMetric('Emergency Sirens', 'Operational (12 zones)', const Color(0xFF10B981), isDark),
          const SizedBox(height: 6),
          _buildStatusMetric('Fire Main Pressure', '6.4 Bar (Optimal)', const Color(0xFF10B981), isDark),
          const SizedBox(height: 6),
          _buildStatusMetric('Backup DG Genset', 'Auto-Start Ready', const Color(0xFF10B981), isDark),
          const SizedBox(height: 6),
          _buildStatusMetric('Assembly Area', 'Turf & Central Lawn', const Color(0xFF2563EB), isDark),
        ],
      ),
    );
  }

  Widget _buildStatusMetric(String label, String value, Color color, bool isDark) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: textMuted),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          flex: 5,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingCertificatesCard(List<ComplianceCertificateItem> certs, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final upcoming = certs.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Certificates Expiry Tracking',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.access_time_rounded, size: 16, color: textMuted),
            ],
          ),
          const SizedBox(height: 10),

          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('All certificates fully up to date', style: TextStyle(fontSize: 11.5, color: textMuted)),
              ),
            )
          else
            ...upcoming.map((c) {
              final isExpiring = c.daysToExpiry <= 45;
              final pillColor = isExpiring ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              c.issuingAuthority,
                              style: TextStyle(fontSize: 10, color: textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: pillColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          c.daysToExpiry > 0 ? '${c.daysToExpiry}d' : 'Expired',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: pillColor),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(WidgetRef ref, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.campaign_rounded,
                  label: 'Schedule Drill',
                  onTap: onOpenScheduleDrill,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.upload_file_rounded,
                  label: 'Upload NOC',
                  onTap: onOpenAddCertificate,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.emergency_share_rounded,
                  label: 'Report SOS',
                  color: const Color(0xFFDC2626),
                  onTap: onOpenReportIncident,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  icon: Icons.file_download_outlined,
                  label: 'Safety Report',
                  onTap: () {
                    ref.read(safetyComplianceProvider.notifier).exportData('inspections');
                  },
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    Color color = const Color(0xFF2563EB),
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
