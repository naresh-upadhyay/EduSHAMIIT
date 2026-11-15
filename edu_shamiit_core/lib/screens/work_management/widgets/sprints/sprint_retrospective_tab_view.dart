import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';
import '../../utils/work_sprint_date_helper.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workSprintRetroProvider.notifier).init(widget.sprintId, teamName: widget.selectedTeam);
    });
  }

  @override
  void didUpdateWidget(covariant SprintRetrospectiveTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sprintId != widget.sprintId || oldWidget.selectedTeam != widget.selectedTeam) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(workSprintRetroProvider.notifier).init(widget.sprintId, teamName: widget.selectedTeam);
      });
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
                child: _buildActionItemDrawer(retroState.selectedActionItem!, isDark),
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
                  OutlinedButton.icon(
                    onPressed: () => _openStartOrReopenSessionDialog(ws),
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: Text(
                      isCompleted ? 'Start New Retrospective' : 'Reopen Retrospective',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
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
                      PopupMenuItem(
                        value: isCompleted ? 'REOPEN' : 'CLOSE',
                        child: Text(isCompleted ? 'Reopen Session' : 'Close Session'),
                      ),
                      const PopupMenuItem(
                        value: 'ADD_PARTICIPANT',
                        child: Text('Invite Participant'),
                      ),
                      const PopupMenuItem(
                        value: 'EDIT_SUMMARY',
                        child: Text('Edit Summary'),
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
                retro.sessionDateFormatted.isNotEmpty && !retro.sessionDateFormatted.contains('2025')
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
                '${retro.participantCount} / ${retro.totalParticipants} (${retro.participationPct}%)',
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
        final colWidth = isWide ? (constraints.maxWidth - 28) / 3 : double.infinity;

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

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              colWentWell,
              const SizedBox(width: 14),
              colDidNotGoWell,
              const SizedBox(width: 14),
              colShouldImprove,
            ],
          );
        } else {
          return Column(
            children: [
              colWentWell,
              const SizedBox(height: 14),
              colDidNotGoWell,
              const SizedBox(height: 14),
              colShouldImprove,
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
    final filterKw = widget.filterKeyword?.trim().toLowerCase() ?? '';
    final filteredEntries = entries.where((e) {
      if (filterKw.isEmpty) return true;
      return e.content.toLowerCase().contains(filterKw) ||
             e.authorName.toLowerCase().contains(filterKw);
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
        cursor: SystemMouseCursors.grab,
        child: _buildEntryCard(entry, cardIcon, themeColor, isDark),
      ),
    );
  }

  Widget _buildEntryCard(
    SprintRetroEntryItemModel entry,
    IconData cardIcon,
    Color themeColor,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.drag_indicator_rounded, size: 14, color: isDark ? Colors.white30 : const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Icon(cardIcon, size: 14, color: themeColor),
              const SizedBox(width: 7),
              Expanded(
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
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Author Avatar
              _buildAvatar(entry.authorAvatar, entry.authorName, radius: 10),
              const SizedBox(width: 6),
              Text(
                entry.authorName,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              // Upvotes
              InkWell(
                onTap: () => ref.read(workSprintRetroProvider.notifier).voteEntry(entry.id),
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    Icon(Icons.thumb_up_alt_outlined, size: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Text(
                      '${entry.votes}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Comments
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                  const SizedBox(width: 3),
                  Text(
                    '${entry.commentsCount}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
                        item.dueDate.isNotEmpty ? item.dueDate : 'Jan 20, 2025',
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
                          if (item.linkedWorkItemId == null)
                            const PopupMenuItem(value: 'CONVERT', child: Text('Convert to Work Item')),
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
            o.dateRange.isNotEmpty && !o.dateRange.contains('2025')
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
                  'Participation (${retro.totalParticipants})',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: participants.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: '${p.name} (${p.role})',
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
  Widget _buildActionItemDrawer(SprintRetroActionItemModel item, bool isDark) {
    final titleCtrl = TextEditingController(text: item.title);
    final descCtrl = TextEditingController(text: item.description ?? '');
    String currentPriority = item.priority;
    String currentStatus = item.status;
    int progress = item.progressPercentage;

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
                    item.itemKey,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => ref.read(workSprintRetroProvider.notifier).closeActionDrawer(),
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
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Description', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  TextField(
                    controller: descCtrl,
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
                              initialValue: currentPriority,
                              items: ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                              onChanged: (v) => currentPriority = v ?? currentPriority,
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
                              initialValue: currentStatus,
                              items: ['OPEN', 'PLANNED', 'IN_PROGRESS', 'COMPLETED'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => currentStatus = v ?? currentStatus,
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
                      Text('$progress%', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    ],
                  ),
                  Slider(
                    value: progress.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    onChanged: (v) => setState(() => progress = v.toInt()),
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
                        const Text('Linked Work Item', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        if (item.linkedWorkItemKey != null)
                          Row(
                            children: [
                              const Icon(Icons.link_rounded, size: 14, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              Text(item.linkedWorkItemKey!, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                            ],
                          )
                        else ...[
                          const Text('No work item linked yet.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          const SizedBox(height: 6),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final notifier = ref.read(workSprintRetroProvider.notifier);
                              await notifier.convertActionItemToWorkItem(item.id, title: titleCtrl.text);
                            },
                            icon: const Icon(Icons.add_task_rounded, size: 13, color: Colors.white),
                            label: const Text('Convert to Real Work Item', style: TextStyle(fontSize: 11, color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
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
                  onPressed: () => ref.read(workSprintRetroProvider.notifier).closeActionDrawer(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final notifier = ref.read(workSprintRetroProvider.notifier);
                    await notifier.updateActionItem(item.id, {
                      'title': titleCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'priority': currentPriority,
                      'status': currentStatus,
                      'progress': progress,
                    });
                    notifier.closeActionDrawer();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // Other Internal Tabs (Action Items Full Tab, Notes & Summary, Feedback, History)
  // ============================================================================
  Widget _buildActionItemsFullTab(SprintRetroWorkspaceModel ws, bool isDark) {
    return _buildActionItemsTableCard(ws, isDark);
  }

  Widget _buildNotesAndSummaryTab(SprintRetroWorkspaceModel ws, bool isDark) {
    final retro = ws.retrospective;
    final summaryCtrl = TextEditingController(text: retro.summary);

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
                  await notifier.updateSession({'summary': summaryCtrl.text.trim()});
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Retrospective summary saved successfully!')),
                    );
                  }
                },
                icon: const Icon(Icons.save_rounded, size: 14, color: Colors.white),
                label: const Text('Save Summary', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: summaryCtrl,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Enter executive retrospective summary...',
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
          ...ws.feedback.map((f) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(f.category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        const SizedBox(width: 8),
                        Row(
                          children: List.generate(
                            5,
                            (idx) => Icon(
                              idx < f.rating ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 14,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(f.userName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                    if (f.content != null && f.content!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(f.content!, style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              )),
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
          const Text('Retrospective Session History & Milestone Audit', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          ...ws.history.map((h) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                title: Text(h.milestone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('${h.description} • by ${h.actorName}', style: const TextStyle(fontSize: 11.5)),
                trailing: Text(h.createdAt, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              )),
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        title: Text('Add to "$title"', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Note / Feedback *', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            TextField(
              controller: contentCtrl,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter specific observation or takeaway...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final text = contentCtrl.text.trim();
              if (text.isNotEmpty) {
                final nav = Navigator.of(ctx);
                final notifier = ref.read(workSprintRetroProvider.notifier);
                await notifier.addEntry(category: categoryKey, content: text);
                nav.pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Add Entry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openAddActionItemDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'MEDIUM';
    String? ownerId;
    final users = ref.read(workSprintRetroProvider).assignableUsers;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          title: const Text('Add Retrospective Action Item', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Title *', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Conduct detailed requirement grooming session',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Description', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Action details and expected outcomes...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Owner', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: ownerId,
                          isExpanded: true,
                          hint: const Text('Select Owner', style: TextStyle(fontSize: 12)),
                          items: users.map((u) => DropdownMenuItem(value: u.userId, child: Text(u.fullName, style: const TextStyle(fontSize: 12)))).toList(),
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
                        const Text('Priority', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isNotEmpty) {
                  final nav = Navigator.of(ctx);
                  final notifier = ref.read(workSprintRetroProvider.notifier);
                  await notifier.addActionItem(
                    title: title,
                    description: descCtrl.text.trim(),
                    ownerId: ownerId,
                    priority: priority,
                    dueDate: 'Jan 24, 2025',
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
    int duration = retro.durationMinutes;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        title: const Text('Edit Retrospective Session', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Title', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            TextField(controller: titleCtrl, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
            const SizedBox(height: 10),
            const Text('Sprint Goal', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            TextField(controller: goalCtrl, maxLines: 2, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
            const SizedBox(height: 10),
            const Text('Duration (Minutes)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            TextFormField(
              initialValue: duration.toString(),
              keyboardType: TextInputType.number,
              onChanged: (v) => duration = int.tryParse(v) ?? 60,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final notifier = ref.read(workSprintRetroProvider.notifier);
              await notifier.updateSession({
                'title': titleCtrl.text.trim(),
                'sprint_goal': goalCtrl.text.trim(),
                'duration_minutes': duration,
              });
              nav.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openStartOrReopenSessionDialog(SprintRetroWorkspaceModel ws) {
    final isCompleted = ws.retrospective.status == 'COMPLETED';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCompleted ? 'Start New Retrospective?' : 'Reopen Retrospective?'),
        content: Text(isCompleted
            ? 'This will set the session status to IN_PROGRESS so team members can submit new feedback and action items.'
            : 'This will reopen the session for further collaboration.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final notifier = ref.read(workSprintRetroProvider.notifier);
              if (isCompleted) {
                await notifier.startSession();
              } else {
                await notifier.reopenSession();
              }
              nav.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
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

  void _handleActionItemMenu(String action, SprintRetroActionItemModel item) {
    final notifier = ref.read(workSprintRetroProvider.notifier);
    if (action == 'VIEW') {
      notifier.openActionDrawer(item);
    } else if (action == 'CONVERT') {
      notifier.convertActionItemToWorkItem(item.id, title: item.title);
    } else if (action == 'DELETE') {
      notifier.deleteActionItem(item.id);
    }
  }

  void _handleHeaderMenuAction(String action, SprintRetroWorkspaceModel ws) {
    final notifier = ref.read(workSprintRetroProvider.notifier);
    if (action == 'CLOSE') {
      notifier.closeSession(summary: ws.retrospective.summary);
    } else if (action == 'REOPEN') {
      notifier.reopenSession();
    } else if (action == 'EDIT_SUMMARY') {
      notifier.setActiveTab('Notes & Summary');
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
