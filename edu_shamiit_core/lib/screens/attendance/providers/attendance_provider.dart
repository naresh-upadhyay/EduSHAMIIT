import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/attendance_models.dart';
import '../services/attendance_api_service.dart';
import '../../classes/models/class_models.dart';
import '../../classes/services/class_api_service.dart';

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
  final Map<String, AttendanceStatus> draftStaffStatuses;
  final Map<String, String> draftStaffRemarks;
  final String staffDepartmentFilter;
  final String staffRoleFilter;
  final String staffStatusFilter;
  final String staffSearchQuery;
  final int staffPage;
  final int staffPageSize;
  final int staffTotalCount;
  final int staffTotalPages;

  final List<AttendanceLeaveRequestModel> leaveRequests;
  final String leaveStatusFilter;
  final String leaveRoleFilter;

  final AttendanceInsightsModel? insights;
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
    this.draftStaffStatuses = const {},
    this.draftStaffRemarks = const {},
    this.staffDepartmentFilter = 'ALL',
    this.staffRoleFilter = 'ALL',
    this.staffStatusFilter = 'ALL',
    this.staffSearchQuery = '',
    this.staffPage = 1,
    this.staffPageSize = 10,
    this.staffTotalCount = 0,
    this.staffTotalPages = 1,
    this.leaveRequests = const [],
    this.leaveStatusFilter = 'ALL',
    this.leaveRoleFilter = 'ALL',
    this.insights,
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
        settings = settings ?? AttendanceSettingsModel();

  String get dateString => DateFormat('yyyy-MM-dd').format(selectedDate);
  String get displayDateString => DateFormat('dd MMM yyyy, EEE').format(selectedDate);
  bool get isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day == now.day;
  }

  bool get hasUnsavedChanges => draftStatuses.isNotEmpty || draftRemarks.isNotEmpty;

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
    Map<String, AttendanceStatus>? draftStaffStatuses,
    Map<String, String>? draftStaffRemarks,
    String? staffDepartmentFilter,
    String? staffRoleFilter,
    String? staffStatusFilter,
    String? staffSearchQuery,
    int? staffPage,
    int? staffPageSize,
    int? staffTotalCount,
    int? staffTotalPages,
    List<AttendanceLeaveRequestModel>? leaveRequests,
    String? leaveStatusFilter,
    String? leaveRoleFilter,
    AttendanceInsightsModel? insights,
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
      draftStaffStatuses: draftStaffStatuses ?? this.draftStaffStatuses,
      draftStaffRemarks: draftStaffRemarks ?? this.draftStaffRemarks,
      staffDepartmentFilter: staffDepartmentFilter ?? this.staffDepartmentFilter,
      staffRoleFilter: staffRoleFilter ?? this.staffRoleFilter,
      staffStatusFilter: staffStatusFilter ?? this.staffStatusFilter,
      staffSearchQuery: staffSearchQuery ?? this.staffSearchQuery,
      staffPage: staffPage ?? this.staffPage,
      staffPageSize: staffPageSize ?? this.staffPageSize,
      staffTotalCount: staffTotalCount ?? this.staffTotalCount,
      staffTotalPages: staffTotalPages ?? this.staffTotalPages,
      leaveRequests: leaveRequests ?? this.leaveRequests,
      leaveStatusFilter: leaveStatusFilter ?? this.leaveStatusFilter,
      leaveRoleFilter: leaveRoleFilter ?? this.leaveRoleFilter,
      insights: insights ?? this.insights,
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
      final classes = (classesData['classes'] as List<AcademicClassModel>?) ?? [];

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

      // 2. Fetch Daily Attendance Data
      await refreshAllData();
      // 3. Fetch Settings in Background
      final settings = await _api.getSettings();
      state = state.copyWith(settings: settings);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to initialize attendance: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
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
      await fetchLeaveRequests();
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
      state = state.copyWith(
        roster: students,
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
      state = state.copyWith(schedulesToday: schedules);
    } catch (_) {}
  }

  /// Fetch staff attendance roster
  Future<void> fetchStaffRoster() async {
    try {
      final res = await _api.getStaffAttendance(
        date: state.dateString,
        department: state.staffDepartmentFilter,
        role: state.staffRoleFilter,
        status: state.staffStatusFilter,
        search: state.staffSearchQuery,
        page: state.staffPage,
        pageSize: state.staffPageSize,
      );

      final staff = res['staff'] as List<StaffAttendanceRowModel>;
      state = state.copyWith(
        staffRoster: staff,
        staffTotalCount: res['totalCount'] as int,
        staffPage: res['page'] as int,
        staffPageSize: res['pageSize'] as int,
        staffTotalPages: res['totalPages'] as int,
        draftStaffStatuses: {},
        draftStaffRemarks: {},
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to load staff roster: $e');
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

  /// Fetch insights & at-risk students
  Future<void> fetchInsights() async {
    try {
      final now = state.selectedDate;
      final startDate = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 30)));
      final endDate = DateFormat('yyyy-MM-dd').format(now);

      final ins = await _api.getInsights(
        startDate: startDate,
        endDate: endDate,
        classId: state.selectedClassId,
        sectionId: state.selectedSectionId,
      );
      state = state.copyWith(insights: ins);
    } catch (_) {}
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
    state = state.copyWith(selectedDate: date, page: 1, clearErrors: true);
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
    state = state.copyWith(selectedMode: mode, page: 1, clearErrors: true);
    refreshAllData();
  }

  void setPeriod(int? periodNumber, String? subjectId) {
    state = state.copyWith(
      selectedPeriodNumber: periodNumber,
      selectedSubjectId: subjectId,
      page: 1,
      clearErrors: true,
    );
    refreshAllData();
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
    final currentDrafts = Map<String, AttendanceStatus>.from(state.draftStatuses);
    currentDrafts[studentId] = newStatus;
    state = state.copyWith(draftStatuses: currentDrafts);
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

  void markAll(AttendanceStatus status) {
    final currentDrafts = Map<String, AttendanceStatus>.from(state.draftStatuses);
    for (final student in state.roster) {
      if (!student.isLocked) {
        currentDrafts[student.studentId] = status;
      }
    }
    state = state.copyWith(draftStatuses: currentDrafts);
  }

  void resetDrafts() {
    state = state.copyWith(draftStatuses: {}, draftRemarks: {}, selectedStudentIds: {});
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
        records.add({
          'student_id': student.studentId,
          'status': st.apiKey,
          'remarks': rem,
          'period_number': state.selectedPeriodNumber,
          'subject_id': state.selectedSubjectId,
        });
      }

      final res = await _api.saveAttendance(
        date: state.dateString,
        classId: state.selectedClassId!,
        sectionId: state.selectedSectionId,
        mode: state.selectedMode.apiKey,
        periodNumber: state.selectedPeriodNumber,
        subjectId: state.selectedSubjectId,
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
  // STAFF, LEAVE, BULK & SETTINGS MUTATIONS
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

  Future<bool> saveStaffAttendance() async {
    state = state.copyWith(isSaving: true, clearErrors: true);
    try {
      final records = <Map<String, dynamic>>[];
      for (final staff in state.staffRoster) {
        final st = state.draftStaffStatuses[staff.employeeId] ?? staff.status;
        final rem = state.draftStaffRemarks[staff.employeeId] ?? staff.remarks;
        records.add({
          'employee_id': staff.employeeId,
          'status': st.apiKey,
          'check_in_time': staff.checkInTime,
          'check_out_time': staff.checkOutTime,
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

  Future<bool> handleLeaveAction(String leaveId, String action, {String? remarks}) async {
    state = state.copyWith(isLoading: true, clearErrors: true);
    try {
      final res = await _api.handleLeaveAction(leaveId: leaveId, action: action, remarks: remarks);
      if (res['success'] == true) {
        state = state.copyWith(successMessage: 'Leave request updated successfully');
        await fetchLeaveRequests();
        await fetchDailyRoster();
        return true;
      } else {
        state = state.copyWith(errorMessage: res['detail'] ?? 'Action failed');
        return false;
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error updating leave: $e');
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
}

final attendanceProvider = StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  final api = ref.watch(attendanceApiServiceProvider);
  return AttendanceNotifier(api);
});
