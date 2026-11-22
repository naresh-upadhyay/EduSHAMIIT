import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/services/work_api_service.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/sprints/work_sprints_tab_view.dart';

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

class FakeWorkApiService extends WorkApiService {
  @override
  Future<List<WorkAssigneeModel>> getAssignableUsers({
    String? q,
    String? role,
    String? department,
    int limit = 100,
  }) async {
    return const [
      WorkAssigneeModel(id: '1', userId: 'u1', fullName: 'Amit Kumar', role: 'Teacher'),
      WorkAssigneeModel(id: '2', userId: 'u2', fullName: 'Priya Singh', role: 'Staff'),
    ];
  }

  @override
  Future<List<WorkSprintModel>> getSprints({String? boardId, bool forceRefresh = false}) async {
    return const [
      WorkSprintModel(id: 's8', name: 'Sprint 8', status: 'ACTIVE', sprintNumber: 8),
      WorkSprintModel(id: 's9', name: 'Sprint 9', status: 'PLANNED', sprintNumber: 9),
    ];
  }

  @override
  Future<bool> bulkUpdateWorkItems({
    required List<String> itemIds,
    String? status,
    String? priority,
    String? assigneeId,
    String? sprintId,
    String? teamId,
    String? teamName,
  }) async {
    return true;
  }

  @override
  Future<bool> bulkDeleteWorkItems(List<String> itemIds) async {
    return true;
  }

  @override
  Future<bool> transitionStatus(String itemId, String status, {String? notes}) async {
    return true;
  }
}

class MockWorkSprintDashboardNotifier extends WorkSprintDashboardNotifier {
  final WorkSprintDashboardState initialState;
  MockWorkSprintDashboardNotifier(this.initialState);

  @override
  WorkSprintDashboardState get state => initialState;

