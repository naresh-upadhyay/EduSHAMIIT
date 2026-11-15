import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';

class SprintTeamTabView extends ConsumerStatefulWidget {
  final String sprintId;
  final String? selectedTeam;

  const SprintTeamTabView({
    super.key,
    required this.sprintId,
    this.selectedTeam,
  });

  @override
  ConsumerState<SprintTeamTabView> createState() => _SprintTeamTabViewState();
}

class _SprintTeamTabViewState extends ConsumerState<SprintTeamTabView> {
  final TextEditingController _searchController = TextEditingController();
  List<WorkAssigneeModel> _assignableUsers = const [];

  @override
  void initState() {
    super.initState();
    _loadAssignableUsers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workSprintTeamProvider.notifier).init(widget.sprintId);
    });
  }

  @override
  void didUpdateWidget(covariant SprintTeamTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sprintId != widget.sprintId || oldWidget.selectedTeam != widget.selectedTeam) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(workSprintTeamProvider.notifier).init(widget.sprintId);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignableUsers() async {
    try {
      final api = ref.read(workApiServiceProvider);
      final users = await api.getAssignableUsers(limit: 60);
      if (mounted && users.isNotEmpty) {
        setState(() => _assignableUsers = users);
      }
    } catch (_) {}
  }

  IconData _getIconData(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'school':
        return Icons.school_outlined;
      case 'assignment':
      case 'fact_check':
        return Icons.assignment_turned_in_outlined;
      case 'computer':
      case 'desktop_windows':
        return Icons.computer_outlined;
      case 'settings':
      case 'build':
      case 'apartment':
        return Icons.settings_suggest_outlined;
      case 'menu_book':
        return Icons.menu_book_outlined;
      case 'layers':
      default:
        return Icons.layers_outlined;
    }
  }

  Widget _buildAvatar(String? url, String name, {double size = 28}) {
    final initials = name.trim().split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join();
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0xFFE2E8F0),
        child: ClipOval(
          child: Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackAvatar(initials, size),
          ),
        ),
      );
    }
    return _buildFallbackAvatar(initials, size);
  }

  Widget _buildFallbackAvatar(String initials, double size) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFE0E7FF),
      child: Text(
        initials.isNotEmpty ? initials : 'U',
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF3730A3),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teamState = ref.watch(workSprintTeamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Top 7 Metric KPI Cards Row
        _buildTopKpiCards(teamState.kpis, isDark),
        const SizedBox(height: 20),

        // 2. Main Two-Column Layout (Left Directory Table + Right Team Drawer)
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1150;
            final isDrawerOpen = teamState.isDrawerOpen && teamState.selectedTeamDetail != null;

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Teams Directory Table
                  Expanded(
                    flex: isDrawerOpen ? 65 : 100,
                    child: _buildTeamsDirectoryCard(teamState, isDark),
                  ),
                  if (isDrawerOpen) ...[
                    const SizedBox(width: 18),
                    // Right: Selected Team Details Panel / Drawer
                    Expanded(
                      flex: 35,
                      child: _buildSelectedTeamDrawer(teamState, isDark),
                    ),
                  ],
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTeamsDirectoryCard(teamState, isDark),
                  if (isDrawerOpen) ...[
                    const SizedBox(height: 20),
                    _buildSelectedTeamDrawer(teamState, isDark),
                  ],
                ],
              );
            }
          },
        ),
      ],
    );
  }

  // ============================================================================
  // 1. TOP 7 KPI METRIC CARDS ROW
  // ============================================================================
  Widget _buildTopKpiCards(TeamKpisModel kpis, bool isDark) {
    final bgColor = isDark ? const Color(0xFF13182C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF232D4B) : const Color(0xFFE2E8F0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 1200
            ? (constraints.maxWidth - (6 * 12)) / 7
            : constraints.maxWidth >= 768
                ? (constraints.maxWidth - (2 * 12)) / 3
                : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard(
              title: 'Total Teams',
              value: '${kpis.totalTeams}',
              icon: Icons.groups_outlined,
              iconColor: const Color(0xFF2563EB),
              iconBgColor: const Color(0xFFEFF6FF),
              width: cardWidth,
              bgColor: bgColor,
              borderColor: borderColor,
              isDark: isDark,
            ),
            _buildMetricCard(
              title: 'Total Members',
              value: '${kpis.totalMembers}',
              icon: Icons.person_add_alt_1_outlined,
              iconColor: const Color(0xFF2563EB),
              iconBgColor: const Color(0xFFEFF6FF),
              width: cardWidth,
              bgColor: bgColor,
              borderColor: borderColor,
              isDark: isDark,
            ),
            _buildMetricCard(
              title: 'Total Capacity',
              value: '${kpis.totalCapacityHours.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} h',
              icon: Icons.layers_outlined,
              iconColor: const Color(0xFF2563EB),
              iconBgColor: const Color(0xFFEFF6FF),
              width: cardWidth,
              bgColor: bgColor,
              borderColor: borderColor,
              isDark: isDark,
            ),
            _buildMetricCard(
              title: 'Allocated Work',
              value: '${kpis.allocatedWorkHours.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} h',
              icon: Icons.schedule_rounded,
              iconColor: const Color(0xFF2563EB),
              iconBgColor: const Color(0xFFEFF6FF),
              width: cardWidth,
              bgColor: bgColor,
              borderColor: borderColor,
              isDark: isDark,
            ),
            _buildUtilizationGaugeCard(
              title: 'Capacity Utilization',
              pct: kpis.capacityUtilizationPct,
              width: cardWidth,
              bgColor: bgColor,
              borderColor: borderColor,
              isDark: isDark,
            ),
            _buildMetricCard(
              title: 'Active Teams',
              value: '${kpis.activeTeams}',
              icon: Icons.sync_rounded,
              iconColor: const Color(0xFF10B981),
              iconBgColor: const Color(0xFFDCFCE7),
              width: cardWidth,
              bgColor: bgColor,
              borderColor: borderColor,
              isDark: isDark,
            ),
            _buildMetricCard(
              title: 'Inactive Teams',
              value: '${kpis.inactiveTeams}',
              icon: Icons.pause_circle_outline_rounded,
              iconColor: const Color(0xFF8B5CF6),
              iconBgColor: const Color(0xFFF3E8FF),
              width: cardWidth,
              bgColor: bgColor,
              borderColor: borderColor,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required double width,
    required Color bgColor,
    required Color borderColor,
    required bool isDark,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? iconColor.withValues(alpha: 0.15) : iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilizationGaugeCard({
    required String title,
    required double pct,
    required double width,
    required Color bgColor,
    required Color borderColor,
    required bool isDark,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (pct / 100.0).clamp(0.0, 1.0),
                  strokeWidth: 3.5,
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
                const Icon(
                  Icons.trending_up_rounded,
                  size: 16,
                  color: Color(0xFF10B981),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 2. LEFT: TEAMS DIRECTORY CARD & TABLE
  // ============================================================================
  Widget _buildTeamsDirectoryCard(WorkSprintTeamState state, bool isDark) {
    final bgColor = isDark ? const Color(0xFF13182C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF232D4B) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Teams (${state.totalCount})',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                // Create Team Button
                ElevatedButton.icon(
                  onPressed: () => _openCreateTeamDialog(isDark),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text(
                    'Create Team',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                // Import Button
                OutlinedButton.icon(
                  onPressed: () => _openImportDialog(isDark),
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: const Text('Import', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                // Export Button
                OutlinedButton.icon(
                  onPressed: () async {
                    final csv = await ref.read(workSprintTeamProvider.notifier).exportCsv();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(csv != null ? 'Teams directory exported successfully' : 'Failed to export CSV'),
                          backgroundColor: const Color(0xFF2563EB),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: const Text('Export', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 4),
                // More options menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 20, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                  onSelected: (val) {
                    if (val == 'select_all') {
                      ref.read(workSprintTeamProvider.notifier).toggleAllSelection(true);
                    } else if (val == 'deselect_all') {
                      ref.read(workSprintTeamProvider.notifier).toggleAllSelection(false);
                    } else if (val == 'refresh') {
                      ref.read(workSprintTeamProvider.notifier).loadTeams();
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'select_all', child: Text('Select All')),
                    const PopupMenuItem(value: 'deselect_all', child: Text('Deselect All')),
                    const PopupMenuItem(value: 'refresh', child: Text('Refresh Directory')),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Search & Filters Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Search Input
                SizedBox(
                  width: 300,
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (q) => ref.read(workSprintTeamProvider.notifier).setSearchQuery(q),
                    decoration: InputDecoration(
                      hintText: 'Search teams by name, owner or department...',
                      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
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
                        borderSide: const BorderSide(color: Color(0xFF2563EB)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),

                // Status Filter Dropdown
                _buildFilterDropdown(
                  label: 'Status',
                  value: state.statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('Status: All')),
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Status: Active')),
                    DropdownMenuItem(value: 'INACTIVE', child: Text('Status: Inactive')),
                  ],
                  onChanged: (v) => ref.read(workSprintTeamProvider.notifier).setStatusFilter(v ?? 'ALL'),
                  isDark: isDark,
                  borderColor: borderColor,
                ),

                // Department Filter Dropdown
                _buildFilterDropdown(
                  label: 'Department',
                  value: state.departmentFilter,
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('Department: All')),
                    DropdownMenuItem(value: 'IT & Digitalization', child: Text('IT & Digitalization')),
                    DropdownMenuItem(value: 'Academics', child: Text('Academics')),
                    DropdownMenuItem(value: 'Examinations', child: Text('Examinations')),
                    DropdownMenuItem(value: 'IT Operations', child: Text('IT Operations')),
                    DropdownMenuItem(value: 'Administration', child: Text('Administration')),
                    DropdownMenuItem(value: 'Library', child: Text('Library')),
                  ],
                  onChanged: (v) => ref.read(workSprintTeamProvider.notifier).setDepartmentFilter(v ?? 'ALL'),
                  isDark: isDark,
                  borderColor: borderColor,
                ),

                // Sort By Dropdown
                _buildFilterDropdown(
                  label: 'Sort By',
                  value: state.sortBy,
                  items: const [
                    DropdownMenuItem(value: 'NAME_ASC', child: Text('Sort By: Name (A-Z)')),
                    DropdownMenuItem(value: 'NAME_DESC', child: Text('Sort By: Name (Z-A)')),
                    DropdownMenuItem(value: 'CAPACITY_DESC', child: Text('Sort By: Capacity (High-Low)')),
                    DropdownMenuItem(value: 'UTIL_DESC', child: Text('Sort By: Utilization (%)')),
                    DropdownMenuItem(value: 'MEMBERS_DESC', child: Text('Sort By: Members Count')),
                  ],
                  onChanged: (v) => ref.read(workSprintTeamProvider.notifier).setSortBy(v ?? 'NAME_ASC'),
                  isDark: isDark,
                  borderColor: borderColor,
                ),

                // Table / Grid View Toggle
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.table_chart_outlined,
                          size: 18,
                          color: !state.isGridView ? const Color(0xFF2563EB) : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                        ),
                        onPressed: () => ref.read(workSprintTeamProvider.notifier).toggleViewMode(false),
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.grid_view_rounded,
                          size: 18,
                          color: state.isGridView ? const Color(0xFF2563EB) : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                        ),
                        onPressed: () => ref.read(workSprintTeamProvider.notifier).toggleViewMode(true),
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Table or Grid View
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.teams.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.groups_outlined, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    const SizedBox(height: 12),
                    Text(
                      'No teams found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try adjusting your search or filters, or create a new team.',
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            )
          else if (state.isGridView)
            _buildTeamsGridView(state, isDark)
          else
            _buildTeamsTableView(state, isDark),

          const Divider(height: 1),

          // Server-Side Pagination Footer
          _buildPaginationFooter(state, isDark),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    required Color borderColor,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.any((i) => i.value == value) ? value : items.first.value,
          items: items,
          onChanged: onChanged,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
        ),
      ),
    );
  }

  // Table View implementation
  Widget _buildTeamsTableView(WorkSprintTeamState state, bool isDark) {
    final allSelected = state.teams.isNotEmpty && state.teams.every((t) => state.selectedTeamIds.contains(t.id));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 880,
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Checkbox(
                      value: allSelected,
                      onChanged: (v) => ref.read(workSprintTeamProvider.notifier).toggleAllSelection(v == true),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    flex: 30,
                    child: Text('Team Name ⇅', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ),
                  const Expanded(
                    flex: 18,
                    child: Text('Department', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ),
                  const Expanded(
                    flex: 14,
                    child: Text('Members', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ),
                  const Expanded(
                    flex: 12,
                    child: Text('Capacity (h)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ),
                  const Expanded(
                    flex: 14,
                    child: Text('Utilization', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ),
                  const Expanded(
                    flex: 10,
                    child: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ),
                  const SizedBox(
                    width: 80,
                    child: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.teams.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final team = state.teams[index];
                final isSelected = team.id == state.selectedTeamId;
                final isChecked = state.selectedTeamIds.contains(team.id);

                return InkWell(
                  onTap: () => ref.read(workSprintTeamProvider.notifier).selectTeam(team.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    color: isSelected
                        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
                        : (index % 2 == 1
                            ? (isDark ? const Color(0xFF161D33) : const Color(0xFFFAFAFA))
                            : Colors.transparent),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Checkbox(
                            value: isChecked,
                            onChanged: (_) => ref.read(workSprintTeamProvider.notifier).toggleTeamSelection(team.id),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Team Name & Icon
                        Expanded(
                          flex: 30,
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(_getIconData(team.icon), size: 18, color: const Color(0xFF2563EB)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      team.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      team.description.isNotEmpty ? team.description : 'Team ID: ${team.teamKey}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Department
                        Expanded(
                          flex: 18,
                          child: Text(
                            team.department,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            ),
                          ),
                        ),

                        // Members Avatar Stack
                        Expanded(
                          flex: 14,
                          child: _buildAvatarStack(team.members, team.memberCount),
                        ),

                        // Capacity (h)
                        Expanded(
                          flex: 12,
                          child: Text(
                            '${team.capacityHours.toInt()} h',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),

                        // Utilization
                        Expanded(
                          flex: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${team.utilizationPct.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: (team.utilizationPct / 100.0).clamp(0.0, 1.0),
                                  minHeight: 4,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Status Badge
                        Expanded(
                          flex: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                        // Actions
                        SizedBox(
                          width: 80,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              InkWell(
                                onTap: () => _openEditTeamDialog(team, isDark),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.all(3),
                                  child: Icon(Icons.edit_outlined, size: 15, color: Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _openDuplicateTeamDialog(team, isDark),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.all(3),
                                  child: Icon(Icons.copy_outlined, size: 15, color: Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _confirmDeleteTeam(team, isDark),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.all(3),
                                  child: Icon(Icons.delete_outline, size: 15, color: Color(0xFFEF4444)),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  // Grid View implementation
  Widget _buildTeamsGridView(WorkSprintTeamState state, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 900 ? 3 : (constraints.maxWidth >= 600 ? 2 : 1);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.teams.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 220,
            ),
            itemBuilder: (context, index) {
              final team = state.teams[index];
              final isSelected = team.id == state.selectedTeamId;

              return InkWell(
                onTap: () => ref.read(workSprintTeamProvider.notifier).selectTeam(team.id),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_getIconData(team.icon), size: 20, color: const Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  team.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  team.department,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        team.description,
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Capacity: ${team.capacityHours.toInt()} h', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('Util: ${team.utilizationPct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (team.utilizationPct / 100.0).clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildAvatarStack(team.members, team.memberCount),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                onPressed: () => _openEditTeamDialog(team, isDark),
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                padding: EdgeInsets.zero,
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_outlined, size: 16),
                                onPressed: () => _openDuplicateTeamDialog(team, isDark),
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAvatarStack(List<TeamMemberItemModel> members, int totalCount) {
    final showCount = members.take(3).toList();
    final remaining = totalCount > 3 ? totalCount - 3 : 0;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
        for (int i = 0; i < showCount.length; i++) ...[
          Transform.translate(
            offset: Offset(-i * 8.0, 0),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: _buildAvatar(showCount[i].avatarUrl, showCount[i].name, size: 24),
            ),
          ),
        ],
        if (remaining > 0) ...[
          Transform.translate(
            offset: Offset(-showCount.length * 8.0, 0),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Text(
                  '+$remaining',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                ),
              ),
            ),
          ),
        ],
      ],
    ));
  }

  // Pagination Footer
  Widget _buildPaginationFooter(WorkSprintTeamState state, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'Showing 1-${state.teams.length} of ${state.totalCount} teams',
            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          const Spacer(),
          // Page Controls
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            onPressed: state.currentPage > 1
                ? () => ref.read(workSprintTeamProvider.notifier).setPage(state.currentPage - 1)
                : null,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${state.currentPage}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            onPressed: (state.currentPage * state.rowsPerPage) < state.totalCount
                ? () => ref.read(workSprintTeamProvider.notifier).setPage(state.currentPage + 1)
                : null,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 16),
          // Rows per page
          Text(
            'Rows per page: ',
            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: state.rowsPerPage,
              items: const [
                DropdownMenuItem(value: 5, child: Text('5')),
                DropdownMenuItem(value: 10, child: Text('10')),
                DropdownMenuItem(value: 20, child: Text('20')),
                DropdownMenuItem(value: 50, child: Text('50')),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(workSprintTeamProvider.notifier).setRowsPerPage(v);
                }
              },
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 3. RIGHT: SELECTED TEAM DETAILS PANEL / DRAWER
  // ============================================================================
  Widget _buildSelectedTeamDrawer(WorkSprintTeamState state, bool isDark) {
    final team = state.selectedTeamDetail!;
    final bgColor = isDark ? const Color(0xFF13182C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF232D4B) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drawer Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_getIconData(team.icon), size: 24, color: const Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  team.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            team.description.isNotEmpty
                                ? team.description
                                : 'Student portal, academic systems and digital campus solutions.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Actions: More and Close
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 18, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                      onSelected: (val) {
                        if (val == 'edit') {
                          final dirTeam = state.teams.firstWhere((t) => t.id == team.id);
                          _openEditTeamDialog(dirTeam, isDark);
                        } else if (val == 'add_member') {
                          _openAddMemberDialog(team.id, isDark);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit Team')),
                        const PopupMenuItem(value: 'add_member', child: Text('Add Member')),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      onPressed: () => ref.read(workSprintTeamProvider.notifier).closeDrawer(),
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Drawer Sub-Tabs Bar: Overview | Members (7) | Capacity | Work Items | Settings
          _buildDrawerTabsBar(state.activeDrawerTab, team.members.length, isDark),
          const Divider(height: 1),

          // Drawer Sub-Tab Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildDrawerTabContent(team, state.activeDrawerTab, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTabsBar(String activeTab, int memberCount, bool isDark) {
    final tabs = [
      'Overview',
      'Members ($memberCount)',
      'Capacity',
      'Work Items',
      'Settings',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = activeTab == tab || (tab.startsWith('Members') && activeTab == 'Members');
          return InkWell(
            onTap: () => ref.read(workSprintTeamProvider.notifier).setDrawerTab(tab.startsWith('Members') ? 'Members' : tab),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  fontSize: 12,
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
    );
  }

  Widget _buildDrawerTabContent(TeamDetailModel team, String tab, bool isDark) {
    switch (tab) {
      case 'Members':
        return _buildDrawerMembersTab(team, isDark);
      case 'Capacity':
        return _buildDrawerCapacityTab(team, isDark);
      case 'Work Items':
        return _buildDrawerWorkItemsTab(team, isDark);
      case 'Settings':
        return _buildDrawerSettingsTab(team, isDark);
      case 'Overview':
      default:
        return _buildDrawerOverviewTab(team, isDark);
    }
  }

  // ============================================================================
  // OVERVIEW SUB-TAB
  // ============================================================================
  Widget _buildDrawerOverviewTab(TeamDetailModel team, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Grid of Metadata Details
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaItem('Team Code', team.teamKey, isDark),
                  const SizedBox(height: 12),
                  _buildMetaItem('Department', team.department, isDark),
                  const SizedBox(height: 12),
                  _buildMetaItemWithAvatar('Team Lead', team.lead.name, team.lead.avatarUrl, isDark),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetaItem('Created On', 'Dec 10, 2024', isDark),
                  const SizedBox(height: 12),
                  _buildMetaItem('Last Updated', 'Jan 06, 2025', isDark),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Team Capacity (Sprint 8) Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Team Capacity (Sprint 8)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${team.capacity.totalCapacityHours.toInt()} h',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${team.capacity.utilizationPct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (team.capacity.utilizationPct / 100.0).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(
                        'Allocated Work: ${team.capacity.plannedHours.toInt()} h',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(
                        'Available Capacity: ${team.capacity.remainingHours.toInt()} h',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 3. Team Members (7) Avatar Cards Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Team Members (${team.members.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            InkWell(
              onTap: () => _openAddMemberDialog(team.id, isDark),
              child: const Text(
                '+ Add Member',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: team.members.map((m) {
              return Container(
                width: 78,
                margin: const EdgeInsets.only(right: 8),
                child: Column(
                  children: [
                    _buildAvatar(m.avatarUrl, m.name, size: 38),
                    const SizedBox(height: 6),
                    Text(
                      m.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      m.role,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        // 4. Team Tags Section
        Text(
          'Team Tags',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in team.tags) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF1E40AF)),
                ),
              ),
            ],
            InkWell(
              onTap: () => _openAddTagDialog(team, isDark),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: const Icon(Icons.add, size: 14, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 5. Team Goal (Sprint 8) Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.track_changes_rounded, size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Team Goal (Sprint 8)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      team.goal.isNotEmpty
                          ? team.goal
                          : 'Deliver student portal enhancement, examination notifications and key infrastructure fixes.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 6. Recent Activity Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            InkWell(
              onTap: () {},
              child: const Text(
                'View All',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: team.activities.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final act = team.activities[idx];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        act.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Jan 06, 2025 10:24 AM',
                        style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetaItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaItemWithAvatar(String label, String value, String? avatarUrl, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildAvatar(avatarUrl, value, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================================
  // MEMBERS SUB-TAB
  // ============================================================================
  Widget _buildDrawerMembersTab(TeamDetailModel team, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Team Members (${team.members.length})',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            ElevatedButton.icon(
              onPressed: () => _openAddMemberDialog(team.id, isDark),
              icon: const Icon(Icons.add, size: 14, color: Colors.white),
              label: const Text('Add Member', style: TextStyle(fontSize: 11, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: team.members.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, idx) {
            final m = team.members[idx];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _buildAvatar(m.avatarUrl, m.name, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              m.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            if (m.isLead) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Lead', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                              ),
                            ],
                          ],
                        ),
                        Text(m.role, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Text('${m.capacityHours.toInt()} h', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                    onPressed: () => _confirmRemoveMember(team.id, m.userId, m.name, isDark),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================================
  // CAPACITY SUB-TAB
  // ============================================================================
  Widget _buildDrawerCapacityTab(TeamDetailModel team, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Team Capacity Configuration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        const SizedBox(height: 14),
        _buildConfigRow('Sprint Capacity', '${team.capacity.totalCapacityHours.toInt()} Hours', isDark),
        _buildConfigRow('Allocated Work', '${team.capacity.plannedHours.toInt()} Hours', isDark),
        _buildConfigRow('Available Capacity', '${team.capacity.remainingHours.toInt()} Hours', isDark),
        _buildConfigRow('Working Days / Sprint', '10 Days (2 Weeks)', isDark),
        _buildConfigRow('Daily Working Hours', '8.0 Hours / Day', isDark),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => _openAdjustCapacityDialog(team, isDark),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Adjust Team Capacity', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildConfigRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  // ============================================================================
  // WORK ITEMS SUB-TAB
  // ============================================================================
  Widget _buildDrawerWorkItemsTab(TeamDetailModel team, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assigned Work Items (${team.workItems.length})',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        if (team.workItems.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('No work items assigned to this team in current sprint')),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: team.workItems.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              final wi = team.workItems[idx];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(wi.itemKey, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wi.title,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text('${wi.type} • ${wi.status}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    _buildAvatar(wi.assigneeAvatar, wi.assigneeName, size: 22),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ============================================================================
  // SETTINGS SUB-TAB
  // ============================================================================
  Widget _buildDrawerSettingsTab(TeamDetailModel team, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Team Settings & Administration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Edit Team Master Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Name, code, department, description, tags and goal', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () {
            final dirTeam = ref.read(workSprintTeamProvider).teams.firstWhere((t) => t.id == team.id);
            _openEditTeamDialog(dirTeam, isDark);
          },
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Duplicate Team Architecture', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Clone team and copy all current member mappings', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          trailing: const Icon(Icons.copy_outlined, size: 18),
          onTap: () {
            final dirTeam = ref.read(workSprintTeamProvider).teams.firstWhere((t) => t.id == team.id);
            _openDuplicateTeamDialog(dirTeam, isDark);
          },
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Archive Team', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
          subtitle: const Text('Deactivate team from future sprints and capacity allocations', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          trailing: const Icon(Icons.archive_outlined, size: 18, color: Color(0xFFEF4444)),
          onTap: () {
            final dirTeam = ref.read(workSprintTeamProvider).teams.firstWhere((t) => t.id == team.id);
            _confirmDeleteTeam(dirTeam, isDark);
          },
        ),
      ],
    );
  }

  // ============================================================================
  // INTERACTIVE DIALOGS
  // ============================================================================
  void _openCreateTeamDialog(bool isDark) {
    final nameCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final goalCtrl = TextEditingController();
    String department = 'IT & Digitalization';
    String? selectedLeadId = _assignableUsers.isNotEmpty ? _assignableUsers.first.userId : null;
    String selectedIcon = 'layers';
    double capacity = 280.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          title: const Text('Create New Team', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Team Name *', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Digital Campus Team',
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
                            const Text('Team Key (Code)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: keyCtrl,
                              decoration: InputDecoration(
                                hintText: 'e.g. DCT',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                            const Text('Department', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: department,
                              dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                              items: const [
                                DropdownMenuItem(value: 'IT & Digitalization', child: Text('IT & Digitalization')),
                                DropdownMenuItem(value: 'Academics', child: Text('Academics')),
                                DropdownMenuItem(value: 'Examinations', child: Text('Examinations')),
                                DropdownMenuItem(value: 'IT Operations', child: Text('IT Operations')),
                                DropdownMenuItem(value: 'Administration', child: Text('Administration')),
                                DropdownMenuItem(value: 'Library', child: Text('Library')),
                              ],
                              onChanged: (v) => setDialogState(() => department = v ?? 'Academics'),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Team Lead', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedLeadId,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                    items: _assignableUsers.map((u) {
                      return DropdownMenuItem(
                        value: u.userId,
                        child: Text('${u.fullName} (${u.role})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() => selectedLeadId = v),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Description', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Core focus and responsibilities...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Sprint Goal', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: goalCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Key deliverables for current sprint...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await ref.read(workSprintTeamProvider.notifier).createTeam({
                  'name': nameCtrl.text.trim(),
                  'team_key': keyCtrl.text.trim(),
                  'department': department,
                  'lead_id': selectedLeadId,
                  'description': descCtrl.text.trim(),
                  'goal': goalCtrl.text.trim(),
                  'capacity_hours': capacity,
                  'icon': selectedIcon,
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Create Team', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditTeamDialog(TeamDirectoryItemModel team, bool isDark) {
    final nameCtrl = TextEditingController(text: team.name);
    final keyCtrl = TextEditingController(text: team.teamKey);
    final descCtrl = TextEditingController(text: team.description);
    final goalCtrl = TextEditingController(text: team.goal);
    String department = team.department;
    double capacity = team.capacityHours;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          title: Text('Edit ${team.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Team Name', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
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
                            const Text('Team Key', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: keyCtrl,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                            const Text('Capacity (h)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(height: 6),
                            TextFormField(
                              initialValue: capacity.toInt().toString(),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => capacity = double.tryParse(v) ?? capacity,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Description', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Goal', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: goalCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(workSprintTeamProvider.notifier).updateTeam(team.id, {
                  'name': nameCtrl.text.trim(),
                  'team_key': keyCtrl.text.trim(),
                  'department': department,
                  'description': descCtrl.text.trim(),
                  'goal': goalCtrl.text.trim(),
                  'capacity_hours': capacity,
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddMemberDialog(String teamId, bool isDark) {
    String? selectedUserId = _assignableUsers.isNotEmpty ? _assignableUsers.first.userId : null;
    String selectedRole = 'Developer';
    double capacity = 40.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
          title: const Text('Add Member to Team', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Institute User', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedUserId,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                items: _assignableUsers.map((u) {
                  return DropdownMenuItem(
                    value: u.userId,
                    child: Text('${u.fullName} (${u.role})', overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (v) => setDialogState(() => selectedUserId = v),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Team Role', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                items: const [
                  DropdownMenuItem(value: 'Team Lead', child: Text('Team Lead')),
                  DropdownMenuItem(value: 'Senior Developer', child: Text('Senior Developer')),
                  DropdownMenuItem(value: 'UI/UX Designer', child: Text('UI/UX Designer')),
                  DropdownMenuItem(value: 'Backend Developer', child: Text('Backend Developer')),
                  DropdownMenuItem(value: 'QA Engineer', child: Text('QA Engineer')),
                  DropdownMenuItem(value: 'DevOps Engineer', child: Text('DevOps Engineer')),
                  DropdownMenuItem(value: 'System Analyst', child: Text('System Analyst')),
                  DropdownMenuItem(value: 'Developer', child: Text('Developer')),
                ],
                onChanged: (v) => setDialogState(() => selectedRole = v ?? 'Developer'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Capacity (Hours / Sprint)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              TextFormField(
                initialValue: '40',
                keyboardType: TextInputType.number,
                onChanged: (v) => capacity = double.tryParse(v) ?? 40.0,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedUserId == null) return;
                Navigator.pop(ctx);
                await ref.read(workSprintTeamProvider.notifier).addMember(teamId, {
                  'user_id': selectedUserId,
                  'role': selectedRole,
                  'capacity_hours': capacity,
                  'is_lead': selectedRole == 'Team Lead',
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Add Member', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openDuplicateTeamDialog(TeamDirectoryItemModel team, bool isDark) {
    final nameCtrl = TextEditingController(text: 'Copy of ${team.name}');
    final keyCtrl = TextEditingController(text: '${team.teamKey}_C');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        title: Text('Duplicate ${team.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Team Name', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(height: 12),
            const Text('New Team Key', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 6),
            TextField(
              controller: keyCtrl,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(workSprintTeamProvider.notifier).duplicateTeam(
                team.id,
                newName: nameCtrl.text.trim(),
                newKey: keyCtrl.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Duplicate Team', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTeam(TeamDirectoryItemModel team, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        title: Text('Archive ${team.name}?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to archive "${team.name}"? It will be removed from the active directory.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(workSprintTeamProvider.notifier).deleteTeam(team.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Archive Team', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveMember(String teamId, String userId, String memberName, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        title: Text('Remove $memberName?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove "$memberName" from this team?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(workSprintTeamProvider.notifier).removeMember(teamId, userId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openAddTagDialog(TeamDetailModel team, bool isDark) {
    final tagCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        title: const Text('Add Team Tag', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: tagCtrl,
          decoration: InputDecoration(
            hintText: 'e.g. Mobile Apps, DevOps',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newTag = tagCtrl.text.trim();
              if (newTag.isEmpty) return;
              Navigator.pop(ctx);
              final updatedTags = List<String>.from(team.tags)..add(newTag);
              await ref.read(workSprintTeamProvider.notifier).updateTeam(team.id, {'tags': updatedTags});
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Add Tag', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openAdjustCapacityDialog(TeamDetailModel team, bool isDark) {
    double cap = team.capacity.totalCapacityHours;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        title: const Text('Adjust Team Capacity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextFormField(
          initialValue: cap.toInt().toString(),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Total Capacity Hours',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (v) => cap = double.tryParse(v) ?? cap,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(workSprintTeamProvider.notifier).updateTeam(team.id, {'capacity_hours': cap});
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Save Capacity', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openImportDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        title: const Text('Import Teams CSV', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload a CSV file containing columns: Team Name, Key, Department, Lead Email, Capacity (h).',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            SizedBox(height: 16),
            Center(
              child: Icon(Icons.cloud_upload_outlined, size: 48, color: Color(0xFF2563EB)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV parser ready for file selection'), backgroundColor: Color(0xFF2563EB)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Select File', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
