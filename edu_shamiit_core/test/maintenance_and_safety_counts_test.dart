import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/campus/models/safety_compliance_models.dart';
import 'package:edu_shamiit_core/screens/campus/providers/safety_compliance_provider.dart';
import 'package:edu_shamiit_core/screens/campus/providers/maintenance_provider.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/safety_compliance/safety_compliance_center_panel.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/safety_compliance/safety_compliance_left_panel.dart';
import 'package:edu_shamiit_core/screens/campus/services/safety_compliance_api_service.dart';

class MockSafetyComplianceApiService implements SafetyComplianceApiService {
  @override
  Future<SafetyComplianceKpis> getKpis() async {
    return const SafetyComplianceKpis(
      overallCompliancePct: 96.4,
      complianceChangePct: 2.3,
      activeCertificates: 6,
      expiringCertificates: 2,
      totalInspections: 6,
      inspectionsPassedPct: 83.3,
      actionNeededInspections: 1,
      openIncidents: 0,
      criticalIncidents: 0,
      drillsConducted: 2,
      avgEvacuationSeconds: 146.0,
      sosReadinessStatus: '100% Operational',
    );
  }

  @override
  Future<SafetyListResponse<SafetyInspectionItem>> getInspections({
    String? category,
    String? status,
    String? buildingId,
    String? search,
    int page = 1,
    int pageSize = 10,
  }) async {
    return const SafetyListResponse<SafetyInspectionItem>(
      totalCount: 1,
      records: [],
      page: 1,
      pageSize: 10,
      totalPages: 1,
    );
  }

  @override
  Future<SafetyListResponse<SafetyIncidentItem>> getIncidents({
    String? status,
    String? severity,
    String? search,
    int page = 1,
    int pageSize = 10,
  }) async {
    return const SafetyListResponse<SafetyIncidentItem>(
      totalCount: 0,
      records: [],
      page: 1,
      pageSize: 10,
      totalPages: 1,
    );
  }

  @override
  Future<SafetyListResponse<ComplianceCertificateItem>> getCertificates({
    String? category,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 10,
  }) async {
    return const SafetyListResponse<ComplianceCertificateItem>(
      totalCount: 2,
      records: [],
      page: 1,
      pageSize: 10,
      totalPages: 1,
    );
  }

  @override
  Future<SafetyListResponse<SafetyDrillItem>> getDrills({
    String? status,
    int page = 1,
    int pageSize = 10,
  }) async {
    return const SafetyListResponse<SafetyDrillItem>(
      totalCount: 2,
      records: [],
      page: 1,
      pageSize: 10,
      totalPages: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Maintenance & Safety Compliance Counts Parity Tests', () {
    test('MaintenanceState initial date range defaults to null (all dates)', () {
      final state = const MaintenanceState();
      expect(state.dateRangeStart, isNull);
      expect(state.dateRangeEnd, isNull);

      final withDates = state.copyWith(
        dateRangeStart: DateTime(2026, 3, 15),
        dateRangeEnd: DateTime(2026, 3, 21),
      );
      expect(withDates.dateRangeStart, isNotNull);
      expect(withDates.dateRangeEnd, isNotNull);

      // Verify clearDateRange works
      final cleared = withDates.copyWith(clearDateRange: true);
      expect(cleared.dateRangeStart, isNull);
      expect(cleared.dateRangeEnd, isNull);
    });

    test('SafetyComplianceKpis parses action_needed_inspections and counts correctly', () {
      final json = {
        'overall_compliance_pct': 96.4,
        'compliance_change_pct': 2.3,
        'active_certificates': 6,
        'expiring_certificates': 2,
        'total_inspections': 6,
        'inspections_passed_pct': 83.3,
        'action_needed_inspections': 1,
        'open_incidents': 0,
        'critical_incidents': 0,
        'drills_conducted': 2,
        'avg_evacuation_seconds': 146.0,
        'sos_readiness_status': '100% Operational',
      };

      final kpis = SafetyComplianceKpis.fromJson(json);
      expect(kpis.actionNeededInspections, equals(1));
      expect(kpis.expiringCertificates, equals(2));
      expect(kpis.activeCertificates, equals(6));
      expect(kpis.totalInspections, equals(6));
      expect(kpis.openIncidents, equals(0));
      expect(kpis.drillsConducted, equals(2));
    });

    test('SafetyComplianceNotifier subtab options and status sanitization prevent DropdownButton crashes', () {
      final mockApi = MockSafetyComplianceApiService();
      final notifier = SafetyComplianceNotifier(mockApi);

      // Subtab 2 has 'Expiring Soon'
      final subTab2Options = SafetyComplianceNotifier.getStatusOptionsForSubTab(2);
      expect(subTab2Options.contains('Expiring Soon'), isTrue);

      // Subtab 0 only has Inspections options
      final subTab0Options = SafetyComplianceNotifier.getStatusOptionsForSubTab(0);
      expect(subTab0Options.contains('Expiring Soon'), isFalse);

      // Set view to expiring_certs
      notifier.setActiveView('expiring_certs');
      expect(notifier.debugState.activeSubTab, equals(2));
      expect(notifier.debugState.selectedStatus, equals('Expiring Soon'));

      // Switch to subtab 0 (Safety Inspections) -> should automatically sanitize status to 'All'
      notifier.setActiveSubTab(0);
      expect(notifier.debugState.activeSubTab, equals(0));
      expect(notifier.debugState.selectedStatus, equals('All'));
    });

    testWidgets('SafetyComplianceCenterPanel switches tabs without DropdownButton value assertion crash', (tester) async {
      final mockApi = MockSafetyComplianceApiService();
      final container = ProviderContainer(
        overrides: [
          safetyComplianceProvider.overrideWith((ref) => SafetyComplianceNotifier(mockApi)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SafetyComplianceCenterPanel(
                onOpenLogInspection: () {},
                onOpenReportIncident: () {},
                onOpenAddCertificate: () {},
                onOpenScheduleDrill: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Statutory Certificates tab and tap it
      final certTab = find.text('Statutory Certificates');
      expect(certTab, findsOneWidget);
      await tester.tap(certTab);
      await tester.pumpAndSettle();

      // Select 'Expiring Soon' from dropdown
      container.read(safetyComplianceProvider.notifier).setStatus('Expiring Soon');
      await tester.pumpAndSettle();

      // Now tap back to 'Safety Inspections' tab
      final inspectionsTab = find.text('Safety Inspections');
      expect(inspectionsTab, findsOneWidget);
      await tester.tap(inspectionsTab);
      await tester.pumpAndSettle();

      // Verify no assertion error occurred and table rendered
      expect(tester.takeException(), isNull);
      expect(find.text('Safety Inspections'), findsOneWidget);
    });

    testWidgets('SafetyComplianceLeftPanel renders dynamic badges strictly matching KPIs', (tester) async {
      final mockApi = MockSafetyComplianceApiService();
      final container = ProviderContainer(
        overrides: [
          safetyComplianceProvider.overrideWith((ref) => SafetyComplianceNotifier(mockApi)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SafetyComplianceLeftPanel(
                onOpenLogInspection: () {},
                onOpenReportIncident: () {},
                onOpenScheduleDrill: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check badges: Action Needed Inspections = 1, Expiring Certificates = 2, Drills = 2
      expect(find.text('Action Needed Inspections'), findsOneWidget);
      expect(find.text('Expiring Certificates'), findsOneWidget);
      expect(find.text('Conducted Drills'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
