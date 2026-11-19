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
  final String? currentStaffId;
  final Map<String, dynamic>? selectedStaffDetail;
  final int currentPage;
  final int pageSize;
  final int totalItems;
  final int totalPages;
  final Set<String> selectedStaffIds;
  final String? sortColumn;
  final bool sortAscending;

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
    this.currentStaffId,
    this.selectedStaffDetail,
    this.currentPage = 1,
    this.pageSize = 10,
    this.totalItems = 0,
    this.totalPages = 1,
    this.selectedStaffIds = const {},
    this.sortColumn,
    this.sortAscending = true,
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
      currentStaffId: clearSelectedStaff ? null : (currentStaffId ?? this.currentStaffId),
      selectedStaffDetail: clearSelectedStaff ? null : (selectedStaffDetail ?? this.selectedStaffDetail),
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalItems: totalItems ?? this.totalItems,
      totalPages: totalPages ?? this.totalPages,
      selectedStaffIds: selectedStaffIds ?? this.selectedStaffIds,
      sortColumn: sortColumn ?? this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
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

  Future<void> loadAllData() async {
    state = state.copyWith(isLoading: true);
    await Future.wait([
      loadMetadata(),
      loadKPIs(),
      loadRoster(),
      loadSalaryStructures(),
      loadPayslips(),
      loadAdvances(),
    ]);

    // Live refresh open drawer to prevent stale financial state
    if (state.isDrawerOpen && state.currentStaffId != null) {
      final detail = await _service.getStaffSalaryDetail(state.currentStaffId!);
      state = state.copyWith(selectedStaffDetail: detail);
    }

    state = state.copyWith(isLoading: false);
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
    final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

    state = state.copyWith(
      staffRoster: list,
      totalItems: (pagination['total_items'] as num?)?.toInt() ?? list.length,
      totalPages: (pagination['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<void> loadSalaryStructures() async {
    final structs = await _service.getStaffSalaryStructures();
    state = state.copyWith(salaryStructures: structs);
  }

  Future<void> loadPayslips() async {
    final res = await _service.getStaffPayslips(
      monthStr: state.selectedMonthStr,
      search: state.searchQuery,
    );
    final pays = res['payslips'] as List<StaffPayslipItem>? ?? [];
    state = state.copyWith(payslipsList: pays);
  }

  Future<void> loadAdvances() async {
    final res = await _service.getStaffSalaryAdvances(search: state.searchQuery);
    final advs = res['advances'] as List<StaffSalaryAdvanceItem>? ?? [];
    state = state.copyWith(advancesList: advs);
  }

  void setMonth(String monthStr) {
    if (state.selectedMonthStr != monthStr) {
      state = state.copyWith(selectedMonthStr: monthStr, currentPage: 1);
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
      if (state.subTab == 5) loadPayslips();
      if (state.subTab == 6) loadAdvances();
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
