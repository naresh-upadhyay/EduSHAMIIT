import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

void main() {
  group('EduSHAMIIT Horizontal Scrollbar & ScrollBehavior Tests', () {
    testWidgets('EduShamiitScrollBehavior supports mouse and touch dragging', (tester) async {
      const behavior = EduShamiitScrollBehavior();
      expect(behavior.dragDevices.contains(PointerDeviceKind.mouse), isTrue);
      expect(behavior.dragDevices.contains(PointerDeviceKind.touch), isTrue);
      expect(behavior.dragDevices.contains(PointerDeviceKind.trackpad), isTrue);
    });

    testWidgets('Theme includes fully configured ScrollbarThemeData for light and dark', (tester) async {
      final lightTheme = getStudentTheme(brightness: Brightness.light);
      final darkTheme = getStudentTheme(brightness: Brightness.dark);
      final teacherLight = getTeacherTheme(brightness: Brightness.light);
      final teacherDark = getTeacherTheme(brightness: Brightness.dark);

      expect(lightTheme.scrollbarTheme.thumbVisibility?.resolve({}), isTrue);
      expect(lightTheme.scrollbarTheme.trackVisibility?.resolve({}), isTrue);
      expect(lightTheme.scrollbarTheme.interactive, isTrue);

      expect(darkTheme.scrollbarTheme.thumbVisibility?.resolve({}), isTrue);
      expect(darkTheme.scrollbarTheme.trackVisibility?.resolve({}), isTrue);
      expect(darkTheme.scrollbarTheme.interactive, isTrue);

      expect(teacherLight.scrollbarTheme.thumbVisibility?.resolve({}), isTrue);
      expect(teacherDark.scrollbarTheme.thumbVisibility?.resolve({}), isTrue);
    });

    testWidgets('DataTable overflowing horizontally builds visible horizontal scrollbar', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const EduShamiitScrollBehavior(),
          theme: getStudentTheme(brightness: Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 1400),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Staff Member')),
                      DataColumn(label: Text('Department')),
                      DataColumn(label: Text('Gross Salary')),
                      DataColumn(label: Text('Deductions')),
                      DataColumn(label: Text('Net Pay')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: List.generate(
                      5,
                      (i) => DataRow(cells: [
                        DataCell(Text('Staff Row $i')),
                        const DataCell(Text('Engineering')),
                        const DataCell(Text('₹ 75,000')),
                        const DataCell(Text('- ₹ 10,000')),
                        const DataCell(Text('₹ 65,000')),
                        const DataCell(Text('Paid')),
                        const DataCell(Text('Action')),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that Scrollbar widgets are constructed
      final scrollbarFinder = find.byType(Scrollbar);
      expect(scrollbarFinder, findsWidgets);

      // Verify mouse drag can scroll horizontally
      final initialOffset = tester.getTopLeft(find.text('Staff Row 0'));
      final gesture = await tester.startGesture(const Offset(400, 200), kind: PointerDeviceKind.mouse);
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pumpAndSettle();
      await gesture.up();

      final scrolledOffset = tester.getTopLeft(find.text('Staff Row 0'));
      expect(scrolledOffset.dx, lessThan(initialOffset.dx));
    });
  });
}
