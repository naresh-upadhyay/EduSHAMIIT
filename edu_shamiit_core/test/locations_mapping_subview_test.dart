import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_locations_mapping_subview.dart';
import 'package:edu_shamiit_core/screens/campus/providers/device_management_provider.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/services/device_management_api_service.dart';

void main() {
  group('DeviceLocationsMappingSubview Tests', () {
    testWidgets('Renders properly on Desktop (1440px) without overflow errors', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockDevices = List.generate(
        10,
        (i) => DeviceLocationMappingItem(
          id: 'dev-$i',
          deviceName: 'Device #$i',
          deviceCode: 'DEV-$i',
          deviceType: 'HVAC (AC)',
          roomSpace: 'Room 40${i + 1}',
          locationPath: 'Academic Block > F4',
          mappingStatus: 'Mapped',
          isOnline: true,
          powerState: true,
        ),
      );

      final state = DeviceManagementState(
        selectedLocationFloorId: 'd1b49946-edcc-46e0-9d26-57c09dbb6306',
        selectedLocationBuildingId: 'd4b547da-ca46-4976-af82-c1b89ac6f0a7',
        selectedLocationDetails: const LocationDetailsModel(
          id: 'd1b49946-edcc-46e0-9d26-57c09dbb6306',
          title: 'Academic Block (A) – Fourth Floor (F4)',
          buildingName: 'Academic Block (A)',
          floorNo: 4,
          totalRooms: 10,
          mappedDevices: 10,
          unmappedDevices: 0,
          groupsAssigned: 1,
          profilesInUse: 1,
          coveragePct: 100.0,
        ),
        locationMappedDevices: mockDevices,
        locationDevicesTotal: 10,
        locationDevicesPage: 1,
        locationDevicesPageSize: 10,
        locationsKpis: const LocationsMappingKpis(
          buildings: 8,
          floors: 38,
          rooms: 160,
          totalDevices: 179,
          mappedDevices: 50,
          mappedPct: 27.9,
          unmappedDevices: 129,
          unmappedPct: 72.1,
          locationsWithDevices: 34,
          coveragePct: 21.3,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) => _MockDeviceNotifier(state)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceLocationsMappingSubview(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title & devices rendered
      expect(find.text('Device Management & Control'), findsOneWidget);
      expect(find.textContaining('Fourth Floor (F4)'), findsWidgets);
      expect(find.text('DEV-0'), findsOneWidget);
      expect(find.text('DEV-9'), findsOneWidget);

      // Verify no hardcoded numbers like 132 or 4 or 97.1%
      expect(find.text('132'), findsNothing);
      expect(find.text('97.1%'), findsNothing);

      // Verify sortable headers present
      expect(find.text('Device Name'), findsOneWidget);
      expect(find.text('Device Type'), findsOneWidget);
      expect(find.text('Room / Space'), findsOneWidget);
      expect(find.text('Mapping Status'), findsOneWidget);

      // Verify pagination
      expect(find.textContaining('Showing 1 – 10 of 10 devices'), findsOneWidget);
      expect(find.text('Rows per page:'), findsOneWidget);
    });

    testWidgets('Renders properly on Tablet (800px) and Mobile (400px) with 0 overflows', (tester) async {
      // 1. Test Tablet (800x1000)
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;

      const state = DeviceManagementState(
        selectedLocationFloorId: 'd1b49946-edcc-46e0-9d26-57c09dbb6306',
        selectedLocationDetails: LocationDetailsModel(
          id: 'd1b49946-edcc-46e0-9d26-57c09dbb6306',
          title: 'Academic Block (A) – Fourth Floor (F4)',
          totalRooms: 10,
          mappedDevices: 10,
        ),
        locationMappedDevices: [],
        locationDevicesTotal: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) => _MockDeviceNotifier(state)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceLocationsMappingSubview(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 2. Test Mobile (400x800)
      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Selection and Bulk Actions appear without double checkboxes', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockDevices = [
        const DeviceLocationMappingItem(
          id: 'dev-1',
          deviceName: 'Light Panel A',
          deviceCode: 'LGT-01',
          deviceType: 'Lighting',
          roomSpace: 'Room 401',
          locationPath: 'Academic Block > F4',
          mappingStatus: 'Mapped',
          isOnline: true,
          powerState: true,
        ),
      ];

      final state = DeviceManagementState(
        selectedLocationFloorId: 'd1b49946-edcc-46e0-9d26-57c09dbb6306',
        locationMappedDevices: mockDevices,
        locationDevicesTotal: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) => _MockDeviceNotifier(state)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceLocationsMappingSubview(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Checkboxes: exactly 1 header checkbox and 1 row checkbox
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));

      // Tap row checkbox to select device
      await tester.tap(checkboxes.last);
      await tester.pumpAndSettle();

      // Verify bulk action bar appeared
      expect(find.text('1 of 1 devices selected'), findsOneWidget);
      expect(find.text('Unmap Selected'), findsOneWidget);
      expect(find.text('Relocate Selected'), findsOneWidget);
      expect(find.text('Deselect All'), findsOneWidget);

      // Tap Deselect All
      await tester.ensureVisible(find.text('Deselect All'));
      await tester.tap(find.text('Deselect All'));
      await tester.pumpAndSettle();

      // Bulk action bar should disappear
      expect(find.text('1 of 1 devices selected'), findsNothing);
    });
  });
}

class _MockDeviceNotifier extends DeviceManagementNotifier {
  _MockDeviceNotifier(DeviceManagementState initialState)
      : super(DeviceManagementApiService.instance) {
    state = initialState;
  }

  @override
  Future<void> loadLocationsMappingData() async {}

  @override
  Future<void> selectLocationFloor({
    required String floorId,
    String? buildingId,
    String? roomId,
  }) async {}

  @override
  Future<bool> unmapDevices({required List<String> deviceIds, String? reason}) async {
    state = state.copyWith(
      locationMappedDevices: state.locationMappedDevices
          .where((d) => !deviceIds.contains(d.id))
          .toList(),
    );
    return true;
  }
}
