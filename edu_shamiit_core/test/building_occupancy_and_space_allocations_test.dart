import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/models/campus_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/buildings/occupancy_subtab_view.dart';

void main() {
  group('Building Occupancy & Space Allocations Test Suite', () {
    late BuildingModel testBuilding;
    late List<BuildingOccupancyModel> sampleAllocations;

    setUp(() {
      testBuilding = const BuildingModel(
        id: '05ca0d68-e33b-43ee-ac72-b6ebe1e7332d',
        schoolId: '11111111-1111-1111-1111-111111111111',
        name: 'Academic Block (A)',
        code: 'B1',
        buildingType: 'Academic',
        totalFloors: 5,
        totalRooms: 52,
        totalCapacity: 2470,
        currentOccupancy: 1578,
        status: 'Active',
      );

      // Create 34 sample allocations matching B1 Academic Block (A)
      sampleAllocations = List.generate(34, (index) {
        final roomNum = (201 + index).toString();
        final isLab = index == 6 || index == 14; // 207, 307 Labs
        final isAdmin = index == 7 || index == 15; // 208, 308 Staff Rooms
        final isGeneral = index == 33;

        String mod = 'Academics';
        String purpose = 'Classroom & Lecture Instruction';
        String name =
            'Grade ${(4 + (index ~/ 6))} - Section ${String.fromCharCode(65 + (index % 3))}';
        String incharge = 'Academic Coordinator';
        // Exact sum across 34 allocations = 1578
        // 30 rooms * 47 = 1410, 2 labs * 54 = 108, 2 staff rooms * 30 = 60 => 1578
        int occ = 47;
        if (isLab) {
          mod = 'Academics';
          name = 'Chemistry Laboratory Beta';
          purpose = 'Laboratory & Practical Sessions';
          incharge = 'Lab Incharge';
          occ = 54;
        } else if (isAdmin) {
          mod = 'Administration';
          name = 'Staff Room - Wing ${index == 7 ? 2 : 3}';
          purpose = 'Staff & Administrative Workstations';
          incharge = 'Department Head';
          occ = 30;
        } else if (isGeneral) {
          mod = 'General';
          name = 'AV Seminar Hall';
          purpose = 'Seminars, Conferences & Events';
          incharge = 'Facility Manager';
          occ = 47;
        }

        return BuildingOccupancyModel(
          id: 'alloc-$index',
          roomId: 'room-$index',
          roomNumber: roomNum,
          roomName: name,
          floorName: 'Floor ${2 + (index ~/ 10)}',
          referenceModule: mod,
          referenceName: name,
          assignmentPurpose: purpose,
          assignedToName: incharge,
          startDate: '2026-01-10',
          status: 'Active',
          maxCapacity: 50,
          currentOccupancy: occ,
        );
      });
    });

    test('BuildingOccupancyModel.fromJson parses fields correctly', () {
      final json = {
        'id': 'alloc-101',
        'room_id': 'room-101',
        'room_number': '201',
        'room_name': 'Grade 4 - Section A',
        'floor_name': 'Second Floor',
        'reference_module': 'Academics',
        'reference_name': 'Grade 4 - Section A',
        'assignment_purpose': 'Classroom & Lecture Instruction',
        'start_date': '2026-01-15',
        'end_date': null,
        'assigned_to_name': 'Mrs. Sarah Connor',
        'status': 'Active',
        'notes': 'Grade 4 Class Section Allocation',
        'max_capacity': 50,
        'current_occupancy': 48,
        'created_at': '2026-01-15T08:00:00Z',
      };

      final model = BuildingOccupancyModel.fromJson(json);
      expect(model.id, 'alloc-101');
      expect(model.roomId, 'room-101');
      expect(model.roomNumber, '201');
      expect(model.roomName, 'Grade 4 - Section A');
      expect(model.floorName, 'Second Floor');
      expect(model.referenceModule, 'Academics');
      expect(model.referenceName, 'Grade 4 - Section A');
      expect(model.assignmentPurpose, 'Classroom & Lecture Instruction');
      expect(model.assignedToName, 'Mrs. Sarah Connor');
      expect(model.status, 'Active');
      expect(model.maxCapacity, 50);
      expect(model.currentOccupancy, 48);
    });

    testWidgets(
        'OccupancySubtabView renders KPIs and allocations grid with perfect match',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(2000, 900));

      bool addClicked = false;
      BuildingOccupancyModel? editedItem;
      BuildingOccupancyModel? deletedItem;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  height: 900,
                  child: OccupancySubtabView(
                    building: testBuilding,
                    occupancyList: sampleAllocations,
                    rooms: const [],
                    isLoading: false,
                    onAddOccupancy: () => addClicked = true,
                    onEditOccupancy: (item) => editedItem = item,
                    onDeleteOccupancy: (item) => deletedItem = item,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Space Occupancy title with Building Code
      expect(find.text('Space Occupancy & Class Allocations'), findsOneWidget);
      expect(find.text('B1'), findsOneWidget);

      // 2. Verify Dynamic Space Booking KPI Metric Tiles
      expect(find.text('Building Capacity'), findsOneWidget);
      expect(find.text('Occupied Right Now'), findsOneWidget);
      expect(find.text('Available Right Now'), findsOneWidget);
      expect(find.text('Sessions Today'), findsOneWidget);
      expect(find.text('Live Utilization'), findsOneWidget);

      // 3. Verify that the grid is NOT empty and shows allocations
      expect(find.text('No space allocations found'), findsNothing);
      expect(find.byType(DataTable), findsOneWidget);

      // 4. Test search filter by room number '201'
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, '201');
      await tester.pumpAndSettle();

      // 5. Test Add Occupancy button click
      final addBtn = find.text('Assign Class / Section');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pump();
      expect(addClicked, isTrue);
    });

    testWidgets(
        'OccupancySubtabView shows empty message only when truly no allocations',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      const emptyBuilding = BuildingModel(
        id: 'empty-bld',
        schoolId: '11111111-1111-1111-1111-111111111111',
        name: 'Empty Annex',
        code: 'B99',
        totalFloors: 1,
        totalRooms: 0,
        totalCapacity: 0,
        currentOccupancy: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: OccupancySubtabView(
                building: emptyBuilding,
                occupancyList: const [],
                rooms: const [],
                isLoading: false,
                onAddOccupancy: () {},
                onEditOccupancy: (_) {},
                onDeleteOccupancy: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No space allocations found'), findsOneWidget);
    });
  });
}
