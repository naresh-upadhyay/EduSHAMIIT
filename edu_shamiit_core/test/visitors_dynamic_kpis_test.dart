import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/visitors/models/visitor_models.dart';
import 'package:edu_shamiit_core/screens/visitors/providers/visitors_provider.dart';
import 'package:edu_shamiit_core/screens/visitors/services/visitors_api_service.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/visitors_kpi_cards.dart';

class MockDynamicKpiApiService extends VisitorsApiService {
  String? lastDateFrom;
  String? lastDateTo;
  String? lastDateRangeLabel;
  String? lastLocation;
  String? lastCategory;

  VisitorKPIs mockKpis = const VisitorKPIs(
    totalVisitors: 329,
    totalTrend: '+12%',
    totalSubtitle: 'All Time',
    currentlyInside: 53,
    currentlyInsideSubtitle: 'On campus now',
    checkedInToday: 21,
    checkedInTodaySubtitle: 'Till now',
    checkedOutToday: 18,
    checkedOutTodaySubtitle: 'Completed visits',
    overstay: 53,
    overstaySubtitle: 'Exceeding allowed time',
    scheduledToday: 4,
    scheduledTodaySubtitle: 'Upcoming visitors',
  );

  @override
  Future<VisitorKPIs> getKPIs({
    String? dateFrom,
    String? dateTo,
    String? dateRangeLabel,
    String? location,
    String? category,
    String? search,
  }) async {
    lastDateFrom = dateFrom;
    lastDateTo = dateTo;
    lastDateRangeLabel = dateRangeLabel;
    lastLocation = location;
    lastCategory = category;
    return mockKpis;
  }

  @override
  Future<ScheduledKPIs> getScheduledKPIs({String? dateFrom, String? dateTo, String? location, String? category, String? search}) async => const ScheduledKPIs();
  @override
  Future<BlacklistKPIs> getBlacklistKPIs({String? dateFrom, String? dateTo, String? location, String? reason, String? search}) async => const BlacklistKPIs();
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
  }) async => {'records': <VisitorItem>[], 'pagination': const VisitorPagination()};
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
  group('Dynamic Visitor KPIs & Drill-down Integration Tests', () {
    testWidgets('VisitorsKPICards renders dynamic values and handles drill-down taps correctly', (tester) async {
      final mockApi = MockDynamicKpiApiService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitorsApiServiceProvider.overrideWithValue(mockApi),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VisitorsKPICards(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all 6 cards render with correct dynamic values
      expect(find.text('Total Visitors'), findsOneWidget);
      expect(find.text('329'), findsOneWidget);
      expect(find.text('+12%'), findsOneWidget);
      expect(find.text('All Time'), findsOneWidget);

      expect(find.text('Currently Inside'), findsOneWidget);
      expect(find.text('On campus now'), findsOneWidget);

      expect(find.text('Checked In Today'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      expect(find.text('Till now'), findsOneWidget);

      expect(find.text('Checked Out Today'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('Completed visits'), findsOneWidget);

      expect(find.text('Overstay'), findsOneWidget);
      expect(find.text('Exceeding allowed time'), findsOneWidget);

      expect(find.text('Scheduled Today'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Upcoming visitors'), findsOneWidget);

      // Tap Currently Inside card
      await tester.tap(find.text('Currently Inside'));
      await tester.pumpAndSettle();

      // Tap Overstay card
      await tester.tap(find.text('Overstay'));
      await tester.pumpAndSettle();

      // Tap Checked In Today card
      await tester.tap(find.text('Checked In Today'));
      await tester.pumpAndSettle();

      // Tap Checked Out Today card
      await tester.tap(find.text('Checked Out Today'));
      await tester.pumpAndSettle();
    });

    test('VisitorsNotifier passes date filters and location to getKPIs', () async {
      final mockApi = MockDynamicKpiApiService();
      final container = ProviderContainer(
        overrides: [
          visitorsApiServiceProvider.overrideWithValue(mockApi),
        ],
      );

      final notifier = container.read(visitorsProvider.notifier);
      await container.pump();

      // Change date range filter
      final start = DateTime(2026, 10, 17);
      final end = DateTime(2026, 10, 17, 23, 59, 59);
      notifier.setDateRangeFilter('Yesterday', startDate: start, endDate: end);
      await container.pump();

      expect(mockApi.lastDateRangeLabel, equals('Yesterday'));
      expect(mockApi.lastDateFrom, equals(start.toUtc().toIso8601String()));
      expect(mockApi.lastDateTo, equals(end.toUtc().toIso8601String()));

      // Change location filter
      notifier.setLocationFilter('Library');
      await container.pump();
      expect(mockApi.lastLocation, equals('Library'));

      // Change category filter
      notifier.setCategoryFilter('Vendor');
      await container.pump();
      expect(mockApi.lastCategory, equals('Vendor'));
    });
  });
}
