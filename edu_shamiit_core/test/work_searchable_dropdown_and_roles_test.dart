import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/utils/work_filter_helper.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/work_searchable_dropdown.dart';

void main() {
  group('WorkSearchableDropdown Option Sorting & Logic Tests', () {
    test('sortOptions pins All at index 0 and sorts remaining alphabetically', () {
      final raw = [
        'Super Admin',
        'Teacher',
        'Academic Admin',
        'All',
        'Hostel Warden',
        'Auditor',
        'Campus Security',
      ];

      final sorted = WorkSearchableDropdown.sortOptions(raw);

      expect(sorted.first, equals('All'));
      expect(sorted, equals([
        'All',
        'Academic Admin',
        'Auditor',
        'Campus Security',
        'Hostel Warden',
        'Super Admin',
        'Teacher',
      ]));
    });

    test('sortOptions pins All Boards / All Roles at index 0', () {
      final raw = [
        'IT & Infra Board',
        'All Boards',
        'Academic Board',
        'Institute Work Board',
      ];

      final sorted = WorkSearchableDropdown.sortOptions(raw);

      expect(sorted.first, equals('All Boards'));
      expect(sorted, equals([
        'All Boards',
        'Academic Board',
        'Institute Work Board',
        'IT & Infra Board',
      ]));
    });
  });

  group('WorkFilterHelper 27 Roles Tests', () {
    test('defaultRoles contains exactly 27 roles plus All (28 items total)', () {
      expect(WorkFilterHelper.defaultRoles.first, equals('All'));
      expect(WorkFilterHelper.defaultRoles.length, equals(28));
      
      // Verify all canonical roles from /v1/work/roles are present
      expect(WorkFilterHelper.defaultRoles, contains('Academic Admin'));
      expect(WorkFilterHelper.defaultRoles, contains('Accountant'));
      expect(WorkFilterHelper.defaultRoles, contains('Auditor'));
      expect(WorkFilterHelper.defaultRoles, contains('Campus Administrator'));
      expect(WorkFilterHelper.defaultRoles, contains('Campus Security'));
      expect(WorkFilterHelper.defaultRoles, contains('Department Head'));
      expect(WorkFilterHelper.defaultRoles, contains('Device Administrator'));
      expect(WorkFilterHelper.defaultRoles, contains('Director'));
      expect(WorkFilterHelper.defaultRoles, contains('Driver'));
      expect(WorkFilterHelper.defaultRoles, contains('Examination Controller'));
      expect(WorkFilterHelper.defaultRoles, contains('Facility Manager'));
      expect(WorkFilterHelper.defaultRoles, contains('Front Office'));
      expect(WorkFilterHelper.defaultRoles, contains('Hostel Warden'));
      expect(WorkFilterHelper.defaultRoles, contains('HR Manager'));
      expect(WorkFilterHelper.defaultRoles, contains('Institution Admin'));
      expect(WorkFilterHelper.defaultRoles, contains('IoT Operator'));
      expect(WorkFilterHelper.defaultRoles, contains('IT/IoT Administrator'));
      expect(WorkFilterHelper.defaultRoles, contains('Librarian'));
      expect(WorkFilterHelper.defaultRoles, contains('Maintenance Staff'));
      expect(WorkFilterHelper.defaultRoles, contains('Sports Coach'));
      expect(WorkFilterHelper.defaultRoles, contains('Staff Member'));
      expect(WorkFilterHelper.defaultRoles, contains('Student'));
      expect(WorkFilterHelper.defaultRoles, contains('Student (Parent)'));
      expect(WorkFilterHelper.defaultRoles, contains('Super Admin'));
      expect(WorkFilterHelper.defaultRoles, contains('Teacher'));
      expect(WorkFilterHelper.defaultRoles, contains('Transport Manager'));
      expect(WorkFilterHelper.defaultRoles, contains('View Only'));

      // Verify strict alphabetical order for items after 'All'
      final subList = WorkFilterHelper.defaultRoles.sublist(1);
      final sortedCopy = List<String>.from(subList)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      expect(subList, equals(sortedCopy));
    });

    test('matchesAdvancedFilters matches role aliases correctly', () {
      const itemWithAcademicAdmin = WorkItemModel(
        id: '1',
        itemNumber: 'TK-101',
        title: 'Curriculum Audit',
        workType: 'TASK',
        status: 'NEW',
        priority: 'MEDIUM',
        category: 'Academic',
        assignees: [
          WorkAssigneeModel(
            id: 'u1',
            userId: 'u1',
            fullName: 'Dr. John Principal',
            role: 'principal',
          ),
        ],
      );

      // Filtering by 'Academic Admin' should match assignee with role 'principal'
      final matches = WorkFilterHelper.matchesAdvancedFilters(
        item: itemWithAcademicAdmin,
        roleFilter: 'Academic Admin',
        departmentFilter: 'All',
        classFilter: 'All',
        sectionFilter: 'All',
      );
      expect(matches, isTrue);

      // Filtering by 'Teacher' should not match
      final mismatch = WorkFilterHelper.matchesAdvancedFilters(
        item: itemWithAcademicAdmin,
        roleFilter: 'Teacher',
        departmentFilter: 'All',
        classFilter: 'All',
        sectionFilter: 'All',
      );
      expect(mismatch, isFalse);
    });
  });

  group('WorkSearchableDropdown Widget Interactive Tests', () {
    testWidgets('renders trigger and opens searchable overlay dialog', (tester) async {
      String? selectedVal = 'All';
      final testItems = [
        'All',
        'Academic Admin',
        'Campus Security',
        'Institution Admin',
        'Staff Member',
        'Teacher',
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WorkSearchableDropdown(
                label: 'Role',
                value: selectedVal,
                items: testItems,
                onChanged: (val) {
                  selectedVal = val;
                },
              ),
            ),
          ),
        ),
      );

      // Verify trigger display
      expect(find.text('Role: '), findsOneWidget);
      expect(find.text('All'), findsOneWidget);

      // Tap to open popover overlay
      await tester.tap(find.byType(WorkSearchableDropdown));
      await tester.pumpAndSettle();

      // Verify search input is displayed
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('of 6 roles'), findsOneWidget);

      // Type "Teacher" into search
      await tester.enterText(find.byType(TextField), 'Teach');
      await tester.pumpAndSettle();

      // Only Teacher should remain matching
      expect(find.textContaining('Teacher'), findsWidgets);
      expect(find.textContaining('Academic Admin'), findsNothing);

      // Tap Teacher to select
      await tester.tap(find.textContaining('Teacher').first);
      await tester.pumpAndSettle();

      expect(selectedVal, equals('Teacher'));
    });
  });
}
