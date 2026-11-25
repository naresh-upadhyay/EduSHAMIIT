import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/campus_reports_provider.dart';
import '../common/campus_pagination_bar.dart';

class CampusReportsTabView extends ConsumerStatefulWidget {
  const CampusReportsTabView({super.key});

  @override
  ConsumerState<CampusReportsTabView> createState() => _CampusReportsTabViewState();
}

class _CampusReportsTabViewState extends ConsumerState<CampusReportsTabView> {
  final List<String> _timeRanges = [
    'Today',
    'Last 7 Days',
    'Last 30 Days',
    'Current Semester',
    'Current Academic Year',
  ];

  late TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    final repState = ref.read(campusReportsProvider);
    _searchCtrl = TextEditingController(text: repState.searchQuery);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _exportReport() {
    ref.read(campusReportsProvider.notifier).exportCsv();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exporting Institutional Campus Report as CSV...'),
        backgroundColor: Color(0xFF059669),
      ),
    );
  }

  void _generatePdfDossier() {
    final repState = ref.read(campusReportsProvider);
    final repNotifier = ref.read(campusReportsProvider.notifier);

    String title;
    List<String> kpiTitles = [];
    List<String> kpiValues = [];
    List<String> headers = [];
    List<List<String>> rows = [];

    switch (repState.selectedReportType) {
      case 0:
        title = 'Space & Room Utilization Audit';
        kpiTitles = ['Total Bookable Spaces', 'Avg Room Utilization', 'Peak Demand Windows', 'Available Capacity'];
        kpiValues = ['48 Spaces', '74.6%', '09:00 AM - 11:30 AM', '1,198 Seats'];
        headers = ['Building', 'Space / Room', 'Type', 'Capacity', 'Utilization Rate', 'Booked Hours', 'Demand Tier'];
        rows = [
          ['B1 - Academic Block (A)', 'Auditorium (A1-101)', 'Auditorium', '250 seats', '84.2%', '38.5 hrs/wk', 'High Demand'],
          ['B1 - Academic Block (A)', 'Computer Lab (A1-105)', 'Computer Lab', '60 seats', '79.1%', '34.0 hrs/wk', 'Optimal'],
          ['B1 - Academic Block (A)', 'Classroom 201', 'Classroom', '45 seats', '91.4%', '41.0 hrs/wk', 'Peak Usage'],
          ['B2 - Academic Block (B)', 'Physics Lab 102', 'Physics Lab', '40 seats', '68.5%', '28.0 hrs/wk', 'Available'],
          ['B3 - Library Block', 'Digital Reading Hall', 'Digital Library', '120 seats', '86.0%', '52.0 hrs/wk', 'High Demand'],
          ['B4 - Auditorium Block', 'Seminar Room 01', 'Seminar Hall', '80 seats', '54.0%', '21.5 hrs/wk', 'Underutilized'],
        ];
        break;
      case 1:
        title = 'Institutional Asset & Equipment Health Audit';
        kpiTitles = ['Tracked Assets', 'Asset Health Index', 'Service Overdue', 'Annual Depreciation'];
        kpiValues = ['3,480 Units', '94.2%', '18 Items', '₹ 14.8 Lakhs'];
        headers = ['Asset Code', 'Equipment Name', 'Location', 'Condition', 'Operational Status', 'Warranty / AMC'];
        rows = [
          ['AST-0104', '4K Laser Digital Projector', 'Auditorium (A1-101)', 'Excellent', 'Operational', 'Valid till Dec 2027'],
          ['AST-0220', 'High-Performance Workstation Cluster', 'Computer Lab 1', 'Good', 'Operational', 'Under Dell ProSupport'],
          ['AST-0341', 'Compound Binocular Microscopes (x20)', 'Biology Lab', 'Good', 'Operational', 'Inspected Nov 2026'],
          ['AST-0418', 'Central Air Handling Unit (AHU-02)', 'Academic Block B', 'Fair', 'Service Due', 'AMC Active (Voltas)'],
        ];
        break;
      case 2:
        title = 'Campus Maintenance & Work Order SLA Performance';
        kpiTitles = ['Total Work Orders', 'SLA Compliance Rate', 'Mean Time to Resolve', 'Total AMC Expenditure'];
        kpiValues = ['142 Orders', '96.4%', '3.8 Hours', '₹ 2.45 Lakhs'];
        headers = ['Ticket Code', 'Title / Issue', 'Location', 'Priority', 'Status', 'Resolution Time', 'Assigned To'];
        rows = [
          ['MT-0588', 'AC cooling malfunction in Lab-1', 'B1 / G-101', 'High', 'In Progress', '1.2 Hours Active', 'Rohan Verma'],
          ['MT-0565', 'Water pressure drop in washroom', 'B3 / GF-WR1', 'High', 'Resolved', '2.5 Hours MTTR', 'Priya Nair'],
          ['MT-0550', 'Network switch port amber LED', 'B1 / Server Room', 'Medium', 'Resolved', '45 Mins MTTR', 'Network Team'],
        ];
        break;
      case 3:
        title = 'Statutory Safety NOC, Inspections & Evacuation Compliance';
        kpiTitles = ['Active Statutory NOCs', 'Next Expiring Cert', 'Emergency Drills Held', 'Open Safety Hazards'];
        kpiValues = ['6 of 6 Valid', 'Dec 31, 2028', '4 Drills', '0 Critical'];
        headers = ['Inspection Code', 'Audit Title', 'Category', 'Overall Score', 'Status', 'Inspector', 'Audit Date'];
        rows = [
          ['INS-2026-001', 'Annual Campus Fire Safety & Hydrant Audit', 'Fire Safety', '96.5%', 'Passed', 'Chief Fire Marshal', '15 Nov 2026'],
          ['INS-2026-002', 'Potable Drinking Water & Chemical Analysis', 'Water Quality', '98.0%', 'Certified Pure', 'District Public Health Lab', '10 Nov 2026'],
          ['INS-2026-003', 'Substation Earthing & Transformer Load Audit', 'Electrical', '94.0%', 'Compliant', 'State Electrical Inspector', '02 Nov 2026'],
        ];
        break;
      default:
        title = 'Campus Energy, Solar Yield & Water Footprint Audit';
        kpiTitles = ['Grid Electricity', 'Solar Generation', 'Water Consumption', 'Carbon Footprint'];
        kpiValues = ['45,210 kWh', '12,480 kWh', '1.85 Lakh L', '36.8 MT CO2'];
        headers = ['Infrastructure Substation', 'Type', 'Recorded Consumption', 'Baseline Comparison', 'Status'];
        rows = [
          ['Main Substation 33kV', 'Grid Power', '45,210 kWh MTD', '+2.4% vs last cycle', 'Normal'],
          ['Rooftop Solar PV Array', 'Solar Power', '320.4 kWh / day', '42% Campus Offset', 'Optimal'],
          ['Central Underground Sump', 'Municipal Water', '85,000 Litres (85%)', 'Recharged from Rainwater', 'Adequate'],
        ];
        break;
    }

    repNotifier.generateExecutiveDossier(
      reportTitle: title,
      kpiTitles: kpiTitles,
      kpiValues: kpiValues,
      headers: headers,
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    final bgCard = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final repState = ref.watch(campusReportsProvider);
    final repNotifier = ref.read(campusReportsProvider.notifier);

    final selectedReportType = repState.selectedReportType;
    final timeRange = repState.timeRange;
    final selectedBuildingId = repState.selectedBuildingId;
    final buildings = repState.buildings;
    final searchQuery = repState.searchQuery;
    final page = repState.currentPage;
    final pageSize = repState.pageSize;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Report Category Selector
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildReportTypeChip(0, 'Space & Room Utilization', Icons.pie_chart_rounded, primaryColor, isDark, selectedReportType, repNotifier),
                  const SizedBox(width: 8),
                  _buildReportTypeChip(1, 'Asset & Equipment Health', Icons.precision_manufacturing_rounded, primaryColor, isDark, selectedReportType, repNotifier),
                  const SizedBox(width: 8),
                  _buildReportTypeChip(2, 'Maintenance & SLA Performance', Icons.build_circle_rounded, primaryColor, isDark, selectedReportType, repNotifier),
                  const SizedBox(width: 8),
                  _buildReportTypeChip(3, 'Safety & Compliance Audit', Icons.verified_user_rounded, primaryColor, isDark, selectedReportType, repNotifier),
                  const SizedBox(width: 8),
                  _buildReportTypeChip(4, 'Energy & Utility Footprint', Icons.electric_bolt_rounded, primaryColor, isDark, selectedReportType, repNotifier),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Report Filters and Export Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // Time Range Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: AppSearchableDropdown<String>.fromMenuItems(
                      value: timeRange,
                      isDense: true,
                      dropdownColor: bgCard,
                      items: _timeRanges
                          .map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 12, color: textPrimary))))
                          .toList(),
                      onChanged: (v) => repNotifier.setTimeRange(v ?? timeRange),
                    ),
                  ),
                ),

                // Building Scope Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: AppSearchableDropdown<String?>.fromMenuItems(
                      value: (selectedBuildingId != null && buildings.any((b) => b.id == selectedBuildingId))
                          ? selectedBuildingId
                          : null,
                      isDense: true,
                      dropdownColor: bgCard,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Campus Infrastructure', style: TextStyle(fontSize: 12))),
                        ...buildings.map((b) => DropdownMenuItem(
                              value: b.id,
                              child: Text('${b.code} - ${b.name}', style: TextStyle(fontSize: 12, color: textPrimary)),
                            )),
                      ],
                      onChanged: (v) => repNotifier.setBuildingId(v),
                    ),
                  ),
                ),

                // Search Box
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => repNotifier.setSearchQuery(v),
                    decoration: InputDecoration(
                      hintText: 'Search records...',
                      hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
                    ),
                    style: TextStyle(fontSize: 12.5, color: textPrimary),
                  ),
                ),

                // Dual Export Actions: CSV & Executive PDF Dossier
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _exportReport,
                      icon: const Icon(Icons.table_chart_outlined, size: 16),
                      label: const Text('Export CSV', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _generatePdfDossier,
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.white),
                      label: const Text('Executive PDF Dossier', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Report Summary KPIs
          _buildReportSummaryKpis(selectedReportType, primaryColor, isDark),
          const SizedBox(height: 14),

          // 4. Report Interactive Data Table
          Container(
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.assessment_rounded, size: 18, color: primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        _getReportTitle(selectedReportType),
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textPrimary),
                      ),
                      const Spacer(),
                      Text('Period: $timeRange', style: TextStyle(fontSize: 12, color: textSecondary)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _buildReportTable(selectedReportType, searchQuery, page, pageSize, repNotifier, primaryColor, textPrimary, textSecondary, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getReportTitle(int type) {
    switch (type) {
      case 0:
        return 'Space & Room Utilization Audit';
      case 1:
        return 'Institutional Asset & Equipment Health Audit';
      case 2:
        return 'Campus Maintenance & Work Order SLA Performance';
      case 3:
        return 'Statutory Safety NOC, Inspections & Evacuation Compliance';
      case 4:
        return 'Campus Energy, Solar Yield & Water Footprint Audit';
      default:
        return 'Campus Infrastructure Report';
    }
  }

  Widget _buildReportTypeChip(
    int index,
    String label,
    IconData icon,
    Color primaryColor,
    bool isDark,
    int selectedReportType,
    CampusReportsNotifier notifier,
  ) {
    final isSelected = selectedReportType == index;
    return InkWell(
      onTap: () => notifier.setReportType(index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? primaryColor : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? primaryColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primaryColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportSummaryKpis(int selectedReportType, Color primaryColor, bool isDark) {
    if (selectedReportType == 0) {
      return Row(
        children: [
          Expanded(child: _buildMetricCard('Total Bookable Spaces', '48 Spaces', 'Across 6 blocks', Icons.meeting_room_rounded, primaryColor, isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Avg Room Utilization', '74.6%', '+5.2% vs last month', Icons.donut_large_rounded, const Color(0xFF10B981), isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Peak Demand Windows', '09:00 AM - 11:30 AM', 'Max academic load', Icons.schedule_rounded, const Color(0xFFF59E0B), isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Idle Space Capacity', '1,198 Seats', 'Available for booking', Icons.event_seat_rounded, const Color(0xFF6366F1), isDark)),
        ],
      );
    } else if (selectedReportType == 1) {
      return Row(
        children: [
          Expanded(child: _buildMetricCard('Tracked Assets', '3,480 Units', 'AV, Furniture, Lab, IT', Icons.inventory_2_rounded, primaryColor, isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Asset Health Index', '94.2%', 'Good or Excellent condition', Icons.health_and_safety_rounded, const Color(0xFF10B981), isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Service Overdue', '18 Items', 'Scheduled preventive check', Icons.warning_amber_rounded, const Color(0xFFF59E0B), isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Annual Depreciation', '₹ 14.8 Lakhs', 'Depreciation standard: SLM', Icons.trending_down_rounded, const Color(0xFF0284C7), isDark)),
        ],
      );
    } else if (selectedReportType == 2) {
      return Row(
        children: [
          Expanded(child: _buildMetricCard('Total Work Orders', '142 Orders', 'In period', Icons.build_rounded, primaryColor, isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('SLA Compliance Rate', '96.4%', 'Resolved within target SLA', Icons.verified_rounded, const Color(0xFF10B981), isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Mean Time to Resolve', '3.8 Hours', 'Down 22% this quarter', Icons.timer_rounded, const Color(0xFF0284C7), isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Total AMC Expenditure', '₹ 2.45 Lakhs', 'Under budget by 8%', Icons.account_balance_wallet_rounded, const Color(0xFF8B5CF6), isDark)),
        ],
      );
    } else if (selectedReportType == 3) {
      return Row(
        children: [
          Expanded(child: _buildMetricCard('Active Statutory NOCs', '6 of 6 Valid', '100% compliance met', Icons.shield_rounded, const Color(0xFF10B981), isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Next Expiring Cert', 'Dec 31, 2028', 'Karnataka Fire Services NOC', Icons.event_rounded, const Color(0xFF3B82F6), isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Emergency Drills Held', '4 Drills', 'Avg evacuation time: 3m 42s', Icons.campaign_rounded, const Color(0xFFF59E0B), isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Open Safety Hazards', '0 Critical', 'All minor audits resolved', Icons.check_circle_rounded, const Color(0xFF059669), isDark)),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: _buildMetricCard('Grid Electricity', '45,210 kWh', 'Peak load 245 kW', Icons.electric_bolt_rounded, const Color(0xFFF59E0B), isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Solar Generation', '12,480 kWh', '27.6% Clean energy offset', Icons.solar_power_rounded, const Color(0xFF10B981), isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Water Consumption', '1.85 Lakh L', 'STP recycled: 62,000 L', Icons.water_drop_rounded, const Color(0xFF0284C7), isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Carbon Footprint', '36.8 MT CO2', 'Reduced 14% YoY', Icons.eco_rounded, const Color(0xFF059669), isDark)),
        ],
      );
    }
  }

  Widget _buildReportTable(
    int selectedReportType,
    String searchQuery,
    int page,
    int pageSize,
    CampusReportsNotifier notifier,
    Color primaryColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    if (selectedReportType == 0) {
      final allRows = [
        {'bld': 'B1 - Academic Block (A)', 'room': 'Auditorium (A1-101)', 'type': 'Auditorium', 'cap': 250, 'occ': '84.2%', 'hours': '38.5 hrs/wk', 'status': 'High Demand'},
        {'bld': 'B1 - Academic Block (A)', 'room': 'Computer Lab (A1-105)', 'type': 'Computer Lab', 'cap': 60, 'occ': '79.1%', 'hours': '34.0 hrs/wk', 'status': 'Optimal'},
        {'bld': 'B1 - Academic Block (A)', 'room': 'Classroom 201', 'type': 'Classroom', 'cap': 45, 'occ': '91.4%', 'hours': '41.0 hrs/wk', 'status': 'Peak Usage'},
        {'bld': 'B2 - Academic Block (B)', 'room': 'Physics Lab 102', 'type': 'Physics Lab', 'cap': 40, 'occ': '68.5%', 'hours': '28.0 hrs/wk', 'status': 'Available'},
        {'bld': 'B3 - Library Block', 'room': 'Digital Reading Hall', 'type': 'Digital Library', 'cap': 120, 'occ': '86.0%', 'hours': '52.0 hrs/wk', 'status': 'High Demand'},
        {'bld': 'B4 - Auditorium Block', 'room': 'Seminar Room 01', 'type': 'Seminar Hall', 'cap': 80, 'occ': '54.0%', 'hours': '21.5 hrs/wk', 'status': 'Underutilized'},
      ];
      final rows = searchQuery.isEmpty
          ? allRows
          : allRows.where((r) => r.values.any((v) => v.toString().toLowerCase().contains(searchQuery.toLowerCase()))).toList();

      final pagedRows = rows;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 35,
              columns: const [
                DataColumn(label: Text('Building', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Space / Room', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Capacity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Utilization Rate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Booked Hours', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Demand Tier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              ],
              rows: pagedRows.map((r) {
                final isPeak = r['status'] == 'Peak Usage' || r['status'] == 'High Demand';
                return DataRow(
                  cells: [
                    DataCell(Text(r['bld'] as String, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(r['room'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                    DataCell(Text(r['type'] as String, style: const TextStyle(fontSize: 11.5))),
                    DataCell(Text('${r['cap']} seats', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(r['occ'] as String, style: TextStyle(fontWeight: FontWeight.w700, color: primaryColor, fontSize: 12))),
                    DataCell(Text(r['hours'] as String, style: const TextStyle(fontSize: 11.5))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isPeak ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r['status'] as String,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isPeak ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                        ),
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: CampusPaginationBar(
              currentPage: page,
              pageSize: pageSize,
              totalItems: rows.length,
              onPageChanged: (newPage) => notifier.setPage(newPage),
              onPageSizeChanged: (newSize) => notifier.setPageSize(newSize),
              itemLabel: 'records',
            ),
          ),
        ],
      );
    } else {
      final auditRows = [
        {'id': 'AUD-01', 'metric': 'Fire NOC Certificate & Extinguishers Audit', 'scope': 'All 8 Buildings', 'value': '100% Compliant', 'score': 'Passed (A+)', 'date': '04 Jan 2026'},
        {'id': 'AUD-02', 'metric': 'Electrical Substation & Earthing Resistance', 'scope': 'Power House', 'value': 'Earth Resistance 0.82 Ohm', 'score': 'Safe & Certified', 'date': '02 Jan 2026'},
        {'id': 'AUD-03', 'metric': 'RO Water Quality & Microbiology Test', 'scope': 'Main RO Plant', 'value': 'TDS 68 ppm • Nil Bacteria', 'score': 'Potable Grade A', 'date': '28 Dec 2025'},
        {'id': 'AUD-04', 'metric': 'Elevators & Escalators Load & Emergency Brake', 'scope': 'B1 & B4 Lifts', 'value': 'Drop Test Passed (8/8)', 'score': 'Fitness Valid', 'date': '22 Dec 2025'},
        {'id': 'AUD-05', 'metric': 'DG Genset Emissions & Fuel Quality Audit', 'scope': 'DG Yard', 'value': '0.04 g/kWh Particulate', 'score': 'CPCB-II Met', 'date': '15 Dec 2025'},
      ];
      final rows = searchQuery.isEmpty
          ? auditRows
          : auditRows.where((r) => r.values.any((v) => v.toString().toLowerCase().contains(searchQuery.toLowerCase()))).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 35,
              columns: const [
                DataColumn(label: Text('Audit ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Compliance Checkpoint', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Scope / Location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Measured Telemetry', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Compliance Rating', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                DataColumn(label: Text('Audit Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
              ],
              rows: rows.map((r) => DataRow(
                cells: [
                  DataCell(Text(r['id'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                  DataCell(Text(r['metric'] as String, style: const TextStyle(fontSize: 12))),
                  DataCell(Text(r['scope'] as String, style: const TextStyle(fontSize: 11.5))),
                  DataCell(Text(r['value'] as String, style: const TextStyle(fontSize: 12))),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      r['score'] as String,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                    ),
                  )),
                  DataCell(Text(r['date'] as String, style: const TextStyle(fontSize: 11.5))),
                ],
              )).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: CampusPaginationBar(
              currentPage: page,
              pageSize: pageSize,
              totalItems: rows.length,
              onPageChanged: (newPage) => notifier.setPage(newPage),
              onPageSizeChanged: (newSize) => notifier.setPageSize(newSize),
              itemLabel: 'audits',
            ),
          ),
        ],
      );
    }
  }

  Widget _buildMetricCard(String title, String value, String sub, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
