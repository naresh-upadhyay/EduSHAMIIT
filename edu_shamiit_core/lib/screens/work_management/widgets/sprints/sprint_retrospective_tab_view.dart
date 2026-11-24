import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/role_provider.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';
import '../../utils/work_sprint_date_helper.dart';
import '../work_searchable_dropdown.dart';

class SprintRetrospectiveTabView extends ConsumerStatefulWidget {
  final String sprintId;
  final String? selectedTeam;
  final String? boardName;
  final String? filterKeyword;
  final String? statusFilter;
  final String? priorityFilter;

  const SprintRetrospectiveTabView({
    super.key,
    required this.sprintId,
    this.selectedTeam,
    this.boardName,
    this.filterKeyword,
    this.statusFilter,
    this.priorityFilter,
  });

  @override
  ConsumerState<SprintRetrospectiveTabView> createState() => _SprintRetrospectiveTabViewState();
}

class _SprintRetrospectiveTabViewState extends ConsumerState<SprintRetrospectiveTabView> {
  final Set<String> _expandedColumns = {};
  late final TextEditingController _retroSearchCtrl;
  int _historyDisplayLimit = 10;

  @override
  void initState() {
    super.initState();
    _retroSearchCtrl = TextEditingController(text: widget.filterKeyword ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workSprintRetroProvider.notifier).init(widget.sprintId, teamName: widget.selectedTeam);
    });
  }

  @override
  void dispose() {
    _retroSearchCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SprintRetrospectiveTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sprintId != widget.sprintId || oldWidget.selectedTeam != widget.selectedTeam) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(workSprintRetroProvider.notifier).init(widget.sprintId, teamName: widget.selectedTeam);
      });
    }
    if (oldWidget.filterKeyword != widget.filterKeyword && widget.filterKeyword != null) {
      _retroSearchCtrl.text = widget.filterKeyword!;
      ref.read(workSprintRetroProvider.notifier).setSearchQuery(widget.filterKeyword!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final retroState = ref.watch(workSprintRetroProvider);
    final ws = retroState.workspace;

    // Default fallback workspace if initial load is still resolving
    final safeWs = ws ?? _createFallbackWorkspace(widget.sprintId);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1080;

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (retroState.isLoading)
                    const LinearProgressIndicator(minHeight: 2, color: Color(0xFF2563EB)),
                  // 1. Retrospective Session Header Card
                  _buildSessionHeaderCard(safeWs, isDark),
                  const SizedBox(height: 12),

                  // Executive Retrospective Scope Toolbar (Sprint, Team, Search, Category Chips, Refresh)
                  _buildRetroScopeBar(safeWs, retroState, isDark),
                  const SizedBox(height: 14),

                  // 2. Retrospective Workspace Internal Tabs
                  _buildInternalTabsBar(safeWs, isDark),
                  const SizedBox(height: 14),

                  // 3. Tab Body
                  if (retroState.activeTab == 'Discussion Board')
                    _buildDiscussionBoardTab(safeWs, isDesktop, isDark)
                  else if (retroState.activeTab.startsWith('Action Items'))
                    _buildActionItemsFullTab(safeWs, isDark)
                  else if (retroState.activeTab == 'Notes & Summary')
                    _buildNotesAndSummaryTab(safeWs, isDark)
                  else if (retroState.activeTab == 'Feedback')
                    _buildFeedbackTab(safeWs, isDark)
                  else
                    _buildHistoryTab(safeWs, isDark),
                ],
              ),
            ),

            // Right-Side Action Item Detail Drawer
            if (retroState.isDrawerOpen && retroState.selectedActionItem != null)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: isDesktop ? 440 : constraints.maxWidth * 0.9,
                child: _RetroActionItemDetailDrawer(
                  item: retroState.selectedActionItem!,
                  isDark: isDark,
                  onClose: () => ref.read(workSprintRetroProvider.notifier).closeActionDrawer(),
                ),
              ),
          ],
        );
      },
    );
  }

  // ============================================================================
  // 1. Session Header Card
  // ============================================================================
  Widget _buildSessionHeaderCard(SprintRetroWorkspaceModel ws, bool isDark) {
    final retro = ws.retrospective;
    final isCompleted = retro.status == 'COMPLETED';

    return Container(
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
          // Top row: Target Icon, Title, Status Badge, and Action Buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.gps_fixed_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            retro.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isCompleted ? 'Completed' : retro.status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ws.sprintOverview.sprintName} (${ws.sprintOverview.dateRange})',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (isCompleted) ...[
                    OutlinedButton.icon(
                      onPressed: () => _openReopenSessionDialog(ws),
                      icon: const Icon(Icons.replay_rounded, size: 14),
                      label: const Text(
                        'Reopen Retrospective',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openStartNewSessionDialog(ws),
                      icon: const Icon(Icons.fiber_new_rounded, size: 14),
                      label: const Text(
                        'Start New Session',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: () => _openCloseSessionDialog(ws),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.white),
                      label: const Text(
                        'Complete Retrospective',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openStartNewSessionDialog(ws),
                      icon: const Icon(Icons.fiber_new_rounded, size: 14),
                      label: const Text(
                        'Start New Session',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => _openEditSessionDialog(ws),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _handleExportCsv(),
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text('Export', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, size: 18, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                    onSelected: (val) => _handleHeaderMenuAction(val, ws),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'START_NEW',
                        child: Row(
                          children: [
                            Icon(Icons.fiber_new_rounded, size: 15, color: Color(0xFF2563EB)),
                            SizedBox(width: 8),
                            Text('Start New Session Cycle'),
                          ],
                        ),
                      ),
                      if (isCompleted)
                        const PopupMenuItem(
                          value: 'REOPEN',
                          child: Row(
                            children: [
                              Icon(Icons.replay_rounded, size: 15, color: Color(0xFF2563EB)),
                              SizedBox(width: 8),
                              Text('Reopen Retrospective'),
                            ],
                          ),
                        )
                      else
                        const PopupMenuItem(
                          value: 'CLOSE',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 15, color: Color(0xFF10B981)),
                              SizedBox(width: 8),
                              Text('Complete Retrospective'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'ADD_PARTICIPANT',
                        child: Row(
                          children: [
                            Icon(Icons.person_add_outlined, size: 15, color: Color(0xFF0284C7)),
                            SizedBox(width: 8),
                            Text('Invite / Add Member'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'EDIT_SUMMARY',
                        child: Row(
                          children: [
                            Icon(Icons.notes_rounded, size: 15, color: Color(0xFFF59E0B)),
                            SizedBox(width: 8),
                            Text('Notes & Summary'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'RESET_ENTRIES',
                        child: Row(
                          children: [
                            Icon(Icons.restart_alt_rounded, size: 15, color: Color(0xFFEF4444)),
                            SizedBox(width: 8),
                            Text('Reset Discussion Cards', style: TextStyle(color: Color(0xFFEF4444))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // Bottom metadata chips row (Date, Facilitator, Participants, Duration, Sprint Goal)
          Wrap(
            spacing: 24,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildMetaItem(
                Icons.calendar_today_outlined,
                'Retrospective Date',
                retro.sessionDateFormatted.isNotEmpty
                    ? retro.sessionDateFormatted
                    : WorkSprintDateHelper.retroSessionDateFmt,
                isDark,
              ),
              _buildMetaItem(
                Icons.person_outline_rounded,
                'Facilitator',
                retro.facilitatorName,
                isDark,
              ),
              _buildMetaItem(
                Icons.group_outlined,
                'Participants',
                '${ws.participants.isNotEmpty ? ws.participants.length : retro.totalParticipants} / ${ws.participants.isNotEmpty ? ws.participants.length : retro.totalParticipants} (100%)',
                isDark,
              ),
              _buildMetaItem(
                Icons.access_time_rounded,
                'Duration',
                '${retro.durationMinutes} min',
                isDark,
              ),
              _buildMetaItem(
                Icons.flag_outlined,
                'Sprint Goal',
                retro.sprintGoal.isNotEmpty ? retro.sprintGoal : ws.sprintOverview.sprintGoal,
                isDark,
                maxWidth: 320,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, String value, bool isDark, {double? maxWidth}) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (maxWidth != null) {
      return SizedBox(
        width: maxWidth,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF2563EB)),
            const SizedBox(width: 6),
            Expanded(child: column),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF2563EB)),
        const SizedBox(width: 6),
        column,
      ],
    );
  }

  // ============================================================================
  // Retrospective Executive Scope Toolbar (Sprint, Team, Search, Category Pills)
  // ============================================================================
  Widget _buildRetroScopeBar(
    SprintRetroWorkspaceModel ws,
    WorkSprintRetroState retroState,
    bool isDark,
  ) {
    final allSprintsState = ref.watch(allSprintsProvider);
    final teamsList = ref.watch(workTeamsListProvider);

    // Dynamic teams from workspace (from db), falling back to teamsListProvider
    final List<String> availableTeamNames = ws.availableTeams.isNotEmpty
        ? ws.availableTeams.map((t) => t.name).toList()
        : teamsList;
    final allTeams = ['All Teams', ...availableTeamNames.where((t) => t != 'All Teams' && t != 'All')];

    // Determine current team selection label
    String currentTeamLabel = 'All Teams';
    if (retroState.teamId != null && retroState.teamId!.isNotEmpty && retroState.teamId != 'All Teams') {
      final match = ws.availableTeams.where((t) => t.id == retroState.teamId || t.name.toLowerCase() == retroState.teamId!.toLowerCase()).firstOrNull;
      currentTeamLabel = match?.name ?? retroState.teamId!;
    }

    // Sprint options combining allSprintsProvider and ws.availableSprints
    final currentSprintId = retroState.sprintId;
    final List<Map<String, String>> sprintOptions = [];
    if (allSprintsState.sprints.isNotEmpty) {
      for (final s in allSprintsState.sprints) {
        sprintOptions.add({
          'id': s.id,
          'label': s.displayLabel,
          'status': s.status.toUpperCase(),
        });
      }
    } else if (ws.availableSprints.isNotEmpty) {
      for (final s in ws.availableSprints) {
        sprintOptions.add({
          'id': s.id,
          'label': s.name,
          'status': s.status.toUpperCase(),
        });
      }
    }

    final sprintMatch = sprintOptions.where((s) => s['id'] == currentSprintId).firstOrNull;
    final currentSprintLabel = sprintMatch?['label'] ?? ws.sprintOverview.sprintName;

    // Counts for Category Pills
    final totalCards = ws.wentWell.entries.length + ws.didNotGoWell.entries.length + ws.shouldImprove.entries.length;
    final activeCat = retroState.selectedCategoryFilter ?? 'ALL';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Left side: Sprint Selector + Team Selector + Refresh
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Sprint Selector
              Builder(
                builder: (context) {
                  final sprintLabels = sprintOptions.map((s) => s['label'] ?? '').where((l) => l.isNotEmpty).toList();
                  return WorkSearchableDropdown(
                    label: 'Sprint',
                    value: currentSprintLabel,
                    items: sprintLabels,
                    icon: Icons.bolt_rounded,
                    compact: false,
                    onChanged: (selectedLabel) {
                      final match = sprintOptions.firstWhere(
                        (s) => s['label'] == selectedLabel,
                        orElse: () => {'id': currentSprintId},
                      );
                      final sid = match['id'];
                      if (sid != null && sid.isNotEmpty) {
                        ref.read(workSprintRetroProvider.notifier).selectSprint(sid);
                      }
                    },
                  );
                },
              ),

              // Team Selector
              WorkSearchableDropdown(
                label: 'Team',
                value: allTeams.contains(currentTeamLabel) ? currentTeamLabel : 'All Teams',
                items: allTeams,
                icon: Icons.groups_rounded,
                compact: false,
                onChanged: (newTeam) {
                  if (newTeam == 'All Teams' || newTeam == 'All') {
                    ref.read(workSprintRetroProvider.notifier).selectTeam(null);
                  } else {
                    final teamObj = ws.availableTeams.where((at) => at.name == newTeam).firstOrNull;
                    ref.read(workSprintRetroProvider.notifier).selectTeam(
                      teamObj?.id ?? newTeam,
                      teamName: newTeam,
                    );
                  }
                },
              ),

              // Refresh Button
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                tooltip: 'Refresh Retrospective',
                onPressed: () => ref.read(workSprintRetroProvider.notifier).loadWorkspace(),
              ),
            ],
          ),

          // Right side: Realtime Search Box + Category Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search Input Box
              Container(
                width: 200,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2D3748) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: TextField(
                  controller: _retroSearchCtrl,
                  onChanged: (val) {
                    ref.read(workSprintRetroProvider.notifier).setSearchQuery(val);
                  },
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search notes & authors...',
                    hintStyle: TextStyle(fontSize: 11.5, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 15, color: Color(0xFF94A3B8)),
                    suffixIcon: _retroSearchCtrl.text.isNotEmpty
                        ? InkWell(
                            onTap: () {
                              _retroSearchCtrl.clear();
                              ref.read(workSprintRetroProvider.notifier).setSearchQuery('');
                            },
                            child: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF94A3B8)),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),

              // Category Pills
              _buildCategoryScopePill('All ($totalCards)', 'ALL', activeCat, const Color(0xFF2563EB), isDark),
              _buildCategoryScopePill('Went Well (${ws.wentWell.entries.length})', 'WENT_WELL', activeCat, const Color(0xFF10B981), isDark),
              _buildCategoryScopePill('Didn\'t Go Well (${ws.didNotGoWell.entries.length})', 'DID_NOT_GO_WELL', activeCat, const Color(0xFFEF4444), isDark),
              _buildCategoryScopePill('Improve (${ws.shouldImprove.entries.length})', 'TO_IMPROVE', activeCat, const Color(0xFF3B82F6), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryScopePill(String label, String categoryKey, String activeCat, Color color, bool isDark) {
    final isSelected = activeCat == categoryKey;
    return InkWell(
      onTap: () {
        ref.read(workSprintRetroProvider.notifier).setCategoryFilter(
          isSelected ? 'ALL' : categoryKey,
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? color : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 2. Internal Tabs Navigation
  // ============================================================================
  Widget _buildInternalTabsBar(SprintRetroWorkspaceModel ws, bool isDark) {
    final retroState = ref.watch(workSprintRetroProvider);
    final activeTab = retroState.activeTab;

    final tabs = [
      'Discussion Board',
      'Action Items (${ws.actionItems.length})',
      'Notes & Summary',
      'Feedback',
      'History',
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final isSelected = activeTab == tab || (tab.startsWith('Action Items') && activeTab.startsWith('Action Items'));
            return InkWell(
              onTap: () => ref.read(workSprintRetroProvider.notifier).setActiveTab(tab),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ============================================================================
  // 3. Discussion Board Tab (Agile Columns + Action Items Table + Right Sidebar)
  // ============================================================================
  Widget _buildDiscussionBoardTab(SprintRetroWorkspaceModel ws, bool isDesktop, bool isDark) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Main Workspace (Columns + Action Items)
          Expanded(
            flex: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAgileColumns(ws, isDark),
                const SizedBox(height: 14),
                _buildActionItemsTableCard(ws, isDark),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Right Sidebar Cards
          Expanded(
            flex: 28,
            child: _buildRightSidebar(ws, isDark),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAgileColumns(ws, isDark),
          const SizedBox(height: 14),
          _buildActionItemsTableCard(ws, isDark),
          const SizedBox(height: 14),
          _buildRightSidebar(ws, isDark),
        ],
      );
    }
  }

  // 3 Agile Columns: What Went Well? (6), What Didn't Go Well? (4), What Should Improve? (5)
  Widget _buildAgileColumns(SprintRetroWorkspaceModel ws, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final retroState = ref.watch(workSprintRetroProvider);
        final catFilter = retroState.selectedCategoryFilter;

        final showWentWell = catFilter == null || catFilter == 'ALL' || catFilter == 'WENT_WELL';
        final showDidNotGoWell = catFilter == null || catFilter == 'ALL' || catFilter == 'DID_NOT_GO_WELL';
        final showShouldImprove = catFilter == null || catFilter == 'ALL' || catFilter == 'TO_IMPROVE';

        final visibleCount = [showWentWell, showDidNotGoWell, showShouldImprove].where((b) => b).length;
        final colWidth = isWide
            ? ((constraints.maxWidth - (visibleCount > 1 ? (visibleCount - 1) * 14 : 0)) / (visibleCount > 0 ? visibleCount : 1))
            : double.infinity;

        final colWentWell = _buildRetroColumn(
          title: ws.wentWell.title.isNotEmpty ? ws.wentWell.title : 'What Went Well? (${ws.wentWell.count})',
          categoryKey: 'WENT_WELL',
          entries: ws.wentWell.entries,
          themeColor: const Color(0xFF10B981),
          icon: Icons.thumb_up_alt_outlined,
          cardIcon: Icons.check_circle_outline_rounded,
          width: colWidth,
          isDark: isDark,
        );

        final colDidNotGoWell = _buildRetroColumn(
          title: ws.didNotGoWell.title.isNotEmpty ? ws.didNotGoWell.title : "What Didn't Go Well? (${ws.didNotGoWell.count})",
          categoryKey: 'DID_NOT_GO_WELL',
          entries: ws.didNotGoWell.entries,
          themeColor: const Color(0xFFEF4444),
          icon: Icons.thumb_down_alt_outlined,
          cardIcon: Icons.error_outline_rounded,
          width: colWidth,
          isDark: isDark,
        );

        final colShouldImprove = _buildRetroColumn(
          title: ws.shouldImprove.title.isNotEmpty ? ws.shouldImprove.title : 'What Should Improve? (${ws.shouldImprove.count})',
          categoryKey: 'TO_IMPROVE',
          entries: ws.shouldImprove.entries,
          themeColor: const Color(0xFF3B82F6),
          icon: Icons.lightbulb_outline_rounded,
          cardIcon: Icons.push_pin_outlined,
          width: colWidth,
          isDark: isDark,
        );

        final activeCols = [
          if (showWentWell) colWentWell,
          if (showDidNotGoWell) colDidNotGoWell,
          if (showShouldImprove) colShouldImprove,
        ];

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < activeCols.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                activeCols[i],
              ],
            ],
          );
        } else {
          return Column(
            children: [
              for (int i = 0; i < activeCols.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                activeCols[i],
              ],
            ],
          );
        }
      },
    );
  }

  Widget _buildRetroColumn({
    required String title,
    required String categoryKey,
    required List<SprintRetroEntryItemModel> entries,
    required Color themeColor,
    required IconData icon,
    required IconData cardIcon,
    required double width,
    required bool isDark,
  }) {
    final retroState = ref.watch(workSprintRetroProvider);
    final filterKw = (retroState.searchQuery.isNotEmpty ? retroState.searchQuery : (widget.filterKeyword ?? '')).trim().toLowerCase();
    final filteredEntries = entries.where((e) {
      if (filterKw.isEmpty) return true;
      return e.content.toLowerCase().contains(filterKw) ||
             e.authorName.toLowerCase().contains(filterKw) ||
             (e.teamName != null && e.teamName!.toLowerCase().contains(filterKw));
    }).toList();

    final isExpanded = _expandedColumns.contains(categoryKey);
    final displayedEntries = isExpanded ? filteredEntries : filteredEntries.take(3).toList();

    return Container(
      width: width,
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
          // Header with Icon, Title, and "+ Add" button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: themeColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => _openAddEntryDialog(categoryKey, title),
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: themeColor),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: themeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Cards list with Drag & Drop target
          DragTarget<SprintRetroEntryItemModel>(
            hitTestBehavior: HitTestBehavior.opaque,
            onWillAcceptWithDetails: (details) => details.data.category != categoryKey,
            onAcceptWithDetails: (details) async {
              final moved = details.data;
              await ref.read(workSprintRetroProvider.notifier).moveFeedbackEntry(moved.id, categoryKey);
              if (mounted) {
                final targetName = categoryKey == 'WENT_WELL'
                    ? 'What Went Well?'
                    : categoryKey == 'DID_NOT_GO_WELL'
                        ? "What Didn't Go Well?"
                        : 'What Should Improve?';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Card moved to "$targetName"'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isHovering ? themeColor.withValues(alpha: 0.08) : Colors.transparent,
                  border: isHovering ? Border.all(color: themeColor, width: 2) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (filteredEntries.isEmpty)
                      Container(
                        height: 90,
                        alignment: Alignment.center,
                        child: Text(
                          filterKw.isNotEmpty ? 'No cards match "$filterKw"' : 'No feedback submitted yet.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      )
                    else
                      ...displayedEntries.map((e) => _buildDraggableEntryCard(e, cardIcon, themeColor, isDark)),

                    // Inline Expansion: "View All (n)" or "Show Less"
                    if (filteredEntries.length > 3)
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedColumns.remove(categoryKey);
                            } else {
                              _expandedColumns.add(categoryKey);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                size: 15,
                                color: const Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isExpanded ? 'Show Less' : 'View All (${filteredEntries.length})',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableEntryCard(
    SprintRetroEntryItemModel entry,
    IconData cardIcon,
    Color themeColor,
    bool isDark,
  ) {
    return Draggable<SprintRetroEntryItemModel>(
      data: entry,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Container(
          width: 290,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: themeColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(cardIcon, size: 14, color: themeColor),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      entry.content,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildAvatar(entry.authorAvatar, entry.authorName, radius: 9),
                  const SizedBox(width: 5),
                  Text(
                    entry.authorName,
                    style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildEntryCard(entry, cardIcon, themeColor, isDark),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: _buildEntryCard(entry, cardIcon, themeColor, isDark),
      ),
    );
  }

  Widget _buildCardActionsMenu(
    SprintRetroEntryItemModel entry,
    IconData cardIcon,
    Color themeColor,
    bool isDark,
  ) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 16, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
      padding: EdgeInsets.zero,
      tooltip: 'Card Actions',
      constraints: const BoxConstraints(minWidth: 160),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (val) {
        if (val == 'edit') {
          _openEditRetroEntryDialog(entry);
        } else if (val == 'comment') {
          _openRetroCommentsDialog(entry, cardIcon, themeColor);
        } else if (val == 'action_item') {
          _openAddActionItemDialog(
            initialTitle: entry.content,
            sourceEntryId: entry.id,
          );
        } else if (val == 'delete') {
          _confirmDeleteRetroEntryDirect(entry.id);
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'edit',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Edit Card', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'comment',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Comments & Discussion', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'action_item',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.assignment_turned_in_outlined, size: 15, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text('Convert to Action Item', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem(
          value: 'delete',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text('Delete Card', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(
    SprintRetroEntryItemModel entry,
    IconData cardIcon,
    Color themeColor,
    bool isDark,
  ) {
    final retroState = ref.watch(workSprintRetroProvider);
    final hasVoted = retroState.votedEntryIds.contains(entry.id) || entry.hasVoted;
    final displayVotes = entry.votes;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.drag_indicator_rounded, size: 14, color: isDark ? Colors.white30 : const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Icon(cardIcon, size: 14, color: themeColor),
              const SizedBox(width: 7),
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openRetroCardDetailDialog(entry, cardIcon, themeColor),
                    child: Text(
                      entry.content,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _buildCardActionsMenu(entry, cardIcon, themeColor, isDark),
            ],
          ),
          if (entry.teamName != null && entry.teamName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.teamName!,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              // Author Avatar
              _buildAvatar(entry.authorAvatar, entry.authorName, radius: 10),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.authorName,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              // Generous Upvotes Chip
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref.read(workSprintRetroProvider.notifier).voteEntry(entry.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasVoted
                          ? const Color(0xFF2563EB).withValues(alpha: 0.18)
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasVoted
                            ? const Color(0xFF2563EB)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        width: hasVoted ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasVoted ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                          size: 14,
                          color: hasVoted
                              ? const Color(0xFF2563EB)
                              : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$displayVotes',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: hasVoted ? FontWeight.w700 : FontWeight.w600,
                            color: hasVoted
                                ? const Color(0xFF2563EB)
                                : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Generous Comments Chip
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openRetroCommentsDialog(entry, cardIcon, themeColor),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: entry.commentsCount > 0
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: entry.commentsCount > 0
                            ? const Color(0xFF10B981)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        width: entry.commentsCount > 0 ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 14,
                          color: entry.commentsCount > 0
                              ? const Color(0xFF10B981)
                              : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${entry.commentsCount}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: entry.commentsCount > 0
                                ? const Color(0xFF10B981)
                                : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openEditRetroEntryDialog(SprintRetroEntryItemModel entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final editCtrl = TextEditingController(text: entry.content);
    String selectedCategory = entry.category;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(
              children: [
                Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text('Edit Retrospective Card', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildCategoryChoiceChip(
                        title: 'What Went Well?',
                        categoryKey: 'WENT_WELL',
                        currentCategory: selectedCategory,
                        activeColor: const Color(0xFF10B981),
                        isDark: isDark,
                        onSelected: (cat) => setDialogState(() => selectedCategory = cat),
                      ),
                      _buildCategoryChoiceChip(
                        title: "What Didn't Go Well?",
                        categoryKey: 'DID_NOT_GO_WELL',
                        currentCategory: selectedCategory,
                        activeColor: const Color(0xFFEF4444),
                        isDark: isDark,
                        onSelected: (cat) => setDialogState(() => selectedCategory = cat),
                      ),
                      _buildCategoryChoiceChip(
                        title: 'What Should Improve?',
                        categoryKey: 'TO_IMPROVE',
                        currentCategory: selectedCategory,
                        activeColor: const Color(0xFF3B82F6),
                        isDark: isDark,
                        onSelected: (cat) => setDialogState(() => selectedCategory = cat),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Feedback / Takeaway Content', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: editCtrl,
                    maxLines: 4,
                    autofocus: true,
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Enter observation, win, blocker, or process improvement...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final text = editCtrl.text.trim();
                  if (text.isEmpty) return;
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  final success = await ref.read(workSprintRetroProvider.notifier).updateEntry(
                    entry.id,
                    category: selectedCategory,
                    content: text,
                  );
                  if (mounted && success) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Retrospective card updated.')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteRetroEntryDirect(String entryId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Delete Retrospective Card', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to permanently delete this retrospective card from the board?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(workSprintRetroProvider.notifier).deleteEntry(entryId);
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Retrospective card deleted from board.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openRetroCommentsDialog(
    SprintRetroEntryItemModel entry,
    IconData cardIcon,
    Color themeColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final commentCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Card snippet & close button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(cardIcon, size: 18, color: themeColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.content,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'by ${entry.authorName} • Discussion Thread',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),

                    // Comments List (Loaded from backend)
                    Expanded(
                      child: FutureBuilder<List<SprintRetroCommentModel>>(
                        future: ref.read(workSprintRetroProvider.notifier).loadComments(entry.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final comments = snapshot.data ?? [];
                          if (comments.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded, size: 36, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No comments yet. Start the discussion!',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView.separated(
                            itemCount: comments.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final c = comments[idx];
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _buildAvatar(c.authorAvatar, c.authorName, radius: 9),
                                        const SizedBox(width: 6),
                                        Text(
                                          c.authorName,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          c.createdAt,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                        if (c.isOwner) ...[
                                          const SizedBox(width: 6),
                                          InkWell(
                                            onTap: () async {
                                              await ref.read(workSprintRetroProvider.notifier).deleteComment(entry.id, c.id);
                                              setDialogState(() {});
                                            },
                                            child: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      c.content,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),
                    Divider(height: 1, color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),

                    // Add Comment Bar
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentCtrl,
                            enabled: !isSubmitting,
                            style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: 'Add a thought, solution or perspective...',
                              hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onSubmitted: (_) async {
                              final text = commentCtrl.text.trim();
                              if (text.isEmpty) return;
                              setDialogState(() => isSubmitting = true);
                              await ref.read(workSprintRetroProvider.notifier).addComment(entry.id, text);
                              commentCtrl.clear();
                              setDialogState(() => isSubmitting = false);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final text = commentCtrl.text.trim();
                                  if (text.isEmpty) return;
                                  setDialogState(() => isSubmitting = true);
                                  await ref.read(workSprintRetroProvider.notifier).addComment(entry.id, text);
                                  commentCtrl.clear();
                                  setDialogState(() => isSubmitting = false);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          child: isSubmitting
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Post', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================================
  // Retrospective Action Items Table Card
  // ============================================================================
  Widget _buildActionItemsTableCard(SprintRetroWorkspaceModel ws, bool isDark) {
    final retroState = ref.watch(workSprintRetroProvider);
    final allActionItems = ws.actionItems;
    final selectedIds = retroState.selectedActionItemIds;

    final filterKw = widget.filterKeyword?.trim().toLowerCase() ?? '';
    final statusF = widget.statusFilter;
    final priorityF = widget.priorityFilter;

    final actionItems = allActionItems.where((item) {
      if (filterKw.isNotEmpty) {
        final matchesTitle = item.title.toLowerCase().contains(filterKw);
        final matchesKey = item.itemKey.toLowerCase().contains(filterKw);
        final matchesOwner = item.ownerName.toLowerCase().contains(filterKw);
        if (!matchesTitle && !matchesKey && !matchesOwner) return false;
      }
      if (statusF != null && statusF != 'All') {
        final normStatus = item.status.toUpperCase();
        if (statusF == 'New' && normStatus != 'OPEN') return false;
        if (statusF == 'Active' && normStatus != 'IN_PROGRESS') return false;
        if (statusF == 'Completed' && normStatus != 'COMPLETED') return false;
        if (statusF != 'New' && statusF != 'Active' && statusF != 'Completed') {
          if (!normStatus.contains(statusF.toUpperCase())) return false;
        }
      }
      if (priorityF != null && priorityF != 'All') {
        if (!item.priority.toUpperCase().contains(priorityF.toUpperCase())) return false;
      }
      return true;
    }).toList();

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
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.assignment_outlined, size: 17, color: Color(0xFF2563EB)),
                const SizedBox(width: 7),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Retrospective Action Items (${actionItems.length})',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedIds.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${selectedIds.length} selected',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => ref.read(workSprintRetroProvider.notifier).toggleAllActionSelection(false),
                                child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF2563EB)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _openAddActionItemDialog(),
                      icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                      label: const Text('Add Action Item', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openBulkUpdateDialog(),
                      icon: const Icon(Icons.tune_rounded, size: 14),
                      label: Text(
                        selectedIds.isNotEmpty ? 'Bulk Update (${selectedIds.length})' : 'Bulk Update',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: selectedIds.isNotEmpty ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : const Color(0xFF334155)),
                        side: BorderSide(color: selectedIds.isNotEmpty ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (selectedIds.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _confirmBulkDeleteActionItems(selectedIds),
                        icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                        label: Text('Delete (${selectedIds.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _handleExportCsv(selectedIds: selectedIds),
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: Text(
                        selectedIds.isNotEmpty ? 'Export (${selectedIds.length})' : 'Export',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Data Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: true,
              onSelectAll: (val) {
                ref.read(workSprintRetroProvider.notifier).toggleAllActionSelection(val == true);
              },
              headingRowHeight: 38,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 46,
              horizontalMargin: 12,
              columnSpacing: 18,
              headingRowColor: WidgetStateProperty.all(
                isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              ),
              columns: const [
                DataColumn(label: Text('ID', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Action Item', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Owner', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Priority', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Due Date', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Status', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Linked Work Item', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('Actions', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
              ],
              rows: actionItems.map((item) {
                final isSelected = selectedIds.contains(item.id);

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) => ref.read(workSprintRetroProvider.notifier).toggleActionItemSelection(item.id),
                  cells: [
                    DataCell(
                      InkWell(
                        onTap: () => ref.read(workSprintRetroProvider.notifier).openActionDrawer(item),
                        child: Text(
                          item.itemKey,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAvatar(item.ownerAvatar, item.ownerName, radius: 10),
                          const SizedBox(width: 6),
                          Text(
                            item.ownerName,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(_buildPriorityBadge(item.priority)),
                    DataCell(
                      Text(
                        item.dueDate.isNotEmpty ? item.dueDate : '-',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    DataCell(_buildStatusBadge(item.status)),
                    DataCell(_buildLinkedWorkItemBadge(item)),
                    DataCell(
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 16),
                        padding: EdgeInsets.zero,
                        onSelected: (val) => _handleActionItemMenu(val, item),
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'VIEW', child: Text('View & Edit Details')),
                          PopupMenuItem(
                            value: 'LINK',
                            child: Row(
                              children: [
                                Icon(
                                  item.linkedWorkItemId == null ? Icons.add_task_rounded : Icons.link_rounded,
                                  size: 14,
                                  color: const Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 8),
                                Text(item.linkedWorkItemId == null ? 'Link / Convert to Work Item' : 'Change / Unlink Work Item'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(value: 'DELETE', child: Text('Delete Action Item')),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg;
    Color fg;
    final p = priority.toUpperCase();

    if (p == 'CRITICAL' || p == 'HIGH') {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      fg = const Color(0xFFEF4444);
    } else if (p == 'MEDIUM') {
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      fg = const Color(0xFFD97706);
    } else {
      bg = const Color(0xFF10B981).withValues(alpha: 0.12);
      fg = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        p[0] + p.substring(1).toLowerCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    final s = status.toUpperCase();

    if (s == 'IN_PROGRESS' || s == 'IN PROGRESS') {
      bg = const Color(0xFF0284C7).withValues(alpha: 0.12);
      fg = const Color(0xFF0284C7);
    } else if (s == 'COMPLETED' || s == 'RESOLVED' || s == 'DONE') {
      bg = const Color(0xFF10B981).withValues(alpha: 0.12);
      fg = const Color(0xFF10B981);
    } else if (s == 'PLANNED') {
      bg = const Color(0xFF8B5CF6).withValues(alpha: 0.12);
      fg = const Color(0xFF8B5CF6);
    } else {
      // OPEN
      bg = const Color(0xFF64748B).withValues(alpha: 0.12);
      fg = const Color(0xFF64748B);
    }

    String label = 'Open';
    if (s.contains('PROGRESS')) label = 'In Progress';
    if (s == 'PLANNED') label = 'Planned';
    if (s == 'COMPLETED') label = 'Completed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildLinkedWorkItemBadge(SprintRetroActionItemModel item) {
    final key = item.linkedWorkItemKey;
    if (key == null || key.isEmpty || key == '-') {
      return const Text('-', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.link_rounded, size: 13, color: Color(0xFF2563EB)),
        const SizedBox(width: 4),
        Text(
          key,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2563EB),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 4. Right Sidebar (Overview, Summary, Participation, History)
  // ============================================================================
  Widget _buildRightSidebar(SprintRetroWorkspaceModel ws, bool isDark) {
    return Column(
      children: [
        // Card 1: Sprint 8 Overview
        _buildSprintOverviewCard(ws, isDark),
        const SizedBox(height: 14),

        // Card 2: Retrospective Summary
        _buildRetrospectiveSummaryCard(ws, isDark),
        const SizedBox(height: 14),

        // Card 3: Participation (7)
        _buildParticipationCard(ws, isDark),
        const SizedBox(height: 14),

        // Card 4: Retrospective History
        _buildRetrospectiveHistoryCard(ws, isDark),
      ],
    );
  }

  Widget _buildSprintOverviewCard(SprintRetroWorkspaceModel ws, bool isDark) {
    final o = ws.sprintOverview;

    return Container(
      padding: const EdgeInsets.all(14),
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
            children: [
              const Icon(Icons.track_changes_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${o.sprintName} Overview',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSidebarRow('Status', o.status, valueColor: const Color(0xFF10B981), isDark: isDark),
          _buildSidebarRow(
            'Duration',
            o.dateRange.isNotEmpty
                ? o.dateRange
                : WorkSprintDateHelper.currentSprintFullDurationRange,
            isDark: isDark,
          ),
          _buildSidebarRow('Team', o.teamName, isDark: isDark),
          _buildSidebarRow('Completed Work', o.completedWork, isDark: isDark),
          const SizedBox(height: 4),
          _buildSidebarRow('Sprint Goal', o.sprintGoal, isDark: isDark, isMultiLine: true),
        ],
      ),
    );
  }

  Widget _buildSidebarRow(String label, String value, {Color? valueColor, required bool isDark, bool isMultiLine = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetrospectiveSummaryCard(SprintRetroWorkspaceModel ws, bool isDark) {
    final retro = ws.retrospective;

    return Container(
      padding: const EdgeInsets.all(14),
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
            children: [
              const Icon(Icons.article_outlined, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Retrospective Summary',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            retro.summary.isNotEmpty
                ? retro.summary
                : 'The team delivered key improvements, maintained good collaboration, and achieved 68% completion. Focus for the next sprint is on better requirement clarity, dependency management and scope stability.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipationCard(SprintRetroWorkspaceModel ws, bool isDark) {
    final retro = ws.retrospective;
    final participants = ws.participants;
    final totalCount = participants.isNotEmpty ? participants.length : retro.totalParticipants;

    return Container(
      padding: const EdgeInsets.all(14),
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
            children: [
              const Icon(Icons.people_alt_outlined, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Participation ($totalCount)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${retro.participationPct}%',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Avatars row
          if (participants.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No members in this team roster',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: participants.map((p) {
                  final tooltip = (p.email != null && p.email!.isNotEmpty)
                      ? '${p.name} (${p.email}) - ${p.role}'
                      : '${p.name} (${p.role})';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Tooltip(
                      message: tooltip,
                      child: _buildAvatar(p.avatarUrl, p.name, radius: 14),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRetrospectiveHistoryCard(SprintRetroWorkspaceModel ws, bool isDark) {
    final history = ws.history;

    return Container(
      padding: const EdgeInsets.all(14),
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
            children: [
              const Icon(Icons.history_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Retrospective History',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => ref.read(workSprintRetroProvider.notifier).setActiveTab('History'),
                child: const Text(
                  'View All',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Timeline milestones list
          ...history.map((h) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h.milestone,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          h.createdAt,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================================
  // Action Item Detail Drawer
  // ============================================================================
  // Handled by _RetroActionItemDetailDrawer (stateful widget below)

  // ============================================================================
  // Other Internal Tabs (Action Items Full Tab, Notes & Summary, Feedback, History)
  // ============================================================================
  Widget _buildActionItemsFullTab(SprintRetroWorkspaceModel ws, bool isDark) {
    return _buildActionItemsTableCard(ws, isDark);
  }

  Widget _buildNotesAndSummaryTab(SprintRetroWorkspaceModel ws, bool isDark) {
    final retro = ws.retrospective;
    final summaryCtrl = TextEditingController(text: retro.summary);
    final notesCtrl = TextEditingController(text: retro.notes ?? '');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Retrospective Summary & Key Decisions',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final notifier = ref.read(workSprintRetroProvider.notifier);
                  final success = await notifier.updateSession({
                    'summary': summaryCtrl.text.trim(),
                    'notes': notesCtrl.text.trim(),
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Retrospective summary & notes saved successfully!' : 'Failed to save summary'),
                        backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save_rounded, size: 14, color: Colors.white),
                label: const Text('Save Notes & Summary', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Executive Retrospective Summary', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          TextField(
            controller: summaryCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter executive retrospective summary and main takeaways...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Internal Discussion Notes & Action Minutes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          TextField(
            controller: notesCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter team notes, follow-up actions, and meeting minutes...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Session Key Decisions & Next Sprint Priorities', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...ws.actionItems.map((a) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
                title: Text(a.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                subtitle: Text('Owner: ${a.ownerName} | Due: ${a.dueDate}', style: const TextStyle(fontSize: 11)),
              )),
        ],
      ),
    );
  }

  Widget _buildFeedbackTab(SprintRetroWorkspaceModel ws, bool isDark) {
    final stats = ws.feedbackStats;
    final authState = ref.watch(authProvider);
    final currentUserId = authState.userData?['id'] as String? ??
        authState.userData?['user_id'] as String? ??
        Supabase.instance.client.auth.currentUser?.id;
    final isSuperAdmin = authState.role == UserRole.superAdmin;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.reviews_rounded, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sprint Team Feedback & Experience',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openSubmitFeedbackDialog(),
                icon: const Icon(Icons.rate_review_rounded, size: 14, color: Colors.white),
                label: const Text('Submit Feedback', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Feedback Stats Chips
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildFeedbackChip('Average Rating', '${stats.avgRating} / 5.0', Icons.star_rounded, const Color(0xFFF59E0B)),
              _buildFeedbackChip('Total Feedback', '${stats.totalFeedback}', Icons.forum_rounded, const Color(0xFF2563EB)),
              _buildFeedbackChip('Team Sentiment', '${stats.sentimentPct}% Positive', Icons.sentiment_satisfied_alt_rounded, const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Feedback cards list
          if (ws.feedback.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.forum_outlined, size: 36, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                  const SizedBox(height: 8),
                  Text(
                    'No feedback submitted yet for this sprint.',
                    style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else
            ...ws.feedback.map((f) {
              final isOwner = (currentUserId != null && f.userId != null && f.userId == currentUserId) || isSuperAdmin;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isOwner
                        ? const Color(0xFF2563EB).withValues(alpha: 0.35)
                        : (isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            f.category,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: List.generate(
                            5,
                            (idx) => Icon(
                              idx < f.rating ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 15,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                        if (isOwner) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (f.isAnonymous)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Anonymous', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          ),
                        Text(
                          f.userName,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isOwner ? FontWeight.bold : FontWeight.normal,
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                          ),
                        ),
                        if (f.createdAt.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text('• ${f.createdAt}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                        // Edit & Delete only for owner
                        if (isOwner) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Edit your feedback',
                            icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () => _openEditFeedbackDialog(f),
                          ),
                          IconButton(
                            tooltip: 'Delete your feedback',
                            icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () => _confirmDeleteFeedback(f),
                          ),
                        ],
                      ],
                    ),
                    if (f.content != null && f.content!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        f.content!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (f.suggestedImprovement != null && f.suggestedImprovement!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded, size: 14, color: Color(0xFF10B981)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Suggestion: ${f.suggestedImprovement}',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF047857)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFeedbackChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(SprintRetroWorkspaceModel ws, bool isDark) {
    final sortedHistory = List<SprintRetroHistoryItemModel>.from(ws.history);
    final displayedHistory = sortedHistory.take(_historyDisplayLimit).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Retrospective Audit Trail & History',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${displayedHistory.length} of ${sortedHistory.length} events',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sortedHistory.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 36, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                  const SizedBox(height: 8),
                  Text(
                    'No retrospective activity recorded yet.',
                    style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedHistory.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final h = displayedHistory[idx];
                IconData milestoneIcon = Icons.check_circle_rounded;
                Color milestoneColor = const Color(0xFF10B981);

                final mLower = h.milestone.toLowerCase();
                final isFeedbackMilestone = mLower.contains('feedback') ||
                    h.description.toLowerCase().contains('feedback') ||
                    h.actorName.toLowerCase().contains('anonymous');

                if (mLower.contains('action item')) {
                  milestoneIcon = Icons.task_alt_rounded;
                  milestoneColor = const Color(0xFF2563EB);
                } else if (isFeedbackMilestone) {
                  milestoneIcon = Icons.rate_review_rounded;
                  milestoneColor = const Color(0xFFF59E0B);
                } else if (mLower.contains('card') || mLower.contains('discussion')) {
                  milestoneIcon = Icons.dashboard_customize_rounded;
                  milestoneColor = const Color(0xFF8B5CF6);
                } else if (mLower.contains('session') || mLower.contains('created') || mLower.contains('closed')) {
                  milestoneIcon = Icons.flag_rounded;
                  milestoneColor = const Color(0xFF10B981);
                }

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: milestoneColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(milestoneIcon, size: 16, color: milestoneColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  h.milestone,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  h.createdAt,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              h.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  isFeedbackMilestone ? Icons.lock_outline_rounded : Icons.person_outline_rounded,
                                  size: 12,
                                  color: isFeedbackMilestone ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isFeedbackMilestone ? 'Anonymous Contributor' : h.actorName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: isFeedbackMilestone ? FontStyle.italic : FontStyle.normal,
                                    fontWeight: FontWeight.w500,
                                    color: isFeedbackMilestone
                                        ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                                if (isFeedbackMilestone) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Anonymous',
                                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (sortedHistory.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_historyDisplayLimit < sortedHistory.length)
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _historyDisplayLimit += 10;
                          });
                        },
                        icon: const Icon(Icons.expand_more_rounded, size: 16),
                        label: Text(
                          'Load More (${sortedHistory.length - _historyDisplayLimit} remaining)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    if (_historyDisplayLimit > 10) ...[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _historyDisplayLimit = 10;
                          });
                        },
                        icon: const Icon(Icons.expand_less_rounded, size: 16),
                        label: const Text(
                          'Show Less',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          side: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ============================================================================
  // Interactive Dialogs
  // ============================================================================
  void _openAddEntryDialog(String categoryKey, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentCtrl = TextEditingController();
    final ws = ref.read(workSprintRetroProvider).workspace;
    final retroState = ref.read(workSprintRetroProvider);
    final List<String> availableTeamNames = (ws?.availableTeams.isNotEmpty == true)
        ? ws!.availableTeams.map((t) => t.name).toList()
        : ref.read(workTeamsListProvider);
    final teamsList = availableTeamNames.where((t) => t != 'All Teams' && t != 'All').toList();

    String selectedTeam;
    final matchingTeam = ws?.availableTeams.where((t) => t.id == retroState.teamId || t.name.toLowerCase() == retroState.teamId?.toLowerCase()).firstOrNull;
    if (matchingTeam != null) {
      selectedTeam = matchingTeam.name;
    } else if (retroState.teamId != null && teamsList.contains(retroState.teamId)) {
      selectedTeam = retroState.teamId!;
    } else {
      selectedTeam = teamsList.isNotEmpty ? teamsList.first : 'Digital Campus Team';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text('Add to "$title"', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (teamsList.isNotEmpty) ...[
                    const Text('Assign Team', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF2D3748) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: teamsList.contains(selectedTeam) ? selectedTeam : teamsList.first,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                          items: teamsList.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedTeam = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('Note / Feedback *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: contentCtrl,
                    autofocus: true,
                    maxLines: 3,
                    style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Enter specific observation or takeaway...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final text = contentCtrl.text.trim();
                  if (text.isNotEmpty) {
                    final nav = Navigator.of(ctx);
                    final notifier = ref.read(workSprintRetroProvider.notifier);
                    final teamObj = ws?.availableTeams.where((t) => t.name == selectedTeam).firstOrNull;
                    await notifier.addEntry(
                      category: categoryKey,
                      content: text,
                      teamId: teamObj?.id,
                      teamName: selectedTeam,
                    );
                    nav.pop();
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                child: const Text('Add Entry', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAddActionItemDialog({String? initialTitle, String? sourceEntryId}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleCtrl = TextEditingController(text: initialTitle ?? '');
    final descCtrl = TextEditingController();
    final dueDateCtrl = TextEditingController(text: 'Feb 15, 2025');
    String priority = 'MEDIUM';
    String? ownerId;

    final ws = ref.read(workSprintRetroProvider).workspace;
    final retroState = ref.read(workSprintRetroProvider);
    final users = retroState.assignableUsers;

    final List<String> availableTeamNames = (ws?.availableTeams.isNotEmpty == true)
        ? ws!.availableTeams.map((t) => t.name).toList()
        : ref.read(workTeamsListProvider);
    final teamsList = availableTeamNames.where((t) => t != 'All Teams' && t != 'All').toList();

    String selectedTeam;
    final matchingTeam = ws?.availableTeams.where((t) => t.id == retroState.teamId || t.name.toLowerCase() == retroState.teamId?.toLowerCase()).firstOrNull;
    if (matchingTeam != null) {
      selectedTeam = matchingTeam.name;
    } else if (retroState.teamId != null && teamsList.contains(retroState.teamId)) {
      selectedTeam = retroState.teamId!;
    } else {
      selectedTeam = teamsList.isNotEmpty ? teamsList.first : 'Digital Campus Team';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          title: const Text('Add Retrospective Action Item', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'e.g. Conduct detailed requirement grooming session',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Action details and expected outcomes...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (teamsList.isNotEmpty) ...[
                    const Text('Team', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF2D3748) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: teamsList.contains(selectedTeam) ? selectedTeam : teamsList.first,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                          items: teamsList.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedTeam = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Owner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              initialValue: ownerId,
                              isExpanded: true,
                              hint: const Text('Select Owner', style: TextStyle(fontSize: 12)),
                              items: users.map((u) {
                                final label = u.email != null && u.email!.isNotEmpty
                                    ? '${u.fullName} (${u.email})'
                                    : u.fullName;
                                return DropdownMenuItem(
                                  value: u.userId,
                                  child: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (v) => setDialogState(() => ownerId = v),
                              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              initialValue: priority,
                              items: ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'].map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (v) => setDialogState(() => priority = v ?? 'MEDIUM'),
                              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('Due Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  TextField(
                    controller: dueDateCtrl,
                    style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'e.g. Feb 15, 2025',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isNotEmpty) {
                  final nav = Navigator.of(ctx);
                  final notifier = ref.read(workSprintRetroProvider.notifier);
                  final teamObj = ws?.availableTeams.where((t) => t.name == selectedTeam).firstOrNull;
                  await notifier.addActionItem(
                    title: title,
                    description: descCtrl.text.trim(),
                    ownerId: ownerId,
                    priority: priority,
                    dueDate: dueDateCtrl.text.trim(),
                    sourceEntryId: sourceEntryId,
                    teamId: teamObj?.id,
                    teamName: selectedTeam,
                  );
                  nav.pop();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Add Action Item', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openRetroCardDetailDialog(
    SprintRetroEntryItemModel entry,
    IconData cardIcon,
    Color themeColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final editCtrl = TextEditingController(text: entry.content);
    final commentCtrl = TextEditingController();
    final commentsFuture = ref.read(workSprintRetroProvider.notifier).loadComments(entry.id);
    bool isEditing = false;
    String currentCategory = entry.category;
    int currentVotes = entry.votes;
    bool currentHasVoted = entry.hasVoted;
    bool isPostingComment = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final catTitle = currentCategory == 'WENT_WELL'
              ? 'What Went Well?'
              : currentCategory == 'DID_NOT_GO_WELL'
                  ? "What Didn't Go Well?"
                  : 'What Should Improve?';

          final catColor = currentCategory == 'WENT_WELL'
              ? const Color(0xFF10B981)
              : currentCategory == 'DID_NOT_GO_WELL'
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF3B82F6);

          final catIcon = currentCategory == 'WENT_WELL'
              ? Icons.check_circle_outline_rounded
              : currentCategory == 'DID_NOT_GO_WELL'
                  ? Icons.error_outline_rounded
                  : Icons.push_pin_outlined;

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Header: Category Badge, Vote Button, Close
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: catColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(catIcon, size: 14, color: catColor),
                              const SizedBox(width: 6),
                              Text(
                                catTitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: catColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Upvote Button
                        InkWell(
                          onTap: () async {
                            setDialogState(() {
                              if (currentHasVoted) {
                                currentHasVoted = false;
                                currentVotes = (currentVotes - 1).clamp(0, 999999);
                              } else {
                                currentHasVoted = true;
                                currentVotes++;
                              }
                            });
                            await ref.read(workSprintRetroProvider.notifier).voteEntry(entry.id);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: currentHasVoted
                                  ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: currentHasVoted
                                    ? const Color(0xFF2563EB)
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  currentHasVoted ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                                  size: 14,
                                  color: currentHasVoted ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '$currentVotes Upvotes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: currentHasVoted ? FontWeight.w700 : FontWeight.w600,
                                    color: currentHasVoted ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 2. Author & Metadata Row
                    Row(
                      children: [
                        _buildAvatar(entry.authorAvatar, entry.authorName, radius: 14),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.authorName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                entry.createdAt.isNotEmpty ? entry.createdAt : 'Retrospective Feedback • Sprint 8',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isEditing)
                          TextButton.icon(
                            onPressed: () => setDialogState(() => isEditing = true),
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            label: const Text('Edit Note', style: TextStyle(fontSize: 11.5)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),

                    // 3. Scrollable Middle Body (Content + Actions + Comments)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Content or Edit Textbox
                            if (isEditing) ...[
                              TextField(
                                controller: editCtrl,
                                maxLines: 4,
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: 'Edit observation or takeaway...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        editCtrl.text = entry.content;
                                        isEditing = false;
                                      });
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final updated = editCtrl.text.trim();
                                      if (updated.isNotEmpty) {
                                        await ref.read(workSprintRetroProvider.notifier).updateEntry(
                                          entry.id,
                                          category: currentCategory,
                                          content: updated,
                                        );
                                        setDialogState(() => isEditing = false);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Save Changes'),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  editCtrl.text,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),

                            // 4. Move Category Chips
                            Text(
                              'Move to Category',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _buildCategoryChoiceChip(
                                  title: 'What Went Well?',
                                  categoryKey: 'WENT_WELL',
                                  currentCategory: currentCategory,
                                  activeColor: const Color(0xFF10B981),
                                  isDark: isDark,
                                  onSelected: (cat) async {
                                    if (currentCategory != cat) {
                                      setDialogState(() => currentCategory = cat);
                                      await ref.read(workSprintRetroProvider.notifier).moveFeedbackEntry(entry.id, cat);
                                    }
                                  },
                                ),
                                _buildCategoryChoiceChip(
                                  title: "What Didn't Go Well?",
                                  categoryKey: 'DID_NOT_GO_WELL',
                                  currentCategory: currentCategory,
                                  activeColor: const Color(0xFFEF4444),
                                  isDark: isDark,
                                  onSelected: (cat) async {
                                    if (currentCategory != cat) {
                                      setDialogState(() => currentCategory = cat);
                                      await ref.read(workSprintRetroProvider.notifier).moveFeedbackEntry(entry.id, cat);
                                    }
                                  },
                                ),
                                _buildCategoryChoiceChip(
                                  title: 'What Should Improve?',
                                  categoryKey: 'TO_IMPROVE',
                                  currentCategory: currentCategory,
                                  activeColor: const Color(0xFF3B82F6),
                                  isDark: isDark,
                                  onSelected: (cat) async {
                                    if (currentCategory != cat) {
                                      setDialogState(() => currentCategory = cat);
                                      await ref.read(workSprintRetroProvider.notifier).moveFeedbackEntry(entry.id, cat);
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // 5. Convert to Action Item Banner
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.assignment_turned_in_outlined, size: 18, color: Color(0xFF2563EB)),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Convert to Action Item',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                        Text(
                                          'Create a concrete action item assigned to a team member to track in this sprint.',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _openAddActionItemDialog(
                                        initialTitle: editCtrl.text.isNotEmpty ? editCtrl.text : entry.content,
                                        sourceEntryId: entry.id,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    child: const Text('Convert', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // 6. Discussion Thread
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Color(0xFF2563EB)),
                                const SizedBox(width: 6),
                                Text(
                                  'Discussion & Perspectives',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Comments List (Loaded from backend)
                            FutureBuilder<List<SprintRetroCommentModel>>(
                              future: commentsFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                                  );
                                }
                                final comments = snapshot.data ?? [];
                                if (comments.isEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'No comments yet. Share your perspective below.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return Column(
                                  children: comments.map((c) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _buildAvatar(c.authorAvatar, c.authorName, radius: 9),
                                            const SizedBox(width: 6),
                                            Text(
                                              c.authorName,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              c.createdAt,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                            if (c.isOwner) ...[
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () async {
                                                  await ref.read(workSprintRetroProvider.notifier).deleteComment(entry.id, c.id);
                                                  setDialogState(() {});
                                                },
                                                child: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          c.content,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                                );
                              },
                            ),

                            // Add Comment input
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: commentCtrl,
                                    enabled: !isPostingComment,
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                                    decoration: InputDecoration(
                                      hintText: 'Add a perspective or response...',
                                      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onSubmitted: (_) async {
                                      final text = commentCtrl.text.trim();
                                      if (text.isEmpty || isPostingComment) return;
                                      setDialogState(() => isPostingComment = true);
                                      final ok = await ref.read(workSprintRetroProvider.notifier).addComment(entry.id, text);
                                      if (ok != null) commentCtrl.clear();
                                      setDialogState(() => isPostingComment = false);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: isPostingComment
                                      ? null
                                      : () async {
                                          final text = commentCtrl.text.trim();
                                          if (text.isEmpty) return;
                                          setDialogState(() => isPostingComment = true);
                                          final ok = await ref.read(workSprintRetroProvider.notifier).addComment(entry.id, text);
                                          if (ok != null) commentCtrl.clear();
                                          setDialogState(() => isPostingComment = false);
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                  child: isPostingComment
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Reply', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Divider(height: 1, color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),

                    // 7. Footer: Delete Button & Done
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            _confirmDeleteRetroEntry(entry.id, ctx);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                          label: const Text('Delete Card', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChoiceChip({
    required String title,
    required String categoryKey,
    required String currentCategory,
    required Color activeColor,
    required bool isDark,
    required Function(String) onSelected,
  }) {
    final isSelected = currentCategory == categoryKey;
    return ChoiceChip(
      selected: isSelected,
      label: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
        ),
      ),
      selectedColor: activeColor,
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected ? activeColor : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      onSelected: (_) => onSelected(categoryKey),
    );
  }

  void _confirmDeleteRetroEntry(String entryId, BuildContext dialogCtx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        title: const Text('Confirm Deletion', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this retrospective feedback card?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(dialogCtx);
              final nav = ScaffoldMessenger.of(context);
              final success = await ref.read(workSprintRetroProvider.notifier).deleteEntry(entryId);
              if (success) {
                nav.showSnackBar(
                  const SnackBar(content: Text('Retrospective card deleted.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openBulkUpdateDialog() {
    final selectedCount = ref.read(workSprintRetroProvider).selectedActionItemIds.length;
    if (selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one action item from the table to bulk update.')),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    String status = 'IN_PROGRESS';
    String priority = 'HIGH';
    bool updateStatus = true;
    bool updatePriority = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          title: Text('Bulk Update ($selectedCount items)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: updateStatus,
                onChanged: (v) => setDialogState(() => updateStatus = v == true),
                title: const Text('Update Status', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              if (updateStatus) ...[
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: ['OPEN', 'PLANNED', 'IN_PROGRESS', 'COMPLETED'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setDialogState(() => status = v ?? 'IN_PROGRESS'),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: updatePriority,
                onChanged: (v) => setDialogState(() => updatePriority = v == true),
                title: const Text('Update Priority', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              if (updatePriority) ...[
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  items: ['URGENT', 'HIGH', 'MEDIUM', 'LOW'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setDialogState(() => priority = v ?? 'HIGH'),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final notifier = ref.read(workSprintRetroProvider.notifier);
                await notifier.bulkUpdateActionItems(
                  status: updateStatus ? status : null,
                  priority: updatePriority ? priority : null,
                );
                nav.pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Apply Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmBulkDeleteActionItems(Set<String> selectedIds) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        title: const Text('Confirm Bulk Deletion', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete ${selectedIds.length} selected action item(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              await ref.read(workSprintRetroProvider.notifier).bulkDeleteActionItems(selectedIds.toList());
              nav.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openEditSessionDialog(SprintRetroWorkspaceModel ws) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final retro = ws.retrospective;
    final titleCtrl = TextEditingController(text: retro.title);
    final goalCtrl = TextEditingController(text: retro.sprintGoal);
    final summaryCtrl = TextEditingController(text: retro.summary);
    final notesCtrl = TextEditingController(text: retro.notes ?? '');
    int duration = retro.durationMinutes > 0 ? retro.durationMinutes : 60;
    String status = ['IN_PROGRESS', 'COMPLETED', 'SCHEDULED', 'PAUSED'].contains(retro.status.toUpperCase())
        ? retro.status.toUpperCase()
        : 'IN_PROGRESS';
    String? selectedFacilitatorId;
    final participants = ws.participants;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 8),
              Text('Edit Retrospective Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Session Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              initialValue: status,
                              items: ['IN_PROGRESS', 'COMPLETED', 'SCHEDULED', 'PAUSED']
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                                  .toList(),
                              onChanged: (v) => setDialogState(() => status = v ?? status),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Duration (Minutes)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            TextFormField(
                              initialValue: duration.toString(),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => duration = int.tryParse(v) ?? 60,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (participants.isNotEmpty) ...[
                    const Text('Facilitator', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedFacilitatorId,
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(retro.facilitatorName.isNotEmpty ? '${retro.facilitatorName} (Current)' : 'Default Facilitator', style: const TextStyle(fontSize: 12)),
                        ),
                        ...participants.map((p) => DropdownMenuItem<String?>(
                              value: p.userId.isNotEmpty ? p.userId : p.id,
                              child: Text('${p.name} (${p.role})', style: const TextStyle(fontSize: 12)),
                            )),
                      ],
                      onChanged: (v) => setDialogState(() => selectedFacilitatorId = v),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const Text('Sprint Focus Goal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  TextField(
                    controller: goalCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Executive Summary', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  TextField(
                    controller: summaryCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter executive summary and takeaways...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Internal Meeting Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter meeting notes, follow-up items...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final notifier = ref.read(workSprintRetroProvider.notifier);
                final success = await notifier.updateSession({
                  'title': titleCtrl.text.trim(),
                  'status': status,
                  'sprint_goal': goalCtrl.text.trim(),
                  'duration_minutes': duration,
                  'summary': summaryCtrl.text.trim(),
                  'notes': notesCtrl.text.trim(),
                  if (selectedFacilitatorId != null) 'facilitator_id': selectedFacilitatorId,
                });
                nav.pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Retrospective session updated successfully!' : 'Failed to update session'),
                      backgroundColor: success ? const Color(0xFF2563EB) : const Color(0xFFEF4444),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.save_rounded, size: 15, color: Colors.white),
              label: const Text('Save Changes', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            ),
          ],
        ),
      ),
    );
  }

  void _openCloseSessionDialog(SprintRetroWorkspaceModel ws) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaryCtrl = TextEditingController(text: ws.retrospective.summary);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 20),
            SizedBox(width: 8),
            Text('Complete Retrospective Session', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completing the session marks the retrospective as COMPLETED and finalizes the executive summary for ${ws.sprintOverview.sprintName}. You can still reopen it later if needed.',
                style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              const Text('Final Executive Summary', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              TextField(
                controller: summaryCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Summarize key takeaways, achievements and focus areas...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final notifier = ref.read(workSprintRetroProvider.notifier);
              final success = await notifier.closeSession(summary: summaryCtrl.text.trim());
              nav.pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Retrospective session completed successfully!' : 'Failed to complete session'),
                    backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_circle_rounded, size: 15, color: Colors.white),
            label: const Text('Complete Session', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          ),
        ],
      ),
    );
  }

  void _openReopenSessionDialog(SprintRetroWorkspaceModel ws) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.replay_rounded, color: Color(0xFF2563EB), size: 20),
            SizedBox(width: 8),
            Text('Reopen Retrospective Session?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Text(
            'This will change the retrospective status back to IN_PROGRESS. Team members will be able to submit additional feedback cards, update votes, and modify action items.',
            style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final notifier = ref.read(workSprintRetroProvider.notifier);
              final success = await notifier.reopenSession();
              nav.pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Retrospective reopened successfully! Status is now IN_PROGRESS.' : 'Failed to reopen retrospective'),
                    backgroundColor: success ? const Color(0xFF2563EB) : const Color(0xFFEF4444),
                  ),
                );
              }
            },
            icon: const Icon(Icons.lock_open_rounded, size: 15, color: Colors.white),
            label: const Text('Confirm Reopen', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  void _openStartNewSessionDialog(SprintRetroWorkspaceModel ws) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final retro = ws.retrospective;
    final titleCtrl = TextEditingController(text: retro.title.isNotEmpty ? retro.title : 'Sprint Retrospective');
    final goalCtrl = TextEditingController(text: retro.sprintGoal);
    int duration = retro.durationMinutes > 0 ? retro.durationMinutes : 60;
    bool resetCards = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.fiber_new_rounded, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 8),
              Text('Start New Retrospective Session', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Initialize a fresh retrospective session for ${ws.sprintOverview.sprintName}. Sets status to IN_PROGRESS and updates the session timeline to active.',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                const Text('Session Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Duration (Minutes)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: duration.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => duration = int.tryParse(v) ?? 60,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Sprint Focus Goal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                TextField(
                  controller: goalCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => setDialogState(() => resetCards = !resetCards),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: resetCards,
                          onChanged: (v) => setDialogState(() => resetCards = v ?? false),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Reset existing discussion cards (start with clean board)',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final notifier = ref.read(workSprintRetroProvider.notifier);
                bool success;
                if (resetCards) {
                  await notifier.resetBoard();
                  success = await notifier.startNewSession(
                    title: titleCtrl.text.trim(),
                    durationMinutes: duration,
                    sprintGoal: goalCtrl.text.trim(),
                  );
                } else {
                  success = await notifier.startNewSession(
                    title: titleCtrl.text.trim(),
                    durationMinutes: duration,
                    sprintGoal: goalCtrl.text.trim(),
                  );
                }
                nav.pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'New retrospective session started successfully!' : 'Failed to start session'),
                      backgroundColor: success ? const Color(0xFF2563EB) : const Color(0xFFEF4444),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
              label: const Text('Start Session', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            ),
          ],
        ),
      ),
    );
  }

  void _openResetBoardDialog(SprintRetroWorkspaceModel ws) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
            SizedBox(width: 8),
            Text('Reset Discussion Board?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear all discussion cards (Went Well, Didn\'t Go Well, Should Improve) for this sprint? This action cannot be undone.',
          style: TextStyle(fontSize: 12.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final notifier = ref.read(workSprintRetroProvider.notifier);
              final success = await notifier.resetBoard();
              nav.pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Discussion board reset successfully!' : 'Failed to reset board'),
                    backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                );
              }
            },
            icon: const Icon(Icons.restart_alt_rounded, size: 15, color: Colors.white),
            label: const Text('Reset Board', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
          ),
        ],
      ),
    );
  }

  void _openInviteMemberDialog(SprintRetroWorkspaceModel ws) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final retroState = ref.read(workSprintRetroProvider);
    final assignableUsers = retroState.assignableUsers;
    final existingUserIds = ws.participants.map((p) => p.userId).toSet();
    final availableUsers = assignableUsers.where((u) => !existingUserIds.contains(u.id)).toList();

    String? selectedUserId = availableUsers.isNotEmpty ? availableUsers.first.id : null;
    String selectedRole = 'Developer';

    // Find the current team ID
    final teamObj = ws.availableTeams.where((t) => t.id == retroState.teamId || t.name == ws.sprintOverview.teamName).firstOrNull;
    final teamId = teamObj?.id ?? ws.availableTeams.firstOrNull?.id;

    if (teamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active team found for this retrospective.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text('Invite / Add Member to Team', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add a team member to ${teamObj?.name ?? ws.sprintOverview.teamName}. They will immediately appear in the retrospective roster and participation stats.',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                const Text('Select User', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                if (availableUsers.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedUserId,
                    items: availableUsers.map((u) {
                      return DropdownMenuItem(
                        value: u.id,
                        child: Text('${u.fullName} (${u.role})', style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selectedUserId = v),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  )
                else
                  Text(
                    'All available institution users are already in this team roster.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                const SizedBox(height: 12),
                const Text('Team Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  items: ['Developer', 'Senior Developer', 'QA Engineer', 'UI/UX Designer', 'DevOps Engineer', 'System Analyst', 'Member']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedRole = v ?? 'Developer'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: selectedUserId == null
                  ? null
                  : () async {
                      final nav = Navigator.of(ctx);
                      final notifier = ref.read(workSprintRetroProvider.notifier);
                      final success = await notifier.addTeamMember(teamId, selectedUserId!, role: selectedRole);
                      nav.pop();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Member added to team roster successfully!' : 'Failed to add member to team'),
                            backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 15, color: Colors.white),
              label: const Text('Add to Team', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            ),
          ],
        ),
      ),
    );
  }

  void _openSubmitFeedbackDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String category = 'Team Collaboration';
    int rating = 5;
    final contentCtrl = TextEditingController();
    bool isAnonymous = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          title: const Text('Submit Retrospective Feedback', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: ['Team Collaboration', 'Planning', 'Workload', 'Process', 'Tools'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setDialogState(() => category = v ?? 'Team Collaboration'),
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              ),
              const SizedBox(height: 10),
              const Text('Rating (1 - 5 Stars)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              Row(
                children: List.generate(
                  5,
                  (idx) => IconButton(
                    icon: Icon(
                      idx < rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                    onPressed: () => setDialogState(() => rating = idx + 1),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Feedback & Comments', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              TextField(
                controller: contentCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share your thoughts on sprint execution...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: isAnonymous,
                contentPadding: EdgeInsets.zero,
                title: const Text('Submit Anonymously', style: TextStyle(fontSize: 12)),
                onChanged: (v) => setDialogState(() => isAnonymous = v == true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final notifier = ref.read(workSprintRetroProvider.notifier);
                await notifier.submitFeedback(
                  category: category,
                  rating: rating,
                  content: contentCtrl.text.trim(),
                  isAnonymous: isAnonymous,
                );
                nav.pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Submit Feedback', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditFeedbackDialog(SprintRetroFeedbackItemModel feedback) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String category = feedback.category;
    int rating = feedback.rating;
    final contentCtrl = TextEditingController(text: feedback.content ?? '');
    final impCtrl = TextEditingController(text: feedback.suggestedImprovement ?? '');
    bool isAnonymous = feedback.isAnonymous;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Edit Retrospective Feedback', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Category', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: ['Team Collaboration', 'Planning', 'Workload', 'Process', 'Tools'].contains(category) ? category : 'Team Collaboration',
                  items: ['Team Collaboration', 'Planning', 'Workload', 'Process', 'Tools'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? 'Team Collaboration'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Rating (1 - 5 Stars)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(
                    5,
                    (idx) => IconButton(
                      icon: Icon(
                        idx < rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                      onPressed: () => setDialogState(() => rating = idx + 1),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Feedback & Comments', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts on sprint execution...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Suggested Improvement (Optional)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                TextField(
                  controller: impCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'How can the team improve in next sprint?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: isAnonymous,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Keep Feedback Anonymous', style: TextStyle(fontSize: 12)),
                  onChanged: (v) => setDialogState(() => isAnonymous = v == true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      final nav = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      final notifier = ref.read(workSprintRetroProvider.notifier);
                      final success = await notifier.updateFeedback(
                        feedback.id,
                        category: category,
                        rating: rating,
                        content: contentCtrl.text.trim(),
                        suggestedImprovement: impCtrl.text.trim(),
                        isAnonymous: isAnonymous,
                      );
                      nav.pop();
                      if (mounted && success) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Feedback updated successfully!')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: Text(isSaving ? 'Saving...' : 'Save Changes', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFeedback(SprintRetroFeedbackItemModel feedback) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Feedback', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove your feedback for "${feedback.category}"? This action cannot be undone.',
          style: const TextStyle(fontSize: 12.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final notifier = ref.read(workSprintRetroProvider.notifier);
              final success = await notifier.deleteFeedback(feedback.id);
              nav.pop();
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Feedback deleted successfully!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteActionItem(SprintRetroActionItemModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Action Item', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete ${item.itemKey}: "${item.title}"? This action cannot be undone.',
          style: const TextStyle(fontSize: 12.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final notifier = ref.read(workSprintRetroProvider.notifier);
              final success = await notifier.deleteActionItem(item.id);
              nav.pop();
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.itemKey} deleted successfully!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleActionItemMenu(String action, SprintRetroActionItemModel item) {
    final notifier = ref.read(workSprintRetroProvider.notifier);
    if (action == 'VIEW') {
      notifier.openActionDrawer(item);
    } else if (action == 'CONVERT' || action == 'LINK') {
      _showLinkOrConvertDialog(item);
    } else if (action == 'DELETE') {
      _confirmDeleteActionItem(item);
    }
  }

  void _showLinkOrConvertDialog(SprintRetroActionItemModel item) {
    final ws = ref.read(workSprintRetroProvider).workspace;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final participants = ws?.participants ?? [];

    showDialog(
      context: context,
      builder: (ctx) => _LinkOrConvertWorkItemDialog(
        item: item,
        participants: participants,
        isDark: isDark,
        onSuccess: () {
          ref.read(workSprintRetroProvider.notifier).loadWorkspace(silent: true);
        },
      ),
    );
  }

  void _handleHeaderMenuAction(String action, SprintRetroWorkspaceModel ws) {
    if (action == 'CLOSE') {
      _openCloseSessionDialog(ws);
    } else if (action == 'REOPEN') {
      _openReopenSessionDialog(ws);
    } else if (action == 'START_NEW') {
      _openStartNewSessionDialog(ws);
    } else if (action == 'RESET_ENTRIES') {
      _openResetBoardDialog(ws);
    } else if (action == 'ADD_PARTICIPANT') {
      _openInviteMemberDialog(ws);
    } else if (action == 'EDIT_SESSION') {
      _openEditSessionDialog(ws);
    } else if (action == 'EDIT_SUMMARY') {
      ref.read(workSprintRetroProvider.notifier).setActiveTab('Notes & Summary');
    } else if (action == 'EXPORT') {
      _handleExportCsv();
    }
  }

  Future<void> _handleExportCsv({Set<String>? selectedIds}) async {
    final notifier = ref.read(workSprintRetroProvider.notifier);
    await notifier.exportCsv();
    if (mounted) {
      final msg = (selectedIds != null && selectedIds.isNotEmpty)
          ? 'Exported ${selectedIds.length} selected action item(s) successfully!'
          : 'Retrospective action items exported successfully!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildAvatar(String? url, String name, {double radius = 12}) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url),
      );
    }
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
      child: Text(
        initial,
        style: TextStyle(fontSize: radius * 0.9, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
      ),
    );
  }

  SprintRetroWorkspaceModel _createFallbackWorkspace(String sprintId) {
    return SprintRetroWorkspaceModel(
      retrospective: SprintRetroHeaderModel(
        id: 'retro-8-id',
        sprintId: sprintId,
        title: 'Sprint Retrospective',
        status: 'COMPLETED',
        sessionDateFormatted: WorkSprintDateHelper.retroSessionDateFmt,
        facilitatorName: 'Neha Sharma',
        participantCount: 7,
        totalParticipants: 7,
        participationPct: 100,
        durationMinutes: 60,
        sprintGoal: 'Deliver student portal enhancement, examination notifications and key infrastructure fixes.',
        summary: 'The team delivered key improvements, maintained good collaboration, and achieved 68% completion. Focus for the next sprint is on better requirement clarity, dependency management and scope stability.',
      ),
      sprintOverview: SprintRetroOverviewModel(
        sprintId: sprintId,
        sprintName: 'Sprint 8',
        status: 'Completed',
        dateRange: WorkSprintDateHelper.currentSprintFullDurationRange,
        teamName: 'Digital Campus Team',
        completedWork: '29 of 42 (68%)',
        sprintGoal: 'Deliver student portal enhancement, examination notifications and key infrastructure fixes.',
      ),
      wentWell: const SprintRetroCategoryColumnModel(
        title: 'What Went Well? (6)',
        key: 'WENT_WELL',
        count: 6,
        entries: [
          SprintRetroEntryItemModel(
            id: 'e1',
            category: 'WENT_WELL',
            content: 'Team collaboration was excellent, especially between academic and IT teams.',
            votes: 3,
            commentsCount: 1,
            authorName: 'Neha Sharma',
          ),
          SprintRetroEntryItemModel(
            id: 'e2',
            category: 'WENT_WELL',
            content: 'Student portal performance improved significantly after the optimization.',
            votes: 4,
            commentsCount: 0,
            authorName: 'Amit Kumar',
          ),
          SprintRetroEntryItemModel(
            id: 'e3',
            category: 'WENT_WELL',
            content: 'Most tasks were completed on or before the due date.',
            votes: 2,
            commentsCount: 0,
            authorName: 'Priya Singh',
          ),
        ],
      ),
      didNotGoWell: const SprintRetroCategoryColumnModel(
        title: "What Didn't Go Well? (4)",
        key: 'DID_NOT_GO_WELL',
        count: 4,
        entries: [
          SprintRetroEntryItemModel(
            id: 'e7',
            category: 'DID_NOT_GO_WELL',
            content: 'Some requirements were not clearly defined in the initial planning.',
            votes: 3,
            commentsCount: 2,
            authorName: 'Rahul Mehta',
          ),
          SprintRetroEntryItemModel(
            id: 'e8',
            category: 'DID_NOT_GO_WELL',
            content: 'Dependency on the external verification API caused delays.',
            votes: 2,
            commentsCount: 1,
            authorName: 'Vikas Gupta',
          ),
          SprintRetroEntryItemModel(
            id: 'e9',
            category: 'DID_NOT_GO_WELL',
            content: 'A few tasks were added mid-sprint, impacting capacity.',
            votes: 1,
            commentsCount: 0,
            authorName: 'Neha Sharma',
          ),
        ],
      ),
      shouldImprove: const SprintRetroCategoryColumnModel(
        title: 'What Should Improve? (5)',
        key: 'TO_IMPROVE',
        count: 5,
        entries: [
          SprintRetroEntryItemModel(
            id: 'e11',
            category: 'TO_IMPROVE',
            content: 'Improve requirement grooming before sprint planning.',
            votes: 5,
            commentsCount: 0,
            authorName: 'Amit Kumar',
          ),
          SprintRetroEntryItemModel(
            id: 'e12',
            category: 'TO_IMPROVE',
            content: 'Set clearer acceptance criteria for all major tasks.',
            votes: 3,
            commentsCount: 1,
            authorName: 'Priya Singh',
          ),
          SprintRetroEntryItemModel(
            id: 'e13',
            category: 'TO_IMPROVE',
            content: 'Limit scope changes during an active sprint.',
            votes: 2,
            commentsCount: 0,
            authorName: 'Neha Sharma',
          ),
        ],
      ),
      actionItems: const [
        SprintRetroActionItemModel(
          id: 'a1',
          itemKey: 'RA-001',
          title: 'Conduct detailed requirement grooming session before next sprint.',
          ownerName: 'Amit Kumar',
          priority: 'HIGH',
          dueDate: 'Jan 20, 2025',
          status: 'IN_PROGRESS',
          linkedWorkItemKey: 'TK-1045',
        ),
        SprintRetroActionItemModel(
          id: 'a2',
          itemKey: 'RA-002',
          title: 'Define and document acceptance criteria for all user stories.',
          ownerName: 'Priya Singh',
          priority: 'MEDIUM',
          dueDate: 'Jan 22, 2025',
          status: 'OPEN',
          linkedWorkItemKey: 'ST-1021',
        ),
        SprintRetroActionItemModel(
          id: 'a3',
          itemKey: 'RA-003',
          title: 'Review and manage external API dependencies earlier.',
          ownerName: 'Rahul Mehta',
          priority: 'HIGH',
          dueDate: 'Jan 24, 2025',
          status: 'IN_PROGRESS',
          linkedWorkItemKey: 'TK-1048',
        ),
        SprintRetroActionItemModel(
          id: 'a4',
          itemKey: 'RA-004',
          title: 'Stabilize sprint scope and avoid mid-sprint additions.',
          ownerName: 'Sneha Verma',
          priority: 'MEDIUM',
          dueDate: 'Jan 24, 2025',
          status: 'OPEN',
        ),
        SprintRetroActionItemModel(
          id: 'a5',
          itemKey: 'RA-005',
          title: 'Update team capacity plan based on actuals from Sprint 8.',
          ownerName: 'Vikas Gupta',
          priority: 'LOW',
          dueDate: 'Jan 27, 2025',
          status: 'PLANNED',
          linkedWorkItemKey: 'TK-1050',
        ),
      ],
      participants: const [
        SprintRetroParticipantModel(id: 'p1', userId: 'u1', name: 'Neha Sharma', role: 'Facilitator'),
        SprintRetroParticipantModel(id: 'p2', userId: 'u2', name: 'Amit Kumar', role: 'Senior Developer'),
        SprintRetroParticipantModel(id: 'p3', userId: 'u3', name: 'Priya Singh', role: 'UI/UX Designer'),
        SprintRetroParticipantModel(id: 'p4', userId: 'u4', name: 'Rahul Mehta', role: 'Backend Developer'),
        SprintRetroParticipantModel(id: 'p5', userId: 'u5', name: 'Sneha Verma', role: 'QA Engineer'),
        SprintRetroParticipantModel(id: 'p6', userId: 'u6', name: 'Vikas Gupta', role: 'DevOps Engineer'),
        SprintRetroParticipantModel(id: 'p7', userId: 'u7', name: 'Karan Jain', role: 'System Analyst'),
      ],
      history: const [
        SprintRetroHistoryItemModel(
          id: 'h1',
          milestone: 'Retrospective created',
          description: 'Session initialized',
          actorName: 'Neha Sharma',
          createdAt: 'Jan 14, 2025 03:40 PM',
        ),
        SprintRetroHistoryItemModel(
          id: 'h2',
          milestone: 'Discussion completed',
          description: 'Team contributed discussion entries',
          actorName: 'Neha Sharma',
          createdAt: 'Jan 14, 2025 04:20 PM',
        ),
        SprintRetroHistoryItemModel(
          id: 'h3',
          milestone: 'Action items added (5)',
          description: 'Action items assigned',
          actorName: 'Neha Sharma',
          createdAt: 'Jan 14, 2025 04:35 PM',
        ),
        SprintRetroHistoryItemModel(
          id: 'h4',
          milestone: 'Retrospective closed',
          description: 'Session completed and summary finalized',
          actorName: 'Neha Sharma',
          createdAt: 'Jan 14, 2025 05:00 PM',
        ),
      ],
      feedback: const [
        SprintRetroFeedbackItemModel(
          id: 'f1',
          category: 'Team Collaboration',
          rating: 5,
          content: 'Great energy and cross-team communication throughout the release.',
          userName: 'Amit Kumar',
        ),
      ],
      feedbackStats: const SprintRetroFeedbackStatsModel(
        totalFeedback: 4,
        avgRating: 4.5,
        sentimentPct: 92,
      ),
    );
  }
}

// ============================================================================
// Action Item Detail Drawer Widget
// ============================================================================
class _RetroActionItemDetailDrawer extends ConsumerStatefulWidget {
  final SprintRetroActionItemModel item;
  final bool isDark;
  final VoidCallback onClose;

  const _RetroActionItemDetailDrawer({
    required this.item,
    required this.isDark,
    required this.onClose,
  });

  @override
  ConsumerState<_RetroActionItemDetailDrawer> createState() => _RetroActionItemDetailDrawerState();
}

class _RetroActionItemDetailDrawerState extends ConsumerState<_RetroActionItemDetailDrawer> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late String _priority;
  late String _status;
  late int _progress;
  bool _isSaving = false;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.item.title);
    _descCtrl = TextEditingController(text: widget.item.description ?? '');
    _priority = widget.item.priority;
    _status = widget.item.status;
    _progress = widget.item.progressPercentage;
  }

  @override
  void didUpdateWidget(covariant _RetroActionItemDetailDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _titleCtrl.text = widget.item.title;
      _descCtrl.text = widget.item.description ?? '';
      _priority = widget.item.priority;
      _status = widget.item.status;
      _progress = widget.item.progressPercentage;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final notifier = ref.read(workSprintRetroProvider.notifier);
    final success = await notifier.updateActionItem(widget.item.id, {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'priority': _priority,
      'status': _status,
      'progress': _progress,
    });
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.item.itemKey} updated successfully!')),
        );
        widget.onClose();
      }
    }
  }

  void _openLinkOrConvertDialog() {
    final ws = ref.read(workSprintRetroProvider).workspace;
    final participants = ws?.participants ?? [];
    showDialog(
      context: context,
      builder: (ctx) => _LinkOrConvertWorkItemDialog(
        item: widget.item,
        participants: participants,
        isDark: widget.isDark,
        onSuccess: () {
          ref.read(workSprintRetroProvider.notifier).loadWorkspace(silent: true);
          widget.onClose();
        },
      ),
    );
  }

  Future<void> _handleUnlink() async {
    setState(() => _isConverting = true);
    final notifier = ref.read(workSprintRetroProvider.notifier);
    final success = await notifier.linkActionItemToWorkItem(widget.item.id, workItemId: null);
    if (mounted) {
      setState(() => _isConverting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unlinked work item from ${widget.item.itemKey}')),
        );
        widget.onClose();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unlink work item')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Material(
      elevation: 16,
      color: isDark ? const Color(0xFF13182C) : Colors.white,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isDark ? const Color(0xFF1F293D) : const Color(0xFFCBD5E1),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.item.itemKey,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Action Item Details',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 14),

            Expanded(
              child: ListView(
                children: [
                  const Text('Title', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Description', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Priority', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              initialValue: ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'].contains(_priority) ? _priority : 'MEDIUM',
                              items: ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _priority = v);
                              },
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Status', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              initialValue: ['OPEN', 'PLANNED', 'IN_PROGRESS', 'COMPLETED'].contains(_status) ? _status : 'OPEN',
                              items: ['OPEN', 'PLANNED', 'IN_PROGRESS', 'COMPLETED'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _status = v);
                              },
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Progress
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Progress', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      Text('$_progress%', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    ],
                  ),
                  Slider(
                    value: _progress.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: (v) => setState(() => _progress = v.toInt()),
                  ),
                  const SizedBox(height: 14),

                  // Linked Work Item
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Linked Work Item', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                            if (widget.item.linkedWorkItemId != null)
                              TextButton.icon(
                                onPressed: _isConverting ? null : _handleUnlink,
                                icon: const Icon(Icons.link_off_rounded, size: 13, color: Color(0xFFEF4444)),
                                label: const Text('Unlink', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (widget.item.linkedWorkItemKey != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.link_rounded, size: 15, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Text(
                                widget.item.linkedWorkItemKey!,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Linked Real Work Item', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _openLinkOrConvertDialog,
                            icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                            label: const Text('Change Linked Work Item', style: TextStyle(fontSize: 11.5)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                        ] else ...[
                          const Text('No work item linked yet.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _isConverting ? null : _openLinkOrConvertDialog,
                            icon: _isConverting
                                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.add_task_rounded, size: 14, color: Colors.white),
                            label: Text(
                              _isConverting ? 'Processing...' : 'Link or Convert to Real Work Item',
                              style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onClose,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  child: Text(_isSaving ? 'Saving...' : 'Save Changes', style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Link or Convert Action Item to Real Work Item Dialog
// ============================================================================
class _LinkOrConvertWorkItemDialog extends ConsumerStatefulWidget {
  final SprintRetroActionItemModel item;
  final List<SprintRetroParticipantModel> participants;
  final bool isDark;
  final VoidCallback onSuccess;

  const _LinkOrConvertWorkItemDialog({
    required this.item,
    required this.participants,
    required this.isDark,
    required this.onSuccess,
  });

  @override
  ConsumerState<_LinkOrConvertWorkItemDialog> createState() => _LinkOrConvertWorkItemDialogState();
}

class _LinkOrConvertWorkItemDialogState extends ConsumerState<_LinkOrConvertWorkItemDialog> {
  int _tabIndex = 0; // 0: Search & Link, 1: Convert to New
  bool _isLoadingItems = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Tab 0: Search & Link
  List<WorkItemModel> _loadedItems = [];
  String _searchQuery = '';
  String _typeFilter = 'ALL';
  String? _selectedWorkItemId;
  String? _selectedWorkItemKey;
  final TextEditingController _searchCtrl = TextEditingController();

  // Tab 1: Convert to New
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late String _priority;
  String _workType = 'TASK';
  String? _selectedOwnerId;

  @override
  void initState() {
    super.initState();
    _selectedWorkItemId = widget.item.linkedWorkItemId;
    _selectedWorkItemKey = widget.item.linkedWorkItemKey;
    _titleCtrl = TextEditingController(text: widget.item.title);
    _descCtrl = TextEditingController(text: widget.item.description ?? '');
    _priority = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'].contains(widget.item.priority) ? widget.item.priority : 'HIGH';
    _selectedOwnerId = widget.item.ownerId;
    _fetchExistingWorkItems();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchExistingWorkItems() async {
    setState(() {
      _isLoadingItems = true;
      _errorMessage = null;
    });
    try {
      final api = ref.read(workApiServiceProvider);
      final res = await api.getItemsPaged(pageSize: 100);
      if (res['items'] is List<WorkItemModel>) {
        _loadedItems = res['items'] as List<WorkItemModel>;
      } else if (res['items'] is List) {
        _loadedItems = (res['items'] as List).map((i) => i is WorkItemModel ? i : WorkItemModel.fromJson(i as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      _errorMessage = 'Could not load existing work items: $e';
    } finally {
      if (mounted) setState(() => _isLoadingItems = false);
    }
  }

  List<WorkItemModel> get _filteredItems {
    return _loadedItems.where((w) {
      if (_typeFilter != 'ALL' && w.workType.toUpperCase() != _typeFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchKey = w.itemNumber.toLowerCase().contains(q);
        final matchTitle = w.title.toLowerCase().contains(q);
        final matchType = w.workType.toLowerCase().contains(q);
        if (!matchKey && !matchTitle && !matchType) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _handleLinkSelected() async {
    if (_selectedWorkItemId == null) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final notifier = ref.read(workSprintRetroProvider.notifier);
      final success = await notifier.linkActionItemToWorkItem(widget.item.id, workItemId: _selectedWorkItemId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Linked ${widget.item.itemKey} to ${_selectedWorkItemKey ?? "Work Item"} successfully!')),
        );
        widget.onSuccess();
        Navigator.of(context).pop();
      } else if (mounted) {
        setState(() => _errorMessage = 'Failed to link work item. Please try again.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error linking work item: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleUnlink() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final notifier = ref.read(workSprintRetroProvider.notifier);
      final success = await notifier.linkActionItemToWorkItem(widget.item.id, workItemId: null);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unlinked work item from ${widget.item.itemKey}')),
        );
        widget.onSuccess();
        Navigator.of(context).pop();
      } else if (mounted) {
        setState(() => _errorMessage = 'Failed to unlink work item.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error unlinking work item: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleConvertNew() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Title cannot be empty');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final notifier = ref.read(workSprintRetroProvider.notifier);
      final success = await notifier.convertActionItemToWorkItem(
        widget.item.id,
        title: title,
        description: _descCtrl.text.trim(),
        ownerId: _selectedOwnerId,
        priority: _priority,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Converted ${widget.item.itemKey} to Real Work Item successfully!')),
        );
        widget.onSuccess();
        Navigator.of(context).pop();
      } else if (mounted) {
        setState(() => _errorMessage = 'Failed to convert action item to real work item.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error converting action item: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'STORY':
        return const Color(0xFF3B82F6);
      case 'BUG':
        return const Color(0xFFEF4444);
      case 'ISSUE':
        return const Color(0xFFF59E0B);
      case 'EPIC':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF6366F1); // TASK
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final filtered = _filteredItems;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hub_rounded, size: 20, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Link or Convert to Real Work Item',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.item.itemKey} • ${widget.item.title}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  splashRadius: 18,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _tabIndex = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _tabIndex == 0
                              ? const Color(0xFF2563EB)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 15,
                              color: _tabIndex == 0 ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Search & Link Existing Item',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _tabIndex == 0 ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _tabIndex = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _tabIndex == 1
                              ? const Color(0xFF2563EB)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_task_rounded,
                              size: 15,
                              color: _tabIndex == 1 ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Convert to New Work Item',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _tabIndex == 1 ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              ),

            // Tab Content
            Expanded(
              child: _tabIndex == 0
                  ? _buildSearchAndLinkTab(isDark, filtered)
                  : _buildConvertNewTab(isDark),
            ),

            const SizedBox(height: 14),
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_tabIndex == 0 && widget.item.linkedWorkItemId != null)
                  TextButton.icon(
                    onPressed: _isSubmitting ? null : _handleUnlink,
                    icon: const Icon(Icons.link_off_rounded, size: 15, color: Color(0xFFEF4444)),
                    label: const Text('Unlink Work Item', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    if (_tabIndex == 0)
                      ElevatedButton.icon(
                        onPressed: (_isSubmitting || _selectedWorkItemId == null) ? null : _handleLinkSelected,
                        icon: _isSubmitting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.link_rounded, size: 15, color: Colors.white),
                        label: Text(_isSubmitting ? 'Linking...' : 'Link to Selected Item', style: const TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _handleConvertNew,
                        icon: _isSubmitting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.add_task_rounded, size: 15, color: Colors.white),
                        label: Text(_isSubmitting ? 'Creating...' : 'Create & Link Real Item', style: const TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndLinkTab(bool isDark, List<WorkItemModel> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
          decoration: InputDecoration(
            hintText: 'Search by ID (e.g. TK-1001, ST-101) or title...',
            hintStyle: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 10),

        // Type filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['ALL', 'STORY', 'TASK', 'BUG', 'ISSUE'].map((t) {
              final isSel = _typeFilter == t;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(t, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.w500, color: isSel ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                  selected: isSel,
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _typeFilter = t),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // Items list container
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
            ),
            child: _isLoadingItems
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : items.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty ? 'No work items match "$_searchQuery"' : 'No work items found',
                          style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (ctx, idx) {
                          final w = items[idx];
                          final isSelected = _selectedWorkItemId == w.id;
                          final color = _getTypeColor(w.workType);

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedWorkItemId = w.id;
                                _selectedWorkItemKey = w.itemNumber;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                                    : (isDark ? const Color(0xFF13182C) : Colors.white),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : (isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Radio<String>(
                                    value: w.id,
                                    groupValue: _selectedWorkItemId,
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedWorkItemId = val;
                                        _selectedWorkItemKey = w.itemNumber;
                                      });
                                    },
                                    activeColor: const Color(0xFF2563EB),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      w.workType.toUpperCase(),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    w.itemNumber,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      w.title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF64748B).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      w.status,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildConvertNewTab(bool isDark) {
    final validParticipants = widget.participants;

    return ListView(
      children: [
        const Text('Work Item Title', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        TextField(
          controller: _titleCtrl,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
        const SizedBox(height: 12),

        const Text('Description', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Work Type', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _workType,
                    items: ['TASK', 'STORY', 'BUG', 'ISSUE'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _workType = v);
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Priority', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _priority,
                    items: ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _priority = v);
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        const Text('Assignee / Owner', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        DropdownButtonFormField<String?>(
          initialValue: validParticipants.any((p) => p.userId == _selectedOwnerId) ? _selectedOwnerId : null,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
            ...validParticipants.map((p) => DropdownMenuItem<String?>(
                  value: p.userId,
                  child: Text('${p.name} (${p.role})'),
                )),
          ],
          onChanged: (v) => setState(() => _selectedOwnerId = v),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }
}

