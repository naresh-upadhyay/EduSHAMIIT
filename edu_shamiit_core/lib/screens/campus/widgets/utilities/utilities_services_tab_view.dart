import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dialogs/log_utility_reading_dialog.dart';

class UtilitiesServicesTabView extends ConsumerStatefulWidget {
  const UtilitiesServicesTabView({super.key});

  @override
  ConsumerState<UtilitiesServicesTabView> createState() => _UtilitiesServicesTabViewState();
}

class _UtilitiesServicesTabViewState extends ConsumerState<UtilitiesServicesTabView> {
  int _activeCategory = 0; // 0: Electrical & Solar, 1: Water & RO, 2: Internet & Fiber, 3: Gas & HVAC

  final List<Map<String, dynamic>> _readingLogs = [
    {
      'timestamp': '10 Jan 2026, 06:30 PM',
      'utility': 'State Power Grid & Substation',
      'reading': '45,210 kWh',
      'location': 'Main Substation (33kV)',
      'recorded_by': 'Suresh Sharma',
      'status': 'Normal',
      'notes': 'Peak evening demand stable at 245 kW',
    },
    {
      'timestamp': '10 Jan 2026, 04:00 PM',
      'utility': 'Rooftop Solar PV Generation',
      'reading': '320.4 kWh (Today)',
      'location': 'Academic Block A & B Roof',
      'recorded_by': 'System Inverter Monitor',
      'status': 'Optimal',
      'notes': 'Sunny conditions, 42% campus load offset achieved',
    },
    {
      'timestamp': '10 Jan 2026, 02:15 PM',
      'utility': 'Backup Diesel Generator Sets (DG)',
      'reading': 'DG-01: 78% Fuel (1,560 L)',
      'location': 'Power House Yard',
      'recorded_by': 'Ramesh Kumar',
      'status': 'Standby Ready',
      'notes': 'Weekly 15-minute test run completed without issues',
    },
    {
      'timestamp': '10 Jan 2026, 11:00 AM',
      'utility': 'Municipal Water & Deep Borewells',
      'reading': '85,000 Litres (85%)',
      'location': 'Central Underground Sump',
      'recorded_by': 'Sunil Rao',
      'status': 'Adequate',
      'notes': 'Overhead tanks replenished for hostel and labs',
    },
    {
      'timestamp': '10 Jan 2026, 09:30 AM',
      'utility': 'Central RO Water Purification Plant',
      'reading': 'TDS: 68 ppm • Flow: 2,500 LPH',
      'location': 'Amenities Block RO Plant',
      'recorded_by': 'Sunil Rao',
      'status': 'Certified Pure',
      'notes': 'UV & Osmosis filters verified clean',
    },
    {
      'timestamp': '10 Jan 2026, 08:00 AM',
      'utility': 'High-Speed Internet / Optical Fiber Leased Line',
      'reading': 'Primary: 1.0 Gbps (99.98% Uptime)',
      'location': 'Server Room Core Rack',
      'recorded_by': 'Kiran Verma',
      'status': 'Healthy',
      'notes': 'Secondary backup wireless line on hot standby',
    },
  ];

