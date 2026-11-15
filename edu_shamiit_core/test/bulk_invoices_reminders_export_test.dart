import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/hostel/providers/hostel_provider.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_fee_models.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/fees/dialogs/bulk_invoice_dialog.dart';

void main() {
  testWidgets('BulkInvoiceDialog renders target students preview and scopes to active academic year', (tester) async {
    final mockStudents = [
      HostelStudentFeeItem(
        accountId: 'acc-1',
        studentId: 'stu-1',
        rowNum: 1,
        name: 'Deepak Chawla 101',
        className: '10 B',
        rollNumber: '201',
        studentIdentifier: '10 B | 0201',
        hostelName: 'Boys Hostel A',
        roomNumber: 'A-105',
        feePlan: 'Monthly',
        totalFee: 7400.0,
        paid: 6400.0,
        due: 1000.0,
        overdue: 0.0,
        status: 'Partial',
        statusRaw: 'PARTIAL',
      ),
      HostelStudentFeeItem(
        accountId: 'acc-2',
        studentId: 'stu-2',
        rowNum: 2,
        name: 'Aman Khan',
        className: '10 C',
        rollNumber: '104',
        studentIdentifier: '10 C | 0104',
        hostelName: 'Boys Hostel A',
        roomNumber: 'A-104',
        feePlan: 'Monthly',
        totalFee: 16000.0,
        paid: 29000.0,
        due: 0.0,
        overdue: 0.0,
        status: 'Over Paid',
        statusRaw: 'OVERPAID',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostelProvider.overrideWith((ref) {
            final notifier = HostelNotifier();
            notifier.state = notifier.state.copyWith(
              selectedAcademicYear: '2026 - 2027',
              studentFeesRoster: mockStudents,
            );
            return notifier;
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: BulkInvoiceDialog(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify dialog title and subtitle scoping
    expect(find.text('Bulk Invoice Generation'), findsOneWidget);
    expect(find.textContaining('2026 - 2027'), findsWidgets);

    // Verify candidate students preview
    expect(find.text('Deepak Chawla 101'), findsOneWidget);
    expect(find.text('Aman Khan'), findsOneWidget);
    expect(find.text('Target Students (2/2 Selected)'), findsOneWidget);

    // Verify deselect all button works
    await tester.tap(find.text('Deselect All'));
    await tester.pumpAndSettle();

    expect(find.text('Target Students (0/2 Selected)'), findsOneWidget);
    expect(find.text('Select All'), findsOneWidget);

    // Verify select all button works
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();

    expect(find.text('Target Students (2/2 Selected)'), findsOneWidget);
  });
}

