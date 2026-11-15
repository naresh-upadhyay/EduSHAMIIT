import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_leave_outing_models.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/leave/hostel_leave_tab.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/leave/hostel_leave_detail_drawer.dart';

void main() {
  group('Hostel Leave & Outing - Models & Serialization', () {
    test('LeaveOutingKpiData parses backend JSON correctly', () {
      final json = {
        'total_requests': 48,
        'total_trend': '↑ 12% This Month',
        'approved': 32,
        'approval_rate': '67% approval rate',
        'pending': 8,
        'pending_subtitle': 'Waiting for approval',
        'rejected': 4,
        'rejected_rate': '8% of requests',
        'currently_out': 15,
        'currently_out_subtitle': 'Students away',
        'due_today': 5,
        'due_today_subtitle': 'Students',
        'overdue': 1,
        'canceled': 4,
      };

      final kpis = LeaveOutingKpiData.fromJson(json);
      expect(kpis.totalRequests, equals(48));
      expect(kpis.approved, equals(32));
      expect(kpis.pending, equals(8));
      expect(kpis.rejected, equals(4));
      expect(kpis.currentlyOut, equals(15));
      expect(kpis.dueToday, equals(5));
      expect(kpis.overdue, equals(1));
      expect(kpis.canceled, equals(4));
    });

    test('LeaveOutingRequestItem parses backend JSON correctly', () {
      final json = {
        'id': 'a1000001-0000-0000-0000-000000000001',
        'request_number': 'REQ-2024-001',
        'display_index': 1,
        'student_id': 'b1000001-0000-0000-0000-000000000001',
        'student_name': 'Rahul Sharma',
        'admission_number': 'ADM-0101',
        'roll_number': '0101',
        'class_name': 'Class 10 A',
        'hostel_name': 'Boys Hostel A',
        'room_number': 'A-101',
        'bed_number': 'Bed 1',
        'request_type': 'LEAVE',
        'request_subtype': 'Home Leave',
        'reason': 'Visiting parents in hometown for family event',
        'destination': 'Jaipur',
        'duration_text': '3 days',
        'status': 'APPROVED',
        'is_emergency': false,
        'guardian_name': 'Rajesh Sharma',
        'guardian_phone': '+91 98765 43210',
        'accompanied_by': 'PARENT',
        'version': 1,
      };

      final item = LeaveOutingRequestItem.fromJson(json);
      expect(item.requestNumber, equals('REQ-2024-001'));
      expect(item.studentName, equals('Rahul Sharma'));
      expect(item.hostelName, equals('Boys Hostel A'));
      expect(item.roomNumber, equals('A-101'));
      expect(item.requestType, equals('LEAVE'));
      expect(item.status, equals('APPROVED'));
      expect(item.accompaniedBy, equals('PARENT'));
    });

    test('LeaveOutingRequestItem parses nested student object fallback without Unknown Student', () {
      final json = {
        'id': 'a1000001-0000-0000-0000-000000000002',
        'request_number': 'LOR-2026-STU-6813f3',
        'request_type': 'OUTING',
        'status': 'APPROVED',
        'student': {
          'id': 'b1000001-0000-0000-0000-000000000002',
          'full_name': 'Rohan Joshi 313',
          'roll_number': '0113',
          'class': '10 B',
          'admission_number': 'ADM-313',
          'hostel_name': 'Boys Hostel A',
          'room_number': 'A-101',
          'bed_number': 'Bed 2',
        },
      };

      final item = LeaveOutingRequestItem.fromJson(json);
      expect(item.studentName, equals('Rohan Joshi 313'));
      expect(item.studentId, equals('b1000001-0000-0000-0000-000000000002'));
      expect(item.rollNumber, equals('0113'));
      expect(item.className, equals('10 B'));
      expect(item.admissionNumber, equals('ADM-313'));
    });

    test('GatePassData parses digital pass information', () {
      final json = {
        'id': 'gp-001',
        'pass_number': 'GP-2024-001',
        'verification_token': 'SEC-TOKEN-12345',
        'qr_reference': 'GIS-HOSTEL-001',
        'status': 'ACTIVE',
        'student_name': 'Rahul Sharma',
        'request_type': 'LEAVE',
        'destination': 'Jaipur',
      };

      final pass = GatePassData.fromJson(json);
      expect(pass.passNumber, equals('GP-2024-001'));
      expect(pass.verificationToken, equals('SEC-TOKEN-12345'));
      expect(pass.status, equals('ACTIVE'));
      expect(pass.studentName, equals('Rahul Sharma'));
    });

    test('LeaveOutingDocumentItem and LeaveOutingNoteItem parse JSON correctly', () {
      final docJson = {
        'id': 'doc-001',
        'document_name': 'Parent Consent Letter.pdf',
        'document_type': 'Parent Consent',
        'file_url': 'https://edushamiit.edu/documents/ParentConsent.pdf',
        'file_size_bytes': 153600,
        'file_size_formatted': '150.0 KB',
        'content_type': 'application/pdf',
        'notes': 'Signed by father',
      };
      final doc = LeaveOutingDocumentItem.fromJson(docJson);
      expect(doc.id, equals('doc-001'));
      expect(doc.documentName, equals('Parent Consent Letter.pdf'));
      expect(doc.documentType, equals('Parent Consent'));
      expect(doc.fileSizeFormatted, equals('150.0 KB'));

      final noteJson = {
        'id': 'note-001',
        'note': 'Verified parent consent by calling father.',
        'category': 'Guardian Verification',
        'author_name': 'Warden Singh',
      };
      final note = LeaveOutingNoteItem.fromJson(noteJson);
      expect(note.id, equals('note-001'));
      expect(note.note, equals('Verified parent consent by calling father.'));
      expect(note.category, equals('Guardian Verification'));
    });

    test('LeaveOutingSettingsData serializes and deserializes', () {
      const settings = LeaveOutingSettingsData(
        leaveAllowed: true,
        outingAllowed: true,
        outingStartTime: '06:00:00',
        lastAllowedReturnTime: '20:00:00',
        guardianConfirmationRequired: true,
        wardenApprovalRequired: true,
        lateReturnGracePeriodMins: 20,
      );

      final json = settings.toJson();
      expect(json['leave_allowed'], isTrue);
      expect(json['outing_allowed'], isTrue);
      expect(json['late_return_grace_period_mins'], equals(20));

      final restored = LeaveOutingSettingsData.fromJson(json);
      expect(restored.leaveAllowed, isTrue);
      expect(restored.lateReturnGracePeriodMins, equals(20));
    });
  });

  group('Hostel Leave & Outing - Widget Rendering', () {
    testWidgets('HostelLeaveTab renders desktop layout cleanly with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HostelLeaveTab(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify Top KPI Cards
      expect(find.text('Total Requests'), findsWidgets);
      expect(find.text('Approved'), findsWidgets);
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Rejected'), findsWidgets);
      expect(find.text('Currently Out'), findsWidgets);
      expect(find.text('Due to Return Today'), findsWidgets);

      // 2. Verify Sub-Tabs Bar (Only Leave & Outing Requests and Gate Pass remain)
      expect(find.text('Leave & Outing Requests'), findsOneWidget);
      expect(find.text('Gate Pass'), findsOneWidget);
      expect(find.text('Leave Calendar'), findsNothing);
      expect(find.text('Outing Register'), findsNothing);
      expect(find.text('Rules & Settings'), findsNothing);

      // 3. Verify Top Actions
      expect(find.text('New Request'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('More Filters'), findsOneWidget);

      // 4. Verify Right Sidebar (Awaiting Approval, Quick Actions & Calendar deleted)
      expect(find.textContaining('Awaiting Approval'), findsNothing);
      expect(find.text('Quick Actions'), findsNothing);
      expect(find.text('Leave & Outing Calendar'), findsNothing);
    });

    testWidgets('HostelLeaveTab renders tablet/mobile layout cleanly', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HostelLeaveTab(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Total Requests'), findsWidgets);
      expect(find.text('Leave & Outing Requests'), findsOneWidget);
    });

    testWidgets('HostelLeaveDetailDrawer renders all 6 tabs and CRUD actions cleanly', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const req = LeaveOutingRequestItem(
        id: 'req-001',
        requestNumber: 'LOR-2024-0012',
        studentId: 'stud-001',
        studentName: 'Vikram Singh',
        rollNumber: '0103',
        className: '11 A',
        hostelName: 'Boys Hostel A',
        roomNumber: 'B-205',
        bedNumber: '1',
        requestType: 'OUTING',
        status: 'PENDING',
        durationText: '3 hours',
        reason: 'Weekend market visit',
        destination: 'Sector 18 Market',
        exitGate: 'Main Gate',
        returnGate: 'Main Gate',
        documents: [
          LeaveOutingDocumentItem(
            id: 'doc-001',
            documentName: 'Parent_Consent.pdf',
            documentType: 'Parent Consent',
            fileUrl: 'https://edushamiit.edu/doc1.pdf',
            fileSizeFormatted: '124.5 KB',
          ),
        ],
        internalNotes: [
          LeaveOutingNoteItem(
            id: 'note-001',
            note: 'Student departed on time and reported back with parent.',
            category: 'General',
            authorName: 'Warden Ramesh',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 560,
                child: HostelLeaveDetailDrawer(
                  request: req,
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Check header and 6 tabs
      expect(find.text('Vikram Singh'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Approval'), findsOneWidget);
      expect(find.text('Gate Pass'), findsOneWidget);
      expect(find.text('Movement'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);

      // In Overview tab: Edit Request and Delete Request buttons
      expect(find.text('Edit Details'), findsOneWidget);
      expect(find.text('Delete Request'), findsOneWidget);

      // Switch to Documents Tab
      await tester.ensureVisible(find.text('Documents'));
      await tester.tap(find.text('Documents'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Upload Document'), findsOneWidget);
      expect(find.text('Parent_Consent.pdf'), findsOneWidget);

      // Switch to Activity Tab
      await tester.ensureVisible(find.text('Activity'));
      await tester.tap(find.text('Activity'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Add Note'), findsOneWidget);
      expect(find.text('Student departed on time and reported back with parent.'), findsOneWidget);

      // Switch to Approval Tab
      await tester.ensureVisible(find.text('Approval'));
      await tester.tap(find.text('Approval'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Approve'), findsWidgets);
      expect(find.text('Reject'), findsWidgets);

      // Switch to Movement Tab
      await tester.ensureVisible(find.text('Movement'));
      await tester.tap(find.text('Movement'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Record Exit'), findsWidgets);

      // Tap Record Exit with 'Main Gate' set (verifies assertion fix)
      await tester.tap(find.text('Record Exit').first);
      await tester.pumpAndSettle();
      expect(find.text('Departure Gate'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Tap Record Return with 'Main Gate' set
      await tester.tap(find.text('Record Return').first);
      await tester.pumpAndSettle();
      expect(find.text('Arrival Gate'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
