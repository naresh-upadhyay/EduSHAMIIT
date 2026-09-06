import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/circulation_models.dart';
import '../services/circulation_api_service.dart';

class CirculationState {
  final bool isLoading;
  final bool isStatsLoading;
  final bool isActionLoading;
  final bool isScanning;
  final List<LibraryTransactionModel> transactions;
  final CirculationStatsModel stats;
  final CirculationFilterOptionsModel filterOptions;
  final List<CirculationActivityModel> activityFeed;
  final List<OverdueSummaryModel> overdueSummary;
  final List<LibraryRequestModel> requests;
  final Map<String, dynamic>? selectedTransaction;
  final bool isDrawerOpen;
  final Set<String> selectedBorrowIds;

  // Filter State
  final String subtab;
  final String searchQuery;
  final String searchIn;
  final String selectedStatus;
  final String selectedTransactionType;
  final String? dateFrom;
  final String? dateTo;

  // Pagination & Sorting
  final int page;
  final int pageSize;
  final int totalPages;
  final int totalTransactions;
  final Map<String, dynamic> subtabCounts;
  final String sortBy;
  final String sortOrder;

  // Feedback & Scanned state
  final ScanResultModel? quickScanResult;
  final String? errorMessage;
  final String? successMessage;

  const CirculationState({
    this.isLoading = false,
    this.isStatsLoading = false,
    this.isActionLoading = false,
    this.isScanning = false,
    this.transactions = const [],
    this.stats = const CirculationStatsModel(),
    this.filterOptions = const CirculationFilterOptionsModel(),
    this.activityFeed = const [],
    this.overdueSummary = const [],
    this.requests = const [],
    this.selectedTransaction,
    this.isDrawerOpen = false,
    this.selectedBorrowIds = const {},
    this.subtab = 'ALL',
    this.searchQuery = '',
    this.searchIn = 'All Transactions',
    this.selectedStatus = 'All',
    this.selectedTransactionType = 'All',
    this.dateFrom,
    this.dateTo,
    this.page = 1,
    this.pageSize = 10,
    this.totalPages = 1,
    this.totalTransactions = 0,
    this.subtabCounts = const {},
    this.sortBy = 'created_at',
    this.sortOrder = 'desc',
    this.quickScanResult,
    this.errorMessage,
    this.successMessage,
  });

