import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_admin/widgets/hr_management_tab_header.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/hr_onboarding_screen.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/start_onboarding_dialog.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('EduSHAMIIT ERP - HR Onboarding Widget Tests', () {
    testWidgets('1. HRManagementTabHeader renders with active Onboarding tab', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HRManagementTabHeader(activeTab: HRTab.onboarding),
          ),
        ),
      );

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Recruitment'), findsOneWidget);
      expect(find.text('Onboarding'), findsOneWidget);
      expect(find.text('Training & Learning'), findsOneWidget);
      expect(find.text('Policies & Documents'), findsOneWidget);
    });

    testWidgets('2. StartOnboardingDialog renders 4-step wizard stepper header', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StartOnboardingDialog(
              onOnboardingCreated: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Start New Onboarding'), findsOneWidget);
      expect(find.text('Select Candidate'), findsOneWidget);
      expect(find.text('Joining Info'), findsOneWidget);
      expect(find.text('Template'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Next Step →'), findsOneWidget);
    });

    testWidgets('3. HROnboardingScreen renders Header, KPIs, Pipeline, and Table Cards', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HROnboardingScreen(),
          ),
        ),
      );
      await tester.pump();

      // Verify Header
      expect(find.text('Onboarding'), findsNWidgets(2)); // in TabHeader and PageTitle
      expect(find.text('Add New Hire'), findsOneWidget);
      expect(find.text('Onboarding Settings'), findsOneWidget);

      // Verify KPI Metric Cards
      expect(find.text('Total Onboardings'), findsOneWidget);
      expect(find.text('In Progress'), findsAtLeastNWidgets(1));
      expect(find.text('Pending Documents'), findsOneWidget);
      expect(find.text('Completed'), findsAtLeastNWidgets(1));
      expect(find.text('Avg. Time to Complete'), findsOneWidget);
      expect(find.text('Onboarding Satisfaction'), findsOneWidget);

      // Verify Dashboard Sections
      expect(find.text('Onboarding Progress'), findsOneWidget);
      expect(find.text('Onboarding by Department'), findsOneWidget);
      expect(find.text('New Joiners (Recent)'), findsOneWidget);
    });
  });
}
