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

  /// Get integrated leave requests
  Future<List<AttendanceLeaveRequestModel>> getLeaveRequests({
    String status = 'ALL',
    String role = 'ALL',
  }) async {
    try {
      final res = await _api.get('/attendance/leave-requests', query: {'status': status, 'role': role}, useCache: false);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final rawList = data['leave_requests'] as List? ?? [];
      return rawList.map((e) => AttendanceLeaveRequestModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
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
    return await _api.post('/attendance/leave-requests/$leaveId/action', body);
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
    String? classId,
    String? sectionId,
  }) async {
    try {
      final query = <String, String>{'start_date': startDate, 'end_date': endDate};
      if (classId != null && classId.isNotEmpty) query['class_id'] = classId;
      if (sectionId != null && sectionId.isNotEmpty) query['section_id'] = sectionId;

      final res = await _api.get('/attendance/insights', query: query, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return AttendanceInsightsModel.fromJson(res['data'] as Map<String, dynamic>);
      }
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
