import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/student_fee_models.dart';
import '../services/payment_management_api_service.dart';
import 'package:edu_shamiit_core/utils/js_helper.dart';

class StudentFeeState {
  final String selectedAcademicYear;
  final List<String> availableAcademicYears;
  final List<String> classesList;
  final List<String> feeTypesList;
  final StudentFeeKPIs kpis;
  final List<StudentFeeRosterItem> studentFeesRoster;
  final List<StudentFeeStructureItem> feeStructures;
  final List<StudentFeeInvoiceItem> invoicesList;
  final List<StudentFeePaymentItem> paymentsList;
  final int subTab; // 0=All, 1=Paid, 2=Partial, 3=Overdue, 4=Fee Structure, 5=Invoices, 6=Payments
  final String searchQuery;
  final String selectedClass;
  final String selectedStatus;
  final String selectedBillingCycle;
  final bool isLoading;
  final bool isDrawerOpen;
  final String? currentStudentId;
  final Map<String, dynamic>? selectedStudentDetail;
  final int currentPage;
  final int pageSize;
  final int totalItems;
  final int totalPages;
  final Set<String> selectedStudentIds;
  final String? sortColumn;
  final bool sortAscending;

  const StudentFeeState({
    this.selectedAcademicYear = '2026 - 2027',
    this.availableAcademicYears = const ['2026 - 2027', '2025 - 2026', '2024 - 2025'],
    this.classesList = const ['All Classes', 'Class 9', 'Class 10', 'Class 11', 'Class 12'],
    this.feeTypesList = const ['Tuition Fee', 'Lab Fee', 'Library Fee', 'Exam Fee', 'Transport Fee'],
    required this.kpis,
    this.studentFeesRoster = const [],
    this.feeStructures = const [],
    this.invoicesList = const [],
    this.paymentsList = const [],
    this.subTab = 0,
    this.searchQuery = '',
    this.selectedClass = 'All Classes',
    this.selectedStatus = 'All Status',
    this.selectedBillingCycle = 'All Cycles',
    this.isLoading = false,
    this.isDrawerOpen = false,
    this.currentStudentId,
    this.selectedStudentDetail,
    this.currentPage = 1,
    this.pageSize = 10,
    this.totalItems = 0,
    this.totalPages = 1,
    this.selectedStudentIds = const {},
    this.sortColumn,
    this.sortAscending = true,
  });

