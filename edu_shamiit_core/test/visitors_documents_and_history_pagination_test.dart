import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/visitors/providers/visitors_provider.dart';
import 'package:edu_shamiit_core/screens/visitors/services/visitors_api_service.dart';
import 'package:edu_shamiit_core/screens/visitors/models/visitor_models.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/tabs/all_visitors_tab.dart';

class MockPaginationVisitorsApiService extends VisitorsApiService {
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
    return {
      'records': <VisitorItem>[
        VisitorItem.fromJson({
          'id': 'v-test-1',
          'visitor_id': 'vis-1',
          'visitor_name': 'Dr. Rajeshwar Sharma',
          'visitor_type': 'Official',
          'phone': '+91 9876543210',
          'location_name': 'Director Office',
          'purpose': 'Official Audit',
          'status': 'Checked Out',
          'check_in_at': '2026-10-18T12:31:00Z',
          'pass_reference': 'GP-101',
          'visit_number': 101,
        }),
      ],
      'pagination': const VisitorPagination(page: 1, pageSize: 10, totalRecords: 1, totalPages: 1),
    };
  }

  @override
  Future<VisitorDetail360?> getVisitDetails(String visitId) async {
    // Generate 11 history items (like in user screenshot) and 7 documents
    return VisitorDetail360.fromJson({
      'visitor': {
        'id': 'vis-1',
        'full_name': 'Dr. Rajeshwar Sharma',
        'phone': '+91 9876543210',
        'email': 'dr.sharma@research.org',
        'visitor_type': 'Official',
        'id_type': 'Govt Issued ID',
        'id_number_masked': 'NRAC-88992-DL',
      },
      'visit': {
        'id': 'v-test-1',
        'visit_number': 101,
        'purpose': 'Official Audit',
        'location': 'Director Office',
        'host_name': 'Director Dr. K. N. Murthy',
        'check_in_at': '2026-10-18T12:31:00Z',
        'expected_out_at': '2026-10-18T14:31:00Z',
        'status': 'Checked Out',
        'duration_text': '2 hrs',
      },
      'documents': List.generate(
        7,
        (i) => {
          'id': 'doc-$i',
          'document_name': 'Identity_Document_${i + 1}.pdf',
          'document_type': 'Govt ID',
          'verification_status': 'VERIFIED',
          'file_url': 'https://example.com/doc$i.pdf',
        },
      ),
      'visit_history': List.generate(
        11,
        (i) => {
          'id': 'v-hist-$i',
          'visit_number': 100 - i,
          'purpose': 'Official Audit Session #${i + 1}',
          'host_name': 'Director Dr. K. N. Murthy',
          'destination': 'Director Office',
          'check_in_at': '2026-10-18T10:00:00Z',
          'status': 'Checked Out',
          'is_current': i == 0,
        },
      ),
    });
  }

  @override
  Future<VisitorKPIs> getKPIs({
    String? dateFrom,
    String? dateTo,
    String? dateRangeLabel,
    String? location,
    String? category,
    String? search,
  }) async => const VisitorKPIs();
  @override
  Future<ScheduledKPIs> getScheduledKPIs({String? dateFrom, String? dateTo, String? location, String? category, String? search}) async => const ScheduledKPIs();
  @override
  Future<BlacklistKPIs> getBlacklistKPIs({String? dateFrom, String? dateTo, String? location, String? reason, String? search}) async => const BlacklistKPIs();
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
  testWidgets('AllVisitorsTab paginates Visit History (11 items) into 5 per page with navigation', (tester) async {
    final mockApi = MockPaginationVisitorsApiService();

    tester.view.physicalSize = const Size(1600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final notifier = VisitorsNotifier(mockApi);
    await notifier.init();
    await notifier.openVisitDetail(notifier.state.visits.first);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitorsApiServiceProvider.overrideWithValue(mockApi),
          visitorsProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AllVisitorsTab(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Tab Header with 11 history items
    expect(find.text('Visit History (11)'), findsOneWidget);

    // Click Visit History tab
    await tester.tap(find.text('Visit History (11)'));
    await tester.pumpAndSettle();

    // On page 1: Should show "1-5 of 11" and "1/3"
    expect(find.text('1-5 of 11'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('Official Audit Session #1'), findsOneWidget);
    expect(find.text('Official Audit Session #5'), findsOneWidget);
    // Session 6 should not be on page 1
    expect(find.text('Official Audit Session #6'), findsNothing);

    // Tap next page ">"
    await tester.tap(find.byKey(const Key('tab_history_next')));
    await tester.pumpAndSettle();

    // On page 2: Should show "6-10 of 11" and "2/3"
    expect(find.text('6-10 of 11'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('Official Audit Session #6'), findsOneWidget);
    expect(find.text('Official Audit Session #10'), findsOneWidget);
    expect(find.text('Official Audit Session #1'), findsNothing);

    // Tap next page ">" to page 3
    await tester.tap(find.byKey(const Key('tab_history_next')));
    await tester.pumpAndSettle();

    // On page 3: Should show "11-11 of 11" and "3/3"
    expect(find.text('11-11 of 11'), findsOneWidget);
    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('Official Audit Session #11'), findsOneWidget);
    expect(find.text('Official Audit Session #6'), findsNothing);

    // Now test Documents tab pagination (7 documents)
    expect(find.text('Documents (7)'), findsOneWidget);
    await tester.tap(find.text('Documents (7)'));
    await tester.pumpAndSettle();

    // On page 1: Should show "1-5 of 7" and "1/2"
    expect(find.text('1-5 of 7'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Identity_Document_1.pdf'), findsOneWidget);
    expect(find.text('Identity_Document_5.pdf'), findsOneWidget);
    expect(find.text('Identity_Document_6.pdf'), findsNothing);

    // Tap next page ">" for documents
    await tester.tap(find.byKey(const Key('tab_docs_next')));
    await tester.pumpAndSettle();

    // On page 2: Should show "6-7 of 7" and "2/2"
    expect(find.text('6-7 of 7'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Identity_Document_6.pdf'), findsOneWidget);
    expect(find.text('Identity_Document_7.pdf'), findsOneWidget);
    expect(find.text('Identity_Document_1.pdf'), findsNothing);
  });
}
