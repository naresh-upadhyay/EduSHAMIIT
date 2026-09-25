import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_admin/widgets/hr_management_tab_header.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/hr_overview_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('EduSHAMIIT ERP - HR Management Overview Widget Tests', () {
    testWidgets('1. HRManagementTabHeader renders all 5 primary tabs with active Overview tab', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HRManagementTabHeader(activeTab: HRTab.overview),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Recruitment'), findsOneWidget);
      expect(find.text('Onboarding'), findsOneWidget);
      expect(find.text('Training & Learning'), findsOneWidget);
      expect(find.text('Policies & Documents'), findsOneWidget);
    });

    testWidgets('2. HROverviewScreen renders top command header, export button and quick actions button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HROverviewScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('HR Management'), findsAtLeastNWidgets(1));
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Generate Report'), findsOneWidget);
    });

    testWidgets('3. HROverviewScreen renders all 6 primary KPI metric cards', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HROverviewScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Total Workforce'), findsOneWidget);
      expect(find.text('Open Positions'), findsOneWidget);
      expect(find.text('Pipeline Candidates'), findsOneWidget);
      expect(find.text('Active Onboarding'), findsOneWidget);
      expect(find.text('Training In Progress'), findsAtLeastNWidgets(1));
      expect(find.text('Compliance Rate'), findsAtLeastNWidgets(1));
    });

    testWidgets('4. HROverviewScreen renders pipeline breakdown sections', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HROverviewScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Recruitment Pipeline Funnel'), findsOneWidget);
      expect(find.text('Onboarding Progression'), findsOneWidget);
      expect(find.text('Training & Learning Status'), findsOneWidget);
      expect(find.text('Policies & Document Compliance'), findsOneWidget);
    });

    testWidgets('5. HROverviewScreen renders actionable pending alerts with resolve buttons', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HROverviewScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Actionable Pending HR Alerts'), findsOneWidget);
      expect(find.text('Onboarding Documents Require Verification'), findsOneWidget);
      expect(find.text('Overdue Onboarding Checklist Tasks'), findsOneWidget);
      expect(find.text('Compliance Documents Expiring Soon'), findsOneWidget);
      expect(find.text('Pending Policy Sign-Offs'), findsOneWidget);
    });

    testWidgets('6. HROverviewScreen renders recent activity feed', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HROverviewScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Recent HR Activities'), findsOneWidget);
      expect(find.text('Training Scheduled'), findsOneWidget);
      expect(find.text('Candidate Shortlisted'), findsOneWidget);
      expect(find.text('Document Verified'), findsOneWidget);
      expect(find.text('Policy Published'), findsOneWidget);
    });

    testWidgets('7. Quick Action dialog displays 4 operation options', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HROverviewScreen(),
          ),
        ),
      );
      await tester.pump();

      // Tap Quick Actions button
      final quickActionBtn = find.text('Quick Actions');
      expect(quickActionBtn, findsOneWidget);
      await tester.tap(quickActionBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('HR Quick Actions'), findsOneWidget);
      expect(find.text('Post New Job Opening'), findsOneWidget);
      expect(find.text('Start New Onboarding'), findsOneWidget);
      expect(find.text('Schedule Training Program'), findsOneWidget);
      expect(find.text('Upload Compliance Document'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('HR Quick Actions'), findsNothing);
    });
  });
}
