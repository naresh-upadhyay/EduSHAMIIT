import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';
import '../../utils/work_sprint_date_helper.dart';
import 'sprint_task_board_view.dart';
import 'sprint_capacity_tab_view.dart';
import 'sprint_team_tab_view.dart';
import 'sprint_retrospective_tab_view.dart';
import '../dialogs/edit_sprint_dialog.dart';
import '../dialogs/complete_sprint_dialog.dart';
import '../dialogs/add_backlog_items_to_sprint_dialog.dart';
import '../dialogs/move_sprint_items_dialog.dart';

class WorkSprintsTabView extends ConsumerStatefulWidget {
  final Function(WorkItemModel item) onOpenDetail;
  final VoidCallback? onOpenFilters;
  final Function(String type) onQuickAction;
  final VoidCallback onCreateSprint;

  const WorkSprintsTabView({
    super.key,
    required this.onOpenDetail,
    this.onOpenFilters,
    required this.onQuickAction,
    required this.onCreateSprint,
  });

  @override
  ConsumerState<WorkSprintsTabView> createState() => _WorkSprintsTabViewState();
}

class _WorkSprintsTabViewState extends ConsumerState<WorkSprintsTabView> {
  String _selectedBoard = 'Institute Work Board';
  String _selectedSprint = 'Current Sprint (Sprint 8)';
  String _selectedTeam = 'All Teams';
  int _activeSubTabIndex = 0;

  // Selected work item IDs for bulk actions
  final Set<String> _selectedItemIds = {};

  // Azure DevOps Filter Bar State
  bool _isFilterBarOpen = false;
  String _keywordFilter = '';
  String _typeFilter = 'All';
  String _assigneeFilter = 'All';
  String _priorityFilter = 'All';
  String _statusFilter = 'All';
  String _categoryFilter = 'All';

  int get _activeFiltersCount {
    int count = 0;
    if (_keywordFilter.trim().isNotEmpty) count++;
    if (_typeFilter != 'All') count++;
    if (_assigneeFilter != 'All') count++;
    if (_priorityFilter != 'All') count++;
    if (_statusFilter != 'All') count++;
    if (_categoryFilter != 'All') count++;
    return count;
  }

  void _clearAllFilters() {
    setState(() {
      _keywordFilter = '';
      _searchController.clear();
      _typeFilter = 'All';
      _assigneeFilter = 'All';
      _priorityFilter = 'All';
      _statusFilter = 'All';
      _categoryFilter = 'All';
      _currentPage = 1;
    });
  }

  int _currentPage = 1;
  int _pageSize = 10;

  List<WorkAssigneeModel> _assigneesList = [];

  Future<void> _loadAssignees() async {
    try {
      final api = ref.read(workApiServiceProvider);
      final list = await api.getAssignableUsers(limit: 60);
      if (mounted) {
        setState(() {
          _assigneesList = list;
        });
      }
    } catch (_) {}
  }