  CirculationState copyWith({
    bool? isLoading,
    bool? isStatsLoading,
    bool? isActionLoading,
    bool? isScanning,
    List<LibraryTransactionModel>? transactions,
    CirculationStatsModel? stats,
    CirculationFilterOptionsModel? filterOptions,
    List<CirculationActivityModel>? activityFeed,
    List<OverdueSummaryModel>? overdueSummary,
    List<LibraryRequestModel>? requests,
    Map<String, dynamic>? selectedTransaction,
    bool? isDrawerOpen,
    Set<String>? selectedBorrowIds,
    String? subtab,
    String? searchQuery,
    String? searchIn,
    String? selectedStatus,
    String? selectedTransactionType,
    String? dateFrom,
    String? dateTo,
    int? page,
    int? pageSize,
    int? totalPages,
    int? totalTransactions,
    Map<String, dynamic>? subtabCounts,
    String? sortBy,
    String? sortOrder,
    ScanResultModel? quickScanResult,
    String? errorMessage,
    String? successMessage,
    bool clearSelectedTransaction = false,
    bool clearScanResult = false,
    bool clearDates = false,
  }) {
    return CirculationState(
      isLoading: isLoading ?? this.isLoading,
      isStatsLoading: isStatsLoading ?? this.isStatsLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      isScanning: isScanning ?? this.isScanning,
      transactions: transactions ?? this.transactions,
      stats: stats ?? this.stats,
      filterOptions: filterOptions ?? this.filterOptions,
      activityFeed: activityFeed ?? this.activityFeed,
      overdueSummary: overdueSummary ?? this.overdueSummary,
      requests: requests ?? this.requests,
      selectedTransaction: clearSelectedTransaction ? null : (selectedTransaction ?? this.selectedTransaction),
      isDrawerOpen: isDrawerOpen ?? this.isDrawerOpen,
      selectedBorrowIds: selectedBorrowIds ?? this.selectedBorrowIds,
      subtab: subtab ?? this.subtab,
      searchQuery: searchQuery ?? this.searchQuery,
      searchIn: searchIn ?? this.searchIn,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedTransactionType: selectedTransactionType ?? this.selectedTransactionType,
      dateFrom: clearDates ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDates ? null : (dateTo ?? this.dateTo),
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalPages: totalPages ?? this.totalPages,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      subtabCounts: subtabCounts ?? this.subtabCounts,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      quickScanResult: clearScanResult ? null : (quickScanResult ?? this.quickScanResult),
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class CirculationNotifier extends StateNotifier<CirculationState> {
  final CirculationApiService _apiService;
  Timer? _debounce;

  CirculationNotifier(this._apiService) : super(const CirculationState()) {
    init();
  }

  Future<void> init() async {
    await Future.wait([
      fetchStats(),
      fetchFilterOptions(),
      fetchActivities(),
      fetchOverdueSummary(),
      fetchTransactions(resetPage: true),
    ]);
  }

  Future<void> fetchStats() async {
    state = state.copyWith(isStatsLoading: true);
    try {
      final stats = await _apiService.fetchCirculationStats();
      state = state.copyWith(stats: stats, isStatsLoading: false);
    } catch (e) {
      debugPrint('[CirculationNotifier] fetchStats error: $e');
      state = state.copyWith(isStatsLoading: false);
    }
  }

  Future<void> fetchFilterOptions() async {
    try {
      final opts = await _apiService.fetchFilterOptions();
      state = state.copyWith(filterOptions: opts);
    } catch (e) {
      debugPrint('[CirculationNotifier] fetchFilterOptions error: $e');
    }
  }

  Future<void> fetchActivities() async {
    try {
      final acts = await _apiService.fetchCirculationActivity();
      state = state.copyWith(activityFeed: acts);
    } catch (e) {
      debugPrint('[CirculationNotifier] fetchActivities error: $e');
    }
  }

  Future<void> fetchOverdueSummary() async {
    try {
      final summary = await _apiService.fetchOverdueSummary();
      state = state.copyWith(overdueSummary: summary);
    } catch (e) {
      debugPrint('[CirculationNotifier] fetchOverdueSummary error: $e');
    }
  }

  Future<void> fetchTransactions({bool resetPage = false}) async {
    final targetPage = resetPage ? 1 : state.page;
    state = state.copyWith(isLoading: true, page: targetPage);

    try {
      final res = await _apiService.fetchTransactions(
        search: state.searchQuery,
        searchIn: state.searchIn,
        subtab: state.subtab,
        status: state.selectedStatus,
        transactionType: state.selectedTransactionType,
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
        sortBy: state.sortBy,
        sortOrder: state.sortOrder,
        page: targetPage,
        pageSize: state.pageSize,
      );

      final items = res['items'] as List<LibraryTransactionModel>;
      final total = res['total'] as int;
      final totalPages = res['total_pages'] as int;
      final counts = res['counts'] as Map<String, dynamic>;

      state = state.copyWith(
        transactions: items,
        totalTransactions: total,
        totalPages: totalPages,
        subtabCounts: counts,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[CirculationNotifier] fetchTransactions error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load circulation transactions: ${e.toString().replaceAll("Exception:", "").trim()}',
      );
    }
  }

  void setSubtab(String subtab) {
    if (state.subtab == subtab) return;
    state = state.copyWith(subtab: subtab, selectedBorrowIds: {});
    fetchTransactions(resetPage: true);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      fetchTransactions(resetPage: true);
    });
  }

  void setSearchIn(String field) {
    if (state.searchIn == field) return;
    state = state.copyWith(searchIn: field);
    fetchTransactions(resetPage: true);
  }

  void setStatus(String status) {
    if (state.selectedStatus == status) return;
    state = state.copyWith(selectedStatus: status);
    fetchTransactions(resetPage: true);
  }

  void setTransactionType(String type) {
    if (state.selectedTransactionType == type) return;
    state = state.copyWith(selectedTransactionType: type);
    fetchTransactions(resetPage: true);
  }

  void setDateRange(String? from, String? to) {
    state = state.copyWith(dateFrom: from, dateTo: to);
    fetchTransactions(resetPage: true);
  }

  void resetFilters() {
    state = state.copyWith(
      searchQuery: '',
      searchIn: 'All Transactions',
      selectedStatus: 'All',
      selectedTransactionType: 'All',
      clearDates: true,
    );
    fetchTransactions(resetPage: true);
  }

  void setPage(int page) {
    if (page < 1 || page > state.totalPages || page == state.page) return;
    state = state.copyWith(page: page);
    fetchTransactions();
  }

  void setPageSize(int size) {
    if (size == state.pageSize) return;
    state = state.copyWith(pageSize: size, page: 1);
    fetchTransactions(resetPage: true);
  }

  void setSorting(String column) {
    if (state.sortBy == column) {
      final newOrder = state.sortOrder.toLowerCase() == 'asc' ? 'desc' : 'asc';
      state = state.copyWith(sortOrder: newOrder);
    } else {
      state = state.copyWith(sortBy: column, sortOrder: 'asc');
    }
    fetchTransactions(resetPage: true);
  }

  void toggleSelection(String id) {
    final updated = Set<String>.from(state.selectedBorrowIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(selectedBorrowIds: updated);
  }

  void selectAll(bool select) {
    if (!select) {
      state = state.copyWith(selectedBorrowIds: {});
    } else {
      final allIds = state.transactions.map((t) => t.id).toSet();
      state = state.copyWith(selectedBorrowIds: allIds);
    }
  }

  Future<void> openDetails(LibraryTransactionModel item) async {
    state = state.copyWith(isDrawerOpen: true);
    try {
      final fullDetail = await _apiService.fetchTransactionDetail(item.id);
      state = state.copyWith(selectedTransaction: fullDetail);
    } catch (e) {
      debugPrint('[CirculationNotifier] openDetails error: $e');
    }
  }

  void closeDrawer() {
    state = state.copyWith(isDrawerOpen: false, clearSelectedTransaction: true);
  }

  Future<ScanResultModel?> scanLookup(String code) async {
    state = state.copyWith(isScanning: true, clearScanResult: true);
    try {
      final result = await _apiService.scanLookup(code);
      state = state.copyWith(isScanning: false, quickScanResult: result);
      return result;
    } catch (e) {
      debugPrint('[CirculationNotifier] scanLookup error: $e');
      state = state.copyWith(
        isScanning: false,
        errorMessage: 'Barcode not found: ${e.toString().replaceAll("Exception:", "").trim()}',
      );
      return null;
    }
  }

  Future<bool> issueBooks({
    required String memberId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    state = state.copyWith(isActionLoading: true);
    try {
      final res = await _apiService.issueBooks(memberId: memberId, items: items, notes: notes);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Books issued successfully.',
      );
      await Future.wait([fetchStats(), fetchActivities(), fetchTransactions(resetPage: true)]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll("Exception:", "").trim(),
      );
      return false;
    }
  }

  Future<bool> returnBooks({
    required List<Map<String, dynamic>> items,
    bool collectFine = false,
    String paymentMethod = 'CASH',
    String? paymentRef,
  }) async {
    state = state.copyWith(isActionLoading: true);
    try {
      final res = await _apiService.returnBooks(
        items: items,
        collectFine: collectFine,
        paymentMethod: paymentMethod,
        paymentRef: paymentRef,
      );
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Books returned successfully.',
      );
      await Future.wait([fetchStats(), fetchActivities(), fetchOverdueSummary(), fetchTransactions(resetPage: true)]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll("Exception:", "").trim(),
      );
      return false;
    }
  }

  Future<bool> renewBook({
    required String borrowId,
    String? newDueDate,
    String? reason,
  }) async {
    state = state.copyWith(isActionLoading: true);
    try {
      final res = await _apiService.renewBook(borrowId: borrowId, newDueDate: newDueDate, reason: reason);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Book renewed successfully.',
      );
      await Future.wait([fetchStats(), fetchActivities(), fetchTransactions(resetPage: true)]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll("Exception:", "").trim(),
      );
      return false;
    }
  }

