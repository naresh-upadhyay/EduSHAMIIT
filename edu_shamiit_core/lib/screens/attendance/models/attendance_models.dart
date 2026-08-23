import 'package:flutter/material.dart';

/// Supported Attendance Statuses across the EduSHAMIIT ERP
enum AttendanceStatus {
  present,
  absent,
  late,
  onLeave,
  halfDay,
  workFromHome,
  holiday,
  partialPeriods,
  notMarked,
}

extension AttendanceStatusExtension on AttendanceStatus {
  String get code {
    switch (this) {
      case AttendanceStatus.present:
        return 'P';
      case AttendanceStatus.absent:
        return 'A';
      case AttendanceStatus.late:
        return 'L';
      case AttendanceStatus.onLeave:
        return 'O';
      case AttendanceStatus.halfDay:
        return 'H';
      case AttendanceStatus.workFromHome:
        return 'W';
      case AttendanceStatus.holiday:
        return 'HD';
      case AttendanceStatus.partialPeriods:
        return 'PP';
      case AttendanceStatus.notMarked:
        return '-';
    }
  }

  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.onLeave:
        return 'On Leave';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.workFromHome:
        return 'Work From Home';
      case AttendanceStatus.holiday:
        return 'Holiday';
      case AttendanceStatus.partialPeriods:
        return 'Partial';
      case AttendanceStatus.notMarked:
        return 'Not Marked';
    }
  }

  String get apiKey {
    switch (this) {
      case AttendanceStatus.present:
        return 'PRESENT';
      case AttendanceStatus.absent:
        return 'ABSENT';
      case AttendanceStatus.late:
        return 'LATE';
      case AttendanceStatus.onLeave:
        return 'ON_LEAVE';
      case AttendanceStatus.halfDay:
        return 'HALF_DAY';
      case AttendanceStatus.workFromHome:
        return 'WORK_FROM_HOME';
      case AttendanceStatus.holiday:
        return 'HOLIDAY';
      case AttendanceStatus.partialPeriods:
        return 'PARTIAL_PERIODS';
      case AttendanceStatus.notMarked:
        return 'NOT_MARKED';
    }
  }

  Color get color {
    switch (this) {
      case AttendanceStatus.present:
        return const Color(0xFF10B981); // Emerald Green
      case AttendanceStatus.absent:
        return const Color(0xFFEF4444); // Red
      case AttendanceStatus.late:
        return const Color(0xFFF59E0B); // Amber / Orange
      case AttendanceStatus.onLeave:
        return const Color(0xFF8B5CF6); // Purple
      case AttendanceStatus.halfDay:
        return const Color(0xFF6366F1); // Indigo
      case AttendanceStatus.workFromHome:
        return const Color(0xFF06B6D4); // Cyan
      case AttendanceStatus.holiday:
        return const Color(0xFF3B82F6); // Blue
      case AttendanceStatus.partialPeriods:
        return const Color(0xFF0EA5E9); // Sky Blue
      case AttendanceStatus.notMarked:
        return const Color(0xFF9CA3AF); // Neutral Gray
    }
  }

  Color get backgroundColor {
    return color.withOpacity(0.12);
  }

  Color get borderColor {
    return color.withOpacity(0.35);
  }

  static AttendanceStatus fromString(String? val) {
    if (val == null) return AttendanceStatus.notMarked;
    final clean = val.toUpperCase().trim();
    switch (clean) {
      case 'PRESENT':
      case 'P':
        return AttendanceStatus.present;
      case 'ABSENT':
      case 'A':
        return AttendanceStatus.absent;
      case 'LATE':
      case 'L':
        return AttendanceStatus.late;
      case 'ON_LEAVE':
      case 'ON LEAVE':
      case 'LEAVE':
      case 'O':
        return AttendanceStatus.onLeave;
      case 'HALF_DAY':
      case 'HALF DAY':
      case 'H':
        return AttendanceStatus.halfDay;
      case 'WORK_FROM_HOME':
      case 'WFH':
      case 'W':
        return AttendanceStatus.workFromHome;
      case 'HOLIDAY':
      case 'HD':
        return AttendanceStatus.holiday;
      case 'PARTIAL_PERIODS':
      case 'PARTIAL':
      case 'PP':
        return AttendanceStatus.partialPeriods;
      default:
        return AttendanceStatus.notMarked;
    }
  }
}

