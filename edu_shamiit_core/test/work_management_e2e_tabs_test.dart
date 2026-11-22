import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/work_management_screen.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/drawers/work_item_detail_drawer.dart';
import 'package:edu_shamiit_core/screens/work_management/utils/work_sprint_date_helper.dart';

// Mock Http to prevent network image failures in tests
class TestHttpOverrides extends HttpOverrides {
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = TestHttpOverrides();

  group('Work Management Models & JSON Serialization Tests', () {
    test('WorkItemModel parses JSON correctly', () {
      final json = {
        'id': 'wm-1050-id',
        'item_number': 'WM-1050',
        'title': 'Collect and verify student project submissions',
        'description': 'Collect project submissions from all assigned students',
        'work_type': 'TASK',
        'priority': 'MEDIUM',
        'status': 'ACTIVE',
        'category': 'Academic',
        'progress_percentage': 60,
        'estimated_hours': 16.0,
        'story_points': 5.0,
        'due_date': '2025-01-10T18:00:00Z',
        'assignees': [
          {
            'id': 'a1',
            'user_id': 'u1',
            'full_name': 'Prof. Rajesh Verma',
            'role': 'teacher',
            'role_type': 'PRIMARY',
          }
        ],
        'checklists': [
          {'id': 'c1', 'title': 'Receive submissions from students', 'is_completed': true},
          {'id': 'c2', 'title': 'Verify as per evaluation criteria', 'is_completed': true},
          {'id': 'c3', 'title': 'Update final list in the portal', 'is_completed': false},
        ],
        'labels': ['Student Project', 'Academic'],
      };

      final item = WorkItemModel.fromJson(json);

      expect(item.itemNumber, equals('WM-1050'));
      expect(item.title, equals('Collect and verify student project submissions'));
      expect(item.workType, equals('TASK'));
      expect(item.priority, equals('MEDIUM'));
      expect(item.status, equals('ACTIVE'));
      expect(item.category, equals('Academic'));
      expect(item.progressPercentage, equals(60));
      expect(item.assignees.length, equals(1));
      expect(item.assignees.first.fullName, equals('Prof. Rajesh Verma'));
      expect(item.checklists.length, equals(3));
      expect(item.checklists.first.isCompleted, isTrue);
      expect(item.checklists.last.isCompleted, isFalse);
      expect(item.labels, contains('Student Project'));
    });

    test('WorkSprintModel parses JSON correctly', () {
      final json = {
        'id': 's8-id',
        'name': 'Sprint 8',
        'sprint_number': 8,
        'goal': 'Deliver student portal enhancement',
        'status': 'ACTIVE',
        'team_name': 'Digital Campus Team',
        'duration_days': 14,
        'capacity_hours': 160.0,
      };

      final sprint = WorkSprintModel.fromJson(json);
      expect(sprint.name, equals('Sprint 8'));
      expect(sprint.sprintNumber, equals(8));
      expect(sprint.status, equals('ACTIVE'));
      expect(sprint.teamName, equals('Digital Campus Team'));
      expect(sprint.durationDays, equals(14));
    });

    test('BacklogEpicModel parses JSON and children correctly', () {
      final json = {
        'id': 'ep-001-id',
        'item_number': 'EP-001',
        'title': 'Campus Digitalization',
        'description': 'End-to-end digital transformation of campus operations',
        'count': 32,
        'is_selected': false,
      };

      final epic = BacklogEpicModel.fromJson(json);
      expect(epic.itemNumber, equals('EP-001'));
      expect(epic.title, equals('Campus Digitalization'));
      expect(epic.count, equals(32));
    });
  });

  group('Work Management Full Screen & 4 Tabs Widget Tests', () {
    testWidgets('Renders Work Management Shell Header, Tabs Bar, and Board Tab View', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WorkManagementScreen(initialTabIndex: 0),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Header
      expect(find.text('Work Management'), findsWidgets);
      expect(find.text('Plan, assign, track and manage all types of work across the institute.'), findsOneWidget);
      expect(find.text('Create Work Item'), findsOneWidget);

      // Verify All 4 Primary Tabs in Tab Bar
      expect(find.text('Board'), findsOneWidget);
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Backlog'), findsOneWidget);
      expect(find.text('Sprints'), findsOneWidget);

      // Verify Board Tab Sub-filters Bar
      expect(find.text('Board: '), findsOneWidget);
      expect(find.text('Institute Work Board'), findsWidgets);
      expect(find.text('View: '), findsOneWidget);
      expect(find.text('Sprint: '), findsOneWidget);
      expect(find.text('Group by: '), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);

      // Verify 4 Kanban Columns
      expect(find.text('New'), findsWidgets);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Resolved'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);

      // Verify Board Right Sidebar
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('New Task'), findsOneWidget);
      expect(find.text('New Story'), findsOneWidget);
      expect(find.text('Report Bug'), findsOneWidget);
      expect(find.text('New Epic'), findsOneWidget);
      expect(find.text('My Work Summary'), findsOneWidget);
      expect(find.text('Overall Progress'), findsOneWidget);
    });

