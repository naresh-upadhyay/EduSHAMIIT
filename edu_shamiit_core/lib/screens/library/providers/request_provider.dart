import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/request_models.dart';
import '../services/request_api_service.dart';

final requestApiServiceProvider = Provider<RequestApiService>((ref) {
  return RequestApiService();
});

class RequestState {
  final RequestKpisModel kpis;
  final RequestFilterOptionsModel options;
  final List<LibraryRequestItem> items;
  final RequestDetailModel? selectedRequestDetail;
  final bool isLoading;
  final bool isDetailLoading;
  final bool isProcessing;
  final String? errorMessage;
  final String? detailErrorMessage;

  // Pagination
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  // Active filters
  final String activeSubtab; // ALL, MY_REQUESTS, NEEDS_REVIEW, ASSIGNED_TO_ME
  final String searchQuery;
  final String selectedType; // ALL, Book, E-Book, etc.
  final String selectedStatus; // ALL, NEW, ACTIVE, IN_PROGRESS, RESOLVED, COMPLETED, REJECTED, CANCELED
  final String selectedPriority; // ALL, Low, Medium, High, Urgent
  final String selectedRole; // ALL, student, teacher, staff
  final DateTimeRange? dateRange;
  final String sortBy;
  final String sortOrder;

  // Selected for bulk actions
  final Set<String> selectedIds;

  RequestState({
    required this.kpis,
    required this.options,
    this.items = const [],
    this.selectedRequestDetail,
    this.isLoading = false,
    this.isDetailLoading = false,
    this.isProcessing = false,
    this.errorMessage,
    this.detailErrorMessage,
    this.total = 0,
    this.page = 1,
    this.pageSize = 10,
    this.totalPages = 1,
    this.activeSubtab = 'ALL',
    this.searchQuery = '',
    this.selectedType = 'ALL',
    this.selectedStatus = 'ALL',
    this.selectedPriority = 'ALL',
    this.selectedRole = 'ALL',
    this.dateRange,
    this.sortBy = 'created_at',
    this.sortOrder = 'DESC',
    this.selectedIds = const {},
  });

