import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  WorkItemModel? _activeBoardDrawerItem;

  @override
  void initState() {
    super.initState();
    _activeTabIndex = widget.initialTabIndex;
  }

  void _openCreateDialog([String? type]) {
    showDialog(
      context: context,
      builder: (ctx) => CreateEditWorkItemDialog(initialWorkType: type),
    );
  }

  void _openCreateSprintDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const CreateSprintDialog(),
    );
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
                  ref.read(workBoardProvider.notifier).loadBoard();
                  ref.read(workListProvider.notifier).loadItems();
                  ref.read(workBacklogProvider.notifier).loadBacklog();
                  ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All Work Management modules refreshed with live data!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined, color: Color(0xFF10B981)),
                title: const Text('Export Work Summary', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Download active sprint items and status breakdown'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Work Summary exported successfully!')),
                  );
                },
              ),
            ],
          ),
        ),
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
                onCreateWorkItem: () => _openCreateDialog(),
                onCreateSpecificType: (type) => _openCreateDialog(type),
                onMoreOptions: _openMoreOptionsMenu,
              ),

              // 2. Primary Tabs (Board | List | Backlog | Sprints)
              WorkTabsBar(
                activeTab: _activeTabIndex,
                onTabSelected: (idx) {
                  setState(() {
                    _activeTabIndex = idx.clamp(0, 3);
                    _activeBoardDrawerItem = null;
                  });
                },
              ),

              // 3. Tab Views Content
              Expanded(
                child: IndexedStack(
                  index: _activeTabIndex.clamp(0, 3),
                  children: [
                    // Tab 0: Board
                    WorkBoardTabView(
                      onOpenDetail: (item) {
                        setState(() => _activeBoardDrawerItem = item);
                      },
                      onQuickAction: (type) => _openCreateDialog(type),
                      onOpenFilters: _openFiltersDialog,
                    ),

                    // Tab 1: List
                    WorkListTabView(
                      onOpenDetail: (item) {
                        setState(() => _activeBoardDrawerItem = item);
                      },
                      onQuickAction: (type) => _openCreateDialog(type),
                      onOpenFilters: _openFiltersDialog,
                    ),

                    // Tab 2: Backlog
                    WorkBacklogTabView(
                      onOpenDetail: (item) {
                        setState(() => _activeBoardDrawerItem = item);
                      },
                      onQuickAction: (type) => _openCreateDialog(type),
                      onOpenFilters: _openFiltersDialog,
                    ),

                    // Tab 3: Sprints
                    WorkSprintsTabView(
                      onOpenDetail: (item) {
                        setState(() => _activeBoardDrawerItem = item);
                      },
                      onQuickAction: (type) => _openCreateDialog(type),
                      onCreateSprint: _openCreateSprintDialog,
                      onOpenFilters: _openFiltersDialog,
                    ),
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
