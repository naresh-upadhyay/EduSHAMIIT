import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';
import '../../services/work_api_service.dart';
import '../../utils/work_sprint_date_helper.dart';
import '../drawers/work_item_detail_drawer.dart';

class WorkListTabView extends ConsumerStatefulWidget {
  final Function(WorkItemModel item) onOpenDetail;
  final VoidCallback? onOpenFilters;
  final Function(String type) onQuickAction;

  const WorkListTabView({
    super.key,
    required this.onOpenDetail,
    this.onOpenFilters,
    required this.onQuickAction,
  });

  @override
  ConsumerState<WorkListTabView> createState() => _WorkListTabViewState();
}

class _WorkListTabViewState extends ConsumerState<WorkListTabView> {
  String _selectedBoard = 'Institute Work Board';
  String _selectedView = 'All Work Items';
  String _selectedType = 'All Types';
  String _selectedStatus = 'All Status';
  String _selectedAssignee = 'All Assignees';

  // Azure DevOps Filter Bar State
  bool _isFilterBarOpen = true;
  String _keywordFilter = '';
  String _typeFilter = 'All';
  String _assigneeFilter = 'All';
  String _statusFilter = 'All';
  String _priorityFilter = 'All';
  String _categoryFilter = 'All';

  final TextEditingController _searchController = TextEditingController();
  List<WorkAssigneeModel> _assigneesList = [];
  int _clientPage = 1;
  int _clientPageSize = 10;

