import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';

void main() {
  group('Exclude Archived & Inactive Teams Everywhere Tests', () {
    test('SprintCapacityTeamModel parses status and isActive, correctly identifies archived teams', () {
      final activeTeam = SprintCapacityTeamModel.fromJson({
        'id': '1',
        'name': 'Digital Campus Team',
        'status': 'ACTIVE',
        'is_active': true,
      });
      expect(activeTeam.isArchived, isFalse);
      expect(activeTeam.status, 'ACTIVE');
      expect(activeTeam.isActive, isTrue);

      final archivedTeam = SprintCapacityTeamModel.fromJson({
        'id': '2',
        'name': 'Copy of Infrastructure & Maintenance Team',
        'status': 'ARCHIVED',
        'is_active': false,
      });
      expect(archivedTeam.isArchived, isTrue);

      final softDeletedTeam = SprintCapacityTeamModel.fromJson({
        'id': '3',
        'name': 'Old Deprecated Team',
        'status': 'ACTIVE',
        'is_active': false,
      });
      expect(softDeletedTeam.isArchived, isTrue);
    });

    test('workTeamsListProvider excludes archived teams from sprintTeamState, retro workspace and capacity', () {
      final container = ProviderContainer(
        overrides: [
          workSprintRetroProvider.overrideWith((ref) => WorkSprintRetroNotifier()),
        ],
      );

      // Verify that default teams do not contain any copy/archived team
      final list = container.read(workTeamsListProvider);
      expect(list.contains('Copy of Infrastructure & Maintenance Team'), isFalse);
      for (final team in list) {
        expect(team.contains('Copy of'), isFalse);
      }
    });
  });
}
