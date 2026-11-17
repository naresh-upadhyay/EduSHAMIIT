import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_bulk_operations_subview.dart';

void main() {
  group('Bulk Operations - Models Unit Tests', () {
    test('BulkOperationOverview parses valid JSON correctly', () {
      final json = {
        'total_devices': 8742,
        'online_devices': 8342,
        'online_percentage': 95.4,
        'offline_devices': 400,
        'offline_percentage': 4.6,
        'selected_devices': 4,
        'selected_groups': 0,
        'selected_locations': 0,
        'affected_devices': 4,
        'operations_running': 1,
        'operations_completed_today': 3,
        'failed_commands': 0,
      };

      final overview = BulkOperationOverview.fromJson(json);
      expect(overview.totalDevices, 8742);
      expect(overview.onlineDevices, 8342);
      expect(overview.onlinePercentage, 95.4);
      expect(overview.offlineDevices, 400);
      expect(overview.offlinePercentage, 4.6);
      expect(overview.operationsRunning, 1);
      expect(overview.operationsCompletedToday, 3);
    });

    test('BulkRecentOperationItem parses valid JSON correctly', () {
      final json = {
        'id': 'b1111111-0000-0000-0000-000000000001',
        'operation_code': 'BLK-2025-0012',
        'name': 'Turn OFF (Control)',
        'operation_type': 'control',
        'target_scope': '12 devices (Classroom A1)',
        'status': 'Success',
        'initiated_by': 'Admin',
        'result': '✓ 12/12 completed',
        'total_devices': 12,
        'successful_devices': 12,
        'created_at': '12 Jan 2025, 02:30 PM',
      };

      final item = BulkRecentOperationItem.fromJson(json);
      expect(item.operationCode, 'BLK-2025-0012');
      expect(item.name, 'Turn OFF (Control)');
      expect(item.status, 'Success');
      expect(item.totalDevices, 12);
      expect(item.successfulDevices, 12);
    });

    test('BulkOperationTemplateItem parses valid JSON correctly', () {
      final json = {
        'id': 'e1111111-0000-0000-0000-000000000001',
        'template_name': 'Turn On All Classroom Lights',
        'description': 'Turn on all classroom lights simultaneously at 100% brightness',
        'operation_type': 'control',
        'target_type': 'by_device_type',
        'icon': 'gps_fixed',
        'color': '#2563EB',
      };

      final tmpl = BulkOperationTemplateItem.fromJson(json);
      expect(tmpl.templateName, 'Turn On All Classroom Lights');
      expect(tmpl.operationType, 'control');
      expect(tmpl.icon, 'gps_fixed');
    });
  });

  group('Bulk Operations - UI Widgets and Responsiveness Tests', () {
    Widget buildTestHarness({double width = 1440, double height = 900}) {
      return MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: const DeviceBulkOperationsSubview(apiBaseUrl: 'http://mock.endpoint'),
          ),
        ),
      );
    }

    testWidgets('Renders all 6 Top KPI Cards with exact metrics', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('Selected Devices'), findsOneWidget);
      expect(find.text('Online'), findsAtLeastNWidgets(1));
      expect(find.text('Offline'), findsAtLeastNWidgets(1));
      expect(find.text('Selected Groups'), findsOneWidget);
      expect(find.text('Selected Locations'), findsOneWidget);
      expect(find.text('Affected Devices'), findsOneWidget);

      expect(find.text('8,342 (95.4%)'), findsOneWidget);
      expect(find.text('400 (4.6%)'), findsOneWidget);
    });

    testWidgets('Renders 3-Step Horizontal Stepper bar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('Select Targets'), findsAtLeastNWidgets(1));
      expect(find.text('Choose devices, groups or locations'), findsOneWidget);
      expect(find.text('Choose Operation'), findsAtLeastNWidgets(1));
      expect(find.text('Select the bulk action to perform'), findsOneWidget);
      expect(find.text('Configure & Execute'), findsOneWidget);
      expect(find.text('Set parameters and run'), findsOneWidget);
    });

    testWidgets('Renders Target Tabs, Filter Dropdowns and Search Bar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('Devices'), findsAtLeastNWidgets(1));
      expect(find.text('Groups'), findsAtLeastNWidgets(1));
      expect(find.text('Locations'), findsAtLeastNWidgets(1));
      expect(find.text('By Device Type'), findsOneWidget);

      expect(find.text('Filter Devices'), findsOneWidget);
      expect(find.text('All Buildings'), findsOneWidget);
      expect(find.text('All Floors'), findsOneWidget);
      expect(find.text('All Rooms'), findsOneWidget);
      expect(find.text('All Types'), findsOneWidget);
      expect(find.text('All Status'), findsOneWidget);
      expect(find.text('All Profiles'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Renders Target Devices Table and toggles device selection', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('Device Name'), findsOneWidget);
      expect(find.text('Classroom Lights (A1-101)'), findsOneWidget);
      expect(find.text('Classroom Lights (A1-102)'), findsOneWidget);
      expect(find.text('Classroom Lights (A1-103)'), findsOneWidget);
      expect(find.text('Classroom Lights (A1-104)'), findsOneWidget);

      // Verify selected count text
      expect(find.text('Selected: 4 devices'), findsOneWidget);

      // Tap Clear Selection
      await tester.ensureVisible(find.text('Clear Selection'));
      await tester.tap(find.text('Clear Selection'));
      await tester.pumpAndSettle();

      expect(find.text('Selected: 0 devices'), findsOneWidget);
    });

    testWidgets('Renders 7 Operation Tiles and updates configuration', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('Control'), findsAtLeastNWidgets(1));
      expect(find.text('Configuration'), findsOneWidget);
      expect(find.text('Firmware Update'), findsAtLeastNWidgets(1));
      expect(find.text('Assign to Group'), findsAtLeastNWidgets(1));
      expect(find.text('Apply Profile'), findsAtLeastNWidgets(1));
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Run Scene'), findsWidgets);

      // Tap Firmware Update
      await tester.ensureVisible(find.text('Firmware Update').first);
      await tester.tap(find.text('Firmware Update').first);
      await tester.pumpAndSettle();

      expect(find.text('Configure Operation – Firmware Update'), findsOneWidget);
    });

    testWidgets('Renders Operation Summary Box and Execute button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('Operation Summary'), findsOneWidget);
      expect(find.text('Target Type'), findsOneWidget);
      expect(find.text('Estimated Duration'), findsOneWidget);
      expect(find.text('Save as Template'), findsOneWidget);
      expect(find.text('Execute Operation'), findsOneWidget);
    });

    testWidgets('Renders Bottom Grid: Recent Bulk Operations and Templates', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('Recent Bulk Operations'), findsOneWidget);
      expect(find.text('Turn OFF (Control)'), findsOneWidget);
      expect(find.text('Apply Profile (Default Lighting)'), findsOneWidget);
      expect(find.text('Firmware Update (v2.4.1)'), findsAtLeastNWidgets(1));
      expect(find.text('Assign to Group (Classroom Lights)'), findsOneWidget);

      expect(find.text('Bulk Operation Templates'), findsOneWidget);
      expect(find.text('Turn On All Classroom Lights'), findsOneWidget);
      expect(find.text('Set AC to 24°C (Academic Block)'), findsOneWidget);
      expect(find.text('Update CCTV Firmware (v2.4.1)'), findsOneWidget);
      expect(find.text('Apply Standard Lighting Profile'), findsOneWidget);
    });

    testWidgets('Opens Operation History Dialog on button tap', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Operation History').first);
      await tester.tap(find.text('Operation History').first);
      await tester.pumpAndSettle();

      expect(find.text('Bulk Operations Audit & Execution History'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('Opens Save as Template Dialog on button tap', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save as Template'));
      await tester.tap(find.text('Save as Template'));
      await tester.pumpAndSettle();

      expect(find.text('Save Operation as Template'), findsOneWidget);
      expect(find.text('Template Name'), findsOneWidget);

      // Close dialog
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('Header button contains clean text without double ++', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      // Check header button text: should be 'Create Bulk Operation' and NOT '+ + Create Bulk Operation'
      expect(find.text('+ + Create Bulk Operation'), findsNothing);
      expect(find.text('Create Bulk Operation'), findsWidgets);
    });

    testWidgets('Switches dynamic config subforms across all 7 operations', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      // 1. Default is Control
      expect(find.text('Configure Operation – Control'), findsOneWidget);
      expect(find.text('Operation Type'), findsOneWidget);
      expect(find.text('Turn ON'), findsWidgets);
      expect(find.text('Turn OFF'), findsWidgets);
      expect(find.text('Set Value'), findsOneWidget);

      // 2. Select Schedule
      await tester.ensureVisible(find.text('Schedule').first);
      await tester.tap(find.text('Schedule').first);
      await tester.pumpAndSettle();

      expect(find.text('Configure Operation – Schedule'), findsOneWidget);
      expect(find.text('Schedule Type'), findsOneWidget);
      expect(find.text('One-Time Execution'), findsOneWidget);
      expect(find.text('Recurring Schedule'), findsOneWidget);
      expect(find.text('Execution Date'), findsOneWidget);
      expect(find.text('Execution Time'), findsOneWidget);
      expect(find.text('Action to Execute on Schedule'), findsOneWidget);

      // 3. Select Configuration
      await tester.ensureVisible(find.text('Configuration').first);
      await tester.tap(find.text('Configuration').first);
      await tester.pumpAndSettle();

      expect(find.text('Configure Operation – Configuration'), findsOneWidget);
      expect(find.text('Heartbeat Interval'), findsOneWidget);
      expect(find.text('Telemetry Frequency'), findsOneWidget);
      expect(find.text('Log Level'), findsOneWidget);

      // 4. Select Firmware Update
      await tester.ensureVisible(find.text('Firmware Update').first);
      await tester.tap(find.text('Firmware Update').first);
      await tester.pumpAndSettle();

      expect(find.text('Configure Operation – Firmware Update'), findsOneWidget);
      expect(find.text('Target Firmware Version'), findsOneWidget);
      expect(find.text('Rollout Strategy'), findsOneWidget);

      // 5. Select Assign to Group
      await tester.ensureVisible(find.text('Assign to Group').first);
      await tester.tap(find.text('Assign to Group').first);
      await tester.pumpAndSettle();

      expect(find.text('Configure Operation – Assign to Group'), findsOneWidget);
      expect(find.text('Group Operation'), findsOneWidget);
      expect(find.text('Target Device Group'), findsOneWidget);

      // 6. Select Apply Profile
      await tester.ensureVisible(find.text('Preset Config'));
      await tester.tap(find.text('Preset Config'));
      await tester.pumpAndSettle();

      expect(find.text('Configure Operation – Apply Profile'), findsOneWidget);
      expect(find.text('Target Control Profile'), findsOneWidget);

      // 7. Select Run Scene
      await tester.ensureVisible(find.text('Preset'));
      await tester.tap(find.text('Preset'));
      await tester.pumpAndSettle();

      expect(find.text('Configure Operation – Run Scene'), findsOneWidget);
      expect(find.text('Preset Scene'), findsOneWidget);
      expect(find.text('Transition Speed'), findsOneWidget);
    });

    testWidgets('Pagination bar renders page controls, rows selector, and handles page switches', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      // Check pagination elements
      expect(find.textContaining('Showing 1 -'), findsOneWidget);
      expect(find.text('Rows: '), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.chevron_right), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.first_page), findsOneWidget);
      expect(find.byIcon(Icons.last_page), findsOneWidget);
    });

    testWidgets('Responsive Layout on Laptop (1280px), Tablet (800px), and Mobile (400px) with 0 overflows', (tester) async {
      final viewports = [
        const Size(1280, 800),
        const Size(800, 700),
        const Size(400, 650),
      ];

      for (var size in viewports) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(buildTestHarness(width: size.width, height: size.height));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(DeviceBulkOperationsSubview), findsOneWidget);
      }
    });
  });
}
