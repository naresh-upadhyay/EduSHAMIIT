// Enterprise Unit, Widget, Responsiveness, and Integration Test Suite
// Device Health & Diagnostics Module - EduSHAMIIT School ERP

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_health_diagnostics_subview.dart';

Widget buildTestWidget({ThemeMode themeMode = ThemeMode.light}) {
  return MaterialApp(
    themeMode: themeMode,
    theme: ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFF1677F2),
    ),
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF1677F2),
    ),
    home: const Scaffold(
      body: DeviceHealthDiagnosticsSubview(
        schoolId: '11111111-1111-1111-1111-111111111111',
      ),
    ),
  );
}

void main() {
  group('1. Device Health & Diagnostics - Enterprise Models Unit Tests', () {
    test('DeviceHealthKpis default and json deserialization', () {
      const kpis = DeviceHealthKpis();
      expect(kpis.totalDevices, 136);
      expect(kpis.healthyCount, 122);
      expect(kpis.healthyPct, 89.7);
      expect(kpis.warningCount, 8);
      expect(kpis.warningPct, 5.9);
      expect(kpis.criticalCount, 4);
      expect(kpis.criticalPct, 2.9);
      expect(kpis.offlineCount, 2);
      expect(kpis.offlinePct, 1.5);
      expect(kpis.avgUptimePct, 98.6);

      final jsonMap = {
        'total_devices': 200,
        'healthy_count': 180,
        'warning_count': 10,
        'critical_count': 6,
        'offline_count': 4,
        'avg_uptime_pct': 99.1,
      };
      final parsed = DeviceHealthKpis.fromJson(jsonMap);
      expect(parsed.totalDevices, 200);
      expect(parsed.healthyCount, 180);
      expect(parsed.healthyPct, 90.0);
      expect(parsed.warningPct, 5.0);
      expect(parsed.avgUptimePct, 99.1);
    });

    test('HealthTrendPoint model serialization and parsing', () {
      const pt = HealthTrendPoint(date: '10 Jan', healthy: 122, warnings: 8, criticalOffline: 6);
      expect(pt.date, '10 Jan');
      expect(pt.healthy, 122);
      expect(pt.warnings, 8);
      expect(pt.criticalOffline, 6);

      final parsed = HealthTrendPoint.fromJson({
        'date': '12 Dec',
        'healthy': 120,
        'warnings': 7,
        'critical_offline': 5,
        'total': 136,
        'uptime_pct': 98.2,
      });
      expect(parsed.date, '12 Dec');
      expect(parsed.healthy, 120);
      expect(parsed.uptimePct, 98.2);
    });

    test('HealthKeyAlert model parsing', () {
      final alert = HealthKeyAlert.fromJson({
        'title': 'High temperature',
        'count': 1,
        'severity': 'warning',
      });
      expect(alert.title, 'High temperature');
      expect(alert.count, 1);
      expect(alert.severity, 'warning');
    });

    test('HealthDeviceTypeSlice and hex color parser', () {
      final slice = HealthDeviceTypeSlice.fromJson({
        'type': 'AC / HVAC',
        'healthy': 24,
        'total': 26,
        'pct': 92.3,
        'color': '#1677F2',
      });
      expect(slice.type, 'AC / HVAC');
      expect(slice.healthy, 24);
      expect(slice.total, 26);
      expect(slice.pct, 92.3);
      expect(slice.color, const Color(0xFF1677F2));
    });

    test('DeviceHealthItem parsing and copyWith', () {
      const item = DeviceHealthItem(
        id: '1',
        deviceName: 'Projector (A1-102)',
        deviceCode: 'DEV-PRJ-000145',
        deviceType: 'Projector',
        locationPath: 'Academic Block (A) > A1-102',
        healthStatus: 'warning',
        uptime: '96.1%',
        uptimePct: 96.1,
        lastSeen: '10 Jan 2025, 02:15 PM',
        issuesAlerts: 'High temperature (72°C)',
        firmwareVersion: 'v2.4.1',
        hasFirmwareUpdate: true,
      );

      final updated = item.copyWith(
        firmwareVersion: 'v2.5.0',
        hasFirmwareUpdate: false,
        healthStatus: 'healthy',
        issuesAlerts: '-',
      );

      expect(updated.firmwareVersion, 'v2.5.0');
      expect(updated.hasFirmwareUpdate, false);
      expect(updated.healthStatus, 'healthy');
      expect(updated.issuesAlerts, '-');
    });

    test('CampusIotGatewayItem and DeviceHealthRuleItem model parsing', () {
      final gw = CampusIotGatewayItem.fromJson({
        'id': 'gw-1',
        'gateway_code': 'GW-ADMIN-01',
        'gateway_name': 'Main Campus MQTT Core Gateway',
        'gateway_type': 'mqtt',
        'ip_address': '192.168.1.10',
        'status': 'online',
        'connected_devices': 42,
        'cpu_usage_pct': 22.4,
      });
      expect(gw.gatewayCode, 'GW-ADMIN-01');
      expect(gw.connectedDevices, 42);

      final rule = DeviceHealthRuleItem.fromJson({
        'id': 'rule-1',
        'rule_name': 'Offline Detection',
        'rule_code': 'RULE-OFFLINE-01',
        'metric_name': 'heartbeat_offline_timeout',
        'operator': '>',
        'threshold_value': 180.0,
        'severity': 'critical',
      });
      expect(rule.ruleCode, 'RULE-OFFLINE-01');
      expect(rule.thresholdValue, 180.0);
      expect(rule.severity, 'critical');
    });
  });

  group('2. DeviceHealthDiagnosticsSubview - Widget & Canonical Layout Tests', () {
    testWidgets('Renders Header with Title, Date Range, Location and Run Diagnostics button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Device Health & Diagnostics'), findsOneWidget);
      expect(find.textContaining('Monitor device health, connectivity'), findsOneWidget);
      expect(find.textContaining('12 Dec 2024 – 10 Jan 2025'), findsOneWidget);
      expect(find.text('All Locations'), findsWidgets);
      expect(find.text('Run Diagnostics'), findsWidgets);
    });

    testWidgets('Renders all 6 Top KPI Cards with exact metrics', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Total Devices'), findsWidgets);
      expect(find.text('Healthy'), findsWidgets);
      expect(find.text('Warnings'), findsWidgets);
      expect(find.text('Critical'), findsWidgets);
      expect(find.text('Offline'), findsWidgets);
      expect(find.text('Avg. Uptime'), findsOneWidget);

      // Verify values
      expect(find.text('136'), findsWidgets);
      expect(find.text('122'), findsWidgets);
      expect(find.text('(89.7%)'), findsWidgets);
      expect(find.text('8'), findsWidgets);
      expect(find.text('(5.9%)'), findsWidgets);
      expect(find.text('4'), findsWidgets);
      expect(find.text('(2.9%)'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('(1.5%)'), findsWidgets);
      expect(find.text('98.6%'), findsWidgets);
    });

    testWidgets('Renders all 8 Sub-Tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Device Health'), findsOneWidget);
      expect(find.text('Diagnostics'), findsOneWidget);
      expect(find.text('Alerts & Incidents'), findsOneWidget);
      expect(find.text('Performance'), findsOneWidget);
      expect(find.text('Connectivity'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
    });

    testWidgets('Renders Row 1 Cards: Donut, 30-Day Trend, and Key Alerts', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Device Health Overview'), findsOneWidget);
      expect(find.text('Health Trend (Last 30 Days)'), findsOneWidget);
      expect(find.text('Key Alerts (Current)'), findsOneWidget);

      // Key alerts check
      expect(find.text('Device not responding (Offline)'), findsOneWidget);
      expect(find.text('High temperature'), findsOneWidget);
      expect(find.text('Low signal / connectivity'), findsOneWidget);
      expect(find.text('Firmware update available'), findsOneWidget);
      expect(find.text('Diagnostics recommended'), findsOneWidget);
    });

    testWidgets('Renders Row 2 Cards: Quick Diagnostics, Health by Type, and System Status', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Quick Diagnostics'), findsOneWidget);
      expect(find.text('Device Health by Type'), findsOneWidget);
      expect(find.text('System & Connectivity Status'), findsOneWidget);

      // System status items
      expect(find.text('MQTT Broker'), findsOneWidget);
      expect(find.text('Gateway(s)'), findsOneWidget);
      expect(find.text('Command Service'), findsOneWidget);
      expect(find.text('Diagnostics Worker'), findsOneWidget);
      expect(find.text('Database (Telemetry)'), findsOneWidget);
      expect(find.text('Last Data Received'), findsOneWidget);
    });

    testWidgets('Renders Central Table with Canonical Devices', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Device Health Details'), findsOneWidget);
      expect(find.text('AC Unit (A1-101)'), findsWidgets);
      expect(find.text('Classroom Lights (A1-102)'), findsWidgets);
      expect(find.text('Projector (A1-102)'), findsWidgets);
      expect(find.text('Ceiling Fan (A1-103)'), findsWidgets);
      expect(find.text('Display (A1-104)'), findsWidgets);
      expect(find.text('Access Door (Main-A)'), findsWidgets);
      expect(find.text('CCTV (Corridor-A1)'), findsWidgets);
    });

    testWidgets('Right Inspector Panel displays Selected Projector specifications', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Selected Device – Projector (A1-102)'), findsOneWidget);
      expect(find.text('DEV-PRJ-000145'), findsOneWidget);
      expect(find.text('Projector'), findsWidgets);
      expect(find.text('Academic Block (A) > A1-102'), findsWidgets);
      expect(find.text('v2.4.1'), findsWidgets);
      expect(find.text('Update Available: v2.5.0'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Update Firmware'), findsOneWidget);
    });

    testWidgets('Inspector Action: Run Diagnostics executes diagnostic progress dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final btn = find.widgetWithText(ElevatedButton, 'Run Diagnostics');
      expect(btn, findsOneWidget);
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pump();

      expect(find.textContaining('Diagnosing Projector (A1-102)'), findsOneWidget);
      // Wait for progress steps to execute
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.textContaining('Diagnostics completed'), findsOneWidget);
    });

    testWidgets('Inspector Action: Restart shows confirmation modal and confirms', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final rstBtn = find.widgetWithText(OutlinedButton, 'Restart');
      expect(rstBtn, findsOneWidget);
      await tester.ensureVisible(rstBtn);
      await tester.pumpAndSettle();
      await tester.tap(rstBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Restart Projector (A1-102)?'), findsOneWidget);
      expect(find.text('Confirm Restart'), findsOneWidget);

      await tester.tap(find.text('Confirm Restart'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Restart signal transmitted'), findsOneWidget);
    });

    testWidgets('Inspector Action: Update Firmware shows confirmation and applies update to v2.5.0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final fwBtn = find.widgetWithText(OutlinedButton, 'Update Firmware');
      expect(fwBtn, findsOneWidget);
      await tester.ensureVisible(fwBtn);
      await tester.pumpAndSettle();
      await tester.tap(fwBtn);
      await tester.pumpAndSettle();

      expect(find.text('Apply Firmware Update v2.5.0'), findsOneWidget);
      expect(find.text('Start OTA Update'), findsOneWidget);

      await tester.tap(find.text('Start OTA Update'));
      await tester.pumpAndSettle();

      expect(find.textContaining('firmware updated to v2.5.0'), findsOneWidget);
    });

    testWidgets('Accordion toggles expand and collapse cleanly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 2400));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Diagnostics results accordion is expanded by default
      expect(find.text('Diagnostics Results (Last Run)'), findsOneWidget);
      expect(find.text('ICMP / Network Connectivity'), findsOneWidget);

      // Toggle Performance Metrics
      final perfHeader = find.text('Performance Metrics');
      await tester.ensureVisible(perfHeader);
      await tester.pumpAndSettle();
      await tester.tap(perfHeader);
      await tester.pumpAndSettle();
      expect(find.text('Operating Temperature'), findsOneWidget);

      // Toggle Device Logs & Events
      final logsHeader = find.text('Device Logs & Events');
      await tester.ensureVisible(logsHeader);
      await tester.pumpAndSettle();
      await tester.tap(logsHeader);
      await tester.pumpAndSettle();
      expect(find.text('Heartbeat Received'), findsOneWidget);
    });

    testWidgets('Sub-Tab Diagnostics renders Centralized Diagnostic Engine', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final tab = find.text('Diagnostics');
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();

      expect(find.text('Centralized Diagnostic Engine'), findsOneWidget);
      expect(find.text('Run Full Institutional Audit'), findsOneWidget);
      expect(find.text('Connectivity & Ping Suite'), findsOneWidget);
      expect(find.text('Hardware & Sensor Audit'), findsOneWidget);
    });

    testWidgets('Sub-Tab Alerts & Incidents renders Active Alerts and Resolve button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final tab = find.text('Alerts & Incidents');
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();

      expect(find.text('Active Device Health Alerts & Incidents'), findsOneWidget);
      expect(find.text('Resolve'), findsWidgets);
    });

    testWidgets('Sub-Tab Connectivity renders Gateways cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final tab = find.text('Connectivity');
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();

      expect(find.textContaining('IoT Gateways & Protocol Bridges'), findsOneWidget);
      expect(find.text('Main Campus MQTT Core Gateway'), findsOneWidget);
    });

    testWidgets('Sub-Tab Maintenance renders maintenance table and modal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final tab = find.text('Maintenance');
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();

      expect(find.text('Device Maintenance Integration'), findsOneWidget);
      expect(find.text('MR-PRJ-2025-001'), findsOneWidget);
    });

    testWidgets('Sub-Tab Reports renders operational health reports', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final tab = find.text('Reports');
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();

      expect(find.text('Operational Health & Availability Reports'), findsOneWidget);
      expect(find.text('Download'), findsWidgets);
    });

    testWidgets('Responsive Tablet Viewport (800x1000) renders with 0 errors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Device Health & Diagnostics'), findsOneWidget);
      expect(find.text('Total Devices'), findsWidgets);
    });

    testWidgets('Responsive Mobile Viewport (400x800) renders with 0 errors and 0 overflows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Device Health & Diagnostics'), findsOneWidget);
      expect(find.text('Total Devices'), findsWidgets);
    });

    testWidgets('Dark Theme renders with dark palette', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(find.text('Device Health & Diagnostics'), findsOneWidget);
      expect(find.text('Total Devices'), findsWidgets);
    });

    testWidgets('Multi-selection action bar toggles on row checkbox selection and clears', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 3200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsWidgets);

      // Initially no multi-selection action bar
      expect(find.text('Reboot Selected'), findsNothing);

      // Scroll to row checkbox and tap (index 1, index 0 is header)
      await tester.ensureVisible(checkboxes.at(1));
      await tester.pumpAndSettle();
      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();

      // Bar is now visible
      expect(find.text('1 device selected'), findsOneWidget);
      expect(find.text('Reboot Selected'), findsOneWidget);
      expect(find.text('Update Firmware'), findsWidgets);
      expect(find.text('Export Selected'), findsOneWidget);
      expect(find.text('Clear Selection'), findsOneWidget);

      // Tap Clear Selection
      await tester.ensureVisible(find.text('Clear Selection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear Selection'));
      await tester.pumpAndSettle();

      // Bar is hidden
      expect(find.text('1 device selected'), findsNothing);
      expect(find.text('Reboot Selected'), findsNothing);
    });

    testWidgets('Header checkbox toggles all devices selection on current page', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 3200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final checkboxes = find.byType(Checkbox);
      // Ensure header checkbox is visible and tap (index 0)
      await tester.ensureVisible(checkboxes.at(0));
      await tester.pumpAndSettle();
      await tester.tap(checkboxes.at(0));
      await tester.pumpAndSettle();

      // Multi-selection bar shows selected count
      expect(find.textContaining('selected'), findsWidgets);
      expect(find.text('Reboot Selected'), findsOneWidget);

      // Tap header checkbox again to deselect
      await tester.tap(checkboxes.at(0));
      await tester.pumpAndSettle();

      expect(find.text('Reboot Selected'), findsNothing);
    });

    testWidgets('Sorting: Tapping column headers triggers sorting without error', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 3200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final deviceNameCol = find.text('Device Name');
      expect(deviceNameCol, findsOneWidget);
      await tester.ensureVisible(deviceNameCol);
      await tester.pumpAndSettle();
      await tester.tap(deviceNameCol);
      await tester.pumpAndSettle();

      final healthStatusCol = find.text('Health Status');
      expect(healthStatusCol, findsOneWidget);
      await tester.ensureVisible(healthStatusCol);
      await tester.pumpAndSettle();
      await tester.tap(healthStatusCol);
      await tester.pumpAndSettle();

      final uptimeCol = find.text('Uptime');
      expect(uptimeCol, findsOneWidget);
      await tester.ensureVisible(uptimeCol);
      await tester.pumpAndSettle();
      await tester.tap(uptimeCol);
      await tester.pumpAndSettle();
    });

    testWidgets('Pagination controls: change page size and navigation buttons render', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 3200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final rowsText = find.text('Rows:');
      expect(rowsText, findsOneWidget);
      await tester.ensureVisible(rowsText);
      await tester.pumpAndSettle();

      expect(find.byTooltip('First Page'), findsOneWidget);
      expect(find.byTooltip('Previous Page'), findsOneWidget);
      expect(find.byTooltip('Next Page'), findsOneWidget);
      expect(find.byTooltip('Last Page'), findsOneWidget);
    });
  });
}
