import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/work_models.dart';
import '../services/work_api_service.dart';
import '../utils/work_sprint_date_helper.dart';

// API Service Provider
final workApiServiceProvider = Provider<WorkApiService>((ref) => WorkApiService.instance);

// ==========================================
// 1. BOARD TAB STATE & NOTIFIER
// ==========================================
class WorkBoardState {
  final bool isLoading;
  final List<KanbanColumnModel> columns;

  const WorkBoardState({
    this.isLoading = false,
    this.columns = const [],
  });

  WorkBoardState copyWith({
    bool? isLoading,
    List<KanbanColumnModel>? columns,
  }) {
    return WorkBoardState(
      isLoading: isLoading ?? this.isLoading,
      columns: columns ?? this.columns,
    );
  }
}

class WorkBoardNotifier extends StateNotifier<WorkBoardState> {
  final Ref? _ref;
  final WorkApiService _api;

  String _lastBoardId = 'default';
  String? _lastSprintId;
  String _lastView = 'Task & Story';
  String _lastGroupBy = 'Status';
  String? _lastSearch;

  WorkBoardNotifier([Ref? ref, WorkApiService? api])
      : _ref = ref,
        _api = api ?? (ref != null ? ref.read(workApiServiceProvider) : WorkApiService.instance),
        super(const WorkBoardState(isLoading: true)) {
    loadBoard();
  }