  final Set<String> _selectedItemIds = {};
  WorkItemModel? _activeDrawerItem;
  String _selectedKpi = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadAssignees();
    // Default select first item (WM-1050) as seen in screenshot 2
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final listState = ref.read(workListProvider);
      if (listState.items.isNotEmpty && _activeDrawerItem == null) {
        setState(() {
          _activeDrawerItem = listState.items.first;
        });
      }
    });
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
      if (mounted) setState(() => _assigneesList = users);
    } catch (_) {}
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_keywordFilter.trim().isNotEmpty) count++;
    if (_typeFilter != 'All') count++;
    if (_assigneeFilter != 'All') count++;
    if (_statusFilter != 'All') count++;
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
      _statusFilter = 'All';
      _priorityFilter = 'All';
      _categoryFilter = 'All';
    });
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'STORY':
        return const Color(0xFF8B5CF6);
      case 'BUG':
        return const Color(0xFFEF4444);
      case 'EPIC':
        return const Color(0xFF2563EB);
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

  Color _getStatusDotColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return const Color(0xFF8B5CF6);
      case 'RESOLVED':
        return const Color(0xFF10B981);
      case 'ACTIVE':
      case 'IN PROGRESS':
        return const Color(0xFF3B82F6);
      case 'NEW':
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listState = ref.watch(workListProvider);

    // Real-time Azure DevOps & Top Selectors Filtering
    final filteredItems = listState.items.where((item) {
      if (_keywordFilter.isNotEmpty) {
        final q = _keywordFilter.toLowerCase();
        final matchesTitle = item.title.toLowerCase().contains(q);
        final matchesNum = item.itemNumber.toLowerCase().contains(q);
        final matchesDesc = item.description.toLowerCase().contains(q);
        final matchesLabels = item.labels.any((l) => l.toLowerCase().contains(q));
        if (!matchesTitle && !matchesNum && !matchesDesc && !matchesLabels) return false;
      }
      if (_typeFilter != 'All' && item.workType.toUpperCase() != _typeFilter.toUpperCase()) return false;
      if (_statusFilter != 'All' && item.status.toUpperCase() != _statusFilter.toUpperCase()) return false;
      if (_priorityFilter != 'All' && item.priority.toUpperCase() != _priorityFilter.toUpperCase()) return false;
      if (_categoryFilter != 'All' && item.category.toLowerCase() != _categoryFilter.toLowerCase()) return false;

      // Top View Selector Filter
      if (_selectedView == 'My Tasks') {
        if (item.assignees.isEmpty) return false;
      } else if (_selectedView == 'High Priority') {
        final p = item.priority.toUpperCase();
        if (p != 'HIGH' && p != 'CRITICAL' && p != 'URGENT') return false;
      }

      // Top Assignee Selector Filter
      if (_selectedAssignee == 'Assigned to Me') {
        if (item.assignees.isEmpty) return false;
      } else if (_selectedAssignee == 'Unassigned') {
        if (item.assignees.isNotEmpty) return false;
      }

      // KPI Card Filter
      if (_selectedKpi == 'OVERDUE') {
        if (!item.isOverdue) return false;
      } else if (_selectedKpi == 'NEW' && item.status.toUpperCase() != 'NEW') {
        return false;
      } else if (_selectedKpi == 'ACTIVE' && item.status.toUpperCase() != 'ACTIVE' && item.status.toUpperCase() != 'IN_PROGRESS') {
        return false;
      } else if (_selectedKpi == 'RESOLVED' && item.status.toUpperCase() != 'RESOLVED') {
        return false;
      } else if (_selectedKpi == 'COMPLETED' && item.status.toUpperCase() != 'COMPLETED') {
        return false;
      }

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
      return true;
    }).toList();

    // If active item is not set yet, pick first item from filteredItems
    if (_activeDrawerItem == null && filteredItems.isNotEmpty) {
      _activeDrawerItem = filteredItems.first;
    }

    final totalCount = filteredItems.length;
    final totalPages = (totalCount / _clientPageSize).ceil().clamp(1, 9999);
    final currentPage = _clientPage.clamp(1, totalPages);
    final startIdx = totalCount == 0 ? 0 : (currentPage - 1) * _clientPageSize;
    final endIdx = (startIdx + _clientPageSize).clamp(0, totalCount);
    final pagedItems = totalCount == 0 ? <WorkItemModel>[] : filteredItems.sublist(startIdx, endIdx);

    final newCount = filteredItems.where((i) => i.status.toUpperCase() == 'NEW').length;
    final activeCount = filteredItems.where((i) => i.status.toUpperCase() == 'ACTIVE' || i.status.toUpperCase() == 'IN_PROGRESS').length;
    final resolvedCount = filteredItems.where((i) => i.status.toUpperCase() == 'RESOLVED').length;
    final completedCount = filteredItems.where((i) => i.status.toUpperCase() == 'COMPLETED').length;
    final overdueCount = filteredItems.where((i) => i.isOverdue).length;

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

          // 3. Six Top KPI Cards (Fully responsive across all screen widths)
          _buildKpiCardsRow(
            total: totalCount,
            newCount: newCount,
            active: activeCount,
            resolved: resolvedCount,
            completed: completedCount,
            overdue: overdueCount,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Floating / Inline Multiselect Action Bar
          if (_selectedItemIds.isNotEmpty) ...[
            _buildMultiselectActionBar(filteredItems, isDark),
            const SizedBox(height: 16),
          ],

          // 4. Main Data Grid with integrated Right Detail Drawer
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Table
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF13182C) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildTable(context, listState, pagedItems, isDark),
                      Divider(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0), height: 1),
                      _buildPaginationFooter(
                        context,
                        currentPage: currentPage,
                        totalPages: totalPages,
                        totalItems: totalCount,
                        startIdx: totalCount == 0 ? 0 : startIdx + 1,
                        endIdx: endIdx,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),

              // Right-Side Detail Drawer (When an item is selected)
              if (_activeDrawerItem != null) ...[
                const SizedBox(width: 16),
                WorkItemDetailDrawer(
                  item: _activeDrawerItem,
                  onUpdated: (updated) => setState(() => _activeDrawerItem = updated),
                  onClose: () => setState(() => _activeDrawerItem = null),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 950;
        final filters = Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildSelector('Board', _selectedBoard, ['Institute Work Board', 'Academic Board'], (v) {
              setState(() => _selectedBoard = v!);
            }, isDark),
            _buildSelector('View', _selectedView, ['All Work Items', 'My Tasks', 'High Priority'], (v) {
              setState(() => _selectedView = v!);
            }, isDark),
            _buildSelector('Work Type', _selectedType, ['All Types', 'Task', 'Story', 'Bug', 'Epic'], (v) {
              setState(() => _selectedType = v!);
              ref.read(workListProvider.notifier).setFilter(workType: v == 'All Types' ? null : v);
            }, isDark),
            _buildSelector('Status', _selectedStatus, ['All Status', 'New', 'Active', 'Resolved', 'Completed'], (v) {
              setState(() => _selectedStatus = v!);
              ref.read(workListProvider.notifier).setFilter(status: v == 'All Status' ? null : v);
            }, isDark),
            _buildSelector('Assignee', _selectedAssignee, ['All Assignees', 'Assigned to Me', 'Unassigned'], (v) {
              setState(() => _selectedAssignee = v!);
            }, isDark),
          ],
        );

        final buttons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.tune_rounded, size: 20),
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              style: IconButton.styleFrom(
                side: BorderSide(
                  color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [filters, const SizedBox(height: 10), buttons],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [filters, buttons],
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
                items: const ['All', 'TASK', 'STORY', 'BUG', 'EPIC', 'HOMEWORK', 'ASSIGNMENT'],
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

              // 7. Clear All
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
              spacing: 8,
              runSpacing: 6,
              children: [
                if (_keywordFilter.isNotEmpty)
                  _buildActiveFilterChip('Keyword: "$_keywordFilter"', () {
                    _searchController.clear();
                    setState(() => _keywordFilter = '');
                  }),
                if (_typeFilter != 'All')
                  _buildActiveFilterChip('Type: $_typeFilter', () => setState(() => _typeFilter = 'All')),
                if (_statusFilter != 'All')
                  _buildActiveFilterChip('Status: $_statusFilter', () => setState(() => _statusFilter = 'All')),
                if (_assigneeFilter != 'All')
                  _buildActiveFilterChip('Assigned: $_assigneeFilter', () => setState(() => _assigneeFilter = 'All')),
                if (_priorityFilter != 'All')
                  _buildActiveFilterChip('Priority: $_priorityFilter', () => setState(() => _priorityFilter = 'All')),
                if (_categoryFilter != 'All')
                  _buildActiveFilterChip('Area: $_categoryFilter', () => setState(() => _categoryFilter = 'All')),
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
              items: items.map((String item) {
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
    final allAssigneeNames = <String>['All', 'Unassigned'];
    for (final a in _assigneesList) {
      if (!allAssigneeNames.contains(a.fullName)) {
        allAssigneeNames.add(a.fullName);
      }
    }

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

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove) {
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

  Widget _buildKpiCardsRow({
    required int total,
    required int newCount,
    required int active,
    required int resolved,
    required int completed,
    required int overdue,
    required bool isDark,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildKpiCard(
            title: 'Total Work Items',
            value: '$total',
            isSelected: _selectedKpi == 'ALL',
            onTap: () => setState(() {
              _selectedKpi = 'ALL';
              _statusFilter = 'All';
            }),
            iconWidget: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.list_alt_rounded, size: 18, color: Color(0xFF2563EB)),
            ),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'New',
            value: '$newCount',
            isSelected: _selectedKpi == 'NEW',
            onTap: () => setState(() {
              _selectedKpi = _selectedKpi == 'NEW' ? 'ALL' : 'NEW';
              _statusFilter = _selectedKpi == 'NEW' ? 'NEW' : 'All';
            }),
            dotColor: const Color(0xFF64748B),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Active',
            value: '$active',
            isSelected: _selectedKpi == 'ACTIVE',
            onTap: () => setState(() {
              _selectedKpi = _selectedKpi == 'ACTIVE' ? 'ALL' : 'ACTIVE';
              _statusFilter = _selectedKpi == 'ACTIVE' ? 'ACTIVE' : 'All';
            }),
            dotColor: const Color(0xFF3B82F6),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Resolved',
            value: '$resolved',
            isSelected: _selectedKpi == 'RESOLVED',
            onTap: () => setState(() {
              _selectedKpi = _selectedKpi == 'RESOLVED' ? 'ALL' : 'RESOLVED';
              _statusFilter = _selectedKpi == 'RESOLVED' ? 'RESOLVED' : 'All';
            }),
            dotColor: const Color(0xFF10B981),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Completed',
            value: '$completed',
            isSelected: _selectedKpi == 'COMPLETED',
            onTap: () => setState(() {
              _selectedKpi = _selectedKpi == 'COMPLETED' ? 'ALL' : 'COMPLETED';
              _statusFilter = _selectedKpi == 'COMPLETED' ? 'COMPLETED' : 'All';
            }),
            dotColor: const Color(0xFF8B5CF6),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Overdue',
            value: '$overdue',
            isSelected: _selectedKpi == 'OVERDUE',
            onTap: () => setState(() {
              _selectedKpi = _selectedKpi == 'OVERDUE' ? 'ALL' : 'OVERDUE';
              _statusFilter = 'All';
            }),
            valueColor: const Color(0xFFEF4444),
            iconWidget: const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFFEF4444)),
            isDark: isDark,
          ),
        ];

        if (constraints.maxWidth >= 1050) {
          return Row(
            children: cards.asMap().entries.map((entry) {
              final idx = entry.key;
              final card = entry.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: idx == cards.length - 1 ? 0 : 12),
                  child: card,
                ),
              );
            }).toList(),
          );
        } else if (constraints.maxWidth >= 550) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[2]),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: cards[3]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[4]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[5]),
                ],
              ),
            ],
          );
        } else {
          return Column(
            children: [
              Row(children: [Expanded(child: cards[0]), const SizedBox(width: 8), Expanded(child: cards[1])]),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: cards[2]), const SizedBox(width: 8), Expanded(child: cards[3])]),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: cards[4]), const SizedBox(width: 8), Expanded(child: cards[5])]),
            ],
          );
        }
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    Color? dotColor,
    Color? valueColor,
    Widget? iconWidget,
    required bool isDark,
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF))
              : (isDark ? const Color(0xFF13182C) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (iconWidget != null) ...[
                  iconWidget,
                  const SizedBox(width: 8),
                ] else if (dotColor != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context, WorkListState listState, List<WorkItemModel> items, bool isDark) {
    return Column(
      children: [
        if (listState.isLoading)
          const LinearProgressIndicator(minHeight: 2.5, color: Color(0xFF2563EB), backgroundColor: Color(0xFFEFF6FF)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 880),
            child: DataTable(
              showCheckboxColumn: true,
              onSelectAll: (val) {
                setState(() {
                  if (val == true) {
                    _selectedItemIds.addAll(items.map((i) => i.id));
                  } else {
                    _selectedItemIds.removeAll(items.map((i) => i.id));
                  }
                });
              },
              horizontalMargin: 16,
              columnSpacing: 20,
              headingRowHeight: 44,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 54,
              headingTextStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              columns: const [
                DataColumn(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('ID'),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_downward, size: 14),
                    ],
                  ),
                ),
                DataColumn(label: Text('Title')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Priority')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Assignee(s)')),
                DataColumn(label: Text('Due Date')),
                DataColumn(label: Text('Progress')),
                DataColumn(label: Text('')),
              ],
              rows: items.map((item) {
          final isSelected = _selectedItemIds.contains(item.id);
          final isActiveRow = _activeDrawerItem?.id == item.id;
          final typeColor = _getTypeColor(item.workType);
          final typeIcon = _getTypeIcon(item.workType);
          final priorityColor = _getPriorityColor(item.priority);
          final statusDotColor = _getStatusDotColor(item.status);

          return DataRow(
            selected: isSelected,
            color: isActiveRow
                ? WidgetStateProperty.all(isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF))
                : null,
            onSelectChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedItemIds.add(item.id);
                } else {
                  _selectedItemIds.remove(item.id);
                }
              });
            },
            cells: [
              // ID
              DataCell(
                Text(
                  item.itemNumber,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),

              // Title
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Type Chip
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 13, color: typeColor),
                      const SizedBox(width: 4),
                      Text(
                        item.workType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Priority
              DataCell(
                Text(
                  '= ${item.priority}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: priorityColor,
                  ),
                ),
              ),

              // Status
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: statusDotColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),

              // Assignee(s)
              DataCell(
                SizedBox(
                  width: 75,
                  child: item.assignees.isEmpty
                      ? const Text('—', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 22,
                              width: (item.assignees.length.clamp(1, 2) * 14.0) + 12.0,
                              child: Stack(
                                children: item.assignees.take(2).toList().asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final a = entry.value;
                                  return Positioned(
                                    left: idx * 14.0,
                                    child: CircleAvatar(
                                      radius: 10,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      backgroundImage: (a.avatarUrl != null && a.avatarUrl!.isNotEmpty)
                                          ? NetworkImage(a.avatarUrl!)
                                          : null,
                                      child: (a.avatarUrl == null || a.avatarUrl!.isEmpty)
                                          ? Text(
                                              a.fullName.isNotEmpty ? a.fullName[0].toUpperCase() : 'U',
                                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                            )
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            if (item.assignees.length > 2)
                              Padding(
                                padding: const EdgeInsets.only(left: 3),
                                child: Text(
                                  '+${item.assignees.length - 2}',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ),
                          ],
                        ),
                ),
              ),

              // Due Date
              DataCell(
                Text(
                  item.dueDate != null && item.dueDate!.length >= 10
                      ? item.dueDate!.substring(0, 10)
                      : (item.dueDateFmt ?? WorkSprintDateHelper.defaultItemDueDateFull),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
              ),

              // Progress
              DataCell(
                SizedBox(
                  width: 110,
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: item.progressPercentage / 100,
                            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              item.progressPercentage >= 100 ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.progressPercentage}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Actions menu
              DataCell(
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 16),
                  color: const Color(0xFF94A3B8),
                  onPressed: () {
                    setState(() => _activeDrawerItem = item);
                  },
                ),
              ),
            ],
          );
        }).toList(),
      ),
    ),
  ),
    if (items.isEmpty && !listState.isLoading)
      Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('No work items found matching current filters', style: TextStyle(color: Color(0xFF64748B))),
      ),
    ],
  );
}

  Widget _buildPaginationFooter(
    BuildContext context, {
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required int startIdx,
    required int endIdx,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 620;
          final infoWidget = Text(
            totalItems == 0 ? 'Showing 0 items' : 'Showing $startIdx - $endIdx of $totalItems items',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          );

          final controlsWidget = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rows per page: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _clientPageSize,
                    isDense: true,
                    style: TextStyle(
                      fontSize: 12,
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
                          _clientPageSize = val;
                          _clientPage = 1;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 14),
                // Pagination controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page_rounded, size: 18),
                      color: currentPage > 1 ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: currentPage > 1 ? () => setState(() => _clientPage = 1) : null,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      color: currentPage > 1 ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: currentPage > 1 ? () => setState(() => _clientPage = currentPage - 1) : null,
                    ),
                    const SizedBox(width: 6),
                    ...List.generate(totalPages.clamp(1, 6), (idx) {
                      final p = idx + 1;
                      final isCurrent = p == currentPage;
                      return InkWell(
                        onTap: () => setState(() => _clientPage = p),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCurrent ? const Color(0xFF2563EB) : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$p',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isCurrent
                                  ? Colors.white
                                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      color: currentPage < totalPages ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: currentPage < totalPages ? () => setState(() => _clientPage = currentPage + 1) : null,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.last_page_rounded, size: 18),
                      color: currentPage < totalPages ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: currentPage < totalPages ? () => setState(() => _clientPage = totalPages) : null,
                    ),
                  ],
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
                infoWidget,
                controlsWidget,
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildMultiselectActionBar(List<WorkItemModel> items, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedItemIds.length}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'items selected',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _selectedItemIds.clear()),
                child: const Text(
                  'Clear',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB), decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: () => _openBulkChangeStatusDialog(_selectedItemIds.toList()),
            icon: const Icon(Icons.sync_alt_rounded, size: 14, color: Color(0xFF2563EB)),
            label: const Text('Change Status', style: TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A))),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              backgroundColor: Colors.white,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _openBulkChangePriorityDialog(_selectedItemIds.toList()),
            icon: const Icon(Icons.priority_high_rounded, size: 14, color: Color(0xFF2563EB)),
            label: const Text('Change Priority', style: TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A))),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              backgroundColor: Colors.white,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _openBulkMoveSprintDialog(_selectedItemIds.toList()),
            icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
            label: const Text('Move to Sprint', style: TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A))),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              backgroundColor: Colors.white,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _openBulkAssignDialog(_selectedItemIds.toList()),
            icon: const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF2563EB)),
            label: const Text('Assign', style: TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A))),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              backgroundColor: Colors.white,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _confirmBulkDelete(_selectedItemIds.toList()),
            icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
            label: const Text('Delete', style: TextStyle(fontSize: 11.5, color: Color(0xFFEF4444))),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              side: const BorderSide(color: Color(0xFFFECACA)),
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _openBulkChangeStatusDialog(List<String> itemIds) {
    String selectedStatus = 'ACTIVE';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Change Status (${itemIds.length} Items)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: DropdownButtonFormField<String>(
            initialValue: selectedStatus,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 'NEW', child: Text('New')),
              DropdownMenuItem(value: 'ACTIVE', child: Text('Active / In Progress')),
              DropdownMenuItem(value: 'RESOLVED', child: Text('Resolved')),
              DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
              DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
            ],
            onChanged: (v) => setDlgState(() => selectedStatus = v ?? 'ACTIVE'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await ref.read(workListProvider.notifier).bulkUpdate(
                  itemIds: itemIds,
                  status: selectedStatus,
                );
                if (mounted) {
                  setState(() => _selectedItemIds.clear());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Status updated for ${itemIds.length} items!' : 'Failed to update status.')),
                  );
                }
              },
              child: const Text('Apply Status', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openBulkChangePriorityDialog(List<String> itemIds) {
    String selectedPriority = 'HIGH';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Change Priority (${itemIds.length} Items)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: DropdownButtonFormField<String>(
            initialValue: selectedPriority,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 'CRITICAL', child: Text('Critical')),
              DropdownMenuItem(value: 'HIGH', child: Text('High')),
              DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
              DropdownMenuItem(value: 'LOW', child: Text('Low')),
            ],
            onChanged: (v) => setDlgState(() => selectedPriority = v ?? 'HIGH'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await ref.read(workListProvider.notifier).bulkUpdate(
                  itemIds: itemIds,
                  priority: selectedPriority,
                );
                if (mounted) {
                  setState(() => _selectedItemIds.clear());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Priority updated for ${itemIds.length} items!' : 'Failed to update priority.')),
                  );
                }
              },
              child: const Text('Apply Priority', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openBulkMoveSprintDialog(List<String> itemIds) async {
    final sprints = await WorkApiService.instance.getSprints();
    String? selectedSprintId = sprints.isNotEmpty ? sprints.first.id : 'BACKLOG';
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Move ${itemIds.length} Items to Sprint', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: DropdownButtonFormField<String>(
            initialValue: selectedSprintId,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem(value: 'BACKLOG', child: Text('Product Backlog (Unassign Sprint)')),
              ...sprints.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.name} (${s.status})'))),
            ],
            onChanged: (v) => setDlgState(() => selectedSprintId = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await ref.read(workListProvider.notifier).bulkUpdate(
                  itemIds: itemIds,
                  sprintId: selectedSprintId,
                );
                if (mounted) {
                  setState(() => _selectedItemIds.clear());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Moved ${itemIds.length} items!' : 'Failed to move items.')),
                  );
                }
              },
              child: const Text('Move Items', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openBulkAssignDialog(List<String> itemIds) {
    if (_assigneesList.isEmpty) return;
    String? selectedUserId = _assigneesList.first.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Assign ${itemIds.length} Work Items', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: DropdownButtonFormField<String>(
            initialValue: selectedUserId,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _assigneesList.map((u) => DropdownMenuItem(value: u.id, child: Text('${u.fullName} (${u.role})'))).toList(),
            onChanged: (v) => setDlgState(() => selectedUserId = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await ref.read(workListProvider.notifier).bulkUpdate(
                  itemIds: itemIds,
                  assigneeId: selectedUserId,
                );
                if (mounted) {
                  setState(() => _selectedItemIds.clear());
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Assigned ${itemIds.length} items successfully!' : 'Failed to assign items.')),
                  );
                }
              },
              child: const Text('Assign Items', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmBulkDelete(List<String> itemIds) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete ${itemIds.length} Items?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
        content: Text('Are you sure you want to delete these ${itemIds.length} work items? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(workListProvider.notifier).bulkDelete(itemIds);
              if (mounted) {
                setState(() => _selectedItemIds.clear());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? 'Deleted ${itemIds.length} items successfully!' : 'Failed to delete items.')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
