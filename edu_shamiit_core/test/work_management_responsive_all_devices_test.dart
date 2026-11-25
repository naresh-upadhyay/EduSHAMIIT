import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/services/work_api_service.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/backlog/work_backlog_tab_view.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/list/work_list_tab_view.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/board/work_board_tab_view.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/sprints/work_sprints_tab_view.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/sprints/sprint_team_tab_view.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/work_header_bar.dart';

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
      WorkAssigneeModel(
          id: '1', userId: 'u1', fullName: 'King Doe', role: 'Super Admin'),
      WorkAssigneeModel(
          id: '2', userId: 'u2', fullName: 'Dr. Neha Sharma', role: 'Teacher'),
      WorkAssigneeModel(
          id: '3', userId: 'u3', fullName: 'Amit Kumar', role: 'Teacher'),
    ];
  }

  @override
  Future<List<WorkSprintModel>> getSprints(
      {String? boardId, bool forceRefresh = false}) async {
    return const [
      WorkSprintModel(
          id: 's8', name: 'Sprint 8', status: 'ACTIVE', sprintNumber: 8),
      WorkSprintModel(
          id: 's9', name: 'Sprint 9', status: 'PLANNED', sprintNumber: 9),
    ];
  }

  @override
  Future<List<WorkBoardModel>> getBoards({bool forceRefresh = false}) async {
    return const [
      WorkBoardModel(
          id: '31dacd93-15ee-4eed-8994-56973fd81245',
          name: 'Institute Work Board',
          code: 'IWB'),
      WorkBoardModel(id: 'b2', name: 'Academic Board', code: 'AB'),
    ];
  }
}

class MockWorkBacklogNotifier extends WorkBacklogNotifier {
  final WorkBacklogState initialState;
  MockWorkBacklogNotifier(this.initialState);

  @override
  WorkBacklogState get state => initialState;

  @override
  Future<void> loadBacklog(
      {String? boardId,
      String? epicId,
      String? search,
      bool forceRefresh = false}) async {}
}

class MockWorkListNotifier extends WorkListNotifier {
  final WorkListState initialState;
  MockWorkListNotifier(this.initialState);

  @override
  WorkListState get state => initialState;

  @override
  Future<void> loadPagedItems(
      {String? boardId, bool forceRefresh = false}) async {}
}

class MockWorkBoardNotifier extends WorkBoardNotifier {
  final WorkBoardState initialState;
  MockWorkBoardNotifier(this.initialState);

  @override
  WorkBoardState get state => initialState;

  @override
  Future<void> loadBoard({
    String? boardId,
    String? sprintId,
    String? view,
    String? groupBy,
    String? search,
    bool forceRefresh = false,
  }) async {}
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  const testEpic = BacklogEpicModel(
    id: 'ep-001',
    itemNumber: 'EP-001',
    title: '1 Campus Digital Transformation and Modernization Project',
    count: 15,
    description:
        'End-to-end digital transformation of campus operations, services and user experience.',
  );

  const testStory = WorkItemModel(
    id: 'story-1',
    itemNumber: 'ST-101',
    title: 'Student Portal Enhancement with Rich Features',
    workType: 'STORY',
    status: 'ACTIVE',
    priority: 'HIGH',
    storyPoints: 5.0,
    estimatedHours: 40.0,
    remainingHours: 10.0,
    progressPercentage: 75,
    children: [
      WorkItemModel(
        id: 'task-1',
        itemNumber: 'TK-1001',
        title: 'Improve dashboard UI and responsiveness',
        workType: 'TASK',
        status: 'NEW',
        priority: 'MEDIUM',
      ),
      WorkItemModel(
        id: 'task-2',
        itemNumber: 'TK-1002',
        title: 'Add assignment submission and grading flow',
        workType: 'TASK',
        status: 'ACTIVE',
        priority: 'HIGH',
      ),
    ],
  );

  const mockBacklogState = WorkBacklogState(
    stories: [testStory],
    selectedEpic: testEpic,
    epics: [testEpic],
    totalCount: 15,
    kpis: {
      'total_backlog': 15,
      'epics': 3,
      'stories': 8,
      'tasks': 25,
      'bugs': 4,
      'issues': 1,
    },
    isLoading: false,
  );

  const mockListState = WorkListState(
    items: [testStory],
    totalCount: 1,
    boardId: '31dacd93-15ee-4eed-8994-56973fd81245',
    isLoading: false,
  );

  const mockBoardState = WorkBoardState(
    columns: [
      const KanbanColumnModel(
        statusKey: 'NEW',
        name: 'To Do',
        color: '#94A3B8',
        count: 1,
        items: [testStory],
      ),
      const KanbanColumnModel(
        statusKey: 'ACTIVE',
        name: 'In Progress',
        color: '#3B82F6',
        count: 0,
        items: [],
      ),
      const KanbanColumnModel(
        statusKey: 'RESOLVED',
        name: 'Resolved',
        color: '#F59E0B',
        count: 0,
        items: [],
      ),
      const KanbanColumnModel(
        statusKey: 'COMPLETED',
        name: 'Done',
        color: '#10B981',
        count: 0,
        items: [],
      ),
    ],
    isLoading: false,
  );

