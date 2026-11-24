import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/services/work_api_service.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/backlog/work_backlog_tab_view.dart';

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
    return const [];
  }

  @override
  Future<List<WorkBoardModel>> getBoards({bool forceRefresh = false}) async {
    return const [
      WorkBoardModel(id: '31dacd93-15ee-4eed-8994-56973fd81245', name: 'Institute Work Board', code: 'IWB'),
    ];
  }
}

class MockWorkBacklogNotifier extends WorkBacklogNotifier {
  WorkBacklogState _customState;
  MockWorkBacklogNotifier(this._customState);

  @override
  WorkBacklogState get state => _customState;

  @override
  void selectEpic(BacklogEpicModel epic) {
    _customState = _customState.copyWith(
      selectedEpic: epic,
      currentEpicId: epic.id.isNotEmpty ? epic.id : epic.itemNumber,
    );
  }

  @override
  Future<void> loadBacklog({String? boardId, String? epicId, String? search, bool forceRefresh = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _TestHttpOverrides();

  const epic001 = BacklogEpicModel(
    id: 'ep-001',
    itemNumber: 'EP-001',
    title: '1 Campus Digitalization',
    count: 15,
  );

  const epic004 = BacklogEpicModel(
    id: 'ep-004',
    itemNumber: 'EP-004',
    title: 'Student Experience',
    count: 9,
  );

  const ep4Story1 = WorkItemModel(
    id: 'st-106',
    itemNumber: 'ST-106',
    title: 'Student Feedback & Extracurricular Activities',
    workType: 'STORY',
    status: 'ACTIVE',
    priority: 'HIGH',
    children: [
      WorkItemModel(id: 'tk-1020', itemNumber: 'TK-1020', title: 'Online feedback portal', workType: 'TASK', status: 'ACTIVE', priority: 'MEDIUM'),
      WorkItemModel(id: 'tk-1021', itemNumber: 'TK-1021', title: 'Extracurricular club registrations', workType: 'TASK', status: 'ACTIVE', priority: 'MEDIUM'),
    ],
  );

  const ep4Story2 = WorkItemModel(
    id: 'st-116',
    itemNumber: 'ST-116',
    title: 'Campus Dining & Canteen Automation',
    workType: 'STORY',
    status: 'ACTIVE',
    priority: 'MEDIUM',
    children: [
      WorkItemModel(id: 'tk-1022', itemNumber: 'TK-1022', title: 'Canteen meal pre-ordering workflow', workType: 'TASK', status: 'ACTIVE', priority: 'MEDIUM'),
      WorkItemModel(id: 'tk-1023', itemNumber: 'TK-1023', title: 'Dietary preferences & menu scheduling', workType: 'TASK', status: 'ACTIVE', priority: 'MEDIUM'),
    ],
  );

  const ep4Story3 = WorkItemModel(
    id: 'st-1022',
    itemNumber: 'ST-1022',
    title: 'Student Wellness & Counseling Hub',
    workType: 'STORY',
    status: 'ACTIVE',
    priority: 'HIGH',
    children: [
      WorkItemModel(id: 'tk-1018', itemNumber: 'TK-1018', title: 'Counselor appointment booking', workType: 'TASK', status: 'ACTIVE', priority: 'MEDIUM'),
      WorkItemModel(id: 'tk-1019', itemNumber: 'TK-1019', title: 'Wellness assessment surveys', workType: 'TASK', status: 'ACTIVE', priority: 'MEDIUM'),
    ],
  );

  const mockBacklogState = WorkBacklogState(
    stories: [ep4Story1, ep4Story2, ep4Story3],
    selectedEpic: epic004,
    epics: [epic001, epic004],
    totalCount: 9,
    kpis: {
      'total_backlog': 24,
      'epics': 2,
      'stories': 3,
      'tasks': 6,
      'bugs': 0,
      'issues': 0,
    },
    isLoading: false,
  );

  group('Backlog Epics Single Source of Truth & Dynamic Count Tests', () {
    testWidgets('1. EP-004 shows consistent 9 work items count without click and when clicked', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
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

      // 1. Verify EP-004 banner displays 9 work items calculated dynamically
      expect(find.text('9 work items'), findsOneWidget);

      // 2. Verify sidebar displays EP-004 with 9
      final ep4Finder = find.textContaining('Student Experience');
      expect(ep4Finder, findsWidgets);

      // 3. Verify all 3 stories and their 6 child tasks are rendered in the backlog tree
      expect(find.text('ST-106'), findsWidgets);
      expect(find.text('ST-116'), findsOneWidget);
      expect(find.text('ST-1022'), findsOneWidget);
      expect(find.text('TK-1020'), findsOneWidget);
      expect(find.text('TK-1021'), findsOneWidget);
      expect(find.text('TK-1022'), findsOneWidget);
      expect(find.text('TK-1023'), findsOneWidget);
      expect(find.text('TK-1018'), findsOneWidget);
      expect(find.text('TK-1019'), findsOneWidget);

      // 4. Tap EP-001 then back to EP-004, verify count remains 9 without jumping
      final ep1Finder = find.textContaining('Campus Digitalization');
      await tester.tap(ep1Finder.first);
      await tester.pump(const Duration(milliseconds: 200));

      final ep4Sidebar = find.textContaining('Student Experience').first;
      await tester.tap(ep4Sidebar);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('9 work items'), findsOneWidget);
    });

    testWidgets('2. Filter by Task displays only the 6 tasks without breaking epic consistency', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
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

      // Click on 'Tasks' KPI card
      final tasksKpiFinder = find.text('Tasks');
      expect(tasksKpiFinder, findsWidgets);
      await tester.tap(tasksKpiFinder.first);
      await tester.pump(const Duration(milliseconds: 200));

      // Header dynamically shows matching work items (not 0!)
      expect(find.text('6 work items'), findsOneWidget);
      expect(find.text('TK-1020'), findsOneWidget);
      expect(find.text('TK-1021'), findsOneWidget);
    });
  });
}
