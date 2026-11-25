import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/common/campus_searchable_dropdown.dart';
import 'package:edu_shamiit_core/screens/campus/models/space_booking_models.dart';
import 'package:edu_shamiit_core/screens/campus/providers/space_booking_provider.dart';

void main() {
  group('CampusSearchableDropdown Unit & Widget Tests', () {
    testWidgets(
        'CampusSearchableDropdown renders with default label and item count',
        (tester) async {
      String selectedValue = 'all';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CampusSearchableDropdown<String>(
                  title: 'Campus Building',
                  label: 'All Buildings',
                  value: selectedValue,
                  allValue: 'all',
                  prefixIcon: Icons.apartment_rounded,
                  isDark: false,
                  items: const [
                    CampusSearchableDropdownItem(
                      value: 'all',
                      label: 'All Buildings',
                      subtitle: 'Every building on campus',
                      icon: Icons.location_city,
                    ),
                    CampusSearchableDropdownItem(
                      value: 'b-1',
                      label: 'B1 - Academic Block (A)',
                      subtitle: '52 Rooms • 5 Floors',
                      icon: Icons.domain,
                    ),
                    CampusSearchableDropdownItem(
                      value: 'b-2',
                      label: 'B2 - Science Complex (B)',
                      subtitle: '36 Rooms • 4 Floors',
                      icon: Icons.science,
                    ),
                    CampusSearchableDropdownItem(
                      value: 'b-3',
                      label: 'B3 - Library & Learning Center',
                      subtitle: '12 Rooms • 3 Floors',
                      icon: Icons.local_library,
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => selectedValue = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify pill label is rendered
      expect(find.text('All Buildings'), findsOneWidget);
      expect(find.byIcon(Icons.apartment_rounded), findsOneWidget);

      // Tap to open search modal dialog
      await tester.tap(find.byType(CampusSearchableDropdown<String>));
      await tester.pumpAndSettle();

      // Verify search dialog opens with title, count and items
      expect(find.text('Campus Building'), findsOneWidget);
      expect(find.text('4 of 4'), findsOneWidget);
      expect(find.text('B1 - Academic Block (A)'), findsOneWidget);
      expect(find.text('B2 - Science Complex (B)'), findsOneWidget);
      expect(find.text('B3 - Library & Learning Center'), findsOneWidget);

      // Type in search field to filter down items
      await tester.enterText(find.byType(TextField), 'science');
      await tester.pumpAndSettle();

      // Verify only science option remains
      expect(find.text('B2 - Science Complex (B)'), findsOneWidget);
      expect(find.text('B1 - Academic Block (A)'), findsNothing);

      // Tap on filtered item to select it
      await tester.tap(find.text('B2 - Science Complex (B)'));
      await tester.pumpAndSettle();

      // Verify dialog is closed and dropdown pill updated
      expect(find.text('4 of 4'), findsNothing);
      expect(selectedValue, 'b-2');
      expect(find.text('B2 - Science Complex (B)'), findsOneWidget);
    });

    test(
        'SpaceTimelineRoom correctly models domain, building, floor and capacity',
        () {
      final roomJson = {
        'room_id': 'room-101',
        'room_name': 'Grade 4 - Section A',
        'room_number': '101',
        'room_code': 'RM-101',
        'room_type': 'Classroom',
        'capacity': 50,
        'building_id': 'bldg-1',
        'building_name': 'Academic Block (A)',
        'building_code': 'B1',
        'floor_id': 'floor-1',
        'floor_name': 'Ground Floor',
        'space_domain': 'room',
        'bookings': [
          {
            'id': 'book-1',
            'booking_ref': 'SB-2026-001',
            'title': 'Mathematics Lecture Grade 4',
            'purpose': 'Academic',
            'start_time': '09:00 AM',
            'end_time': '10:00 AM',
            'duration_minutes': 60,
            'organizer_name': 'Mr. Sharma',
            'organizer_role': 'Academic / Teaching',
            'status': 'Confirmed',
            'is_approved': true,
          }
        ]
      };

      final room = SpaceTimelineRoom.fromJson(roomJson);
      expect(room.roomId, 'room-101');
      expect(room.roomName, 'Grade 4 - Section A');
      expect(room.capacity, 50);
      expect(room.buildingId, 'bldg-1');
      expect(room.floorId, 'floor-1');
      expect(room.spaceDomain, 'room');
      expect(room.bookings.length, 1);
      expect(room.bookings.first.title, 'Mathematics Lecture Grade 4');
      expect(room.bookings.first.status, 'Confirmed');
    });

    test('SpaceTimelineRoom models campus facility with spaceDomain facility',
        () {
      final facilityJson = {
        'room_id': 'fac-spt-01',
        'room_name': 'Olympic Standard Swimming & Athletics Arena',
        'room_number': 'FAC-SPT-01',
        'room_code': 'FAC-SPT-01',
        'room_type': 'Sports Complex / Ground',
        'capacity': 300,
        'building_id': '00000000-0000-0000-0000-000000000000',
        'building_name': 'Campus Facilities & Grounds',
        'building_code': 'FAC',
        'floor_id': null,
        'floor_name': 'Ground Level',
        'space_domain': 'facility',
        'bookings': []
      };

      final facility = SpaceTimelineRoom.fromJson(facilityJson);
      expect(facility.roomId, 'fac-spt-01');
      expect(facility.spaceDomain, 'facility');
      expect(facility.capacity, 300);
      expect(facility.roomType, 'Sports Complex / Ground');
      expect(facility.bookings, isEmpty);
    });

    test('SpaceBookingState stores all 10 popup filter parameters cleanly', () {
      final state = SpaceBookingState(
        selectedDate: DateTime(2026, 11, 24),
        selectedDomain: 'facility',
        selectedBuildingId: 'bldg-1',
        selectedFloorId: 'floor-2',
        selectedRoomId: 'fac-spt-01',
        selectedSpaceType: 'Sports Facility',
        selectedPurpose: 'Sports & Athletic Training',
        selectedClassId: 'class-10-a',
        selectedDepartment: 'Sports & Physical Ed',
        selectedCapacity: '200+ seats',
        statusFilter: 'Confirmed',
      );

      expect(state.selectedDomain, 'facility');
      expect(state.selectedBuildingId, 'bldg-1');
      expect(state.selectedFloorId, 'floor-2');
      expect(state.selectedRoomId, 'fac-spt-01');
      expect(state.selectedSpaceType, 'Sports Facility');
      expect(state.selectedPurpose, 'Sports & Athletic Training');
      expect(state.selectedClassId, 'class-10-a');
      expect(state.selectedDepartment, 'Sports & Physical Ed');
      expect(state.selectedCapacity, '200+ seats');
      expect(state.statusFilter, 'Confirmed');
    });
  });
}
