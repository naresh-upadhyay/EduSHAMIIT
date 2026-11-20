import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/providers/space_booking_provider.dart';
import 'package:edu_shamiit_core/screens/campus/models/space_booking_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/space_booking_kpis_bar.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/space_booking_left_panel.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/space_booking_center_panel.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/space_booking_right_panel.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/space_booking_tab_view.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/common/campus_pagination_bar.dart';
import 'package:edu_shamiit_core/screens/campus/services/space_booking_api_service.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/dialogs/create_edit_booking_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/dialogs/booking_details_drawer.dart';

void main() {
  group('Space Booking Powerful UI Enhancements & Consistency Tests', () {
    const consistentKpis = SpaceBookingKpis(
      totalBookings: 217,
      totalChangePct: 12.0,
      confirmedBookings: 190,
      confirmedPct: 87.6,
      pendingBookings: 20,
      pendingPct: 9.2,
      rejectedBookings: 7,
      rejectedPct: 3.2,
      currentUsageSpaces: 34,
      utilizationRate: 72.8,
      utilizationChangePct: 4.6,
    );

    testWidgets('SpaceBookingKpisBar renders strictly consistent mathematical values', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 300));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpaceBookingKpisBar(kpis: consistentKpis),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check values
      expect(find.text('Total Bookings'), findsOneWidget);
      expect(find.text('217'), findsOneWidget);

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('190'), findsOneWidget);
      expect(find.text('(87.6%)'), findsOneWidget);

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('(9.2%)'), findsOneWidget);

      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('(3.2%)'), findsOneWidget);

      expect(find.text('Current Usage'), findsOneWidget);
      expect(find.text('34 Spaces'), findsOneWidget);

      expect(find.text('Utilization'), findsOneWidget);
      expect(find.text('72.8%'), findsOneWidget);
    });

    testWidgets('SpaceBookingLeftPanel removed unwanted tabs and has Booking Spaces, Requests, Calendar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      final state = SpaceBookingState(
        selectedDate: DateTime(2026, 3, 15),
        selectedNav: 'Booking Spaces',
        kpis: consistentKpis,
        dateRangeFrom: null,
        dateRangeTo: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spaceBookingProvider.overrideWith((ref) => _FakeSpaceBookingNotifier(state)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SpaceBookingLeftPanel(
                onOpenBookModal: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Clean, Consolidated Navigation Items exist
      expect(find.text('Booking Spaces'), findsOneWidget);
      expect(find.text('Booking Requests'), findsOneWidget);
      expect(find.text('20'), findsOneWidget); // Pending badge on Booking Requests
      expect(find.text('Usage & Reports'), findsOneWidget);
      expect(find.text('Booking Calendar'), findsNothing); // Duplicate removed as requested
      expect(find.text('Recurring Bookings'), findsNothing); // Removed as requested

      // Verify unwanted redundant status tabs and Quick Filters are REMOVED from the left panel
      expect(find.text('Approved Bookings'), findsNothing);
      expect(find.text('Rejected Bookings'), findsNothing);
      expect(find.text('My Bookings'), findsNothing);
      expect(find.text('Quick Filters'), findsNothing); // Removed as requested
      expect(find.text('Reset'), findsNothing); // Removed as requested
      expect(find.text('Recurring Series'), findsOneWidget); // Quick shortcut intact
    });

    testWidgets('SpaceBookingCenterPanel renders top navigation tabs and Booking Requests without scrolling', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));

      final state = SpaceBookingState(
        selectedDate: DateTime(2026, 3, 15),
        selectedNav: 'Booking Requests',
        statusFilter: 'Pending',
        kpis: consistentKpis,
        bookingRequests: SpaceBookingListResponse(
          items: List.generate(
            10,
            (i) => SpaceBookingRequestItem(
              id: 'req-$i',
              bookingRef: 'BK-2026-0$i',
              title: 'Request Title $i',
              purpose: 'Club Activity',
              category: 'Activity',
              priority: 'Normal',
              status: 'Pending',
              isApproved: false,
              bookingDate: '2026-03-20',
              startTime: '02:00 PM',
              endTime: '04:00 PM',
              formattedSchedule: '20 Mar, 02:00 PM - 04:00 PM',
              roomId: 'r1',
              roomName: 'G-101',
              roomType: 'Classroom',
              spaceDisplay: 'G-101 (Classroom)',
              buildingId: 'b1',
              buildingName: 'Academic Block',
              organizerName: 'Organizer $i',
              organizerRole: 'Student',
              requestedByDisplay: 'Organizer $i (Student)',
              attendeeCount: 30,
              isRecurring: false,
            ),
          ),
          totalCount: 20,
          page: 1,
          pageSize: 10,
          totalPages: 2,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spaceBookingProvider.overrideWith((ref) => _FakeSpaceBookingNotifier(state)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SpaceBookingCenterPanel(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Top Center Navigation Tabs exist (Consolidated 3 Tabs)
      expect(find.text('Booking Spaces'), findsOneWidget);
      expect(find.text('Usage & Reports'), findsOneWidget);
      expect(find.text('Booking Calendar'), findsNothing); // Duplicate removed as requested

      // Verify Table status tabs have consistent numbers
      expect(find.text('All (217)'), findsOneWidget);
      expect(find.text('Pending (20)'), findsOneWidget);
      expect(find.text('Approved (190)'), findsOneWidget);
      expect(find.text('Rejected (7)'), findsOneWidget);

      // Verify Header Title reflects Pending (20)
      expect(find.text('Booking Requests (20)'), findsOneWidget);

      expect(find.byType(CampusPaginationBar), findsOneWidget);
      final paginationBar = tester.widget<CampusPaginationBar>(find.byType(CampusPaginationBar));
      expect(paginationBar.totalCount, equals(20));
      expect(paginationBar.currentPage, equals(1));
      expect(paginationBar.pageSize, equals(10));
    });

    testWidgets('SpaceBookingTabView dedicates right side full width to calendar and grids, and embeds Today Space Utilization donut into Usage & Reports', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));

      final spacesState = SpaceBookingState(
        selectedDate: DateTime(2026, 3, 15),
        selectedNav: 'Booking Spaces',
        kpis: consistentKpis,
        roomsTimeline: [
          SpaceTimelineRoom(
            roomId: 'r1',
            roomNumber: '101',
            roomCode: 'G-101',
            roomName: 'G-101',
            roomType: 'Classroom',
            capacity: 40,
            buildingId: 'b1',
            buildingName: 'Academic Block',
            buildingCode: 'B1',
            bookings: const [],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('spaces-tab-view-test'),
          overrides: [
            spaceBookingProvider.overrideWith((ref) => _FakeSpaceBookingNotifier(spacesState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SpaceBookingTabView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Booking Spaces view is active and right side form is eliminated
      expect(find.text('Space Availability & Booking'), findsOneWidget);
      expect(find.text('Submit Booking Request'), findsNothing); // Removed right form

      // 2. On Usage & Reports tab: Today's Space Utilization donut chart is embedded
      final usageState = SpaceBookingState(
        selectedDate: DateTime(2026, 3, 15),
        selectedNav: 'Usage & Reports',
        kpis: consistentKpis,
        utilization: const SpaceUtilizationStats(
          totalSpaces: 150,
          overallRate: 72.8,
          inUseCount: 109,
          inUsePct: 72.8,
          availableCount: 32,
          availablePct: 21.4,
          maintenanceCount: 6,
          maintenancePct: 4.0,
          notBookableCount: 3,
          notBookablePct: 2.0,
        ),
        analyticsReport: const SpaceAnalyticsReport(
          totalBookedHours: 353,
          avgDurationMinutes: 95,
          peakHourLabel: '10:00 AM - 12:00 PM',
          overallUtilizationPct: 72.8,
          activeSpacesCount: 34,
          totalSpacesCount: 48,
          hourlyOccupancy: [],
          spaceTypeBreakdown: [],
          dayOfWeekTraffic: [],
          buildingUtilization: [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('usage-tab-view-test'),
          overrides: [
            spaceBookingProvider.overrideWith((ref) => _FakeSpaceBookingNotifier(usageState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SpaceBookingTabView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Today's Space Utilization donut chart moved into Usage & Reports screen
      expect(find.text("Today's Space Utilization"), findsOneWidget);
      expect(find.text('Space Type Breakdown'), findsOneWidget);
      expect(find.text('Building-wise Utilization Matrix'), findsOneWidget);
    });

    testWidgets('CreateEditBookingDialog renders 4 modular tabs including Recurrence and Dynamic Requester', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spaceBookingProvider.overrideWith((ref) => _FakeSpaceBookingNotifier(SpaceBookingState(
              selectedDate: DateTime(2026, 3, 15),
              bookableRooms: const [
                BookableRoomItem(
                  id: 'room-1',
                  name: 'Auditorium Hall',
                  roomNumber: 'AUD-1',
                  roomCode: 'AUD1',
                  roomType: 'Auditorium',
                  maxCapacity: 200,
                  buildingId: 'b1',
                  buildingName: 'Academic Block',
                  buildingCode: 'B1',
                ),
              ],
            ))),
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

      // Verify all 4 tabs exist
      expect(find.text('Space & Timings'), findsOneWidget);
      expect(find.text('Recurrence'), findsOneWidget);
      expect(find.text('Requester & Contact'), findsOneWidget);
      expect(find.text('Amenities & Notes'), findsOneWidget);

      // Tab 1: Space & Timings is active by default
      expect(find.text('Booking Title *'), findsOneWidget);

      // Switch to Recurrence tab
      await tester.tap(find.text('Recurrence'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Repeat Frequency'), findsOneWidget);

      // Switch to Requester tab
      await tester.tap(find.text('Requester & Contact'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Search & Select Requestor from User Directory'), findsOneWidget);
      expect(find.text('Organizer Name *'), findsOneWidget);
    });

    test('SpaceAnalyticsReport parses backend payload and provides chart metrics', () {
      final json = {
        'summary_kpis': {
          'total_bookings': 224,
          'confirmed_bookings': 190,
          'pending_bookings': 20,
          'rejected_bookings': 7,
          'total_booked_hours': 353.0,
          'avg_duration_minutes': 95.0,
          'overall_utilization_pct': 72.8,
          'peak_hour_label': '10:00 AM - 12:00 PM',
          'active_spaces_count': 34,
          'total_spaces_count': 150,
        },
        'hourly_occupancy': [
          {'military_hour': 8, 'hour_label': '08:00 AM', 'active_bookings': 3, 'occupancy_pct': 29.0},
          {'military_hour': 10, 'hour_label': '10:00 AM', 'active_bookings': 178, 'occupancy_pct': 98.5},
        ],
        'day_of_week_traffic': [
          {'day_index': 1, 'day_name': 'Monday', 'day_short': 'Mon', 'bookings_count': 82, 'utilization_pct': 82.5},
          {'day_index': 3, 'day_name': 'Wednesday', 'day_short': 'Wed', 'bookings_count': 91, 'utilization_pct': 91.5},
        ],
        'space_type_breakdown': [
          {'code': 'Classroom', 'type_name': 'Classrooms / Lecture Halls', 'count': 67, 'percentage': 44.7, 'color_hex': '#3B82F6'},
        ],
        'building_utilization': [
          {'building_id': 'b1', 'building_name': 'Academic Block', 'building_code': 'B1', 'total_rooms': 15, 'booked_rooms': 11, 'utilization_pct': 84.5},
        ],
      };

      final report = SpaceAnalyticsReport.fromJson(json);
      expect(report.totalBookings, 224);
      expect(report.confirmedBookings, 190);
      expect(report.pendingBookings, 20);
      expect(report.rejectedBookings, 7);
      expect(report.hourlyOccupancy.length, 2);
      expect(report.hourlyOccupancy[1].militaryHour, 10);
      expect(report.hourlyOccupancy[1].occupancyPct, 98.5);
      expect(report.dayOfWeekTraffic.length, 2);
      expect(report.spaceTypeBreakdown.first.code, 'Classroom');
      expect(report.buildingUtilization.first.buildingCode, 'B1');
    });

    testWidgets('BookingDetailsDrawer renders Edit and Delete actions in header and footer for Approved booking', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));

      const approvedItem = SpaceBookingRequestItem(
        id: 'bk-105',
        bookingRef: 'BK-2026-0105',
        title: 'Workshop on Modern Robotics',
        purpose: 'Workshop',
        category: 'Academic',
        priority: 'Normal',
        status: 'Approved',
        isApproved: true,
        bookingDate: '15 Mar 2026',
        startTime: '11:00 AM',
        endTime: '01:00 PM',
        formattedSchedule: '15 Mar 2026, 11:00 AM - 01:00 PM',
        roomId: 'r-102',
        roomName: 'G-102',
        roomType: 'Classroom',
        spaceDisplay: 'G-102 (Classroom)',
        buildingId: 'b-1',
        buildingName: 'Academic Block (A)',
        organizerName: 'Literary Club',
        organizerRole: 'Faculty',
        requestedByDisplay: 'Literary Club (Faculty)',
        attendeeCount: 40,
        isRecurring: false,
      );

      bool editTriggered = false;
      bool deleteTriggered = false;

      final testState = SpaceBookingState(
        selectedDate: DateTime(2026, 3, 15),
        kpis: consistentKpis,
        roomsTimeline: const [],
        bookingRequests: const SpaceBookingListResponse(items: [approvedItem], totalCount: 1, page: 1, pageSize: 10, totalPages: 1),
        utilization: const SpaceUtilizationStats(),
        bookableRooms: const [],
        analyticsReport: const SpaceAnalyticsReport(),
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spaceBookingProvider.overrideWith((ref) => _FakeSpaceBookingNotifier(testState)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BookingDetailsDrawer(
                item: approvedItem,
                onEdit: () => editTriggered = true,
                onDelete: () => deleteTriggered = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Header should show Edit and Delete icon buttons
      expect(find.byTooltip('Modify / Edit Schedule'), findsOneWidget);
      expect(find.byTooltip('Delete Schedule'), findsOneWidget);

      // Footer should show 'Modify Schedule' and 'Delete / Cancel' buttons for Approved status
      expect(find.text('Modify Schedule'), findsOneWidget);
      expect(find.text('Delete / Cancel'), findsOneWidget);

      // Trigger Edit
      await tester.tap(find.text('Modify Schedule'));
      await tester.pump();
      expect(editTriggered, isTrue);

      // Trigger Delete
      await tester.tap(find.text('Delete / Cancel'));
      await tester.pump();
      expect(deleteTriggered, isTrue);
    });

    testWidgets('CreateEditBookingDialog pre-populates all booking schedule fields when modifying', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 900));

      const existingItem = SpaceBookingRequestItem(
        id: 'bk-105',
        bookingRef: 'BK-2026-0105',
        title: 'Physics Practical Lab Session',
        purpose: 'Academic',
        category: 'Academic',
        priority: 'Normal',
        status: 'Approved',
        isApproved: true,
        bookingDate: '2026-03-21',
        startTime: '10:00 AM',
        endTime: '12:00 PM',
        formattedSchedule: '21 Mar 2026, 10:00 AM - 12:00 PM',
        roomId: 'r-101',
        roomName: 'G-101',
        roomType: 'Classroom',
        spaceDisplay: 'G-101 (Classroom)',
        buildingId: 'b-1',
        buildingName: 'Academic Block (A)',
        organizerName: 'Dr. Ananya Sharma',
        organizerRole: 'Faculty',
        requestedByDisplay: 'Dr. Ananya Sharma (Faculty)',
        attendeeCount: 45,
        isRecurring: false,
      );

      final testState = SpaceBookingState(
        selectedDate: DateTime(2026, 3, 15),
        kpis: consistentKpis,
        roomsTimeline: const [],
        bookingRequests: const SpaceBookingListResponse(items: [existingItem], totalCount: 1, page: 1, pageSize: 10, totalPages: 1),
        utilization: const SpaceUtilizationStats(),
        bookableRooms: const [
          BookableRoomItem(
            id: 'r-101',
            name: 'G-101',
            roomNumber: '101',
            roomCode: 'G-101',
            roomType: 'Classroom',
            maxCapacity: 50,
            buildingId: 'b-1',
            buildingName: 'Academic Block',
            buildingCode: 'B1',
          ),
        ],
        analyticsReport: const SpaceAnalyticsReport(),
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spaceBookingProvider.overrideWith((ref) => _FakeSpaceBookingNotifier(testState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CreateEditBookingDialog(initialItem: existingItem),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Title should show Edit mode
      expect(find.text('Edit Space Booking'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Verify title field is pre-populated
      expect(find.text('Physics Practical Lab Session'), findsOneWidget);

      // Verify attendees count is pre-populated
      expect(find.text('45'), findsOneWidget);

      // Switch to Requester Tab to verify organizer name pre-population
      await tester.tap(find.text('Requester & Contact'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'Dr. Ananya Sharma'),
        findsWidgets,
      );
    });

    testWidgets('Usage & Reports tab renders analytics and hides right panel form for full width presentation', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));

      const report = SpaceAnalyticsReport(
        totalBookings: 216,
        confirmedBookings: 182,
        pendingBookings: 20,
        rejectedBookings: 7,
        totalBookedHours: 68.0,
        avgDurationMinutes: 95.0,
        overallUtilizationPct: 72.8,
        peakHourLabel: '10:00 AM - 12:00 PM',
        activeSpacesCount: 34,
        totalSpacesCount: 48,
      );

      final usageState = SpaceBookingState(
        selectedDate: DateTime(2026, 3, 15),
        selectedNav: 'Usage & Reports',
        kpis: consistentKpis,
        analyticsReport: report,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spaceBookingProvider.overrideWith((ref) => _FakeSpaceBookingNotifier(usageState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SpaceBookingTabView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Usage & Reports analytics title is rendered
      expect(find.text('Space Utilization & Advanced Analytics'), findsOneWidget);

      // Verify consistent KPI values on Card 4
      expect(find.text('Campus Space Utilization'), findsOneWidget);
      expect(find.text('72.8%'), findsWidgets);
      expect(find.text('34 Active / 48 Bookable Spaces'), findsOneWidget);

      // Verify the right panel submission form is NOT rendered on Usage & Reports tab
      expect(find.byType(SpaceBookingRightPanel), findsNothing);
    });

    testWidgets('Usage & Reports tab renders dynamically for Today with 1 booking for 2 hours (KING)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));

      const todayReport = SpaceAnalyticsReport(
        totalBookings: 1,
        confirmedBookings: 1,
        pendingBookings: 0,
        rejectedBookings: 0,
        totalBookedHours: 2.0,
        avgDurationMinutes: 120.0,
        overallUtilizationPct: 0.6,
        peakHourLabel: '02:00 PM - 04:00 PM',
        activeSpacesCount: 1,
        totalSpacesCount: 166,
        mostActiveRoom: 'Grade 4 - Section A',
      );

      final todayUsageState = SpaceBookingState(
        selectedDate: DateTime(2026, 11, 20),
        selectedNav: 'Usage & Reports',
        kpis: consistentKpis,
        analyticsReport: todayReport,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spaceBookingProvider.overrideWith((ref) => _FakeSpaceBookingNotifier(todayUsageState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SpaceBookingTabView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Today dynamic values
      expect(find.text('02:00 PM - 04:00 PM'), findsOneWidget);
      expect(find.text('2 Hours'), findsOneWidget);
      expect(find.text('1 reservation'), findsOneWidget);
      expect(find.text('120 Minutes'), findsOneWidget);
      expect(find.text('0.6%'), findsWidgets);
      expect(find.text('1 Active / 166 Bookable Spaces'), findsOneWidget);
    });

    testWidgets('Clicking on empty grid slot triggers onCreateBooking with pre-selected room, date, and time slot', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));

      final testRoom = SpaceTimelineRoom(
        roomId: 'r-101',
        roomNumber: '101',
        roomCode: 'G-101',
        roomName: 'G-101',
        roomType: 'Classroom',
        capacity: 40,
        buildingId: 'b-1',
        buildingName: 'Academic Block (A)',
        buildingCode: 'B1',
        bookings: const [],
      );

      final state = SpaceBookingState(
        selectedDate: DateTime(2026, 11, 20),
        selectedNav: 'Booking Spaces',
        kpis: consistentKpis,
        roomsTimeline: [testRoom],
      );

      String? clickedRoomId;
      String? clickedRoomName;
      String? clickedStartTime;
      String? clickedEndTime;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spaceBookingProvider.overrideWith((ref) => _FakeSpaceBookingNotifier(state)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SpaceBookingCenterPanel(
                onCreateBooking: ({roomId, roomName, roomType, date, startTime, endTime}) {
                  clickedRoomId = roomId;
                  clickedRoomName = roomName;
                  clickedStartTime = startTime;
                  clickedEndTime = endTime;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the interactive grid slot tooltip for 10:00 AM
      final slotFinder = find.byTooltip('Click to schedule G-101 (10:00 AM - 11:00 AM)');
      expect(slotFinder, findsOneWidget);

      // Tap the empty slot
      await tester.tap(slotFinder);
      await tester.pump();

      // Verify callback triggered with exact pre-selected room and timing
      expect(clickedRoomId, 'r-101');
      expect(clickedRoomName, 'G-101');
      expect(clickedStartTime, '10:00 AM');
      expect(clickedEndTime, '11:00 AM');
    });

    test('Default selected date in SpaceBookingNotifier defaults to today', () {
      final notifier = _FakeSpaceBookingNotifier(SpaceBookingNotifier(SpaceBookingApiService.instance).state);
      final now = DateTime.now();
      expect(notifier.state.selectedDate.year, equals(now.year));
      expect(notifier.state.selectedDate.month, equals(now.month));
      expect(notifier.state.selectedDate.day, equals(now.day));
    });

    testWidgets('CreateEditBookingDialog displays Slot Free & Available when no conflict exists', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));

      const room = BookableRoomItem(
        id: 'r-101',
        name: 'G-101',
        roomNumber: '101',
        roomCode: 'G-101',
        roomType: 'Classroom',
        buildingId: 'b-1',
        buildingName: 'Academic Block (A)',
        buildingCode: 'B1',
        maxCapacity: 40,
      );

      final state = SpaceBookingState(
        selectedDate: DateTime(2026, 11, 20),
        selectedNav: 'Booking Spaces',
        kpis: consistentKpis,
        bookableRooms: [room],
        roomsTimeline: [
          SpaceTimelineRoom(
            roomId: 'r-101',
            roomNumber: '101',
            roomCode: 'G-101',
            roomName: 'G-101',
            roomType: 'Classroom',
            capacity: 40,
            buildingId: 'b-1',
            buildingName: 'Academic Block (A)',
            buildingCode: 'B1',
            bookings: const [], // empty, completely free
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spaceBookingProvider.overrideWith((ref) => _FakeSpaceBookingNotifier(state)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CreateEditBookingDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the Free & Available live card is rendered
      expect(find.text('Slot Free & Available'), findsOneWidget);
      expect(find.text('AVAILABLE'), findsOneWidget);
      expect(find.text('No conflicts detected. Space is available for the selected schedule.'), findsOneWidget);
    });

    testWidgets('CreateEditBookingDialog displays Slot Busy & Conflict Detected when colliding with an approved booking', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));

      const room = BookableRoomItem(
        id: 'r-101',
        name: 'G-101',
        roomNumber: '101',
        roomCode: 'G-101',
        roomType: 'Classroom',
        buildingId: 'b-1',
        buildingName: 'Academic Block (A)',
        buildingCode: 'B1',
        maxCapacity: 40,
      );

      final state = SpaceBookingState(
        selectedDate: DateTime(2026, 11, 20),
        selectedNav: 'Booking Spaces',
        kpis: consistentKpis,
        bookableRooms: [room],
        roomsTimeline: [
          SpaceTimelineRoom(
            roomId: 'r-101',
            roomNumber: '101',
            roomCode: 'G-101',
            roomName: 'G-101',
            roomType: 'Classroom',
            capacity: 40,
            buildingId: 'b-1',
            buildingName: 'Academic Block (A)',
            buildingCode: 'B1',
            bookings: [
              SpaceTimelineBooking(
                id: 'b-math-1',
                bookingRef: 'BK-001',
                title: 'Math Lecture',
                purpose: 'Lecture',
                organizerName: 'Prof. Ramanathan',
                organizerRole: 'Faculty',
                startTime: '02:00 PM',
                endTime: '04:00 PM',
                status: 'Approved',
              ),
            ],
          ),
        ],
      );

      // Default dialog has 02:00 PM to 04:00 PM, which directly overlaps with Math Lecture!
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spaceBookingProvider.overrideWith((ref) => _FakeSpaceBookingNotifier(state)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CreateEditBookingDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the Slot Busy • Conflict Detected live card is rendered
      expect(find.text('Slot Busy • Time Conflict Detected'), findsOneWidget);
      expect(find.text('COLLISION'), findsOneWidget);
      expect(find.textContaining('Math Lecture'), findsWidgets);
    });

    testWidgets('BookingDetailsDrawer renders Approval Conflict Alert when booking is in Conflict status', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));

      final conflictItem = SpaceBookingRequestItem(
        id: 'req-conflict-1',
        bookingRef: 'BK-CONF-01',
        title: 'Colliding Workshop',
        purpose: 'Workshop',
        category: 'Academic',
        priority: 'Normal',
        status: 'Conflict',
        isApproved: false,
        bookingDate: '2026-11-20',
        startTime: '02:00 PM',
        endTime: '04:00 PM',
        formattedSchedule: '02:00 PM - 04:00 PM',
        roomId: 'r-101',
        roomName: 'G-101',
        roomType: 'Classroom',
        spaceDisplay: '101 - G-101',
        buildingId: 'b-1',
        buildingName: 'Academic Block (A)',
        organizerName: 'Prof. Test',
        organizerRole: 'Faculty',
        requestedByDisplay: 'Prof. Test (Faculty)',
        attendeeCount: 30,
        isRecurring: false,
        rejectionReason: 'Time slot conflict with approved booking Math Lecture (02:00 PM - 04:00 PM)',
      );

      final state = SpaceBookingState(
        selectedDate: DateTime(2026, 11, 20),
        selectedNav: 'Booking Requests',
        kpis: consistentKpis,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spaceBookingProvider.overrideWith((ref) => _FakeSpaceBookingNotifier(state)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BookingDetailsDrawer(item: conflictItem),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Approval Conflict Alert banner is rendered
      expect(find.text('Approval Conflict Alert'), findsOneWidget);
      expect(find.text('DOUBLE-BOOKING DETECTED'), findsOneWidget);
      expect(find.textContaining('Math Lecture'), findsWidgets);

      // Verify Conflict status badge is rendered
      expect(find.text('Conflict'), findsWidgets);
    });
  });
}

class _FakeSpaceBookingNotifier extends SpaceBookingNotifier {
  _FakeSpaceBookingNotifier(SpaceBookingState initialState)
      : super(SpaceBookingApiService.instance) {
    state = initialState;
  }

  @override
  Future<void> loadAll() async {
    // Preserve injected test state
  }
}
