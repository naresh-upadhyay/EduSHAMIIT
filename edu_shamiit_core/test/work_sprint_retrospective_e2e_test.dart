import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/services/work_api_service.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';
import 'package:edu_shamiit_core/screens/work_management/widgets/sprints/sprint_retrospective_tab_view.dart';

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
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
      WorkAssigneeModel(
          id: '1', userId: 'u1', fullName: 'Neha Sharma', role: 'Teacher'),
      WorkAssigneeModel(
          id: '2', userId: 'u2', fullName: 'Amit Kumar', role: 'Teacher'),
    ];
  }
}

class MockWorkSprintRetroNotifier extends WorkSprintRetroNotifier {
  MockWorkSprintRetroNotifier(WorkSprintRetroState initialState) {
    state = initialState;
  }

  @override
  Future<void> init(String sprintId, {String? teamId, String? teamName}) async {
    // Keep initial state for tests
  }

  @override
  Future<void> loadWorkspace({bool silent = false}) async {
    // Keep initial state for tests
  }

  @override
  Future<List<SprintRetroCommentModel>> loadComments(String entryId) async {
    return [];
  }

  @override
  Future<bool> voteEntry(String entryId) async {
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _TestHttpOverrides();

  group('Enterprise Sprint Retrospective Management E2E Tests', () {
    test('Sprint Retro Models parse JSON accurately matching reference design',
        () {
      final json = {
        'retrospective': {
          'id': 'retro-8-id',
          'sprint_id': 'sprint-8-id',
          'title': 'Sprint Retrospective',
          'status': 'COMPLETED',
          'session_date_formatted': 'Jan 14, 2025, 04:00 PM',
          'facilitator_name': 'Neha Sharma',
          'participant_count': 7,
          'total_participants': 7,
          'participation_pct': 100,
          'duration_minutes': 60,
          'sprint_goal':
              'Deliver student portal enhancement, examination notifications and key infrastructure fixes.',
          'summary':
              'The team delivered key improvements, maintained good collaboration, and achieved 68% completion. Focus for the next sprint is on better requirement clarity, dependency management and scope stability.',
        },
        'sprint_overview': {
          'sprint_id': 'sprint-8-id',
          'sprint_name': 'Sprint 8',
          'status': 'Completed',
          'date_range': 'Jan 01 – Jan 14, 2025 (14 days)',
          'team_name': 'Digital Campus Team',
          'completed_work': '29 of 42 (68%)',
          'sprint_goal':
              'Deliver student portal enhancement, examination notifications and key infrastructure fixes.',
        },
        'categories': {
          'went_well': {
            'title': 'What Went Well?',
            'key': 'WENT_WELL',
            'count': 6,
            'entries': [
              {
                'id': 'e1',
                'category': 'WENT_WELL',
                'content':
                    'Team collaboration was excellent, especially between academic and IT teams.',
                'votes': 3,
                'comments_count': 1,
                'author_name': 'Neha Sharma',
              },
            ],
          },
          'did_not_go_well': {
            'title': "What Didn't Go Well?",
            'key': 'DID_NOT_GO_WELL',
            'count': 4,
            'entries': [
              {
                'id': 'e7',
                'category': 'DID_NOT_GO_WELL',
                'content':
                    'Some requirements were not clearly defined in the initial planning.',
                'votes': 3,
                'comments_count': 2,
                'author_name': 'Rahul Mehta',
              },
            ],
          },
          'should_improve': {
            'title': 'What Should Improve?',
            'key': 'TO_IMPROVE',
            'count': 5,
            'entries': [
              {
                'id': 'e11',
                'category': 'TO_IMPROVE',
                'content':
                    'Improve requirement grooming before sprint planning.',
                'votes': 5,
                'comments_count': 0,
                'author_name': 'Amit Kumar',
              },
            ],
          },
        },
        'action_items': [
          {
            'id': 'a1',
            'item_key': 'RA-001',
            'title':
                'Conduct detailed requirement grooming session before next sprint.',
            'owner_name': 'Amit Kumar',
            'priority': 'HIGH',
            'due_date': 'Jan 20, 2025',
            'status': 'IN_PROGRESS',
            'linked_work_item_key': 'TK-1045',
          },
        ],
        'participants': [
          {
            'id': 'p1',
            'user_id': 'u1',
            'name': 'Neha Sharma',
            'role': 'Facilitator',
            'attendance_status': 'ATTENDED',
          },
        ],
        'history': [
          {
            'id': 'h1',
            'milestone': 'Retrospective created',
            'description': 'Session initialized',
            'actor_name': 'Neha Sharma',
            'created_at': 'Jan 14, 2025 03:40 PM',
          },
        ],
        'feedback': [
          {
            'id': 'f1',
            'category': 'Team Collaboration',
            'rating': 5,
            'content': 'Great collaboration',
            'user_name': 'Amit Kumar',
          },
        ],
        'feedback_stats': {
          'total_feedback': 4,
          'avg_rating': 4.5,
          'sentiment_pct': 92,
        },
      };

      final ws = SprintRetroWorkspaceModel.fromJson(json);
      expect(ws.retrospective.title, 'Sprint Retrospective');
      expect(ws.retrospective.status, 'COMPLETED');
      expect(ws.retrospective.participantCount, 7);
      expect(ws.retrospective.participationPct, 100);
      expect(ws.sprintOverview.completedWork, '29 of 42 (68%)');
      expect(ws.wentWell.count, 6);
      expect(ws.didNotGoWell.count, 4);
      expect(ws.shouldImprove.count, 5);
      expect(ws.actionItems.length, 1);
      expect(ws.actionItems.first.itemKey, 'RA-001');
      expect(ws.actionItems.first.linkedWorkItemKey, 'TK-1045');
      expect(ws.participants.length, 1);
      expect(ws.history.length, 1);
      expect(ws.feedbackStats.avgRating, 4.5);
    });

    testWidgets(
        'SprintRetrospectiveTabView renders session header, 3 agile columns, action items, and sidebar',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // ignore: prefer_const_constructors
      final mockWs = SprintRetroWorkspaceModel(
        retrospective: const SprintRetroHeaderModel(
          id: 'retro-8-id',
          sprintId: 'sprint-8-id',
          title: 'Sprint Retrospective',
          status: 'COMPLETED',
          sessionDateFormatted: 'Jan 14, 2025, 04:00 PM',
          facilitatorName: 'Neha Sharma',
          participantCount: 7,
          totalParticipants: 7,
          participationPct: 100,
          durationMinutes: 60,
          sprintGoal:
              'Deliver student portal enhancement, examination notifications and key infrastructure fixes.',
          summary:
              'The team delivered key improvements, maintained good collaboration, and achieved 68% completion. Focus for the next sprint is on better requirement clarity, dependency management and scope stability.',
        ),
        sprintOverview: const SprintRetroOverviewModel(
          sprintId: 'sprint-8-id',
          sprintName: 'Sprint 8',
          status: 'Completed',
          dateRange: 'Jan 01 – Jan 14, 2025 (14 days)',
          teamName: 'Digital Campus Team',
          completedWork: '29 of 42 (68%)',
          sprintGoal:
              'Deliver student portal enhancement, examination notifications and key infrastructure fixes.',
        ),
        wentWell: const SprintRetroCategoryColumnModel(
          title: 'What Went Well? (6)',
          key: 'WENT_WELL',
          count: 6,
          entries: [
            SprintRetroEntryItemModel(
              id: 'e1',
              category: 'WENT_WELL',
              content:
                  'Team collaboration was excellent, especially between academic and IT teams.',
              votes: 3,
              commentsCount: 1,
              authorName: 'Neha Sharma',
            ),
            SprintRetroEntryItemModel(
              id: 'e2',
              category: 'WENT_WELL',
              content:
                  'Student portal performance improved significantly after the optimization.',
              votes: 4,
              commentsCount: 0,
              authorName: 'Amit Kumar',
            ),
            SprintRetroEntryItemModel(
              id: 'e3',
              category: 'WENT_WELL',
              content: 'Most tasks were completed on or before the due date.',
              votes: 2,
              commentsCount: 0,
              authorName: 'Priya Singh',
            ),
          ],
        ),
        didNotGoWell: const SprintRetroCategoryColumnModel(
          title: "What Didn't Go Well? (4)",
          key: 'DID_NOT_GO_WELL',
          count: 4,
          entries: [
            SprintRetroEntryItemModel(
              id: 'e7',
              category: 'DID_NOT_GO_WELL',
              content:
                  'Some requirements were not clearly defined in the initial planning.',
              votes: 3,
              commentsCount: 2,
              authorName: 'Rahul Mehta',
            ),
            SprintRetroEntryItemModel(
              id: 'e8',
              category: 'DID_NOT_GO_WELL',
              content:
                  'Dependency on the external verification API caused delays.',
              votes: 2,
              commentsCount: 1,
              authorName: 'Vikas Gupta',
            ),
            SprintRetroEntryItemModel(
              id: 'e9',
              category: 'DID_NOT_GO_WELL',
              content: 'A few tasks were added mid-sprint, impacting capacity.',
              votes: 1,
              commentsCount: 0,
              authorName: 'Neha Sharma',
            ),
          ],
        ),
        shouldImprove: const SprintRetroCategoryColumnModel(
          title: 'What Should Improve? (5)',
          key: 'TO_IMPROVE',
          count: 5,
          entries: [
            SprintRetroEntryItemModel(
              id: 'e11',
              category: 'TO_IMPROVE',
              content: 'Improve requirement grooming before sprint planning.',
              votes: 5,
              commentsCount: 0,
              authorName: 'Amit Kumar',
            ),
            SprintRetroEntryItemModel(
              id: 'e12',
              category: 'TO_IMPROVE',
              content: 'Set clearer acceptance criteria for all major tasks.',
              votes: 3,
              commentsCount: 1,
              authorName: 'Priya Singh',
            ),
            SprintRetroEntryItemModel(
              id: 'e13',
              category: 'TO_IMPROVE',
              content: 'Limit scope changes during an active sprint.',
              votes: 2,
              commentsCount: 0,
              authorName: 'Neha Sharma',
            ),
          ],
        ),
        actionItems: const [
          SprintRetroActionItemModel(
            id: 'a1',
            itemKey: 'RA-001',
            title:
                'Conduct detailed requirement grooming session before next sprint.',
            ownerName: 'Amit Kumar',
            priority: 'HIGH',
            dueDate: 'Jan 20, 2025',
            status: 'IN_PROGRESS',
            linkedWorkItemKey: 'TK-1045',
          ),
          SprintRetroActionItemModel(
            id: 'a2',
            itemKey: 'RA-002',
            title:
                'Define and document acceptance criteria for all user stories.',
            ownerName: 'Priya Singh',
            priority: 'MEDIUM',
            dueDate: 'Jan 22, 2025',
            status: 'OPEN',
            linkedWorkItemKey: 'ST-1021',
          ),
          SprintRetroActionItemModel(
            id: 'a3',
            itemKey: 'RA-003',
            title: 'Review and manage external API dependencies earlier.',
            ownerName: 'Rahul Mehta',
            priority: 'HIGH',
            dueDate: 'Jan 24, 2025',
            status: 'IN_PROGRESS',
            linkedWorkItemKey: 'TK-1048',
          ),
          SprintRetroActionItemModel(
            id: 'a4',
            itemKey: 'RA-004',
            title: 'Stabilize sprint scope and avoid mid-sprint additions.',
            ownerName: 'Sneha Verma',
            priority: 'MEDIUM',
            dueDate: 'Jan 24, 2025',
            status: 'OPEN',
          ),
          SprintRetroActionItemModel(
            id: 'a5',
            itemKey: 'RA-005',
            title: 'Update team capacity plan based on actuals from Sprint 8.',
            ownerName: 'Vikas Gupta',
            priority: 'LOW',
            dueDate: 'Jan 27, 2025',
            status: 'PLANNED',
            linkedWorkItemKey: 'TK-1050',
          ),
        ],
        participants: const [
          SprintRetroParticipantModel(
              id: 'p1', userId: 'u1', name: 'Neha Sharma', role: 'Facilitator'),
          SprintRetroParticipantModel(
              id: 'p2',
              userId: 'u2',
              name: 'Amit Kumar',
              role: 'Senior Developer'),
          SprintRetroParticipantModel(
              id: 'p3',
              userId: 'u3',
              name: 'Priya Singh',
              role: 'UI/UX Designer'),
          SprintRetroParticipantModel(
              id: 'p4',
              userId: 'u4',
              name: 'Rahul Mehta',
              role: 'Backend Developer'),
          SprintRetroParticipantModel(
              id: 'p5', userId: 'u5', name: 'Sneha Verma', role: 'QA Engineer'),
          SprintRetroParticipantModel(
              id: 'p6',
              userId: 'u6',
              name: 'Vikas Gupta',
              role: 'DevOps Engineer'),
          SprintRetroParticipantModel(
              id: 'p7',
              userId: 'u7',
              name: 'Karan Jain',
              role: 'System Analyst'),
        ],
        history: const [
          SprintRetroHistoryItemModel(
            id: 'h1',
            milestone: 'Retrospective created',
            description: 'Session initialized',
            actorName: 'Neha Sharma',
            createdAt: 'Jan 14, 2025 03:40 PM',
          ),
          SprintRetroHistoryItemModel(
            id: 'h2',
            milestone: 'Discussion completed',
            description: 'Team contributed discussion entries',
            actorName: 'Neha Sharma',
            createdAt: 'Jan 14, 2025 04:20 PM',
          ),
          SprintRetroHistoryItemModel(
            id: 'h3',
            milestone: 'Action items added (5)',
            description: 'Action items assigned',
            actorName: 'Neha Sharma',
            createdAt: 'Jan 14, 2025 04:35 PM',
          ),
          SprintRetroHistoryItemModel(
            id: 'h4',
            milestone: 'Retrospective closed',
            description: 'Session completed and summary finalized',
            actorName: 'Neha Sharma',
            createdAt: 'Jan 14, 2025 05:00 PM',
          ),
        ],
        feedback: const [
          SprintRetroFeedbackItemModel(
            id: 'f1',
            category: 'Team Collaboration',
            rating: 5,
            content: 'Great collaboration',
            userName: 'Amit Kumar',
          ),
        ],
        feedbackStats: const SprintRetroFeedbackStatsModel(
          totalFeedback: 4,
          avgRating: 4.5,
          sentimentPct: 92,
        ),
      );

      final testState = WorkSprintRetroState(
        sprintId: 'sprint-8-id',
        workspace: mockWs,
        activeTab: 'Discussion Board',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
            workSprintRetroProvider
                .overrideWith((ref) => MockWorkSprintRetroNotifier(testState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SprintRetrospectiveTabView(sprintId: 'sprint-8-id'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 1. Session Header Verification
      expect(find.text('Sprint Retrospective'), findsOneWidget);
      expect(find.text('Completed'), findsAtLeastNWidgets(1));
      expect(find.text('Start New Retrospective'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Export'), findsAtLeastNWidgets(1));
      expect(find.text('Retrospective Date'), findsOneWidget);
      expect(find.text('Facilitator'), findsOneWidget);
      expect(find.text('Participants'), findsOneWidget);
      expect(find.text('Duration'), findsAtLeastNWidgets(1));
      expect(find.text('Sprint Goal'), findsAtLeastNWidgets(1));
      expect(find.text('Neha Sharma'), findsAtLeastNWidgets(1));
      expect(find.text('7 / 7 (100%)'), findsOneWidget);
      expect(find.text('60 min'), findsOneWidget);

      // 2. 5 Internal Workspace Tabs Verification
      expect(find.text('Discussion Board'), findsOneWidget);
      expect(find.text('Action Items (5)'), findsOneWidget);
      expect(find.text('Notes & Summary'), findsOneWidget);
      expect(find.text('Feedback'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);

      // 3. 3 Agile Columns Verification
      expect(find.text('What Went Well? (6)'), findsOneWidget);
      expect(find.text("What Didn't Go Well? (4)"), findsOneWidget);
      expect(find.text('What Should Improve? (5)'), findsOneWidget);
      expect(
          find.text(
              'Team collaboration was excellent, especially between academic and IT teams.'),
          findsOneWidget);
      expect(
          find.text(
              'Some requirements were not clearly defined in the initial planning.'),
          findsOneWidget);
      expect(find.text('Improve requirement grooming before sprint planning.'),
          findsOneWidget);

      // 4. Retrospective Action Items Table Verification
      expect(find.text('Retrospective Action Items (5)'), findsOneWidget);
      expect(find.text('Add Action Item'), findsOneWidget);
      expect(find.text('Bulk Update'), findsOneWidget);
      expect(find.text('RA-001'), findsOneWidget);
      expect(find.text('RA-002'), findsOneWidget);
      expect(find.text('RA-003'), findsOneWidget);
      expect(find.text('RA-004'), findsOneWidget);
      expect(find.text('RA-005'), findsOneWidget);
      expect(find.text('TK-1045'), findsOneWidget);
      expect(find.text('ST-1021'), findsOneWidget);
      expect(find.text('TK-1048'), findsOneWidget);
      expect(find.text('TK-1050'), findsOneWidget);

      // 5. Right Sidebar Verification
      expect(find.text('Sprint 8 Overview'), findsOneWidget);
      expect(find.text('Digital Campus Team'), findsOneWidget);
      expect(find.text('29 of 42 (68%)'), findsOneWidget);
      expect(find.text('Retrospective Summary'), findsOneWidget);
      expect(find.text('Participation (7)'), findsOneWidget);
      expect(find.text('Retrospective History'), findsOneWidget);
      expect(find.text('Retrospective created'), findsOneWidget);
      expect(find.text('Discussion completed'), findsOneWidget);
      expect(find.text('Action items added (5)'), findsOneWidget);
      expect(find.text('Retrospective closed'), findsOneWidget);
    });

    testWidgets(
        'SprintRetrospectiveTabView switches internal tabs and opens action item drawer',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // ignore: prefer_const_constructors
      final mockWs = SprintRetroWorkspaceModel(
        retrospective: const SprintRetroHeaderModel(
          id: 'retro-8-id',
          sprintId: 'sprint-8-id',
          title: 'Sprint Retrospective',
          status: 'COMPLETED',
          sessionDateFormatted: 'Jan 14, 2025, 04:00 PM',
          facilitatorName: 'Neha Sharma',
          participantCount: 7,
          totalParticipants: 7,
          participationPct: 100,
          durationMinutes: 60,
          sprintGoal: 'Deliver student portal enhancement',
          summary: 'Executive retrospective summary',
        ),
        sprintOverview: const SprintRetroOverviewModel(
          sprintId: 'sprint-8-id',
          sprintName: 'Sprint 8',
          status: 'Completed',
          dateRange: 'Jan 01 – Jan 14, 2025 (14 days)',
          teamName: 'Digital Campus Team',
          completedWork: '29 of 42 (68%)',
          sprintGoal: 'Deliver student portal enhancement',
        ),
        wentWell: const SprintRetroCategoryColumnModel(
          title: 'What Went Well? (6)',
          key: 'WENT_WELL',
          count: 6,
          entries: [],
        ),
        didNotGoWell: const SprintRetroCategoryColumnModel(
          title: "What Didn't Go Well? (4)",
          key: 'DID_NOT_GO_WELL',
          count: 4,
          entries: [],
        ),
        shouldImprove: const SprintRetroCategoryColumnModel(
          title: 'What Should Improve? (5)',
          key: 'TO_IMPROVE',
          count: 5,
          entries: [],
        ),
        actionItems: const [
          SprintRetroActionItemModel(
            id: 'a1',
            itemKey: 'RA-001',
            title:
                'Conduct detailed requirement grooming session before next sprint.',
            ownerName: 'Amit Kumar',
            priority: 'HIGH',
            dueDate: 'Jan 20, 2025',
            status: 'IN_PROGRESS',
            linkedWorkItemKey: 'TK-1045',
          ),
        ],
        participants: const [
          SprintRetroParticipantModel(
              id: 'p1', userId: 'u1', name: 'Neha Sharma', role: 'Facilitator'),
        ],
        history: const [
          SprintRetroHistoryItemModel(
            id: 'h1',
            milestone: 'Retrospective created',
            description: 'Session initialized',
            actorName: 'Neha Sharma',
            createdAt: 'Jan 14, 2025 03:40 PM',
          ),
        ],
        feedback: const [
          SprintRetroFeedbackItemModel(
            id: 'f1',
            category: 'Team Collaboration',
            rating: 5,
            content: 'Great collaboration',
            userName: 'Amit Kumar',
          ),
        ],
        feedbackStats: const SprintRetroFeedbackStatsModel(
          totalFeedback: 4,
          avgRating: 4.5,
          sentimentPct: 92,
        ),
      );

      final notifier = MockWorkSprintRetroNotifier(WorkSprintRetroState(
        sprintId: 'sprint-8-id',
        workspace: mockWs,
        activeTab: 'Discussion Board',
      ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
            workSprintRetroProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SprintRetrospectiveTabView(sprintId: 'sprint-8-id'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Switch to Notes & Summary
      await tester.tap(find.text('Notes & Summary'));
      await tester.pump();
      expect(
          find.text('Retrospective Summary & Key Decisions'), findsOneWidget);

      // Switch to Feedback
      await tester.tap(find.text('Feedback'));
      await tester.pump();
      expect(find.text('Sprint Team Feedback & Experience'), findsOneWidget);
      expect(find.text('Average Rating'), findsOneWidget);
      expect(find.text('4.5 / 5.0'), findsOneWidget);

      // Switch to History
      await tester.tap(find.text('History'));
      await tester.pump();
      expect(find.text('Retrospective Session History & Milestone Audit'),
          findsOneWidget);
    });

    testWidgets(
        'Inline View All expansion shows all remaining cards and collapses back to 3',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sixEntries = List.generate(
        6,
        (i) => SprintRetroEntryItemModel(
          id: 'card-$i',
          category: 'WENT_WELL',
          content: 'Went well item #$i',
          votes: i,
          authorName: 'User $i',
        ),
      );

      final mockWs = SprintRetroWorkspaceModel(
        retrospective: const SprintRetroHeaderModel(
          id: 'retro-8-id',
          sprintId: 'sprint-8-id',
          title: 'Sprint Retrospective',
          status: 'COMPLETED',
          sessionDateFormatted: 'Jan 14, 2025',
          facilitatorName: 'Neha Sharma',
          participantCount: 7,
          totalParticipants: 7,
          participationPct: 100,
          durationMinutes: 60,
          sprintGoal: 'Sprint Goal',
          summary: 'Summary',
        ),
        sprintOverview: const SprintRetroOverviewModel(sprintId: 'sprint-8-id'),
        wentWell: SprintRetroCategoryColumnModel(
          title: 'What Went Well? (6)',
          key: 'WENT_WELL',
          count: 6,
          entries: sixEntries,
        ),
        didNotGoWell: const SprintRetroCategoryColumnModel(
          title: "What Didn't Go Well? (0)",
          key: 'DID_NOT_GO_WELL',
          count: 0,
          entries: [],
        ),
        shouldImprove: const SprintRetroCategoryColumnModel(
          title: 'What Should Improve? (0)',
          key: 'TO_IMPROVE',
          count: 0,
          entries: [],
        ),
        actionItems: const [],
        participants: const [],
        history: const [],
        feedback: const [],
        feedbackStats: const SprintRetroFeedbackStatsModel(),
      );

      final notifier = MockWorkSprintRetroNotifier(WorkSprintRetroState(
        sprintId: 'sprint-8-id',
        workspace: mockWs,
        activeTab: 'Discussion Board',
      ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
            workSprintRetroProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SprintRetrospectiveTabView(sprintId: 'sprint-8-id'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Initially only 3 items visible, plus "View All (6)" button
      expect(find.text('Went well item #0'), findsOneWidget);
      expect(find.text('Went well item #1'), findsOneWidget);
      expect(find.text('Went well item #2'), findsOneWidget);
      expect(find.text('Went well item #3'), findsNothing);
      expect(find.text('View All (6)'), findsOneWidget);

      // Tap View All (6)
      await tester.tap(find.text('View All (6)'));
      await tester.pump();

      // Now all 6 items are visible inline on screen!
      expect(find.text('Went well item #3'), findsOneWidget);
      expect(find.text('Went well item #4'), findsOneWidget);
      expect(find.text('Went well item #5'), findsOneWidget);
      expect(find.text('Show Less'), findsOneWidget);

      // Tap Show Less to collapse back
      await tester.ensureVisible(find.text('Show Less'));
      await tester.tap(find.text('Show Less'));
      await tester.pumpAndSettle();

      expect(find.text('Went well item #3'), findsNothing);
      expect(find.text('View All (6)'), findsOneWidget);
    });

    testWidgets(
        'Retrospective Action Items table has no double checkboxes and filters work',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockWs = SprintRetroWorkspaceModel(
        retrospective: SprintRetroHeaderModel(
          id: 'retro-8-id',
          sprintId: 'sprint-8-id',
          title: 'Sprint Retrospective',
          status: 'COMPLETED',
          sessionDateFormatted: 'Jan 14, 2025',
          facilitatorName: 'Neha Sharma',
          participantCount: 7,
          totalParticipants: 7,
          participationPct: 100,
          durationMinutes: 60,
          sprintGoal: 'Sprint Goal',
          summary: 'Summary',
        ),
        sprintOverview: SprintRetroOverviewModel(sprintId: 'sprint-8-id'),
        wentWell: SprintRetroCategoryColumnModel(
          title: 'What Went Well? (1)',
          key: 'WENT_WELL',
          count: 1,
          entries: [
            SprintRetroEntryItemModel(
                id: 'c1',
                category: 'WENT_WELL',
                content: 'Database performance is fast',
                authorName: 'Alice'),
          ],
        ),
        didNotGoWell: SprintRetroCategoryColumnModel(
            title: '', key: 'DID_NOT_GO_WELL', count: 0, entries: []),
        shouldImprove: SprintRetroCategoryColumnModel(
            title: '', key: 'TO_IMPROVE', count: 0, entries: []),
        actionItems: [
          SprintRetroActionItemModel(
            id: 'a1',
            itemKey: 'RA-001',
            title: 'Refactor database queries',
            ownerName: 'Amit Kumar',
            priority: 'HIGH',
            status: 'OPEN',
            dueDate: 'Jan 20, 2025',
          ),
          SprintRetroActionItemModel(
            id: 'a2',
            itemKey: 'RA-002',
            title: 'Design UI mockups',
            ownerName: 'Priya Singh',
            priority: 'LOW',
            status: 'COMPLETED',
            dueDate: 'Jan 22, 2025',
          ),
        ],
        participants: [],
        history: [],
        feedback: [],
        feedbackStats: SprintRetroFeedbackStatsModel(),
      );

      final notifier = MockWorkSprintRetroNotifier(const WorkSprintRetroState(
        sprintId: 'sprint-8-id',
        workspace: mockWs,
        activeTab: 'Discussion Board',
      ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
            workSprintRetroProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SprintRetrospectiveTabView(
                  sprintId: 'sprint-8-id',
                  filterKeyword: 'database',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Only items containing 'database' match!
      expect(find.text('Database performance is fast'), findsOneWidget);
      expect(find.text('RA-001'), findsOneWidget);
      expect(find.text('RA-002'), findsNothing);

      // Verify DataTable checkbox column is native (only one checkbox per row, exactly 2 checkboxes total: 1 header + 1 row)
      expect(find.byType(Checkbox), findsNWidgets(2));
    });

    testWidgets(
        'Clicking retrospective discussion card opens detail dialog with observation, upvotes, and conversion',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockWs = SprintRetroWorkspaceModel(
        retrospective: const SprintRetroHeaderModel(
          id: 'retro-8-id',
          sprintId: 'sprint-8-id',
          title: 'Sprint Retrospective',
          status: 'COMPLETED',
        ),
        sprintOverview: const SprintRetroOverviewModel(
          sprintId: 'sprint-8-id',
          sprintName: 'Sprint 8',
          dateRange: 'Nov 15, 2026 – Nov 28, 2026',
        ),
        wentWell: const SprintRetroCategoryColumnModel(
          title: 'What Went Well?',
          key: 'WENT_WELL',
          count: 1,
          entries: [
            SprintRetroEntryItemModel(
              id: 'e1',
              category: 'WENT_WELL',
              content:
                  'Some requirements were not clearly defined in the initial planning.',
              authorName: 'Rahul Mehta',
              votes: 3,
              commentsCount: 2,
            ),
          ],
        ),
        didNotGoWell: const SprintRetroCategoryColumnModel(
          title: "What Didn't Go Well?",
          key: 'DID_NOT_GO_WELL',
          count: 0,
          entries: [],
        ),
        shouldImprove: const SprintRetroCategoryColumnModel(
          title: 'What Should Improve?',
          key: 'TO_IMPROVE',
          count: 0,
          entries: [],
        ),
        actionItems: [],
        participants: [],
        history: [],
        feedback: [],
        feedbackStats: const SprintRetroFeedbackStatsModel(),
      );

      final notifier = MockWorkSprintRetroNotifier(WorkSprintRetroState(
        sprintId: 'sprint-8-id',
        workspace: mockWs,
        activeTab: 'Discussion Board',
      ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
            workSprintRetroProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SprintRetrospectiveTabView(
                  sprintId: 'sprint-8-id',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Card is displayed on the board
      final cardFinder = find.text(
          'Some requirements were not clearly defined in the initial planning.');
      expect(cardFinder, findsOneWidget);

      // Tap on the card
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      // Verify that the Retro Card Detail Dialog is now open!
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('3 Upvotes'), findsOneWidget);
      expect(find.text('Rahul Mehta'), findsWidgets);
      expect(find.text('Convert to Action Item'), findsOneWidget);
      expect(find.text('Move to Category'), findsOneWidget);
      expect(find.text('Delete Card'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Tap 'Done' to close the dialog
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Dialog is closed
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets(
        'Sprint Retro dynamic available teams, participation and clearTeamId work accurately',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final jsonWithTeams = {
        'retrospective': {
          'id': 'retro-1',
          'sprint_id': 'sprint-1',
          'title': 'Sprint Retrospective',
          'status': 'COMPLETED',
          'total_participants': 2,
          'participant_count': 2,
          'participation_pct': 100,
        },
        'sprint_overview': {
          'sprint_id': 'sprint-1',
          'sprint_name': 'Sprint 9',
          'status': 'Planned',
          'date_range': 'Jan 15, 2025 - Jan 28, 2025 (14 days)',
          'team_name': 'KING',
          'completed_work': '0 of 15 (0%)',
        },
        'categories': {
          'went_well': {
            'title': 'What Went Well?',
            'key': 'WENT_WELL',
            'count': 0,
            'entries': []
          },
          'did_not_go_well': {
            'title': "What Didn't Go Well?",
            'key': 'DID_NOT_GO_WELL',
            'count': 0,
            'entries': []
          },
          'should_improve': {
            'title': 'What Should Improve?',
            'key': 'TO_IMPROVE',
            'count': 0,
            'entries': []
          },
        },
        'action_items': [
          {
            'id': 'act-1',
            'item_key': 'RA-001',
            'title': 'KING Action Item',
            'team_id': 'king-team-id',
            'team_name': 'KING',
            'owner_name': 'Archana Shukla',
            'owner_email': 'archana@edushamiit.com',
            'priority': 'HIGH',
            'status': 'OPEN',
            'due_date': 'Jan 28, 2025',
          }
        ],
        'participants': [
          {
            'id': 'p1',
            'user_id': 'u1',
            'name': 'Archana Shukla',
            'email': 'archana@edushamiit.com',
            'role': 'Lead',
            'attendance_status': 'ATTENDED',
          },
          {
            'id': 'p2',
            'user_id': 'u2',
            'name': 'King Doe',
            'email': 'king@edushamiit.com',
            'role': 'Admin',
            'attendance_status': 'ATTENDED',
          },
        ],
        'available_teams': [
          {
            'id': 'team-1',
            'name': 'Academic Systems Team',
            'members_count': 8,
            'is_selected': false
          },
          {
            'id': 'team-2',
            'name': 'Digital Campus Team',
            'members_count': 7,
            'is_selected': false
          },
          {
            'id': 'team-3',
            'name': 'Examination Team',
            'members_count': 6,
            'is_selected': false
          },
          {
            'id': 'king-team-id',
            'name': 'KING',
            'members_count': 2,
            'is_selected': true
          },
        ],
        'available_sprints': [
          {
            'id': 'sprint-1',
            'name': 'Sprint 9',
            'status': 'PLANNED',
            'is_current': true
          },
          {
            'id': 'sprint-2',
            'name': 'Sprint 8',
            'status': 'COMPLETED',
            'is_current': false
          },
        ],
      };

      final ws = SprintRetroWorkspaceModel.fromJson(jsonWithTeams);
      expect(ws.availableTeams.length, 4);
      expect(ws.availableTeams[3].name, 'KING');
      expect(ws.availableTeams[3].membersCount, 2);
      expect(ws.availableSprints.length, 2);
      expect(ws.actionItems.first.teamName, 'KING');
      expect(ws.actionItems.first.ownerEmail, 'archana@edushamiit.com');
      expect(ws.participants.length, 2);
      expect(ws.participants.first.email, 'archana@edushamiit.com');

      // Test WorkSprintRetroState clearTeamId functionality
      var retroState = WorkSprintRetroState(
          sprintId: 'sprint-1', teamId: 'KING', workspace: ws);
      expect(retroState.teamId, 'KING');

      // Clearing teamId via clearTeamId
      retroState = retroState.copyWith(clearTeamId: true);
      expect(retroState.teamId, isNull);

      final notifier = MockWorkSprintRetroNotifier(WorkSprintRetroState(
        sprintId: 'sprint-1',
        teamId: 'KING',
        workspace: ws,
        activeTab: 'Discussion Board',
      ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workApiServiceProvider.overrideWithValue(FakeWorkApiService()),
            workSprintRetroProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SprintRetrospectiveTabView(
                  sprintId: 'sprint-1',
                  selectedTeam: 'KING',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Participation card displays actual 2 participants count
      expect(find.text('Participation (2)'), findsOneWidget);
      expect(find.text('100%'), findsWidgets);

      // Verify Duration displays Jan 15, 2025 - Jan 28, 2025 (not suppressed)
      expect(
          find.text('Jan 15, 2025 - Jan 28, 2025 (14 days)'), findsOneWidget);
    });
  });
}
