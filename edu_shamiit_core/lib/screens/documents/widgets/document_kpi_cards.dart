import 'package:flutter/material.dart';
import '../../../constants/app_fonts.dart';
import '../../../models/document_model.dart';

class DocumentKpiCards extends StatelessWidget {
  final DocumentStatsModel stats;
  final bool isDark;

  const DocumentKpiCards({
    super.key,
    required this.stats,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 600;
        final isTablet = width >= 600 && width < 1050;

        final double cardWidth = isMobile
            ? width
            : (isTablet ? (width - 12) / 2 : (width - 48) / 4);

        final cards = [
          _buildKpiCard(
            title: 'Total Documents',
            value: '${stats.totalDocuments}',
            badgeText: stats.pendingApprovals > 0 ? '${stats.pendingApprovals} pending' : 'Active',
            badgeColor: stats.pendingApprovals > 0 ? const Color(0xFFD97706) : const Color(0xFF16A34A),
            badgeBg: stats.pendingApprovals > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
            icon: Icons.folder_rounded,
            iconColor: const Color(0xFF2563EB),
            iconBg: const Color(0xFFEFF6FF),
            width: cardWidth,
            cardBg: cardBg,
            borderCol: borderCol,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
          _buildKpiCard(
            title: 'Shared Documents',
            value: '${stats.sharedDocuments}',
            badgeText: 'Shared',
            badgeColor: const Color(0xFF9333EA),
            badgeBg: const Color(0xFFF3E8FF),
            icon: Icons.groups_rounded,
            iconColor: const Color(0xFF9333EA),
            iconBg: const Color(0xFFF3E8FF),
            width: cardWidth,
            cardBg: cardBg,
            borderCol: borderCol,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
          _buildKpiCard(
            title: 'Storage Used',
            value: '${stats.storageUsedLabel} / ${stats.storageQuotaLabel}',
            badgeText: '${stats.storagePercentage}%',
            badgeColor: const Color(0xFF0284C7),
            badgeBg: const Color(0xFFE0F2FE),
            icon: Icons.storage_rounded,
            iconColor: const Color(0xFF16A34A),
            iconBg: const Color(0xFFDCFCE7),
            width: cardWidth,
            cardBg: cardBg,
            borderCol: borderCol,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
          _buildKpiCard(
            title: 'Recent Uploads',
            value: '${stats.recentUploads}',
            badgeText: stats.recentToday > 0 ? '↑ ${stats.recentToday} today' : '7 days',
            badgeColor: stats.recentToday > 0 ? const Color(0xFF16A34A) : textMuted,
            badgeBg: stats.recentToday > 0 ? const Color(0xFFDCFCE7) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
            icon: Icons.access_time_rounded,
            iconColor: const Color(0xFFEA580C),
            iconBg: const Color(0xFFFFEDD5),
            width: cardWidth,
            cardBg: cardBg,
            borderCol: borderCol,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
        ];

        if (isMobile) {
          return Column(
            children: [
              cards[0],
              const SizedBox(height: 10),
              cards[1],
              const SizedBox(height: 10),
              cards[2],
              const SizedBox(height: 10),
              cards[3],
            ],
          );
        }

        if (isTablet) {
          return Column(
            children: [
              Row(children: [cards[0], const SizedBox(width: 12), cards[1]]),
              const SizedBox(height: 12),
              Row(children: [cards[2], const SizedBox(width: 12), cards[3]]),
            ],
          );
        }

        return Row(
          children: [
            cards[0],
            const SizedBox(width: 16),
            cards[1],
            const SizedBox(width: 16),
            cards[2],
            const SizedBox(width: 16),
            cards[3],
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required double width,
    required Color cardBg,
    required Color borderCol,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon Box
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
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
