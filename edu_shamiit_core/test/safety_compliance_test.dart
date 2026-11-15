import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/models/safety_compliance_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/safety_compliance/safety_compliance_kpis_bar.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/safety_compliance/safety_compliance_tab_view.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/safety_compliance/dialogs/report_incident_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/safety_compliance/dialogs/log_inspection_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/safety_compliance/dialogs/add_certificate_dialog.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/safety_compliance/dialogs/schedule_drill_dialog.dart';

void main() {
  group('Safety & Compliance Unit & Model Tests', () {
    test('SafetyComplianceKpis fromJson deserializes properly', () {
      final json = {
        'overall_compliance_pct': 97.2,
        'compliance_change_pct': 3.1,
        'active_certificates': 14,
        'expiring_certificates': 1,
        'total_inspections': 30,
        'inspections_passed_pct': 96.5,
        'open_incidents': 2,
        'critical_incidents': 0,
        'drills_conducted': 8,
        'avg_evacuation_seconds': 132.5,
        'sos_readiness_status': '100% Operational',
      };

      final kpis = SafetyComplianceKpis.fromJson(json);
      expect(kpis.overallCompliancePct, 97.2);
      expect(kpis.complianceChangePct, 3.1);
      expect(kpis.activeCertificates, 14);
      expect(kpis.expiringCertificates, 1);
      expect(kpis.totalInspections, 30);
      expect(kpis.inspectionsPassedPct, 96.5);
      expect(kpis.openIncidents, 2);
      expect(kpis.criticalIncidents, 0);
      expect(kpis.drillsConducted, 8);
      expect(kpis.avgEvacuationSeconds, 132.5);
      expect(kpis.sosReadinessStatus, '100% Operational');
    });

    test('SafetyInspectionItem fromJson deserializes properly', () {
      final json = {
        'id': '11111111-2222-3333-4444-555555555555',
        'inspection_code': 'SI-2026-001',
        'title': 'Fire Extinguisher Pressure Audit',
        'category': 'Fire Safety',
        'location_display': 'Academic Block / All Floors',
        'inspector_name': 'Capt. Rajesh Varma',
        'inspector_role': 'Fire Marshal',
        'inspection_date': '2026-03-05',
        'status': 'Passed',
        'compliance_score': 98.0,
        'findings': 'All extinguishers tagged.',
        'created_at': '2026-03-05T10:00:00Z',
      };

      final item = SafetyInspectionItem.fromJson(json);
      expect(item.id, '11111111-2222-3333-4444-555555555555');
      expect(item.inspectionCode, 'SI-2026-001');
      expect(item.title, 'Fire Extinguisher Pressure Audit');
      expect(item.category, 'Fire Safety');
      expect(item.inspectorName, 'Capt. Rajesh Varma');
      expect(item.status, 'Passed');
      expect(item.complianceScore, 98.0);
    });

    test('SafetyIncidentItem fromJson deserializes properly', () {
      final json = {
        'id': '22222222-3333-4444-5555-666666666666',
        'incident_code': 'INC-2026-001',
        'title': 'Acid Splash in Lab 103',
        'severity': 'Medium',
        'incident_type': 'Lab Incident',
        'location_display': 'B1 / F1-103 Chemistry Lab',
        'reported_by_name': 'Dr. Anand Kelkar',
        'reported_by_role': 'Teacher',
        'incident_time': '2026-03-04T11:20:00Z',
        'status': 'Resolved',
        'victims_count': 1,
        'first_aid_provided': true,
      };

      final item = SafetyIncidentItem.fromJson(json);
      expect(item.incidentCode, 'INC-2026-001');
      expect(item.severity, 'Medium');
      expect(item.incidentType, 'Lab Incident');
      expect(item.victimsCount, 1);
      expect(item.firstAidProvided, true);
    });

    test('ComplianceCertificateItem fromJson deserializes properly', () {
      final json = {
        'id': '33333333-4444-5555-6666-777777777777',
        'certificate_code': 'CERT-FIRE-2026',
        'title': 'Fire NOC',
        'category': 'Fire Safety',
        'issuing_authority': 'State Fire Services',
        'certificate_number': 'FS-NOC/2026/01',
        'location_display': 'All Campus Buildings',
        'issue_date': '2025-04-10',
        'expiry_date': '2026-04-09',
        'status': 'Valid',
        'days_to_expiry': 29,
      };

      final item = ComplianceCertificateItem.fromJson(json);
      expect(item.certificateCode, 'CERT-FIRE-2026');
      expect(item.category, 'Fire Safety');
      expect(item.status, 'Valid');
      expect(item.daysToExpiry, 29);
    });

    test('SafetyDrillItem fromJson deserializes properly', () {
      final json = {
        'id': '44444444-5555-6666-7777-888888888888',
        'drill_code': 'DRL-2026-01',
        'title': 'Annual Campus Mega Fire Evacuation',
        'drill_type': 'Fire Evacuation',
        'location_display': 'All Campus Blocks',
        'scheduled_date': '2026-02-18',
        'status': 'Completed',
        'participants_count': 1420,
        'evacuation_time_seconds': 138,
        'target_time_seconds': 180,
        'coordinator_name': 'Capt. Rajesh Varma',
        'performance_rating': 'Excellent',
      };

      final item = SafetyDrillItem.fromJson(json);
      expect(item.drillCode, 'DRL-2026-01');
      expect(item.participantsCount, 1420);
      expect(item.evacuationTimeSeconds, 138);
      expect(item.targetTimeSeconds, 180);
      expect(item.performanceRating, 'Excellent');
    });
  });

  group('Safety & Compliance Responsive UI Tests (0 Overflows)', () {
    testWidgets('Renders SafetyComplianceKpisBar on desktop & mobile without overflow', (tester) async {
      // 1. Desktop
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SafetyComplianceKpisBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Safety Compliance'), findsOneWidget);
      expect(find.text('Statutory Certificates'), findsOneWidget);
      final err = tester.takeException();
      if (err is FlutterError) {
        debugPrint('FLUTTER_ERR_MSG: ${err.message}');
        for (final d in err.diagnostics) {
          debugPrint('DIAG: $d');
        }
      }
      expect(err, isNull);

      // 2. Mobile (360px)
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SafetyComplianceKpisBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Safety Compliance'), findsOneWidget);
      final err2 = tester.takeException();
      if (err2 is FlutterError) {
        debugPrint('FLUTTER_ERR_MSG: ${err2.message}');
        for (final d in err2.diagnostics) {
          debugPrint('DIAG: $d');
        }
      }
      expect(err2, isNull);
    });

    testWidgets('Renders SafetyComplianceTabView without overflow on Desktop (1280x800)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SafetyComplianceTabView(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(SafetyComplianceTabView), findsOneWidget);
      final err = tester.takeException();
      if (err is FlutterError) {
        debugPrint('FLUTTER_ERR_MSG: ${err.message}');
        for (final d in err.diagnostics) {
          debugPrint('DIAG: $d');
        }
      }
      expect(err, isNull);
    });

    testWidgets('Renders SafetyComplianceTabView without overflow on Mobile (360x720)', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SafetyComplianceTabView(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(SafetyComplianceTabView), findsOneWidget);
      final err = tester.takeException();
      if (err is FlutterError) {
        debugPrint('FLUTTER_ERR_MSG: ${err.message}');
        for (final d in err.diagnostics) {
          debugPrint('DIAG: $d');
        }
      }
      expect(err, isNull);
    });

    testWidgets('Renders ReportIncidentDialog on 360px mobile viewport without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReportIncidentDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Report Safety & Security Incident'), findsOneWidget);
      final err = tester.takeException();
      if (err is FlutterError) {
        debugPrint('FLUTTER_ERR_MSG: ${err.message}');
        for (final d in err.diagnostics) {
          debugPrint('DIAG: $d');
        }
      }
      expect(err, isNull);
    });

    testWidgets('Renders LogInspectionDialog on 360px mobile viewport without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LogInspectionDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Log Safety & Quality Inspection'), findsOneWidget);
      final err = tester.takeException();
      if (err is FlutterError) {
        debugPrint('FLUTTER_ERR_MSG: ${err.message}');
        for (final d in err.diagnostics) {
          debugPrint('DIAG: $d');
        }
      }
      expect(err, isNull);
    });

    testWidgets('Renders AddCertificateDialog on 360px mobile viewport without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AddCertificateDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add Statutory Certificate'), findsOneWidget);
      final err = tester.takeException();
      if (err is FlutterError) {
        debugPrint('FLUTTER_ERR_MSG: ${err.message}');
        for (final d in err.diagnostics) {
          debugPrint('DIAG: $d');
        }
      }
      expect(err, isNull);
    });

    testWidgets('Renders ScheduleDrillDialog on 360px mobile viewport without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ScheduleDrillDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Schedule Emergency Evacuation Drill'), findsOneWidget);
      final err = tester.takeException();
      if (err is FlutterError) {
        debugPrint('FLUTTER_ERR_MSG: ${err.message}');
        for (final d in err.diagnostics) {
          debugPrint('DIAG: $d');
        }
      }
      expect(err, isNull);
    });
  });
}
