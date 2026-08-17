import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notice_models.dart';
import '../services/notice_api_service.dart';

// ============================================================================
// Notice State Model
// ============================================================================

class NoticeState {
  final List<NoticeModel> notices;
  final NoticeSummaryModel summary;
  final List<NoticeCategoryModel> categories;
  final List<String> roles;
  final List<String> classes;
  final bool isLoading;
  final bool isSummaryLoading;
  final String? error;

  final String activeTab;
  final String searchQuery;
  final String selectedAudience;
  final String selectedCategory;
  final String selectedPriority;
  final String selectedStatus;
  final DateTime? fromDate;
  final DateTime? toDate;
  final bool? requiresAck;
  final bool? isRead;
  final bool? hasAttachment;

  final String sortBy;
  final String sortOrder;
  final int currentPage;
  final int pageSize;
  final int totalRecords;
  final int totalPages;

  final bool isTableView;
  final Set<String> selectedNoticeIds;

  const NoticeState({
    this.notices = const [],
    this.summary = const NoticeSummaryModel(),
    this.categories = const [],
    this.roles = const [],
    this.classes = const [],
    this.isLoading = false,
    this.isSummaryLoading = false,
    this.error,
    this.activeTab = 'all',
    this.searchQuery = '',
    this.selectedAudience = 'All',
    this.selectedCategory = 'All',
    this.selectedPriority = 'All',
    this.selectedStatus = 'All',
    this.fromDate,
    this.toDate,
    this.requiresAck,
    this.isRead,
    this.hasAttachment,
    this.sortBy = 'published_at',
    this.sortOrder = 'DESC',
    this.currentPage = 1,
    this.pageSize = 10,
    this.totalRecords = 0,
    this.totalPages = 1,
    this.isTableView = true,
    this.selectedNoticeIds = const {},
  });

  NoticeState copyWith({
    List<NoticeModel>? notices,
    NoticeSummaryModel? summary,
    List<NoticeCategoryModel>? categories,
    List<String>? roles,
    List<String>? classes,
    bool? isLoading,
    bool? isSummaryLoading,
    String? error,
    String? activeTab,
    String? searchQuery,
    String? selectedAudience,
    String? selectedCategory,
    String? selectedPriority,
    String? selectedStatus,
    DateTime? fromDate,
    DateTime? toDate,
    bool? requiresAck,
    bool? isRead,
    bool? hasAttachment,
    String? sortBy,
    String? sortOrder,
    int? currentPage,
    int? pageSize,
    int? totalRecords,
    int? totalPages,
    bool? isTableView,
    Set<String>? selectedNoticeIds,
    bool clearDates = false,
    bool clearRequiresAck = false,
    bool clearIsRead = false,
    bool clearHasAttachment = false,
  }) {
    return NoticeState(
      notices: notices ?? this.notices,
      summary: summary ?? this.summary,
      categories: categories ?? this.categories,
      roles: roles ?? this.roles,
      classes: classes ?? this.classes,
      isLoading: isLoading ?? this.isLoading,
      isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
      error: error,
      activeTab: activeTab ?? this.activeTab,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedAudience: selectedAudience ?? this.selectedAudience,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedPriority: selectedPriority ?? this.selectedPriority,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      fromDate: clearDates ? null : (fromDate ?? this.fromDate),
      toDate: clearDates ? null : (toDate ?? this.toDate),
      requiresAck: clearRequiresAck ? null : (requiresAck ?? this.requiresAck),
      isRead: clearIsRead ? null : (isRead ?? this.isRead),
      hasAttachment: clearHasAttachment ? null : (hasAttachment ?? this.hasAttachment),
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalRecords: totalRecords ?? this.totalRecords,
      totalPages: totalPages ?? this.totalPages,
      isTableView: isTableView ?? this.isTableView,
      selectedNoticeIds: selectedNoticeIds ?? this.selectedNoticeIds,
    );
  }

  bool get hasActiveFilters {
    return searchQuery.isNotEmpty ||
        selectedAudience != 'All' ||
        selectedCategory != 'All' ||
        selectedPriority != 'All' ||
        selectedStatus != 'All' ||
        fromDate != null ||
        toDate != null ||
        requiresAck != null ||
        isRead != null ||
        hasAttachment != null;
  }
}

// ============================================================================
// Notice State Notifier
// ============================================================================

class NoticeNotifier extends StateNotifier<NoticeState> {
  final NoticeApiService _apiService;
  Timer? _debounceTimer;

