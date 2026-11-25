import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/js_helper.dart';
import 'package:edu_shamiit_core/utils/tab_url_sync.dart';
import 'models/work_models.dart';
import 'providers/work_management_provider.dart';
import 'widgets/work_header_bar.dart';
import 'widgets/work_tabs_bar.dart';
import 'widgets/board/work_board_tab_view.dart';
import 'widgets/list/work_list_tab_view.dart';
import 'widgets/backlog/work_backlog_tab_view.dart';
import 'widgets/sprints/work_sprints_tab_view.dart';
import 'widgets/sprints/sprint_team_tab_view.dart';
import 'widgets/drawers/work_item_detail_drawer.dart';
import 'widgets/dialogs/create_edit_work_item_dialog.dart';
import 'widgets/dialogs/create_sprint_dialog.dart';
import 'services/work_api_service.dart';
import 'utils/work_filter_helper.dart';

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
  final GlobalKey<WorkBoardTabViewState> _boardKey = GlobalKey<WorkBoardTabViewState>();
  final GlobalKey<WorkSprintsTabViewState> _sprintsKey = GlobalKey<WorkSprintsTabViewState>();
  String? _boardTargetSprint;
  String? _boardTargetSprintId;

  String _resolveBasePath() {
    final path = Uri.base.path;
    if (path == '/work' || path.startsWith('/work/')) {
      return '/work';
    }
    return '/admin/work';
  }

  @override
  void initState() {
    super.initState();
    _activeTabIndex = widget.initialTabIndex.clamp(0, 4);
    _loadedTabs.add(_activeTabIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshTabOnSwitch(_activeTabIndex);
    });
  }

  @override
  void didUpdateWidget(covariant WorkManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIdx = widget.initialTabIndex.clamp(0, 4);
    if (nextIdx != oldWidget.initialTabIndex.clamp(0, 4) &&
        nextIdx != _activeTabIndex) {
      setState(() {
        _activeTabIndex = nextIdx;
        _loadedTabs.add(nextIdx);
        _activeBoardDrawerItem = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshTabOnSwitch(nextIdx);
      });
    }
  }

  void _navigateToCapacityTab(String teamName, String? sprintId) {
    setState(() {
      _activeTabIndex = 3; // Sprints Tab
      _loadedTabs.add(3);
      _activeBoardDrawerItem = null;
    });
    updateTabUrl(_resolveBasePath(), 3);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sprintsKey.currentState?.switchToCapacity(team: teamName, sprintId: sprintId);
    });
  }

  void _navigateToBoardWithSprint(String sprintId) {
    final allSprints = ref.read(allSprintsProvider).sprints;
    final match = allSprints.where((s) => s.id == sprintId).firstOrNull;
    final sprintLabel = match?.displayLabel ?? (match?.name.isNotEmpty == true ? match!.name : sprintId);

    ref.read(allSprintsProvider.notifier).selectSprint(sprintId);
    setState(() {
      _boardTargetSprint = sprintLabel;
      _boardTargetSprintId = sprintId;
      _activeTabIndex = 0;
      _loadedTabs.add(0);
      _activeBoardDrawerItem = null;
    });
    updateTabUrl(_resolveBasePath(), 0);

    WorkApiService.instance.invalidateCache();
    _boardKey.currentState?.selectSprint(sprintLabel, sprintId);
  }

  void _refreshTabOnSwitch(int tabIndex) {
    WorkApiService.instance.invalidateCache();
    WorkFilterHelper.clearCache();
    switch (tabIndex) {
      case 0: // Board
        if (_boardKey.currentState != null) {
          _boardKey.currentState!.reloadCurrent();
        } else {
          ref.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
        }
        break;
      case 1: // List
        final currentBoardId = ref.read(workListProvider).boardId;
        ref.read(workListProvider.notifier).loadPagedItems(boardId: currentBoardId, forceRefresh: true);
        break;
      case 2: // Backlog
        ref.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
        break;
      case 3: // Sprints
        ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(forceRefresh: true);
        ref.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
        break;
      case 4: // Team
        final allSprints = ref.read(allSprintsProvider).sprints;
        final activeSprint = allSprints.where((s) => s.status.toUpperCase() == 'ACTIVE').firstOrNull;
        final sid = activeSprint?.id ?? ref.read(workSprintDashboardProvider).sprint?.id ?? (allSprints.isNotEmpty ? allSprints.first.id : '');
        ref.read(workSprintTeamProvider.notifier).init(sid);
        break;
    }
  }

  void _openCreateDialog({
    String? type,
    String? status,
    String? priority,
    String? category,
    String? sprintId,
    String? parentId,
    String? boardId,
  }) async {
    String? effectiveBoardId = boardId;
    if (effectiveBoardId == null || effectiveBoardId == 'all' || effectiveBoardId.isEmpty) {
      if (_activeTabIndex == 0) {
        effectiveBoardId = ref.read(workBoardProvider).boardId;
      } else if (_activeTabIndex == 1) {
        effectiveBoardId = ref.read(workListProvider).boardId;
      } else if (_activeTabIndex == 2) {
        effectiveBoardId = ref.read(workBacklogProvider).boardId;
      } else if (_activeTabIndex == 3) {
        effectiveBoardId = ref.read(workSprintDashboardProvider).sprint?.boardId;
      }
    }

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => CreateEditWorkItemDialog(
        initialWorkType: type,
        initialStatus: status,
        initialPriority: priority,
        initialCategory: category,
        boardId: effectiveBoardId,
        sprintId: sprintId,
        parentId: parentId,
      ),
    );
    if (res == true && mounted) {
      ref.read(workApiServiceProvider).invalidateCache();
      ref.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      ref.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
      ref.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
      ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(forceRefresh: true);
      ref.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
      ref.read(workOverviewProvider.notifier).loadOverview();
      if (_loadedTabs.contains(4)) {
        final allSprints = ref.read(allSprintsProvider).sprints;
        final activeSprint = allSprints.where((s) => s.status.toUpperCase() == 'ACTIVE').firstOrNull;
        final sid = activeSprint?.id ?? ref.read(workSprintDashboardProvider).sprint?.id ?? 's8';
        final teamNotifier = ref.read(workSprintTeamProvider.notifier);
        teamNotifier.init(sid);
        final teamState = ref.read(workSprintTeamProvider);
        if (teamState.selectedTeamId != null) {
          teamNotifier.loadTeamDetail(teamState.selectedTeamId!, silent: true);
        }
      }
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
                  if (_loadedTabs.contains(4)) {
                    final allSprints = ref.read(allSprintsProvider).sprints;
                    final activeSprint = allSprints.where((s) => s.status.toUpperCase() == 'ACTIVE').firstOrNull;
                    final sid = activeSprint?.id ?? ref.read(workSprintDashboardProvider).sprint?.id ?? 's8';
                    ref.read(workSprintTeamProvider.notifier).init(sid);
                  }
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

              // 2. Primary Tabs (Board | List | Backlog | Sprints | Teams)
              WorkTabsBar(
                activeTab: _activeTabIndex,
                onTabSelected: (idx) {
                  final clampedIdx = idx.clamp(0, 4);
                  setState(() {
                    _activeTabIndex = clampedIdx;
                    _loadedTabs.add(clampedIdx);
                    _activeBoardDrawerItem = null;
                  });
                  updateTabUrl(_resolveBasePath(), clampedIdx);
                  _refreshTabOnSwitch(clampedIdx);
                },
              ),

              // 3. Tab Views Content (Lazily loaded for fast startup)
              Expanded(
                child: IndexedStack(
                  index: _activeTabIndex.clamp(0, 4),
                  children: [
                    // Tab 0: Board
                    _loadedTabs.contains(0)
                        ? WorkBoardTabView(
                            key: _boardKey,
                            initialSprint: _boardTargetSprint,
                            targetSprintId: _boardTargetSprintId,
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
                            key: _sprintsKey,
                            onOpenDetail: (item) {
                              setState(() => _activeBoardDrawerItem = item);
                            },
                            onQuickAction: (type) => _openCreateDialog(type: type),
                            onCreateItem: _openCreateDialog,
                            onCreateSprint: _openCreateSprintDialog,
                            onOpenFilters: _openFiltersDialog,
                            onOpenInBoard: (sprintId) {
                              _navigateToBoardWithSprint(sprintId);
                            },
                          )
                        : const SizedBox.shrink(),

                    // Tab 4: Team
                    _loadedTabs.contains(4)
                        ? Consumer(
                            builder: (context, ref, _) {
                              final allSprints = ref.watch(allSprintsProvider).sprints;
                              final activeSprint = allSprints.where((s) => s.status.toUpperCase() == 'ACTIVE').firstOrNull;
                              final sprintId = activeSprint?.id ?? ref.watch(workSprintDashboardProvider).sprint?.id ?? (allSprints.isNotEmpty ? allSprints.first.id : '');
                              return SprintTeamTabView(
                                sprintId: sprintId,
                                selectedTeam: 'All Teams',
                                onNavigateToCapacity: _navigateToCapacityTab,
                              );
                            },
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),

          // Detail Drawer for all tabs when an item is tapped
          if (_activeBoardDrawerItem != null) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _activeBoardDrawerItem = null),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ),
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
        ],
      ),
    );
  }
}
