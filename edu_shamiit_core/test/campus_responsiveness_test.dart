import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/campus_header_bar.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/campus_kpi_cards.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/campus_tabs_bar.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/buildings/building_center_panel.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/dialogs/room_equipment_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/dialogs/add_edit_room_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/dialogs/add_edit_building_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/dialogs/add_edit_floor_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/models/campus_models.dart';

void main() {
  group('Campus Module Device Responsiveness Tests (Mobile, Tablet, Desktop)', () {
    const sampleBuilding = BuildingModel(
      id: 'bld-001',
      schoolId: 'sch-001',
      name: 'Academic Block',
      code: 'B1',
      buildingType: 'Academic',
      totalFloors: 5,
      totalRooms: 42,
      totalCapacity: 2100,
      currentOccupancy: 1950,
      occupancyRate: 92.9,
    );

    const sampleFloor = BuildingFloorModel(
      id: 'flr-001',
      schoolId: 'sch-001',
      buildingId: 'bld-001',
      name: 'Ground Floor',
      floorCode: 'G',
      floorLevel: 0,
      totalRooms: 8,
      roomTypesSummary: 'Classroom (4), Lab (2), Office (2)',
      capacity: 400,
      occupancy: 368,
      occupancyPercentage: 92.0,
    );

    const sampleRoom = RoomModel(
      id: 'rm-101',
      schoolId: 'sch-001',
      buildingId: 'bld-001',
      floorId: 'flr-001',
      name: 'Grade 2 - Section A',
      roomNumber: '101',
      roomCode: 'RM-101',
      roomType: 'Classroom',
      maxCapacity: 40,
      currentOccupancy: 38,
      operationalStatus: 'Available',
      assignmentStatus: 'Assigned',
    );

    const sampleKpis = CampusKpis(
      totalBuildings: 8,
      totalFloors: 38,
      totalRooms: 156,
      totalCapacity: 7560,
      occupiedRooms: 142,
      occupiedCapacity: 6842,
      availableRooms: 14,
      availableCapacity: 718,
      occupancyRate: 90.5,
      maintenanceRooms: 3,
      totalEquipment: 420,
      equipmentNotWorking: 12,
    );

    testWidgets('CampusHeaderBar renders without overflow on mobile (360px), tablet (768px), and desktop (1280px)', (tester) async {
      for (final width in [360.0, 768.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CampusHeaderBar(
                onAddBuilding: () {},
                onBulkImport: () {},
                onExport: () {},
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Campus Management'), findsOneWidget);
      }
    });

    testWidgets('CampusKpiCards renders without overflow on mobile (360px), tablet (768px), and desktop (1280px)', (tester) async {
      for (final width in [360.0, 768.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CampusKpiCards(kpis: sampleKpis),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('CampusTabsBar renders horizontally scrollable without overflow on mobile (360px)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampusTabsBar(
              activeIndex: 0,
              onTabSelected: (_) {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Buildings & Rooms'), findsOneWidget);
    });

    testWidgets('RoomEquipmentDialog renders on mobile (360px) without yellow/black hazard stripe overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoomEquipmentDialog(
              room: sampleRoom,
              onUpdated: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Facilities & Equipment: Room 101'), findsOneWidget);
    });

    testWidgets('AddEditRoomDialog renders on mobile (360px) without yellow/black hazard stripe overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddEditRoomDialog(
              building: sampleBuilding,
              floors: const [sampleFloor],
              onSaved: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Add New Room / Space'), findsOneWidget);
    });

    testWidgets('AddEditBuildingDialog and AddEditFloorDialog render on mobile (360px) without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddEditBuildingDialog(onSaved: () {}),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddEditFloorDialog(
              buildingId: sampleBuilding.id,
              onSaved: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('BuildingCenterPanel renders on mobile (360px) and desktop (1280px) without overflow', (tester) async {
      for (final width in [360.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BuildingCenterPanel(
                building: sampleBuilding,
                activeSubTab: 0,
                onSubTabChanged: (_) {},
                onEditBuilding: () {},
                onArchiveBuilding: () {},
                onDeleteBuilding: () {},
                floors: const [sampleFloor],
                onAddFloor: () {},
                onEditFloor: (_) {},
                onDeleteFloor: (_) {},
                onViewRoomsOnFloor: (_) {},
                rooms: const [sampleRoom],
                roomsViewMode: 0,
                onRoomsViewModeChanged: (_) {},
                roomSearchQuery: '',
                onRoomSearch: (_) {},
                onFilterFloor: (_) {},
                onFilterRoomType: (_) {},
                onFilterStatus: (_) {},
                onClearRoomFilters: () {},
                onAddRoom: () {},
                onBulkCreateRooms: () {},
                onInspectRoom: (_) {},
                onEditRoom: (_) {},
                onManageEquipment: (_) {},
                onDeleteRoom: (_) {},
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      }
    });
  });
}