  final Set<String> _expandedStoryNumbers = {'ST-101', 'ST-102', 'ST-103'};
  final TextEditingController _searchController = TextEditingController();

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF2563EB);
    }
  }

  void _openEditGoalDialog(WorkSprintModel? sprint) {
    if (sprint == null) return;
    final controller = TextEditingController(text: sprint.goal);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        title: const Text('Edit Sprint Goal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Describe key sprint objectives...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newGoal = controller.text.trim();
              final nav = Navigator.of(ctx);
              await ref.read(workSprintDashboardProvider.notifier).updateSprint(sprint.id, {'goal': newGoal});
              nav.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAssignees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isCompleted(String status) {
    final s = status.toUpperCase();
    return s == 'COMPLETED' || s == 'RESOLVED' || s == 'DONE';
  }

  bool _isInProgress(String status) {
    final s = status.toUpperCase();
    return s == 'ACTIVE' || s == 'IN PROGRESS' || s == 'IN_PROGRESS';
  }

  bool _isNotStarted(String status) {
    final s = status.toUpperCase();
    return s == 'NEW' || s == 'PLANNED' || s == 'NOT STARTED' || s == 'NOT_STARTED';
  }

  bool _isBlocked(String status) {
    final s = status.toUpperCase();
    return s == 'BLOCKED';
  }

  bool _statusMatches(String status, String target) {
    if (target == 'All') return true;
    if (target == 'COMPLETED') return _isCompleted(status);
    if (target == 'ACTIVE') return _isInProgress(status);
    if (target == 'NEW') return _isNotStarted(status);
    if (target == 'BLOCKED') return _isBlocked(status);
    if (target == 'RESOLVED') return status.toUpperCase() == 'RESOLVED';
    return status.toUpperCase() == target.toUpperCase();
  }

  List<WorkItemModel> _filterStories(List<WorkItemModel> rawStories) {
    final kw = _keywordFilter.trim().toLowerCase();

    return rawStories.map((story) {
      final matchingChildren = story.children.where((child) {
        if (kw.isNotEmpty) {
          final inNum = child.itemNumber.toLowerCase().contains(kw);
          final inTitle = child.title.toLowerCase().contains(kw);
          if (!inNum && !inTitle) return false;
        }
        if (_typeFilter != 'All' && child.workType.toUpperCase() != _typeFilter.toUpperCase()) {
          return false;
        }
        if (_statusFilter != 'All' && !_statusMatches(child.status, _statusFilter)) {
          return false;
        }
        if (_priorityFilter != 'All' && child.priority.toUpperCase() != _priorityFilter.toUpperCase()) {
          return false;
        }
        if (_categoryFilter != 'All' && child.category.toLowerCase() != _categoryFilter.toLowerCase()) {
          return false;
        }
        if (_assigneeFilter == 'Unassigned') {
          if (child.assignees.isNotEmpty) return false;
        } else if (_assigneeFilter != 'All') {
          final matches = child.assignees.any((a) => a.fullName.toLowerCase() == _assigneeFilter.toLowerCase());
          if (!matches) return false;
        }
        return true;
      }).toList();

      bool storyMatches = true;
      if (kw.isNotEmpty) {
        final inNum = story.itemNumber.toLowerCase().contains(kw);
        final inTitle = story.title.toLowerCase().contains(kw);
        if (!inNum && !inTitle) storyMatches = false;
      }
      if (_typeFilter != 'All' && story.workType.toUpperCase() != _typeFilter.toUpperCase()) {
        storyMatches = false;
      }
      if (_statusFilter != 'All' && !_statusMatches(story.status, _statusFilter)) {
        storyMatches = false;
      }
      if (_priorityFilter != 'All' && story.priority.toUpperCase() != _priorityFilter.toUpperCase()) {
        storyMatches = false;
      }
      if (_categoryFilter != 'All' && story.category.toLowerCase() != _categoryFilter.toLowerCase()) {
        storyMatches = false;
      }
      if (_assigneeFilter == 'Unassigned') {
        if (story.assignees.isNotEmpty) storyMatches = false;
      } else if (_assigneeFilter != 'All') {
        final matches = story.assignees.any((a) => a.fullName.toLowerCase() == _assigneeFilter.toLowerCase());
        if (!matches) storyMatches = false;
      }

      if (storyMatches) {
        final hasChildFilters = _typeFilter != 'All' || _statusFilter != 'All' || _priorityFilter != 'All' || _assigneeFilter != 'All';
        return story.copyWith(children: hasChildFilters ? matchingChildren : story.children);
      } else if (matchingChildren.isNotEmpty) {
        _expandedStoryNumbers.add(story.itemNumber);
        return story.copyWith(children: matchingChildren);
      } else {
        return null;
      }
    }).whereType<WorkItemModel>().toList();
  }

  void _onBoardChanged(String? newBoard) {
    if (newBoard == null) return;
    setState(() {
      _selectedBoard = newBoard;
      _currentPage = 1;
      _selectedItemIds.clear();
    });
    final sid = ref.read(workSprintDashboardProvider).sprint?.id ?? 's8';
    ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(
      sprintId: sid,
      boardId: newBoard == 'Academic Board' ? 'academic' : 'default',
      team: _selectedTeam,
    );
    ref.read(workSprintRetroProvider.notifier).init(sid, teamName: _selectedTeam);
  }

  void _onSprintChanged(String? newSprint) {
    if (newSprint == null) return;
    setState(() {
      _selectedSprint = newSprint;
      _currentPage = 1;
      _selectedItemIds.clear();
    });
    String targetSid = 's8';
    if (newSprint.contains('Sprint 9')) targetSid = 's9';
    if (newSprint.contains('Sprint 7')) targetSid = 's7';
    if (newSprint.contains('Sprint 10')) targetSid = 's10';

    ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(
      sprintId: targetSid,
      boardId: _selectedBoard == 'Academic Board' ? 'academic' : 'default',
      team: _selectedTeam,
    );
    ref.read(workSprintRetroProvider.notifier).init(targetSid, teamName: _selectedTeam);
    ref.read(workSprintCapacityProvider.notifier).init(sprintId: targetSid, team: _selectedTeam);
    ref.read(workSprintTeamProvider.notifier).init(targetSid);
  }

  void _onTeamFilterChanged(String teamName) {
    setState(() {
      _selectedTeam = teamName;
      _currentPage = 1;
      _selectedItemIds.clear();
    });
    ref.read(workSprintCapacityProvider.notifier).selectTeam(teamName);
    final sid = ref.read(workSprintDashboardProvider).sprint?.id ?? 's8';
    ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(
      sprintId: sid,
      boardId: _selectedBoard == 'Academic Board' ? 'academic' : 'default',
      team: teamName,
    );
    ref.read(workSprintRetroProvider.notifier).init(sid, teamName: teamName);
  }

  Widget _buildActiveSubTabView(
    BuildContext context,
    WorkSprintDashboardState sprintState,
    List<WorkItemModel> filteredStories,
    bool isDark,
  ) {
    final sprintId = sprintState.sprint?.id ?? 's8';
    final allFilteredItems = <WorkItemModel>[];
    for (final s in filteredStories) {
      allFilteredItems.add(s);
      allFilteredItems.addAll(s.children);
    }

    switch (_activeSubTabIndex) {
      case 1:
        return SprintTaskBoardView(
          items: allFilteredItems,
          onOpenDetail: widget.onOpenDetail,
          onQuickAction: widget.onQuickAction,
          sprintId: sprintId,
        );
      case 2:
        return SprintCapacityTabView(
          sprintId: sprintId,
          selectedTeam: _selectedTeam,
          onTeamChanged: _onTeamFilterChanged,
        );
      case 3:
        return SprintTeamTabView(
          sprintId: sprintId,
          selectedTeam: _selectedTeam,
        );
      case 4:
        return SprintRetrospectiveTabView(
          sprintId: sprintId,
          selectedTeam: _selectedTeam,
          boardName: _selectedBoard,
          filterKeyword: _keywordFilter,
          statusFilter: _statusFilter,
          priorityFilter: _priorityFilter,
        );
      case 0:
      default:
        return _buildSprintTreeTable(context, sprintState, filteredStories, isDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sprintState = ref.watch(workSprintDashboardProvider);
    final rawStories = sprintState.items.isNotEmpty
        ? sprintState.items
        : ref.watch(workBacklogProvider).stories;
    final filteredStories = _filterStories(rawStories);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Sub-filters Bar
          _buildFilterBar(context, isDark),

          // 2. Inline Collapsible Azure DevOps Filter Bar
          if (_isFilterBarOpen) ...[
            _buildAzureDevOpsFilterBar(isDark),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 16),
          ],

          // 3. Sprint Header Cards & KPIs (Always visible across all sprint sub-tabs)
          _buildSprintHeaderCards(context, sprintState, filteredStories, isDark),
          const SizedBox(height: 18),

          // 4. Sub-tabs bar
          _buildSubTabsBar(isDark),
          const SizedBox(height: 16),

          // 5. Tab Content
          if (_activeSubTabIndex == 0) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1150;
                final leftView = _buildActiveSubTabView(context, sprintState, filteredStories, isDark);

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: leftView,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 3,
                        child: _buildRightSidebar(context, sprintState, isDark),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      leftView,
                      const SizedBox(height: 20),
                      _buildRightSidebar(context, sprintState, isDark),
                    ],
                  );
                }
              },
            ),
          ] else ...[
            _buildActiveSubTabView(context, sprintState, filteredStories, isDark),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 950;
        final leftSelectors = Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildSelector('Board', _selectedBoard, ['Institute Work Board', 'Academic Board'], (v) {
              _onBoardChanged(v);
            }, isDark),
            _buildSelector('Sprint', _selectedSprint, [
              'Current Sprint (Sprint 8)',
              'Sprint 9 (Planned)',
              'Sprint 7 (Closed)',
            ], (v) {
              _onSprintChanged(v);
            }, isDark),
            _buildSearchableTeamSelector(context, isDark),
          ],
        );

        final rightButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Azure DevOps Filters Toggle Button with Active Badge
            InkWell(
              onTap: () {
                setState(() => _isFilterBarOpen = !_isFilterBarOpen);
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _isFilterBarOpen || _activeFiltersCount > 0
                      ? const Color(0xFF2563EB)
                      : (isDark ? const Color(0xFF13182C) : Colors.white),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isFilterBarOpen || _activeFiltersCount > 0
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_list_rounded,
                      size: 16,
                      color: _isFilterBarOpen || _activeFiltersCount > 0
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _isFilterBarOpen || _activeFiltersCount > 0
                            ? Colors.white
                            : (isDark ? Colors.white : const Color(0xFF334155)),
                      ),
                    ),
                    if (_activeFiltersCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_activeFiltersCount',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: widget.onCreateSprint,
              icon: const Icon(Icons.add, size: 14, color: Colors.white),
              label: const Text('New Sprint', style: TextStyle(fontSize: 12, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leftSelectors,
              const SizedBox(height: 10),
              rightButtons,
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: leftSelectors),
              const SizedBox(width: 12),
              rightButtons,
            ],
          );
        }
      },
    );
  }

  Widget _buildAzureDevOpsFilterBar(bool isDark) {
    final bgColor = isDark ? const Color(0xFF13182C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 1. Keyword search
              SizedBox(
                width: 240,
                height: 36,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _keywordFilter = v.trim()),
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Filter by keyword...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF3B82F6)),
                    suffixIcon: _keywordFilter.isNotEmpty
                        ? InkWell(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _keywordFilter = '');
                            },
                            child: const Icon(Icons.close_rounded, size: 14),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                  ),
                ),
              ),

              // 2. Types
              _buildDevOpsFilterDropdown(
                label: 'Types',
                value: _typeFilter,
                items: const ['All', 'TASK', 'STORY', 'BUG', 'EPIC'],
                onChanged: (v) => setState(() => _typeFilter = v!),
                isDark: isDark,
              ),

              // 3. Status
              _buildDevOpsFilterDropdown(
                label: 'Status',
                value: _statusFilter,
                items: const ['All', 'NEW', 'ACTIVE', 'RESOLVED', 'COMPLETED'],
                onChanged: (v) => setState(() => _statusFilter = v!),
                isDark: isDark,
              ),

              // 4. Assigned To
              _buildAssigneeFilterDropdown(isDark),

              // 5. Priority
              _buildPriorityFilterDropdown(isDark),

              // 6. Area
              _buildDevOpsFilterDropdown(
                label: 'Area',
                value: _categoryFilter,
                items: const [
                  'All',
                  'Academic',
                  'IT Services',
                  'Administration',
                  'Department',
                  'Student Activity',
                  'Facilities',
                  'Examination'
                ],
                onChanged: (v) => setState(() => _categoryFilter = v!),
                isDark: isDark,
              ),

              // Clear all
              if (_activeFiltersCount > 0)
                InkWell(
                  onTap: _clearAllFilters,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_alt_off_rounded, size: 14, color: Color(0xFFEF4444)),
                        SizedBox(width: 4),
                        Text(
                          'Clear all',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Active Filter Chips Tray
          if (_activeFiltersCount > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Active filters:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                if (_keywordFilter.isNotEmpty)
                  _buildActiveFilterChip('Keyword: "$_keywordFilter"', () {
                    _searchController.clear();
                    setState(() => _keywordFilter = '');
                  }, isDark),
                if (_typeFilter != 'All')
                  _buildActiveFilterChip('Type: $_typeFilter', () => setState(() => _typeFilter = 'All'), isDark),
                if (_statusFilter != 'All')
                  _buildActiveFilterChip('Status: $_statusFilter', () => setState(() => _statusFilter = 'All'), isDark),
                if (_priorityFilter != 'All')
                  _buildActiveFilterChip('Priority: $_priorityFilter', () => setState(() => _priorityFilter = 'All'), isDark),
                if (_assigneeFilter != 'All')
                  _buildActiveFilterChip('Assigned: $_assigneeFilter', () => setState(() => _assigneeFilter = 'All'), isDark),
                if (_categoryFilter != 'All')
                  _buildActiveFilterChip('Area: $_categoryFilter', () => setState(() => _categoryFilter = 'All'), isDark),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDevOpsFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    final borderColor = isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              isDense: true,
              dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssigneeFilterDropdown(bool isDark) {
    final borderColor = isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1);
    final allAssigneeNames = [
      'All',
      'Unassigned',
      ..._assigneesList.map((a) => a.fullName).toSet(),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Assigned to: ',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: allAssigneeNames.contains(_assigneeFilter) ? _assigneeFilter : 'All',
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              isDense: true,
              dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              items: allAssigneeNames.map((name) {
                return DropdownMenuItem<String>(
                  value: name,
                  child: Text(name),
                );
              }).toList(),
              onChanged: (v) => setState(() => _assigneeFilter = v!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityFilterDropdown(bool isDark) {
    final borderColor = isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Priority: ',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _priorityFilter,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              isDense: true,
              dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              items: const ['All', 'CRITICAL', 'HIGH', 'MEDIUM', 'LOW'].map((p) {
                return DropdownMenuItem<String>(
                  value: p,
                  child: Text(p),
                );
              }).toList(),
              onChanged: (v) => setState(() => _priorityFilter = v!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  Widget _buildSelector(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
    bool isDark,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13182C) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              isDense: true,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
              onChanged: onChanged,
              items: items.map((String item) {
                return DropdownMenuItem<String>(value: item, child: Text(item));
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  final GlobalKey _teamSelectorKey = GlobalKey();

  Widget _buildSearchableTeamSelector(BuildContext context, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Team: ',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        InkWell(
          key: _teamSelectorKey,
          onTap: () => _openTeamSelectionMenu(context, isDark),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13182C) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedTeam,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openTeamSelectionMenu(BuildContext context, bool isDark) {
    final searchController = TextEditingController();
    final defaultTeams = [
      {'name': 'All Teams', 'icon': Icons.groups_outlined},
      {'name': 'Digital Campus Team', 'icon': Icons.groups_rounded},
      {'name': 'Academic Systems Team', 'icon': Icons.school_outlined},
      {'name': 'Examination Team', 'icon': Icons.assignment_turned_in_outlined},
      {'name': 'IT Operations Team', 'icon': Icons.computer_rounded},
      {'name': 'Infrastructure & Maintenance Team', 'icon': Icons.apartment_rounded},
      {'name': 'Library Systems Team', 'icon': Icons.menu_book_rounded},
    ];

    final renderBox = _teamSelectorKey.currentContext?.findRenderObject() as RenderBox?;
    Offset targetOffset = const Offset(360, 130);
    if (renderBox != null) {
      targetOffset = renderBox.localToGlobal(Offset.zero);
    }

    showDialog(
      context: context,
      barrierColor: Colors.black12,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = searchController.text.trim().toLowerCase();
          final filtered = defaultTeams.where((t) {
            return (t['name'] as String).toLowerCase().contains(query);
          }).toList();

          return Stack(
            children: [
              Positioned(
                top: targetOffset.dy + 36,
                left: targetOffset.dx.clamp(16.0, MediaQuery.of(context).size.width - 270.0),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: isDark ? const Color(0xFF13182C) : Colors.white,
                  child: Container(
                    width: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: TextField(
                            controller: searchController,
                            autofocus: true,
                            onChanged: (_) => setDialogState(() {}),
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Search team...',
                              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                              prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: filtered.map((t) {
                                final name = t['name'] as String;
                                final icon = t['icon'] as IconData;
                                final isSel = _selectedTeam == name;

                                return InkWell(
                                  onTap: () {
                                    _onTeamFilterChanged(name);
                                    Navigator.pop(ctx);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    color: isSel
                                        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
                                        : Colors.transparent,
                                    child: Row(
                                      children: [
                                        Icon(
                                          icon,
                                          size: 16,
                                          color: isSel ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                              color: isSel
                                                  ? const Color(0xFF2563EB)
                                                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                            ),
                                          ),
                                        ),
                                        if (isSel)
                                          const Icon(Icons.check_box_rounded, size: 16, color: Color(0xFF2563EB)),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSprintHeaderCards(
    BuildContext context,
    WorkSprintDashboardState sprintState,
    List<WorkItemModel> filteredStories,
    bool isDark,
  ) {
    final sprint = sprintState.sprint;
    final allItems = <WorkItemModel>[];
    for (final s in filteredStories) {
      allItems.add(s);
      allItems.addAll(s.children);
    }

    final rawMetrics = sprintState.metrics;
    final int totalItems;
    final int completedItems;
    final int inProgressItems;
    final int notStartedItems;
    final int blockedItems;

    if (_activeFiltersCount > 0 || allItems.isNotEmpty) {
      totalItems = allItems.length;
      completedItems = allItems.where((i) => _isCompleted(i.status)).length;
      inProgressItems = allItems.where((i) => _isInProgress(i.status)).length;
      notStartedItems = allItems.where((i) => _isNotStarted(i.status)).length;
      blockedItems = allItems.where((i) => _isBlocked(i.status)).length;
    } else {
      totalItems = (rawMetrics['total_items'] as num?)?.toInt() ?? 44;
      completedItems = (rawMetrics['completed_items'] as num?)?.toInt() ?? 29;
      inProgressItems = (rawMetrics['in_progress_items'] as num?)?.toInt() ?? 8;
      notStartedItems = (rawMetrics['not_started_items'] as num?)?.toInt() ?? 5;
      blockedItems = (rawMetrics['blocked_items'] as num?)?.toInt() ?? 2;
    }

    final progressPct = totalItems > 0 ? ((completedItems / totalItems) * 100).round() : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 950;

        final sprintInfoCard = Container(
          width: isWide ? 270 : double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13182C) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.flag_outlined, size: 16, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sprint?.name ?? 'Sprint 8',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                sprint != null && sprint.startDateFmt.isNotEmpty && !sprint.startDateFmt.contains('2025')
                    ? '${sprint.startDateFmt} – ${sprint.endDateFmt} (${sprint.durationDays} days)'
                    : WorkSprintDateHelper.currentSprintFullDurationRange,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.grid_view_rounded, size: 12, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _selectedBoard,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (progressPct / 100).clamp(0.0, 1.0),
                        backgroundColor: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$progressPct%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$completedItems of $totalItems work items completed',
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        );

        final kpiCards = [
          _buildKpiCard(
            'Total Items',
            '$totalItems',
            icon: Icons.layers_outlined,
            color: const Color(0xFF2563EB),
            isSelected: _statusFilter == 'All',
            onTap: () {
              setState(() {
                _statusFilter = 'All';
                _currentPage = 1;
              });
            },
            isDark: isDark,
          ),
          _buildKpiCard(
            'Completed',
            '$completedItems',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF10B981),
            isSelected: _statusFilter == 'COMPLETED',
            onTap: () {
              setState(() {
                _statusFilter = _statusFilter == 'COMPLETED' ? 'All' : 'COMPLETED';
                _currentPage = 1;
              });
            },
            isDark: isDark,
          ),
          _buildKpiCard(
            'In Progress',
            '$inProgressItems',
            icon: Icons.sync_rounded,
            color: const Color(0xFF3B82F6),
            isSelected: _statusFilter == 'ACTIVE',
            onTap: () {
              setState(() {
                _statusFilter = _statusFilter == 'ACTIVE' ? 'All' : 'ACTIVE';
                _currentPage = 1;
              });
            },
            isDark: isDark,
          ),
          _buildKpiCard(
            'Not Started',
            '$notStartedItems',
            icon: Icons.stop_circle_outlined,
            color: const Color(0xFF94A3B8),
            isSelected: _statusFilter == 'NEW',
            onTap: () {
              setState(() {
                _statusFilter = _statusFilter == 'NEW' ? 'All' : 'NEW';
                _currentPage = 1;
              });
            },
            isDark: isDark,
          ),
          _buildKpiCard(
            'Blocked',
            '$blockedItems',
            icon: Icons.block_flipped,
            color: const Color(0xFFEF4444),
            isSelected: _statusFilter == 'BLOCKED',
            onTap: () {
              setState(() {
                _statusFilter = _statusFilter == 'BLOCKED' ? 'All' : 'BLOCKED';
                _currentPage = 1;
              });
            },
            isDark: isDark,
          ),
        ];

        final sprintGoalCard = Container(
          height: 135,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13182C) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.track_changes_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Text(
                    'Sprint Goal',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => _openEditGoalDialog(sprint),
                    child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  sprint?.goal.isNotEmpty == true
                      ? sprint!.goal
                      : 'Deliver student portal enhancement, examination notifications and key infrastructure fixes.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );

        // Dynamic Burndown Line Chart Spots with safe bounds scaling
        final List<FlSpot> idealSpots = [];
        final List<FlSpot> actualSpots = [];

        final effectiveTotal = (totalItems > 0 ? totalItems : 6).toDouble();
        final effectiveCompleted = completedItems.clamp(0, totalItems).toDouble();
        final effectiveRemaining = (effectiveTotal - effectiveCompleted).clamp(0.0, effectiveTotal);

        if (sprintState.burndownPoints.isNotEmpty) {
          final firstIdeal = sprintState.burndownPoints.first.idealRemaining;
          final needsScale = firstIdeal > 0 && firstIdeal != effectiveTotal && effectiveTotal > 0;
          final scaleFactor = needsScale ? (effectiveTotal / firstIdeal) : 1.0;

          for (int i = 0; i < sprintState.burndownPoints.length; i++) {
            final pt = sprintState.burndownPoints[i];
            final dayX = (i + 1).toDouble().clamp(1.0, 14.0);
            final idealY = (pt.idealRemaining * scaleFactor).clamp(0.0, effectiveTotal);
            final actualY = (pt.actualRemaining * scaleFactor).clamp(0.0, effectiveTotal);
            idealSpots.add(FlSpot(dayX, idealY));
            actualSpots.add(FlSpot(dayX, actualY));
          }
        } else {
          idealSpots.addAll([
            FlSpot(1, effectiveTotal),
            const FlSpot(14, 0),
          ]);
          actualSpots.addAll([
            FlSpot(1, effectiveTotal),
            FlSpot(3, (effectiveTotal * 0.90).clamp(effectiveRemaining, effectiveTotal)),
            FlSpot(5, (effectiveTotal * 0.75).clamp(effectiveRemaining, effectiveTotal)),
            FlSpot(7, (effectiveTotal * 0.60).clamp(effectiveRemaining, effectiveTotal)),
            FlSpot(9, (effectiveTotal * 0.45).clamp(effectiveRemaining, effectiveTotal)),
            FlSpot(11, (effectiveTotal * 0.30).clamp(effectiveRemaining, effectiveTotal)),
            FlSpot(14, effectiveRemaining),
          ]);
        }

        double maxYVal = effectiveTotal;
        for (final s in idealSpots) {
          if (s.y > maxYVal) maxYVal = s.y;
        }
        for (final s in actualSpots) {
          if (s.y > maxYVal) maxYVal = s.y;
        }
        if (maxYVal <= 0) maxYVal = 6.0;
        final maxChartY = (maxYVal * 1.15).ceilToDouble();

        final burndownChart = Container(
          height: 135,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13182C) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sprint Burndown',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF93C5FD), shape: BoxShape.circle)),
                      const SizedBox(width: 3),
                      const Text('Ideal', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                      const SizedBox(width: 8),
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle)),
                      const SizedBox(width: 3),
                      const Text('Remaining', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRect(
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxChartY > 4 ? (maxChartY / 3).roundToDouble().clamp(1.0, 50.0) : 1.0,
                        getDrawingHorizontalLine: (val) => FlLine(
                          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: maxChartY > 4 ? (maxChartY / 2).roundToDouble().clamp(1.0, 50.0) : 2.0,
                            getTitlesWidget: (val, meta) {
                              if (val == 0 || val == maxChartY) {
                                return Text('${val.toInt()}', style: const TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 14,
                            interval: 6,
                            getTitlesWidget: (val, meta) {
                              if (val == 1) return const Text('D1', style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8)));
                              if (val == 7) return const Text('D7', style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8)));
                              if (val == 14) return const Text('D14', style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8)));
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 1,
                      maxX: 14,
                      minY: 0,
                      maxY: maxChartY,
                      lineBarsData: [
                        // Ideal Line (dotted)
                        LineChartBarData(
                          spots: idealSpots,
                          isCurved: false,
                          color: const Color(0xFF93C5FD),
                          barWidth: 1.5,
                          dotData: const FlDotData(show: false),
                          dashArray: [4, 4],
                        ),
                        // Remaining Line (solid blue)
                        LineChartBarData(
                          spots: actualSpots,
                          isCurved: false,
                          color: const Color(0xFF2563EB),
                          barWidth: 2,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        if (constraints.maxWidth >= 1550) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sprintInfoCard,
              const SizedBox(width: 12),
              ...kpiCards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: c))),
              const SizedBox(width: 4),
              SizedBox(width: 240, child: sprintGoalCard),
              const SizedBox(width: 12),
              SizedBox(width: 240, child: burndownChart),
            ],
          );
        } else if (constraints.maxWidth >= 950) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tier 1: Sprint Info Card + 5 KPI Cards
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sprintInfoCard,
                  const SizedBox(width: 12),
                  ...kpiCards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: c))),
                ],
              ),
              const SizedBox(height: 12),
              // Tier 2: Sprint Goal Card + Burndown Chart
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: sprintGoalCard),
                  const SizedBox(width: 12),
                  Expanded(flex: 5, child: burndownChart),
                ],
              ),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sprintInfoCard,
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kpiCards.map((c) => SizedBox(width: (constraints.maxWidth - 20) / 2, child: c)).toList(),
              ),
              const SizedBox(height: 12),
              sprintGoalCard,
              const SizedBox(height: 12),
              burndownChart,
            ],
          );
        }
      },
    );
  }

  Widget _buildKpiCard(
    String title,
    String value, {
    required IconData icon,
    required Color color,
    required bool isDark,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      key: ValueKey('kpi_$title'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.20 : 0.08)
              : (isDark ? const Color(0xFF13182C) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isSelected
                          ? color
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabsBar(bool isDark) {
    final subTabs = [
      'Sprint Backlog',
      'Boards (Task Board)',
      'Capacity',
      'Team',
      'Retrospective',
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: subTabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final label = entry.value;
          final isActive = idx == _activeSubTabIndex;

          return InkWell(
            onTap: () => setState(() => _activeSubTabIndex = idx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSprintTreeTable(
    BuildContext context,
    WorkSprintDashboardState sprintState,
    List<WorkItemModel> filteredStories,
    bool isDark,
  ) {
    final totalStories = filteredStories.length;
    final totalItems = totalStories + filteredStories.fold<int>(0, (sum, s) => sum + s.children.length);
    final totalPages = (totalStories / _pageSize).ceil().clamp(1, 9999);
    final currentPage = _currentPage.clamp(1, totalPages);
    final startIndex = totalStories == 0 ? 0 : (currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalStories);
    final pagedStories = totalStories == 0 ? <WorkItemModel>[] : filteredStories.sublist(startIndex, endIndex);

    // Current page visible IDs for master checkbox
    final allVisibleItemIds = <String>{};
    for (final s in pagedStories) {
      allVisibleItemIds.add(s.id);
      for (final c in s.children) {
        allVisibleItemIds.add(c.id);
      }
    }
    final bool allSelected = allVisibleItemIds.isNotEmpty && allVisibleItemIds.every((id) => _selectedItemIds.contains(id));
    final bool someSelected = allVisibleItemIds.any((id) => _selectedItemIds.contains(id)) && !allSelected;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          // 1. Toolbar
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, toolbarConstraints) {
                final bool isCompact = toolbarConstraints.maxWidth < 800;
                final searchWidget = SizedBox(
                  width: isCompact ? double.infinity : 240,
                  height: 32,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {
                      _keywordFilter = v.trim();
                      _currentPage = 1;
                    }),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                      hintText: 'Search work items in this sprint...',
                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                );

                final actionButtons = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: isCompact ? WrapAlignment.start : WrapAlignment.end,
                  children: [
                    // Add Work Item Popup Menu
                    PopupMenuButton<String>(
                      tooltip: 'Add Work Item',
                      onSelected: (val) {
                        if (val == 'BACKLOG') {
                          final sprint = sprintState.sprint;
                          if (sprint != null) {
                            showDialog(
                              context: context,
                              builder: (_) => AddBacklogItemsToSprintDialog(sprintId: sprint.id),
                            );
                          }
                        } else {
                          widget.onQuickAction(val);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'TASK',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF3B82F6)),
                              SizedBox(width: 8),
                              Text('New Task', style: TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'STORY',
                          child: Row(
                            children: [
                              Icon(Icons.auto_stories_outlined, size: 16, color: Color(0xFF8B5CF6)),
                              SizedBox(width: 8),
                              Text('New Story', style: TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'BUG',
                          child: Row(
                            children: [
                              Icon(Icons.bug_report_outlined, size: 16, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Text('Report Bug', style: TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'BACKLOG',
                          child: Row(
                            children: [
                              Icon(Icons.playlist_add_rounded, size: 16, color: Color(0xFF2563EB)),
                              SizedBox(width: 8),
                              Text('Add from Backlog...', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Add Work Item', style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600)),
                            SizedBox(width: 3),
                            Icon(Icons.arrow_drop_down, size: 14, color: Colors.white),
                          ],
                        ),
                      ),
                    ),

                    // Link Work Item Button
                    OutlinedButton.icon(
                      onPressed: () {
                        if (_selectedItemIds.isNotEmpty) {
                          for (final s in filteredStories) {
                            if (_selectedItemIds.contains(s.id)) {
                              widget.onOpenDetail(s);
                              return;
                            }
                            for (final c in s.children) {
                              if (_selectedItemIds.contains(c.id)) {
                                widget.onOpenDetail(c);
                                return;
                              }
                            }
                          }
                        } else if (filteredStories.isNotEmpty) {
                          widget.onOpenDetail(filteredStories.first);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No work items to link')),
                          );
                        }
                      },
                      icon: const Icon(Icons.link_rounded, size: 14, color: Color(0xFF64748B)),
                      label: Text('Link Work Item', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        side: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),

                    // Move to Another Sprint Button
                    OutlinedButton.icon(
                      onPressed: () {
                        final sprint = sprintState.sprint;
                        if (sprint == null) return;
                        final idsToMove = _selectedItemIds.isNotEmpty
                            ? _selectedItemIds.toList()
                            : allVisibleItemIds.toList();

                        if (idsToMove.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No items to move')),
                          );
                          return;
                        }

                        showDialog(
                          context: context,
                          builder: (_) => MoveSprintItemsDialog(
                            currentSprintId: sprint.id,
                            itemIds: idsToMove,
                          ),
                        );
                      },
                      icon: const Icon(Icons.drive_file_move_outlined, size: 14, color: Color(0xFF64748B)),
                      label: Text('Move to Another Sprint', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        side: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),

                    // Bulk Actions Popup Menu
                    PopupMenuButton<String>(
                      tooltip: 'Bulk Actions',
                      onSelected: (action) async {
                        if (_selectedItemIds.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Select items first using checkboxes.')),
                          );
                          return;
                        }
                        final sprint = sprintState.sprint;
                        if (sprint == null) return;

                        if (action == 'MOVE') {
                          showDialog(
                            context: context,
                            builder: (_) => MoveSprintItemsDialog(
                              currentSprintId: sprint.id,
                              itemIds: _selectedItemIds.toList(),
                            ),
                          );
                        } else if (action == 'REMOVE') {
                          for (final id in _selectedItemIds) {
                            await ref.read(workSprintDashboardProvider.notifier).removeItemFromSprint(sprint.id, id);
                          }
                          setState(() => _selectedItemIds.clear());
                        } else if (action == 'COMPLETE') {
                          final api = ref.read(workApiServiceProvider);
                          await api.bulkUpdateWorkItems(itemIds: _selectedItemIds.toList(), status: 'COMPLETED');
                          ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(sprintId: sprint.id);
                          setState(() => _selectedItemIds.clear());
                        } else if (action == 'DELETE') {
                          _confirmBulkDeleteSelected(context);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'MOVE',
                          child: Row(
                            children: [
                              Icon(Icons.drive_file_move_outlined, size: 16, color: Color(0xFF2563EB)),
                              SizedBox(width: 8),
                              Text('Move to Another Sprint', style: TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'COMPLETE',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                              SizedBox(width: 8),
                              Text('Mark as Completed', style: TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'REMOVE',
                          child: Row(
                            children: [
                              Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Text('Remove from Sprint', style: TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'DELETE',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Text('Delete Selected', style: TextStyle(fontSize: 12.5, color: Color(0xFFEF4444))),
                            ],
                          ),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.swap_vert_rounded, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text('Bulk Actions', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchWidget,
                      const SizedBox(height: 10),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  children: [
                    searchWidget,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: actionButtons,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 2. Floating Selection Action Bar when items are checked
          if (_selectedItemIds.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildSelectionActionBar(context, isDark),
            ),
          ],

          Divider(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0), height: 1),

          // 3. Tree Table List
          if (filteredStories.isEmpty)
            Container(
              height: 200,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_alt_off_rounded, size: 28, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 8),
                  const Text('No sprint items match the current filters.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _clearAllFilters,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Clear Filters', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const minWidth = 740.0;
                final targetWidth = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: targetWidth,
                    child: Column(
                      children: [
                        // Table Header Row with Master Checkbox
                        _buildTableHeader(
                          allSelected: allSelected,
                          someSelected: someSelected,
                          onToggleAll: () {
                            setState(() {
                              if (allSelected) {
                                for (final id in allVisibleItemIds) {
                                  _selectedItemIds.remove(id);
                                }
                              } else {
                                _selectedItemIds.addAll(allVisibleItemIds);
                              }
                            });
                          },
                          pagedStories: pagedStories,
                          isDark: isDark,
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: pagedStories.length,
                          itemBuilder: (context, sIdx) {
                            final story = pagedStories[sIdx];
                            final isExpanded = _expandedStoryNumbers.contains(story.itemNumber);
                            final children = story.children;

                            final isStoryChecked = _selectedItemIds.contains(story.id);
                            final hasCheckedChildren = children.any((c) => _selectedItemIds.contains(c.id));
                            final isStoryIndeterminate = !isStoryChecked && hasCheckedChildren;

                            return Column(
                              children: [
                                // Story Row
                                InkWell(
                                  onTap: () => widget.onOpenDetail(story),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: isStoryChecked
                                          ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.15 : 0.05)
                                          : (isDark ? const Color(0xFF13182C) : Colors.white),
                                      border: Border(
                                        bottom: BorderSide(
                                          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (isExpanded) {
                                                _expandedStoryNumbers.remove(story.itemNumber);
                                              } else {
                                                _expandedStoryNumbers.add(story.itemNumber);
                                              }
                                            });
                                          },
                                          child: Icon(
                                            isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                                            size: 18,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (isStoryChecked) {
                                                _selectedItemIds.remove(story.id);
                                                for (final c in story.children) {
                                                  _selectedItemIds.remove(c.id);
                                                }
                                              } else {
                                                _selectedItemIds.add(story.id);
                                                for (final c in story.children) {
                                                  _selectedItemIds.add(c.id);
                                                }
                                              }
                                            });
                                          },
                                          child: Icon(
                                            isStoryChecked
                                                ? Icons.check_box_rounded
                                                : (isStoryIndeterminate
                                                    ? Icons.indeterminate_check_box_rounded
                                                    : Icons.check_box_outline_blank_rounded),
                                            size: 16,
                                            color: (isStoryChecked || isStoryIndeterminate)
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFFCBD5E1),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 65,
                                          child: Text(
                                            story.itemNumber,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            story.title,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 55,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('STORY', textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          width: 70,
                                          child: Text(
                                            '= ${story.priority}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: story.priority == 'HIGH' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                            ),
                                          ),
                                        ),
                                        // Assignees
                                        SizedBox(
                                          width: 50,
                                          child: _buildAssigneeAvatar(story),
                                        ),
                                        // Status
                                        SizedBox(
                                          width: 90,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: _isCompleted(story.status)
                                                      ? const Color(0xFF10B981)
                                                      : (_isInProgress(story.status) ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8)),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  _isCompleted(story.status)
                                                      ? 'Completed'
                                                      : (_isInProgress(story.status) ? 'In Progress' : 'New'),
                                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Progress Bar
                                        SizedBox(
                                          width: 90,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(3),
                                                  child: LinearProgressIndicator(
                                                    value: (_isCompleted(story.status) ? 100 : (_isInProgress(story.status) ? 60 : 0)) / 100,
                                                    backgroundColor: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      _isCompleted(story.status) ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                                    ),
                                                    minHeight: 4,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _isCompleted(story.status) ? '100%' : (_isInProgress(story.status) ? '60%' : '0%'),
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Child Tasks
                                if (isExpanded)
                                  ...children.map((child) {
                                    final isChildDone = _isCompleted(child.status);
                                    final isChildProg = _isInProgress(child.status);
                                    final pct = isChildDone ? 100 : (isChildProg ? 70 : 0);
                                    final isChildChecked = _selectedItemIds.contains(child.id);

                                    return InkWell(
                                      onTap: () => widget.onOpenDetail(child),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: isChildChecked
                                              ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.15 : 0.05)
                                              : (isDark ? const Color(0xFF0B0F19).withValues(alpha: 0.6) : const Color(0xFFF8FAFC)),
                                          border: Border(
                                            bottom: BorderSide(
                                              color: isDark ? const Color(0xFF1F293D).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const SizedBox(width: 22),
                                            InkWell(
                                              onTap: () {
                                                setState(() {
                                                  if (isChildChecked) {
                                                    _selectedItemIds.remove(child.id);
                                                    _selectedItemIds.remove(story.id);
                                                  } else {
                                                    _selectedItemIds.add(child.id);
                                                    if (story.children.every((c) => _selectedItemIds.contains(c.id))) {
                                                      _selectedItemIds.add(story.id);
                                                    }
                                                  }
                                                });
                                              },
                                              child: Icon(
                                                isChildChecked
                                                    ? Icons.check_box_rounded
                                                    : Icons.check_box_outline_blank_rounded,
                                                size: 14,
                                                color: isChildChecked
                                                    ? const Color(0xFF2563EB)
                                                    : const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 65,
                                              child: Text(
                                                child.itemNumber,
                                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                child.title,
                                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(
                                              width: 55,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  child.workType.toUpperCase(),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            SizedBox(
                                              width: 70,
                                              child: Text(
                                                '= ${child.priority}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: child.priority == 'HIGH' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 50,
                                              child: _buildAssigneeAvatar(child),
                                            ),
                                            SizedBox(
                                              width: 90,
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: isChildDone
                                                          ? const Color(0xFF10B981)
                                                          : (isChildProg ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8)),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Expanded(
                                                    child: Text(
                                                      isChildDone ? 'Completed' : (isChildProg ? 'In Progress' : 'Not Started'),
                                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 90,
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(3),
                                                      child: LinearProgressIndicator(
                                                        value: pct / 100,
                                                        backgroundColor: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                                                        valueColor: AlwaysStoppedAnimation<Color>(
                                                          isChildDone ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                                                        ),
                                                        minHeight: 4,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '$pct%',
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          Divider(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0), height: 1),
          // Interactive Pagination Footer
          _buildSprintPaginationFooter(
            totalStories: totalStories,
            totalItems: totalItems,
            currentPage: currentPage,
            totalPages: totalPages,
            startIdx: totalStories == 0 ? 0 : startIndex + 1,
            endIdx: endIndex,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader({
    required bool allSelected,
    required bool someSelected,
    required VoidCallback onToggleAll,
    required List<WorkItemModel> pagedStories,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          // Expand/Collapse all
          InkWell(
            onTap: () {
              setState(() {
                if (_expandedStoryNumbers.isNotEmpty) {
                  _expandedStoryNumbers.clear();
                } else {
                  _expandedStoryNumbers.addAll(pagedStories.map((s) => s.itemNumber));
                }
              });
            },
            child: Icon(
              _expandedStoryNumbers.isNotEmpty ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
              size: 18,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 6),
          // Master Checkbox
          InkWell(
            onTap: onToggleAll,
            child: Icon(
              allSelected
                  ? Icons.check_box_rounded
                  : (someSelected ? Icons.indeterminate_check_box_rounded : Icons.check_box_outline_blank_rounded),
              size: 16,
              color: (allSelected || someSelected) ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(
            width: 65,
            child: Text('ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ),
          const SizedBox(width: 8),
          const Expanded(
            flex: 3,
            child: Text('TITLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ),
          const SizedBox(
            width: 55,
            child: Text('TYPE', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ),
          const SizedBox(width: 10),
          const SizedBox(
            width: 70,
            child: Text('PRIORITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ),
          const SizedBox(
            width: 50,
            child: Text('ASSIGNEES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ),
          const SizedBox(
            width: 90,
            child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ),
          const SizedBox(
            width: 90,
            child: Text('PROGRESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }

  Widget _buildAssigneeAvatar(WorkItemModel item) {
    if (item.assignees.isNotEmpty) {
      final a = item.assignees.first;
      final initials = a.fullName.trim().split(' ').map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').take(2).join();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: const Color(0xFFDBEAFE),
            child: Text(
              initials.isNotEmpty ? initials : 'U',
              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
            ),
          ),
          if (item.assignees.length > 1) ...[
            const SizedBox(width: 2),
            Text(
              '+${item.assignees.length - 1}',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
            ),
          ],
        ],
      );
    }
    return const CircleAvatar(
      radius: 9,
      backgroundColor: Color(0xFFF1F5F9),
      child: Icon(Icons.person_outline, size: 10, color: Color(0xFF94A3B8)),
    );
  }

  Widget _buildSelectionActionBar(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.35)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Text(
                '${_selectedItemIds.length} items selected',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
              ),
            ],
          ),
          // 1. Move to Sprint
          ElevatedButton.icon(
            onPressed: () {
              final sprint = ref.read(workSprintDashboardProvider).sprint;
              if (sprint == null) return;
              showDialog(
                context: context,
                builder: (_) => MoveSprintItemsDialog(
                  currentSprintId: sprint.id,
                  itemIds: _selectedItemIds.toList(),
                ),
              );
            },
            icon: const Icon(Icons.drive_file_move_outlined, size: 13, color: Colors.white),
            label: const Text('Move to Sprint', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          // 2. Change Status Dropdown
          PopupMenuButton<String>(
            tooltip: 'Change Status',
            onSelected: (newStatus) async {
              final messenger = ScaffoldMessenger.of(context);
              final api = ref.read(workApiServiceProvider);
              final success = await api.bulkUpdateWorkItems(
                itemIds: _selectedItemIds.toList(),
                status: newStatus,
              );
              if (success) {
                final sid = ref.read(workSprintDashboardProvider).sprint?.id ?? 's8';
                ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(sprintId: sid);
                if (mounted) {
                  setState(() => _selectedItemIds.clear());
                  messenger.showSnackBar(
                    SnackBar(content: Text('Updated status to $newStatus for selected items')),
                  );
                }
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'NEW', child: Text('New')),
              PopupMenuItem(value: 'ACTIVE', child: Text('Active (In Progress)')),
              PopupMenuItem(value: 'COMPLETED', child: Text('Completed')),
              PopupMenuItem(value: 'BLOCKED', child: Text('Blocked')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13182C) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sync_alt_rounded, size: 13, color: Color(0xFF475569)),
                  SizedBox(width: 4),
                  Text('Change Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 14),
                ],
              ),
            ),
          ),
          // 3. Change Priority Dropdown
          PopupMenuButton<String>(
            tooltip: 'Change Priority',
            onSelected: (newPriority) async {
              final messenger = ScaffoldMessenger.of(context);
              final api = ref.read(workApiServiceProvider);
              final success = await api.bulkUpdateWorkItems(
                itemIds: _selectedItemIds.toList(),
                priority: newPriority,
              );
              if (success) {
                final sid = ref.read(workSprintDashboardProvider).sprint?.id ?? 's8';
                ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(sprintId: sid);
                if (mounted) {
                  setState(() => _selectedItemIds.clear());
                  messenger.showSnackBar(
                    SnackBar(content: Text('Updated priority to $newPriority for selected items')),
                  );
                }
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'CRITICAL', child: Text('Critical')),
              PopupMenuItem(value: 'HIGH', child: Text('High')),
              PopupMenuItem(value: 'MEDIUM', child: Text('Medium')),
              PopupMenuItem(value: 'LOW', child: Text('Low')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13182C) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_outlined, size: 13, color: Color(0xFF475569)),
                  SizedBox(width: 4),
                  Text('Change Priority', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 14),
                ],
              ),
            ),
          ),
          // 4. Assign To Dropdown
          PopupMenuButton<String>(
            tooltip: 'Assign To',
            onSelected: (userId) async {
              final messenger = ScaffoldMessenger.of(context);
              final api = ref.read(workApiServiceProvider);
              final success = await api.bulkUpdateWorkItems(
                itemIds: _selectedItemIds.toList(),
                assigneeId: userId,
              );
              if (success) {
                final sid = ref.read(workSprintDashboardProvider).sprint?.id ?? 's8';
                ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(sprintId: sid);
                if (mounted) {
                  setState(() => _selectedItemIds.clear());
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Assigned selected items')),
                  );
                }
              }
            },
            itemBuilder: (ctx) => _assigneesList.map((a) {
              return PopupMenuItem(value: a.userId, child: Text(a.fullName));
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13182C) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline, size: 13, color: Color(0xFF475569)),
                  SizedBox(width: 4),
                  Text('Assign To', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, size: 14),
                ],
              ),
            ),
          ),
          // 5. Delete Button
          OutlinedButton.icon(
            onPressed: () => _confirmBulkDeleteSelected(context),
            icon: const Icon(Icons.delete_outline_rounded, size: 13, color: Color(0xFFEF4444)),
            label: const Text('Delete', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFEF4444)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          // 6. Clear Selection
          IconButton(
            tooltip: 'Clear Selection',
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: () => setState(() => _selectedItemIds.clear()),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _confirmBulkDeleteSelected(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Work Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete ${_selectedItemIds.length} selected work items? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final api = ref.read(workApiServiceProvider);
              final success = await api.bulkDeleteWorkItems(_selectedItemIds.toList());
              if (success) {
                final sid = ref.read(workSprintDashboardProvider).sprint?.id ?? 's8';
                ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(sprintId: sid);
                if (mounted) {
                  setState(() => _selectedItemIds.clear());
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Deleted selected items successfully')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSprintPaginationFooter({
    required int totalStories,
    required int totalItems,
    required int currentPage,
    required int totalPages,
    required int startIdx,
    required int endIdx,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;
          final infoWidget = Text(
            totalStories == 0
                ? 'Showing 0 work items'
                : 'Showing $startIdx - $endIdx of $totalStories stories ($totalItems items)',
            style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          );

          final controlsWidget = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rows per page: ',
                  style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _pageSize,
                    isDense: true,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5')),
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 20, child: Text('20')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                      DropdownMenuItem(value: 100, child: Text('100')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _pageSize = val;
                          _currentPage = 1;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 14),
                IconButton(
                  icon: const Icon(Icons.first_page_rounded, size: 18),
                  color: currentPage > 1 ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: currentPage > 1 ? () => setState(() => _currentPage = 1) : null,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  color: currentPage > 1 ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: currentPage > 1 ? () => setState(() => _currentPage = currentPage - 1) : null,
                ),
                const SizedBox(width: 4),
                ...List.generate(totalPages.clamp(1, 5), (idx) {
                  final p = idx + 1;
                  final isCurrent = p == currentPage;
                  return InkWell(
                    onTap: () => setState(() => _currentPage = p),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCurrent ? const Color(0xFF2563EB) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$p',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isCurrent
                              ? Colors.white
                              : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  color: currentPage < totalPages ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: currentPage < totalPages ? () => setState(() => _currentPage = currentPage + 1) : null,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.last_page_rounded, size: 18),
                  color: currentPage < totalPages ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: currentPage < totalPages ? () => setState(() => _currentPage = totalPages) : null,
                ),
              ],
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                infoWidget,
                const SizedBox(height: 8),
                controlsWidget,
              ],
            );
          } else {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: infoWidget),
                const SizedBox(width: 8),
                controlsWidget,
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildRightSidebar(
    BuildContext context,
    WorkSprintDashboardState sprintState,
    bool isDark,
  ) {
    final sprint = sprintState.sprint;
    final metrics = sprintState.metrics;
    final totalItems = (metrics['total_items'] as num?)?.toInt() ?? 42;
    final completedItems = (metrics['completed_items'] as num?)?.toInt() ?? 29;
    final progressPct = (metrics['completion_percentage'] as num?)?.toInt() ?? 68;

    final progressList = sprintState.progressByType.isNotEmpty
        ? sprintState.progressByType
        : [
            {'type': 'Task', 'count': 26, 'percentage': 62, 'color': '#3B82F6'},
            {'type': 'Story', 'count': 10, 'percentage': 24, 'color': '#38BDF8'},
            {'type': 'Bug', 'count': 3, 'percentage': 7, 'color': '#EF4444'},
            {'type': 'Issue', 'count': 3, 'percentage': 7, 'color': '#F59E0B'},
          ];

    final upcomingList = sprintState.upcomingSprints.isNotEmpty
        ? sprintState.upcomingSprints
        : WorkSprintDateHelper.upcomingSprintsList;

    final pieSections = progressList.map((item) {
      final count = (item['count'] as num?)?.toDouble() ?? 1.0;
      final colorHex = item['color']?.toString() ?? '#3B82F6';
      final c = _parseColor(colorHex);
      return PieChartSectionData(color: c, value: count, showTitle: false, radius: 14);
    }).toList();

    return Column(
      children: [
        // 1. Sprint Details Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13182C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sprint Details',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      if (sprint != null) {
                        showDialog(
                          context: context,
                          builder: (_) => EditSprintDialog(sprint: sprint),
                        );
                      }
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                        SizedBox(width: 4),
                        Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailLine(Icons.flag_outlined, 'Sprint', sprint?.name ?? 'Sprint 8', isDark),
              _buildDetailLine(
                Icons.calendar_today_outlined,
                'Duration',
                sprint != null && sprint.startDateFmt.isNotEmpty && !sprint.startDateFmt.contains('2025')
                    ? '${sprint.startDateFmt} – ${sprint.endDateFmt} (${sprint.durationDays} days)'
                    : WorkSprintDateHelper.currentSprintFullDurationRange,
                isDark,
              ),
              _buildDetailLine(Icons.info_outline, 'Status', sprint?.status ?? 'Active', isDark),
              _buildDetailLine(Icons.grid_view_rounded, 'Board', sprint?.boardName ?? 'Institute Work Board', isDark),
              _buildDetailLine(Icons.groups_outlined, 'Team', sprint?.teamName ?? 'Digital Campus Team', isDark),
              const SizedBox(height: 8),
              Text(
                'Sprint Goal',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 3),
              Text(
                sprint?.goal.isNotEmpty == true
                    ? sprint!.goal
                    : 'Deliver student portal enhancement, examination notifications and key infrastructure fixes.',
                style: TextStyle(fontSize: 11.5, height: 1.35, color: isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Completion', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  Text('$progressPct% ($completedItems of $totalItems items)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (progressPct / 100).clamp(0.0, 1.0),
                  backgroundColor: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 14),

              // Sprint Lifecycle Action Buttons
              if (sprint?.status.toUpperCase() == 'PLANNED')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await ref.read(workSprintDashboardProvider.notifier).startSprint(sprint!.id);
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                    label: const Text('Start Sprint', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                )
              else if (sprint?.status.toUpperCase() == 'ACTIVE')
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => CompleteSprintDialog(
                              sprintId: sprint!.id,
                              sprintName: sprint.name,
                              completedCount: completedItems,
                              incompleteCount: (totalItems - completedItems).clamp(0, 9999),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.white),
                        label: const Text('Complete Sprint', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Cancel Sprint?'),
                            content: const Text('Are you sure you want to cancel this active sprint? Incomplete items will be returned to the backlog.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                child: const Text('Cancel Sprint', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(workSprintDashboardProvider.notifier).cancelSprint(sprint!.id);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 11.5, color: Color(0xFFEF4444))),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Sprint Progress by Type Donut Chart
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13182C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sprint Progress by Type',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    height: 105,
                    width: 105,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 32,
                            startDegreeOffset: -90,
                            sections: pieSections,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$totalItems', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            const Text('Items', style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: progressList.map((item) {
                        final type = item['type']?.toString() ?? 'Task';
                        final count = item['count']?.toString() ?? '0';
                        final pct = item['percentage']?.toString() ?? '0';
                        final colorHex = item['color']?.toString() ?? '#3B82F6';
                        final c = _parseColor(colorHex);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _ProgressTypeLegend(color: c, label: type, count: '$count ($pct%)'),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Upcoming Sprints Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13182C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Upcoming Sprints',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  InkWell(
                    onTap: () {},
                    child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...upcomingList.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildUpcomingSprintRow(
                    s['name']?.toString() ?? 'Sprint',
                    s['date_range']?.toString() ?? '',
                    s['status']?.toString() ?? 'Planned',
                    isDark,
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailLine(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSprintRow(String name, String dates, String status, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                Text(
                  dates,
                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressTypeLegend extends StatelessWidget {
  final Color color;
  final String label;
  final String count;

  const _ProgressTypeLegend({required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ),
        Text(count, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
