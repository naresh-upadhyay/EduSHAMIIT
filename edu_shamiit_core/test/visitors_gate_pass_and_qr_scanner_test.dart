import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/visitors/models/visitor_models.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/common/scannable_qr_widget.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/dialogs/visitor_gate_pass_dialog.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/dialogs/visitor_profiles_gate_pass_dialog.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/dialogs/visitor_qr_scanner_dialog.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/dialogs/visitor_date_range_dialog.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/dialogs/visitors_more_filters_dialog.dart';

void main() {
  group('Visitor Gate Pass & QR Scanner Models', () {
    test('VisitorProfileItem parses JSON correctly', () {
      final json = {
        'id': 'p1',
        'school_id': 's1',
        'full_name': 'Dr. Marcus Vance',
        'phone': '+91 9988776655',
        'visitor_type': 'Vendor',
        'company': 'TechCorp Solutions',
        'id_type': 'Driving License',
        'id_number_masked': 'DL-XXXX-5544',
        'total_visits': 5,
        'is_blacklisted': false,
      };

      final profile = VisitorProfileItem.fromJson(json);
      expect(profile.id, 'p1');
      expect(profile.fullName, 'Dr. Marcus Vance');
      expect(profile.phone, '+91 9988776655');
      expect(profile.visitorType, 'Vendor');
      expect(profile.company, 'TechCorp Solutions');
      expect(profile.totalVisits, 5);
      expect(profile.isBlacklisted, isFalse);
    });

    test('GeneratedGatePassItem parses JSON correctly', () {
      final json = {
        'pass_id': 'gp-uuid-1',
        'pass_number': 'GP-2026-0298',
        'visit_id': 'v-uuid-1',
        'visit_number': 'VIS-2026-0298',
        'visitor_id': 'p1',
        'visitor_name': 'Dr. Marcus Vance',
        'visitor_type': 'Vendor',
        'phone': '+91 9988776655',
        'company': 'TechCorp Solutions',
        'destination': 'Main Gate Reception',
        'host_name': 'Director Dr. Sharma',
        'purpose': 'AI Infrastructure Inspection',
        'issued_at': '2026-10-18T08:00:00Z',
        'expires_at': '2026-10-18T12:00:00Z',
        'status': 'ACTIVE',
        'visit_status': 'Scheduled',
        'qr_code_base64': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUg==',
        'qr_code_url': '/api/visitors/gate-passes/GP-2026-0298/qr.png',
      };

      final pass = GeneratedGatePassItem.fromJson(json);
      expect(pass.passNumber, 'GP-2026-0298');
      expect(pass.visitorName, 'Dr. Marcus Vance');
      expect(pass.destination, 'Main Gate Reception');
      expect(pass.status, 'ACTIVE');
      expect(pass.qrCodeBase64, contains('base64,'));
    });

    test('GatePassScanResult parses JSON with suggested action', () {
      final json = {
        'success': true,
        'is_valid': true,
        'decoded_text': 'GP-2026-0298',
        'suggested_action': 'CHECK_IN',
        'message': 'Gate Pass GP-2026-0298 verified.',
        'data': {
          'pass_number': 'GP-2026-0298',
          'visitor_name': 'Dr. Marcus Vance',
          'visit_status': 'Scheduled',
        }
      };

      final res = GatePassScanResult.fromJson(json);
      expect(res.success, isTrue);
      expect(res.isValid, isTrue);
      expect(res.decodedText, 'GP-2026-0298');
      expect(res.suggestedAction, 'CHECK_IN');
      expect(res.data?['visitor_name'], 'Dr. Marcus Vance');
    });
  });

  group('Gate Pass UI & Widgets', () {
    testWidgets('ScannableQrWidget renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScannableQrWidget(
              passNumber: 'GP-2026-0298',
              size: 100,
            ),
          ),
        ),
      );

      expect(find.byType(ScannableQrWidget), findsOneWidget);
    });

    testWidgets('VisitorGatePassDialog displays official gate pass card and QR code', (tester) async {
      const visitor = VisitorItem(
        id: '1',
        visitNumber: 'VIS-2026-001',
        visitorId: 'vis-1',
        visitorName: 'Dr. Marcus Vance',
        phone: '+91 9988776655',
        visitorType: 'Vendor',
        category: 'Vendor',
        purpose: 'Inspection',
        location: 'Main Gate Reception',
        destination: 'Main Gate Reception',
        hostName: 'Director Dr. Sharma',
        checkInAt: '2026-10-18T08:00:00Z',
        expectedOutAt: '2026-10-18T12:00:00Z',
        status: 'Scheduled',
        passReference: 'GP-2026-0298',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitorGatePassDialog(visitor: visitor),
          ),
        ),
      );

      expect(find.text('Official Gate Pass'), findsOneWidget);
      expect(find.text('EduSHAMIIT ERP'), findsOneWidget);
      expect(find.text('AUTHORIZED'), findsOneWidget);
      expect(find.text('Dr. Marcus Vance'), findsOneWidget);
      expect(find.text('GP-2026-0298'), findsWidgets);
      expect(find.byType(ScannableQrWidget), findsOneWidget);
      expect(find.text('Print Badge & Pass'), findsOneWidget);
    });

    testWidgets('VisitorProfilesGatePassDialog renders with profile selection stepper', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VisitorProfilesGatePassDialog(),
            ),
          ),
        ),
      );

      expect(find.text('Visitor Profiles & Gate Pass'), findsOneWidget);
      expect(find.text('1. Select Profiles'), findsOneWidget);
      expect(find.text('2. Pass Details'), findsOneWidget);
      expect(find.text('3. QR Passes'), findsOneWidget);
      expect(find.text('+ New Profile'), findsOneWidget);
      expect(find.text('Next: Pass Details'), findsOneWidget);
    });

    testWidgets('VisitorQrScannerDialog renders with mode selector tabs and switches to Live Camera', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VisitorQrScannerDialog(),
            ),
          ),
        ),
      );

      expect(find.text('Gate Security QR Scanner'), findsOneWidget);
      expect(find.text('Upload QR Image'), findsOneWidget);
      expect(find.text('Live Camera'), findsOneWidget);
      expect(find.text('Scan Gun / Pass ID'), findsOneWidget);
      expect(find.text('Choose Pass Image File'), findsOneWidget);

      // Switch to Live Camera tab
      await tester.tap(find.text('Live Camera'));
      await tester.pump();
      expect(find.text('Live Camera'), findsOneWidget);
    });

    testWidgets('VisitorDateRangeDialog renders presets and custom range options', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VisitorDateRangeDialog(),
            ),
          ),
        ),
      );

      expect(find.text('Date & Time Range Selection'), findsOneWidget);
      expect(find.text('From Time'), findsOneWidget);
      expect(find.textContaining('Today'), findsWidgets);
      expect(find.textContaining('Last 7 Days'), findsOneWidget);
      expect(find.textContaining('Academic Year'), findsNothing);
    });

    testWidgets('VisitorsMoreFiltersDialog renders search, location, category and status filters', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VisitorsMoreFiltersDialog(),
            ),
          ),
        ),
      );

      expect(find.text('More Filters'), findsOneWidget);
      expect(find.text('Search Keyword / Host / Purpose / Vehicle'), findsOneWidget);
      expect(find.text('Campus Location / Destination'), findsOneWidget);
      expect(find.text('Visitor Category'), findsOneWidget);
      expect(find.text('Visitor Status'), findsOneWidget);
      expect(find.text('Only Show Overstay Visitors'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);
    });
  });
}
