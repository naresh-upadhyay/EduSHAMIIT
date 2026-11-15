import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_audit_logs_subview.dart';

void main() {
  group('Enterprise Audit Logs Models Tests', () {
    test('AuditLogEntry JSON deserialization with full cryptographic metadata', () {
      final json = {
        'id': 'evt-001',
        'event_id': 'EVT-20250110-00010',
        'correlation_id': 'corr-cmd-ac-001',
        'causation_id': 'user-click-live-control',
        'timestamp': '10 Jan 2025, 02:18:27 PM',
        'occurred_at': '2025-01-10T14:18:27+05:30',
        'user': 'Admin',
        'user_role': 'Super Admin',
        'event_type': 'Device Command',
        'category': 'device_command',
        'action': 'Turn ON',
        'target_type': 'device',
        'target': 'AC Unit (A1-101)',
        'location': 'Academic Block (A) > Room 101',
        'details': 'Mode: Cool, Temp: 24°C',
        'result': 'Success',
        'source': 'Web',
        'ip_address': '192.168.1.100',
        'user_agent': 'Mozilla/5.0 Chrome/120',
        'device_code': 'DEV-AC-00101',
        'previous_state': {'power': 'off'},
        'new_state': {'power': 'on', 'temperature': 24},
        'metadata': {'qos': 1, 'ack_latency_ms': 42},
        'hash': '467197cf86926563916ab6b80d5eeaac6256a360993679e6fb2e96c3106c156d',
      };

      final entry = AuditLogEntry.fromJson(json);
      expect(entry.eventId, 'EVT-20250110-00010');
      expect(entry.user, 'Admin');
      expect(entry.userRole, 'Super Admin');
      expect(entry.eventType, 'Device Command');
      expect(entry.action, 'Turn ON');
      expect(entry.target, 'AC Unit (A1-101)');
      expect(entry.details, 'Mode: Cool, Temp: 24°C');
      expect(entry.result, 'Success');
      expect(entry.source, 'Web');
      expect(entry.hash, isNotNull);
      expect(entry.previousState['power'], 'off');
      expect(entry.newState['temperature'], 24);
    });

    test('AuditRetentionPolicy JSON deserialization', () {
      final json = {
        'id': 'pol-1',
        'policy_name': 'Access & Security Compliance',
        'category': 'Access & Permissions',
        'retention_days': 730,
        'auto_archive': true,
        'archive_storage': 'Immutable WORM Storage (SOC2/ISO27001)',
        'is_immutable': true,
        'status': 'Active',
      };

      final policy = AuditRetentionPolicy.fromJson(json);
      expect(policy.policyName, 'Access & Security Compliance');
      expect(policy.retentionDays, 730);
      expect(policy.autoArchive, isTrue);
      expect(policy.isImmutable, isTrue);
      expect(policy.status, 'Active');
    });

    test('AuditReportItem JSON deserialization', () {
      final json = {
        'id': 'rep-1',
        'report_title': 'Monthly Device Control Audit Trail',
        'report_type': 'Device Operations',
        'requested_by': 'Admin',
        'format': 'PDF',
        'date_range': '01 Dec 2024 - 31 Dec 2024',
        'records_count': 12430,
        'file_size': '4.2 MB',
        'status': 'Completed',
        'created_at': '2025-01-01',
      };

      final report = AuditReportItem.fromJson(json);
      expect(report.reportTitle, 'Monthly Device Control Audit Trail');
      expect(report.format, 'PDF');
      expect(report.recordsCount, 12430);
      expect(report.fileSize, '4.2 MB');
      expect(report.status, 'Completed');
    });
  });

  group('DeviceAuditLogsSubview Widget Tests', () {
    Widget buildTestWidget({Size viewportSize = const Size(1440, 900)}) {
      return MaterialApp(
        theme: ThemeData.light(),
        home: MediaQuery(
          data: MediaQueryData(size: viewportSize),
          child: Scaffold(
            body: DeviceAuditLogsSubview(
              logs: const [],
              onBackToDashboard: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('Renders Header, Subtitle, and all 6 KPI cards', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Top Module Titles
      expect(find.text('Device Management & Control'), findsOneWidget);
      expect(find.text('Audit Logs'), findsOneWidget);
      expect(
        find.text('Complete and tamper-evident record of all device operations, access changes, configurations and system activities.'),
        findsOneWidget,
      );

      // 6 Top KPI Cards
      expect(find.text('Total Logs'), findsWidgets);
      expect(find.text('24,860'), findsWidgets);

      expect(find.text('Device Commands'), findsWidgets);
      expect(find.text('12,430'), findsWidgets);
      expect(find.text('(50.0%)'), findsWidgets);

      expect(find.text('Access Changes'), findsWidgets);
      expect(find.text('1,820'), findsWidgets);
      expect(find.text('(7.3%)'), findsWidgets);

      expect(find.text('Configuration'), findsWidgets);
      expect(find.text('3,610'), findsWidgets);
      expect(find.text('(14.5%)'), findsWidgets);

      expect(find.text('System Events'), findsWidgets);
      expect(find.text('5,720'), findsWidgets);
      expect(find.text('(23.0%)'), findsWidgets);

      expect(find.text('Security Events'), findsWidgets);
      expect(find.text('280'), findsWidgets);
      expect(find.text('(1.1%)'), findsWidgets);
    });

    testWidgets('Renders all 7 category sub-tabs and allows selecting tabs', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final subtabs = [
        'All Logs',
        'Device Commands',
        'Access & Permissions',
        'Configuration Changes',
        'Automation & Schedules',
        'System Events',
        'Security & Alerts',
      ];

      for (var tab in subtabs) {
        expect(find.text(tab), findsWidgets);
      }

      // Tap Device Commands sub-tab
      final devCmdTab = find.byKey(const Key('audit_subtab_Device Commands'));
      await tester.ensureVisible(devCmdTab);
      await tester.tap(devCmdTab);
      await tester.pumpAndSettle();

      // Tap Security & Alerts sub-tab
      final secTab = find.byKey(const Key('audit_subtab_Security & Alerts'));
      await tester.ensureVisible(secTab);
      await tester.tap(secTab);
      await tester.pumpAndSettle();
    });

    testWidgets('Renders Donut Chart, Trend Line Chart, and Top Activities', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Donut Chart Header
      expect(find.text('Audit Activity Overview (Last 30 Days)'), findsOneWidget);

      // Trend Line Chart Header
      expect(find.text('Audit Trend (Last 30 Days)'), findsOneWidget);

      // Top Activities Header
      expect(find.text('Top Activities'), findsOneWidget);
      expect(find.text('Device ON/OFF'), findsOneWidget);
      expect(find.text('4,320 (17.4%)'), findsOneWidget);
      expect(find.text('Parameter Change'), findsOneWidget);
      expect(find.text('3,210 (12.9%)'), findsOneWidget);
      expect(find.text('Scene / Preset Run'), findsOneWidget);
      expect(find.text('1,980 (8.0%)'), findsOneWidget);
      expect(find.text('Schedule Execution'), findsOneWidget);
      expect(find.text('1,650 (6.6%)'), findsOneWidget);
      expect(find.text('User Login / Logout'), findsOneWidget);
      expect(find.text('1,420 (5.7%)'), findsOneWidget);
    });

    testWidgets('Renders Advanced Filter Bar and filters', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Time Range'), findsOneWidget);
      expect(find.text('Start Date'), findsOneWidget);
      expect(find.text('End Date'), findsOneWidget);
      expect(find.text('Event Type'), findsWidgets);
      expect(find.text('User'), findsWidgets);
      expect(find.text('Device Type'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Apply Filter'), findsOneWidget);

      // Tap Apply Filter button
      await tester.tap(find.byKey(const Key('audit_apply_filter_btn')));
      await tester.pumpAndSettle();
    });

    testWidgets('Renders canonical 10 table rows with badges and actions', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Canonical targets from the screenshot
      expect(find.text('AC Unit (A1-101)'), findsWidgets);
      expect(find.text('Device Group (Classroom AC)'), findsWidgets);
      expect(find.text('Gateway (GW-A01)'), findsWidgets);
      expect(find.text('Scene: Class Start'), findsWidgets);
      expect(find.text('Projector (A1-102)'), findsWidgets);
      expect(find.text('User: test.user'), findsWidgets);
      expect(find.text('Energy Saving Rule'), findsWidgets);
      expect(find.text('Lighting Group (A1-F1)'), findsWidgets);
      expect(find.text('Gateway (GW-A02)'), findsWidgets);
      expect(find.text('MQTT Broker'), findsWidgets);

      // Canonical details
      expect(find.text('Mode: Cool, Temp: 24°C'), findsWidgets);
      expect(find.text('Role: Facility Manager'), findsWidgets);
      expect(find.text('Heartbeat: 30s → 15s'), findsWidgets);
      expect(find.text('Location: A-101'), findsWidgets);
      expect(find.text('Input: HDMI, Brightness: 80%'), findsWidgets);
      expect(find.text('Invalid password (3rd attempt)'), findsWidgets);
      expect(find.text('Condition: After 6:00 PM'), findsWidgets);
      expect(find.text('15 devices'), findsWidgets);
      expect(find.text('v2.3.1 → v2.4.0'), findsWidgets);
      expect(find.text('Uptime: 12d 04h 21m'), findsWidgets);

      // Badges
      expect(find.text('Success'), findsWidgets);
      expect(find.text('Failed'), findsWidgets);
      expect(find.text('Web'), findsWidgets);
      expect(find.text('Mobile'), findsWidgets);
      expect(find.text('Scheduler'), findsWidgets);
      expect(find.text('Automation'), findsWidgets);
      expect(find.text('System'), findsWidgets);

      // Pagination controls
      expect(find.text('Show'), findsOneWidget);
      expect(find.text('entries'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('349'), findsOneWidget);
    });

    testWidgets('Toggles 5 Expandable Accordions', (tester) async {
      tester.view.physicalSize = const Size(1440, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 1. Log Details is expanded by default
      expect(find.text('Log Details'), findsOneWidget);
      expect(find.text('Operational & Command Lifecycle Trace'), findsOneWidget);
      expect(find.text('Previous State'), findsOneWidget);
      expect(find.text('New Mutated State'), findsOneWidget);

      // 2. Expand User Activity Summary
      final userSummaryHeader = find.text('User Activity Summary');
      await tester.ensureVisible(userSummaryHeader);
      await tester.tap(userSummaryHeader);
      await tester.pumpAndSettle();
      expect(find.text('Total Operations'), findsOneWidget);
      expect(find.text('Vikas Singh'), findsWidgets);

      // 3. Expand Device Activity Summary
      final devSummaryHeader = find.text('Device Activity Summary');
      await tester.ensureVisible(devSummaryHeader);
      await tester.tap(devSummaryHeader);
      await tester.pumpAndSettle();
      expect(find.text('Device Category'), findsOneWidget);
      expect(find.text('AC / HVAC Units'), findsOneWidget);

      // 4. Expand Audit Reports
      final reportsHeader = find.text('Audit Reports');
      await tester.ensureVisible(reportsHeader);
      await tester.tap(reportsHeader);
      await tester.pumpAndSettle();
      expect(find.text('Generate New PDF Report'), findsOneWidget);

      // 5. Expand Retention & Archiving
      final retHeader = find.text('Retention & Archiving');
      await tester.ensureVisible(retHeader);
      await tester.tap(retHeader);
      await tester.pumpAndSettle();
      expect(find.text('Add Retention Policy'), findsOneWidget);
      expect(find.text('Device Commands Retention'), findsOneWidget);
    });

    testWidgets('Opens Inspection Modal and JSON Dialog', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap View Details button
      final viewDetailsBtn = find.text('View Details');
      await tester.tap(viewDetailsBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Audit Event:'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Tap raw JSON code button on first row
      final jsonIcons = find.byIcon(Icons.data_object_rounded);
      expect(jsonIcons, findsWidgets);
      await tester.ensureVisible(jsonIcons.first);
      await tester.tap(jsonIcons.first);
      await tester.pumpAndSettle();

      expect(find.text('Raw Event Payload (JSON)'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('Responsive Layout - Mobile (400px) has ZERO RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(viewportSize: const Size(400, 800)));
      await tester.pumpAndSettle();

      // Verify header rendered without overflow exceptions
      expect(find.text('Audit Logs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive Layout - Tablet (800px) has ZERO RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(viewportSize: const Size(800, 1000)));
      await tester.pumpAndSettle();

      expect(find.text('Audit Logs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
