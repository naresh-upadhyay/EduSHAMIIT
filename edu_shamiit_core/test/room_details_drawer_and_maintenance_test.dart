import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/models/campus_models.dart';
import 'package:edu_shamiit_core/screens/campus/providers/campus_provider.dart';
import 'package:edu_shamiit_core/screens/campus/providers/space_booking_provider.dart';
import 'package:edu_shamiit_core/screens/campus/services/campus_api_service.dart';
import 'package:edu_shamiit_core/screens/campus/services/space_booking_api_service.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/dialogs/room_details_drawer.dart';

void main() {
  group('Room Details Drawer & Maintenance Actions Test Suite', () {
    final sampleBuilding = BuildingModel(
      id: 'bld-1',
      schoolId: 'sch-1',
      name: 'Academic Block A',
      code: 'B1',
      totalFloors: 4,
      totalRooms: 40,
      totalCapacity: 1600,
      status: 'Active',
    );

    final sampleRoom = RoomModel(
      id: 'room-1',
      schoolId: 'sch-1',
      buildingId: 'bld-1',
      floorId: 'fl-1',
      floorName: 'Ground Floor',
      roomNumber: '101',
      roomCode: 'B1-101',
      name: 'Mathematics Smart Lab',
      roomType: 'Classroom',
      maxCapacity: 50,
      currentOccupancy: 45,
      seatingCapacity: 50,
      recommendedCapacity: 45,
      area: 850.0,
      areaUnit: 'sq ft',
      length: 30.0,
      width: 28.0,
      operationalStatus: 'Available',
      assignmentStatus: 'Assigned',
      responsibleDepartment: 'Mathematics Department',
      responsiblePersonName: 'Dr. Srinivasa',
      liftProximity: 'Nearby (10m)',
      emergencyExitProximity: 'Direct Access',
      isDifferentlyAbledAccessible: true,
    );

    testWidgets('RoomDetailsDrawer renders modern capacity meter, maintenance section and no Allocate button', (tester) async {
      bool editTapped = false;
      bool maintenanceTapped = false;

      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusProvider.overrideWith((ref) => CampusNotifier(CampusApiService.instance)),
            spaceBookingProvider.overrideWith((ref) => SpaceBookingNotifier(SpaceBookingApiService.instance)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RoomDetailsDrawer(
                room: sampleRoom,
                building: sampleBuilding,
                onClose: () {},
                onEdit: () => editTapped = true,
                onManageEquipment: () {},
                onRaiseMaintenance: () => maintenanceTapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify Header contains room number and name
      expect(find.text('101'), findsOneWidget);
      expect(find.text('Mathematics Smart Lab'), findsOneWidget);

      // 2. Verify Capacity & Real-Time Occupancy card
      expect(find.text('Capacity & Real-Time Occupancy'), findsOneWidget);
      expect(find.textContaining('Occupied: 45 students'), findsOneWidget);
      expect(find.textContaining('Max Capacity: 50 seats'), findsOneWidget);
      expect(find.text('90.0% Full'), findsOneWidget);

      // 3. Verify Maintenance card and buttons
      expect(find.text('Maintenance & Health Status'), findsOneWidget);
      expect(find.text('Raise Maintenance'), findsOneWidget);
      expect(find.text('Edit Room'), findsOneWidget);

      // 4. Verify OLD 'Allocate' button is COMPLETELY REMOVED
      expect(find.text('Allocate'), findsNothing);

      // 5. Test Tap "Raise Maintenance"
      await tester.tap(find.text('Raise Maintenance'));
      await tester.pump();
      expect(maintenanceTapped, isTrue);

      // 6. Test Tap "Edit Room"
      await tester.tap(find.text('Edit Room'));
      await tester.pump();
      expect(editTapped, isTrue);
    });

    testWidgets('RoomDetailsDrawer updates live in real-time when room prop changes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final updatedRoom = RoomModel(
        id: 'room-1',
        schoolId: 'sch-1',
        buildingId: 'bld-1',
        floorId: 'fl-1',
        floorName: 'Ground Floor',
        roomNumber: '101',
        roomCode: 'B1-101',
        name: 'Advanced Robotics Lab',
        roomType: 'Classroom',
        maxCapacity: 60,
        currentOccupancy: 30,
        seatingCapacity: 60,
        recommendedCapacity: 50,
        area: 900.0,
        areaUnit: 'sq ft',
        length: 30.0,
        width: 30.0,
        operationalStatus: 'Available',
        assignmentStatus: 'Assigned',
        responsibleDepartment: 'Mathematics Department',
        responsiblePersonName: 'Dr. Srinivasa',
        liftProximity: 'Nearby (10m)',
        emergencyExitProximity: 'Direct Access',
        isDifferentlyAbledAccessible: true,
      );

      Widget buildWidget(RoomModel room) {
        return ProviderScope(
          overrides: [
            campusProvider.overrideWith((ref) => CampusNotifier(CampusApiService.instance)),
            spaceBookingProvider.overrideWith((ref) => SpaceBookingNotifier(SpaceBookingApiService.instance)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RoomDetailsDrawer(
                room: room,
                building: sampleBuilding,
                onClose: () {},
                onEdit: () {},
                onManageEquipment: () {},
                onRaiseMaintenance: () {},
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWidget(sampleRoom));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Mathematics Smart Lab'), findsOneWidget);
      expect(find.text('90.0% Full'), findsOneWidget);

      // Now re-pump with updated room object (simulating real-time save / reload)
      await tester.pumpWidget(buildWidget(updatedRoom));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Advanced Robotics Lab'), findsOneWidget);
      expect(find.text('50.0% Full'), findsOneWidget);
      expect(find.textContaining('Occupied: 30 students'), findsOneWidget);
      expect(find.textContaining('Max Capacity: 60 seats'), findsOneWidget);
    });
  });
}
