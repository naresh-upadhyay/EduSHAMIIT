import 'package:flutter/material.dart';

/// Reusable responsive KPI card grid that dynamically adjusts across all
/// device viewports (desktop, tablet, mobile) with flexible wrapping and
/// zero rigid constraints, completely eliminating layout overflows and
/// assertion errors.
class HostelKpiGrid extends StatelessWidget {
  final List<Widget> children;
  final int desktopColumns;
  final int? tabletColumns;
  final int? mobileColumns;
  final double spacing;
  final double runSpacing;

  const HostelKpiGrid({
    super.key,
    required this.children,
    this.desktopColumns = 6,
    this.tabletColumns,
    this.mobileColumns,
    this.spacing = 12.0,
    this.runSpacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int cols;

        if (desktopColumns == 4) {
          if (width >= 960) {
            cols = 4;
          } else if (width >= 560) {
            cols = tabletColumns ?? 2;
          } else {
            cols = width < 360 ? 1 : (mobileColumns ?? 2);
          }
        } else if (desktopColumns == 5) {
          if (width >= 1150) {
            cols = 5;
          } else if (width >= 750) {
            cols = tabletColumns ?? 3;
          } else if (width >= 500) {
            cols = 2;
          } else {
            cols = width < 360 ? 1 : (mobileColumns ?? 2);
          }
        } else {
          // Default 6 columns
          if (width >= 1200) {
            cols = 6;
          } else if (width >= 750) {
            cols = tabletColumns ?? 3;
          } else if (width >= 500) {
            cols = 2;
          } else {
            cols = width < 360 ? 1 : (mobileColumns ?? 2);
          }
        }

        final double totalSpacing = (cols - 1) * spacing;
        final double cardWidth = ((width - totalSpacing) / cols).floorToDouble();

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((card) {
            return SizedBox(
              width: cardWidth,
              child: card,
            );
          }).toList(),
        );
      },
    );
  }
}

/// Unified premium KPI card component matching modern executive dashboard design.
/// Uses dynamic content-driven sizing, explicit typography line-heights, and
/// snug padding to guarantee zero-overflow rendering on all screen sizes and DPI settings.
class HostelUnifiedKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final Color? badgeBg;
  final IconData icon;
  final Color iconColor;
  final Color? iconBg;
  final bool isSelected;
  final VoidCallback? onTap;
  final double? progress;
  final String? tooltip;
  final double? minHeight;

  const HostelUnifiedKpiCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.badgeBg,
    required this.icon,
    required this.iconColor,
    this.iconBg,
    this.isSelected = false,
    this.onTap,
    this.progress,
    this.tooltip,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final resolvedIconBg = iconBg ??
        (isDark ? iconColor.withValues(alpha: 0.18) : iconColor.withValues(alpha: 0.10));

    final effectiveBadgeColor = badgeColor ?? const Color(0xFF16A34A);
    final effectiveBadgeBg = badgeBg ??
        (isDark
            ? effectiveBadgeColor.withValues(alpha: 0.20)
            : effectiveBadgeColor.withValues(alpha: 0.12));

    Widget cardWidget = Container(
      constraints: BoxConstraints(
        minHeight: minHeight ?? (progress != null ? 84.0 : 76.0),
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Icon Container
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: resolvedIconBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Icon(icon, color: iconColor, size: 19),
                  ),
                ),
                const SizedBox(width: 10),

                // 2. Text Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title + Optional Badge Row
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w500,
                                height: 1.15,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          if (badge != null && badge!.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              flex: 2,
                              fit: FlexFit.loose,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4.5, vertical: 1.0),
                                decoration: BoxDecoration(
                                  color: effectiveBadgeBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  badge!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                    color: effectiveBadgeColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Metric Value
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),

                      // Optional Micro Progress Indicator
                      if (progress != null) ...[
                        const SizedBox(height: 3.0),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress!.clamp(0.0, 1.0),
                            minHeight: 3.0,
                            backgroundColor: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                          ),
                        ),
                        const SizedBox(height: 2.0),
                      ] else ...[
                        const SizedBox(height: 1.5),
                      ],

                      // Subtitle
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w400,
                            height: 1.15,
                            color: isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        waitDuration: const Duration(milliseconds: 400),
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}
