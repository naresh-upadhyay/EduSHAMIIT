import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/device_management_kpis_bar.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/device_quick_controls_card.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/device_live_control_table.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/device_scenes_presets_card.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/dialogs/device_details_drawer.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/device_management_tab_view.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_groups_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_automations_subview.dart';
import 'package:edu_shamiit_core/screens/campus/services/device_management_api_service.dart';
import 'package:edu_shamiit_core/screens/campus/providers/device_management_provider.dart';

class _MockDeviceManagementNotifier extends DeviceManagementNotifier {
  _MockDeviceManagementNotifier() : super(DeviceManagementApiService.instance);

  @override
  Future<void> loadDeviceGroupsData() async {}

  @override
  Future<void> loadGroupMembers(String groupId) async {}
}

void main() {
  group('Device Management Models Test Suite', () {
    test('DeviceManagementKpis parses JSON correctly', () {
      final json = {
        'total_devices': 8742,
        'online': 8342,
        'offline': 400,
        'online_percentage': 95.4,
        'device_types': 24,
        'locations_summary': '6 Buildings • 42 Floors',
        'buildings_count': 6,
        'floors_count': 42,
        'automations_active': 128,
        'schedules_count': 276,
        'alerts_count': 18,
      };

      final kpis = DeviceManagementKpis.fromJson(json);
      expect(kpis.totalDevices, 8742);
      expect(kpis.online, 8342);
      expect(kpis.offline, 400);
      expect(kpis.onlinePercentage, 95.4);
      expect(kpis.deviceTypes, 24);
      expect(kpis.locationsSummary, '6 Buildings • 42 Floors');
      expect(kpis.automationsActive, 128);
      expect(kpis.schedulesCount, 276);
      expect(kpis.alertsCount, 18);
    });

    test('DeviceItemModel handles capability controls state', () {
      final json = {
        'id': 'd1-uuid',
        'device_name': 'AC-B1-F1-101-01',
        'device_code': 'AC-B1-F1-101-01',
        'type_name': 'AC (HVAC)',
        'type_code': 'ac',
        'location_display': 'B1 > F1 > Room 101',
        'is_online': true,
        'power_state': true,
        'current_state': {
          'power': true,
          'temperature': 24,
          'mode': 'Cool',
          'fan_speed': 'Medium',
        },
      };

      final device = DeviceItemModel.fromJson(json);
      expect(device.deviceName, 'AC-B1-F1-101-01');
      expect(device.typeCode, 'ac');
      expect(device.isOnline, true);
      expect(device.powerState, true);
      expect(device.currentState['temperature'], 24);
      expect(device.currentState['mode'], 'Cool');

      final updated = device.copyWith(
        powerState: false,
        currentState: {'power': false, 'temperature': 22},
      );
      expect(updated.powerState, false);
      expect(updated.currentState['temperature'], 22);
    });
  });

  group('Device Management Widgets & Responsiveness', () {
    testWidgets('DeviceManagementKpisBar renders all 8 metrics',
        (tester) async {
      const kpis = DeviceManagementKpis();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeviceManagementKpisBar(kpis: kpis),
          ),
        ),
      );

      expect(find.text('Total Devices'), findsOneWidget);
      expect(find.text('8,742'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('8,342 (95.4%)'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Device Types'), findsOneWidget);
      expect(find.text('Locations'), findsOneWidget);
      expect(find.text('Automations'), findsOneWidget);
      expect(find.text('Schedules'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
    });

    testWidgets('DeviceQuickControlsCard renders all 6 quick action tiles',
        (tester) async {
      String? triggeredAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: DeviceQuickControlsCard(
                onActionTriggered: (act) => triggeredAction = act,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Quick Controls (Entire Campus)'), findsOneWidget);
      expect(find.text('Turn ON'), findsOneWidget);
      expect(find.text('Turn OFF'), findsOneWidget);
      expect(find.text('Set Level'), findsOneWidget);
      expect(find.text('Set Temperature'), findsOneWidget);
      expect(find.text('Apply Scene'), findsOneWidget);
      expect(find.text('Power Supply'), findsOneWidget);

      await tester.tap(find.text('Turn ON'));
      await tester.pump();
      expect(triggeredAction, 'Turn ON');
    });

    testWidgets(
        'DeviceScenesPresetsCard renders preset grid and handles selection',
        (tester) async {
      DeviceSceneItem? selectedScene;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: DeviceScenesPresetsCard(
                scenes: const [],
                onSelectScene: (s) => selectedScene = s,
                onCreateCustomScene: () {},
                onManageScenes: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Scenes & Presets'), findsOneWidget);
      expect(find.text('Classroom'), findsOneWidget);
      expect(find.text('Lecture'), findsOneWidget);
      expect(find.text('Examination'), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
      expect(find.text('Energy Save'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      await tester.tap(find.text('Classroom'));
      await tester.pump();
      expect(selectedScene?.code, 'classroom');
    });

    testWidgets(
        'DeviceLiveControlTable renders dynamic controls and handles interactions without assertion errors',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testDevices = <DeviceItemModel>[
        const DeviceItemModel(
          id: 'dev-ac',
          deviceName: 'AC-B1-F1-101-01',
          deviceCode: 'AC-B1-F1-101-01',
          typeName: 'AC (HVAC)',
          typeCode: 'ac',
          typeIcon: 'ac',
          locationDisplay: 'B1 > F1 > Room 101',
          isOnline: true,
          powerState: true,
          currentState: {
            'power': true,
            'temperature': 24,
            'mode': 'Cool',
            'fan_speed': 'Medium'
          },
        ),
        const DeviceItemModel(
          id: 'dev-light',
          deviceName: 'Light-B1-F1-101-A',
          deviceCode: 'Light-B1-F1-101-A',
          typeName: 'Lighting',
          typeCode: 'lighting',
          typeIcon: 'light',
          locationDisplay: 'B1 > F1 > Room 101',
          isOnline: true,
          powerState: true,
          currentState: {'power': true, 'brightness': 80},
        ),
        const DeviceItemModel(
          id: 'dev-fan',
          deviceName: 'Fan-B1-F1-101-01',
          deviceCode: 'Fan-B1-F1-101-01',
          typeName: 'Fan',
          typeCode: 'fan',
          typeIcon: 'fan',
          locationDisplay: 'B1 > F1 > Room 101',
          isOnline: true,
          powerState: true,
          currentState: {'power': true, 'speed': 'Medium'},
        ),
        const DeviceItemModel(
          id: 'dev-proj',
          deviceName: 'Proj-B1-F1-101',
          deviceCode: 'Proj-B1-F1-101',
          typeName: 'Projector',
          typeCode: 'projector',
          typeIcon: 'projector',
          locationDisplay: 'B1 > F1 > Room 101',
          isOnline: true,
          powerState: true,
          currentState: {'power': true, 'input': 'HDMI 1', 'volume': 70},
        ),
        const DeviceItemModel(
          id: 'dev-gate',
          deviceName: 'Gate-ENT-Main',
          deviceCode: 'Gate-ENT-Main',
          typeName: 'Gate Controller',
          typeCode: 'gate',
          typeIcon: 'gate',
          locationDisplay: 'B1 > Main Entrance',
          isOnline: true,
          powerState: true,
          currentState: {'position': 'Closed', 'locked': true},
        ),
      ];

      String? clickedFanSpeed;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 500,
              child: DeviceLiveControlTable(
                devices: testDevices,
                isLoading: false,
                activeTab: 'Live Device Control',
                onTabChanged: (_) {},
                searchQuery: '',
                onSearchChanged: (_) {},
                selectedDeviceIds: const {'dev-ac'},
                onToggleSelect: (_) {},
                onToggleSelectAll: (_) {},
                onTogglePower: (_) {},
                onSetTemperature: (_, __) {},
                onSetHvacMode: (_, __) {},
                onSetFanSpeed: (_, s) => clickedFanSpeed = s,
                onSetBrightness: (_, __) {},
                onSetProjectorInput: (_, __) {},
                onSetProjectorVolume: (_, __) {},
                onGateControl: (_, __) {},
                onInspectDevice: (_) {},
                onDeleteDevice: (_) {},
                currentPage: 1,
                totalCount: 5,
                onPageChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check column headers exist
      expect(find.text('Device Name'), findsOneWidget);
      expect(find.text('Location (Building > Floor > Room)'), findsOneWidget);
      expect(find.text('Control / Current State'), findsOneWidget);

      // Check devices rendered
      expect(find.text('AC-B1-F1-101-01'), findsOneWidget);
      expect(find.text('Light-B1-F1-101-A'), findsOneWidget);
      expect(find.text('Fan-B1-F1-101-01'), findsOneWidget);
      expect(find.text('Proj-B1-F1-101'), findsOneWidget);
      expect(find.text('Gate-ENT-Main'), findsOneWidget);

      // Check fan segments and tap High
      expect(find.text('High'), findsOneWidget);
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();
      expect(clickedFanSpeed, 'High');

      // Check gate buttons
      expect(find.text('Lock'), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);

      // Ensure ZERO assertion exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('DeviceManagementTabView renders cleanly on Desktop (1440x900)',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DeviceManagementTabView(),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Device Management & Control'), findsOneWidget);
      expect(find.text('Add New Device'), findsOneWidget);
      expect(find.text('Campus Device Overview (Live)'), findsOneWidget);
      expect(find.text('Devices by Type'), findsOneWidget);
      expect(find.text('Quick Controls (Entire Campus)'), findsOneWidget);
      expect(find.text('Location Explorer'), findsOneWidget);
    });

    testWidgets(
        'DeviceManagementTabView renders with ZERO overflows on Mobile (360x640)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DeviceManagementTabView(),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Device Management & Control'), findsOneWidget);
      expect(find.text('Add New Device'), findsOneWidget);
      expect(tester.takeException(), isNull); // ZERO overflows
    });

    testWidgets(
        'DeviceDetailsDrawer renders type-specific controls and handles CRUD edit',
        (tester) async {
      const acDevice = DeviceItemModel(
        id: 'dev-ac-1',
        deviceName: 'AC-B1-F1-102-A',
        deviceCode: 'AC-B1-F1-102-A',
        typeName: 'AC (HVAC)',
        typeCode: 'ac',
        typeIcon: 'ac_unit',
        locationDisplay: 'B1 > F1 > 102',
        isOnline: true,
        powerState: true,
        currentState: {
          'temperature': 24,
          'mode': 'Cool',
          'fan_speed': 'Medium'
        },
      );

      bool powerToggled = false;
      int? updatedTemp;
      Map<String, dynamic>? updatedSpecs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceDetailsDrawer(
              device: acDevice,
              onClose: () {},
              onTogglePower: () => powerToggled = true,
              onSetTemperature: (t) => updatedTemp = t,
              onUpdateDevice: (d) => updatedSpecs = d,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify AC Climate controls rendered
      expect(find.text('HVAC & Climate Controls'), findsOneWidget);
      expect(find.text('24°C'), findsOneWidget);
      expect(find.text('Cool'), findsOneWidget);
      expect(find.text('Fan Speed'), findsOneWidget);

      // Tap + button to increment temperature
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(updatedTemp, 25);

      // Tap Turn OFF power button
      await tester.tap(find.text('Turn OFF'));
      await tester.pumpAndSettle();
      expect(powerToggled, true);

      // Verify Edit button exists and switch to Edit mode
      expect(find.text('Edit'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // Check edit form elements are visible
      expect(find.text('Edit Device Specifications'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Tap Save Changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(updatedSpecs, isNotNull);
      expect(updatedSpecs!['device_name'], 'AC-B1-F1-102-A');
    });

    testWidgets(
        'DeviceManagementTabView renders with ZERO overflows on Laptop (1280x800)',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DeviceManagementTabView(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'DeviceGroupsSubview renders groups, handles actions and opens create dialog',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testGroups = [
        {
          'id': 'grp-1',
          'name': 'Sports Complex Lighting',
          'code': 'GRP-SPORTS-LGT',
          'description': 'High-mast stadium floodlights',
          'device_count': 3,
          'color': '#2563EB',
        },
        {
          'id': 'grp-2',
          'name': 'Campus HVAC Fleet',
          'code': 'GRP-HVAC-ALL',
          'description': 'Centralized HVAC systems',
          'device_count': 3,
          'color': '#0284C7',
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider
                .overrideWith((ref) => _MockDeviceManagementNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DeviceGroupsSubview(
                groups: testGroups,
                onBackToDashboard: () {},
                onGroupAction: (_, __) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and create button
      expect(find.text('Device Groups'), findsWidgets);
      expect(find.text('Create Group'), findsOneWidget);

      // Tap Create Group
      await tester.tap(find.text('Create Group'));
      await tester.pumpAndSettle();
      expect(find.text('Create Device Group'), findsOneWidget);
      expect(find.text('Group Name *'), findsOneWidget);
    });

    testWidgets(
        'DeviceAutomationsSubview renders split rules list and interactive rule builder',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testAutomations = [
        {
          'id': 'rule-1',
          'name': 'Auto Close Classroom Door (No Occupancy)',
          'description':
              'Close automatic door when no one is in the room for 2 min',
          'trigger_type': 'smart',
          'is_active': true,
          'trigger_condition': {
            'category': 'Smart Rule',
            'location': 'B1 • Classrooms',
            'combinator': 'AND',
            'conditions': [
              {
                'attribute': 'Occupancy',
                'operator': 'is equal to',
                'value': '0 (No one)'
              },
              {
                'attribute': 'For a duration of',
                'operator': '>=',
                'value': '2',
                'unit': 'Minutes'
              },
            ],
          },
          'action_payload': {
            'execution_mode': 'In Sequence',
            'actions': [
              {'target': 'Automatic Door', 'action': 'Close'},
              {'target': 'Send Notification', 'action': 'To: Facility Team'},
            ],
          },
        },
        {
          'id': 'rule-2',
          'name': 'Turn Off Lights (Room Empty)',
          'description': 'Turn off lights when occupancy is zero for 5 min',
          'trigger_type': 'smart',
          'is_active': true,
          'trigger_condition': {
            'category': 'Smart Rule',
            'location': 'B1 • All Classrooms',
            'combinator': 'AND',
            'conditions': [
              {
                'attribute': 'Occupancy',
                'operator': 'is equal to',
                'value': '0 (No one)'
              },
            ],
          },
          'action_payload': {
            'execution_mode': 'In Sequence',
            'actions': [
              {'target': 'Classroom Lights', 'action': 'Turn OFF'},
            ],
          },
        },
      ];

      Map<String, dynamic>? testedData;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceAutomationsSubview(
              automations: testAutomations,
              onBackToDashboard: () {},
              onToggleAutomation: (_) {},
              onTestRule: (data) async {
                testedData = data;
                return {'condition_met': true, 'evaluation': 'Test Passed'};
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Left Pane: Header, rules list, badges
      expect(find.text('Automation Rules (2)'), findsOneWidget);
      expect(find.text('Create New Rule'), findsOneWidget);
      expect(find.text('Auto Close Classroom Door (No Occupancy)'),
          findsNWidgets(2)); // in list and editor title
      expect(find.text('Turn Off Lights (Room Empty)'), findsOneWidget);
      expect(find.text('B1 • Classrooms'), findsOneWidget);

      // Verify Right Pane: Rule Builder Form
      expect(find.text('IF (Conditions)'), findsOneWidget);
      expect(find.text('All Conditions (AND)'), findsOneWidget);
      expect(find.text('Add Condition'), findsOneWidget);

      expect(find.text('THEN (Actions)'), findsOneWidget);
      expect(find.text('In Sequence'), findsOneWidget);
      expect(find.text('Add Action'), findsOneWidget);

      expect(find.text('Also Set (Optional)'), findsOneWidget);
      expect(find.text('Effective For'), findsOneWidget);
      expect(find.text('Test Rule'), findsOneWidget);
      expect(find.text('Save Rule'), findsOneWidget);

      // Tap Test Rule
      await tester.tap(find.text('Test Rule'));
      await tester.pumpAndSettle();
      expect(testedData, isNotNull);
      expect(find.text('Test Passed'), findsOneWidget);
    });
  });
}
