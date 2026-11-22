import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/staff_salary_models.dart';
import '../services/payment_management_api_service.dart';
import 'package:edu_shamiit_core/utils/js_helper.dart';

class StaffSalaryState {
  final String selectedMonthStr; // e.g. '2026-10'
  final List<String> availableMonths;
  final List<String> departmentsList;
  final List<String> rolesList;
  final StaffSalaryKPIs kpis;
  final List<StaffSalaryRosterItem> staffRoster;
  final List<StaffSalaryStructureItem> salaryStructures;
  final List<StaffPayslipItem> payslipsList;
  final List<StaffSalaryAdvanceItem> advancesList;
  final int subTab; // 0=All Staff, 1=Paid, 2=Pending, 3=On Hold, 4=Salary Structures, 5=Payslips, 6=Advances
  final String searchQuery;
  final String selectedDepartment;
  final String selectedRole;
  final String selectedStatus;
  final bool isLoading;
  final bool isDrawerOpen;
  final bool isRightSummaryVisible;
  final String? currentStaffId;
  final Map<String, dynamic>? selectedStaffDetail;

  // Pagination & Sorting for Roster (Tabs 0-3)
  final int currentPage;
  final int pageSize;
  final int totalItems;
  final int totalPages;
  final Set<String> selectedStaffIds;
  final String? sortColumn;
  final bool sortAscending;

  // Pagination & Sorting for Structures (Tab 4)
  final int structuresPage;
  final int structuresPageSize;
  final int structuresTotal;
  final int structuresTotalPages;
  final String structuresSearch;
  final String structuresDept;
  final String structuresSortColumn;
  final bool structuresSortAscending;

  // Pagination & Sorting for Payslips (Tab 5)
  final int payslipsPage;
  final int payslipsPageSize;
  final int payslipsTotal;
  final int payslipsTotalPages;
  final String payslipsSearch;
  final String payslipsDept;
  final String payslipsSortColumn;
  final bool payslipsSortAscending;

  // Pagination & Sorting for Advances (Tab 6)
  final int advancesPage;
  final int advancesPageSize;
  final int advancesTotal;
  final int advancesTotalPages;
  final String advancesSearch;
  final String advancesStatus;
  final String advancesSortColumn;
  final bool advancesSortAscending;

  const StaffSalaryState({
    this.selectedMonthStr = '2026-10',
    this.availableMonths = const ['2026-12', '2026-11', '2026-10', '2026-09', '2026-08'],
    this.departmentsList = const ['All Departments', 'Academic & Teaching', 'Administration', 'Finance & Accounts', 'Hostel Staff', 'IT & Support'],
    this.rolesList = const ['All Roles', 'teacher', 'admin', 'accountant', 'hostel_warden', 'driver'],
    required this.kpis,
    this.staffRoster = const [],
    this.salaryStructures = const [],
    this.payslipsList = const [],
    this.advancesList = const [],
    this.subTab = 0,
    this.searchQuery = '',
    this.selectedDepartment = 'All Departments',
    this.selectedRole = 'All Roles',
    this.selectedStatus = 'All Status',
    this.isLoading = false,
    this.isDrawerOpen = false,
    this.isRightSummaryVisible = true,
    this.currentStaffId,
    this.selectedStaffDetail,
    this.currentPage = 1,
    this.pageSize = 10,
    this.totalItems = 0,
    this.totalPages = 1,
    this.selectedStaffIds = const {},
    this.sortColumn,
    this.sortAscending = true,
    this.structuresPage = 1,
    this.structuresPageSize = 10,
    this.structuresTotal = 0,
    this.structuresTotalPages = 1,
    this.structuresSearch = '',
    this.structuresDept = 'All Departments',
    this.structuresSortColumn = 'name',
    this.structuresSortAscending = true,
    this.payslipsPage = 1,
    this.payslipsPageSize = 10,
    this.payslipsTotal = 0,
    this.payslipsTotalPages = 1,
    this.payslipsSearch = '',
    this.payslipsDept = 'All Departments',
    this.payslipsSortColumn = 'payslip_number',
    this.payslipsSortAscending = false,
    this.advancesPage = 1,
    this.advancesPageSize = 10,
    this.advancesTotal = 0,
    this.advancesTotalPages = 1,
    this.advancesSearch = '',
    this.advancesStatus = 'All Status',
    this.advancesSortColumn = 'created_at',
    this.advancesSortAscending = false,
  });

