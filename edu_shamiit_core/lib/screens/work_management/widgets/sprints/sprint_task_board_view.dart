import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';

class SprintTaskBoardView extends ConsumerStatefulWidget {
  final List<WorkItemModel> items;
  final Function(WorkItemModel item) onOpenDetail;
  final Function(String type) onQuickAction;
  final Function({
    String? type,
    String? status,
    String? priority,
    String? category,
    String? sprintId,
    String? parentId,
  })? onCreateItem;
  final String sprintId;

  const SprintTaskBoardView({
    super.key,
    required this.items,
    required this.onOpenDetail,
    required this.onQuickAction,
    this.onCreateItem,
    required this.sprintId,
  });

  @override
  ConsumerState<SprintTaskBoardView> createState() => _SprintTaskBoardViewState();
}

class _SprintTaskBoardViewState extends ConsumerState<SprintTaskBoardView> {
  final List<String> _statuses = ['NEW', 'ACTIVE', 'IN PROGRESS', 'RESOLVED', 'COMPLETED'];
  List<WorkItemModel> _localItems = [];
  bool _isOptimisticTransition = false;

  @override
  void initState() {
    super.initState();
    _localItems = _flattenItems(widget.items);
  }

  @override
  void didUpdateWidget(SprintTaskBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isOptimisticTransition && widget.items != oldWidget.items) {
      _localItems = _flattenItems(widget.items);
    }
  }

  List<WorkItemModel> _flattenItems(List<WorkItemModel> items) {
    final Map<String, WorkItemModel> deduplicated = {};
    for (final item in items) {
      deduplicated[item.id] = item;
      for (final child in item.children) {
        deduplicated[child.id] = child;
      }
    }
    return deduplicated.values.toList();
  }

  void _handleCreateItem({
    String? type,
    String? status,
    String? priority,
    String? category,
    String? sprintId,
    String? parentId,
  }) {
    if (widget.onCreateItem != null) {
      widget.onCreateItem!(
        type: type ?? 'TASK',
        status: status,
        priority: priority,
        category: category,
        sprintId: sprintId ?? widget.sprintId,
        parentId: parentId,
      );
    } else {
      widget.onQuickAction(type ?? 'TASK');
    }
  }
  final Map<String, int> _columnDisplayLimits = {};

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
    final currentNorm = item.status.replaceAll('_', ' ').trim().toUpperCase();
    final targetNorm = targetStatus.replaceAll('_', ' ').trim().toUpperCase();
    if (currentNorm == targetNorm) return;

    final backup = List<WorkItemModel>.from(_localItems);
    _isOptimisticTransition = true;

    // 1. Instant synchronous optimistic UI update - moves card to target column immediately without delay/flicker
    setState(() {
      final idx = _localItems.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        _localItems[idx] = _localItems[idx].copyWith(
          status: targetNorm == 'IN PROGRESS' ? 'IN PROGRESS' : targetStatus.toUpperCase(),
          progressPercentage: (targetNorm == 'COMPLETED' || targetNorm == 'RESOLVED')
              ? 100
              : (targetNorm == 'NEW' ? 0 : 50),
        );
      }
    });

    // 2. Synchronous optimistic update in provider so parent or other components stay consistent
    ref.read(workSprintDashboardProvider.notifier).optimisticallyUpdateItemStatus(item.id, targetStatus);

    // 3. Persist status transition to backend
    final api = ref.read(workApiServiceProvider);
    final success = await api.transitionStatus(item.id, targetStatus);

    if (success) {
      // Quietly reconcile sprint dashboard metrics without triggering loading spinner/flicker
      ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(
        sprintId: widget.sprintId,
        quiet: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('${item.itemNumber} moved to ${_statusDisplay[targetStatus] ?? targetStatus}'),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF2563EB),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _localItems = backup;
        });
        ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(sprintId: widget.sprintId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status. Reverted.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
    _isOptimisticTransition = false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use localItems for instantaneous flicker-free UI; fall back to widget.items if empty
    final List<WorkItemModel> allSprintItems = _localItems.isNotEmpty
        ? _localItems
        : _flattenItems(widget.items);

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (allSprintItems.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            final anyExpanded = _columnDisplayLimits.values.any((lim) => lim > 10);
                            if (anyExpanded) {
                              _columnDisplayLimits.clear();
                            } else {
                              for (final st in _statuses) {
                                _columnDisplayLimits[st] = 9999;
                              }
                            }
                          });
                        },
                        icon: Icon(
                          _columnDisplayLimits.values.any((lim) => lim > 10)
                              ? Icons.unfold_less_rounded
                              : Icons.unfold_more_rounded,
                          size: 14,
                          color: const Color(0xFF2563EB),
                        ),
                        label: Text(
                          _columnDisplayLimits.values.any((lim) => lim > 10) ? 'Collapse (10)' : 'Expand All',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: () => _handleCreateItem(type: 'TASK', sprintId: widget.sprintId),
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
                    final s = i.status.trim().toUpperCase();
                    if (status == 'NEW') {
                      return s == 'NEW' || s == 'OPEN' || s == 'PLANNED' || s == 'NOT STARTED' || s == 'NOT_STARTED' || s == 'TODO';
                    }
                    if (status == 'ACTIVE') {
                      return s == 'ACTIVE' || s == 'CRITICAL';
                    }
                    if (status == 'IN PROGRESS') {
                      return s == 'IN PROGRESS' || s == 'IN_PROGRESS' || s == 'DOING';
                    }
                    if (status == 'RESOLVED') {
                      return s == 'RESOLVED' || s == 'TESTING' || s == 'QA' || s == 'CODE REVIEW';
                    }
                    if (status == 'COMPLETED') {
                      return s == 'COMPLETED' || s == 'CLOSED' || s == 'DONE';
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

  Widget _buildDropPlaceholder(Color statusColor, String displayName, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 15, color: statusColor),
            const SizedBox(width: 6),
            Text(
              'Drop to move to $displayName',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(String status, List<WorkItemModel> items, bool isDark) {
    final statusColor = _statusColors[status] ?? const Color(0xFF64748B);
    final displayName = _statusDisplay[status] ?? status;
    final limit = _columnDisplayLimits[status] ?? 10;
    final visibleItems = items.take(limit).toList();
    final hasMore = items.length > visibleItems.length;
    final remainingCount = items.length - visibleItems.length;

    return DragTarget<WorkItemModel>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) => _handleDrop(details.data, status),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return Container(
          width: 250,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: isHovering
                ? statusColor.withValues(alpha: isDark ? 0.08 : 0.04)
                : (isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHovering
                  ? statusColor.withValues(alpha: 0.8)
                  : (isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
              width: isHovering ? 1.5 : 1.0,
            ),
          ),
          child: Column(
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
                      color: isHovering
                          ? statusColor.withValues(alpha: 0.4)
                          : (isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
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
                        items.length > visibleItems.length
                            ? '${visibleItems.length}/${items.length}'
                            : '${items.length}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => _handleCreateItem(
                        type: 'TASK',
                        status: status.toUpperCase() == 'IN PROGRESS' ? 'ACTIVE' : status.toUpperCase(),
                        sprintId: widget.sprintId,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.add_rounded, size: 16, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),

              // Cards list
              Expanded(
                child: visibleItems.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                          child: isHovering
                              ? _buildDropPlaceholder(statusColor, displayName, isDark)
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      size: 30,
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No $displayName tasks',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: () => _handleCreateItem(
                                        type: 'TASK',
                                        status: status.toUpperCase() == 'IN PROGRESS' ? 'ACTIVE' : status.toUpperCase(),
                                        sprintId: widget.sprintId,
                                      ),
                                      icon: const Icon(Icons.add, size: 13),
                                      label: Text('Add $displayName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: statusColor,
                                        side: BorderSide(color: statusColor.withValues(alpha: 0.5)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(10),
                        itemCount: visibleItems.length + (hasMore ? 1 : 0) + (isHovering ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          if (isHovering && idx == 0) {
                            return _buildDropPlaceholder(statusColor, displayName, isDark);
                          }
                          final itemIdx = isHovering ? idx - 1 : idx;

                          if (itemIdx == visibleItems.length && hasMore) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _columnDisplayLimits[status] = limit + 10;
                                  });
                                },
                                icon: const Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF2563EB)),
                                label: Text(
                                  'Load 10 More ($remainingCount left)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: const Color(0xFF2563EB).withValues(alpha: 0.35)),
                                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            );
                          }
                          final item = visibleItems[itemIdx];
                          return Draggable<WorkItemModel>(
                            data: item,
                            feedback: Material(
                              elevation: 10,
                              shadowColor: Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 230,
                                child: _buildItemCard(item, isDark, isDragging: true),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.25,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF64748B).withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: _buildItemCard(item, isDark),
                              ),
                            ),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: _buildItemCard(item, isDark),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
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
