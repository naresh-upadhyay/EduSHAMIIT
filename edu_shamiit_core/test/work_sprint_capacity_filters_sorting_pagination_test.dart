import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/sprints/sprint_capacity_tab_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget({
    String sprintId = 's8',
    String selectedTeam = 'Digital Campus Team',
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            height: 1000,
            child: SprintCapacityTabView(
              sprintId: sprintId,
              selectedTeam: selectedTeam,
            ),
          ),
        ),
      ),
    );
  }

  group('Sprint Capacity Filters, Sorting & Pagination Tests', () {
    testWidgets(
        '1. Top scope filter bar renders Sprint & Team selectors and Refresh action',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Capacity Scope Filters'), findsOneWidget);
      expect(find.text('Sprint:'), findsOneWidget);
      expect(find.text('Team:'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets(
        '2. Grid filters toolbar renders Search, Role dropdown, and Status dropdown',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Search member by name, role...'), findsOneWidget);
      expect(find.text('Role:'), findsOneWidget);
      expect(find.text('Status:'), findsOneWidget);
    });

    testWidgets('3. Grid search filters member list in real-time',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Initially Neha Sharma and Amit Kumar are visible
      expect(find.text('Neha Sharma'), findsOneWidget);
      expect(find.text('Amit Kumar'), findsOneWidget);

      // Enter "Karan" into the grid search input
      final searchFinder =
          find.widgetWithText(TextField, 'Search member by name, role...');
      await tester.enterText(searchFinder, 'Karan');
      await tester.pumpAndSettle(const Duration(milliseconds: 350));

      // Now only Karan Jain should be visible, others filtered out
      expect(find.text('Karan Jain'), findsOneWidget);
      expect(find.text('Neha Sharma'), findsNothing);

      // Active filters badge should be shown
      expect(find.text('Active filters:'), findsOneWidget);
      expect(find.text('Search: "Karan"'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);

      // Reset filters button clears the search
      await tester.tap(find.text('Reset Filters'));
      await tester.pumpAndSettle(const Duration(milliseconds: 350));

      expect(find.text('Neha Sharma'), findsOneWidget);
      expect(find.text('Amit Kumar'), findsOneWidget);
    });

    testWidgets('4. Grid sorting on column headers toggles sort state',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Column headers
      expect(find.text('Team Member'), findsOneWidget);
      expect(find.text('Role'), findsOneWidget);
      expect(find.text('Capacity (h)'), findsWidgets);
      expect(find.text('Planned (h)'), findsWidgets);
      expect(find.text('Actual (h)'), findsWidgets);
      expect(find.text('Remaining (h)'), findsOneWidget);
      expect(find.text('Utilization'), findsWidgets);
      expect(find.text('Work Items'), findsOneWidget);

      // Tap "Role" to sort by Role
      await tester.tap(find.text('Role'));
      await tester.pumpAndSettle();

      // Tap "Role" again to toggle descending
      await tester.tap(find.text('Role'));
      await tester.pumpAndSettle();

      // Tap "Capacity (h)"
      await tester.tap(find.text('Capacity (h)').first);
      await tester.pumpAndSettle();
    });

    testWidgets(
        '5. Pagination footer renders rows per page and page navigation',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Pagination elements
      expect(find.text('Rows per page:'), findsOneWidget);
      expect(find.byIcon(Icons.first_page_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.byIcon(Icons.last_page_rounded), findsOneWidget);
    });
  });
}