  void _openLogReadingModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LogUtilityReadingDialog(
        onSaved: () {
          setState(() {
            _readingLogs.insert(0, {
              'timestamp': 'Just Now',
              'utility': 'State Power Grid & Substation',
              'reading': '45,340 kWh',
              'location': 'Main Substation',
              'recorded_by': 'Campus Officer',
              'status': 'Normal',
              'notes': 'Manual utility log entry recorded successfully',
            });
          });
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Utilities KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 900;
              if (isCompact) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildKpiCard('Grid Power Load', '245 kW', '45,210 kWh MTD', Icons.electric_bolt_rounded, const Color(0xFFF59E0B), isDark)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildKpiCard('Solar Generation', '84 kWp', '320 kWh Today', Icons.solar_power_rounded, const Color(0xFF10B981), isDark)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildKpiCard('Generator Fuel', '78% Full', '1,560 Litres Diesel', Icons.ev_station_rounded, const Color(0xFF6366F1), isDark)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildKpiCard('Water Storage', '85% Capacity', '85,000 Litres Sump', Icons.water_drop_rounded, const Color(0xFF0284C7), isDark)),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: _buildKpiCard('Grid Power Load', '245 kW', '45,210 kWh MTD', Icons.electric_bolt_rounded, const Color(0xFFF59E0B), isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildKpiCard('Solar Generation', '84 kWp', '320 kWh Today', Icons.solar_power_rounded, const Color(0xFF10B981), isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildKpiCard('Generator Fuel', '78% Full', '1,560 Litres Diesel', Icons.ev_station_rounded, const Color(0xFF6366F1), isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildKpiCard('Water Storage', '85% Capacity', '85,000 Litres Sump', Icons.water_drop_rounded, const Color(0xFF0284C7), isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildKpiCard('Fiber Leased Line', '1.0 Gbps', '99.98% Uptime', Icons.wifi_rounded, primaryColor, isDark)),
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
                        _buildSubTabButton(0, 'Electrical & Solar Power', Icons.electric_meter_rounded, primaryColor, isDark),
                        const SizedBox(width: 8),
                        _buildSubTabButton(1, 'Water, Sump & RO Plant', Icons.water_drop_outlined, primaryColor, isDark),
                        const SizedBox(width: 8),
                        _buildSubTabButton(2, 'Internet, Fiber & Telecom', Icons.router_rounded, primaryColor, isDark),
                        const SizedBox(width: 8),
                        _buildSubTabButton(3, 'Gas Supply & HVAC Central', Icons.hvac_rounded, primaryColor, isDark),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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

          // 3. Category Overview Card
          _buildCategoryOverviewCard(primaryColor, bgCard, borderColor, textPrimary, textSecondary, isDark),
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
                    columns: const [
                      DataColumn(label: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Utility Infrastructure', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Reading / Telemetry', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Substation / Location', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Officer', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Operational Health', style: TextStyle(fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.w700))),
                    ],
                    rows: _readingLogs.map((log) {
                      final isNormal = log['status'] == 'Normal' || log['status'] == 'Optimal' || log['status'] == 'Adequate' || log['status'] == 'Healthy' || log['status'] == 'Certified Pure' || log['status'] == 'Standby Ready';
                      final statusColor = isNormal ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

                      return DataRow(
                        cells: [
                          DataCell(Text(log['timestamp'] ?? '', style: TextStyle(fontSize: 12, color: textSecondary))),
                          DataCell(Text(log['utility'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
                          DataCell(Text(log['reading'] ?? '', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: primaryColor))),
                          DataCell(Text(log['location'] ?? '', style: const TextStyle(fontSize: 12))),
                          DataCell(Text(log['recorded_by'] ?? '', style: const TextStyle(fontSize: 12))),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              log['status'] ?? '',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                            ),
                          )),
                          DataCell(Text(log['notes'] ?? '', style: TextStyle(fontSize: 12, color: textSecondary))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabButton(int index, String label, IconData icon, Color primaryColor, bool isDark) {
    final isSelected = _activeCategory == index;
    return InkWell(
      onTap: () => setState(() => _activeCategory = index),
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

  Widget _buildCategoryOverviewCard(Color primaryColor, Color bgCard, Color borderColor, Color textPrimary, Color textSecondary, bool isDark) {
    if (_activeCategory == 0) {
      // Electrical & Solar Power
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
                Text('Campus Electrical Grid & Solar Generation Subsystem', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  children: [
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildSubsystemBox(
                        'Main 33kV / 415V Substation',
                        'Sanctioned: 500 kVA • Transformer Health: 98% Normal • Power Factor: 0.98 • Auto-phase sync active.',
                        Icons.electrical_services_rounded,
                        const Color(0xFFF59E0B),
                        isDark,
                      ),
                    ),
                    SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 10),
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildSubsystemBox(
                        'Rooftop Solar PV Array (150 kWp)',
                        'Current Yield: 84 kW • Total Clean Energy: 48,200 kWh • Avoided Carbon: 38.5 metric tons CO2.',
                        Icons.wb_sunny_rounded,
                        const Color(0xFF10B981),
                        isDark,
                      ),
                    ),
                    SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 10),
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildSubsystemBox(
                        'Dual Cummins 250 kVA DG Sets',
                        'Total Fuel: 1,560 L • Auto-Mains Failure (AMF) panel online • Transfer time < 8 seconds.',
                        Icons.ev_station_rounded,
                        const Color(0xFF6366F1),
                        isDark,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    } else if (_activeCategory == 1) {
      // Water & RO
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
                Text('Potable Water Supply, Underground Sump & Central RO Purification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  children: [
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildSubsystemBox(
                        'Underground Reservoir (100,000 L)',
                        'Current Level: 85,000 L (85%) • Inflow: Municipal line 12,000 L/day • Borewell: 18,000 L/day.',
                        Icons.water_rounded,
                        const Color(0xFF0284C7),
                        isDark,
                      ),
                    ),
                    SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 10),
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildSubsystemBox(
                        'Central RO Purification Plant',
                        'Output Capacity: 2,500 LPH • Water Quality: TDS 68 ppm (Safe Standard: <150 ppm) • UV Sterilizer Active.',
                        Icons.filter_alt_rounded,
                        const Color(0xFF10B981),
                        isDark,
                      ),
                    ),
                    SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 10),
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildSubsystemBox(
                        'Sewage Treatment Plant (STP 50 kLD)',
                        'Treated effluent recycled 100% for campus landscape gardening and washroom flushing systems.',
                        Icons.recycling_rounded,
                        const Color(0xFF059669),
                        isDark,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    } else if (_activeCategory == 2) {
      // Internet & Fiber
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
                Icon(Icons.wifi_rounded, size: 20, color: primaryColor),
                const SizedBox(width: 8),
                Text('Campus Optical Fiber Backbone & Leased Line Telecommunications', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  children: [
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildSubsystemBox(
                        'Primary ISP Leased Line',
                        'Airtel Fiber 1.0 Gbps 1:1 Symmetric • Static IP Block: 8 IPv4 addresses • Latency: 4ms to Tier-1 DC.',
                        Icons.speed_rounded,
                        primaryColor,
                        isDark,
                      ),
                    ),
                    SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 10),
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildSubsystemBox(
                        'Secondary Backup Link',
                        'Tata Telecommunications 500 Mbps Failover • BGP multi-homing with zero-loss automatic failover.',
                        Icons.sync_alt_rounded,
                        const Color(0xFF6366F1),
                        isDark,
                      ),
                    ),
                    SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 10),
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildSubsystemBox(
                        'Wi-Fi 6 Campus Coverage',
                        '128 Cisco Catalyst Access Points deployed across all academic corridors, hostel commons and libraries.',
                        Icons.settings_input_antenna_rounded,
                        const Color(0xFF10B981),
                        isDark,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    } else {
      // Gas & HVAC
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
                Text('Piped Natural Gas (PNG) Lab Pipeline & Central HVAC Chillers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  children: [
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildSubsystemBox(
                        'Piped Gas (Chemistry & Dining)',
                        'Gas Pressure: 0.5 Bar • Automatic emergency shutoff solenoid valves installed with leak alarms.',
                        Icons.local_fire_department_rounded,
                        const Color(0xFFEF4444),
                        isDark,
                      ),
                    ),
                    SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 10),
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildSubsystemBox(
                        'Auditorium Central Chiller (120 TR)',
                        'Water-cooled centrifugal chiller serving main auditorium and library learning commons.',
                        Icons.ac_unit_rounded,
                        const Color(0xFF0284C7),
                        isDark,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSubsystemBox(String title, String desc, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 3),
                Text(desc, style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, IconData icon, Color color, bool isDark) {
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
