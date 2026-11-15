import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/visitors/providers/visitors_provider.dart';
import 'package:edu_shamiit_core/screens/visitors/services/visitors_api_service.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/visitors_data_table.dart';
import 'package:edu_shamiit_core/screens/visitors/models/visitor_models.dart';

class MockBulkVisitorsApiService extends VisitorsApiService {
  int bulkCheckOutCallCount = 0;
  List<String> lastVisitIds = [];

  @override
  Future<Map<String, dynamic>> bulkCheckOutVisits(
    List<String> visitIds, {
    String exitLocation = 'Main Gate',
    String? remarks,
  }) async {
    bulkCheckOutCallCount++;
    lastVisitIds = visitIds;
    return {
      'success': true,
      'data': {
        'total': visitIds.length,
        'checked_out_count': visitIds.length,
        'already_checked_out_count': 0,
        'failed_count': 0,
        'message': 'Successfully checked out ${visitIds.length} visitor(s).',
      },
    };
  }

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
      'records': [
        VisitorItem.fromJson({
          'id': 'v-101',
          'visitor_id': 'vis-1',
          'visitor_name': 'Rahul Verma',
          'visitor_type': 'Parent',
          'phone': '9876543210',
          'location_name': 'Main Gate',
          'purpose': 'Fee Inquiry',
          'status': 'Inside',
          'check_in_at': '2026-10-18T10:00:00Z',
          'pass_reference': 'GP-101',
          'visit_number': 101,
        }),
        VisitorItem.fromJson({
          'id': 'v-102',
          'visitor_id': 'vis-2',
          'visitor_name': 'Priya Singh',
          'visitor_type': 'Vendor',
          'phone': '9876543211',
          'location_name': 'Director Office',
          'purpose': 'Hardware Delivery',
          'status': 'Inside',
          'check_in_at': '2026-10-18T10:30:00Z',
          'pass_reference': 'GP-102',
          'visit_number': 102,
        }),
      ],
      'pagination': const VisitorPagination(
        page: 1,
        pageSize: 10,
        totalRecords: 2,
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
  }) async {
    return VisitorKPIs.fromJson({
      'total_month': 200,
      'on_campus_now': 2,
      'today_total': 15,
      'completed_today': 13,
      'overstaying_count': 0,
      'expected_today': 5,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getLocations() async {
    return [
      {'name': 'Main Gate'},
      {'name': 'Director Office'},
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Visitor Bulk Actions & QR Printing Tests', () {
    test('bulkCheckOutVisits invokes API once atomically without individual item loops', () async {
      final mockApi = MockBulkVisitorsApiService();
      final container = ProviderContainer(
        overrides: [
          visitorsApiServiceProvider.overrideWithValue(mockApi),
        ],
      );

      final notifier = container.read(visitorsProvider.notifier);
      final success = await notifier.bulkCheckOutVisits(['v-101', 'v-102']);

      expect(success, isTrue);
      expect(mockApi.bulkCheckOutCallCount, equals(1));
      expect(mockApi.lastVisitIds, equals(['v-101', 'v-102']));
      expect(
        container.read(visitorsProvider).successMessage,
        equals('Successfully checked out 2 visitor(s).'),
      );
    });

    testWidgets('VisitorsDataTable does not have duplicate Export CSV in bulk actions dropdown', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockApi = MockBulkVisitorsApiService();
      final container = ProviderContainer(
        overrides: [
          visitorsApiServiceProvider.overrideWithValue(mockApi),
        ],
      );

      // Preload visits
      await container.read(visitorsProvider.notifier).fetchVisits();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  height: 900,
                  child: VisitorsDataTable(
                    onSelectVisitor: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Outer Export CSV button exists
      expect(find.text('Export CSV'), findsOneWidget);

      // Open Bulk Actions popup
      final bulkActionsBtn = find.byTooltip('Bulk Actions');
      expect(bulkActionsBtn, findsOneWidget);
      await tester.tap(bulkActionsBtn);
      await tester.pumpAndSettle();

      // Inside dropdown: Bulk Check-Out, Print Selected Passes, Clear Selection exist
      expect(find.text('Bulk Check-Out Selected'), findsOneWidget);
      expect(find.text('Print Selected Passes'), findsOneWidget);
      expect(find.text('Clear Selection'), findsOneWidget);

      // Duplicate 'Export Selected to CSV' MUST NOT exist
      expect(find.text('Export Selected to CSV'), findsNothing);
    });

    test('Batch pass dictionary contains all required attributes for QR and pass rendering', () {
      final item = VisitorItem.fromJson({
        'id': 'v-101',
        'school_id': 'sch-1',
        'visitor_id': 'vis-1',
        'visitor_name': 'Rahul Verma',
        'visitor_type': 'Parent',
        'phone': '9876543210',
        'location_name': 'Main Gate',
        'purpose': 'Fee Inquiry',
        'status': 'Inside',
        'check_in_at': '18 Oct 2026 10:00 AM',
        'expected_out_at': '18 Oct 2026 12:00 PM',
        'pass_reference': 'GP-101',
        'visit_number': 101,
      });

      final passMap = {
        'pass_number': item.passReference!.isNotEmpty ? item.passReference! : 'GP-${item.visitNumber}',
        'passNumber': item.passReference!.isNotEmpty ? item.passReference! : 'GP-${item.visitNumber}',
        'visitor_name': item.visitorName,
        'visitorName': item.visitorName,
        'visitor_type': item.visitorType,
        'visitorType': item.visitorType,
        'phone': item.phone,
        'destination': item.location,
        'host_name': item.hostName,
        'hostName': item.hostName,
        'hostDepartment': item.hostDepartment,
        'check_in_at': item.checkInAt,
        'checkInAt': item.checkInAt,
        'expires_at': item.expectedOutAt,
        'validUntil': item.expectedOutAt,
        'status': item.status,
      };

      expect(passMap['passNumber'], equals('GP-101'));
      expect(passMap['visitorName'], equals('Rahul Verma'));
      expect(passMap['visitorType'], equals('Parent'));
      expect(passMap['validUntil'], equals('18 Oct 2026 12:00 PM'));
      expect(passMap['checkInAt'], equals('18 Oct 2026 10:00 AM'));
      expect(passMap['destination'], equals('Main Gate'));
    });
  });
}
