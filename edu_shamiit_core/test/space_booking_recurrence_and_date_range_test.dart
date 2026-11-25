import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/screens/campus/models/space_booking_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/widgets/space_booking_week_view.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/widgets/space_booking_month_view.dart';

void main() {
  group('Space Booking Date Range Calculations', () {
    (DateTime, DateTime) getTimelineRangeFor(DateTime date, String mode) {
      if (mode == 'Week') {
        final startOfWeek =
            date.subtract(Duration(days: (date.weekday - 1) % 7));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return (startOfWeek, endOfWeek);
      } else if (mode == 'Month') {
        final startOfMonth = DateTime(date.year, date.month, 1);
        final endOfMonth = DateTime(date.year, date.month + 1, 0);
        return (startOfMonth, endOfMonth);
      } else {
        return (date, date);
      }
    }

    test('Day mode returns exactly start == end == target date', () {
      final nov20 = DateTime(2026, 11, 20);
      final range = getTimelineRangeFor(nov20, 'Day');
      expect(range.$1, equals(nov20));
      expect(range.$2, equals(nov20));
    });

    test('Week mode returns Monday to Sunday for any weekday in the week', () {
      // Nov 16, 2026 is Monday; Nov 20 is Friday; Nov 22 is Sunday
      final monday = DateTime(2026, 11, 16);
      final wednesday = DateTime(2026, 11, 18);
      final friday = DateTime(2026, 11, 20);
      final sunday = DateTime(2026, 11, 22);

      for (final testDate in [monday, wednesday, friday, sunday]) {
        final range = getTimelineRangeFor(testDate, 'Week');
        expect(range.$1.year, equals(2026));
        expect(range.$1.month, equals(11));
        expect(range.$1.day, equals(16),
            reason: 'Week start must be Monday 16 Nov');
        expect(range.$2.year, equals(2026));
        expect(range.$2.month, equals(11));
        expect(range.$2.day, equals(22),
            reason: 'Week end must be Sunday 22 Nov');
        expect(range.$2.difference(range.$1).inDays, equals(6));
      }
    });

    test('Month mode returns first day to last day of month', () {
      final nov20 = DateTime(2026, 11, 20);
      final range = getTimelineRangeFor(nov20, 'Month');
      expect(range.$1, equals(DateTime(2026, 11, 1)));
      expect(range.$2, equals(DateTime(2026, 11, 30)));

      // February in leap year
      final leapFeb = DateTime(2028, 2, 14);
      final leapRange = getTimelineRangeFor(leapFeb, 'Month');
      expect(leapRange.$1, equals(DateTime(2028, 2, 1)));
      expect(leapRange.$2, equals(DateTime(2028, 2, 29)));
    });
  });

  group('SpaceTimelineBooking Model & Recurrence Deserialization', () {
    test('SpaceTimelineBooking correctly parses booking_date and is_recurring',
        () {
      final json1 = {
        'id': 'sb-101',
        'booking_ref': 'BK-REC-261116-001',
        'title': 'KING',
        'purpose': 'Academic',
        'start_time': '08:00 AM',
        'end_time': '09:00 AM',
        'booking_date': '2026-11-16',
        'is_recurring': true,
        'recurring_series_id': 'series-abc-123',
        'organizer_name': 'Admin',
        'organizer_role': 'Faculty',
        'status': 'Confirmed',
      };

      final booking = SpaceTimelineBooking.fromJson(json1);
      expect(booking.id, equals('sb-101'));
      expect(booking.bookingRef, equals('BK-REC-261116-001'));
      expect(booking.title, equals('KING'));
      expect(booking.bookingDate, equals('2026-11-16'));
      expect(booking.startTime, equals('08:00 AM'));
      expect(booking.isRecurring, isTrue);
    });

    test('SpaceTimelineBooking handles legacy recurrence_series_id key', () {
      final json2 = {
        'id': 'sb-102',
        'booking_ref': 'BK-REC-261117-002',
        'title': 'Maths Lab',
        'purpose': 'Academic',
        'start_time': '08:00:00',
        'end_time': '09:00:00',
        'booking_date': '2026-11-17',
        'recurrence_series_id': 'series-xyz-456',
        'organizer_name': 'Prof',
        'organizer_role': 'HOD',
        'status': 'Confirmed',
      };

      final booking = SpaceTimelineBooking.fromJson(json2);
      expect(booking.bookingDate, equals('2026-11-17'));
      expect(booking.isRecurring, isTrue);
    });
  });

  group('Recurrence Payload Engine for all scenarios', () {
    List<int> convertDaysToIntegers(List<String> days) {
      const map = {
        'MO': 1,
        'TU': 2,
        'WE': 3,
        'TH': 4,
        'FR': 5,
        'SA': 6,
        'SU': 7
      };
      return days.map((d) => map[d] ?? 1).toList()..sort();
    }

    Map<String, dynamic> buildRecurrencePayload({
      required String frequency,
      int interval = 1,
      List<String> days = const ['MO', 'WE', 'FR'],
      String endType = 'never',
      int count = 10,
      DateTime? untilDate,
      DateTime? startDate,
    }) {
      return {
        'frequency': frequency,
        'interval': interval,
        'days_of_week': frequency == 'daily'
            ? [1, 2, 3, 4, 5, 6, 7]
            : (frequency == 'weekdays'
                ? [1, 2, 3, 4, 5]
                : convertDaysToIntegers(days)),
        'end_type': endType,
        'count': count,
        'until_date':
            DateFormat('yyyy-MM-dd').format(untilDate ?? DateTime(2027, 1, 19)),
      };
    }

    test('Daily recurrence for 3 occurrences payload', () {
      final payload = buildRecurrencePayload(
        frequency: 'daily',
        interval: 1,
        endType: 'count',
        count: 3,
      );
      expect(payload['frequency'], equals('daily'));
      expect(payload['interval'], equals(1));
      expect(payload['end_type'], equals('count'));
      expect(payload['count'], equals(3));
      expect(payload['days_of_week'], equals([1, 2, 3, 4, 5, 6, 7]));
    });

    test('Every Weekday recurrence payload (Mon to Fri)', () {
      final payload = buildRecurrencePayload(
        frequency: 'weekdays',
        interval: 1,
        endType: 'never',
      );
      expect(payload['frequency'], equals('weekdays'));
      expect(payload['days_of_week'], equals([1, 2, 3, 4, 5]));
      expect(payload['end_type'], equals('never'));
    });

    test('Weekly recurrence on MO, WE, FR every 2 weeks', () {
      final payload = buildRecurrencePayload(
        frequency: 'weekly',
        interval: 2,
        days: ['MO', 'WE', 'FR'],
        endType: 'date',
        untilDate: DateTime(2026, 12, 31),
      );
      expect(payload['frequency'], equals('weekly'));
      expect(payload['interval'], equals(2));
      expect(payload['days_of_week'], equals([1, 3, 5]));
      expect(payload['end_type'], equals('date'));
      expect(payload['until_date'], equals('2026-12-31'));
    });

    test('Monthly recurrence payload', () {
      final payload = buildRecurrencePayload(
        frequency: 'monthly',
        interval: 1,
        endType: 'count',
        count: 6,
      );
      expect(payload['frequency'], equals('monthly'));
      expect(payload['count'], equals(6));
    });

    test('Custom recurrence with specific weekend days (SA, SU)', () {
      final payload = buildRecurrencePayload(
        frequency: 'custom',
        interval: 1,
        days: ['SA', 'SU'],
        endType: 'count',
        count: 4,
      );
      expect(payload['frequency'], equals('custom'));
      expect(payload['days_of_week'], equals([6, 7]));
    });
  });

  group('SpaceBookingWeekView Multi-Day Occurrence Rendering', () {
    testWidgets(
        'renders all 3 occurrences on Mon 16, Tue 17, and Wed 18 at 08:00 AM',
        (tester) async {
      final nov16 = DateTime(2026, 11, 16);

      const room = SpaceTimelineRoom(
        roomId: 'room-201',
        roomName: 'Grade 4 - Section A',
        roomNumber: '201',
        roomCode: 'G4-A',
        roomType: 'Classroom',
        capacity: 50,
        buildingId: 'b-1',
        buildingName: 'Academic Block (A)',
        buildingCode: 'B1',
        floorId: 'fl-1',
        floorName: 'Floor 1',
        bookings: [
          const SpaceTimelineBooking(
            id: 'bk-1',
            bookingRef: 'BK-REC-261116-001',
            title: 'KING',
            purpose: 'Academic',
            startTime: '08:00 AM',
            endTime: '09:00 AM',
            bookingDate: '2026-11-16',
            organizerName: 'Admin',
            organizerRole: 'Faculty',
            status: 'Confirmed',
          ),
          const SpaceTimelineBooking(
            id: 'bk-2',
            bookingRef: 'BK-REC-261117-002',
            title: 'KING',
            purpose: 'Academic',
            startTime: '08:00 AM',
            endTime: '09:00 AM',
            bookingDate: '2026-11-17',
            organizerName: 'Admin',
            organizerRole: 'Faculty',
            status: 'Confirmed',
          ),
          const SpaceTimelineBooking(
            id: 'bk-3',
            bookingRef: 'BK-REC-261118-003',
            title: 'KING',
            purpose: 'Academic',
            startTime: '08:00 AM',
            endTime: '09:00 AM',
            bookingDate: '2026-11-18',
            organizerName: 'Admin',
            organizerRole: 'Faculty',
            status: 'Confirmed',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SpaceBookingWeekView(
                selectedDate: nov16,
                rooms: [room],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // "KING" must appear 3 times in the weekly grid: on Monday 16, Tuesday 17, and Wednesday 18!
      expect(find.text('KING'), findsNWidgets(3));
    });
  });

  group('SpaceBookingMonthView Multi-Day Occurrence Rendering', () {
    testWidgets('renders bookings on their corresponding month grid dates',
        (tester) async {
      final nov16 = DateTime(2026, 11, 16);

      const room = SpaceTimelineRoom(
        roomId: 'room-201',
        roomName: 'Grade 4 - Section A',
        roomNumber: '201',
        roomCode: 'G4-A',
        roomType: 'Classroom',
        capacity: 50,
        buildingId: 'b-1',
        buildingName: 'Academic Block (A)',
        buildingCode: 'B1',
        floorId: 'fl-1',
        floorName: 'Floor 1',
        bookings: [
          const SpaceTimelineBooking(
            id: 'bk-1',
            bookingRef: 'BK-REC-261116-001',
            title: 'Series Session 1',
            purpose: 'Academic',
            startTime: '08:00 AM',
            endTime: '09:00 AM',
            bookingDate: '2026-11-16',
            organizerName: 'Admin',
            organizerRole: 'Faculty',
            status: 'Confirmed',
          ),
          const SpaceTimelineBooking(
            id: 'bk-2',
            bookingRef: 'BK-REC-261117-002',
            title: 'Series Session 2',
            purpose: 'Academic',
            startTime: '08:00 AM',
            endTime: '09:00 AM',
            bookingDate: '2026-11-17',
            organizerName: 'Admin',
            organizerRole: 'Faculty',
            status: 'Confirmed',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SpaceBookingMonthView(
                selectedDate: nov16,
                rooms: [room],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Series Session 1'), findsOneWidget);
      expect(find.textContaining('Series Session 2'), findsOneWidget);
    });
  });
}
