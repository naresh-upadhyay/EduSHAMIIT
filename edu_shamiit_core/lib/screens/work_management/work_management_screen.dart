import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/js_helper.dart';
import 'models/work_models.dart';
import 'providers/work_management_provider.dart';
import 'widgets/work_header_bar.dart';
import 'widgets/work_tabs_bar.dart';
import 'widgets/board/work_board_tab_view.dart';
import 'widgets/list/work_list_tab_view.dart';
import 'widgets/backlog/work_backlog_tab_view.dart';
import 'widgets/sprints/work_sprints_tab_view.dart';
import 'widgets/drawers/work_item_detail_drawer.dart';
import 'widgets/dialogs/create_edit_work_item_dialog.dart';
import 'widgets/dialogs/create_sprint_dialog.dart';
import 'services/work_api_service.dart';

class WorkManagementScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const WorkManagementScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<WorkManagementScreen> createState() => _WorkManagementScreenState();
}

class _WorkManagementScreenState extends ConsumerState<WorkManagementScreen> {
  late int _activeTabIndex;
  final Set<int> _loadedTabs = {};
  WorkItemModel? _activeBoardDrawerItem;

  @override
  void initState() {
    super.initState();
    _activeTabIndex = widget.initialTabIndex;
    _loadedTabs.add(_activeTabIndex);
  }

  void _openCreateDialog({
    String? type,
    String? status,
    String? priority,
    String? category,
    String? sprintId,
    String? parentId,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => CreateEditWorkItemDialog(
        initialWorkType: type,
        initialStatus: status,
        initialPriority: priority,
        initialCategory: category,
        sprintId: sprintId,
        parentId: parentId,
      ),
    );
    if (res == true && mounted) {
      ref.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      ref.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
      ref.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
      ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(forceRefresh: true);
      ref.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
    }
  }

