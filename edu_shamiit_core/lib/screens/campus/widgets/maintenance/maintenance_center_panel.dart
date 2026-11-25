import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/maintenance_models.dart';
import '../../providers/maintenance_provider.dart';
import '../../providers/campus_provider.dart';
import '../common/campus_pagination_bar.dart';
import 'subviews/vendor_contracts_subview.dart';
import 'subviews/maintenance_plans_subview.dart';

class MaintenanceCenterPanel extends ConsumerStatefulWidget {
  final VoidCallback onOpenNewRequest;
  final Function(MaintenanceRequestItem item)? onInspectRequest;
  final Function(MaintenanceRequestItem item)? onEditRequest;

  const MaintenanceCenterPanel({
    super.key,
    required this.onOpenNewRequest,
    this.onInspectRequest,
    this.onEditRequest,
  });

  @override
  ConsumerState<MaintenanceCenterPanel> createState() => _MaintenanceCenterPanelState();
}

class _MaintenanceCenterPanelState extends ConsumerState<MaintenanceCenterPanel> {
  final TextEditingController _searchController = TextEditingController();

  String _filterBuilding = 'All';
  String _filterLocation = 'All';
  String _filterType = 'All';
  String _filterStatus = 'All';
  String _filterPriority = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteRequest(MaintenanceRequestItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Maintenance Request'),
        content: Text('Are you sure you want to delete "${item.requestCode} - ${item.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(maintenanceProvider.notifier).deleteRequest(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Work order deleted successfully!' : 'Failed to delete request.'),
            backgroundColor: success ? const Color(0xFF059669) : const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maintenanceProvider);

    // Dedicated Tab Screen Subviews for Vendors & Contracts and Maintenance Plans
    if (state.activeView == 'vendors') {
      return const VendorContractsSubview();
    }
    if (state.activeView == 'plans') {
      return const MaintenancePlansSubview();
    }

