import 'package:flutter/material.dart';

class VisitorsQuickActions extends StatelessWidget {
  final VoidCallback onRegisterVisitor;
  final VoidCallback onCheckInWalkIn;
  final VoidCallback onScheduleVisit;
  final VoidCallback onGenerateGatePass;
  final VoidCallback onScanQrPass;
  final VoidCallback onVisitorLogReport;

  const VisitorsQuickActions({
    super.key,
    required this.onRegisterVisitor,
    required this.onCheckInWalkIn,
    required this.onScheduleVisit,
    required this.onGenerateGatePass,
    required this.onScanQrPass,
    required this.onVisitorLogReport,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildActionCard(
              title: 'Register Visitor',
              icon: Icons.add_rounded,
              color: const Color(0xFF2563EB),
              bg: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : const Color(0xFFEFF6FF),
              onTap: onRegisterVisitor,
              isDark: isDark,
            ),
            _buildActionCard(
              title: 'Check-In (Walk-In)',
              icon: Icons.published_with_changes_rounded,
              color: const Color(0xFF16A34A),
              bg: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.2) : const Color(0xFFECFDF5),
              onTap: onCheckInWalkIn,
              isDark: isDark,
            ),
            _buildActionCard(
              title: 'Scan QR Pass',
              icon: Icons.qr_code_scanner_rounded,
              color: const Color(0xFFD97706),
              bg: isDark ? const Color(0xFF78350F).withValues(alpha: 0.25) : const Color(0xFFFEF3C7),
              onTap: onScanQrPass,
              isDark: isDark,
            ),
            _buildActionCard(
              title: 'Schedule Visit',
              icon: Icons.calendar_month_rounded,
              color: const Color(0xFF9333EA),
              bg: isDark ? const Color(0xFF581C87).withValues(alpha: 0.2) : const Color(0xFFFAF5FF),
              onTap: onScheduleVisit,
              isDark: isDark,
            ),
            _buildActionCard(
              title: 'Generate Gate Pass',
              icon: Icons.badge_outlined,
              color: const Color(0xFF059669),
              bg: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.2) : const Color(0xFFF0FDF4),
              onTap: onGenerateGatePass,
              isDark: isDark,
            ),
            _buildActionCard(
              title: 'Visitor Log Report',
              icon: Icons.description_outlined,
              color: const Color(0xFF0284C7),
              bg: isDark ? const Color(0xFF0C4A6E).withValues(alpha: 0.2) : const Color(0xFFF0F9FF),
              onTap: onVisitorLogReport,
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
