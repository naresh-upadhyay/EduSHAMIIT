import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/finance/dialogs/collect_payment_dialog.dart';
import 'package:edu_shamiit_core/screens/edushamiit_pay/edushamiit_pay_fee_checkout_dialog.dart';
import 'package:edu_shamiit_core/screens/finance/drawers/student_fee_account_drawer.dart';
import 'package:edu_shamiit_core/screens/finance/widgets/finance_overview_tab.dart';
import 'package:edu_shamiit_core/screens/finance/widgets/revenue_management_view.dart';

void main() {
  const viewports = [
    Size(1920, 1080), // Desktop Full HD
    Size(1366, 768),  // Standard Laptop
    Size(1024, 768),  // iPad Landscape
    Size(768, 1024),  // iPad Portrait
    Size(480, 800),   // Small Mobile / Phablet
    Size(390, 844),   // iPhone 14
    Size(360, 800),   // Compact Android
  ];

  group('Responsive Layout & Overflow Tests across Viewports', () {
    for (final size in viewports) {
      testWidgets('CollectPaymentDialog renders without overflow at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: CollectPaymentDialog(
                  studentId: 'test-student-1',
                  invoiceId: 'test-inv-1',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'RenderFlex or constraint overflow detected on CollectPaymentDialog at $size');
      });

      testWidgets('EduSHAMIITPayFeeCheckoutDialog renders without overflow at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EduSHAMIITPayFeeCheckoutDialog(
                schoolId: 'sch-1',
                studentId: 'std-1',
                studentName: 'Aarav Sharma',
                feeInvoiceId: 'inv-1',
                invoiceNumber: 'INV-2026-001',
                feeHead: 'Tuition Fee Q3',
                amount: 25000.0,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'RenderFlex or constraint overflow detected on EduSHAMIITPayFeeCheckoutDialog at $size');
      });

      testWidgets('StudentFeeAccountDrawer renders without overflow at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: StudentFeeAccountDrawer(
                  onClose: () {},
                  onCollectPayment: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected on StudentFeeAccountDrawer at $size');
      });

      testWidgets('FinanceOverviewTab renders without overflow at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: FinanceOverviewTab(),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected on FinanceOverviewTab at $size');
      });

      testWidgets('RevenueManagementView renders without overflow at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: RevenueManagementView(),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected on RevenueManagementView at $size');
      });
    }
  });
}
