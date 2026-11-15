import 'package:flutter/material.dart';

class WorkHeaderBar extends StatelessWidget {
  final VoidCallback onCreateWorkItem;
  final Function(String type)? onCreateSpecificType;
  final VoidCallback? onMoreOptions;

  const WorkHeaderBar({
    super.key,
    required this.onCreateWorkItem,
    this.onCreateSpecificType,
    this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.layers_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Work Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Plan, assign, track and manage all types of work across the institute.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // "+ Create Work Item" Dropdown Button
          PopupMenuButton<String>(
            tooltip: 'Create Work Item',
            onSelected: (val) {
              if (onCreateSpecificType != null) {
                onCreateSpecificType!(val);
              } else {
                onCreateWorkItem();
              }
            },
            offset: const Offset(0, 42),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'TASK',
                child: Row(
                  children: [
                    Icon(Icons.assignment_outlined, size: 18, color: Color(0xFF3B82F6)),
                    SizedBox(width: 10),
                    Text('New Task', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'STORY',
                child: Row(
                  children: [
                    Icon(Icons.auto_stories_outlined, size: 18, color: Color(0xFF8B5CF6)),
                    SizedBox(width: 10),
                    Text('New Story', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'BUG',
                child: Row(
                  children: [
                    Icon(Icons.bug_report_outlined, size: 18, color: Color(0xFFEF4444)),
                    SizedBox(width: 10),
                    Text('Report Bug', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'EPIC',
                child: Row(
                  children: [
                    Icon(Icons.military_tech_outlined, size: 18, color: Color(0xFFEC4899)),
                    SizedBox(width: 10),
                    Text('New Epic', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'HOMEWORK',
                child: Row(
                  children: [
                    Icon(Icons.school_outlined, size: 18, color: Color(0xFF10B981)),
                    SizedBox(width: 10),
                    Text('New Homework', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Create Work Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Options Button
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13182C) : Colors.white,
              border: Border.all(
                color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.more_horiz_rounded, size: 18),
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              onPressed: onMoreOptions ?? () {},
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
