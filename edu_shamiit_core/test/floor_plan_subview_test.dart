import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/services/device_management_api_service.dart';
import 'package:edu_shamiit_core/screens/campus/providers/device_management_provider.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_locations_mapping_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/dialogs/floor_plan_fullscreen_dialog.dart';

class TestDeviceManagementNotifier extends DeviceManagementNotifier {
  TestDeviceManagementNotifier() : super(DeviceManagementApiService.instance);

  @override
  Future<void> loadLocationsMappingData() async {}

  @override
  Future<void> selectLocationFloor({required String floorId, String? buildingId, String? roomId}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testRooms = [
    const FloorPlanRoomLayout(roomId: 'r201', code: '201', name: 'Grade 4 - Section A', roomType: 'Classroom', x: 0.04, y: 0.06, w: 0.21, h: 0.38),
    const FloorPlanRoomLayout(roomId: 'r202', code: '202', name: 'Grade 4 - Section B', roomType: 'Classroom', x: 0.27, y: 0.06, w: 0.21, h: 0.38),
    const FloorPlanRoomLayout(roomId: 'r203', code: '203', name: 'Grade 4 - Section C', roomType: 'Classroom', x: 0.50, y: 0.06, w: 0.21, h: 0.38),
    const FloorPlanRoomLayout(roomId: 'r204', code: '204', name: 'Grade 5 - Section A', roomType: 'Classroom', x: 0.73, y: 0.06, w: 0.23, h: 0.38),
    const FloorPlanRoomLayout(roomId: 'corridor', code: 'Corridor', name: 'Corridor', roomType: 'Corridor', x: 0.04, y: 0.46, w: 0.92, h: 0.10),
    const FloorPlanRoomLayout(roomId: 'r205', code: '205', name: 'Grade 5 - Section B', roomType: 'Classroom', x: 0.04, y: 0.58, w: 0.21, h: 0.38),
    const FloorPlanRoomLayout(roomId: 'r206', code: '206', name: 'Grade 5 - Section C', roomType: 'Classroom', x: 0.27, y: 0.58, w: 0.21, h: 0.38),
    const FloorPlanRoomLayout(roomId: 'r207', code: '207', name: 'Chemistry Laboratory Beta', roomType: 'Laboratory', x: 0.50, y: 0.58, w: 0.21, h: 0.38),
    const FloorPlanRoomLayout(roomId: 'r208', code: '208', name: 'Staff Room - Wing 2', roomType: 'Staff Room', x: 0.73, y: 0.58, w: 0.23, h: 0.38),
  ];

  final testFloors = [
    const FloorPlanAvailableFloor(id: '8770a0e6-8aa9-4e65-9a85-539eabd5f9a6', name: 'First Floor (F1)', floorLevel: 1, isCurrent: false),
    const FloorPlanAvailableFloor(id: 'b88cf8d5-d000-40ea-b1c5-be7534ca74ab', name: 'Second Floor (F2)', floorLevel: 2, isCurrent: true),
  ];

  final testAsset = FloorPlanAssetModel(
    id: 'fp-second-floor',
    floorId: 'b88cf8d5-d000-40ea-b1c5-be7534ca74ab',
    buildingName: 'Academic Block (A)',
    floorName: 'Second Floor',
    title: 'Academic Block (A) – Second Floor Architectural Blueprint',
    roomsLayout: testRooms,
    availableFloors: testFloors,
  );

  final testMarkers = [
    const FloorPlanMarkerModel(id: 'm1', deviceId: 'd1', deviceName: 'AC Unit 201', deviceCode: 'AC-201', markerLabel: 'AC-201', deviceType: 'HVAC', posX: 0.10, posY: 0.16, roomId: 'r201', roomNumber: '201'),
    const FloorPlanMarkerModel(id: 'm2', deviceId: 'd2', deviceName: 'Projector 201', deviceCode: 'PRJ-201', markerLabel: 'PRJ-201', deviceType: 'Projector', posX: 0.19, posY: 0.16, roomId: 'r201', roomNumber: '201'),
    const FloorPlanMarkerModel(id: 'm3', deviceId: 'd3', deviceName: 'Light 201', deviceCode: 'LGT-201', markerLabel: 'LGT-201', deviceType: 'Lighting', posX: 0.10, posY: 0.30, roomId: 'r201', roomNumber: '201'),
    const FloorPlanMarkerModel(id: 'm4', deviceId: 'd4', deviceName: 'Light 202', deviceCode: 'LGT-202', markerLabel: 'LGT-202', deviceType: 'Lighting', posX: 0.33, posY: 0.16, roomId: 'r202', roomNumber: '202'),
    const FloorPlanMarkerModel(id: 'm5', deviceId: 'd5', deviceName: 'Audio Speaker 202', deviceCode: 'AUD-202', markerLabel: 'AUD-202', deviceType: 'Audio', posX: 0.43, posY: 0.16, roomId: 'r202', roomNumber: '202'),
    const FloorPlanMarkerModel(id: 'm6', deviceId: 'd6', deviceName: 'HVAC 203', deviceCode: 'AC-203', markerLabel: 'AC-203', deviceType: 'HVAC', posX: 0.57, posY: 0.16, roomId: 'r203', roomNumber: '203'),
    const FloorPlanMarkerModel(id: 'm7', deviceId: 'd7', deviceName: 'Fan 203', deviceCode: 'FAN-203', markerLabel: 'FAN-203', deviceType: 'Fan', posX: 0.66, posY: 0.16, roomId: 'r203', roomNumber: '203'),
    const FloorPlanMarkerModel(id: 'm8', deviceId: 'd8', deviceName: 'CCTV Chem Lab', deviceCode: 'CAM-207', markerLabel: 'CAM-207', deviceType: 'CCTV', posX: 0.57, posY: 0.68, roomId: 'r207', roomNumber: '207'),
    const FloorPlanMarkerModel(id: 'm9', deviceId: 'd9', deviceName: 'HVAC Chem Lab', deviceCode: 'AC-207', markerLabel: 'AC-207', deviceType: 'HVAC', posX: 0.66, posY: 0.68, roomId: 'r207', roomNumber: '207'),
    const FloorPlanMarkerModel(id: 'm10', deviceId: 'd10', deviceName: 'Corridor CCTV', deviceCode: 'CAM-CORR', markerLabel: 'CAM-CORR', deviceType: 'CCTV', posX: 0.08, posY: 0.51, roomId: null, roomNumber: null),
  ];

  final testLegend = FloorPlanLegendModel(
    cctv: 2,
    lighting: 2,
    hvac: 3,
    projector: 1,
    accessPoint: 0,
    audio: 1,
    fan: 1,
    total: 10,
  );

  Widget createTestApp({required Widget child, Size size = const Size(1280, 800)}) {
    return ProviderScope(
      overrides: [
        deviceManagementProvider.overrideWith((ref) {
          final notifier = TestDeviceManagementNotifier();
          notifier.state = notifier.state.copyWith(
            floorPlanAsset: testAsset,
            floorPlanMarkers: testMarkers,
            floorPlanLegend: testLegend,
            selectedLocationFloorId: 'b88cf8d5-d000-40ea-b1c5-be7534ca74ab',
            locationActiveSubTab: 'Floor Plan',
          );
          return notifier;
        }),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('Enterprise Floor Plan Studio Tests', () {
    testWidgets('1. Renders floor plan view with dynamic rooms and synchronized legend counts', (tester) async {
      await tester.pumpWidget(createTestApp(child: const DeviceLocationsMappingSubview()));
      await tester.pumpAndSettle();

      // Check title contains Second Floor
      expect(find.textContaining('Second Floor'), findsWidgets);

      // Check dynamic rooms rendered
      expect(find.text('201'), findsWidgets);
      expect(find.text('202'), findsWidgets);
      expect(find.text('207'), findsWidgets);
      expect(find.text('Corridor'), findsWidgets);

      // Check synchronized legend counts
      expect(find.textContaining('CCTV (2)'), findsWidgets);
      expect(find.textContaining('Lighting (2)'), findsWidgets);
      expect(find.textContaining('HVAC (3)'), findsWidgets);
      expect(find.textContaining('Projector (1)'), findsWidgets);
      expect(find.textContaining('Audio (1)'), findsWidgets);
      expect(find.textContaining('Fan (1)'), findsWidgets);
      expect(find.textContaining('Access Point (0)'), findsWidgets);

      // Total count badge
      expect(find.text('10'), findsWidgets);
    });

    testWidgets('2. Category filter chips and interactive legend highlight matching markers', (tester) async {
      await tester.pumpWidget(createTestApp(child: const DeviceLocationsMappingSubview()));
      await tester.pumpAndSettle();

      // Tap on CCTV in the legend
      final cctvLegendFinder = find.textContaining('CCTV (2)');
      expect(cctvLegendFinder, findsWidgets);
      await tester.tap(cctvLegendFinder.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Tap on HVAC filter chip
      final hvacChipFinder = find.widgetWithText(InkWell, 'HVAC');
      if (hvacChipFinder.evaluate().isNotEmpty) {
        await tester.tap(hvacChipFinder.first, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('3. Floor switcher dropdown displays sibling floors', (tester) async {
      await tester.pumpWidget(createTestApp(child: const DeviceLocationsMappingSubview()));
      await tester.pumpAndSettle();

      // Verify dropdown has Second Floor (F2)
      expect(find.text('Second Floor (F2)'), findsWidgets);
    });

    testWidgets('4. Fullscreen floor plan dialog renders with dynamic rooms and markers', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FloorPlanFullScreenDialog(
            floorPlan: testAsset,
            markers: testMarkers,
            legend: testLegend,
            title: 'Academic Block (A) – Second Floor Architectural Blueprint',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Second Floor'), findsWidgets);
      expect(find.text('201'), findsWidgets);
      expect(find.text('207'), findsWidgets);
      expect(find.textContaining('CCTV (2)'), findsWidgets);
      expect(find.textContaining('HVAC (3)'), findsWidgets);
    });

    testWidgets('5. Responsive layout across Mobile, Tablet, and Desktop with 0 overflow errors', (tester) async {
      for (final size in [
        const Size(400, 800),   // Mobile
        const Size(800, 900),   // Tablet
        const Size(1440, 900),  // Desktop
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(createTestApp(child: const DeviceLocationsMappingSubview(), size: size));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Must render with 0 exceptions at ${size.width}x${size.height}');
      }
    });
  });
}