/// Attendance Mode Selector
enum AttendanceMode {
  allDay,
  byPeriod,
  customSelection,
}

extension AttendanceModeExtension on AttendanceMode {
  String get label {
    switch (this) {
      case AttendanceMode.allDay:
        return 'By Schedule (All Day)';
      case AttendanceMode.byPeriod:
        return 'By Period';
      case AttendanceMode.customSelection:
        return 'Custom Selection';
    }
  }

  String get apiKey {
    switch (this) {
      case AttendanceMode.allDay:
        return 'ALL_DAY';
      case AttendanceMode.byPeriod:
        return 'PERIOD';
      case AttendanceMode.customSelection:
        return 'MULTI_SCHEDULE';
    }
  }
}

/// Dashboard Summary Stats
class AttendanceStatsModel {
  final double overallAttendancePct;
  final int totalStudents;
  final int studentsPresent;
  final int studentsAbsent;
  final int lateEntries;
  final int onLeave;
  final int halfDay;
  final int notMarked;
  final Map<String, dynamic> daySummary;

  AttendanceStatsModel({
    this.overallAttendancePct = 0.0,
    this.totalStudents = 0,
    this.studentsPresent = 0,
    this.studentsAbsent = 0,
    this.lateEntries = 0,
    this.onLeave = 0,
    this.halfDay = 0,
    this.notMarked = 0,
    this.daySummary = const {},
  });

  factory AttendanceStatsModel.fromJson(Map<String, dynamic> json) {
    return AttendanceStatsModel(
      overallAttendancePct: (json['overall_attendance_pct'] as num?)?.toDouble() ?? 0.0,
      totalStudents: json['total_students'] as int? ?? 0,
      studentsPresent: json['students_present'] as int? ?? 0,
      studentsAbsent: json['students_absent'] as int? ?? 0,
      lateEntries: json['late_entries'] as int? ?? 0,
      onLeave: json['on_leave'] as int? ?? 0,
      halfDay: json['half_day'] as int? ?? 0,
      notMarked: json['not_marked'] as int? ?? 0,
      daySummary: (json['day_summary'] as Map<String, dynamic>?) ?? {},
    );
  }

  double get overallRate => overallAttendancePct;
  int get presentCount => studentsPresent;
  int get absentCount => studentsAbsent;
  int get lateCount => lateEntries;
  int get onLeaveCount => onLeave;
}

/// Student Roster Row Model
class AttendanceStudentRowModel {
  final String id;
  final String studentId;
  final String fullName;
  final String? avatarUrl;
  final String rollNumber;
  final String admissionNumber;
  final String? classId;
  final String className;
  final String? sectionId;
  final String sectionName;
  final AttendanceStatus status;
  final String remarks;
  final bool isLocked;
  final bool lockedByAllDay;
  final bool isOverridden;
  final String? overrideReason;
  final bool hasApprovedLeave;
  final String? leaveReason;
  final DateTime? lastUpdatedAt;
  final String? updatedByName;
  final List<StudentPeriodAttendanceModel> periods;
  final StudentPeriodsSummaryModel? periodsSummary;

  AttendanceStudentRowModel({
    required this.id,
    required this.studentId,
    required this.fullName,
    this.avatarUrl,
    required this.rollNumber,
    required this.admissionNumber,
    this.classId,
    required this.className,
    this.sectionId,
    required this.sectionName,
    required this.status,
    this.remarks = '',
    this.isLocked = false,
    this.lockedByAllDay = false,
    this.isOverridden = false,
    this.overrideReason,
    this.hasApprovedLeave = false,
    this.leaveReason,
    this.lastUpdatedAt,
    this.updatedByName,
    this.periods = const [],
    this.periodsSummary,
  });

