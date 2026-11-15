import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/campus/models/maintenance_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/maintenance/maintenance_kpis_bar.dart';

void main() {
  group('Campus Maintenance Models & Serialization Tests', () {
    test('MaintenanceKpis fromJson parses exact Greenwood High School screenshot metrics', () {
      final json = {
        'total_requests': 312,
        'total_change_pct': 14.0,
        'resolved': 254,
        'resolved_pct': 81.4,
        'in_progress': 34,
        'in_progress_pct': 10.9,
        'overdue': 12,
        'overdue_pct': 3.8,
        'scheduled': 28,
        'avg_resolution_days': 1.8,
        'resolution_change_pct': -22.0,
        'my_requests': 18,
        'assigned_to_me': 7,
        'high_priority': 24,
      };

      final kpis = MaintenanceKpis.fromJson(json);

      expect(kpis.totalRequests, 312);
      expect(kpis.totalChangePct, 14.0);
      expect(kpis.resolved, 254);
      expect(kpis.resolvedPct, 81.4);
      expect(kpis.inProgress, 34);
      expect(kpis.inProgressPct, 10.9);
      expect(kpis.overdue, 12);
      expect(kpis.overduePct, 3.8);
      expect(kpis.scheduled, 28);
      expect(kpis.avgResolutionDays, 1.8);
      expect(kpis.resolutionChangePct, -22.0);
      expect(kpis.myRequests, 18);
      expect(kpis.assignedToMe, 7);
      expect(kpis.highPriority, 24);
    });

    test('MaintenanceRequestItem fromJson parses Row 1 MT-0568 AC not cooling accurately', () {
      final json = {
        'id': 'df658283-0828-4619-ac0e-e0216c9df26a',
        'request_code': 'MT-0568',
        'title': 'AC not cooling',
        'description': 'Classroom split AC is blowing warm air even at 18 degrees.',
        'request_type': 'HVAC',
        'priority': 'High',
        'status': 'In Progress',
        'location_display': 'B1 / G-101',
        'reported_by_name': 'Rohan Verma',
        'reported_by_role': 'Student',
        'reported_at': '2026-03-20T10:24:00+05:30',
        'preferred_date': '2026-03-20',
        'preferred_time': '02:00 PM',
        'assigned_to_name': 'Suresh Electrician',
        'assigned_vendor_name': 'CoolAir Solutions Pvt Ltd',
      };

      final item = MaintenanceRequestItem.fromJson(json);

      expect(item.requestCode, 'MT-0568');
      expect(item.title, 'AC not cooling');
      expect(item.locationDisplay, 'B1 / G-101');
      expect(item.requestType, 'HVAC');
      expect(item.priority, 'High');
      expect(item.status, 'In Progress');
      expect(item.reportedByName, 'Rohan Verma');
      expect(item.reportedByRole, 'Student');
      expect(item.assignedToName, 'Suresh Electrician');
      expect(item.assignedVendorName, 'CoolAir Solutions Pvt Ltd');
    });

    test('MaintenanceAnalyticsData fromJson parses trends, donut categories, and SLA meters', () {
      final json = {
        'trends': [
          {'month': 'Sep', 'requests': 40, 'resolved': 32},
          {'month': 'Mar', 'requests': 92, 'resolved': 78},
        ],
        'categories': [
          {'type': 'HVAC (AC)', 'count': 84, 'pct': 26.9, 'color': '#0284C7'},
          {'type': 'Electrical', 'count': 58, 'pct': 18.6, 'color': '#10B981'},
        ],
        'sla': {
          'resolution_within_sla_pct': 81.4,
          'avg_resolution_days': 1.8,
          'overdue_rate_pct': 3.8,
          'first_response_hours': 4.2,
        },
        'total_requests': 312,
      };

      final analytics = MaintenanceAnalyticsData.fromJson(json);

      expect(analytics.trends.length, 2);
      expect(analytics.trends.first.month, 'Sep');
      expect(analytics.categories.length, 2);
      expect(analytics.categories.first.type, 'HVAC (AC)');
      expect(analytics.categories.first.pct, 26.9);
      expect(analytics.sla.resolutionWithinSlaPct, 81.4);
      expect(analytics.sla.avgResolutionDays, 1.8);
      expect(analytics.sla.overdueRatePct, 3.8);
      expect(analytics.sla.firstResponseHours, 4.2);
    });

    test('MaintenancePlanItem and MaintenanceVendorItem parse correctly', () {
      final planJson = {
        'id': 'plan-1',
        'plan_code': 'MP-001',
        'title': 'AC Annual Servicing & Filter Replacement',
        'category': 'HVAC',
        'frequency': 'Quarterly',
        'assigned_team': 'CoolAir Solutions',
        'estimated_duration_hours': 4.0,
        'estimated_cost': 12500.00,
        'next_due_date': '2026-04-15',
      };
      final plan = MaintenancePlanItem.fromJson(planJson);
      expect(plan.planCode, 'MP-001');
      expect(plan.estimatedCost, 12500.0);

      final vendorJson = {
        'id': 'vendor-1',
        'vendor_name': 'CoolAir Solutions Pvt Ltd',
        'service_category': 'HVAC',
        'contract_type': 'AMC',
        'sla_response_hours': 2.0,
      };
      final vendor = MaintenanceVendorItem.fromJson(vendorJson);
      expect(vendor.vendorName, 'CoolAir Solutions Pvt Ltd');
      expect(vendor.contractType, 'AMC');
    });
  });

  group('Campus Maintenance Widget Tests', () {
    testWidgets('MaintenanceKpisBar renders all 6 KPI cards with live values', (tester) async {
      const kpis = MaintenanceKpis(
        totalRequests: 312,
        totalChangePct: 14.0,
        resolved: 254,
        resolvedPct: 81.4,
        inProgress: 34,
        inProgressPct: 10.9,
        overdue: 12,
        overduePct: 3.8,
        scheduled: 28,
        avgResolutionDays: 1.8,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MaintenanceKpisBar(kpis: kpis),
          ),
        ),
      );

      expect(find.text('Total Requests'), findsOneWidget);
      expect(find.text('312'), findsOneWidget);
      expect(find.text('↑ 14%'), findsOneWidget);

      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('254'), findsOneWidget);
      expect(find.text('(81.4%)'), findsOneWidget);

      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('34'), findsOneWidget);
      expect(find.text('(10.9%)'), findsOneWidget);

      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('(3.8%)'), findsOneWidget);

      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);

      expect(find.text('Avg. Resolution Time'), findsOneWidget);
      expect(find.text('1.8 Days'), findsOneWidget);
    });
  });
}
