import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/visitor_models.dart';
import '../providers/visitors_provider.dart';
import '../utils/visitor_avatar_helper.dart';
import '../../../utils/js_helper.dart';
import 'dialogs/visitor_gate_pass_dialog.dart';
import 'dialogs/visitor_extend_dialog.dart';
import 'dialogs/visitor_restriction_dialog.dart';
import 'dialogs/visitor_schedule_dialog.dart';

class VisitorsDataTable extends ConsumerStatefulWidget {
  final Function(VisitorItem) onSelectVisitor;
  final Function(VisitorItem)? onEditVisitor;
  final VoidCallback? onExportCSV;

  const VisitorsDataTable({
    super.key,
    required this.onSelectVisitor,
    this.onEditVisitor,
    this.onExportCSV,
  });

  @override
  ConsumerState<VisitorsDataTable> createState() => _VisitorsDataTableState();
}

class _VisitorsDataTableState extends ConsumerState<VisitorsDataTable> {
  final Set<String> _selectedIds = {};
  final Set<String> _visibleColumns = {
    'Photo',
    'Type',
    'Purpose',
    'Location',
    'Host',
    'Check In',
    'Expected Out',
    'Status',
  };

  String _generateCsv(List<VisitorItem> items) {
    final buffer = StringBuffer();
    buffer.writeln('"Visit Number","Visitor Name","Visitor Type","Purpose","Location","Host","Check In","Expected Out","Status","Phone"');
    for (final item in items) {
      buffer.writeln([
        '"${item.visitNumber.replaceAll('"', '""')}"',
        '"${item.visitorName.replaceAll('"', '""')}"',
        '"${item.visitorType.replaceAll('"', '""')}"',
        '"${item.purpose.replaceAll('"', '""')}"',
        '"${item.location.replaceAll('"', '""')}"',
        '"${item.hostName.replaceAll('"', '""')}"',
        '"${item.checkInAt.replaceAll('"', '""')}"',
        '"${(item.expectedOutAt ?? '').replaceAll('"', '""')}"',
        '"${item.status.replaceAll('"', '""')}"',
        '"${item.phone.replaceAll('"', '""')}"',
      ].join(','));
    }
    return buffer.toString();
  }