  Future<bool> collectFine({
    required String fineId,
    required double amount,
    String paymentMethod = 'CASH',
    String? reference,
    String? notes,
  }) async {
    state = state.copyWith(isActionLoading: true);
    try {
      final res = await _apiService.collectFine(
        fineId: fineId,
        amount: amount,
        paymentMethod: paymentMethod,
        reference: reference,
        notes: notes,
      );
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Fine payment recorded successfully.',
      );
      await Future.wait([fetchStats(), fetchTransactions(resetPage: true)]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll("Exception:", "").trim(),
      );
      return false;
    }
  }

  Future<bool> waiveFine({
    required String fineId,
    required double amount,
    required String reason,
  }) async {
    state = state.copyWith(isActionLoading: true);
    try {
      final res = await _apiService.waiveFine(fineId: fineId, amount: amount, reason: reason);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Fine waiver recorded successfully.',
      );
      await Future.wait([fetchStats(), fetchTransactions(resetPage: true)]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll("Exception:", "").trim(),
      );
      return false;
    }
  }

  Future<void> fetchRequests() async {
    try {
      final res = await _apiService.fetchRequests();
      state = state.copyWith(requests: res['items'] as List<LibraryRequestModel>);
    } catch (e) {
      debugPrint('[CirculationNotifier] fetchRequests error: $e');
    }
  }

  Future<bool> createRequest({
    required String memberId,
    required String bookId,
    String requestType = 'ISSUE',
    String? reason,
    String? requestedDueDate,
  }) async {
    state = state.copyWith(isActionLoading: true);
    try {
      final res = await _apiService.createRequest(
        memberId: memberId,
        bookId: bookId,
        requestType: requestType,
        reason: reason,
        requestedDueDate: requestedDueDate,
      );
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Issue request created.',
      );
      await fetchStats();
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll("Exception:", "").trim(),
      );
      return false;
    }
  }

  Future<bool> processRequest({
    required String requestId,
    required String action,
    String? rejectionReason,
    String? copyId,
  }) async {
    state = state.copyWith(isActionLoading: true);
    try {
      final res = await _apiService.processRequest(
        requestId: requestId,
        action: action,
        rejectionReason: rejectionReason,
        copyId: copyId,
      );
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Request processed successfully.',
      );
      await Future.wait([fetchStats(), fetchRequests(), fetchTransactions(resetPage: true)]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll("Exception:", "").trim(),
      );
      return false;
    }
  }

  Future<bool> bulkAction(String action, [Map<String, dynamic>? params]) async {
    if (state.selectedBorrowIds.isEmpty) return false;
    state = state.copyWith(isActionLoading: true);
    try {
      final res = await _apiService.bulkAction(
        borrowIds: state.selectedBorrowIds.toList(),
        action: action,
        params: params,
      );
      state = state.copyWith(
        isActionLoading: false,
        selectedBorrowIds: {},
        successMessage: res['message']?.toString() ?? 'Bulk operation completed.',
      );
      await fetchTransactions(resetPage: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll("Exception:", "").trim(),
      );
      return false;
    }
  }

  void clearNotifications() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final circulationApiServiceProvider = Provider<CirculationApiService>((ref) {
  return CirculationApiService();
});

final circulationProvider = StateNotifierProvider<CirculationNotifier, CirculationState>((ref) {
  final api = ref.watch(circulationApiServiceProvider);
  return CirculationNotifier(api);
});
