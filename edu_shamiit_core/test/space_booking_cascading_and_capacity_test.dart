import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:edu_shamiit_core/screens/campus/providers/space_booking_provider.dart';
import 'package:edu_shamiit_core/screens/campus/services/space_booking_api_service.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/dialogs/create_edit_booking_dialog.dart';

void main() {
  group('Space Booking Cascading Selection & Capacity Verification Tests', () {
    test('BookableRoomItem parses floor_id and floor_name correctly', () {
      final json = {
        'id': 'room-uuid-101',
        'name': 'Physics Lab 1',
        'room_number': '101',
        'room_code': 'PL-101',
        'room_type': 'Laboratory',
        'building_id': 'b-uuid-1',
        'building_name': 'Science Block',
        'building_code': 'SB',
        'floor_id': 'floor-uuid-1',
        'floor_name': 'First Floor',
        'max_capacity': 45,
      };

      final item = BookableRoomItem.fromJson(json);

      expect(item.id, equals('room-uuid-101'));
      expect(item.name, equals('Physics Lab 1'));
      expect(item.buildingId, equals('b-uuid-1'));
      expect(item.floorId, equals('floor-uuid-1'));
      expect(item.floorName, equals('First Floor'));
      expect(item.maxCapacity, equals(45));
    });

    testWidgets('CreateEditBookingDialog renders cascading selection and academic target fields', (tester) async {
      final sampleRooms = [
        const BookableRoomItem(
          id: 'room-1',
          name: 'Classroom 101',
          roomNumber: '101',
          roomCode: 'CR-101',
          roomType: 'Classroom',
          buildingId: 'b-1',
          buildingName: 'Academic Block A',
          buildingCode: 'B1',
          floorId: 'fl-1',
          floorName: 'Ground Floor',
          maxCapacity: 50,
        ),
        const BookableRoomItem(
          id: 'room-2',
          name: 'Seminar Hall B',
          roomNumber: '201',
          roomCode: 'SH-201',
          roomType: 'Auditorium',
          buildingId: 'b-2',
          buildingName: 'Main Auditorium',
          buildingCode: 'B2',
          floorId: 'fl-2',
          floorName: 'Second Floor',
          maxCapacity: 20,
        ),
      ];

      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spaceBookingProvider.overrideWith((ref) {
              final notifier = SpaceBookingNotifier(SpaceBookingApiService.instance);
              notifier.state = notifier.state.copyWith(
                bookableRooms: sampleRooms,
                isLoading: false,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CreateEditBookingDialog(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Dialog header
      expect(find.text('Book a Campus Space'), findsOneWidget);
      expect(find.text('Space & Timings'), findsOneWidget);

      // Verify Cascading Space Selection header
      expect(find.text('Campus Space Allocation'), findsOneWidget);
      expect(find.text('1. Select Building'), findsOneWidget);
      expect(find.text('2. Select Floor'), findsOneWidget);
      expect(find.text('3. Select Room / Space (Capacity) *'), findsOneWidget);

      // Verify academic target card is present (Academic purpose is default)
      expect(find.text('Academic Purpose: Class & Section Allocation'), findsOneWidget);
      expect(find.text('Target Class'), findsOneWidget);

      // Verify capacity filter option
      expect(find.textContaining('Show only spaces that can accommodate'), findsOneWidget);
    });
  });
}
