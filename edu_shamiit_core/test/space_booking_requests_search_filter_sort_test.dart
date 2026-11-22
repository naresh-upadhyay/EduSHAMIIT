import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/models/space_booking_models.dart';
import 'package:edu_shamiit_core/screens/campus/providers/space_booking_provider.dart';
import 'package:edu_shamiit_core/screens/campus/services/space_booking_api_service.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/dialogs/space_conflict_warning_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/space_booking/dialogs/create_edit_booking_dialog.dart';

class MockSpaceBookingApiService implements SpaceBookingApiService {
  String? lastSortBy;
  String? lastSortOrder;
  String? lastSearch;
  String? lastBuildingId;
  String? lastRoomType;
  String? lastPurpose;
  int lastPage = 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<SpaceBookingListResponse> getRequests({
    String? status,
    String? buildingId,
    String? roomType,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int pageSize = 10,
    String? purpose,
    String? priority,
    String? sortBy,
    String? sortOrder,
  }) async {
    lastSortBy = sortBy;
    lastSortOrder = sortOrder;
    lastSearch = search;
    lastBuildingId = buildingId;
    lastRoomType = roomType;
    lastPurpose = purpose;
    lastPage = page;

    return SpaceBookingListResponse(
      items: [
        const SpaceBookingRequestItem(
          id: 'test-1',
          bookingRef: 'BK-001',
          title: 'Mathematics Seminar',
          purpose: 'Academic',
          category: 'Academic',
          priority: 'Normal',
          status: 'Pending',
          isApproved: false,
          bookingDate: '2026-11-22',
          startTime: '10:00 AM',
          endTime: '11:00 AM',
          formattedSchedule: '2026-11-22 10:00 AM - 11:00 AM',
          roomId: 'room-1',
          roomName: 'Classroom 101',
          roomType: 'Classroom',
          spaceDisplay: 'Classroom 101 (Classroom)',
          buildingId: 'b-1',
          buildingName: 'Academic Block A',
          organizerName: 'Dr. Euler',
          organizerRole: 'Faculty',
          requestedByDisplay: 'Dr. Euler (Faculty)',
          attendeeCount: 40,
          isRecurring: false,
        ),
      ],
      totalCount: 1,
      page: page,
      pageSize: pageSize,
      totalPages: 1,
    );
  }

  @override
  Future<SpaceBookingKpis> getKpis({DateTime? date}) async => const SpaceBookingKpis();

  @override
  Future<List<SpaceTimelineRoom>> getTimeline({
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String? buildingId,
    String? roomType,
  }) async => [];

  @override
  Future<SpaceUtilizationStats> getUtilizationStats({DateTime? date}) async => const SpaceUtilizationStats();

  @override
  Future<List<BookableRoomItem>> getBookableRooms({String? buildingId, String? roomType}) async => [];

  @override
  Future<SpaceAnalyticsReport> getAnalyticsReport({String? buildingId, String timeframe = 'today', DateTime? date}) async =>
      const SpaceAnalyticsReport();

  @override
  Future<List<SpaceRequesterProfile>> getRequesters({String? search, String? role}) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Space Booking Requests - Server-Side Sorting & Filters', () {
    late MockSpaceBookingApiService mockService;
    late SpaceBookingNotifier notifier;

    setUp(() {
      mockService = MockSpaceBookingApiService();
      notifier = SpaceBookingNotifier(mockService);
    });

    test('Initial state has default sort_by=booking_date and sort_order=ASC', () {
      expect(notifier.state.sortBy, 'booking_date');
      expect(notifier.state.sortOrder, 'ASC');
    });

    test('setSorting toggles order from ASC to DESC on same column', () async {
      await notifier.setSorting('booking_date');
      expect(notifier.state.sortBy, 'booking_date');
      expect(notifier.state.sortOrder, 'DESC');
      expect(mockService.lastSortBy, 'booking_date');
      expect(mockService.lastSortOrder, 'DESC');

      await notifier.setSorting('booking_date');
      expect(notifier.state.sortOrder, 'ASC');
      expect(mockService.lastSortOrder, 'ASC');
    });

