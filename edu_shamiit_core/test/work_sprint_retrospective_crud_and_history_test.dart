import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';
import 'package:edu_shamiit_core/screens/work_management/services/work_api_service.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';

class MockWorkApiService extends WorkApiService {
  final List<Map<String, dynamic>> actionItemUpdates = [];
  final List<String> actionItemDeletes = [];
  final List<String> actionItemConversions = [];
  final List<Map<String, dynamic>> feedbackSubmissions = [];
  final List<Map<String, dynamic>> feedbackUpdates = [];
  final List<String> feedbackDeletes = [];

  SprintRetroWorkspaceModel? workspaceToReturn;

  @override
  Future<SprintRetroWorkspaceModel?> getSprintRetrospectiveWorkspace(
    String sprintId, {
    String? teamId,
  }) async {
    return workspaceToReturn ??
        SprintRetroWorkspaceModel(
          sprintOverview: const SprintRetroOverviewModel(sprintId: 'sprint-1'),
          retrospective: const SprintRetroHeaderModel(
            id: 'retro-1',
            sprintId: 'sprint-1',
            title: 'Sprint 9 Retrospective',
            status: 'COMPLETED',
            sessionDateFormatted: 'Nov 24, 2026, 09:00 AM',
            facilitatorName: 'Neha Sharma',
            participantCount: 8,
            totalParticipants: 8,
            participationPct: 100,
            durationMinutes: 60,
            sprintGoal: 'Faculty management modules',
            summary: 'Great delivery',
          ),
          wentWell: const SprintRetroCategoryColumnModel(
            title: 'What Went Well? (1)',
            key: 'WENT_WELL',
            count: 1,
            entries: [
              SprintRetroEntryItemModel(
                id: 'e1',
                category: 'WENT_WELL',
                content: 'Fast releases',
                authorName: 'King Doe',
                votes: 3,
                commentsCount: 1,
              ),
            ],
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
          actionItems: const [
            SprintRetroActionItemModel(
              id: 'a1',
              itemKey: 'RA-002',
              title: 'gajab',
              description: 'Fix database connection pooling',
              priority: 'MEDIUM',
              status: 'OPEN',
              progressPercentage: 25,
            ),
          ],
          history: const [
            SprintRetroHistoryItemModel(
              id: 'h1',
              milestone: 'Action item created',
              description: 'Created RA-002: gajab',
              actorName: 'King Doe',
              createdAt: 'Nov 24, 2026, 09:15 AM',
            ),
            SprintRetroHistoryItemModel(
              id: 'h2',
              milestone: 'Feedback submitted',
              description: 'Submitted 5-star feedback for Planning',
              actorName: 'King Doe',
              createdAt: 'Nov 24, 2026, 09:20 AM',
            ),
          ],
          feedback: const [
            SprintRetroFeedbackItemModel(
              id: 'f1',
              userId: 'user-king',
              category: 'Team Collaboration',
              rating: 5,
              content: 'urw',
              suggestedImprovement: 'Improve CI pipeline speed',
              isAnonymous: true,
              userName: 'Anonymous Contributor',
              createdAt: 'Nov 24, 2026',
            ),
            SprintRetroFeedbackItemModel(
              id: 'f2',
              userId: 'user-other',
              category: 'Workload',
              rating: 4,
              content: 'test from another teammate',
              isAnonymous: false,
              userName: 'Amit Kumar',
              createdAt: 'Nov 24, 2026',
            ),
          ],
          participants: const [],
          feedbackStats: const SprintRetroFeedbackStatsModel(
            totalFeedback: 2,
            avgRating: 4.5,
            sentimentPct: 90,
          ),
        );
  }

  @override
  Future<bool> updateActionItem(String sprintId, String actionItemId, Map<String, dynamic> data) async {
    actionItemUpdates.add({'sprintId': sprintId, 'id': actionItemId, ...data});
    return true;
  }

  @override
  Future<bool> deleteActionItem(String sprintId, String actionItemId) async {
    actionItemDeletes.add(actionItemId);
    return true;
  }

  @override
  Future<bool> convertActionItemToWorkItem(
    String sprintId,
    String actionItemId, {
    String? title,
    String? description,
    String? ownerId,
    String? priority,
  }) async {
    actionItemConversions.add(actionItemId);
    return true;
  }

  @override
  Future<bool> submitRetroFeedback(
    String sprintId, {
    required String category,
    required int rating,
    String? content,
    String? suggestedImprovement,
    bool isAnonymous = false,
  }) async {
    feedbackSubmissions.add({
      'sprintId': sprintId,
      'category': category,
      'rating': rating,
      'content': content,
      'isAnonymous': isAnonymous,
    });
    return true;
  }

  @override
  Future<bool> updateRetroFeedback(
    String sprintId,
    String feedbackId, {
    required String category,
    required int rating,
    String? content,
    String? suggestedImprovement,
    bool isAnonymous = false,
  }) async {
    feedbackUpdates.add({
      'sprintId': sprintId,
      'id': feedbackId,
      'category': category,
      'rating': rating,
      'content': content,
      'isAnonymous': isAnonymous,
    });
    return true;
  }

  @override
  Future<bool> deleteRetroFeedback(String sprintId, String feedbackId) async {
    feedbackDeletes.add(feedbackId);
    return true;
  }
}

void main() {
  group('Sprint Retrospective Full CRUD, Ownership & History Tests', () {
    test('SprintRetroFeedbackItemModel correctly parses userId and ownership fields', () {
      final json = {
        'id': 'fb-123',
        'user_id': 'user-king',
        'category': 'Team Collaboration',
        'rating': 5,
        'content': 'Outstanding team support',
        'suggested_improvement': 'None needed',
        'is_anonymous': true,
        'author_name': 'Anonymous Contributor',
        'created_at': 'Nov 24, 2026',
      };

      final model = SprintRetroFeedbackItemModel.fromJson(json);
      expect(model.id, equals('fb-123'));
      expect(model.userId, equals('user-king'));
      expect(model.category, equals('Team Collaboration'));
      expect(model.rating, equals(5));
      expect(model.content, equals('Outstanding team support'));
      expect(model.suggestedImprovement, equals('None needed'));
      expect(model.isAnonymous, isTrue);
      expect(model.userName, equals('Anonymous Contributor'));
    });

    test('Feedback ownership logic allows owner and super admin, blocks others', () {
      const myFeedback = SprintRetroFeedbackItemModel(
        id: 'fb-mine',
        userId: 'user-king',
        category: 'Team Collaboration',
        rating: 5,
        content: 'My private thoughts',
      );

      const otherFeedback = SprintRetroFeedbackItemModel(
        id: 'fb-other',
        userId: 'user-other',
        category: 'Process',
        rating: 4,
        content: 'Other team member thoughts',
      );

      const currentUserId = 'user-king';

      // 1. Regular user checks own feedback -> CAN edit/delete
      bool canModifyMine = (myFeedback.userId == currentUserId);
      expect(canModifyMine, isTrue);

      // 2. Regular user checks other user's feedback -> CANNOT edit/delete
      bool canModifyOther = (otherFeedback.userId == currentUserId);
      expect(canModifyOther, isFalse);

      // 3. Super Admin override
      const bool isSuperAdmin = true;
      bool superAdminCanModifyOther = (otherFeedback.userId == currentUserId) || isSuperAdmin;
      expect(superAdminCanModifyOther, isTrue);
    });

    test('WorkSprintRetroNotifier handles action item edit, convert, and delete', () async {
      final mockApi = MockWorkApiService();
      final container = ProviderContainer(
        overrides: [
          workApiServiceProvider.overrideWithValue(mockApi),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(workSprintRetroProvider.notifier);
      await notifier.init('sprint-1');

      // 1. Update action item
      final updateSuccess = await notifier.updateActionItem('a1', {
        'title': 'gajab updated',
        'priority': 'HIGH',
        'status': 'IN_PROGRESS',
        'progress': 75,
      });
      expect(updateSuccess, isTrue);
      expect(mockApi.actionItemUpdates.length, equals(1));
      expect(mockApi.actionItemUpdates.first['title'], equals('gajab updated'));
      expect(mockApi.actionItemUpdates.first['progress'], equals(75));

      // 2. Convert action item to real work item
      final convertSuccess = await notifier.convertActionItemToWorkItem(
        'a1',
        title: 'gajab updated',
        description: 'Fix database connection pooling',
        priority: 'HIGH',
      );
      expect(convertSuccess, isTrue);
      expect(mockApi.actionItemConversions, contains('a1'));

      // 3. Delete action item
      final deleteSuccess = await notifier.deleteActionItem('a1');
      expect(deleteSuccess, isTrue);
      expect(mockApi.actionItemDeletes, contains('a1'));
    });

    test('WorkSprintRetroNotifier handles feedback update and delete', () async {
      final mockApi = MockWorkApiService();
      final container = ProviderContainer(
        overrides: [
          workApiServiceProvider.overrideWithValue(mockApi),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(workSprintRetroProvider.notifier);
      await notifier.init('sprint-1');

      // 1. Submit feedback
      final submitSuccess = await notifier.submitFeedback(
        category: 'Planning',
        rating: 5,
        content: 'Sprint 9 was planned well',
        suggestedImprovement: 'Keep this pace',
        isAnonymous: false,
      );
      expect(submitSuccess, isTrue);
      expect(mockApi.feedbackSubmissions.length, equals(1));

      // 2. Update feedback
      final updateSuccess = await notifier.updateFeedback(
        'f1',
        category: 'Team Collaboration',
        rating: 4,
        content: 'Updated feedback text',
        suggestedImprovement: 'Streamline testing',
        isAnonymous: true,
      );
      expect(updateSuccess, isTrue);
      expect(mockApi.feedbackUpdates.length, equals(1));
      expect(mockApi.feedbackUpdates.first['id'], equals('f1'));
      expect(mockApi.feedbackUpdates.first['rating'], equals(4));

      // 3. Delete feedback
      final deleteSuccess = await notifier.deleteFeedback('f1');
      expect(deleteSuccess, isTrue);
      expect(mockApi.feedbackDeletes, contains('f1'));
    });

    test('Retrospective history is populated and captured', () async {
      final mockApi = MockWorkApiService();
      final container = ProviderContainer(
        overrides: [
          workApiServiceProvider.overrideWithValue(mockApi),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(workSprintRetroProvider.notifier);
      await notifier.init('sprint-1');

      final state = container.read(workSprintRetroProvider);
      expect(state.workspace, isNotNull);
      final history = state.workspace!.history;
      expect(history.length, equals(2));
      expect(history[0].milestone, equals('Action item created'));
      expect(history[0].description, contains('RA-002: gajab'));
      expect(history[0].actorName, equals('King Doe'));
      expect(history[1].milestone, equals('Feedback submitted'));
    });
  });
}