  Future<void> _exportToCSV(
    BuildContext context,
    WidgetRef ref,
    VisitorsState state,
    List<VisitorItem> visits,
  ) async {
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);
    if (_selectedIds.isNotEmpty) {
      final selectedItems = visits.where((v) => _selectedIds.contains(v.id)).toList();
      final csvContent = _generateCsv(selectedItems);
      downloadCsvWeb(csvContent, 'Visitors_Selected_Log_$nowStr.csv');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${selectedItems.length} selected visitor records to CSV successfully!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } else {
      final api = ref.read(visitorsApiServiceProvider);
      final apiCsv = await api.exportVisitsCSVText(
        search: state.searchQuery,
        location: state.selectedLocation,
        category: state.selectedCategory,
        status: state.selectedStatus,
        dateFrom: state.startDate?.toIso8601String(),
        dateTo: state.endDate?.toIso8601String(),
      );
      final csvContent = apiCsv.trim().isNotEmpty ? apiCsv : _generateCsv(visits);
      downloadCsvWeb(csvContent, 'Visitors_Log_$nowStr.csv');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exported full visitors log to CSV successfully! Check your browser downloads.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(visitorsProvider);
    final notifier = ref.read(visitorsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visits = state.visits;
    final pagination = state.pagination;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Table Top Header: Title, Export, Bulk Actions, Columns
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Visitors (${pagination.totalRecords > 0 ? pagination.totalRecords : visits.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  if (_selectedIds.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_selectedIds.length} Selected',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => setState(() => _selectedIds.clear()),
                            child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF3B82F6)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 20),
                  // Export Button
                  OutlinedButton.icon(
                    onPressed: () => _exportToCSV(context, ref, state, visits),
                    icon: Icon(Icons.file_download_outlined, size: 15, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
                    label: Text(
                      _selectedIds.isNotEmpty ? 'Export Selected (${_selectedIds.length})' : 'Export CSV',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Bulk Actions Dropdown
                  PopupMenuButton<String>(
                    tooltip: 'Bulk Actions',
                    onSelected: (action) async {
                      if (_selectedIds.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select at least one visitor to perform bulk action.'),
                          ),
                        );
                        return;
                      }
                      if (action == 'checkout') {
                        final idsToCheckout = List<String>.from(_selectedIds);
                        setState(() => _selectedIds.clear());
                        await notifier.bulkCheckOutVisits(idsToCheckout);
                      } else if (action == 'print_passes') {
                        final selectedItems = visits.where((v) => _selectedIds.contains(v.id)).toList();
                        final passesList = selectedItems.map((v) {
                          final passNum = (v.passReference != null && v.passReference!.isNotEmpty)
                              ? v.passReference!
                              : 'GP-${v.visitNumber}';
                          return {
                            'pass_number': passNum,
                            'passNumber': passNum,
                            'visitor_name': v.visitorName,
                            'visitorName': v.visitorName,
                            'visitor_type': v.visitorType,
                            'visitorType': v.visitorType,
                            'phone': v.phone,
                            'destination': v.location,
                            'host_name': v.hostName,
                            'hostName': v.hostName,
                            'hostDepartment': v.hostDepartment,
                            'check_in_at': v.checkInAt,
                            'checkInAt': v.checkInAt,
                            'expires_at': v.expectedOutAt,
                            'validUntil': v.expectedOutAt,
                            'status': v.status,
                          };
                        }).toList();
                        printMultipleVisitorGatePassesHtml(passes: passesList);
                      } else if (action == 'clear') {
                        setState(() => _selectedIds.clear());
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'checkout',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF16A34A)),
                            SizedBox(width: 8),
                            Flexible(child: Text('Bulk Check-Out Selected')),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'print_passes',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.print_rounded, size: 16, color: Color(0xFF0284C7)),
                            SizedBox(width: 8),
                            Flexible(child: Text('Print Selected Passes')),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.clear_all_rounded, size: 16, color: Color(0xFFEF4444)),
                            SizedBox(width: 8),
                            Flexible(child: Text('Clear Selection')),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Bulk Actions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Column Customization icon
                PopupMenuButton<String>(
                  tooltip: 'Customize Columns',
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      enabled: false,
                      child: Text('Toggle Columns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    ...['Photo', 'Type', 'Purpose', 'Location', 'Host', 'Check In', 'Expected Out', 'Status'].map((col) {
                      return CheckedPopupMenuItem<String>(
                        value: col,
                        checked: _visibleColumns.contains(col),
                        child: Text(col, style: const TextStyle(fontSize: 12.5)),
                      );
                    }),
                  ],
                  onSelected: (col) {
                    setState(() {
                      if (_visibleColumns.contains(col)) {
                        if (_visibleColumns.length > 2) _visibleColumns.remove(col);
                      } else {
                        _visibleColumns.add(col);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.view_column_outlined, size: 18, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

          // 2. Scrollable Table Header & Rows with dynamic responsive width
          LayoutBuilder(
            builder: (context, constraints) {
              const minWidth = 1220.0;
              final tableWidth = math.max(constraints.maxWidth, minWidth);
              final extra = tableWidth > minWidth ? (tableWidth - minWidth) : 0.0;
              final nameWidth = 140.0 + (extra * 0.35);
              final purposeWidth = 130.0 + (extra * 0.25);
              final hostWidth = 140.0 + (extra * 0.40);
              final headerStyle = _getHeaderStyle(isDark);

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Builder(
                              builder: (context) {
                                final currentIds = visits.map((v) => v.id).toSet();
                                final allCurrentSelected = visits.isNotEmpty && currentIds.every((id) => _selectedIds.contains(id));
                                final someCurrentSelected = visits.isNotEmpty && currentIds.any((id) => _selectedIds.contains(id));

                                return SizedBox(
                                  width: 34,
                                  child: Checkbox(
                                    tristate: true,
                                    value: allCurrentSelected ? true : (someCurrentSelected ? null : false),
                                    onChanged: (val) {
                                      setState(() {
                                        if (allCurrentSelected) {
                                          _selectedIds.removeAll(currentIds);
                                        } else {
                                          _selectedIds.addAll(currentIds);
                                        }
                                      });
                                    },
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                );
                              },
                            ),
                            _buildSortableHeaderCell(
                              title: '#',
                              sortKey: 'created_at',
                              width: 32,
                              currentSortBy: state.visitsSortBy,
                              currentSortOrder: state.visitsSortOrder,
                              baseStyle: headerStyle,
                              onTap: () => notifier.sortVisits('created_at'),
                            ),
                            if (_visibleColumns.contains('Photo'))
                              SizedBox(width: 46, child: Text('Photo', style: headerStyle)),
                            _buildSortableHeaderCell(
                              title: 'Visitor Name',
                              sortKey: 'visitor_name',
                              width: nameWidth,
                              currentSortBy: state.visitsSortBy,
                              currentSortOrder: state.visitsSortOrder,
                              baseStyle: headerStyle,
                              onTap: () => notifier.sortVisits('visitor_name'),
                            ),
                            if (_visibleColumns.contains('Type'))
                              _buildSortableHeaderCell(
                                title: 'Type',
                                sortKey: 'category',
                                width: 85,
                                currentSortBy: state.visitsSortBy,
                                currentSortOrder: state.visitsSortOrder,
                                baseStyle: headerStyle,
                                onTap: () => notifier.sortVisits('category'),
                              ),
                            if (_visibleColumns.contains('Purpose'))
                              _buildSortableHeaderCell(
                                title: 'Purpose',
                                sortKey: 'purpose',
                                width: purposeWidth,
                                currentSortBy: state.visitsSortBy,
                                currentSortOrder: state.visitsSortOrder,
                                baseStyle: headerStyle,
                                onTap: () => notifier.sortVisits('purpose'),
                              ),
                            if (_visibleColumns.contains('Location'))
                              _buildSortableHeaderCell(
                                title: 'Location',
                                sortKey: 'destination',
                                width: 95,
                                currentSortBy: state.visitsSortBy,
                                currentSortOrder: state.visitsSortOrder,
                                baseStyle: headerStyle,
                                onTap: () => notifier.sortVisits('destination'),
                              ),
                            if (_visibleColumns.contains('Host'))
                              _buildSortableHeaderCell(
                                title: 'Host / Person to Meet',
                                sortKey: 'host_name',
                                width: hostWidth,
                                currentSortBy: state.visitsSortBy,
                                currentSortOrder: state.visitsSortOrder,
                                baseStyle: headerStyle,
                                onTap: () => notifier.sortVisits('host_name'),
                              ),
                            if (_visibleColumns.contains('Check In'))
                              _buildSortableHeaderCell(
                                title: 'Check In',
                                sortKey: 'entry_time',
                                width: 125,
                                currentSortBy: state.visitsSortBy,
                                currentSortOrder: state.visitsSortOrder,
                                baseStyle: headerStyle,
                                onTap: () => notifier.sortVisits('entry_time'),
                              ),
                            if (_visibleColumns.contains('Expected Out'))
                              _buildSortableHeaderCell(
                                title: 'Expected Out',
                                sortKey: 'expected_exit_time',
                                width: 125,
                                currentSortBy: state.visitsSortBy,
                                currentSortOrder: state.visitsSortOrder,
                                baseStyle: headerStyle,
                                onTap: () => notifier.sortVisits('expected_exit_time'),
                              ),
                            if (_visibleColumns.contains('Status'))
                              _buildSortableHeaderCell(
                                title: 'Status',
                                sortKey: 'status',
                                width: 85,
                                currentSortBy: state.visitsSortBy,
                                currentSortOrder: state.visitsSortOrder,
                                baseStyle: headerStyle,
                                onTap: () => notifier.sortVisits('status'),
                              ),
                            SizedBox(width: 110, child: Text('Actions', style: headerStyle, textAlign: TextAlign.center)),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

                  // Table Rows
                  if (visits.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.person_search_outlined, size: 40, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                          const SizedBox(height: 10),
                          Text(
                            'No visitor records found',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try adjusting your filters or register a new visitor.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      itemCount: visits.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        final item = visits[index];
                        final isSelected = _selectedIds.contains(item.id);
                        final isCurrentInspected = state.selectedVisit?.id == item.id;

                        return InkWell(
                          onTap: () => widget.onSelectVisitor(item),
                          child: Container(
                            color: isCurrentInspected
                                ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
                                : (isSelected
                                    ? (isDark ? const Color(0xFF334155).withValues(alpha: 0.2) : const Color(0xFFF8FAFC))
                                    : Colors.transparent),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                // Checkbox
                                SizedBox(
                                  width: 34,
                                  child: Checkbox(
                                    value: isSelected,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedIds.add(item.id);
                                        } else {
                                          _selectedIds.remove(item.id);
                                        }
                                      });
                                    },
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                // Index
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '${(pagination.page - 1) * pagination.pageSize + index + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                // Photo
                                if (_visibleColumns.contains('Photo'))
                                  SizedBox(
                                    width: 46,
                                    child: VisitorAvatar(
                                      photoUrl: item.photoUrl,
                                      name: item.visitorName,
                                      radius: 15,
                                      fontSize: 11,
                                    ),
                                  ),
                                // Visitor Name
                                SizedBox(
                                  width: nameWidth,
                                  child: Text(
                                    item.visitorName,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Type
                                if (_visibleColumns.contains('Type'))
                                  SizedBox(
                                    width: 85,
                                    child: _buildTypeBadge(item.category),
                                  ),
                                // Purpose
                                if (_visibleColumns.contains('Purpose'))
                                  SizedBox(
                                    width: purposeWidth,
                                    child: Text(
                                      item.purpose,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                // Location
                                if (_visibleColumns.contains('Location'))
                                  SizedBox(
                                    width: 95,
                                    child: Text(
                                      item.location,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                // Host / Person to Meet
                                if (_visibleColumns.contains('Host'))
                                  SizedBox(
                                    width: hostWidth,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          item.hostName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (item.hostDepartment != null && item.hostDepartment!.isNotEmpty)
                                          Text(
                                            item.hostDepartment!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                // Check In
                                if (_visibleColumns.contains('Check In'))
                                  SizedBox(
                                    width: 125,
                                    child: Text(
                                      _formatDateTime(item.checkInAt),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                // Expected Out
                                if (_visibleColumns.contains('Expected Out'))
                                  SizedBox(
                                    width: 125,
                                    child: Text(
                                      _formatDateTime(item.expectedOutAt),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                // Status
                                if (_visibleColumns.contains('Status'))
                                  SizedBox(
                                    width: 85,
                                    child: _buildStatusBadge(item.status, isDark),
                                  ),
                                // Actions
                                SizedBox(
                                  width: 110,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      InkWell(
                                        onTap: () => widget.onSelectVisitor(item),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Icon(Icons.visibility_outlined, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () => widget.onEditVisitor?.call(item),
                                        borderRadius: BorderRadius.circular(4),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Builder(
                                        builder: (ctx) {
                                          final isBlocked = item.status.toLowerCase() == 'blocked' ||
                                              item.status.toLowerCase() == 'blacklisted' ||
                                              item.status.toLowerCase() == 'restricted';

                                          return PopupMenuButton<String>(
                                            icon: Icon(Icons.more_vert, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                            onSelected: (val) async {
                                              if (val == 'unblock') {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (dialogCtx) => AlertDialog(
                                                    title: const Text('Unblock Visitor'),
                                                    content: Text('Lift security restriction and unblock access for ${item.visitorName}?'),
                                                    actions: [
                                                      TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
                                                      ElevatedButton(
                                                        onPressed: () => Navigator.pop(dialogCtx, true),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF16A34A),
                                                          foregroundColor: Colors.white,
                                                        ),
                                                        child: const Text('Confirm Unblock'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true) {
                                                  await notifier.unblockVisitor(item.visitorId.isNotEmpty ? item.visitorId : item.id);
                                                }
                                              } else if (val == 'view_details') {
                                                widget.onSelectVisitor(item);
                                              } else if (val == 'gate_pass') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => VisitorGatePassDialog(visit: item),
                                                );
                                              } else if (val == 'extend') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => VisitorExtendDialog(visit: item),
                                                );
                                              } else if (val == 'checkout') {
                                                notifier.checkOutVisit(item.id);
                                              } else if (val == 'schedule') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => VisitorScheduleDialog(initialVisitor: item),
                                                );
                                              } else if (val == 'blacklist') {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => VisitorRestrictionDialog(initialVisitor: item),
                                                );
                                              }
                                            },
                                            itemBuilder: (ctx) {
                                              if (isBlocked) {
                                                return [
                                                  const PopupMenuItem(
                                                    value: 'unblock',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.lock_open_rounded, size: 16, color: Color(0xFF16A34A)),
                                                        SizedBox(width: 8),
                                                        Text('Unblock Visitor', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                                                      ],
                                                    ),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'view_details',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF2563EB)),
                                                        SizedBox(width: 8),
                                                        Text('View Details'),
                                                      ],
                                                    ),
                                                  ),
                                                ];
                                              }
                                              return [
                                                const PopupMenuItem(
                                                  value: 'gate_pass',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.badge_outlined, size: 16, color: Color(0xFF0284C7)),
                                                      SizedBox(width: 8),
                                                      Text('Print Gate Pass'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'schedule',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF9333EA)),
                                                      SizedBox(width: 8),
                                                      Text('Schedule Appointment'),
                                                    ],
                                                  ),
                                                ),
                                                if (item.status.toLowerCase() == 'inside' || item.status.toLowerCase() == 'overstay') ...[
                                                  const PopupMenuItem(
                                                    value: 'extend',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.more_time_rounded, size: 16, color: Color(0xFF2563EB)),
                                                        SizedBox(width: 8),
                                                        Text('Extend Visit'),
                                                      ],
                                                    ),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'checkout',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.exit_to_app_rounded, size: 16, color: Color(0xFF16A34A)),
                                                        SizedBox(width: 8),
                                                        Text('Check Out'),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                const PopupMenuDivider(),
                                                const PopupMenuItem(
                                                  value: 'blacklist',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.block_rounded, size: 16, color: Color(0xFFDC2626)),
                                                      SizedBox(width: 8),
                                                      Text('Blacklist Visitor', style: TextStyle(color: Color(0xFFDC2626))),
                                                    ],
                                                  ),
                                                ),
                                              ];
                                            },
                                          );
                                        },
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
        },
      ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // 3. Bottom Pagination
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Showing ${pagination.totalRecords == 0 ? 0 : (pagination.page - 1) * pagination.pageSize + 1} - ${(pagination.page * pagination.pageSize).clamp(0, pagination.totalRecords)} of ${pagination.totalRecords} visitors',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Page navigator buttons
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    onPressed: pagination.page > 1 ? () => notifier.fetchVisits(page: pagination.page - 1) : null,
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
                      '${pagination.page}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    onPressed: pagination.page < pagination.totalPages
                        ? () => notifier.fetchVisits(page: pagination.page + 1)
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    'Rows per page',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: [10, 25, 50, 100].contains(pagination.pageSize) ? pagination.pageSize : 10,
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
                            notifier.fetchVisits(page: 1, pageSize: val);
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

  static TextStyle _getHeaderStyle(bool isDark) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
    letterSpacing: 0.2,
  );

  Widget _buildTypeBadge(String type) {
    Color bg;
    Color text;
    switch (type.toLowerCase()) {
      case 'parent':
        bg = const Color(0xFFDBEAFE);
        text = const Color(0xFF1D4ED8);
        break;
      case 'official':
        bg = const Color(0xFFF3E8FF);
        text = const Color(0xFF7E22CE);
        break;
      case 'vendor':
        bg = const Color(0xFFFFEDD5);
        text = const Color(0xFFC2410C);
        break;
      case 'relative':
        bg = const Color(0xFFCFFAFE);
        text = const Color(0xFF0E7490);
        break;
      case 'delivery':
        bg = const Color(0xFFFFE4E6);
        text = const Color(0xFFBE123C);
        break;
      case 'maintenance':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        break;
      case 'alumni':
        bg = const Color(0xFFFCE7F3);
        text = const Color(0xFFBE185D);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(
        type,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bg;
    Color text;
    switch (status.toLowerCase()) {
      case 'inside':
        bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
        text = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D);
        break;
      case 'checked out':
        bg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
        text = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF64748B);
        break;
      case 'overstay':
        bg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
        text = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
        break;
      case 'blocked':
      case 'blacklisted':
      case 'restricted':
        bg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
        text = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
        break;
      default:
        bg = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
        text = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}\n${hour.toString().padLeft(2, '0')}:$min $ampm';
    } catch (_) {
      return raw;
    }
  }

  Widget _buildSortableHeaderCell({
    required String title,
    required String sortKey,
    required double width,
    required String currentSortBy,
    required String currentSortOrder,
    required TextStyle baseStyle,
    required VoidCallback onTap,
  }) {
    final isSorted = currentSortBy.toLowerCase() == sortKey.toLowerCase();
    final isAsc = currentSortOrder.toUpperCase() == 'ASC';

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
                style: baseStyle.copyWith(
                  color: isSorted ? const Color(0xFF2563EB) : null,
                  fontWeight: isSorted ? FontWeight.w800 : null,
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
