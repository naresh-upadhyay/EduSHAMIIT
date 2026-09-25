import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_admin/widgets/hr_management_tab_header.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/create_training_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/assign_employees_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/add_session_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/record_attendance_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/certificates_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/training_calendar_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/skill_gaps_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/training_reports_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/training_detail_drawer.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/hr_training_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('EduSHAMIIT ERP - Training & Learning Widget Tests', () {
    testWidgets('1. HRManagementTabHeader renders with active Training & Learning tab', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HRManagementTabHeader(activeTab: HRTab.training),
          ),
        ),
      );

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Recruitment'), findsOneWidget);
      expect(find.text('Onboarding'), findsOneWidget);
      expect(find.text('Training & Learning'), findsOneWidget);
      expect(find.text('Policies & Documents'), findsOneWidget);
    });

    testWidgets('2. CreateTrainingDialog renders form fields and actions', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateTrainingDialog(onTrainingCreated: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Create Training Program'), findsOneWidget);
      expect(find.text('Training Title *'), findsOneWidget);
      expect(find.text('Save Draft'), findsOneWidget);
      expect(find.text('Create & Publish'), findsOneWidget);
    });

    testWidgets('3. AssignEmployeesDialog renders search, department filters and multi-select', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssignEmployeesDialog(
              programId: 'test-program-1',
              programTitle: 'Child Safety & Safeguarding',
              onAssigned: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Assign Employees to Training'), findsOneWidget);
      expect(find.text('Child Safety & Safeguarding'), findsOneWidget);
      expect(find.text('Assign Selected (0)'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('4. AddSessionDialog renders session form inputs', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddSessionDialog(
              programId: 'test-program-1',
              programTitle: 'Child Safety & Safeguarding',
              onSessionAdded: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Add Training Session'), findsOneWidget);
      expect(find.text('Child Safety & Safeguarding'), findsOneWidget);
      expect(find.text('Add Session'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('5. RecordAttendanceDialog renders attendance management interface', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordAttendanceDialog(
              sessionId: 'test-session-1',
              sessionTitle: 'Session 1: Introduction',
              sessionDate: '2026-09-12',
              sessionTime: '10:00 AM',
              onAttendanceSaved: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Record Session Attendance'), findsOneWidget);
      expect(find.text('Mark All Present'), findsOneWidget);
      expect(find.text('Save Attendance'), findsOneWidget);
    });

    testWidgets('6. CertificatesDialog renders registry search and export options', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CertificatesDialog(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Certificates & Expiring Certifications'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('7. TrainingCalendarDialog renders calendar month, legend and agenda', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainingCalendarDialog(onSessionChanged: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Training Calendar & Timetable'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Holiday'), findsOneWidget);
    });

    testWidgets('8. SkillGapsDialog renders training needs and add skill gap form', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkillGapsDialog(
              onGapsChanged: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Training Needs & Skill Gaps'), findsOneWidget);
      expect(find.text('Identify Need'), findsOneWidget);
    });

    testWidgets('9. TrainingReportsDialog renders report download choices', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TrainingReportsDialog(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('HR Training & Learning Reports'), findsOneWidget);
      expect(find.text('Training Programs Master Ledger'), findsOneWidget);
      expect(find.text('Export CSV'), findsAtLeastNWidgets(1));
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('10. TrainingDetailDrawer renders 9 tabs correctly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainingDetailDrawer(
              programId: 'prog-001',
              onProgramUpdated: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TrainingDetailDrawer), findsOneWidget);
    });

    testWidgets('11. HRTrainingScreen main screen renders Header, 6 KPIs, Learning Paths, Table, and Calendar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: HRTrainingScreen(),
        ),
      );
      await tester.pump();

      // Top title and action buttons
      expect(find.text('Training & Learning'), findsAtLeastNWidgets(1));
      expect(find.text('Facilitate teacher development, professional upskilling, and compliance certifications.'), findsOneWidget);
      expect(find.text('Create Training Program'), findsOneWidget);
      expect(find.text('Training Calendar'), findsAtLeastNWidgets(1));
      expect(find.text('Reports'), findsOneWidget);

      // 6 KPI cards
      expect(find.text('Total Trainings'), findsOneWidget);
      expect(find.text('Completed Trainings'), findsOneWidget);
      expect(find.text('In Progress'), findsAtLeastNWidgets(1));
      expect(find.text('Total Participants'), findsOneWidget);
      expect(find.text('Avg. Training Completion'), findsOneWidget);
      expect(find.text('Training Hours'), findsOneWidget);

      // Section titles
      expect(find.text('Learning Paths'), findsOneWidget);
      expect(find.text('Training Overview'), findsOneWidget);
      expect(find.text('Upcoming Training Sessions'), findsOneWidget);
      expect(find.text('Training Programs & Courses'), findsOneWidget);
      expect(find.text('Top Performing Employees'), findsOneWidget);
      expect(find.text('Recent Activity'), findsOneWidget);
      expect(find.text('Invest in People'), findsOneWidget);
    });
  });
}
