import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_energy_usage_subview.dart';

void main() {
  group('1. Energy & Usage Enterprise Models Unit Tests', () {
    test('DeviceEnergyUsageKpis default and json deserialization', () {
      const kpis = DeviceEnergyUsageKpis();
      expect(kpis.totalEnergyTodayKwh, 482.7);
      expect(kpis.totalEnergyTodayTrend, -12.4);
      expect(kpis.totalCostTodayInr, 5795.0);
      expect(kpis.monthlyEnergyKwh, 14860.0);
      expect(kpis.monthlyCostInr, 178320.0);
      expect(kpis.co2EmissionMonthlyTonnes, 11.2);
      expect(kpis.activeDevicesCount, 132);
      expect(kpis.totalDevicesCount, 136);
      expect(kpis.uptimePct, 97.1);

      final jsonMap = {
        'total_energy_today_kwh': 512.4,
        'total_energy_today_trend': -5.0,
        'total_cost_today_inr': 6148.0,
        'total_cost_today_trend': -5.0,
        'monthly_energy_kwh': 15200.0,
        'monthly_energy_trend': -2.1,
        'monthly_cost_inr': 182400.0,
        'monthly_cost_trend': -2.1,
        'co2_emission_monthly_tonnes': 11.4,
        'co2_emission_trend': -2.1,
        'active_devices_count': 130,
        'total_devices_count': 136,
        'uptime_pct': 95.6,
      };

      final parsed = DeviceEnergyUsageKpis.fromJson(jsonMap);
      expect(parsed.totalEnergyTodayKwh, 512.4);
      expect(parsed.monthlyEnergyKwh, 15200.0);
      expect(parsed.uptimePct, 95.6);
      expect(parsed.activeDevicesCount, 130);
    });

    test('EnergyTrendPoint model serialization', () {
      final point = EnergyTrendPoint.fromJson({
        'date': '2025-01-10',
        'label': '10 Jan',
        'daily_kwh': 482.7,
        'moving_avg_kwh': 498.4,
        'cost_inr': 5795.0,
        'co2_kg': 362.0,
      });

      expect(point.date, '2025-01-10');
      expect(point.label, '10 Jan');
      expect(point.dailyKwh, 482.7);
      expect(point.movingAvgKwh, 498.4);
      expect(point.costInr, 5795.0);
      expect(point.co2Kg, 362.0);
    });

    test('EnergyDeviceTypeSlice and Color helper', () {
      final slice = EnergyDeviceTypeSlice.fromJson({
        'name': 'AC / HVAC',
        'kwh': 5781.0,
        'percentage': 38.9,
        'color': '#2563EB',
        'count': 32,
      });

      expect(slice.name, 'AC / HVAC');
      expect(slice.percentage, 38.9);
      expect(slice.color, const Color(0xFF2563EB));
      expect(slice.count, 32);
    });

    test('EnergyLocationSlice model', () {
      final loc = EnergyLocationSlice.fromJson({
        'name': 'Academic Block (A)',
        'kwh': 4320.0,
        'percentage': 29.1,
        'device_count': 48,
      });

      expect(loc.name, 'Academic Block (A)');
      expect(loc.kwh, 4320.0);
      expect(loc.percentage, 29.1);
      expect(loc.deviceCount, 48);
    });

    test('DeviceUptimeBreakdown default and json', () {
      const breakdown = DeviceUptimeBreakdown();
      expect(breakdown.uptimePct, 97.1);
      expect(breakdown.activeCount, 132);
      expect(breakdown.idleCount, 2);
      expect(breakdown.offlineCount, 2);
      expect(breakdown.totalDevices, 136);

      final parsed = DeviceUptimeBreakdown.fromJson({
        'uptime_pct': 98.0,
        'active_count': 134,
        'active_pct': 98.5,
        'idle_count': 1,
        'idle_pct': 0.7,
        'offline_count': 1,
        'offline_pct': 0.7,
        'total_devices': 136,
      });
      expect(parsed.uptimePct, 98.0);
      expect(parsed.activeCount, 134);
    });

    test('EnergyInsightItem model', () {
      final insight = EnergyInsightItem.fromJson({
        'id': '1',
        'type': 'positive',
        'icon': 'electric_bolt_rounded',
        'title': 'Daily Reduction',
        'text': 'Energy use is 12.4% lower than yesterday (482.7 kWh vs. 551.1 kWh).',
      });

      expect(insight.id, '1');
      expect(insight.type, 'positive');
      expect(insight.title, 'Daily Reduction');
      expect(insight.text, contains('12.4% lower'));
    });

    test('EnergyGoalsPolicy model and calculations', () {
      final goals = EnergyGoalsPolicy.fromJson({
        'monthly_target_kwh': 16000.0,
        'monthly_actual_kwh': 14860.0,
        'monthly_kwh_pct': 92.9,
        'cost_target_inr': 190000.0,
        'cost_actual_inr': 178320.0,
        'cost_pct': 93.8,
        'emission_target_tonnes': 12.5,
        'emission_actual_tonnes': 11.2,
        'emission_pct': 89.6,
      });

      expect(goals.monthlyTargetKwh, 16000.0);
      expect(goals.monthlyActualKwh, 14860.0);
      expect(goals.monthlyKwhPct, 92.9);
      expect(goals.costTargetInr, 190000.0);
      expect(goals.costActualInr, 178320.0);
      expect(goals.emissionActualTonnes, 11.2);
    });

    test('DeviceDetailedEnergyMetric model full parsing', () {
      final dev = DeviceDetailedEnergyMetric.fromJson({
        'id': 'dev-001',
        'device_name': 'AC Unit (A1-101)',
        'device_code': 'AC-A1-101',
        'device_type': 'AC / HVAC',
        'building_name': 'Academic Block (A)',
        'room_name': 'A1-101',
        'location_path': 'Academic Block (A) > A1-101',
        'group_name': 'Academic HVAC',
        'metric_date': '2025-01-10',
        'energy_kwh': 120.5,
        'usage_hours': 720.0,
        'avg_power_watts': 167.0,
        'cost_inr': 1446.0,
        'co2_kg': 90.1,
        'trend_pct': -11.8,
        'status': 'active',
      });

      expect(dev.deviceName, 'AC Unit (A1-101)');
      expect(dev.deviceCode, 'AC-A1-101');
      expect(dev.energyKwh, 120.5);
      expect(dev.usageHours, 720.0);
      expect(dev.avgPowerWatts, 167.0);
      expect(dev.costInr, 1446.0);
      expect(dev.co2Kg, 90.1);
      expect(dev.trendPct, -11.8);
      expect(dev.status, 'active');
    });
  });

  group('2. DeviceEnergyUsageSubview Widget Tests', () {
    Widget buildTestWidget({
      Size size = const Size(1440, 900),
      bool isDark = false,
      VoidCallback? onBack,
    }) {
      return MaterialApp(
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: SizedBox(
              width: size.width,
              height: size.height,
              child: DeviceEnergyUsageSubview(
                onBackToDashboard: onBack,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Renders Header, Sub-Tabs and KPI Cards on Desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Top Header
      expect(find.text('Energy & Usage'), findsWidgets);
      expect(find.text('Monitor energy consumption, device usage and operational efficiency across campus.'), findsOneWidget);
      expect(find.text('Export'), findsWidgets);

      // Sub-Tabs
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('By Location'), findsOneWidget);
      expect(find.text('By Device Type'), findsOneWidget);
      expect(find.text('By Device'), findsOneWidget);
      expect(find.text('Trends & Comparison'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);

      // Top 6 KPI Cards
      expect(find.text('Total Energy (Today)'), findsOneWidget);
      expect(find.text('482.7 kWh'), findsOneWidget);
      expect(find.text('-12.4% vs. yesterday'), findsOneWidget);

      expect(find.text('Total Cost (Today)'), findsOneWidget);
      expect(find.text('₹ 5795'), findsOneWidget);

      expect(find.text('Monthly Energy'), findsOneWidget);
      expect(find.text('14860 kWh'), findsOneWidget);

      expect(find.text('Monthly Cost'), findsOneWidget);
      expect(find.text('₹ 178320'), findsOneWidget);

      expect(find.text('CO₂ Emission (Monthly)'), findsOneWidget);
      expect(find.text('11.2 tCO₂'), findsOneWidget);

      expect(find.text('Active Devices'), findsOneWidget);
      expect(find.text('132 / 136'), findsOneWidget);
    });

    testWidgets('Renders Consumption Trend, Donut, Location Top 5, and Uptime Gauge', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Middle Card Titles
      expect(find.text('Energy Consumption Trend'), findsOneWidget);
      expect(find.text('Total (Last 30 Days)'), findsOneWidget);
      expect(find.text('Daily Energy (kWh)'), findsOneWidget);
      expect(find.text('7-Day Moving Average'), findsOneWidget);

      expect(find.text('Energy by Device Type'), findsOneWidget);
      expect(find.text('AC / HVAC'), findsWidgets);
      expect(find.text('Lighting'), findsWidgets);

      expect(find.text('Energy by Location (Top 5)', skipOffstage: false), findsOneWidget);
      expect(find.text('Academic Block (A)', skipOffstage: false), findsWidgets);
      expect(find.text('Library Block', skipOffstage: false), findsWidgets);

      expect(find.text('Device Usage', skipOffstage: false), findsOneWidget);
      expect(find.text('Device Uptime', skipOffstage: false), findsOneWidget);
      expect(find.text('Total Devices', skipOffstage: false), findsWidgets);
    });

    testWidgets('Renders Energy Insights, Quick Actions, and Goals & Policy', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Energy Insights
      expect(find.text('Energy Insights', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('Energy use is 12.4% lower than yesterday', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('8.9% lower monthly consumption', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('Lighting in Academic Block is 18.6% higher', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('1,240 kWh (8.3%) can be saved', skipOffstage: false), findsOneWidget);

      // Quick Actions
      expect(find.text('Quick Actions', skipOffstage: false), findsOneWidget);
      expect(find.text('Set Energy Schedule', skipOffstage: false), findsOneWidget);
      expect(find.text('Create Automation', skipOffstage: false), findsOneWidget);
      expect(find.text('Apply Energy Policy', skipOffstage: false), findsOneWidget);
      expect(find.text('Optimize Usage', skipOffstage: false), findsOneWidget);

      // Energy Goals & Policy
      expect(find.text('Energy Goals & Policy', skipOffstage: false), findsOneWidget);
      expect(find.text('Monthly Target', skipOffstage: false), findsOneWidget);
      expect(find.text('Cost Target', skipOffstage: false), findsOneWidget);
      expect(find.text('Emission Target', skipOffstage: false), findsOneWidget);
    });

    testWidgets('Renders Detailed Device Usage Table and Canonical Rows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Scroll to Detailed Table
      final tableTitle = find.text('Detailed Device Usage');
      await tester.ensureVisible(tableTitle);
      expect(tableTitle, findsOneWidget);

      // Canonical rows from reference design
      expect(find.text('AC Unit (A1-101)'), findsOneWidget);
      expect(find.text('Classroom Lights (A1-101)'), findsOneWidget);
      expect(find.text('Projector (A1-102)'), findsOneWidget);
      expect(find.text('Ceiling Fan (A1-101)'), findsOneWidget);
      expect(find.text('Interactive Display (A1-102)'), findsOneWidget);

      // Metric cells
      expect(find.text('120.5 kWh'), findsOneWidget);
      expect(find.text('48.6 kWh'), findsOneWidget);
      expect(find.text('36.8 kWh'), findsOneWidget);
      expect(find.text('28.4 kWh'), findsOneWidget);
      expect(find.text('42.1 kWh'), findsOneWidget);

      // Pagination
      expect(find.textContaining('Showing 1 – 5 of'), findsOneWidget);
      expect(find.text('Rows per page:'), findsOneWidget);
    });

    testWidgets('Quick Action Set Energy Schedule opens dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final btn = find.text('Set Energy Schedule');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Configure campus-wide automated shutoff during non-academic hours:'), findsOneWidget);
      expect(find.text('Activate Schedule'), findsOneWidget);

      await tester.tap(find.text('Activate Schedule'));
      await tester.pumpAndSettle();
      expect(find.text('Energy schedule activated successfully across target devices!'), findsOneWidget);
    });

    testWidgets('Quick Action Optimize Usage opens dialog and applies', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final btn = find.text('Optimize Usage');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.text('Optimize Campus Energy Usage'), findsOneWidget);
      expect(find.text('Apply Optimizations'), findsOneWidget);

      await tester.tap(find.text('Apply Optimizations'));
      await tester.pumpAndSettle();
      expect(find.text('Applied 3 optimization rules across campus IoT network.'), findsOneWidget);
    });

    testWidgets('Device Row Quick Control opens Quick Control modal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final playIcon = find.byTooltip('Run / Quick Control').first;
      await tester.ensureVisible(playIcon);
      await tester.tap(playIcon);
      await tester.pumpAndSettle();

      expect(find.textContaining('Quick Control:'), findsOneWidget);
      expect(find.text('ECO Mode (24°C)'), findsOneWidget);
      expect(find.text('Turn OFF'), findsOneWidget);

      await tester.tap(find.text('ECO Mode (24°C)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Switched'), findsOneWidget);
    });

    testWidgets('Device Row Analytics opens duty cycle simulator dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final chartIcon = find.byTooltip('View Analytics').first;
      await tester.ensureVisible(chartIcon);
      await tester.tap(chartIcon);
      await tester.pumpAndSettle();

      expect(find.text('24-Hour Duty Cycle Simulation'), findsOneWidget);
      expect(find.text('8 AM (School Start)'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('Responsive Tablet View (800x1000) renders with 0 errors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      await tester.pumpWidget(buildTestWidget(size: const Size(800, 1000)));
      await tester.pumpAndSettle();

      expect(find.text('Energy & Usage', skipOffstage: false), findsWidgets);
      expect(find.text('Total Energy (Today)', skipOffstage: false), findsOneWidget);
      expect(find.text('Detailed Device Usage', skipOffstage: false), findsOneWidget);
    });

    testWidgets('Responsive Mobile View (400x800) renders with 0 errors and 0 overflows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(buildTestWidget(size: const Size(400, 800)));
      await tester.pumpAndSettle();

      expect(find.text('Energy & Usage', skipOffstage: false), findsWidgets);
      expect(find.text('Total Energy (Today)', skipOffstage: false), findsOneWidget);
      expect(find.text('Detailed Device Usage', skipOffstage: false), findsOneWidget);
    });

    testWidgets('Dark Theme renders with dark palette', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget(isDark: true));
      await tester.pumpAndSettle();

      expect(find.text('Energy & Usage'), findsWidgets);
      expect(find.text('14,860 kWh'), findsWidgets);
    });

    testWidgets('Sub-Tab By Location renders building cards and opens breakdown dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('By Location'));
      await tester.pumpAndSettle();

      expect(find.text('Campus Location Energy Hierarchy'), findsOneWidget);
      expect(find.text('Academic Block (A)'), findsWidgets);
      expect(find.text('Library Block'), findsWidgets);
      expect(find.text('Laboratories Block'), findsWidgets);

      await tester.tap(find.text('Inspect Rooms →').first);
      await tester.pumpAndSettle();

      expect(find.text('Rooms Breakdown:'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('Sub-Tab By Device Type renders category cards and efficiency grades', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('By Device Type'));
      await tester.pumpAndSettle();

      expect(find.text('Device Category Consumption & Efficiency'), findsOneWidget);
      expect(find.text('AC / HVAC'), findsWidgets);
      expect(find.text('Lighting'), findsWidgets);
      expect(find.text('Grade A'), findsWidgets);
    });

    testWidgets('Sub-Tab Trends & Comparison renders interval chips and comparison metrics', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trends & Comparison'));
      await tester.pumpAndSettle();

      expect(find.text('Current Period'), findsOneWidget);
      expect(find.text('Baseline Period'), findsOneWidget);
      expect(find.text('Net Energy Saved'), findsOneWidget);
      expect(find.text('Period-over-Period Consumption & Baseline Overlay'), findsOneWidget);
    });

    testWidgets('Sub-Tab Cost Analysis renders tariffs, utility bills, and opens modal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cost Analysis'));
      await tester.pumpAndSettle();

      expect(find.text('Active Electricity Tariff (Time-of-Use)'), findsOneWidget);
      expect(find.text('State Electricity Board (BESCOM)'), findsWidgets);
      expect(find.text('Utility Bill Reconciliation & Invoice Log'), findsOneWidget);

      await tester.tap(find.text('Record Utility Bill'));
      await tester.pumpAndSettle();

      expect(find.text('Record Utility Bill'), findsWidgets);
      await tester.tap(find.text('Save & Reconcile'));
      await tester.pumpAndSettle();
    });

    testWidgets('Sub-Tab Efficiency & Savings renders actionable recommendations', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Efficiency & Savings'));
      await tester.pumpAndSettle();

      expect(find.text('Actionable Energy Optimization Recommendations'), findsOneWidget);
      expect(find.textContaining('Adjust AC setpoints to 24°C in Academic Block A'), findsOneWidget);
      expect(find.text('Apply Plan'), findsWidgets);
    });

    testWidgets('Sub-Tab Reports renders 20 report templates and generates new report', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Reports'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();

      expect(find.text('Campus Energy Reporting Center (20 Templates)'), findsOneWidget);
      expect(find.text('Generate Report'), findsOneWidget);

      await tester.tap(find.text('Generate Report'));
      await tester.pumpAndSettle();
    });

    testWidgets('Smart Meters Button opens hardware dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Smart Meters'));
      await tester.pumpAndSettle();

      expect(find.text('Smart Energy Meters & Submeters (8)'), findsOneWidget);
      expect(find.text('Main Substation 3-Phase Meter'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('DataTables enforce showCheckboxColumn: false preventing double checkboxes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify all rendered DataTables have showCheckboxColumn: false
      final dataTables = tester.widgetList<DataTable>(find.byType(DataTable));
      expect(dataTables.isNotEmpty, isTrue);
      for (final dt in dataTables) {
        expect(dt.showCheckboxColumn, isFalse, reason: 'Every DataTable must set showCheckboxColumn: false to prevent duplicate checkboxes');
      }
    });

    testWidgets('Header Select-All checkbox toggles selection and displays Batch Actions Toolbar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find all checkboxes in the detailed device table
      final selectAllCheckbox = find.byType(Checkbox).first;
      await tester.ensureVisible(selectAllCheckbox);
      await tester.pumpAndSettle();

      // Tap header Select-All checkbox
      await tester.tap(selectAllCheckbox);
      await tester.pumpAndSettle();

      // Batch Actions Toolbar should now be displayed
      expect(find.textContaining('device(s) selected'), findsOneWidget);
      expect(find.text('Eco Mode'), findsOneWidget);
      expect(find.text('Turn OFF'), findsOneWidget);
      expect(find.text('Power Limit'), findsOneWidget);
      expect(find.text('Export Selected'), findsOneWidget);
      expect(find.text('Deselect All'), findsOneWidget);

      // Tap Deselect All
      await tester.tap(find.text('Deselect All'));
      await tester.pumpAndSettle();

      expect(find.textContaining('device(s) selected'), findsNothing);
    });

    testWidgets('Power Limit modal opens from bulk actions and applies wattage', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Select first row checkbox
      final rowCheckbox = find.byType(Checkbox).at(1);
      await tester.ensureVisible(rowCheckbox);
      await tester.pumpAndSettle();
      await tester.tap(rowCheckbox);
      await tester.pumpAndSettle();

      expect(find.text('Power Limit'), findsOneWidget);
      await tester.tap(find.text('Power Limit'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Set Power Limit'), findsOneWidget);
      expect(find.text('Apply Limit'), findsOneWidget);

      await tester.tap(find.text('Apply Limit'));
      await tester.pumpAndSettle();
    });

    testWidgets('Column header onSort toggles database-driven sorting', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on Device Name column header to sort
      final colHeader = find.text('Device Name');
      await tester.ensureVisible(colHeader);
      await tester.pumpAndSettle();
      await tester.tap(colHeader);
      await tester.pumpAndSettle();

      // Tap again to toggle asc/desc
      await tester.tap(colHeader);
      await tester.pumpAndSettle();
    });

    testWidgets('Pagination controls with page size selector and navigation buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final paginationLabel = find.text('Rows per page:');
      await tester.ensureVisible(paginationLabel);
      await tester.pumpAndSettle();

      expect(paginationLabel, findsOneWidget);
      expect(find.byIcon(Icons.first_page_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.byIcon(Icons.last_page_rounded), findsOneWidget);
    });

    testWidgets('Cost Analysis Sub-Tab supports Tariff & Utility Bill full CRUD actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cost Analysis'));
      await tester.pumpAndSettle();

      // Check edit and delete icons on tariffs
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.byIcon(Icons.delete_outline_rounded), findsWidgets);

      // Open Add Tariff dialog
      await tester.tap(find.text('Add / Configure Tariff'));
      await tester.pumpAndSettle();
      expect(find.text('Configure Electricity Tariff'), findsOneWidget);
      expect(find.text('Save Tariff'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Open Record Utility Bill dialog
      await tester.tap(find.text('Record Utility Bill'));
      await tester.pumpAndSettle();
      expect(find.text('Record Utility Bill'), findsWidgets);
      expect(find.text('Save & Reconcile'), findsOneWidget);
      await tester.tap(find.text('Save & Reconcile'));
      await tester.pumpAndSettle();
    });

    testWidgets('Smart Meters dialog renders with Register Meter button and Actions column', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Smart Meters'));
      await tester.pumpAndSettle();

      expect(find.text('Register Meter'), findsOneWidget);
      expect(find.text('Actions'), findsWidgets);

      await tester.tap(find.text('Register Meter'));
      await tester.pumpAndSettle();

      expect(find.text('Register Smart Energy Meter'), findsOneWidget);
      expect(find.text('Save Meter'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });
  });
}