  StaffSalaryState copyWith({
    String? selectedMonthStr,
    List<String>? availableMonths,
    List<String>? departmentsList,
    List<String>? rolesList,
    StaffSalaryKPIs? kpis,
    List<StaffSalaryRosterItem>? staffRoster,
    List<StaffSalaryStructureItem>? salaryStructures,
    List<StaffPayslipItem>? payslipsList,
    List<StaffSalaryAdvanceItem>? advancesList,
    int? subTab,
    String? searchQuery,
    String? selectedDepartment,
    String? selectedRole,
    String? selectedStatus,
    bool? isLoading,
    bool? isDrawerOpen,
    bool? isRightSummaryVisible,
    String? currentStaffId,
    Map<String, dynamic>? selectedStaffDetail,
    bool clearSelectedStaff = false,
    int? currentPage,
    int? pageSize,
    int? totalItems,
    int? totalPages,
    Set<String>? selectedStaffIds,
    String? sortColumn,
    bool? sortAscending,
    int? structuresPage,
    int? structuresPageSize,
    int? structuresTotal,
    int? structuresTotalPages,
    String? structuresSearch,
    String? structuresDept,
    String? structuresSortColumn,
    bool? structuresSortAscending,
    int? payslipsPage,
    int? payslipsPageSize,
    int? payslipsTotal,
    int? payslipsTotalPages,
    String? payslipsSearch,
    String? payslipsDept,
    String? payslipsSortColumn,
    bool? payslipsSortAscending,
    int? advancesPage,
    int? advancesPageSize,
    int? advancesTotal,
    int? advancesTotalPages,
    String? advancesSearch,
    String? advancesStatus,
    String? advancesSortColumn,
    bool? advancesSortAscending,
  }) {
    return StaffSalaryState(
      selectedMonthStr: selectedMonthStr ?? this.selectedMonthStr,
      availableMonths: availableMonths ?? this.availableMonths,
      departmentsList: departmentsList ?? this.departmentsList,
      rolesList: rolesList ?? this.rolesList,
      kpis: kpis ?? this.kpis,
      staffRoster: staffRoster ?? this.staffRoster,
      salaryStructures: salaryStructures ?? this.salaryStructures,
      payslipsList: payslipsList ?? this.payslipsList,
      advancesList: advancesList ?? this.advancesList,
      subTab: subTab ?? this.subTab,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedDepartment: selectedDepartment ?? this.selectedDepartment,
      selectedRole: selectedRole ?? this.selectedRole,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      isLoading: isLoading ?? this.isLoading,
      isDrawerOpen: isDrawerOpen ?? this.isDrawerOpen,
      isRightSummaryVisible: isRightSummaryVisible ?? this.isRightSummaryVisible,
      currentStaffId: clearSelectedStaff ? null : (currentStaffId ?? this.currentStaffId),
      selectedStaffDetail: clearSelectedStaff ? null : (selectedStaffDetail ?? this.selectedStaffDetail),
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalItems: totalItems ?? this.totalItems,
      totalPages: totalPages ?? this.totalPages,
      selectedStaffIds: selectedStaffIds ?? this.selectedStaffIds,
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
      structuresPage: structuresPage ?? this.structuresPage,
      structuresPageSize: structuresPageSize ?? this.structuresPageSize,
      structuresTotal: structuresTotal ?? this.structuresTotal,
      structuresTotalPages: structuresTotalPages ?? this.structuresTotalPages,
      structuresSearch: structuresSearch ?? this.structuresSearch,
      structuresDept: structuresDept ?? this.structuresDept,
      structuresSortColumn: structuresSortColumn ?? this.structuresSortColumn,
      structuresSortAscending: structuresSortAscending ?? this.structuresSortAscending,
      payslipsPage: payslipsPage ?? this.payslipsPage,
      payslipsPageSize: payslipsPageSize ?? this.payslipsPageSize,
      payslipsTotal: payslipsTotal ?? this.payslipsTotal,
      payslipsTotalPages: payslipsTotalPages ?? this.payslipsTotalPages,
      payslipsSearch: payslipsSearch ?? this.payslipsSearch,
      payslipsDept: payslipsDept ?? this.payslipsDept,
      payslipsSortColumn: payslipsSortColumn ?? this.payslipsSortColumn,
      payslipsSortAscending: payslipsSortAscending ?? this.payslipsSortAscending,
      advancesPage: advancesPage ?? this.advancesPage,
      advancesPageSize: advancesPageSize ?? this.advancesPageSize,
      advancesTotal: advancesTotal ?? this.advancesTotal,
      advancesTotalPages: advancesTotalPages ?? this.advancesTotalPages,
      advancesSearch: advancesSearch ?? this.advancesSearch,
      advancesStatus: advancesStatus ?? this.advancesStatus,
      advancesSortColumn: advancesSortColumn ?? this.advancesSortColumn,
      advancesSortAscending: advancesSortAscending ?? this.advancesSortAscending,
    );
  }
}

