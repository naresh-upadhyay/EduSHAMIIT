import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';

class SprintTaskBoardView extends ConsumerStatefulWidget {
  final List<WorkItemModel> items;
  final Function(WorkItemModel item) onOpenDetail;
  final Function(String type) onQuickAction;
  final String sprintId;

  const SprintTaskBoardView({
    super.key,
    required this.items,
    required this.onOpenDetail,
    required this.onQuickAction,
    required this.sprintId,
  });

  @override
  ConsumerState<SprintTaskBoardView> createState() => _SprintTaskBoardViewState();
}

class _SprintTaskBoardViewState extends ConsumerState<SprintTaskBoardView> {
  final List<String> _statuses = ['NEW', 'ACTIVE', 'IN PROGRESS', 'RESOLVED', 'COMPLETED'];

  final Map<String, String> _statusDisplay = {
    'NEW': 'New',
    'ACTIVE': 'Active',
    'IN PROGRESS': 'In Progress',
    'RESOLVED': 'Resolved',
    'COMPLETED': 'Completed',
  };

  final Map<String, Color> _statusColors = {
    'NEW': const Color(0xFF64748B),
    'ACTIVE': const Color(0xFF2563EB),
    'IN PROGRESS': const Color(0xFF3B82F6),
    'RESOLVED': const Color(0xFF10B981),
    'COMPLETED': const Color(0xFF8B5CF6),
  };

  Future<void> _handleDrop(WorkItemModel item, String targetStatus) async {
    if (item.status.toUpperCase() == targetStatus.toUpperCase()) return;

    final api = ref.read(workApiServiceProvider);
    final success = await api.transitionStatus(item.id, targetStatus);
    if (success) {
      ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(sprintId: widget.sprintId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.itemNumber} moved to ${_statusDisplay[targetStatus]}'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Collect all items including story children
    final List<WorkItemModel> allSprintItems = [];
    for (final item in widget.items) {
      allSprintItems.add(item);
      for (final child in item.children) {
        allSprintItems.add(child);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.dashboard_customize_outlined, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    'Sprint Task Board',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${allSprintItems.length} items',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => widget.onQuickAction('TASK'),
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: const Text('Add Task', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Horizontal scrolling columns container
          SizedBox(
            height: 580,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _statuses.map((status) {
                  final columnItems = allSprintItems.where((i) {
                    final s = i.status.toUpperCase();
                    if (status == 'IN PROGRESS') {
                      return s == 'IN PROGRESS' || s == 'IN_PROGRESS';
                    }
                    return s == status;
                  }).toList();

                  return _buildKanbanColumn(status, columnItems, isDark);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanColumn(String status, List<WorkItemModel> items, bool isDark) {
    final statusColor = _statusColors[status] ?? const Color(0xFF64748B);
    final displayName = _statusDisplay[status] ?? status;

    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: DragTarget<WorkItemModel>(
        onWillAcceptWithDetails: (details) => true,
        onAcceptWithDetails: (details) => _handleDrop(details.data, status),
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;

          return Column(
            children: [
              // Column Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isHovering
                      ? statusColor.withValues(alpha: 0.15)
                      : (isDark ? const Color(0xFF13182C) : Colors.white),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${items.length}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => widget.onQuickAction('TASK'),
                      child: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // Cards list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final item = items[idx];
                    return Draggable<WorkItemModel>(
                      data: item,
                      feedback: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 230,
                          child: _buildItemCard(item, isDark, isDragging: true),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _buildItemCard(item, isDark),
                      ),
                      child: _buildItemCard(item, isDark),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemCard(WorkItemModel item, bool isDark, {bool isDragging = false}) {
    final typeColor = item.workType.toUpperCase() == 'STORY'
        ? const Color(0xFF8B5CF6)
        : (item.workType.toUpperCase() == 'BUG'
            ? const Color(0xFFEF4444)
            : const Color(0xFF3B82F6));

    final isHigh = item.priority.toUpperCase() == 'HIGH' || item.priority.toUpperCase() == 'CRITICAL';

    return InkWell(
      onTap: () => widget.onOpenDetail(item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13182C) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.workType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: typeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.itemNumber,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  item.priority.isNotEmpty ? '= ${item.priority}' : '',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isHigh ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.folder_open_rounded, size: 12, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.category.isNotEmpty ? item.category : 'General',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Assignee avatar
                if (item.assignees.isNotEmpty)
                  CircleAvatar(
                    radius: 9,
                    backgroundColor: const Color(0xFF2563EB),
                    child: Text(
                      item.assignees.first.fullName.isNotEmpty
                          ? item.assignees.first.fullName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  const CircleAvatar(
                    radius: 9,
                    backgroundColor: Color(0xFFE2E8F0),
                    child: Icon(Icons.person, size: 10, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
