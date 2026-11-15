import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/visitor_models.dart';
import '../../providers/visitors_provider.dart';
import '../dialogs/restriction_lift_dialog.dart';
import '../dialogs/restriction_update_dialog.dart';
import '../dialogs/visitor_restriction_dialog.dart';
import '../dialogs/visitors_more_filters_dialog.dart';
import '../dialogs/visitor_date_range_dialog.dart';
import '../dialogs/visitor_upload_document_dialog.dart';
import '../../utils/visitor_avatar_helper.dart';
import '../../../../utils/js_helper.dart';

class BlacklistedVisitorsTab extends ConsumerStatefulWidget {
  const BlacklistedVisitorsTab({super.key});

  @override
  ConsumerState<BlacklistedVisitorsTab> createState() => _BlacklistedVisitorsTabState();
}

class _BlacklistedVisitorsTabState extends ConsumerState<BlacklistedVisitorsTab> {
  int _activeDetailTab = 0; // 0: Overview, 1: Documents, 2: Incident History
  int _docPage = 1;
  static const int _docPageSize = 5;
  int _historyPage = 1;
  static const int _historyPageSize = 5;
  String? _lastRestrictionId;
  final Set<String> _selectedRestrictionIds = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(visitorsProvider);
    final notifier = ref.read(visitorsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kpis = state.blacklistKpis;
    final restrictions = state.restrictions;
    final selectedRest = state.selectedRestriction ?? (restrictions.isNotEmpty ? restrictions.first : null);
    final detail = state.selectedRestrictionDetail;

    if (selectedRest != null && selectedRest.id != _lastRestrictionId) {
      _lastRestrictionId = selectedRest.id;
      _docPage = 1;
      _historyPage = 1;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: isMobile ? 10 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==================================================================
          // 1. KPI CARDS ROW (4 Cards Matching Screenshot 2)
          // ==================================================================
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount;
              if (constraints.maxWidth > 1000) {
                crossAxisCount = 4;
              } else if (constraints.maxWidth > 700) {
                crossAxisCount = 2;
              } else if (constraints.maxWidth > 480) {
                crossAxisCount = 2;
              } else {
                crossAxisCount = 1;
              }
              final cardWidth = (constraints.maxWidth - ((crossAxisCount - 1) * 10)) / crossAxisCount;
              final cards = [
                _buildKpiCard(
                  context,
                  title: 'Total Blacklisted',
                  value: '${kpis.totalBlacklisted}',
                  subtitle: kpis.totalBlacklistedSubtitle,
                  icon: Icons.cancel_rounded,
                  iconBg: const Color(0xFFFEE2E2),
                  iconColor: const Color(0xFFEF4444),
                  isDark: isDark,
                  onTap: () => notifier.setStatusFilter('All'),
                ),
                _buildKpiCard(
                  context,
                  title: 'Active Blocks',
                  value: '${kpis.activeBlocks}',
                  subtitle: kpis.activeBlocksSubtitle,
                  icon: Icons.shield_rounded,
                  iconBg: const Color(0xFFDBEAFE),
                  iconColor: const Color(0xFF2563EB),
                  isDark: isDark,
                  onTap: () => notifier.setStatusFilter('Active'),
                ),
                _buildKpiCard(
                  context,
                  title: 'Expired Blocks',
                  value: '${kpis.expiredBlocks}',
                  subtitle: kpis.expiredBlocksSubtitle,
                  icon: Icons.access_time_filled_rounded,
                  iconBg: const Color(0xFFFFEDD5),
                  iconColor: const Color(0xFFEA580C),
                  isDark: isDark,
                  onTap: () => notifier.setStatusFilter('Expired'),
                ),
                _buildKpiCard(
                  context,
                  title: 'Attempted Entries',
                  value: '${kpis.attemptedEntries}',
                  subtitle: kpis.attemptedEntriesSubtitle,
                  icon: Icons.person_off_rounded,
                  iconBg: const Color(0xFFFEE2E2),
                  iconColor: const Color(0xFFDC2626),
                  isDark: isDark,
                  onTap: () => notifier.setStatusFilter('Attempted'),
                ),
              ];

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
              );
            },
          ),
          const SizedBox(height: 16),

          // ==================================================================
          // 2. SEARCH & FILTER TOOLBAR (Matching Screenshot 2)
          // ==================================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: LayoutBuilder(
              builder: (context, filterConstraints) {
                final isNarrowFilter = filterConstraints.maxWidth < 600;
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Search field
                    SizedBox(
                      width: isNarrowFilter ? filterConstraints.maxWidth : 320,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name, mobile, ID number, reason...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (v) => notifier.setSearchQuery(v),
                  ),
                ),

                // All Locations Dropdown
                _buildDropdown(
                  value: const ['All Locations', 'Main Gate', 'Library', 'Lab', 'Girls Hostel', 'Auditorium', 'Science Lab'].contains(state.selectedLocation) ? state.selectedLocation : 'All Locations',
                  items: const ['All Locations', 'Main Gate', 'Library', 'Lab', 'Girls Hostel', 'Auditorium', 'Science Lab'],
                  isDark: isDark,
                  onChanged: (val) {
                    if (val != null) {
                      notifier.setLocationFilter(val);
                    }
                  },
                ),

                // All Block Reasons Dropdown
                _buildDropdown(
                  value: const [
                    'All Block Reasons',
                    'Security Incident',
                    'Threat / Harassment',
                    'Policy Violation',
                    'Unauthorized Entry',
                    'Legal Order',
                    'Theft',
                    'Misbehavior',
                    'Harassment',
                    'Other'
                  ].contains(state.selectedCategory) ? state.selectedCategory : 'All Block Reasons',
                  items: const [
                    'All Block Reasons',
                    'Security Incident',
                    'Threat / Harassment',
                    'Policy Violation',
                    'Unauthorized Entry',
                    'Legal Order',
                    'Theft',
                    'Misbehavior',
                    'Harassment',
                    'Other'
                  ],
                  isDark: isDark,
                  onChanged: (val) {
                    if (val != null) {
                      notifier.setCategoryFilter(val);
                    }
                  },
                ),

                // All Status Dropdown
                _buildDropdown(
                  value: const ['All Status', 'Active', 'Expired', 'Lifted'].contains(state.selectedStatus) ? state.selectedStatus : 'All Status',
                  items: const ['All Status', 'Active', 'Expired', 'Lifted'],
                  isDark: isDark,
                  onChanged: (val) {
                    if (val != null) {
                      notifier.setStatusFilter(val);
                    }
                  },
                ),

                // Date Range Button (Interactive)
                InkWell(
                  onTap: () => showVisitorDateRangeDialog(context, ref),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          state.selectedDateRange,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),

                // More Filters Button (Interactive)
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const VisitorsMoreFiltersDialog(),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded, size: 15, color: Color(0xFF64748B)),
                  label: const Text('More Filters', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            );
          },
            ),
          ),
          const SizedBox(height: 16),

          // ==================================================================
          // 3. MAIN WORKSPACE: TABLE (7) + RIGHT INSPECTOR (3)
          // ==================================================================
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1050;
              final tableWidget = _buildRestrictionsTable(context, isDark, state, notifier, selectedRest);
              final drawerWidget = _buildRightInspector(context, isDark, state, notifier, selectedRest, detail);

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: tableWidget),
                    const SizedBox(width: 16),
                    SizedBox(width: 380, child: drawerWidget),
                  ],
                );
              } else {
                return Column(
                  children: [
                    tableWidget,
                    const SizedBox(height: 16),
                    drawerWidget,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KPI CARD HELPER
  // ==========================================================================
  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // DROPDOWN HELPER
  // ==========================================================================
  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isDense: true,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          items: items.map((it) => DropdownMenuItem(value: it, child: Text(it))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ==========================================================================
  // TABLE WIDGET (Matching Screenshot 2)
  // ==========================================================================
  Widget _buildRestrictionsTable(
    BuildContext context,
    bool isDark,
    VisitorsState state,
    VisitorsNotifier notifier,
    BlacklistedVisitorItem? selectedRest,
  ) {
    final restrictions = state.restrictions;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Toolbar Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Blacklisted Visitors (${restrictions.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Export button
                  OutlinedButton.icon(
                    onPressed: () async {
                      final api = ref.read(visitorsApiServiceProvider);
                      final bytes = await api.exportVisitsCSV();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Exported ${bytes.length} bytes of blacklisted restrictions!'),
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.file_download_outlined, size: 15, color: Color(0xFF475569)),
                    label: const Text('Export', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Bulk Actions PopupMenu
                  PopupMenuButton<String>(
                    tooltip: 'Bulk Actions',
                    onSelected: (action) async {
                      if (_selectedRestrictionIds.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select restrictions to perform bulk action.')),
                        );
                        return;
                      }
                      if (action == 'lift') {
                        for (final id in _selectedRestrictionIds) {
                          await notifier.liftRestriction(id, 'Bulk lifted by administrator');
                        }
                        setState(() => _selectedRestrictionIds.clear());
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bulk restriction lift completed.'), backgroundColor: Color(0xFF16A34A)),
                          );
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'lift',
                        child: Row(
                          children: [
                            Icon(Icons.lock_open_rounded, size: 16, color: Color(0xFF16A34A)),
                            SizedBox(width: 8),
                            Text('Bulk Lift Restrictions'),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Bulk Actions', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                          SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Columns Customization
                  PopupMenuButton<String>(
                    tooltip: 'Customize Columns',
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        enabled: false,
                        child: Text('Toggle Columns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      ...['Photo', 'Name', 'ID Type & Number', 'Mobile No.', 'Block Reason', 'Location(s)', 'Blocked On', 'Valid Till', 'Status'].map((col) {
                        return CheckedPopupMenuItem<String>(
                          value: col,
                          checked: true,
                          child: Text(col, style: const TextStyle(fontSize: 12.5)),
                        );
                      }),
                    ],
                    onSelected: (_) {},
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.view_column_outlined, size: 18, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

          // Scrollable Table Content with responsive dynamic width
          LayoutBuilder(
            builder: (context, tableConstraints) {
              const minWidth = 1180.0;
              final tableWidth = math.max(tableConstraints.maxWidth, minWidth);
              final extra = tableWidth > minWidth ? (tableWidth - minWidth) : 0.0;
              final nameWidth = 140.0 + (extra * 0.25);
              final idWidth = 125.0 + (extra * 0.20);
              final phoneWidth = 125.0 + (extra * 0.20);
              final reasonWidth = 140.0 + (extra * 0.20);
              final locationWidth = 105.0 + (extra * 0.15);

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // Table Column Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 34,
                              child: Checkbox(
                                value: _selectedRestrictionIds.length == restrictions.length && restrictions.isNotEmpty,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedRestrictionIds.addAll(restrictions.map((r) => r.id));
                                    } else {
                                      _selectedRestrictionIds.clear();
                                    }
                                  });
                                },
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            _buildSortableHeaderCell(
                              title: '#',
                              sortKey: 'created_at',
                              width: 30,
                              currentSortBy: state.restrictionsSortBy,
                              currentSortOrder: state.restrictionsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortRestrictions('created_at'),
                            ),
                            SizedBox(width: 44, child: Text('Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B)))),
                            _buildSortableHeaderCell(
                              title: 'Name',
                              sortKey: 'visitor_name',
                              width: nameWidth,
                              currentSortBy: state.restrictionsSortBy,
                              currentSortOrder: state.restrictionsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortRestrictions('visitor_name'),
                            ),
                            _buildSortableHeaderCell(
                              title: 'ID Type & Number',
                              sortKey: 'id_type',
                              width: idWidth,
                              currentSortBy: state.restrictionsSortBy,
                              currentSortOrder: state.restrictionsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortRestrictions('id_type'),
                            ),
                            _buildSortableHeaderCell(
                              title: 'Mobile No.',
                              sortKey: 'phone',
                              width: phoneWidth,
                              currentSortBy: state.restrictionsSortBy,
                              currentSortOrder: state.restrictionsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortRestrictions('phone'),
                            ),
                            _buildSortableHeaderCell(
                              title: 'Block Reason',
                              sortKey: 'reason_category',
                              width: reasonWidth,
                              currentSortBy: state.restrictionsSortBy,
                              currentSortOrder: state.restrictionsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortRestrictions('reason_category'),
                            ),
                            _buildSortableHeaderCell(
                              title: 'Location(s)',
                              sortKey: 'scope_name',
                              width: locationWidth,
                              currentSortBy: state.restrictionsSortBy,
                              currentSortOrder: state.restrictionsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortRestrictions('scope_name'),
                            ),
                            _buildSortableHeaderCell(
                              title: 'Blocked On',
                              sortKey: 'created_at',
                              width: 95,
                              currentSortBy: state.restrictionsSortBy,
                              currentSortOrder: state.restrictionsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortRestrictions('created_at'),
                            ),
                            _buildSortableHeaderCell(
                              title: 'Valid Till',
                              sortKey: 'valid_till',
                              width: 95,
                              currentSortBy: state.restrictionsSortBy,
                              currentSortOrder: state.restrictionsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortRestrictions('valid_till'),
                            ),
                            _buildSortableHeaderCell(
                              title: 'Status',
                              sortKey: 'status',
                              width: 80,
                              currentSortBy: state.restrictionsSortBy,
                              currentSortOrder: state.restrictionsSortOrder,
                              isDark: isDark,
                              onTap: () => notifier.sortRestrictions('status'),
                            ),
                            SizedBox(width: 115, child: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B)))),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

                      // Table Rows
                      if (restrictions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: Text('No restricted or blacklisted visitors found.')),
                        )
                      else
                        ...List.generate(restrictions.length, (idx) {
                          final item = restrictions[idx];
                          final isSelected = selectedRest?.id == item.id;
                          final isActive = item.status.toLowerCase() == 'active';

                          return InkWell(
                            onTap: () => notifier.openRestrictionDetail(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : const Color(0xFFEFF6FF))
                                    : (idx.isEven ? Colors.transparent : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.3) : const Color(0xFFFAFAFA))),
                                border: Border(
                                  bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 34,
                                    child: Checkbox(
                                      value: _selectedRestrictionIds.contains(item.id),
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selectedRestrictionIds.add(item.id);
                                          } else {
                                            _selectedRestrictionIds.remove(item.id);
                                          }
                                        });
                                      },
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 25,
                                    child: Text('${idx + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  ),
                                  SizedBox(
                                    width: 44,
                                    child: VisitorAvatar(
                                      photoUrl: item.photoUrl,
                                      name: item.visitorName,
                                      radius: 15,
                                      fontSize: 11,
                                    ),
                                  ),
                                  SizedBox(
                                    width: nameWidth,
                                    child: Text(
                                      item.visitorName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(
                                    width: idWidth,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(item.idType, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                        Text(item.idNumberMasked, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: phoneWidth,
                                    child: Text(
                                      item.mobileNo,
                                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                    ),
                                  ),
                                  SizedBox(
                                    width: reasonWidth,
                                    child: _buildReasonPill(item.reasonCategory),
                                  ),
                                  SizedBox(
                                    width: locationWidth,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        item.scopeName,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 95,
                                    child: Text(
                                      item.blockedOnText.isNotEmpty ? item.blockedOnText : item.effectiveFrom,
                                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 95,
                                    child: Text(
                                      item.validTillText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: item.validTillText.toLowerCase() == 'permanent' ? FontWeight.w600 : FontWeight.normal,
                                        color: item.validTillText.toLowerCase() == 'permanent' ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isActive ? const Color(0xFFFEE2E2) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        item.status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isActive ? const Color(0xFFDC2626) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 115,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: Icon(Icons.visibility_outlined, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                            tooltip: 'View Details',
                                            onPressed: () => notifier.openRestrictionDetail(item),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: Icon(Icons.edit_outlined, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                            tooltip: 'Update Details',
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => RestrictionUpdateDialog(restriction: item),
                                              );
                                            },
                                          ),
                                        ),
                                        SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: PopupMenuButton<String>(
                                            padding: EdgeInsets.zero,
                                            icon: Icon(Icons.more_vert, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                            onSelected: (val) {
                                              if (val == 'lift') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => RestrictionLiftDialog(restriction: item),
                                                );
                                              } else if (val == 'block') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => VisitorRestrictionDialog(
                                                    initialProfile: VisitorProfileItem(
                                                      id: item.visitorId,
                                                      schoolId: '',
                                                      fullName: item.visitorName,
                                                      phone: item.visitorPhone,
                                                      photoUrl: item.photoUrl,
                                                      idType: item.idType,
                                                      idNumberMasked: item.idNumberMasked,
                                                    ),
                                                  ),
                                                );
                                              } else if (val == 'update') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => RestrictionUpdateDialog(restriction: item),
                                                );
                                              }
                                            },
                                            itemBuilder: (ctx) => [
                                              const PopupMenuItem(value: 'update', child: Text('Update Details')),
                                              if (item.status.toUpperCase() != 'LIFTED')
                                                const PopupMenuItem(
                                                  value: 'lift',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFFDC2626)),
                                                      SizedBox(width: 8),
                                                      Text('Remove from Blocklist', style: TextStyle(color: Color(0xFFDC2626))),
                                                    ],
                                                  ),
                                                )
                                              else
                                                const PopupMenuItem(
                                                  value: 'block',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.block_rounded, size: 16, color: Color(0xFFDC2626)),
                                                      SizedBox(width: 8),
                                                      Text('Block Visitor', style: TextStyle(color: Color(0xFFDC2626))),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
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
                  ),
                ),
              );
            },
          ),

          // Pagination Bar at Bottom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Showing ${state.restrictionPagination.totalRecords == 0 ? 0 : (state.restrictionPagination.page - 1) * state.restrictionPagination.pageSize + 1} - ${(state.restrictionPagination.page * state.restrictionPagination.pageSize).clamp(0, state.restrictionPagination.totalRecords)} of ${state.restrictionPagination.totalRecords} blacklisted visitors',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Pagination controls
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    onPressed: state.restrictionPagination.page > 1
                        ? () => notifier.fetchRestrictions(page: state.restrictionPagination.page - 1)
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${state.restrictionPagination.page}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    onPressed: state.restrictionPagination.page < state.restrictionPagination.totalPages
                        ? () => notifier.fetchRestrictions(page: state.restrictionPagination.page + 1)
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  Text('Rows per page', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: [10, 25, 50, 100].contains(state.restrictionPagination.pageSize) ? state.restrictionPagination.pageSize : 10,
                        isDense: true,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        items: const [
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 25, child: Text('25')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                          DropdownMenuItem(value: 100, child: Text('100')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            notifier.fetchRestrictions(page: 1, pageSize: val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // REASON PILL BADGE HELPER
  // ==========================================================================
  Widget _buildReasonPill(String reason) {
    Color bg;
    Color fg;
    final r = reason.toLowerCase();
    if (r.contains('theft') || r.contains('disruptive') || r.contains('police')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
    } else if (r.contains('misbehavior') || r.contains('harassment')) {
      bg = const Color(0xFFFCE7F3);
      fg = const Color(0xFFBE185D);
    } else if (r.contains('unauthorized') || r.contains('photography')) {
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF7E22CE);
    } else if (r.contains('fake') || r.contains('solicitation')) {
      bg = const Color(0xFFFFEDD5);
      fg = const Color(0xFFC2410C);
    } else {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        reason,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ==========================================================================
  // RIGHT-SIDE 360° INSPECTOR DRAWER (Matching Screenshot 2)
  // ==========================================================================
  Widget _buildRightInspector(
    BuildContext context,
    bool isDark,
    VisitorsState state,
    VisitorsNotifier notifier,
    BlacklistedVisitorItem? rest,
    RestrictionDetail360? detail,
  ) {
    if (rest == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: Text('Select a restricted visitor to inspect')),
      );
    }

    List<Map<String, dynamic>> docs = [];
    if (detail != null && detail.documents.isNotEmpty) {
      docs = List<Map<String, dynamic>>.from(detail.documents);
    } else {
      docs = [
        {
          'document_name': '${rest.idType} (${rest.idNumberMasked})',
          'document_type': rest.idType,
          'file_name': '${rest.idType.toLowerCase().replaceAll(' ', '_')}.pdf',
          'status': 'Verified',
          'is_verified': true,
          'uploaded_at': rest.effectiveFrom,
        },
        {
          'document_name': 'Incident Report & Proof',
          'document_type': 'Incident Report',
          'file_name': 'incident_report_${rest.reasonCategory.toLowerCase().replaceAll(' ', '_')}.pdf',
          'status': 'Confidential',
          'is_verified': true,
          'uploaded_at': rest.effectiveFrom,
        },
      ];
    }

    List<Map<String, dynamic>> hist = [];
    if (detail != null && detail.history.isNotEmpty) {
      hist = List<Map<String, dynamic>>.from(detail.history);
    } else {
      hist = [
        {
          'performed_at': rest.blockedOnText.isNotEmpty ? rest.blockedOnText : '12 May 2024, 10:30 AM',
          'action': 'Restriction Created by ${rest.blockedByName ?? "Security"}',
          'reason': 'Reason: ${rest.reasonCategory}',
        },
        {
          'performed_at': 'Incident recorded at ${rest.scopeName}',
          'action': 'Security flag logged',
          'reason': rest.confidentialNotes.isNotEmpty ? rest.confidentialNotes : rest.remarks ?? 'Incident flagged',
        },
      ];
    }


    return Column(
      children: [
        // Main Overview Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drawer Header with "Edit"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Visitor Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => RestrictionUpdateDialog(restriction: rest),
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                        SizedBox(width: 4),
                        Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Avatar & Name Card
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VisitorAvatar(
                    photoUrl: rest.photoUrl,
                    name: rest.visitorName,
                    radius: 28,
                    fontSize: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                rest.visitorName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Text(
                              rest.status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: rest.status.toUpperCase() == 'LIFTED' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildProfileField('ID Type', rest.idType, isDark),
                        _buildProfileField('ID Number', rest.idNumberMasked, isDark),
                        _buildProfileField('Mobile', rest.mobileNo, isDark),
                        _buildProfileField('Email', rest.email ?? '-', isDark),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3 Sub-tabs: Overview | Documents (${docs.length}) | Incident History (${hist.length})
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSubTab(0, 'Overview', _activeDetailTab == 0),
                    _buildSubTab(1, 'Documents (${docs.length})', _activeDetailTab == 1),
                    _buildSubTab(2, 'Incident History (${hist.length})', _activeDetailTab == 2),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              const SizedBox(height: 14),

              // Sub-tab content: Key-value details
              if (_activeDetailTab == 0) ...[
                _buildDetailRow(Icons.gavel_outlined, 'Block Reason', rest.reasonCategory, isDark),
                _buildDetailRow(Icons.place_outlined, 'Location(s)', rest.scopeName, isDark),
                _buildDetailRow(Icons.calendar_today_outlined, 'Blocked On', rest.blockedOnText.isNotEmpty ? rest.blockedOnText : '12 May 2024, 10:30 AM', isDark),
                _buildDetailRow(Icons.lock_clock_outlined, 'Valid Till', rest.validTillText, isDark),
                _buildDetailRow(Icons.security_outlined, 'Blocked By', rest.blockedByName ?? 'Rahul Sharma (Security)', isDark),
                _buildDetailRow(Icons.chat_bubble_outline, 'Remarks', rest.remarks ?? 'Attempted unauthorized entry.', isDark),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 10, color: Color(0xFFDC2626)),
                      const SizedBox(width: 12),
                      SizedBox(width: 95, child: Text('Status', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)))),
                      Text(': ', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: rest.status.toUpperCase() == 'LIFTED' ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          rest.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: rest.status.toUpperCase() == 'LIFTED' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_activeDetailTab == 1) ...[
                _buildDocumentsTab(context, isDark, docs, rest),
              ] else ...[
                _buildIncidentHistoryTab(context, isDark, hist),
              ],
              const SizedBox(height: 20),

              // Action Buttons: Remove from Blocklist (or Block Visitor if lifted) & Update Details
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (rest.status.toUpperCase() == 'LIFTED') {
                          showDialog(
                            context: context,
                            builder: (ctx) => VisitorRestrictionDialog(
                              initialProfile: VisitorProfileItem(
                                id: rest.visitorId,
                                schoolId: '',
                                fullName: rest.visitorName,
                                phone: rest.visitorPhone,
                                photoUrl: rest.photoUrl,
                                idType: rest.idType,
                                idNumberMasked: rest.idNumberMasked,
                              ),
                            ),
                          );
                        } else {
                          showDialog(
                            context: context,
                            builder: (ctx) => RestrictionLiftDialog(restriction: rest),
                          );
                        }
                      },
                      icon: Icon(
                        rest.status.toUpperCase() == 'LIFTED' ? Icons.block_rounded : Icons.lock_open_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        rest.status.toUpperCase() == 'LIFTED' ? 'Block Visitor' : 'Remove from Blocklist',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => RestrictionUpdateDialog(restriction: rest),
                        );
                      },
                      icon: const Icon(Icons.edit_note, size: 16, color: Color(0xFF2563EB)),
                      label: const Text('Update Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE)),
                        backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileField(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 65,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            ' : ',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTab(int index, String label, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _activeDetailTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          const SizedBox(width: 8),
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            ': ',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab(BuildContext context, bool isDark, List<Map<String, dynamic>> docs, BlacklistedVisitorItem rest) {
    final totalDocs = docs.length;
    final totalPages = (totalDocs / _docPageSize).ceil().clamp(1, 999999);
    final currentPage = _docPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _docPageSize;
    final endIndex = (startIndex + _docPageSize).clamp(0, totalDocs);
    final pagedDocs = docs.isNotEmpty ? docs.sublist(startIndex, endIndex) : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Action Bar with Upload Document Button
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              'Documents (${docs.length})',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => VisitorUploadDocumentDialog(
                    visitorId: rest.visitorId,
                    restrictionId: rest.id,
                    visitorName: rest.visitorName,
                    initialDocumentType: 'Security Incident Report',
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
              label: const Text('Upload Document', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (docs.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.description_outlined, size: 36, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text(
                  'No restriction documents uploaded yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload incident evidence, FIR, police reports, or barring notices.',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => VisitorUploadDocumentDialog(
                        visitorId: rest.visitorId,
                        restrictionId: rest.id,
                        visitorName: rest.visitorName,
                        initialDocumentType: 'Security Incident Report',
                      ),
                    );
                  },
                  icon: const Icon(Icons.upload_file_rounded, size: 14, color: Colors.white),
                  label: const Text('Upload Document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          )
        else ...[
          ...pagedDocs.map((doc) {
            final docId = doc['id']?.toString();
            final docName = doc['document_name']?.toString() ?? doc['file_name']?.toString() ?? 'Document';
            final docType = doc['document_type']?.toString() ?? 'Security Record';
            final isVerified = doc['is_verified'] == true || doc['status'] == 'Verified' || doc['status'] == 'Confidential';
            final status = doc['status']?.toString() ?? (isVerified ? 'Verified' : 'Pending');
            final fileUrl = doc['file_url']?.toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, size: 24, color: Color(0xFFDC2626)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          docName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                docType,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                              ),
                            ),
                            Text(
                              '• $status',
                              style: TextStyle(
                                fontSize: 10,
                                color: status == 'Confidential' ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF64748B)),
                    tooltip: 'Download $docName',
                    onPressed: () {
                      if (fileUrl != null && fileUrl.isNotEmpty) {
                        downloadFileWeb(fileUrl, docName);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Downloading $docName...')),
                      );
                    },
                  ),
                  if (docId != null && docId.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      tooltip: 'Delete $docName',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Document'),
                            content: Text('Are you sure you want to delete "$docName"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          ref.read(visitorsProvider.notifier).deleteDocument(docId, restrictionId: rest.id);
                        }
                      },
                    ),
                ],
              ),
            );
          }),
        ],
        _buildPaginationFooter(
          currentPage: currentPage,
          totalPages: totalPages,
          totalItems: totalDocs,
          startIndex: startIndex,
          endIndex: endIndex,
          itemLabel: 'documents',
          isDark: isDark,
          prevKey: const Key('rest_docs_prev'),
          nextKey: const Key('rest_docs_next'),
          onPageChanged: (newPage) => setState(() => _docPage = newPage),
        ),
      ],
    );
  }

  Widget _buildIncidentHistoryTab(BuildContext context, bool isDark, List<Map<String, dynamic>> hist) {
    if (hist.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.history_rounded, size: 36, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(
              'No incident history recorded',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      );
    }

    final totalHist = hist.length;
    final totalPages = (totalHist / _historyPageSize).ceil().clamp(1, 999999);
    final currentPage = _historyPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _historyPageSize;
    final endIndex = (startIndex + _historyPageSize).clamp(0, totalHist);
    final pagedHist = hist.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...pagedHist.map((h) {
          final time = h['performed_at']?.toString() ?? h['created_at']?.toString() ?? '-';
          final action = h['action']?.toString() ?? 'Security Record';
          final reason = h['reason']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildHistoryRow(time, action, reason, isDark),
          );
        }),
        _buildPaginationFooter(
          currentPage: currentPage,
          totalPages: totalPages,
          totalItems: totalHist,
          startIndex: startIndex,
          endIndex: endIndex,
          itemLabel: 'logs',
          isDark: isDark,
          prevKey: const Key('rest_history_prev'),
          nextKey: const Key('rest_history_next'),
          onPageChanged: (newPage) => setState(() => _historyPage = newPage),
        ),
      ],
    );
  }

  Widget _buildPaginationFooter({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required int startIndex,
    required int endIndex,
    required String itemLabel,
    required bool isDark,
    required ValueChanged<int> onPageChanged,
    Key? prevKey,
    Key? nextKey,
  }) {
    if (totalItems <= 5) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              '${startIndex + 1}-$endIndex of $totalItems',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: prevKey,
                icon: const Icon(Icons.chevron_left_rounded, size: 17),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                color: currentPage > 1
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  '$currentPage/$totalPages',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                key: nextKey,
                icon: const Icon(Icons.chevron_right_rounded, size: 17),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                color: currentPage < totalPages
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(String time, String action, String note, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(time, style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(
            action,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          Text(note, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        ],
      ),
    );
  }


  Widget _buildSortableHeaderCell({
    required String title,
    required String sortKey,
    required double width,
    required String currentSortBy,
    required String currentSortOrder,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final isSorted = currentSortBy.toLowerCase() == sortKey.toLowerCase();
    final isAsc = currentSortOrder.toUpperCase() == 'ASC';
    final baseColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: width,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSorted ? const Color(0xFF2563EB) : baseColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              isSorted
                  ? (isAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 13,
              color: isSorted ? const Color(0xFF2563EB) : const Color(0xFF94A3B8).withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class AllAttemptedEntriesDialog extends StatefulWidget {
  final List<dynamic> attempts;
  final String visitorName;

  const AllAttemptedEntriesDialog({
    super.key,
    required this.attempts,
    required this.visitorName,
  });

  @override
  State<AllAttemptedEntriesDialog> createState() => _AllAttemptedEntriesDialogState();
}

class _AllAttemptedEntriesDialogState extends State<AllAttemptedEntriesDialog> {
  String _searchFilter = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = widget.attempts.where((a) {
      if (_searchFilter.isEmpty) return true;
      final q = _searchFilter.toLowerCase();
      final loc = (a['location'] ?? a['gate_name'] ?? '').toString().toLowerCase();
      final time = (a['attempted_at'] ?? a['created_at'] ?? '').toString().toLowerCase();
      final action = (a['action_taken'] ?? '').toString().toLowerCase();
      final op = (a['operator_name'] ?? a['guard_name'] ?? '').toString().toLowerCase();
      return loc.contains(q) || time.contains(q) || action.contains(q) || op.contains(q);
    }).toList();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.security, color: Color(0xFFDC2626), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attempted Entry Logs - ${widget.visitorName}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Security incidents and blocked gate entrance history',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: TextField(
                onChanged: (v) => setState(() => _searchFilter = v),
                decoration: InputDecoration(
                  hintText: 'Filter by gate location, action taken, guard...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No attempted entries match your search criteria.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      itemBuilder: (context, idx) {
                        final a = filtered[idx];
                        final time = a['attempted_at']?.toString() ?? a['created_at']?.toString() ?? '-';
                        final loc = a['location']?.toString() ?? a['gate_name']?.toString() ?? 'Main Gate';
                        final action = a['action_taken']?.toString() ?? 'Access Denied / Blocked';
                        final guard = a['operator_name']?.toString() ?? a['guard_name']?.toString() ?? 'Security Guard';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Gate: $loc',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Reported by: $guard  •  $time',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  action,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