    final notifier = ref.read(maintenanceProvider.notifier);
    final campusState = ref.watch(campusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final buildingList = ['All', ...campusState.buildings.map((b) => b.code.isNotEmpty ? b.code : b.name)];
    final locationList = [
      'All',
      ...campusState.rooms.map((r) => r.roomNumber.isNotEmpty ? r.roomNumber : r.name),
      if (campusState.rooms.isEmpty) ...['G-101', 'G-102', 'F1-202', 'GF-WR1', 'F2-305', 'Seminar Hall', 'Library', 'Lab-1'],
    ];

    final currentBuildingVal = buildingList.contains(_filterBuilding) ? _filterBuilding : 'All';
    final currentLocationVal = locationList.contains(_filterLocation) ? _filterLocation : 'All';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Center Top: Requests Table Card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0284C7).withValues(alpha: 0.2) : const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF0284C7)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Maintenance Requests (${state.requests.totalCount})',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: widget.onOpenNewRequest,
                            icon: const Icon(Icons.add, size: 15, color: Colors.white),
                            label: const Text('New Request', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: () => notifier.loadRequests(),
                            icon: Icon(Icons.more_vert, size: 18, color: textMuted),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // Search Bar & Filter Dropdowns
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Search input
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderColor),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => notifier.setSearchQuery(val),
                          style: TextStyle(fontSize: 12, color: textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search by request ID, title, location...',
                            hintStyle: TextStyle(fontSize: 12, color: textMuted),
                            prefixIcon: Icon(Icons.search, size: 16, color: textMuted),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 14),
                                    onPressed: () {
                                      _searchController.clear();
                                      notifier.setSearchQuery('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.only(top: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Filter Dropdowns Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterPill(
                              label: 'Building',
                              value: currentBuildingVal,
                              items: buildingList,
                              onChanged: (v) {
                                setState(() => _filterBuilding = v);
                                notifier.setBuildingFilter(v == 'All' ? 'all' : v.toLowerCase());
                              },
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              label: 'Location',
                              value: currentLocationVal,
                              items: locationList,
                              onChanged: (v) {
                                setState(() => _filterLocation = v);
                                notifier.setLocationFilter(v);
                              },
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              label: 'Type',
                              value: _filterType,
                              items: ['All', 'HVAC', 'AV Equipment', 'Electrical', 'Plumbing', 'Furniture', 'Civil', 'Sanitation', 'IT / Network'],
                              onChanged: (v) {
                                setState(() => _filterType = v);
                                notifier.setTypeFilter(v);
                              },
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              label: 'Status',
                              value: _filterStatus,
                              items: ['All', 'In Progress', 'Assigned', 'Pending', 'Scheduled', 'Resolved'],
                              onChanged: (v) {
                                setState(() => _filterStatus = v);
                                notifier.setStatusFilter(v);
                              },
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              label: 'Priority',
                              value: _filterPriority,
                              items: ['All', 'Critical', 'High', 'Medium', 'Low'],
                              onChanged: (v) {
                                setState(() => _filterPriority = v);
                                notifier.setPriorityFilter(v);
                              },
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Table
                state.isTableLoading
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 850),
                          child: DataTable(
                            headingRowHeight: 34,
                            dataRowMinHeight: 32,
                            dataRowMaxHeight: 35,
                            horizontalMargin: 12,
                            columnSpacing: 14,
                            headingRowColor: WidgetStateProperty.all(
                              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            ),
                            columns: [
                              _tableHeader('#'),
                              _tableHeader('Request ID', sortKey: 'request_code', notifier: notifier, state: state),
                              _tableHeader('Title / Issue', sortKey: 'title', notifier: notifier, state: state),
                              _tableHeader('Location', sortKey: 'location_display', notifier: notifier, state: state),
                              _tableHeader('Type', sortKey: 'request_type', notifier: notifier, state: state),
                              _tableHeader('Priority', sortKey: 'priority', notifier: notifier, state: state),
                              _tableHeader('Reported By', sortKey: 'reported_by_name', notifier: notifier, state: state),
                              _tableHeader('Status', sortKey: 'status', notifier: notifier, state: state),
                              _tableHeader('Actions'),
                            ],
                            rows: List.generate(state.requests.records.length, (idx) {
                              final item = state.requests.records[idx];
                              final rowNum = (state.currentPage - 1) * state.pageSize + idx + 1;
                              final isSelected = state.inspectedRequest?.id == item.id;

                              return DataRow(
                                selected: isSelected,
                                color: WidgetStateProperty.resolveWith((states) {
                                  if (isSelected) {
                                    return isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF);
                                  }
                                  return idx % 2 == 0
                                      ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                      : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : const Color(0xFFFAFAFA));
                                }),
                                onSelectChanged: (_) {
                                  notifier.inspectRequest(item);
                                  if (widget.onInspectRequest != null) widget.onInspectRequest!(item);
                                },
                                cells: [
                                  DataCell(Text('$rowNum', style: TextStyle(fontSize: 11.5, color: textMuted))),
                                  DataCell(
                                    Text(
                                      item.requestCode,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 180),
                                      child: Text(
                                        item.title,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.locationDisplay,
                                      style: TextStyle(fontSize: 11.5, color: textMuted, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  DataCell(_buildTypeCell(item.requestType, isDark)),
                                  DataCell(_buildPriorityBadge(item.priority)),
                                  DataCell(
                                    Text(
                                      item.reportedByName,
                                      style: TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  DataCell(_buildStatusBadge(item.status)),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_red_eye_outlined, size: 15),
                                          color: const Color(0xFF2563EB),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                          tooltip: 'View Request',
                                          onPressed: () {
                                            notifier.inspectRequest(item);
                                            if (widget.onInspectRequest != null) widget.onInspectRequest!(item);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 15),
                                          color: const Color(0xFFF59E0B),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                          tooltip: 'Edit Request',
                                          onPressed: () {
                                            if (widget.onEditRequest != null) widget.onEditRequest!(item);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 15),
                                          color: const Color(0xFFEF4444),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                          tooltip: 'Delete Request',
                                          onPressed: () => _deleteRequest(item),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.more_vert, size: 15, color: textMuted),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                          onPressed: () => notifier.inspectRequest(item),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),

                // Pagination Footer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: CampusPaginationBar(
                    currentPage: state.currentPage,
                    pageSize: state.pageSize,
                    totalItems: state.requests.totalCount,
                    onPageChanged: (newPage) => notifier.setPage(newPage),
                    onPageSizeChanged: (newSize) => notifier.setPageSize(newSize),
                    itemLabel: 'requests',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Center Bottom: 3 Operational Analytics Widgets Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 950;
              final widgets = [
                // Widget 1: Maintenance Trends
                _buildAnalyticsCard(
                  title: 'Maintenance Trends',
                  headerTrailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _legendDot(const Color(0xFF38BDF8), 'Requests'),
                      const SizedBox(width: 10),
                      _legendDot(const Color(0xFF818CF8), 'Resolved'),
                    ],
                  ),
                  child: _buildTrendsChart(state.analytics.trends, isDark),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                ),

                // Widget 2: Requests by Type Donut
                _buildAnalyticsCard(
                  title: 'Requests by Type',
                  icon: Icons.pie_chart_outline_rounded,
                  child: _buildCategoryDonut(state.analytics.categories, isDark),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                ),

                // Widget 3: SLA & Performance Meters
                _buildAnalyticsCard(
                  title: 'SLA & Performance',
                  icon: Icons.track_changes_rounded,
                  child: _buildSlaMeters(state.analytics.sla, isDark),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: widgets[0]),
                    const SizedBox(width: 12),
                    Expanded(flex: 6, child: widgets[1]),
                    const SizedBox(width: 12),
                    Expanded(flex: 6, child: widgets[2]),
                  ],
                );
              } else {
                return Column(
                  children: [
                    widgets[0],
                    const SizedBox(height: 12),
                    widgets[1],
                    const SizedBox(height: 12),
                    widgets[2],
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  DataColumn _tableHeader(String title, {String? sortKey, MaintenanceNotifier? notifier, MaintenanceState? state}) {
    final isSorted = sortKey != null && state?.sortBy == sortKey;
    final isAsc = state?.sortOrder == 'asc';

    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isSorted ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
          ),
          if (sortKey != null) ...[
            const SizedBox(width: 3),
            Icon(
              isSorted
                  ? (isAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 13,
              color: isSorted ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
          ],
        ],
      ),
      onSort: sortKey != null && notifier != null
          ? (_, __) => notifier.setSort(sortKey)
          : null,
    );
  }

  Widget _buildTypeCell(String type, bool isDark) {
    IconData icon;
    Color iconColor;

    if (type.contains('HVAC')) {
      icon = Icons.ac_unit_rounded;
      iconColor = const Color(0xFF0284C7);
    } else if (type.contains('AV')) {
      icon = Icons.connected_tv_rounded;
      iconColor = const Color(0xFFEC4899);
    } else if (type.contains('Electrical')) {
      icon = Icons.bolt_rounded;
      iconColor = const Color(0xFFF59E0B);
    } else if (type.contains('Plumbing')) {
      icon = Icons.water_drop_rounded;
      iconColor = const Color(0xFF0EA5E9);
    } else if (type.contains('Furniture')) {
      icon = Icons.chair_rounded;
      iconColor = const Color(0xFF8B5CF6);
    } else if (type.contains('Civil')) {
      icon = Icons.handyman_rounded;
      iconColor = const Color(0xFF64748B);
    } else if (type.contains('Sanitation')) {
      icon = Icons.cleaning_services_rounded;
      iconColor = const Color(0xFF10B981);
    } else {
      icon = Icons.wifi_rounded;
      iconColor = const Color(0xFF0284C7);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Text(
          type,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg;
    Color text;

    switch (priority.toLowerCase()) {
      case 'critical':
      case 'high':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFDC2626);
        break;
      case 'medium':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFD97706);
        break;
      default:
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF16A34A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(priority, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: text)),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;

    switch (status.toLowerCase()) {
      case 'in progress':
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF0284C7);
        break;
      case 'assigned':
        bg = const Color(0xFFEDE9FE);
        text = const Color(0xFF7C3AED);
        break;
      case 'scheduled':
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF475569);
        break;
      case 'resolved':
      case 'closed':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF16A34A);
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFD97706);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: text)),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<String>.fromMenuItems(
          value: value,
          isDense: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text('$label: $e', style: const TextStyle(fontSize: 11.5)))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          icon: const Icon(Icons.keyboard_arrow_down, size: 14),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    IconData? icon,
    Widget? headerTrailing,
    required Widget child,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: const Color(0xFF2563EB)),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
              ),
              const Spacer(),
              if (headerTrailing != null) headerTrailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
      ],
    );
  }

  // 1. Bar Chart: Trends
  Widget _buildTrendsChart(List<MaintenanceTrendsItem> trends, bool isDark) {
    final list = trends.isNotEmpty
        ? trends
        : [
            const MaintenanceTrendsItem(month: 'Sep', requests: 40, resolved: 32),
            const MaintenanceTrendsItem(month: 'Oct', requests: 58, resolved: 46),
            const MaintenanceTrendsItem(month: 'Nov', requests: 64, resolved: 52),
            const MaintenanceTrendsItem(month: 'Dec', requests: 70, resolved: 62),
            const MaintenanceTrendsItem(month: 'Jan', requests: 78, resolved: 68),
            const MaintenanceTrendsItem(month: 'Feb', requests: 82, resolved: 70),
            const MaintenanceTrendsItem(month: 'Mar', requests: 92, resolved: 78),
          ];

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Y-Axis markers
          const Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('100', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
              Text('80', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
              Text('60', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
              Text('40', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
              Text('20', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
              Text('0', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(width: 8),

          // Bars
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: list.map((item) {
                final reqHeight = (item.requests / 100.0) * 115;
                final resHeight = (item.resolved / 100.0) * 115;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 8,
                          height: reqHeight,
                          decoration: const BoxDecoration(
                            color: Color(0xFF38BDF8),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Container(
                          width: 8,
                          height: resHeight,
                          decoration: const BoxDecoration(
                            color: Color(0xFF818CF8),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.month,
                      style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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

  // 2. Donut Chart: Requests by Type
  Widget _buildCategoryDonut(List<MaintenanceCategoryShare> categories, bool isDark) {
    final list = categories.isNotEmpty
        ? categories
        : const [
            MaintenanceCategoryShare(type: 'HVAC (AC)', count: 84, pct: 26.9, color: Color(0xFF0284C7)),
            MaintenanceCategoryShare(type: 'Electrical', count: 58, pct: 18.6, color: Color(0xFF10B981)),
            MaintenanceCategoryShare(type: 'Plumbing', count: 38, pct: 12.2, color: Color(0xFFF59E0B)),
            MaintenanceCategoryShare(type: 'Civil / Building', count: 30, pct: 9.6, color: Color(0xFF8B5CF6)),
            MaintenanceCategoryShare(type: 'AV Equipment', count: 26, pct: 8.3, color: Color(0xFFEC4899)),
            MaintenanceCategoryShare(type: 'Others', count: 76, pct: 24.4, color: Color(0xFF06B6D4)),
          ];

    return SizedBox(
      height: 140,
      child: Row(
        children: [
          // Donut circle
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(110, 110),
                  painter: _DonutChartPainter(list),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '312',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Text('Requests', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Legend column
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: list.map((c) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(width: 7, height: 7, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.type,
                          style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${c.pct.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Progress Meters: SLA & Performance
  Widget _buildSlaMeters(MaintenanceSlaStats sla, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _slaMeterItem('Resolution within SLA', '${sla.resolutionWithinSlaPct}%', sla.resolutionWithinSlaPct / 100.0, const Color(0xFF16A34A), isDark),
        const SizedBox(height: 8),
        _slaMeterItem('Average Resolution Time', '${sla.avgResolutionDays} Days', math.min(sla.avgResolutionDays / 5.0, 1.0), const Color(0xFF2563EB), isDark),
        const SizedBox(height: 8),
        _slaMeterItem('Overdue Rate', '${sla.overdueRatePct}%', sla.overdueRatePct / 20.0, const Color(0xFFF59E0B), isDark),
        const SizedBox(height: 8),
        _slaMeterItem('First Response Time', '${sla.firstResponseHours} Hours', math.min(sla.firstResponseHours / 12.0, 1.0), const Color(0xFF0284C7), isDark),
      ],
    );
  }

  Widget _slaMeterItem(String label, String value, double progress, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
            Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<MaintenanceCategoryShare> categories;

  _DonutChartPainter(this.categories);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

    double startAngle = -math.pi / 2;
    final total = categories.fold<double>(0.0, (acc, c) => acc + c.pct);

    for (final c in categories) {
      final sweepAngle = (c.pct / (total > 0 ? total : 100.0)) * 2 * math.pi;
      final paint = Paint()
        ..color = c.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle - 0.03, // subtle gap
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}