  StudentFeeState copyWith({
    String? selectedAcademicYear,
    List<String>? availableAcademicYears,
    List<String>? classesList,
    List<String>? feeTypesList,
    StudentFeeKPIs? kpis,
    List<StudentFeeRosterItem>? studentFeesRoster,
    List<StudentFeeStructureItem>? feeStructures,
    List<StudentFeeInvoiceItem>? invoicesList,
    List<StudentFeePaymentItem>? paymentsList,
    int? subTab,
    String? searchQuery,
    String? selectedClass,
    String? selectedStatus,
    String? selectedBillingCycle,
    bool? isLoading,
    bool? isDrawerOpen,
    String? currentStudentId,
    Map<String, dynamic>? selectedStudentDetail,
    bool clearSelectedStudent = false,
    int? currentPage,
    int? pageSize,
    int? totalItems,
    int? totalPages,
    Set<String>? selectedStudentIds,
    String? sortColumn,
    bool? sortAscending,
  }) {
    return StudentFeeState(
      selectedAcademicYear: selectedAcademicYear ?? this.selectedAcademicYear,
      availableAcademicYears: availableAcademicYears ?? this.availableAcademicYears,
      classesList: classesList ?? this.classesList,
      feeTypesList: feeTypesList ?? this.feeTypesList,
      kpis: kpis ?? this.kpis,
      studentFeesRoster: studentFeesRoster ?? this.studentFeesRoster,
      feeStructures: feeStructures ?? this.feeStructures,
      invoicesList: invoicesList ?? this.invoicesList,
      paymentsList: paymentsList ?? this.paymentsList,
      subTab: subTab ?? this.subTab,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedClass: selectedClass ?? this.selectedClass,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedBillingCycle: selectedBillingCycle ?? this.selectedBillingCycle,
      isLoading: isLoading ?? this.isLoading,
      isDrawerOpen: isDrawerOpen ?? this.isDrawerOpen,
      currentStudentId: clearSelectedStudent ? null : (currentStudentId ?? this.currentStudentId),
      selectedStudentDetail: clearSelectedStudent ? null : (selectedStudentDetail ?? this.selectedStudentDetail),
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalItems: totalItems ?? this.totalItems,
      totalPages: totalPages ?? this.totalPages,
      selectedStudentIds: selectedStudentIds ?? this.selectedStudentIds,
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

class StudentFeeNotifier extends StateNotifier<StudentFeeState> {
  final PaymentManagementApiService _service = PaymentManagementApiService.instance;
  Timer? _debounceTimer;

  StudentFeeNotifier() : super(StudentFeeState(kpis: StudentFeeKPIs())) {
    loadAllData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> loadAllData() async {
    state = state.copyWith(isLoading: true);
    await Future.wait([
      loadMetadata(),
      loadKPIs(),
      loadRoster(),
      loadFeeStructures(),
      loadInvoices(),
      loadPayments(),
    ]);

    // Live refresh open drawer to prevent stale financial state
    if (state.isDrawerOpen && state.currentStudentId != null) {
      final detail = await _service.getStudentFeeDetail(state.currentStudentId!);
      state = state.copyWith(selectedStudentDetail: detail);
    }

    state = state.copyWith(isLoading: false);
  }

  Future<void> loadMetadata() async {
    final meta = await _service.getStudentFeeMetadata();
    final rawClasses = meta['classes'] as List<String>? ?? [];
    final rawYears = meta['academic_years'] as List<String>? ?? [];
    final rawFeeTypes = meta['fee_types'] as List<String>? ?? [];

    final classes = ['All Classes', ...rawClasses.where((c) => c != 'All Classes')];
    state = state.copyWith(
      classesList: classes,
      availableAcademicYears: rawYears.isNotEmpty ? rawYears : state.availableAcademicYears,
      feeTypesList: rawFeeTypes.isNotEmpty ? rawFeeTypes : state.feeTypesList,
    );
  }

  Future<void> loadKPIs() async {
    final kpis = await _service.getStudentFeeSummary(state.selectedAcademicYear);
    state = state.copyWith(kpis: kpis);
  }

  Future<void> loadRoster() async {
    String? statusFilter;
    if (state.subTab == 1) {
      statusFilter = 'Paid';
    } else if (state.subTab == 2) {
      statusFilter = 'Partial';
    } else if (state.subTab == 3) {
      statusFilter = 'Overdue';
    } else if (state.selectedStatus != 'All Status') {
      statusFilter = state.selectedStatus;
    }

    final data = await _service.getStudentFeeRoster(
      academicYear: state.selectedAcademicYear,
      search: state.searchQuery,
      className: state.selectedClass,
      status: statusFilter,
      page: state.currentPage,
      pageSize: state.pageSize,
    );

    var list = data['students'] as List<StudentFeeRosterItem>? ?? [];
    final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

    // Apply client sorting if active
    if (state.sortColumn != null) {
      list = List.from(list);
      list.sort((a, b) {
        int cmp = 0;
        switch (state.sortColumn) {
          case 'name':
            cmp = a.studentName.compareTo(b.studentName);
            break;
          case 'billed':
            cmp = a.totalBilled.compareTo(b.totalBilled);
            break;
          case 'paid':
            cmp = a.paidAmount.compareTo(b.paidAmount);
            break;
          case 'balance':
            cmp = a.balanceAmount.compareTo(b.balanceAmount);
            break;
          case 'status':
            cmp = a.status.compareTo(b.status);
            break;
          default:
            cmp = a.studentName.compareTo(b.studentName);
        }
        return state.sortAscending ? cmp : -cmp;
      });
    }

    state = state.copyWith(
      studentFeesRoster: list,
      totalItems: (pagination['total_items'] as num?)?.toInt() ?? list.length,
      totalPages: (pagination['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<void> loadFeeStructures() async {
    final structures = await _service.getStudentFeeStructures();
    state = state.copyWith(feeStructures: structures);
  }

  Future<void> loadInvoices() async {
    final res = await _service.getAllStudentInvoices(search: state.searchQuery);
    final invs = res['invoices'] as List<StudentFeeInvoiceItem>? ?? [];
    state = state.copyWith(invoicesList: invs);
  }

  Future<void> loadPayments() async {
    final res = await _service.getAllStudentPayments(search: state.searchQuery);
    final pays = res['payments'] as List<StudentFeePaymentItem>? ?? [];
    state = state.copyWith(paymentsList: pays);
  }

  void setAcademicYear(String year) {
    if (state.selectedAcademicYear != year) {
      state = state.copyWith(selectedAcademicYear: year, currentPage: 1);
      loadAllData();
    }
  }

  void setSubTab(int index) {
    state = state.copyWith(subTab: index, currentPage: 1);
    loadRoster();
  }

  void setSearchQuery(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      state = state.copyWith(searchQuery: query, currentPage: 1);
      loadRoster();
      if (state.subTab == 5) loadInvoices();
      if (state.subTab == 6) loadPayments();
    });
  }

  void setClassFilter(String cls) {
    state = state.copyWith(selectedClass: cls, currentPage: 1);
    loadRoster();
  }

  void setStatusFilter(String status) {
    state = state.copyWith(selectedStatus: status, currentPage: 1);
    loadRoster();
  }

  void setPage(int page) {
    if (page >= 1 && page <= state.totalPages && page != state.currentPage) {
      state = state.copyWith(currentPage: page);
      loadRoster();
    }
  }

  void toggleSort(String column) {
    if (state.sortColumn == column) {
      state = state.copyWith(sortAscending: !state.sortAscending);
    } else {
      state = state.copyWith(sortColumn: column, sortAscending: true);
    }
    loadRoster();
  }

  Future<void> openStudentDrawer(String studentId) async {
    state = state.copyWith(isLoading: true, currentStudentId: studentId);
    final detail = await _service.getStudentFeeDetail(studentId);
    state = state.copyWith(
      isDrawerOpen: true,
      currentStudentId: studentId,
      selectedStudentDetail: detail,
      isLoading: false,
    );
  }

  void closeStudentDrawer() {
    state = state.copyWith(
      isDrawerOpen: false,
      clearSelectedStudent: true,
      currentStudentId: null,
    );
  }

  void toggleStudentSelection(String studentId) {
    final updated = Set<String>.from(state.selectedStudentIds);
    if (updated.contains(studentId)) {
      updated.remove(studentId);
    } else {
      updated.add(studentId);
    }
    state = state.copyWith(selectedStudentIds: updated);
  }

  void toggleSelectAll(bool selectAll) {
    if (selectAll) {
      final allIds = state.studentFeesRoster.map((e) => e.studentId).toSet();
      state = state.copyWith(selectedStudentIds: allIds);
    } else {
      state = state.copyWith(selectedStudentIds: {});
    }
  }

  Future<bool> executeBulkAction(String action) async {
    if (state.selectedStudentIds.isEmpty) return false;
    final ok = await _service.executeStudentFeeBulkAction({
      'action': action,
      'ids': state.selectedStudentIds.toList(),
    });
    if (ok) {
      state = state.copyWith(selectedStudentIds: {});
      await loadAllData();
    }
    return ok;
  }

  Future<bool> updatePaymentStatus(String paymentId, String status, {String? remarks}) async {
    final ok = await _service.updateStudentPaymentStatus(paymentId, status, remarks: remarks);
    if (ok) {
      if (state.currentStudentId != null) {
        final detail = await _service.getStudentFeeDetail(state.currentStudentId!);
        state = state.copyWith(selectedStudentDetail: detail);
      }
      await Future.wait([
        loadKPIs(),
        loadRoster(),
        loadPayments(),
      ]);
    }
    return ok;
  }

  Future<bool> deleteConcession(String concessionId) async {
    final ok = await _service.deleteStudentConcession(concessionId);
    if (ok) await loadAllData();
    return ok;
  }

  Future<bool> deletePenalty(String penaltyId) async {
    final ok = await _service.deleteStudentPenalty(penaltyId);
    if (ok) await loadAllData();
    return ok;
  }

  void exportCsv() {
    final year = Uri.encodeComponent(state.selectedAcademicYear);
    final url = '/api/v1/payment-management/student-fees/export/csv?academic_year=$year';
    try {
      downloadFileWeb(url, 'Student_Fees_Roster.csv');
    } catch (_) {}
  }
}

final studentFeeProvider = StateNotifierProvider<StudentFeeNotifier, StudentFeeState>((ref) {
  return StudentFeeNotifier();
});
