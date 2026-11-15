import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/visitors/providers/visitors_provider.dart';
import 'package:edu_shamiit_core/screens/visitors/services/visitors_api_service.dart';
import 'package:edu_shamiit_core/screens/visitors/models/visitor_models.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/tabs/scheduled_visitors_tab.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/tabs/blacklisted_visitors_tab.dart';

class MockFullVisitorsApiService extends VisitorsApiService {
  String? lastApptDateFrom;
  String? lastApptDateTo;
  String? lastApptLocation;
  String? lastApptCategory;

  String? lastRestDateFrom;
  String? lastRestDateTo;

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
  }) async {
    lastApptDateFrom = dateFrom;
    lastApptDateTo = dateTo;
    lastApptLocation = location;
    lastApptCategory = category;

    return {
      'records': <ScheduledAppointmentItem>[
        ScheduledAppointmentItem.fromJson({
          'id': 'appt-1',
          'appointment_id': 'APT-901',
          'visitor_id': 'vis-901',
          'visitor_name': 'Prof. A. K. Sen',
          'visitor_type': 'Academic',
          'phone': '+91 9988776655',
          'email': 'prof.sen@univ.ac.in',
          'id_type': 'University ID',
          'id_number_masked': 'UNIV-***-89',
          'host_name': 'Dr. K. N. Murthy',
          'host_department': 'Academics',
          'purpose': 'Guest Lecture',
          'location': 'Auditorium Gate 1',
          'location_name': 'Auditorium Gate 1',
          'scheduled_date': '2026-10-18',
          'scheduled_time': '10:00 AM - 11:30 AM',
          'start_time': '10:00:00',
          'end_time': '11:30:00',
          'status': 'Confirmed',
          'pass_reference': 'GP-APPT-901',
          'created_at': '2026-10-15T09:00:00Z',
        }),
      ],
      'pagination': const VisitorPagination(page: 1, pageSize: 10, totalRecords: 1, totalPages: 1),
    };
  }

  @override
  Future<AppointmentDetail360?> getAppointmentDetails(String appointmentId) async {
    // Generate 7 documents and 8 history records to test pagination
    return AppointmentDetail360.fromJson({
      'appointment': {
        'id': 'appt-1',
        'appointment_id': 'APT-901',
        'visitor_name': 'Prof. A. K. Sen',
        'status': 'Confirmed',
        'location': 'Auditorium Gate 1',
      },
      'documents': List.generate(7, (i) => {
        'document_name': 'Academic Document ${i + 1}',
        'document_type': 'Verification Form',
        'file_name': 'doc_${i + 1}.pdf',
        'is_verified': true,
        'status': 'Verified',
        'uploaded_at': '2026-10-18 09:00',
      }),
      'visit_history': List.generate(8, (i) => {
        'purpose': 'Academic Meeting ${i + 1}',
        'destination': 'Auditorium Gate 1',
        'host_name': 'Dr. K. N. Murthy',
        'status': 'Completed',
        'check_in_at': '2026-10-18 10:0$i AM',
      }),
      'related_appointments': [
        {
          'id': 'appt-2',
          'visitor_name': 'Dr. S. Roy (Co-speaker)',
          'location': 'Auditorium Gate 1',
          'status': 'Confirmed',
          'scheduled_time': '11:30 AM',
        }
      ],
    });
  }

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
  }) async {
    lastRestDateFrom = dateFrom;
    lastRestDateTo = dateTo;

    return {
      'records': <BlacklistedVisitorItem>[
        BlacklistedVisitorItem.fromJson({
          'id': 'rest-1',
          'visitor_id': 'vis-99',
          'visitor_name': 'Ramesh Kumar',
          'phone': '+91 9123456780',
          'email': 'ramesh@fake.com',
          'id_type': 'Aadhaar Card',
          'id_number_masked': 'XXXX-XXXX-9999',
          'restriction_type': 'Blacklist',
          'reason_category': 'Behavioral Misconduct',
          'reason': 'Repeated gate trespassing',
          'remarks': 'Barred indefinitely by Admin',
          'status': 'Active',
          'effective_from': '2026-05-10',
          'effective_to': null,
          'scope': 'Campus Wide',
          'scope_name': 'All Gates',
          'incident_reference': 'INC-2026-009',
          'created_at': '2026-05-10T08:00:00Z',
          'confidential_notes': 'High priority alert',
        }),
      ],
      'pagination': const VisitorPagination(page: 1, pageSize: 10, totalRecords: 1, totalPages: 1),
    };
  }

  @override
  Future<RestrictionDetail360?> getRestrictionDetails(String restrictionId) async {
    return RestrictionDetail360.fromJson({
      'restriction': {
        'id': 'rest-1',
        'visitor_name': 'Ramesh Kumar',
        'status': 'Active',
      },
      'documents': List.generate(6, (i) => {
        'document_name': 'Incident FIR Document ${i + 1}',
        'document_type': 'Security Report',
        'file_name': 'fir_${i + 1}.pdf',
        'status': 'Confidential',
        'is_verified': true,
        'uploaded_at': '2026-05-10',
      }),
      'history': List.generate(7, (i) => {
        'performed_at': '2026-05-1$i 14:00',
        'action': 'Disciplinary Hearing Event ${i + 1}',
        'reason': 'Action logged by Proctorial Board ${i + 1}',
      }),
      'attempted_entries': List.generate(9, (i) => {
        'attempted_at': '2026-10-1$i 08:30 AM',
        'location': 'Gate ${i + 1}',
        'action_taken': 'Denied & Turned Back',
      }),
    });
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
  Future<ScheduledKPIs> getScheduledKPIs({String? dateFrom, String? dateTo}) async {
    return ScheduledKPIs.fromJson({
      'total_scheduled': 45,
      'today_count': 12,
      'this_week': 28,
      'expected_today': 7,
      'pending_count': 3,
    });
  }

  @override
  Future<BlacklistKPIs> getBlacklistKPIs({String? dateFrom, String? dateTo}) async {
    return BlacklistKPIs.fromJson({
      'total_blocked': 18,
      'active_blocks': 14,
      'expired_blocks': 4,
      'attempted_entries': 9,
    });
  }

  @override
  Future<VisitorAnalyticsData> getAnalytics() async => const VisitorAnalyticsData();

  @override
  Future<List<Map<String, dynamic>>> getLocations() async => [
    {'name': 'All Gates'},
    {'name': 'Auditorium Gate 1'},
  ];
}

