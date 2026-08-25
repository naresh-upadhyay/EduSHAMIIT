import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final String? sectionId;
  final String? sectionName;
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
    this.sectionId,
    this.sectionName,
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
      sectionId: json['section_id']?.toString(),
      sectionName: json['section_name']?.toString(),
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
    String? sectionId,
    String? sectionName,
  }) {
    return StudentPeriodAttendanceModel(
      periodNumber: periodNumber,
      periodLabel: periodLabel,
      subjectId: subjectId,
      subjectName: subjectName,
      subjectCode: subjectCode,
      subjectColor: subjectColor,
      scheduleId: scheduleId,
      sectionId: sectionId ?? this.sectionId,
      sectionName: sectionName ?? this.sectionName,
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
  final int? sectionPeriodNumber;
  final String? sectionPeriodLabel;
  final String? sectionId;
  final String? sectionName;
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
    this.sectionPeriodNumber,
    this.sectionPeriodLabel,
    this.sectionId,
    this.sectionName,
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
      sectionPeriodNumber: json['section_period_number'] as int?,
      sectionPeriodLabel: json['section_period_label']?.toString(),
      sectionId: json['section_id']?.toString(),
      sectionName: json['section_name']?.toString(),
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

/// Enhanced Leave Request Model
class AttendanceLeaveRequestModel {
  final String id;
  final String requestCode;
  final String applicantId;
  final String applicantName;
  final String? avatarUrl;
  final String employeeCode;
  final String applicantRole;
  final String department;
  final String designation;
  final String leaveType;
  final Color leaveTypeColor;
  final DateTime startDate;
  final DateTime endDate;
  final double daysCount;
  final String halfDayType;
  final String reason;
  final String status;
  final String? remarks;
  final String? rejectionReason;
  final String? attachmentUrl;
  final String? contactNumber;
  final DateTime appliedAt;
  final String? approvedByName;
  final String? managerName;

  AttendanceLeaveRequestModel({
    required this.id,
    this.requestCode = '',
    required this.applicantId,
    required this.applicantName,
    this.avatarUrl,
    this.employeeCode = '',
    required this.applicantRole,
    this.department = 'General',
    this.designation = '',
    required this.leaveType,
    this.leaveTypeColor = const Color(0xFF4F46E5),
    required this.startDate,
    required this.endDate,
    this.daysCount = 1.0,
    this.halfDayType = 'FULL_DAY',
    required this.reason,
    required this.status,
    this.remarks,
    this.rejectionReason,
    this.attachmentUrl,
    this.contactNumber,
    required this.appliedAt,
    this.approvedByName,
    this.managerName,
  });

  DateTime get createdAt => appliedAt;

  factory AttendanceLeaveRequestModel.fromJson(Map<String, dynamic> json) {
    Color parsedColor = const Color(0xFF4F46E5);
    final hex = json['color_hex']?.toString() ?? json['leave_type_color']?.toString() ?? '';
    if (hex.startsWith('#') && hex.length >= 7) {
      try {
        final colorInt = int.parse(hex.replaceFirst('#', '0xFF'));
        parsedColor = Color(colorInt);
      } catch (_) {}
    }

    final rawDays = json['billable_days'] ?? json['duration_days'] ?? json['days_count'] ?? json['days'];
    final parsedDays = (rawDays is num) ? rawDays.toDouble() : (double.tryParse(rawDays?.toString() ?? '') ?? 1.0);

    return AttendanceLeaveRequestModel(
      id: json['id']?.toString() ?? '',
      requestCode: json['request_code']?.toString() ?? '',
      applicantId: json['applicant_id']?.toString() ?? '',
      applicantName: json['applicant_name']?.toString() ?? 'Applicant',
      avatarUrl: json['avatar_url']?.toString(),
      employeeCode: json['employee_code']?.toString() ?? '',
      applicantRole: json['applicant_role']?.toString() ?? 'teacher',
      department: json['department']?.toString() ?? 'General',
      designation: json['designation']?.toString() ?? '',
      leaveType: json['leave_type']?.toString() ?? 'Casual Leave',
      leaveTypeColor: parsedColor,
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date']?.toString() ?? '') ?? DateTime.now(),
      daysCount: parsedDays,
      halfDayType: json['half_day_type']?.toString() ?? 'FULL_DAY',
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      remarks: json['remarks']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      attachmentUrl: json['attachment_url']?.toString(),
      contactNumber: json['contact_number']?.toString(),
      appliedAt: DateTime.tryParse(json['applied_at']?.toString() ?? json['created_at']?.toString() ?? '') ?? DateTime.now(),
      approvedByName: json['approved_by_name']?.toString(),
      managerName: json['manager_name']?.toString(),
    );
  }
}

/// Leave Dashboard KPI Summary Model
class LeaveDashboardKpiModel {
  final int totalRequests;
  final int approvedLeaves;
  final int pendingRequests;
  final int rejectedLeaves;
  final int cancelledLeaves;
  final double approvedPercentage;
  final double pendingPercentage;
  final double rejectedPercentage;
  final double cancelledPercentage;

  LeaveDashboardKpiModel({
    this.totalRequests = 0,
    this.approvedLeaves = 0,
    this.pendingRequests = 0,
    this.rejectedLeaves = 0,
    this.cancelledLeaves = 0,
    this.approvedPercentage = 0.0,
    this.pendingPercentage = 0.0,
    this.rejectedPercentage = 0.0,
    this.cancelledPercentage = 0.0,
  });

  factory LeaveDashboardKpiModel.fromJson(Map<String, dynamic> json) {
    return LeaveDashboardKpiModel(
      totalRequests: json['total_requests'] as int? ?? 0,
      approvedLeaves: json['approved_leaves'] as int? ?? 0,
      pendingRequests: json['pending_requests'] as int? ?? 0,
      rejectedLeaves: json['rejected_leaves'] as int? ?? 0,
      cancelledLeaves: json['cancelled_leaves'] as int? ?? 0,
      approvedPercentage: (json['approved_percentage'] as num?)?.toDouble() ?? 0.0,
      pendingPercentage: (json['pending_percentage'] as num?)?.toDouble() ?? 0.0,
      rejectedPercentage: (json['rejected_percentage'] as num?)?.toDouble() ?? 0.0,
      cancelledPercentage: (json['cancelled_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Leave Balance Summary Item Model (Right Sidebar)
class LeaveBalanceSummaryItemModel {
  final String leaveTypeId;
  final String leaveTypeName;
  final String leaveTypeCode;
  final Color color;
  final double allocatedDays;
  final double usedDays;
  final double pendingDays;
  final double availableDays;

  LeaveBalanceSummaryItemModel({
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.leaveTypeCode,
    this.color = const Color(0xFF4F46E5),
    this.allocatedDays = 12.0,
    this.usedDays = 0.0,
    this.pendingDays = 0.0,
    this.availableDays = 12.0,
  });

  factory LeaveBalanceSummaryItemModel.fromJson(Map<String, dynamic> json) {
    Color parsedColor = const Color(0xFF4F46E5);
    final hex = json['color_hex']?.toString() ?? '';
    if (hex.startsWith('#') && hex.length >= 7) {
      try {
        final colorInt = int.parse(hex.replaceFirst('#', '0xFF'));
        parsedColor = Color(colorInt);
      } catch (_) {}
    }

    return LeaveBalanceSummaryItemModel(
      leaveTypeId: json['leave_type_id']?.toString() ?? '',
      leaveTypeName: json['leave_type_name']?.toString() ?? 'Leave',
      leaveTypeCode: json['leave_type_code']?.toString() ?? 'LV',
      color: parsedColor,
      allocatedDays: (json['allocated_days'] as num?)?.toDouble() ?? 12.0,
      usedDays: (json['used_days'] as num?)?.toDouble() ?? 0.0,
      pendingDays: (json['pending_days'] as num?)?.toDouble() ?? 0.0,
      availableDays: (json['available_days'] as num?)?.toDouble() ?? 12.0,
    );
  }
}

/// Upcoming Leave Item Model (Right Sidebar)
class UpcomingLeaveItemModel {
  final String id;
  final String employeeName;
  final String? avatarUrl;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String dateRangeFormatted;

  UpcomingLeaveItemModel({
    required this.id,
    required this.employeeName,
    this.avatarUrl,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.dateRangeFormatted,
  });

  factory UpcomingLeaveItemModel.fromJson(Map<String, dynamic> json) {
    final sDate = DateTime.tryParse(json['start_date']?.toString() ?? '') ?? DateTime.now();
    final eDate = DateTime.tryParse(json['end_date']?.toString() ?? '') ?? sDate;
    String formattedDate = json['date_range_formatted']?.toString() ?? '';
    if (formattedDate.isEmpty) {
      if (sDate.year == eDate.year && sDate.month == eDate.month && sDate.day == eDate.day) {
        formattedDate = DateFormat('dd MMM').format(sDate);
      } else if (sDate.month == eDate.month && sDate.year == eDate.year) {
        formattedDate = '${DateFormat('dd').format(sDate)} - ${DateFormat('dd MMM').format(eDate)}';
      } else {
        formattedDate = '${DateFormat('dd MMM').format(sDate)} - ${DateFormat('dd MMM').format(eDate)}';
      }
    }

    final empName = json['employee_name']?.toString() ?? json['applicant_name']?.toString() ?? json['full_name']?.toString() ?? json['name']?.toString() ?? 'Employee';

    return UpcomingLeaveItemModel(
      id: json['id']?.toString() ?? '',
      employeeName: empName,
      avatarUrl: json['avatar_url']?.toString(),
      leaveType: json['leave_type']?.toString() ?? 'Leave',
      startDate: sDate,
      endDate: eDate,
      dateRangeFormatted: formattedDate,
    );
  }
}

/// Complete Leave & Permissions Dashboard Model
class LeaveDashboardModel {
  final LeaveDashboardKpiModel kpi;
  final List<AttendanceLeaveRequestModel> requests;
  final List<LeaveBalanceSummaryItemModel> balanceSummary;
  final List<UpcomingLeaveItemModel> upcomingLeaves;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  LeaveDashboardModel({
    required this.kpi,
    this.requests = const [],
    this.balanceSummary = const [],
    this.upcomingLeaves = const [],
    this.page = 1,
    this.pageSize = 10,
    this.totalCount = 0,
    this.totalPages = 1,
  });

  factory LeaveDashboardModel.fromJson(Map<String, dynamic> json) {
    final kpiData = json['kpi'] as Map<String, dynamic>? ?? {};
    final reqList = json['requests'] as List? ?? [];
    final balList = json['balance_summary'] as List? ?? [];
    final upList = json['upcoming_leaves'] as List? ?? [];
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

    final parsedPage = (json['page'] ?? pagination['page']) as int? ?? 1;
    final parsedPageSize = (json['page_size'] ?? pagination['page_size']) as int? ?? 10;
    final parsedTotalCount = (json['total_count'] ?? pagination['total_count'] ?? kpiData['total_requests']) as int? ?? reqList.length;
    final parsedTotalPages = (json['total_pages'] ?? pagination['total_pages']) as int? ?? 1;

    return LeaveDashboardModel(
      kpi: LeaveDashboardKpiModel.fromJson(kpiData),
      requests: reqList.map((e) => AttendanceLeaveRequestModel.fromJson(e as Map<String, dynamic>)).toList(),
      balanceSummary: balList.map((e) => LeaveBalanceSummaryItemModel.fromJson(e as Map<String, dynamic>)).toList(),
      upcomingLeaves: upList.map((e) => UpcomingLeaveItemModel.fromJson(e as Map<String, dynamic>)).toList(),
      page: parsedPage,
      pageSize: parsedPageSize,
      totalCount: parsedTotalCount,
      totalPages: parsedTotalPages,
    );
  }
}

/// Role Model from app_roles
class AppRoleItemModel {
  final String id;
  final String name;
  final String code;
  final String displayName;
  final String description;

  const AppRoleItemModel({
    required this.id,
    required this.name,
    required this.code,
    required this.displayName,
    this.description = '',
  });

  factory AppRoleItemModel.fromJson(Map<String, dynamic> json) {
    return AppRoleItemModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}

/// Configurable Leave Type & Policy Model
class LeaveTypeModel {
  final String id;
  final String name;
  final String code;
  final String category;
  final double annualEntitlement;
  final bool monthlyAccrual;
  final bool carryForwardAllowed;
  final double maxCarryForward;
  final bool encashmentAllowed;
  final bool docRequired;
  final double docRequiredAfterDays;
  final bool allowHalfDay;
  final List<String> applicableRoles;
  final Color color;
  final bool isActive;

  LeaveTypeModel({
    required this.id,
    required this.name,
    required this.code,
    this.category = 'PAID',
    this.annualEntitlement = 12.0,
    this.monthlyAccrual = false,
    this.carryForwardAllowed = true,
    this.maxCarryForward = 5.0,
    this.encashmentAllowed = false,
    this.docRequired = false,
    this.docRequiredAfterDays = 2.0,
    this.allowHalfDay = true,
    this.applicableRoles = const [],
    this.color = const Color(0xFF4F46E5),
    this.isActive = true,
  });

  factory LeaveTypeModel.fromJson(Map<String, dynamic> json) {
    Color parsedColor = const Color(0xFF4F46E5);
    final hex = json['color_hex']?.toString() ?? '';
    if (hex.startsWith('#') && hex.length >= 7) {
      try {
        final colorInt = int.parse(hex.replaceFirst('#', '0xFF'));
        parsedColor = Color(colorInt);
      } catch (_) {}
    }

    final rolesRaw = json['applicable_roles'];
    List<String> parsedRoles = [];
    if (rolesRaw is List) {
      parsedRoles = rolesRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } else if (rolesRaw is String && rolesRaw.isNotEmpty) {
      parsedRoles = rolesRaw.replaceAll('{', '').replaceAll('}', '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    return LeaveTypeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      category: json['category']?.toString() ?? 'PAID',
      annualEntitlement: (json['annual_entitlement'] as num?)?.toDouble() ?? 12.0,
      monthlyAccrual: json['monthly_accrual'] == true,
      carryForwardAllowed: json['carry_forward_allowed'] == true,
      maxCarryForward: (json['max_carry_forward'] as num?)?.toDouble() ?? 5.0,
      encashmentAllowed: json['encashment_allowed'] == true,
      docRequired: json['doc_required'] == true,
      docRequiredAfterDays: (json['doc_required_after_days'] as num?)?.toDouble() ?? 2.0,
      allowHalfDay: json['allow_half_day'] != false,
      applicableRoles: parsedRoles,
      color: parsedColor,
      isActive: json['is_active'] != false,
    );
  }
}

/// Employee Leave Balance Detailed Row Model
class LeaveBalanceRowModel {
  final String id;
  final String userId;
  final String fullName;
  final String role;
  final String employeeCode;
  final String department;
  final String designation;
  final String leaveTypeId;
  final String leaveTypeName;
  final String leaveTypeCode;
  final Color color;
  final double allocatedDays;
  final double usedDays;
  final double pendingDays;
  final double carriedForwardDays;
  final double availableDays;
  final String academicYear;

  LeaveBalanceRowModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.role,
    this.employeeCode = '',
    this.department = 'General',
    this.designation = '',
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.leaveTypeCode,
    this.color = const Color(0xFF4F46E5),
    this.allocatedDays = 12.0,
    this.usedDays = 0.0,
    this.pendingDays = 0.0,
    this.carriedForwardDays = 0.0,
    this.availableDays = 12.0,
    this.academicYear = '2026-2027',
  });

  factory LeaveBalanceRowModel.fromJson(Map<String, dynamic> json) {
    Color parsedColor = const Color(0xFF4F46E5);
    final hex = json['color_hex']?.toString() ?? '';
    if (hex.startsWith('#') && hex.length >= 7) {
      try {
        final colorInt = int.parse(hex.replaceFirst('#', '0xFF'));
        parsedColor = Color(colorInt);
      } catch (_) {}
    }

    return LeaveBalanceRowModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      employeeCode: json['employee_code']?.toString() ?? '',
      department: json['department']?.toString() ?? 'General',
      designation: json['designation']?.toString() ?? '',
      leaveTypeId: json['leave_type_id']?.toString() ?? '',
      leaveTypeName: json['leave_type_name']?.toString() ?? '',
      leaveTypeCode: json['leave_type_code']?.toString() ?? '',
      color: parsedColor,
      allocatedDays: (json['allocated_days'] as num?)?.toDouble() ?? 12.0,
      usedDays: (json['used_days'] as num?)?.toDouble() ?? 0.0,
      pendingDays: (json['pending_days'] as num?)?.toDouble() ?? 0.0,
      carriedForwardDays: (json['carried_forward_days'] as num?)?.toDouble() ?? 0.0,
      availableDays: (json['available_days'] as num?)?.toDouble() ?? 12.0,
      academicYear: json['academic_year']?.toString() ?? '2026-2027',
    );
  }
}

/// Grouped Employee Leave Balances Model
class EmployeeLeaveBalanceModel {
  final String userId;
  final String fullName;
  final String role;
  final String? avatarUrl;
  final String employeeCode;
  final String department;
  final String designation;
  final List<LeaveBalanceRowModel> balances;
  final double totalAllocated;
  final double totalUsed;
  final double totalAvailable;

  EmployeeLeaveBalanceModel({
    required this.userId,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    required this.employeeCode,
    this.department = 'General',
    this.designation = '',
    this.balances = const [],
    this.totalAllocated = 0.0,
    this.totalUsed = 0.0,
    this.totalAvailable = 0.0,
  });

  factory EmployeeLeaveBalanceModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['balances'] as List? ?? [];
    final bals = rawList.map((b) {
      final bMap = Map<String, dynamic>.from(b as Map<String, dynamic>);
      bMap['user_id'] = json['user_id'];
      bMap['full_name'] = json['full_name'];
      bMap['role'] = json['role'];
      bMap['avatar_url'] = json['avatar_url'];
      bMap['employee_code'] = json['employee_code'];
      bMap['department'] = json['department'];
      bMap['designation'] = json['designation'];
      return LeaveBalanceRowModel.fromJson(bMap);
    }).toList();

    return EmployeeLeaveBalanceModel(
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      employeeCode: json['employee_code']?.toString() ?? '',
      department: json['department']?.toString() ?? 'General',
      designation: json['designation']?.toString() ?? '',
      balances: bals,
      totalAllocated: (json['total_allocated'] as num?)?.toDouble() ?? 0.0,
      totalUsed: (json['total_used'] as num?)?.toDouble() ?? 0.0,
      totalAvailable: (json['total_available'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Short Permission / Hourly Leave Request Model
class PermissionRequestModel {
  final String id;
  final String requestCode;
  final String applicantId;
  final String applicantName;
  final String? avatarUrl;
  final String employeeCode;
  final String department;
  final String applicantRole;
  final String permissionType;
  final DateTime permissionDate;
  final String startTime;
  final String endTime;
  final double durationHours;
  final String reason;
  final String status;
  final String? rejectionReason;
  final String? remarks;
  final DateTime createdAt;
  final String? approvedByName;

  PermissionRequestModel({
    required this.id,
    this.requestCode = '',
    required this.applicantId,
    required this.applicantName,
    this.avatarUrl,
    this.employeeCode = '',
    this.department = 'General',
    this.applicantRole = 'teacher',
    required this.permissionType,
    required this.permissionDate,
    required this.startTime,
    required this.endTime,
    this.durationHours = 1.0,
    required this.reason,
    required this.status,
    this.rejectionReason,
    this.remarks,
    required this.createdAt,
    this.approvedByName,
  });

  factory PermissionRequestModel.fromJson(Map<String, dynamic> json) {
    return PermissionRequestModel(
      id: json['id']?.toString() ?? '',
      requestCode: json['request_code']?.toString() ?? '',
      applicantId: json['applicant_id']?.toString() ?? '',
      applicantName: json['applicant_name']?.toString() ?? 'Applicant',
      avatarUrl: json['avatar_url']?.toString(),
      employeeCode: json['employee_code']?.toString() ?? '',
      department: json['department']?.toString() ?? 'General',
      applicantRole: json['applicant_role']?.toString() ?? 'teacher',
      permissionType: json['permission_type']?.toString() ?? 'SHORT_PERMISSION',
      permissionDate: DateTime.tryParse(json['permission_date']?.toString() ?? '') ?? DateTime.now(),
      startTime: json['start_time']?.toString() ?? '09:00',
      endTime: json['end_time']?.toString() ?? '10:00',
      durationHours: (json['duration_hours'] as num?)?.toDouble() ?? 1.0,
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      rejectionReason: json['rejection_reason']?.toString(),
      remarks: json['remarks']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      approvedByName: json['approved_by_name']?.toString(),
    );
  }
}

/// Attendance Insights Analytics Model
class AttendanceInsightsModel {
  final String startDate;
  final String endDate;
  final String viewBy;
  final String? role;
  final String? department;
  final String granularity;
  final Map<String, dynamic> kpis;
  final List<Map<String, dynamic>> trend;
  final Map<String, dynamic> distribution;
  final List<Map<String, dynamic>> topClasses;
  final List<Map<String, dynamic>> topAbsentees;
  final List<Map<String, dynamic>> dayOfWeek;
  final List<Map<String, dynamic>> departmentStats;
  final List<Map<String, dynamic>> availableDepartments;
  final List<Map<String, dynamic>> availableRoles;
  final List<Map<String, dynamic>> insightsAlerts;

  AttendanceInsightsModel({
    required this.startDate,
    required this.endDate,
    this.viewBy = 'OVERALL',
    this.role,
    this.department,
    this.granularity = 'monthly',
    this.kpis = const {},
    this.trend = const [],
    this.distribution = const {},
    this.topClasses = const [],
    this.topAbsentees = const [],
    this.dayOfWeek = const [],
    this.departmentStats = const [],
    this.availableDepartments = const [],
    this.availableRoles = const [],
    this.insightsAlerts = const [],
  });

  // Backward compatibility getters
  List<Map<String, dynamic>> get dailyTrend => trend;
  List<Map<String, dynamic>> get atRiskStudents => topAbsentees;
  int get atRiskCount => topAbsentees.length;
  List<Map<String, dynamic>> get classComparison => topClasses;

  factory AttendanceInsightsModel.fromJson(Map<String, dynamic> json) {
    return AttendanceInsightsModel(
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      viewBy: json['view_by']?.toString() ?? 'OVERALL',
      role: json['role']?.toString(),
      department: json['department']?.toString(),
      granularity: json['granularity']?.toString() ?? 'monthly',
      kpis: (json['kpis'] as Map<String, dynamic>?) ?? {},
      trend: (json['trend'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          (json['daily_trend'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [],
      distribution: (json['distribution'] as Map<String, dynamic>?) ?? {},
      topClasses: (json['top_classes'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          (json['class_comparison'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [],
      topAbsentees: (json['top_absentees'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          (json['at_risk_students'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [],
      dayOfWeek: (json['day_of_week'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      departmentStats: (json['department_stats'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      availableDepartments: (json['available_departments'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      availableRoles: (json['available_roles'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      insightsAlerts: (json['insights_alerts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
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

/// Public & Institutional Holiday Model for Calendar & Leave Exclusions
class HolidayItemModel {
  final String id;
  final String title;
  final String? description;
  final String scheduleType;
  final String category;
  final DateTime startDate;
  final DateTime endDate;
  final Color color;
  final String calendarName;

  HolidayItemModel({
    required this.id,
    required this.title,
    this.description,
    this.scheduleType = 'holiday',
    this.category = 'Holidays',
    required this.startDate,
    required this.endDate,
    this.color = const Color(0xFFEF4444),
    this.calendarName = 'Public Holidays',
  });

  factory HolidayItemModel.fromJson(Map<String, dynamic> json) {
    Color parsedColor = const Color(0xFFEF4444);
    final hex = json['color']?.toString() ?? '';
    if (hex.startsWith('#') && hex.length >= 7) {
      try {
        final colorInt = int.parse(hex.replaceFirst('#', '0xFF'));
        parsedColor = Color(colorInt);
      } catch (_) {}
    }

    return HolidayItemModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Public Holiday',
      description: json['description']?.toString(),
      scheduleType: json['schedule_type']?.toString() ?? 'holiday',
      category: json['category']?.toString() ?? 'Holidays',
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date']?.toString() ?? '') ?? DateTime.now(),
      color: parsedColor,
      calendarName: json['calendar_name']?.toString() ?? 'Public Holidays',
    );
  }
}