  factory AttendanceStudentRowModel.fromJson(Map<String, dynamic> json) {
    List<StudentPeriodAttendanceModel> parsedPeriods = [];
    if (json['periods'] is List) {
      parsedPeriods = (json['periods'] as List)
          .map((p) => StudentPeriodAttendanceModel.fromJson(p as Map<String, dynamic>))
          .toList();
    }

    StudentPeriodsSummaryModel? summary;
    if (json['periods_summary'] is Map<String, dynamic>) {
      summary = StudentPeriodsSummaryModel.fromJson(json['periods_summary'] as Map<String, dynamic>);
    }

    return AttendanceStudentRowModel(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Student',
      avatarUrl: json['avatar_url']?.toString(),
      rollNumber: json['roll_number']?.toString() ?? '',
      admissionNumber: json['admission_number']?.toString() ?? '',
      classId: json['class_id']?.toString(),
      className: json['class_name']?.toString() ?? '',
      sectionId: json['section_id']?.toString(),
      sectionName: json['section_name']?.toString() ?? '',
      status: AttendanceStatusExtension.fromString(json['status']?.toString()),
      remarks: json['remarks']?.toString() ?? '',
      isLocked: json['is_locked'] == true,
      lockedByAllDay: json['locked_by_all_day'] == true,
      isOverridden: json['is_overridden'] == true,
      overrideReason: json['override_reason']?.toString(),
      hasApprovedLeave: json['has_approved_leave'] == true,
      leaveReason: json['leave_reason']?.toString(),
      lastUpdatedAt: json['last_updated_at'] != null ? DateTime.tryParse(json['last_updated_at'].toString()) : null,
      updatedByName: json['updated_by_name']?.toString(),
      periods: parsedPeriods,
      periodsSummary: summary,
    );
  }

  AttendanceStudentRowModel copyWith({
    AttendanceStatus? status,
    String? remarks,
    bool? isLocked,
    bool? isOverridden,
    String? overrideReason,
    List<StudentPeriodAttendanceModel>? periods,
    StudentPeriodsSummaryModel? periodsSummary,
  }) {
    return AttendanceStudentRowModel(
      id: id,
      studentId: studentId,
      fullName: fullName,
      avatarUrl: avatarUrl,
      rollNumber: rollNumber,
      admissionNumber: admissionNumber,
      classId: classId,
      className: className,
      sectionId: sectionId,
      sectionName: sectionName,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      isLocked: isLocked ?? this.isLocked,
      lockedByAllDay: lockedByAllDay,
      isOverridden: isOverridden ?? this.isOverridden,
      overrideReason: overrideReason ?? this.overrideReason,
      hasApprovedLeave: hasApprovedLeave,
      leaveReason: leaveReason,
      lastUpdatedAt: lastUpdatedAt,
      updatedByName: updatedByName,
      periods: periods ?? this.periods,
      periodsSummary: periodsSummary ?? this.periodsSummary,
    );
  }
}

class StudentPeriodAttendanceModel {
  final int periodNumber;
  final String periodLabel;
  final String? subjectId;
  final String subjectName;
  final String subjectCode;
  final Color subjectColor;
  final String? scheduleId;
  final String timeRange;
  final String teacherName;
  final String? teacherAvatar;
  final AttendanceStatus status;
  final String remarks;
  final bool isLocked;
  final bool lockedByAllDay;
  final bool isOverridden;
  final String? overrideReason;
  final DateTime? lastUpdatedAt;
  final String? updatedByName;

