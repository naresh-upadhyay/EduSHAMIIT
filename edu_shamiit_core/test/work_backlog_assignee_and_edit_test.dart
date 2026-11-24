import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';

void main() {
  group('Backlog Assignee & Edit Verification Tests', () {
    test('WorkItemModel parses multiple assignees and fallback assignee_name', () {
      final multiAssigneeJson = {
        'id': 'tk-3001',
        'item_number': 'TK-3001',
        'title': 'RFID Turnstile Integration & Protocol Gateway',
        'work_type': 'TASK',
        'priority': 'HIGH',
        'status': 'ACTIVE',
        'category': 'Facilities',
        'assignees': [
          {
            'id': 'u1',
            'user_id': 'u1',
            'full_name': 'System Admin',
            'role': 'admin',
            'email': 'admin@edushamiit.com',
          },
          {
            'id': 'u2',
            'user_id': 'u2',
            'full_name': 'Test Admin 2',
            'role': 'admin',
            'email': 'admin2@edushamiit.com',
          },
          {
            'id': 'u3',
            'user_id': 'u3',
            'full_name': 'Test Admin QA',
            'role': 'qa',
            'email': 'qa@edushamiit.com',
          },
        ],
      };

      final item = WorkItemModel.fromJson(multiAssigneeJson);
      expect(item.assignees.length, equals(3));
      expect(item.assignees[0].fullName, equals('System Admin'));
      expect(item.assignees[1].fullName, equals('Test Admin 2'));
      expect(item.assignees[2].fullName, equals('Test Admin QA'));

      // Fallback single assignee
      final singleAssigneeJson = {
        'id': 'tk-3002',
        'item_number': 'TK-3002',
        'title': 'Single Assignee Item',
        'work_type': 'TASK',
        'priority': 'MEDIUM',
        'status': 'NEW',
        'category': 'IT',
        'assignee_id': 'u4',
        'assignee_name': 'Dr. Rajesh Verma',
        'assignee_role': 'teacher',
      };

      final singleItem = WorkItemModel.fromJson(singleAssigneeJson);
      expect(singleItem.assignees.length, equals(1));
      expect(singleItem.assignees.first.fullName, equals('Dr. Rajesh Verma'));
      expect(singleItem.assignees.first.role, equals('teacher'));
    });

    test('WorkItemModel.copyWith preserves and updates title, description, category, and assignees', () {
      const original = WorkItemModel(
        id: 'st-101',
        itemNumber: 'ST-101',
        title: 'Original Title',
        description: 'Original Description',
        workType: 'STORY',
        priority: 'MEDIUM',
        status: 'NEW',
        category: 'Academic',
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        description: 'Updated Description',
        category: 'Administration',
        priority: 'HIGH',
        status: 'ACTIVE',
        assignees: [
          const WorkAssigneeModel(
            id: 'a1',
            userId: 'a1',
            fullName: 'Test User',
          ),
        ],
      );

      expect(updated.title, equals('Updated Title'));
      expect(updated.description, equals('Updated Description'));
      expect(updated.category, equals('Administration'));
      expect(updated.priority, equals('HIGH'));
      expect(updated.status, equals('ACTIVE'));
      expect(updated.assignees.length, equals(1));
      expect(updated.assignees.first.fullName, equals('Test User'));
    });

    test('WorkBacklogNotifier.updateItemLocally updates both top-level stories and child tasks instantly', () {
      final notifier = WorkBacklogNotifier();

      const initialChild = WorkItemModel(
        id: 'tk-3001',
        itemNumber: 'TK-3001',
        title: 'Child Task',
        workType: 'TASK',
        priority: 'HIGH',
        status: 'NEW',
        assignees: [],
      );

      const initialStory = WorkItemModel(
        id: 'st-101',
        itemNumber: 'ST-101',
        title: 'Parent Story',
        workType: 'STORY',
        priority: 'MEDIUM',
        status: 'NEW',
        assignees: [],
        children: [initialChild],
      );

      notifier.state = notifier.state.copyWith(
        stories: [initialStory],
        isLoading: false,
      );

      // Now simulate assigning 3 users to TK-3001
      final updatedChild = initialChild.copyWith(
        status: 'ACTIVE',
        assignees: [
          const WorkAssigneeModel(id: 'u1', userId: 'u1', fullName: 'System Admin'),
          const WorkAssigneeModel(id: 'u2', userId: 'u2', fullName: 'Test Admin 2'),
          const WorkAssigneeModel(id: 'u3', userId: 'u3', fullName: 'Test Admin QA'),
        ],
      );

      notifier.updateItemLocally(updatedChild);

      final currentStory = notifier.state.stories.first;
      expect(currentStory.children.first.status, equals('ACTIVE'));
      expect(currentStory.children.first.assignees.length, equals(3));
      expect(currentStory.children.first.assignees.map((a) => a.fullName),
          containsAll(['System Admin', 'Test Admin 2', 'Test Admin QA']));
    });
  });
}