  RequestState copyWith({
    RequestKpisModel? kpis,
    RequestFilterOptionsModel? options,
    List<LibraryRequestItem>? items,
    RequestDetailModel? selectedRequestDetail,
    bool clearDetail = false,
    bool? isLoading,
    bool? isDetailLoading,
    bool? isProcessing,
    String? errorMessage,
    String? detailErrorMessage,
    int? total,
    int? page,
    int? pageSize,
    int? totalPages,
    String? activeSubtab,
    String? searchQuery,
    String? selectedType,
    String? selectedStatus,
    String? selectedPriority,
    String? selectedRole,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    String? sortBy,
    String? sortOrder,
    Set<String>? selectedIds,
  }) {
    return RequestState(
      kpis: kpis ?? this.kpis,
      options: options ?? this.options,
      items: items ?? this.items,
      selectedRequestDetail: clearDetail ? null : (selectedRequestDetail ?? this.selectedRequestDetail),
      isLoading: isLoading ?? this.isLoading,
      isDetailLoading: isDetailLoading ?? this.isDetailLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
      detailErrorMessage: detailErrorMessage,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalPages: totalPages ?? this.totalPages,
      activeSubtab: activeSubtab ?? this.activeSubtab,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedType: selectedType ?? this.selectedType,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedPriority: selectedPriority ?? this.selectedPriority,
      selectedRole: selectedRole ?? this.selectedRole,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

class RequestNotifier extends StateNotifier<RequestState> {
  final RequestApiService _api;
  Timer? _searchDebounce;

  RequestNotifier(this._api)
      : super(RequestState(
          kpis: RequestKpisModel(),
          options: RequestFilterOptionsModel(),
        )) {
    init();
  }

  Future<void> init() async {
    await Future.wait([
      fetchKpis(),
      fetchOptions(),
      loadRequests(),
    ]);
  }

  Future<void> fetchKpis() async {
    try {
      final kpis = await _api.fetchRequestKpis();
      state = state.copyWith(kpis: kpis);
    } catch (e) {
      debugPrint('[RequestNotifier] Error fetching KPIs: $e');
    }
  }

  Future<void> fetchOptions() async {
    try {
      final options = await _api.fetchRequestOptions();
      state = state.copyWith(options: options);
    } catch (e) {
      debugPrint('[RequestNotifier] Error fetching options: $e');
    }
  }

  Future<void> loadRequests({bool resetPage = false}) async {
    final pageToLoad = resetPage ? 1 : state.page;
    state = state.copyWith(isLoading: true, errorMessage: null, page: pageToLoad);

    try {
      String? dFrom;
      String? dTo;
      if (state.dateRange != null) {
        dFrom = '${state.dateRange!.start.year}-${state.dateRange!.start.month.toString().padLeft(2, '0')}-${state.dateRange!.start.day.toString().padLeft(2, '0')}';
        dTo = '${state.dateRange!.end.year}-${state.dateRange!.end.month.toString().padLeft(2, '0')}-${state.dateRange!.end.day.toString().padLeft(2, '0')}';
      }

      final res = await _api.fetchRequests(
        search: state.searchQuery,
        subtab: state.activeSubtab,
        requestType: state.selectedType,
        status: state.selectedStatus,
        priority: state.selectedPriority,
        requestedByRole: state.selectedRole,
        dateFrom: dFrom,
        dateTo: dTo,
        sortBy: state.sortBy,
        sortOrder: state.sortOrder,
        page: pageToLoad,
        pageSize: state.pageSize,
      );

      final items = res['items'] as List<LibraryRequestItem>;
      final total = res['total'] as int;
      final totalPages = res['total_pages'] as int;

      state = state.copyWith(
        items: items,
        total: total,
        totalPages: totalPages,
        page: pageToLoad,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[RequestNotifier] Error loading requests: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load requests: ${e.toString().replaceAll('Exception:', '').trim()}',
      );
    }
  }

  void setSearchQuery(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      state = state.copyWith(searchQuery: query);
      loadRequests(resetPage: true);
    });
  }

  void setSubtab(String subtab) {
    if (state.activeSubtab == subtab) return;
    state = state.copyWith(activeSubtab: subtab);
    loadRequests(resetPage: true);
  }

  void setTypeFilter(String type) {
    if (state.selectedType == type) return;
    state = state.copyWith(selectedType: type);
    loadRequests(resetPage: true);
  }

  void setStatusFilter(String status) {
    if (state.selectedStatus == status) return;
    state = state.copyWith(selectedStatus: status);
    loadRequests(resetPage: true);
  }

  void setPriorityFilter(String priority) {
    if (state.selectedPriority == priority) return;
    state = state.copyWith(selectedPriority: priority);
    loadRequests(resetPage: true);
  }

  void setRoleFilter(String role) {
    if (state.selectedRole == role) return;
    state = state.copyWith(selectedRole: role);
    loadRequests(resetPage: true);
  }

  void setDateRange(DateTimeRange? range) {
    if (range == null) {
      state = state.copyWith(clearDateRange: true);
    } else {
      state = state.copyWith(dateRange: range);
    }
    loadRequests(resetPage: true);
  }

  void resetFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedType: 'ALL',
      selectedStatus: 'ALL',
      selectedPriority: 'ALL',
      selectedRole: 'ALL',
      clearDateRange: true,
      activeSubtab: 'ALL',
    );
    loadRequests(resetPage: true);
  }

  void setPage(int page) {
    if (page < 1 || (page > state.totalPages && state.totalPages > 0)) return;
    state = state.copyWith(page: page);
    loadRequests();
  }

  void setPageSize(int pageSize) {
    state = state.copyWith(pageSize: pageSize);
    loadRequests(resetPage: true);
  }

  void toggleSort(String column) {
    if (state.sortBy == column) {
      final newOrder = state.sortOrder.toUpperCase() == 'ASC' ? 'DESC' : 'ASC';
      state = state.copyWith(sortOrder: newOrder);
    } else {
      state = state.copyWith(sortBy: column, sortOrder: 'DESC');
    }
    loadRequests(resetPage: true);
  }

  void toggleSelectAll(bool selectAll) {
    if (selectAll) {
      state = state.copyWith(selectedIds: state.items.map((e) => e.id).toSet());
    } else {
      state = state.copyWith(selectedIds: {});
    }
  }

  void toggleSelectId(String id) {
    final updated = Set<String>.from(state.selectedIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(selectedIds: updated);
  }

  // Fetch single detail for drawer
  Future<void> openRequestDetail(String requestId) async {
    state = state.copyWith(isDetailLoading: true, detailErrorMessage: null);
    try {
      final detail = await _api.fetchRequestDetail(requestId);
      state = state.copyWith(selectedRequestDetail: detail, isDetailLoading: false);
    } catch (e) {
      debugPrint('[RequestNotifier] Error loading request detail: $e');
      state = state.copyWith(
        isDetailLoading: false,
        detailErrorMessage: 'Failed to load request detail: ${e.toString()}',
      );
    }
  }

  void closeRequestDetail() {
    state = state.copyWith(clearDetail: true);
  }

  // Transitions and actions
  Future<bool> transitionStatus({
    required String requestId,
    required String toStatus,
    String? reason,
    String? comment,
  }) async {
    state = state.copyWith(isProcessing: true);
    try {
      await _api.transitionStatus(
        requestId: requestId,
        toStatus: toStatus,
        reason: reason,
        comment: comment,
      );
      await Future.wait([
        fetchKpis(),
        loadRequests(),
        if (state.selectedRequestDetail?.request.id == requestId) openRequestDetail(requestId),
      ]);
      state = state.copyWith(isProcessing: false);
      return true;
    } catch (e) {
      state = state.copyWith(isProcessing: false);
      rethrow;
    }
  }

  Future<bool> assignRequest({
    required String requestId,
    required String assignedTo,
    String? notes,
  }) async {
    state = state.copyWith(isProcessing: true);
    try {
      await _api.assignRequest(requestId: requestId, assignedTo: assignedTo, notes: notes);
      await Future.wait([
        fetchKpis(),
        loadRequests(),
        if (state.selectedRequestDetail?.request.id == requestId) openRequestDetail(requestId),
      ]);
      state = state.copyWith(isProcessing: false);
      return true;
    } catch (e) {
      state = state.copyWith(isProcessing: false);
      rethrow;
    }
  }

  Future<bool> addComment({
    required String requestId,
    required String comment,
    bool isInternal = false,
  }) async {
    try {
      await _api.addComment(requestId: requestId, comment: comment, isInternal: isInternal);
      if (state.selectedRequestDetail?.request.id == requestId) {
        await openRequestDetail(requestId);
      }
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadTempAttachment({
    required List<int> bytes,
    required String filename,
  }) async {
    return await _api.uploadTempAttachment(bytes, filename);
  }

  Future<bool> uploadAttachment({
    required String requestId,
    required List<int> bytes,
    required String filename,
  }) async {
    state = state.copyWith(isProcessing: true);
    try {
      await _api.uploadRequestAttachment(
        requestId: requestId,
        bytes: bytes,
        filename: filename,
      );
      if (state.selectedRequestDetail?.request.id == requestId) {
        await openRequestDetail(requestId);
      }
      state = state.copyWith(isProcessing: false);
      return true;
    } catch (e) {
      state = state.copyWith(isProcessing: false);
      rethrow;
    }
  }

  Future<bool> createRequest(Map<String, dynamic> payload) async {
    state = state.copyWith(isProcessing: true);
    try {
      await _api.createRequest(payload);
      await Future.wait([
        fetchKpis(),
        loadRequests(resetPage: true),
      ]);
      state = state.copyWith(isProcessing: false);
      return true;
    } catch (e) {
      state = state.copyWith(isProcessing: false);
      rethrow;
    }
  }


  Future<Map<String, dynamic>> performBulkAction({
    required String action,
    String? assignedTo,
    String? reason,
  }) async {
    if (state.selectedIds.isEmpty) return {'success': false, 'message': 'No items selected'};
    state = state.copyWith(isProcessing: true);
    try {
      final res = await _api.bulkAction(
        requestIds: state.selectedIds.toList(),
        action: action,
        assignedTo: assignedTo,
        reason: reason,
      );
      state = state.copyWith(selectedIds: {});
      await Future.wait([
        fetchKpis(),
        loadRequests(),
      ]);
      state = state.copyWith(isProcessing: false);
      return res;
    } catch (e) {
      state = state.copyWith(isProcessing: false);
      rethrow;
    }
  }

  String getExportCsvUrl() {
    return _api.getExportCsvUrl();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}


final requestProvider = StateNotifierProvider<RequestNotifier, RequestState>((ref) {
  final api = ref.watch(requestApiServiceProvider);
  return RequestNotifier(api);
});
