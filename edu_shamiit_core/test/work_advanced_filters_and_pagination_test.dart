import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/utils/work_filter_helper.dart';

void main() {
  group('Advanced Work Management Filters Test Suite', () {
    final studentAssignee1 = WorkAssigneeModel(
      id: 'usr-1',
      userId: 'usr-1',
      fullName: 'Aarav Sharma',
      email: 'aarav@shamiit.com',
      role: 'STUDENT',
      department: 'Academic',
      className: 'Class 5',
      sectionName: 'A',
    );

    final studentAssignee2 = WorkAssigneeModel(
      id: 'usr-2',
      userId: 'usr-2',
      fullName: 'Bhavya Patel',
      email: 'bhavya@shamiit.com',
      role: 'STUDENT',
      department: 'Academic',
      className: 'Class 5',
      sectionName: 'B',
    );

    final teacherAssignee = WorkAssigneeModel(
      id: 'usr-3',
      userId: 'usr-3',
      fullName: 'Rajesh Sharma',
      email: 'rajesh@shamiit.com',
      role: 'TEACHER',
      department: 'Academic',
    );

    final itStaffAssignee = WorkAssigneeModel(
      id: 'usr-4',
      userId: 'usr-4',
      fullName: 'Vikram Singh',
      email: 'vikram@shamiit.com',
      role: 'STAFF',
      department: 'IT Services',
    );

    final studentTaskClass5SecA = WorkItemModel(
      id: 'tk-1',
      itemNumber: 'TK-101',
      title: 'Class 5 Math Assignment',
      workType: 'TASK',
      status: 'NEW',
      priority: 'MEDIUM',
      category: 'Academic',
      assignees: [studentAssignee1],
    );

    final studentTaskClass5SecB = WorkItemModel(
      id: 'tk-2',
      itemNumber: 'TK-102',
      title: 'Class 5 Science Project',
      workType: 'TASK',
      status: 'ACTIVE',
      priority: 'HIGH',
      category: 'Academic',
      assignees: [studentAssignee2],
    );

    final teacherTask = WorkItemModel(
      id: 'tk-3',
      itemNumber: 'TK-103',
      title: 'Grade Midterm Papers',
      workType: 'TASK',
      status: 'ACTIVE',
      priority: 'HIGH',
      category: 'Academic',
      assignees: [teacherAssignee],
    );

    final itTask = WorkItemModel(
      id: 'tk-4',
      itemNumber: 'TK-104',
      title: 'WiFi Router Installation',
      workType: 'TASK',
      status: 'RESOLVED',
      priority: 'LOW',
      category: 'IT Services',
      assignees: [itStaffAssignee],
    );

    test('All filter returns true for all items', () {
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: studentTaskClass5SecA,
          roleFilter: 'All',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
        ),
        isTrue,
      );
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: itTask,
          roleFilter: 'All',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
        ),
        isTrue,
      );
    });

    test('Role filtering isolates Student vs Teacher vs Staff', () {
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: studentTaskClass5SecA,
          roleFilter: 'Student',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
        ),
        isTrue,
      );
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: teacherTask,
          roleFilter: 'Student',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
        ),
        isFalse,
      );
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: teacherTask,
          roleFilter: 'Teacher',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
        ),
        isTrue,
      );
    });

    test('Department filtering isolates IT Services vs Academic', () {
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: itTask,
          roleFilter: 'All',
          departmentFilter: 'IT Services',
          classFilter: 'All',
          sectionFilter: 'All',
        ),
        isTrue,
      );
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: studentTaskClass5SecA,
          roleFilter: 'All',
          departmentFilter: 'IT Services',
          classFilter: 'All',
          sectionFilter: 'All',
        ),
        isFalse,
      );
    });

    test('Cascaded Class and Section filtering for Student role', () {
      // 1. Role: Student, Class: Class 5 -> Both Sec A and Sec B match
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: studentTaskClass5SecA,
          roleFilter: 'Student',
          departmentFilter: 'All',
          classFilter: 'Class 5',
          sectionFilter: 'All',
        ),
        isTrue,
      );
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: studentTaskClass5SecB,
          roleFilter: 'Student',
          departmentFilter: 'All',
          classFilter: 'Class 5',
          sectionFilter: 'All',
        ),
        isTrue,
      );

      // 2. Role: Student, Class: Class 5, Section: A -> Only Sec A matches
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: studentTaskClass5SecA,
          roleFilter: 'Student',
          departmentFilter: 'All',
          classFilter: 'Class 5',
          sectionFilter: 'A',
        ),
        isTrue,
      );
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: studentTaskClass5SecB,
          roleFilter: 'Student',
          departmentFilter: 'All',
          classFilter: 'Class 5',
          sectionFilter: 'A',
        ),
        isFalse,
      );

      // 3. Different Class (Class 10) -> Fails
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: studentTaskClass5SecA,
          roleFilter: 'Student',
          departmentFilter: 'All',
          classFilter: 'Class 10',
          sectionFilter: 'All',
        ),
        isFalse,
      );
    });

    test('Academic classes and sections extractor parses classes with nested sections', () {
      final mockClasses = [
        const WorkAcademicClassModel(
          id: 'cls-1',
          name: 'Class 5',
          sections: [
            WorkAcademicSectionModel(id: 's-1', name: 'A'),
            WorkAcademicSectionModel(id: 's-2', name: 'B'),
            WorkAcademicSectionModel(id: 's-3', name: 'NEWSUB2'),
          ],
        ),
        const WorkAcademicClassModel(
          id: 'cls-2',
          name: 'Class 10',
          sections: [
            WorkAcademicSectionModel(id: 's-4', name: 'A'),
            WorkAcademicSectionModel(id: 's-5', name: 'C'),
          ],
        ),
      ];

      final sectionsForCls5 = WorkFilterHelper.getSectionsForClass(mockClasses, 'Class 5');
      expect(sectionsForCls5, equals(['All', 'A', 'B', 'NEWSUB2']));

      final sectionsForCls10 = WorkFilterHelper.getSectionsForClass(mockClasses, 'Class 10');
      expect(sectionsForCls10, equals(['All', 'A', 'C']));

      final sectionsForUnknown = WorkFilterHelper.getSectionsForClass(mockClasses, 'NonExistent');
      expect(sectionsForUnknown, equals(['All']));
    });

    test('Team filtering isolates Academic Systems Team vs Digital Campus Team', () {
      final teamTask1 = WorkItemModel(
        id: 'tk-10',
        itemNumber: 'TK-201',
        title: 'Curriculum Engine Optimization',
        workType: 'TASK',
        status: 'ACTIVE',
        priority: 'HIGH',
        category: 'Academic',
        teamId: 'team-ast',
        teamName: 'Academic Systems Team',
      );

      final teamTask2 = WorkItemModel(
        id: 'tk-11',
        itemNumber: 'TK-202',
        title: 'Student Portal Mobile Responsive Fix',
        workType: 'TASK',
        status: 'NEW',
        priority: 'MEDIUM',
        category: 'IT Services',
        teamId: 'team-dct',
        teamName: 'Digital Campus Team',
      );

      // Matches Academic Systems Team
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: teamTask1,
          roleFilter: 'All',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
          teamFilter: 'Academic Systems Team',
        ),
        isTrue,
      );

      // Digital Campus Team does not match Academic Systems Team
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: teamTask2,
          roleFilter: 'All',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
          teamFilter: 'Academic Systems Team',
        ),
        isFalse,
      );

      // Digital Campus Team matches Digital Campus Team
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: teamTask2,
          roleFilter: 'All',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
          teamFilter: 'Digital Campus Team',
        ),
        isTrue,
      );
    });

    test('Parent story matches team filter when child task is tagged to team', () {
      final childTask = WorkItemModel(
        id: 'tk-child-1',
        itemNumber: 'TK-301',
        title: 'Backend API for Marks Entry',
        workType: 'TASK',
        status: 'ACTIVE',
        priority: 'HIGH',
        category: 'Examination',
        teamId: 'team-exam',
        teamName: 'Examination Team',
      );

      final parentStory = WorkItemModel(
        id: 'st-parent-1',
        itemNumber: 'ST-501',
        title: 'Term 1 Exam Marks Publishing',
        workType: 'STORY',
        status: 'NEW',
        priority: 'HIGH',
        category: 'Examination',
        teamName: null, // Story itself has no team
        children: [childTask], // But child task is tagged to Examination Team
      );

      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: parentStory,
          roleFilter: 'All',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
          teamFilter: 'Examination Team',
        ),
        isTrue,
      );

      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: parentStory,
          roleFilter: 'All',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
          teamFilter: 'Digital Campus Team',
        ),
        isFalse,
      );
    });

    test('Tagging multiple items updates teamName and teamId correctly', () {
      final untaggedItem1 = WorkItemModel(
        id: 'item-1',
        itemNumber: 'TK-1001',
        title: 'Setup Library Barcode Scanner',
        workType: 'TASK',
        status: 'NEW',
        priority: 'LOW',
        category: 'Library',
      );

      final untaggedItem2 = WorkItemModel(
        id: 'item-2',
        itemNumber: 'TK-1002',
        title: 'Library Database Indexing',
        workType: 'TASK',
        status: 'NEW',
        priority: 'MEDIUM',
        category: 'Library',
      );

      // Simulate bulk tagging both to Operations & Facilities Team
      final tagged1 = untaggedItem1.copyWith(
        teamId: 'team-ops',
        teamName: 'Operations & Facilities Team',
      );
      final tagged2 = untaggedItem2.copyWith(
        teamId: 'team-ops',
        teamName: 'Operations & Facilities Team',
      );

      expect(tagged1.teamName, equals('Operations & Facilities Team'));
      expect(tagged1.teamId, equals('team-ops'));
      expect(tagged2.teamName, equals('Operations & Facilities Team'));
      expect(tagged2.teamId, equals('team-ops'));

      // Both now match Operations & Facilities Team filter
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: tagged1,
          roleFilter: 'All',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
          teamFilter: 'Operations & Facilities Team',
        ),
        isTrue,
      );

      // Simulate untagging / unassigning
      final untaggedAgain = tagged1.copyWith(
        clearTeam: true,
      );
      expect(untaggedAgain.teamName, isNull);
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: untaggedAgain,
          roleFilter: 'All',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
          teamFilter: 'Operations & Facilities Team',
        ),
        isFalse,
      );
    });

    test('Combined Role, Department, Class, Section, and Team filters', () {
      final complexTask = WorkItemModel(
        id: 'tk-complex',
        itemNumber: 'TK-999',
        title: 'Class 5 Mathematics Olympiad Prep',
        workType: 'HOMEWORK',
        status: 'ACTIVE',
        priority: 'HIGH',
        category: 'Academic',
        teamId: 'team-ast',
        teamName: 'Academic Systems Team',
        assignees: [studentAssignee1], // Aarav Sharma, STUDENT, Academic, Class 5, Section A
      );

      // All filters matching
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: complexTask,
          roleFilter: 'Student',
          departmentFilter: 'Academic',
          classFilter: 'Class 5',
          sectionFilter: 'A',
          teamFilter: 'Academic Systems Team',
        ),
        isTrue,
      );

      // Team mismatch fails
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: complexTask,
          roleFilter: 'Student',
          departmentFilter: 'Academic',
          classFilter: 'Class 5',
          sectionFilter: 'A',
          teamFilter: 'Digital Campus Team',
        ),
        isFalse,
      );

      // Section mismatch fails
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: complexTask,
          roleFilter: 'Student',
          departmentFilter: 'Academic',
          classFilter: 'Class 5',
          sectionFilter: 'B',
          teamFilter: 'Academic Systems Team',
        ),
        isFalse,
      );
    });
  });
}