void main() {
  testWidgets('ScheduledVisitorsTab renders dynamic documents & history pagination and handles page turns', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2000));
    tester.view.physicalSize = const Size(1800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetPhysicalSize();
    });

    final mockApi = MockFullVisitorsApiService();
    final notifier = VisitorsNotifier(mockApi);
    await notifier.init();
    notifier.setActiveTab(1);
    await notifier.openAppointmentDetail(notifier.state.appointments.first);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitorsApiServiceProvider.overrideWithValue(mockApi),
          visitorsProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ScheduledVisitorsTab(),
          ),
        ),
      ),
    );

    // Initial pump & settle
    await tester.pumpAndSettle();

    // Verify appointment item is listed
    expect(find.text('Prof. A. K. Sen'), findsWidgets);

    // Verify dynamic sub-tabs show correct counts: Documents (7) and Visit History (8)
    expect(find.text('Documents (7)'), findsOneWidget);
    expect(find.text('Visit History (8)'), findsOneWidget);

    // Tap on Visit History sub-tab
    await tester.ensureVisible(find.text('Visit History (8)'));
    await tester.tap(find.text('Visit History (8)'));
    await tester.pumpAndSettle();

    // Page 1 should show 1-5 of 8
    expect(find.text('1-5 of 8'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Academic Meeting 1'), findsOneWidget);
    expect(find.text('Academic Meeting 5'), findsOneWidget);
    expect(find.text('Academic Meeting 6'), findsNothing);

    // Turn to page 2 via nextKey
    final nextBtn = find.byKey(const Key('appt_history_next'));
    expect(nextBtn, findsOneWidget);
    await tester.ensureVisible(nextBtn);
    await tester.tap(nextBtn);
    await tester.pumpAndSettle();

    // Page 2 should show 6-8 of 8
    expect(find.text('6-8 of 8'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Academic Meeting 6'), findsOneWidget);
    expect(find.text('Academic Meeting 8'), findsOneWidget);
    expect(find.text('Academic Meeting 1'), findsNothing);

    // Tap on Documents sub-tab
    await tester.ensureVisible(find.text('Documents (7)'));
    await tester.tap(find.text('Documents (7)'));
    await tester.pumpAndSettle();

    // Page 1 should show 1-5 of 7
    expect(find.text('1-5 of 7'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Academic Document 1'), findsOneWidget);
    expect(find.text('Academic Document 5'), findsOneWidget);
    expect(find.text('Academic Document 6'), findsNothing);

    // Turn page on documents
    final docNextBtn = find.byKey(const Key('appt_docs_next'));
    expect(docNextBtn, findsOneWidget);
    await tester.ensureVisible(docNextBtn);
    await tester.tap(docNextBtn);
    await tester.pumpAndSettle();

    expect(find.text('6-7 of 7'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Academic Document 6'), findsOneWidget);
    expect(find.text('Academic Document 7'), findsOneWidget);
  });

  testWidgets('BlacklistedVisitorsTab renders dynamic documents, incident history, attempted entries with pagination, and interactive KPI cards', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 2000));
    tester.view.physicalSize = const Size(1800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetPhysicalSize();
    });

    final mockApi = MockFullVisitorsApiService();
    final notifier = VisitorsNotifier(mockApi);
    await notifier.init();
    notifier.setActiveTab(2);
    await notifier.openRestrictionDetail(notifier.state.restrictions.first);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitorsApiServiceProvider.overrideWithValue(mockApi),
          visitorsProvider.overrideWith((ref) => notifier),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: BlacklistedVisitorsTab(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify blacklisted visitor is listed
    expect(find.text('Ramesh Kumar'), findsWidgets);

    // Verify 4 KPI cards matching screenshot
    expect(find.text('Total Blacklisted'), findsOneWidget);
    expect(find.text('Active Blocks'), findsOneWidget);
    expect(find.text('Expired Blocks'), findsOneWidget);
    expect(find.text('Attempted Entries'), findsOneWidget);

    // Dynamic counts in subtabs: Documents (6) and Incident History (7)
    expect(find.text('Documents (6)'), findsOneWidget);
    expect(find.text('Incident History (7)'), findsOneWidget);

    // Tap on Incident History subtab
    await tester.ensureVisible(find.text('Incident History (7)'));
    await tester.tap(find.text('Incident History (7)'));
    await tester.pumpAndSettle();

    // Page 1 shows 1-5 of 7
    expect(find.text('1-5 of 7'), findsOneWidget);
    expect(find.text('1/2'), findsWidgets);
    expect(find.text('Disciplinary Hearing Event 1'), findsOneWidget);
    expect(find.text('Disciplinary Hearing Event 5'), findsOneWidget);
    expect(find.text('Disciplinary Hearing Event 6'), findsNothing);

    // Turn page on Incident History
    final histNextBtn = find.byKey(const Key('rest_history_next'));
    expect(histNextBtn, findsOneWidget);
    await tester.ensureVisible(histNextBtn);
    await tester.tap(histNextBtn);
    await tester.pumpAndSettle();

    expect(find.text('6-7 of 7'), findsOneWidget);
    expect(find.text('2/2'), findsWidgets);
    expect(find.text('Disciplinary Hearing Event 6'), findsOneWidget);

    // Test KPI cards tap handler for Attempted Entries
    await tester.ensureVisible(find.text('Attempted Entries'));
    await tester.tap(find.text('Attempted Entries'));
    await tester.pumpAndSettle();
  });
}
