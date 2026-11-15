import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_fee_models.dart';
import 'package:edu_shamiit_core/screens/hostel/providers/hostel_provider.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/fees/hostel_student_fee_drawer.dart';

void main() {
  testWidgets('HostelStudentFeeDrawer displays dynamic assigned fee heads and CRUD action buttons', (tester) async {
    final mockDetail = HostelStudentFeeDetail360(
      studentId: 'b1000001-0000-0000-0000-000000000101',
      fullName: 'Deepak Chawla 101',
      className: '10 B',
      rollNumber: '201',
      hostelName: 'Boys Hostel A',
      roomNumber: 'A-105',
      bedNumber: 'Bed 1',
      feePlan: 'Monthly',
      totalFee: 6100.0,
      totalPaid: 6100.0,
      totalDue: 0.0,
      totalOverdue: 0.0,
      status: 'Paid',
      breakdown: [
        HostelFeeHeadBreakdownItem(
          id: 'head-1',
          headName: 'Room Rent',
          headCode: 'ROOM_FEE',
          amount: 6000.0,
          netAmount: 6000.0,
          isMandatory: true,
          isRefundable: false,
          frequency: 'MONTHLY',
        ),
        HostelFeeHeadBreakdownItem(
          id: 'head-2',
          headName: 'Security Deposit',
          headCode: 'SECURITY_DEP',
          amount: 100.0,
          netAmount: 100.0,
          isMandatory: true,
          isRefundable: true,
          frequency: 'ONE_TIME',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostelProvider.overrideWith((ref) {
            final notifier = HostelNotifier();
            notifier.state = notifier.state.copyWith(
              isFeeDrawerOpen: true,
              selectedFeeStudentId: mockDetail.studentId,
              selectedFeeStudentDetail: mockDetail,
              feeDrawerTab: 0,
            );
            return notifier;
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 800,
              child: HostelStudentFeeDrawer(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify student name and fee plan
    expect(find.text('Deepak Chawla 101'), findsOneWidget);
    expect(find.text('Assigned Fee Structure: Monthly'), findsOneWidget);

    // Verify dynamic heads
    expect(find.text('Room Rent'), findsOneWidget);
    expect(find.text('Security Deposit'), findsOneWidget);
    expect(find.text('Refundable Deposit'), findsOneWidget);

    // Verify amounts (6000 and 100)
    expect(find.text('₹ 6,000'), findsOneWidget);
    expect(find.text('₹ 100'), findsOneWidget);

    // Verify NO hardcoded amounts from 82,000 exist
    expect(find.text('₹ 35,000'), findsNothing);
    expect(find.text('₹ 25,000'), findsNothing);
    expect(find.text('₹ 8,000'), findsNothing);
    expect(find.text('₹ 4,000'), findsNothing);

    // Verify CRUD action buttons exist
    expect(find.text('Add Fee Head'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(2));

    // Tap Add Fee Head button to open dialog
    await tester.tap(find.text('Add Fee Head'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Fee Head Name *'), findsOneWidget);
    expect(find.text('Amount (₹) *'), findsOneWidget);
  });
}