  StudentPeriodAttendanceModel({
    required this.periodNumber,
    required this.periodLabel,
    this.subjectId,
    required this.subjectName,
    this.subjectCode = '',
    this.subjectColor = const Color(0xFF4F46E5),
    this.scheduleId,
    this.timeRange = '',
    this.teacherName = '',
    this.teacherAvatar,
    required this.status,
    this.remarks = '',
    this.isLocked = false,
    this.lockedByAllDay = false,
    this.isOverridden = false,
    this.overrideReason,
    this.lastUpdatedAt,
    this.updatedByName,
  });

  factory StudentPeriodAttendanceModel.fromJson(Map<String, dynamic> json) {
    Color parsedColor = const Color(0xFF4F46E5);
    final hex = json['subject_color']?.toString();
    if (hex != null && hex.isNotEmpty) {
      try {
        final clean = hex.replaceAll('#', '');
        parsedColor = Color(int.parse('FF$clean', radix: 16));
      } catch (_) {}
    }

    return StudentPeriodAttendanceModel(
      periodNumber: int.tryParse(json['period_number']?.toString() ?? '1') ?? 1,
      periodLabel: json['period_label']?.toString() ?? 'P${json['period_number'] ?? 1}',
      subjectId: json['subject_id']?.toString(),
      subjectName: json['subject_name']?.toString() ?? 'Subject',
      subjectCode: json['subject_code']?.toString() ?? '',
      subjectColor: parsedColor,
      scheduleId: json['schedule_id']?.toString(),
      timeRange: json['time_range']?.toString() ?? '',
      teacherName: json['teacher_name']?.toString() ?? 'Teacher',
      teacherAvatar: json['teacher_avatar']?.toString(),
      status: AttendanceStatusExtension.fromString(json['status']?.toString()),
      remarks: json['remarks']?.toString() ?? '',
      isLocked: json['is_locked'] == true,
      lockedByAllDay: json['locked_by_all_day'] == true,
      isOverridden: json['is_overridden'] == true,
      overrideReason: json['override_reason']?.toString(),
      lastUpdatedAt: json['last_updated_at'] != null ? DateTime.tryParse(json['last_updated_at'].toString()) : null,
      updatedByName: json['updated_by_name']?.toString(),
    );
  }

  StudentPeriodAttendanceModel copyWith({
    AttendanceStatus? status,
    String? remarks,
    bool? isLocked,
    bool? isOverridden,
    String? overrideReason,
  }) {
    return StudentPeriodAttendanceModel(
      periodNumber: periodNumber,
      periodLabel: periodLabel,
      subjectId: subjectId,
      subjectName: subjectName,
      subjectCode: subjectCode,
      subjectColor: subjectColor,
      scheduleId: scheduleId,
      timeRange: timeRange,
      teacherName: teacherName,
      teacherAvatar: teacherAvatar,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      isLocked: isLocked ?? this.isLocked,
      lockedByAllDay: lockedByAllDay,
      isOverridden: isOverridden ?? this.isOverridden,
      overrideReason: overrideReason ?? this.overrideReason,
      lastUpdatedAt: lastUpdatedAt,
      updatedByName: updatedByName,
    );
  }
}

class StudentPeriodsSummaryModel {
  final int totalPeriods;
  final int markedPeriods;
  final int notMarkedCount;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int onLeaveCount;
  final int halfDayCount;

  StudentPeriodsSummaryModel({
    this.totalPeriods = 0,
    this.markedPeriods = 0,
    this.notMarkedCount = 0,
    this.presentCount = 0,
    this.absentCount = 0,
    this.lateCount = 0,
    this.onLeaveCount = 0,
    this.halfDayCount = 0,
  });

