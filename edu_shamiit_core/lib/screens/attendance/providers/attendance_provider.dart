import '../../../utils/download_helper.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/attendance_models.dart';
import '../services/attendance_api_service.dart';
import '../../classes/models/class_models.dart';
import '../../classes/services/class_api_service.dart';
import '../../classes/services/academic_lookup_helper.dart';

final attendanceApiServiceProvider = Provider<AttendanceApiService>((ref) {
  return AttendanceApiService();
});

class AttendanceState {
  final int activeTab; // 0: Daily, 1: Staff, 2: Leave, 3: Bulk, 4: Insights, 5: Settings
  final DateTime selectedDate;
  final String? selectedClassId;
  final String? selectedSectionId;
  final AttendanceMode selectedMode;
  final int? selectedPeriodNumber;
  final String? selectedSubjectId;
  final Set<String> selectedScheduleIds; // For Custom Selection mode

  final List<AcademicClassModel> availableClasses;
  final AttendanceStatsModel stats;
  final List<AttendanceStudentRowModel> roster;
  final Map<String, AttendanceStatus> draftStatuses;
  final Map<String, String> draftRemarks;
  final Set<String> selectedStudentIds;

  final List<AttendanceScheduleItemModel> schedulesToday;
  final List<StaffAttendanceRowModel> staffRoster;
  final List<String> staffAvailableDepartments;
  final Map<String, AttendanceStatus> draftStaffStatuses;
  final Map<String, String> draftStaffRemarks;
  final Map<String, String> draftStaffCheckIns;
  final Map<String, String> draftStaffCheckOuts;
  final Set<String> selectedStaffIds;
  final bool staffManagerOnlyFilter;
  final String? staffSelectedManagerId;
  final String staffDepartmentFilter;
  final String staffRoleFilter;
  final String staffStatusFilter;
  final String staffSearchQuery;
  final int staffPage;
  final int staffPageSize;
  final int staffTotalCount;
  final int staffTotalPages;
  final bool isStaffLoading;

  final List<AttendanceLeaveRequestModel> leaveRequests;
  final String leaveStatusFilter;
  final String leaveRoleFilter;

  final AttendanceInsightsModel? insights;
  final DateTime? insightsStartDate;
  final DateTime? insightsEndDate;
  final String insightsViewBy;
  final String? insightsRole;
  final String? insightsClassId;
  final String? insightsSectionId;
  final String? insightsDepartment;
  final List<Map<String, dynamic>> insightsAvailableDepartments;
  final List<Map<String, dynamic>> insightsAvailableRoles;
  final String insightsGranularity;
  final bool insightsIsLoading;
  final AttendanceSettingsModel settings;
  final List<AttendanceAuditLogModel> auditLogs;

  final String searchQuery;
  final String statusFilter;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  final bool isLockedAllDay;
  final DateTime? lockedAt;
  final String? lockedByName;
  final bool isManager;
  final int directReportsCount;
  final bool isManagerStatusLoaded;

  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  AttendanceState({
    this.activeTab = 0,
    this.isManager = false,
    this.directReportsCount = 0,
    this.isManagerStatusLoaded = false,
    DateTime? selectedDate,
    this.selectedClassId,
    this.selectedSectionId,
    this.selectedMode = AttendanceMode.allDay,
    this.selectedPeriodNumber,
    this.selectedSubjectId,
    this.selectedScheduleIds = const {},
    this.availableClasses = const [],
    AttendanceStatsModel? stats,
    this.roster = const [],
    this.draftStatuses = const {},
    this.draftRemarks = const {},
    this.selectedStudentIds = const {},
    this.schedulesToday = const [],
    this.staffRoster = const [],
    this.staffAvailableDepartments = const [],
    this.draftStaffStatuses = const {},
    this.draftStaffRemarks = const {},
    this.draftStaffCheckIns = const {},
    this.draftStaffCheckOuts = const {},
    this.selectedStaffIds = const {},
    this.staffManagerOnlyFilter = false,
    this.staffSelectedManagerId,
    this.staffDepartmentFilter = 'ALL',
    this.staffRoleFilter = 'ALL',
    this.staffStatusFilter = 'ALL',
    this.staffSearchQuery = '',
    this.staffPage = 1,
    this.staffPageSize = 10,
    this.staffTotalCount = 0,
    this.staffTotalPages = 1,
    this.isStaffLoading = false,
    this.leaveRequests = const [],
    this.leaveStatusFilter = 'ALL',
    this.leaveRoleFilter = 'ALL',
    LeaveDashboardModel? leaveDashboard,
    this.publicHolidays = const [],
    this.leaveTypes = const [],
    this.activeRoles = const [],
    this.isActiveRolesLoaded = false,
    this.leaveBalances = const [],
    this.employeeLeaveBalances = const [],
    this.balancesPage = 1,
    this.balancesPageSize = 10,
    this.balancesTotalCount = 0,
    this.balancesTotalPages = 1,
    this.isLeaveBalancesLoading = false,
    this.isLeaveBalancesLoaded = false,
    this.isLeaveTypesLoaded = false,
    this.isPermissionRequestsLoaded = false,
    this.permissionRequests = const [],
    this.leaveSubTab = 'REQUESTS',
    this.leaveUserTypeFilter = 'ALL',
    this.leaveDepartmentFilter = 'ALL',
    this.leaveTypeFilter = 'ALL',
    this.leaveSearchQuery = '',
    this.leaveFromDate,
    this.leaveToDate,
    this.leavePage = 1,
    this.leavePageSize = 10,
    this.insights,
    this.insightsStartDate,
    this.insightsEndDate,
    this.insightsViewBy = 'OVERALL',
    this.insightsRole,
    this.insightsClassId,
    this.insightsSectionId,
    this.insightsDepartment,
    this.insightsAvailableDepartments = const [],
    this.insightsAvailableRoles = const [],
    this.insightsGranularity = 'monthly',
    this.insightsIsLoading = false,
    AttendanceSettingsModel? settings,
    this.auditLogs = const [],
    this.searchQuery = '',
    this.statusFilter = 'ALL',
    this.page = 1,
    this.pageSize = 10,
    this.totalCount = 0,
    this.totalPages = 1,
    this.isLockedAllDay = false,
    this.lockedAt,
    this.lockedByName,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
  })  : selectedDate = selectedDate ?? DateTime.now(),
        stats = stats ?? AttendanceStatsModel(),
        settings = settings ?? AttendanceSettingsModel(),
        leaveDashboard = leaveDashboard ?? LeaveDashboardModel(kpi: LeaveDashboardKpiModel());

  final LeaveDashboardModel leaveDashboard;
  final List<HolidayItemModel> publicHolidays;
  final List<LeaveTypeModel> leaveTypes;
  final List<AppRoleItemModel> activeRoles;
  final bool isActiveRolesLoaded;
  final List<LeaveBalanceRowModel> leaveBalances;
  final List<EmployeeLeaveBalanceModel> employeeLeaveBalances;
  final int balancesPage;
  final int balancesPageSize;
  final int balancesTotalCount;
  final int balancesTotalPages;
  final bool isLeaveBalancesLoading;
  final bool isLeaveBalancesLoaded;
  final bool isLeaveTypesLoaded;
  final bool isPermissionRequestsLoaded;
  final List<PermissionRequestModel> permissionRequests;
  final String leaveSubTab; // REQUESTS, BALANCES, TYPES, PERMISSIONS, WORKFLOW
  final String leaveUserTypeFilter;
  final String leaveDepartmentFilter;
  final String leaveTypeFilter;
  final String leaveSearchQuery;
  final DateTime? leaveFromDate;
  final DateTime? leaveToDate;
  final int leavePage;
  final int leavePageSize;

