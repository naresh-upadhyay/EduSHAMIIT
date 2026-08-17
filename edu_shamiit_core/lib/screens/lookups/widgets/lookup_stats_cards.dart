import 'package:flutter/material.dart';
import '../models/lookup_models.dart';
import 'dialogs/lookup_usage_drawer.dart';

class LookupStatsCards extends StatelessWidget {
  final LookupStatsModel stats;
  final LookupKeyModel lookupKey;

  const LookupStatsCards({
    super.key,
    required this.stats,
    required this.lookupKey,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    final cards = [
      _buildCard(
        context,
        title: 'Total Values',
        value: '${stats.totalValues}',
        icon: Icons.grid_view_rounded,
        iconColor: const Color(0xFF8B5CF6),
        isDark: isDark,
      ),
      _buildCard(
        context,
        title: 'Active Values',
        value: '${stats.activeValues}',
        icon: Icons.check_circle_outline_rounded,
        iconColor: const Color(0xFF10B981),
        isDark: isDark,
      ),
      _buildCard(
        context,
        title: 'Inactive Values',
        value: '${stats.inactiveValues}',
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFEF4444),
        isDark: isDark,
      ),
      _buildCard(
        context,
        title: 'Used In Module',
        value: stats.usedInModule,
        icon: Icons.table_chart_outlined,
        iconColor: const Color(0xFF0EA5E9),
        isDark: isDark,
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (ctx) => LookupUsageDrawer(lookupKey: lookupKey),
          );
        },
      ),
      _buildCard(
        context,
        title: 'Key Type',
        value: stats.keyType == 'SYSTEM' ? 'System' : 'Custom',
        icon: Icons.shield_outlined,
        iconColor: const Color(0xFF6366F1),
        isDark: isDark,
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 78,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, idx) => SizedBox(width: 140, child: cards[idx]),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: cards.map((c) => Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: c,
          ))).toList(),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
