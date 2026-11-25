import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/services/work_api_service.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/sprints/sprint_team_tab_view.dart';

class TestHttpOverrides extends HttpOverrides {
}

class FakeWorkApiService extends WorkApiService {
  @override
  Future<List<WorkAssigneeModel>> getAssignableUsers({
    String? q,
    String? role,
    String? department,
    int limit = 100,
  }) async {
    return const [
      WorkAssigneeModel(id: '1', userId: 'u1', fullName: 'Neha Sharma', role: 'Teacher'),
      WorkAssigneeModel(id: '2', userId: 'u2', fullName: 'Amit Kumar', role: 'Teacher'),
    ];
  }
}

class MockWorkSprintTeamNotifier extends WorkSprintTeamNotifier {
  MockWorkSprintTeamNotifier(WorkSprintTeamState initialState) {
    state = initialState;
  }

  @override
  Future<void> init(String sprintId) async {
    // Keep initial state for test
  }

  @override
  Future<void> loadTeams({bool silent = false, bool forceRefresh = false}) async {
    // Keep initial state for test
  }

  @override
  Future<void> loadTeamDetail(String teamId, {bool silent = false, bool forceRefresh = true}) async {
    // Keep initial state for test
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = TestHttpOverrides();

  group('Enterprise Sprint Team Management E2E Tests', () {
    test('Team Models parse JSON accurately matching reference design', () {
      final json = {
        'total_teams': 6,
        'total_members': 42,
        'total_capacity_hours': 1680.0,
        'allocated_work_hours': 1521.0,
        'capacity_utilization_pct': 90.5,
        'active_teams': 6,
        'inactive_teams': 0,
      };

      final kpis = TeamKpisModel.fromJson(json);
      expect(kpis.totalTeams, 6);
      expect(kpis.totalMembers, 42);
      expect(kpis.totalCapacityHours, 1680.0);
      expect(kpis.allocatedWorkHours, 1521.0);
      expect(kpis.capacityUtilizationPct, 90.5);
      expect(kpis.activeTeams, 6);
      expect(kpis.inactiveTeams, 0);
    });

    test('TeamDetailModel parses complete overview, members, activities, and work items', () {
      final detailJson = {
        'id': 'team-dct-id',
        'name': 'Digital Campus Team',
        'team_key': 'DCT',
        'department': 'IT & Digitalization',
        'description': 'Student portal, academic systems and digital campus solutions.',
        'icon': 'layers',
        'color': '#2563EB',
        'is_active': true,
        'status': 'ACTIVE',
        'tags': ['Digital Campus', 'Student Portal', 'Academics', 'Integration'],
        'goal': 'Deliver student portal enhancement, examination notifications and key infrastructure fixes.',
        'created_at': '2024-12-10T09:00:00Z',
        'updated_at': '2025-01-06T10:24:00Z',
        'lead': {
          'id': 'u1',
          'name': 'Neha Sharma',
          'email': 'neha.sharma@edushamiit.com',
          'avatar_url': null,
        },
        'capacity': {
          'total_capacity_hours': 280.0,
          'planned_hours': 257.0,
          'remaining_hours': 23.0,
          'utilization_pct': 91.8,
        },
        'members': [
          {'id': 'm1', 'user_id': 'u1', 'name': 'Neha Sharma', 'role': 'Team Lead', 'capacity_hours': 40.0, 'is_lead': true},
          {'id': 'm2', 'user_id': 'u2', 'name': 'Amit Kumar', 'role': 'Senior Developer', 'capacity_hours': 40.0, 'is_lead': false},
          {'id': 'm3', 'user_id': 'u3', 'name': 'Priya Singh', 'role': 'UI/UX Designer', 'capacity_hours': 40.0, 'is_lead': false},
          {'id': 'm4', 'user_id': 'u4', 'name': 'Rahul Mehta', 'role': 'Backend Developer', 'capacity_hours': 40.0, 'is_lead': false},
          {'id': 'm5', 'user_id': 'u5', 'name': 'Sneha Verma', 'role': 'QA Engineer', 'capacity_hours': 40.0, 'is_lead': false},
          {'id': 'm6', 'user_id': 'u6', 'name': 'Vikas Gupta', 'role': 'DevOps Engineer', 'capacity_hours': 40.0, 'is_lead': false},
          {'id': 'm7', 'user_id': 'u7', 'name': 'Karan Jain', 'role': 'System Analyst', 'capacity_hours': 40.0, 'is_lead': false},
        ],
        'activities': [
          {'id': 'a1', 'activity_type': 'CAPACITY_UPDATED', 'description': 'Team capacity updated to 280 h by Dr. Rajesh Verma', 'actor_name': 'Dr. Rajesh Verma', 'created_at': '2025-01-06T10:24:00Z'},
          {'id': 'a2', 'activity_type': 'MEMBER_ADDED', 'description': 'Member Karan Jain added to the team', 'actor_name': 'Dr. Rajesh Verma', 'created_at': '2025-01-05T16:10:00Z'},
          {'id': 'a3', 'activity_type': 'GOAL_UPDATED', 'description': 'Team goal updated for Sprint 8', 'actor_name': 'Neha Sharma', 'created_at': '2025-01-03T11:32:00Z'},
        ],
        'work_items': [
          {'id': 'w1', 'item_key': 'WM-1050', 'title': 'Collect and verify student project submissions', 'type': 'TASK', 'priority': 'MEDIUM', 'status': 'ACTIVE', 'progress_percentage': 60, 'assignee_name': 'Amit Kumar'},
        ],
      };

      final teamDetail = TeamDetailModel.fromJson(detailJson);
      expect(teamDetail.name, 'Digital Campus Team');
      expect(teamDetail.teamKey, 'DCT');
      expect(teamDetail.department, 'IT & Digitalization');
      expect(teamDetail.lead.name, 'Neha Sharma');
      expect(teamDetail.capacity.totalCapacityHours, 280.0);
      expect(teamDetail.capacity.plannedHours, 257.0);
      expect(teamDetail.capacity.utilizationPct, 91.8);
      expect(teamDetail.members.length, 7);
      expect(teamDetail.activities.length, 3);
      expect(teamDetail.workItems.length, 1);
    });

    testWidgets('SprintTeamTabView renders 7 KPI cards, table directory, and selected team drawer', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dummyMembers = [
        const TeamMemberItemModel(id: 'm1', userId: 'u1', name: 'Neha Sharma', role: 'Team Lead', isLead: true),
        const TeamMemberItemModel(id: 'm2', userId: 'u2', name: 'Amit Kumar', role: 'Senior Developer'),
        const TeamMemberItemModel(id: 'm3', userId: 'u3', name: 'Priya Singh', role: 'UI/UX Designer'),
        const TeamMemberItemModel(id: 'm4', userId: 'u4', name: 'Rahul Mehta', role: 'Backend Developer'),
        const TeamMemberItemModel(id: 'm5', userId: 'u5', name: 'Sneha Verma', role: 'QA Engineer'),
        const TeamMemberItemModel(id: 'm6', userId: 'u6', name: 'Vikas Gupta', role: 'DevOps Engineer'),
        const TeamMemberItemModel(id: 'm7', userId: 'u7', name: 'Karan Jain', role: 'System Analyst'),
      ];

      final dummyDetail = TeamDetailModel(
        id: 'team-dct-id',
        name: 'Digital Campus Team',
        teamKey: 'DCT',
        department: 'IT & Digitalization',
        description: 'Student portal, academic systems and digital campus solutions.',
        icon: 'layers',
        color: '#2563EB',
        isActive: true,
        status: 'ACTIVE',
        tags: const ['Digital Campus', 'Student Portal', 'Academics', 'Integration'],
        goal: 'Deliver student portal enhancement, examination notifications and key infrastructure fixes.',
        createdAt: 'Dec 10, 2024',
        updatedAt: 'Jan 06, 2025',
        lead: const TeamLeadModel(id: 'u1', name: 'Neha Sharma'),
        capacity: const TeamDetailCapacityModel(
          sprintId: 'sprint-103-id',
          sprintName: 'Sprint 103',
          totalCapacityHours: 280.0,
          plannedHours: 257.0,
          remainingHours: 23.0,
          utilizationPct: 91.8,
        ),
        members: dummyMembers,
        activities: const [
          TeamActivityItemModel(
            id: 'a1',
            activityType: 'CAPACITY_UPDATED',
            description: 'Team capacity updated to 280 h by Dr. Rajesh Verma',
            actorName: 'Dr. Rajesh Verma',
            createdAt: 'Jan 06, 2025 10:24 AM',
          ),
          TeamActivityItemModel(
            id: 'a2',
            activityType: 'MEMBER_ADDED',
            description: 'Member Karan Jain added to the team',
            actorName: 'Dr. Rajesh Verma',
            createdAt: 'Jan 05, 2025 04:10 PM',
          ),
          TeamActivityItemModel(
            id: 'a3',
            activityType: 'GOAL_UPDATED',
            description: 'Team goal updated for Sprint 8',
            actorName: 'Neha Sharma',
            createdAt: 'Jan 03, 2025 11:32 AM',
          ),
        ],
        workItems: const [
          TeamWorkItemModel(
            id: 'w1',
            itemKey: 'WM-1050',
            title: 'Collect and verify student project submissions',
            type: 'TASK',
            priority: 'MEDIUM',
            status: 'ACTIVE',
            progressPercentage: 60,
            assigneeName: 'Amit Kumar',
          ),
        ],
      );

      final dummyTeams = [
        TeamDirectoryItemModel(
          id: 'team-dct-id',
          name: 'Digital Campus Team',
          teamKey: 'DCT',
          department: 'IT & Digitalization',
          description: 'Student portal, academic systems and digital campus solutions.',
          icon: 'layers',
          color: '#2563EB',
          status: 'ACTIVE',
          isActive: true,
          tags: const ['Digital Campus', 'Student Portal', 'Academics', 'Integration'],
          goal: 'Deliver student portal enhancement, examination notifications and key infrastructure fixes.',
          lead: const TeamLeadModel(id: 'u1', name: 'Neha Sharma'),
          memberCount: 7,
          members: dummyMembers,
          capacityHours: 280.0,
          plannedHours: 257.0,
          remainingHours: 23.0,
          utilizationPct: 91.8,
        ),
        TeamDirectoryItemModel(
          id: 'team-ast-id',
          name: 'Academic Systems Team',
          teamKey: 'AST',
          department: 'Academics',
          description: 'Academic planning, curriculum and evaluation engines.',
          icon: 'school',
          color: '#0284C7',
          status: 'ACTIVE',
          isActive: true,
          tags: const ['Curriculum', 'Syllabus'],
          goal: 'Implement curriculum planner',
          lead: const TeamLeadModel(id: 'u2', name: 'Amit Kumar'),
          memberCount: 8,
          members: dummyMembers,
          capacityHours: 320.0,
          plannedHours: 282.0,
          remainingHours: 38.0,
          utilizationPct: 88.1,
        ),
      ];

      final testState = WorkSprintTeamState(
        sprintId: 'sprint-8-id',
        kpis: const TeamKpisModel(
          totalTeams: 6,
          totalMembers: 42,
          totalCapacityHours: 1680.0,
          allocatedWorkHours: 1521.0,
          capacityUtilizationPct: 90.5,
          activeTeams: 6,
          inactiveTeams: 0,
        ),
        teams: dummyTeams,
        totalCount: 6,
        selectedTeamId: 'team-dct-id',
        selectedTeamDetail: dummyDetail,
        isDrawerOpen: true,
        activeDrawerTab: 'Overview',
      );

      String? navigatedTeam;
      String? navigatedSprintId;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
            workSprintTeamProvider.overrideWith((ref) => MockWorkSprintTeamNotifier(testState)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SprintTeamTabView(
                  sprintId: 'sprint-8-id',
                  onNavigateToCapacity: (team, sprintId) {
                    navigatedTeam = team;
                    navigatedSprintId = sprintId;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify KPI Cards
      expect(find.text('Total Teams'), findsOneWidget);
      expect(find.text('Total Members'), findsOneWidget);
      expect(find.text('Total Capacity'), findsOneWidget);
      expect(find.text('Allocated Work'), findsOneWidget);
      expect(find.text('Capacity Utilization'), findsOneWidget);
      expect(find.text('Active Teams'), findsOneWidget);
      expect(find.text('Inactive Teams'), findsOneWidget);
      expect(find.text('1,680 h'), findsOneWidget);
      expect(find.text('1,521 h'), findsOneWidget);
      expect(find.text('90.5%'), findsOneWidget);

      // Verify Left Directory Table
      expect(find.text('Teams (6)'), findsOneWidget);
      expect(find.text('Create Team'), findsOneWidget);
      expect(find.text('Import'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('Digital Campus Team'), findsAtLeastNWidgets(1));
      expect(find.text('Academic Systems Team'), findsOneWidget);
      expect(find.text('IT & Digitalization'), findsAtLeastNWidgets(1));

      // Verify Right Selected Team Drawer
      expect(find.text('Team Code'), findsOneWidget);
      expect(find.text('DCT'), findsOneWidget);
      expect(find.text('Team Capacity (Sprint 103)'), findsOneWidget);
      expect(find.text('View More'), findsOneWidget);
      expect(find.text('280 h'), findsAtLeastNWidgets(1));
      expect(find.text('Allocated Work: 257 h'), findsOneWidget);
      expect(find.text('Available Capacity: 23 h'), findsOneWidget);
      expect(find.text('Team Members (7)'), findsAtLeastNWidgets(1));
      expect(find.text('Digital Campus'), findsOneWidget);
      expect(find.text('Student Portal'), findsOneWidget);
      expect(find.text('Deliver student portal enhancement, examination notifications and key infrastructure fixes.'), findsOneWidget);
      expect(find.text('Team capacity updated to 280 h by Dr. Rajesh Verma'), findsOneWidget);

      // Verify View More interaction switches to Capacity screen with team & sprint
      await tester.tap(find.text('View More'));
      await tester.pump();
      expect(navigatedTeam, 'Digital Campus Team');
      expect(navigatedSprintId, 'sprint-103-id');

      // Verify Team Lead is clickable and opens Assign Team Lead dialog
      expect(find.text('Change'), findsOneWidget);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      expect(find.text('Assign Team Lead'), findsOneWidget);
      expect(find.text('Select a team member or staff to lead Digital Campus Team'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
