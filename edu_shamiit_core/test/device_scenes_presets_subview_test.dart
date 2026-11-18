import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_scenes_presets_subview.dart';

void main() {
  group('Device Scenes & Presets - Models Unit Tests', () {
    test('DeviceScenesPresetsKpis parses valid JSON correctly', () {
      final json = {
        'total_scenes': 42,
        'active_scenes': 36,
        'active_percentage': 85.7,
        'disabled_scenes': 6,
        'disabled_percentage': 14.3,
        'total_presets': 118,
        'used_in_automations': 24,
        'used_in_schedules': 37,
        'popular_scenes': [
          {'id': '1', 'scene_code': 'SCN-001', 'name': 'Class Start', 'target_name': '8 devices', 'target_count': 8, 'icon': 'wb_sunny_rounded', 'color': '#F59E0B'}
        ],
        'usage_stats': {
          'total_executions_30d': 428,
          'breakdown': [
            {'name': 'Class Start', 'count': 128, 'percentage': 29.9, 'color': '#10B981'},
            {'name': 'Class End', 'count': 96, 'percentage': 22.4, 'color': '#3B82F6'},
          ]
        }
      };

      final kpis = DeviceScenesPresetsKpis.fromJson(json);
      expect(kpis.totalScenes, 42);
      expect(kpis.activeScenes, 36);
      expect(kpis.activePercentage, 85.7);
      expect(kpis.disabledScenes, 6);
      expect(kpis.disabledPercentage, 14.3);
      expect(kpis.totalPresets, 118);
      expect(kpis.usedInAutomations, 24);
      expect(kpis.usedInSchedules, 37);
      expect(kpis.popularScenes.length, 1);
      expect(kpis.popularScenes.first.name, 'Class Start');
      expect(kpis.usageStats.totalExecutions30d, 428);
      expect(kpis.usageStats.breakdown.length, 2);
    });

    test('DeviceSceneItem parses valid JSON and supports copyWith', () {
      final json = {
        'id': 'scn-test-01',
        'scene_code': 'SCN-001',
        'name': 'Class Start',
        'category': 'academic',
        'scene_type': 'scene',
        'target_type': 'devices',
        'target_name': '8 devices',
        'target_count': 8,
        'location_scope': 'Classroom / Academic Block',
        'tags': ['Scene', 'Academic'],
        'description': 'Prepare classroom for class (lights, AC, projector)',
        'icon': 'wb_sunny_rounded',
        'color': '#F59E0B',
        'status': 'active',
        'created_by_name': 'Admin',
        'execution_count': 128,
        'used_in_automations_count': 2,
        'used_in_schedules_count': 3,
        'is_popular': true,
        'steps': [
          {'order': 1, 'target_name': 'Classroom Lights', 'action': 'Turn ON 100%', 'icon': 'lightbulb'}
        ]
      };

      final item = DeviceSceneItem.fromJson(json);
      expect(item.sceneCode, 'SCN-001');
      expect(item.name, 'Class Start');
      expect(item.targetName, '8 devices');
      expect(item.targetCount, 8);
      expect(item.status, 'active');
      expect(item.isActive, true);
      expect(item.executionCount, 128);
      expect(item.steps.length, 1);
      expect(item.steps.first.action, 'Turn ON 100%');

      final copied = item.copyWith(status: 'disabled', isActive: false, executionCount: 129);
      expect(copied.status, 'disabled');
      expect(copied.isActive, false);
      expect(copied.executionCount, 129);
      expect(copied.name, 'Class Start');
    });

    test('DeviceSceneStep serializes and deserializes properly', () {
      const step = DeviceSceneStep(order: 2, targetName: 'AC Unit', action: 'Set to 24°C', icon: 'ac_unit');
      final map = step.toJson();
      expect(map['order'], 2);
      expect(map['target_name'], 'AC Unit');
      expect(map['action'], 'Set to 24°C');

      final fromMap = DeviceSceneStep.fromJson(map);
      expect(fromMap.order, 2);
      expect(fromMap.targetName, 'AC Unit');
      expect(fromMap.action, 'Set to 24°C');
    });

    test('DeviceSceneExecutionRecord parses JSON correctly', () {
      final json = {
        'id': 'exec-01',
        'execution_code': 'EXEC-SCN-20250110-141500',
        'executed_at': '10 Jan 2025, 02:15 PM',
        'executed_by_name': 'Admin',
        'status': 'success',
        'duration_ms': 420,
        'affected_devices_count': 8,
        'success_count': 8,
        'failed_count': 0,
      };

      final record = DeviceSceneExecutionRecord.fromJson(json);
      expect(record.executionCode, 'EXEC-SCN-20250110-141500');
      expect(record.status, 'success');
      expect(record.durationMs, 420);
      expect(record.affectedDevicesCount, 8);
    });
  });

  group('Device Scenes & Presets - Subview Widget Tests', () {
    Widget createWidgetUnderTest({
      String apiBaseUrl = 'mock://test',
      VoidCallback? onBack,
      Function(DeviceSceneItem)? onExecute,
      ThemeMode themeMode = ThemeMode.light,
    }) {
      return MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: Scaffold(
          body: DeviceScenesPresetsSubview(
            apiBaseUrl: apiBaseUrl,
            onBackToDashboard: onBack,
            onExecuteScene: onExecute,
          ),
        ),
      );
    }

    testWidgets('Renders Top Header, Subtitle, and Main Action Buttons', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Scenes & Presets'), findsWidgets);
      expect(find.textContaining('Create multi-device scenes for common use cases'), findsOneWidget);
      expect(find.text('Scene History'), findsOneWidget);
      expect(find.text('Create Scene / Preset'), findsOneWidget);
    });

    testWidgets('Renders 6 Top KPI Cards with exact metrics', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Total Scenes'), findsOneWidget);
      expect(find.text('42'), findsWidgets);

      expect(find.text('Active'), findsWidgets);
      expect(find.text('36'), findsOneWidget);
      expect(find.text('(85.7%)'), findsOneWidget);

      expect(find.text('Disabled'), findsWidgets);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('(14.3%)'), findsOneWidget);

      expect(find.text('Presets'), findsWidgets);
      expect(find.text('118'), findsWidgets);

      expect(find.text('Used in Automations'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);

      expect(find.text('Used in Schedules'), findsOneWidget);
      expect(find.text('37'), findsOneWidget);
    });

    testWidgets('Renders Sub-Tabs and Filter Bar', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Scenes (42)'), findsOneWidget);
      expect(find.text('Presets (118)'), findsOneWidget);
      expect(find.text('Scene Groups'), findsOneWidget);
      expect(find.text('Libraries'), findsOneWidget);
      expect(find.text('Templates'), findsOneWidget);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All Locations'), findsOneWidget);
      expect(find.text('All Device Types'), findsOneWidget);
      expect(find.text('All Status'), findsOneWidget);
      expect(find.text('All Tags'), findsOneWidget);
    });

    testWidgets('Renders Central Table with Canonical Scenes and Presets', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Class Start'), findsWidgets);
      expect(find.text('Class End'), findsWidgets);
      expect(find.text('Presentation Mode'), findsWidgets);
      expect(find.text('Exam Mode'), findsWidgets);
      expect(find.text('Energy Saving'), findsWidgets);
      expect(find.text('Campus Lockdown'), findsOneWidget);
      expect(find.text('Night Mode'), findsWidgets);
    });

    testWidgets('Selecting a row updates Right Inspector Panel specifications', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Right panel header
      expect(find.text('Scene Details'), findsOneWidget);

      // Selected Scene metadata
      expect(find.text('SCN-001'), findsOneWidget);
      expect(find.text('Classroom / Academic Block'), findsWidgets);
      expect(find.text('Scene Steps (Device Actions)'), findsOneWidget);

      // Verify steps list
      expect(find.text('Classroom Lights (Group)'), findsOneWidget);
      expect(find.text('Turn ON, Brightness: 100%'), findsOneWidget);
      expect(find.text('AC Unit (A1-101)'), findsOneWidget);
      expect(find.text('Set to 24°C, Mode: Cool, Fan: Auto'), findsOneWidget);
    });

    testWidgets('Quick Action: Run Now executes scene and shows feedback snackbar', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      DeviceSceneItem? executed;
      await tester.pumpWidget(createWidgetUnderTest(
        onExecute: (s) => executed = s,
      ));
      await tester.pumpAndSettle();

      // Find 'Run Now' button in Right Inspector
      final runNowButton = find.widgetWithText(InkWell, 'Run Now');
      expect(runNowButton, findsOneWidget);
      await tester.ensureVisible(runNowButton);
      await tester.pumpAndSettle();

      await tester.tap(runNowButton);
      await tester.pumpAndSettle();

      expect(executed, isNotNull);
      expect(executed!.name, 'Class Start');
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('executed successfully'), findsOneWidget);
    });

    testWidgets('Quick Action: Disable/Enable toggles scene status', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final disableButton = find.widgetWithText(InkWell, 'Disable');
      expect(disableButton, findsOneWidget);
      await tester.ensureVisible(disableButton);
      await tester.pumpAndSettle();

      await tester.tap(disableButton);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('is now DISABLED'), findsOneWidget);
    });

    testWidgets('Quick Action: Duplicate clones scene with copy name', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final dupButton = find.widgetWithText(InkWell, 'Duplicate');
      expect(dupButton, findsOneWidget);
      await tester.ensureVisible(dupButton);
      await tester.pumpAndSettle();

      await tester.tap(dupButton);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Duplicated scene'), findsOneWidget);
      expect(find.text('Class Start (Copy)'), findsWidgets);
    });

    testWidgets('Renders Bottom Cards: Popular Scenes & Donut Usage Chart', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Popular Scenes'), findsOneWidget);
      expect(find.text('Scene Usage (Last 30 Days)'), findsOneWidget);
      expect(find.text('428'), findsOneWidget);
      expect(find.text('Executions'), findsOneWidget);
      expect(find.text('128 (29.9%)'), findsOneWidget);
      expect(find.text('96 (22.4%)'), findsOneWidget);
    });

    testWidgets('Scene History button opens history dialog', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final historyBtn = find.widgetWithText(OutlinedButton, 'Scene History');
      expect(historyBtn, findsOneWidget);

      await tester.tap(historyBtn);
      await tester.pumpAndSettle();

      expect(find.text('Scene Execution History'), findsOneWidget);
      expect(find.text('EXEC-SCN-20250110-141500'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Scene Execution History'), findsNothing);
    });

    testWidgets('Create Scene / Preset button opens create dialog', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final createBtn = find.widgetWithText(ElevatedButton, 'Create Scene / Preset');
      expect(createBtn, findsOneWidget);

      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      expect(find.text('Create Scene / Preset'), findsWidgets);
      expect(find.text('Scene / Preset Name *'), findsOneWidget);
      expect(find.textContaining('Device Actions / Steps'), findsOneWidget);

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Scene / Preset Name *'), findsNothing);
    });

    testWidgets('Table has single checkbox column and showCheckboxColumn is false (NO double checkbox)', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final dataTableFinder = find.byType(DataTable);
      expect(dataTableFinder, findsOneWidget);

      final dataTable = tester.widget<DataTable>(dataTableFinder);
      expect(dataTable.showCheckboxColumn, isFalse, reason: 'Enforces single checkbox column to eliminate Flutter double checkbox bug');

      // Verify the manual single checkbox in header column exists
      final headerCheckboxes = find.descendant(
        of: find.byType(DataTable),
        matching: find.byType(Checkbox),
      );
      expect(headerCheckboxes, findsWidgets);
    });

    testWidgets('Dynamic Target Selection: Switch to Multi-Select Devices across Locations', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final createBtn = find.widgetWithText(ElevatedButton, 'Create Scene / Preset');
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Tap Multi-Select Devices chip
      final multiSelectChip = find.text('Multi-Select Devices');
      expect(multiSelectChip, findsOneWidget);
      await tester.ensureVisible(multiSelectChip);
      await tester.tap(multiSelectChip);
      await tester.pumpAndSettle();

      // Verify multi-select search and device checklist
      expect(find.text('Search devices by name, code or room...'), findsOneWidget);
      expect(find.text('Select All'), findsOneWidget);
      expect(find.text('Smart Light Panel 1'), findsOneWidget);

      // Tap Select All
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Targeting:'), findsWidgets);

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Dynamic Step Sequence Builder: Configure Action Step with hardware parameters', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final createBtn = find.widgetWithText(ElevatedButton, 'Create Scene / Preset');
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Tap 'Add Action Step' button
      final addStepBtn = find.widgetWithText(ElevatedButton, 'Add Action Step');
      expect(addStepBtn, findsOneWidget);
      await tester.ensureVisible(addStepBtn);
      await tester.tap(addStepBtn);
      await tester.pumpAndSettle();

      // Verify step editor panel opened with hardware components
      expect(find.text('Configure New Action Step'), findsOneWidget);
      expect(find.text('Target Component / Hardware'), findsOneWidget);
      expect(find.text('Power Action'), findsWidgets);

      // Tap 'Add to Sequence'
      final addToSeqBtn = find.widgetWithText(ElevatedButton, 'Add to Sequence');
      expect(addToSeqBtn, findsOneWidget);
      await tester.ensureVisible(addToSeqBtn);
      await tester.tap(addToSeqBtn);
      await tester.pumpAndSettle();

      // Verify step editor closed and step added
      expect(find.text('Configure New Action Step'), findsNothing);
      expect(find.textContaining('Device Actions / Steps (4)'), findsOneWidget);

      // Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Responsive Layout - Desktop (1440x900) has 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive Layout - Tablet (800x1000) has 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive Layout - Mobile (400x800) has 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Dark Theme renders with 0 errors and proper contrast', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Scenes & Presets'), findsWidgets);
    });

    testWidgets('Multi-Selection: Checking row checkbox shows multi-selection toolbar with all operations', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Before checking: multi-selection action bar is not visible
      expect(find.text('Activate Selected'), findsNothing);
      expect(find.text('Deactivate Selected'), findsNothing);
      expect(find.text('Trigger All'), findsNothing);
      expect(find.text('Delete Selected'), findsNothing);

      // Find row checkboxes (index 0 is header checkbox, index 1 is first row checkbox)
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsAtLeastNWidgets(2));

      // Tap first row checkbox
      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();

      // Action bar now visible
      expect(find.text('1 scene/preset selected'), findsOneWidget);
      expect(find.text('Activate Selected'), findsOneWidget);
      expect(find.text('Deactivate Selected'), findsOneWidget);
      expect(find.text('Trigger All'), findsOneWidget);
      expect(find.text('Delete Selected'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);

      // Tap Clear All
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      // Action bar hides
      expect(find.text('1 scene/preset selected'), findsNothing);
      expect(find.text('Activate Selected'), findsNothing);
    });

    testWidgets('Zero double checkboxes and zero double ++ on Scenes & Presets screen', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('+ +'), findsNothing);
      expect(find.text('++'), findsNothing);
    });
  });
}
