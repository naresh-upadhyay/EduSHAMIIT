import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';
import '../../utils/work_sprint_date_helper.dart';
import 'work_item_card.dart';
import 'board_right_sidebar.dart';
import 'board_bottom_widgets.dart';

class WorkBoardTabView extends ConsumerStatefulWidget {
  final Function(WorkItemModel item) onOpenDetail;
  final Function(String type) onQuickAction;
  final VoidCallback? onOpenFilters;

  const WorkBoardTabView({
    super.key,
    required this.onOpenDetail,
    required this.onQuickAction,
    this.onOpenFilters,
  });

  @override
  ConsumerState<WorkBoardTabView> createState() => _WorkBoardTabViewState();
}

class _WorkBoardTabViewState extends ConsumerState<WorkBoardTabView> {
  String _selectedBoard = 'Institute Work Board';
  String _selectedView = 'Task & Story';
  String _selectedSprint = WorkSprintDateHelper.currentSprintBoardDropdownLabel;
  String _selectedGroupBy = 'Status';

  // Azure DevOps Filter Bar State
  bool _isFilterBarOpen = true;
  String _keywordFilter = '';
  String _typeFilter = 'All';
  String _assigneeFilter = 'All';
  String _priorityFilter = 'All';
  String _categoryFilter = 'All';

  final TextEditingController _searchController = TextEditingController();
  List<WorkAssigneeModel> _assigneesList = [];

  @override
  void initState() {
    super.initState();
    _selectedSprint = WorkSprintDateHelper.currentSprintBoardDropdownLabel;
    _loadAssignees();
  }

  void _reloadBoard() {
    ref.read(workBoardProvider.notifier).loadBoard(
          boardId: _selectedBoard,
          sprintId: _selectedSprint,
          view: _selectedView,
          groupBy: _selectedGroupBy,
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignees() async {
    try {
      final api = ref.read(workApiServiceProvider);
      final users = await api.getAssignableUsers(limit: 60);
      if (mounted) {
        setState(() => _assigneesList = users);
      }
    } catch (_) {}
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_keywordFilter.trim().isNotEmpty) count++;
    if (_typeFilter != 'All') count++;
    if (_assigneeFilter != 'All') count++;
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
      _priorityFilter = 'All';
      _categoryFilter = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boardData = ref.watch(workBoardProvider);
    final overviewData = ref.watch(workOverviewProvider);
    final notifier = ref.read(workBoardProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Board Sub-filters Bar & Azure DevOps Filter Header
          _buildFilterBar(context, isDark),

          // 2. Inline Collapsible Azure DevOps Filter Bar
          if (_isFilterBarOpen) ...[
            _buildAzureDevOpsFilterBar(isDark),
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

  Widget _buildFilterBar(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 950;
        final leftControls = Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildSelector(
              label: 'Board',
              value: _selectedBoard,
              items: const ['Institute Work Board', 'Academic Board', 'IT & Infra Board'],
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
              value: _selectedSprint,
              items: WorkSprintDateHelper.boardSprintOptions,
              onChanged: (v) {
                setState(() => _selectedSprint = v!);
                _reloadBoard();
              },
              isDark: isDark,
            ),
          ],
        );

        final rightControls = Row(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(width: 10),

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

  Widget _buildAzureDevOpsFilterBar(bool isDark) {
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

              // 4. Priority Filter
              _buildPriorityFilterDropdown(isDark),

              // 5. Category / Area Filter
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

              // 6. Clear All action
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
      ..._assigneesList.map((a) => a.fullName).toSet()
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
    const priorities = ['All', 'CRITICAL', 'URGENT', 'HIGH', 'MEDIUM', 'LOW'];

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
              value: priorities.contains(_priorityFilter) ? _priorityFilter : 'All',
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              isDense: true,
              dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
              items: priorities.map((p) {
                Color dotColor;
                switch (p) {
                  case 'CRITICAL':
                    dotColor = const Color(0xFFEF4444);
                    break;
                  case 'URGENT':
                    dotColor = const Color(0xFFF97316);
                    break;
                  case 'HIGH':
                    dotColor = const Color(0xFFF59E0B);
                    break;
                  case 'MEDIUM':
                    dotColor = const Color(0xFF3B82F6);
                    break;
                  case 'LOW':
                    dotColor = const Color(0xFF10B981);
                    break;
                  default:
                    dotColor = Colors.transparent;
                }
                return DropdownMenuItem<String>(
                  value: p,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dotColor != Colors.transparent) ...[
                        Container(width: 7, height: 7, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        p,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
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
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
            ),
          ),
        ),
      ],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final colCount = activeColumns.length.clamp(1, 6);
        final colWidth = (availableWidth - ((colCount - 1) * 14)) / colCount;
        final effectiveWidth = colWidth < 260 ? 260.0 : colWidth;

        // Precompute filtered items and determine uniform column height
        int maxFilteredCount = 0;
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

            // 5. Priority filter
            if (_priorityFilter != 'All' && item.priority.toUpperCase() != _priorityFilter.toUpperCase()) {
              return false;
            }

            // 6. Category / Area filter
            if (_categoryFilter != 'All' && item.category.toLowerCase() != _categoryFilter.toLowerCase()) {
              return false;
            }

            return true;
          }).toList();

          filteredItemsPerColumn[i] = fItems;
          if (fItems.length > maxFilteredCount) {
            maxFilteredCount = fItems.length;
          }
        }

        // Ensure all columns visually stretch to equal height (minimum 650px) so the empty space is fully droppable
        final boardHeight = (maxFilteredCount * 145.0 + 120.0).clamp(650.0, 3000.0);

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
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
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
  }) {
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
          final oldStatus = droppedItem.status;
          if (oldStatus.toUpperCase() != status.toUpperCase()) {
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
                          Text(
                            '${filteredItems.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => widget.onQuickAction('TASK'),
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
                    ? Center(
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
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: filteredItems.length + 1,
                        itemBuilder: (context, itemIdx) {
                          if (itemIdx == filteredItems.length) {
                            // Bottom empty drop space inside the column
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
                                      height: 180,
                                      color: Colors.transparent,
                                    ),
                            );
                          }

                          final item = filteredItems[itemIdx];

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
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
