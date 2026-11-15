import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/visitors/providers/visitors_provider.dart';
import 'package:edu_shamiit_core/screens/visitors/services/visitors_api_service.dart';
import 'package:edu_shamiit_core/screens/visitors/models/visitor_models.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/tabs/all_visitors_tab.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/tabs/scheduled_visitors_tab.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/dialogs/restriction_update_dialog.dart';

class MockBlockedVisitorsApiService extends VisitorsApiService {
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
          'id': 'visit-rtrete-1',
          'visit_number': 'VIS-2026-0328',
          'visitor_id': 'profile-rtrete',
          'visitor_name': 'RTRETE',
          'phone': '545465657',
          'visitor_type': 'Parent',
          'category': 'Parent',
          'purpose': 'Meet Student',
          'location': 'Main Gate',
          'destination': 'Main Gate',
          'host_name': 'Rahul Sharma (Class 10)',
          'status': 'Blocked',
          'check_in_at': '2026-10-19T17:24:43Z',
        }),
      ],
      'pagination': const VisitorPagination(page: 1, pageSize: 10, totalRecords: 1, totalPages: 1),
    };
  }

  @override
  Future<VisitorDetail360?> getVisitDetails(String visitId) async {
    return VisitorDetail360.fromJson({
      'visit': {
        'id': 'visit-rtrete-1',
        'visit_number': 'VIS-2026-0328',
        'visitor_name': 'RTRETE',
        'status': 'Blocked',
        'purpose': 'Meet Student',
        'location': 'Main Gate',
        'destination': 'Main Gate',
        'host_name': 'Rahul Sharma (Class 10)',
        'remarks': 'Blocked due to security blacklist',
      },
      'visitor': {
        'id': 'profile-rtrete',
        'full_name': 'RTRETE',
        'phone': '545465657',
        'visitor_type': 'Parent',
        'id_type': 'Aadhaar',
        'id_number_masked': 'XXXX-1234',
        'is_blacklisted': true,
      },
      'documents': <Map<String, dynamic>>[],
      'visit_history': [
        {
          'id': 'visit-rtrete-1',
          'purpose': 'Meet Student',
          'status': 'Blocked',
          'destination': 'Main Gate',
          'host_name': 'Rahul Sharma',
          'check_in_at': '2026-10-19T17:24:43Z',
        }
      ],
      'access_events': <Map<String, dynamic>>[],
    });
  }

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
    return {
      'records': <ScheduledAppointmentItem>[
        ScheduledAppointmentItem.fromJson({
          'id': 'appt-rtrete-1',
          'appointment_number': 'APT-2026-0042',
          'visitor_id': 'profile-rtrete',
          'visitor_name': 'RTRETE',
          'phone': '545465657',
          'purpose': 'Parent Discussion',
          'location': 'Main Gate',
          'destination': 'Main Gate',
          'host_name': 'Principal Office',
          'scheduled_date': '2026-10-20',
          'scheduled_start_at': '10:00 AM',
          'scheduled_end_at': '11:00 AM',
          'status': 'Blocked',
        }),
      ],
      'pagination': const VisitorPagination(page: 1, pageSize: 10, totalRecords: 1, totalPages: 1),
    };
  }

  @override
  Future<AppointmentDetail360?> getAppointmentDetails(String appointmentId) async {
    return AppointmentDetail360.fromJson({
      'appointment': {
        'id': 'appt-rtrete-1',
        'appointment_number': 'APT-2026-0042',
        'visitor_name': 'RTRETE',
        'phone': '545465657',
        'status': 'Blocked',
        'location': 'Main Gate',
        'destination': 'Main Gate',
        'host_name': 'Principal Office',
        'purpose': 'Parent Discussion',
      },
      'documents': <Map<String, dynamic>>[],
      'visit_history': <Map<String, dynamic>>[],
      'related_appointments': <Map<String, dynamic>>[],
    });
  }

  @override
  Future<ScheduledKPIs> getScheduledKPIs({String? dateFrom, String? dateTo}) async => const ScheduledKPIs();

  @override
  Future<BlacklistKPIs> getBlacklistKPIs({String? dateFrom, String? dateTo}) async => const BlacklistKPIs();

  @override
  Future<VisitorKPIs> getKPIs({
    String? dateFrom,
    String? dateTo,
    String? dateRangeLabel,
    String? location,
    String? category,
  }) async => const VisitorKPIs();

  @override
  Future<Map<String, dynamic>> updateRestriction(String restrictionId, Map<String, dynamic> payload) async {
    return {'success': true, 'message': 'Restriction updated successfully.'};
  }

  @override
  Future<Map<String, dynamic>> liftRestriction(String restrictionId, {required String reason}) async {
    return {'success': true, 'status': 'LIFTED'};
  }
}

