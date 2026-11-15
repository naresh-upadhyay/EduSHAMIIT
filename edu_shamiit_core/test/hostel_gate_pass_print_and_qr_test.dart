import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_leave_outing_models.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/leave/scannable_hostel_qr_widget.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/leave/hostel_gate_pass_print_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hostel Gate Pass QR & Print Badge Suite', () {
    testWidgets('ScannableHostelQrWidget renders base64 memory image when provided', (tester) async {
      // 1x1 transparent PNG in base64
      const dummyPngBase64 =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScannableHostelQrWidget(
              passNumber: 'GP-2026-00055',
              qrBase64: dummyPngBase64,
              size: 140,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ScannableHostelQrWidget), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('HostelGatePassPrintDialog renders all details and toggles A4 vs 80mm mode', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const pass = GatePassData(
        id: 'gp-001',
        passNumber: 'GP-2026-00055',
        verificationToken: 'TOKEN-7a13235fe22e',
        qrReference: 'REF-001',
        status: 'ACTIVE',
        studentName: 'Aarav Sharma',
        className: 'Class 9-A',
        rollNumber: '101',
        hostelName: 'Hostel Block',
        roomNumber: 'A-101',
        requestType: 'OUTING',
        destination: 'City Center Mall',
        validFromFormatted: '06 Nov 2026, 02:44 PM',
        validUntilFormatted: '08 Nov 2026, 01:30 AM',
        emergencyContact: '+91 98100 22334',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HostelGatePassPrintDialog(
              gatePass: pass,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Modes
      expect(find.text('Official Gate Pass'), findsOneWidget);
      expect(find.text('Standard Badge (A4)'), findsOneWidget);
      expect(find.text('Thermal Slip (80mm)'), findsOneWidget);

      // Verify Pass Details
      expect(find.text('EduSHAMIIT ERP'), findsOneWidget);
      expect(find.text('AUTHORIZED'), findsOneWidget);
      expect(find.text('GP-2026-00055'), findsWidgets);
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Resident • Class 9-A • Roll 101'), findsOneWidget);
      expect(find.text('Hostel Block (Room A-101)'), findsOneWidget);
      expect(find.text('OUTING'), findsOneWidget);
      expect(find.text('City Center Mall'), findsOneWidget);
      expect(find.text('06 Nov 2026, 02:44 PM - 08 Nov 2026, 01:30 AM'), findsOneWidget);
      expect(find.text('+91 98100 22334'), findsOneWidget);

      // Verify Initial A4 Button Label
      expect(find.text('Print Badge & Pass'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Switch to 80mm Thermal mode
      await tester.tap(find.text('Thermal Slip (80mm)'));
      await tester.pumpAndSettle();

      // Verify Thermal changes
      expect(find.text('POS Thermal Gate Pass (80mm)'), findsOneWidget);
      expect(find.text('Print 80mm POS Slip'), findsOneWidget);

      // Switch back to Standard Badge (A4)
      await tester.tap(find.text('Standard Badge (A4)'));
      await tester.pumpAndSettle();

      expect(find.text('Greenwood High International School'), findsOneWidget);
      expect(find.text('Print Badge & Pass'), findsOneWidget);
    });
  });
}

