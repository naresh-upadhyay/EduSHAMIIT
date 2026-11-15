import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_models.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_leave_outing_models.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/dialogs/transfer_hostel_student_dialog.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/students/hostel_students_table.dart';
import 'package:edu_shamiit_core/screens/hostel/providers/hostel_provider.dart';

void main() {
  group('Hostel Roster Pagination Fix Tests', () {
    test('HostelStudentRosterPagination parses total_records, total_count, or total', () {
      final p1 = HostelStudentRosterPagination.fromJson({
        'page': 1,
        'page_size': 10,
        'total_count': 358,
      });
      expect(p1.totalRecords, 358);
      expect(p1.totalPages, 36);
      expect(p1.hasNext, true);
      expect(p1.hasPrev, false);

      final p2 = HostelStudentRosterPagination.fromJson({
        'page': 2,
        'page_size': 10,
        'total_records': 358,
        'total_pages': 36,
        'has_prev': true,
        'has_next': true,
      });
      expect(p2.totalRecords, 358);
      expect(p2.page, 2);
      expect(p2.hasPrev, true);
      expect(p2.hasNext, true);

      final p3 = HostelStudentRosterPagination.fromJson({
        'total': 45,
        'page': 5,
        'page_size': 10,
      });
      expect(p3.totalRecords, 45);
      expect(p3.totalPages, 5);
      expect(p3.hasNext, false);
      expect(p3.hasPrev, true);
    });
  });

  group('Dynamic Leave & Outing Date and Duration Calculations', () {
    test('LeaveOutingRequestItem formats dynamic dates and duration correctly from timestamps', () {
      final item1 = LeaveOutingRequestItem.fromJson({
        'id': 'test-1',
        'request_number': 'LOR-2026-0424',
        'student_id': 'stu-1',
        'student_name': 'Aditya Gupta',
        'start_at': '2026-11-02T12:23:00Z',
        'expected_return_at': '2026-11-03T18:00:00Z',
        'created_at': '2026-11-02T04:55:49Z',
        'reason': 'JJJJK',
        'destination': 'JJJJ',
        'request_type': 'OUTING',
        'status': 'PENDING',
      });

      expect(item1.displayFromDate, '02 Nov 2026');
      expect(item1.displayToDate, '03 Nov 2026');
      expect(item1.displayRequestedOn, '02 Nov 2026');
      expect(item1.displayDuration, '2 days');
      // Ensure it is NOT hardcoded '10 May 2024'
      expect(item1.displayFromDate, isNot(equals('10 May 2024')));
    });

    test('LeaveOutingRequestItem uses database formatted fields when provided', () {
      final item2 = LeaveOutingRequestItem.fromJson({
        'id': 'test-2',
        'request_number': 'LOR-2024-0010',
        'student_id': 'stu-2',
        'student_name': 'Aditya Gupta',
        'from_date_formatted': '25 May 2024',
        'to_date_formatted': '25 May 2024',
        'requested_on_formatted': '22 May 2024',
        'duration_text': '6 hours',
        'reason': 'Passport office appointment',
        'destination': 'Regional Passport Kendra',
        'request_type': 'OUTING',
        'status': 'PENDING',
      });

      expect(item2.displayFromDate, '25 May 2024');
      expect(item2.displayToDate, '25 May 2024');
      expect(item2.displayRequestedOn, '22 May 2024');
      expect(item2.displayDuration, '6 hours');
    });
  });

  group('Transfer Room & Bed Modal Zero-Overflow Verification', () {
    testWidgets('TransferHostelStudentDialog renders cleanly without RenderFlex overflow', (tester) async {
      final student = HostelStudentRosterItem(
        id: 'adm-1',
        admissionId: 'adm-1',
        allocationId: 'alloc-1',
        studentId: 'stu-1',
        studentName: 'Aditya Gupta',
        guardianName: 'Sanjay Gupta',
        guardianRelation: 'S/o Sanjay Gupta',
        rollNo: '0105',
        className: '12 A',
        hostelId: 'b-1',
        hostelName: 'Boys Hostel A',
        roomNumber: 'A-102',
        bedNo: '1',
        status: 'Active',
        rawStatus: 'ACTIVE',
        feeStatus: 'Paid',
        admissionDate: '22 Apr 2024',
      );

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TransferHostelStudentDialog(student: student),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify that Transfer Room & Bed dialog title is present
      expect(find.text('Transfer Room & Bed'), findsOneWidget);
      expect(find.text('Target Hostel *'), findsOneWidget);
      expect(find.text('Room Type'), findsOneWidget);

      // Verify NO RenderFlex yellow-striped overflow errors were raised
      expect(tester.takeException(), isNull);
    });
  });

  group('Hostel Students Table Footer Text Verification', () {
    testWidgets('HostelStudentsTable displays dynamic record counts instead of Showing 0-0 of 0', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

    final list = List.generate(
      10,
      (i) => HostelStudentRosterItem(
        id: 'adm-$i',
        admissionId: 'adm-$i',
        allocationId: 'alloc-$i',
        studentId: 'stu-$i',
        studentName: 'Student $i',
        guardianName: 'Parent $i',
        guardianRelation: 'S/o Parent $i',
        rollNo: '010$i',
        className: '10 A',
        hostelId: 'b-1',
        hostelName: 'Boys Hostel A',
        roomNumber: 'A-101',
        bedNo: '$i',
        status: 'Active',
        rawStatus: 'ACTIVE',
        feeStatus: 'Paid',
        admissionDate: '01 Nov 2026',
      ),
    );

    final mockState = HostelState.initial().copyWith(
      studentsRoster: list,
      studentsPagination: HostelStudentRosterPagination(
        page: 1,
        pageSize: 10,
        totalRecords: 358,
        totalPages: 36,
        hasPrev: false,
        hasNext: true,
      ),
      isStudentsLoading: false,
      activeTab: 2,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostelProvider.overrideWith((ref) => MockHostelNotifier(mockState)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: HostelStudentsTable(),
          ),
        ),
      ),
    );

    await tester.pump();

    // Check that footer shows Showing 1-10 of 358 students
    expect(find.text('Showing 1-10 of 358 students'), findsOneWidget);
    expect(find.text('Showing 0-0 of 0 students'), findsNothing);
  });
});
}

class MockHostelNotifier extends HostelNotifier {
  final HostelState mockState;
  MockHostelNotifier(this.mockState) : super() {
    state = mockState;
  }

  @override
  Future<void> loadInitialData() async {}
}