void main() {
  testWidgets('Blocked visitor renders red "Blocked" badge in All Visitors data table and drawer', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockApi = MockBlockedVisitorsApiService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitorsApiServiceProvider.overrideWithValue(mockApi),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AllVisitorsTab(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify RTRETE appears in table
    expect(find.text('RTRETE'), findsAtLeastNWidgets(1));

    // Verify "Blocked" status badge appears
    expect(find.text('Blocked'), findsAtLeastNWidgets(1));

    // Verify it is NOT shown as "Scheduled"
    expect(find.text('Scheduled'), findsNothing);

    // Verify that the status badge has red background styling
    final blockedBadgeFinder = find.ancestor(
      of: find.text('Blocked').first,
      matching: find.byType(Container),
    );
    expect(blockedBadgeFinder, findsAtLeastNWidgets(1));
    final container = tester.widget<Container>(blockedBadgeFinder.first);
    final boxDecoration = container.decoration as BoxDecoration;
    expect(boxDecoration.color, equals(const Color(0xFFFEE2E2)));

    // Verify prohibition banner is present when inspecting blocked visitor
    expect(find.textContaining('Visitor is blocked / blacklisted'), findsAtLeastNWidgets(1));
    expect(find.text('Check Out'), findsNothing);
  });

  testWidgets('Blocked appointment renders red "Blocked" badge in Scheduled Visitors tab', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockApi = MockBlockedVisitorsApiService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitorsApiServiceProvider.overrideWithValue(mockApi),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ScheduledVisitorsTab(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify RTRETE appears in scheduled visitors table
    expect(find.text('RTRETE'), findsAtLeastNWidgets(1));

    // Verify "Blocked" status badge appears on scheduled tab
    expect(find.text('Blocked'), findsAtLeastNWidgets(1));

    // Verify RTRETE's row badge displays Blocked and NOT Pending or Confirmed
    final rowFinder = find.ancestor(of: find.text('RTRETE').first, matching: find.byType(InkWell));
    expect(find.descendant(of: rowFinder.first, matching: find.text('Blocked')), findsOneWidget);
    expect(find.descendant(of: rowFinder.first, matching: find.text('Pending')), findsNothing);
    expect(find.descendant(of: rowFinder.first, matching: find.text('Confirmed')), findsNothing);

    // Verify prohibition alert exists and Approve button is suppressed
    expect(find.textContaining('This appointment is blocked'), findsAtLeastNWidgets(1));
    expect(find.text('Approve'), findsNothing);
  });

  testWidgets('RestrictionUpdateDialog allows selecting Valid Till Date when Permanent is unchecked', (tester) async {
    final restriction = BlacklistedVisitorItem.fromJson({
      'id': 'rest-1',
      'visitor_id': 'v-1',
      'visitor_name': 'Flagged Person',
      'mobile_no': '+91 966607d8e5',
      'reason_category': 'Prior access violation',
      'scope_name': 'Entire Institution',
      'is_permanent': true,
      'valid_till': 'Permanent',
      'status': 'Active',
      'remarks': 'Attempted unauthorized entry.',
    });

    final mockApi = MockBlockedVisitorsApiService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitorsApiServiceProvider.overrideWithValue(mockApi),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RestrictionUpdateDialog(restriction: restriction),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initially permanent is checked
    expect(find.text('Permanent Restriction'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);

    // Uncheck Permanent Restriction
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Valid Till Date field should now be visible and NOT say "Permanent"
    expect(find.text('Valid Till Date *'), findsOneWidget);
    expect(find.text('Permanent'), findsNothing);

    // Tap on the calendar icon or text field to open DatePicker
    await tester.tap(find.byIcon(Icons.calendar_month_rounded));
    await tester.pumpAndSettle();

    // Verify date picker opened
    expect(find.text('Select Valid Till Date'), findsOneWidget);
  });
}
