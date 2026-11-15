import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';
import '../../services/work_api_service.dart';
import '../drawers/work_item_detail_drawer.dart';

class WorkBacklogTabView extends ConsumerStatefulWidget {
  final Function(WorkItemModel item) onOpenDetail;
  final VoidCallback? onOpenFilters;
  final Function(String type) onQuickAction;

  const WorkBacklogTabView({
    super.key,
    required this.onOpenDetail,
    this.onOpenFilters,
    required this.onQuickAction,
  });

  @override
  ConsumerState<WorkBacklogTabView> createState() => _WorkBacklogTabViewState();
}

class _WorkBacklogTabViewState extends ConsumerState<WorkBacklogTabView> {
  String _selectedBoard = 'Institute Work Board';
  String _selectedView = 'Product & Work Backlog';
  String _selectedType = 'All Types';
  String _selectedAssignee = 'All';

  // Azure DevOps Filter Bar State
  bool _isFilterBarOpen = true;
  String _keywordFilter = '';
  String _typeFilter = 'All';
  String _assigneeFilter = 'All';
  String _priorityFilter = 'All';
  String _categoryFilter = 'All';

  int get _activeFiltersCount {
    int count = 0;
    if (_keywordFilter.trim().isNotEmpty) count++;
    if (_typeFilter != 'All') count++;
    if (_assigneeFilter != 'All') count++;
    if (_priorityFilter != 'All') count++;
    if (_categoryFilter != 'All') count++;
    if (_selectedView != 'Product & Work Backlog') count++;
    return count;
  }

  void _clearAllFilters() {
    setState(() {
      _keywordFilter = '';
      _searchController.clear();
      _typeFilter = 'All';
      _selectedType = 'All Types';
      _assigneeFilter = 'All';
      _selectedAssignee = 'All';
      _priorityFilter = 'All';
      _categoryFilter = 'All';
      _selectedView = 'Product & Work Backlog';
      _currentPage = 1;
    });
  }

  bool _isEpicsSidebarOpen = true;
  int _currentPage = 1;
  int _pageSize = 10;
  String _selectedEpicNumber = 'EP-001';
  final Set<String> _expandedStoryIds = {'ST-101', 'ST-102', 'ST-103', 'ST-301', 'ST-302'};
  final Set<String> _selectedItemIds = {};
  WorkItemModel? _activeDrawerItem;
  final TextEditingController _searchController = TextEditingController();

  final List<BacklogEpicModel> _fallbackEpics = const [
    BacklogEpicModel(id: '0d59ba0f-7969-4a1f-b2d8-8a7ac2a6023d', itemNumber: 'EP-001', title: 'Campus Digitalization', count: 15, description: 'End-to-end digital transformation of campus operations, services and user experience.'),
    BacklogEpicModel(id: '073040f1-0db4-47fc-bdd4-6ef2ab738341', itemNumber: 'EP-002', title: 'Academic Excellence', count: 9, description: 'Enhancement of curriculum tracking, syllabus planning and learning benchmarks.'),
    BacklogEpicModel(id: 'b4b3d4ea-1ce0-4dc9-ae09-3f9746879a10', itemNumber: 'EP-003', title: 'Smart Campus Control', count: 24, description: 'Automated IoT campus security, smart lighting and laboratory access.'),
    BacklogEpicModel(id: 'd4a464e9-0bc2-457b-8684-2650c8a021d0', itemNumber: 'EP-004', title: 'Student Experience', count: 9, description: 'Modern student self-service portal, mobile apps and campus community hubs.'),
    BacklogEpicModel(id: '05f55e6a-23b3-40d4-abc2-c08c62aee89a', itemNumber: 'EP-005', title: 'Infrastructure & Facilities', count: 9, description: 'Preventive maintenance, classroom upgrades and hostel amenities.'),
    BacklogEpicModel(id: 'fbf3ce2d-16ca-45cf-ad43-d314daaf1065', itemNumber: 'EP-006', title: 'Administrative Automation', count: 9, description: 'Digital paperwork, approvals workflow and document archivals.'),
    BacklogEpicModel(id: 'aab79e03-cf6c-4eb9-885e-2083eda941fc', itemNumber: 'EP-007', title: 'Sustainability & Energy', count: 9, description: 'Solar tracking, water management and green campus goals.'),
    BacklogEpicModel(id: 'eadb3c87-7be8-4e90-8fc3-2a6bf1619f1b', itemNumber: 'EP-008', title: 'Library & Learning Resources', count: 9, description: 'RFID cataloguing and open access digital textbook integration.'),
    BacklogEpicModel(id: '9bef3a51-f715-4847-999e-f305d0b7533e', itemNumber: 'EP-009', title: 'Examination Management', count: 9, description: 'Secure question bank generation, seat scheduling and evaluation.'),
    BacklogEpicModel(id: '189a6eef-ab14-47d1-a5a8-028221be2c15', itemNumber: 'EP-010', title: 'Safety & Compliance', count: 9, description: 'Fire drills, emergency drills, state board compliance reports.'),
    BacklogEpicModel(id: '1f679757-5e23-469c-8e72-99f02b16f2f5', itemNumber: 'EP-011', title: 'Hostels & Residential Life', count: 9, description: 'Room allotments, mess feedback and night attendance management.'),
    BacklogEpicModel(id: 'cf24d256-52ba-4b57-8fec-67d19e138152', itemNumber: 'EP-012', title: 'Events & Engagement', count: 6, description: 'Annual tech fest, sports symposium and alumni celebrations.'),
  ];

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

