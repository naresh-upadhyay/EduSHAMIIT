import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_import_export_subview.dart';

void main() {
  group('Import / Export Data Models Tests', () {
    test('ImportExportOperation JSON deserialization', () {
      final json = {
        'id': 'op-001',
        'operation_id': 'IMP-20250110-0142',
        'type': 'Import',
        'operation': 'Devices',
        'file_name': 'devices_import.xlsx',
        'records': 1250,
        'success': 1238,
        'failed': 12,
        'user': 'Admin',
        'started_at': '10 Jan 2025, 02:18 PM',
        'duration': '00:01:32',
        'status': 'Completed',
        'download_url': '/api/v1/devices/import-export/files/IMP-20250110-0142_devices_import.xlsx',
      };

      final op = ImportExportOperation.fromJson(json);
      expect(op.operationId, 'IMP-20250110-0142');
      expect(op.type, 'Import');
      expect(op.operation, 'Devices');
      expect(op.fileName, 'devices_import.xlsx');
      expect(op.records, 1250);
      expect(op.success, 1238);
      expect(op.failed, 12);
      expect(op.user, 'Admin');
      expect(op.duration, '00:01:32');
      expect(op.status, 'Completed');
    });

    test('ImportExportTemplate JSON deserialization', () {
      final json = {
        'id': 'tpl-001',
        'template_name': 'Device Import (Standard)',
        'type': 'Import',
        'module': 'Devices',
        'file_format': 'XLSX',
        'description': 'All required device fields',
        'required_columns': ['device_id', 'device_name', 'type_code', 'building_code', 'room_number'],
        'version': 'v2.4',
        'download_url': '/templates/device-standard.xlsx',
      };

      final tpl = ImportExportTemplate.fromJson(json);
      expect(tpl.name, 'Device Import (Standard)');
      expect(tpl.type, 'Import');
      expect(tpl.module, 'Devices');
      expect(tpl.fileFormat, 'XLSX');
      expect(tpl.requiredColumns.length, 5);
      expect(tpl.version, 'v2.4');
    });

    test('ScheduledExport JSON deserialization', () {
      final json = {
        'id': 'sch-001',
        'name': 'Daily Device Registry Snapshot',
        'module': 'Device Registry',
        'format': 'XLSX',
        'recurrence': 'Daily',
        'cron': '0 2 * * *',
        'destination': 'Storage & Email',
        'recipient': 'admin@edushamiit.edu',
        'is_enabled': true,
        'last_run': '10 Jan 2025, 02:00 AM',
        'next_run': '11 Jan 2025, 02:00 AM',
      };

      final sch = ScheduledExport.fromJson(json);
      expect(sch.name, 'Daily Device Registry Snapshot');
      expect(sch.module, 'Device Registry');
      expect(sch.recurrence, 'Daily');
      expect(sch.isEnabled, true);
    });
  });

  group('DeviceImportExportSubview Widget Rendering Tests', () {
    Widget buildTestWidget({Size surfaceSize = const Size(1440, 1000)}) {
      return MaterialApp(
        theme: ThemeData.light(),
        home: MediaQuery(
          data: MediaQueryData(size: surfaceSize),
          child: Scaffold(
            body: DeviceImportExportSubview(
              onBackToDashboard: () {},
              autoFetch: false,
            ),
          ),
        ),
      );
    }

    testWidgets('Renders module header and back button', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Import / Export'), findsWidgets);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(
        find.text('Import device data from files or export device, configuration and operational data for backup, migration and reporting.'),
        findsOneWidget,
      );
    });

    testWidgets('Renders all 6 Top KPI summary cards with canonical numbers', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Top 6 KPI titles
      expect(find.text('Total Operations'), findsWidgets);
      expect(find.text('Imports'), findsOneWidget);
      expect(find.text('Exports'), findsOneWidget);
      expect(find.text('Successful'), findsWidgets);
      expect(find.text('Failed'), findsWidgets);
      expect(find.text('Last Operation'), findsOneWidget);

      // KPI values
      expect(find.text('482'), findsWidgets);
      expect(find.text('268 (55.6%)'), findsOneWidget);
      expect(find.text('214 (44.4%)'), findsOneWidget);
      expect(find.text('460 (95.4%)'), findsWidgets);
      expect(find.text('22 (4.6%)'), findsWidgets);
      expect(find.text('10 Jan 2025, 02:18 PM'), findsWidgets);
    });

    testWidgets('Renders all 8 Sub-Tabs', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Import Devices'), findsWidgets);
      expect(find.text('Export Data'), findsOneWidget);
      expect(find.text('Templates'), findsOneWidget);
      expect(find.text('Mapping & Validation'), findsOneWidget);
      expect(find.text('Import History'), findsOneWidget);
      expect(find.text('Export History'), findsOneWidget);
      expect(find.byKey(const Key('subtab_7')), findsOneWidget);
    });

    testWidgets('Renders Overview Middle Row 1 cards: Donut, Trend, Quick Actions', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Import / Export Overview'), findsOneWidget);
      expect(find.text('Operation Trend (Last 30 Days)'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);

      // Quick Actions labels
      expect(find.text('Export Devices'), findsOneWidget);
      expect(find.text('Download Template'), findsOneWidget);
      expect(find.text('View Import History'), findsOneWidget);
      expect(find.text('View Export History'), findsOneWidget);
      expect(find.text('Schedule Export'), findsOneWidget);
    });

    testWidgets('Renders Overview Middle Row 2 cards: Supported Operations, Limits, Templates mini table', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Supported Operations'), findsOneWidget);
      expect(find.text('Devices (Registry)'), findsOneWidget);
      expect(find.text('Energy & Usage Data'), findsOneWidget);

      expect(find.text('File Formats & Limits'), findsOneWidget);
      expect(find.text('Microsoft Excel (.xlsx)'), findsOneWidget);
      expect(find.text('CSV (Comma Separated)'), findsOneWidget);
      expect(find.text('JSON (Structured Data)'), findsOneWidget);
      expect(find.text('ZIP (Bulk with Multiple Files)'), findsOneWidget);

      expect(find.text('Import / Export Templates'), findsOneWidget);
      expect(find.text('Device Import (Standard)'), findsOneWidget);
      expect(find.text('Device Import (With Group)'), findsOneWidget);
      expect(find.text('Location Import'), findsOneWidget);
      expect(find.text('Device Export (Full)'), findsOneWidget);
      expect(find.text('Configuration Export'), findsOneWidget);
    });

    testWidgets('Renders History Data Table with 10 canonical rows', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check canonical Operation IDs from screenshot
      expect(find.text('IMP-20250110-0142'), findsOneWidget);
      expect(find.text('EXP-20250110-0137'), findsOneWidget);
      expect(find.text('IMP-20250109-0098'), findsOneWidget);
      expect(find.text('EXP-20250109-0095'), findsOneWidget);
      expect(find.text('IMP-20250108-0081'), findsOneWidget);
      expect(find.text('EXP-20250107-0076'), findsOneWidget);
      expect(find.text('IMP-20250107-0071'), findsOneWidget);
      expect(find.text('EXP-20250106-0068'), findsOneWidget);
      expect(find.text('IMP-20250105-0061'), findsOneWidget);
      expect(find.text('EXP-20250104-0059'), findsOneWidget);

      // Check file names
      expect(find.text('devices_import.xlsx'), findsOneWidget);
      expect(find.text('devices_export_20250110.xlsx'), findsOneWidget);
      expect(find.text('config_export.json'), findsOneWidget);
      expect(find.text('audit_logs_20250101_20250106.zip'), findsOneWidget);

      // Check users from canonical table
      expect(find.text('Priya Verma'), findsWidgets);
      expect(find.text('Rohan Mehta'), findsWidgets);
      expect(find.text('Neha Kapoor'), findsOneWidget);
      expect(find.text('Vikas Singh'), findsOneWidget);

      // Pagination controls
      expect(find.text('Showing 1 \u2013 10 of 482 operations'), findsOneWidget);
      expect(find.text('Rows per page: '), findsOneWidget);
    });

    testWidgets('Switches across sub-tabs cleanly without exceptions', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on 'Import Devices' tab (index 1)
      await tester.tap(find.byKey(const Key('subtab_1')));
      await tester.pumpAndSettle();
      expect(find.text('Guided Batch Import Wizard'), findsOneWidget);

      // Tap on 'Export Data' tab (index 2)
      await tester.tap(find.byKey(const Key('subtab_2')));
      await tester.pumpAndSettle();
      expect(find.text('Campus Data Export Studio'), findsOneWidget);

      // Tap on 'Templates' tab (index 3)
      await tester.tap(find.byKey(const Key('subtab_3')));
      await tester.pumpAndSettle();
      expect(find.text('Import & Export Templates Catalog'), findsOneWidget);

      // Tap on 'Mapping & Validation' tab (index 4)
      await tester.tap(find.byKey(const Key('subtab_4')));
      await tester.pumpAndSettle();
      expect(find.text('Column Mapping & Value Transformers'), findsOneWidget);

      // Tap on 'Schedules' tab (index 7)
      await tester.ensureVisible(find.byKey(const Key('subtab_7')));
      await tester.tap(find.byKey(const Key('subtab_7')));
      await tester.pumpAndSettle();
      expect(find.text('Automated Recurring Export Schedules'), findsOneWidget);
    });

    testWidgets('Responsive rendering on tablet and mobile viewports with zero overflows', (tester) async {
      // Tablet Viewport (800x1024)
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(800, 1024)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Mobile Viewport (400x800)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(400, 800)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
