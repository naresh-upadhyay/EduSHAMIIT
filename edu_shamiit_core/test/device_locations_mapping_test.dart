import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/services/device_management_api_service.dart';
import 'package:edu_shamiit_core/screens/campus/providers/device_management_provider.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_locations_mapping_subview.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/dialogs/map_device_location_dialog.dart';

class TestLocationsDeviceManagementNotifier extends DeviceManagementNotifier {
  TestLocationsDeviceManagementNotifier(DeviceManagementState initial)
      : super(DeviceManagementApiService.instance) {
    state = initial;
  }

  @override
  Future<void> loadLocationsMappingData() async {}

  @override
  Future<void> selectLocationFloor({required String floorId, String? buildingId, String? roomId}) async {}
}

void main() {
  group('Locations & Mapping - Models Unit Tests', () {
    test('LocationsMappingKpis deserialization matching exact screenshot metrics', () {
      final json = {
        'buildings': 6,
        'floors': 42,
        'rooms': 276,
        'total_devices': 8742,
        'mapped_devices': 8296,
        'mapped_pct': 95.0,
        'unmapped_devices': 446,
        'unmapped_pct': 5.0,
        'locations_with_devices': 268,
        'coverage_pct': 97.1,
      };

      final kpis = LocationsMappingKpis.fromJson(json);
      expect(kpis.buildings, 6);
      expect(kpis.floors, 42);
      expect(kpis.rooms, 276);
      expect(kpis.mappedDevices, 8296);
      expect(kpis.mappedPct, 95.0);
      expect(kpis.unmappedDevices, 446);
      expect(kpis.unmappedPct, 5.0);
      expect(kpis.locationsWithDevices, 268);
      expect(kpis.coveragePct, 97.1);
    });

    test('LocationHierarchyNode deserialization', () {
      final json = {
        'id': 'school-1',
        'name': 'Greenwood High School',
        'type': 'campus',
        'children': [
          {
            'id': 'bldg-1',
            'name': 'Academic Block (A)',
            'code': 'B1',
            'type': 'building',
            'children': [
              {
                'id': 'floor-1',
                'name': 'First Floor',
                'code': '1F',
                'level': 1,
                'device_count': 14,
                'room_count': 14,
                'type': 'floor',
              }
            ]
          }
        ]
      };

      final root = LocationHierarchyNode.fromJson(json);
      expect(root.name, 'Greenwood High School');
      expect(root.children.length, 1);
      final bldg = root.children.first;
      expect(bldg.name, 'Academic Block (A)');
      expect(bldg.children.first.deviceCount, 14);
    });

    test('DeviceLocationMappingItem deserialization', () {
      final json = {
        'id': 'dev-1',
        'device_name': 'CAM-A1-101',
        'device_code': 'CAM-A1-101',
        'device_type': 'CCTV',
        'room_space': 'A1-101 (Classroom)',
        'location_path': 'Academic Block (A) > 1F',
        'mapping_status': 'Mapped',
        'is_online': true,
        'power_state': true,
      };

      final item = DeviceLocationMappingItem.fromJson(json);
      expect(item.deviceCode, 'CAM-A1-101');
      expect(item.deviceType, 'CCTV');
      expect(item.roomSpace, 'A1-101 (Classroom)');
      expect(item.mappingStatus, 'Mapped');
    });

    test('FloorPlanAsset and Markers deserialization', () {
      final json = {
        'id': 'plan-1',
        'title': 'Academic Block (A) – First Floor Architectural Plan',
        'dimensions_width': 1200.0,
        'dimensions_height': 750.0,
        'rooms_layout': [
          {'room_id': 'r1', 'code': 'A1-101', 'name': 'Classroom', 'x': 0.04, 'y': 0.08, 'w': 0.21, 'h': 0.36}
        ]
      };

      final plan = FloorPlanAssetModel.fromJson(json);
      expect(plan.title, contains('Academic Block (A)'));
      expect(plan.roomsLayout.length, 1);
      expect(plan.roomsLayout.first.code, 'A1-101');

      final markerJson = {
        'id': 'm1',
        'device_id': 'd1',
        'device_name': 'CAM-A1-101',
        'device_code': 'CAM-A1-101',
        'marker_label': 'CAM-A1-101',
        'device_type': 'CCTV',
        'pos_x': 0.11,
        'pos_y': 0.18,
        'is_online': true,
      };

      final marker = FloorPlanMarkerModel.fromJson(markerJson);
      expect(marker.markerLabel, 'CAM-A1-101');
      expect(marker.posX, 0.11);
      expect(marker.posY, 0.18);
    });
  });

  group('DeviceLocationsMappingSubview - UI Rendering Tests', () {
    late DeviceManagementState testState;

    setUp(() {
      testState = const DeviceManagementState(
        locationsKpis: LocationsMappingKpis(
          buildings: 6,
          floors: 42,
          rooms: 276,
          totalDevices: 8742,
          mappedDevices: 8296,
          mappedPct: 95.0,
          unmappedDevices: 446,
          unmappedPct: 5.0,
          locationsWithDevices: 268,
          coveragePct: 97.1,
        ),
        locationsHierarchy: LocationHierarchyNode(
          id: 'school-1',
          name: 'Greenwood High School',
          type: 'campus',
          children: [
            LocationHierarchyNode(
              id: 'bldg-admin',
              name: 'Admin Block',
              code: 'B5',
              type: 'building',
              children: [
                LocationHierarchyNode(id: 'f-adm-0', name: 'Ground Floor', roomCount: 8, deviceCount: 8),
                LocationHierarchyNode(id: 'f-adm-1', name: 'First Floor', roomCount: 6, deviceCount: 6),
              ],
            ),
            LocationHierarchyNode(
              id: '2af829b6-81a4-469a-a91a-71f2bd390fc4',
              name: 'Academic Block (A)',
              code: 'B1',
              type: 'building',
              children: [
                LocationHierarchyNode(id: 'f-acad-0', name: 'Ground Floor', roomCount: 12, deviceCount: 12),
                LocationHierarchyNode(id: 'b8b4c4de-11e1-4d42-b4ad-27b86c8c823a', name: 'First Floor', roomCount: 14, deviceCount: 14),
                LocationHierarchyNode(id: 'f-acad-2', name: 'Second Floor', roomCount: 10, deviceCount: 10),
              ],
            ),
            LocationHierarchyNode(id: 'bldg-acad-b', name: 'Academic Block (B)', code: 'B2', type: 'building'),
            LocationHierarchyNode(id: 'bldg-lab', name: 'Laboratories Block', code: 'B7', type: 'building'),
            LocationHierarchyNode(id: 'bldg-lib', name: 'Library Block', code: 'B3', type: 'building'),
            LocationHierarchyNode(id: 'bldg-aud', name: 'Auditorium Block', code: 'B4', type: 'building'),
            LocationHierarchyNode(id: 'bldg-sport', name: 'Sports Complex', code: 'B6', type: 'building'),
          ],
        ),
        selectedLocationFloorId: 'b8b4c4de-11e1-4d42-b4ad-27b86c8c823a',
        selectedLocationDetails: LocationDetailsModel(
          id: 'b8b4c4de-11e1-4d42-b4ad-27b86c8c823a',
          title: 'Academic Block (A) – First Floor',
          buildingName: 'Academic Block (A)',
          locationType: 'Floor',
          parentLocation: 'Academic Block (A)',
          floorNo: 1,
          totalRooms: 14,
          mappedDevices: 132,
          unmappedDevices: 4,
          groupsAssigned: 8,
          profilesInUse: 5,
          coveragePct: 97.1,
          rooms: [
            LocationRoomItem(id: 'r1', roomNumber: 'A1-101', name: 'Classroom', roomType: 'Classroom'),
            LocationRoomItem(id: 'r2', roomNumber: 'A1-102', name: 'Classroom', roomType: 'Classroom'),
          ],
          assignedGroups: [
            LocationAssignedGroupItem(id: 'g1', name: 'Classroom Lighting - Block A', code: 'GRP-LGT', deviceCount: 96),
          ],
        ),
        locationMappedDevices: [
          DeviceLocationMappingItem(id: 'd1', deviceName: 'CAM-A1-101', deviceCode: 'CAM-A1-101', deviceType: 'CCTV', roomSpace: 'A1-101 (Classroom)', locationPath: 'Academic Block (A) > 1F', mappingStatus: 'Mapped'),
          DeviceLocationMappingItem(id: 'd2', deviceName: 'LIGHT-A1-101', deviceCode: 'LIGHT-A1-101', deviceType: 'Lighting', roomSpace: 'A1-101 (Classroom)', locationPath: 'Academic Block (A) > 1F', mappingStatus: 'Mapped'),
          DeviceLocationMappingItem(id: 'd3', deviceName: 'AC-A1-101', deviceCode: 'AC-A1-101', deviceType: 'HVAC (AC)', roomSpace: 'A1-101 (Classroom)', locationPath: 'Academic Block (A) > 1F', mappingStatus: 'Mapped'),
          DeviceLocationMappingItem(id: 'd4', deviceName: 'PRJ-A1-102', deviceCode: 'PRJ-A1-102', deviceType: 'Projector', roomSpace: 'A1-102 (Classroom)', locationPath: 'Academic Block (A) > 1F', mappingStatus: 'Mapped'),
          DeviceLocationMappingItem(id: 'd5', deviceName: 'AP-A1-1F-01', deviceCode: 'AP-A1-1F-01', deviceType: 'Access Point', roomSpace: 'A1-Common Area', locationPath: 'Academic Block (A) > 1F', mappingStatus: 'Mapped'),
          DeviceLocationMappingItem(id: 'd6', deviceName: 'SPK-A1-1F-01', deviceCode: 'SPK-A1-1F-01', deviceType: 'Audio / Speaker', roomSpace: 'A1-Common Area', locationPath: 'Academic Block (A) > 1F', mappingStatus: 'Mapped'),
        ],
        locationDevicesTotal: 14,
        floorPlanLegend: FloorPlanLegendModel(
          cctv: 2,
          lighting: 6,
          hvac: 3,
          projector: 1,
          accessPoint: 1,
          audio: 1,
        ),
        floorPlanMarkers: [
          FloorPlanMarkerModel(id: 'm1', deviceId: 'd1', deviceName: 'CAM-A1-101', deviceCode: 'CAM-A1-101', markerLabel: 'CAM-A1-101', deviceType: 'CCTV', posX: 0.11, posY: 0.18),
          FloorPlanMarkerModel(id: 'm2', deviceId: 'd2', deviceName: 'LIGHT-A1-101', deviceCode: 'LIGHT-A1-101', markerLabel: 'LIGHT-A1-101', deviceType: 'Lighting', posX: 0.15, posY: 0.28),
        ],
        devices: [
          DeviceItemModel(
            id: 'c1c00000-0000-0000-0000-000000000001',
            deviceName: 'Classroom 101 CCTV Bullet Cam',
            deviceCode: 'CAM-A1-101',
            typeName: 'CCTV Camera',
            typeCode: 'cctv_camera',
            typeIcon: 'videocam',
            locationDisplay: 'Academic Block (A) > First Floor > A1-101',
            isOnline: true,
            powerState: true,
            currentState: {'power': true},
            operationalStatus: 'active',
          ),
        ],
      );
    });

    testWidgets('Renders all Top KPI cards with exact counts and percentages', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) => TestLocationsDeviceManagementNotifier(testState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceLocationsMappingSubview(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify KPI Header
      expect(find.text('Device Management & Control'), findsOneWidget);
      expect(find.text('Buildings'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('Floors'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Rooms / Spaces'), findsOneWidget);
      expect(find.text('276'), findsOneWidget);
      expect(find.text('8,296 (95.0%)'), findsOneWidget);
      expect(find.text('446 (5.0%)'), findsOneWidget);
      expect(find.text('268 (97.1%)'), findsOneWidget);
    });

    testWidgets('Renders Sub-Tabs Bar and Global Action Buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) => TestLocationsDeviceManagementNotifier(testState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceLocationsMappingSubview(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Location Hierarchy'), findsOneWidget);
      expect(find.text('Device Mapping'), findsOneWidget);
      expect(find.text('Location Map'), findsOneWidget);
      expect(find.text('Floor Plan'), findsOneWidget);
      expect(find.text('Coverage & Utilization'), findsOneWidget);
      expect(find.text('Add Location'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
    });

    testWidgets('Renders Left Panel Campus Location Hierarchy Tree with Greenwood High School root', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) => TestLocationsDeviceManagementNotifier(testState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceLocationsMappingSubview(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Campus Location Hierarchy'), findsOneWidget);
      expect(find.text('Greenwood High School'), findsOneWidget);
      expect(find.text('Admin Block'), findsOneWidget);
      expect(find.text('Academic Block (A)'), findsWidgets);
      expect(find.text('Laboratories Block'), findsOneWidget);
    });

    testWidgets('Renders Center Device Mapping Table with exact matching device rows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) => TestLocationsDeviceManagementNotifier(testState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceLocationsMappingSubview(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify row device codes
      expect(find.text('CAM-A1-101'), findsWidgets);
      expect(find.text('LIGHT-A1-101'), findsWidgets);
      expect(find.text('AC-A1-101'), findsWidgets);
      expect(find.text('PRJ-A1-102'), findsWidgets);
      expect(find.text('AP-A1-1F-01'), findsWidgets);
      expect(find.text('SPK-A1-1F-01'), findsWidgets);

      // Verify types
      expect(find.text('CCTV'), findsWidgets);
      expect(find.text('Lighting'), findsWidgets);
      expect(find.text('HVAC (AC)'), findsWidgets);
      expect(find.text('Projector'), findsWidgets);
      expect(find.text('Access Point'), findsWidgets);
      expect(find.text('Audio / Speaker'), findsWidgets);

      // Verify pagination text
      expect(find.text('Showing 1 – 6 of 14 devices (First Floor)'), findsOneWidget);
    });

    testWidgets('Renders Floor Plan view with room architecture and Legend counts', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) => TestLocationsDeviceManagementNotifier(testState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceLocationsMappingSubview(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Floor Plan View'), findsOneWidget);
      expect(find.text('Open Full Plan'), findsOneWidget);
      expect(find.text('Legend'), findsOneWidget);
      expect(find.text('CCTV (2)'), findsOneWidget);
      expect(find.text('Lighting (6)'), findsOneWidget);
      expect(find.text('HVAC (3)'), findsOneWidget);
      expect(find.text('Projector (1)'), findsOneWidget);
      expect(find.text('Access Point (1)'), findsOneWidget);
      expect(find.text('Audio (1)'), findsOneWidget);
    });

    testWidgets('Renders Right Panel Location Details with Specs & Quick Actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) => TestLocationsDeviceManagementNotifier(testState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceLocationsMappingSubview(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Location Details'), findsOneWidget);
      expect(find.text('Total Rooms / Spaces'), findsOneWidget);
      expect(find.text('14'), findsWidgets);
      expect(find.text('Mapped Devices'), findsWidgets);
      expect(find.text('132'), findsOneWidget);
      expect(find.text('Unmapped Devices'), findsWidgets);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Groups Assigned'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('97.1%'), findsWidgets);

      // Quick Actions
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Map Devices'), findsWidgets);
      expect(find.text('Unmap Devices'), findsOneWidget);
      expect(find.text('View Floor Plan'), findsOneWidget);
      expect(find.text('+ Add Room / Space'), findsOneWidget);
    });

    testWidgets('Responsive Layout test across Tablet and Laptop viewports without RenderFlex overflow', (tester) async {
      // 1. Laptop / Desktop
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) => TestLocationsDeviceManagementNotifier(testState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceLocationsMappingSubview(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 2. Tablet Viewport
      await tester.binding.setSurfaceSize(const Size(800, 1024));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) => TestLocationsDeviceManagementNotifier(testState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceLocationsMappingSubview(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('MapDeviceLocationDialog opens and renders controls', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) => TestLocationsDeviceManagementNotifier(testState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MapDeviceLocationDialog(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Map Campus Device'), findsOneWidget);
      expect(find.text('Select Device'), findsOneWidget);
      expect(find.text('Mount Type'), findsOneWidget);
      expect(find.text('Confirm Mapping'), findsOneWidget);
    });

    testWidgets('SubTab Location Map renders dedicated campus building cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      final mapState = testState.copyWith(locationActiveSubTab: 'Location Map');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) => TestLocationsDeviceManagementNotifier(mapState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceLocationsMappingSubview(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Campus Location Map & Building Facilities'), findsOneWidget);
      expect(find.text('Academic Block (A)'), findsWidgets);
      expect(find.text('Admin Block'), findsWidgets);
    });

    testWidgets('SubTab Coverage & Utilization renders dedicated coverage cards and density table', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      final covState = testState.copyWith(locationActiveSubTab: 'Coverage & Utilization');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceManagementProvider.overrideWith((ref) => TestLocationsDeviceManagementNotifier(covState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DeviceLocationsMappingSubview(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Space Coverage & Device Utilization Analytics'), findsOneWidget);
      expect(find.text('Wi-Fi Coverage'), findsOneWidget);
      expect(find.text('Security Reach'), findsOneWidget);
      expect(find.text('Automation Rate'), findsOneWidget);
      expect(find.text('Room-by-Room Device Density & Utilization Index'), findsOneWidget);
    });
  });
}
