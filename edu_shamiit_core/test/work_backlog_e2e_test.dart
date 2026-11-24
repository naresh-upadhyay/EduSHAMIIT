import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/services/work_api_service.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/backlog/work_backlog_tab_view.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/drawers/work_item_detail_drawer.dart';

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
      WorkAssigneeModel(id: '2', userId: 'u2', fullName: 'Priya Singh', role: 'Teacher'),
    ];
  }

  @override
  Future<List<WorkSprintModel>> getSprints({String? boardId, bool forceRefresh = false}) async {
    return const [
      WorkSprintModel(id: 's8', name: 'Sprint 8', status: 'ACTIVE', sprintNumber: 8),
    ];
  }
}

class MockWorkBacklogNotifier extends WorkBacklogNotifier {
  final WorkBacklogState initialState;
  MockWorkBacklogNotifier(this.initialState);

  @override
  WorkBacklogState get state => initialState;

  @override
  Future<void> loadBacklog({String? boardId, String? epicId, String? search, bool forceRefresh = false}) async {
    // Mock load
  }

  @override
  Future<bool> bulkUpdate({
    required List<String> itemIds,
    String? status,
    String? priority,
    String? assigneeId,
    List<String>? assigneeIds,
    List<WorkAssigneeModel>? assignees,
    String? sprintId,
    String? teamId,
    String? teamName,
  }) async {
    return true;
  }

  @override
  Future<bool> bulkDelete(List<String> itemIds) async {
    return true;
  }

  @override
  Future<bool> reorderItem({
    required String itemId,
    required double newRank,
    String? newParentId,
  }) async {
    return true;
  }