  factory StudentPeriodsSummaryModel.fromJson(Map<String, dynamic> json) {
    return StudentPeriodsSummaryModel(
      totalPeriods: int.tryParse(json['total_periods']?.toString() ?? '0') ?? 0,
      markedPeriods: int.tryParse(json['marked_periods']?.toString() ?? '0') ?? 0,
      notMarkedCount: int.tryParse(json['not_marked_count']?.toString() ?? '0') ?? 0,
      presentCount: int.tryParse(json['present_count']?.toString() ?? '0') ?? 0,
      absentCount: int.tryParse(json['absent_count']?.toString() ?? '0') ?? 0,
      lateCount: int.tryParse(json['late_count']?.toString() ?? '0') ?? 0,
      onLeaveCount: int.tryParse(json['on_leave_count']?.toString() ?? '0') ?? 0,
      halfDayCount: int.tryParse(json['half_day_count']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Today's Timetable Schedule Item Model
class AttendanceScheduleItemModel {
  final String id;
  final String? scheduleId;
  final String? scheduleTitle;
  final int periodNumber;
  final String periodLabel;
  final String timeRange;
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final Color subjectColor;
  final String teacherName;
  final String? teacherAvatar;
  final bool isLocked;
  final bool isCompleted;
  final String status;
  final int presentCount;
  final int absentCount;
  final int lateCount;

  AttendanceScheduleItemModel({
    required this.id,
    this.scheduleId,
    this.scheduleTitle,
    required this.periodNumber,
    required this.periodLabel,
    required this.timeRange,
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.subjectColor,
    required this.teacherName,
    this.teacherAvatar,
    this.isLocked = false,
    this.isCompleted = false,
    required this.status,
    this.presentCount = 0,
    this.absentCount = 0,
    this.lateCount = 0,
  });

  factory AttendanceScheduleItemModel.fromJson(Map<String, dynamic> json) {
    Color parsedColor = const Color(0xFF4F46E5);
    final hex = json['subject_color']?.toString() ?? '';
    if (hex.startsWith('#') && hex.length >= 7) {
      try {
        final colorInt = int.parse(hex.replaceFirst('#', '0xFF'));
        parsedColor = Color(colorInt);
      } catch (_) {}
    }

    return AttendanceScheduleItemModel(
      id: json['id']?.toString() ?? '',
      scheduleId: json['schedule_id']?.toString(),
      scheduleTitle: json['schedule_title']?.toString(),
      periodNumber: json['period_number'] as int? ?? 1,
      periodLabel: json['period_label']?.toString() ?? 'P1',
      timeRange: json['time_range']?.toString() ?? '08:30 - 09:15',
      subjectId: json['subject_id']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? 'Subject',
      subjectCode: json['subject_code']?.toString() ?? '',
      subjectColor: parsedColor,
      teacherName: json['teacher_name']?.toString() ?? 'Teacher',
      teacherAvatar: json['teacher_avatar']?.toString(),
      isLocked: json['is_locked'] == true,
      isCompleted: json['is_completed'] == true,
      status: json['status']?.toString() ?? 'NOT_STARTED',
      presentCount: json['present_count'] as int? ?? 0,
      absentCount: json['absent_count'] as int? ?? 0,
      lateCount: json['late_count'] as int? ?? 0,
    );
  }
}

/// Staff Attendance Row Model
class StaffAttendanceRowModel {
  final String id;
  final String employeeId;
  final String employeeCode;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final String role;
  final String department;
  final String designation;
  final AttendanceStatus status;
  final String? checkInTime;
  final String? checkOutTime;
  final bool isWfh;
  final String remarks;
  final String? managerName;
  final DateTime? lastUpdatedAt;
  final String? updatedByName;

  StaffAttendanceRowModel({
    required this.id,
    required this.employeeId,
    required this.employeeCode,
    required this.fullName,
    required this.email,
    this.avatarUrl,
    required this.role,
    required this.department,
    required this.designation,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.isWfh = false,
    this.remarks = '',
    this.managerName,
    this.lastUpdatedAt,
    this.updatedByName,
  });

  factory StaffAttendanceRowModel.fromJson(Map<String, dynamic> json) {
    return StaffAttendanceRowModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? json['id']?.toString() ?? '',
      employeeCode: json['employee_code']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Employee',
      email: json['email']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      role: json['role']?.toString() ?? 'staff',
      department: json['department']?.toString() ?? 'General',
      designation: json['designation']?.toString() ?? json['role']?.toString() ?? 'Staff',
      status: AttendanceStatusExtension.fromString(json['status']?.toString()),
      checkInTime: json['check_in_time']?.toString(),
      checkOutTime: json['check_out_time']?.toString(),
      isWfh: json['is_wfh'] == true,
      remarks: json['remarks']?.toString() ?? '',
      managerName: json['manager_name']?.toString(),
      lastUpdatedAt: json['last_updated_at'] != null ? DateTime.tryParse(json['last_updated_at'].toString()) : null,
      updatedByName: json['updated_by_name']?.toString(),
    );
  }

  StaffAttendanceRowModel copyWith({
    AttendanceStatus? status,
    String? checkInTime,
    String? checkOutTime,
    bool? isWfh,
    String? remarks,
  }) {
    return StaffAttendanceRowModel(
      id: id,
      employeeId: employeeId,
      employeeCode: employeeCode,
      fullName: fullName,
      email: email,
      avatarUrl: avatarUrl,
      role: role,
      department: department,
      designation: designation,
      status: status ?? this.status,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      isWfh: isWfh ?? this.isWfh,
      remarks: remarks ?? this.remarks,
      managerName: managerName,
      lastUpdatedAt: lastUpdatedAt,
      updatedByName: updatedByName,
    );
  }
}

/// Leave Request Model
class AttendanceLeaveRequestModel {
  final String id;
  final String applicantId;
  final String applicantName;
  final String? avatarUrl;
  final String applicantRole;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status;
  final String? remarks;
  final String? approvedByName;
  final int daysCount;
  final DateTime createdAt;

  AttendanceLeaveRequestModel({
    required this.id,
    required this.applicantId,
    required this.applicantName,
    this.avatarUrl,
    required this.applicantRole,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    this.remarks,
    this.approvedByName,
    this.daysCount = 1,
    required this.createdAt,
  });

  factory AttendanceLeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return AttendanceLeaveRequestModel(
      id: json['id']?.toString() ?? '',
      applicantId: json['applicant_id']?.toString() ?? '',
      applicantName: json['applicant_name']?.toString() ?? 'Applicant',
      avatarUrl: json['avatar_url']?.toString(),
      applicantRole: json['applicant_role']?.toString() ?? 'student',
      leaveType: json['leave_type']?.toString() ?? 'Medical Leave',
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date']?.toString() ?? '') ?? DateTime.now(),
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      remarks: json['remarks']?.toString(),
      approvedByName: json['approved_by_name']?.toString(),
      daysCount: json['days_count'] as int? ?? 1,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Attendance Insights Analytics Model
class AttendanceInsightsModel {
  final String startDate;
  final String endDate;
  final List<Map<String, dynamic>> dailyTrend;
  final List<Map<String, dynamic>> atRiskStudents;
  final int atRiskCount;
  final List<Map<String, dynamic>> classComparison;

  AttendanceInsightsModel({
    required this.startDate,
    required this.endDate,
    this.dailyTrend = const [],
    this.atRiskStudents = const [],
    this.atRiskCount = 0,
    this.classComparison = const [],
  });

  factory AttendanceInsightsModel.fromJson(Map<String, dynamic> json) {
    return AttendanceInsightsModel(
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      dailyTrend: (json['daily_trend'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      atRiskStudents: (json['at_risk_students'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      atRiskCount: json['at_risk_count'] as int? ?? 0,
      classComparison: (json['class_comparison'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
    );
  }
}

/// Attendance School Settings Model
class AttendanceSettingsModel {
  final String? id;
  final String? schoolId;
  final bool allowLate;
  final int lateCutoffMinutes;
  final bool requireAbsentRemark;
  final bool requireLateRemark;
  final bool autoMarkApprovedLeave;
  final int lockAfterHours;
  final bool allowTeacherOverrideLocked;
  final bool enableNotifications;

  AttendanceSettingsModel({
    this.id,
    this.schoolId,
    this.allowLate = true,
    this.lateCutoffMinutes = 15,
    this.requireAbsentRemark = false,
    this.requireLateRemark = false,
    this.autoMarkApprovedLeave = true,
    this.lockAfterHours = 24,
    this.allowTeacherOverrideLocked = false,
    this.enableNotifications = true,
  });

  factory AttendanceSettingsModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSettingsModel(
      id: json['id']?.toString(),
      schoolId: json['school_id']?.toString(),
      allowLate: json['allow_late'] == true,
      lateCutoffMinutes: json['late_cutoff_minutes'] as int? ?? 15,
      requireAbsentRemark: json['require_absent_remark'] == true,
      requireLateRemark: json['require_late_remark'] == true,
      autoMarkApprovedLeave: json['auto_mark_approved_leave'] == true,
      lockAfterHours: json['lock_after_hours'] as int? ?? 24,
      allowTeacherOverrideLocked: json['allow_teacher_override_locked'] == true,
      enableNotifications: json['enable_notifications'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allow_late': allowLate,
      'late_cutoff_minutes': lateCutoffMinutes,
      'require_absent_remark': requireAbsentRemark,
      'require_late_remark': requireLateRemark,
      'auto_mark_approved_leave': autoMarkApprovedLeave,
      'lock_after_hours': lockAfterHours,
      'allow_teacher_override_locked': allowTeacherOverrideLocked,
      'enable_notifications': enableNotifications,
    };
  }

  AttendanceSettingsModel copyWith({
    bool? allowLate,
    int? lateCutoffMinutes,
    bool? requireAbsentRemark,
    bool? requireLateRemark,
    bool? autoMarkApprovedLeave,
    int? lockAfterHours,
    bool? allowTeacherOverrideLocked,
    bool? enableNotifications,
  }) {
    return AttendanceSettingsModel(
      id: id,
      schoolId: schoolId,
      allowLate: allowLate ?? this.allowLate,
      lateCutoffMinutes: lateCutoffMinutes ?? this.lateCutoffMinutes,
      requireAbsentRemark: requireAbsentRemark ?? this.requireAbsentRemark,
      requireLateRemark: requireLateRemark ?? this.requireLateRemark,
      autoMarkApprovedLeave: autoMarkApprovedLeave ?? this.autoMarkApprovedLeave,
      lockAfterHours: lockAfterHours ?? this.lockAfterHours,
      allowTeacherOverrideLocked: allowTeacherOverrideLocked ?? this.allowTeacherOverrideLocked,
      enableNotifications: enableNotifications ?? this.enableNotifications,
    );
  }
}

/// Audit Log Model
class AttendanceAuditLogModel {
  final String id;
  final String recordType;
  final String? recordId;
  final String action;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final String? reason;
  final DateTime createdAt;
  final String? userName;
  final String? userAvatar;
  final String? userRole;

  AttendanceAuditLogModel({
    required this.id,
    required this.recordType,
    this.recordId,
    required this.action,
    this.oldValue,
    this.newValue,
    this.reason,
    required this.createdAt,
    this.userName,
    this.userAvatar,
    this.userRole,
  });

  factory AttendanceAuditLogModel.fromJson(Map<String, dynamic> json) {
    return AttendanceAuditLogModel(
      id: json['id']?.toString() ?? '',
      recordType: json['record_type']?.toString() ?? 'DAILY',
      recordId: json['record_id']?.toString(),
      action: json['action']?.toString() ?? 'UPDATE',
      oldValue: json['old_value'] as Map<String, dynamic>?,
      newValue: json['new_value'] as Map<String, dynamic>?,
      reason: json['reason']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      userName: json['user_name']?.toString() ?? 'System',
      userAvatar: json['user_avatar']?.toString(),
      userRole: json['user_role']?.toString(),
    );
  }
}
