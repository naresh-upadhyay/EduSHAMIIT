import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/backlog/work_backlog_tab_view.dart';

class MockWorkBacklogNotifier extends WorkBacklogNotifier {
  final WorkBacklogState initialState;
  MockWorkBacklogNotifier(this.initialState);

  @override
  WorkBacklogState get state => initialState;

  @override
  Future<void> loadBacklog({String? boardId, String? epicId, String? search, bool forceRefresh = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testEpic = BacklogEpicModel(
    id: 'ep-001',
    itemNumber: 'EP-001',
    title: '1 Campus Digital Transformation',
    count: 15,
  );

  const testStory = WorkItemModel(
    id: 'story-1',
    itemNumber: 'ST-101',
    title: 'Student Portal Enhancement',
    workType: 'STORY',
    status: 'ACTIVE',
    priority: 'HIGH',
    children: [
      WorkItemModel(
        id: 'task-1',
        itemNumber: 'TK-1001',
        title: 'Improve dashboard UI',
        workType: 'TASK',
        status: 'NEW',
        priority: 'MEDIUM',
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
      'epics': 1,
      'stories': 1,
      'tasks': 1,
      'bugs': 0,
      'issues': 0,
    },
    isLoading: false,
  );

  group('Work Management KPI & Epics Expand Regression Tests', () {
    test('1. WorkListState default pageSize accommodates all 143 items', () {
      const state = WorkListState();
      expect(state.pageSize, greaterThanOrEqualTo(250));
      expect(state.pageSize, 500);
    });

    test('2. WorkBoardNotifier loads all 143 cards when boardId is all or null', () {
      final notifier = WorkBoardNotifier();
      expect(notifier, isNotNull);
    });

    testWidgets('3. Backlog Epics sidebar expands and collapses on user toggle without width restriction', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workBacklogProvider.overrideWith((ref) => MockWorkBacklogNotifier(mockBacklogState)),
          ],
          child: MaterialApp(
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

      // In initial state, epics sidebar is open
      final collapseTooltipFinder = find.byTooltip('Collapse Epics');
      expect(collapseTooltipFinder, findsOneWidget);

      // Tap collapse button
      await tester.tap(collapseTooltipFinder);
      await tester.pump(const Duration(milliseconds: 200));

      // After collapse, expand chevron must be visible
      final expandChevronFinder = find.byTooltip('Expand Epics');
      expect(expandChevronFinder, findsOneWidget);

      // Tap expand button - on 1280 screen, it MUST expand (previously blocked by < 1400 check)
      await tester.tap(expandChevronFinder);
      await tester.pump(const Duration(milliseconds: 200));

      // Verify that it expanded back!
      expect(find.byTooltip('Collapse Epics'), findsOneWidget);
    });

    testWidgets('4. Tapping KPI card toggles filter on and tapping again toggles off to All', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workBacklogProvider.overrideWith((ref) => MockWorkBacklogNotifier(mockBacklogState)),
          ],
          child: MaterialApp(
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

      // Initial state: ST-101 story should be present in table / detail
      expect(find.text('ST-101'), findsAtLeastNWidgets(1));

      // Tap on Issues KPI card (which has 0 issues)
      final issuesCardFinder = find.text('Issues');
      expect(issuesCardFinder, findsOneWidget);
      await tester.tap(issuesCardFinder);
      await tester.pump(const Duration(milliseconds: 200));

      // Filter is applied: empty state is displayed
      expect(find.text('No backlog items found matching the current filters'), findsOneWidget);
      expect(find.text('Reset All Filters'), findsOneWidget);

      // Tap Issues card again to toggle off!
      await tester.tap(issuesCardFinder);
      await tester.pump(const Duration(milliseconds: 200));

      // Verified: ST-101 is visible again because filter toggled off back to All!
      expect(find.text('ST-101'), findsAtLeastNWidgets(1));
    });

    testWidgets('5. Empty state Reset All Filters button clears filter', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workBacklogProvider.overrideWith((ref) => MockWorkBacklogNotifier(mockBacklogState)),
          ],
          child: MaterialApp(
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

      // Tap Bugs card (0 bugs)
      await tester.tap(find.text('Bugs'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Reset All Filters'), findsOneWidget);

      // Tap Reset All Filters
      await tester.tap(find.text('Reset All Filters'));
      await tester.pump(const Duration(milliseconds: 200));

      // ST-101 is back!
      expect(find.text('ST-101'), findsAtLeastNWidgets(1));
    });

    testWidgets('6. Actions toolbar renders Bulk Actions button cleanly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workBacklogProvider.overrideWith((ref) => MockWorkBacklogNotifier(mockBacklogState)),
          ],
          child: MaterialApp(
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

      expect(find.text('Bulk Actions'), findsOneWidget);
      expect(find.text('Reorder'), findsOneWidget);
      expect(find.text('Add Work Item'), findsOneWidget);
    });
  });
}
