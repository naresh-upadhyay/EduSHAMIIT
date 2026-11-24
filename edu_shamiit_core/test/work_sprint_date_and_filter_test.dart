import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';
import 'package:edu_shamiit_core/screens/work_management/services/work_api_service.dart';
import 'package:edu_shamiit_core/screens/work_management/utils/work_sprint_date_helper.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/board/work_board_tab_view.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/sprints/work_sprints_tab_view.dart';

const List<int> _kTransparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();
  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _kTransparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_kTransparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

class TestFakeWorkApiService extends WorkApiService {
  @override
  Future<List<KanbanColumnModel>> getBoardKanban(
    String boardId, {
    String? sprintId,
    String? view = 'All',
    String? groupBy = 'Status',
    String? search,
    bool forceRefresh = false,
  }) async => const [
    KanbanColumnModel(statusKey: 'NEW', name: 'New', color: '#64748B', count: 0, items: []),
    KanbanColumnModel(statusKey: 'ACTIVE', name: 'Active', color: '#3B82F6', count: 0, items: []),
  ];

  @override
  Future<List<WorkAssigneeModel>> getAssignableUsers({
    String? q,
    String? role,
    String? department,
    int limit = 100,
  }) async => const [
    WorkAssigneeModel(id: 'u1', userId: 'user-1', fullName: 'Dr. Neha Sharma', role: 'Faculty Lead'),
    WorkAssigneeModel(id: 'u2', userId: 'user-2', fullName: 'Amit Kumar', role: 'Developer'),
  ];

