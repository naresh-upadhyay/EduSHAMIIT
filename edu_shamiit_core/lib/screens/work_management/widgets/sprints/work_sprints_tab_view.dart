import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';
import '../../services/work_api_service.dart';
import 'sprint_capacity_tab_view.dart';
import 'sprint_retrospective_tab_view.dart';
import 'all_sprints_grid_view.dart';

class WorkSprintsTabView extends ConsumerStatefulWidget {
  final Function(WorkItemModel item) onOpenDetail;
  final VoidCallback? onOpenFilters;
  final Function(String type) onQuickAction;
  final Function({
    String? type,
    String? status,
    String? priority,
    String? category,
    String? sprintId,
    String? parentId,
  })? onCreateItem;
  final Function(String sprintId)? onOpenInBoard;
  final VoidCallback onCreateSprint;

  const WorkSprintsTabView({
    super.key,
    required this.onOpenDetail,
    this.onOpenFilters,
    required this.onQuickAction,
    this.onCreateItem,
    this.onOpenInBoard,
    required this.onCreateSprint,
  });

  @override
  ConsumerState<WorkSprintsTabView> createState() => _WorkSprintsTabViewState();
}

class _WorkSprintsTabViewState extends ConsumerState<WorkSprintsTabView> {
  final String _selectedBoard = 'All Boards';
  String _selectedTeam = 'All Teams';
  int _activeSubTabIndex = 0;

  // Filter state for child views
  final String _keywordFilter = '';
  final String _statusFilter = 'All';
  final String _priorityFilter = 'All';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(allSprintsProvider.notifier).loadSprints();
    });
  }

  void _onSprintChanged(String? newSprint) {
    if (newSprint == null) return;

    final allSprints = ref.read(allSprintsProvider).sprints;
    WorkSprintModel? match;
    for (final s in allSprints) {
      if (s.displayLabel == newSprint || s.name == newSprint) {
        match = s;
        break;
      }
    }
    if (match == null) {
      for (final s in allSprints) {
        if (newSprint.contains(s.name) || newSprint.contains('Sprint ${s.sprintNumber}')) {
          match = s;
          break;
        }
      }
    }

    final targetSid = match?.id ?? (allSprints.isNotEmpty ? allSprints.first.id : 's8');
    ref.read(allSprintsProvider.notifier).selectSprint(targetSid);

    ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(
      sprintId: targetSid,
      boardId: _selectedBoard,
      team: _selectedTeam,
      forceRefresh: true,
    );
    final effTeam = (_selectedTeam.isNotEmpty && _selectedTeam != 'All Teams') ? _selectedTeam : null;
    ref.read(workSprintRetroProvider.notifier).init(targetSid, teamName: effTeam);
    ref.read(workSprintCapacityProvider.notifier).init(sprintId: targetSid, team: effTeam ?? 'Digital Campus Team');
    ref.read(workSprintTeamProvider.notifier).init(targetSid);
  }

  void _onTeamFilterChanged(String teamName) {
    setState(() {
      _selectedTeam = teamName;
    });
    ref.read(workSprintCapacityProvider.notifier).selectTeam(teamName);
    final sid = ref.read(workSprintDashboardProvider).sprint?.id ?? 's8';
    ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(
      sprintId: sid,
      boardId: _selectedBoard,
      team: teamName,
      forceRefresh: true,
    );
    ref.read(workSprintRetroProvider.notifier).init(sid, teamName: teamName);
  }

  Widget _buildSubTabsBar(bool isDark) {
    final subTabs = [
      'All Sprints (Grid)',
      'Capacity',
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: subTabs.asMap().entries.map((entry) {
            final idx = entry.key;
            final label = entry.value;
            final isActive = idx == _activeSubTabIndex;

            return InkWell(
              onTap: () {
                setState(() => _activeSubTabIndex = idx);
                WorkApiService.instance.invalidateCache();
                final currentSprintId = ref.read(workSprintDashboardProvider).sprint?.id ??
                    ref.read(allSprintsProvider).activeSprint?.id ??
                    (ref.read(allSprintsProvider).sprints.isNotEmpty ? ref.read(allSprintsProvider).sprints.first.id : 's8');
                switch (idx) {
                  case 0:
                    ref.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
                    break;
                  case 1:
                    ref.read(workSprintCapacityProvider.notifier).init(sprintId: currentSprintId);
                    break;
                  case 2:
                    ref.read(workSprintRetroProvider.notifier).init(currentSprintId);
                    break;
                }
              },
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
      ),
    );
  }

  Widget _buildActiveSubTabView(
    BuildContext context,
    WorkSprintDashboardState sprintState,
    bool isDark,
  ) {
    final sprintId = sprintState.sprint?.id ??
        ref.read(allSprintsProvider).activeSprint?.id ??
        (ref.read(allSprintsProvider).sprints.isNotEmpty ? ref.read(allSprintsProvider).sprints.first.id : 's8');

    switch (_activeSubTabIndex) {
      case 1:
        return SprintCapacityTabView(
          sprintId: sprintId,
          selectedTeam: _selectedTeam,
          onTeamChanged: _onTeamFilterChanged,
          onSprintChanged: (newSid) {
            final allSprints = ref.read(allSprintsProvider).sprints;
            final match = allSprints.firstWhere(
              (s) => s.id == newSid || s.name == newSid,
              orElse: () => const WorkSprintModel(id: '', name: ''),
            );
            _onSprintChanged(match.name.isNotEmpty ? match.displayLabel : newSid);
          },
        );
      case 2:
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
        return AllSprintsGridView(
          onSelectSprint: (sprintId) {
            if (widget.onOpenInBoard != null) {
              widget.onOpenInBoard!(sprintId);
            } else {
              final allSprints = ref.read(allSprintsProvider).sprints;
              final match = allSprints.firstWhere(
                (s) => s.id == sprintId,
                orElse: () => const WorkSprintModel(id: '', name: ''),
              );
              _onSprintChanged(match.name.isNotEmpty ? match.displayLabel : sprintId);
            }
          },
          onOpenInBoard: widget.onOpenInBoard,
          onOpenCreateSprint: widget.onCreateSprint,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sprintState = ref.watch(workSprintDashboardProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Sub-tabs bar at top for seamless navigation across all devices
          _buildSubTabsBar(isDark),
          const SizedBox(height: 16),

          // 2. Tab Content
          _buildActiveSubTabView(context, sprintState, isDark),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
