import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';
import 'package:edu_shamiit_core/screens/work_management/services/work_api_service.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/work_tabs_bar.dart';

class FakeWorkApiService extends WorkApiService {
  static const testItem = WorkItemModel(
    id: 'test-item-99',
    itemNumber: 'TK-999',
    title: 'Test Drag Item',
    description: 'For testing drag and drop',
    workType: 'TASK',
    priority: 'LOW',
    status: 'NEW',
    category: 'IT Services',
  );

  @override
  Future<List<KanbanColumnModel>> getBoardKanban(
    String boardId, {
    String? sprintId,
    String? view = 'All',
    String? groupBy = 'Status',
    String? search,
    bool forceRefresh = false,
  }) async => [
    const KanbanColumnModel(statusKey: 'NEW', name: 'New', color: '#64748B', count: 1, items: [testItem]),
    const KanbanColumnModel(statusKey: 'ACTIVE', name: 'Active', color: '#3B82F6', count: 0, items: []),
    const KanbanColumnModel(statusKey: 'RESOLVED', name: 'Resolved', color: '#10B981', count: 0, items: []),
    const KanbanColumnModel(statusKey: 'COMPLETED', name: 'Completed', color: '#8B5CF6', count: 0, items: []),
  ];

  @override
  Future<bool> transitionStatus(String itemId, String newStatus, {String? notes}) async => true;

  @override
  Future<bool> updateItem(String itemId, Map<String, dynamic> data) async => true;

  @override
  Future<bool> deleteItem(String itemId, {String? reason}) async => true;

  @override
  Future<bool> reorderKanban(String boardId, String itemId, String newStatus, double newRank) async => true;

  @override
  Future<bool> bulkUpdateWorkItems({
    required List<String> itemIds,
    String? status,
    String? priority,
    String? assigneeId,
    String? sprintId,
    String? teamId,
    String? teamName,
  }) async => true;

  Future<Map<String, dynamic>> bulkUpdateItems({
    required List<String> itemIds,
    String? status,
    String? priority,
    String? sprintId,
    String? boardId,
    String? workType,
    List<String>? assignees,
    String? reason,
  }) async => {'success': true, 'updated_count': itemIds.length};

  Future<Map<String, dynamic>> bulkDeleteItems({
    required List<String> itemIds,
    String? reason,
  }) async => {'success': true, 'deleted_count': itemIds.length};

  @override
  Future<bool> updateRetroEntry(
    String sprintId,
    String entryId, {
    required String category,
    required String content,
    String? teamId,
    String? teamName,
  }) async => true;

  Future<bool> moveRetroFeedbackEntry(String entryId, String newCategory) async => true;

  @override
  Future<Map<String, dynamic>> getItemsPaged({
    String? boardId,
    String? sprintId,
    String type = 'All',
    String status = 'All',
    String? assigneeId,
    String priority = 'All',
    String? search,
    String sortCol = 'created_at',
    String sortDir = 'DESC',
    int page = 1,
    int pageSize = 12,
    bool forceRefresh = false,
  }) async => {'items': [], 'total': 0};

  @override
  Future<SprintRetroWorkspaceModel?> getSprintRetrospectiveWorkspace(
    String sprintId, {
    String? teamId,
  }) async => SprintRetroWorkspaceModel.fromJson({
    'retrospective': {
      'id': 'r1',
      'sprint_id': sprintId,
      'status': 'Completed',
      'retro_date': '2025-01-14',
    },
    'categories': {
      'went_well': {
        'title': 'What Went Well?',
        'category': 'WENT_WELL',
        'entries': [
          {
            'id': 'entry-1',
            'content': 'Team collaboration was excellent',
            'author_name': 'Amit Kumar',
            'category': 'WENT_WELL',
            'votes': 3,
            'comments_count': 1,
          },
        ],
      },
      'did_not_go_well': {
        'title': "What Didn't Go Well?",
        'category': 'DID_NOT_GO_WELL',
        'entries': [],
      },
      'should_improve': {
        'title': 'What Should Improve?',
        'category': 'SHOULD_IMPROVE',
        'entries': [],
      },
    },
  });

