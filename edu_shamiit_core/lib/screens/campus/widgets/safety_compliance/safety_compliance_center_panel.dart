import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/safety_compliance_provider.dart';
import '../common/campus_pagination_bar.dart';

class SafetyComplianceCenterPanel extends ConsumerStatefulWidget {
  final VoidCallback onOpenLogInspection;
  final VoidCallback onOpenReportIncident;
  final VoidCallback onOpenAddCertificate;
  final VoidCallback onOpenScheduleDrill;
  final Function(dynamic item)? onInspectItem;
  final Function(dynamic item)? onEditItem;

  const SafetyComplianceCenterPanel({
    super.key,
    required this.onOpenLogInspection,
    required this.onOpenReportIncident,
    required this.onOpenAddCertificate,
    required this.onOpenScheduleDrill,
    this.onInspectItem,
    this.onEditItem,
  });

  @override
  ConsumerState<SafetyComplianceCenterPanel> createState() => _SafetyComplianceCenterPanelState();
}

class _SafetyComplianceCenterPanelState extends ConsumerState<SafetyComplianceCenterPanel> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(safetyComplianceProvider);
    final notifier = ref.read(safetyComplianceProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Sub-Tabs Bar (Inspections, Incidents, Certificates, Drills)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                return isNarrow
                    ? Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildSubTabItem(0, 'Inspections', state.inspections.totalCount, isDark, state.activeSubTab == 0)),
                              Expanded(child: _buildSubTabItem(1, 'Incidents', state.incidents.totalCount, isDark, state.activeSubTab == 1)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(child: _buildSubTabItem(2, 'Certificates', state.certificates.totalCount, isDark, state.activeSubTab == 2)),
                              Expanded(child: _buildSubTabItem(3, 'Emergency Drills', state.drills.totalCount, isDark, state.activeSubTab == 3)),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _buildSubTabItem(0, 'Safety Inspections', state.inspections.totalCount, isDark, state.activeSubTab == 0)),
                          Expanded(child: _buildSubTabItem(1, 'Incident Reports', state.incidents.totalCount, isDark, state.activeSubTab == 1)),
                          Expanded(child: _buildSubTabItem(2, 'Statutory Certificates', state.certificates.totalCount, isDark, state.activeSubTab == 2)),
                          Expanded(child: _buildSubTabItem(3, 'Emergency Drills', state.drills.totalCount, isDark, state.activeSubTab == 3)),
                        ],
                      );
              },
            ),
          ),
          const SizedBox(height: 14),

          // 2. Data Card (Search, Filters, Data Table, Pagination)
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Search & Filter Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // Search box
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (v) => notifier.setSearchQuery(v),
                          decoration: InputDecoration(
                            hintText: 'Search by title, code, location...',
                            hintStyle: TextStyle(fontSize: 12, color: textMuted),
                            prefixIcon: Icon(Icons.search, size: 17, color: textMuted),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      notifier.setSearchQuery('');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                          style: TextStyle(fontSize: 12.5, color: textPrimary),
                        ),
                      ),

                      // Status Filter Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: Builder(
                            builder: (context) {
                              final options = _getStatusDropdownOptions(state.activeSubTab);
                              final currentVal = options.contains(state.selectedStatus) ? state.selectedStatus : options.first;
                              return DropdownButton<String>(
                                value: currentVal,
                                isDense: true,
                                dropdownColor: cardBg,
                                icon: Icon(Icons.keyboard_arrow_down, size: 16, color: textMuted),
                                items: options
                                    .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s, style: TextStyle(fontSize: 12, color: textPrimary)),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) notifier.setStatus(v);
                                },
                              );
                            },
                          ),
                        ),
                      ),

                      // Action Buttons: + Add & Export
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.file_download_outlined, size: 18),
                            tooltip: 'Export CSV',
                            color: const Color(0xFF2563EB),
                            onPressed: () {
                              final types = ['inspections', 'incidents', 'certificates', 'drills'];
                              notifier.exportData(types[state.activeSubTab]);
                            },
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton.icon(
                            onPressed: () => _triggerAddModal(state.activeSubTab),
                            icon: const Icon(Icons.add, size: 15, color: Colors.white),
                            label: Text(
                              _getAddButtonLabel(state.activeSubTab),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: state.activeSubTab == 1 ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // Table View depending on active sub-tab
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _buildTableForSubTab(state, notifier, isDark),

                const Divider(height: 1, thickness: 1),

                // Pagination Footer
                _buildPaginationFooter(state, notifier, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabItem(int index, String title, int count, bool isDark, bool isSelected) {
    return InkWell(
      onTap: () => ref.read(safetyComplianceProvider.notifier).setActiveSubTab(index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF2563EB) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected && !isDark
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF2563EB))
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFEFF6FF))
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF2563EB))
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getStatusDropdownOptions(int subTab) {
    if (subTab == 0) return ['All', 'Passed', 'Needs Attention', 'Critical Action', 'Scheduled'];
    if (subTab == 1) return ['All', 'Reported', 'Under Investigation', 'Action Taken', 'Resolved', 'Closed'];
    if (subTab == 2) return ['All', 'Valid', 'Expiring Soon', 'Expired', 'Renewal Pending'];
    return ['All', 'Scheduled', 'Completed', 'Cancelled'];
  }

  String _getAddButtonLabel(int subTab) {
    if (subTab == 0) return 'Log Inspection';
    if (subTab == 1) return 'Report Incident';
    if (subTab == 2) return 'Add Certificate';
    return 'Schedule Drill';
  }

  void _triggerAddModal(int subTab) {
    if (subTab == 0) widget.onOpenLogInspection();
    if (subTab == 1) widget.onOpenReportIncident();
    if (subTab == 2) widget.onOpenAddCertificate();
    if (subTab == 3) widget.onOpenScheduleDrill();
  }

  Widget _buildTableForSubTab(SafetyComplianceState state, SafetyComplianceNotifier notifier, bool isDark) {
    if (state.activeSubTab == 0) {
      return _buildInspectionsTable(state, isDark);
    } else if (state.activeSubTab == 1) {
      return _buildIncidentsTable(state, isDark);
    } else if (state.activeSubTab == 2) {
      return _buildCertificatesTable(state, isDark);
    } else {
      return _buildDrillsTable(state, isDark);
    }
  }

  // 1. Inspections Table
  Widget _buildInspectionsTable(SafetyComplianceState state, bool isDark) {
    final list = state.inspections.records;
    if (list.isEmpty) return _buildEmptyTable('No safety inspections found.');

    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        border: TableBorder(horizontalInside: BorderSide(color: borderColor, width: 0.8)),
        headingRowColor: WidgetStateProperty.all(headerBg),
        headingRowHeight: 40,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 60,
        columnSpacing: 18,
        columns: [
          DataColumn(label: Text('# Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Inspection Title / Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Inspector', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Score', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
        ],
        rows: list.map((item) {
          final isPassed = item.status.toLowerCase() == 'passed';
          final statusColor = isPassed ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

          return DataRow(
            cells: [
              DataCell(Text(item.inspectionCode, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary))),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 2),
                      Text(item.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: textMuted)),
                    ],
                  ),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(item.locationDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textPrimary)),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.inspectorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textPrimary)),
                      const SizedBox(height: 2),
                      Text(item.inspectorRole, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: textMuted)),
                    ],
                  ),
                ),
              ),
              DataCell(Text('${item.inspectionDate.day}/${item.inspectionDate.month}/${item.inspectionDate.year}', style: TextStyle(fontSize: 12, color: textMuted))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(item.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ),
              DataCell(
                Text(
                  '${item.complianceScore.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: item.complianceScore >= 90 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      tooltip: 'View Details',
                      onPressed: () => widget.onInspectItem?.call(item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      tooltip: 'Edit',
                      onPressed: () => widget.onEditItem?.call(item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(context, 'inspection', item.id, item.inspectionCode),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // 2. Incidents Table
  Widget _buildIncidentsTable(SafetyComplianceState state, bool isDark) {
    final list = state.incidents.records;
    if (list.isEmpty) return _buildEmptyTable('No safety incidents reported.');

    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        border: TableBorder(horizontalInside: BorderSide(color: borderColor, width: 0.8)),
        headingRowColor: WidgetStateProperty.all(headerBg),
        headingRowHeight: 40,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 60,
        columnSpacing: 18,
        columns: [
          DataColumn(label: Text('# Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Incident / Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Severity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Reported By', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Date & Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
        ],
        rows: list.map((item) {
          final isCritical = item.severity.toLowerCase() == 'critical';
          final isHigh = item.severity.toLowerCase() == 'high';
          final sevColor = isCritical
              ? const Color(0xFFDC2626)
              : (isHigh ? const Color(0xFFEA580C) : const Color(0xFF2563EB));

          return DataRow(
            cells: [
              DataCell(Text(item.incidentCode, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary))),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 2),
                      Text(item.incidentType, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: textMuted)),
                    ],
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sevColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(item.severity, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sevColor)),
                ),
              ),
              DataCell(Text(item.locationDisplay, style: TextStyle(fontSize: 12, color: textPrimary))),
              DataCell(Text(item.reportedByName, style: TextStyle(fontSize: 12, color: textPrimary))),
              DataCell(Text('${item.incidentTime.day}/${item.incidentTime.month} ${item.incidentTime.hour.toString().padLeft(2, '0')}:${item.incidentTime.minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 11.5, color: textMuted))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.status == 'Resolved'
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: item.status == 'Resolved' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      tooltip: 'View Details',
                      onPressed: () => widget.onInspectItem?.call(item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      tooltip: 'Edit / Resolve',
                      onPressed: () => widget.onEditItem?.call(item),
                    ),
                    if (item.severity == 'Critical')
                      IconButton(
                        icon: const Icon(Icons.emergency_share_rounded, size: 16, color: Color(0xFFEF4444)),
                        tooltip: 'Dispatch Life Safety IoT Interlock (Unlock Doors, Trip HVAC, Sound Sirens)',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Trigger Emergency Life Safety Interlock'),
                              content: Text('Are you sure you want to trigger emergency evacuation override for incident ${item.incidentCode}? This will immediately unlock all magnetic doors, stop ventilation to prevent smoke propagation, and activate campus alarm beacons.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('DISPATCH EMERGENCY OVERRIDE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final res = await ref.read(safetyComplianceProvider.notifier).triggerEmergencyOverride(item.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message']?.toString() ?? 'Emergency override dispatched!'),
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(context, 'incident', item.id, item.incidentCode),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // 3. Certificates Table
  Widget _buildCertificatesTable(SafetyComplianceState state, bool isDark) {
    final list = state.certificates.records;
    if (list.isEmpty) return _buildEmptyTable('No statutory compliance certificates found.');

    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        border: TableBorder(horizontalInside: BorderSide(color: borderColor, width: 0.8)),
        headingRowColor: WidgetStateProperty.all(headerBg),
        headingRowHeight: 40,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 60,
        columnSpacing: 18,
        columns: [
          DataColumn(label: Text('# Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Certificate Title / Authority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('License / Reg No.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Expiry Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Validity Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
        ],
        rows: list.map((item) {
          final isExpiring = item.status.toLowerCase() == 'expiring soon';
          final isExpired = item.status.toLowerCase() == 'expired';
          final statusColor = isExpired
              ? const Color(0xFFEF4444)
              : (isExpiring ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

          return DataRow(
            cells: [
              DataCell(Text(item.certificateCode, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary))),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 2),
                      Text(item.issuingAuthority, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: textMuted)),
                    ],
                  ),
                ),
              ),
              DataCell(Text(item.category, style: TextStyle(fontSize: 12, color: textPrimary))),
              DataCell(Text(item.certificateNumber, style: TextStyle(fontSize: 12, color: textMuted))),
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${item.expiryDate.day}/${item.expiryDate.month}/${item.expiryDate.year}', style: TextStyle(fontSize: 12, color: textPrimary)),
                    Text(
                      item.daysToExpiry > 0 ? '${item.daysToExpiry} days left' : 'Expired',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                    ),
                  ],
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(item.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      tooltip: 'View Details',
                      onPressed: () => widget.onInspectItem?.call(item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      tooltip: 'Edit / Renew',
                      onPressed: () => widget.onEditItem?.call(item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(context, 'certificate', item.id, item.certificateCode),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // 4. Drills Table
  Widget _buildDrillsTable(SafetyComplianceState state, bool isDark) {
    final list = state.drills.records;
    if (list.isEmpty) return _buildEmptyTable('No emergency drills found.');

    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        border: TableBorder(horizontalInside: BorderSide(color: borderColor, width: 0.8)),
        headingRowColor: WidgetStateProperty.all(headerBg),
        headingRowHeight: 40,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 60,
        columnSpacing: 18,
        columns: [
          DataColumn(label: Text('# Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Drill Title / Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Scheduled / Conducted', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Participants', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Evac Time / Target', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Rating / Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
          DataColumn(label: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted))),
        ],
        rows: list.map((item) {
          final isCompleted = item.status.toLowerCase() == 'completed';
          final statusColor = isCompleted ? const Color(0xFF10B981) : const Color(0xFF2563EB);

          return DataRow(
            cells: [
              DataCell(Text(item.drillCode, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary))),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 2),
                      Text(item.drillType, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: textMuted)),
                    ],
                  ),
                ),
              ),
              DataCell(Text(item.locationDisplay, style: TextStyle(fontSize: 12, color: textPrimary))),
              DataCell(
                Text(
                  '${item.scheduledDate.day}/${item.scheduledDate.month}/${item.scheduledDate.year}',
                  style: TextStyle(fontSize: 12, color: textPrimary),
                ),
              ),
              DataCell(Text('${item.participantsCount}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary))),
              DataCell(
                Text(
                  item.evacuationTimeSeconds > 0
                      ? '${item.evacuationTimeSeconds}s / ${item.targetTimeSeconds}s'
                      : 'Target: ${item.targetTimeSeconds}s',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: item.evacuationTimeSeconds <= item.targetTimeSeconds ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${item.performanceRating} (${item.status})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      tooltip: 'View Details',
                      onPressed: () => widget.onInspectItem?.call(item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      tooltip: 'Edit / Log Outcome',
                      onPressed: () => widget.onEditItem?.call(item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(context, 'drill', item.id, item.drillCode),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyTable(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.shield_outlined, size: 44, color: Colors.grey.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(SafetyComplianceState state, SafetyComplianceNotifier notifier, bool isDark) {
    int totalCount = 0;
    String label = 'inspections';
    if (state.activeSubTab == 0) {
      totalCount = state.inspections.totalCount;
      label = 'inspections';
    } else if (state.activeSubTab == 1) {
      totalCount = state.incidents.totalCount;
      label = 'incidents';
    } else if (state.activeSubTab == 2) {
      totalCount = state.certificates.totalCount;
      label = 'certificates';
    } else {
      totalCount = state.drills.totalCount;
      label = 'drills';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: CampusPaginationBar(
        currentPage: state.currentPage,
        pageSize: state.pageSize,
        totalItems: totalCount,
        onPageChanged: (newPage) => notifier.setPage(newPage),
        onPageSizeChanged: (newSize) => notifier.setPageSize(newSize),
        itemLabel: label,
      ),
    );
  }

  void _confirmDelete(BuildContext context, String entityType, String entityId, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $code?'),
        content: Text('Are you sure you want to remove this $entityType from safety records?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              Navigator.pop(ctx);
              final notifier = ref.read(safetyComplianceProvider.notifier);
              if (entityType == 'inspection') {
                notifier.deleteInspection(entityId);
              } else if (entityType == 'incident') {
                notifier.deleteIncident(entityId);
              } else if (entityType == 'certificate') {
                notifier.deleteCertificate(entityId);
              } else if (entityType == 'drill') {
                notifier.deleteDrill(entityId);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