  Future<void> loadBoard({
    String? boardId,
    String? sprintId,
    String? view,
    String? groupBy,
    String? search,
    bool forceRefresh = false,
  }) async {
    if (boardId != null) _lastBoardId = boardId;
    if (sprintId != null) _lastSprintId = sprintId;
    if (view != null) _lastView = view;
    if (groupBy != null) _lastGroupBy = groupBy;
    if (search != null) _lastSearch = search;

    state = state.copyWith(isLoading: true);
    try {
      final cols = await _api.getBoardKanban(
        _lastBoardId,
        sprintId: _lastSprintId,
        view: _lastView,
        groupBy: _lastGroupBy,
        search: _lastSearch,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      state = WorkBoardState(isLoading: false, columns: cols);
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  bool _statusMatchesNormalized(String a, String b) {
    return a.replaceAll('_', ' ').trim().toUpperCase() == b.replaceAll('_', ' ').trim().toUpperCase();
  }

  Future<bool> transitionStatus(String itemId, String newStatus, {String? notes}) async {
    // 1. Optimistic Local Update
    final currentCols = state.columns;
    WorkItemModel? targetItem;

    final updatedCols = currentCols.map((col) {
      final items = List<WorkItemModel>.from(col.items);
      final index = items.indexWhere((i) => i.id == itemId);
      if (index != -1) {
        targetItem = items.removeAt(index);
        return col.copyWith(items: items, count: items.length);
      }
      return col;
    }).toList();

    if (targetItem != null) {
      final newCols = updatedCols.map((col) {
        if (_statusMatchesNormalized(col.statusKey, newStatus)) {
          final items = List<WorkItemModel>.from(col.items);
          final updated = targetItem!.copyWith(
            status: newStatus.toUpperCase(),
            progressPercentage: (newStatus.toUpperCase() == 'COMPLETED' || newStatus.toUpperCase() == 'RESOLVED')
                ? 100
                : (newStatus.toUpperCase() == 'NEW' ? 0 : 50),
          );
          items.add(updated);
          return col.copyWith(items: items, count: items.length);
        }
        return col;
      }).toList();

      state = WorkBoardState(isLoading: false, columns: newCols);
    }

    // 2. Persist to DB via Stored Procedure
    final success = await _api.transitionStatus(itemId, newStatus, notes: notes);
    if (!mounted) return success;
    if (!success) {
      // Rollback on failure
      loadBoard();
    } else {
      _ref?.read(workSprintDashboardProvider.notifier).loadSprintDashboard(quiet: true, forceRefresh: true);
      _ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
      _ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
    }
    return success;
  }

  Future<bool> updateItemPriority(String itemId, String newPriority) async {
    // 1. Optimistic Local Update
    final currentCols = state.columns;
    WorkItemModel? targetItem;

    final updatedCols = currentCols.map((col) {
      final items = List<WorkItemModel>.from(col.items);
      final index = items.indexWhere((i) => i.id == itemId);
      if (index != -1) {
        targetItem = items.removeAt(index);
        return col.copyWith(items: items, count: items.length);
      }
      return col;
    }).toList();

    if (targetItem != null) {
      final newCols = updatedCols.map((col) {
        if (col.statusKey.toUpperCase() == newPriority.toUpperCase()) {
          final items = List<WorkItemModel>.from(col.items);
          final updated = targetItem!.copyWith(priority: newPriority.toUpperCase());
          items.add(updated);
          return col.copyWith(items: items, count: items.length);
        }
        return col;
      }).toList();

      state = WorkBoardState(isLoading: false, columns: newCols);
    }

    // 2. Persist to DB
    final success = await _api.updateItem(itemId, {'priority': newPriority.toUpperCase()});
    if (!mounted) return success;
    if (!success) {
      loadBoard();
    } else {
      _ref?.read(workSprintDashboardProvider.notifier).loadSprintDashboard(quiet: true, forceRefresh: true);
      _ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
      _ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
    }
    return success;
  }

  Future<bool> updateItemType(String itemId, String newType) async {
    // 1. Optimistic Local Update
    final currentCols = state.columns;
    WorkItemModel? targetItem;

    final updatedCols = currentCols.map((col) {
      final items = List<WorkItemModel>.from(col.items);
      final index = items.indexWhere((i) => i.id == itemId);
      if (index != -1) {
        targetItem = items.removeAt(index);
        return col.copyWith(items: items, count: items.length);
      }
      return col;
    }).toList();

    if (targetItem != null) {
      final newCols = updatedCols.map((col) {
        if (col.statusKey.toUpperCase() == newType.toUpperCase()) {
          final items = List<WorkItemModel>.from(col.items);
          final updated = targetItem!.copyWith(workType: newType.toUpperCase());
          items.add(updated);
          return col.copyWith(items: items, count: items.length);
        }
        return col;
      }).toList();

      state = WorkBoardState(isLoading: false, columns: newCols);
    }

    // 2. Persist to DB
    final success = await _api.updateItem(itemId, {'work_type': newType.toUpperCase()});
    if (!mounted) return success;
    if (!success) {
      loadBoard();
    } else {
      _ref?.read(workSprintDashboardProvider.notifier).loadSprintDashboard(quiet: true, forceRefresh: true);
      _ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
      _ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
    }
    return success;
  }
}

final workBoardProvider = StateNotifierProvider<WorkBoardNotifier, WorkBoardState>((ref) {
  return WorkBoardNotifier(ref, ref.read(workApiServiceProvider));
});

// ==========================================
// 2. OVERVIEW PROVIDER
// ==========================================
class WorkOverviewNotifier extends StateNotifier<Map<String, dynamic>> {
  final WorkApiService _api = WorkApiService.instance;

  WorkOverviewNotifier() : super({}) {
    loadOverview();
  }

  Future<void> loadOverview({String? boardId, String? sprintId}) async {
    try {
      final res = await _api.getOverview(boardId: boardId, sprintId: sprintId);
      if (!mounted) return;
      state = res;
    } catch (_) {}
  }
}

final workOverviewProvider =
    StateNotifierProvider<WorkOverviewNotifier, Map<String, dynamic>>((ref) {
  return WorkOverviewNotifier();
});

// ==========================================
// 3. LIST TAB STATE & NOTIFIER
// ==========================================
class WorkListState {
  final bool isLoading;
  final List<WorkItemModel> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;
  final Map<String, dynamic> kpis;
  final String workType;
  final String status;
  final String? assigneeId;
  final String? boardId;

  const WorkListState({
    this.isLoading = false,
    this.items = const [],
    this.totalCount = 66,
    this.page = 1,
    this.pageSize = 12,
    this.totalPages = 6,
    this.kpis = const {},
    this.workType = 'All',
    this.status = 'All',
    this.assigneeId,
    this.boardId,
  });

  WorkListState copyWith({
    bool? isLoading,
    List<WorkItemModel>? items,
    int? totalCount,
    int? page,
    int? pageSize,
    int? totalPages,
    Map<String, dynamic>? kpis,
    String? workType,
    String? status,
    String? assigneeId,
    String? boardId,
  }) {
    return WorkListState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalPages: totalPages ?? this.totalPages,
      kpis: kpis ?? this.kpis,
      workType: workType ?? this.workType,
      status: status ?? this.status,
      assigneeId: assigneeId ?? this.assigneeId,
      boardId: boardId ?? this.boardId,
    );
  }
}

class WorkListNotifier extends StateNotifier<WorkListState> {
  final Ref? _ref;
  final WorkApiService _api;

  WorkListNotifier([Ref? ref, WorkApiService? api])
      : _ref = ref,
        _api = api ?? (ref != null ? ref.read(workApiServiceProvider) : WorkApiService.instance),
        super(const WorkListState(isLoading: true)) {
    loadPagedItems();
  }

  Future<void> loadPagedItems({String? boardId, bool forceRefresh = false}) async {
    final effectiveBoardId = boardId ?? state.boardId;
    state = state.copyWith(isLoading: true, boardId: effectiveBoardId);
    try {
      final res = await _api.getItemsPaged(
        boardId: effectiveBoardId,
        type: state.workType,
        status: state.status,
        assigneeId: state.assigneeId,
        page: state.page,
        pageSize: state.pageSize,
        forceRefresh: forceRefresh,
      );

      final total = (res['total'] as num?)?.toInt() ?? 66;
      final pages = (total / state.pageSize).ceil().clamp(1, 99);
      final items = (res['items'] as List<WorkItemModel>?) ?? [];

      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        items: items,
        totalCount: total,
        totalPages: pages,
        kpis: res['kpis'] as Map<String, dynamic>? ?? {},
      );
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  void setFilter({String? workType, String? status, String? assigneeId, String? boardId}) {
    state = state.copyWith(
      workType: workType ?? state.workType,
      status: status ?? state.status,
      assigneeId: assigneeId,
      boardId: boardId ?? state.boardId,
      page: 1,
    );
    loadPagedItems();
  }

  void setPage(int newPage, {int? pageSize}) {
    state = state.copyWith(
      page: newPage,
      pageSize: pageSize ?? state.pageSize,
    );
    loadPagedItems();
  }

  Future<bool> bulkUpdate({
    required List<String> itemIds,
    String? status,
    String? priority,
    String? assigneeId,
    String? sprintId,
    String? teamId,
    String? teamName,
  }) async {
    final success = await _api.bulkUpdateWorkItems(
      itemIds: itemIds,
      status: status,
      priority: priority,
      assigneeId: assigneeId,
      sprintId: sprintId,
      teamId: teamId,
      teamName: teamName,
    );
    if (success) {
      final updated = state.items.map((item) {
        if (itemIds.contains(item.id)) {
          final isUnassign = teamName == 'UNASSIGN' || teamId == 'UNASSIGN';
          return item.copyWith(
            status: status ?? item.status,
            priority: priority ?? item.priority,
            sprintId: sprintId ?? item.sprintId,
            teamId: isUnassign ? null : (teamId ?? item.teamId),
            teamName: isUnassign ? null : (teamName ?? item.teamName),
            clearTeam: isUnassign,
          );
        }
        return item;
      }).toList();
      state = state.copyWith(items: updated);
      if (mounted) {
        _ref?.read(workSprintDashboardProvider.notifier).loadSprintDashboard(forceRefresh: true);
        _ref?.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
        _ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
        _ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      }
    }
    return success;
  }

  Future<bool> bulkDelete(List<String> itemIds) async {
    bool allSuccess = true;
    for (final id in itemIds) {
      final ok = await _api.deleteItem(id);
      if (!ok) allSuccess = false;
    }
    if (!mounted) return allSuccess;
    final remaining = state.items.where((i) => !itemIds.contains(i.id)).toList();
    state = state.copyWith(items: remaining, totalCount: remaining.length);
    if (mounted) {
      _ref?.read(workSprintDashboardProvider.notifier).loadSprintDashboard(forceRefresh: true);
      _ref?.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
      _ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
      _ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
    }
    return allSuccess;
  }

  void loadItems() {
    loadPagedItems();
  }
}

final workListProvider = StateNotifierProvider<WorkListNotifier, WorkListState>((ref) {
  return WorkListNotifier(ref, ref.read(workApiServiceProvider));
});

// ==========================================
// 4. BACKLOG TAB STATE & NOTIFIER
// ==========================================
class WorkBacklogState {
  final bool isLoading;
  final List<WorkItemModel> stories;
  final List<BacklogEpicModel> epics;
  final BacklogEpicModel? selectedEpic;
  final String? currentEpicId;
  final int totalCount;
  final Map<String, dynamic> kpis;
  final String? boardId;

  const WorkBacklogState({
    this.isLoading = false,
    this.stories = const [],
    this.epics = const [],
    this.selectedEpic,
    this.currentEpicId,
    this.totalCount = 0,
    this.kpis = const {},
    this.boardId,
  });

  WorkBacklogState copyWith({
    bool? isLoading,
    List<WorkItemModel>? stories,
    List<BacklogEpicModel>? epics,
    BacklogEpicModel? selectedEpic,
    String? currentEpicId,
    int? totalCount,
    Map<String, dynamic>? kpis,
    String? boardId,
  }) {
    return WorkBacklogState(
      isLoading: isLoading ?? this.isLoading,
      stories: stories ?? this.stories,
      epics: epics ?? this.epics,
      selectedEpic: selectedEpic ?? this.selectedEpic,
      currentEpicId: currentEpicId ?? this.currentEpicId,
      totalCount: totalCount ?? this.totalCount,
      kpis: kpis ?? this.kpis,
      boardId: boardId ?? this.boardId,
    );
  }
}

class WorkBacklogNotifier extends StateNotifier<WorkBacklogState> {
  final Ref? _ref;
  final WorkApiService _api;

  WorkBacklogNotifier([Ref? ref, WorkApiService? api])
      : _ref = ref,
        _api = api ?? (ref != null ? ref.read(workApiServiceProvider) : WorkApiService.instance),
        super(const WorkBacklogState(isLoading: true)) {
    loadBacklog();
  }

  void selectEpic(BacklogEpicModel epic) {
    state = state.copyWith(
      selectedEpic: epic,
      currentEpicId: epic.id.isNotEmpty ? epic.id : epic.itemNumber,
    );
  }

  Future<void> loadBacklog({String? boardId, String? epicId, String? search, bool forceRefresh = false}) async {
    final effectiveBoardId = boardId ?? state.boardId;
    state = state.copyWith(isLoading: true, currentEpicId: epicId ?? state.currentEpicId, boardId: effectiveBoardId);
    try {
      final res = await _api.getBacklogTree(
        boardId: effectiveBoardId,
        epicId: epicId ?? state.currentEpicId,
        search: search,
        forceRefresh: forceRefresh,
      );
      final items = (res['items'] as List<WorkItemModel>?) ?? [];
      final epics = (res['epics'] as List<BacklogEpicModel>?) ?? [];
      final kpis = (res['kpis'] as Map<String, dynamic>?) ?? {};
      final total = (res['total_items'] as num?)?.toInt() ?? items.length;
      BacklogEpicModel? selectedEpic;
      if (res['selected_epic'] is Map && (res['selected_epic'] as Map).isNotEmpty) {
        selectedEpic = BacklogEpicModel.fromJson(res['selected_epic'] as Map<String, dynamic>);
      } else if (epicId != null && epics.isNotEmpty) {
        selectedEpic = epics.firstWhere(
          (e) => e.id == epicId || e.itemNumber.toUpperCase() == epicId.toUpperCase(),
          orElse: () => epics.first,
        );
      } else if (state.selectedEpic != null && epics.any((e) => e.id == state.selectedEpic!.id || e.itemNumber == state.selectedEpic!.itemNumber)) {
        selectedEpic = epics.firstWhere(
          (e) => e.id == state.selectedEpic!.id || e.itemNumber == state.selectedEpic!.itemNumber,
          orElse: () => state.selectedEpic!,
        );
      } else if (epics.isNotEmpty) {
        selectedEpic = epics.first;
      }

      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        stories: items,
        epics: epics,
        selectedEpic: selectedEpic,
        totalCount: total,
        kpis: kpis,
      );
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<bool> bulkUpdate({
    required List<String> itemIds,
    String? status,
    String? priority,
    String? assigneeId,
    String? sprintId,
    String? teamId,
    String? teamName,
  }) async {
    final success = await _api.bulkUpdateWorkItems(
      itemIds: itemIds,
      status: status,
      priority: priority,
      assigneeId: assigneeId,
      sprintId: sprintId,
      teamId: teamId,
      teamName: teamName,
    );
    if (success) {
      await loadBacklog(forceRefresh: true);
      _ref?.read(workSprintDashboardProvider.notifier).loadSprintDashboard(forceRefresh: true);
      _ref?.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
      _ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      _ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
    }
    return success;
  }

  Future<bool> bulkDelete(List<String> itemIds) async {
    final success = await _api.bulkDeleteWorkItems(itemIds);
    if (!mounted) return success;
    if (success) {
      await loadBacklog(forceRefresh: true);
      if (mounted) {
        _ref?.read(workSprintDashboardProvider.notifier).loadSprintDashboard(forceRefresh: true);
        _ref?.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
        _ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
        _ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
      }
    }
    return success;
  }

  Future<bool> reorderItem({
    required String itemId,
    required double newRank,
    String? newParentId,
  }) async {
    final success = await _api.reorderBacklogItem(
      itemId: itemId,
      newRank: newRank,
      newParentId: newParentId,
    );
    if (!mounted) return success;
    if (success) {
      await loadBacklog(forceRefresh: true);
      if (mounted) {
        _ref?.read(workSprintDashboardProvider.notifier).loadSprintDashboard(forceRefresh: true);
        _ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
        _ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
      }
    }
    return success;
  }

  Future<bool> reparentStoryTask({
    required WorkItemModel task,
    required WorkItemModel targetStory,
  }) async {
    final previousStories = state.stories;

    final updatedTask = task.copyWith(
      parentId: targetStory.id.isNotEmpty ? targetStory.id : targetStory.itemNumber,
      parentCode: targetStory.itemNumber,
      parentTitle: targetStory.title,
    );

    final updatedStories = state.stories.map((story) {
      final isTarget = story.id == targetStory.id ||
          story.itemNumber.toUpperCase() == targetStory.itemNumber.toUpperCase();
      final isSource = story.children.any((c) =>
          c.id == task.id ||
          c.itemNumber.toUpperCase() == task.itemNumber.toUpperCase());

      if (isTarget) {
        final newChildren = List<WorkItemModel>.from(story.children)
          ..removeWhere((c) =>
              c.id == task.id ||
              c.itemNumber.toUpperCase() == task.itemNumber.toUpperCase())
          ..add(updatedTask);
        return story.copyWith(children: newChildren);
      } else if (isSource) {
        final newChildren = story.children
            .where((c) =>
                c.id != task.id &&
                c.itemNumber.toUpperCase() != task.itemNumber.toUpperCase())
            .toList();
        return story.copyWith(children: newChildren);
      }
      return story;
    }).toList();

    state = state.copyWith(stories: updatedStories);

    try {
      final targetRank = targetStory.children.isNotEmpty
          ? (targetStory.children.last.rank + 10.0)
          : (task.rank > 0 ? task.rank : 1000.0);

      final success = await _api.reorderBacklogItem(
        itemId: task.id.isNotEmpty ? task.id : task.itemNumber,
        newRank: targetRank,
        newParentId: targetStory.id.isNotEmpty ? targetStory.id : targetStory.itemNumber,
      );

      if (!mounted) return success;

      if (!success) {
        state = state.copyWith(stories: previousStories);
        return false;
      }
      if (mounted) {
        _ref?.read(workSprintDashboardProvider.notifier).loadSprintDashboard(forceRefresh: true);
        _ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
        _ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
      }
      _ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
      return true;
    } catch (_) {
      state = state.copyWith(stories: previousStories);
      return false;
    }
  }
}

final workBacklogProvider = StateNotifierProvider<WorkBacklogNotifier, WorkBacklogState>((ref) {
  return WorkBacklogNotifier(ref, ref.read(workApiServiceProvider));
});

// ==========================================
// 5. SPRINTS TAB STATE & NOTIFIER
// ==========================================
class WorkSprintDashboardState {
  final bool isLoading;
  final WorkSprintModel? sprint;
  final Map<String, dynamic> metrics;
  final List<BurndownPointModel> burndownPoints;
  final List<WorkItemModel> items;
  final List<SprintMemberModel> teamMembers;
  final List<SprintBlockerModel> blockers;
  final Map<String, dynamic> retroData;
  final List<Map<String, dynamic>> progressByType;
  final List<Map<String, dynamic>> upcomingSprints;
  final int totalCount;

  const WorkSprintDashboardState({
    this.isLoading = false,
    this.sprint,
    this.metrics = const {},
    this.burndownPoints = const [],
    this.items = const [],
    this.teamMembers = const [],
    this.blockers = const [],
    this.retroData = const {},
    this.progressByType = const [],
    this.upcomingSprints = const [],
    this.totalCount = 42,
  });

  WorkSprintDashboardState copyWith({
    bool? isLoading,
    WorkSprintModel? sprint,
    Map<String, dynamic>? metrics,
    List<BurndownPointModel>? burndownPoints,
    List<WorkItemModel>? items,
    List<SprintMemberModel>? teamMembers,
    List<SprintBlockerModel>? blockers,
    Map<String, dynamic>? retroData,
    List<Map<String, dynamic>>? progressByType,
    List<Map<String, dynamic>>? upcomingSprints,
    int? totalCount,
  }) {
    return WorkSprintDashboardState(
      isLoading: isLoading ?? this.isLoading,
      sprint: sprint ?? this.sprint,
      metrics: metrics ?? this.metrics,
      burndownPoints: burndownPoints ?? this.burndownPoints,
      items: items ?? this.items,
      teamMembers: teamMembers ?? this.teamMembers,
      blockers: blockers ?? this.blockers,
      retroData: retroData ?? this.retroData,
      progressByType: progressByType ?? this.progressByType,
      upcomingSprints: upcomingSprints ?? this.upcomingSprints,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

class WorkSprintDashboardNotifier extends StateNotifier<WorkSprintDashboardState> {
  final Ref? _ref;
  final WorkApiService _api;

  String _lastSprintId = 'active';
  String? _lastBoardId;
  String? _lastTeam;
  String? _lastSearch;
  int _lastPage = 1;
  int _lastPageSize = 10;

  WorkSprintDashboardNotifier([Ref? ref, WorkApiService? api])
      : _ref = ref,
        _api = api ?? (ref != null ? ref.read(workApiServiceProvider) : WorkApiService.instance),
        super(const WorkSprintDashboardState(isLoading: true)) {
    loadSprintDashboard();
  }

  void optimisticallyUpdateItemStatus(String itemId, String newStatus) {
    final cleanStatus = newStatus.trim().toUpperCase();
    final updatedItems = state.items.map((story) {
      if (story.id == itemId) {
        return story.copyWith(
          status: cleanStatus,
          progressPercentage: (cleanStatus == 'COMPLETED' || cleanStatus == 'RESOLVED') ? 100 : (cleanStatus == 'NEW' ? 0 : 50),
        );
      }
      final updatedChildren = story.children.map((child) {
        if (child.id == itemId) {
          return child.copyWith(
            status: cleanStatus,
            progressPercentage: (cleanStatus == 'COMPLETED' || cleanStatus == 'RESOLVED') ? 100 : (cleanStatus == 'NEW' ? 0 : 50),
          );
        }
        return child;
      }).toList();
      return story.copyWith(children: updatedChildren);
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  Future<void> loadSprintDashboard({
    String sprintId = 's8',
    String? boardId,
    String? team,
    String? search,
    int page = 1,
    int pageSize = 10,
    bool quiet = false,
    bool forceRefresh = false,
  }) async {
    if (sprintId.isNotEmpty && sprintId != 's8') {
      _lastSprintId = sprintId;
    } else if (sprintId == 's8' && _lastSprintId != 's8') {
      // Keep _lastSprintId unless explicitly requested
    } else {
      _lastSprintId = sprintId;
    }
    if (boardId != null) _lastBoardId = boardId;
    if (team != null) _lastTeam = team;
    if (search != null) _lastSearch = search;
    _lastPage = page;
    _lastPageSize = pageSize;

    if (!quiet) {
      state = state.copyWith(isLoading: true);
    }
    try {
      if (forceRefresh) {
        _api.invalidateCache();
      }
      final res = await _api.getSprintDashboard(
        _lastSprintId,
        boardId: _lastBoardId,
        team: _lastTeam ?? 'All Teams',
        search: _lastSearch,
        page: _lastPage,
        pageSize: _lastPageSize,
        forceRefresh: forceRefresh,
      );
      final items = (res['items'] as List<WorkItemModel>?) ?? [];
      final burndown = (res['burndown'] as List<BurndownPointModel>?) ?? [];
      final kpis = (res['kpis'] as Map<String, dynamic>?) ?? {};
      final teamMembers = (res['team_members'] as List<SprintMemberModel>?) ?? [];
      final blockers = (res['blockers'] as List<SprintBlockerModel>?) ?? [];
      final retro = (res['retrospective'] as Map<String, dynamic>?) ?? {};
      final rawProgress = res['progress_by_type'];
      List<Map<String, dynamic>> progressByType = [];
      if (rawProgress is List) {
        progressByType = rawProgress.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      final rawUpcoming = res['upcoming_sprints'];
      List<Map<String, dynamic>> upcomingSprints = [];
      if (rawUpcoming is List) {
        upcomingSprints = rawUpcoming.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      final sprintModel = WorkSprintModel(
        id: res['sprint_id']?.toString() ?? _lastSprintId,
        name: res['sprint_name'] ?? 'Sprint 8',
        sprintNumber: (res['sprint_number'] as num?)?.toInt() ?? 8,
        status: res['status'] ?? 'ACTIVE',
        goal: res['goal'] ?? 'Deliver student portal enhancement, examination notifications and key infrastructure fixes.',
        durationDays: (res['duration_days'] as num?)?.toInt() ?? 14,
        teamName: res['team_name'] ?? 'Digital Campus Team',
        boardId: res['board_id']?.toString(),
        boardName: res['board_name'] ?? 'Institute Work Board',
        startDateFmt: (res['start_date_fmt'] != null && !res['start_date_fmt'].toString().contains('2025'))
            ? res['start_date_fmt']
            : WorkSprintDateHelper.currentSprintStartFmt,
        endDateFmt: (res['end_date_fmt'] != null && !res['end_date_fmt'].toString().contains('2025'))
            ? res['end_date_fmt']
            : WorkSprintDateHelper.currentSprintEndFmt,
        capacityHours: (res['capacity_hours'] as num?)?.toDouble() ?? 160.0,
        workingDays: (res['working_days'] as num?)?.toInt() ?? 10,
        workingHoursPerDay: (res['working_hours_per_day'] as num?)?.toDouble() ?? 8.0,
        ownerName: res['owner_name'],
        capacityUnit: res['capacity_unit'] ?? 'HOURS',
        color: res['color'] ?? '#2563EB',
      );

      _lastSprintId = sprintModel.id;

      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        sprint: sprintModel,
        metrics: kpis,
        burndownPoints: burndown,
        items: items,
        teamMembers: teamMembers,
        blockers: blockers,
        retroData: retro,
        progressByType: progressByType,
        upcomingSprints: upcomingSprints,
        totalCount: (res['total_items_count'] as num?)?.toInt() ?? items.length,
      );

      if (_ref != null && sprintModel.id.isNotEmpty && mounted) {
        _ref!.read(allSprintsProvider.notifier).selectSprint(sprintModel.id);
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<bool> updateSprint(String sprintId, Map<String, dynamic> data) async {
    final success = await _api.updateSprint(sprintId, data);
    if (success) {
      await loadSprintDashboard(sprintId: sprintId, forceRefresh: true);
      _ref?.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
      _ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
      _ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      _ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
    }
    return success;
  }

  Future<bool> startSprint(String sprintId) async {
    final success = await _api.startSprint(sprintId);
    if (success) {
      await loadSprintDashboard(sprintId: sprintId, forceRefresh: true);
      _ref?.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
      _ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
      _ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      _ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
    }
    return success;
  }

  Future<bool> completeSprint(String sprintId, {String? moveIncompleteToSprintId, String? notes}) async {
    final success = await _api.completeSprint(sprintId, moveIncompleteToSprintId: moveIncompleteToSprintId, notes: notes);
    if (success) {
      await loadSprintDashboard(sprintId: sprintId, forceRefresh: true);
      _ref?.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
      _ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
      _ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      _ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
    }
    return success;
  }

  Future<bool> cancelSprint(String sprintId, {String? reason}) async {
    final success = await _api.cancelSprint(sprintId, reason: reason);
    if (success) {
      await loadSprintDashboard(sprintId: sprintId, forceRefresh: true);
      _ref?.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
      _ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
      _ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      _ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
    }
    return success;
  }

  Future<bool> addItemsToSprint(String sprintId, List<String> itemIds) async {
    final success = await _api.addItemsToSprint(sprintId, itemIds);
    if (success) {
      await loadSprintDashboard(sprintId: sprintId, forceRefresh: true);
      _ref?.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
      _ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
      _ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      _ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
    }
    return success;
  }

  Future<bool> removeItemFromSprint(String sprintId, String itemId) async {
    // 1. Optimistic removal from state.items immediately
    final previousItems = state.items;
    final previousTotal = state.totalCount;
    final idUpper = itemId.toUpperCase();
    final updatedItems = state.items.where((i) => i.id.toUpperCase() != idUpper && i.itemNumber.toUpperCase() != idUpper).map((story) {
      final updatedChildren = story.children.where((c) => c.id.toUpperCase() != idUpper && c.itemNumber.toUpperCase() != idUpper).toList();
      return story.copyWith(children: updatedChildren);
    }).toList();
    final removedCount = previousItems.length - updatedItems.length;
    state = state.copyWith(
      items: updatedItems,
      totalCount: (previousTotal - (removedCount > 0 ? removedCount : 1)).clamp(0, 999999),
    );

    final success = await _api.removeItemFromSprint(sprintId, itemId);
    if (success) {
      await loadSprintDashboard(sprintId: sprintId, forceRefresh: true);
      _ref?.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
      _ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
      _ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      _ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
    } else {
      state = state.copyWith(items: previousItems, totalCount: previousTotal);
    }
    return success;
  }

  Future<bool> moveItemsToSprint(String sprintId, String targetSprintId, List<String> itemIds) async {
    // 1. Optimistic removal from state.items immediately
    final previousItems = state.items;
    final previousTotal = state.totalCount;
    final idSet = itemIds.map((id) => id.toUpperCase()).toSet();
    final updatedItems = state.items.where((i) => !idSet.contains(i.id.toUpperCase()) && !idSet.contains(i.itemNumber.toUpperCase())).map((story) {
      final updatedChildren = story.children.where((c) => !idSet.contains(c.id.toUpperCase()) && !idSet.contains(c.itemNumber.toUpperCase())).toList();
      return story.copyWith(children: updatedChildren);
    }).toList();
    final removedCount = previousItems.length - updatedItems.length;
    state = state.copyWith(
      items: updatedItems,
      totalCount: (previousTotal - (removedCount > 0 ? removedCount : itemIds.length)).clamp(0, 999999),
    );

    final success = await _api.moveItemsToSprint(sprintId, targetSprintId, itemIds);
    if (success) {
      await loadSprintDashboard(sprintId: sprintId, forceRefresh: true);
      _ref?.read(allSprintsProvider.notifier).loadSprints(forceRefresh: true);
      _ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
      _ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      _ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
    } else {
      state = state.copyWith(items: previousItems, totalCount: previousTotal);
    }
    return success;
  }

  Future<bool> manageSprintMember(
    String sprintId, {
    required String userId,
    String? role,
    double? availableHours,
    String action = 'UPSERT',
  }) async {
    final success = await _api.manageSprintMember(
      sprintId,
      userId: userId,
      role: role,
      availableHours: availableHours,
      action: action,
    );
    if (success) {
      await loadSprintDashboard(sprintId: sprintId);
    }
    return success;
  }

  Future<bool> removeSprintMember(String sprintId, String userId) async {
    final success = await _api.removeSprintMember(sprintId, userId);
    if (success) {
      await loadSprintDashboard(sprintId: sprintId);
    }
    return success;
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
    final success = await _api.manageSprintBlocker(
      sprintId,
      blockerId: blockerId,
      workItemId: workItemId,
      title: title,
      description: description,
      severity: severity,
      status: status,
      ownerId: ownerId,
      expectedResolutionDate: expectedResolutionDate,
      resolutionNotes: resolutionNotes,
      action: action,
    );
    if (success) {
      await loadSprintDashboard(sprintId: sprintId);
    }
    return success;
  }

  Future<bool> deleteSprintBlocker(String sprintId, String blockerId) async {
    final success = await _api.deleteSprintBlocker(sprintId, blockerId);
    if (success) {
      await loadSprintDashboard(sprintId: sprintId);
    }
    return success;
  }

  Future<bool> addRetroEntry(String sprintId, {required String category, required String content}) async {
    final success = await _api.addRetroEntry(sprintId, category: category, content: content);
    if (success) {
      await loadSprintDashboard(sprintId: sprintId);
    }
    return success;
  }

  Future<bool> deleteRetroEntry(String sprintId, String entryId) async {
    final success = await _api.deleteRetroEntry(sprintId, entryId);
    if (success) {
      await loadSprintDashboard(sprintId: sprintId);
    }
    return success;
  }

  Future<bool> voteRetroEntry(String sprintId, String entryId) async {
    final success = await _api.voteRetroEntry(sprintId, entryId);
    if (success) {
      await loadSprintDashboard(sprintId: sprintId);
    }
    return success;
  }

  Future<bool> addActionItem(
    String sprintId, {
    required String title,
    String? description,
    String? ownerId,
    String? dueDate,
    String priority = 'MEDIUM',
    String status = 'OPEN',
    String? linkedWorkItemId,
  }) async {
    final success = await _api.addActionItem(
      sprintId,
      title: title,
      description: description,
      ownerId: ownerId,
      dueDate: dueDate,
      priority: priority,
      status: status,
      linkedWorkItemId: linkedWorkItemId,
    );
    if (success) {
      await loadSprintDashboard(sprintId: sprintId);
    }
    return success;
  }

  Future<bool> updateActionItem(
    String sprintId,
    String actionItemId,
    Map<String, dynamic> data,
  ) async {
    final success = await _api.updateActionItem(sprintId, actionItemId, data);
    if (success) {
      await loadSprintDashboard(sprintId: sprintId);
    }
    return success;
  }

  Future<bool> deleteActionItem(String sprintId, String actionItemId) async {
    final success = await _api.deleteActionItem(sprintId, actionItemId);
    if (success) {
      await loadSprintDashboard(sprintId: sprintId);
    }
    return success;
  }
}

final workSprintDashboardProvider =
    StateNotifierProvider<WorkSprintDashboardNotifier, WorkSprintDashboardState>((ref) {
  return WorkSprintDashboardNotifier(ref, ref.read(workApiServiceProvider));
});

// ==========================================
// 6. SPRINT CAPACITY TAB STATE & NOTIFIER
// ==========================================
class WorkSprintCapacityState {
  final bool isLoading;
  final SprintCapacityDashboardModel? dashboard;
  final List<SprintCapacityTeamModel> availableTeams;
  final String selectedTeam;
  final String sprintId;
  final String? errorMessage;
  final String searchQuery;
  final String selectedRole;
  final String selectedStatus;
  final String sortBy;
  final String sortOrder;
  final int currentPage;
  final int rowsPerPage;
  final List<SprintCapacityMemberModel> allMembers;

  const WorkSprintCapacityState({
    this.isLoading = false,
    this.dashboard,
    this.availableTeams = const [],
    this.selectedTeam = 'Digital Campus Team',
    this.sprintId = 's8',
    this.errorMessage,
    this.searchQuery = '',
    this.selectedRole = 'All',
    this.selectedStatus = 'All',
    this.sortBy = 'name',
    this.sortOrder = 'asc',
    this.currentPage = 1,
    this.rowsPerPage = 10,
    this.allMembers = const [],
  });

  WorkSprintCapacityState copyWith({
    bool? isLoading,
    SprintCapacityDashboardModel? dashboard,
    List<SprintCapacityTeamModel>? availableTeams,
    String? selectedTeam,
    String? sprintId,
    String? errorMessage,
    String? searchQuery,
    String? selectedRole,
    String? selectedStatus,
    String? sortBy,
    String? sortOrder,
    int? currentPage,
    int? rowsPerPage,
    List<SprintCapacityMemberModel>? allMembers,
  }) {
    return WorkSprintCapacityState(
      isLoading: isLoading ?? this.isLoading,
      dashboard: dashboard ?? this.dashboard,
      availableTeams: availableTeams ?? this.availableTeams,
      selectedTeam: selectedTeam ?? this.selectedTeam,
      sprintId: sprintId ?? this.sprintId,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedRole: selectedRole ?? this.selectedRole,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      currentPage: currentPage ?? this.currentPage,
      rowsPerPage: rowsPerPage ?? this.rowsPerPage,
      allMembers: allMembers ?? this.allMembers,
    );
  }
}

class WorkSprintCapacityNotifier extends StateNotifier<WorkSprintCapacityState> {
  final WorkApiService _api = WorkApiService.instance;

  WorkSprintCapacityNotifier()
      : super(WorkSprintCapacityState(
          isLoading: false,
          dashboard: _buildDefaultDashboard('s8', 'Digital Campus Team'),
        )) {
    init();
  }

  static SprintCapacityDashboardModel _buildDefaultDashboard(String sid, String teamName) {
    return SprintCapacityDashboardModel(
      sprintId: sid,
      sprintName: 'Sprint 8',
      sprintDuration: WorkSprintDateHelper.currentSprintFullDurationRange,
      boardName: 'Institute Work Board',
      selectedTeam: teamName,
      kpis: const SprintCapacityKpisModel(
        teamMembers: 7,
        totalCapacityHours: 280.0,
        plannedWorkHours: 257.0,
        actualWorkHours: 217.0,
        remainingCapacityHours: 23.0,
        utilizationPct: 91.8,
        overAllocationHours: 0.0,
        overloadedMembersCount: 1,
      ),
      teams: const [
        SprintCapacityTeamModel(id: '1', name: 'Digital Campus Team', icon: 'groups', isSelected: true),
        SprintCapacityTeamModel(id: '2', name: 'Academic Systems Team', icon: 'school'),
        SprintCapacityTeamModel(id: '3', name: 'Examination Team', icon: 'assignment_turned_in'),
        SprintCapacityTeamModel(id: '4', name: 'IT Operations Team', icon: 'computer'),
        SprintCapacityTeamModel(id: '5', name: 'Infrastructure & Maintenance Team', icon: 'apartment'),
        SprintCapacityTeamModel(id: '6', name: 'Library Systems Team', icon: 'menu_book'),
      ],
      members: const [
        SprintCapacityMemberModel(
          id: '1',
          userId: '55555555-0001-0000-0000-000000000001',
          fullName: 'Neha Sharma',
          role: 'Team Lead',
          capacityHours: 40.0,
          plannedHours: 38.0,
          actualHours: 32.0,
          remainingHours: 8.0,
          utilizationPct: 95.0,
          workItemsCount: 8,
          status: 'High',
        ),
        SprintCapacityMemberModel(
          id: '2',
          userId: '55555555-0002-0000-0000-000000000002',
          fullName: 'Amit Kumar',
          role: 'Senior Developer',
          capacityHours: 40.0,
          plannedHours: 36.0,
          actualHours: 31.0,
          remainingHours: 9.0,
          utilizationPct: 90.0,
          workItemsCount: 7,
          status: 'Balanced',
        ),
        SprintCapacityMemberModel(
          id: '3',
          userId: '55555555-0003-0000-0000-000000000003',
          fullName: 'Priya Singh',
          role: 'UI/UX Designer',
          capacityHours: 40.0,
          plannedHours: 32.0,
          actualHours: 28.0,
          remainingHours: 12.0,
          utilizationPct: 80.0,
          workItemsCount: 6,
          status: 'Balanced',
        ),
        SprintCapacityMemberModel(
          id: '4',
          userId: '55555555-0004-0000-0000-000000000004',
          fullName: 'Rahul Mehta',
          role: 'Backend Developer',
          capacityHours: 40.0,
          plannedHours: 40.0,
          actualHours: 36.0,
          remainingHours: 4.0,
          utilizationPct: 100.0,
          workItemsCount: 8,
          status: 'High',
        ),
        SprintCapacityMemberModel(
          id: '5',
          userId: '55555555-0005-0000-0000-000000000005',
          fullName: 'Sneha Verma',
          role: 'QA Engineer',
          capacityHours: 40.0,
          plannedHours: 34.0,
          actualHours: 28.0,
          remainingHours: 12.0,
          utilizationPct: 85.0,
          workItemsCount: 6,
          status: 'Balanced',
        ),
        SprintCapacityMemberModel(
          id: '6',
          userId: '55555555-0006-0000-0000-000000000006',
          fullName: 'Vikas Gupta',
          role: 'DevOps Engineer',
          capacityHours: 40.0,
          plannedHours: 36.0,
          actualHours: 32.0,
          remainingHours: 8.0,
          utilizationPct: 90.0,
          workItemsCount: 7,
          status: 'Balanced',
        ),
        SprintCapacityMemberModel(
          id: '7',
          userId: '55555555-0007-0000-0000-000000000007',
          fullName: 'Karan Jain',
          role: 'System Analyst',
          capacityHours: 40.0,
          plannedHours: 41.0,
          actualHours: 30.0,
          remainingHours: 10.0,
          utilizationPct: 102.5,
          workItemsCount: 6,
          status: 'Overloaded',
        ),
      ],
      dailyChart: WorkSprintDateHelper.generateDailyCapacityPoints(),
      utilization: const SprintCapacityUtilizationModel(
        plannedHours: 257.0,
        availableHours: 23.0,
        totalCapacityHours: 280.0,
        plannedPct: 91.8,
        availablePct: 8.2,
      ),
      summary: const SprintCapacitySummaryModel(
        totalTeamCapacity: '280 h',
        plannedCommittedWork: '257 h',
        actualWorkCompleted: '217 h',
        remainingCapacity: '23 h',
        utilization: '91.80%',
        overAllocation: '0 h',
      ),
      insights: const [
        SprintCapacityInsightModel(type: 'SUCCESS', icon: 'check_circle', text: 'Team is within capacity (91.8% utilization).'),
        SprintCapacityInsightModel(type: 'WARNING', icon: 'warning', text: '1 member is over-allocated (Karan Jain – 102.5%).'),
        SprintCapacityInsightModel(type: 'INFO', icon: 'info', text: '23 h capacity available for additional high-priority work.'),
        SprintCapacityInsightModel(type: 'INFO', icon: 'info', text: 'Average capacity per member: 40 h (planned: 36.7 h).'),
      ],
    );
  }

  Future<void> init({String sprintId = 's8', String team = 'Digital Campus Team'}) async {
    state = state.copyWith(sprintId: sprintId, selectedTeam: team);
    await Future.wait([
      loadTeams(),
      loadCapacity(sprintId: sprintId, team: team),
    ]);
  }

  Future<void> loadTeams() async {
    try {
      final teams = await _api.getCapacityTeams();
      if (teams.isNotEmpty) {
        state = state.copyWith(availableTeams: teams);
      }
    } catch (_) {}
  }

  Future<void> loadCapacity({
    String? sprintId,
    String? team,
    String? search,
    String? role,
    String? status,
    String? sortBy,
    String? sortOrder,
    int? page,
    int? limit,
    bool forceRefresh = false,
  }) async {
    final sid = sprintId ?? state.sprintId;
    final t = team ?? state.selectedTeam;
    final q = search ?? state.searchQuery;
    final r = role ?? state.selectedRole;
    final st = status ?? state.selectedStatus;
    final sb = sortBy ?? state.sortBy;
    final so = sortOrder ?? state.sortOrder;
    final p = page ?? state.currentPage;
    final l = limit ?? state.rowsPerPage;

    try {
      final dash = await _api.getSprintCapacityDashboard(
        sid,
        team: t,
        search: q,
        role: r,
        status: st,
        sortBy: sb,
        sortOrder: so,
        page: p,
        limit: l,
        forceRefresh: forceRefresh,
      );
      final finalDash = dash ?? _buildDefaultDashboard(sid, t);
      state = state.copyWith(
        isLoading: false,
        dashboard: finalDash,
        sprintId: sid,
        selectedTeam: t,
        searchQuery: q,
        selectedRole: r,
        selectedStatus: st,
        sortBy: sb,
        sortOrder: so,
        currentPage: p,
        rowsPerPage: l,
        allMembers: finalDash.members.isNotEmpty ? finalDash.members : state.allMembers,
      );
    } catch (e) {
      final defDash = _buildDefaultDashboard(sid, t);
      state = state.copyWith(
        isLoading: false,
        dashboard: defDash,
        sprintId: sid,
        selectedTeam: t,
        searchQuery: q,
        selectedRole: r,
        selectedStatus: st,
        sortBy: sb,
        sortOrder: so,
        currentPage: p,
        rowsPerPage: l,
      );
    }
  }

  void selectSprint(String sprintId) {
    if (state.sprintId == sprintId) return;
    state = state.copyWith(sprintId: sprintId, currentPage: 1);
    loadCapacity(sprintId: sprintId, page: 1, forceRefresh: true);
  }

  void selectTeam(String team) {
    if (state.selectedTeam == team) return;
    state = state.copyWith(selectedTeam: team, currentPage: 1);
    loadCapacity(team: team, page: 1, forceRefresh: true);
  }

  void setSearch(String q) {
    state = state.copyWith(searchQuery: q, currentPage: 1);
    loadCapacity(search: q, page: 1);
  }

  void setRoleFilter(String role) {
    state = state.copyWith(selectedRole: role, currentPage: 1);
    loadCapacity(role: role, page: 1);
  }

  void setStatusFilter(String status) {
    state = state.copyWith(selectedStatus: status, currentPage: 1);
    loadCapacity(status: status, page: 1);
  }

  void setSorting(String column) {
    final newOrder = (state.sortBy == column && state.sortOrder == 'asc') ? 'desc' : 'asc';
    state = state.copyWith(sortBy: column, sortOrder: newOrder);
    loadCapacity(sortBy: column, sortOrder: newOrder);
  }

  void setPage(int page) {
    if (page == state.currentPage || page < 1) return;
    state = state.copyWith(currentPage: page);
    loadCapacity(page: page);
  }

  void setRowsPerPage(int limit) {
    if (limit == state.rowsPerPage) return;
    state = state.copyWith(rowsPerPage: limit, currentPage: 1);
    loadCapacity(limit: limit, page: 1);
  }

  void resetFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedRole: 'All',
      selectedStatus: 'All',
      currentPage: 1,
    );
    loadCapacity(search: '', role: 'All', status: 'All', page: 1);
  }

  Future<bool> manageMemberCapacity({
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
    final success = await _api.manageMemberCapacity(
      state.sprintId,
      userId: userId,
      capacityHours: capacityHours,
      dailyWorkingHours: dailyWorkingHours,
      workingDays: workingDays,
      role: role,
      teamName: teamName ?? state.selectedTeam,
      overrideValue: overrideValue,
      overrideReason: overrideReason,
      notes: notes,
    );
    if (success) {
      await loadCapacity();
    }
    return success;
  }

  Future<bool> removeMember(String userId) async {
    final success = await _api.removeCapacityMember(state.sprintId, userId);
    if (success) {
      await loadCapacity();
    }
    return success;
  }

  Future<bool> manageAvailability({
    required String userId,
    required String startDate,
    required String endDate,
    double unavailableHours = 8.0,
    String? reason,
  }) async {
    final success = await _api.manageCapacityAvailability(
      state.sprintId,
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      unavailableHours: unavailableHours,
      reason: reason,
    );
    if (success) {
      await loadCapacity();
    }
    return success;
  }

  Future<bool> deleteAvailability(String availabilityId) async {
    final success = await _api.deleteCapacityAvailability(state.sprintId, availabilityId);
    if (success) {
      await loadCapacity();
    }
    return success;
  }

  Future<bool> rebalanceWorkload({
    required String workItemId,
    required String fromUserId,
    required String toUserId,
    String? reason,
  }) async {
    final success = await _api.rebalanceWorkload(
      state.sprintId,
      workItemId: workItemId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      reason: reason,
    );
    if (success) {
      await loadCapacity();
    }
    return success;
  }

  Future<String?> exportCsv() async {
    return await _api.exportCapacityCsv(state.sprintId, team: state.selectedTeam);
  }
}

final workSprintCapacityProvider =
    StateNotifierProvider<WorkSprintCapacityNotifier, WorkSprintCapacityState>((ref) {
  return WorkSprintCapacityNotifier();
});

// ============================================================================
// ENTERPRISE SPRINT TEAM MANAGEMENT NOTIFIER & PROVIDER
// ============================================================================

class WorkSprintTeamState {
  final bool isLoading;
  final bool isDetailLoading;
  final String? errorMessage;
  final String sprintId;
  final TeamKpisModel kpis;
  final List<TeamDirectoryItemModel> teams;
  final int totalCount;
  final int currentPage;
  final int rowsPerPage;
  final String? selectedTeamId;
  final TeamDetailModel? selectedTeamDetail;
  final bool isDrawerOpen;
  final String activeDrawerTab; // 'Overview', 'Members', 'Capacity', 'Work Items', 'Settings'
  final String searchQuery;
  final String statusFilter; // 'ALL', 'ACTIVE', 'INACTIVE'
  final String departmentFilter; // 'ALL', 'IT & Digitalization', 'Academics', ...
  final String sortBy; // 'NAME_ASC', 'NAME_DESC', 'CAPACITY_DESC', 'UTIL_DESC', 'MEMBERS_DESC'
  final bool isGridView;
  final Set<String> selectedTeamIds;

  const WorkSprintTeamState({
    this.isLoading = false,
    this.isDetailLoading = false,
    this.errorMessage,
    this.sprintId = '',
    this.kpis = const TeamKpisModel(),
    this.teams = const [],
    this.totalCount = 0,
    this.currentPage = 1,
    this.rowsPerPage = 10,
    this.selectedTeamId,
    this.selectedTeamDetail,
    this.isDrawerOpen = true,
    this.activeDrawerTab = 'Overview',
    this.searchQuery = '',
    this.statusFilter = 'ALL',
    this.departmentFilter = 'ALL',
    this.sortBy = 'NAME_ASC',
    this.isGridView = false,
    this.selectedTeamIds = const {},
  });

  WorkSprintTeamState copyWith({
    bool? isLoading,
    bool? isDetailLoading,
    String? errorMessage,
    String? sprintId,
    TeamKpisModel? kpis,
    List<TeamDirectoryItemModel>? teams,
    int? totalCount,
    int? currentPage,
    int? rowsPerPage,
    String? selectedTeamId,
    TeamDetailModel? selectedTeamDetail,
    bool? isDrawerOpen,
    String? activeDrawerTab,
    String? searchQuery,
    String? statusFilter,
    String? departmentFilter,
    String? sortBy,
    bool? isGridView,
    Set<String>? selectedTeamIds,
  }) {
    return WorkSprintTeamState(
      isLoading: isLoading ?? this.isLoading,
      isDetailLoading: isDetailLoading ?? this.isDetailLoading,
      errorMessage: errorMessage,
      sprintId: sprintId ?? this.sprintId,
      kpis: kpis ?? this.kpis,
      teams: teams ?? this.teams,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      rowsPerPage: rowsPerPage ?? this.rowsPerPage,
      selectedTeamId: selectedTeamId ?? this.selectedTeamId,
      selectedTeamDetail: selectedTeamDetail ?? this.selectedTeamDetail,
      isDrawerOpen: isDrawerOpen ?? this.isDrawerOpen,
      activeDrawerTab: activeDrawerTab ?? this.activeDrawerTab,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      departmentFilter: departmentFilter ?? this.departmentFilter,
      sortBy: sortBy ?? this.sortBy,
      isGridView: isGridView ?? this.isGridView,
      selectedTeamIds: selectedTeamIds ?? this.selectedTeamIds,
    );
  }
}

class WorkSprintTeamNotifier extends StateNotifier<WorkSprintTeamState> {
  final WorkApiService _api = WorkApiService.instance;

  WorkSprintTeamNotifier() : super(const WorkSprintTeamState());

  Future<void> init(String sprintId) async {
    state = state.copyWith(sprintId: sprintId);
    await loadTeams();
  }

  Future<void> loadTeams({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }
    final resp = await _api.getTeamsDirectory(
      sprintId: state.sprintId,
      status: state.statusFilter,
      department: state.departmentFilter,
      search: state.searchQuery,
      sortBy: state.sortBy,
      page: state.currentPage,
      limit: state.rowsPerPage,
    );

    if (resp != null) {
      final teams = resp.teams;
      String? currentSelected = state.selectedTeamId;
      if (currentSelected == null || !teams.any((t) => t.id == currentSelected)) {
        currentSelected = teams.isNotEmpty ? teams.first.id : null;
      }

      state = state.copyWith(
        isLoading: false,
        kpis: resp.kpis,
        teams: teams,
        totalCount: resp.totalCount,
        selectedTeamId: currentSelected,
        isDrawerOpen: currentSelected != null,
      );

      if (currentSelected != null) {
        await loadTeamDetail(currentSelected, silent: true);
      }
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> selectTeam(String teamId) async {
    state = state.copyWith(
      selectedTeamId: teamId,
      isDrawerOpen: true,
      activeDrawerTab: 'Overview',
    );
    await loadTeamDetail(teamId);
  }

  Future<void> loadTeamDetail(String teamId, {bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isDetailLoading: true);
    }
    final detail = await _api.getTeamDetail(teamId, sprintId: state.sprintId);
    if (detail != null) {
      state = state.copyWith(
        isDetailLoading: false,
        selectedTeamDetail: detail,
      );
    } else {
      state = state.copyWith(isDetailLoading: false);
    }
  }

  void closeDrawer() {
    state = state.copyWith(isDrawerOpen: false);
  }

  void setDrawerTab(String tab) {
    state = state.copyWith(activeDrawerTab: tab);
  }

  void setSearchQuery(String q) {
    state = state.copyWith(searchQuery: q, currentPage: 1);
    loadTeams();
  }

  void setStatusFilter(String status) {
    state = state.copyWith(statusFilter: status, currentPage: 1);
    loadTeams();
  }

  void setDepartmentFilter(String dept) {
    state = state.copyWith(departmentFilter: dept, currentPage: 1);
    loadTeams();
  }

  void setSortBy(String sort) {
    state = state.copyWith(sortBy: sort);
    loadTeams();
  }

  void toggleViewMode(bool isGrid) {
    state = state.copyWith(isGridView: isGrid);
  }

  void setPage(int p) {
    state = state.copyWith(currentPage: p);
    loadTeams();
  }

  void setRowsPerPage(int r) {
    state = state.copyWith(rowsPerPage: r, currentPage: 1);
    loadTeams();
  }

  void toggleTeamSelection(String teamId) {
    final next = Set<String>.from(state.selectedTeamIds);
    if (next.contains(teamId)) {
      next.remove(teamId);
    } else {
      next.add(teamId);
    }
    state = state.copyWith(selectedTeamIds: next);
  }

  void toggleAllSelection(bool selectAll) {
    if (selectAll) {
      state = state.copyWith(selectedTeamIds: state.teams.map((t) => t.id).toSet());
    } else {
      state = state.copyWith(selectedTeamIds: {});
    }
  }

  Future<bool> createTeam(Map<String, dynamic> data) async {
    final success = await _api.createWorkTeam(data);
    if (success) {
      await loadTeams();
    }
    return success;
  }

  Future<bool> updateTeam(String teamId, Map<String, dynamic> data) async {
    final success = await _api.updateWorkTeam(teamId, data);
    if (success) {
      await loadTeams(silent: true);
      if (state.selectedTeamId == teamId) {
        await loadTeamDetail(teamId, silent: true);
      }
    }
    return success;
  }

  Future<bool> duplicateTeam(String teamId, {String? newName, String? newKey}) async {
    final success = await _api.duplicateWorkTeam(teamId, newName: newName, newKey: newKey);
    if (success) {
      await loadTeams();
    }
    return success;
  }

  Future<bool> deleteTeam(String teamId, {bool hard = false}) async {
    final success = await _api.deleteWorkTeam(teamId, hard: hard);
    if (success) {
      if (state.selectedTeamId == teamId) {
        state = state.copyWith(selectedTeamId: null, selectedTeamDetail: null);
      }
      await loadTeams();
    }
    return success;
  }

  Future<bool> addMember(String teamId, Map<String, dynamic> data) async {
    final success = await _api.addTeamMember(teamId, data);
    if (success) {
      await loadTeams(silent: true);
      if (state.selectedTeamId == teamId) {
        await loadTeamDetail(teamId, silent: true);
      }
    }
    return success;
  }

  Future<bool> removeMember(String teamId, String userId) async {
    final success = await _api.removeTeamMember(teamId, userId);
    if (success) {
      await loadTeams(silent: true);
      if (state.selectedTeamId == teamId) {
        await loadTeamDetail(teamId, silent: true);
      }
    }
    return success;
  }

  Future<String?> exportCsv() async {
    return await _api.exportTeamsCsv(
      sprintId: state.sprintId,
      status: state.statusFilter,
      department: state.departmentFilter,
      search: state.searchQuery,
    );
  }
}

final workSprintTeamProvider =
    StateNotifierProvider<WorkSprintTeamNotifier, WorkSprintTeamState>((ref) {
  return WorkSprintTeamNotifier();
});

// ============================================================================
// Sprint Retrospective State & Notifier
// ============================================================================

class WorkSprintRetroState {
  final bool isLoading;
  final bool isSaving;
  final String sprintId;
  final String? teamId;
  final SprintRetroWorkspaceModel? workspace;
  final String activeTab; // 'Discussion Board', 'Action Items (5)', 'Notes & Summary', 'Feedback', 'History'
  final String searchQuery;
  final String actionStatusFilter; // 'ALL', 'OPEN', 'IN_PROGRESS', 'PLANNED', 'COMPLETED'
  final Set<String> selectedActionItemIds;
  final SprintRetroActionItemModel? selectedActionItem;
  final bool isDrawerOpen;
  final List<WorkAssigneeModel> assignableUsers;
  final String? errorMessage;

  const WorkSprintRetroState({
    this.isLoading = false,
    this.isSaving = false,
    this.sprintId = '',
    this.teamId,
    this.workspace,
    this.activeTab = 'Discussion Board',
    this.searchQuery = '',
    this.actionStatusFilter = 'ALL',
    this.selectedActionItemIds = const {},
    this.selectedActionItem,
    this.isDrawerOpen = false,
    this.assignableUsers = const [],
    this.errorMessage,
  });

  WorkSprintRetroState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? sprintId,
    String? teamId,
    SprintRetroWorkspaceModel? workspace,
    String? activeTab,
    String? searchQuery,
    String? actionStatusFilter,
    Set<String>? selectedActionItemIds,
    SprintRetroActionItemModel? selectedActionItem,
    bool? isDrawerOpen,
    List<WorkAssigneeModel>? assignableUsers,
    String? errorMessage,
  }) {
    return WorkSprintRetroState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      sprintId: sprintId ?? this.sprintId,
      teamId: teamId ?? this.teamId,
      workspace: workspace ?? this.workspace,
      activeTab: activeTab ?? this.activeTab,
      searchQuery: searchQuery ?? this.searchQuery,
      actionStatusFilter: actionStatusFilter ?? this.actionStatusFilter,
      selectedActionItemIds: selectedActionItemIds ?? this.selectedActionItemIds,
      selectedActionItem: selectedActionItem ?? this.selectedActionItem,
      isDrawerOpen: isDrawerOpen ?? this.isDrawerOpen,
      assignableUsers: assignableUsers ?? this.assignableUsers,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class WorkSprintRetroNotifier extends StateNotifier<WorkSprintRetroState> {
  final WorkApiService _api;

  WorkSprintRetroNotifier([Ref? ref, WorkApiService? api])
      : _api = api ?? (ref != null ? ref.read(workApiServiceProvider) : WorkApiService.instance),
        super(const WorkSprintRetroState());

  Future<void> init(String sprintId, {String? teamId, String? teamName}) async {
    final effectiveTeam = (teamId != null && teamId.isNotEmpty) ? teamId : teamName;
    state = state.copyWith(sprintId: sprintId, teamId: effectiveTeam, isLoading: true, errorMessage: null);
    await Future.wait([
      loadWorkspace(silent: true),
      _loadAssignableUsers(),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadAssignableUsers() async {
    try {
      final users = await _api.getAssignableUsers(limit: 50);
      state = state.copyWith(assignableUsers: users);
    } catch (_) {}
  }

  Future<void> loadWorkspace({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }
    try {
      final ws = await _api.getSprintRetrospectiveWorkspace(
        state.sprintId,
        teamId: state.teamId,
      );
      if (ws != null) {
        state = state.copyWith(workspace: ws, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setActiveTab(String tab) {
    state = state.copyWith(activeTab: tab);
  }

  void setSearchQuery(String q) {
    state = state.copyWith(searchQuery: q);
  }

  void setActionStatusFilter(String filter) {
    state = state.copyWith(actionStatusFilter: filter);
  }

  void toggleActionItemSelection(String id) {
    final next = Set<String>.from(state.selectedActionItemIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(selectedActionItemIds: next);
  }

  void toggleAllActionSelection(bool selectAll) {
    if (selectAll && state.workspace != null) {
      state = state.copyWith(
        selectedActionItemIds: state.workspace!.actionItems.map((a) => a.id).toSet(),
      );
    } else {
      state = state.copyWith(selectedActionItemIds: {});
    }
  }

  void openActionDrawer(SprintRetroActionItemModel item) {
    state = state.copyWith(selectedActionItem: item, isDrawerOpen: true);
  }

  void closeActionDrawer() {
    state = state.copyWith(isDrawerOpen: false);
  }

  Future<bool> updateSession(Map<String, dynamic> data) async {
    state = state.copyWith(isSaving: true);
    final success = await _api.updateSprintRetroSession(state.sprintId, data);
    state = state.copyWith(isSaving: false);
    if (success) {
      await loadWorkspace(silent: true);
    }
    return success;
  }

  Future<bool> startSession() async {
    state = state.copyWith(isSaving: true);
    final success = await _api.startSprintRetroSession(state.sprintId);
    state = state.copyWith(isSaving: false);
    if (success) {
      await loadWorkspace(silent: true);
    }
    return success;
  }

  Future<bool> closeSession({String? summary}) async {
    state = state.copyWith(isSaving: true);
    final success = await _api.closeSprintRetroSession(state.sprintId, summary: summary);
    state = state.copyWith(isSaving: false);
    if (success) {
      await loadWorkspace(silent: true);
    }
    return success;
  }

  Future<bool> reopenSession() async {
    state = state.copyWith(isSaving: true);
    final success = await _api.reopenSprintRetroSession(state.sprintId);
    state = state.copyWith(isSaving: false);
    if (success) {
      await loadWorkspace(silent: true);
    }
    return success;
  }

  Future<bool> addEntry({required String category, required String content}) async {
    final success = await _api.addRetroEntry(state.sprintId, category: category, content: content);
    if (success) {
      await loadWorkspace(silent: true);
    }
    return success;
  }

  Future<bool> updateEntry(String entryId, {required String category, required String content}) async {
    final success = await _api.updateRetroEntry(state.sprintId, entryId, category: category, content: content);
    if (success) {
      await loadWorkspace(silent: true);
    }
    return success;
  }

  Future<bool> deleteEntry(String entryId) async {
    final success = await _api.deleteRetroEntry(state.sprintId, entryId);
    if (success) {
      await loadWorkspace(silent: true);
    }
    return success;
  }

  Future<bool> voteEntry(String entryId) async {
    final success = await _api.voteRetroEntry(state.sprintId, entryId);
    if (success) {
      await loadWorkspace(silent: true);
    }
    return success;
  }

  Future<bool> moveFeedbackEntry(String entryId, String targetCategory) async {
    final ws = state.workspace;
    if (ws == null) return false;

    SprintRetroEntryItemModel? targetItem;
    for (final e in ws.wentWell.entries) {
      if (e.id == entryId) { targetItem = e; break; }
    }
    if (targetItem == null) {
      for (final e in ws.didNotGoWell.entries) {
        if (e.id == entryId) { targetItem = e; break; }
      }
    }
    if (targetItem == null) {
      for (final e in ws.shouldImprove.entries) {
        if (e.id == entryId) { targetItem = e; break; }
      }
    }

    if (targetItem == null || targetItem.category == targetCategory) {
      return false;
    }

    final updatedItem = targetItem.copyWith(category: targetCategory);

    final newWentWell = ws.wentWell.entries.where((e) => e.id != entryId).toList();
    final newDidNotGoWell = ws.didNotGoWell.entries.where((e) => e.id != entryId).toList();
    final newShouldImprove = ws.shouldImprove.entries.where((e) => e.id != entryId).toList();

    if (targetCategory == 'WENT_WELL') {
      newWentWell.insert(0, updatedItem);
    } else if (targetCategory == 'DID_NOT_GO_WELL') {
      newDidNotGoWell.insert(0, updatedItem);
    } else {
      newShouldImprove.insert(0, updatedItem);
    }

    state = state.copyWith(
      workspace: ws.copyWith(
        wentWell: SprintRetroCategoryColumnModel(
          title: ws.wentWell.title,
          key: ws.wentWell.key,
          count: newWentWell.length,
          entries: newWentWell,
        ),
        didNotGoWell: SprintRetroCategoryColumnModel(
          title: ws.didNotGoWell.title,
          key: ws.didNotGoWell.key,
          count: newDidNotGoWell.length,
          entries: newDidNotGoWell,
        ),
        shouldImprove: SprintRetroCategoryColumnModel(
          title: ws.shouldImprove.title,
          key: ws.shouldImprove.key,
          count: newShouldImprove.length,
          entries: newShouldImprove,
        ),
      ),
    );

    final success = await _api.updateRetroEntry(
      state.sprintId,
      entryId,
      category: targetCategory,
      content: targetItem.content,
    );
    if (!success) {
      await loadWorkspace(silent: true);
    }
    return success;
  }

  Future<bool> addActionItem({
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
    state = state.copyWith(isSaving: true);
    final success = await _api.addActionItem(
      state.sprintId,
      title: title,
      itemKey: itemKey,
      description: description,
      ownerId: ownerId,
      dueDate: dueDate,
      priority: priority,
      status: status,
      progress: progress,
      linkedWorkItemId: linkedWorkItemId,
      sourceEntryId: sourceEntryId,
    );
    state = state.copyWith(isSaving: false);
    if (success) {
      await loadWorkspace(silent: true);
    }
    return success;
  }

  Future<bool> updateActionItem(String actionItemId, Map<String, dynamic> data) async {
    final success = await _api.updateActionItem(state.sprintId, actionItemId, data);
    if (success) {
      await loadWorkspace(silent: true);
      if (state.selectedActionItem?.id == actionItemId) {
        final updated = state.workspace?.actionItems.firstWhere(
          (a) => a.id == actionItemId,
          orElse: () => state.selectedActionItem!,
        );
        state = state.copyWith(selectedActionItem: updated);
      }
    }
    return success;
  }

  Future<bool> deleteActionItem(String actionItemId) async {
    final success = await _api.deleteActionItem(state.sprintId, actionItemId);
    if (success) {
      if (state.selectedActionItem?.id == actionItemId) {
        state = state.copyWith(isDrawerOpen: false, selectedActionItem: null);
      }
      await loadWorkspace(silent: true);
    }
    return success;
  }

  Future<bool> convertActionItemToWorkItem(
    String actionItemId, {
    String? title,
    String? description,
    String? ownerId,
    String? priority,
  }) async {
    state = state.copyWith(isSaving: true);
    final success = await _api.convertActionItemToWorkItem(
      state.sprintId,
      actionItemId,
      title: title,
      description: description,
      ownerId: ownerId,
      priority: priority,
    );
    state = state.copyWith(isSaving: false);
    if (success) {
      await loadWorkspace(silent: true);
    }
    return success;
  }

  Future<bool> bulkUpdateActionItems({String? status, String? priority}) async {
    if (state.selectedActionItemIds.isEmpty) return false;
    state = state.copyWith(isSaving: true);
    final success = await _api.bulkUpdateActionItems(
      state.sprintId,
      actionItemIds: state.selectedActionItemIds.toList(),
      status: status,
      priority: priority,
    );
    state = state.copyWith(isSaving: false, selectedActionItemIds: {});
    if (success) {
      await loadWorkspace(silent: true);
    }
    return success;
  }

  Future<bool> bulkDeleteActionItems(List<String> actionItemIds) async {
    if (actionItemIds.isEmpty) return false;
    state = state.copyWith(isSaving: true);
    bool allSuccess = true;
    for (final id in actionItemIds) {
      final s = await _api.deleteActionItem(state.sprintId, id);
      if (!s) allSuccess = false;
    }
    state = state.copyWith(isSaving: false, selectedActionItemIds: {});
    await loadWorkspace(silent: true);
    return allSuccess;
  }

  Future<bool> submitFeedback({
    required String category,
    required int rating,
    String? content,
    String? suggestedImprovement,
    bool isAnonymous = false,
  }) async {
    state = state.copyWith(isSaving: true);
    final success = await _api.submitRetroFeedback(
      state.sprintId,
      category: category,
      rating: rating,
      content: content,
      suggestedImprovement: suggestedImprovement,
      isAnonymous: isAnonymous,
    );
    state = state.copyWith(isSaving: false);
    if (success) {
      await loadWorkspace(silent: true);
    }
    return success;
  }

  Future<String?> exportCsv() async {
    return await _api.exportSprintRetroCsv(state.sprintId);
  }
}

final workSprintRetroProvider =
    StateNotifierProvider<WorkSprintRetroNotifier, WorkSprintRetroState>((ref) {
  return WorkSprintRetroNotifier(ref, ref.read(workApiServiceProvider));
});

// ==========================================
// 10. ALL SPRINTS GLOBAL SYNC PROVIDER (CRUD & UNIFIED SELECTION)
// ==========================================
class WorkAllSprintsState {
  final bool isLoading;
  final List<WorkSprintModel> sprints;
  final String? selectedSprintId;
  final String? errorMessage;

  const WorkAllSprintsState({
    this.isLoading = false,
    this.sprints = const [],
    this.selectedSprintId,
    this.errorMessage,
  });

  WorkSprintModel? get activeSprint {
    if (sprints.isEmpty) return null;
    if (selectedSprintId != null) {
      final match = sprints.where(
        (s) =>
            s.id == selectedSprintId ||
            s.name.toLowerCase() == selectedSprintId!.toLowerCase() ||
            s.id.toLowerCase().contains(selectedSprintId!.toLowerCase()),
      );
      if (match.isNotEmpty) return match.first;
    }
    return sprints.firstWhere((s) => s.status == 'ACTIVE', orElse: () => sprints.first);
  }

  WorkAllSprintsState copyWith({
    bool? isLoading,
    List<WorkSprintModel>? sprints,
    String? selectedSprintId,
    String? errorMessage,
  }) {
    return WorkAllSprintsState(
      isLoading: isLoading ?? this.isLoading,
      sprints: sprints ?? this.sprints,
      selectedSprintId: selectedSprintId ?? this.selectedSprintId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class WorkAllSprintsNotifier extends StateNotifier<WorkAllSprintsState> {
  final Ref? ref;
  final WorkApiService _api;

  WorkAllSprintsNotifier(this.ref, [WorkApiService? api, WorkAllSprintsState? initialState])
      : _api = api ?? WorkApiService.instance,
        super(initialState ?? const WorkAllSprintsState(isLoading: true)) {
    if (initialState == null) {
      loadSprints();
    }
  }

  Future<void> loadSprints({String? boardId, bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true);
    try {
      final sprints = await _api.getSprints(boardId: boardId, forceRefresh: forceRefresh);
      final active = sprints.firstWhere(
        (s) => s.status == 'ACTIVE',
        orElse: () => sprints.isNotEmpty ? sprints.first : const WorkSprintModel(id: 's8', name: 'Sprint 8'),
      );
      final targetSprintId = state.selectedSprintId != null && sprints.any((s) => s.id == state.selectedSprintId)
          ? state.selectedSprintId!
          : active.id;
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        sprints: sprints,
        selectedSprintId: targetSprintId,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  void selectSprint(String sprintId) {
    if (state.selectedSprintId != sprintId) {
      state = state.copyWith(selectedSprintId: sprintId);
    }
  }

  Future<bool> createSprint(Map<String, dynamic> data) async {
    final success = await _api.createSprint(data);
    if (success) {
      await loadSprints(forceRefresh: true);
      final latest = state.sprints.isNotEmpty ? state.sprints.last : null;
      if (latest != null) {
        selectSprint(latest.id);
        await ref?.read(workSprintDashboardProvider.notifier).loadSprintDashboard(sprintId: latest.id, forceRefresh: true);
      } else {
        await ref?.read(workSprintDashboardProvider.notifier).loadSprintDashboard(forceRefresh: true);
      }
      ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
      ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
    }
    return success;
  }

  Future<bool> updateSprint(String sprintId, Map<String, dynamic> data) async {
    final success = await _api.updateSprint(sprintId, data);
    if (success) {
      selectSprint(sprintId);
      await loadSprints(forceRefresh: true);
      await ref?.read(workSprintDashboardProvider.notifier).loadSprintDashboard(sprintId: sprintId, forceRefresh: true);
      ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
      ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
    }
    return success;
  }

  Future<bool> deleteSprint(String sprintId) async {
    final success = await _api.deleteSprint(sprintId);
    if (success) {
      if (state.selectedSprintId == sprintId) {
        state = state.copyWith(selectedSprintId: null);
      }
      await loadSprints(forceRefresh: true);
      final nextSprintId = state.activeSprint?.id ?? (state.sprints.isNotEmpty ? state.sprints.first.id : 's8');
      selectSprint(nextSprintId);
      await ref?.read(workSprintDashboardProvider.notifier).loadSprintDashboard(sprintId: nextSprintId, forceRefresh: true);
      ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
      ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
    }
    return success;
  }

  Future<bool> startSprint(String sprintId) async {
    final success = await _api.startSprint(sprintId);
    if (success) {
      await loadSprints(forceRefresh: true);
      ref?.read(workSprintDashboardProvider.notifier).loadSprintDashboard(sprintId: sprintId, forceRefresh: true);
      ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
      ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
    }
    return success;
  }

  Future<bool> completeSprint(String sprintId, {String? moveIncompleteToSprintId, String? notes}) async {
    final success = await _api.completeSprint(
      sprintId,
      moveIncompleteToSprintId: moveIncompleteToSprintId,
      notes: notes,
    );
    if (success) {
      await loadSprints(forceRefresh: true);
      ref?.read(workSprintDashboardProvider.notifier).loadSprintDashboard(forceRefresh: true);
      ref?.read(workBoardProvider.notifier).loadBoard(forceRefresh: true);
      ref?.read(workListProvider.notifier).loadPagedItems(forceRefresh: true);
      ref?.read(workBacklogProvider.notifier).loadBacklog(forceRefresh: true);
    }
    return success;
  }
}

final allSprintsProvider =
    StateNotifierProvider<WorkAllSprintsNotifier, WorkAllSprintsState>((ref) {
  return WorkAllSprintsNotifier(ref, ref.read(workApiServiceProvider));
});

