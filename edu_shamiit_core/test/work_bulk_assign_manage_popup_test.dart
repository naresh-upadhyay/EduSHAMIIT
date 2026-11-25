import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/utils/work_filter_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockUsers = [
    const WorkAssigneeModel(
      id: 'u-1',
      userId: 'u-1',
      fullName: 'Archana Shukla',
      role: 'teacher',
      email: 'archana@school.com',
      department: 'Mathematics',
    ),
    const WorkAssigneeModel(
      id: 'u-2',
      userId: 'u-2',
      fullName: 'King Doe',
      role: 'super_admin',
      email: 'king@school.com',
      department: 'Administration',
    ),
    const WorkAssigneeModel(
      id: 'u-3',
      userId: 'u-3',
      fullName: 'Amit Kumar',
      role: 'teacher',
      email: 'amit@school.com',
      department: 'Computer Science',
    ),
  ];

  testWidgets(
      'WorkFilterHelper.openManageAssigneesDialog renders and applies multi-assignees',
      (tester) async {
    List<String> appliedItemIds = [];
    List<String> appliedUserIds = [];
    List<WorkAssigneeModel> appliedUsers = [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () {
                  WorkFilterHelper.openManageAssigneesDialog(
                    context: context,
                    itemIds: ['item-101', 'item-102'],
                    availableUsers: mockUsers,
                    initialSelectedUserIds: {'u-1'},
                    onApply: ({
                      required List<String> itemIds,
                      required List<String> selectedUserIds,
                      required List<WorkAssigneeModel> selectedUsers,
                    }) async {
                      appliedItemIds = itemIds;
                      appliedUserIds = selectedUserIds;
                      appliedUsers = selectedUsers;
                      return true;
                    },
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      ),
    );

    // Tap to open dialog
    await tester.tap(find.byKey(const Key('open_dialog_btn')));
    await tester.pumpAndSettle();

    // Verify dialog header shows initial selection
    expect(find.text('Manage Assignees (1 selected)'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);

    // Verify search field exists
    expect(find.byType(TextField), findsOneWidget);
    expect(
        find.text('Search teachers, students, staff by name, role, email...'),
        findsOneWidget);

    // Verify role filter chips exist
    expect(find.text('All Roles'), findsOneWidget);
    expect(find.text('TEACHER'), findsOneWidget);
    expect(find.text('SUPER_ADMIN'), findsOneWidget);

    // Verify user list items with roles and departments
    expect(find.text('Archana Shukla'), findsOneWidget);
    expect(find.text('King Doe'), findsOneWidget);
    expect(find.text('Amit Kumar'), findsOneWidget);
    expect(find.text('TEACHER • Mathematics • archana@school.com'),
        findsOneWidget);

    // Select second user (King Doe)
    final kingCheckbox = find.widgetWithText(CheckboxListTile, 'King Doe');
    expect(kingCheckbox, findsOneWidget);
    await tester.tap(kingCheckbox);
    await tester.pumpAndSettle();

    // Verify count updated to 2
    expect(find.text('Manage Assignees (2 selected)'), findsOneWidget);
    expect(find.text('Save (2)'), findsOneWidget);

    // Tap Save button
    await tester.tap(find.text('Save (2)'));
    await tester.pumpAndSettle();

    // Verify onApply was called with correct items and both selected user IDs
    expect(appliedItemIds, equals(['item-101', 'item-102']));
    expect(appliedUserIds.toSet(), equals({'u-1', 'u-2'}));
    expect(appliedUsers.length, equals(2));
  });

  testWidgets('WorkFilterHelper.openManageAssigneesDialog Clear all works',
      (tester) async {
    List<String> appliedUserIds = ['should-be-cleared'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                key: const Key('open_dialog_btn_2'),
                onPressed: () {
                  WorkFilterHelper.openManageAssigneesDialog(
                    context: context,
                    itemIds: ['item-101'],
                    availableUsers: mockUsers,
                    initialSelectedUserIds: {'u-1'},
                    onApply: ({
                      required List<String> itemIds,
                      required List<String> selectedUserIds,
                      required List<WorkAssigneeModel> selectedUsers,
                    }) async {
                      appliedUserIds = selectedUserIds;
                      return true;
                    },
                  );
                },
                child: const Text('Open Dialog 2'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_dialog_btn_2')));
    await tester.pumpAndSettle();

    expect(find.text('Manage Assignees (1 selected)'), findsOneWidget);

    // Tap Clear all
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    expect(find.text('Manage Assignees (0 selected)'), findsOneWidget);
    expect(find.text('Save (0)'), findsOneWidget);

    // Save with 0 assignees
    await tester.tap(find.text('Save (0)'));
    await tester.pumpAndSettle();

    expect(appliedUserIds, isEmpty);
  });
}
