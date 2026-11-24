import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/services/work_api_service.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/list/work_list_tab_view.dart';

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

class MockWorkListNotifier extends WorkListNotifier {
  final WorkListState initialState;
  MockWorkListNotifier(this.initialState);

  @override
  WorkListState get state => initialState;

  @override
  Future<void> loadPagedItems({String? boardId, bool forceRefresh = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _TestHttpOverrides();

  // Generate 42 NEW items and 58 ACTIVE items, plus others to total 143
  final items = <WorkItemModel>[];
  for (int i = 1; i <= 42; i++) {
    items.add(
      WorkItemModel(
        id: 'new-$i',
        itemNumber: 'TK-$i',
        title: 'New Work Item $i',
        workType: 'TASK',
        status: 'NEW',
        priority: 'MEDIUM',
        dueDate: '2026-11-28T00:00:00Z',
        dueDateFmt: 'Nov 28, 2026',
      ),
    );
  }
  for (int i = 43; i <= 100; i++) {
    items.add(
      WorkItemModel(
        id: 'active-$i',
        itemNumber: 'TK-$i',
        title: 'Active Work Item $i',
        workType: 'TASK',
        status: 'ACTIVE',
        priority: 'HIGH',
        dueDate: '2026-11-28T00:00:00Z',
        dueDateFmt: 'Nov 28, 2026',
      ),
    );
  }
  for (int i = 101; i <= 143; i++) {
    items.add(
      WorkItemModel(
        id: 'res-$i',
        itemNumber: 'TK-$i',
        title: 'Resolved Work Item $i',
        workType: 'TASK',
        status: 'RESOLVED',
        priority: 'LOW',
        dueDate: '2026-11-28T00:00:00Z',
        dueDateFmt: 'Nov 28, 2026',
      ),
    );
  }

  final mockListState = WorkListState(
    items: items,
    totalCount: 143,
    boardId: '31dacd93-15ee-4eed-8994-56973fd81245',
    kpis: {
      'total': 143,
      'new': 42,
      'active': 58,
      'resolved': 43,
      'completed': 0,
      'overdue': 0,
    },
    isLoading: false,
  );

  group('Work List Tab View - KPI Pagination and Due Date Tests', () {
    testWidgets('1. Shows correct pagination count for All (143), New (42), and Active (58)', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
            workListProvider.overrideWith((ref) => MockWorkListNotifier(mockListState)),
          ],
          child: MaterialApp(
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

      // Initially All is selected -> Showing 1 - 10 of 143 items
      expect(find.text('Showing 1 - 10 of 143 items'), findsOneWidget);

      // Tap on "New" (42) KPI card
      final newKpiCard = find.text('New');
      expect(newKpiCard, findsWidgets);
      await tester.tap(newKpiCard.first);
      await tester.pump(const Duration(milliseconds: 200));

      // Bottom footer must say Showing 1 - 10 of 42 items!
      expect(find.text('Showing 1 - 10 of 42 items'), findsOneWidget);

      // Tap on "Active" (58) KPI card
      final activeKpiCard = find.text('Active');
      expect(activeKpiCard, findsWidgets);
      await tester.tap(activeKpiCard.first);
      await tester.pump(const Duration(milliseconds: 200));

      // Bottom footer must say Showing 1 - 10 of 58 items!
      expect(find.text('Showing 1 - 10 of 58 items'), findsOneWidget);
    });

    testWidgets('2. Due Date column header and cells render single-line without wrapping or overflow', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
            workListProvider.overrideWith((ref) => MockWorkListNotifier(mockListState)),
          ],
          child: MaterialApp(
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

      expect(tester.takeException(), isNull);
      expect(find.text('Due Date'), findsOneWidget);
      expect(find.text('2026-11-28'), findsWidgets);
    });
  });
}
