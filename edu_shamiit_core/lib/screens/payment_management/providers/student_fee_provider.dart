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
  final FeeStructureCohortSummary? feeStructureSummary;
  final List<StudentFeeInvoiceItem> invoicesList;
  final List<StudentFeePaymentItem> paymentsList;
  final int subTab; // 0=All, 1=Paid, 2=Partial, 3=Pending, 4=Overdue, 5=Advance/Overpaid, 6=Fee Structure, 7=Invoices, 8=Payments
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
  final List<Map<String, dynamic>> scheduleRules;
  final List<Map<String, dynamic>> scheduleRuns;
  final bool loadingRules;
  final bool loadingRuns;
  final Map<String, List<String>> classesWithSections;

  const StudentFeeState({
    this.selectedAcademicYear = '2026 - 2027',
    this.availableAcademicYears = const ['2026 - 2027', '2025 - 2026', '2024 - 2025'],
    this.classesList = const ['All Classes', 'Class 9', 'Class 10', 'Class 11', 'Class 12'],
    this.feeTypesList = const ['Tuition Fee', 'Lab Fee', 'Library Fee', 'Exam Fee', 'Transport Fee'],
    required this.kpis,
    this.studentFeesRoster = const [],
    this.feeStructures = const [],
    this.feeStructureSummary,
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
    this.scheduleRules = const [],
    this.scheduleRuns = const [],
    this.loadingRules = false,
    this.loadingRuns = false,
    this.classesWithSections = const {},
  });

  StudentFeeState copyWith({
    String? selectedAcademicYear,
    List<String>? availableAcademicYears,
    List<String>? classesList,
    List<String>? feeTypesList,
    StudentFeeKPIs? kpis,
    List<StudentFeeRosterItem>? studentFeesRoster,
    List<StudentFeeStructureItem>? feeStructures,
    FeeStructureCohortSummary? feeStructureSummary,
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
    List<Map<String, dynamic>>? scheduleRules,
    List<Map<String, dynamic>>? scheduleRuns,
    bool? loadingRules,
    bool? loadingRuns,
    Map<String, List<String>>? classesWithSections,
  }) {
    return StudentFeeState(
      selectedAcademicYear: selectedAcademicYear ?? this.selectedAcademicYear,
      availableAcademicYears: availableAcademicYears ?? this.availableAcademicYears,
      classesList: classesList ?? this.classesList,
      feeTypesList: feeTypesList ?? this.feeTypesList,
      kpis: kpis ?? this.kpis,
      studentFeesRoster: studentFeesRoster ?? this.studentFeesRoster,
      feeStructures: feeStructures ?? this.feeStructures,
      feeStructureSummary: feeStructureSummary ?? this.feeStructureSummary,
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
      scheduleRules: scheduleRules ?? this.scheduleRules,
      scheduleRuns: scheduleRuns ?? this.scheduleRuns,
      loadingRules: loadingRules ?? this.loadingRules,
      loadingRuns: loadingRuns ?? this.loadingRuns,
      classesWithSections: classesWithSections ?? this.classesWithSections,
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
    try {
      await Future.wait([
        loadMetadata().catchError((_) {}),
        loadKPIs().catchError((_) {}),
        if (state.subTab <= 5)
          loadRoster().catchError((_) {})
        else if (state.subTab == 6)
          loadFeeStructures().catchError((_) {})
        else if (state.subTab == 7)
          loadInvoices().catchError((_) {})
        else if (state.subTab == 8)
          loadPayments().catchError((_) {}),
      ]);

      state = state.copyWith(isLoading: false);
      _prefetchOtherTabsInBackground();
    } catch (_) {
      state = state.copyWith(isLoading: false);
    } finally {
      state = state.copyWith(isLoading: false);
    }

    // Live refresh open drawer to prevent stale financial state
    if (state.isDrawerOpen && state.currentStudentId != null) {
      final detail = await _service.getStudentFeeDetail(state.currentStudentId!);
      state = state.copyWith(selectedStudentDetail: detail);
    }
  }

  void _prefetchOtherTabsInBackground() {
    if (state.feeStructures.isEmpty) {
      loadFeeStructures().catchError((_) {});
    }
    if (state.invoicesList.isEmpty) {
      loadInvoices().catchError((_) {});
    }
    if (state.paymentsList.isEmpty) {
      loadPayments().catchError((_) {});
    }
  }

  Future<void> loadMetadata() async {
    final meta = await _service.getStudentFeeMetadata();
    final rawClasses = meta['classes'] as List<String>? ?? [];
    final rawYears = meta['academic_years'] as List<String>? ?? [];
    final rawFeeTypes = meta['fee_types'] as List<String>? ?? [];
    final rawClassesWithSections = meta['classes_with_sections'] as List<dynamic>? ?? [];

    final Map<String, List<String>> sectionsMap = {};
    for (final item in rawClassesWithSections) {
      if (item is Map) {
        final cName = item['class_name']?.toString() ?? '';
        final secs = (item['sections'] as List?)?.map((s) => s.toString()).toList() ?? <String>[];
        if (cName.isNotEmpty) {
          sectionsMap[cName] = secs;
        }
      }
    }

    final classes = ['All Classes', ...rawClasses.where((c) => c != 'All Classes')];
    state = state.copyWith(
      classesList: classes,
      availableAcademicYears: rawYears.isNotEmpty ? rawYears : state.availableAcademicYears,
      feeTypesList: rawFeeTypes.isNotEmpty ? rawFeeTypes : state.feeTypesList,
      classesWithSections: sectionsMap,
    );
  }

  Future<void> loadKPIs() async {
    try {
      final kpis = await _service.getStudentFeeSummary(
        state.selectedAcademicYear,
        className: state.selectedClass,
      );
      state = state.copyWith(kpis: kpis);
    } catch (_) {}
  }

  Future<void> loadRoster() async {
    String? statusFilter;
    if (state.subTab == 1) {
      statusFilter = 'Paid';
    } else if (state.subTab == 2) {
      statusFilter = 'Partial';
    } else if (state.subTab == 3) {
      statusFilter = 'Pending';
    } else if (state.subTab == 4) {
      statusFilter = 'Overdue';
    } else if (state.subTab == 5) {
      statusFilter = 'Overpaid';
    } else if (state.selectedStatus != 'All Status') {
      statusFilter = state.selectedStatus;
    }

    final data = await _service.getStudentFeeRoster(
      academicYear: state.selectedAcademicYear,
      search: state.searchQuery,
      className: state.selectedClass,
      status: statusFilter,
      sortBy: state.sortColumn ?? 'name',
      sortOrder: state.sortAscending ? 'ASC' : 'DESC',
      page: state.currentPage,
      pageSize: state.pageSize,
    );

    final list = data['students'] as List<StudentFeeRosterItem>? ?? [];
    final rawPagination = data['pagination'];
    final pagination = rawPagination is Map
        ? Map<String, dynamic>.from(rawPagination)
        : <String, dynamic>{};

    state = state.copyWith(
      studentFeesRoster: list,
      totalItems: (pagination['total_items'] as num?)?.toInt() ?? list.length,
      totalPages: (pagination['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<void> loadFeeStructures({
    String? classGrade,
    String? sectionName,
    String? frequencyType,
    String? search,
  }) async {
    final res = await _service.getStudentFeeStructuresWithSummary(
      classGrade: classGrade,
      sectionName: sectionName,
      frequencyType: frequencyType,
      search: search,
    );
    final structures = res['structures'] as List<StudentFeeStructureItem>? ?? [];
    final summary = res['summary'] as FeeStructureCohortSummary?;
    state = state.copyWith(
      feeStructures: structures,
      feeStructureSummary: summary,
    );
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

  void setSubTab(int index, {String? statusFilter}) {
    final newStatus = statusFilter ??
        (index == 1
            ? 'Paid'
            : index == 2
                ? 'Partial'
                : index == 3
                    ? 'Pending'
                    : index == 4
                        ? 'Overdue'
                        : index == 5
                            ? 'Overpaid'
                            : 'All Status');
    state = state.copyWith(
      subTab: index,
      currentPage: 1,
      selectedStatus: (index <= 5) ? newStatus : state.selectedStatus,
    );
    if (index <= 5) {
      loadRoster();
    } else if (index == 6) {
      loadFeeStructures();
    } else if (index == 7) {
      loadInvoices();
    } else if (index == 8) {
      loadPayments();
    }
  }

  void setSearchQuery(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      state = state.copyWith(searchQuery: query, currentPage: 1);
      if (state.subTab <= 5) {
        loadRoster();
      } else if (state.subTab == 7) {
        loadInvoices();
      } else if (state.subTab == 8) {
        loadPayments();
      }
    });
  }

  void setClassFilter(String cls) {
    state = state.copyWith(selectedClass: cls, currentPage: 1);
    loadKPIs();
    loadRoster();
  }

  void setStatusFilter(String status) {
    int newSubTab = state.subTab;
    if (status == 'All Status' || status == 'All Fees' || status == 'All') {
      newSubTab = 0;
    } else if (status == 'Paid') {
      newSubTab = 1;
    } else if (status == 'Partial') {
      newSubTab = 2;
    } else if (status == 'Pending') {
      newSubTab = 3;
    } else if (status == 'Overdue') {
      newSubTab = 4;
    } else if (status == 'Overpaid') {
      newSubTab = 5;
    }
    state = state.copyWith(selectedStatus: status, subTab: newSubTab, currentPage: 1);
    loadRoster();
  }

  void setPage(int page) {
    if (page >= 1 && page <= state.totalPages && page != state.currentPage) {
      state = state.copyWith(currentPage: page);
      loadRoster();
    }
  }

  void setPageSize(int size) {
    if (state.pageSize != size) {
      state = state.copyWith(pageSize: size, currentPage: 1);
      loadRoster();
    }
  }

  void toggleSort(String column) {
    if (state.sortColumn == column) {
      state = state.copyWith(sortAscending: !state.sortAscending, currentPage: 1);
    } else {
      state = state.copyWith(sortColumn: column, sortAscending: true, currentPage: 1);
    }
    loadRoster();
  }

  void clearSelection() {
    state = state.copyWith(selectedStudentIds: {});
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

  Future<Map<String, dynamic>> processStudentRefund(Map<String, dynamic> payload) async {
    final res = await _service.refundStudentFee(payload);
    if (res['success'] == true) {
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
    return res;
  }

  Future<Map<String, dynamic>> settleInvoiceFromAdvance(String invoiceId) async {
    final res = await _service.settleInvoiceFromAdvance(invoiceId);
    if (res['success'] == true) {
      if (state.currentStudentId != null) {
        final detail = await _service.getStudentFeeDetail(state.currentStudentId!);
        state = state.copyWith(selectedStudentDetail: detail);
      }
      await Future.wait([
        loadKPIs(),
        loadRoster(),
        loadInvoices(),
        loadPayments(),
      ]);
    }
    return res;
  }

  Future<Map<String, dynamic>> settleStudentInvoicesFromAdvance(String studentId) async {
    final res = await _service.settleStudentInvoicesFromAdvance(studentId);
    if (res['success'] == true) {
      if (state.currentStudentId != null) {
        final detail = await _service.getStudentFeeDetail(state.currentStudentId!);
        state = state.copyWith(selectedStudentDetail: detail);
      }
      await Future.wait([
        loadKPIs(),
        loadRoster(),
        loadInvoices(),
        loadPayments(),
      ]);
    }
    return res;
  }

  Future<void> loadScheduleRules() async {
    state = state.copyWith(loadingRules: true);
    final rules = await _service.getFeeScheduleRules();
    state = state.copyWith(scheduleRules: rules, loadingRules: false);
  }

  Future<void> loadScheduleRuns({String? ruleId}) async {
    state = state.copyWith(loadingRuns: true);
    final runs = await _service.getFeeScheduleRuns(ruleId: ruleId);
    state = state.copyWith(scheduleRuns: runs, loadingRuns: false);
  }

  Future<Map<String, dynamic>> createScheduleRule(Map<String, dynamic> payload) async {
    final res = await _service.createFeeScheduleRule(payload);
    if (res['success'] == true) {
      await loadScheduleRules();
    }
    return res;
  }

  Future<Map<String, dynamic>> createBatchCohortSchedules({
    required String targetClass,
    String targetSection = 'All Sections',
    String academicYear = '2026 - 2027',
    bool autoDeductAdvanceCredit = true,
    bool sendParentEmail = true,
  }) async {
    final res = await _service.createBatchCohortSchedules(
      targetClass: targetClass,
      targetSection: targetSection,
      academicYear: academicYear,
      autoDeductAdvanceCredit: autoDeductAdvanceCredit,
      sendParentEmail: sendParentEmail,
    );
    if (res['success'] == true) {
      await loadScheduleRules();
    }
    return res;
  }

  Future<Map<String, dynamic>> updateScheduleRule(String ruleId, Map<String, dynamic> payload) async {
    final res = await _service.updateFeeScheduleRule(ruleId, payload);
    if (res['success'] == true) {
      await loadScheduleRules();
    }
    return res;
  }

  Future<bool> toggleScheduleRule(String ruleId) async {
    final res = await _service.toggleFeeScheduleRule(ruleId);
    if (res['success'] == true) {
      await loadScheduleRules();
      return true;
    }
    return false;
  }

  Future<bool> deleteScheduleRule(String ruleId) async {
    final ok = await _service.deleteFeeScheduleRule(ruleId);
    if (ok) {
      await loadScheduleRules();
    }
    return ok;
  }

  Future<Map<String, dynamic>> runScheduleRuleNow(String ruleId) async {
    final res = await _service.runFeeScheduleRuleNow(ruleId);
    if (res['success'] == true) {
      await Future.wait([
        loadScheduleRules(),
        loadScheduleRuns(),
        loadKPIs(),
        loadInvoices(),
        loadRoster(),
      ]);
    }
    return res;
  }

  Future<Map<String, dynamic>> enhancedBulkGenerate(Map<String, dynamic> payload) async {
    final res = await _service.enhancedBulkGenerateInvoices(payload);
    if (res['success'] == true) {
      await Future.wait([
        loadKPIs(),
        loadInvoices(),
        loadRoster(),
        loadScheduleRuns(),
      ]);
    }
    return res;
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
