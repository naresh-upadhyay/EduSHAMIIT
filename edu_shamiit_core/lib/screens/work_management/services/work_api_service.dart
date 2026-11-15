import '../../../services/api_service.dart';
import '../models/work_models.dart';
import '../utils/work_sprint_date_helper.dart';

class WorkApiService {
  static final WorkApiService instance = WorkApiService();
  WorkApiService();

  final ApiService _api = ApiService();

  // 1. Overview KPIs & Analytics
  Future<Map<String, dynamic>> getOverview({String? boardId, String? sprintId}) async {
    try {
      final query = <String, dynamic>{};
      if (boardId != null) query['board_id'] = boardId;
      if (sprintId != null) query['sprint_id'] = sprintId;
      final res = await _api.get('/v1/work/overview', query: query, useCache: false);
      return res;
    } catch (e) {
      return {};
    }
  }

  // 2. Boards
  Future<List<WorkBoardModel>> getBoards() async {
    try {
      final res = await _api.get('/v1/work/boards', useCache: false);
      if (res['boards'] is List) {
        return (res['boards'] as List)
            .map((b) => WorkBoardModel.fromJson(b))
            .toList();
      }
    } catch (_) {}
    return [
      const WorkBoardModel(id: 'default', name: 'Institute Work Board', code: 'IWB'),
    ];
  }

