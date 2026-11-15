import 'package:flutter/material.dart';
import '../../models/work_models.dart';
import '../../utils/work_sprint_date_helper.dart';

class WorkItemCard extends StatelessWidget {
  final WorkItemModel item;
  final VoidCallback onTap;

  const WorkItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'STORY':
        return const Color(0xFF8B5CF6);
      case 'BUG':
        return const Color(0xFFEF4444);
      case 'EPIC':
        return const Color(0xFFEC4899);
      case 'HOMEWORK':
      case 'ASSIGNMENT':
        return const Color(0xFF10B981);
      case 'TASK':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'STORY':
        return Icons.auto_stories_outlined;
      case 'BUG':
        return Icons.bug_report_outlined;
      case 'EPIC':
        return Icons.military_tech_outlined;
      case 'HOMEWORK':
      case 'ASSIGNMENT':
        return Icons.school_outlined;
      case 'TASK':
      default:
        return Icons.assignment_outlined;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
      case 'URGENT':
      case 'HIGH':
        return const Color(0xFFEF4444);
      case 'MEDIUM':
        return const Color(0xFFF59E0B);
      case 'LOW':
      default:
        return const Color(0xFF10B981);
    }
  }

  IconData _getCategoryIcon(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('academic') || c.contains('student')) return Icons.school_outlined;
    if (c.contains('it') || c.contains('portal') || c.contains('tech')) return Icons.computer_outlined;
    if (c.contains('facilities') || c.contains('room')) return Icons.apartment_outlined;
    if (c.contains('exam')) return Icons.quiz_outlined;
    if (c.contains('dept') || c.contains('department')) return Icons.domain_outlined;
    return Icons.folder_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _getTypeColor(item.workType);
    final priorityColor = _getPriorityColor(item.priority);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13182C) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row: Type chip & ID
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: typeColor.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getTypeIcon(item.workType), size: 12, color: typeColor),
                      const SizedBox(width: 4),
                      Text(
                        item.workType,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.itemNumber,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),

            // Category & Assignees
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Category
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getCategoryIcon(item.category), size: 14, color: const Color(0xFF94A3B8)),
                    const SizedBox(width: 5),
                    Text(
                      item.category,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),

                // Assignee Avatars
                _buildAssigneeAvatars(),
              ],
            ),
            const SizedBox(height: 10),

            // Divider
            Divider(height: 1, color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Bottom row: Due Date & Priority
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Due date / Resolution date
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.status == 'COMPLETED'
                          ? Icons.check_circle_outline
                          : (item.status == 'RESOLVED' ? Icons.task_alt : Icons.calendar_today_outlined),
                      size: 13,
                      color: item.status == 'COMPLETED'
                          ? const Color(0xFF8B5CF6)
                          : (item.status == 'RESOLVED'
                              ? const Color(0xFF10B981)
                              : (item.isOverdue ? const Color(0xFFEF4444) : const Color(0xFF94A3B8))),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.status == 'COMPLETED' && item.completedDateStr != null
                          ? 'Completed: ${item.completedDateStr}'
                          : (item.status == 'RESOLVED' && item.completedDateStr != null
                              ? 'Resolved: ${item.completedDateStr}'
                              : 'Due: ${item.dueDateFmt ?? WorkSprintDateHelper.defaultItemDueDateFmt}'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: item.isOverdue
                            ? const Color(0xFFEF4444)
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),

                // Priority Indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '=',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: priorityColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.priority,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: priorityColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssigneeAvatars() {
    if (item.assignees.isEmpty) {
      return const CircleAvatar(
        radius: 12,
        backgroundColor: Color(0xFFE2E8F0),
        child: Icon(Icons.person, size: 14, color: Color(0xFF64748B)),
      );
    }

    final primary = item.assignees.first;
    final extraCount = item.assignees.length - 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: const Color(0xFFDBEAFE),
          child: Text(
            primary.fullName.isNotEmpty ? primary.fullName[0].toUpperCase() : 'U',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D4ED8),
            ),
          ),
        ),
        if (extraCount > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
            ),
            child: Text(
              '+$extraCount',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
