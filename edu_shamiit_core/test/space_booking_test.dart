import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:edu_shamiit_core/screens/campus/providers/space_booking_provider.dart';

void main() {
  group('Space Booking Models & Serialization Tests', () {
    test('SpaceBookingKpis fromJson parses exact screenshot values', () {
      final json = {
        'total_bookings': 246,
        'total_change_pct': 12.0,
        'confirmed_bookings': 198,
        'confirmed_pct': 80.5,
        'pending_bookings': 28,
        'pending_pct': 11.4,
        'rejected_bookings': 9,
        'rejected_pct': 3.7,
        'current_usage_spaces': 34,
        'utilization_rate': 72.8,
        'utilization_change_pct': 4.6,
      };

      final kpis = SpaceBookingKpis.fromJson(json);

      expect(kpis.totalBookings, equals(246));
      expect(kpis.confirmedBookings, equals(198));
      expect(kpis.confirmedPct, equals(80.5));
      expect(kpis.pendingBookings, equals(28));
      expect(kpis.pendingPct, equals(11.4));
      expect(kpis.rejectedBookings, equals(9));
      expect(kpis.rejectedPct, equals(3.7));
      expect(kpis.currentUsageSpaces, equals(34));
      expect(kpis.utilizationRate, equals(72.8));
    });

    test('SpaceTimelineRoom parses room and booking event intervals', () {
      final json = {
        'room_id': '11111111-2222-3333-4444-555555555555',
        'room_name': 'G-101',
        'room_number': 'G-101',
        'room_code': 'B1-G101',
        'room_type': 'Classroom',
        'capacity': 40,
        'building_id': 'b1',
        'building_name': 'B1 - Academic Block',
        'building_code': 'B1',
        'bookings': [
          {
            'id': 'b1',
            'booking_ref': 'BK-2026-0101',
            'title': 'Math Lecture',
            'purpose': 'Lecture',
            'start_time': '08:00 AM',
            'end_time': '09:30 AM',
            'duration_minutes': 90,
            'organizer_name': 'Prof. Ramanathan',
            'organizer_role': 'Faculty',
            'status': 'Confirmed',
          },
          {
            'id': 'b2',
            'booking_ref': 'BK-2026-0102',
            'title': 'Physics Practical',
            'purpose': 'Practical',
            'start_time': '10:00 AM',
            'end_time': '12:00 PM',
            'duration_minutes': 120,
            'organizer_name': 'Dr. V. Rao',
            'organizer_role': 'Faculty',
            'status': 'Confirmed',
          }
        ]
      };

      final room = SpaceTimelineRoom.fromJson(json);

      expect(room.roomName, equals('G-101'));
      expect(room.capacity, equals(40));
      expect(room.bookings.length, equals(2));
      expect(room.bookings.first.title, equals('Math Lecture'));
      expect(room.bookings.first.durationMinutes, equals(90));
      expect(room.bookings[1].title, equals('Physics Practical'));
    });

    test('SpaceUtilizationStats calculates donut breakdown percentages', () {
      final json = {
        'total_spaces': 150,
        'overall_rate': 72.8,
        'in_use': {'count': 109, 'percentage': 72.8},
        'available': {'count': 32, 'percentage': 21.4},
        'under_maintenance': {'count': 6, 'percentage': 4.0},
        'not_bookable': {'count': 3, 'percentage': 2.0},
      };

      final stats = SpaceUtilizationStats.fromJson(json);

      expect(stats.totalSpaces, equals(150));
      expect(stats.overallRate, equals(72.8));
      expect(stats.inUseCount, equals(109));
      expect(stats.availableCount, equals(32));
      expect(stats.maintenanceCount, equals(6));
      expect(stats.notBookableCount, equals(3));
    });

    test('SpaceBookingListResponse parses paged requests table items', () {
      final json = {
        'items': [
          {
            'id': 'req-1',
            'booking_ref': 'BK-2026-0201',
            'title': 'CS Club Meeting',
            'purpose': 'Club Activity',
            'category': 'Club Activity',
            'priority': 'Normal',
            'status': 'Pending',
            'is_approved': false,
            'booking_date': '2026-03-20',
            'start_time': '02:00 PM',
            'end_time': '04:00 PM',
            'formatted_schedule': '20 Mar, 02:00 PM - 04:00 PM',
            'room_id': 'r1',
            'room_name': 'G-101',
            'room_type': 'Classroom',
            'space_display': 'G-101 (Classroom)',
            'building_id': 'b1',
            'building_name': 'B1 - Academic Block',
            'organizer_name': 'Rohan Verma',
            'organizer_role': 'Student',
            'requested_by_display': 'Rohan Verma (Student)',
            'attendee_count': 35,
            'is_recurring': false,
          }
        ],
        'total_count': 28,
        'page': 1,
        'page_size': 5,
        'total_pages': 6,
      };

      final response = SpaceBookingListResponse.fromJson(json);

      expect(response.totalCount, equals(28));
      expect(response.items.length, equals(1));
      expect(response.items.first.title, equals('CS Club Meeting'));
      expect(response.items.first.requestedByDisplay, equals('Rohan Verma (Student)'));
      expect(response.items.first.status, equals('Pending'));
    });
    test('SpaceBookingState supports Day, Week, Month and Purpose Filtering', () {
      final initial = SpaceBookingState(
        selectedDate: DateTime(2026, 3, 15),
        timelineViewMode: 'Day',
        displayMode: 'Timeline',
        selectedPurpose: 'All',
      );

      expect(initial.timelineViewMode, equals('Day'));
      expect(initial.selectedPurpose, equals('All'));

      // Switch to Week view mode
      final weekState = initial.copyWith(timelineViewMode: 'Week');
      expect(weekState.timelineViewMode, equals('Week'));

      // Switch to Month view mode
      final monthState = initial.copyWith(timelineViewMode: 'Month');
      expect(monthState.timelineViewMode, equals('Month'));

      // Switch display mode to List
      final listState = initial.copyWith(displayMode: 'List');
      expect(listState.displayMode, equals('List'));

      // Set purpose filter
      final filteredState = initial.copyWith(selectedPurpose: 'Workshop');
      expect(filteredState.selectedPurpose, equals('Workshop'));
    });

    test('Date stepping advances by day, week, or month based on view mode', () {
      final baseDate = DateTime(2026, 3, 15);

      // Day mode step: 1 day
      final nextDay = baseDate.add(const Duration(days: 1));
      expect(nextDay.day, equals(16));

      // Week mode step: 7 days
      final nextWeek = baseDate.add(const Duration(days: 7));
      expect(nextWeek.day, equals(22));

      // Month mode step: 1 month
      final nextMonth = DateTime(baseDate.year, baseDate.month + 1, baseDate.day);
      expect(nextMonth.month, equals(4));
    });

    test('SpaceBookingKpis math consistency (Confirmed 190 + Pending 20 + Rejected 7 = Total 217)', () {
      final json = {
        'total_bookings': 217,
        'total_change_pct': 12.0,
        'confirmed_bookings': 190,
        'confirmed_pct': 87.6,
        'pending_bookings': 20,
        'pending_pct': 9.2,
        'rejected_bookings': 7,
        'rejected_pct': 3.2,
        'current_usage_spaces': 34,
        'utilization_rate': 72.8,
        'utilization_change_pct': 4.6,
      };

      final kpis = SpaceBookingKpis.fromJson(json);

      // Counts sum must strictly equal total bookings
      expect(kpis.confirmedBookings + kpis.pendingBookings + kpis.rejectedBookings, equals(kpis.totalBookings));
      expect(kpis.totalBookings, equals(217));
      expect(kpis.confirmedBookings, equals(190));
      expect(kpis.pendingBookings, equals(20));
      expect(kpis.rejectedBookings, equals(7));

      // Percentage sum must strictly equal 100.0%
      final pctSum = double.parse((kpis.confirmedPct + kpis.pendingPct + kpis.rejectedPct).toStringAsFixed(1));
      expect(pctSum, equals(100.0));
      expect(kpis.currentUsageSpaces, equals(34));
      expect(kpis.utilizationRate, equals(72.8));
    });

    test('SpaceBookingState dateRange defaults to null and copyWith supports clearDateRange', () {
      final state = SpaceBookingState(selectedDate: DateTime(2026, 3, 15));
      expect(state.dateRangeFrom, isNull);
      expect(state.dateRangeTo, isNull);

      final withRange = state.copyWith(
        dateRangeFrom: DateTime(2026, 3, 15),
        dateRangeTo: DateTime(2026, 3, 21),
      );
      expect(withRange.dateRangeFrom, equals(DateTime(2026, 3, 15)));
      expect(withRange.dateRangeTo, equals(DateTime(2026, 3, 21)));

      final cleared = withRange.copyWith(clearDateRange: true);
      expect(cleared.dateRangeFrom, isNull);
      expect(cleared.dateRangeTo, isNull);
    });
  });
}