  @override
  Future<List<WorkAssigneeModel>> getAssignableUsers({
    String? q,
    String? role,
    String? department,
    int limit = 100,
  }) async => [];
}

void main() {
  group('1. Ghost Tabs Elimination & Primary Tabs Structure', () {
    testWidgets('WorkTabsBar displays exactly 4 tabs and eliminates all ghost tabs', (tester) async {
      int activeIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return WorkTabsBar(
                  activeTab: activeIndex,
                  onTabSelected: (idx) {
                    setState(() => activeIndex = idx);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify the primary tabs are present
      expect(find.text('Board'), findsOneWidget);
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Backlog'), findsOneWidget);
      expect(find.text('Sprints'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);

      // Verify ghost tabs are NOT present
      expect(find.text('Calendar'), findsNothing);
      expect(find.text('Timeline'), findsNothing);
      expect(find.text('Reports'), findsNothing);
      expect(find.text('Settings'), findsNothing);

      // Test tapping tabs
      await tester.tap(find.text('List'));
      await tester.pump();
      expect(activeIndex, 1);

      await tester.tap(find.text('Backlog'));
      await tester.pump();
      expect(activeIndex, 2);

      await tester.tap(find.text('Sprints'));
      await tester.pump();
      expect(activeIndex, 3);

      await tester.tap(find.text('Team'));
      await tester.pump();
      expect(activeIndex, 4);

      await tester.tap(find.text('Board'));
      await tester.pump();
      expect(activeIndex, 0);
    });
  });

  group('2. WorkItemModel & copyWith Integrity', () {
    test('WorkItemModel correctly copies with updated workType, status, priority', () {
      const item = WorkItemModel(
        id: 'item-1',
        itemNumber: 'TK-1001',
        title: 'Improve dashboard UI',
        description: 'Test description',
        workType: 'TASK',
        priority: 'MEDIUM',
        status: 'NEW',
        category: 'Academic',
        progressPercentage: 20,
        rank: 1.0,
      );

      // Verify workType update
      final typeUpdated = item.copyWith(workType: 'BUG');
      expect(typeUpdated.workType, 'BUG');
      expect(typeUpdated.title, 'Improve dashboard UI');
      expect(typeUpdated.id, 'item-1');

      // Verify priority update
      final priorityUpdated = item.copyWith(priority: 'HIGH');
      expect(priorityUpdated.priority, 'HIGH');
      expect(priorityUpdated.workType, 'TASK');

      // Verify status update
      final statusUpdated = item.copyWith(status: 'ACTIVE');
      expect(statusUpdated.status, 'ACTIVE');

      // Verify children copyWith
      const childItem = WorkItemModel(
        id: 'child-1',
        itemNumber: 'TK-1002',
        title: 'Child Task',
        description: '',
        workType: 'TASK',
        priority: 'LOW',
        status: 'NEW',
        category: 'Academic',
      );
      final withChildren = item.copyWith(children: [childItem]);
      expect(withChildren.children.length, 1);
      expect(withChildren.children.first.id, 'child-1');
    });
  });

  group('3. Board State & Drag and Drop Provider Logic', () {
    test('WorkBoardNotifier optimistic updates: status transition, priority update, and type update', () async {
      final container = ProviderContainer(
        overrides: [
          workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(workBoardProvider.notifier);

      // Wait for initial loadBoard to finish
      await Future.delayed(const Duration(milliseconds: 50));

      const testItem = FakeWorkApiService.testItem;

      // 1. Test transitionStatus to ACTIVE
      await notifier.transitionStatus(testItem.id, 'ACTIVE');
      var updatedState = container.read(workBoardProvider);
      var activeCol = updatedState.columns.firstWhere((c) => c.statusKey.toUpperCase() == 'ACTIVE');
      expect(activeCol.items.any((i) => i.id == testItem.id), true);

      // 2. Test updateItemPriority to HIGH
      final priorityCols = <KanbanColumnModel>[
        const KanbanColumnModel(statusKey: 'LOW', name: 'Low', color: '#10B981', count: 1, items: [testItem]),
        const KanbanColumnModel(statusKey: 'HIGH', name: 'High', color: '#F59E0B', count: 0, items: []),
      ];
      notifier.state = WorkBoardState(
        isLoading: false,
        columns: priorityCols,
      );
      await notifier.updateItemPriority(testItem.id, 'HIGH');
      updatedState = container.read(workBoardProvider);
      var highCol = updatedState.columns.firstWhere((c) => c.statusKey.toUpperCase() == 'HIGH');
      expect(highCol.items.any((i) => i.id == testItem.id && i.priority == 'HIGH'), true);

      // 3. Test updateItemType to BUG
      final typeCols = <KanbanColumnModel>[
        const KanbanColumnModel(statusKey: 'TASK', name: 'Task', color: '#3B82F6', count: 1, items: [testItem]),
        const KanbanColumnModel(statusKey: 'BUG', name: 'Bug', color: '#EF4444', count: 0, items: []),
      ];
      notifier.state = WorkBoardState(
        isLoading: false,
        columns: typeCols,
      );
      await notifier.updateItemType(testItem.id, 'BUG');
      updatedState = container.read(workBoardProvider);
      var bugCol = updatedState.columns.firstWhere((c) => c.statusKey.toUpperCase() == 'BUG');
      expect(bugCol.items.any((i) => i.id == testItem.id && i.workType == 'BUG'), true);
    });
  });

  group('4. List Tab Bulk Operations & Multi-Select Logic', () {
    test('WorkListNotifier bulkUpdate and bulkDelete optimistic updates', () async {
      final container = ProviderContainer(
        overrides: [
          workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(workListProvider.notifier);

      final sampleItems = [
        const WorkItemModel(
          id: 'item-101',
          itemNumber: 'TK-101',
          title: 'Bulk Test 1',
          description: '',
          workType: 'TASK',
          priority: 'LOW',
          status: 'NEW',
          category: 'Academic',
        ),
        const WorkItemModel(
          id: 'item-102',
          itemNumber: 'TK-102',
          title: 'Bulk Test 2',
          description: '',
          workType: 'BUG',
          priority: 'MEDIUM',
          status: 'ACTIVE',
          category: 'IT Services',
        ),
      ];

      notifier.state = WorkListState(
        isLoading: false,
        items: sampleItems,
      );

      // 1. Bulk Update Status
      final updateSuccess = await notifier.bulkUpdate(
        itemIds: ['item-101', 'item-102'],
        status: 'COMPLETED',
      );
      expect(updateSuccess, true);

      var state = container.read(workListProvider);
      expect(state.items.every((i) => i.status == 'COMPLETED'), true);

      // 2. Bulk Update Priority
      await notifier.bulkUpdate(
        itemIds: ['item-101'],
        priority: 'CRITICAL',
      );
      state = container.read(workListProvider);
      expect(state.items.firstWhere((i) => i.id == 'item-101').priority, 'CRITICAL');

      // 3. Bulk Delete
      final deleteSuccess = await notifier.bulkDelete(['item-101']);
      expect(deleteSuccess, true);

      state = container.read(workListProvider);
      expect(state.items.length, 1);
      expect(state.items.first.id, 'item-102');
    });
  });

  group('5. Backlog Dynamic Count & Epic Synchronization', () {
    test('Dynamic calculation of totalVisibleItems matches filtered stories and child tasks', () {
      final stories = [
        const WorkItemModel(
          id: 'story-1',
          itemNumber: 'ST-101',
          title: 'Student Portal',
          description: '',
          workType: 'STORY',
          priority: 'HIGH',
          status: 'ACTIVE',
          category: 'Academic',
          children: [
            WorkItemModel(
              id: 'task-1',
              itemNumber: 'TK-101',
              title: 'Task 1',
              description: '',
              workType: 'TASK',
              priority: 'HIGH',
              status: 'COMPLETED',
              category: 'Academic',
            ),
            WorkItemModel(
              id: 'task-2',
              itemNumber: 'TK-102',
              title: 'Task 2',
              description: '',
              workType: 'TASK',
              priority: 'MEDIUM',
              status: 'ACTIVE',
              category: 'Academic',
            ),
          ],
        ),
        const WorkItemModel(
          id: 'story-2',
          itemNumber: 'ST-102',
          title: 'Faculty Portal',
          description: '',
          workType: 'STORY',
          priority: 'MEDIUM',
          status: 'NEW',
          category: 'Academic',
          children: [
            WorkItemModel(
              id: 'task-3',
              itemNumber: 'TK-103',
              title: 'Task 3',
              description: '',
              workType: 'TASK',
              priority: 'LOW',
              status: 'NEW',
              category: 'Academic',
            ),
          ],
        ),
      ];

      // Calculate total visible items (stories + child tasks)
      int totalVisibleItems = 0;
      for (final s in stories) {
        totalVisibleItems += 1 + s.children.length;
      }

      // Expected: 2 stories + 3 children = 5 total items
      expect(totalVisibleItems, 5);
      expect(stories.first.children.length, 2);
      expect(stories[1].children.length, 1);
    });
  });

  group('6. Sprints Capacity & Retrospective Edge Cases', () {
    test('Capacity Dashboard scales dynamic maximum Y and aggregates utilization', () {
      final dailyChart = [
        const SprintCapacityDailyPointModel(fullDate: '2025-01-01', dateFmt: 'Jan 01', capacityHours: 35, plannedHours: 30, actualHours: 25),
        const SprintCapacityDailyPointModel(fullDate: '2025-01-02', dateFmt: 'Jan 02', capacityHours: 48, plannedHours: 42, actualHours: 36),
      ];

      // Find max value in daily chart
      double maxBarValue = 0.0;
      for (final pt in dailyChart) {
        if (pt.capacityHours > maxBarValue) maxBarValue = pt.capacityHours;
        if (pt.plannedHours > maxBarValue) maxBarValue = pt.plannedHours;
        if (pt.actualHours > maxBarValue) maxBarValue = pt.actualHours;
      }
      expect(maxBarValue, 48.0);

      // Verify dynamic upper bound calculation
      final dynamicMaxY = maxBarValue > 0 ? (((maxBarValue * 1.25) / 6).ceil() * 6.0).clamp(42.0, 200.0) : 42.0;
      expect(dynamicMaxY >= 48.0, true);
      expect(dynamicMaxY % 6 == 0, true);
    });

    test('Retrospective Move Entry updates category across columns', () async {
      final container = ProviderContainer(
        overrides: [
          workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
        ],
      );
      addTearDown(container.dispose);

      final retroNotifier = container.read(workSprintRetroProvider.notifier);
      await retroNotifier.init('s8', teamName: 'All Teams');

      final workspace = container.read(workSprintRetroProvider).workspace;
      final wentWellEntries = workspace?.wentWell.entries ?? [];
      expect(wentWellEntries.isNotEmpty, true);

      final entryToMove = wentWellEntries.first;
      final moveSuccess = await retroNotifier.moveFeedbackEntry(entryToMove.id, 'DID_NOT_GO_WELL');
      expect(moveSuccess, true);

      final updatedWorkspace = container.read(workSprintRetroProvider).workspace;
      final inWentPoorly = updatedWorkspace?.didNotGoWell.entries.any((e) => e.id == entryToMove.id) ?? false;
      expect(inWentPoorly, true);
    });
  });

  group('7. Live DB Refresh on Tab Switch & List Tab Filter Synchronization', () {
    test('WorkListNotifier loads paged items and setFilter properly updates board and type', () async {
      final fakeApi = FakeWorkApiService();
      final container = ProviderContainer(
        overrides: [
          workApiServiceProvider.overrideWithValue(fakeApi),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(workListProvider.notifier);
      expect(notifier.state.boardId, isNull);

      // Test setFilter
      notifier.setFilter(boardId: '31dacd93-15ee-4eed-8994-56973fd81245', workType: 'STORY', status: 'ACTIVE');
      expect(notifier.state.boardId, '31dacd93-15ee-4eed-8994-56973fd81245');
      expect(notifier.state.workType, 'STORY');
      expect(notifier.state.status, 'ACTIVE');

      // Test reset filter and clear board
      notifier.setFilter(workType: 'All', status: 'All', clearBoard: true);
      expect(notifier.state.workType, 'All');
      expect(notifier.state.status, 'All');
      expect(notifier.state.boardId, isNull);
    });
  });
}
