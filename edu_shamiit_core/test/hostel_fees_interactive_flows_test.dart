import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/fees/dialogs/collect_payment_dialog.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/fees/dialogs/generate_invoice_dialog.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/fees/dialogs/apply_concession_dialog.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/fees/dialogs/add_penalty_dialog.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/fees/dialogs/bulk_invoice_dialog.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/fees/hostel_student_fee_drawer.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/fees/hostel_student_fee_table.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_fee_models.dart';
import 'package:edu_shamiit_core/screens/hostel/providers/hostel_provider.dart';

final testStudent = HostelStudentFeeItem(
  accountId: 'a1000001-0000-0000-0000-000000000001',
  studentId: 's1000001-0000-0000-0000-000000000001',
  rowNum: 1,
  name: 'Rahul Sharma',
  rollNumber: 'HS-001',
  studentIdentifier: 'STU-001',
  className: 'Class 10A',
  roomNumber: 'A-101',
  hostelName: 'Boys Hostel A',
  feePlan: 'Standard',
  totalFee: 36000,
  paid: 36000,
  due: 0,
  overdue: 0,
  status: 'Paid',
  statusRaw: 'PAID',
);

final mockDetail = HostelStudentFeeDetail360(
  studentId: 's1000001-0000-0000-0000-000000000001',
  fullName: 'Rahul Sharma',
  className: 'Class 10A',
  rollNumber: 'HS-001',
  hostelName: 'Boys Hostel A',
  roomNumber: 'A-101',
  bedNumber: 'Bed 1',
  feePlan: 'Standard',
  totalFee: 36000,
  totalPaid: 36000,
  totalDue: 0,
  totalOverdue: 0,
  totalConcession: 0,
  advanceCredit: 0,
  securityDepositExpected: 10000,
  securityDepositPaid: 10000,
  status: 'Paid',
);

