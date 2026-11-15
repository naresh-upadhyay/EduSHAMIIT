import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/visitors/providers/visitors_provider.dart';
import 'package:edu_shamiit_core/screens/visitors/services/visitors_api_service.dart';
import 'package:edu_shamiit_core/screens/visitors/models/visitor_models.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/tabs/scheduled_visitors_tab.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/tabs/blacklisted_visitors_tab.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/dialogs/visitor_upload_document_dialog.dart';

class MockUploadVisitorsApiService extends VisitorsApiService {
  bool uploadCalled = false;
  bool deleteCalled = false;
  Map<String, dynamic>? lastUploadPayload;
  String? lastDeletedDocId;

  @override
  Future<Map<String, dynamic>> uploadDocument({
    String? visitorId,
    String? appointmentId,
    String? restrictionId,
    String? visitId,
    required String documentName,
    required String documentType,
    required String fileUrl,
    int? fileSizeBytes,
    String? verificationStatus,
  }) async {
    uploadCalled = true;
    lastUploadPayload = {
      'visitor_id': visitorId,
      'appointment_id': appointmentId,
      'restriction_id': restrictionId,
      'visit_id': visitId,
      'document_type': documentType,
      'document_name': documentName,
      'file_url': fileUrl,
      'file_size_bytes': fileSizeBytes,
      'verification_status': verificationStatus,
    };
    return {'status': 'success', 'document_id': 'doc-new-123'};
  }

  @override
  Future<Map<String, dynamic>> deleteDocument(String documentId) async {
    deleteCalled = true;
    lastDeletedDocId = documentId;
    return {'status': 'success', 'message': 'Document deleted successfully'};
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
          'id': 'appt-test-1',
          'visitor_id': 'vis-test-1',
          'visitor_name': 'Dr. Sneha Iyer',
          'category': 'Official',
          'phone': '+91 98765 00008',
          'id_type': 'Aadhaar Card',
          'id_number_masked': 'XXXX-XXXX-1234',
          'purpose': 'Health Checkup Camp',
          'location': 'Medical Room',
          'host_name': 'School Nurse',
          'host_subtitle': 'Infirmary',
          'scheduled_date': '19 Oct 2026',
          'scheduled_start_at': '02:00 PM',
          'scheduled_end_at': '05:00 PM',
          'status': 'Pending',
        }),
      ],
      'pagination': const VisitorPagination(page: 1, pageSize: 10, totalRecords: 1, totalPages: 1),
    };
  }

  @override
  Future<AppointmentDetail360?> getAppointmentDetails(String appointmentId) async {
    return AppointmentDetail360.fromJson({
      'appointment': {
        'id': 'appt-test-1',
        'visitor_id': 'vis-test-1',
        'visitor_name': 'Dr. Sneha Iyer',
        'phone': '+91 98765 00008',
        'purpose': 'Health Checkup Camp',
        'location': 'Medical Room',
        'host_name': 'School Nurse',
        'status': 'Pending',
        'scheduled_date': '19 Oct 2026',
        'scheduled_start_at': '02:00 PM',
        'scheduled_end_at': '05:00 PM',
        'id_type': 'Aadhaar Card',
        'id_number_masked': 'XXXX-XXXX-1234',
      },
      'documents': [
        {
          'id': 'doc-1',
          'document_name': 'Aadhaar Card (XXXX-XXXX-1234)',
          'document_type': 'Aadhaar Card',
          'status': 'Verified',
          'file_url': 'https://example.com/aadhaar.pdf',
        },
        {
          'id': 'doc-2',
          'document_name': 'Appointment Pass',
          'document_type': 'Appointment Pass',
          'status': 'Verified',
          'file_url': 'https://example.com/pass.pdf',
        },
      ],
      'visit_history': [],
      'related_appointments': [],
    });
  }

  @override
  Future<Map<String, dynamic>> getRestrictions({
    String search = '',
    String status = 'All',
    String? location,
    String? category,
    String? severity,
    String? reason,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
    String? sortOrder,
  }) async {
    return {
      'records': <BlacklistedVisitorItem>[
        BlacklistedVisitorItem.fromJson({
          'id': 'rest-test-1',
          'visitor_id': 'vis-rest-1',
          'visitor_name': 'Ramesh Verma',
          'category': 'Vendor',
          'phone': '+91 98765 11111',
          'id_type': 'Driving License',
          'id_number_masked': 'DL-XXXX-5678',
          'reason': 'Violent Behavior',
          'severity': 'Permanent',
          'status': 'Active',
          'created_at': '2026-10-18T10:00:00Z',
        }),
      ],
      'pagination': const VisitorPagination(page: 1, pageSize: 10, totalRecords: 1, totalPages: 1),
    };
  }

  @override
  Future<RestrictionDetail360?> getRestrictionDetails(String restrictionId) async {
    return RestrictionDetail360.fromJson({
      'restriction': {
        'id': 'rest-test-1',
        'visitor_id': 'vis-rest-1',
        'visitor_name': 'Ramesh Verma',
        'phone': '+91 98765 11111',
        'severity': 'Permanent',
        'reason': 'Violent Behavior',
        'status': 'Active',
        'created_at': '2026-10-18T10:00:00Z',
      },
      'documents': [
        {
          'id': 'rest-doc-1',
          'document_name': 'Incident_Report_FIR.pdf',
          'document_type': 'Security Incident Report',
          'status': 'Confidential',
          'file_url': 'https://example.com/fir.pdf',
        },
      ],
      'access_attempts': [],
      'visit_history': [],
    });
  }
}

