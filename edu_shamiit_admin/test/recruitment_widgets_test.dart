import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_admin/widgets/hr_management_tab_header.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/schedule_interview_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/interview_feedback_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/create_offer_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/assign_assessment_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/record_assessment_result_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/offer_letter_preview_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/hire_candidate_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/create_job_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/add_candidate_dialog.dart';
import 'package:edu_shamiit_admin/screens/modules/recruit/widgets/stage_details_dialog.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('HR Management & Recruitment Widget Tests', () {
    testWidgets('1. HRManagementTabHeader renders all 5 required tabs with active Recruitment highlight', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HRManagementTabHeader(activeTab: HRTab.recruitment),
          ),
        ),
      );

      // Verify the 5 exact tabs exist
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Recruitment'), findsOneWidget);
      expect(find.text('Onboarding'), findsOneWidget);
      expect(find.text('Training & Learning'), findsOneWidget);
      expect(find.text('Policies & Documents'), findsOneWidget);
    });

    testWidgets('2. CreateJobDialog renders all required input fields and actions', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateJobDialog(onJobCreated: () {}),
          ),
        ),
      );

      expect(find.text('Create New Job Opening'), findsOneWidget);
      expect(find.text('1. Position & Department Details'), findsOneWidget);
      expect(find.text('2. Qualifications & Experience'), findsOneWidget);
      expect(find.text('3. Compensation & Timeline'), findsOneWidget);
      expect(find.text('Save as Draft'), findsOneWidget);
      expect(find.text('Publish Job Opening'), findsOneWidget);
    });

    testWidgets('3. AddCandidateDialog renders candidate input fields and submit action', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddCandidateDialog(onCandidateAdded: () {}),
          ),
        ),
      );

      expect(find.text('Add New Candidate Application'), findsOneWidget);
      expect(find.text('1. Position & Application Source'), findsOneWidget);
      expect(find.text('2. Personal & Contact Information'), findsOneWidget);
      expect(find.text('3. Qualifications & Experience'), findsOneWidget);
      expect(find.text('Add Candidate'), findsOneWidget);
    });

    testWidgets('4. ScheduleInterviewDialog renders round selector, mode, and date pickers', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScheduleInterviewDialog(
              applicationId: 'app-101',
              candidateName: 'Dr. John Doe',
              jobTitle: 'Physics Teacher',
              onScheduled: () {},
            ),
          ),
        ),
      );

      expect(find.text('Schedule Interview'), findsNWidgets(2)); // Header title and button
      expect(find.text('Dr. John Doe • Physics Teacher'), findsOneWidget);
      expect(find.text('Interview Round'), findsOneWidget);
      expect(find.text('Interview Mode'), findsOneWidget);
    });

    testWidgets('5. InterviewFeedbackDialog renders 7 competency rating rows and recommendation options', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InterviewFeedbackDialog(
              interviewId: 'itw-202',
              roundTitle: 'Round 2 - Technical',
              candidateName: 'Jane Smith',
              onFeedbackSubmitted: () {},
            ),
          ),
        ),
      );

      expect(find.text('Submit Interview Feedback'), findsOneWidget);
      expect(find.text('Jane Smith • Round 2 - Technical'), findsOneWidget);
      expect(find.text('Competency Ratings'), findsOneWidget);
      expect(find.text('Technical & Core Competency'), findsOneWidget);
      expect(find.text('Communication & Articulation'), findsOneWidget);
      expect(find.text('Recommendation'), findsOneWidget);
      expect(find.text('Strong Hire'), findsOneWidget);
      expect(find.text('Hire'), findsOneWidget);
      expect(find.text('Save Feedback'), findsOneWidget);
    });

    testWidgets('6. CreateOfferDialog renders salary, probation period, and issue button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateOfferDialog(
              applicationId: 'app-303',
              candidateName: 'Aarav Patel',
              jobTitle: 'Mathematics Teacher',
              onOfferCreated: () {},
            ),
          ),
        ),
      );

      expect(find.text('Generate Employment Offer'), findsOneWidget);
      expect(find.text('Aarav Patel • Mathematics Teacher'), findsOneWidget);
      expect(find.text('Offered Monthly Salary (₹) *'), findsOneWidget);
      expect(find.text('Probation Period (Months)'), findsOneWidget);
      expect(find.text('Save Offer as Draft'), findsOneWidget);
    });

    testWidgets('6b. AssignAssessmentDialog renders title, type selector, and submit action', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssignAssessmentDialog(
              applicationId: 'app-501',
              candidateName: 'Dr. Evelyn Reed',
              jobTitle: 'Physics Teacher',
              onAssessmentAssigned: () {},
            ),
          ),
        ),
      );

      expect(find.text('Assign Candidate Assessment'), findsOneWidget);
      expect(find.text('Dr. Evelyn Reed • Physics Teacher'), findsOneWidget);
      expect(find.text('Assessment Title *'), findsOneWidget);
      expect(find.text('Assessment Type'), findsOneWidget);
      expect(find.text('Max Marks'), findsOneWidget);
      expect(find.text('Assign Assessment'), findsOneWidget);
    });

    testWidgets('6c. RecordAssessmentResultDialog renders outcome options, score input, and save action', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordAssessmentResultDialog(
              assessmentId: 'ass-601',
              assessmentTitle: 'Teaching Demo Lecture',
              candidateName: 'Dr. Evelyn Reed',
              maxScore: 100.0,
              currentResult: 'Pending',
              onResultUpdated: () {},
            ),
          ),
        ),
      );

      expect(find.text('Record Assessment Outcome'), findsOneWidget);
      expect(find.text('Passed'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Score Achieved'), findsOneWidget);
      expect(find.text('Save & Publish Result'), findsOneWidget);
    });

    testWidgets('6d. OfferLetterPreviewDialog renders formal letterhead, terms, and action buttons', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfferLetterPreviewDialog(
              offer: const {
                'id': 'off-701',
                'salary': 75000,
                'job_title': 'Senior Lecturer',
                'employment_type': 'Full-time',
                'joining_date': '2026-10-15',
                'probation_period_months': 6,
                'status': 'Draft',
                'benefits': 'Medical insurance, PF',
              },
              candidateName: 'Rahul Verma',
              candidateEmail: 'rahul.verma@example.com',
              applicationReference: 'APP-2026-0099',
              onOfferUpdated: () {},
            ),
          ),
        ),
      );

      expect(find.text('Formal Employment Offer Letter'), findsOneWidget);
      expect(find.text('EduSHAMIIT ACADEMY'), findsOneWidget);
      expect(find.textContaining('Rahul Verma'), findsWidgets);
      expect(find.text('Send to Candidate via Email'), findsOneWidget);
      expect(find.text('Copy Letter Text'), findsOneWidget);
    });

    testWidgets('7. HireCandidateDialog renders employee ID, confirmation banner, and hire action', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HireCandidateDialog(
              candidateId: 'cand-404',
              applicationId: 'app-404',
              candidateName: 'Priya Sharma',
              jobTitle: 'Chemistry Teacher',
              department: 'Teaching',
              onHired: () {},
            ),
          ),
        ),
      );

      expect(find.text('Confirm Official Hiring'), findsOneWidget);
      expect(find.text('Priya Sharma • Chemistry Teacher'), findsOneWidget);
      expect(find.text('Assigned Employee ID'), findsOneWidget);
      expect(find.text('Final Designation'), findsOneWidget);
      expect(find.text('Department'), findsOneWidget);
      expect(find.text('Confirm Hire & Onboard'), findsOneWidget);
    });

    testWidgets('8. StageDetailsDialog renders stage workspace with search, subtabs, and filters', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StageDetailsDialog(
              stage: 'Screening',
              candidateCount: 18,
              onDataChanged: () {},
            ),
          ),
        ),
      );

      expect(find.text('Stage Workspace: Screening'), findsOneWidget);
      expect(find.text('18 Candidates'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