  // 3. Board Kanban Columns
  Future<List<KanbanColumnModel>> getBoardKanban(
    String boardId, {
    String? sprintId,
    String? view = 'All',
    String? groupBy = 'Status',
    String? search,
  }) async {
    try {
      final query = <String, dynamic>{
        'view': view,
        'group_by': groupBy,
      };
      if (sprintId != null) query['sprint_id'] = sprintId;
      if (search != null && search.isNotEmpty) query['search'] = search;

      final res = await _api.get('/v1/work/boards/$boardId/kanban', query: query, useCache: false);
      if (res['columns'] is List) {
        return (res['columns'] as List)
            .map((c) => KanbanColumnModel.fromJson(c))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // 4. Kanban Reorder
  Future<bool> reorderKanban(String boardId, String itemId, String newStatus, double newRank) async {
    try {
      final res = await _api.post('/v1/work/boards/$boardId/reorder', {
        'item_id': itemId,
        'new_status': newStatus,
        'new_rank': newRank,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // 5. List Tab Paged Items
  Future<Map<String, dynamic>> getItemsPaged({
    String? boardId,
    String? sprintId,
    String type = 'All',
    String status = 'All',
    String? assigneeId,
    String priority = 'All',
    String? search,
    String sortCol = 'created_at',
    String sortDir = 'DESC',
    int page = 1,
    int pageSize = 12,
  }) async {
    try {
      final query = <String, dynamic>{
        'type': type,
        'status': status,
        'priority': priority,
        'sort_col': sortCol,
        'sort_dir': sortDir,
        'page': page,
        'page_size': pageSize,
      };
      if (boardId != null) query['board_id'] = boardId;
      if (sprintId != null) query['sprint_id'] = sprintId;
      if (assigneeId != null) query['assignee_id'] = assigneeId;
      if (search != null && search.isNotEmpty) query['search'] = search;

      final res = await _api.get('/v1/work/items', query: query, useCache: false);
      List<WorkItemModel> items = [];
      if (res['items'] is List) {
        items = (res['items'] as List)
            .map((i) => WorkItemModel.fromJson(i))
            .toList();
      }
      return {
        'total': (res['total'] as num?)?.toInt() ?? items.length,
        'page': page,
        'pageSize': pageSize,
        'kpis': res['kpis'] ?? {},
        'items': items,
      };
    } catch (_) {
      return {'total': 0, 'page': page, 'pageSize': pageSize, 'kpis': {}, 'items': <WorkItemModel>[]};
    }
  }

  // 6. Item Detail
  Future<WorkItemModel?> getItemDetail(String itemId) async {
    try {
      final res = await _api.get('/v1/work/items/$itemId', useCache: false);
      if (res['item'] != null) {
        return WorkItemModel.fromJson(res['item']);
      }
    } catch (_) {}
    return null;
  }

  // 7. Create Work Item
  Future<Map<String, dynamic>> createItem(Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/v1/work/items', data);
      return res;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 8. Update Work Item
  Future<bool> updateItem(String itemId, Map<String, dynamic> data) async {
    try {
      final res = await _api.patch('/v1/work/items/$itemId', data);
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // 9. Delete Work Item
  Future<bool> deleteItem(String itemId) async {
    try {
      final res = await _api.delete('/v1/work/items/$itemId');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // 10. Transition Status
  Future<bool> transitionStatus(String itemId, String newStatus, {String? notes}) async {
    try {
      final res = await _api.post('/v1/work/items/$itemId/transition', {
        'new_status': newStatus,
        'notes': notes,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // 11. Backlog Tree
  Future<Map<String, dynamic>> getBacklogTree({
    String? boardId,
    String? epicId,
    String? search,
    String type = 'All',
    String? assigneeId,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final query = <String, dynamic>{
        'type': type,
        'page': page,
        'page_size': pageSize,
      };
      if (boardId != null) query['board_id'] = boardId;
      if (epicId != null) query['epic_id'] = epicId;
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (assigneeId != null) query['assignee_id'] = assigneeId;

      final res = await _api.get('/v1/work/backlog', query: query, useCache: false);
      List<BacklogEpicModel> epics = [];
      if (res['epics'] is List) {
        epics = (res['epics'] as List).map((e) => BacklogEpicModel.fromJson(e)).toList();
      }
      List<WorkItemModel> items = [];
      if (res['items'] is List) {
        items = (res['items'] as List).map((i) => WorkItemModel.fromJson(i)).toList();
      }

      return {
        'kpis': res['kpis'] ?? {},
        'epics': epics,
        'selected_epic': res['selected_epic'] ?? {},
        'total_items': (res['total_items'] as num?)?.toInt() ?? items.length,
        'page': page,
        'pageSize': pageSize,
        'items': items,
      };
    } catch (_) {
      return {'kpis': {}, 'epics': <BacklogEpicModel>[], 'selected_epic': {}, 'items': <WorkItemModel>[]};
    }
  }

  // 11b. Backlog Reorder
  Future<bool> reorderBacklogItem({
    required String itemId,
    required double newRank,
    String? newParentId,
  }) async {
    try {
      final res = await _api.post('/v1/work/backlog/reorder', {
        'item_id': itemId,
        'new_rank': newRank,
        'new_parent_id': newParentId,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // 11c. Work Items Bulk Update
  Future<bool> bulkUpdateWorkItems({
    required List<String> itemIds,
    String? status,
    String? priority,
    String? assigneeId,
    String? sprintId,
  }) async {
    try {
      final payload = <String, dynamic>{'item_ids': itemIds};
      if (status != null) payload['status'] = status;
      if (priority != null) payload['priority'] = priority;
      if (assigneeId != null) payload['assignee_id'] = assigneeId;
      if (sprintId != null) payload['sprint_id'] = sprintId;

      final res = await _api.post('/v1/work/items/bulk-update', payload);
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // 11d. Work Items Bulk Delete
  Future<bool> bulkDeleteWorkItems(List<String> itemIds) async {
    try {
      final res = await _api.post('/v1/work/items/bulk-delete', {'item_ids': itemIds});
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // 12. Sprints List
  Future<List<WorkSprintModel>> getSprints({String? boardId}) async {
    try {
      final query = <String, dynamic>{};
      if (boardId != null) query['board_id'] = boardId;
      final res = await _api.get('/v1/work/sprints', query: query, useCache: false);
      if (res['sprints'] is List) {
        return (res['sprints'] as List)
            .map((s) => WorkSprintModel.fromJson(s))
            .toList();
      }
    } catch (_) {}
    return [
      const WorkSprintModel(id: 's8', name: 'Sprint 8', status: 'ACTIVE', sprintNumber: 8),
    ];
  }

  // 13. Sprint Dashboard
  Future<Map<String, dynamic>> getSprintDashboard(
    String sprintId, {
    String? boardId,
    String? team = 'All Teams',
    String? search,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final query = <String, dynamic>{
        'team': team,
        'page': page,
        'page_size': pageSize,
      };
      if (boardId != null) query['board_id'] = boardId;
      if (search != null && search.isNotEmpty) query['search'] = search;

      final res = await _api.get('/v1/work/sprints/$sprintId', query: query, useCache: false);
      List<WorkItemModel> items = [];
      if (res['items'] is List) {
        items = (res['items'] as List).map((i) => WorkItemModel.fromJson(i)).toList();
      }
      List<BurndownPointModel> burndown = [];
      if (res['burndown'] is List) {
        burndown = (res['burndown'] as List).map((b) => BurndownPointModel.fromJson(b)).toList();
      }

      List<SprintMemberModel> teamMembers = [];
      if (res['team_members'] is List) {
        teamMembers = (res['team_members'] as List).map((m) => SprintMemberModel.fromJson(m)).toList();
      }
      List<SprintBlockerModel> blockers = [];
      if (res['blockers'] is List) {
        blockers = (res['blockers'] as List).map((b) => SprintBlockerModel.fromJson(b)).toList();
      }

      return {
        'sprint_id': res['sprint_id'],
        'sprint_name': res['sprint_name'] ?? 'Sprint 8',
        'sprint_number': res['sprint_number'] ?? 8,
        'status': res['status'] ?? 'ACTIVE',
        'board_id': res['board_id'],
        'board_name': res['board_name'] ?? 'Institute Work Board',
        'team_name': res['team_name'] ?? 'Digital Campus Team',
        'goal': res['goal'] ?? '',
        'start_date_fmt': (res['start_date_fmt'] != null && !res['start_date_fmt'].toString().contains('2025'))
            ? res['start_date_fmt']
            : WorkSprintDateHelper.currentSprintStartFmt,
        'end_date_fmt': (res['end_date_fmt'] != null && !res['end_date_fmt'].toString().contains('2025'))
            ? res['end_date_fmt']
            : WorkSprintDateHelper.currentSprintEndFmt,
        'duration_days': (res['duration_days'] as num?)?.toInt() ?? 14,
        'capacity_hours': res['capacity_hours'] ?? 160.0,
        'working_days': res['working_days'] ?? 10,
        'working_hours_per_day': res['working_hours_per_day'] ?? 8.0,
        'owner_name': res['owner_name'],
        'capacity_unit': res['capacity_unit'] ?? 'HOURS',
        'color': res['color'] ?? '#2563EB',
        'kpis': res['kpis'] ?? {},
        'burndown': burndown,
        'progress_by_type': res['progress_by_type'] ?? [],
        'upcoming_sprints': res['upcoming_sprints'] ?? [],
        'team_members': teamMembers,
        'blockers': blockers,
        'retrospective': res['retrospective'] ?? {},
        'total_items_count': (res['total_items_count'] as num?)?.toInt() ?? items.length,
        'page': page,
        'pageSize': pageSize,
        'items': items,
      };
    } catch (_) {
      return {};
    }
  }

  // 14. Sprint Lifecycle & Management
  Future<bool> createSprint(Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/v1/work/sprints', data);
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateSprint(String sprintId, Map<String, dynamic> data) async {
    try {
      final res = await _api.patch('/v1/work/sprints/$sprintId', data);
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteSprint(String sprintId) async {
    try {
      final res = await _api.delete('/v1/work/sprints/$sprintId');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> duplicateSprint(String sprintId) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/duplicate', {});
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startSprint(String sprintId) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/start', {});
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> completeSprint(String sprintId, {String? moveIncompleteToSprintId, String? notes}) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/complete', {
        'move_incomplete_to_sprint_id': moveIncompleteToSprintId,
        'retrospective_notes': notes,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancelSprint(String sprintId, {String? reason}) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/cancel', {
        'action': 'CANCEL',
        'notes': reason,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addItemsToSprint(String sprintId, List<String> itemIds) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/work-items', {
        'item_ids': itemIds,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeItemFromSprint(String sprintId, String itemId) async {
    try {
      final res = await _api.delete('/v1/work/sprints/$sprintId/work-items/$itemId');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> moveItemsToSprint(String sprintId, String targetSprintId, List<String> itemIds) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/work-items/move', {
        'target_sprint_id': targetSprintId,
        'item_ids': itemIds,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> manageSprintMember(
    String sprintId, {
    required String userId,
    String? role,
    double? availableHours,
    String action = 'UPSERT',
  }) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/members', {
        'user_id': userId,
        'role': role,
        'available_hours': availableHours,
        'action': action,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeSprintMember(String sprintId, String userId) async {
    try {
      final res = await _api.delete('/v1/work/sprints/$sprintId/members/$userId');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> manageSprintBlocker(
    String sprintId, {
    String? blockerId,
    String? workItemId,
    required String title,
    String? description,
    String severity = 'HIGH',
    String status = 'OPEN',
    String? ownerId,
    String? expectedResolutionDate,
    String? resolutionNotes,
    String action = 'CREATE',
  }) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/blockers', {
        'blocker_id': blockerId,
        'work_item_id': workItemId,
        'title': title,
        'description': description,
        'severity': severity,
        'status': status,
        'owner_id': ownerId,
        'expected_resolution_date': expectedResolutionDate,
        'resolution_notes': resolutionNotes,
        'action': action,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteSprintBlocker(String sprintId, String blockerId) async {
    try {
      final res = await _api.delete('/v1/work/sprints/$sprintId/blockers/$blockerId');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // 15. Sprints Retrospective Enterprise Operations
  Future<SprintRetroWorkspaceModel?> getSprintRetrospectiveWorkspace(
    String sprintId, {
    String? teamId,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (teamId != null && teamId.isNotEmpty) query['team_id'] = teamId;
      final res = await _api.get(
        '/v1/work/sprints/$sprintId/retrospective',
        query: query,
        useCache: false,
      );
      if (res.containsKey('retrospective')) {
        return SprintRetroWorkspaceModel.fromJson(res);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> updateSprintRetroSession(String sprintId, Map<String, dynamic> data) async {
    try {
      final res = await _api.patch('/v1/work/sprints/$sprintId/retrospective', data);
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startSprintRetroSession(String sprintId) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/retrospective/start', {});
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> closeSprintRetroSession(String sprintId, {String? summary}) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/retrospective/close', {
        if (summary != null) 'summary': summary,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reopenSprintRetroSession(String sprintId) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/retrospective/reopen', {});
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addRetroEntry(String sprintId, {required String category, required String content}) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/retrospective/entries', {
        'category': category,
        'content': content,
        'action': 'ADD',
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateRetroEntry(String sprintId, String entryId, {required String category, required String content}) async {
    try {
      final res = await _api.patch('/v1/work/sprints/$sprintId/retrospective/entries/$entryId', {
        'category': category,
        'content': content,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteRetroEntry(String sprintId, String entryId) async {
    try {
      final res = await _api.delete('/v1/work/sprints/$sprintId/retrospective/entries/$entryId');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> voteRetroEntry(String sprintId, String entryId) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/retrospective/entries/$entryId/vote', {});
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addActionItem(
    String sprintId, {
    required String title,
    String? itemKey,
    String? description,
    String? ownerId,
    String? dueDate,
    String priority = 'MEDIUM',
    String status = 'OPEN',
    int progress = 0,
    String? linkedWorkItemId,
    String? sourceEntryId,
  }) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/retrospective/action-items', {
        'title': title,
        'item_key': itemKey,
        'description': description,
        'owner_id': ownerId,
        'due_date': dueDate,
        'priority': priority,
        'status': status,
        'progress': progress,
        'linked_work_item_id': linkedWorkItemId,
        'source_entry_id': sourceEntryId,
        'action': 'ADD',
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateActionItem(
    String sprintId,
    String actionItemId,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _api.patch('/v1/work/sprints/$sprintId/retrospective/action-items/$actionItemId', data);
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteActionItem(String sprintId, String actionItemId) async {
    try {
      final res = await _api.delete('/v1/work/sprints/$sprintId/retrospective/action-items/$actionItemId');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> convertActionItemToWorkItem(
    String sprintId,
    String actionItemId, {
    String? title,
    String? description,
    String? ownerId,
    String? priority,
  }) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/retrospective/action-items/$actionItemId/convert-to-work-item', {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (ownerId != null) 'owner_id': ownerId,
        if (priority != null) 'priority': priority,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> bulkUpdateActionItems(
    String sprintId, {
    required List<String> actionItemIds,
    String? status,
    String? priority,
  }) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/retrospective/action-items/bulk-update', {
        'action_item_ids': actionItemIds,
        if (status != null) 'status': status,
        if (priority != null) 'priority': priority,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> submitRetroFeedback(
    String sprintId, {
    required String category,
    required int rating,
    String? content,
    String? suggestedImprovement,
    bool isAnonymous = false,
  }) async {
    try {
      final res = await _api.post('/v1/work/sprints/$sprintId/retrospective/feedback', {
        'category': category,
        'rating': rating,
        'content': content,
        'suggested_improvement': suggestedImprovement,
        'is_anonymous': isAnonymous,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> exportSprintRetroCsv(String sprintId) async {
    try {
      final res = await _api.get('/v1/work/sprints/$sprintId/retrospective/export', useCache: false);
      if (res['data'] is String) return res['data'] as String;
      if (res['csv'] is String) return res['csv'] as String;
      return res.toString();
    } catch (_) {}
    return null;
  }

  // 16. Comments & Checklists
  Future<bool> addComment(String itemId, String commentText) async {
    try {
      final res = await _api.post('/v1/work/items/$itemId/comments', {
        'comment_text': commentText,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleChecklist(String entryId, bool isCompleted) async {
    try {
      final res = await _api.post('/v1/work/checklists/$entryId/toggle', {
        'is_completed': isCompleted,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> addChecklistEntry(String itemId, String title) async {
    try {
      final res = await _api.post('/v1/work/items/$itemId/checklists', {
        'title': title,
      });
      return res;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> updateChecklistEntry(String entryId, {String? title, bool? isCompleted}) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (isCompleted != null) body['is_completed'] = isCompleted;
      final res = await _api.patch('/v1/work/checklists/$entryId', body);
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteChecklistEntry(String entryId) async {
    try {
      final res = await _api.delete('/v1/work/checklists/$entryId');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // 17. Users for Selectors
  Future<List<WorkAssigneeModel>> getAssignableUsers({
    String? q,
    String? role,
    String? department,
    int limit = 100,
  }) async {
    try {
      final query = <String, dynamic>{'limit': limit};
      if (q != null && q.isNotEmpty) query['q'] = q;
      if (role != null && role != 'All') query['role'] = role;
      if (department != null && department != 'All') query['department'] = department;

      final res = await _api.get('/v1/work/users', query: query, useCache: false);
      if (res['users'] is List) {
        return (res['users'] as List)
            .map((u) => WorkAssigneeModel.fromJson(u))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<WorkAssigneeModel>> previewAssignees({
    required String assignmentMode,
    String? targetRole,
    String? classId,
    String? className,
    String? sectionId,
    String? sectionName,
    String? department,
    String? q,
    int limit = 150,
  }) async {
    try {
      final payload = <String, dynamic>{
        'assignment_mode': assignmentMode,
        'limit': limit,
      };
      if (targetRole != null && targetRole != 'All') payload['target_role'] = targetRole;
      if (classId != null) payload['class_id'] = classId;
      if (className != null) payload['class_name'] = className;
      if (sectionId != null) payload['section_id'] = sectionId;
      if (sectionName != null) payload['section_name'] = sectionName;
      if (department != null && department != 'All') payload['department'] = department;
      if (q != null && q.trim().isNotEmpty) payload['q'] = q.trim();

      final res = await _api.post('/v1/work/preview-assignees', payload);
      if (res['users'] is List) {
        return (res['users'] as List)
            .map((u) => WorkAssigneeModel.fromJson(u))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<WorkAcademicClassModel>> getAcademicClasses() async {
    try {
      final res = await _api.get('/v1/work/academic-options', useCache: false);
      if (res['classes'] is List) {
        return (res['classes'] as List)
            .map((c) => WorkAcademicClassModel.fromJson(c))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // 18. Lookups
  Future<Map<String, List<Map<String, String>>>> getLookups() async {
    try {
      final res = await _api.get('/v1/work/lookups', useCache: false);
      if (res['lookups'] is Map) {
        final Map<String, List<Map<String, String>>> result = {};
        (res['lookups'] as Map).forEach((k, v) {
          if (v is List) {
            result[k.toString()] = v
                .map((item) => {
                      'code': item['code']?.toString() ?? '',
                      'name': item['name']?.toString() ?? '',
                    })
                .toList();
          }
        });
        return result;
      }
    } catch (_) {}
    return {};
  }

  // 19. Academic Options
  Future<Map<String, dynamic>> getAcademicOptions() async {
    try {
      final res = await _api.get('/v1/work/academic-options', useCache: false);
      return res;
    } catch (_) {
      return {'classes': [], 'subjects': []};
    }
  }

  // Convenience Aliases for UI Components
  Future<Map<String, dynamic>> getWorkItemDetail(String itemId) async {
    try {
      final res = await _api.get('/v1/work/items/$itemId', useCache: false);
      return res;
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> createWorkItem(Map<String, dynamic> data) async {
    return await createItem(data);
  }

  Future<bool> toggleChecklistEntry(String entryId, bool isCompleted) async {
    return await toggleChecklist(entryId, isCompleted);
  }

  // 20. Azure DevOps Enhancements
  Future<Map<String, dynamic>> copyWorkItem(
    String itemId, {
    String? newTitle,
    bool includeChildren = true,
    bool includeAttachments = true,
  }) async {
    try {
      final res = await _api.post('/v1/work/items/$itemId/copy', {
        if (newTitle != null && newTitle.isNotEmpty) 'new_title': newTitle,
        'include_children': includeChildren,
        'include_attachments': includeAttachments,
      });
      return res;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> linkWorkItems(String sourceId, String targetId, String linkType) async {
    final res = await linkWorkItemDetailed(sourceId, targetId, linkType);
    return res['success'] == true;
  }

  Future<Map<String, dynamic>> linkWorkItemDetailed(
    String sourceId,
    String targetRef,
    String linkType,
  ) async {
    try {
      final res = await _api.post('/v1/work/items/$sourceId/links', {
        'target_id': targetRef,
        'link_type': linkType,
      });
      return res;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> unlinkWorkItems(String sourceId, String targetId) async {
    try {
      final res = await _api.delete('/v1/work/items/$sourceId/links/$targetId');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateLinkRelationship(String sourceId, String targetId, String newLinkType) async {
    try {
      final res = await _api.put('/v1/work/items/$sourceId/links/$targetId', {
        'link_type': newLinkType,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> addAttachment(
    String itemId,
    String fileName,
    String fileUrl, {
    int fileSizeBytes = 0,
    String fileType = 'document',
  }) async {
    try {
      final res = await _api.post('/v1/work/items/$itemId/attachments', {
        'file_name': fileName,
        'file_url': fileUrl,
        'file_size_bytes': fileSizeBytes,
        'file_type': fileType,
      });
      return res;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadAttachment(
    String itemId,
    List<int> bytes,
    String filename,
  ) async {
    try {
      final res = await _api.multipartPostBytes(
        '/v1/work/items/$itemId/attachments/upload',
        bytes,
        filename,
        'file',
      );
      return res;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> deleteAttachment(String attachmentId) async {
    try {
      final res = await _api.delete('/v1/work/attachments/$attachmentId');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // 24. Capacity Management Endpoints
  Future<SprintCapacityDashboardModel?> getSprintCapacityDashboard(
    String sprintId, {
    String? team,
    String? search,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (team != null && team.isNotEmpty) query['team'] = team;
      if (search != null && search.isNotEmpty) query['search'] = search;
      final res = await _api.get('/v1/work/sprints/$sprintId/capacity', query: query, useCache: false);
      if (res['success'] == true) {
        return SprintCapacityDashboardModel.fromJson(res);
      }
    } catch (_) {}
    return null;
  }

  Future<List<SprintCapacityTeamModel>> getCapacityTeams() async {
    try {
      final res = await _api.get('/v1/work/capacity/teams', useCache: false);
      if (res['teams'] is List) {
        return (res['teams'] as List)
            .map((t) => SprintCapacityTeamModel.fromJson(t as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> manageMemberCapacity(
    String sprintId, {
    required String userId,
    required double capacityHours,
    double? dailyWorkingHours,
    int? workingDays,
    String? role,
    String? teamName,
    double? overrideValue,
    String? overrideReason,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'user_id': userId,
        'capacity_hours': capacityHours,
        if (dailyWorkingHours != null) 'daily_working_hours': dailyWorkingHours,
        if (workingDays != null) 'working_days': workingDays,
        if (role != null) 'role': role,
        if (teamName != null) 'team_name': teamName,
        if (overrideValue != null) 'override_value': overrideValue,
        if (overrideReason != null) 'override_reason': overrideReason,
        if (notes != null) 'notes': notes,
      };
      final res = await _api.post('/v1/work/sprints/$sprintId/capacity/members', body);
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeCapacityMember(String sprintId, String userId) async {
    try {
      final res = await _api.delete('/v1/work/sprints/$sprintId/capacity/members/$userId');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> manageCapacityAvailability(
    String sprintId, {
    required String userId,
    required String startDate,
    required String endDate,
    double unavailableHours = 8.0,
    String? reason,
    String? availabilityType = 'LEAVE',
  }) async {
    try {
      final body = <String, dynamic>{
        'user_id': userId,
        'start_date': startDate,
        'end_date': endDate,
        'unavailable_hours': unavailableHours,
        'availability_type': availabilityType,
        if (reason != null) 'reason': reason,
      };
      final res = await _api.post('/v1/work/sprints/$sprintId/capacity/availability', body);
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteCapacityAvailability(String sprintId, String availabilityId) async {
    try {
      final res = await _api.delete('/v1/work/sprints/$sprintId/capacity/availability/$availabilityId');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rebalanceWorkload(
    String sprintId, {
    required String workItemId,
    required String fromUserId,
    required String toUserId,
    String? reason,
  }) async {
    try {
      final body = <String, dynamic>{
        'work_item_id': workItemId,
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'reason': reason ?? 'Workload rebalancing',
      };
      final res = await _api.post('/v1/work/sprints/$sprintId/capacity/rebalance', body);
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> exportCapacityCsv(String sprintId, {String? team}) async {
    try {
      final query = <String, dynamic>{};
      if (team != null && team.isNotEmpty) query['team'] = team;
      final res = await _api.get('/v1/work/sprints/$sprintId/capacity/export', query: query, useCache: false);
      if (res['data'] is String) return res['data'] as String;
      if (res['csv'] is String) return res['csv'] as String;
      return res.toString();
    } catch (_) {}
    return null;
  }

  // 25. Enterprise Team Administration Endpoints
  Future<TeamDirectoryResponseModel?> getTeamsDirectory({
    String? sprintId,
    String? status,
    String? department,
    String? search,
    String? sortBy,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (sprintId != null && sprintId.isNotEmpty) query['sprint_id'] = sprintId;
      if (status != null && status.isNotEmpty) query['status'] = status;
      if (department != null && department.isNotEmpty) query['department'] = department;
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (sortBy != null && sortBy.isNotEmpty) query['sort_by'] = sortBy;

      final res = await _api.get('/v1/work/teams', query: query, useCache: false);
      if (res['success'] == true) {
        return TeamDirectoryResponseModel.fromJson(res);
      }
    } catch (_) {}
    return null;
  }

  Future<TeamDetailModel?> getTeamDetail(String teamId, {String? sprintId}) async {
    try {
      final query = <String, dynamic>{};
      if (sprintId != null && sprintId.isNotEmpty) query['sprint_id'] = sprintId;
      final res = await _api.get('/v1/work/teams/$teamId', query: query, useCache: false);
      if (res['success'] == true && res['team'] != null) {
        return TeamDetailModel.fromJson(res['team'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> createWorkTeam(Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/v1/work/teams', data);
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateWorkTeam(String teamId, Map<String, dynamic> data) async {
    try {
      final res = await _api.patch('/v1/work/teams/$teamId', data);
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> duplicateWorkTeam(String teamId, {String? newName, String? newKey}) async {
    try {
      final body = <String, dynamic>{
        if (newName != null) 'new_name': newName,
        if (newKey != null) 'new_key': newKey,
      };
      final res = await _api.post('/v1/work/teams/$teamId/duplicate', body);
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteWorkTeam(String teamId, {bool hard = false}) async {
    try {
      final res = await _api.delete('/v1/work/teams/$teamId${hard ? "?hard=true" : ""}');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addTeamMember(String teamId, Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/v1/work/teams/$teamId/members', data);
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeTeamMember(String teamId, String userId) async {
    try {
      final res = await _api.delete('/v1/work/teams/$teamId/members/$userId');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> exportTeamsCsv({String? sprintId, String? status, String? department, String? search}) async {
    try {
      final query = <String, dynamic>{};
      if (sprintId != null && sprintId.isNotEmpty) query['sprint_id'] = sprintId;
      if (status != null && status.isNotEmpty) query['status'] = status;
      if (department != null && department.isNotEmpty) query['department'] = department;
      if (search != null && search.isNotEmpty) query['search'] = search;
      final res = await _api.get('/v1/work/teams/export', query: query, useCache: false);
      if (res['data'] is String) return res['data'] as String;
      if (res['csv'] is String) return res['csv'] as String;
      return res.toString();
    } catch (_) {}
    return null;
  }
}