  @override
  void initState() {
    super.initState();
    _loadAssignees();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final backlogState = ref.read(workBacklogProvider);
      if (backlogState.stories.isNotEmpty && _activeDrawerItem == null) {
        setState(() {
          _activeDrawerItem = backlogState.stories.first;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BacklogEpicModel> _getEpics(WorkBacklogState state) {
    if (state.epics.isNotEmpty) {
      return state.epics;
    }
    return _fallbackEpics;
  }

  BacklogEpicModel _getActiveEpic(List<BacklogEpicModel> epics, WorkBacklogState state) {
    if (state.selectedEpic != null && state.selectedEpic!.itemNumber == _selectedEpicNumber) {
      return state.selectedEpic!;
    }
    return epics.firstWhere(
      (e) => e.itemNumber == _selectedEpicNumber,
      orElse: () => epics.isNotEmpty ? epics.first : _fallbackEpics.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backlogState = ref.watch(workBacklogProvider);
    final epics = _getEpics(backlogState);
    final activeEpic = _getActiveEpic(epics, backlogState);

    // If active item not selected, pick first story
    if (_activeDrawerItem == null && backlogState.stories.isNotEmpty) {
      _activeDrawerItem = backlogState.stories.first;
    }

    final filteredStories = backlogState.stories.where((story) {
      // 1. Work Type filter
      if (_typeFilter != 'All' && story.workType.toUpperCase() != _typeFilter.toUpperCase()) {
        final hasMatchingChild = story.children.any((c) => c.workType.toUpperCase() == _typeFilter.toUpperCase());
        if (!hasMatchingChild) return false;
      }
      // 2. Priority filter
      if (_priorityFilter != 'All' && story.priority.toUpperCase() != _priorityFilter.toUpperCase()) {
        final hasMatchingChild = story.children.any((c) => c.priority.toUpperCase() == _priorityFilter.toUpperCase());
        if (!hasMatchingChild) return false;
      }
      // 3. Category / Area filter
      if (_categoryFilter != 'All' && story.category.toLowerCase() != _categoryFilter.toLowerCase()) {
        final hasMatchingChild = story.children.any((c) => c.category.toLowerCase() == _categoryFilter.toLowerCase());
        if (!hasMatchingChild) return false;
      }
      // 4. View filter
      if (_selectedView == 'Unassigned Sprints' && story.sprintId != null && story.sprintId!.isNotEmpty) {
        return false;
      }
      // 5. Keyword search
      if (_keywordFilter.isNotEmpty) {
        final kw = _keywordFilter.toLowerCase();
        final matchStory = story.title.toLowerCase().contains(kw) || story.itemNumber.toLowerCase().contains(kw);
        final matchChild = story.children.any((c) => c.title.toLowerCase().contains(kw) || c.itemNumber.toLowerCase().contains(kw));
        if (!matchStory && !matchChild) return false;
      }
      // 6. Assignee filter
      if (_assigneeFilter == 'Unassigned') {
        if (story.assignees.isNotEmpty) return false;
      } else if (_assigneeFilter == 'Assigned to Me') {
        final matchStory = story.assignees.any((a) => a.fullName.toLowerCase().contains('king') || a.fullName.toLowerCase().contains('doe') || a.fullName.toLowerCase().contains('rajesh'));
        final matchChild = story.children.any((c) => c.assignees.any((a) => a.fullName.toLowerCase().contains('king') || a.fullName.toLowerCase().contains('doe')));
        if (!matchStory && !matchChild) return false;
      } else if (_assigneeFilter != 'All') {
        final matchStory = story.assignees.any((a) => a.fullName.toLowerCase() == _assigneeFilter.toLowerCase());
        final matchChild = story.children.any((c) => c.assignees.any((a) => a.fullName.toLowerCase() == _assigneeFilter.toLowerCase()));
        if (!matchStory && !matchChild) return false;
      }
      return true;
    }).toList();

    // Dynamic count of visible stories + child tasks
    int totalVisibleItems = 0;
    for (final s in filteredStories) {
      totalVisibleItems += 1 + s.children.length;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Sub-filters Bar (Board, View, Work Type, Assigned To, Filters toggle)
          _buildFilterBar(context, isDark),

          // 2. Inline Collapsible Azure DevOps Filter Bar
          if (_isFilterBarOpen) ...[
            const SizedBox(height: 12),
            _buildAzureDevOpsFilterBar(isDark),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 16),
          ],

          // 3. Six Top Dynamic KPI Cards
          _buildKpiCardsRow(isDark, backlogState, epics, filteredStories),
          const SizedBox(height: 16),

          // 4. Main Content: Left Epics Sidebar (Collapsible) + Center Tree + Right Drawer
          LayoutBuilder(
            builder: (context, rowConstraints) {
              final shouldAutoCollapseEpics = rowConstraints.maxWidth < 1180 && _activeDrawerItem != null;
              final showExpandedEpics = _isEpicsSidebarOpen && !shouldAutoCollapseEpics;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Epics Panel (Collapsible)
                  if (showExpandedEpics) ...[
                    _buildEpicsSidebar(epics, isDark, totalVisibleItems),
                    const SizedBox(width: 16),
                  ] else ...[
                    _buildCollapsedEpicsSidebar(epics, isDark),
                    const SizedBox(width: 12),
                  ],

                  // Center Backlog Tree Table
                  Expanded(
                    child: _buildCenterTreePanel(context, activeEpic, backlogState, filteredStories, isDark),
                  ),

                  // Right Detail Drawer (When item selected)
                  if (_activeDrawerItem != null) ...[
                    const SizedBox(width: 16),
                    WorkItemDetailDrawer(
                      item: _activeDrawerItem,
                      onUpdated: (updated) => setState(() => _activeDrawerItem = updated),
                      onClose: () => setState(() => _activeDrawerItem = null),
                    ),
                  ],
                ],
              );
            },
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
              setState(() => _selectedBoard = v ?? 'Institute Work Board');
            }, isDark),
            _buildSelector('View', _selectedView, ['Product & Work Backlog', 'All Backlog', 'Unassigned Sprints'], (v) {
              setState(() {
                _selectedView = v ?? 'Product & Work Backlog';
                _currentPage = 1;
              });
            }, isDark),
            _buildSelector('Work Type', _selectedType, ['All Types', 'Story', 'Task', 'Bug', 'Epic'], (v) {
              setState(() {
                _selectedType = v ?? 'All Types';
                _typeFilter = (v ?? 'All Types') == 'All Types' ? 'All' : (v ?? '').toUpperCase();
                _currentPage = 1;
              });
            }, isDark),
            _buildSelector('Assigned To', _selectedAssignee, ['All', 'Assigned to Me', 'Unassigned'], (v) {
              setState(() {
                _selectedAssignee = v ?? 'All';
                _assigneeFilter = v ?? 'All';
                _currentPage = 1;
              });
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
              onPressed: () {
                ref.read(workBacklogProvider.notifier).loadBacklog();
              },
              tooltip: 'Refresh Backlog',
              icon: const Icon(Icons.refresh_rounded, size: 20),
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
                  onChanged: (v) => setState(() {
                    _keywordFilter = v.trim();
                    _currentPage = 1;
                  }),
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
                onChanged: (v) => setState(() {
                  _typeFilter = v!;
                  _selectedType = v == 'All' ? 'All Types' : (v == 'TASK' ? 'Task' : (v == 'STORY' ? 'Story' : (v == 'BUG' ? 'Bug' : 'Epic')));
                  _currentPage = 1;
                }),
                isDark: isDark,
              ),

              // 3. Priority
              _buildPriorityFilterDropdown(isDark),

              // 4. Assigned To
              _buildAssigneeFilterDropdown(isDark),

              // 5. Area
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
                  'Safety',
                  'Examination'
                ],
                onChanged: (v) => setState(() {
                  _categoryFilter = v!;
                  _currentPage = 1;
                }),
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
                  _buildActiveFilterChip('Type: $_typeFilter', () => setState(() {
                    _typeFilter = 'All';
                    _selectedType = 'All Types';
                  }), isDark),
                if (_priorityFilter != 'All')
                  _buildActiveFilterChip('Priority: $_priorityFilter', () => setState(() => _priorityFilter = 'All'), isDark),
                if (_assigneeFilter != 'All')
                  _buildActiveFilterChip('Assigned: $_assigneeFilter', () => setState(() {
                    _assigneeFilter = 'All';
                    _selectedAssignee = 'All';
                  }), isDark),
                if (_categoryFilter != 'All')
                  _buildActiveFilterChip('Area: $_categoryFilter', () => setState(() => _categoryFilter = 'All'), isDark),
                if (_selectedView != 'Product & Work Backlog')
                  _buildActiveFilterChip('View: $_selectedView', () => setState(() => _selectedView = 'Product & Work Backlog'), isDark),
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
      'Assigned to Me',
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
              onChanged: (v) => setState(() {
                _assigneeFilter = v!;
                _selectedAssignee = v;
                _currentPage = 1;
              }),
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
              onChanged: (v) => setState(() {
                _priorityFilter = v!;
                _currentPage = 1;
              }),
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

  Widget _buildKpiCardsRow(
    bool isDark,
    WorkBacklogState backlogState,
    List<BacklogEpicModel> epics,
    List<WorkItemModel> filteredStories,
  ) {
    final kpis = backlogState.kpis;
    final totalBacklog = kpis['total_backlog']?.toString() ?? '${backlogState.totalCount}';
    final epicsCount = kpis['epics']?.toString() ?? '${epics.length}';
    final storiesCount = kpis['stories']?.toString() ?? '${backlogState.stories.length}';
    final computedTasks = backlogState.stories.fold<int>(0, (sum, s) => sum + s.children.where((c) => c.workType.toUpperCase() == 'TASK').length);
    final computedBugs = backlogState.stories.fold<int>(0, (sum, s) => sum + s.children.where((c) => c.workType.toUpperCase() == 'BUG').length);
    final tasksCount = (kpis['tasks'] != null && (kpis['tasks'] as num) > 0) ? kpis['tasks'].toString() : '$computedTasks';
    final bugsCount = (kpis['bugs'] != null && (kpis['bugs'] as num) > 0) ? kpis['bugs'].toString() : '$computedBugs';
    final issuesCount = kpis['issues']?.toString() ?? '0';

    final cards = [
      _buildKpiCard(
        'Total Backlog Items',
        totalBacklog,
        icon: Icons.layers_outlined,
        color: const Color(0xFF2563EB),
        isSelected: _typeFilter == 'All',
        onTap: () => setState(() {
          _typeFilter = 'All';
          _selectedType = 'All Types';
          _currentPage = 1;
        }),
        isDark: isDark,
      ),
      _buildKpiCard(
        'Epics',
        epicsCount,
        icon: Icons.military_tech_outlined,
        color: const Color(0xFF8B5CF6),
        isSelected: _typeFilter == 'EPIC',
        onTap: () => setState(() {
          _isEpicsSidebarOpen = true;
          _typeFilter = 'EPIC';
          _currentPage = 1;
        }),
        isDark: isDark,
      ),
      _buildKpiCard(
        'Stories',
        storiesCount,
        icon: Icons.auto_stories_outlined,
        color: const Color(0xFF3B82F6),
        isSelected: _typeFilter == 'STORY',
        onTap: () => setState(() {
          _typeFilter = 'STORY';
          _selectedType = 'Story';
          _currentPage = 1;
        }),
        isDark: isDark,
      ),
      _buildKpiCard(
        'Tasks',
        tasksCount,
        icon: Icons.assignment_outlined,
        color: const Color(0xFF0EA5E9),
        isSelected: _typeFilter == 'TASK',
        onTap: () => setState(() {
          _typeFilter = 'TASK';
          _selectedType = 'Task';
          _currentPage = 1;
        }),
        isDark: isDark,
      ),
      _buildKpiCard(
        'Bugs',
        bugsCount,
        icon: Icons.bug_report_outlined,
        color: const Color(0xFFEF4444),
        isSelected: _typeFilter == 'BUG',
        onTap: () => setState(() {
          _typeFilter = 'BUG';
          _selectedType = 'Bug';
          _currentPage = 1;
        }),
        isDark: isDark,
      ),
      _buildKpiCard(
        'Issues',
        issuesCount,
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFF59E0B),
        isSelected: _typeFilter == 'ISSUE',
        onTap: () => setState(() {
          _typeFilter = 'ISSUE';
          _currentPage = 1;
        }),
        isDark: isDark,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1050) {
          return Row(
            children: cards.asMap().entries.map((entry) {
              final idx = entry.key;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: idx == cards.length - 1 ? 0 : 12),
                  child: entry.value,
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

  Widget _buildKpiCard(
    String title,
    String value, {
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isSelected = false,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? (isSelected ? color.withValues(alpha: 0.15) : const Color(0xFF13182C))
              : (isSelected ? color.withValues(alpha: 0.08) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
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
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpicsSidebar(List<BacklogEpicModel> epics, bool isDark, [int? activeEpicCount]) {
    return Container(
      width: 260,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Epics (${epics.length})',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => widget.onQuickAction('EPIC'),
                      child: const Icon(Icons.add, size: 18, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => setState(() => _isEpicsSidebarOpen = false),
                      child: Tooltip(
                        message: 'Collapse Epics',
                        child: Icon(Icons.chevron_left_rounded, size: 20, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0), height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: epics.length,
            separatorBuilder: (_, __) => Divider(
              color: isDark ? const Color(0xFF1F293D).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
              height: 1,
            ),
            itemBuilder: (context, idx) {
              final epic = epics[idx];
              final num = epic.itemNumber;
              final title = epic.title;
              final isSelected = num == _selectedEpicNumber;
              final count = isSelected && activeEpicCount != null ? activeEpicCount : epic.count;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedEpicNumber = num;
                    _currentPage = 1;
                    _selectedItemIds.clear();
                  });
                  ref.read(workBacklogProvider.notifier).loadBacklog(epicId: epic.id.isNotEmpty ? epic.id : num);
                },
                child: Container(
                  color: isSelected
                      ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF))
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.military_tech_outlined,
                        size: 15,
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF8B5CF6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            children: [
                              TextSpan(
                                text: '$num ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                ),
                              ),
                              TextSpan(
                                text: title,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : (isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedEpicsSidebar(List<BacklogEpicModel> epics, bool isDark) {
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            color: const Color(0xFF2563EB),
            tooltip: 'Expand Epics',
            onPressed: () => setState(() => _isEpicsSidebarOpen = true),
          ),
          const SizedBox(height: 12),
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              'EPICS (${epics.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterTreePanel(
    BuildContext context,
    BacklogEpicModel activeEpic,
    WorkBacklogState backlogState,
    List<WorkItemModel> filteredStories,
    bool isDark,
  ) {
    // Total items count = stories + child tasks
    int totalVisibleItems = 0;
    for (final s in filteredStories) {
      totalVisibleItems += 1 + s.children.length;
    }
    final effectiveTotal = activeEpic.count > 0 ? activeEpic.count : totalVisibleItems;

    final totalStories = filteredStories.length;
    final totalPages = (totalStories / _pageSize).ceil().clamp(1, 9999);
    final currentPage = _currentPage.clamp(1, totalPages);
    final startIndex = totalStories == 0 ? 0 : (currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalStories);
    final pagedStories = totalStories == 0 ? <WorkItemModel>[] : filteredStories.sublist(startIndex, endIndex);

    return Container(
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
          // Active Epic Banner
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.military_tech_outlined, size: 20, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${activeEpic.itemNumber}  ${activeEpic.title}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$effectiveTotal work items',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.keyboard_arrow_up_rounded, size: 20, color: Color(0xFF64748B)),
                  ],
                ),
                if (activeEpic.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    activeEpic.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Responsive Actions Toolbar
                LayoutBuilder(
                  builder: (context, toolbarConstraints) {
                    final isNarrow = toolbarConstraints.maxWidth < 580;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 34,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) => setState(() {
                                _keywordFilter = v.trim();
                                _currentPage = 1;
                              }),
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                                hintText: 'Search in backlog...',
                                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => widget.onQuickAction('TASK'),
                                  icon: const Icon(Icons.add, size: 14, color: Colors.white),
                                  label: const Text('Add Work Item', style: TextStyle(fontSize: 12, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _openReorderBacklogDialog(filteredStories),
                                  icon: const Icon(Icons.swap_vert_rounded, size: 14, color: Color(0xFF64748B)),
                                  label: Text(
                                    'Reorder',
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    side: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _openBulkActionsDialog(filteredStories),
                                  icon: const Icon(Icons.checklist_rounded, size: 14, color: Color(0xFF64748B)),
                                  label: Text(
                                    _selectedItemIds.isNotEmpty ? 'Bulk Actions (${_selectedItemIds.length})' : 'Bulk Actions',
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    side: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        SizedBox(
                          width: 220,
                          height: 34,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() {
                              _keywordFilter = v.trim();
                              _currentPage = 1;
                            }),
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                              hintText: 'Search in backlog...',
                              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => widget.onQuickAction('TASK'),
                          icon: const Icon(Icons.add, size: 14, color: Colors.white),
                          label: const Text('Add Work Item', style: TextStyle(fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _openReorderBacklogDialog(filteredStories),
                          icon: const Icon(Icons.swap_vert_rounded, size: 14, color: Color(0xFF64748B)),
                          label: Text(
                            'Reorder',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            side: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _openBulkActionsDialog(filteredStories),
                          icon: const Icon(Icons.checklist_rounded, size: 14, color: Color(0xFF64748B)),
                          label: Text(
                            _selectedItemIds.isNotEmpty ? 'Bulk Actions (${_selectedItemIds.length})' : 'Bulk Actions',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            side: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Active Multiselect Floating Action Bar
                if (_selectedItemIds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildMultiselectActionBar(filteredStories, isDark),
                ],
              ],
            ),
          ),

          Divider(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0), height: 1),

          // Tree Table (Wrapped in Horizontal Scroll to guarantee ZERO RenderFlex overflow)
          LayoutBuilder(
            builder: (context, constraints) {
              const minWidth = 920.0;
              final targetWidth = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: targetWidth,
                  child: _buildBacklogTree(context, backlogState, pagedStories, filteredStories, isDark),
                ),
              );
            },
          ),

          Divider(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0), height: 1),

          // Interactive Better Pagination Footer
          _buildPaginationFooter(
            totalStories: totalStories,
            effectiveTotal: effectiveTotal,
            epicNumber: activeEpic.itemNumber,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildMultiselectActionBar(List<WorkItemModel> allStories, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF93C5FD)),
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
                  'Clear selection',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB), decoration: TextDecoration.underline),
                ),
              ),
            ],
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

  Widget _buildPaginationFooter({
    required int totalStories,
    required int effectiveTotal,
    required String epicNumber,
    required bool isDark,
  }) {
    final totalPages = (totalStories / _pageSize).ceil().clamp(1, 9999);
    final currentPage = _currentPage.clamp(1, totalPages);
    final startIdx = totalStories == 0 ? 0 : ((currentPage - 1) * _pageSize) + 1;
    final endIdx = (currentPage * _pageSize).clamp(0, totalStories);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 620;
          final infoWidget = Text(
            totalStories == 0
                ? 'Showing 0 work items'
                : 'Showing $startIdx - $endIdx of $effectiveTotal work items (under $epicNumber)',
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
                    value: _pageSize,
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
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  color: currentPage > 1 ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: currentPage > 1 ? () => setState(() => _currentPage = currentPage - 1) : null,
                ),
                const SizedBox(width: 6),
                ...List.generate(totalPages.clamp(1, 5), (idx) {
                  final p = idx + 1;
                  final isCurrent = p == currentPage;
                  return InkWell(
                    onTap: () => setState(() => _currentPage = p),
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
                  onPressed: currentPage < totalPages ? () => setState(() => _currentPage = currentPage + 1) : null,
                ),
                const SizedBox(width: 6),
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
                infoWidget,
                controlsWidget,
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildTableHeader(List<WorkItemModel> stories, bool isDark) {
    // Gather all item IDs in this view
    final allVisibleIds = <String>{};
    for (final s in stories) {
      allVisibleIds.add(s.id);
      for (final c in s.children) {
        allVisibleIds.add(c.id);
      }
    }

    final isAllSelected = allVisibleIds.isNotEmpty && allVisibleIds.every((id) => _selectedItemIds.contains(id));
    final isSomeSelected = allVisibleIds.any((id) => _selectedItemIds.contains(id)) && !isAllSelected;

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Master Checkbox
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isAllSelected ? true : (isSomeSelected ? null : false),
              tristate: true,
              activeColor: const Color(0xFF2563EB),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedItemIds.addAll(allVisibleIds);
                  } else {
                    _selectedItemIds.removeAll(allVisibleIds);
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          // ID Header
          const SizedBox(
            width: 85,
            child: Text(
              'ID',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 10),
          // Title Header
          const Expanded(
            flex: 3,
            child: Text(
              'TITLE',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
          ),
          // Type Header
          const SizedBox(
            width: 65,
            child: Text(
              'TYPE',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 12),
          // Priority Header
          const SizedBox(
            width: 75,
            child: Text(
              'PRIORITY',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
          ),
          // Estimate Header
          const SizedBox(
            width: 50,
            child: Text(
              'EST',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
          ),
          // Status Header
          const SizedBox(
            width: 110,
            child: Text(
              'STATUS',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
          ),
          // Assignees Header
          const SizedBox(
            width: 55,
            child: Text(
              'ASSIGNEE',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
          ),
          // Actions Header
          const SizedBox(
            width: 28,
            child: Text(
              '',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBacklogTree(
    BuildContext context,
    WorkBacklogState backlogState,
    List<WorkItemModel> stories,
    List<WorkItemModel> allStories,
    bool isDark,
  ) {
    if (backlogState.isLoading && stories.isEmpty) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }
    if (stories.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('No backlog items found matching the current filters', style: TextStyle(color: Color(0xFF64748B))),
      );
    }

    return Column(
      children: [
        // Table Header
        _buildTableHeader(stories, isDark),
        Divider(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0), height: 1),

        // List of Stories and Children
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stories.length,
          itemBuilder: (context, sIdx) {
            final story = stories[sIdx];
            final isExpanded = _expandedStoryIds.contains(story.itemNumber);
            final isActive = _activeDrawerItem?.id == story.id;
            final children = story.children;

            final isStorySelected = _selectedItemIds.contains(story.id);
            final someChildrenSelected = children.any((c) => _selectedItemIds.contains(c.id));
            final allChildrenSelected = children.isNotEmpty && children.every((c) => _selectedItemIds.contains(c.id));

            return Column(
              children: [
                // Story Parent Row
                InkWell(
                  onTap: () {
                    setState(() => _activeDrawerItem = story);
                  },
                  child: Container(
                    color: isActive
                        ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
                        : (isStorySelected
                            ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.18) : const Color(0xFFF0FDF4))
                            : (isDark ? const Color(0xFF13182C) : Colors.white)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        // Checkbox
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: isStorySelected
                                ? true
                                : (someChildrenSelected && !allChildrenSelected ? null : (allChildrenSelected ? true : false)),
                            tristate: true,
                            activeColor: const Color(0xFF2563EB),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedItemIds.add(story.id);
                                  for (final c in story.children) {
                                    _selectedItemIds.add(c.id);
                                  }
                                } else {
                                  _selectedItemIds.remove(story.id);
                                  for (final c in story.children) {
                                    _selectedItemIds.remove(c.id);
                                  }
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Expand/Collapse Chevron
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedStoryIds.remove(story.itemNumber);
                              } else {
                                _expandedStoryIds.add(story.itemNumber);
                              }
                            });
                          },
                          child: Icon(
                            isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                            size: 20,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Story ID
                        SizedBox(
                          width: 60,
                          child: Text(
                            story.itemNumber,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Story Title
                        Expanded(
                          flex: 3,
                          child: Text(
                            story.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Type pill
                        SizedBox(
                          width: 65,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'STORY',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Priority
                        SizedBox(
                          width: 75,
                          child: Text(
                            '= ${story.priority}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: story.priority == 'HIGH' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                            ),
                          ),
                        ),

                        // Estimate
                        SizedBox(
                          width: 50,
                          child: Text(
                            '${story.estimatedHours > 0 ? story.estimatedHours.toInt() : 40}h',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                        ),

                        // Status
                        SizedBox(
                          width: 110,
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: story.status == 'ACTIVE'
                                      ? const Color(0xFF3B82F6)
                                      : (story.status == 'COMPLETED'
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF64748B)),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  story.status.replaceAll('_', ' '),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Assignees
                        SizedBox(
                          width: 55,
                          child: Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFDBEAFE),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'A',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Text('+2', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                            ],
                          ),
                        ),

                        // 3 dots
                        IconButton(
                          icon: const Icon(Icons.more_vert, size: 16),
                          color: const Color(0xFF94A3B8),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => setState(() => _activeDrawerItem = story),
                        ),
                      ],
                    ),
                  ),
                ),

                // Child Tasks Rows
                if (isExpanded)
                  ...children.map((child) {
                    final isChildActive = _activeDrawerItem?.id == child.id;
                    final isChildSelected = _selectedItemIds.contains(child.id);

                    return InkWell(
                      onTap: () {
                        setState(() => _activeDrawerItem = child);
                      },
                      child: Container(
                        color: isChildActive
                            ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : const Color(0xFFEFF6FF))
                            : (isChildSelected
                                ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.15) : const Color(0xFFF0FDF4))
                                : (isDark ? const Color(0xFF0B0F19).withValues(alpha: 0.6) : const Color(0xFFF8FAFC))),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            const SizedBox(width: 20),
                            // Child Checkbox
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: isChildSelected,
                                activeColor: const Color(0xFF2563EB),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedItemIds.add(child.id);
                                    } else {
                                      _selectedItemIds.remove(child.id);
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Drag indicator & arrow
                            const Icon(Icons.drag_indicator, size: 14, color: Color(0xFFCBD5E1)),
                            const SizedBox(width: 4),
                            const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 6),

                            // Child ID
                            SizedBox(
                              width: 65,
                              child: Text(
                                child.itemNumber,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Child Title
                            Expanded(
                              flex: 3,
                              child: Text(
                                child.title,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Type pill
                            SizedBox(
                              width: 65,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'TASK',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Priority
                            SizedBox(
                              width: 75,
                              child: Text(
                                '= ${child.priority}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: child.priority == 'HIGH' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                ),
                              ),
                            ),

                            // Estimate
                            SizedBox(
                              width: 50,
                              child: Text(
                                '${child.estimatedHours > 0 ? child.estimatedHours.toInt() : 8}h',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ),

                            // Status
                            SizedBox(
                              width: 110,
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: child.status == 'ACTIVE'
                                          ? const Color(0xFF3B82F6)
                                          : (child.status == 'COMPLETED'
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF64748B)),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      child.status.replaceAll('_', ' '),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Assignees
                            SizedBox(
                              width: 55,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE0E7FF),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'U',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF4338CA)),
                                  ),
                                ),
                              ),
                            ),

                            // 3 dots
                            IconButton(
                              icon: const Icon(Icons.more_vert, size: 16),
                              color: const Color(0xFF94A3B8),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              onPressed: () => setState(() => _activeDrawerItem = child),
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
    );
  }

  // ==========================================
  // BULK ACTIONS & REORDER DIALOGS
  // ==========================================

  void _openBulkActionsDialog(List<WorkItemModel> allStories) {
    final targetIds = _selectedItemIds.isNotEmpty
        ? _selectedItemIds.toList()
        : allStories.map((s) => s.id).toList();

    if (targetIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No work items available to perform bulk actions.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.checklist_rounded, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 8),
              Text('Bulk Actions (${targetIds.length} items)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select an operation to apply to all chosen work items:'),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF2563EB)),
                title: const Text('Move to Sprint', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Assign selected items to a sprint or return to Product Backlog'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openBulkMoveSprintDialog(targetIds);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sync_alt_rounded, color: Color(0xFF10B981)),
                title: const Text('Change Status', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Update status to NEW, ACTIVE, RESOLVED, or COMPLETED'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openBulkChangeStatusDialog(targetIds);
                },
              ),
              ListTile(
                leading: const Icon(Icons.priority_high_rounded, color: Color(0xFFF59E0B)),
                title: const Text('Change Priority', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Set priority to CRITICAL, HIGH, MEDIUM, or LOW'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openBulkChangePriorityDialog(targetIds);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded, color: Color(0xFF8B5CF6)),
                title: const Text('Assign Owner', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Assign all selected items to an authorized team member'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openBulkAssignDialog(targetIds);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                title: const Text('Delete / Archive', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                subtitle: const Text('Safely archive selected work items'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmBulkDelete(targetIds);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _openBulkMoveSprintDialog(List<String> itemIds) async {
    final sprints = await WorkApiService.instance.getSprints();
    String? selectedSprintId = sprints.isNotEmpty ? sprints.first.id : 'BACKLOG';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Move ${itemIds.length} Items to Sprint', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select target destination:'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
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
                ],
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
                    final success = await ref.read(workBacklogProvider.notifier).bulkUpdate(
                      itemIds: itemIds,
                      sprintId: selectedSprintId,
                    );
                    if (mounted) {
                      setState(() => _selectedItemIds.clear());
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(success ? 'Successfully moved ${itemIds.length} items!' : 'Failed to move items.')),
                      );
                    }
                  },
                  child: const Text('Move Items', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openBulkChangeStatusDialog(List<String> itemIds) {
    String selectedStatus = 'ACTIVE';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Change Status (${itemIds.length} Items)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select new status:'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
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
                ],
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
                    final success = await ref.read(workBacklogProvider.notifier).bulkUpdate(
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
            );
          },
        );
      },
    );
  }

  void _openBulkChangePriorityDialog(List<String> itemIds) {
    String selectedPriority = 'HIGH';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Change Priority (${itemIds.length} Items)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select new priority level:'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
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
                ],
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
                    final success = await ref.read(workBacklogProvider.notifier).bulkUpdate(
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
            );
          },
        );
      },
    );
  }

  void _openBulkAssignDialog(List<String> itemIds) {
    String? selectedUserId;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Assign (${itemIds.length} Items)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select team member:'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedUserId,
                    hint: const Text('Select Assignee'),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _assigneesList.map((a) {
                      return DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.fullName} (${a.role})'),
                      );
                    }).toList(),
                    onChanged: (v) => setDlgState(() => selectedUserId = v),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: selectedUserId == null ? null : () async {
                    Navigator.pop(ctx);
                    final success = await ref.read(workBacklogProvider.notifier).bulkUpdate(
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
                  child: const Text('Assign', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmBulkDelete(List<String> itemIds) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
              SizedBox(width: 8),
              Text('Delete Work Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text('Are you sure you want to delete and archive ${itemIds.length} selected work items? This action cannot be easily undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await ref.read(workBacklogProvider.notifier).bulkDelete(itemIds);
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
        );
      },
    );
  }

  void _openReorderBacklogDialog(List<WorkItemModel> stories) {
    if (stories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No work items to reorder in the current view.')),
      );
      return;
    }

    final reorderList = List<WorkItemModel>.from(stories);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Row(
                children: [
                  Icon(Icons.swap_vert_rounded, color: Color(0xFF2563EB), size: 22),
                  SizedBox(width: 8),
                  Text('Reorder Backlog Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SizedBox(
                width: 480,
                height: 380,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Adjust priority ranking by moving items up or down:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: reorderList.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = reorderList[idx];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(item.itemNumber, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
                            ),
                            title: Text(item.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                                  color: idx > 0 ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                                  onPressed: idx > 0
                                      ? () {
                                          setDlgState(() {
                                            final temp = reorderList[idx];
                                            reorderList[idx] = reorderList[idx - 1];
                                            reorderList[idx - 1] = temp;
                                          });
                                        }
                                      : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                                  color: idx < reorderList.length - 1 ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                                  onPressed: idx < reorderList.length - 1
                                      ? () {
                                          setDlgState(() {
                                            final temp = reorderList[idx];
                                            reorderList[idx] = reorderList[idx + 1];
                                            reorderList[idx + 1] = temp;
                                          });
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
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
                    // Commit ranks sequentially
                    for (int i = 0; i < reorderList.length; i++) {
                      await ref.read(workBacklogProvider.notifier).reorderItem(
                        itemId: reorderList[i].id,
                        newRank: (i + 1) * 10.0,
                      );
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Backlog priority order saved successfully!')),
                      );
                    }
                  },
                  child: const Text('Save Order', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
