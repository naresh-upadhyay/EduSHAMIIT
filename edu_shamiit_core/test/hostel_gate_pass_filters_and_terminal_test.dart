import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_leave_outing_models.dart';
import 'package:edu_shamiit_core/screens/hostel/providers/hostel_provider.dart';
import 'package:edu_shamiit_core/screens/hostel/widgets/leave/gate_pass_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gate Pass Hub & Filters Verification', () {
    test('GatePassData parses all fields and IST formatted timestamps correctly', () {
      final json = {
        'id': 'gp-001',
        'pass_number': 'GP-2026-0033',
        'verification_token': 'TOKEN-eab0a422',
        'qr_reference': 'https://edushamiit.edu/gatepass/TOKEN-eab0a422',
        'status': 'ACTIVE',
        'student_name': 'Priyanka Sen 20',
        'student_photo': 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150',
        'admission_number': 'ADM-2024-001',
        'roll_number': '120',
        'class_name': '9 A',
        'hostel_name': 'Boys Hostel A',
        'room_number': 'A-201',
        'request_type': 'OUTING',
        'destination': 'City Center',
        'valid_from_formatted': '31 Oct 2028, 05:39 AM',
        'valid_until_formatted': '31 Oct 2028, 03:39 PM',
        'valid_from': '2028-10-31T00:09:06.778251Z',
        'valid_until': '2028-10-31T10:09:06.778251Z',
        'approved_by_name': 'Rohit Sharma (Warden)',
        'used_exit_at': null,
        'used_return_at': null,
      };

      final pass = GatePassData.fromJson(json);
      expect(pass.id, equals('gp-001'));
      expect(pass.passNumber, equals('GP-2026-0033'));
      expect(pass.verificationToken, equals('TOKEN-eab0a422'));
      expect(pass.status, equals('ACTIVE'));
      expect(pass.studentName, equals('Priyanka Sen 20'));
      expect(pass.admissionNumber, equals('ADM-2024-001'));
      expect(pass.rollNumber, equals('120'));
      expect(pass.className, equals('9 A'));
      expect(pass.hostelName, equals('Boys Hostel A'));
      expect(pass.roomNumber, equals('A-201'));
      expect(pass.validFromFormatted, equals('31 Oct 2028, 05:39 AM'));
      expect(pass.validUntilFormatted, equals('31 Oct 2028, 03:39 PM'));
    });

    test('HostelState initializes with gate passes pagination and leaveSubTab support', () {
      final state = HostelState.initial();
      expect(state.gatePassesList, isEmpty);
      expect(state.gatePassesPagination['page'], equals(1));
      expect(state.gatePassesPagination['page_size'], equals(10));
      expect(state.leaveSubTab, equals(0));
    });
  });

  group('GatePassDialog Terminal Widget Verification', () {
    testWidgets('GatePassDialog renders in upload image mode and toggles to input mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: GatePassDialog(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Header
      expect(find.text('Hostel Gate Pass Terminal'), findsOneWidget);
      expect(find.text('Upload QR Image'), findsOneWidget);
      expect(find.text('Live Camera'), findsOneWidget);
      expect(find.text('Scan Gun / Pass ID'), findsOneWidget);

      // Verify Mode 0 (Upload QR Image)
      expect(find.text('Upload Gate Pass QR Image'), findsOneWidget);
      expect(find.text('Browse QR File'), findsOneWidget);
      expect(find.text('Take Camera Photo'), findsOneWidget);

      // Tap on Scan Gun / Pass ID tab
      await tester.tap(find.text('Scan Gun / Pass ID'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Mode 2 (Scan Gun / Pass ID)
      expect(find.text('Enter Gate Pass # or Barcode Token'), findsOneWidget);
      expect(find.text('Verify Pass'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('GatePassDialog displays verified pass details and security clearance form', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      const samplePass = GatePassData(
        id: 'gp-verified',
        passNumber: 'GP-2026-0033',
        verificationToken: 'TOKEN-eab0a422',
        qrReference: 'https://edushamiit.edu/gatepass/TOKEN-eab0a422',
        status: 'ACTIVE',
        studentName: 'Priyanka Sen',
        admissionNumber: 'ADM-2024-001',
        rollNumber: '120',
        className: '9 A',
        hostelName: 'Boys Hostel A',
        roomNumber: 'A-201',
        requestType: 'OUTING',
        destination: 'City Market',
        validFromFormatted: '04 Nov 2026, 05:00 PM',
        validUntilFormatted: '04 Nov 2026, 08:00 PM',
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: GatePassDialog(gatePass: samplePass),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Terminal should display header
      expect(find.text('Hostel Gate Pass Terminal'), findsOneWidget);

      // Should have verified student name & pass number
      expect(find.text('Priyanka Sen'), findsOneWidget);
      expect(find.text('Record Gate Clearance'), findsOneWidget);
      expect(find.text('Record Departure (Exit)'), findsOneWidget);
      expect(find.text('Record Arrival (Return)'), findsOneWidget);
      expect(find.text('Scan Another Pass'), findsOneWidget);
    });
  });
}
