import 'package:flutter/material.dart';

class LiveClassStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color? iconBgColor;
  final String title;
  final String value;
  final String? subtitle;
  final Widget? trailingBadge;
  final VoidCallback? onTap;

  const LiveClassStatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    this.iconBgColor,
    required this.title,
    required this.value,
    this.subtitle,
    this.trailingBadge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor ?? iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
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
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF10B981),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (trailingBadge != null) trailingBadge!,
          ],
        ),
      ),
    );
  }
}