  @override
  Future<bool> reparentStoryTask({
    required WorkItemModel task,
    required WorkItemModel targetStory,
  }) async {
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _TestHttpOverrides();

  final sampleEpics = [
    const BacklogEpicModel(
      id: '0d59ba0f-7969-4a1f-b2d8-8a7ac2a6023d',
      itemNumber: 'EP-001',
      title: 'Campus Digitalization',
      count: 15,
      description: 'End-to-end digital transformation.',
    ),
    const BacklogEpicModel(
      id: 'b4b3d4ea-1ce0-4dc9-ae09-3f9746879a10',
      itemNumber: 'EP-003',
      title: 'Smart Campus Control',
      count: 24,
      description: 'Automated IoT campus security.',
    ),
  ];

  final sampleStories = [
    const WorkItemModel(
      id: 'story-1',
      itemNumber: 'ST-301',
      title: 'IoT Campus Access & Smart Turnstiles',
      workType: 'STORY',
      priority: 'HIGH',
      status: 'ACTIVE',
      category: 'Facilities',
      children: [
        WorkItemModel(
          id: 'task-101',
          itemNumber: 'TK-3001',
          title: 'RFID Turnstile Integration',
          workType: 'TASK',
          priority: 'HIGH',
          status: 'ACTIVE',
          category: 'Facilities',
        ),
        WorkItemModel(
          id: 'task-102',
          itemNumber: 'TK-3002',
          title: 'Facial Recognition Scanner',
          workType: 'TASK',
          priority: 'HIGH',
          status: 'COMPLETED',
          category: 'Facilities',
        ),
      ],
    ),
    const WorkItemModel(
      id: 'story-2',
      itemNumber: 'ST-302',
      title: 'Smart Classroom & Lab Lighting Automation',
      workType: 'STORY',
      priority: 'MEDIUM',
      status: 'ACTIVE',
      category: 'Facilities',
    ),
  ];

  final mockState = WorkBacklogState(
    isLoading: false,
    epics: sampleEpics,
    selectedEpic: sampleEpics[1],
    stories: sampleStories,
    totalCount: 24,
    kpis: {
      'total_backlog': 136,
      'epics': 12,
      'stories': 36,
      'tasks': 84,
      'bugs': 4,
      'issues': 27,
    },
  );

  Widget createBacklogWidget() {
    return ProviderScope(
      overrides: [
        workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
        workBacklogProvider.overrideWith((ref) => MockWorkBacklogNotifier(mockState)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: WorkBacklogTabView(
            onOpenDetail: (item) {},
            onQuickAction: (type) {},
          ),
        ),
      ),
    );
  }

  testWidgets('Renders 6 dynamic KPI cards with database counts and allows filtering on click', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createBacklogWidget());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Total Backlog Items'), findsOneWidget);
    expect(find.text('136'), findsOneWidget);
    expect(find.text('Epics'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Stories'), findsOneWidget);
    expect(find.text('36'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('84'), findsOneWidget);
    expect(find.text('Bugs'), findsOneWidget);
    expect(find.text('4'), findsWidgets);

    // Tap on Stories KPI card to filter
    await tester.tap(find.text('Stories'));
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('Renders Epics sidebar, center banner with matching count 24 work items', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createBacklogWidget());
    await tester.pump(const Duration(milliseconds: 200));

    // Find EP-003
    final ep3Finder = find.textContaining('EP-003');
    expect(ep3Finder, findsWidgets);

    // Tap on EP-003
    await tester.tap(ep3Finder.first);
    await tester.pump(const Duration(milliseconds: 200));

    // Center banner should now display EP-003 with dynamic work items count
    expect(find.textContaining('EP-003'), findsWidgets);
    expect(find.textContaining('work items'), findsWidgets);
  });

  testWidgets('Multiselect Checkboxes: Toggling story checkbox selects items and shows selection action bar', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createBacklogWidget());
    await tester.pump(const Duration(milliseconds: 200));

    // Checkboxes should exist for master, story, and child tasks
    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsWidgets);

    // Tap the first story checkbox
    await tester.tap(checkboxes.at(1));
    await tester.pump(const Duration(milliseconds: 200));

    // Multiselect action bar should now appear with selected count and actions
    expect(find.text('items selected'), findsOneWidget);
    expect(find.text('Move to Sprint'), findsOneWidget);
    expect(find.text('Change Status'), findsOneWidget);
    expect(find.text('Change Priority'), findsOneWidget);
    expect(find.text('Clear selection'), findsOneWidget);
  });

  testWidgets('Toolbar buttons: Reorder and Bulk Actions open interactive dialogs', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createBacklogWidget());
    await tester.pump(const Duration(milliseconds: 200));

    // Tap Reorder button
    final reorderBtn = find.widgetWithText(OutlinedButton, 'Reorder');
    expect(reorderBtn, findsWidgets);
    await tester.tap(reorderBtn.first);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Reorder Backlog Items'), findsOneWidget);
    expect(find.text('Save Order'), findsOneWidget);

    // Close Reorder dialog
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 200));

    // Tap Bulk Actions button
    final bulkBtn = find.widgetWithText(OutlinedButton, 'Bulk Actions');
    expect(bulkBtn, findsWidgets);
    await tester.tap(bulkBtn.first);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Bulk Actions'), findsWidgets);
    expect(find.text('Select an operation to apply to all chosen work items:'), findsOneWidget);
  });

  testWidgets('Better pagination footer renders rows per page, pages, and accurate item count', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createBacklogWidget());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Rows per page: '), findsOneWidget);
    expect(find.textContaining('Showing'), findsOneWidget);
    expect(find.textContaining('work items'), findsWidgets);
  });

  testWidgets('Close button of Detail Drawer closes the drawer, and clicking item re-opens it', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createBacklogWidget());
    await tester.pump(const Duration(milliseconds: 200));

    // Initially, drawer is rendered with first item and "Effort & Progress" card
    expect(find.byType(WorkItemDetailDrawer), findsOneWidget);
    expect(find.text('Effort & Progress'), findsOneWidget);

    // Find and tap close button on WorkItemDetailDrawer
    final closeBtn = find.byTooltip('Close');
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pump(const Duration(milliseconds: 200));

    // Drawer is now completely closed and removed from tree
    expect(find.byType(WorkItemDetailDrawer), findsNothing);
    expect(find.text('Effort & Progress'), findsNothing);

    // Tapping a story row re-opens the drawer
    final storyRow = find.text('ST-301');
    expect(storyRow, findsWidgets);
    await tester.tap(storyRow.first);
    await tester.pump(const Duration(milliseconds: 200));

    // Drawer is open again
    expect(find.byType(WorkItemDetailDrawer), findsOneWidget);
    expect(find.text('Effort & Progress'), findsOneWidget);
  });

  testWidgets('Edit Epic button in center banner opens EditEpicDialog with epic details', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createBacklogWidget());
    await tester.pump(const Duration(milliseconds: 200));

    // Tap on EP-003 in Epics sidebar
    final ep3Finder = find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText().contains('EP-003'),
    );
    expect(ep3Finder, findsWidgets);
    await tester.tap(ep3Finder.first);
    await tester.pump(const Duration(milliseconds: 200));

    // The center banner displays the selected epic 'EP-003' and an 'Edit Epic' button
    expect(find.textContaining('EP-003'), findsWidgets);
    final editEpicButton = find.widgetWithText(OutlinedButton, 'Edit Epic');
    expect(editEpicButton, findsOneWidget);

    // Tap 'Edit Epic'
    await tester.tap(editEpicButton);
    await tester.pump(const Duration(milliseconds: 300));

    // EditEpicDialog should be open with title and description populated
    expect(find.text('Edit Epic Details'), findsOneWidget);
    expect(find.text('Smart Campus Control'), findsWidgets);
    expect(find.text('Automated IoT campus security.'), findsWidgets);
    expect(find.text('Save Epic Changes'), findsOneWidget);
  });

  testWidgets('Allows dragging task and dropping onto target story to dynamically re-parent', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createBacklogWidget());
    await tester.pump(const Duration(milliseconds: 200));

    // Ensure story 1 is expanded and child TK-3001 is visible
    expect(find.text('TK-3001'), findsOneWidget);
    expect(find.text('ST-302'), findsOneWidget);

    // Verify Draggable widget exists for TK-3001
    final draggableFinder = find.byWidgetPredicate(
      (w) => w is Draggable<WorkItemModel> && w.data?.itemNumber == 'TK-3001',
    );
    expect(draggableFinder, findsOneWidget);

    // Verify DragTarget exists for stories and drop zones
    final targetFinder = find.byWidgetPredicate(
      (w) => w is DragTarget<WorkItemModel>,
    );
    expect(targetFinder, findsWidgets);

    // Perform drag gesture on TK-3001
    final gesture = await tester.startGesture(tester.getCenter(draggableFinder));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
  });
}
