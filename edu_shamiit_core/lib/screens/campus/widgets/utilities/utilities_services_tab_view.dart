import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/campus_provider.dart';
import '../../providers/utilities_provider.dart';
import '../../services/campus_api_service.dart';
import '../common/campus_pagination_bar.dart';
import 'dialogs/log_utility_reading_dialog.dart';

class UtilitiesServicesTabView extends ConsumerStatefulWidget {
  const UtilitiesServicesTabView({super.key});

  @override
  ConsumerState<UtilitiesServicesTabView> createState() => _UtilitiesServicesTabViewState();
}

class _UtilitiesServicesTabViewState extends ConsumerState<UtilitiesServicesTabView> {
  void _openLogReadingModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LogUtilityReadingDialog(
        onSaved: () {
          ref.read(utilitiesProvider.notifier).loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Utility meter reading successfully recorded!'), backgroundColor: Color(0xFF059669)),
          );
        },
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

    final utilState = ref.watch(utilitiesProvider);
    final utilNotifier = ref.read(utilitiesProvider.notifier);

    final kpis = utilState.kpis;
    final readingLogs = utilState.readingLogs;
    final activeCategory = utilState.activeCategory;
    final currentPage = utilState.currentPage;
    final pageSize = utilState.pageSize;
    final totalCount = utilState.totalCount;
    final sortCol = utilState.sortCol;
    final sortAsc = utilState.sortAsc;
    final isLoading = utilState.isLoading;
    final anomaly = utilState.latestAnomaly;

    return RefreshIndicator(
      onRefresh: () => utilNotifier.loadData(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLoading)
              const LinearProgressIndicator(minHeight: 2),

            // Anomaly Alert Banner (if consumption spike detected)
            if (anomaly != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Automated Utility Surge Detected (>1.5x Baseline)',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEF4444), fontSize: 13.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'A high-priority maintenance ticket (${anomaly['ticket_code'] ?? 'Work Order'}) was automatically generated in Tab 3.',
                            style: TextStyle(color: textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(campusProvider.notifier).setActiveCampusTab(3); // Jump to Maintenance
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                      label: const Text('View Work Order', style: TextStyle(fontSize: 12, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                    ),
                  ],
                ),
              ),
            ],

            // 1. Top Utilities KPI Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 900;
                final gridVal = kpis['grid_power_load']?.toString() ?? '245 kW';
                final gridSub = kpis['grid_power_mtd']?.toString() ?? '45,210 kWh MTD';
                final solarVal = kpis['solar_generation']?.toString() ?? '84 kWp';
                final solarSub = kpis['solar_today']?.toString() ?? '320.4 kWh Today';
                final genVal = kpis['dg_fuel_level']?.toString() ?? '78% (1,560 L)';
                const genSub = 'Diesel Standby Ready';
                final waterVal = kpis['water_storage']?.toString() ?? '85% (85,000 L)';
                final waterSub = kpis['ro_purity']?.toString() ?? 'TDS: 68 ppm';
                const fiberVal = '1.0 Gbps';
                final fiberSub = kpis['internet_uptime']?.toString() ?? '99.98% Uptime';

