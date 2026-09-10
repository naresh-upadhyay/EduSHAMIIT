import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/finance_models.dart';
import '../services/finance_api_service.dart';

class FinanceState {
  final int activeTabIndex;
  final String academicYear;
  final String financialYear;
  final String searchQuery;
  final String? selectedClassId;
  final String? selectedFeeHead;
  final String selectedStatus;
  final int currentPage;
  final int limit;
  final bool isLoading;
  final FinanceOverviewData? overview;
  final List<FeeLedgerItem> ledgerItems;
  final int totalLedgerItems;
  final int totalLedgerPages;
  final List<FeeStructureModel> feeStructures;
  final String? selectedStudentId;
  final StudentFeeAccountData? selectedStudentAccount;
  final Set<String> selectedInvoiceIds;

  FinanceState({
    this.activeTabIndex = 0,
    this.academicYear = '2026-27',
    this.financialYear = '2026-27',
    this.searchQuery = '',
    this.selectedClassId,
    this.selectedFeeHead,
    this.selectedStatus = 'ALL',
    this.currentPage = 1,
    this.limit = 10,
    this.isLoading = false,
    this.overview,
    this.ledgerItems = const [],
    this.totalLedgerItems = 0,
    this.totalLedgerPages = 1,
    this.feeStructures = const [],
    this.selectedStudentId,
    this.selectedStudentAccount,
    this.selectedInvoiceIds = const {},
  });

  FinanceState copyWith({
    int? activeTabIndex,
    String? academicYear,
    String? financialYear,
    String? searchQuery,
    String? selectedClassId,
    String? selectedFeeHead,
    String? selectedStatus,
    int? currentPage,
    int? limit,
    bool? isLoading,
    FinanceOverviewData? overview,
    List<FeeLedgerItem>? ledgerItems,
    int? totalLedgerItems,
    int? totalLedgerPages,
    List<FeeStructureModel>? feeStructures,
    String? selectedStudentId,
    StudentFeeAccountData? selectedStudentAccount,
    Set<String>? selectedInvoiceIds,
  }) {
    return FinanceState(
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      academicYear: academicYear ?? this.academicYear,
      financialYear: financialYear ?? this.financialYear,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedClassId: selectedClassId ?? this.selectedClassId,
      selectedFeeHead: selectedFeeHead ?? this.selectedFeeHead,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      currentPage: currentPage ?? this.currentPage,
      limit: limit ?? this.limit,
      isLoading: isLoading ?? this.isLoading,
      overview: overview ?? this.overview,
      ledgerItems: ledgerItems ?? this.ledgerItems,
      totalLedgerItems: totalLedgerItems ?? this.totalLedgerItems,
      totalLedgerPages: totalLedgerPages ?? this.totalLedgerPages,
      feeStructures: feeStructures ?? this.feeStructures,
      selectedStudentId: selectedStudentId ?? this.selectedStudentId,
      selectedStudentAccount: selectedStudentAccount ?? this.selectedStudentAccount,
      selectedInvoiceIds: selectedInvoiceIds ?? this.selectedInvoiceIds,
    );
  }
}

class FinanceNotifier extends StateNotifier<FinanceState> {
  final FinanceApiService _api = FinanceApiService();

  FinanceNotifier() : super(FinanceState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    await Future.wait([
      fetchOverview(),
      fetchLedger(),
      fetchFeeStructures(),
    ]);
    state = state.copyWith(isLoading: false);
  }

  Future<void> fetchOverview() async {
    final overviewData = await _api.getOverview(academicYear: state.academicYear);
    if (overviewData != null) {
      state = state.copyWith(overview: overviewData);
    }
  }

  Future<void> fetchLedger() async {
    final res = await _api.getFeesLedger(
      page: state.currentPage,
      limit: state.limit,
      academicYear: state.academicYear,
      classId: state.selectedClassId,
      feeHead: state.selectedFeeHead,
      status: state.selectedStatus,
      search: state.searchQuery,
    );
    state = state.copyWith(
      ledgerItems: res['items'] as List<FeeLedgerItem>,
      totalLedgerItems: res['total'] as int,
      totalLedgerPages: res['total_pages'] as int,
    );
  }

  Future<void> fetchFeeStructures() async {
    final structs = await _api.getFeeStructures(academicYear: state.academicYear);
    state = state.copyWith(feeStructures: structs);
  }

  void setActiveTab(int index) {
    state = state.copyWith(activeTabIndex: index);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, currentPage: 1);
    fetchLedger();
  }

  void setClassFilter(String? classId) {
    state = state.copyWith(selectedClassId: classId, currentPage: 1);
    fetchLedger();
  }

  void setFeeHeadFilter(String? feeHead) {
    state = state.copyWith(selectedFeeHead: feeHead, currentPage: 1);
    fetchLedger();
  }

  void setStatusFilter(String status) {
    state = state.copyWith(selectedStatus: status, currentPage: 1);
    fetchLedger();
  }

  void setPage(int page) {
    state = state.copyWith(currentPage: page);
    fetchLedger();
  }

  void resetFilters() {
    state = FinanceState(
      activeTabIndex: state.activeTabIndex,
      academicYear: state.academicYear,
      financialYear: state.financialYear,
    );
    loadAll();
  }

  Future<void> openStudentDrawer(String studentId) async {
    state = state.copyWith(selectedStudentId: studentId, isLoading: true);
    final account = await _api.getStudentAccount(studentId);
    state = state.copyWith(selectedStudentAccount: account, isLoading: false);
  }

  void closeStudentDrawer() {
    state = state.copyWith(selectedStudentId: null, selectedStudentAccount: null);
  }

  void toggleInvoiceSelection(String invoiceId) {
    final updated = Set<String>.from(state.selectedInvoiceIds);
    if (updated.contains(invoiceId)) {
      updated.remove(invoiceId);
    } else {
      updated.add(invoiceId);
    }
    state = state.copyWith(selectedInvoiceIds: updated);
  }

  void selectAllInvoices(bool select) {
    if (select) {
      final allIds = state.ledgerItems.map((e) => e.id).toSet();
      state = state.copyWith(selectedInvoiceIds: allIds);
    } else {
      state = state.copyWith(selectedInvoiceIds: {});
    }
  }

  Future<bool> collectPayment(Map<String, dynamic> payload) async {
    final res = await _api.collectPayment(payload);
    if (res != null) {
      await loadAll();
      if (state.selectedStudentId != null) {
        await openStudentDrawer(state.selectedStudentId!);
      }
      return true;
    }
    return false;
  }

  Future<bool> applyConcession(Map<String, dynamic> payload) async {
    final success = await _api.applyConcession(payload);
    if (success) {
      await loadAll();
    }
    return success;
  }

  Future<bool> requestRefund(Map<String, dynamic> payload) async {
    final success = await _api.requestRefund(payload);
    if (success) {
      await loadAll();
    }
    return success;
  }

  Future<bool> sendReminders(List<String> studentIds) async {
    final success = await _api.sendReminders(studentIds);
    if (success) {
      await fetchOverview();
    }
    return success;
  }
}

final financeProvider = StateNotifierProvider<FinanceNotifier, FinanceState>((ref) {
  return FinanceNotifier();
});
