import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';
import '../../utils/work_sprint_date_helper.dart';
import '../../utils/work_filter_helper.dart';
import '../work_searchable_dropdown.dart';
import 'work_item_card.dart';
import 'board_right_sidebar.dart';
import 'board_bottom_widgets.dart';

class WorkBoardTabView extends ConsumerStatefulWidget {
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
  final VoidCallback? onOpenFilters;
  final String? initialSprint;
  final String? targetSprintId;

  const WorkBoardTabView({
    super.key,
    required this.onOpenDetail,
    required this.onQuickAction,
    this.onCreateItem,
    this.onOpenFilters,
    this.initialSprint,
    this.targetSprintId,
  });

  @override
  ConsumerState<WorkBoardTabView> createState() => WorkBoardTabViewState();
}

class WorkBoardTabViewState extends ConsumerState<WorkBoardTabView> {
  String _selectedBoard = 'All Boards';
  String _selectedView = 'Task & Story';

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
        type: type,
        status: status,
        priority: priority,
        category: category,
        sprintId: sprintId,
        parentId: parentId,
      );
    } else {
      widget.onQuickAction(type ?? 'TASK');
    }
  }
  String _selectedSprint = WorkSprintDateHelper.currentSprintBoardDropdownLabel;
  String _selectedGroupBy = 'Status';

  // SHAMIIT Filter Bar State
  bool _isFilterBarOpen = true;
  String _keywordFilter = '';
  String _typeFilter = 'All';
  String _assigneeFilter = 'All';
  String _roleFilter = 'All';
  String _departmentFilter = 'All';
  String _classFilter = 'All';
  String _sectionFilter = 'All';
  String _teamFilter = 'All';
  String _priorityFilter = 'All';
  String _categoryFilter = 'All';

  final TextEditingController _searchController = TextEditingController();
  List<WorkAssigneeModel> _assigneesList = [];
  List<WorkAcademicClassModel> _classesList = [];
  List<String> _teamsList = WorkFilterHelper.defaultTeams;
  Timer? _searchDebounce;

  // Board Card Virtualization & Load More limits per column (defaults to 10)
  final Map<String, int> _columnDisplayLimits = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialSprint != null && widget.initialSprint!.isNotEmpty) {
      _selectedSprint = widget.initialSprint!;
    } else {
      _selectedSprint = 'All Sprints';
    }
    _loadAssignees();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(allSprintsProvider.notifier).loadSprints();
      _reloadBoard(widget.targetSprintId);
    });
  }

  @override
  void didUpdateWidget(covariant WorkBoardTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetSprintId != null && widget.targetSprintId != oldWidget.targetSprintId) {
      final allSprints = ref.read(allSprintsProvider).sprints;
      final match = allSprints.where((s) => s.id == widget.targetSprintId).firstOrNull;
      final label = widget.initialSprint ?? match?.displayLabel ?? widget.targetSprintId!;
      selectSprint(label, widget.targetSprintId);
    }
  }

  void selectSprint(String sprintLabel, [String? sprintId]) {
    final allSprintsState = ref.read(allSprintsProvider);
    final match = allSprintsState.sprints.firstWhere(
      (s) => s.id == sprintId || s.displayLabel == sprintLabel || s.name == sprintLabel,
      orElse: () => const WorkSprintModel(id: '', name: ''),
    );
    final effectiveLabel = match.id.isNotEmpty ? match.displayLabel : sprintLabel;
    final effectiveId = match.id.isNotEmpty ? match.id : (sprintId ?? sprintLabel);

    if (mounted) {
      setState(() {
        _selectedSprint = effectiveLabel;
      });
    }
    ref.read(allSprintsProvider.notifier).selectSprint(effectiveId);
    _reloadBoard(effectiveId);
  }

  void reloadCurrent() {
    _reloadBoard();
  }

  String? _getEffectiveSprintId() {
    if (_selectedSprint == 'All Sprints' || _selectedSprint == 'Backlog Only') return null;
    final allSprints = ref.read(allSprintsProvider).sprints;
    final match = allSprints.firstWhere(
      (s) => s.displayLabel == _selectedSprint || s.name == _selectedSprint,
      orElse: () => allSprints.firstWhere(
        (s) => _selectedSprint.contains(s.name) || _selectedSprint.contains('Sprint ${s.sprintNumber}'),
        orElse: () => const WorkSprintModel(id: '', name: ''),
      ),
    );
    return match.id.isNotEmpty ? match.id : null;
  }

  void _onKeywordSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() => _keywordFilter = v.trim());
      }
    });
  }

  void _reloadBoard([String? sprintOverride]) {
    final sprintVal = sprintOverride ?? _selectedSprint;
    final allSprints = ref.read(allSprintsProvider).sprints;
    String targetSprintId = sprintVal;
    if (sprintVal == 'All Sprints') {
      targetSprintId = 'all';
    } else if (sprintVal == 'Backlog Only') {
      targetSprintId = 'backlog';
    } else {
      final match = allSprints.firstWhere(
        (s) => s.id == sprintVal || s.displayLabel == sprintVal || s.name == sprintVal,
        orElse: () => allSprints.firstWhere(
          (s) => sprintVal.contains(s.name) || (s.name.isNotEmpty && sprintVal.contains('Sprint ${s.sprintNumber}')),
          orElse: () => const WorkSprintModel(id: '', name: ''),
        ),
      );
      if (match.id.isNotEmpty) {
        targetSprintId = match.id;
      }
    }

    final resolvedBoard = WorkFilterHelper.resolveBoardId(_selectedBoard) ?? 'all';
    ref.read(workBoardProvider.notifier).loadBoard(
          boardId: resolvedBoard,
          sprintId: targetSprintId,
          view: _selectedView,
          groupBy: _selectedGroupBy,
          forceRefresh: true,
        );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignees() async {
    try {
      final api = ref.read(workApiServiceProvider);
      final meta = await WorkFilterHelper.loadMetadata(api);
      if (mounted) {
        setState(() {
          _assigneesList = meta.assignees;
          _classesList = meta.classes;
          _teamsList = meta.teams;
        });
      }
    } catch (_) {}
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_keywordFilter.trim().isNotEmpty) count++;
    if (_typeFilter != 'All') count++;
    if (_assigneeFilter != 'All') count++;
    if (_roleFilter != 'All') count++;
    if (_departmentFilter != 'All') count++;
    if (_teamFilter != 'All') count++;
    if (_classFilter != 'All') count++;
    if (_sectionFilter != 'All') count++;
    if (_priorityFilter != 'All') count++;
    if (_categoryFilter != 'All') count++;
    return count;
  }

  void _clearAllFilters() {
    setState(() {
      _keywordFilter = '';
      _searchController.clear();
      _typeFilter = 'All';
      _assigneeFilter = 'All';
      _roleFilter = 'All';
      _departmentFilter = 'All';
      _teamFilter = 'All';
      _classFilter = 'All';
      _sectionFilter = 'All';
      _priorityFilter = 'All';
      _categoryFilter = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boardData = ref.watch(workBoardProvider);
    final overviewData = ref.watch(workOverviewProvider);
    final allSprintsState = ref.watch(allSprintsProvider);
    final notifier = ref.read(workBoardProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Board Sub-filters Bar & SHAMIIT Filter Header
          _buildFilterBar(context, isDark, allSprintsState),

          // 2. Inline Collapsible SHAMIIT Filter Bar
          if (_isFilterBarOpen) ...[
            _buildShamiitFilterBar(isDark),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 16),
          ],

          // 3. Main Board Content: Kanban Columns + Right Sidebar
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1200;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kanban 4 Columns
                    Expanded(
                      child: _buildKanbanGrid(context, boardData, notifier, isDark),
                    ),
                    const SizedBox(width: 18),
                    // Right Sidebar (Quick Actions, My Work, Overall Progress)
                    BoardRightSidebar(
                      overviewData: overviewData,
                      onQuickAction: widget.onQuickAction,
                      onCreateItem: _handleCreateItem,
                      onSelectFilter: (filter) {
                        setState(() {
                          if (filter.contains('Assigned')) {
                            _assigneeFilter = _assigneesList.isNotEmpty ? _assigneesList.first.fullName : 'All';
                          } else if (filter.contains('Created')) {
                            _keywordFilter = 'System';
                          } else if (filter.contains('Overdue')) {
                            _priorityFilter = 'HIGH';
                          } else if (filter.contains('Week')) {
                            _typeFilter = 'TASK';
                          }
                        });
                      },
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildKanbanGrid(context, boardData, notifier, isDark),
                    const SizedBox(height: 20),
                    BoardRightSidebar(
                      overviewData: overviewData,
                      onQuickAction: widget.onQuickAction,
                      onCreateItem: _handleCreateItem,
                      onSelectFilter: (filter) {
                        setState(() {
                          if (filter.contains('Assigned')) {
                            _assigneeFilter = _assigneesList.isNotEmpty ? _assigneesList.first.fullName : 'All';
                          } else if (filter.contains('Created')) {
                            _keywordFilter = 'System';
                          } else if (filter.contains('Overdue')) {
                            _priorityFilter = 'HIGH';
                          } else if (filter.contains('Week')) {
                            _typeFilter = 'TASK';
                          }
                        });
                      },
                    ),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 24),

          // 4. Bottom Row: Recent Activity, Work by Type, Work by Category
          BoardBottomWidgets(
            overviewData: overviewData,
            onViewAllActivity: () => _showActivityLogsDialog(context, overviewData, isDark),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showActivityLogsDialog(BuildContext context, Map<String, dynamic> overviewData, bool isDark) {
    final rawLogs = overviewData['recent_activity'] as List<dynamic>? ?? [];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.history_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Recent Activity & Audit Trail', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: rawLogs.isEmpty
              ? const Text('No recent activities recorded on this board.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: rawLogs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final log = rawLogs[idx] as Map<String, dynamic>;
                    final actor = log['actor_name']?.toString() ?? 'User';
                    final action = log['action']?.toString() ?? log['activity_type']?.toString() ?? '';
                    final timeAgo = log['time_ago']?.toString() ?? 'Just now';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFDBEAFE),
                        child: Icon(Icons.person_outline, size: 14, color: Color(0xFF1E40AF)),
                      ),
                      title: Text('$actor $action', style: const TextStyle(fontSize: 12.5)),
                      subtitle: Text(timeAgo, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, bool isDark, WorkAllSprintsState allSprintsState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 950;
        final sprintOptions = [
          'All Sprints',
          'Backlog Only',
          ...allSprintsState.sprints.map((s) => s.displayLabel),
        ];
        String effectiveSprintValue = sprintOptions.first;
        if (sprintOptions.contains(_selectedSprint)) {
          effectiveSprintValue = _selectedSprint;
        } else {
          final match = allSprintsState.sprints.firstWhere(
            (s) => _selectedSprint.contains(s.name) || (s.name.isNotEmpty && _selectedSprint.contains(s.name.split(' ').first)),
            orElse: () => const WorkSprintModel(id: '', name: ''),
          );
          if (match.id.isNotEmpty && sprintOptions.contains(match.displayLabel)) {
            effectiveSprintValue = match.displayLabel;
            _selectedSprint = match.displayLabel;
          }
        }

        final leftControls = Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildSelector(
              label: 'Board',
              value: _selectedBoard,
              items: WorkFilterHelper.boardOptions,
              onChanged: (v) {
                setState(() => _selectedBoard = v!);
                _reloadBoard();
              },
              isDark: isDark,
            ),
            _buildSelector(
              label: 'View',
              value: _selectedView,
              items: const ['Task & Story', 'All Work Items', 'My Tasks Only', 'Bugs & Issues'],
              onChanged: (v) {
                setState(() => _selectedView = v!);
                _reloadBoard();
              },
              isDark: isDark,
            ),
            _buildSelector(
              label: 'Sprint',
              value: effectiveSprintValue,
              items: sprintOptions,
              onChanged: (v) {
                setState(() => _selectedSprint = v!);
                final match = allSprintsState.sprints.firstWhere(
                  (s) => s.displayLabel == v || s.name == v,
                  orElse: () => const WorkSprintModel(id: '', name: ''),
                );
                if (match.id.isNotEmpty) {
                  ref.read(allSprintsProvider.notifier).selectSprint(match.id);
                }
                _reloadBoard(v);
              },
              isDark: isDark,
            ),
          ],
        );

        final rightControls = Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildSelector(
              label: 'Group by',
              value: _selectedGroupBy,
              items: const ['Status', 'Priority', 'Work Type'],
              onChanged: (v) {
                setState(() => _selectedGroupBy = v!);
                _reloadBoard();
              },
              isDark: isDark,
            ),

            // SHAMIIT Filters Toggle Button with Active Badge
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
                  boxShadow: _isFilterBarOpen
                      ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
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
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leftControls,
              const SizedBox(height: 10),
              rightControls,
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: leftControls),
              const SizedBox(width: 12),
              rightControls,
            ],
          );
        }
      },
    );
  }

  Widget _buildShamiitFilterBar(bool isDark) {
    final bgColor = isDark ? const Color(0xFF13182C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
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
          // Filter Inputs Row
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 1. Keyword search input
              SizedBox(
                width: 240,
                height: 36,
                child: TextField(
                  controller: _searchController,
                  onChanged: _onKeywordSearchChanged,
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                    ),
                  ),
                ),
              ),

              // 2. Work Item Types Filter
              _buildDevOpsFilterDropdown(
                label: 'Types',
                value: _typeFilter,
                items: const ['All', 'TASK', 'STORY', 'BUG', 'EPIC', 'HOMEWORK', 'ASSIGNMENT'],
                onChanged: (v) => setState(() => _typeFilter = v!),
                isDark: isDark,
              ),

              // 3. Assigned to Filter
              _buildAssigneeFilterDropdown(isDark),

              // 4. Role Filter
              WorkFilterHelper.buildFilterDropdown(
                label: 'Role',
                value: _roleFilter,
                items: WorkFilterHelper.roleOptions,
                onChanged: (v) {
                  setState(() {
                    _roleFilter = v ?? 'All';
                    if (_roleFilter.toLowerCase() != 'student') {
                      _classFilter = 'All';
                      _sectionFilter = 'All';
                    }
                  });
                },
                isDark: isDark,
                prefixIcon: Icons.badge_outlined,
              ),

              // 5. Department Filter
              WorkFilterHelper.buildFilterDropdown(
                label: 'Department',
                value: _departmentFilter,
                items: WorkFilterHelper.defaultDepartments,
                onChanged: (v) => setState(() => _departmentFilter = v ?? 'All'),
                isDark: isDark,
                prefixIcon: Icons.apartment_rounded,
              ),

              // 6. Team Filter
              WorkFilterHelper.buildFilterDropdown(
                label: 'Team',
                value: _teamFilter,
                items: <String>{'All', ...ref.watch(workTeamsListProvider), ..._teamsList}.toList(),
                onChanged: (v) => setState(() => _teamFilter = v ?? 'All'),
                isDark: isDark,
                prefixIcon: Icons.groups_rounded,
                accentColor: const Color(0xFF6366F1),
              ),

              // 7. Cascaded Class Filter (Visible when Role is Student)
              if (_roleFilter.toLowerCase() == 'student') ...[
                WorkFilterHelper.buildFilterDropdown(
                  label: 'Class',
                  value: _classFilter,
                  items: ['All', ..._classesList.map((c) => c.name)],
                  onChanged: (v) {
                    setState(() {
                      _classFilter = v ?? 'All';
                      _sectionFilter = 'All';
                    });
                  },
                  isDark: isDark,
                  prefixIcon: Icons.school_outlined,
                  accentColor: const Color(0xFF2563EB),
                ),

                // 7. Cascaded Section Filter (Visible when Class is chosen)
                if (_classFilter != 'All')
                  WorkFilterHelper.buildFilterDropdown(
                    label: 'Section',
                    value: _sectionFilter,
                    items: WorkFilterHelper.getSectionsForClass(_classesList, _classFilter),
                    onChanged: (v) => setState(() => _sectionFilter = v ?? 'All'),
                    isDark: isDark,
                    prefixIcon: Icons.groups_outlined,
                    accentColor: const Color(0xFF10B981),
                  ),
              ],

              // 8. Priority Filter
              _buildPriorityFilterDropdown(isDark),

              // 9. Category / Area Filter
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

              // 10. Clear All action
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
                if (_assigneeFilter != 'All')
                  _buildActiveFilterChip('Assigned: $_assigneeFilter', () => setState(() => _assigneeFilter = 'All'), isDark),
                if (_roleFilter != 'All')
                  _buildActiveFilterChip('Role: $_roleFilter', () {
                    setState(() {
                      _roleFilter = 'All';
                      _classFilter = 'All';
                      _sectionFilter = 'All';
                    });
                  }, isDark),
                if (_departmentFilter != 'All')
                  _buildActiveFilterChip('Dept: $_departmentFilter', () => setState(() => _departmentFilter = 'All'), isDark),
                if (_teamFilter != 'All')
                  _buildActiveFilterChip('Team: $_teamFilter', () => setState(() => _teamFilter = 'All'), isDark),
                if (_classFilter != 'All')
                  _buildActiveFilterChip('Class: $_classFilter', () {
                    setState(() {
                      _classFilter = 'All';
                      _sectionFilter = 'All';
                    });
                  }, isDark),
                if (_sectionFilter != 'All')
                  _buildActiveFilterChip('Section: $_sectionFilter', () => setState(() => _sectionFilter = 'All'), isDark),
                if (_priorityFilter != 'All')
                  _buildActiveFilterChip('Priority: $_priorityFilter', () => setState(() => _priorityFilter = 'All'), isDark),
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
    return WorkSearchableDropdown(
      label: label,
      value: value,
      items: items,
      compact: true,
      onChanged: (v) => onChanged(v),
    );
  }

  Widget _buildAssigneeFilterDropdown(bool isDark) {
    final allAssigneeNames = [
      'All',
      'Unassigned',
      ..._assigneesList.map((a) => a.fullName).toSet(),
    ];

    return WorkSearchableDropdown(
      label: 'Assigned to',
      value: _assigneeFilter,
      items: allAssigneeNames,
      icon: Icons.person_outline,
      compact: true,
      onChanged: (v) => setState(() => _assigneeFilter = v),
    );
  }

  Widget _buildPriorityFilterDropdown(bool isDark) {
    const priorities = ['All', 'CRITICAL', 'URGENT', 'HIGH', 'MEDIUM', 'LOW'];

    return WorkSearchableDropdown(
      label: 'Priority',
      value: _priorityFilter,
      items: priorities,
      compact: true,
      itemColors: const {
        'CRITICAL': Color(0xFFEF4444),
        'URGENT': Color(0xFFF97316),
        'HIGH': Color(0xFFF59E0B),
        'MEDIUM': Color(0xFF3B82F6),
        'LOW': Color(0xFF10B981),
      },
      onChanged: (v) => setState(() => _priorityFilter = v),
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
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

  Widget _buildSelector({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return WorkSearchableDropdown(
      label: label,
      value: value,
      items: items,
      compact: false,
      onChanged: (v) => onChanged(v),
    );
  }

  Color _getColumnDotColor(String key, String? colorHex) {
    if (colorHex != null && colorHex.isNotEmpty) {
      var str = colorHex.replaceAll('#', '');
      if (str.length == 6) str = 'FF$str';
      final val = int.tryParse(str, radix: 16);
      if (val != null) return Color(val);
    }
    switch (key.toUpperCase()) {
      case 'NEW':
        return const Color(0xFF64748B);
      case 'ACTIVE':
      case 'TASK':
      case 'MEDIUM':
        return const Color(0xFF3B82F6);
      case 'RESOLVED':
      case 'LOW':
        return const Color(0xFF10B981);
      case 'COMPLETED':
      case 'STORY':
        return const Color(0xFF8B5CF6);
      case 'BUG':
      case 'CRITICAL':
      case 'URGENT':
        return const Color(0xFFEF4444);
      case 'EPIC':
        return const Color(0xFFEC4899);
      case 'HIGH':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  Widget _buildColumnCardSkeletons(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1F293D).withValues(alpha: 0.6) : Colors.white;
    final placeholderColor = isDark ? const Color(0xFF2E3B52) : const Color(0xFFE2E8F0);

    return ListView(
      padding: const EdgeInsets.all(10),
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(3, (cardIdx) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
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
                  Container(
                    width: 60,
                    height: 14,
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    width: 45,
                    height: 14,
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 14,
                decoration: BoxDecoration(
                  color: placeholderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 140,
                height: 14,
                decoration: BoxDecoration(
                  color: placeholderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 50,
                    height: 12,
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: placeholderColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildKanbanGrid(
    BuildContext context,
    WorkBoardState boardData,
    WorkBoardNotifier notifier,
    bool isDark,
  ) {

    final cols = boardData.columns;
    final activeColumns = cols.isNotEmpty
        ? cols
        : [
            const KanbanColumnModel(statusKey: 'NEW', name: 'New', color: '#64748B', count: 0, items: []),
            const KanbanColumnModel(statusKey: 'ACTIVE', name: 'Active', color: '#3B82F6', count: 0, items: []),
            const KanbanColumnModel(statusKey: 'RESOLVED', name: 'Resolved', color: '#10B981', count: 0, items: []),
            const KanbanColumnModel(statusKey: 'COMPLETED', name: 'Completed', color: '#8B5CF6', count: 0, items: []),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (boardData.isLoading) ...[
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(2)),
            child: LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(height: 6),
        ],
        LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final colCount = activeColumns.length.clamp(1, 6);
        final colWidth = (availableWidth - ((colCount - 1) * 14)) / colCount;
        final effectiveWidth = colWidth < 260 ? 260.0 : colWidth;

        // Precompute filtered items and determine uniform column height
        final filteredItemsPerColumn = <int, List<WorkItemModel>>{};

        for (int i = 0; i < activeColumns.length; i++) {
          final colData = activeColumns[i];
          final fItems = colData.items.where((item) {
            // 1. Keyword search
            if (_keywordFilter.isNotEmpty) {
              final q = _keywordFilter.toLowerCase();
              final matchesTitle = item.title.toLowerCase().contains(q);
              final matchesNumber = item.itemNumber.toLowerCase().contains(q);
              final matchesDesc = item.description.toLowerCase().contains(q);
              final matchesLabels = item.labels.any((l) => l.toLowerCase().contains(q));
              if (!matchesTitle && !matchesNumber && !matchesDesc && !matchesLabels) {
                return false;
              }
            }

            // 2. Work Item Type filter
            if (_typeFilter != 'All' && item.workType.toUpperCase() != _typeFilter.toUpperCase()) {
              return false;
            }

            // 3. View filter ('Task & Story', 'My Tasks Only', 'Bugs & Issues')
            if (_selectedView == 'Bugs & Issues') {
              final wt = item.workType.toUpperCase();
              if (wt != 'BUG' && wt != 'ISSUE') return false;
            }

            // 4. Assignee filter
            if (_assigneeFilter != 'All') {
              if (_assigneeFilter == 'Unassigned') {
                if (item.assignees.isNotEmpty) return false;
              } else {
                final hasMatch = item.assignees.any((a) =>
                    a.fullName.toLowerCase() == _assigneeFilter.toLowerCase() ||
                    a.fullName.toLowerCase().contains(_assigneeFilter.toLowerCase()));
                if (!hasMatch) return false;
              }
            }

            // 5. Advanced Cascaded Filters: Role, Department, Class, Section, Team, Board
            if (!WorkFilterHelper.matchesAdvancedFilters(
              item: item,
              roleFilter: _roleFilter,
              departmentFilter: _departmentFilter,
              classFilter: _classFilter,
              sectionFilter: _sectionFilter,
              teamFilter: _teamFilter,
              boardFilter: _selectedBoard,
            )) {
              return false;
            }

            // 6. Priority filter
            if (_priorityFilter != 'All' && item.priority.toUpperCase() != _priorityFilter.toUpperCase()) {
              return false;
            }

            // 7. Category / Area filter
            if (_categoryFilter != 'All' && item.category.toLowerCase() != _categoryFilter.toLowerCase()) {
              return false;
            }

            return true;
          }).toList();

          filteredItemsPerColumn[i] = fItems;
        }

        // Calculate maximum visible cards count for uniform and responsive column height
        int maxVisibleCount = 0;
        for (int i = 0; i < activeColumns.length; i++) {
          final colName = activeColumns[i].name;
          final fItems = filteredItemsPerColumn[i] ?? [];
          final limit = _getColumnLimit(colName);
          final visibleCount = fItems.length > limit ? limit + 1 : fItems.length;
          if (visibleCount > maxVisibleCount) {
            maxVisibleCount = visibleCount;
          }
        }

        // Ensure all columns visually stretch to equal height (minimum 650px) so the empty space is fully droppable
        final boardHeight = (maxVisibleCount * 145.0 + 140.0).clamp(650.0, 3200.0);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: activeColumns.asMap().entries.map((entry) {
              final idx = entry.key;
              final colData = entry.value;
              final status = colData.statusKey;
              final title = colData.name;
              final dotColor = _getColumnDotColor(status, colData.color);
              final filteredItems = filteredItemsPerColumn[idx] ?? [];

              return Padding(
                padding: EdgeInsets.only(right: idx == activeColumns.length - 1 ? 0 : 14),
                child: SizedBox(
                  width: effectiveWidth,
                  height: boardHeight,
                  child: _buildColumn(
                    context,
                    status: status,
                    title: title,
                    dotColor: dotColor,
                    headerBg: dotColor.withValues(alpha: 0.1),
                    columnData: colData,
                    filteredItems: filteredItems,
                    notifier: notifier,
                    isDark: isDark,
                    columnHeight: boardHeight,
                    isLoading: boardData.isLoading,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    ),
    ],
    );
  }

  Widget _buildColumn(
    BuildContext context, {
    required String status,
    required String title,
    required Color dotColor,
    required Color headerBg,
    required KanbanColumnModel columnData,
    required List<WorkItemModel> filteredItems,
    required WorkBoardNotifier notifier,
    required bool isDark,
    required double columnHeight,
    bool isLoading = false,
  }) {
    final colLimit = _getColumnLimit(title);
    final visibleItems = filteredItems.take(colLimit).toList();
    final bool hasMore = filteredItems.length > visibleItems.length;
    final int remaining = filteredItems.length - visibleItems.length;
    final int nextBatch = remaining > 10 ? 10 : remaining;

    return DragTarget<WorkItemModel>(
      hitTestBehavior: HitTestBehavior.opaque,
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final droppedItem = details.data;
        if (_selectedGroupBy == 'Priority') {
          final oldVal = droppedItem.priority;
          if (oldVal.toUpperCase() != status.toUpperCase()) {
            notifier.updateItemPriority(droppedItem.id, status);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF0F172A),
                content: Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded, color: Color(0xFF60A5FA), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Priority changed for ${droppedItem.itemNumber} ($oldVal → $title)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else if (_selectedGroupBy == 'Work Type') {
          final oldVal = droppedItem.workType;
          if (oldVal.toUpperCase() != status.toUpperCase()) {
            notifier.updateItemType(droppedItem.id, status);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF0F172A),
                content: Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded, color: Color(0xFF60A5FA), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Work Type changed for ${droppedItem.itemNumber} ($oldVal → $title)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          final oldStatus = droppedItem.status.replaceAll('_', ' ').trim().toUpperCase();
          final newStatus = status.replaceAll('_', ' ').trim().toUpperCase();
          if (oldStatus != newStatus) {
            notifier.transitionStatus(droppedItem.id, status);

            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF0F172A),
                content: Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded, color: Color(0xFF60A5FA), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Moved ${droppedItem.itemNumber} ($oldStatus → $title)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: columnHeight,
          decoration: BoxDecoration(
            color: isHovered
                ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
                : (isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovered
                  ? const Color(0xFF2563EB)
                  : (isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
              width: isHovered ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                          if (title.toUpperCase().contains('ACTIVE') || title.toUpperCase().contains('RESOLVED')) ...[
                            Builder(builder: (context) {
                              final int wipLimit = title.toUpperCase().contains('ACTIVE') ? 25 : 20;
                              final bool isWipExceeded = filteredItems.length > wipLimit;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isWipExceeded
                                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                      : (isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(4),
                                  border: isWipExceeded
                                      ? Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5))
                                      : null,
                                ),
                                child: Text(
                                  '${filteredItems.length}/$wipLimit${isWipExceeded ? ' • WIP' : ''}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: isWipExceeded
                                        ? const Color(0xFFEF4444)
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                              );
                            }),
                          ] else ...[
                            if (hasMore) ...[
                              Tooltip(
                                message: 'Showing ${visibleItems.length} of ${filteredItems.length} loaded items',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${visibleItems.length}/${filteredItems.length}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              Text(
                                '${filteredItems.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        String? targetType;
                        String? targetStatus;
                        String? targetPriority;

                        if (_selectedGroupBy == 'Work Type') {
                          targetType = status.toUpperCase();
                          targetStatus = 'NEW';
                          targetPriority = _priorityFilter != 'All' ? _priorityFilter : null;
                        } else if (_selectedGroupBy == 'Priority') {
                          targetType = _typeFilter != 'All' ? _typeFilter : 'TASK';
                          targetPriority = status.toUpperCase();
                          targetStatus = 'NEW';
                        } else {
                          // Default: Group by Status
                          targetType = _typeFilter != 'All' ? _typeFilter : 'TASK';
                          targetStatus = status.toUpperCase();
                          targetPriority = _priorityFilter != 'All' ? _priorityFilter : null;
                        }

                        _handleCreateItem(
                          type: targetType,
                          status: targetStatus,
                          priority: targetPriority,
                          category: _categoryFilter != 'All' ? _categoryFilter : null,
                          sprintId: _getEffectiveSprintId(),
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 13, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                            const SizedBox(width: 2),
                            Text(
                              'Add',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(
                color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                height: 1,
              ),

              // Items List & Empty Space Drop Target Area
              Expanded(
                child: filteredItems.isEmpty
                    ? (isLoading
                        ? _buildColumnCardSkeletons(isDark)
                        : Center(
                            child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                          decoration: BoxDecoration(
                            color: isHovered
                                ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isHovered
                                  ? const Color(0xFF2563EB)
                                  : (isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isHovered ? Icons.add_circle_outline_rounded : Icons.inbox_outlined,
                                size: 28,
                                color: isHovered ? const Color(0xFF60A5FA) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isHovered
                                    ? 'Drop here to move to $title'
                                    : (columnData.items.isEmpty ? 'No items in $title' : 'No items matching filters'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isHovered ? FontWeight.w600 : FontWeight.w500,
                                  color: isHovered ? const Color(0xFF60A5FA) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: () {
                                  String? targetType;
                                  String? targetStatus;
                                  String? targetPriority;

                                  if (_selectedGroupBy == 'Work Type') {
                                    targetType = status.toUpperCase();
                                    targetStatus = 'NEW';
                                    targetPriority = _priorityFilter != 'All' ? _priorityFilter : null;
                                  } else if (_selectedGroupBy == 'Priority') {
                                    targetType = _typeFilter != 'All' ? _typeFilter : 'TASK';
                                    targetPriority = status.toUpperCase();
                                    targetStatus = 'NEW';
                                  } else {
                                    targetType = _typeFilter != 'All' ? _typeFilter : 'TASK';
                                    targetStatus = status.toUpperCase();
                                    targetPriority = _priorityFilter != 'All' ? _priorityFilter : null;
                                  }

                                  _handleCreateItem(
                                    type: targetType,
                                    status: targetStatus,
                                    priority: targetPriority,
                                    category: _categoryFilter != 'All' ? _categoryFilter : null,
                                    sprintId: _getEffectiveSprintId(),
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.add_rounded, size: 14, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Create $title',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: visibleItems.length + (hasMore ? 1 : 0) + 1,
                        itemBuilder: (context, itemIdx) {
                          // 1. Draggable cards within visible range
                          if (itemIdx < visibleItems.length) {
                            final item = visibleItems[itemIdx];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Draggable<WorkItemModel>(
                                data: item,
                                feedback: Material(
                                  elevation: 8,
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 260,
                                    child: WorkItemCard(
                                      item: item,
                                      onTap: () {},
                                    ),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.25,
                                  child: WorkItemCard(
                                    item: item,
                                    onTap: () => widget.onOpenDetail(item),
                                  ),
                                ),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.grab,
                                  child: WorkItemCard(
                                    item: item,
                                    onTap: () => widget.onOpenDetail(item),
                                  ),
                                ),
                              ),
                            );
                          }

                          // 2. Interactive "Load 10 More" Button if items remain in column
                          if (hasMore && itemIdx == visibleItems.length) {
                            return Container(
                              margin: const EdgeInsets.only(top: 2, bottom: 10),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _columnDisplayLimits[title] = colLimit + 10;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.45 : 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF3B82F6)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Load $nextBatch More ($remaining left)',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          // 3. Bottom empty drop space inside the column
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(top: 4, bottom: 20),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isHovered
                                  ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isHovered
                                  ? Border.all(
                                      color: const Color(0xFF60A5FA).withValues(alpha: 0.6),
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: isHovered
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF60A5FA)),
                                      SizedBox(width: 6),
                                      Text(
                                        'Drop here',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF60A5FA),
                                        ),
                                      ),
                                    ],
                                  )
                                : Container(
                                    height: 140,
                                    color: Colors.transparent,
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

  int _getColumnLimit(String title) {
    if (_columnDisplayLimits['__ALL__'] != null) return _columnDisplayLimits['__ALL__']!;
    return _columnDisplayLimits[title] ?? 10;
  }
}
