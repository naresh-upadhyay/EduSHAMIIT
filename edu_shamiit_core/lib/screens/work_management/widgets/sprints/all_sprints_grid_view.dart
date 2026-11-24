import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';
import '../dialogs/create_sprint_dialog.dart';
import '../dialogs/edit_sprint_dialog.dart';
import '../dialogs/complete_sprint_dialog.dart';
import '../work_searchable_dropdown.dart';

class AllSprintsGridView extends ConsumerStatefulWidget {
  final Function(String sprintId) onSelectSprint;
  final Function(String sprintId)? onOpenInBoard;
  final VoidCallback onOpenCreateSprint;

  const AllSprintsGridView({
    super.key,
    required this.onSelectSprint,
    this.onOpenInBoard,
    required this.onOpenCreateSprint,
  });

  @override
  ConsumerState<AllSprintsGridView> createState() => _AllSprintsGridViewState();
}

class _AllSprintsGridViewState extends ConsumerState<AllSprintsGridView> {
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _sortColumn = 'sprintNumber';
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(allSprintsProvider.notifier).loadSprints();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sprintsState = ref.watch(allSprintsProvider);
    final sprints = sprintsState.sprints;

    // Filter sprints
    final filtered = sprints.where((s) {
      if (_statusFilter != 'All' && s.status.toUpperCase() != _statusFilter.toUpperCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = s.name.toLowerCase().contains(q);
        final matchGoal = s.goal.toLowerCase().contains(q);
        final matchTeam = s.teamName.toLowerCase().contains(q);
        if (!matchName && !matchGoal && !matchTeam) return false;
      }
      return true;
    }).toList();

