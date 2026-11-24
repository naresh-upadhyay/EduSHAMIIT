import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/sprints/all_sprints_grid_view.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/board/work_board_tab_view.dart';
import 'package:edu_shamiit_core/screens/work_management/work_management_screen.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';

class MockWorkAllSprintsNotifier extends WorkAllSprintsNotifier {
  MockWorkAllSprintsNotifier(Ref ref, List<WorkSprintModel> sprints)
      : super(ref, null, WorkAllSprintsState(isLoading: false, sprints: sprints));

  @override
  Future<void> loadSprints({String? boardId, bool forceRefresh = false}) async {
    // Keep test sprints in mock state
  }
}

class TestHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = TestHttpOverrides();

  // Silence network image resolution errors in headless widget tests
  FlutterError.onError = (details) {
    final bool isNetworkImage = details.exception is NetworkImageLoadException ||
        details.exception.toString().contains('NetworkImageLoadException') ||
        details.exception.toString().contains('statusCode: 400');
    if (!isNetworkImage) {
      FlutterError.presentError(details);
    }
  };

  group('Work Sprint Timeline Days Calculation Tests', () {
    test('1. WorkSprintModel correctly calculates 18 days for Jan 01 - Jan 18, 2025', () {
      const sprint = WorkSprintModel(
        id: 's8',
        name: 'Sprint 8',
        startDate: '2025-01-01',
        endDate: '2025-01-18',
        startDateFmt: 'Jan 01, 2025',
        endDateFmt: 'Jan 18, 2025',
      );

      expect(sprint.computedDurationDays, equals(18));
      expect(sprint.durationDays, equals(18));
    });

    test('2. WorkSprintModel correctly calculates 14 days for Jan 15 - Jan 28, 2025', () {
      const sprint = WorkSprintModel(
        id: 's9',
        name: 'Sprint 9',
        startDate: '2025-01-15',
        endDate: '2025-01-28',
      );

      expect(sprint.computedDurationDays, equals(14));
      expect(sprint.durationDays, equals(14));
    });

    test('3. WorkSprintModel.fromJson parses duration_days or computes from start/end dates', () {
      final jsonWithDates = {
        'id': 's8',
        'name': 'Sprint 8',
        'start_date': '2025-01-01',
        'end_date': '2025-01-18',
        'start_date_fmt': 'Jan 01, 2025',
        'end_date_fmt': 'Jan 18, 2025',
      };

      final parsed = WorkSprintModel.fromJson(jsonWithDates);
      expect(parsed.durationDays, equals(18));
      expect(parsed.computedDurationDays, equals(18));

      // With only formatted dates
      final jsonFmtOnly = {
        'id': 's8_fmt',
        'name': 'Sprint 8 Fmt',
        'start_date_fmt': 'Jan 01, 2025',
        'end_date_fmt': 'Jan 18, 2025',
      };
      final parsedFmt = WorkSprintModel.fromJson(jsonFmtOnly);
      expect(parsedFmt.durationDays, equals(18));
      expect(parsedFmt.computedDurationDays, equals(18));
    });
  });

  group('Open in Sprint Board Navigation & Action Tests', () {
    testWidgets('4. AllSprintsGridView displays computed days and triggers onOpenInBoard callback', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? openedSprintId;

      final testSprints = [
        const WorkSprintModel(
          id: 's8',
          name: 'Sprint 8',
          status: 'COMPLETED',
          sprintNumber: 8,
          startDate: '2025-01-01',
          endDate: '2025-01-18',
          startDateFmt: 'Jan 01, 2025',
          endDateFmt: 'Jan 18, 2025',
          totalItems: 30,
          completedItems: 30,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allSprintsProvider.overrideWith((ref) => MockWorkAllSprintsNotifier(ref, testSprints)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AllSprintsGridView(
                onSelectSprint: (id) {},
                onOpenInBoard: (id) {
                  openedSprintId = id;
                },
                onOpenCreateSprint: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify that '18 days' is rendered on the screen
      expect(find.text('18 days'), findsOneWidget);

      // Verify open in sprint board icon button exists
      final openBoardBtn = find.byTooltip('Open in Sprint Board');
      expect(openBoardBtn, findsOneWidget);

      // Tap the button
      await tester.tap(openBoardBtn);
      await tester.pump();

      expect(openedSprintId, equals('s8'));
    });

    testWidgets('5. WorkManagementScreen end-to-end switches to Board tab when onOpenInBoard is invoked', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testSprints = [
        const WorkSprintModel(
          id: 's8',
          name: 'Sprint 8',
          status: 'COMPLETED',
          sprintNumber: 8,
          startDate: '2025-01-01',
          endDate: '2025-01-18',
          startDateFmt: 'Jan 01, 2025',
          endDateFmt: 'Jan 18, 2025',
        ),
        const WorkSprintModel(
          id: 's103',
          name: 'Sprint 103',
          status: 'ACTIVE',
          sprintNumber: 103,
          startDate: '2026-11-15',
          endDate: '2026-11-28',
          startDateFmt: 'Nov 15, 2026',
          endDateFmt: 'Nov 28, 2026',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allSprintsProvider.overrideWith((ref) => MockWorkAllSprintsNotifier(ref, testSprints)),
          ],
          child: const MaterialApp(
            home: WorkManagementScreen(initialTabIndex: 3),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify open in sprint board button exists
      final openBoardBtns = find.byTooltip('Open in Sprint Board');
      expect(openBoardBtns, findsWidgets);

      // Tap Open in Sprint Board on the first sprint
      await tester.tap(openBoardBtns.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // WorkBoardTabView should now be mounted
      expect(find.byType(WorkBoardTabView), findsOneWidget);
    });
  });
}