  final targetViewports = <String, Size>{
    'Mobile (iPhone SE 375x667)': const Size(375, 667),
    'Mobile (Android 412x915)': const Size(412, 915),
    'Tablet (iPad 768x1024)': const Size(768, 1024),
    'Tablet Landscape (1024x768)': const Size(1024, 768),
    'Desktop Compact (1200x800)': const Size(1200, 800),
    'Desktop Standard (1440x900)': const Size(1440, 900),
    'Desktop Full HD (1920x1080)': const Size(1920, 1080),
  };

  group('Work Management Multi-Device Responsiveness - Zero Overflow Guarantee',
      () {
    for (final entry in targetViewports.entries) {
      final deviceName = entry.key;
      final viewportSize = entry.value;

      testWidgets('HeaderBar renders cleanly on $deviceName without overflow',
          (tester) async {
        tester.view.physicalSize = viewportSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WorkHeaderBar(
                onCreateWorkItem: () {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final exc = tester.takeException();
        if (exc != null) {
          debugPrint('>>> OVERFLOW in ListTabView on $deviceName:\n$exc');
          if (exc is FlutterError) {
            for (final d in exc.diagnostics) {
              debugPrint('    ${d.toStringDeep()}');
            }
          }
        }
        expect(exc, isNull);
        expect(find.text('Work Management'), findsOneWidget);
      });

      testWidgets(
          'BacklogTabView renders cleanly on $deviceName with zero overflow',
          (tester) async {
        tester.view.physicalSize = viewportSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              workBacklogProvider.overrideWith(
                  (ref) => MockWorkBacklogNotifier(mockBacklogState)),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: WorkBacklogTabView(
                  onOpenDetail: (_) {},
                  onQuickAction: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // Must have ZERO exceptions / overflows
        final exc = tester.takeException();
        if (exc != null) {
          debugPrint('>>> OVERFLOW in BacklogTabView on $deviceName: $exc');
          if (exc is FlutterError) {
            for (final d in exc.diagnostics) {
              debugPrint('    ${d.toStringDeep()}');
            }
          }
        }
        expect(exc, isNull);
        expect(find.textContaining('EP-001'), findsWidgets);
      });

      testWidgets(
          'ListTabView renders cleanly on $deviceName with zero overflow',
          (tester) async {
        tester.view.physicalSize = viewportSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              workListProvider
                  .overrideWith((ref) => MockWorkListNotifier(mockListState)),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: WorkListTabView(
                  onOpenDetail: (_) {},
                  onQuickAction: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final exc = tester.takeException();
        if (exc != null) {
          debugPrint('>>> OVERFLOW in ListTabView on $deviceName:\n$exc');
          if (exc is FlutterError) {
            for (final d in exc.diagnostics) {
              debugPrint('    ${d.toStringDeep()}');
            }
          }
        }
        expect(exc, isNull);
        expect(find.text('Total Work Items'), findsOneWidget);
      });

      testWidgets(
          'BoardTabView renders cleanly on $deviceName with zero overflow',
          (tester) async {
        tester.view.physicalSize = viewportSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              workBoardProvider
                  .overrideWith((ref) => MockWorkBoardNotifier(mockBoardState)),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: WorkBoardTabView(
                  onOpenDetail: (_) {},
                  onQuickAction: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final exc = tester.takeException();
        if (exc != null) {
          debugPrint('>>> OVERFLOW in ListTabView on $deviceName:\n$exc');
          if (exc is FlutterError) {
            for (final d in exc.diagnostics) {
              debugPrint('    ${d.toStringDeep()}');
            }
          }
        }
        expect(exc, isNull);
      });

      testWidgets(
          'SprintsTabView renders cleanly on $deviceName with zero overflow',
          (tester) async {
        tester.view.physicalSize = viewportSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData.dark(),
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
        await tester.pump(const Duration(milliseconds: 200));

        final exc = tester.takeException();
        if (exc != null) {
          debugPrint('>>> OVERFLOW in ListTabView on $deviceName:\n$exc');
          if (exc is FlutterError) {
            for (final d in exc.diagnostics) {
              debugPrint('    ${d.toStringDeep()}');
            }
          }
        }
        expect(exc, isNull);
        expect(find.text('All Sprints (Grid)'), findsOneWidget);
      });

      testWidgets(
          'SprintTeamTabView renders cleanly on $deviceName with zero overflow',
          (tester) async {
        tester.view.physicalSize = viewportSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SprintTeamTabView(
                  sprintId: 's8',
                  selectedTeam: 'All Teams',
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final exc = tester.takeException();
        if (exc != null) {
          debugPrint('>>> OVERFLOW in ListTabView on $deviceName:\n$exc');
          if (exc is FlutterError) {
            for (final d in exc.diagnostics) {
              debugPrint('    ${d.toStringDeep()}');
            }
          }
        }
        expect(exc, isNull);
        expect(find.text('Total Teams'), findsOneWidget);
      });
    }
  });
}
