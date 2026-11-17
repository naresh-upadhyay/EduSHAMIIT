import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_automations_subview.dart';

void main() {
  final testAutomations = [
    {
      'id': 'a1111111-1111-1111-1111-111111111001',
      'name': 'Turn Off Lights (Room Empty)',
      'description': 'Turn off lights when occupancy is zero for 10 min',
      'category': 'Smart Rule',
      'location_scope': {'location_name': 'B1 • Classrooms'},
      'building_name': 'Academic Block (A)',
      'target_scope': {'target_name': 'Classroom Lights'},
      'status': 'active',
      'is_active': true,
      'execution_count': 142,
      'trigger_condition': {
        'combinator': 'AND',
        'category': 'Smart Rule',
        'location': 'B1 • Classrooms',
        'conditions': [
          {'attribute': 'Occupancy', 'operator': 'is equal to', 'value': '0 (No one)', 'unit': ''},
          {'attribute': 'For a duration of', 'operator': '>=', 'value': '10', 'unit': 'Minutes'}
        ],
      },
      'action_payload': {
        'execution_mode': 'In Sequence',
        'actions': [
          {'target_type': 'device_type', 'target': 'Classroom Lights', 'action': 'Turn OFF', 'parameter': ''},
          {'target_type': 'notification', 'target': 'Send Notification', 'action': 'To: Facility Team', 'parameter': ''}
        ],
      },
      'allow_manual_override': true,
      'log_activity': true,
      'effective_for': 'always',
    },
    {
      'id': 'a1111111-1111-1111-1111-111111111002',
      'name': 'Turn Off Fans (No Students)',
      'description': 'Turn off fans when class ends and room is empty',
      'category': 'Smart Rule',
      'location_scope': {'location_name': 'B1 • Classrooms'},
      'building_name': 'Academic Block (A)',
      'target_scope': {'target_name': 'Ceiling Fans'},
      'status': 'active',
      'is_active': true,
      'execution_count': 98,
      'trigger_condition': {
        'combinator': 'AND',
        'category': 'Smart Rule',
        'location': 'B1 • Classrooms',
        'conditions': [
          {'attribute': 'Occupancy', 'operator': 'is equal to', 'value': '0', 'unit': 'Students'},
          {'attribute': 'For a duration of', 'operator': '>=', 'value': '5', 'unit': 'Minutes'}
        ],
      },
      'action_payload': {
        'execution_mode': 'In Sequence',
        'actions': [
          {'target_type': 'device_type', 'target': 'Ceiling Fans', 'action': 'Turn OFF', 'parameter': ''}
        ],
      },
      'allow_manual_override': true,
      'log_activity': true,
      'effective_for': 'always',
    },
    {
      'id': 'a1111111-1111-1111-1111-111111111003',
      'name': 'Projector Auto OFF (No Input)',
      'description': 'Turn off projector when no signal is detected for 10 min',
      'category': 'Smart Rule',
      'location_scope': {'location_name': 'B1 • Classrooms'},
      'building_name': 'Academic Block (A)',
      'target_scope': {'target_name': 'Projectors'},
      'status': 'active',
      'is_active': true,
      'execution_count': 64,
      'trigger_condition': {
        'combinator': 'AND',
        'category': 'Smart Rule',
        'location': 'B1 • Classrooms',
        'conditions': [
          {'attribute': 'Video Input Signal', 'operator': 'is equal to', 'value': 'None / Inactive', 'unit': ''},
          {'attribute': 'For a duration of', 'operator': '>=', 'value': '10', 'unit': 'Minutes'}
        ],
      },
      'action_payload': {
        'execution_mode': 'In Sequence',
        'actions': [
          {'target_type': 'device_type', 'target': 'Projector', 'action': 'Turn OFF', 'parameter': ''}
        ],
      },
      'allow_manual_override': true,
      'log_activity': true,
      'effective_for': 'always',
    },
    {
      'id': 'a1111111-1111-1111-1111-111111111004',
      'name': 'Main Entrance - Auto Open (Class Time)',
      'description': 'Open main entrance 30 min before first class',
      'category': 'Schedule Rule',
      'location_scope': {'location_name': 'B1 • Main Entrance'},
      'building_name': 'Academic Block (A)',
      'target_scope': {'target_name': 'Automatic Door'},
      'status': 'inactive',
      'is_active': false,
      'execution_count': 12,
      'trigger_condition': {
        'combinator': 'AND',
        'category': 'Schedule Rule',
        'location': 'B1 • Main Entrance',
        'conditions': [
          {'attribute': 'Time of Day', 'operator': 'is equal to', 'value': '07:30 AM', 'unit': ''}
        ],
      },
      'action_payload': {
        'execution_mode': 'In Sequence',
        'actions': [
          {'target_type': 'device_type', 'target': 'Automatic Door', 'action': 'Open', 'parameter': ''}
        ],
      },
      'allow_manual_override': true,
      'log_activity': true,
      'effective_for': 'schedule',
    }
  ];

  final testCascadingOptions = {
    'buildings': [
      {'id': 'b-1', 'name': 'Academic Block (A)', 'code': 'A'},
      {'id': 'b-2', 'name': 'Science Block (B)', 'code': 'B'},
    ],
    'floors': [
      {'id': 'f-1', 'name': 'Ground Floor', 'building_id': 'b-1'},
      {'id': 'f-2', 'name': 'First Floor', 'building_id': 'b-1'},
    ],
    'rooms': [
      {'id': 'r-1', 'name': 'Room 101 - Grade 1A', 'floor_id': 'f-1', 'building_id': 'b-1'},
      {'id': 'r-2', 'name': 'Computer Lab 1', 'floor_id': 'f-2', 'building_id': 'b-1'},
    ],
    'device_types': [
      {'id': 'dt-1', 'name': 'Lighting'},
      {'id': 'dt-2', 'name': 'HVAC (AC)'},
      {'id': 'dt-3', 'name': 'Projector'},
    ],
    'device_groups': [
      {'id': 'dg-1', 'name': 'Classroom Lights (A)'},
      {'id': 'dg-2', 'name': 'Main HVAC Units'},
    ],
    'devices': [
      {'id': 'd-1', 'name': 'Classroom Light A-101', 'device_code': 'LGT-001'},
      {'id': 'd-2', 'name': 'AC Unit A-101', 'device_code': 'AC-001'},
    ],
    'scenes': [
      {'id': 'sc-1', 'name': 'Lecture Mode'},
      {'id': 'sc-2', 'name': 'Examination Mode'},
    ],
    'condition_attributes': [
      {'attribute': 'Occupancy'},
      {'attribute': 'For a duration of'},
      {'attribute': 'Room Temperature'},
    ],
    'action_commands': [
      {'action': 'Turn ON'},
      {'action': 'Turn OFF'},
      {'action': 'Set Temperature'},
    ],
  };

  final testKpis = {
    'total_rules': 8,
    'active_rules': 7,
    'inactive_rules': 1,
    'triggers_today': 428,
    'devices_governed': 8342,
    'health_percentage': 99.4,
    'cron_active': true,
    'cron_interval_sec': 60,
    'last_cron_run': '2026-11-17T05:00:00Z',
  };

  Widget buildTestWidget({
    Size surfaceSize = const Size(1440, 900),
    VoidCallback? onBack,
    Function(String id)? onToggle,
    Function(Map<String, dynamic> data)? onCreate,
    Function(String ruleId, Map<String, dynamic> data)? onUpdate,
    Function(String ruleId)? onDelete,
    Function(String ruleId)? onDuplicate,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)? onTest,
    Future<Map<String, dynamic>> Function()? onRunCron,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(size: surfaceSize),
          child: SizedBox(
            width: surfaceSize.width,
            height: surfaceSize.height,
            child: DeviceAutomationsSubview(
              automations: testAutomations,
              initialKpis: testKpis,
              initialCascadingOptions: testCascadingOptions,
              initialIsLoading: false,
              apiBaseUrl: 'mock',
              onBackToDashboard: onBack,
              onToggleAutomation: onToggle ?? (_) {},
              onCreateRule: onCreate ?? (_) {},
              onUpdateRule: onUpdate ?? (_, __) {},
              onDeleteRule: onDelete ?? (_) {},
              onDuplicateRule: onDuplicate ?? (_) {},
              onTestRule: onTest ?? (_) async => {
                'success': true,
                'condition_met': true,
                'matching_devices_count': 4,
                'evaluation': 'All conditions satisfied against live telemetry.',
                'sample_devices': [
                  {'name': 'Classroom Light A-101', 'code': 'LGT-001', 'status': 'ONLINE'}
                ],
                'simulated_actions': [
                  {'target': 'Classroom Lights', 'action': 'Turn OFF'}
                ],
              },
              onRunCron: onRunCron ?? () async => {'success': true, 'evaluated_rules': 8},
            ),
          ),
        ),
      ),
    );
  }

  group('Device Automations Subview - Comprehensive Widget Tests', () {
    testWidgets('1. Renders top 6 Dynamic KPI cards and Live Cron pill', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Top Header
      expect(find.text('Campus Automation Rules'), findsOneWidget);
      expect(find.text('Trigger automated device operations based on occupancy, schedules, and environmental thresholds'), findsOneWidget);

      // KPI Cards
      expect(find.text('Total Rules'), findsOneWidget);
      expect(find.text('Active Rules'), findsOneWidget);
      expect(find.text('Inactive Rules'), findsOneWidget);
      expect(find.text('Triggers Today'), findsOneWidget);
      expect(find.text('Governed Devices'), findsOneWidget);
      expect(find.text('Health Rate'), findsOneWidget);

      // Cron Status pill
      expect(find.text('Cron: 60s'), findsOneWidget);
      expect(find.text('Run Cron'), findsOneWidget);
    });

    testWidgets('2. Zero double checkboxes and exactly one checkbox per rule in grid data', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // In the rule list, each row has exactly 1 checkbox (4 rule rows = 4 checkboxes)
      final listCheckboxes = find.descendant(of: find.byType(ListView), matching: find.byType(Checkbox));
      expect(listCheckboxes, findsNWidgets(4));

      // Plus 1 in list header (select-all) and 3 in the editor panel (optional flags) = 8 total
      expect(find.byType(Checkbox), findsNWidgets(8));
    });

    testWidgets('3. Multi-selection batch action bar appears when items are checked', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initially batch action bar is hidden
      expect(find.textContaining('Selected:'), findsNothing);

      // Tap the first rule's checkbox in the ListView
      final firstRowCheckbox = find.descendant(of: find.byType(ListView), matching: find.byType(Checkbox)).first;
      await tester.tap(firstRowCheckbox);
      await tester.pumpAndSettle();

      // Batch action bar should now be visible
      expect(find.text('Selected: 1 rules'), findsOneWidget);
      expect(find.text('Enable All'), findsOneWidget);
      expect(find.text('Disable All'), findsOneWidget);
      expect(find.text('Delete Selected'), findsOneWidget);
      expect(find.text('Run Selected'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);

      // Tap Clear
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Selected:'), findsNothing);
    });

    testWidgets('4. Zero double ++ on any button or UI text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Ensure no double ++ anywhere
      expect(find.textContaining('++'), findsNothing);
      expect(find.textContaining('+ +'), findsNothing);

      // Verify clean single + buttons
      expect(find.text('Create New Rule'), findsWidgets);
      expect(find.text('Add Condition'), findsOneWidget);
      expect(find.text('Add Action'), findsOneWidget);
    });

    testWidgets('5. Selecting a rule from list loads its details into the Rule Editor', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Default editor loads rule 1
      expect(find.text('Edit Automation Rule'), findsOneWidget);
      expect(find.text('Turn Off Lights (Room Empty)'), findsWidgets);

      // Tap second rule in ListView
      await tester.tap(find.text('Turn Off Fans (No Students)').first);
      await tester.pumpAndSettle();

      expect(find.text('Turn Off Fans (No Students)'), findsWidgets);
    });

    testWidgets('6. Create New Rule button clears editor and loads template', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create New Rule').first);
      await tester.pumpAndSettle();

      expect(find.text('Create Automation Rule'), findsOneWidget);
    });

    testWidgets('7. Test Rule button triggers simulation dialog with live telemetry', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Ensure Test Rule button is visible in right panel
      final testRuleBtn = find.text('Test Rule');
      expect(testRuleBtn, findsOneWidget);

      await tester.tap(testRuleBtn);
      await tester.pumpAndSettle();

      // Verify simulation dialog appears
      expect(find.textContaining('Live Telemetry Simulation'), findsOneWidget);
      expect(find.textContaining('Matching Real Devices Evaluated'), findsOneWidget);
      expect(find.textContaining('Actions to Dispatch'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Live Telemetry Simulation'), findsNothing);
    });

    testWidgets('8. Database pagination controls and page size selector render properly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Database pagination controls
      expect(find.textContaining('Rows:'), findsOneWidget);
      expect(find.textContaining('Showing 1 - 4 of 4 rules'), findsOneWidget);
    });

    testWidgets('9. Responsive layout on Tablet (800x1024) with zero overflow errors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1024));
      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(800, 1024)));
      await tester.pumpAndSettle();

      // In tablet mode, sub-tabs switch between Rules List and Edit Rule
      expect(find.text('Rules List (4)'), findsOneWidget);
      expect(find.text('Edit Rule'), findsOneWidget);

      // Switch to Edit Rule tab
      await tester.tap(find.text('Edit Rule'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Automation Rule'), findsOneWidget);
      expect(find.text('IF (Conditions)'), findsOneWidget);
      expect(find.text('THEN (Actions)'), findsOneWidget);
    });

    testWidgets('10. Responsive layout on Mobile (400x850) with zero overflow errors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 850));
      await tester.pumpWidget(buildTestWidget(surfaceSize: const Size(400, 850)));
      await tester.pumpAndSettle();

      // Verify mobile tabs and rule cards render without overflow
      expect(find.text('Rules List (4)'), findsOneWidget);
      expect(find.text('Edit Rule'), findsOneWidget);

      // Switch tab on mobile
      await tester.tap(find.text('Edit Rule'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Automation Rule'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });
  });
}
