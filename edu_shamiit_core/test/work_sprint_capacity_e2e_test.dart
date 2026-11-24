import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/sprints/sprint_capacity_tab_view.dart';
import 'package:edu_shamiit_core/screens/work_management/utils/work_sprint_date_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableCapacityWidget({String sprintId = 's8', String selectedTeam = 'Digital Campus Team', double width = 1800}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
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

  group('Sprint Capacity Management Comprehensive E2E Tests', () {
    testWidgets('Renders Hero card and all 6 KPI cards with exact values', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      await tester.pumpWidget(buildTestableCapacityWidget());
      await tester.pumpAndSettle();

      // 1. Hero Card
      expect(find.text('Digital Campus Team'), findsWidgets);
      expect(find.text('Sprint 8 (${WorkSprintDateHelper.currentSprintFullDurationRange})'), findsOneWidget);

      // 2. 6 KPI Cards
      expect(find.text('Team Members'), findsOneWidget);
      expect(find.text('7'), findsWidgets);

      expect(find.text('Total Capacity'), findsWidgets);
      expect(find.text('280 h'), findsWidgets);

      expect(find.text('Planned Work'), findsWidgets);
      expect(find.text('257 h'), findsWidgets);

      expect(find.text('Remaining'), findsOneWidget);
      expect(find.text('23 h'), findsWidgets);

      expect(find.text('Utilization'), findsWidgets);
      expect(find.text('91.8%'), findsWidgets);

      expect(find.text('Over Allocation'), findsWidgets);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('Renders Sprint Burndown Chart toggle and Daily Grouped Bar Chart', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      await tester.pumpWidget(buildTestableCapacityWidget());
      await tester.pumpAndSettle();

      expect(find.text('Sprint Burndown'), findsWidgets);
      expect(find.text('Burndown'), findsOneWidget);
      expect(find.text('Daily Effort'), findsOneWidget);

      // Verify legend indicators
      expect(find.text('Ideal Burndown'), findsOneWidget);
      expect(find.text('Remaining (h)'), findsWidgets);
      expect(find.text('Completed (h)'), findsOneWidget);
      expect(find.text('Daily Capacity'), findsOneWidget);

      // Tap Daily Effort switcher
      await tester.tap(find.text('Daily Effort'));
      await tester.pumpAndSettle();

      expect(find.text('Capacity vs Workload (Daily)'), findsOneWidget);
      expect(find.text('Capacity (h)'), findsWidgets);
      expect(find.text('Planned (h)'), findsWidgets);
      expect(find.text('Actual (h)'), findsWidgets);
    });

    testWidgets('Renders 7 Team Members with Roles, Hours, and Status Badges', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      await tester.pumpWidget(buildTestableCapacityWidget());
      await tester.pumpAndSettle();

      expect(find.text('Team Member Capacity & Workload (7)'), findsOneWidget);

      // Members
      expect(find.text('Neha Sharma'), findsOneWidget);
      expect(find.text('Team Lead'), findsOneWidget);

      expect(find.text('Amit Kumar'), findsOneWidget);
      expect(find.text('Senior Developer'), findsOneWidget);

      expect(find.text('Priya Singh'), findsOneWidget);
      expect(find.text('UI/UX Designer'), findsOneWidget);

      expect(find.text('Rahul Mehta'), findsOneWidget);
      expect(find.text('Backend Developer'), findsOneWidget);

      expect(find.text('Sneha Verma'), findsOneWidget);
      expect(find.text('QA Engineer'), findsOneWidget);

      expect(find.text('Vikas Gupta'), findsOneWidget);
      expect(find.text('DevOps Engineer'), findsOneWidget);

      expect(find.text('Karan Jain'), findsOneWidget);
      expect(find.text('System Analyst'), findsOneWidget);

      // Statuses
      expect(find.text('Overloaded'), findsOneWidget);
      expect(find.text('High'), findsWidgets);
      expect(find.text('Balanced'), findsWidgets);
    });

    testWidgets('Renders Capacity Utilization Donut, Summary, and Insights Cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      await tester.pumpWidget(buildTestableCapacityWidget());
      await tester.pumpAndSettle();

      // Donut
      expect(find.text('Capacity Utilization'), findsOneWidget);
      expect(find.text('Available Capacity'), findsOneWidget);

      // Summary
      expect(find.text('Capacity Summary'), findsOneWidget);
      expect(find.text('Total Team Capacity'), findsOneWidget);
      expect(find.text('Planned / Committed Work'), findsOneWidget);
      expect(find.text('Actual Work (Completed)'), findsOneWidget);
      expect(find.text('Remaining Capacity'), findsOneWidget);

      // Insights
      expect(find.text('Capacity Insights'), findsOneWidget);
      expect(find.text('Team is within capacity (91.8% utilization).'), findsOneWidget);
      expect(find.text('1 member is over-allocated (Karan Jain – 102.5%).'), findsOneWidget);
      expect(find.text('23 h capacity available for additional high-priority work.'), findsOneWidget);
      expect(find.text('Average capacity per member: 40 h (planned: 36.7 h).'), findsOneWidget);
    });

    testWidgets('Opens Adjust Capacity Dialog when button is tapped', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      await tester.pumpWidget(buildTestableCapacityWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Adjust Capacity'));
      await tester.pumpAndSettle();

      expect(find.text('Daily Hours'), findsOneWidget);
      expect(find.text('Sprint Days'), findsOneWidget);
      expect(find.text('Save Sprint Capacity'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Add Team Member button is permanently removed and Edit Capacity buttons are present', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1900, 1200));
      await tester.pumpWidget(buildTestableCapacityWidget(width: 1900));
      await tester.pumpAndSettle();

      // Ensure Add Team Member button is not on screen
      expect(find.text('Add Team Member'), findsNothing);

      // Verify individual Edit button exists for each member row
      expect(find.byTooltip('Edit Sprint Capacity'), findsWidgets);

      // Scroll to ensure visible in horizontal view then tap
      await tester.ensureVisible(find.byTooltip('Edit Sprint Capacity').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit Sprint Capacity').first);
      await tester.pumpAndSettle();

      expect(find.text('Daily Hours'), findsOneWidget);
      expect(find.text('Sprint Days'), findsOneWidget);
      expect(find.text('Days Off / Leaves'), findsOneWidget);
      expect(find.text('Role in this Sprint (from System Roles)'), findsOneWidget);
      expect(find.text('Save Sprint Capacity'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Checkbox selection renders single column, shows selected count, and supports select-all', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      await tester.pumpWidget(buildTestableCapacityWidget());
      await tester.pumpAndSettle();

      // Checkboxes exist (one per row plus one in header)
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsWidgets);

      // Select first row checkbox
      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();

      // Selected badge should now appear
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Adjust Capacity (1)'), findsOneWidget);
      expect(find.text('Remove (1)'), findsOneWidget);

      // Tap header checkbox (select all)
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      // All 7 selected
      expect(find.text('7 selected'), findsOneWidget);
      expect(find.text('Adjust Capacity (7)'), findsOneWidget);

      // Clear selection via close icon
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('7 selected'), findsNothing);
      expect(find.text('Adjust Capacity'), findsOneWidget);
    });
  });
}