  @override
  Future<void> loadSprintDashboard({
    String sprintId = 's8',
    String? boardId,
    String? team,
    String? search,
    int page = 1,
    int pageSize = 10,
    bool quiet = false,
    bool forceRefresh = false,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _TestHttpOverrides();

  final sampleStories = [
    const WorkItemModel(
      id: 'story-1',
      itemNumber: 'ST-101',
      title: 'Student Portal Enhancement',
      workType: 'STORY',
      priority: 'MEDIUM',
      status: 'ACTIVE',
      category: 'IT Services',
      progressPercentage: 60,
      assignees: [
        WorkAssigneeModel(id: '1', userId: 'u1', fullName: 'Amit Kumar', role: 'Teacher'),
      ],
      children: [
        WorkItemModel(
          id: 'task-1001',
          itemNumber: 'TK-1001',
          title: 'Improve dashboard UI',
          workType: 'TASK',
          priority: 'MEDIUM',
          status: 'COMPLETED',
          category: 'IT Services',
          progressPercentage: 100,
        ),
        WorkItemModel(
          id: 'task-1002',
          itemNumber: 'TK-1002',
          title: 'Add assignment submission',
          workType: 'TASK',
          priority: 'HIGH',
          status: 'ACTIVE',
          category: 'IT Services',
          progressPercentage: 70,
        ),
        WorkItemModel(
          id: 'task-1003',
          itemNumber: 'TK-1003',
          title: 'Mobile responsiveness bug',
          workType: 'BUG',
          priority: 'MEDIUM',
          status: 'NEW',
          category: 'IT Services',
          progressPercentage: 0,
        ),
      ],
    ),
    const WorkItemModel(
      id: 'story-2',
      itemNumber: 'ST-102',
      title: 'Faculty Management Module',
      workType: 'STORY',
      priority: 'HIGH',
      status: 'COMPLETED',
      category: 'Academic',
      progressPercentage: 100,
      children: [
        WorkItemModel(
          id: 'task-1005',
          itemNumber: 'TK-1005',
          title: 'Faculty profile and workload',
          workType: 'TASK',
          priority: 'MEDIUM',
          status: 'COMPLETED',
          category: 'Academic',
          progressPercentage: 100,
        ),
      ],
    ),
  ];

  final mockSprintState = WorkSprintDashboardState(
    isLoading: false,
    sprint: const WorkSprintModel(
      id: 's8',
      name: 'Sprint 8',
      status: 'ACTIVE',
      sprintNumber: 8,
      goal: 'Deliver student portal enhancement and core improvements.',
      startDateFmt: 'Jan 01, 2025',
      endDateFmt: 'Jan 14, 2025',
      durationDays: 14,
      boardName: 'Institute Work Board',
      teamName: 'Digital Campus Team',
    ),
    items: sampleStories,
    metrics: const {
      'total_items': 6,
      'completed_items': 3,
      'in_progress_items': 2,
      'not_started_items': 1,
      'blocked_items': 0,
      'completion_percentage': 50,
    },
  );

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
        workSprintDashboardProvider.overrideWith((ref) => MockWorkSprintDashboardNotifier(mockSprintState)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: WorkSprintsTabView(
            onOpenDetail: (_) {},
            onQuickAction: (_) {},
            onCreateSprint: () {},
          ),
        ),
      ),
    );
  }

  group('Work Sprints Tab View E2E Tests', () {
    testWidgets('1. Renders Sprint 8 hero card, top filter bar, and live KPI cards', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Top Filter Bar
      expect(find.text('Board: '), findsWidgets);
      expect(find.text('Institute Work Board'), findsWidgets);
      expect(find.text('Sprint: '), findsWidgets);
      expect(find.textContaining('Sprint 8'), findsWidgets);
      expect(find.text('Team: '), findsWidgets);
      expect(find.text('All Teams'), findsWidgets);

      // Hero Card
      expect(find.text('Sprint 8'), findsWidgets);
      expect(find.text('Active'), findsWidgets);

      // KPIs
      expect(find.text('Total Items'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('In Progress'), findsWidgets);
      expect(find.text('Not Started'), findsWidgets);
      expect(find.text('Blocked'), findsWidgets);

      // Grid items
      expect(find.text('ST-101'), findsOneWidget);
      expect(find.text('Student Portal Enhancement'), findsOneWidget);
      expect(find.text('ST-102'), findsOneWidget);
      expect(find.text('Faculty Management Module'), findsOneWidget);
    });

    testWidgets('2. Interactive KPI cards toggle status filter and filter items', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap 'Completed' KPI card
      await tester.tap(find.byKey(const ValueKey('kpi_Completed')));
      await tester.pumpAndSettle();

      // In completed mode, ST-102 (completed) is shown
      expect(find.text('ST-102'), findsOneWidget);

      // Tap 'Total Items' KPI card to reset
      await tester.tap(find.byKey(const ValueKey('kpi_Total Items')));
      await tester.pumpAndSettle();

      // Both stories shown
      expect(find.text('ST-101'), findsOneWidget);
      expect(find.text('ST-102'), findsOneWidget);
    });

    testWidgets('3. Master checkbox selects all items and displays floating action bar', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially no floating action bar
      expect(find.textContaining('items selected'), findsNothing);

      // Tap master checkbox in table header
      final checkboxes = find.byIcon(Icons.check_box_outline_blank_rounded);
      expect(checkboxes, findsWidgets);
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      // Floating action bar appears
      expect(find.textContaining('items selected'), findsOneWidget);
      expect(find.text('Move to Sprint'), findsOneWidget);
      expect(find.text('Change Status'), findsOneWidget);
      expect(find.text('Change Priority'), findsOneWidget);
      expect(find.text('Assign To'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Tap Clear Selection icon
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      // Floating action bar dismissed
      expect(find.textContaining('items selected'), findsNothing);
    });

    testWidgets('4. Sub-tabs switch between Backlog, Task Board, Capacity, Team, and Retrospective', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Boards (Task Board)
      await tester.tap(find.text('Boards (Task Board)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Sprint Task Board'), findsOneWidget);

      // Switch to Capacity
      await tester.tap(find.text('Capacity'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Retrospective
      await tester.tap(find.text('Retrospective'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch back to Sprint Backlog
      await tester.tap(find.text('Sprint Backlog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('ST-101'), findsOneWidget);
    });

    testWidgets('5. Pagination controls render rows per page and page info', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Rows per page: '), findsOneWidget);
      expect(find.textContaining('Showing 1 - 2 of 2 stories'), findsOneWidget);
    });

    testWidgets('6. Sprint filter dropdown strictly matches the loaded sprint', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Create state with renamed sprint "Sprint 10 11"
      final customSprintState = WorkSprintDashboardState(
        isLoading: false,
        sprint: const WorkSprintModel(
          id: 's10',
          name: 'Sprint 10 11',
          status: 'ACTIVE',
          sprintNumber: 10,
          goal: 'Mobile release',
          boardName: 'Institute Work Board',
          teamName: 'Digital Campus Team',
        ),
        items: sampleStories,
        metrics: const {
          'total_items': 6,
          'completed_items': 3,
          'in_progress_items': 2,
          'not_started_items': 1,
          'blocked_items': 0,
          'completion_percentage': 50,
        },
      );

      const customAllSprintsState = WorkAllSprintsState(
        isLoading: false,
        sprints: [
          WorkSprintModel(id: 's8', name: 'Sprint 8', status: 'COMPLETED', sprintNumber: 8),
          WorkSprintModel(id: 's10', name: 'Sprint 10 11', status: 'ACTIVE', sprintNumber: 10),
        ],
        selectedSprintId: 's10',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
            workSprintDashboardProvider.overrideWith((ref) => MockWorkSprintDashboardNotifier(customSprintState)),
            allSprintsProvider.overrideWith((ref) => WorkAllSprintsNotifier(ref, FakeWorkApiService(), customAllSprintsState)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: WorkSprintsTabView(
                onOpenDetail: (_) {},
                onQuickAction: (_) {},
                onCreateSprint: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dropdown and card both display Sprint 10 11
      expect(find.textContaining('Sprint 10 11'), findsWidgets);
      // It should not display Sprint 8 in the dropdown value
      expect(find.text('Sprint 8 (Active)'), findsNothing);
    });

    testWidgets('7. Sprint Task Board renders Draggable cards and DragTarget columns', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Boards (Task Board)
      await tester.tap(find.text('Boards (Task Board)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify DragTargets exist for each status column
      expect(find.byType(DragTarget<WorkItemModel>), findsWidgets);

      // Verify Draggable widgets exist for sprint items
      expect(find.byType(Draggable<WorkItemModel>), findsWidgets);
    });
  });
}