  void _openCreateSprintDialog() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => const CreateSprintDialog(),
    );
    if (res == true && mounted) {
      ref.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
      ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(forceRefresh: true);
      ref.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
      ref.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      ref.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
    }
  }

  void _openFiltersDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.filter_list_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Quick Filters & Search', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Use the inline filter bar directly below the sub-filters in Board, List, Backlog, or Sprints to filter in real-time by keyword, type, priority, status, and assignee.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _openMoreOptionsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
                title: const Text('Refresh All Work Data', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Re-fetch boards, backlog, sprints and live metrics from DB'),
                onTap: () {
                  Navigator.pop(ctx);
                  WorkApiService.instance.invalidateCache();
                  ref.read(allSprintsProvider.notifier).loadSprints();
                  ref.read(workBoardProvider.notifier).loadBoard();
                  if (_loadedTabs.contains(1)) ref.read(workListProvider.notifier).loadPagedItems();
                  if (_loadedTabs.contains(2)) ref.read(workBacklogProvider.notifier).loadBacklog();
                  if (_loadedTabs.contains(3)) ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All Work Management modules refreshed with live data!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined, color: Color(0xFF10B981)),
                title: const Text('Export Work Summary', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Download active sprint items and status breakdown as CSV'),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportWorkSummary();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportWorkSummary() {
    final listState = ref.read(workListProvider);
    final boardState = ref.read(workBoardProvider);
    final sprintState = ref.read(workSprintDashboardProvider);

    // Collect all unique items across modules
    final Map<String, WorkItemModel> allItemsMap = {};
    for (final item in listState.items) {
      allItemsMap[item.id] = item;
    }
    for (final col in boardState.columns) {
      for (final item in col.items) {
        allItemsMap[item.id] = item;
      }
    }
    for (final item in sprintState.items) {
      allItemsMap[item.id] = item;
      for (final child in item.children) {
        allItemsMap[child.id] = child;
      }
    }

    final items = allItemsMap.values.toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No work items available to export.')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Item Number,Title,Work Type,Status,Priority,Category,Story Points,Estimated Hours,Progress,Due Date');
    for (final item in items) {
      final safeTitle = '"${item.title.replaceAll('"', '""')}"';
      final safeCategory = '"${item.category.replaceAll('"', '""')}"';
      final due = item.dueDate ?? '';
      buffer.writeln('${item.itemNumber},$safeTitle,${item.workType},${item.status},${item.priority},$safeCategory,${item.storyPoints},${item.estimatedHours},${item.progressPercentage}%,$due');
    }

    downloadCsvWeb(buffer.toString(), 'EduSHAMIIT_Work_Summary.csv');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${items.length} work items to EduSHAMIIT_Work_Summary.csv'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090B15) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Universal Top Header
              WorkHeaderBar(
                onCreateWorkItem: () {
                  String? defaultParentId;
                  if (_activeTabIndex == 2) {
                    final selEpic = ref.read(workBacklogProvider).selectedEpic;
                    defaultParentId = selEpic?.id.isNotEmpty == true ? selEpic!.id : selEpic?.itemNumber;
                  }
                  _openCreateDialog(
                    type: _activeTabIndex == 2 ? 'STORY' : null,
                    parentId: defaultParentId,
                  );
                },
                onCreateSpecificType: (type) {
                  String? defaultParentId;
                  if (_activeTabIndex == 2 && type.toUpperCase() == 'STORY') {
                    final selEpic = ref.read(workBacklogProvider).selectedEpic;
                    defaultParentId = selEpic?.id.isNotEmpty == true ? selEpic!.id : selEpic?.itemNumber;
                  }
                  _openCreateDialog(type: type, parentId: defaultParentId);
                },
                onMoreOptions: _openMoreOptionsMenu,
              ),

              // 2. Primary Tabs (Board | List | Backlog | Sprints)
              WorkTabsBar(
                activeTab: _activeTabIndex,
                onTabSelected: (idx) {
                  setState(() {
                    _activeTabIndex = idx.clamp(0, 3);
                    _loadedTabs.add(_activeTabIndex);
                    _activeBoardDrawerItem = null;
                  });
                },
              ),

              // 3. Tab Views Content (Lazily loaded for fast startup)
              Expanded(
                child: IndexedStack(
                  index: _activeTabIndex.clamp(0, 3),
                  children: [
                    // Tab 0: Board
                    _loadedTabs.contains(0)
                        ? WorkBoardTabView(
                            onOpenDetail: (item) {
                              setState(() => _activeBoardDrawerItem = item);
                            },
                            onQuickAction: (type) => _openCreateDialog(type: type),
                            onCreateItem: _openCreateDialog,
                            onOpenFilters: _openFiltersDialog,
                          )
                        : const SizedBox.shrink(),

                    // Tab 1: List
                    _loadedTabs.contains(1)
                        ? WorkListTabView(
                            onOpenDetail: (item) {
                              setState(() => _activeBoardDrawerItem = item);
                            },
                            onQuickAction: (type) => _openCreateDialog(type: type),
                            onCreateItem: _openCreateDialog,
                            onOpenFilters: _openFiltersDialog,
                          )
                        : const SizedBox.shrink(),

                    // Tab 2: Backlog
                    _loadedTabs.contains(2)
                        ? WorkBacklogTabView(
                            onOpenDetail: (item) {
                              setState(() => _activeBoardDrawerItem = item);
                            },
                            onQuickAction: (type) => _openCreateDialog(type: type),
                            onCreateItem: _openCreateDialog,
                            onOpenFilters: _openFiltersDialog,
                          )
                        : const SizedBox.shrink(),

                    // Tab 3: Sprints
                    _loadedTabs.contains(3)
                        ? WorkSprintsTabView(
                            onOpenDetail: (item) {
                              setState(() => _activeBoardDrawerItem = item);
                            },
                            onQuickAction: (type) => _openCreateDialog(type: type),
                            onCreateItem: _openCreateDialog,
                            onCreateSprint: _openCreateSprintDialog,
                            onOpenFilters: _openFiltersDialog,
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),

          // Detail Drawer for all tabs when an item is tapped
          if (_activeBoardDrawerItem != null)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: WorkItemDetailDrawer(
                item: _activeBoardDrawerItem,
                onUpdated: (updated) => setState(() => _activeBoardDrawerItem = updated),
                onClose: () => setState(() => _activeBoardDrawerItem = null),
              ),
            ),
        ],
      ),
    );
  }
}