void main() {
  testWidgets('CollectPaymentDialog renders all input fields and payment modes', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CollectPaymentDialog(student: testStudent),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Collect Hostel Fee'), findsOneWidget);
    expect(find.textContaining('Payment Amount'), findsOneWidget);
    expect(find.textContaining('Payment Mode'), findsOneWidget);
    expect(find.textContaining('Transaction / Ref'), findsOneWidget);
    expect(find.textContaining('Dispatch digital receipt voucher'), findsOneWidget);
    expect(find.text('Record Payment'), findsOneWidget);
  });

  testWidgets('GenerateInvoiceDialog renders line items breakdown and total', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: GenerateInvoiceDialog(student: testStudent),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Generate Hostel Invoice'), findsOneWidget);
    expect(find.textContaining('Billing Title'), findsOneWidget);
    expect(find.text('Room Rent'), findsWidgets);
    expect(find.text('Mess & Food Charges'), findsWidgets);
    expect(find.text('Issue Invoice'), findsOneWidget);
  });

  testWidgets('ApplyConcessionDialog renders concession types and percentage/flat options', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ApplyConcessionDialog(student: testStudent),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Apply Fee Concession'), findsOneWidget);
    expect(find.textContaining('Concession Category'), findsOneWidget);
    expect(find.textContaining('Reason'), findsWidgets);
    expect(find.text('Apply Concession'), findsOneWidget);
  });

  testWidgets('AddPenaltyDialog renders penalty types and fine amount fields', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AddPenaltyDialog(student: testStudent),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Add Hostel Penalty / Fine'), findsOneWidget);
    expect(find.textContaining('Violation / Penalty Category'), findsOneWidget);
    expect(find.textContaining('Fine Amount'), findsOneWidget);
    expect(find.textContaining('Incident Description'), findsOneWidget);
    expect(find.text('Assess Fine'), findsOneWidget);
  });

  testWidgets('BulkInvoiceDialog renders hostel selector and billing batch options', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: BulkInvoiceDialog(),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Bulk Invoice Generation'), findsOneWidget);
    expect(find.textContaining('Target Hostel Cohort'), findsOneWidget);
    expect(find.textContaining('Fee Structure / Plan Template'), findsOneWidget);
    expect(find.text('Generate Bulk Invoices'), findsOneWidget);
  });

  testWidgets('HostelStudentFeeDrawer renders 360 degree financial tabs and overview', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    container.read(hostelProvider.notifier).openFeeDrawer(
      's1000001-0000-0000-0000-000000000001',
      initialDetail: mockDetail,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 440,
              height: 900,
              child: HostelStudentFeeDrawer(),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Rahul Sharma'), findsWidgets);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Invoices'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Ledger'), findsOneWidget);
    expect(find.text('Collect Fee'), findsOneWidget);
  });

  testWidgets('HostelStudentFeeTable renders Fee Structure catalog when feesSubTab is 4', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockPlan = HostelFeePlanModel(
      id: 'p1',
      name: 'Standard Hostel Plan',
      code: 'STD-ROOM',
      roomType: 'Standard',
      roomCategory: 'Non-AC',
      billingCycle: 'MONTHLY',
      totalAnnualAmount: 36000.0,
      totalCycleAmount: 3000.0,
      status: 'ACTIVE',
      heads: [
        HostelFeePlanHeadModel(
          id: 'h1',
          feeHeadCode: 'ROOM_RENT',
          feeHeadName: 'Room Rent',
          amount: 21600.0,
          chargeType: 'RECURRING',
          frequency: 'MONTHLY',
        ),
      ],
    );

    final container = ProviderContainer();
    container.read(hostelProvider.notifier).setFeesSubTab(4);
    // Inject mockPlan
    container.read(hostelProvider.notifier).state = container.read(hostelProvider).copyWith(
      feePlans: [mockPlan],
      feesSubTab: 4,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: HostelStudentFeeTable(),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Hostel Fee Structures & Plans'), findsOneWidget);
    expect(find.text('Create Fee Structure'), findsOneWidget);
    expect(find.text('STD-ROOM'), findsOneWidget);
    expect(find.text('Standard Hostel Plan'), findsOneWidget);
  });

  test('HostelStudentFeeItem and HostelStudentFeeDetail360 compute 0 balance and Over Paid status when paid exceeds total billed', () {
    // Overpaid item (like Ananya Singh: Billed 37,000, Paid 51,000)
    final overpaidItem = HostelStudentFeeItem(
      accountId: 'acc-ananya',
      studentId: 'stu-ananya',
      rowNum: 4,
      name: 'Ananya Singh',
      className: '10 A',
      rollNumber: '0101',
      studentIdentifier: '10 A | 0101',
      hostelName: 'Boys Hostel A',
      roomNumber: 'A-101',
      feePlan: 'Monthly',
      totalFee: 37000.0,
      paid: 51000.0,
      due: 0.0,
      overdue: 0.0,
      status: 'Over Paid',
      statusRaw: 'OVERPAID',
    );

    expect(overpaidItem.balanceDue, 0.0);
    expect(overpaidItem.feeStatus, 'Over Paid');
    expect(overpaidItem.balanceDueFormatted, '₹ 0');
    expect(overpaidItem.totalBilledFormatted, '₹ 37,000');
    expect(overpaidItem.totalPaidFormatted, '₹ 51,000');

    // Test fromJson computation with raw input where paid > total_fee
    final fromJsonItem = HostelStudentFeeItem.fromJson({
      'account_id': 'acc-ananya',
      'student_id': 'stu-ananya',
      'total_fee': 37000.0,
      'paid': 51000.0,
      'due': 1000.0, // erroneous raw due should be sanitized to 0.0
      'status': 'Partial', // should be corrected to Over Paid
    });
    expect(fromJsonItem.due, 0.0);
    expect(fromJsonItem.balanceDue, 0.0);
    expect(fromJsonItem.feeStatus, 'Over Paid');
    expect(fromJsonItem.balanceDueFormatted, '₹ 0');

    // 360 Detail
    final overpaidDetail = HostelStudentFeeDetail360(
      studentId: 'stu-ananya',
      fullName: 'Ananya Singh',
      className: '10 A',
      rollNumber: '0101',
      hostelName: 'Boys Hostel A',
      roomNumber: 'A-101',
      bedNumber: 'Bed 1',
      feePlan: 'Monthly',
      totalFee: 37000.0,
      totalPaid: 51000.0,
      totalDue: 0.0,
      totalOverdue: 0.0,
      advanceCredit: 14000.0,
      securityDepositExpected: 10000.0,
      securityDepositPaid: 10000.0,
      status: 'Over Paid',
    );
    expect(overpaidDetail.balanceDue, 0.0);
    expect(overpaidDetail.feeStatus, 'Over Paid');
    expect(overpaidDetail.balanceDueFormatted, '₹ 0');
    expect(overpaidDetail.advanceCredit, 14000.0);
  });

  testWidgets('HostelStudentFeeDrawer renders Over Paid pill and 0 balance due for overpaid student', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final overpaidDetail = HostelStudentFeeDetail360(
      studentId: 'stu-ananya',
      fullName: 'Ananya Singh',
      className: '10 A',
      rollNumber: '0101',
      hostelName: 'Boys Hostel A',
      roomNumber: 'A-101',
      bedNumber: 'Bed 1',
      feePlan: 'Monthly',
      totalFee: 37000.0,
      totalPaid: 51000.0,
      totalDue: 0.0,
      totalOverdue: 0.0,
      advanceCredit: 14000.0,
      securityDepositExpected: 10000.0,
      securityDepositPaid: 10000.0,
      status: 'Over Paid',
    );

    final container = ProviderContainer();
    container.read(hostelProvider.notifier).openFeeDrawer(
      'stu-ananya',
      initialDetail: overpaidDetail,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 440,
              height: 900,
              child: HostelStudentFeeDrawer(),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Ananya Singh'), findsWidgets);
    expect(find.text('Over Paid'), findsOneWidget);
    expect(find.text('₹ 37,000'), findsOneWidget); // Total Billed
    expect(find.text('₹ 51,000'), findsOneWidget); // Total Paid
    expect(find.text('₹ 0'), findsOneWidget); // Balance Due
  });
}
