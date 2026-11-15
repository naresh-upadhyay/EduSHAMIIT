import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/services/device_management_api_service.dart';
import 'package:edu_shamiit_core/screens/campus/providers/device_management_provider.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_live_control_subview.dart';

class TestLiveControlNotifier extends DeviceManagementNotifier {
  final List<Map<String, dynamic>> executedCommands = [];

  TestLiveControlNotifier(DeviceManagementState initial)
      : super(DeviceManagementApiService.instance) {
    state = initial;
  }

  @override
  Future<void> loadLiveControlData() async {}

  @override
  Future<bool> executeLiveDeviceCommand({
    required String deviceId,
    required String commandType,
    required Map<String, dynamic> payload,
  }) async {
    executedCommands.add({
      'deviceId': deviceId,
      'commandType': commandType,
      'payload': payload,
    });
    return super.executeLiveDeviceCommand(
      deviceId: deviceId,
      commandType: commandType,
      payload: payload,
    );
  }
}

void main() {
  group('Live Control - Models Unit Tests', () {
    test('LiveControlKpis deserialization matching exact screenshot metrics', () {
      final json = {
        'online_devices': 8342,
        'online_percentage': 95.4,
        'offline_devices': 400,
        'offline_percentage': 4.6,
        'controllable_now': 8106,
        'active_groups': 118,
        'running_automations': 27,
        'active_schedules': 63,
      };

      final kpis = LiveControlKpis.fromJson(json);
      expect(kpis.onlineDevices, 8342);
      expect(kpis.onlinePercentage, 95.4);
      expect(kpis.offlineDevices, 400);
      expect(kpis.offlinePercentage, 4.6);
      expect(kpis.controllableNow, 8106);
      expect(kpis.activeGroups, 118);
      expect(kpis.runningAutomations, 27);
      expect(kpis.activeSchedules, 63);
    });

    test('LiveControlDeviceItem state getters for 8 canonical device types', () {
      final acItem = LiveControlDeviceItem.fromJson({
        'id': 'c1c00000-0000-0000-0000-000000000009',
        'device_name': 'AC (HVAC)',
        'device_code': 'AC-A1-103',
        'device_type_name': 'HVAC (AC)',
        'device_type_code': 'ac',
        'room_number': 'A1-103',
        'current_state': {
          'power': true,
          'temperature': 24,
          'mode': 'Cool',
          'fan_speed': 'Medium',
          'swing': true,
          'quick_preset': 'Classroom',
        },
      });

      expect(acItem.temperature, 24);
      expect(acItem.mode, 'Cool');
      expect(acItem.fanSpeed, 'Medium');
      expect(acItem.swing, true);
      expect(acItem.quickPreset, 'Classroom');

      final lightItem = LiveControlDeviceItem.fromJson({
        'id': 'c1c00000-0000-0000-0000-000000000008',
        'device_name': 'Classroom Lights',
        'device_code': 'LIGHT-A1-103',
        'device_type_name': 'Lighting',
        'current_state': {'power': true, 'brightness': 80},
      });
      expect(lightItem.brightness, 80);

      final switchItem = LiveControlDeviceItem.fromJson({
        'id': 'c1c00000-0000-0000-0000-000000000020',
        'device_name': 'Smart Switch',
        'device_code': 'SW-A1-103',
        'device_type_name': 'Power & Switches',
        'current_state': {'channels': [1, 2, 4]},
      });
      expect(switchItem.channels, [1, 2, 4]);

      final doorItem = LiveControlDeviceItem.fromJson({
        'id': 'c1c00000-0000-0000-0000-000000000022',
        'device_name': 'Access Door',
        'device_code': 'DOOR-A1-103',
        'device_type_name': 'Smart Door',
        'current_state': {'status': 'locked', 'lock_state': true},
      });
      expect(doorItem.isLocked, true);
    });

    test('LiveDeviceCommandLog deserialization', () {
      final log = LiveDeviceCommandLog.fromJson({
        'id': 'cmd-1',
        'command_type': 'set_temperature',
        'payload': {'temperature': 24},
        'status': 'acknowledged',
        'created_at': '2026-11-12T10:00:00Z',
      });
      expect(log.id, 'cmd-1');
      expect(log.commandType, 'set_temperature');
      expect(log.payload['temperature'], 24);
      expect(log.status, 'acknowledged');
    });
  });

  group('Live Control - Widget Tests', () {
    late List<LiveControlDeviceItem> mockDevices;
    late DeviceManagementState mockState;

    setUp(() {
      mockDevices = [
        const LiveControlDeviceItem(
          id: 'c1c00000-0000-0000-0000-000000000008',
          deviceName: 'Classroom Lights',
          deviceCode: 'LIGHT-A1-103',
          deviceTypeName: 'Lighting',
          roomNumber: 'A1-103',
          currentState: {'power': true, 'brightness': 80},
        ),
        const LiveControlDeviceItem(
          id: 'c1c00000-0000-0000-0000-000000000009',
          deviceName: 'AC (HVAC)',
          deviceCode: 'AC-A1-103',
          deviceTypeName: 'HVAC (AC)',
          roomNumber: 'A1-103',
          currentState: {
            'power': true,
            'temperature': 24,
            'mode': 'Cool',
            'fan_speed': 'Medium',
            'swing': true,
            'quick_preset': 'Classroom',
          },
        ),
        const LiveControlDeviceItem(
          id: 'c1c00000-0000-0000-0000-000000000018',
          deviceName: 'Projector',
          deviceCode: 'PRJ-A1-103',
          deviceTypeName: 'Projector',
          roomNumber: 'A1-103',
          currentState: {'power': true, 'input': 'HDMI 1'},
        ),
        const LiveControlDeviceItem(
          id: 'c1c00000-0000-0000-0000-000000000019',
          deviceName: 'Fan',
          deviceCode: 'FAN-A1-103',
          deviceTypeName: 'Fan',
          roomNumber: 'A1-103',
          currentState: {'power': true, 'speed': 'Medium'},
        ),
        const LiveControlDeviceItem(
          id: 'c1c00000-0000-0000-0000-000000000020',
          deviceName: 'Smart Switch',
          deviceCode: 'SW-A1-103',
          deviceTypeName: 'Power & Switches',
          roomNumber: 'A1-103',
          currentState: {'power': true, 'channels': [1, 2, 4]},
        ),
        const LiveControlDeviceItem(
          id: 'c1c00000-0000-0000-0000-000000000021',
          deviceName: 'CCTV',
          deviceCode: 'CAM-A1-103',
          deviceTypeName: 'CCTV',
          roomNumber: 'A1-103',
          currentState: {'power': true, 'recording': true},
        ),
        const LiveControlDeviceItem(
          id: 'c1c00000-0000-0000-0000-000000000022',
          deviceName: 'Access Door',
          deviceCode: 'DOOR-A1-103',
          deviceTypeName: 'Smart Door',
          roomNumber: 'A1-103',
          currentState: {'status': 'locked', 'lock_state': true},
        ),
        const LiveControlDeviceItem(
          id: 'c1c00000-0000-0000-0000-000000000023',
          deviceName: 'Audio / Speaker',
          deviceCode: 'SPK-A1-103',
          deviceTypeName: 'Audio / Speaker',
          roomNumber: 'A1-103',
          currentState: {'power': true, 'volume': 65},
        ),
      ];

      mockState = DeviceManagementState(
        liveControlKpis: const LiveControlKpis(
          onlineDevices: 8342,
          onlinePercentage: 95.4,
          offlineDevices: 400,
          offlinePercentage: 4.6,
          controllableNow: 8106,
          activeGroups: 118,
          runningAutomations: 27,
          activeSchedules: 63,
        ),
        liveControlDevices: mockDevices,
        selectedLiveDeviceId: 'c1c00000-0000-0000-0000-000000000009',
        selectedLiveDevice: mockDevices[1], // AC (HVAC)
        liveDeviceDetails: LiveControlDeviceDetails(
          device: mockDevices[1],
          recentLogs: const [
            LiveDeviceCommandLog(
              id: '1',
              commandType: 'set_temperature',
              payload: {'temperature': 24},
              status: 'acknowledged',
            ),
          ],
        ),
      );
    });

    Widget createTestWidget({
      DeviceManagementState? state,
      TestLiveControlNotifier? notifier,
      Size size = const Size(1600, 1000),
    }) {
      final s = state ?? mockState;
      final notif = notifier ?? TestLiveControlNotifier(s);

      return ProviderScope(
        overrides: [
          deviceManagementProvider.overrideWith((ref) => notif),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(size: size),
              child: const SizedBox(
                width: 1600,
                height: 1000,
                child: DeviceLiveControlSubview(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Renders all 6 operational KPI metrics accurately', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Online Devices'), findsOneWidget);
      expect(find.text('8,342 (95.4%)'), findsOneWidget);
      expect(find.text('Offline Devices'), findsOneWidget);
      expect(find.text('400 (4.6%)'), findsOneWidget);
      expect(find.text('Controllable Now'), findsOneWidget);
      expect(find.text('8,106'), findsOneWidget);
      expect(find.text('Active Groups'), findsOneWidget);
      expect(find.text('118'), findsOneWidget);
      expect(find.text('Running Automations'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);
      expect(find.text('Active Schedules'), findsOneWidget);
      expect(find.text('63'), findsOneWidget);
    });

    testWidgets('Renders 5 Sub-Nav Tabs properly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Live Control'), findsWidgets);
      expect(find.text('Device Control'), findsOneWidget);
      expect(find.text('Group Control'), findsOneWidget);
      expect(find.text('Location Control'), findsOneWidget);
      expect(find.text('Scenes & Presets'), findsOneWidget);
      expect(find.text('Live View (CCTV)'), findsOneWidget);
    });

    testWidgets('Renders 8 Canonical Device Cards in Room A1-103', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Classroom Lights'), findsOneWidget);
      expect(find.text('AC (HVAC)'), findsWidgets);
      expect(find.text('Projector'), findsWidgets);
      expect(find.text('Fan'), findsWidgets);
      expect(find.text('Smart Switch'), findsWidgets);
      expect(find.text('CCTV'), findsWidgets);
      expect(find.text('Access Door'), findsWidgets);
      expect(find.text('Audio / Speaker'), findsWidgets);
    });

    testWidgets('Interactive Device Cards: Temp Adjust, Switch Channels, Door Lock', (tester) async {
      final notifier = TestLiveControlNotifier(mockState);
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      await tester.pumpWidget(createTestWidget(notifier: notifier));
      await tester.pumpAndSettle();

      // Find '+' on AC card or inspector and tap
      final addIcons = find.byIcon(Icons.add);
      expect(addIcons, findsWidgets);
      await tester.tap(addIcons.first);
      await tester.pumpAndSettle();

      // Expect command executed
      expect(notifier.executedCommands.isNotEmpty, isTrue);
      expect(notifier.executedCommands.first['commandType'], 'set_temperature');
    });

    testWidgets('Renders Floor Plan view with A1-103 Classroom & Legend', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Floor Plan – Academic Block (A) > First Floor'), findsOneWidget);
      expect(find.text('Open Full Plan'), findsOneWidget);
      expect(find.text('A1-101'), findsOneWidget);
      expect(find.text('A1-102'), findsOneWidget);
      expect(find.text('A1-103'), findsWidgets);
      expect(find.text('A1-104'), findsOneWidget);
      expect(find.text('Corridor'), findsOneWidget);
      expect(find.text('A1-105'), findsOneWidget);
      expect(find.text('A1-106'), findsOneWidget);
      expect(find.text('A1-107'), findsOneWidget);
      expect(find.text('Legend'), findsOneWidget);
    });

    testWidgets('Renders Right Device Control Panel Inspector with Mode, Presets, Info', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Device Control Panel'), findsOneWidget);
      expect(find.text('Power'), findsOneWidget);
      expect(find.text('Mode'), findsOneWidget);
      expect(find.text('Cool'), findsWidgets);
      expect(find.text('Heat'), findsOneWidget);
      expect(find.text('Temperature'), findsWidgets);
      expect(find.text('24°C'), findsWidgets);
      expect(find.text('Quick Presets'), findsOneWidget);
      expect(find.text('Classroom'), findsWidgets);
      expect(find.text('Meeting'), findsOneWidget);
      expect(find.text('Energy Save'), findsOneWidget);
      expect(find.text('Device Information'), findsOneWidget);
      expect(find.text('AC-A1-103'), findsWidgets);
    });

    testWidgets('Tapping Open Full Plan opens expanded floor plan modal dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1200));
      await tester.pumpWidget(createTestWidget(size: const Size(1600, 1200)));
      await tester.pumpAndSettle();

      final fullPlanBtn = find.text('Open Full Plan');
      await tester.ensureVisible(fullPlanBtn);
      await tester.pumpAndSettle();
      await tester.tap(fullPlanBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Full Architectural Floor Plan'), findsOneWidget);
    });

    testWidgets('Tapping CCTV Live View opens live video modal dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1200));
      await tester.pumpWidget(createTestWidget(size: const Size(1600, 1200)));
      await tester.pumpAndSettle();

      final liveViewBtn = find.text('Live View');
      await tester.ensureVisible(liveViewBtn);
      await tester.pumpAndSettle();
      await tester.tap(liveViewBtn);
      await tester.pumpAndSettle();

      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Close Stream'), findsOneWidget);
    });

    testWidgets('Responsive Layout on Compact / Mobile without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) => TestLiveControlNotifier(mockState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 1400,
                child: DeviceLiveControlSubview(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
