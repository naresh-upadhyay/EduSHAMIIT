import 'package:flutter/material.dart';

class CampusTabsBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final bool isKpisVisible;
  final VoidCallback? onToggleKpis;

  static const List<String> tabs = [
    'Buildings & Rooms',
    'Facilities',
    'Space Booking',
    'Maintenance',
    'Safety & Compliance',
    'Device Management & Control',
    'Utilities & Services',
    'Reports',
  ];

  const CampusTabsBar({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
    this.isKpisVisible = true,
    this.onToggleKpis,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(tabs.length, (index) {
                  final isActive = index == activeIndex;
                  return InkWell(
                    onTap: () => onTabSelected(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isActive ? primaryColor : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Text(
                        tabs[index],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? primaryColor
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          if (onToggleKpis != null)
            Tooltip(
              message: isKpisVisible ? 'Collapse Top Summary Stats' : 'Expand Top Summary Stats',
              child: InkWell(
                onTap: onToggleKpis,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isKpisVisible ? primaryColor.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isKpisVisible ? primaryColor.withValues(alpha: 0.3) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isKpisVisible ? Icons.insights_rounded : Icons.insights_outlined,
                        size: 14,
                        color: isKpisVisible ? primaryColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Stats',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isKpisVisible ? primaryColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