  @override
  Future<Map<String, dynamic>> getSprintDashboard(
    String sprintId, {
    String? boardId,
    String? team = 'All Teams',
    String? search,
    int page = 1,
    int pageSize = 10,
    bool forceRefresh = false,
  }) async => {
    'sprint_id': 's8',
    'sprint_name': 'Sprint 8',
    'status': 'ACTIVE',
    'start_date_fmt': 'Nov 15, 2026',
    'end_date_fmt': 'Nov 28, 2026',
    'total_items_count': 6,
    'kpis': {
      'total_items': 6,
      'completed_items': 4,
      'in_progress_items': 0,
      'not_started_items': 2,
      'blocked_items': 0,
    },
    'items': [
      const WorkItemModel(id: 'w1', itemNumber: 'TK-101', title: 'Task 1', workType: 'TASK', priority: 'MEDIUM', status: 'COMPLETED'),
      const WorkItemModel(id: 'w2', itemNumber: 'TK-102', title: 'Task 2', workType: 'TASK', priority: 'MEDIUM', status: 'COMPLETED'),
      const WorkItemModel(id: 'w3', itemNumber: 'TK-103', title: 'Task 3', workType: 'TASK', priority: 'MEDIUM', status: 'COMPLETED'),
      const WorkItemModel(id: 'w4', itemNumber: 'TK-104', title: 'Task 4', workType: 'TASK', priority: 'MEDIUM', status: 'COMPLETED'),
      const WorkItemModel(id: 'w5', itemNumber: 'TK-105', title: 'Task 5', workType: 'TASK', priority: 'MEDIUM', status: 'NEW'),
      const WorkItemModel(id: 'w6', itemNumber: 'TK-106', title: 'Task 6', workType: 'TASK', priority: 'MEDIUM', status: 'NEW'),
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _TestHttpOverrides();

  tearDown(() {
    WorkSprintDateHelper.setMockNow(null);
  });

  group('WorkSprintDateHelper Dynamic Date Logic', () {
    test('Calculates current, next, and previous sprint correctly for November 15, 2026', () {
      WorkSprintDateHelper.setMockNow(DateTime(2026, 11, 15));

      // Nov 15 is day >= 15
      expect(WorkSprintDateHelper.currentSprintStart, DateTime(2026, 11, 15));
      expect(WorkSprintDateHelper.currentSprintEnd, DateTime(2026, 11, 28));
      expect(WorkSprintDateHelper.currentSprintShortRange, 'Nov 15 – Nov 28');
      expect(WorkSprintDateHelper.currentSprintFullDurationRange, 'Nov 15, 2026 – Nov 28, 2026 (14 days)');
      expect(WorkSprintDateHelper.currentSprintBoardDropdownLabel, 'Current Sprint (Nov 15 – Nov 28)');

      // Next sprint is Dec 1 - Dec 14
      expect(WorkSprintDateHelper.nextSprintStart, DateTime(2026, 12, 1));
      expect(WorkSprintDateHelper.nextSprintEnd, DateTime(2026, 12, 14));
      expect(WorkSprintDateHelper.nextSprintShortRange, 'Dec 1 – Dec 14');

      // Previous sprint is Nov 1 - Nov 14
      expect(WorkSprintDateHelper.prevSprintStart, DateTime(2026, 11, 1));
      expect(WorkSprintDateHelper.prevSprintEnd, DateTime(2026, 11, 14));
      expect(WorkSprintDateHelper.prevSprintShortRange, 'Nov 1 – Nov 14');

      // Options list check
      final options = WorkSprintDateHelper.boardSprintOptions;
      expect(options.contains('Current Sprint (Nov 15 – Nov 28)'), isTrue);
      expect(options.contains('Sprint 9 (Dec 1 – Dec 14)'), isTrue);
      expect(options.contains('Current Sprint (Jan 1 – Jan 14)'), isFalse);
    });

    test('Calculates current sprint correctly for first half of month (November 3, 2026)', () {
      WorkSprintDateHelper.setMockNow(DateTime(2026, 11, 3));

      expect(WorkSprintDateHelper.currentSprintStart, DateTime(2026, 11, 1));
      expect(WorkSprintDateHelper.currentSprintEnd, DateTime(2026, 11, 14));
      expect(WorkSprintDateHelper.currentSprintShortRange, 'Nov 1 – Nov 14');
      expect(WorkSprintDateHelper.nextSprintShortRange, 'Nov 15 – Nov 28');
      expect(WorkSprintDateHelper.prevSprintShortRange, 'Oct 15 – Oct 28');
      expect(WorkSprintDateHelper.currentSprintBoardDropdownLabel, 'Current Sprint (Nov 1 – Nov 14)');
    });

    test('Handles year rollover at December 25, 2026', () {
      WorkSprintDateHelper.setMockNow(DateTime(2026, 12, 25));

      expect(WorkSprintDateHelper.currentSprintStart, DateTime(2026, 12, 15));
      expect(WorkSprintDateHelper.currentSprintEnd, DateTime(2026, 12, 28));
      expect(WorkSprintDateHelper.nextSprintStart, DateTime(2027, 1, 1));
      expect(WorkSprintDateHelper.nextSprintEnd, DateTime(2027, 1, 14));
      expect(WorkSprintDateHelper.nextSprintShortRange, 'Jan 1 – Jan 14');
    });

    test('Generates 14 dynamic daily points for capacity chart in current sprint', () {
      WorkSprintDateHelper.setMockNow(DateTime(2026, 11, 15));
      final points = WorkSprintDateHelper.generateDailyCapacityPoints();
      expect(points.length, 14);
      expect(points.first.fullDate, '2026-11-15');
      expect(points.first.dateFmt, 'Nov 15');
      expect(points.last.fullDate, '2026-11-28');
      expect(points.last.dateFmt, 'Nov 28');
    });
  });

  group('WorkBoardTabView Filters Badge and Sprint Dropdown Tests', () {
    testWidgets('Board tab shows dynamic current sprint and does NOT show Filters 2 badge when zero filters applied', (tester) async {
      WorkSprintDateHelper.setMockNow(DateTime(2026, 11, 15));
      final fakeApi = TestFakeWorkApiService();

      await tester.binding.setSurfaceSize(const Size(1400, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workApiServiceProvider.overrideWithValue(fakeApi),
            workBoardProvider.overrideWith((ref) => WorkBoardNotifier(ref, fakeApi)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: WorkBoardTabView(
                onOpenDetail: (_) {},
                onQuickAction: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify that "All Sprints" is displayed in sprint selector by default
      expect(find.text('All Sprints'), findsWidgets);
      expect(find.text('Current Sprint (Jan 1 – Jan 14)'), findsNothing);

      // 2. Verify that the "Filters" button is rendered
      final filtersButton = find.ancestor(
        of: find.text('Filters'),
        matching: find.byType(InkWell),
      );
      expect(filtersButton, findsOneWidget);

      // 3. Verify that the badge is NOT rendered in the Filters button since 0 filters are active
      expect(find.descendant(of: filtersButton, matching: find.text('2')), findsNothing);
      expect(find.descendant(of: filtersButton, matching: find.text('0')), findsNothing);

      // 4. Now enter text into keyword search filter
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'portal');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 5. With 1 active filter applied, badge "1" should be rendered inside the Filters button!
      expect(find.descendant(of: filtersButton, matching: find.text('1')), findsOneWidget);

      // 6. Clear filter
      final clearButton = find.text('Clear all');
      if (clearButton.evaluate().isNotEmpty) {
        await tester.tap(clearButton);
        await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
        // Badge should disappear again
        expect(find.descendant(of: filtersButton, matching: find.text('1')), findsNothing);
      }
    });

    testWidgets('Sprints tab renders subtabs and All Sprints Grid without Sprint Backlog or Task Board', (tester) async {
      WorkSprintDateHelper.setMockNow(DateTime(2026, 11, 15));
      final fakeApi = TestFakeWorkApiService();

      await tester.binding.setSurfaceSize(const Size(1400, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workApiServiceProvider.overrideWithValue(fakeApi),
            workSprintDashboardProvider.overrideWith((ref) => WorkSprintDashboardNotifier(ref, fakeApi)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: WorkSprintsTabView(
                onCreateSprint: () {},
                onQuickAction: (_) {},
                onOpenDetail: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify Subtabs: All Sprints (Grid), Capacity, Retrospective exist
      expect(find.text('All Sprints (Grid)'), findsOneWidget);
      expect(find.text('Capacity'), findsOneWidget);
      expect(find.text('Retrospective'), findsOneWidget);

      // 2. Verify deleted subtabs are NOT present
      expect(find.text('Sprint Backlog'), findsNothing);
      expect(find.text('Boards (Task Board)'), findsNothing);

      // 3. Verify All Sprints Grid header is present
      expect(find.text('Total Sprints'), findsOneWidget);
    });
  });
}