  String get dateString => DateFormat('yyyy-MM-dd').format(selectedDate);
  String get displayDateString => DateFormat('dd MMM yyyy, EEE').format(selectedDate);
  bool get isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day == now.day;
  }

  bool get hasUnsavedChanges => draftStatuses.isNotEmpty || draftRemarks.isNotEmpty;
  bool get hasUnsavedStaffChanges => draftStaffStatuses.isNotEmpty || draftStaffRemarks.isNotEmpty || draftStaffCheckIns.isNotEmpty || draftStaffCheckOuts.isNotEmpty;

  AttendanceState copyWith({
    int? activeTab,
    DateTime? selectedDate,
    String? selectedClassId,
    String? selectedSectionId,
    bool clearSection = false,
    AttendanceMode? selectedMode,
    int? selectedPeriodNumber,
    String? selectedSubjectId,
    Set<String>? selectedScheduleIds,
    List<AcademicClassModel>? availableClasses,
    AttendanceStatsModel? stats,
    List<AttendanceStudentRowModel>? roster,
    Map<String, AttendanceStatus>? draftStatuses,
    Map<String, String>? draftRemarks,
    Set<String>? selectedStudentIds,
    List<AttendanceScheduleItemModel>? schedulesToday,
    List<StaffAttendanceRowModel>? staffRoster,
    List<String>? staffAvailableDepartments,
    Map<String, AttendanceStatus>? draftStaffStatuses,
    Map<String, String>? draftStaffRemarks,
    Map<String, String>? draftStaffCheckIns,
    Map<String, String>? draftStaffCheckOuts,
    Set<String>? selectedStaffIds,
    bool? staffManagerOnlyFilter,
    String? staffSelectedManagerId,
    bool clearStaffManager = false,
    String? staffDepartmentFilter,
    String? staffRoleFilter,
    String? staffStatusFilter,
    String? staffSearchQuery,
    int? staffPage,
    int? staffPageSize,
    int? staffTotalCount,
    int? staffTotalPages,
    bool? isStaffLoading,
    List<AttendanceLeaveRequestModel>? leaveRequests,
    String? leaveStatusFilter,
    String? leaveRoleFilter,
    LeaveDashboardModel? leaveDashboard,
    List<HolidayItemModel>? publicHolidays,
    List<LeaveTypeModel>? leaveTypes,
    List<LeaveBalanceRowModel>? leaveBalances,
    List<EmployeeLeaveBalanceModel>? employeeLeaveBalances,
    int? balancesPage,
    int? balancesPageSize,
    int? balancesTotalCount,
    int? balancesTotalPages,
    bool? isLeaveBalancesLoading,
    bool? isLeaveBalancesLoaded,
    bool? isLeaveTypesLoaded,
    List<AppRoleItemModel>? activeRoles,
    bool? isActiveRolesLoaded,
    bool? isPermissionRequestsLoaded,
    List<PermissionRequestModel>? permissionRequests,
    String? leaveSubTab,
    String? leaveUserTypeFilter,
    String? leaveDepartmentFilter,
    String? leaveTypeFilter,
    String? leaveSearchQuery,
    DateTime? leaveFromDate,
    DateTime? leaveToDate,
    bool clearLeaveDates = false,
    int? leavePage,
    int? leavePageSize,
    AttendanceInsightsModel? insights,
    DateTime? insightsStartDate,
    DateTime? insightsEndDate,
    bool clearInsightsDates = false,
    String? insightsViewBy,
    String? insightsRole,
    bool clearInsightsRole = false,
    String? insightsClassId,
    bool clearInsightsClass = false,
    String? insightsSectionId,
    bool clearInsightsSection = false,
    String? insightsDepartment,
    bool clearInsightsDepartment = false,
    List<Map<String, dynamic>>? insightsAvailableDepartments,
    List<Map<String, dynamic>>? insightsAvailableRoles,
    String? insightsGranularity,
    bool? insightsIsLoading,
    AttendanceSettingsModel? settings,
    List<AttendanceAuditLogModel>? auditLogs,
    String? searchQuery,
    String? statusFilter,
    int? page,
    int? pageSize,
    int? totalCount,
    int? totalPages,
    bool? isLockedAllDay,
    DateTime? lockedAt,
    String? lockedByName,
    bool? isManager,
    int? directReportsCount,
    bool? isManagerStatusLoaded,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    bool clearErrors = false,
  }) {
    return AttendanceState(
      activeTab: activeTab ?? this.activeTab,
      isManager: isManager ?? this.isManager,
      directReportsCount: directReportsCount ?? this.directReportsCount,
      isManagerStatusLoaded: isManagerStatusLoaded ?? this.isManagerStatusLoaded,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedClassId: selectedClassId ?? this.selectedClassId,
      selectedSectionId: clearSection ? null : (selectedSectionId ?? this.selectedSectionId),
      selectedMode: selectedMode ?? this.selectedMode,
      selectedPeriodNumber: selectedPeriodNumber ?? this.selectedPeriodNumber,
      selectedSubjectId: selectedSubjectId ?? this.selectedSubjectId,
      selectedScheduleIds: selectedScheduleIds ?? this.selectedScheduleIds,
      availableClasses: availableClasses ?? this.availableClasses,
      stats: stats ?? this.stats,
      roster: roster ?? this.roster,
      draftStatuses: draftStatuses ?? this.draftStatuses,
      draftRemarks: draftRemarks ?? this.draftRemarks,
      selectedStudentIds: selectedStudentIds ?? this.selectedStudentIds,
      schedulesToday: schedulesToday ?? this.schedulesToday,
      staffRoster: staffRoster ?? this.staffRoster,
      staffAvailableDepartments: staffAvailableDepartments ?? this.staffAvailableDepartments,
      draftStaffStatuses: draftStaffStatuses ?? this.draftStaffStatuses,
      draftStaffRemarks: draftStaffRemarks ?? this.draftStaffRemarks,
      draftStaffCheckIns: draftStaffCheckIns ?? this.draftStaffCheckIns,
      draftStaffCheckOuts: draftStaffCheckOuts ?? this.draftStaffCheckOuts,
      selectedStaffIds: selectedStaffIds ?? this.selectedStaffIds,
      staffManagerOnlyFilter: staffManagerOnlyFilter ?? this.staffManagerOnlyFilter,
      staffSelectedManagerId: clearStaffManager ? null : (staffSelectedManagerId ?? this.staffSelectedManagerId),
      staffDepartmentFilter: staffDepartmentFilter ?? this.staffDepartmentFilter,
      staffRoleFilter: staffRoleFilter ?? this.staffRoleFilter,
      staffStatusFilter: staffStatusFilter ?? this.staffStatusFilter,
      staffSearchQuery: staffSearchQuery ?? this.staffSearchQuery,
      staffPage: staffPage ?? this.staffPage,
      staffPageSize: staffPageSize ?? this.staffPageSize,
      staffTotalCount: staffTotalCount ?? this.staffTotalCount,
      staffTotalPages: staffTotalPages ?? this.staffTotalPages,
      isStaffLoading: isStaffLoading ?? this.isStaffLoading,
      leaveRequests: leaveRequests ?? this.leaveRequests,
      leaveStatusFilter: leaveStatusFilter ?? this.leaveStatusFilter,
      leaveRoleFilter: leaveRoleFilter ?? this.leaveRoleFilter,
      leaveDashboard: leaveDashboard ?? this.leaveDashboard,
      publicHolidays: publicHolidays ?? this.publicHolidays,
      leaveTypes: leaveTypes ?? this.leaveTypes,
      activeRoles: activeRoles ?? this.activeRoles,
      isActiveRolesLoaded: isActiveRolesLoaded ?? this.isActiveRolesLoaded,
      leaveBalances: leaveBalances ?? this.leaveBalances,
      employeeLeaveBalances: employeeLeaveBalances ?? this.employeeLeaveBalances,
      balancesPage: balancesPage ?? this.balancesPage,
      balancesPageSize: balancesPageSize ?? this.balancesPageSize,
      balancesTotalCount: balancesTotalCount ?? this.balancesTotalCount,
      balancesTotalPages: balancesTotalPages ?? this.balancesTotalPages,
      isLeaveBalancesLoading: isLeaveBalancesLoading ?? this.isLeaveBalancesLoading,
      isLeaveBalancesLoaded: isLeaveBalancesLoaded ?? this.isLeaveBalancesLoaded,
      isLeaveTypesLoaded: isLeaveTypesLoaded ?? this.isLeaveTypesLoaded,
      isPermissionRequestsLoaded: isPermissionRequestsLoaded ?? this.isPermissionRequestsLoaded,
      permissionRequests: permissionRequests ?? this.permissionRequests,
      leaveSubTab: leaveSubTab ?? this.leaveSubTab,
      leaveUserTypeFilter: leaveUserTypeFilter ?? this.leaveUserTypeFilter,
      leaveDepartmentFilter: leaveDepartmentFilter ?? this.leaveDepartmentFilter,
      leaveTypeFilter: leaveTypeFilter ?? this.leaveTypeFilter,
      leaveSearchQuery: leaveSearchQuery ?? this.leaveSearchQuery,
      leaveFromDate: clearLeaveDates ? null : (leaveFromDate ?? this.leaveFromDate),
      leaveToDate: clearLeaveDates ? null : (leaveToDate ?? this.leaveToDate),
      leavePage: leavePage ?? this.leavePage,
      leavePageSize: leavePageSize ?? this.leavePageSize,
      insights: insights ?? this.insights,
      insightsStartDate: clearInsightsDates ? null : (insightsStartDate ?? this.insightsStartDate),
      insightsEndDate: clearInsightsDates ? null : (insightsEndDate ?? this.insightsEndDate),
      insightsViewBy: insightsViewBy ?? this.insightsViewBy,
      insightsRole: clearInsightsRole ? null : (insightsRole ?? this.insightsRole),
      insightsClassId: clearInsightsClass ? null : (insightsClassId ?? this.insightsClassId),
      insightsSectionId: clearInsightsSection ? null : (insightsSectionId ?? this.insightsSectionId),
      insightsDepartment: clearInsightsDepartment ? null : (insightsDepartment ?? this.insightsDepartment),
      insightsAvailableDepartments: insightsAvailableDepartments ?? this.insightsAvailableDepartments,
      insightsAvailableRoles: insightsAvailableRoles ?? this.insightsAvailableRoles,
      insightsGranularity: insightsGranularity ?? this.insightsGranularity,
      insightsIsLoading: insightsIsLoading ?? this.insightsIsLoading,
      settings: settings ?? this.settings,
      auditLogs: auditLogs ?? this.auditLogs,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalCount: totalCount ?? this.totalCount,
      totalPages: totalPages ?? this.totalPages,
      isLockedAllDay: isLockedAllDay ?? this.isLockedAllDay,
      lockedAt: lockedAt ?? this.lockedAt,
      lockedByName: lockedByName ?? this.lockedByName,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearErrors ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearErrors ? null : (successMessage ?? this.successMessage),
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final AttendanceApiService _api;
  final ClassApiService _classApi = ClassApiService();

  AttendanceNotifier(this._api) : super(AttendanceState()) {
    init();
  }

  /// Initial load: fetch classes and current attendance data
  Future<void> init() async {
    state = state.copyWith(isLoading: true, clearErrors: true);
    try {
      // 1. Fetch available classes
      final classesData = await _classApi.getClasses(pageSize: 100);
      final rawClasses = (classesData['classes'] as List<AcademicClassModel>?) ?? [];
      final seenIds = <String>{};
      final classes = <AcademicClassModel>[];
      for (final c in rawClasses) {
        if (c.id.isNotEmpty && !seenIds.contains(c.id)) {
          seenIds.add(c.id);
          classes.add(c);
        }
      }

      String? initialClassId;
      String? initialSectionId;
      if (classes.isNotEmpty) {
        initialClassId = classes.first.id;
        if (classes.first.sections.isNotEmpty) {
          initialSectionId = classes.first.sections.first.id;
        }
      }

      state = state.copyWith(
        availableClasses: classes,
        selectedClassId: initialClassId,
        selectedSectionId: initialSectionId,
      );

      // 1. Check Manager Status
      await checkManagerStatus();

      // 2. Fetch Lookups from key-value tables (DEPARTMENT, etc.)
      await fetchStaffLookups();

      // 3. Fetch Daily Attendance Data
      await refreshAllData();
      // 4. Fetch Settings in Background
      final settings = await _api.getSettings();
      state = state.copyWith(settings: settings);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to initialize attendance: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Fetch departments dynamically from Lookup Key-Value tables ('DEPARTMENT')
  Future<void> fetchStaffLookups() async {
    try {
      final deptItems = await AcademicLookupHelper.instance.getActiveLookup('DEPARTMENT');
      final depts = deptItems.map((e) => e.label).where((d) => d.isNotEmpty && d != 'ALL').toSet();

      final updatedDepts = Set<String>.from(state.staffAvailableDepartments)..addAll(depts);
      if (state.staffDepartmentFilter.isNotEmpty && state.staffDepartmentFilter != 'ALL') {
        updatedDepts.add(state.staffDepartmentFilter);
      }

      state = state.copyWith(
        staffAvailableDepartments: updatedDepts.toList()..sort(),
      );
    } catch (_) {}
  }

  /// Check whether logged-in user is a reporting manager
  Future<void> checkManagerStatus() async {
    try {
      final res = await _api.getManagerStatus();
      final isMgr = res['is_manager'] == true;
      final count = int.tryParse(res['direct_reports_count']?.toString() ?? '0') ?? 0;
      state = state.copyWith(
        isManager: isMgr,
        directReportsCount: count,
        isManagerStatusLoaded: true,
      );
      if (!isMgr && (state.activeTab == 1 || state.activeTab == 2)) {
        setTab(0);
      }
    } catch (_) {
      state = state.copyWith(isManagerStatusLoaded: true);
    }
  }

  /// Refresh everything for the current tab & filters
  Future<void> refreshAllData() async {
    if (state.activeTab == 0) {
      await Future.wait([
        fetchDashboardStats(),
        fetchDailyRoster(),
        fetchTodaySchedules(),
      ]);
    } else if (state.activeTab == 1) {
      await fetchStaffRoster();
    } else if (state.activeTab == 2) {
      if (state.leaveSubTab == 'BALANCES') {
        await Future.wait([
          fetchLeaveDashboard(),
          fetchLeaveBalances(force: true),
          fetchLeaveHolidays(force: true),
        ]);
      } else {
        await Future.wait([
          fetchLeaveDashboard(),
          fetchLeaveHolidays(force: true),
        ]);
      }
    } else if (state.activeTab == 4) {
      await fetchInsights();
    } else if (state.activeTab == 5) {
      await fetchSettings();
    }
  }

  /// Fetch dynamic 5 summary metric cards
  Future<void> fetchDashboardStats() async {
    try {
      final stats = await _api.getStats(
        date: state.dateString,
        classId: state.selectedClassId,
        sectionId: state.selectedSectionId,
      );
      state = state.copyWith(stats: stats);
    } catch (_) {}
  }

  /// Fetch student roster for the selected class & section
  Future<void> fetchDailyRoster() async {
    if (state.selectedClassId == null) return;
    try {
      final res = await _api.getRoster(
        date: state.dateString,
        classId: state.selectedClassId!,
        sectionId: state.selectedSectionId,
        mode: state.selectedMode.apiKey,
        periodNumber: state.selectedPeriodNumber,
        subjectId: state.selectedSubjectId,
        search: state.searchQuery,
        statusFilter: state.statusFilter,
        page: state.page,
        pageSize: state.pageSize,
      );

      final students = res['students'] as List<AttendanceStudentRowModel>;
      final uniqueMap = <String, AttendanceStudentRowModel>{};
      for (final s in students) {
        if (!uniqueMap.containsKey(s.studentId)) {
          uniqueMap[s.studentId] = s;
        }
      }
      final uniqueList = uniqueMap.values.toList();

      state = state.copyWith(
        roster: uniqueList,
        totalCount: res['totalCount'] as int,
        page: res['page'] as int,
        pageSize: res['pageSize'] as int,
        totalPages: res['totalPages'] as int,
        isLockedAllDay: res['isLockedAllDay'] == true,
        lockedAt: res['lockedAt'] as DateTime?,
        lockedByName: res['lockedByName'] as String?,
        draftStatuses: {},
        draftRemarks: {},
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to load roster: $e');
    }
  }

  /// Fetch today's scheduled academic periods
  Future<void> fetchTodaySchedules() async {
    if (state.selectedClassId == null) return;
    try {
      final schedules = await _api.getSchedulesToday(
        date: state.dateString,
        classId: state.selectedClassId!,
        sectionId: state.selectedSectionId,
      );

      int? newPeriodNumber = state.selectedPeriodNumber;
      String? newSubjectId = state.selectedSubjectId;
      Set<String> newSelectedSchedIds = Set<String>.from(state.selectedScheduleIds);

      // Auto-select first period if in byPeriod mode and nothing is selected
      if (state.selectedMode == AttendanceMode.byPeriod && schedules.isNotEmpty) {
        final hasCurrent = schedules.any((s) => s.periodNumber == state.selectedPeriodNumber);
        if (!hasCurrent) {
          newPeriodNumber = schedules.first.periodNumber;
          newSubjectId = schedules.first.subjectId;
        }
      }

      // Auto-select all or valid schedules if in customSelection mode
      if (state.selectedMode == AttendanceMode.customSelection && schedules.isNotEmpty) {
        if (newSelectedSchedIds.isEmpty) {
          newSelectedSchedIds = schedules.map((s) => s.id).toSet();
        }
      }

      state = state.copyWith(
        schedulesToday: schedules,
        selectedPeriodNumber: newPeriodNumber,
        selectedSubjectId: newSubjectId,
        selectedScheduleIds: newSelectedSchedIds,
      );
    } catch (_) {}
  }

  /// Fetch staff attendance roster
  Future<void> fetchStaffRoster() async {
    state = state.copyWith(isStaffLoading: true, clearErrors: true);
    try {
      final managerId = state.staffManagerOnlyFilter ? 'MY_REPORTS' : state.staffSelectedManagerId;
      final res = await _api.getStaffAttendance(
        date: state.dateString,
        department: state.staffDepartmentFilter,
        role: state.staffRoleFilter,
        status: state.staffStatusFilter,
        search: state.staffSearchQuery,
        page: state.staffPage,
        pageSize: state.staffPageSize,
        managerId: managerId,
      );

      final staff = res['staff'] as List<StaffAttendanceRowModel>;
      final updatedDepts = Set<String>.from(state.staffAvailableDepartments);
      final lookupDepts = AcademicLookupHelper.instance.getCachedLookup('DEPARTMENT');
      for (final item in lookupDepts) {
        if (item.label.isNotEmpty && item.label != 'ALL') {
          updatedDepts.add(item.label);
        }
      }
      for (final s in staff) {
        if (s.department.isNotEmpty && s.department != 'ALL') {
          updatedDepts.add(s.department);
        }
      }
      if (state.staffDepartmentFilter.isNotEmpty && state.staffDepartmentFilter != 'ALL') {
        updatedDepts.add(state.staffDepartmentFilter);
      }

      state = state.copyWith(
        staffRoster: staff,
        staffAvailableDepartments: updatedDepts.toList()..sort(),
        staffTotalCount: res['totalCount'] as int,
        staffPage: res['page'] as int,
        staffPageSize: res['pageSize'] as int,
        staffTotalPages: res['totalPages'] as int,
        draftStaffStatuses: {},
        draftStaffRemarks: {},
        draftStaffCheckIns: {},
        draftStaffCheckOuts: {},
        selectedStaffIds: {},
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to load staff roster: $e');
    } finally {
      state = state.copyWith(isStaffLoading: false);
    }
  }

  /// Fetch integrated leave requests
  Future<void> fetchLeaveRequests() async {
    try {
      final reqs = await _api.getLeaveRequests(
        status: state.leaveStatusFilter,
        role: state.leaveRoleFilter,
      );
      state = state.copyWith(leaveRequests: reqs);
    } catch (_) {}
  }

  /// Fetch insights & at-risk analytics
  Future<void> fetchInsights() async {
    try {
      state = state.copyWith(insightsIsLoading: true);
      final now = DateTime.now();
      final sDate = state.insightsStartDate ?? now.subtract(const Duration(days: 30));
      final eDate = state.insightsEndDate ?? now;
      final startDate = DateFormat('yyyy-MM-dd').format(sDate);
      final endDate = DateFormat('yyyy-MM-dd').format(eDate);

      final ins = await _api.getInsights(
        startDate: startDate,
        endDate: endDate,
        viewBy: state.insightsViewBy,
        role: state.insightsRole,
        classId: state.insightsClassId,
        sectionId: state.insightsSectionId,
        department: state.insightsDepartment,
        granularity: state.insightsGranularity,
      );

      final depts = (ins != null && ins.availableDepartments.isNotEmpty)
          ? ins.availableDepartments
          : state.insightsAvailableDepartments;
      final roles = (ins != null && ins.availableRoles.isNotEmpty)
          ? ins.availableRoles
          : state.insightsAvailableRoles;

      state = state.copyWith(
        insights: ins,
        insightsAvailableDepartments: depts,
        insightsAvailableRoles: roles,
        insightsIsLoading: false,
      );
    } catch (_) {
      state = state.copyWith(insightsIsLoading: false);
    }
  }

  /// Update insights filter parameters and trigger refetch
  void setInsightsFilters({
    DateTime? startDate,
    DateTime? endDate,
    String? viewBy,
    String? role,
    String? classId,
    String? sectionId,
    String? department,
    String? granularity,
  }) {
    state = state.copyWith(
      insightsStartDate: startDate ?? state.insightsStartDate,
      insightsEndDate: endDate ?? state.insightsEndDate,
      insightsViewBy: viewBy ?? state.insightsViewBy,
      insightsRole: role ?? state.insightsRole,
      clearInsightsRole: role == null && role != state.insightsRole,
      insightsClassId: classId ?? state.insightsClassId,
      clearInsightsClass: classId == null && classId != state.insightsClassId,
      insightsSectionId: sectionId ?? state.insightsSectionId,
      clearInsightsSection: sectionId == null && sectionId != state.insightsSectionId,
      insightsDepartment: department ?? state.insightsDepartment,
      clearInsightsDepartment: department == null && department != state.insightsDepartment,
      insightsGranularity: granularity ?? state.insightsGranularity,
    );
    fetchInsights();
  }

  /// Set trend granularity (daily, weekly, monthly)
  void setInsightsGranularity(String granularity) {
    state = state.copyWith(insightsGranularity: granularity);
    fetchInsights();
  }

  /// Reset insights filters to default 30-day baseline
  void resetInsightsFilters() {
    state = state.copyWith(
      clearInsightsDates: true,
      insightsViewBy: 'OVERALL',
      clearInsightsRole: true,
      clearInsightsClass: true,
      clearInsightsSection: true,
      clearInsightsDepartment: true,
      insightsGranularity: 'monthly',
    );
    fetchInsights();
  }

  /// Fetch school attendance settings
  Future<void> fetchSettings() async {
    try {
      final s = await _api.getSettings();
      state = state.copyWith(settings: s);
    } catch (_) {}
  }

  // ==========================================================================
  // TAB & FILTER MUTATIONS
  // ==========================================================================

  void setTab(int tabIndex) {
    if (state.activeTab == tabIndex) return;
    state = state.copyWith(activeTab: tabIndex, clearErrors: true);
    refreshAllData();
  }

  void setDate(DateTime date) {
    state = state.copyWith(selectedDate: date, page: 1, staffPage: 1, clearErrors: true);
    refreshAllData();
  }

  void nextDay() {
    setDate(state.selectedDate.add(const Duration(days: 1)));
  }

  void prevDay() {
    setDate(state.selectedDate.subtract(const Duration(days: 1)));
  }

  void setToday() {
    setDate(DateTime.now());
  }

  void setClass(String classId) {
    final matched = state.availableClasses.firstWhere((c) => c.id == classId, orElse: () => state.availableClasses.first);
    final secId = matched.sections.isNotEmpty ? matched.sections.first.id : null;
    state = state.copyWith(
      selectedClassId: classId,
      selectedSectionId: secId,
      page: 1,
      clearErrors: true,
    );
    refreshAllData();
  }

  void setSection(String? sectionId) {
    state = state.copyWith(
      selectedSectionId: sectionId,
      clearSection: sectionId == null,
      page: 1,
      clearErrors: true,
    );
    refreshAllData();
  }

  void setMode(AttendanceMode mode) {
    int? newPeriod = state.selectedPeriodNumber;
    String? newSub = state.selectedSubjectId;
    Set<String> newScheds = Set<String>.from(state.selectedScheduleIds);

    if (mode == AttendanceMode.byPeriod && state.schedulesToday.isNotEmpty) {
      if (newPeriod == null) {
        newPeriod = state.schedulesToday.first.periodNumber;
        newSub = state.schedulesToday.first.subjectId;
      }
    } else if (mode == AttendanceMode.customSelection && state.schedulesToday.isNotEmpty) {
      if (newScheds.isEmpty) {
        newScheds = state.schedulesToday.map((s) => s.id).toSet();
      }
    }

    state = state.copyWith(
      selectedMode: mode,
      selectedPeriodNumber: newPeriod,
      selectedSubjectId: newSub,
      selectedScheduleIds: newScheds,
      page: 1,
      clearErrors: true,
    );
    refreshAllData();
  }

  void setPeriod(int? periodNumber, String? subjectId, {String? scheduleId}) {
    final schedIds = (scheduleId != null && scheduleId.isNotEmpty) ? {scheduleId} : state.selectedScheduleIds;
    state = state.copyWith(
      selectedPeriodNumber: periodNumber,
      selectedSubjectId: subjectId,
      selectedScheduleIds: schedIds,
      page: 1,
      clearErrors: true,
    );
    // If roster is already loaded in memory, don't wipe un-saved in-memory drafts by re-fetching.
    // Only fetch if roster is empty.
    if (state.roster.isEmpty) {
      fetchDailyRoster();
    }
  }

  void toggleScheduleSelection(String scheduleId) {
    final current = Set<String>.from(state.selectedScheduleIds);
    if (current.contains(scheduleId)) {
      current.remove(scheduleId);
    } else {
      current.add(scheduleId);
    }
    state = state.copyWith(selectedScheduleIds: current);
  }

  void selectAllSchedules(bool selectAll) {
    if (selectAll) {
      final allIds = state.schedulesToday.map((s) => s.id).toSet();
      state = state.copyWith(selectedScheduleIds: allIds);
    } else {
      state = state.copyWith(selectedScheduleIds: {});
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query, page: 1);
    fetchDailyRoster();
  }

  void setStatusFilter(String filter) {
    state = state.copyWith(statusFilter: filter, page: 1);
    fetchDailyRoster();
  }

  void setPage(int newPage) {
    if (newPage < 1 || (newPage > state.totalPages && state.totalPages > 0)) return;
    state = state.copyWith(page: newPage);
    fetchDailyRoster();
  }

  void setPageSize(int newSize) {
    state = state.copyWith(pageSize: newSize, page: 1);
    fetchDailyRoster();
  }

  // ==========================================================================
  // ROSTER INTERACTION & DRAFT MUTATIONS
  // ==========================================================================

  void updateStudentStatus(String studentId, AttendanceStatus newStatus) {
    markAttendance(newStatus, targetStudentIds: {studentId});
  }

  void updateStudentRemarks(String studentId, String remarks) {
    final currentDrafts = Map<String, String>.from(state.draftRemarks);
    currentDrafts[studentId] = remarks;
    state = state.copyWith(draftRemarks: currentDrafts);
  }

  void toggleStudentSelection(String studentId) {
    final s = Set<String>.from(state.selectedStudentIds);
    if (s.contains(studentId)) {
      s.remove(studentId);
    } else {
      s.add(studentId);
    }
    state = state.copyWith(selectedStudentIds: s);
  }

  void selectAllStudents(bool selectAll) {
    if (selectAll) {
      final allIds = state.roster.map((s) => s.studentId).toSet();
      state = state.copyWith(selectedStudentIds: allIds);
    } else {
      state = state.copyWith(selectedStudentIds: {});
    }
  }

  /// Compatibility wrapper for markAll
  void markAll(AttendanceStatus status) {
    markAttendance(status);
  }

  /// Core intelligent mark attendance action (Single / Multi-Select / Bulk All)
  /// - Whole Day: updates whole day status AND all periods for the target students
  /// - Period Mode: updates the specific active period for target students and recalculates composite status
  /// - Custom Mode: updates all selected custom periods for target students and recalculates composite status
  void markAttendance(
    AttendanceStatus status, {
    Set<String>? targetStudentIds,
    String? remarks,
  }) {
    final targets = (targetStudentIds != null && targetStudentIds.isNotEmpty)
        ? targetStudentIds
        : (state.selectedStudentIds.isNotEmpty
            ? state.selectedStudentIds
            : state.roster.map((s) => s.studentId).toSet());

    final updatedRoster = <AttendanceStudentRowModel>[];
    final updatedDraftStatuses = Map<String, AttendanceStatus>.from(state.draftStatuses);
    final updatedDraftRemarks = Map<String, String>.from(state.draftRemarks);

    for (final student in state.roster) {
      if (!targets.contains(student.studentId)) {
        updatedRoster.add(student);
        continue;
      }

      final updatedPeriods = <StudentPeriodAttendanceModel>[];

      if (state.selectedMode == AttendanceMode.allDay) {
        // MODE 1: Whole Day Mode
        // Mark whole day + mark ALL periods for this student
        for (final p in student.periods) {
          updatedPeriods.add(p.copyWith(
            status: status,
            remarks: remarks ?? p.remarks,
          ));
        }
        updatedDraftStatuses[student.studentId] = status;
        if (remarks != null && remarks.isNotEmpty) {
          updatedDraftRemarks[student.studentId] = remarks;
        }

        updatedRoster.add(student.copyWith(
          status: status,
          remarks: remarks ?? student.remarks,
          periods: updatedPeriods,
        ));
      } else if (state.selectedMode == AttendanceMode.byPeriod) {
        // MODE 2: Specific Period Mode
        final activePeriodNumber = state.selectedPeriodNumber ??
            (student.periods.isNotEmpty ? student.periods.first.periodNumber : 1);

        for (final p in student.periods) {
          if (p.periodNumber == activePeriodNumber) {
            updatedPeriods.add(p.copyWith(
              status: status,
              remarks: remarks ?? p.remarks,
            ));
          } else {
            updatedPeriods.add(p);
          }
        }

        final compositeStatus = _calculateCompositeDayStatus(updatedPeriods, fallback: status);
        updatedDraftStatuses[student.studentId] = compositeStatus;
        if (remarks != null && remarks.isNotEmpty) {
          updatedDraftRemarks[student.studentId] = remarks;
        }

        updatedRoster.add(student.copyWith(
          status: compositeStatus,
          remarks: remarks ?? student.remarks,
          periods: updatedPeriods,
        ));
      } else if (state.selectedMode == AttendanceMode.customSelection) {
        // MODE 3: Custom Selection Mode
        final selectedScheduleIds = state.selectedScheduleIds;
        final selectedPeriodNumbers = <int>{};
        for (final sched in state.schedulesToday) {
          if (selectedScheduleIds.contains(sched.id) ||
              (sched.scheduleId != null && selectedScheduleIds.contains(sched.scheduleId))) {
            selectedPeriodNumbers.add(sched.periodNumber);
          }
        }

        for (final p in student.periods) {
          final isSelected = selectedPeriodNumbers.contains(p.periodNumber) ||
              (p.scheduleId != null && selectedScheduleIds.contains(p.scheduleId));
          if (isSelected) {
            updatedPeriods.add(p.copyWith(
              status: status,
              remarks: remarks ?? p.remarks,
            ));
          } else {
            updatedPeriods.add(p);
          }
        }

        final compositeStatus = _calculateCompositeDayStatus(updatedPeriods, fallback: status);
        updatedDraftStatuses[student.studentId] = compositeStatus;
        if (remarks != null && remarks.isNotEmpty) {
          updatedDraftRemarks[student.studentId] = remarks;
        }

        updatedRoster.add(student.copyWith(
          status: compositeStatus,
          remarks: remarks ?? student.remarks,
          periods: updatedPeriods,
        ));
      }
    }

    // Recalculate dynamic statistics optimistically
    int presentCnt = 0;
    int absentCnt = 0;
    int lateCnt = 0;
    int leaveCnt = 0;
    int halfDayCnt = 0;
    int notMarkedCnt = 0;

    for (final s in updatedRoster) {
      final st = updatedDraftStatuses[s.studentId] ?? s.status;
      switch (st) {
        case AttendanceStatus.present:
          presentCnt++;
          break;
        case AttendanceStatus.absent:
          absentCnt++;
          break;
        case AttendanceStatus.late:
          lateCnt++;
          break;
        case AttendanceStatus.onLeave:
          leaveCnt++;
          break;
        case AttendanceStatus.halfDay:
          halfDayCnt++;
          break;
        case AttendanceStatus.notMarked:
        default:
          notMarkedCnt++;
          break;
      }
    }

    final total = updatedRoster.length;
    final double overallPct = total > 0
        ? ((presentCnt + (lateCnt * 0.8) + (halfDayCnt * 0.5)) / total * 100)
        : 0.0;

    final updatedStats = AttendanceStatsModel(
      overallAttendancePct: math.max(0.0, math.min(100.0, overallPct)),
      totalStudents: total,
      studentsPresent: presentCnt,
      studentsAbsent: absentCnt,
      lateEntries: lateCnt,
      onLeave: leaveCnt,
      halfDay: halfDayCnt,
      notMarked: notMarkedCnt,
      daySummary: {
        'total': total,
        'present': presentCnt,
        'absent': absentCnt,
        'late': lateCnt,
        'on_leave': leaveCnt,
        'half_day': halfDayCnt,
        'not_marked': notMarkedCnt,
      },
    );

    state = state.copyWith(
      roster: updatedRoster,
      draftStatuses: updatedDraftStatuses,
      draftRemarks: updatedDraftRemarks,
      stats: updatedStats,
    );
  }

  AttendanceStatus _calculateCompositeDayStatus(
    List<StudentPeriodAttendanceModel> periods, {
    AttendanceStatus fallback = AttendanceStatus.notMarked,
  }) {
    if (periods.isEmpty) return fallback;
    final totalPeriods = periods.length;
    final marked = periods.where((p) => p.status != AttendanceStatus.notMarked).toList();
    if (marked.isEmpty) return AttendanceStatus.notMarked;

    final presentCount = marked.where((p) => p.status == AttendanceStatus.present).length;
    final absentCount = marked.where((p) => p.status == AttendanceStatus.absent).length;
    final lateCount = marked.where((p) => p.status == AttendanceStatus.late).length;
    final leaveCount = marked.where((p) => p.status == AttendanceStatus.onLeave).length;
    final halfDayCount = marked.where((p) => p.status == AttendanceStatus.halfDay).length;

    // 1. All ON_LEAVE
    if (leaveCount == totalPeriods) {
      return AttendanceStatus.onLeave;
    }

    // 2. All ABSENT
    if (absentCount == totalPeriods) {
      return AttendanceStatus.absent;
    }

    // 3. All periods PRESENT
    if (presentCount == totalPeriods) {
      return AttendanceStatus.present;
    }

    // 4. All attended but at least one LATE
    if ((presentCount + lateCount) == totalPeriods && lateCount > 0 && absentCount == 0 && leaveCount == 0 && halfDayCount == 0) {
      return AttendanceStatus.late;
    }

    // 5. Any official leave + other non-present periods (e.g. Leave + Absent)
    if (leaveCount > 0 && presentCount == 0 && lateCount == 0) {
      return AttendanceStatus.onLeave;
    }

    // 6. Percentage calculation: Attended score = Present (1.0) + Late (1.0) + Half Day (0.5)
    final attendedScore = presentCount.toDouble() + lateCount.toDouble() + (0.5 * halfDayCount.toDouble());
    final pct = (attendedScore / (totalPeriods > 0 ? totalPeriods : 1)) * 100.0;

    if (pct >= 75.0) {
      return AttendanceStatus.present;
    } else if (pct >= 50.0) {
      return AttendanceStatus.halfDay;
    } else {
      if (leaveCount > 0 && (absentCount > 0 || halfDayCount > 0)) {
        return AttendanceStatus.onLeave;
      }
      return AttendanceStatus.absent;
    }
  }

  void applyBulkRemarks(String remarks, {Set<String>? targetStudentIds}) {
    final targets = (targetStudentIds != null && targetStudentIds.isNotEmpty)
        ? targetStudentIds
        : (state.selectedStudentIds.isNotEmpty
            ? state.selectedStudentIds
            : state.roster.map((s) => s.studentId).toSet());

    final updatedDraftRemarks = Map<String, String>.from(state.draftRemarks);
    final updatedRoster = <AttendanceStudentRowModel>[];

    for (final student in state.roster) {
      if (targets.contains(student.studentId)) {
        updatedDraftRemarks[student.studentId] = remarks;
        updatedRoster.add(student.copyWith(remarks: remarks));
      } else {
        updatedRoster.add(student);
      }
    }

    state = state.copyWith(
      roster: updatedRoster,
      draftRemarks: updatedDraftRemarks,
    );
  }

  void resetDrafts() {
    state = state.copyWith(draftStatuses: {}, draftRemarks: {}, selectedStudentIds: {});
  }

  /// Quick mark a student's attendance for a specific period
  Future<bool> quickMarkStudentPeriod({
    required String studentId,
    required int periodNumber,
    required AttendanceStatus status,
    String? subjectId,
    String? scheduleId,
    String? remarks,
  }) async {
    // 1. Optimistic in-memory update for 0ms visual feedback
    final updatedRoster = <AttendanceStudentRowModel>[];
    for (final student in state.roster) {
      if (student.studentId == studentId) {
        final updatedPeriods = <StudentPeriodAttendanceModel>[];
        for (final p in student.periods) {
          if (p.periodNumber == periodNumber) {
            updatedPeriods.add(p.copyWith(
              status: status,
              remarks: remarks ?? p.remarks,
            ));
          } else {
            updatedPeriods.add(p);
          }
        }
        final compStatus = _calculateCompositeDayStatus(updatedPeriods, fallback: status);
        final currentDrafts = Map<String, AttendanceStatus>.from(state.draftStatuses);
        currentDrafts[studentId] = compStatus;
        updatedRoster.add(student.copyWith(
          status: compStatus,
          periods: updatedPeriods,
        ));
      } else {
        updatedRoster.add(student);
      }
    }

    // Recalculate dynamic statistics optimistically
    int presentCnt = 0;
    int absentCnt = 0;
    int lateCnt = 0;
    int leaveCnt = 0;
    int halfDayCnt = 0;
    int notMarkedCnt = 0;

    for (final s in updatedRoster) {
      final st = (s.studentId == studentId ? (state.draftStatuses[studentId] ?? s.status) : (state.draftStatuses[s.studentId] ?? s.status));
      switch (st) {
        case AttendanceStatus.present:
          presentCnt++;
          break;
        case AttendanceStatus.absent:
          absentCnt++;
          break;
        case AttendanceStatus.late:
          lateCnt++;
          break;
        case AttendanceStatus.onLeave:
          leaveCnt++;
          break;
        case AttendanceStatus.halfDay:
          halfDayCnt++;
          break;
        case AttendanceStatus.notMarked:
        default:
          notMarkedCnt++;
          break;
      }
    }

    final total = updatedRoster.length;
    final double overallPct = total > 0
        ? ((presentCnt + (lateCnt * 0.8) + (halfDayCnt * 0.5)) / total * 100)
        : 0.0;

    final updatedStats = AttendanceStatsModel(
      overallAttendancePct: math.max(0.0, math.min(100.0, overallPct)),
      totalStudents: total,
      studentsPresent: presentCnt,
      studentsAbsent: absentCnt,
      lateEntries: lateCnt,
      onLeave: leaveCnt,
      halfDay: halfDayCnt,
      notMarked: notMarkedCnt,
      daySummary: {
        'total': total,
        'present': presentCnt,
        'absent': absentCnt,
        'late': lateCnt,
        'on_leave': leaveCnt,
        'half_day': halfDayCnt,
        'not_marked': notMarkedCnt,
      },
    );

    state = state.copyWith(
      roster: updatedRoster,
      draftStatuses: Map<String, AttendanceStatus>.from(state.draftStatuses)..addAll({studentId: (updatedRoster.firstWhere((x) => x.studentId == studentId).status)}),
      stats: updatedStats,
    );

    // 2. Persist to Backend API
    try {
      final res = await _api.quickMarkStudentPeriod(
        studentId: studentId,
        date: state.dateString,
        periodNumber: periodNumber,
        status: status.apiKey,
        subjectId: subjectId,
        scheduleId: scheduleId,
        remarks: remarks,
      );

      if (res['success'] == true) {
        await refreshAllData();
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to update period attendance');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  // ==========================================================================
  // SAVE & OVERRIDE ACTIONS
  // ==========================================================================

  /// Save daily attendance
  Future<bool> saveDailyAttendance({bool allowOverride = false}) async {
    if (state.selectedClassId == null) return false;
    state = state.copyWith(isSaving: true, clearErrors: true);

    try {
      final records = <Map<String, dynamic>>[];
      for (final student in state.roster) {
        final st = state.draftStatuses[student.studentId] ?? student.status;
        final rem = state.draftRemarks[student.studentId] ?? student.remarks;

        final periodsList = student.periods.map((p) => {
          'period_number': p.periodNumber,
          'period_label': p.periodLabel,
          'status': p.status.apiKey,
          'remarks': p.remarks,
          'subject_id': p.subjectId,
          'schedule_id': p.scheduleId,
        }).toList();

        records.add({
          'student_id': student.studentId,
          'status': st.apiKey,
          'remarks': rem,
          'period_number': state.selectedPeriodNumber,
          'subject_id': state.selectedSubjectId,
          'periods': periodsList,
        });
      }

      // Build multi-periods payload if in customSelection mode
      List<Map<String, dynamic>>? selectedPeriodsPayload;
      if (state.selectedMode == AttendanceMode.customSelection) {
        selectedPeriodsPayload = [];
        for (final sched in state.schedulesToday) {
          if (state.selectedScheduleIds.contains(sched.id) ||
              (sched.scheduleId != null && state.selectedScheduleIds.contains(sched.scheduleId))) {
            selectedPeriodsPayload.add({
              'period_number': sched.periodNumber,
              'subject_id': sched.subjectId,
              'schedule_id': sched.scheduleId,
            });
          }
        }
      }

      // Find scheduleId if in byPeriod mode
      String? singleScheduleId;
      if (state.selectedMode == AttendanceMode.byPeriod) {
        final matching = state.schedulesToday.firstWhere(
          (s) => s.periodNumber == state.selectedPeriodNumber,
          orElse: () => state.schedulesToday.isNotEmpty ? state.schedulesToday.first : AttendanceScheduleItemModel(
            id: '',
            periodNumber: 1,
            periodLabel: 'P1',
            timeRange: '',
            subjectId: '',
            subjectName: '',
            subjectCode: '',
            subjectColor: const Color(0xFF4F46E5),
            teacherName: '',
            status: '',
          ),
        );
        singleScheduleId = matching.scheduleId;
      }

      final res = await _api.saveAttendance(
        date: state.dateString,
        classId: state.selectedClassId!,
        sectionId: state.selectedSectionId,
        mode: state.selectedMode.apiKey,
        periodNumber: state.selectedPeriodNumber,
        subjectId: state.selectedSubjectId,
        scheduleId: singleScheduleId,
        selectedScheduleIds: state.selectedScheduleIds.toList(),
        selectedPeriods: selectedPeriodsPayload,
        records: records,
        allowOverride: allowOverride,
      );

      if (res['success'] == true) {
        state = state.copyWith(
          successMessage: res['message'] ?? 'Attendance saved successfully',
          draftStatuses: {},
          draftRemarks: {},
        );
        await refreshAllData();
        return true;
      } else {
        state = state.copyWith(errorMessage: res['detail'] ?? res['error'] ?? 'Failed to save attendance');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error saving attendance: $e');
      return false;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  /// Override a locked student record with justification
  Future<bool> overrideStudentRecord({
    required String recordId,
    String recordType = 'DAILY',
    required AttendanceStatus newStatus,
    required String reason,
  }) async {
    state = state.copyWith(isSaving: true, clearErrors: true);
    try {
      final res = await _api.overrideLockedRecord(
        recordId: recordId,
        recordType: recordType,
        newStatus: newStatus.apiKey,
        reason: reason,
      );

      if (res['success'] == true) {
        state = state.copyWith(successMessage: 'Record overridden successfully');
        await refreshAllData();
        return true;
      } else {
        state = state.copyWith(errorMessage: res['detail'] ?? res['error'] ?? 'Override failed');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error overriding record: $e');
      return false;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  // ==========================================================================
  // STAFF ATTENDANCE MUTATIONS & BULK ACTIONS
  // ==========================================================================

  void updateStaffStatus(String employeeId, AttendanceStatus status) {
    final current = Map<String, AttendanceStatus>.from(state.draftStaffStatuses);
    current[employeeId] = status;
    state = state.copyWith(draftStaffStatuses: current);
  }

  void updateStaffRemarks(String employeeId, String remarks) {
    final current = Map<String, String>.from(state.draftStaffRemarks);
    current[employeeId] = remarks;
    state = state.copyWith(draftStaffRemarks: current);
  }

  void updateStaffCheckInTime(String employeeId, String? timeStr) {
    final current = Map<String, String>.from(state.draftStaffCheckIns);
    if (timeStr == null || timeStr.isEmpty) {
      current[employeeId] = '';
    } else {
      current[employeeId] = timeStr;
    }
    state = state.copyWith(draftStaffCheckIns: current);
  }

  void updateStaffCheckOutTime(String employeeId, String? timeStr) {
    final current = Map<String, String>.from(state.draftStaffCheckOuts);
    if (timeStr == null || timeStr.isEmpty) {
      current[employeeId] = '';
    } else {
      current[employeeId] = timeStr;
    }
    state = state.copyWith(draftStaffCheckOuts: current);
  }

  void toggleStaffSelection(String employeeId) {
    final s = Set<String>.from(state.selectedStaffIds);
    if (s.contains(employeeId)) {
      s.remove(employeeId);
    } else {
      s.add(employeeId);
    }
    state = state.copyWith(selectedStaffIds: s);
  }

  void selectAllStaff(bool selectAll) {
    if (selectAll) {
      final allIds = state.staffRoster.map((s) => s.employeeId).toSet();
      state = state.copyWith(selectedStaffIds: allIds);
    } else {
      state = state.copyWith(selectedStaffIds: {});
    }
  }

  void markAllStaff(AttendanceStatus status) {
    final drafts = Map<String, AttendanceStatus>.from(state.draftStaffStatuses);
    for (final staff in state.staffRoster) {
      drafts[staff.employeeId] = status;
    }
    state = state.copyWith(draftStaffStatuses: drafts);
  }

  void markSelectedStaff(AttendanceStatus status) {
    if (state.selectedStaffIds.isEmpty) return;
    final drafts = Map<String, AttendanceStatus>.from(state.draftStaffStatuses);
    for (final empId in state.selectedStaffIds) {
      drafts[empId] = status;
    }
    state = state.copyWith(draftStaffStatuses: drafts);
  }

  void bulkSetStaffCheckIn(String timeStr) {
    if (state.selectedStaffIds.isEmpty) return;
    final drafts = Map<String, String>.from(state.draftStaffCheckIns);
    for (final empId in state.selectedStaffIds) {
      drafts[empId] = timeStr;
    }
    state = state.copyWith(draftStaffCheckIns: drafts);
  }

  void bulkSetStaffCheckOut(String timeStr) {
    if (state.selectedStaffIds.isEmpty) return;
    final drafts = Map<String, String>.from(state.draftStaffCheckOuts);
    for (final empId in state.selectedStaffIds) {
      drafts[empId] = timeStr;
    }
    state = state.copyWith(draftStaffCheckOuts: drafts);
  }

  void setStaffManagerOnlyFilter(bool managerOnly) {
    state = state.copyWith(staffManagerOnlyFilter: managerOnly, staffPage: 1);
    fetchStaffRoster();
  }

  void setStaffDepartmentFilter(String dept) {
    state = state.copyWith(staffDepartmentFilter: dept, staffPage: 1);
    fetchStaffRoster();
  }

  void setStaffRoleFilter(String role) {
    state = state.copyWith(staffRoleFilter: role, staffPage: 1);
    fetchStaffRoster();
  }

  void setStaffStatusFilter(String status) {
    state = state.copyWith(staffStatusFilter: status, staffPage: 1);
    fetchStaffRoster();
  }

  void setStaffSearch(String query) {
    state = state.copyWith(staffSearchQuery: query, staffPage: 1);
    fetchStaffRoster();
  }

  void setStaffPage(int page) {
    if (page < 1 || (page > state.staffTotalPages && state.staffTotalPages > 0)) return;
    state = state.copyWith(staffPage: page);
    fetchStaffRoster();
  }

  void setStaffPageSize(int pageSize) {
    state = state.copyWith(staffPageSize: pageSize, staffPage: 1);
    fetchStaffRoster();
  }

  void resetStaffDrafts() {
    state = state.copyWith(
      draftStaffStatuses: {},
      draftStaffRemarks: {},
      draftStaffCheckIns: {},
      draftStaffCheckOuts: {},
      selectedStaffIds: {},
    );
  }

  Future<bool> saveStaffAttendance() async {
    state = state.copyWith(isSaving: true, clearErrors: true);
    try {
      final records = <Map<String, dynamic>>[];
      for (final staff in state.staffRoster) {
        final st = state.draftStaffStatuses[staff.employeeId] ?? staff.status;
        final rem = state.draftStaffRemarks[staff.employeeId] ?? staff.remarks;
        final inTime = state.draftStaffCheckIns[staff.employeeId] ?? staff.checkInTime;
        final outTime = state.draftStaffCheckOuts[staff.employeeId] ?? staff.checkOutTime;

        records.add({
          'employee_id': staff.employeeId,
          'status': st.apiKey,
          'check_in_time': inTime,
          'check_out_time': outTime,
          'is_wfh': staff.isWfh,
          'remarks': rem,
        });
      }

      final res = await _api.saveStaffAttendance(date: state.dateString, records: records);
      if (res['success'] == true) {
        state = state.copyWith(
          successMessage: 'Staff attendance saved successfully',
          draftStaffStatuses: {},
          draftStaffRemarks: {},
          draftStaffCheckIns: {},
          draftStaffCheckOuts: {},
          selectedStaffIds: {},
        );
        await fetchStaffRoster();
        return true;
      } else {
        state = state.copyWith(errorMessage: res['detail'] ?? 'Failed to save staff attendance');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error saving staff attendance: $e');
      return false;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  // ==========================================================================
  // LEAVE & PERMISSIONS COMPLETE OPERATIONS
  // ==========================================================================

  Future<void> fetchLeaveHolidays({bool force = false}) async {
    if (state.publicHolidays.isNotEmpty && !force) return;
    try {
      final holidays = await _api.getLeaveHolidays();
      state = state.copyWith(publicHolidays: holidays);
    } catch (_) {}
  }

  Future<void> fetchLeaveDashboard() async {
    try {
      final fromStr = state.leaveFromDate != null ? DateFormat('yyyy-MM-dd').format(state.leaveFromDate!) : null;
      final toStr = state.leaveToDate != null ? DateFormat('yyyy-MM-dd').format(state.leaveToDate!) : null;
      final managerId = state.staffManagerOnlyFilter ? 'MY_REPORTS' : null;

      final dash = await _api.getLeaveDashboard(
        userType: state.leaveUserTypeFilter,
        department: state.leaveDepartmentFilter,
        status: state.leaveStatusFilter,
        leaveType: state.leaveTypeFilter,
        search: state.leaveSearchQuery,
        fromDate: fromStr,
        toDate: toStr,
        page: state.leavePage,
        pageSize: state.leavePageSize,
        managerId: managerId,
      );

      state = state.copyWith(
        leaveDashboard: dash,
        leaveRequests: dash.requests,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to load leave dashboard: $e');
    }
  }

  Future<void> fetchLeaveTypes({bool force = false}) async {
    if (state.isLeaveTypesLoaded && !force && state.leaveTypes.isNotEmpty) {
      return;
    }
    try {
      final list = await _api.getLeaveTypes();
      state = state.copyWith(leaveTypes: list, isLeaveTypesLoaded: true);
    } catch (_) {}
  }

  Future<void> fetchActiveRoles({bool force = false}) async {
    if (state.isActiveRolesLoaded && !force && state.activeRoles.isNotEmpty) {
      return;
    }
    try {
      final roles = await _api.getActiveRoles();
      state = state.copyWith(activeRoles: roles, isActiveRolesLoaded: true);
    } catch (_) {}
  }

  Future<void> fetchLeaveBalances({bool force = false, bool background = false}) async {
    if (state.isLeaveBalancesLoaded && !force && state.employeeLeaveBalances.isNotEmpty) {
      return;
    }
    if (!background || state.employeeLeaveBalances.isEmpty) {
      state = state.copyWith(isLeaveBalancesLoading: true);
    }
    try {
      final res = await _api.getLeaveBalances(
        department: state.leaveDepartmentFilter,
        role: state.leaveUserTypeFilter,
        search: state.leaveSearchQuery,
        page: state.balancesPage,
        pageSize: state.balancesPageSize,
      );
      final emps = res['employees'] as List<EmployeeLeaveBalanceModel>? ?? [];
      final bals = res['balances'] as List<LeaveBalanceRowModel>? ?? [];
      state = state.copyWith(
        employeeLeaveBalances: emps,
        leaveBalances: bals,
        balancesPage: res['page'] as int? ?? state.balancesPage,
        balancesPageSize: res['pageSize'] as int? ?? state.balancesPageSize,
        balancesTotalCount: res['totalCount'] as int? ?? emps.length,
        balancesTotalPages: res['totalPages'] as int? ?? 1,
        isLeaveBalancesLoading: false,
        isLeaveBalancesLoaded: true,
      );
    } catch (_) {
      state = state.copyWith(isLeaveBalancesLoading: false);
    }
  }

  Future<void> fetchPermissionRequests({bool force = false}) async {
    if (state.isPermissionRequestsLoaded && !force && state.permissionRequests.isNotEmpty) {
      return;
    }
    try {
      final list = await _api.getPermissionRequests(
        status: state.leaveStatusFilter,
        search: state.leaveSearchQuery,
      );
      state = state.copyWith(permissionRequests: list, isPermissionRequestsLoaded: true);
    } catch (_) {}
  }

  void setLeaveSubTab(String subTab) {
    state = state.copyWith(leaveSubTab: subTab);
    if (subTab == 'REQUESTS' && state.leaveRequests.isEmpty) {
      fetchLeaveDashboard();
    } else if (subTab == 'BALANCES' && !state.isLeaveBalancesLoaded) {
      fetchLeaveBalances();
    } else if (subTab == 'TYPES' && !state.isLeaveTypesLoaded) {
      fetchLeaveTypes();
    } else if (subTab == 'PERMISSIONS' && !state.isPermissionRequestsLoaded) {
      fetchPermissionRequests();
    }
  }

  void setLeaveFilters({
    String? userType,
    String? department,
    String? status,
    String? leaveType,
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    state = state.copyWith(
      leaveUserTypeFilter: userType,
      leaveDepartmentFilter: department,
      leaveStatusFilter: status,
      leaveTypeFilter: leaveType,
      leaveSearchQuery: search,
      leaveFromDate: fromDate,
      leaveToDate: toDate,
      leavePage: 1,
      balancesPage: 1,
      isLeaveBalancesLoaded: false,
      isLeaveTypesLoaded: false,
      isPermissionRequestsLoaded: false,
    );
    if (state.leaveSubTab == 'BALANCES') {
      fetchLeaveBalances(force: true);
    } else if (state.leaveSubTab == 'TYPES') {
      fetchLeaveTypes(force: true);
    } else if (state.leaveSubTab == 'PERMISSIONS') {
      fetchPermissionRequests(force: true);
    } else {
      fetchLeaveDashboard();
    }
  }

  void resetLeaveFilters() {
    state = state.copyWith(
      leaveUserTypeFilter: 'ALL',
      leaveDepartmentFilter: 'ALL',
      leaveStatusFilter: 'ALL',
      leaveTypeFilter: 'ALL',
      leaveSearchQuery: '',
      clearLeaveDates: true,
      leavePage: 1,
      balancesPage: 1,
      isLeaveBalancesLoaded: false,
      isLeaveTypesLoaded: false,
      isPermissionRequestsLoaded: false,
    );
    if (state.leaveSubTab == 'BALANCES') {
      fetchLeaveBalances(force: true);
    } else if (state.leaveSubTab == 'TYPES') {
      fetchLeaveTypes(force: true);
    } else if (state.leaveSubTab == 'PERMISSIONS') {
      fetchPermissionRequests(force: true);
    } else {
      fetchLeaveDashboard();
    }
  }

  void setLeavePage(int page) {
    if (page < 1) return;
    state = state.copyWith(leavePage: page);
    fetchLeaveDashboard();
  }

  void setLeavePageSize(int pageSize) {
    state = state.copyWith(leavePageSize: pageSize, leavePage: 1);
    fetchLeaveDashboard();
  }

  void setBalancesPage(int page) {
    if (page < 1) return;
    state = state.copyWith(balancesPage: page);
    fetchLeaveBalances(force: true);
  }

  void setBalancesPageSize(int pageSize) {
    state = state.copyWith(balancesPageSize: pageSize, balancesPage: 1);
    fetchLeaveBalances(force: true);
  }

  /// Upload real leave supporting file (Medical cert, proof document)
  Future<Map<String, dynamic>> uploadLeaveDocument(List<int> bytes, String filename) async {
    try {
      final res = await _api.uploadLeaveDocument(bytes, filename);
      return res;
    } catch (e) {
      return {'success': false, 'detail': e.toString()};
    }
  }

  /// Export filtered leave requests to CSV format and trigger download
  Future<void> exportLeaveRequestsCsv() async {
    final requests = state.leaveRequests;
    if (requests.isEmpty) {
      state = state.copyWith(errorMessage: 'No leave requests to export');
      return;
    }

    final buffer = StringBuffer();
    // UTF-8 BOM for Excel compatibility
    buffer.write('﻿');
    // Header
    buffer.writeln('Request ID,Applicant Name,Employee Code,Department,Role,Leave Type,From Date,To Date,Days,Half Day,Status,Reason,Emergency Contact,Applied On,Approved/Rejected By,Review Remarks');

    for (final req in requests) {
      final code = req.requestCode.isNotEmpty ? req.requestCode : 'LV-${req.id.length >= 4 ? req.id.substring(0, 4).toUpperCase() : req.id}';
      final name = '"${req.applicantName.replaceAll('"', '""')}"';
      final empCode = '"${req.employeeCode.replaceAll('"', '""')}"';
      final dept = '"${req.department.replaceAll('"', '""')}"';
      final role = '"${req.applicantRole.replaceAll('"', '""')}"';
      final type = '"${req.leaveType.replaceAll('"', '""')}"';
      final from = DateFormat('yyyy-MM-dd').format(req.startDate);
      final to = DateFormat('yyyy-MM-dd').format(req.endDate);
      final days = req.daysCount.toStringAsFixed(1);
      final half = req.halfDayType.replaceAll('_', ' ');
      final status = req.status.toUpperCase();
      final reason = '"${req.reason.replaceAll('"', '""')}"';
      final contact = '"${(req.contactNumber ?? '').replaceAll('"', '""')}"';
      final applied = DateFormat('yyyy-MM-dd HH:mm').format(req.appliedAt);
      final approver = '"${(req.approvedByName ?? '').replaceAll('"', '""')}"';
      final remarks = '"${(req.remarks ?? '').replaceAll('"', '""')}"';

      buffer.writeln('$code,$name,$empCode,$dept,$role,$type,$from,$to,$days,$half,$status,$reason,$contact,$applied,$approver,$remarks');
    }

    try {
      final csvContent = buffer.toString();
      final bytes = utf8.encode(csvContent);
      final filename = 'leave_requests_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      
      final downloadHelper = getDownloadHelper();
      await downloadHelper.downloadBytes(bytes, filename);

      state = state.copyWith(successMessage: 'Exported ${requests.length} leave records to $filename');
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to export CSV: $e');
    }
  }

  void exportAttendanceCsv() {
    exportLeaveRequestsCsv();
  }

  Future<bool> applyLeave({
    String? applicantId,
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
    String halfDayType = 'FULL_DAY',
    String? contactNumber,
    String? attachmentUrl,
    double? billableDays,
    double? daysCount,
  }) async {
    state = state.copyWith(isSaving: true, clearErrors: true);
    try {
      final res = await _api.applyLeave(
        applicantId: applicantId,
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        halfDayType: halfDayType,
        contactNumber: contactNumber,
        attachmentUrl: attachmentUrl,
        billableDays: billableDays,
        daysCount: daysCount,
      );
      if (res['success'] == true) {
        state = state.copyWith(successMessage: 'Leave application submitted successfully');
        await fetchLeaveDashboard();
        return true;
      } else {
        state = state.copyWith(errorMessage: res['detail'] ?? res['error'] ?? 'Failed to apply leave');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error applying leave: $e');
      return false;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<bool> handleLeaveAction(String leaveId, String action, {String? remarks}) async {
    state = state.copyWith(isLoading: true, clearErrors: true);
    try {
      final res = await _api.handleLeaveAction(leaveId: leaveId, action: action, remarks: remarks);
      if (res['success'] == true) {
        state = state.copyWith(successMessage: 'Leave request updated successfully');
        await fetchLeaveDashboard();
        await fetchDailyRoster();
        await fetchStaffRoster();
        return true;
      } else {
        state = state.copyWith(errorMessage: res['detail'] ?? res['error'] ?? 'Action failed');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error updating leave: $e');
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> handleBatchLeaveAction({
    required List<String> requestIds,
    required String action,
    String? remarks,
    bool selectAll = false,
  }) async {
    if (requestIds.isEmpty && !selectAll) return true;
    state = state.copyWith(isLoading: true, clearErrors: true);
    try {
      final res = await _api.handleBatchLeaveAction(
        requestIds: requestIds,
        action: action,
        remarks: remarks,
        selectAll: selectAll,
        status: state.leaveStatusFilter,
        userType: state.leaveRoleFilter,
      );
      if (res['success'] == true) {
        state = state.copyWith(successMessage: res['message'] ?? 'Batch leave action completed');
        await fetchLeaveDashboard();
        await fetchDailyRoster();
        await fetchStaffRoster();
        return true;
      } else {
        state = state.copyWith(errorMessage: res['detail'] ?? res['error'] ?? 'Batch action failed');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error processing batch leave action: $e');
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> handleBatchPermissionAction({
    required List<String> permissionIds,
    required String action,
    String? remarks,
    bool selectAll = false,
  }) async {
    if (permissionIds.isEmpty && !selectAll) return true;
    state = state.copyWith(isLoading: true, clearErrors: true);
    try {
      final res = await _api.handleBatchPermissionAction(
        permissionIds: permissionIds,
        action: action,
        remarks: remarks,
        selectAll: selectAll,
        status: state.leaveStatusFilter,
      );
      if (res['success'] == true) {
        state = state.copyWith(successMessage: res['message'] ?? 'Batch permission action completed');
        await fetchPermissionRequests(force: true);
        await fetchLeaveDashboard();
        return true;
      } else {
        state = state.copyWith(errorMessage: res['detail'] ?? res['error'] ?? 'Batch action failed');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error processing batch permission action: $e');
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> saveLeaveType(Map<String, dynamic> payload) async {
    state = state.copyWith(isSaving: true, clearErrors: true);
    try {
      final res = await _api.saveLeaveType(payload);
      if (res['success'] == true) {
        state = state.copyWith(successMessage: 'Leave type saved successfully');
        await fetchLeaveTypes(force: true);
        await fetchLeaveDashboard();
        return true;
      } else {
        state = state.copyWith(errorMessage: res['detail'] ?? 'Failed to save leave type');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error saving leave type: $e');
      return false;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<bool> adjustLeaveBalance({
    required String userId,
    required String leaveTypeId,
    required double adjustmentDays,
    required String reason,
  }) async {
    state = state.copyWith(isSaving: true, clearErrors: true);
    try {
      final res = await _api.adjustLeaveBalance(
        userId: userId,
        leaveTypeId: leaveTypeId,
        adjustmentDays: adjustmentDays,
        reason: reason,
      );
      if (res['success'] == true) {
        state = state.copyWith(successMessage: 'Leave balance adjusted successfully');
        await fetchLeaveBalances(force: true);
        await fetchLeaveDashboard();
        return true;
      } else {
        state = state.copyWith(errorMessage: res['detail'] ?? res['error'] ?? 'Failed to adjust balance');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error adjusting balance: $e');
      return false;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<bool> applyPermissionRequest({
    String? applicantId,
    required String permissionType,
    required String date,
    required String startTime,
    required String endTime,
    double durationHours = 1.0,
    required String reason,
  }) async {
    state = state.copyWith(isSaving: true, clearErrors: true);
    try {
      final res = await _api.applyPermissionRequest(
        applicantId: applicantId,
        permissionType: permissionType,
        date: date,
        startTime: startTime,
        endTime: endTime,
        durationHours: durationHours,
        reason: reason,
      );
      if (res['success'] == true) {
        state = state.copyWith(successMessage: 'Permission request submitted successfully');
        await fetchPermissionRequests(force: true);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['detail'] ?? res['error'] ?? 'Failed to apply permission');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error applying permission: $e');
      return false;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<bool> handlePermissionAction({
    required String permissionId,
    required String action,
    String? remarks,
  }) async {
    state = state.copyWith(isLoading: true, clearErrors: true);
    try {
      final res = await _api.handlePermissionAction(
        permissionId: permissionId,
        action: action,
        remarks: remarks,
      );
      if (res['success'] == true) {
        state = state.copyWith(successMessage: 'Permission request updated successfully');
        await fetchPermissionRequests(force: true);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['detail'] ?? 'Action failed');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error updating permission: $e');
      return false;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> executeBulkOperation({
    required String operation,
    required List<String> studentIds,
    String? targetStatus,
    String? remarks,
    String? reason,
  }) async {
    if (state.selectedClassId == null) return false;
    state = state.copyWith(isSaving: true, clearErrors: true);
    try {
      final res = await _api.executeBulkOperation(
        operation: operation,
        date: state.dateString,
        classId: state.selectedClassId!,
        sectionId: state.selectedSectionId,
        studentIds: studentIds,
        targetStatus: targetStatus,
        remarks: remarks,
        reason: reason,
      );

      if (res['success'] == true) {
        state = state.copyWith(
          successMessage: res['message'] ?? 'Bulk operation executed successfully',
          selectedStudentIds: {},
        );
        await refreshAllData();
        return true;
      } else {
        state = state.copyWith(errorMessage: res['detail'] ?? 'Bulk operation failed');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error in bulk operation: $e');
      return false;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<bool> updateSettings(AttendanceSettingsModel newSettings) async {
    state = state.copyWith(isSaving: true, clearErrors: true);
    try {
      final res = await _api.updateSettings(newSettings.toJson());
      if (res['success'] == true) {
        state = state.copyWith(
          settings: newSettings,
          successMessage: 'Settings updated successfully',
        );
        return true;
      } else {
        state = state.copyWith(errorMessage: res['detail'] ?? 'Failed to update settings');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error updating settings: $e');
      return false;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  /// Alias to refreshAllData
  Future<void> refreshAll() async {
    await refreshAllData();
  }
}

final attendanceProvider = StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  final api = ref.watch(attendanceApiServiceProvider);
  return AttendanceNotifier(api);
});
