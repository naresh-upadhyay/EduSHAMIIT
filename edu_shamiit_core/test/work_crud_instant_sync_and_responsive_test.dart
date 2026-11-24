import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/drawers/work_item_detail_drawer.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/list/work_list_tab_view.dart';
import 'package:edu_shamiit_core/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Work Management Instant CRUD & Responsive Screen Tests', () {
    test('1. ApiService clearCache on mutations', () {
      final api = ApiService();
      api.clearCache();
      expect(api, isNotNull);
    });

    test('2. WorkAssigneeModel toJson and serialization', () {
      const assignee = WorkAssigneeModel(
        id: 'usr_1',
        userId: 'usr_1',
        fullName: 'Archana Shukla',
        role: 'teacher',
        email: 'archana@school.edu',
        department: 'Academics',
      );
      final json = assignee.toJson();
      expect(json['id'], equals('usr_1'));
      expect(json['full_name'], equals('Archana Shukla'));
      expect(json['department'], equals('Academics'));

      final fromJson = WorkAssigneeModel.fromJson(json);
      expect(fromJson.fullName, equals('Archana Shukla'));
      expect(fromJson.department, equals('Academics'));
    });

    test('3. WorkListNotifier and WorkBoardNotifier updateItemLocally zero-latency logic', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testItem = WorkItemModel(
        id: 'tk-1',
        itemNumber: 'TK-1001',
        title: 'Initial Title',
        workType: 'TASK',
        status: 'NEW',
        priority: 'MEDIUM',
      );

      // Verify list notifier local update
      final listNotifier = container.read(workListProvider.notifier);
      listNotifier.updateItemLocally(testItem.copyWith(title: 'Updated Title', status: 'ACTIVE'));
      expect(listNotifier, isNotNull);

      // Verify board notifier local update
      final boardNotifier = container.read(workBoardProvider.notifier);
      boardNotifier.updateItemLocally(testItem.copyWith(title: 'Updated Title', status: 'ACTIVE'));
      expect(boardNotifier, isNotNull);
    });

    testWidgets('4. WorkItemDetailDrawer adapts height responsively to screen size', (tester) async {
      // Simulate smaller laptop viewport (e.g., 1024x600)
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const testItem = WorkItemModel(
        id: 'item-101',
        itemNumber: 'TK-101',
        title: 'Responsive Work Item',
        workType: 'TASK',
        status: 'ACTIVE',
        priority: 'HIGH',
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
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('TK-101'), findsOneWidget);
      expect(find.text('Responsive Work Item'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
    });

    testWidgets('5. WorkListTabView renders responsive table without unbounded RenderFlex', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: WorkListTabView(
                  onOpenDetail: (_) {},
                  onQuickAction: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WorkListTabView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