    testWidgets('Switches to List Tab and renders 6 KPI cards & Data Table', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WorkManagementScreen(initialTabIndex: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify 6 KPI Cards
      expect(find.text('Total Work Items'), findsOneWidget);
      expect(find.text('New'), findsWidgets);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Resolved'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Overdue'), findsWidgets);

      // Verify List Table Headers
      expect(find.text('ID'), findsOneWidget);
      expect(find.text('Title'), findsWidgets);
      expect(find.text('Type'), findsWidgets);
      expect(find.text('Priority'), findsWidgets);
      expect(find.text('Status'), findsWidgets);
      expect(find.text('Assignee(s)'), findsWidgets);
      expect(find.text('Due Date'), findsWidgets);
      expect(find.text('Progress'), findsWidgets);
    });

    testWidgets('Switches to Backlog Tab and renders Epics Sidebar & Story Tree', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WorkManagementScreen(initialTabIndex: 2),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Backlog Top KPIs
      expect(find.text('Total Backlog Items'), findsOneWidget);
      expect(find.text('Epics'), findsOneWidget);
      expect(find.text('Stories'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Bugs'), findsOneWidget);
      expect(find.text('Issues'), findsOneWidget);

      // Verify Epics Sidebar
      expect(find.text('Epics (12)'), findsOneWidget);
      expect(find.textContaining('EP-001'), findsWidgets);
      expect(find.textContaining('Campus Digitalization'), findsWidgets);

      // Verify Backlog Action Bar
      expect(find.text('Search in backlog...'), findsOneWidget);
      expect(find.text('Add Work Item'), findsWidgets);
      expect(find.text('Reorder'), findsOneWidget);
      expect(find.text('Bulk Actions'), findsOneWidget);
    });

    testWidgets('Switches to Sprints Tab and renders Sprint Dashboard, KPIs, and Burndown', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WorkManagementScreen(initialTabIndex: 3),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Sprint Header Card & Status
      expect(find.text('Sprint 8'), findsWidgets);
      expect(find.text('Active'), findsWidgets);
      expect(find.textContaining(WorkSprintDateHelper.currentSprintStartFmt), findsWidgets);

      // Verify 5 Sprint KPI Cards
      expect(find.text('Total Items'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('In Progress'), findsWidgets);
      expect(find.text('Not Started'), findsWidgets);
      expect(find.text('Blocked'), findsWidgets);

      // Verify Sprint Goal Card & Burndown
      expect(find.text('Sprint Goal'), findsWidgets);
      expect(find.text('Sprint Burndown'), findsOneWidget);

      // Verify Sub-tabs
      expect(find.text('Sprint Backlog'), findsOneWidget);
      expect(find.text('Boards (Task Board)'), findsOneWidget);
      expect(find.text('Capacity'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('Retrospective'), findsOneWidget);

      // Verify Right Column Widgets
      expect(find.text('Sprint Details'), findsOneWidget);
      expect(find.text('Sprint Progress by Type'), findsOneWidget);
      expect(find.text('Upcoming Sprints'), findsOneWidget);
      expect(find.text('Sprint 9'), findsWidgets);
      expect(find.text('Sprint 10'), findsWidgets);
    });

    testWidgets('Opens Create Work Item Dialog when Create button is clicked', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WorkManagementScreen(initialTabIndex: 0),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Click Create Work Item dropdown
      await tester.tap(find.text('Create Work Item'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Select 'New Task' from menu
      await tester.tap(find.text('New Task').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Dialog renders with fields
      expect(find.text('Create New Work Item'), findsOneWidget);
      expect(find.text('Work Type'), findsOneWidget);
      expect(find.text('Priority'), findsOneWidget);
      expect(find.text('Title *'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Kanban Board provides DragTarget widgets for drag-and-drop across columns', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WorkManagementScreen(initialTabIndex: 0),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify DragTargets for all 4 status columns (New, Active, Resolved, Completed)
      expect(find.byType(DragTarget<WorkItemModel>), findsWidgets);
    });

    testWidgets('WorkItemDetailDrawer renders Azure DevOps effort and audit history tabs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const testItem = WorkItemModel(
        id: 'test-item-1',
        itemNumber: 'WM-1050',
        title: 'Collect and verify student project submissions',
        description: 'Collect project submissions from all students',
        workType: 'TASK',
        priority: 'MEDIUM',
        status: 'ACTIVE',
        progressPercentage: 60,
        estimatedHours: 16.0,
        remainingHours: 6.0,
        actualHours: 10.0,
        storyPoints: 5.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WorkItemDetailDrawer(
                item: testItem,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Header & Item Number
      expect(find.text('WM-1050'), findsOneWidget);
      expect(find.text('TASK'), findsOneWidget);
      expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);

      // Verify Tabs
      expect(find.text('Details'), findsOneWidget);
      expect(find.textContaining('Comments'), findsOneWidget);
      expect(find.textContaining('Activity'), findsOneWidget);
      expect(find.textContaining('Links'), findsOneWidget);

      // Verify Effort Box & Progress
      expect(find.text('Effort & Progress'), findsOneWidget);
      expect(find.text('Original (h)'), findsOneWidget);
      expect(find.text('Remaining (h)'), findsOneWidget);
      expect(find.text('Completed (h)'), findsOneWidget);
      expect(find.text('Save Effort'), findsOneWidget);
    });

    testWidgets('Sprint Screen sub-tabs switch between Task Board, Capacity, Team, and Retrospective', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WorkManagementScreen(initialTabIndex: 3),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify Sprint Sub-Tabs including All Sprints (Grid)
      expect(find.text('Sprint Backlog'), findsOneWidget);
      expect(find.text('Boards (Task Board)'), findsOneWidget);
      expect(find.text('All Sprints (Grid)'), findsOneWidget);
      expect(find.text('Capacity'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('Retrospective'), findsOneWidget);

      // 2. Switch to All Sprints (Grid)
      await tester.tap(find.text('All Sprints (Grid)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Total Sprints'), findsOneWidget);
      expect(find.text('Active Sprints'), findsOneWidget);
      expect(find.text('Planned Sprints'), findsOneWidget);
      expect(find.text('Total Capacity'), findsWidgets);
      expect(find.text('Create Sprint'), findsOneWidget);
      expect(find.text('Search sprints by name, goal, team...'), findsOneWidget);

      // 3. Verify Right Sidebar on Sprint Backlog
      await tester.tap(find.text('Sprint Backlog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Sprint Details'), findsOneWidget);
      expect(find.text('Sprint Progress by Type'), findsOneWidget);
      expect(find.text('Upcoming Sprints'), findsOneWidget);

      // 4. Switch to Boards (Task Board)
      await tester.tap(find.text('Boards (Task Board)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Sprint Task Board'), findsOneWidget);

      // 5. Switch to Capacity
      await tester.tap(find.text('Capacity'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Total Capacity'), findsWidgets);
      expect(find.text('Planned Work'), findsWidgets);
      expect(find.text('Remaining'), findsWidgets);
      expect(find.text('Capacity vs Workload (Daily)'), findsOneWidget);
      expect(find.text('Team Member Capacity & Workload (7)'), findsOneWidget);

      // 6. Switch to Team
      await tester.tap(find.text('Team'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Total Teams'), findsWidgets);
      expect(find.text('Total Members'), findsWidgets);

      // 7. Switch to Retrospective
      await tester.tap(find.text('Retrospective'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('What Went Well'), findsOneWidget);
      expect(find.textContaining("What Didn't Go Well"), findsOneWidget);
      expect(find.textContaining('What Should Improve'), findsOneWidget);
      expect(find.textContaining('Retrospective Action Items'), findsOneWidget);
    });

    testWidgets('AllSprintsGridView renders KPIs, filters, search bar, and grid actions', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WorkManagementScreen(initialTabIndex: 3),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Click on All Sprints (Grid) subtab
      await tester.tap(find.text('All Sprints (Grid)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify KPI Summary Cards
      expect(find.text('Total Sprints'), findsOneWidget);
      expect(find.text('Active Sprints'), findsOneWidget);
      expect(find.text('Planned Sprints'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);

      // Verify Action buttons in Grid
      expect(find.text('Create Sprint'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsWidgets);
    });
  });
}