void main() {
  testWidgets('VisitorUploadDocumentDialog renders properly and submits document', (WidgetTester tester) async {
    final mockApi = MockUploadVisitorsApiService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitorsApiServiceProvider.overrideWithValue(mockApi),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: VisitorUploadDocumentDialog(
              visitorId: 'vis-123',
              appointmentId: 'appt-456',
              visitorName: 'Dr. Sneha Iyer',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upload Document'), findsWidgets);
    expect(find.textContaining('Dr. Sneha Iyer'), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNWidgets(2));

    // Verify Document Name field
    final titleField = find.byType(TextFormField).first;
    await tester.enterText(titleField, 'Official Medical Clearance');
    await tester.pumpAndSettle();

    // Verify Submit button exists
    expect(find.widgetWithText(ElevatedButton, 'Upload Document'), findsOneWidget);
  });

  testWidgets('ScheduledVisitorsTab renders Documents (2) and opens Upload Document Dialog', (WidgetTester tester) async {
    final mockApi = MockUploadVisitorsApiService();

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

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

    // Select the first appointment
    final rowText = find.text('Dr. Sneha Iyer');
    expect(rowText, findsWidgets);
    await tester.tap(rowText.first);
    await tester.pumpAndSettle();

    // Verify Documents tab button is present
    final docsTabFinder = find.text('Documents (2)');
    expect(docsTabFinder, findsOneWidget);

    // Switch to Documents tab
    await tester.tap(docsTabFinder);
    await tester.pumpAndSettle();

    // Check documents are displayed
    expect(find.text('Aadhaar Card (XXXX-XXXX-1234)'), findsOneWidget);
    expect(find.text('Appointment Pass'), findsWidgets);

    // Check Top Upload Document button is visible and clickable
    final uploadBtn = find.widgetWithText(ElevatedButton, 'Upload Document');
    expect(uploadBtn, findsOneWidget);

    await tester.tap(uploadBtn);
    await tester.pumpAndSettle();

    // Verify dialog opened with appointment context
    expect(find.textContaining('Dr. Sneha Iyer'), findsWidgets);
    expect(find.widgetWithText(ElevatedButton, 'Upload Document'), findsWidgets);
  });

  testWidgets('BlacklistedVisitorsTab renders Documents and opens Upload Document Dialog with Security Incident Report default', (WidgetTester tester) async {
    final mockApi = MockUploadVisitorsApiService();

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitorsApiServiceProvider.overrideWithValue(mockApi),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: BlacklistedVisitorsTab(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Select blacklisted visitor
    final visitorRow = find.text('Ramesh Verma');
    expect(visitorRow, findsWidgets);
    await tester.tap(visitorRow.first);
    await tester.pumpAndSettle();

    // Documents (1) should be visible
    final docsTab = find.text('Documents (1)');
    expect(docsTab, findsOneWidget);

    // Switch to documents tab
    await tester.tap(docsTab);
    await tester.pumpAndSettle();

    // Check document item
    expect(find.text('Incident_Report_FIR.pdf'), findsOneWidget);

    // Click Upload Document button
    final uploadBtn = find.widgetWithText(ElevatedButton, 'Upload Document');
    expect(uploadBtn, findsOneWidget);

    await tester.tap(uploadBtn);
    await tester.pumpAndSettle();

    // Verify dialog opened with restriction initial type
    expect(find.text('Security Incident Report'), findsWidgets);
    expect(find.text('Ramesh Verma'), findsWidgets);
  });
}