    test('setSorting switches to new column with default ASC', () async {
      await notifier.setSorting('title');
      expect(notifier.state.sortBy, 'title');
      expect(notifier.state.sortOrder, 'ASC');
      expect(mockService.lastSortBy, 'title');
      expect(mockService.lastSortOrder, 'ASC');
    });

    test('setSearchQuery updates state and calls service with query', () async {
      await notifier.setSearchQuery('Annual Science Fair');
      expect(notifier.state.searchQuery, 'Annual Science Fair');
      expect(mockService.lastSearch, 'Annual Science Fair');
      expect(notifier.state.currentPage, 1);
    });

    test('setBuildingFilter, setSpaceTypeFilter, setPurposeFilter apply cleanly', () async {
      await notifier.setBuildingFilter('b-block-c');
      expect(notifier.state.selectedBuildingId, 'b-block-c');
      expect(mockService.lastBuildingId, 'b-block-c');

      await notifier.setSpaceTypeFilter('Auditorium');
      expect(notifier.state.selectedSpaceType, 'Auditorium');
      expect(mockService.lastRoomType, 'Auditorium');

      await notifier.setPurposeFilter('Workshop');
      expect(notifier.state.selectedPurpose, 'Workshop');
      expect(mockService.lastPurpose, 'Workshop');
    });

    test('clearAllRequestsFilters resets all filter state to defaults', () async {
      await notifier.setSearchQuery('Workshop');
      await notifier.setBuildingFilter('b-1');
      await notifier.setSorting('title');
      expect(notifier.state.searchQuery, 'Workshop');

      await notifier.clearAllRequestsFilters();
      expect(notifier.state.searchQuery, '');
      expect(notifier.state.selectedBuildingId, 'all');
      expect(notifier.state.selectedSpaceType, 'All');
      expect(notifier.state.selectedPurpose, 'All');
      expect(notifier.state.sortBy, 'booking_date');
      expect(notifier.state.sortOrder, 'ASC');
    });
  });

  group('Space Conflict Warning Dialog & Dropdown Safety', () {
    testWidgets('SpaceConflictWarningDialog dismisses without crashing and invokes onChangeTime', (tester) async {
      bool changeTimeInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (dCtx) => SpaceConflictWarningDialog(
                      roomName: 'Classroom 101',
                      requestedTime: '2026-11-22 (10:00 AM - 11:30 AM)',
                      conflictMessage: 'Collides with existing event',
                      onChangeTime: () {
                        changeTimeInvoked = true;
                      },
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Space Booking Conflict'), findsOneWidget);
      expect(find.text('Change Time / Room'), findsOneWidget);

      await tester.tap(find.text('Change Time / Room'));
      await tester.pumpAndSettle();

      expect(changeTimeInvoked, isTrue);
      expect(find.text('Space Booking Conflict'), findsNothing);
    });

    testWidgets('CreateEditBookingDialog renders safely with arbitrary purpose without dropdown assertion', (tester) async {
      const customItem = SpaceBookingRequestItem(
        id: 'item-custom-purpose',
        bookingRef: 'BK-999',
        title: 'Robotics Showcase',
        purpose: 'NonStandardCustomPurpose',
        category: 'Academic',
        priority: 'High',
        status: 'Pending',
        isApproved: false,
        bookingDate: '2026-11-22',
        startTime: '08:00 AM',
        endTime: '09:00 AM',
        formattedSchedule: '2026-11-22 08:00 AM - 09:00 AM',
        roomId: '',
        roomName: 'Main Hall',
        roomType: 'Auditorium',
        spaceDisplay: 'Main Hall (Auditorium)',
        buildingId: '',
        buildingName: 'Main',
        organizerName: 'Robotics Club',
        organizerRole: 'CustomClubRep',
        requestedByDisplay: 'Robotics Club (CustomClubRep)',
        attendeeCount: 50,
        isRecurring: false,
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CreateEditBookingDialog(
                initialItem: customItem,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Robotics Showcase'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
