import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/visitors/providers/visitors_provider.dart';
import 'package:edu_shamiit_core/screens/visitors/services/visitors_api_service.dart';
import 'package:edu_shamiit_core/screens/visitors/models/visitor_models.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/dialogs/visitor_date_range_dialog.dart';

class MockDateRangeVisitorsApiService extends VisitorsApiService {
  String? lastDateFrom;
  String? lastDateTo;
  int getVisitsCallCount = 0;

  @override
  Future<Map<String, dynamic>> getVisits({
    String search = '',
    String location = 'All Locations',
    String category = 'All Visitor Types',
    String status = 'All Status',
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    getVisitsCallCount++;
    lastDateFrom = dateFrom;
    lastDateTo = dateTo;
    return {
      'records': <VisitorItem>[
        VisitorItem.fromJson({
          'id': 'v-yest-1',
          'visitor_id': 'vis-yest-1',
          'visitor_name': 'Yesterday Visitor',
          'visitor_type': 'Official',
          'phone': '9876543210',
          'location_name': 'Main Gate',
          'purpose': 'Audit',
          'status': 'Checked Out',
          'check_in_at': '2026-10-17T11:00:00Z',
          'pass_reference': 'GP-YEST-1',
          'visit_number': 99,
        }),
      ],
      'pagination': const VisitorPagination(
        page: 1,
        pageSize: 10,
        totalRecords: 1,
        totalPages: 1,
      ),
    };
  }

  @override
  Future<VisitorKPIs> getKPIs({
    String? dateFrom,
    String? dateTo,
    String? dateRangeLabel,
    String? location,
    String? category,
  }) async => const VisitorKPIs();
  @override
  Future<ScheduledKPIs> getScheduledKPIs({String? dateFrom, String? dateTo}) async => const ScheduledKPIs();
  @override
  Future<BlacklistKPIs> getBlacklistKPIs({String? dateFrom, String? dateTo}) async => const BlacklistKPIs();
  @override
  Future<Map<String, dynamic>> getAppointments({
    String search = '',
    String status = 'All',
    String? location,
    String? category,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async => {'records': <ScheduledAppointmentItem>[], 'pagination': const VisitorPagination()};
  @override
  Future<Map<String, dynamic>> getRestrictions({
    String search = '',
    String status = 'All',
    String? location,
    String? category,
    String? reason,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async => {'records': <BlacklistedVisitorItem>[], 'pagination': const VisitorPagination()};
  @override
  Future<VisitorAnalyticsData> getAnalytics() async => const VisitorAnalyticsData();
  @override
  Future<List<Map<String, dynamic>>> getLocations() async => [];
}

void main() {
  test('VisitorsNotifier forwards date_from and date_to when setDateRangeFilter is invoked', () async {
    final mockApi = MockDateRangeVisitorsApiService();
    final notifier = VisitorsNotifier(mockApi);

    // Initial state: "All Time" by default with null dates
    expect(notifier.state.selectedDateRange, 'All Time');
    expect(notifier.state.startDate, isNull);
    expect(notifier.state.endDate, isNull);

    // Filter by Yesterday (17 Oct 2026)
    final yesterdayStart = DateTime(2026, 10, 17, 0, 0, 0);
    final yesterdayEnd = DateTime(2026, 10, 17, 23, 59, 59);

    notifier.setDateRangeFilter(
      'Yesterday',
      startDate: yesterdayStart,
      endDate: yesterdayEnd,
    );

    expect(notifier.state.selectedDateRange, 'Yesterday');
    expect(notifier.state.startDate, yesterdayStart);
    expect(notifier.state.endDate, yesterdayEnd);

    // Verify mockApi received the ISO formatted bounds in UTC
    expect(mockApi.lastDateFrom, yesterdayStart.toUtc().toIso8601String());
    expect(mockApi.lastDateTo, yesterdayEnd.toUtc().toIso8601String());

    // Reset filters
    notifier.resetFilters();
    expect(notifier.state.selectedDateRange, 'All Time');
    expect(notifier.state.startDate, isNull);
    expect(notifier.state.endDate, isNull);
    expect(mockApi.lastDateFrom, isNull);
    expect(mockApi.lastDateTo, isNull);
  });

  test('VisitorsNotifier forwards page_size when changing rows per page', () async {
    final mockApi = MockDateRangeVisitorsApiService();
    final notifier = VisitorsNotifier(mockApi);

    await notifier.fetchVisits(page: 1, pageSize: 25);
    expect(notifier.state.pagination.pageSize, 25);
  });

  testWidgets('VisitorDateRangeDialog renders presets, calendar, and time boundaries', (tester) async {
    final mockApi = MockDateRangeVisitorsApiService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitorsApiServiceProvider.overrideWithValue(mockApi),
          visitorsProvider.overrideWith((ref) => VisitorsNotifier(mockApi)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: VisitorDateRangeDialog(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify dialog header
    expect(find.text('Date & Time Range Selection'), findsOneWidget);
    expect(find.text('QUICK PRESETS'), findsOneWidget);

    // Verify presets (both preset item and calendar button contain 'Today')
    expect(find.text('Today'), findsNWidgets(2));
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Last 7 Days'), findsOneWidget);
    expect(find.text('Last 30 Days'), findsOneWidget);
    expect(find.text('This Month'), findsOneWidget);
    expect(find.text('Last Month'), findsOneWidget);
    expect(find.text('Academic Year'), findsNothing);
    expect(find.text('All Time'), findsOneWidget);

    // Verify Time controls
    expect(find.text('From Time'), findsOneWidget);
    expect(find.text('To Time'), findsOneWidget);
    expect(find.text('Apply Filter'), findsOneWidget);

    // Tap "Yesterday" preset
    await tester.tap(find.text('Yesterday'));
    await tester.pumpAndSettle();

    // Tap "Apply Filter"
    await tester.tap(find.text('Apply Filter'));
    await tester.pumpAndSettle();

    // Verify mockApi was called with yesterday date bounds
    expect(mockApi.lastDateFrom, isNotNull);
    expect(mockApi.lastDateTo, isNotNull);
  });
}
