import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/maintenance_provider.dart';

class MaintenanceRightPanel extends ConsumerWidget {
  final VoidCallback? onUpdateStatus;
  final VoidCallback? onAssignTechnician;
  final VoidCallback? onScheduleMaintenance;
  final VoidCallback? onCreatePlan;
  final VoidCallback? onManageAssets;
  final VoidCallback? onManageVendors;

  const MaintenanceRightPanel({
    super.key,
    this.onUpdateStatus,
    this.onAssignTechnician,
    this.onScheduleMaintenance,
    this.onCreatePlan,
    this.onManageAssets,
    this.onManageVendors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(maintenanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final item = state.inspectedRequest ??
        (state.requests.records.isNotEmpty ? state.requests.records.first : null);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Card: Request Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0284C7).withValues(alpha: 0.2) : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.build_rounded, size: 16, color: Color(0xFF0284C7)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Request Details',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (item == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No request selected', style: TextStyle(color: textMuted, fontSize: 12)),
                    ),
                  )
                else ...[
                  _detailRow('Request ID', item.requestCode, isBold: true, isDark: isDark),
                  _detailRow('Title', item.title, isBold: true, isDark: isDark),
                  _detailRow('Location', item.locationDisplay.contains('Academic') ? item.locationDisplay : 'B1 - Academic Block / ${item.locationDisplay}', isDark: isDark),
                  _detailRow('Type', '${item.requestType} (${item.requestType == 'HVAC' ? 'AC' : 'General'})', isDark: isDark),
                  _detailRow('Priority', item.priority, isBadge: true, badgeBg: const Color(0xFFFEE2E2), badgeText: const Color(0xFFDC2626), isDark: isDark),
                  _detailRow('Status', item.status, isBadge: true, badgeBg: const Color(0xFFE0F2FE), badgeText: const Color(0xFF0284C7), isDark: isDark),
                  _detailRow('Reported By', '${item.reportedByName} (${item.reportedByRole})', isDark: isDark),
                  _detailRow('Reported On', '20 Mar 2026, 10:24 AM', isDark: isDark),
                  const SizedBox(height: 14),

                  // Actions Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onUpdateStatus,
                          icon: const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white),
                          label: const Text('Update Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onAssignTechnician,
                          icon: const Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF2563EB)),
                          label: const Text('Assign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2563EB)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Bottom Card: Quick Actions 2x2 Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      'Quick Actions',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2x2 Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        title: 'Schedule\nMaintenance',
                        icon: Icons.calendar_today_outlined,
                        onTap: onScheduleMaintenance,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionTile(
                        title: 'Create\nMaintenance Plan',
                        icon: Icons.fact_check_outlined,
                        onTap: onCreatePlan,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        title: 'Manage\nAssets',
                        icon: Icons.inventory_2_outlined,
                        onTap: onManageAssets,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionTile(
                        title: 'Manage\nService Vendors',
                        icon: Icons.handshake_outlined,
                        onTap: onManageVendors,
                        isDark: isDark,
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

  Widget _detailRow(String label, String value, {
    bool isBold = false,
    bool isBadge = false,
    Color? badgeBg,
    Color? badgeText,
    required bool isDark,
  }) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Flexible(
            child: isBadge
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: badgeBg ?? const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: badgeText ?? const Color(0xFF2563EB),
                      ),
                    ),
                  )
                : Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF2563EB)),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