    // Sort sprints
    filtered.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case 'sprintNumber':
          cmp = a.sprintNumber.compareTo(b.sprintNumber);
          break;
        case 'name':
          cmp = a.name.compareTo(b.name);
          break;
        case 'status':
          cmp = a.status.compareTo(b.status);
          break;
        case 'startDate':
          cmp = (a.startDate ?? '').compareTo(b.startDate ?? '');
          break;
        case 'totalItems':
          cmp = a.totalItems.compareTo(b.totalItems);
          break;
        case 'capacity':
          cmp = a.capacityHours.compareTo(b.capacityHours);
          break;
        default:
          cmp = a.sprintNumber.compareTo(b.sprintNumber);
      }
      return _sortAsc ? cmp : -cmp;
    });

    final totalCount = sprints.length;
    final activeCount = sprints.where((s) => s.status.toUpperCase() == 'ACTIVE').length;
    final plannedCount = sprints.where((s) => s.status.toUpperCase() == 'PLANNED').length;
    final completedCount = sprints.where((s) => s.status.toUpperCase() == 'COMPLETED' || s.status.toUpperCase() == 'CLOSED').length;
    final totalCapacity = sprints.fold<double>(0.0, (sum, s) => sum + s.capacityHours);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. KPI Cards Row
          _buildKpiCardsRow(
            total: totalCount,
            active: activeCount,
            planned: plannedCount,
            completed: completedCount,
            totalCapacity: totalCapacity,
            isDark: isDark,
          ),
          const SizedBox(height: 18),

          // 2. Toolbar & Search
          _buildToolbar(context, isDark, filtered.length, totalCount),
          const SizedBox(height: 14),

          // 3. Grid Table
          if (sprintsState.isLoading && sprints.isEmpty)
            _buildLoadingState(isDark)
          else if (filtered.isEmpty)
            _buildEmptyState(isDark)
          else
            _buildSprintsTable(filtered, isDark),
        ],
      ),
    );
  }

  Widget _buildKpiCardsRow({
    required int total,
    required int active,
    required int planned,
    required int completed,
    required double totalCapacity,
    required bool isDark,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cards = [
          _buildKpiCard(
            title: 'Total Sprints',
            value: total.toString(),
            subtitle: 'Iteration cycles',
            icon: Icons.calendar_view_week_rounded,
            color: const Color(0xFF3B82F6),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Active Sprints',
            value: active.toString(),
            subtitle: 'Currently in flight',
            icon: Icons.play_circle_fill_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Planned Sprints',
            value: planned.toString(),
            subtitle: 'Upcoming roadmap',
            icon: Icons.schedule_rounded,
            color: const Color(0xFF6366F1),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Completed',
            value: completed.toString(),
            subtitle: 'Delivered cycles',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF8B5CF6),
            isDark: isDark,
          ),
          _buildKpiCard(
            title: 'Total Capacity',
            value: '${totalCapacity.toStringAsFixed(0)} h',
            subtitle: 'Available team hours',
            icon: Icons.access_time_filled_rounded,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
        ];

        if (width < 550) {
          return Column(
            children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c)).toList(),
          );
        } else if (width < 1000) {
          final itemWidth = (width - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards.map((c) => SizedBox(width: itemWidth, child: c)).toList(),
          );
        }

        return Row(
          children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final bgColor = isDark ? const Color(0xFF13182C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, bool isDark, int filteredCount, int totalCount) {
    final bgColor = isDark ? const Color(0xFF13182C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 680;

        final searchField = SizedBox(
          height: 38,
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Search sprints by name, goal, team...',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF64748B)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              filled: true,
              fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB))),
            ),
          ),
        );

        final statusDropdown = WorkSearchableDropdown(
          label: 'Status',
          value: _statusFilter == 'All' ? 'All' : _statusFilter.substring(0, 1).toUpperCase() + _statusFilter.substring(1).toLowerCase(),
          items: const ['All', 'Active', 'Planned', 'Completed'],
          icon: Icons.filter_list_rounded,
          compact: true,
          itemColors: const {
            'Active': Color(0xFF10B981),
            'Planned': Color(0xFF3B82F6),
            'Completed': Color(0xFF6B7280),
          },
          onChanged: (v) {
            setState(() {
              _statusFilter = v.toUpperCase() == 'ALL' ? 'All' : v.toUpperCase();
            });
          },
        );

        final refreshBtn = IconButton(
          tooltip: 'Refresh Sprints from Database',
          icon: const Icon(Icons.refresh_rounded, size: 19),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: () => ref.read(allSprintsProvider.notifier).loadSprints(),
          color: const Color(0xFF64748B),
        );

        final createSprintBtn = ElevatedButton.icon(
          onPressed: () async {
            final res = await showDialog<bool>(
              context: context,
              builder: (ctx) => const CreateSprintDialog(),
            );
            if (res == true && mounted) {
              await ref.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
              ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(forceRefresh: true);
              ref.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
              ref.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
              ref.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
            }
          },
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Create Sprint', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        statusDropdown,
                        const SizedBox(width: 8),
                        refreshBtn,
                        const Spacer(),
                        createSprintBtn,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 12),
                    statusDropdown,
                    const SizedBox(width: 12),
                    refreshBtn,
                    const SizedBox(width: 4),
                    createSprintBtn,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSprintsTable(List<WorkSprintModel> sprints, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double minTableWidth = 1180.0;
        final tableContent = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth,
          ),
          child: _buildSprintsTableContainer(sprints, isDark),
        );

        if (constraints.maxWidth < minTableWidth) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: tableContent,
          );
        }
        return tableContent;
      },
    );
  }

  Widget _buildSprintsTableContainer(List<WorkSprintModel> sprints, bool isDark) {
    final bgColor = isDark ? const Color(0xFF13182C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0);
    final headerBg = isDark ? const Color(0xFF0E1326) : const Color(0xFFF8FAFC);

    return Container(
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
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                _buildSortHeader('SPRINT', 'sprintNumber', flex: 3, isDark: isDark),
                _buildSortHeader('STATUS', 'status', flex: 2, isDark: isDark),
                _buildSortHeader('TIMELINE', 'startDate', flex: 3, isDark: isDark),
                _buildSortHeader('PROGRESS & WORK ITEMS', 'totalItems', flex: 3, isDark: isDark),
                _buildSortHeader('CAPACITY', 'capacity', flex: 2, isDark: isDark),
                _buildSortHeader('TEAM', 'name', flex: 3, isDark: isDark),
                const Expanded(
                  flex: 3,
                  child: Text(
                    'GOAL / OBJECTIVES',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(
                  width: 170,
                  child: Text(
                    'ACTIONS',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sprints.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
            itemBuilder: (context, idx) {
              final s = sprints[idx];
              return _buildSprintRow(s, isDark);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSortHeader(String title, String columnKey, {required int flex, required bool isDark}) {
    final isSelected = _sortColumn == columnKey;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () {
          setState(() {
            if (_sortColumn == columnKey) {
              _sortAsc = !_sortAsc;
            } else {
              _sortColumn = columnKey;
              _sortAsc = true;
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 3),
              Icon(
                _sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 13,
                color: const Color(0xFF2563EB),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSprintRow(WorkSprintModel sprint, bool isDark) {
    final status = sprint.status.toUpperCase();
    final isActive = status == 'ACTIVE';
    final isPlanned = status == 'PLANNED';
    final isCompleted = status == 'COMPLETED' || status == 'CLOSED';

    Color statusColor = const Color(0xFF64748B);
    Color statusBg = const Color(0xFFF1F5F9);
    if (isActive) {
      statusColor = const Color(0xFF10B981);
      statusBg = const Color(0xFF10B981).withValues(alpha: 0.12);
    } else if (isPlanned) {
      statusColor = const Color(0xFF3B82F6);
      statusBg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
    } else if (isCompleted) {
      statusColor = const Color(0xFF8B5CF6);
      statusBg = const Color(0xFF8B5CF6).withValues(alpha: 0.12);
    }

    final datesText = sprint.startDateFmt.isNotEmpty && sprint.endDateFmt.isNotEmpty
        ? '${sprint.startDateFmt} – ${sprint.endDateFmt}'
        : (sprint.startDate != null && sprint.endDate != null ? '${sprint.startDate} – ${sprint.endDate}' : 'Flexible Dates');

    final progressPct = sprint.progressPercentage;

    return InkWell(
      onTap: () {
        ref.read(allSprintsProvider.notifier).selectSprint(sprint.id);
        if (widget.onOpenInBoard != null) {
          widget.onOpenInBoard!(sprint.id);
        } else {
          widget.onSelectSprint(sprint.id);
        }
      },
      hoverColor: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Sprint Name & Badge
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF10B981) : (isPlanned ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sprint.name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Iteration #${sprint.sprintNumber}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Status Badge
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Timeline
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    datesText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${sprint.computedDurationDays} ${sprint.computedDurationDays == 1 ? "day" : "days"}',
                      style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),

            // Progress & Work Items
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${sprint.completedItems}/${sprint.totalItems} items',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${progressPct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: progressPct >= 100 ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: sprint.totalItems > 0 ? (sprint.completedItems / sprint.totalItems).clamp(0.0, 1.0) : 0.0,
                      minHeight: 5,
                      backgroundColor: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progressPct >= 100 ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Capacity
            Expanded(
              flex: 2,
              child: Text(
                '${sprint.capacityHours.toStringAsFixed(0)} h',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Team
            Expanded(
              flex: 3,
              child: Text(
                sprint.teamName.isNotEmpty ? sprint.teamName : 'All Teams',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Goal
            Expanded(
              flex: 3,
              child: Text(
                sprint.goal.isNotEmpty ? sprint.goal : 'No sprint goal set.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: sprint.goal.isNotEmpty ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)) : Colors.grey,
                  fontStyle: sprint.goal.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Actions Buttons
            SizedBox(
              width: 170,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                  // Start Sprint (if Planned)
                  if (isPlanned)
                    IconButton(
                      tooltip: 'Start Sprint',
                      padding: const EdgeInsets.all(5),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      splashRadius: 18,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18, color: Color(0xFF10B981)),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('Start ${sprint.name}?'),
                            content: Text('This will set ${sprint.name} as ACTIVE and initiate the sprint burndown tracking.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Start Sprint', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ref.read(allSprintsProvider.notifier).startSprint(sprint.id);
                        }
                      },
                    ),

                  // Complete Sprint (if Active)
                  if (isActive)
                    IconButton(
                      tooltip: 'Complete Sprint',
                      padding: const EdgeInsets.all(5),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      splashRadius: 18,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF8B5CF6)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => CompleteSprintDialog(
                            sprintId: sprint.id,
                            sprintName: sprint.name,
                            completedCount: sprint.completedItems,
                            incompleteCount: (sprint.totalItems - sprint.completedItems).clamp(0, 9999),
                          ),
                        );
                      },
                    ),

                  // View / Open Sprint
                  IconButton(
                    tooltip: 'Open in Sprint Board',
                    padding: const EdgeInsets.all(5),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    splashRadius: 18,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF2563EB)),
                    onPressed: () {
                      ref.read(allSprintsProvider.notifier).selectSprint(sprint.id);
                      if (widget.onOpenInBoard != null) {
                        widget.onOpenInBoard!(sprint.id);
                      } else {
                        widget.onSelectSprint(sprint.id);
                      }
                    },
                  ),

                  // Edit Sprint
                  IconButton(
                    tooltip: 'Edit Sprint Details',
                    padding: const EdgeInsets.all(5),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    splashRadius: 18,
                    icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                    onPressed: () async {
                      final res = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => EditSprintDialog(sprint: sprint),
                      );
                      if (res == true && mounted) {
                        await ref.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
                        ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(sprintId: sprint.id, forceRefresh: true);
                        ref.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
                        ref.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
                        ref.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
                      }
                    },
                  ),

                  // Delete Sprint
                  IconButton(
                    tooltip: 'Delete / Archive Sprint',
                    padding: const EdgeInsets.all(5),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    splashRadius: 18,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Delete ${sprint.name}?'),
                          content: const Text('Are you sure you want to delete this sprint? Any assigned work items will be safely returned to the product backlog.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Delete Sprint', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref.read(allSprintsProvider.notifier).deleteSprint(sprint.id);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(color: Color(0xFF2563EB)),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(48),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_today_outlined, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'No Sprints Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty ? 'No sprints match the current filter or search criteria.' : 'Get started by creating your first team sprint iteration.',
            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final res = await showDialog<bool>(
                context: context,
                builder: (ctx) => const CreateSprintDialog(),
              );
              if (res == true && mounted) {
                await ref.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
                ref.read(workSprintDashboardProvider.notifier).loadSprintDashboard(forceRefresh: true);
                ref.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
                ref.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
                ref.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
              }
            },
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Create New Sprint'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