class StaffSalaryNotifier extends StateNotifier<StaffSalaryState> {
  final PaymentManagementApiService _service = PaymentManagementApiService.instance;
  Timer? _debounceTimer;

  StaffSalaryNotifier() : super(StaffSalaryState(kpis: StaffSalaryKPIs())) {
    loadAllData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void toggleRightSummary() {
    state = state.copyWith(isRightSummaryVisible: !state.isRightSummaryVisible);
  }

  Future<void> loadAllData() async {
    state = state.copyWith(isLoading: true);
    try {
      await Future.wait([
        loadMetadata(),
        loadKPIs(),
        if (state.subTab <= 3)
          loadRoster()
        else if (state.subTab == 4)
          loadSalaryStructures()
        else if (state.subTab == 5)
          loadPayslips()
        else if (state.subTab == 6)
          loadAdvances(),
      ]);

      state = state.copyWith(isLoading: false);
      _prefetchOtherTabsInBackground();
    } catch (_) {
      state = state.copyWith(isLoading: false);
    } finally {
      state = state.copyWith(isLoading: false);
    }

    // Live refresh open drawer to prevent stale financial state
    if (state.isDrawerOpen && state.currentStaffId != null) {
      final detail = await _service.getStaffSalaryDetail(state.currentStaffId!);
      state = state.copyWith(selectedStaffDetail: detail);
    }
  }

  void _prefetchOtherTabsInBackground() {
    if (state.salaryStructures.isEmpty) {
      loadSalaryStructures();
    }
    if (state.payslipsList.isEmpty) {
      loadPayslips();
    }
    if (state.advancesList.isEmpty) {
      loadAdvances();
    }
  }

  Future<void> loadMetadata() async {
    final meta = await _service.getStaffSalaryMetadata();
    final rawDepts = meta['departments'] as List<String>? ?? [];
    final rawRoles = meta['roles'] as List<String>? ?? [];
    final rawMonths = meta['available_months'] as List<String>? ?? [];

    final depts = ['All Departments', ...rawDepts.where((d) => d != 'All Departments')];
    final roles = ['All Roles', ...rawRoles.where((r) => r != 'All Roles')];

    state = state.copyWith(
      departmentsList: depts,
      rolesList: roles,
      availableMonths: rawMonths.isNotEmpty ? rawMonths : state.availableMonths,
    );
  }

  Future<void> loadKPIs() async {
    final kpis = await _service.getStaffSalarySummary(state.selectedMonthStr);
    state = state.copyWith(kpis: kpis);
  }

  Future<void> loadRoster() async {
    String? statusFilter;
    if (state.subTab == 1) {
      statusFilter = 'Paid';
    } else if (state.subTab == 2) {
      statusFilter = 'Pending';
    } else if (state.subTab == 3) {
      statusFilter = 'On Hold';
    } else if (state.selectedStatus != 'All Status') {
      statusFilter = state.selectedStatus;
    }

    final data = await _service.getStaffSalaryRoster(
      monthStr: state.selectedMonthStr,
      search: state.searchQuery,
      department: state.selectedDepartment,
      role: state.selectedRole,
      status: statusFilter,
      sortBy: state.sortColumn ?? 'name',
      sortOrder: state.sortAscending ? 'ASC' : 'DESC',
      page: state.currentPage,
      pageSize: state.pageSize,
    );

    final list = data['staff'] as List<StaffSalaryRosterItem>? ?? [];
    final rawPagination = data['pagination'];
    final pagination = rawPagination is Map
        ? Map<String, dynamic>.from(rawPagination)
        : <String, dynamic>{};

    state = state.copyWith(
      staffRoster: list,
      totalItems: (pagination['total_items'] as num?)?.toInt() ?? list.length,
      totalPages: (pagination['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  // --- Sub-Tab 4: Structures Catalog ---
  Future<void> loadSalaryStructures() async {
    final res = await _service.getSalaryStructuresCatalog(
      department: state.structuresDept,
      search: state.structuresSearch,
      sortBy: state.structuresSortColumn,
      sortOrder: state.structuresSortAscending ? 'ASC' : 'DESC',
      page: state.structuresPage,
      pageSize: state.structuresPageSize,
    );
    final structs = res['structures'] as List<StaffSalaryStructureItem>? ?? [];
    state = state.copyWith(
      salaryStructures: structs,
      structuresTotal: (res['total_items'] as num?)?.toInt() ?? structs.length,
      structuresTotalPages: (res['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  void setStructuresPage(int page) {
    if (page >= 1 && page <= state.structuresTotalPages && page != state.structuresPage) {
      state = state.copyWith(structuresPage: page);
      loadSalaryStructures();
    }
  }

  void setStructuresPageSize(int size) {
    if (state.structuresPageSize != size) {
      state = state.copyWith(structuresPageSize: size, structuresPage: 1);
      loadSalaryStructures();
    }
  }

  void setStructuresSearch(String q) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      state = state.copyWith(structuresSearch: q, structuresPage: 1);
      loadSalaryStructures();
    });
  }

  void setStructuresDept(String dept) {
    state = state.copyWith(structuresDept: dept, structuresPage: 1);
    loadSalaryStructures();
  }

  void toggleStructuresSort(String column) {
    if (state.structuresSortColumn == column) {
      state = state.copyWith(structuresSortAscending: !state.structuresSortAscending, structuresPage: 1);
    } else {
      state = state.copyWith(structuresSortColumn: column, structuresSortAscending: true, structuresPage: 1);
    }
    loadSalaryStructures();
  }

  Future<bool> saveSalaryStructure(Map<String, dynamic> payload) async {
    final ok = await _service.createSalaryStructure(payload);
    if (ok) {
      await loadSalaryStructures();
      await loadRoster();
    }
    return ok;
  }

  Future<Map<String, dynamic>> runAutomatedPayroll({bool sendEmail = true}) async {
    state = state.copyWith(isLoading: true);
    final res = await _service.triggerAutoPayrollRun(
      monthStr: state.selectedMonthStr,
      sendEmail: sendEmail,
    );
    await loadAllData();
    state = state.copyWith(isLoading: false);
    return res;
  }


  // --- Sub-Tab 5: Payslips Master ---
  Future<void> loadPayslips() async {
    final res = await _service.getStaffPayslips(
      monthStr: state.selectedMonthStr,
      department: state.payslipsDept,
      search: state.payslipsSearch,
      sortBy: state.payslipsSortColumn,
      sortOrder: state.payslipsSortAscending ? 'ASC' : 'DESC',
      page: state.payslipsPage,
      pageSize: state.payslipsPageSize,
    );
    final pays = res['payslips'] as List<StaffPayslipItem>? ?? [];
    state = state.copyWith(
      payslipsList: pays,
      payslipsTotal: (res['total_items'] as num?)?.toInt() ?? pays.length,
      payslipsTotalPages: (res['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  void setPayslipsPage(int page) {
    if (page >= 1 && page <= state.payslipsTotalPages && page != state.payslipsPage) {
      state = state.copyWith(payslipsPage: page);
      loadPayslips();
    }
  }

  void setPayslipsPageSize(int size) {
    if (state.payslipsPageSize != size) {
      state = state.copyWith(payslipsPageSize: size, payslipsPage: 1);
      loadPayslips();
    }
  }

  void setPayslipsSearch(String q) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      state = state.copyWith(payslipsSearch: q, payslipsPage: 1);
      loadPayslips();
    });
  }

  void setPayslipsDept(String dept) {
    state = state.copyWith(payslipsDept: dept, payslipsPage: 1);
    loadPayslips();
  }

  void togglePayslipsSort(String column) {
    if (state.payslipsSortColumn == column) {
      state = state.copyWith(payslipsSortAscending: !state.payslipsSortAscending, payslipsPage: 1);
    } else {
      state = state.copyWith(payslipsSortColumn: column, payslipsSortAscending: true, payslipsPage: 1);
    }
    loadPayslips();
  }

  void exportBankDisbursalFile() {
    final month = Uri.encodeComponent(state.selectedMonthStr);
    final url = '/api/v1/payment-management/staff-salary/export/bank-file?month_str=$month';
    try {
      downloadFileWeb(url, 'Bank_Disbursal_$month.csv');
    } catch (_) {}
  }

  // --- Sub-Tab 6: Advances Master ---
  Future<void> loadAdvances() async {
    final res = await _service.getStaffSalaryAdvances(
      status: state.advancesStatus,
      search: state.advancesSearch,
      sortBy: state.advancesSortColumn,
      sortOrder: state.advancesSortAscending ? 'ASC' : 'DESC',
      page: state.advancesPage,
      pageSize: state.advancesPageSize,
    );
    final advs = res['advances'] as List<StaffSalaryAdvanceItem>? ?? [];
    state = state.copyWith(
      advancesList: advs,
      advancesTotal: (res['total_items'] as num?)?.toInt() ?? advs.length,
      advancesTotalPages: (res['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  void setAdvancesPage(int page) {
    if (page >= 1 && page <= state.advancesTotalPages && page != state.advancesPage) {
      state = state.copyWith(advancesPage: page);
      loadAdvances();
    }
  }

  void setAdvancesPageSize(int size) {
    if (state.advancesPageSize != size) {
      state = state.copyWith(advancesPageSize: size, advancesPage: 1);
      loadAdvances();
    }
  }

  void setAdvancesSearch(String q) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      state = state.copyWith(advancesSearch: q, advancesPage: 1);
      loadAdvances();
    });
  }

  void setAdvancesStatus(String status) {
    state = state.copyWith(advancesStatus: status, advancesPage: 1);
    loadAdvances();
  }

  void toggleAdvancesSort(String column) {
    if (state.advancesSortColumn == column) {
      state = state.copyWith(advancesSortAscending: !state.advancesSortAscending, advancesPage: 1);
    } else {
      state = state.copyWith(advancesSortColumn: column, advancesSortAscending: true, advancesPage: 1);
    }
    loadAdvances();
  }

  Future<bool> settleAdvance(
    String advanceId, {
    required double settlementAmount,
    String paymentMode = 'Cash',
    String remarks = 'Early loan clearance',
  }) async {
    final ok = await _service.settleStaffSalaryAdvance(
      advanceId,
      settlementAmount: settlementAmount,
      paymentMode: paymentMode,
      remarks: remarks,
    );
    if (ok) {
      await loadAdvances();
      await loadRoster();
    }
    return ok;
  }

  Future<bool> bulkRunPayroll({
    String paymentMode = 'Direct Bank Transfer (NEFT/RTGS)',
    String? department,
  }) async {
    state = state.copyWith(isLoading: true);
    final parts = state.selectedMonthStr.split('-');
    final yr = int.tryParse(parts[0]) ?? 2026;
    final mo = parts.length > 1 ? (int.tryParse(parts[1]) ?? 10) : 10;

    final ok = await _service.bulkProcessStaffPayroll({
      'month': mo,
      'year': yr,
      'month_str': state.selectedMonthStr,
      'department': department ?? state.selectedDepartment,
      'payment_mode': paymentMode,
    });

    await loadAllData();
    state = state.copyWith(isLoading: false);
    return ok;
  }

  void setMonth(String monthStr) {
    if (state.selectedMonthStr != monthStr) {
      state = state.copyWith(selectedMonthStr: monthStr, currentPage: 1, structuresPage: 1, payslipsPage: 1, advancesPage: 1);
      loadAllData();
    }
  }

  void setSubTab(int index, {String? statusFilter}) {
    final newStatus = statusFilter ??
        (index == 1
            ? 'Paid'
            : index == 2
                ? 'Pending'
                : index == 3
                    ? 'On Hold'
                    : 'All Status');
    state = state.copyWith(
      subTab: index,
      selectedStatus: (index <= 3) ? newStatus : state.selectedStatus,
    );
    if (index >= 0 && index <= 3) {
      loadRoster();
    } else if (index == 4) {
      if (state.salaryStructures.isEmpty) {
        loadSalaryStructures();
      }
    } else if (index == 5) {
      if (state.payslipsList.isEmpty) {
        loadPayslips();
      }
    } else if (index == 6) {
      if (state.advancesList.isEmpty) {
        loadAdvances();
      }
    }
  }

  void setSearchQuery(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      state = state.copyWith(searchQuery: query, currentPage: 1);
      loadRoster();
    });
  }

  void setDepartmentFilter(String dept) {
    state = state.copyWith(selectedDepartment: dept, currentPage: 1);
    loadRoster();
  }

  void setRoleFilter(String role) {
    state = state.copyWith(selectedRole: role, currentPage: 1);
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
    state = state.copyWith(selectedStaffIds: {});
  }

  Future<void> openStaffDrawer(String staffId) async {
    state = state.copyWith(isLoading: true, currentStaffId: staffId);
    final detail = await _service.getStaffSalaryDetail(staffId);
    state = state.copyWith(
      isDrawerOpen: true,
      currentStaffId: staffId,
      selectedStaffDetail: detail,
      isLoading: false,
    );
  }

  void closeStaffDrawer() {
    state = state.copyWith(
      isDrawerOpen: false,
      clearSelectedStaff: true,
      currentStaffId: null,
    );
  }

  void toggleStaffSelection(String staffId) {
    final updated = Set<String>.from(state.selectedStaffIds);
    if (updated.contains(staffId)) {
      updated.remove(staffId);
    } else {
      updated.add(staffId);
    }
    state = state.copyWith(selectedStaffIds: updated);
  }

  void toggleSelectAll(bool selectAll) {
    if (selectAll) {
      final allIds = state.staffRoster.map((e) => e.staffId).toSet();
      state = state.copyWith(selectedStaffIds: allIds);
    } else {
      state = state.copyWith(selectedStaffIds: {});
    }
  }

  Future<bool> executeBulkAction(String action) async {
    if (state.selectedStaffIds.isEmpty) return false;
    final ok = await _service.executeStaffSalaryBulkAction({
      'action': action,
      'ids': state.selectedStaffIds.toList(),
      'month_str': state.selectedMonthStr,
    });
    if (ok) {
      state = state.copyWith(selectedStaffIds: {});
      await loadAllData();
    }
    return ok;
  }

  Future<bool> updateAdvanceStatus(String advanceId, String status, {String? remarks}) async {
    final ok = await _service.updateStaffAdvanceStatus(advanceId, status, remarks: remarks);
    if (ok) await loadAllData();
    return ok;
  }

  void exportCsv() {
    final month = Uri.encodeComponent(state.selectedMonthStr);
    final url = '/api/v1/payment-management/staff-salary/export/csv?month_str=$month';
    try {
      downloadFileWeb(url, 'Staff_Salary_Roster.csv');
    } catch (_) {}
  }
}

final staffSalaryProvider = StateNotifierProvider<StaffSalaryNotifier, StaffSalaryState>((ref) {
  return StaffSalaryNotifier();
});
