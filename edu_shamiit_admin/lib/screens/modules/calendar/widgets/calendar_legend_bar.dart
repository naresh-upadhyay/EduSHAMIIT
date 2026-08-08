import 'package:flutter/material.dart';

class CalendarLegendBarWidget extends StatelessWidget {
  const CalendarLegendBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final badges = [
      _LegendItem(label: 'Meeting', color: const Color(0xFF8B5CF6)),
      _LegendItem(label: 'Task', color: const Color(0xFF10B981)),
      _LegendItem(label: 'Event', color: const Color(0xFFEF4444)),
      _LegendItem(label: 'Training', color: const Color(0xFFF59E0B)),
      _LegendItem(label: 'Reminder', color: const Color(0xFF3B82F6)),
      _LegendItem(label: 'Personal', color: const Color(0xFFA855F7)),
      _LegendItem(label: 'Holiday', color: const Color(0xFFF43F5E)),
      _LegendItem(label: 'Leave', color: const Color(0xFF64748B)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: badges.map((b) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: b.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          b.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                'All times are shown in Asia/Kolkata (IST)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;

  _LegendItem({required this.label, required this.color});
}
