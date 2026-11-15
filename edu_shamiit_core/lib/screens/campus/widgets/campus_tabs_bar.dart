import 'package:flutter/material.dart';

class CampusTabsBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTabSelected;

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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isActive = index == activeIndex;
            return InkWell(
              onTap: () => onTabSelected(index),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                    fontSize: 13.5,
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
    );
  }
}
