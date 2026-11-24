import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/services/work_api_service.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/sprints/work_sprints_tab_view.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/sprints/sprint_task_board_view.dart';

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
    List<String>? assigneeIds,
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
    String? sprintId,
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
    testWidgets('1. Renders subtabs and default All Sprints Grid', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Sub-tabs
      expect(find.text('All Sprints (Grid)'), findsOneWidget);
      expect(find.text('Capacity'), findsOneWidget);
      expect(find.text('Retrospective'), findsOneWidget);

      // Verify removed subtabs
      expect(find.text('Sprint Backlog'), findsNothing);
      expect(find.text('Boards (Task Board)'), findsNothing);

      // Default active view: All Sprints Grid
      expect(find.text('Total Sprints'), findsOneWidget);
      expect(find.text('Active Sprints'), findsOneWidget);
      expect(find.text('Planned Sprints'), findsOneWidget);
      expect(find.text('Total Capacity'), findsWidgets);
    });

    testWidgets('2. Sub-tabs switch between All Sprints, Capacity, and Retrospective', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Capacity
      await tester.tap(find.text('Capacity'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Capacity vs Workload (Daily)'), findsOneWidget);

      // Switch to Retrospective
      await tester.tap(find.text('Retrospective'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Sprint Retrospective'), findsWidgets);

      // Switch back to All Sprints (Grid)
      await tester.tap(find.text('All Sprints (Grid)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Total Sprints'), findsOneWidget);
    });

    testWidgets('3. Standalone Sprint Task Board renders Draggable cards and DragTarget columns', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SprintTaskBoardView(
              items: sampleStories,
              onOpenDetail: (_) {},
              onQuickAction: (_) {},
              sprintId: 's8',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify DragTargets exist for each status column
      expect(find.byType(DragTarget<WorkItemModel>), findsWidgets);

      // Verify Draggable widgets exist for sprint items
      expect(find.byType(Draggable<WorkItemModel>), findsWidgets);
    });
  });
}
