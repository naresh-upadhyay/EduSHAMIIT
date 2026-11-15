import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/campus_lookup_helper.dart';
import '../../services/campus_api_service.dart';
import '../../models/campus_models.dart';

class CampusReportsTabView extends ConsumerStatefulWidget {
  const CampusReportsTabView({super.key});

  @override
  ConsumerState<CampusReportsTabView> createState() => _CampusReportsTabViewState();
}

class _CampusReportsTabViewState extends ConsumerState<CampusReportsTabView> {
  int _selectedReportType = 0;
  // 0: Space & Room Utilization Audit
  // 1: Infrastructure Asset & Equipment Health
  // 2: Maintenance SLA & Work Order Performance
  // 3: Campus Safety, NOC & Compliance Audit
  // 4: Energy & Utility Footprint Report

  String _timeRange = 'Last 30 Days';
  String? _selectedBuildingId;
  String _searchQuery = '';
  List<BuildingModel> _buildings = [];

  final List<String> _timeRanges = [
    'Today',
    'Last 7 Days',
    'Last 30 Days',
    'Current Semester',
    'Current Academic Year',
  ];

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    final bldgs = await CampusLookupHelper.instance.getActiveBuildings();
    if (mounted) {
      setState(() => _buildings = bldgs);
    }
  }

  void _exportReport() {
    final reportNames = [
      'space_utilization',
      'equipment_health',
      'maintenance_sla',
      'safety_compliance',
      'energy_utility',
    ];
    final selectedName = reportNames[_selectedReportType];
    CampusApiService.instance.exportData(
      _selectedReportType == 1 ? 'equipment' : (_selectedReportType == 0 ? 'rooms' : 'buildings'),
      buildingId: _selectedBuildingId,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting Institutional Campus Report: $selectedName.csv'),
        backgroundColor: const Color(0xFF059669),
      ),
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
                  _buildReportTypeChip(0, 'Space & Room Utilization', Icons.pie_chart_rounded, primaryColor, isDark),
                  const SizedBox(width: 8),
                  _buildReportTypeChip(1, 'Asset & Equipment Health', Icons.precision_manufacturing_rounded, primaryColor, isDark),
                  const SizedBox(width: 8),
                  _buildReportTypeChip(2, 'Maintenance & SLA Performance', Icons.build_circle_rounded, primaryColor, isDark),
                  const SizedBox(width: 8),
                  _buildReportTypeChip(3, 'Safety & Compliance Audit', Icons.verified_user_rounded, primaryColor, isDark),
                  const SizedBox(width: 8),
                  _buildReportTypeChip(4, 'Energy & Utility Footprint', Icons.electric_bolt_rounded, primaryColor, isDark),
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
                    child: DropdownButton<String>(
                      value: _timeRange,
                      isDense: true,
                      dropdownColor: bgCard,
                      items: _timeRanges
                          .map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 12, color: textPrimary))))
                          .toList(),
                      onChanged: (v) => setState(() => _timeRange = v ?? _timeRange),
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
                    child: DropdownButton<String?>(
                      value: _selectedBuildingId,
                      isDense: true,
                      dropdownColor: bgCard,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Campus Infrastructure', style: TextStyle(fontSize: 12))),
                        ..._buildings.map((b) => DropdownMenuItem(
                              value: b.id,
                              child: Text('${b.code} - ${b.name}', style: TextStyle(fontSize: 12, color: textPrimary)),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selectedBuildingId = v),
                    ),
                  ),
                ),

                // Search Box
                SizedBox(
                  width: 200,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
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

                // Export Button
                ElevatedButton.icon(
                  onPressed: _exportReport,
                  icon: const Icon(Icons.file_download_outlined, size: 16, color: Colors.white),
                  label: const Text('Export CSV', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Report Summary KPIs
          _buildReportSummaryKpis(primaryColor, isDark),
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
                        _getReportTitle(),
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textPrimary),
                      ),
                      const Spacer(),
                      Text('Period: $_timeRange', style: TextStyle(fontSize: 12, color: textSecondary)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _buildReportTable(primaryColor, textPrimary, textSecondary, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getReportTitle() {
    switch (_selectedReportType) {
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

  Widget _buildReportTypeChip(int index, String label, IconData icon, Color primaryColor, bool isDark) {
    final isSelected = _selectedReportType == index;
    return InkWell(
      onTap: () => setState(() => _selectedReportType = index),
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

  Widget _buildReportSummaryKpis(Color primaryColor, bool isDark) {
    if (_selectedReportType == 0) {
      return Row(
        children: [
          Expanded(child: _buildMetricCard('Campus Occupancy', '78.4%', 'Up 4.2% vs last term', Icons.pie_chart_rounded, const Color(0xFF10B981), isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Total Bookable Rooms', '166 Rooms', '52 Classrooms, 34 Labs', Icons.meeting_room_rounded, primaryColor, isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Peak Utilization Time', '10:00 AM - 01:00 PM', '92% rooms occupied', Icons.access_time_filled_rounded, const Color(0xFFF59E0B), isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Idle Space Capacity', '1,198 Seats', 'Available for booking', Icons.event_seat_rounded, const Color(0xFF6366F1), isDark)),
        ],
      );
    } else if (_selectedReportType == 1) {
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
    } else if (_selectedReportType == 2) {
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
    } else if (_selectedReportType == 3) {
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

  Widget _buildReportTable(Color primaryColor, Color textPrimary, Color textSecondary, bool isDark) {
    if (_selectedReportType == 0) {
      // Space & Room Utilization Table
      final allRows = [
        {'bld': 'B1 - Academic Block (A)', 'room': 'Auditorium (A1-101)', 'type': 'Auditorium', 'cap': 250, 'occ': '84.2%', 'hours': '38.5 hrs/wk', 'status': 'High Demand'},
        {'bld': 'B1 - Academic Block (A)', 'room': 'Computer Lab (A1-105)', 'type': 'Computer Lab', 'cap': 60, 'occ': '79.1%', 'hours': '34.0 hrs/wk', 'status': 'Optimal'},
        {'bld': 'B1 - Academic Block (A)', 'room': 'Classroom 201', 'type': 'Classroom', 'cap': 45, 'occ': '91.4%', 'hours': '41.0 hrs/wk', 'status': 'Peak Usage'},
        {'bld': 'B2 - Academic Block (B)', 'room': 'Physics Lab 102', 'type': 'Physics Lab', 'cap': 40, 'occ': '68.5%', 'hours': '28.0 hrs/wk', 'status': 'Available'},
        {'bld': 'B3 - Library Block', 'room': 'Digital Reading Hall', 'type': 'Digital Library', 'cap': 120, 'occ': '86.0%', 'hours': '52.0 hrs/wk', 'status': 'High Demand'},
        {'bld': 'B4 - Auditorium Block', 'room': 'Seminar Room 01', 'type': 'Seminar Hall', 'cap': 80, 'occ': '54.0%', 'hours': '21.5 hrs/wk', 'status': 'Underutilized'},
      ];
      final rows = _searchQuery.isEmpty
          ? allRows
          : allRows.where((r) => r.values.any((v) => v.toString().toLowerCase().contains(_searchQuery.toLowerCase()))).toList();

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Building', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Space / Room', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Capacity', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Utilization Rate', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Booked Hours', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Demand Tier', style: TextStyle(fontWeight: FontWeight.w700))),
          ],
          rows: rows.map((r) {
            final isPeak = r['status'] == 'Peak Usage' || r['status'] == 'High Demand';
            return DataRow(
              cells: [
                DataCell(Text(r['bld'] as String, style: const TextStyle(fontSize: 12.5))),
                DataCell(Text(r['room'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                DataCell(Text(r['type'] as String, style: const TextStyle(fontSize: 12))),
                DataCell(Text('${r['cap']} seats', style: const TextStyle(fontSize: 12))),
                DataCell(Text(r['occ'] as String, style: TextStyle(fontWeight: FontWeight.w700, color: primaryColor, fontSize: 13))),
                DataCell(Text(r['hours'] as String, style: const TextStyle(fontSize: 12))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isPeak ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    r['status'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isPeak ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                    ),
                  ),
                )),
              ],
            );
          }).toList(),
        ),
      );
    } else {
      // General Audit Records Table
      final auditRows = [
        {'id': 'AUD-01', 'metric': 'Fire NOC Certificate & Extinguishers Audit', 'scope': 'All 8 Buildings', 'value': '100% Compliant', 'score': 'Passed (A+)', 'date': '04 Jan 2026'},
        {'id': 'AUD-02', 'metric': 'Electrical Substation & Earthing Resistance', 'scope': 'Power House', 'value': 'Earth Resistance 0.82 Ohm', 'score': 'Safe & Certified', 'date': '02 Jan 2026'},
        {'id': 'AUD-03', 'metric': 'RO Water Quality & Microbiology Test', 'scope': 'Main RO Plant', 'value': 'TDS 68 ppm • Nil Bacteria', 'score': 'Potable Grade A', 'date': '28 Dec 2025'},
        {'id': 'AUD-04', 'metric': 'Elevator / Lift Fitness Certification', 'scope': 'Academic Blocks A & B', 'value': 'Dual Otis Passenger Lifts', 'score': 'License Valid', 'date': '20 Dec 2025'},
        {'id': 'AUD-05', 'metric': 'Solar Inverter Efficiency & Clean Energy', 'scope': '150 kWp Rooftop', 'value': '320.4 kWh Daily Average', 'score': 'Optimal PR: 82%', 'date': '15 Dec 2025'},
      ];

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Audit ID', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Infrastructure Audit Parameter', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Campus Scope', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Measured Metric / Value', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Audit Result', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Verified Date', style: TextStyle(fontWeight: FontWeight.w700))),
          ],
          rows: auditRows.map((r) {
            return DataRow(
              cells: [
                DataCell(Text(r['id'] as String, style: TextStyle(fontSize: 12, color: textSecondary))),
                DataCell(Text(r['metric'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                DataCell(Text(r['scope'] as String, style: const TextStyle(fontSize: 12))),
                DataCell(Text(r['value'] as String, style: TextStyle(fontWeight: FontWeight.w600, color: primaryColor, fontSize: 12.5))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    r['score'] as String,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                  ),
                )),
                DataCell(Text(r['date'] as String, style: TextStyle(fontSize: 12, color: textSecondary))),
              ],
            );
          }).toList(),
        ),
      );
    }
  }

  Widget _buildMetricCard(String title, String value, String subtitle, IconData icon, Color color, bool isDark) {
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
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
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
