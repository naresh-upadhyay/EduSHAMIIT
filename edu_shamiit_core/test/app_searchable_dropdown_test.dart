import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';

void main() {
  group('DropdownHelper.sortOptions Tests', () {
    test('pins "All" or "All ..." at index 0 and sorts remaining alphabetically', () {
      final raw = ['Zebra', 'Apple', 'All Items', 'Mango'];
      final sorted = DropdownHelper.sortOptions(raw);
      expect(sorted.first, equals('All Items'));
      expect(sorted, equals(['All Items', 'Apple', 'Mango', 'Zebra']));
    });

    test('handles custom object types via itemLabel', () {
      final items = [
        {'id': 1, 'name': 'Mathematics'},
        {'id': 2, 'name': 'All Subjects'},
        {'id': 3, 'name': 'Biology'},
      ];

      final sorted = DropdownHelper.sortOptions(
        items,
        itemLabel: (it) => it['name'] as String,
      );

      expect(sorted.first['name'], equals('All Subjects'));
      expect(sorted.map((e) => e['name']).toList(), equals([
        'All Subjects',
        'Biology',
        'Mathematics',
      ]));
    });
  });

  group('AppSearchableDropdown Widget Tests', () {
    testWidgets('Renders label and current value cleanly', (tester) async {
      String? selected = 'Sprint 103 (Active)';
      final items = [
        'All Sprints',
        'Backlog Only',
        'Sprint 103 (Active)',
        'Sprint 8 (Completed)',
        'Sprint 9 (Planned)',
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppSearchableDropdown<String>(
                label: 'Sprint',
                value: selected,
                items: items,
                onChanged: (val) => selected = val,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sprint: '), findsOneWidget);
      expect(find.text('Sprint 103 (Active)'), findsOneWidget);

      // Tap to open popover
      await tester.tap(find.text('Sprint 103 (Active)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Popover should show search input and items
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('5 of 5 sprints'), findsOneWidget);
      expect(find.text('Reset to All'), findsOneWidget);
      expect(find.text('Sprint 8 (Completed)'), findsOneWidget);

      // Tap on Sprint 8
      await tester.tap(find.text('Sprint 8 (Completed)'));
      await tester.pumpAndSettle();

      expect(selected, equals('Sprint 8 (Completed)'));
    });

    testWidgets('Live search filters items accurately', (tester) async {
      String? selected;
      final items = ['Driver Alice', 'Driver Bob', 'Driver Charlie', 'Driver David'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppSearchableDropdown<String>(
                label: 'Driver',
                value: selected,
                items: items,
                onChanged: (val) => selected = val,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppSearchableDropdown<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Enter search text 'bob'
      await tester.enterText(find.byType(TextField), 'bob');
      await tester.pump();

      expect(find.text('Driver Bob'), findsOneWidget);
      expect(find.text('Driver Alice'), findsNothing);
      expect(find.text('1 of 4 drivers'), findsOneWidget);

      // Select Driver Bob
      await tester.tap(find.text('Driver Bob'));
      await tester.pumpAndSettle();

      expect(selected, equals('Driver Bob'));
    });

    testWidgets('Renders safely in unbounded horizontal Row with isExpanded: true without throwing BoxConstraints exception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  AppSearchableDropdown<String>.fromMenuItems(
                    value: 'Item 1',
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'Item 1', child: Text('Item 1')),
                      DropdownMenuItem(value: 'Item 2', child: Text('Item 2')),
                    ],
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('Renders custom widget from selectedItemBuilder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppSearchableDropdown<String>.fromMenuItems(
                value: 'Custom 1',
                items: const [
                  DropdownMenuItem(value: 'Custom 1', child: Text('Default 1')),
                  DropdownMenuItem(value: 'Custom 2', child: Text('Default 2')),
                ],
                selectedItemBuilder: (ctx) => [
                  const Text('Custom Render 1'),
                  const Text('Custom Render 2'),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Custom Render 1'), findsOneWidget);
    });

    testWidgets('Upward opening popover has zero excessive gap and sits directly above trigger button', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? selected = 'Active';
      final items = ['All Status', 'Active', 'Inactive'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: const Alignment(0, 0.9), // Near bottom of screen
              child: AppSearchableDropdown<String>(
                label: 'Status',
                value: selected,
                items: items,
                onChanged: (v) => selected = v,
              ),
            ),
          ),
        ),
      );

      final buttonBox = tester.renderObject(find.byType(AppSearchableDropdown<String>)) as RenderBox;
      final buttonTopY = buttonBox.localToGlobal(Offset.zero).dy;

      // Tap to open popover
      await tester.tap(find.text('Active'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(TextField), findsOneWidget);

      // Find the search textfield inside the popover
      final searchBox = tester.renderObject(find.byType(TextField)) as RenderBox;
      final searchY = searchBox.localToGlobal(Offset.zero).dy;

      // The popover should be above the button
      expect(searchY, lessThan(buttonTopY));

      // The bottom item (Inactive) should be close to the button top (within ~40px including container padding)
      final inactiveBox = tester.renderObject(find.text('Inactive')) as RenderBox;
      final inactiveBottomY = inactiveBox.localToGlobal(Offset.zero).dy + inactiveBox.size.height;
      final gap = buttonTopY - inactiveBottomY;

      // Gap between last item and button should be tight and professional (between 0 and 25px)
      // Before this fix, gap was > 160px!
      expect(gap, greaterThanOrEqualTo(0.0));
      expect(gap, lessThanOrEqualTo(25.0));
    });
  });

  group('AppSearchableDropdownFormField Form Integration Tests', () {
    testWidgets('Integrates with GlobalKey<FormState>() and validates required field', (tester) async {
      final formKey = GlobalKey<FormState>();
      String? selectedVehicle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Column(
                children: [
                  AppSearchableDropdownFormField<String>(
                    labelText: 'Select Vehicle',
                    initialValue: selectedVehicle,
                    items: const ['Bus-01', 'Van-02', 'Bus-03'],
                    validator: (val) => val == null ? 'Vehicle is required' : null,
                    onChanged: (val) => selectedVehicle = val,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Select Vehicle'), findsOneWidget);

      // Validate form when empty -> should fail
      final isValidInitial = formKey.currentState!.validate();
      await tester.pump();
      expect(isValidInitial, isFalse);
      expect(find.text('Vehicle is required'), findsOneWidget);

      // Open popover and pick Bus-01
      await tester.tap(find.byType(AppSearchableDropdownFormField<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Bus-01'));
      await tester.pumpAndSettle();

      expect(selectedVehicle, equals('Bus-01'));

      // Validate form again -> should pass
      final isValidAfter = formKey.currentState!.validate();
      await tester.pump();
      expect(isValidAfter, isTrue);
      expect(find.text('Vehicle is required'), findsNothing);
    });

    testWidgets('fromMenuItems adapter correctly maps values and labels', (tester) async {
      final items = [
        const DropdownMenuItem(value: 101, child: Text('Room 101 (Lab)')),
        const DropdownMenuItem(value: 102, child: Text('Room 102 (Lecture)')),
        const DropdownMenuItem(value: 103, child: Text('Room 103 (Seminar)')),
      ];

      int? selectedRoom;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchableDropdownFormField<int>.fromMenuItems(
              labelText: 'Classroom',
              initialValue: 102,
              items: items,
              onChanged: (val) => selectedRoom = val,
            ),
          ),
        ),
      );

      expect(find.text('Room 102 (Lecture)'), findsOneWidget);

      await tester.tap(find.text('Room 102 (Lecture)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Room 101 (Lab)'), findsOneWidget);
      expect(find.text('Room 103 (Seminar)'), findsOneWidget);

      await tester.tap(find.text('Room 101 (Lab)'));
      await tester.pumpAndSettle();

      expect(selectedRoom, equals(101));
    });

    testWidgets('fromMenuItems handles null initialValue without TypeError', (tester) async {
      final items = [
        const DropdownMenuItem<String?>(value: null, child: Text('No Route Assigned')),
        const DropdownMenuItem<String?>(value: 'route_1', child: Text('Morning Route A')),
        const DropdownMenuItem<String?>(value: 'route_2', child: Text('Evening Route B')),
      ];

      String? selectedRoute;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchableDropdownFormField<String?>.fromMenuItems(
              labelText: 'Transport Route',
              initialValue: null,
              items: items,
              onChanged: (val) => selectedRoute = val,
            ),
          ),
        ),
      );

      // Should render without error and show empty or hint
      expect(find.byType(AppSearchableDropdownFormField<String?>), findsOneWidget);

      await tester.tap(find.byType(AppSearchableDropdownFormField<String?>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Morning Route A'), findsOneWidget);
      expect(find.text('Evening Route B'), findsOneWidget);

      await tester.tap(find.text('Morning Route A'));
      await tester.pumpAndSettle();

      expect(selectedRoute, equals('route_1'));
    });

    testWidgets('AppSearchableDropdown handles null value safely without TypeError', (tester) async {
      String? selectedVal;
      final items = ['Option A', 'Option B'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSearchableDropdown<String>(
              label: 'Test Null',
              value: null,
              items: items,
              onChanged: (val) => selectedVal = val,
            ),
          ),
        ),
      );

      expect(find.text('Test Null: '), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
    });
  });
}