                if (isCompact) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildKpiCard('Grid Power Load', gridVal, gridSub, Icons.electric_bolt_rounded, const Color(0xFFF59E0B), isDark)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildKpiCard('Solar Generation', solarVal, solarSub, Icons.solar_power_rounded, const Color(0xFF10B981), isDark)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildKpiCard('Generator Fuel', genVal, genSub, Icons.ev_station_rounded, const Color(0xFF6366F1), isDark)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildKpiCard('Water Storage', waterVal, waterSub, Icons.water_drop_rounded, const Color(0xFF0284C7), isDark)),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: _buildKpiCard('Grid Power Load', gridVal, gridSub, Icons.electric_bolt_rounded, const Color(0xFFF59E0B), isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKpiCard('Solar Generation', solarVal, solarSub, Icons.solar_power_rounded, const Color(0xFF10B981), isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKpiCard('Generator Fuel', genVal, genSub, Icons.ev_station_rounded, const Color(0xFF6366F1), isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKpiCard('Water Storage', waterVal, waterSub, Icons.water_drop_rounded, const Color(0xFF0284C7), isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKpiCard('Fiber Leased Line', fiberVal, fiberSub, Icons.wifi_rounded, primaryColor, isDark)),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // 2. Sub-Category Tabs & Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildSubTabButton(0, 'Electrical & Solar Power', Icons.electric_meter_rounded, primaryColor, isDark, activeCategory, utilNotifier),
                          const SizedBox(width: 8),
                          _buildSubTabButton(1, 'Water, Sump & RO Plant', Icons.water_drop_outlined, primaryColor, isDark, activeCategory, utilNotifier),
                          const SizedBox(width: 8),
                          _buildSubTabButton(2, 'Internet, Fiber & Telecom', Icons.router_rounded, primaryColor, isDark, activeCategory, utilNotifier),
                          const SizedBox(width: 8),
                          _buildSubTabButton(3, 'Gas Supply & HVAC Central', Icons.hvac_rounded, primaryColor, isDark, activeCategory, utilNotifier),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => CampusApiService.instance.exportCampusReport(reportType: 4),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Export Readings', style: TextStyle(fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _openLogReadingModal,
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text('Log Reading', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Category Overview Card & Tariff/Cost Projections
            _buildCategoryOverviewCard(activeCategory, utilState, primaryColor, bgCard, borderColor, textPrimary, textSecondary, isDark),
            const SizedBox(height: 16),

            // 4. Utility Readings & Operational Audit History
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
                        Icon(Icons.history_rounded, size: 18, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Recent Utility Meter Readings & Telemetry Audits',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 34,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 35,
                      sortColumnIndex: sortCol,
                      sortAscending: sortAsc,
                      columns: [
                        DataColumn(
                          label: const Text('Timestamp', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          onSort: (col, asc) => utilNotifier.setSorting(col, asc),
                        ),
                        DataColumn(
                          label: const Text('Utility Infrastructure', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          onSort: (col, asc) => utilNotifier.setSorting(col, asc),
                        ),
                        DataColumn(
                          label: const Text('Reading / Telemetry', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          onSort: (col, asc) => utilNotifier.setSorting(col, asc),
                        ),
                        DataColumn(
                          label: const Text('Substation / Location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          onSort: (col, asc) => utilNotifier.setSorting(col, asc),
                        ),
                        DataColumn(
                          label: const Text('Officer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          onSort: (col, asc) => utilNotifier.setSorting(col, asc),
                        ),
                        DataColumn(
                          label: const Text('Operational Health', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          onSort: (col, asc) => utilNotifier.setSorting(col, asc),
                        ),
                        const DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      ],
                      rows: (() {
                        final list = List<Map<String, dynamic>>.from(readingLogs);
                        if (sortCol != null) {
                          list.sort((a, b) {
                            int cmp = 0;
                            switch (sortCol) {
                              case 0:
                                cmp = (a['timestamp'] ?? a['recorded_at'] ?? '').toString().compareTo((b['timestamp'] ?? b['recorded_at'] ?? '').toString());
                                break;
                              case 1:
                                cmp = (a['utility_name'] ?? a['utility'] ?? '').toString().compareTo((b['utility_name'] ?? b['utility'] ?? '').toString());
                                break;
                              case 2:
                                cmp = (a['reading_value'] ?? a['reading'] ?? '').toString().compareTo((b['reading_value'] ?? b['reading'] ?? '').toString());
                                break;
                              case 3:
                                cmp = (a['location'] ?? '').toString().compareTo((b['location'] ?? '').toString());
                                break;
                              case 4:
                                cmp = (a['recorded_by'] ?? '').toString().compareTo((b['recorded_by'] ?? '').toString());
                                break;
                              case 5:
                                cmp = (a['status'] ?? '').toString().compareTo((b['status'] ?? '').toString());
                                break;
                            }
                            return sortAsc ? cmp : -cmp;
                          });
                        }

                        return list.map((log) {
                          final status = log['status']?.toString() ?? 'Normal';
                          final isNormal = status == 'Normal' || status == 'Optimal' || status == 'Adequate' || status == 'Healthy' || status == 'Certified Pure' || status == 'Standby Ready';
                          final statusColor = isNormal ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
                          final utilityName = log['utility_name'] ?? log['utility'] ?? 'Utility Item';
                          final readingVal = log['reading_value'] ?? log['reading'] ?? '';
                          final loc = log['location'] ?? 'Campus Substation';
                          final officer = log['recorded_by'] ?? 'Facility Officer';
                          final ts = log['timestamp'] ?? log['recorded_at'] ?? 'Recent';
                          final notes = log['notes'] ?? '-';

                          return DataRow(
                            cells: [
                              DataCell(Text(ts, style: TextStyle(fontSize: 11.5, color: textSecondary))),
                              DataCell(Text(utilityName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                              DataCell(Text(readingVal, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryColor))),
                              DataCell(Text(loc, style: const TextStyle(fontSize: 11.5))),
                              DataCell(Text(officer, style: const TextStyle(fontSize: 11.5))),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: statusColor),
                                ),
                              )),
                              DataCell(Text(notes, style: TextStyle(fontSize: 11.5, color: textSecondary))),
                            ],
                          );
                        }).toList();
                      })(),
                    ),
                  ),
                  if (readingLogs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: CampusPaginationBar(
                        currentPage: currentPage,
                        pageSize: pageSize,
                        totalItems: totalCount > 0 ? totalCount : readingLogs.length,
                        onPageChanged: (newPage) => utilNotifier.setPage(newPage),
                        onPageSizeChanged: (newSize) => utilNotifier.setPageSize(newSize),
                        itemLabel: 'logs',
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

  Widget _buildSubTabButton(
    int index,
    String label,
    IconData icon,
    Color primaryColor,
    bool isDark,
    int activeCategory,
    UtilitiesNotifier notifier,
  ) {
    final isSelected = activeCategory == index;
    return InkWell(
      onTap: () => notifier.setActiveCategory(index),
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

  Widget _buildCategoryOverviewCard(
    int activeCategory,
    UtilitiesState state,
    Color primaryColor,
    Color bgCard,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    if (activeCategory == 0) {
      // Electrical & Solar Power with Tariff Projections
      const estKwh = 45210.0;
      final estMonthlyCost = estKwh * state.tariffKwh;
      final solarOffsetCost = 320.4 * 30 * state.tariffKwh;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Text('Electrical & Solar Power Infrastructure Summary', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textPrimary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Grid Stable • Synchronized', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'High-tension 33kV dedicated feeder line with dual 1,250 kVA dry-type transformers, integrated with 84 kWp rooftop photovoltaic solar system and two auto-start 500 kVA backup diesel generator sets.',
              style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            // Tariff & Billing Projection Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Commercial Power Tariff', style: TextStyle(fontSize: 11, color: textSecondary)),
                        const SizedBox(height: 2),
                        Text('₹${state.tariffKwh.toStringAsFixed(2)} / kWh', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Projected Monthly Bill', style: TextStyle(fontSize: 11, color: textSecondary)),
                        const SizedBox(height: 2),
                        Text('₹${estMonthlyCost.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primaryColor)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Solar Monthly Savings', style: TextStyle(fontSize: 11, color: textSecondary)),
                        const SizedBox(height: 2),
                        Text('₹${solarOffsetCost.toStringAsFixed(0)} (Offset)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (activeCategory == 1) {
      // Water, Sump & RO Plant
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.water_drop_rounded, size: 20, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Text('Water Supply, Sump & RO Purification Hub', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textPrimary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('TDS Certified Pure', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '100,000 Litre central underground sump fed by municipal connection and 2 deep borewells with rainwater harvesting recharge pits. Central RO plant supplies 2,500 LPH drinking water across all water dispensers.',
              style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.4),
            ),
          ],
        ),
      );
    } else if (activeCategory == 2) {
      // Internet, Fiber & Telecom
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.router_rounded, size: 20, color: primaryColor),
                const SizedBox(width: 8),
                Text('Optical Fiber Leased Line & Wi-Fi Backhaul', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textPrimary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('99.98% High Uptime', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '1:1 uncompressed 1.0 Gbps leased line termination with BGP multi-homing to secondary 200 Mbps wireless backup link. Core 10-Gigabit optical fiber ring interconnects all 6 campus blocks.',
              style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.4),
            ),
          ],
        ),
      );
    } else {
      // Gas Supply & HVAC Central
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hvac_rounded, size: 20, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 8),
                Text('Central HVAC Chillers & Science Lab Piped Gas', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textPrimary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Pressure Nominal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Central variable refrigerant volume (VRV) cooling system servicing classrooms and auditorium, paired with manifold piped LPG gas bank supplying chemistry and biology laboratories with automatic gas leak detection and shutoff.',
              style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.4),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildKpiCard(String title, String value, String sub, IconData icon, Color color, bool isDark) {
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
