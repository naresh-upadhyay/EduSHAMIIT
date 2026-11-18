import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_schedules_subview.dart';

void main() {
  group('Device Schedules - Models Unit Tests', () {
    test('DeviceSchedulesKpis parses valid JSON correctly', () {
      final json = {
        'total_schedules': 276,
        'active_schedules': 192,
        'active_percentage': 69.6,
        'paused_schedules': 8,
        'paused_percentage': 2.9,
        'upcoming_24h': 34,
        'executed_today': 428,
        'failed_skipped': 6,
        'completed_count': 2318,
      };

      final kpis = DeviceSchedulesKpis.fromJson(json);
      expect(kpis.totalSchedules, 276);
      expect(kpis.activeSchedules, 192);
      expect(kpis.activePercentage, 69.6);
      expect(kpis.pausedSchedules, 8);
      expect(kpis.pausedPercentage, 2.9);
      expect(kpis.upcoming24h, 34);
      expect(kpis.executedToday, 428);
      expect(kpis.failedSkipped, 6);
      expect(kpis.completedCount, 2318);
    });

    test('DeviceScheduleItem parses valid JSON correctly and supports copyWith', () {
      final json = {
        'id': 'sch-test-01',
        'schedule_code': 'SCH-001',
        'name': 'Classroom Lights - Auto ON/OFF',
        'description': 'Automated routine for lights',
        'target_type': 'group',
        'target_name': 'Classroom Lights (A)',
        'target_count': 96,
        'operation_type': 'turn_on_off',
        'operation_value': 'Turn ON / Turn OFF',
        'recurrence_type': 'daily',
        'recurrence_label': 'Daily (Every day)',
        'time_window_label': '07:00 AM - 06:00 PM',
        'validity_label': '01 Jan 2025 - No End Date',
        'status': 'active',
        'is_active': true,
        'created_by_name': 'Admin (John Doe)',
      };

      final item = DeviceScheduleItem.fromJson(json);
      expect(item.scheduleCode, 'SCH-001');
      expect(item.name, 'Classroom Lights - Auto ON/OFF');
      expect(item.targetName, 'Classroom Lights (A)');
      expect(item.targetCount, 96);
      expect(item.status, 'active');
      expect(item.isActive, true);

      final updated = item.copyWith(status: 'paused', isActive: false);
      expect(updated.status, 'paused');
      expect(updated.isActive, false);
      expect(updated.name, item.name);
    });

    test('DeviceScheduleTimelineEvent and ExecutionLog parse correctly', () {
      final evJson = {
        'id': 'ev-1',
        'schedule_id': 'sch-test-01',
        'event_title': 'Classroom Lights - Turn ON',
        'action_type': 'turn_on',
        'scheduled_time_label': 'Tomorrow, 07:00 AM',
        'target_summary': 'Classroom Lights (A)',
        'status': 'upcoming',
      };
      final ev = DeviceScheduleTimelineEvent.fromJson(evJson);
      expect(ev.eventTitle, 'Classroom Lights - Turn ON');
      expect(ev.actionType, 'turn_on');
      expect(ev.status, 'upcoming');

      final logJson = {
        'id': 'ex-1',
        'schedule_id': 'sch-test-01',
        'execution_code': 'RUN-20250112-180000',
        'trigger_time_label': 'Today, 06:00 PM',
        'action_executed': 'Turn OFF (Auto Routine)',
        'status': 'success',
        'affected_devices_count': 96,
        'success_count': 96,
      };
      final log = DeviceScheduleExecutionLog.fromJson(logJson);
      expect(log.executionCode, 'RUN-20250112-180000');
      expect(log.affectedDevicesCount, 96);
      expect(log.status, 'success');
    });
  });

  group('Device Schedules - UI Widgets and Responsiveness Tests', () {
    Widget buildTestHarness({double width = 1440, double height = 900, bool isDark = false}) {
      return MaterialApp(
        theme: isDark ? ThemeData.dark() : ThemeData.light(),
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: const DeviceSchedulesSubview(apiBaseUrl: 'http://mock.endpoint'),
          ),
        ),
      );
    }

    testWidgets('Renders Header with Title and action buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('Schedules'), findsOneWidget);
      expect(find.text('Create and manage automated time-based schedules for devices, groups, and locations.'), findsOneWidget);
      expect(find.text('Schedule History'), findsOneWidget);
      expect(find.text('+ + Create Schedule'), findsNothing);
      expect(find.text('Create Schedule'), findsWidgets);
    });

    testWidgets('Renders all 6 Top KPI Cards with exact metrics', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('Total Schedules'), findsOneWidget);
      expect(find.text('10'), findsAtLeastNWidgets(1));

      expect(find.text('Active'), findsAtLeastNWidgets(1));
      expect(find.text('9'), findsOneWidget);
      expect(find.text('90.0%'), findsOneWidget);

      expect(find.text('Paused'), findsAtLeastNWidgets(1));
      expect(find.text('1'), findsAtLeastNWidgets(1));
      expect(find.text('10.0%'), findsOneWidget);

      expect(find.text('Upcoming (Next 24h)'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      expect(find.text('Executed Today'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      expect(find.text('Failed / Skipped'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('Renders Sub-Tabs Bar and toggles tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('All Schedules (10)'), findsOneWidget);
      expect(find.text('Active (9)'), findsOneWidget);
      expect(find.text('Paused (1)'), findsOneWidget);
      expect(find.text('Upcoming (2)'), findsOneWidget);
      expect(find.text('Completed (0)'), findsOneWidget);

      // Tap on Active tab
      await tester.tap(find.text('Active (9)'));
      await tester.pumpAndSettle();
    });

    testWidgets('Renders Search field and 5 Filter Dropdowns', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All Locations'), findsOneWidget);
      expect(find.text('All Device Types'), findsOneWidget);
      expect(find.text('All Groups'), findsOneWidget);
      expect(find.text('All Operations'), findsOneWidget);
      expect(find.text('All Status'), findsOneWidget);
    });

    testWidgets('Renders Central Table with Canonical Schedules', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('SCHEDULE NAME'), findsOneWidget);
      expect(find.text('TARGET'), findsOneWidget);
      expect(find.text('OPERATION'), findsOneWidget);
      expect(find.text('SCHEDULE'), findsOneWidget);
      expect(find.text('NEXT RUN'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
      expect(find.text('ACTIONS'), findsOneWidget);

      // Check canonical schedules exist in table
      expect(find.text('Classroom Lights - Auto ON/OFF'), findsAtLeastNWidgets(1));
      expect(find.text('SCH-001'), findsAtLeastNWidgets(1));
      expect(find.text('AC - Academic Block (Weekdays)'), findsOneWidget);
      expect(find.text('SCH-002'), findsOneWidget);
      expect(find.text('Projector - Auditorium (Event Days)'), findsOneWidget);
      expect(find.text('Ceiling Fans - Library (Daily)'), findsOneWidget);
    });

    testWidgets('Selecting a row updates Right Inspector Panel', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      // Right panel defaults to first item SCH-001
      expect(find.text('Schedule ID: SCH-001'), findsOneWidget);

      // Tap second item in table
      await tester.tap(find.text('AC - Academic Block (Weekdays)'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule ID: SCH-002'), findsOneWidget);
    });

    testWidgets('Renders 6 Quick Actions in Right Inspector Panel', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Run Now (ON)'), findsOneWidget);
      expect(find.text('Run Now (OFF)'), findsOneWidget);
      expect(find.text('Pause Schedule'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('Renders Accordions and toggles expansion', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('Target Devices (96)'), findsOneWidget);
      expect(find.text('Execution History'), findsOneWidget);
      expect(find.text('Dependencies (0)'), findsOneWidget);
      expect(find.text('Audit Logs'), findsOneWidget);

      // Expand Target Devices
      await tester.ensureVisible(find.text('Target Devices (96)'));
      await tester.tap(find.text('Target Devices (96)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Target fleet: Classroom Lights (A)'), findsOneWidget);
    });

    testWidgets('Opens Create Schedule Dialog when Create Schedule is tapped', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Schedule').first);
      await tester.pumpAndSettle();

      expect(find.text('Create Device Schedule'), findsOneWidget);
      expect(find.text('Schedule Name *'), findsOneWidget);
      expect(find.text('1. Target Fleet Selection'), findsOneWidget);
      expect(find.text('2. Operation & Parameters'), findsOneWidget);
      expect(find.text('3. Trigger Timing & Recurrence'), findsOneWidget);
      expect(find.text('Target Mode'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Create Device Schedule'), findsNothing);
    });

    testWidgets('Table has exactly ONE checkbox column and showCheckboxColumn is false (NO double checkbox)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      final dataTableFinder = find.byType(DataTable);
      expect(dataTableFinder, findsOneWidget);

      final dataTable = tester.widget<DataTable>(dataTableFinder);
      expect(dataTable.showCheckboxColumn, isFalse);

      // Check checkboxes inside table
      final checkboxes = find.descendant(of: dataTableFinder, matching: find.byType(Checkbox));
      expect(checkboxes, findsAtLeastNWidgets(1));
    });

    testWidgets('Dynamic Target Selection: Switch to Multi-Select Devices across Locations', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Schedule').first);
      await tester.pumpAndSettle();

      // Open Target Mode dropdown
      await tester.tap(find.text('Device Group (Existing Group)'));
      await tester.pumpAndSettle();

      // Select Multi-Select Devices across Locations
      await tester.tap(find.text('Multi-Select Devices across Locations (Search & Select)').last);
      await tester.pumpAndSettle();

      // Verify search input and device items are rendered
      expect(find.text('Search devices by name, code or location...'), findsOneWidget);
      expect(find.text('Select All'), findsOneWidget);
      expect(find.text('0 Devices Selected'), findsOneWidget);
      expect(find.text('Classroom Lights (A1-101)'), findsOneWidget);

      // Tap Select All
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();

      expect(find.text('Deselect Filtered'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Dynamic Operation: Switch operation and configure parameters', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Schedule').first);
      await tester.pumpAndSettle();

      // Default operation: Power Control
      expect(find.text('Power Routine Type'), findsOneWidget);
      expect(find.text('Turn ON at Start & Turn OFF at End'), findsAtLeastNWidgets(1));

      // Switch to Climate & Temperature
      await tester.tap(find.text('Power Control (Turn ON / Turn OFF)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Climate & Temperature (HVAC AC)').last);
      await tester.pumpAndSettle();

      // Verify Climate controls: Target Temp, Stepper, HVAC Mode, Fan Speed
      expect(find.text('Target Temperature'), findsOneWidget);
      expect(find.text('24°C'), findsOneWidget);
      expect(find.text('HVAC Mode'), findsOneWidget);
      expect(find.text('Fan Speed'), findsOneWidget);

      // Increment temperature
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(find.text('25°C'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Opens Schedule History Dialog when Schedule History is tapped', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Schedule History'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule Execution History'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Schedule Execution History'), findsNothing);
    });

    testWidgets('Opens Full Timeline Dialog when View Full Schedule is tapped', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('View Full Schedule →'));
      await tester.tap(find.text('View Full Schedule →'));
      await tester.pumpAndSettle();

      expect(find.text('Full 7-Day Schedule Projections'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Full 7-Day Schedule Projections'), findsNothing);
    });

    testWidgets('Renders on Tablet Viewport (800x900) without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      await tester.pumpWidget(buildTestHarness(width: 800, height: 900));
      await tester.pumpAndSettle();

      expect(find.text('Schedules'), findsOneWidget);
      expect(find.text('Total Schedules'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders on Mobile Viewport (400x800) without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(buildTestHarness(width: 400, height: 800));
      await tester.pumpAndSettle();

      expect(find.text('Schedules'), findsOneWidget);
      expect(find.text('Total Schedules'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders on Dark Theme without errors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness(isDark: true));
      await tester.pumpAndSettle();

      expect(find.text('Schedules'), findsOneWidget);
      expect(find.text('Total Schedules'), findsOneWidget);
      expect(find.text('10'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Multi-Selection: Checking row checkbox shows multi-selection toolbar with all operations', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      // Before checking: multi-selection action bar is not visible
      expect(find.text('Activate Selected'), findsNothing);
      expect(find.text('Pause Selected'), findsNothing);
      expect(find.text('Run Selected'), findsNothing);
      expect(find.text('Delete Selected'), findsNothing);

      // Find row checkboxes (index 0 is header checkbox, index 1 is first row checkbox)
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsAtLeastNWidgets(2));

      // Tap first row checkbox
      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();

      // Action bar now visible
      expect(find.text('1 schedule selected'), findsOneWidget);
      expect(find.text('Activate Selected'), findsOneWidget);
      expect(find.text('Pause Selected'), findsOneWidget);
      expect(find.text('Run Selected'), findsOneWidget);
      expect(find.text('Delete Selected'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);

      // Tap Clear All
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      // Action bar hides
      expect(find.text('1 schedule selected'), findsNothing);
      expect(find.text('Activate Selected'), findsNothing);
    });

    testWidgets('Zero double checkboxes and zero double ++ on Schedules screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('+ +'), findsNothing);
      expect(find.text('++'), findsNothing);
    });
  });
}
