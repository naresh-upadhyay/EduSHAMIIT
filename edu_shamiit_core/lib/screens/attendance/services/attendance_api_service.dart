import '../../../../services/api_service.dart';
import '../models/attendance_models.dart';

class AttendanceApiService {
  final ApiService _api = ApiService();

  /// Retrieve summary stats and day summary
  Future<AttendanceStatsModel> getStats({
    required String date,
    String? classId,
    String? sectionId,
    String? teacherId,
  }) async {
    try {
      final query = <String, String>{'attendance_date': date};
      if (classId != null && classId.isNotEmpty) query['class_id'] = classId;
      if (sectionId != null && sectionId.isNotEmpty) query['section_id'] = sectionId;
      if (teacherId != null && teacherId.isNotEmpty) query['teacher_id'] = teacherId;

      final res = await _api.get('/attendance/stats', query: query, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return AttendanceStatsModel.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return AttendanceStatsModel();
  }

  /// Get paginated student roster with status, remarks, locks, and leave info
  Future<Map<String, dynamic>> getRoster({
    required String date,
    required String classId,
    String? sectionId,
    String mode = 'ALL_DAY',
    int? periodNumber,
    String? subjectId,
    String search = '',
    String statusFilter = 'ALL',
    int page = 1,
    int pageSize = 10,
    String? teacherId,
  }) async {
    final query = <String, String>{
      'attendance_date': date,
      'class_id': classId,
      'mode': mode,
      'search': search,
      'status_filter': statusFilter,
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (sectionId != null && sectionId.isNotEmpty) query['section_id'] = sectionId;
    if (periodNumber != null) query['period_number'] = periodNumber.toString();
    if (subjectId != null && subjectId.isNotEmpty) query['subject_id'] = subjectId;
    if (teacherId != null && teacherId.isNotEmpty) query['teacher_id'] = teacherId;

    final res = await _api.get('/attendance/roster', query: query, useCache: false);
    final data = res['data'] as Map<String, dynamic>? ?? {};
    final rawList = data['students'] as List? ?? [];
    final students = rawList.map((e) => AttendanceStudentRowModel.fromJson(e as Map<String, dynamic>)).toList();

    return {
      'students': students,
      'totalCount': data['total_count'] ?? 0,
      'page': data['page'] ?? page,
      'pageSize': data['page_size'] ?? pageSize,
      'totalPages': data['total_pages'] ?? 1,
      'isLockedAllDay': data['is_locked_all_day'] == true,
      'lockedAt': data['locked_at'] != null ? DateTime.tryParse(data['locked_at'].toString()) : null,
      'lockedByName': data['locked_by_name']?.toString(),
    };
  }

  /// Save daily or period attendance
  Future<Map<String, dynamic>> saveAttendance({
    required String date,
    required String classId,
    String? sectionId,
    String mode = 'ALL_DAY',
    int? periodNumber,
    String? subjectId,
    String? scheduleId,
    List<String>? selectedScheduleIds,
    List<Map<String, dynamic>>? selectedPeriods,
    required List<Map<String, dynamic>> records,
    bool allowOverride = false,
  }) async {
    final body = <String, dynamic>{
      'attendance_date': date,
      'class_id': classId,
      'section_id': sectionId,
      'mode': mode,
      'period_number': periodNumber,
      'subject_id': subjectId,
      'schedule_id': scheduleId,
      if (selectedScheduleIds != null && selectedScheduleIds.isNotEmpty)
        'selected_schedule_ids': selectedScheduleIds,
      if (selectedPeriods != null && selectedPeriods.isNotEmpty)
        'selected_periods': selectedPeriods,
      'records': records,
      'allow_override': allowOverride,
    };
    return await _api.post('/attendance/save', body);
  }

  /// Override a locked record with mandatory reason
  Future<Map<String, dynamic>> overrideLockedRecord({
    required String recordId,
    String recordType = 'DAILY',
    required String newStatus,
    required String reason,
  }) async {
    final body = <String, dynamic>{
      'record_id': recordId,
      'record_type': recordType,
      'new_status': newStatus,
      'reason': reason,
    };
    return await _api.post('/attendance/override', body);
  }

  /// Quick mark or update a single student's attendance for a specific period
  Future<Map<String, dynamic>> quickMarkStudentPeriod({
    required String studentId,
    required String date,
    required int periodNumber,
    required String status,
    String? subjectId,
    String? scheduleId,
    String? remarks,
  }) async {
    final body = <String, dynamic>{
      'student_id': studentId,
      'attendance_date': date,
      'period_number': periodNumber,
      'status': status,
      if (subjectId != null && subjectId.isNotEmpty) 'subject_id': subjectId,
      if (scheduleId != null && scheduleId.isNotEmpty) 'schedule_id': scheduleId,
      'remarks': remarks ?? '',
    };
    return await _api.post('/attendance/quick-mark-period', body);
  }

  /// Fetch today's timetable schedules for a class and section
  Future<List<AttendanceScheduleItemModel>> getSchedulesToday({
    required String date,
    required String classId,
    String? sectionId,
  }) async {
    try {
      final query = <String, String>{'attendance_date': date, 'class_id': classId};
      if (sectionId != null && sectionId.isNotEmpty) query['section_id'] = sectionId;

      final res = await _api.get('/attendance/schedules', query: query, useCache: false);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final rawList = data['schedules'] as List? ?? [];
      return rawList.map((e) => AttendanceScheduleItemModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch student attendance details for side drawer
  Future<Map<String, dynamic>> getStudentDetail({
    required String studentId,
    required String date,
  }) async {
    final res = await _api.get('/attendance/student-detail/$studentId', query: {'attendance_date': date}, useCache: false);
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// Get staff attendance roster
  Future<Map<String, dynamic>> getStaffAttendance({
    required String date,
    String department = 'ALL',
    String role = 'ALL',
    String status = 'ALL',
    String search = '',
    int page = 1,
    int pageSize = 10,
    String? managerId,
  }) async {
    final query = <String, String>{
      'attendance_date': date,
      'department': department,
      'role': role,
      'status': status,
      'search': search,
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (managerId != null && managerId.isNotEmpty) query['manager_id'] = managerId;

    final res = await _api.get('/attendance/staff', query: query, useCache: false);
    final data = res['data'] as Map<String, dynamic>? ?? {};
    final rawList = data['staff'] as List? ?? [];
    final staff = rawList.map((e) => StaffAttendanceRowModel.fromJson(e as Map<String, dynamic>)).toList();

    return {
      'staff': staff,
      'totalCount': data['total_count'] ?? 0,
      'page': data['page'] ?? page,
      'pageSize': data['page_size'] ?? pageSize,
      'totalPages': data['total_pages'] ?? 1,
    };
  }

  /// Save staff attendance
  Future<Map<String, dynamic>> saveStaffAttendance({
    required String date,
    required List<Map<String, dynamic>> records,
  }) async {
    final body = <String, dynamic>{
      'attendance_date': date,
      'records': records,
    };
    return await _api.post('/attendance/staff/save', body);
  }

  /// Get comprehensive Leave & Permissions Dashboard
  Future<LeaveDashboardModel> getLeaveDashboard({
    String userType = 'ALL',
    String department = 'ALL',
    String status = 'ALL',
    String leaveType = 'ALL',
    String search = '',
    String? fromDate,
    String? toDate,
    int page = 1,
    int pageSize = 10,
    String? managerId,
  }) async {
    try {
      final query = <String, String>{
        'user_type': userType,
        'department': department,
        'status': status,
        'leave_type': leaveType,
        'search': search,
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (fromDate != null && fromDate.isNotEmpty) query['from_date'] = fromDate;
      if (toDate != null && toDate.isNotEmpty) query['to_date'] = toDate;
      if (managerId != null && managerId.isNotEmpty) query['manager_id'] = managerId;

      final res = await _api.get('/attendance/leave/dashboard', query: query, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return LeaveDashboardModel.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return LeaveDashboardModel(kpi: LeaveDashboardKpiModel());
  }

  /// Get integrated leave requests list
  Future<List<AttendanceLeaveRequestModel>> getLeaveRequests({
    String status = 'ALL',
    String role = 'ALL',
    String? managerId,
  }) async {
    try {
      final query = <String, String>{'status': status, 'role': role};
      if (managerId != null && managerId.isNotEmpty) query['manager_id'] = managerId;
      final res = await _api.get('/attendance/leave-requests', query: query, useCache: false);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final list = data['leave_requests'] as List? ?? [];
      return list.map((e) => AttendanceLeaveRequestModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Upload supporting leave document (medical certificate, proof)
  Future<Map<String, dynamic>> uploadLeaveDocument(List<int> bytes, String filename) async {
    return await _api.multipartPostBytes('/attendance/leave/upload', bytes, filename, 'file');
  }

  /// Retrieve public & institutional calendar holidays
  Future<List<HolidayItemModel>> getLeaveHolidays() async {
    try {
      final res = await _api.get('/attendance/leave/holidays', useCache: false);
      final list = res['data'] as List? ?? [];
      return list.map((e) => HolidayItemModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Apply for a leave application
  Future<Map<String, dynamic>> applyLeave({
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
    final body = <String, dynamic>{
      'leave_type': leaveType,
      'start_date': startDate,
      'end_date': endDate,
      'reason': reason,
      'half_day_type': halfDayType,
    };
    if (applicantId != null && applicantId.isNotEmpty) body['applicant_id'] = applicantId;
    if (contactNumber != null && contactNumber.isNotEmpty) body['contact_number'] = contactNumber;
    if (attachmentUrl != null && attachmentUrl.isNotEmpty) body['attachment_url'] = attachmentUrl;
    if (billableDays != null) body['billable_days'] = billableDays;
    if (daysCount != null) body['days_count'] = daysCount;

    return await _api.post('/attendance/leave/apply', body);
  }

  /// Approve or Reject a leave application
  Future<Map<String, dynamic>> handleLeaveAction({
    required String leaveId,
    required String action, // APPROVE, REJECT, CANCEL
    String? remarks,
  }) async {
    final body = <String, dynamic>{
      'action': action,
      'remarks': remarks,
    };
    return await _api.post('/attendance/leave/requests/$leaveId/action', body);
  }

  /// Batch Approve, Reject or Cancel multiple leave applications
  Future<Map<String, dynamic>> handleBatchLeaveAction({
    required List<String> requestIds,
    required String action, // APPROVE, REJECT, CANCEL
    String? remarks,
    bool selectAll = false,
    String? status,
    String? userType,
    String? department,
  }) async {
    final body = <String, dynamic>{
      'request_ids': requestIds,
      'action': action,
      'remarks': remarks,
      'select_all': selectAll,
    };
    if (status != null) body['status'] = status;
    if (userType != null) body['user_type'] = userType;
    if (department != null) body['department'] = department;
    return await _api.post('/attendance/leave/requests/batch-action', body);
  }

  /// Get list of configured leave types, optionally filtered by role
  Future<List<LeaveTypeModel>> getLeaveTypes({String? role}) async {
    try {
      final query = (role != null && role.isNotEmpty && role.toUpperCase() != 'ALL') ? {'role': role} : null;
      final res = await _api.get('/attendance/leave/types', query: query, useCache: false);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final list = data['leave_types'] as List? ?? [];
      return list.map((e) => LeaveTypeModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get active roles from app_roles
  Future<List<AppRoleItemModel>> getActiveRoles() async {
    try {
      final res = await _api.get('/attendance/roles', useCache: false);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final list = data['roles'] as List? ?? [];
      return list.map((e) => AppRoleItemModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Save or update a leave type policy
  Future<Map<String, dynamic>> saveLeaveType(Map<String, dynamic> payload) async {
    return await _api.post('/attendance/leave/types', payload);
  }

  /// Get all employee leave balances (paginated)
  Future<Map<String, dynamic>> getLeaveBalances({
    String academicYear = '2026-2027',
    String department = 'ALL',
    String role = 'ALL',
    String search = '',
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final query = <String, String>{
        'academic_year': academicYear,
        'department': department,
        'role': role,
        'search': search,
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      final res = await _api.get('/attendance/leave/balances', query: query, useCache: false);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final rawEmployees = data['employees'] as List? ?? [];
      final employees = rawEmployees.map((e) => EmployeeLeaveBalanceModel.fromJson(e as Map<String, dynamic>)).toList();
      final rawBalances = data['balances'] as List? ?? [];
      final balances = rawBalances.map((e) => LeaveBalanceRowModel.fromJson(e as Map<String, dynamic>)).toList();

      return {
        'employees': employees,
        'balances': balances,
        'page': (data['page'] as num?)?.toInt() ?? page,
        'pageSize': (data['page_size'] as num?)?.toInt() ?? pageSize,
        'totalCount': (data['total_count'] as num?)?.toInt() ?? employees.length,
        'totalPages': (data['total_pages'] as num?)?.toInt() ?? 1,
      };
    } catch (_) {
      return {
        'employees': <EmployeeLeaveBalanceModel>[],
        'balances': <LeaveBalanceRowModel>[],
        'page': 1,
        'pageSize': 10,
        'totalCount': 0,
        'totalPages': 1,
      };
    }
  }

  /// Adjust employee leave balance
  Future<Map<String, dynamic>> adjustLeaveBalance({
    required String userId,
    required String leaveTypeId,
    required double adjustmentDays,
    required String reason,
    String academicYear = '2026-2027',
  }) async {
    final body = <String, dynamic>{
      'user_id': userId,
      'leave_type_id': leaveTypeId,
      'adjustment_days': adjustmentDays,
      'reason': reason,
      'academic_year': academicYear,
    };
    return await _api.post('/attendance/leave/balances/adjust', body);
  }

  /// Get short permission requests
  Future<List<PermissionRequestModel>> getPermissionRequests({
    String status = 'ALL',
    String? date,
    String search = '',
  }) async {
    try {
      final query = <String, String>{'status': status, 'search': search};
      if (date != null && date.isNotEmpty) query['date'] = date;
      final res = await _api.get('/attendance/permissions/requests', query: query, useCache: false);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final list = data['permissions'] as List? ?? [];
      return list.map((e) => PermissionRequestModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Apply for short permission request
  Future<Map<String, dynamic>> applyPermissionRequest({
    String? applicantId,
    required String permissionType,
    required String date,
    required String startTime,
    required String endTime,
    double durationHours = 1.0,
    required String reason,
  }) async {
    final body = <String, dynamic>{
      'permission_type': permissionType,
      'permission_date': date,
      'start_time': startTime,
      'end_time': endTime,
      'duration_hours': durationHours,
      'reason': reason,
    };
    if (applicantId != null && applicantId.isNotEmpty) body['applicant_id'] = applicantId;
    return await _api.post('/attendance/permissions/requests', body);
  }

  /// Approve or Reject short permission request
  Future<Map<String, dynamic>> handlePermissionAction({
    required String permissionId,
    required String action, // APPROVE, REJECT, CANCEL
    String? remarks,
  }) async {
    final body = <String, dynamic>{
      'action': action,
      'remarks': remarks,
    };
    return await _api.post('/attendance/permissions/requests/$permissionId/action', body);
  }

  /// Batch Approve, Reject or Cancel multiple permission requests
  Future<Map<String, dynamic>> handleBatchPermissionAction({
    required List<String> permissionIds,
    required String action, // APPROVE, REJECT, CANCEL
    String? remarks,
    bool selectAll = false,
    String? status,
  }) async {
    final body = <String, dynamic>{
      'permission_ids': permissionIds,
      'action': action,
      'remarks': remarks,
      'select_all': selectAll,
    };
    if (status != null) body['status'] = status;
    return await _api.post('/attendance/permissions/requests/batch-action', body);
  }

  /// Execute bulk operations
  Future<Map<String, dynamic>> executeBulkOperation({
    required String operation,
    required String date,
    required String classId,
    String? sectionId,
    required List<String> studentIds,
    String? targetStatus,
    String? remarks,
    String? reason,
  }) async {
    final body = <String, dynamic>{
      'operation': operation,
      'attendance_date': date,
      'class_id': classId,
      'section_id': sectionId,
      'student_ids': studentIds,
      'target_status': targetStatus,
      'remarks': remarks,
      'reason': reason,
    };
    return await _api.post('/attendance/bulk', body);
  }

  /// Get attendance insights & at-risk students
  Future<AttendanceInsightsModel?> getInsights({
    required String startDate,
    required String endDate,
    String? viewBy,
    String? role,
    String? classId,
    String? sectionId,
    String? department,
    String? granularity,
  }) async {
    try {
      final query = <String, String>{'start_date': startDate, 'end_date': endDate};
      if (viewBy != null && viewBy.isNotEmpty) query['view_by'] = viewBy;
      if (role != null && role.isNotEmpty && role != 'ALL') query['role'] = role;
      if (classId != null && classId.isNotEmpty) query['class_id'] = classId;
      if (sectionId != null && sectionId.isNotEmpty) query['section_id'] = sectionId;
      if (department != null && department.isNotEmpty && department != 'ALL' && department != 'All Departments') {
        query['department'] = department;
      }
      if (granularity != null && granularity.isNotEmpty) query['granularity'] = granularity;

      final res = await _api.get('/attendance/insights', query: query, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return AttendanceInsightsModel.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// Get student attendance insights profile & calendar heatmap
  Future<Map<String, dynamic>?> getStudentInsightsProfile(
    String studentId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final query = <String, String>{};
      if (startDate != null && startDate.isNotEmpty) query['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) query['end_date'] = endDate;

      final res = await _api.get('/attendance/insights/student/$studentId', query: query, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return res['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Download attendance insights CSV report
  Future<String?> exportInsightsReport({
    required String startDate,
    required String endDate,
    String? viewBy,
    String? classId,
    String? sectionId,
    String? department,
  }) async {
    try {
      final query = <String, String>{'start_date': startDate, 'end_date': endDate};
      if (viewBy != null && viewBy.isNotEmpty) query['view_by'] = viewBy;
      if (classId != null && classId.isNotEmpty) query['class_id'] = classId;
      if (sectionId != null && sectionId.isNotEmpty) query['section_id'] = sectionId;
      if (department != null && department.isNotEmpty && department != 'ALL') query['department'] = department;

      final res = await _api.get('/attendance/insights/export', query: query, useCache: false);
      return res.toString();
    } catch (_) {}
    return null;
  }

  /// Get attendance school settings
  Future<AttendanceSettingsModel> getSettings() async {
    try {
      final res = await _api.get('/attendance/settings', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return AttendanceSettingsModel.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return AttendanceSettingsModel();
  }

  /// Update attendance school settings
  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> payload) async {
    return await _api.put('/attendance/settings', payload);
  }

  /// Get audit logs
  Future<List<AttendanceAuditLogModel>> getAuditLogs({int limit = 50}) async {
    try {
      final res = await _api.get('/attendance/audit', query: {'limit': limit.toString()}, useCache: false);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final rawList = data['audit_logs'] as List? ?? [];
      return rawList.map((e) => AttendanceAuditLogModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Export attendance as CSV
  Future<String> exportCsv({
    required String date,
    String? classId,
    String? sectionId,
  }) async {
    final query = <String, String>{'attendance_date': date};
    if (classId != null && classId.isNotEmpty) query['class_id'] = classId;
    if (sectionId != null && sectionId.isNotEmpty) query['section_id'] = sectionId;
    final res = await _api.get('/attendance/export', query: query, useCache: false);
    return res['csv_data']?.toString() ?? res['data']?.toString() ?? '';
  }

  /// Get current user's reporting manager status & direct reports count
  Future<Map<String, dynamic>> getManagerStatus() async {
    try {
      final res = await _api.get('/attendance/manager-status', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return Map<String, dynamic>.from(res['data'] as Map);
      }
    } catch (_) {}
    return {'is_manager': false, 'direct_reports_count': 0};
  }
}