  NoticeNotifier(this._apiService) : super(const NoticeState()) {
    init();
  }

  Future<void> init() async {
    await Future.wait([
      fetchNotices(),
      fetchSummary(),
      fetchCategories(),
    ]);
  }

  Future<void> fetchNotices() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _apiService.getNotices(
        tab: state.activeTab,
        search: state.searchQuery,
        category: state.selectedCategory == 'All' ? '' : state.selectedCategory,
        priority: state.selectedPriority == 'All' ? '' : state.selectedPriority.toLowerCase(),
        status: state.selectedStatus == 'All' ? '' : state.selectedStatus.toLowerCase(),
        audience: state.selectedAudience == 'All' ? '' : state.selectedAudience,
        fromDate: state.fromDate?.toIso8601String(),
        toDate: state.toDate?.toIso8601String(),
        requiresAck: state.requiresAck,
        isRead: state.isRead,
        hasAttachment: state.hasAttachment,
        sortBy: state.sortBy,
        sortOrder: state.sortOrder,
        page: state.currentPage,
        pageSize: state.pageSize,
      );

      state = state.copyWith(
        notices: res['notices'] as List<NoticeModel>,
        currentPage: res['page'] as int,
        pageSize: res['pageSize'] as int,
        totalRecords: res['totalRecords'] as int,
        totalPages: res['totalPages'] as int,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchSummary() async {
    state = state.copyWith(isSummaryLoading: true);
    try {
      final summary = await _apiService.getNoticeSummary();
      state = state.copyWith(summary: summary, isSummaryLoading: false);
    } catch (_) {
      state = state.copyWith(isSummaryLoading: false);
    }
  }

  Future<void> fetchCategories() async {
    await fetchMetadata();
  }

  Future<void> fetchMetadata() async {
    try {
      final res = await _apiService.getMetadata();
      final rolesList = res['roles'] is List ? (res['roles'] as List).map((e) => e.toString()).toList() : <String>[];
      final classesList = res['classes'] is List ? (res['classes'] as List).map((e) => e.toString()).toList() : <String>[];
      final categoriesList = res['categories'] is List
          ? (res['categories'] as List).map((e) => NoticeCategoryModel.fromJson(Map<String, dynamic>.from(e))).toList()
          : <NoticeCategoryModel>[];

      state = state.copyWith(
        roles: rolesList.isNotEmpty ? rolesList : state.roles,
        classes: classesList.isNotEmpty ? classesList : state.classes,
        categories: categoriesList.isNotEmpty ? categoriesList : state.categories,
      );
    } catch (_) {}
  }

  void setTab(String tab) {
    if (state.activeTab == tab) return;
    state = state.copyWith(activeTab: tab, currentPage: 1, selectedNoticeIds: {});
    fetchNotices();
  }

  void onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      state = state.copyWith(searchQuery: query.trim(), currentPage: 1);
      fetchNotices();
    });
  }

  void setCategoryFilter(String category) {
    state = state.copyWith(selectedCategory: category, currentPage: 1);
    fetchNotices();
  }

  void setPriorityFilter(String priority) {
    state = state.copyWith(selectedPriority: priority, currentPage: 1);
    fetchNotices();
  }

  void setStatusFilter(String status) {
    state = state.copyWith(selectedStatus: status, currentPage: 1);
    fetchNotices();
  }

  void setAudienceFilter(String audience) {
    state = state.copyWith(selectedAudience: audience, currentPage: 1);
    fetchNotices();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(
      fromDate: from,
      toDate: to,
      clearDates: (from == null && to == null),
      currentPage: 1,
    );
    fetchNotices();
  }

  void clearDateRange() {
    state = state.copyWith(clearDates: true, currentPage: 1);
    fetchNotices();
  }

  void clearAudienceFilter() {
    state = state.copyWith(selectedAudience: 'All', currentPage: 1);
    fetchNotices();
  }

  void clearCategoryFilter() {
    state = state.copyWith(selectedCategory: 'All', currentPage: 1);
    fetchNotices();
  }

  void clearPriorityFilter() {
    state = state.copyWith(selectedPriority: 'All', currentPage: 1);
    fetchNotices();
  }

  void clearStatusFilter() {
    state = state.copyWith(selectedStatus: 'All', currentPage: 1);
    fetchNotices();
  }

  void clearRequiresAckFilter() {
    state = state.copyWith(clearRequiresAck: true, currentPage: 1);
    fetchNotices();
  }

  void clearIsReadFilter() {
    state = state.copyWith(clearIsRead: true, currentPage: 1);
    fetchNotices();
  }

  void clearHasAttachmentFilter() {
    state = state.copyWith(clearHasAttachment: true, currentPage: 1);
    fetchNotices();
  }

  void setSorting(String sortBy, {String? sortOrder}) {
    final newOrder = sortOrder ?? (state.sortBy == sortBy && state.sortOrder == 'DESC' ? 'ASC' : 'DESC');
    state = state.copyWith(sortBy: sortBy, sortOrder: newOrder, currentPage: 1);
    fetchNotices();
  }

  void setPage(int page) {
    if (page < 1 || page > state.totalPages || page == state.currentPage) return;
    state = state.copyWith(currentPage: page);
    fetchNotices();
  }

  void setPageSize(int size) {
    if (size == state.pageSize) return;
    state = state.copyWith(pageSize: size, currentPage: 1);
    fetchNotices();
  }

  void toggleViewMode() {
    state = state.copyWith(isTableView: !state.isTableView);
  }

  void toggleNoticeSelection(String id) {
    final updated = Set<String>.from(state.selectedNoticeIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(selectedNoticeIds: updated);
  }

  void selectAllNotices(bool selectAll) {
    if (selectAll) {
      final allIds = state.notices.map((n) => n.id).toSet();
      state = state.copyWith(selectedNoticeIds: allIds);
    } else {
      state = state.copyWith(selectedNoticeIds: {});
    }
  }

  void resetFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedAudience: 'All',
      selectedCategory: 'All',
      selectedPriority: 'All',
      selectedStatus: 'All',
      clearDates: true,
      clearRequiresAck: true,
      clearIsRead: true,
      clearHasAttachment: true,
      currentPage: 1,
      selectedNoticeIds: {},
    );
    fetchNotices();
  }

  Future<Map<String, dynamic>> bulkImportNotices(List<Map<String, dynamic>> notices) async {
    final res = await _apiService.bulkImportNotices(notices);
    await refreshAll();
    return res;
  }

  // Action Handlers
  Future<void> publishNotice(String id) async {
    await _apiService.publishNotice(id);
    await refreshAll();
  }

  Future<void> archiveNotice(String id) async {
    await _apiService.archiveNotice(id);
    await refreshAll();
  }

  Future<void> restoreNotice(String id) async {
    await _apiService.restoreNotice(id);
    await refreshAll();
  }

  Future<void> deleteNotice(String id) async {
    await _apiService.deleteNotice(id);
    await refreshAll();
  }

  Future<void> duplicateNotice(String id) async {
    await _apiService.duplicateNotice(id);
    await refreshAll();
  }

  Future<void> updateNotice(String id, Map<String, dynamic> payload) async {
    await _apiService.updateNotice(id, payload);
    await refreshAll();
  }

  Future<void> togglePin(String id) async {
    final notice = state.notices.where((n) => n.id == id).firstOrNull;
    if (notice != null) {
      await _apiService.updateNotice(id, {'is_pinned': !notice.isPinned});
      await refreshAll();
    }
  }

  Future<void> acknowledgeNotice(String id, {String status = 'acknowledged', String? declineReason}) async {
    await _apiService.acknowledgeNotice(id, status: status, declineReason: declineReason);
    await refreshAll();
  }

  Future<void> approveNotice(String id) async {
    await _apiService.approveNotice(id);
    await refreshAll();
  }

  Future<void> rejectNotice(String id, String reason) async {
    await _apiService.rejectNotice(id, reason);
    await refreshAll();
  }

  Future<void> requestChanges(String id, String comment) async {
    await _apiService.requestChanges(id, comment);
    await refreshAll();
  }

  Future<void> performBulkAction(String action) async {
    if (state.selectedNoticeIds.isEmpty) return;
    await _apiService.bulkAction(state.selectedNoticeIds.toList(), action);
    state = state.copyWith(selectedNoticeIds: {});
    await refreshAll();
  }

  Future<void> refreshAll() async {
    await Future.wait([
      fetchNotices(),
      fetchSummary(),
      fetchMetadata(),
    ]);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

// Provider definition
final noticeApiServiceProvider = Provider<NoticeApiService>((ref) {
  return NoticeApiService();
});

final noticeProvider = StateNotifierProvider<NoticeNotifier, NoticeState>((ref) {
  final api = ref.watch(noticeApiServiceProvider);
  return NoticeNotifier(api);
});
