import 'package:flutter/foundation.dart';

/// Teacher profile data model
@immutable
class TeacherProfile {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String? phone;
  final String? profileImageUrl;
  final String subject;
  final String? specialization;
  final List<String> classes;
  final String qualification;
  final int experienceYears;
  final DateTime? joiningDate;
  final int xpPoints;
  final int streak;
  final String? bio;
  final DateTime createdAt;
  final DateTime updatedAt;

  TeacherProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    this.phone,
    this.profileImageUrl,
    required this.subject,
    this.specialization,
    required this.classes,
    required this.qualification,
    required this.experienceYears,
    this.joiningDate,
    required this.xpPoints,
    required this.streak,
    this.bio,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeacherProfile.fromJson(Map<String, dynamic> json) {
    return TeacherProfile(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      subject: json['subject'] as String? ?? '',
      specialization: json['specialization'] as String?,
      classes: (json['classes'] as List<dynamic>?)?.cast<String>() ?? [],
      qualification: json['qualification'] as String? ?? '',
      experienceYears: json['experience_years'] as int? ?? 0,
      joiningDate: json['joining_date'] != null 
          ? DateTime.parse(json['joining_date'] as String) 
          : null,
      xpPoints: json['xp_points'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      bio: json['bio'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'profile_image_url': profileImageUrl,
      'subject': subject,
      'specialization': specialization,
      'classes': classes,
      'qualification': qualification,
      'experience_years': experienceYears,
      'joining_date': joiningDate?.toIso8601String(),
      'xp_points': xpPoints,
      'streak': streak,
      'bio': bio,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  TeacherProfile copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? email,
    String? phone,
    String? profileImageUrl,
    String? subject,
    String? specialization,
    List<String>? classes,
    String? qualification,
    int? experienceYears,
    DateTime? joiningDate,
    int? xpPoints,
    int? streak,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeacherProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      subject: subject ?? this.subject,
      specialization: specialization ?? this.specialization,
      classes: classes ?? this.classes,
      qualification: qualification ?? this.qualification,
      experienceYears: experienceYears ?? this.experienceYears,
      joiningDate: joiningDate ?? this.joiningDate,
      xpPoints: xpPoints ?? this.xpPoints,
      streak: streak ?? this.streak,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Teacher dashboard data model
@immutable
class TeacherDashboard {
  final TeacherProfile user;
  final TeacherStats stats;
  final List<TeacherScheduleItem> todaySchedule;
  final List<TeacherTask> pendingTasks;
  final List<QuickAccessItem> quickAccess;

  TeacherDashboard({
    required this.user,
    required this.stats,
    required this.todaySchedule,
    required this.pendingTasks,
    required this.quickAccess,
  });

  factory TeacherDashboard.fromJson(Map<String, dynamic> json) {
    return TeacherDashboard(
      user: TeacherProfile.fromJson(json['user'] as Map<String, dynamic>),
      stats: TeacherStats.fromJson(json['stats'] as Map<String, dynamic>),
      todaySchedule: (json['today_schedule'] as List<dynamic>?)
              ?.map((item) => TeacherScheduleItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      pendingTasks: (json['pending_tasks'] as List<dynamic>?)
              ?.map((item) => TeacherTask.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      quickAccess: (json['quick_access'] as List<dynamic>?)
              ?.map((item) => QuickAccessItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'stats': stats.toJson(),
      'today_schedule': todaySchedule.map((item) => item.toJson()).toList(),
      'pending_tasks': pendingTasks.map((task) => task.toJson()).toList(),
      'quick_access': quickAccess.map((item) => item.toJson()).toList(),
    };
  }
}

/// Teacher statistics model
@immutable
class TeacherStats {
  final double attendancePct;
  final double avgScore;
  final int classesCount;
  final int studentsCount;
  final int? totalHomework;
  final int? pendingGrading;
  final double? avgCompletionRate;

  TeacherStats({
    required this.attendancePct,
    required this.avgScore,
    required this.classesCount,
    required this.studentsCount,
    this.totalHomework,
    this.pendingGrading,
    this.avgCompletionRate,
  });

  factory TeacherStats.fromJson(Map<String, dynamic> json) {
    return TeacherStats(
      attendancePct: (json['attendance_pct'] as num?)?.toDouble() ?? 0.0,
      avgScore: (json['avg_score'] as num?)?.toDouble() ?? 0.0,
      classesCount: json['classes_count'] as int? ?? 0,
      studentsCount: json['students_count'] as int? ?? 0,
      totalHomework: json['total_homework'] as int?,
      pendingGrading: json['pending_grading'] as int?,
      avgCompletionRate: (json['avg_completion_rate'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attendance_pct': attendancePct,
      'avg_score': avgScore,
      'classes_count': classesCount,
      'students_count': studentsCount,
      'total_homework': totalHomework,
      'pending_grading': pendingGrading,
      'avg_completion_rate': avgCompletionRate,
    };
  }
}

/// Teacher schedule item model
@immutable
class TeacherScheduleItem {
  final String subject;
  final String icon;
  final String class_;
  final String startTime;
  final String endTime;
  final String room;
  final bool isNow;

  TeacherScheduleItem({
    required this.subject,
    required this.icon,
    required this.class_,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.isNow,
  });

  factory TeacherScheduleItem.fromJson(Map<String, dynamic> json) {
    return TeacherScheduleItem(
      subject: json['subject'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      class_: json['class'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      room: json['room'] as String? ?? '',
      isNow: json['is_now'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject': subject,
      'icon': icon,
      'class': class_,
      'start_time': startTime,
      'end_time': endTime,
      'room': room,
      'is_now': isNow,
    };
  }
}

/// Teacher task model
@immutable
class TeacherTask {
  final String id;
  final String title;
  final String class_;
  final String icon;
  final String dueDate;
  final String status;
  final int count;

  TeacherTask({
    required this.id,
    required this.title,
    required this.class_,
    required this.icon,
    required this.dueDate,
    required this.status,
    required this.count,
  });

  factory TeacherTask.fromJson(Map<String, dynamic> json) {
    return TeacherTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      class_: json['class'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      dueDate: json['due_date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'class': class_,
      'icon': icon,
      'due_date': dueDate,
      'status': status,
      'count': count,
    };
  }
}

/// Quick access item model
@immutable
class QuickAccessItem {
  final String title;
  final String icon;
  final String route;

  QuickAccessItem({
    required this.title,
    required this.icon,
    required this.route,
  });

  factory QuickAccessItem.fromJson(Map<String, dynamic> json) {
    return QuickAccessItem(
      title: json['title'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      route: json['route'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'icon': icon,
      'route': route,
    };
  }
}

/// Student directory entry model
@immutable
class StudentDirectoryEntry {
  final String id;
  final String name;
  final String rollNo;
  final String class_;
  final String? section;
  final String? email;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? parentName;
  final String? parentPhone;
  final double? attendancePct;
  final double? avgMarks;
  final String? profileImageUrl;

  StudentDirectoryEntry({
    required this.id,
    required this.name,
    required this.rollNo,
    required this.class_,
    this.section,
    this.email,
    this.phone,
    this.dateOfBirth,
    this.parentName,
    this.parentPhone,
    this.attendancePct,
    this.avgMarks,
    this.profileImageUrl,
  });

  factory StudentDirectoryEntry.fromJson(Map<String, dynamic> json) {
    return StudentDirectoryEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rollNo: json['roll_no'] as String? ?? '',
      class_: json['class'] as String? ?? '',
      section: json['section'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      dateOfBirth: json['date_of_birth'] != null 
          ? DateTime.parse(json['date_of_birth'] as String) 
          : null,
      parentName: json['parent_name'] as String?,
      parentPhone: json['parent_phone'] as String?,
      attendancePct: (json['attendance_pct'] as num?)?.toDouble(),
      avgMarks: (json['avg_marks'] as num?)?.toDouble(),
      profileImageUrl: json['profile_image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'roll_no': rollNo,
      'class': class_,
      'section': section,
      'email': email,
      'phone': phone,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'parent_name': parentName,
      'parent_phone': parentPhone,
      'attendance_pct': attendancePct,
      'avg_marks': avgMarks,
      'profile_image_url': profileImageUrl,
    };
  }
}

/// Attendance record model for teachers
@immutable
class TeacherAttendanceRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String rollNo;
  final String class_;
  final DateTime date;
  final String status; // present, absent, late, excused
  final String? period;
  final String? markedBy;
  final DateTime? createdAt;

  TeacherAttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    required this.class_,
    required this.date,
    required this.status,
    this.period,
    this.markedBy,
    this.createdAt,
  });

  factory TeacherAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return TeacherAttendanceRecord(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      rollNo: json['roll_no'] as String? ?? '',
      class_: json['class'] as String? ?? '',
      date: json['date'] != null 
          ? DateTime.parse(json['date'] as String) 
          : DateTime.now(),
      status: json['status'] as String? ?? 'absent',
      period: json['period'] as String?,
      markedBy: json['marked_by'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'roll_no': rollNo,
      'class': class_,
      'date': date.toIso8601String(),
      'status': status,
      'period': period,
      'marked_by': markedBy,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

/// Homework assignment model for teachers
@immutable
class TeacherHomeworkAssignment {
  final String id;
  final String title;
  final String description;
  final String class_;
  final String subject;
  final DateTime dueDate;
  final String status; // active, pending, completed, archived
  final int submittedCount;
  final int totalCount;
  final String? attachmentUrl;
  final int? maxMarks;
  final String? instructions;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  TeacherHomeworkAssignment({
    required this.id,
    required this.title,
    required this.description,
    required this.class_,
    required this.subject,
    required this.dueDate,
    required this.status,
    required this.submittedCount,
    required this.totalCount,
    this.attachmentUrl,
    this.maxMarks,
    this.instructions,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeacherHomeworkAssignment.fromJson(Map<String, dynamic> json) {
    return TeacherHomeworkAssignment(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      class_: json['class'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      dueDate: json['due_date'] != null 
          ? DateTime.parse(json['due_date'] as String) 
          : DateTime.now(),
      status: json['status'] as String? ?? 'active',
      submittedCount: json['submitted_count'] as int? ?? 0,
      totalCount: json['total_count'] as int? ?? 0,
      attachmentUrl: json['attachment_url'] as String?,
      maxMarks: json['max_marks'] as int?,
      instructions: json['instructions'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'class': class_,
      'subject': subject,
      'due_date': dueDate.toIso8601String(),
      'status': status,
      'submitted_count': submittedCount,
      'total_count': totalCount,
      'attachment_url': attachmentUrl,
      'max_marks': maxMarks,
      'instructions': instructions,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  double get submissionRate => totalCount > 0 ? (submittedCount / totalCount * 100) : 0.0;
  bool get isOverdue => dueDate.isBefore(DateTime.now()) && status != 'completed';
}

/// Homework submission model
@immutable
class HomeworkSubmission {
  final String id;
  final String homeworkId;
  final String studentId;
  final String studentName;
  final String class_;
  final String? submissionText;
  final String? attachmentUrl;
  final DateTime submittedAt;
  final double? marksObtained;
  final String? feedback;
  final String status; // submitted, graded, returned
  final String? gradedBy;
  final DateTime? gradedAt;

  HomeworkSubmission({
    required this.id,
    required this.homeworkId,
    required this.studentId,
    required this.studentName,
    required this.class_,
    this.submissionText,
    this.attachmentUrl,
    required this.submittedAt,
    this.marksObtained,
    this.feedback,
    required this.status,
    this.gradedBy,
    this.gradedAt,
  });

  factory HomeworkSubmission.fromJson(Map<String, dynamic> json) {
    return HomeworkSubmission(
      id: json['id'] as String? ?? '',
      homeworkId: json['homework_id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      class_: json['class'] as String? ?? '',
      submissionText: json['submission_text'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      submittedAt: json['submitted_at'] != null 
          ? DateTime.parse(json['submitted_at'] as String) 
          : DateTime.now(),
      marksObtained: (json['marks_obtained'] as num?)?.toDouble(),
      feedback: json['feedback'] as String?,
      status: json['status'] as String? ?? 'submitted',
      gradedBy: json['graded_by'] as String?,
      gradedAt: json['graded_at'] != null 
          ? DateTime.parse(json['graded_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'homework_id': homeworkId,
      'student_id': studentId,
      'student_name': studentName,
      'class': class_,
      'submission_text': submissionText,
      'attachment_url': attachmentUrl,
      'submitted_at': submittedAt.toIso8601String(),
      'marks_obtained': marksObtained,
      'feedback': feedback,
      'status': status,
      'graded_by': gradedBy,
      'graded_at': gradedAt?.toIso8601String(),
    };
  }
}

/// Exam model for teachers
@immutable
class TeacherExam {
  final String id;
  final String title;
  final String subject;
  final String class_;
  final DateTime examDate;
  final String duration;
  final int totalMarks;
  final String? syllabus;
  final String examType; // term, unit, quiz, final
  final String? roomNumber;
  final DateTime? createdAt;

  TeacherExam({
    required this.id,
    required this.title,
    required this.subject,
    required this.class_,
    required this.examDate,
    required this.duration,
    required this.totalMarks,
    this.syllabus,
    required this.examType,
    this.roomNumber,
    this.createdAt,
  });

  factory TeacherExam.fromJson(Map<String, dynamic> json) {
    return TeacherExam(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      class_: json['class'] as String? ?? '',
      examDate: json['exam_date'] != null 
          ? DateTime.parse(json['exam_date'] as String) 
          : DateTime.now(),
      duration: json['duration'] as String? ?? '',
      totalMarks: json['total_marks'] as int? ?? 0,
      syllabus: json['syllabus'] as String?,
      examType: json['exam_type'] as String? ?? 'term',
      roomNumber: json['room_number'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'class': class_,
      'exam_date': examDate.toIso8601String(),
      'duration': duration,
      'total_marks': totalMarks,
      'syllabus': syllabus,
      'exam_type': examType,
      'room_number': roomNumber,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

/// Grade record model
@immutable
class GradeRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String rollNo;
  final String class_;
  final String subject;
  final String assessmentType; // term, unit, quiz, assignment
  final String assessmentName;
  final double marksObtained;
  final int totalMarks;
  final String grade;
  final String? remarks;
  final DateTime? gradedAt;
  final String? gradedBy;
  final String trend; // up, down, stable

  GradeRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    required this.class_,
    required this.subject,
    required this.assessmentType,
    required this.assessmentName,
    required this.marksObtained,
    required this.totalMarks,
    required this.grade,
    this.remarks,
    this.gradedAt,
    this.gradedBy,
    required this.trend,
  });

  factory GradeRecord.fromJson(Map<String, dynamic> json) {
    return GradeRecord(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      rollNo: json['roll_no'] as String? ?? '',
      class_: json['class'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      assessmentType: json['assessment_type'] as String? ?? '',
      assessmentName: json['assessment_name'] as String? ?? '',
      marksObtained: (json['marks_obtained'] as num?)?.toDouble() ?? 0.0,
      totalMarks: json['total_marks'] as int? ?? 0,
      grade: json['grade'] as String? ?? '',
      remarks: json['remarks'] as String?,
      gradedAt: json['graded_at'] != null 
          ? DateTime.parse(json['graded_at'] as String) 
          : null,
      gradedBy: json['graded_by'] as String?,
      trend: json['trend'] as String? ?? 'stable',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'roll_no': rollNo,
      'class': class_,
      'subject': subject,
      'assessment_type': assessmentType,
      'assessment_name': assessmentName,
      'marks_obtained': marksObtained,
      'total_marks': totalMarks,
      'grade': grade,
      'remarks': remarks,
      'graded_at': gradedAt?.toIso8601String(),
      'graded_by': gradedBy,
      'trend': trend,
    };
  }

  double get percentage => totalMarks > 0 ? (marksObtained / totalMarks * 100) : 0.0;
}

/// Timetable period model
@immutable
class TeacherTimetablePeriod {
  final String id;
  final String dayOfWeek; // Monday, Tuesday, etc.
  final String periodNumber;
  final String startTime;
  final String endTime;
  final String subject;
  final String class_;
  final String? roomNumber;
  final String? teacherId;
  final String? teacherName;

  TeacherTimetablePeriod({
    required this.id,
    required this.dayOfWeek,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.class_,
    this.roomNumber,
    this.teacherId,
    this.teacherName,
  });

  factory TeacherTimetablePeriod.fromJson(Map<String, dynamic> json) {
    return TeacherTimetablePeriod(
      id: json['id'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as String? ?? '',
      periodNumber: json['period_number'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      class_: json['class'] as String? ?? '',
      roomNumber: json['room_number'] as String?,
      teacherId: json['teacher_id'] as String?,
      teacherName: json['teacher_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day_of_week': dayOfWeek,
      'period_number': periodNumber,
      'start_time': startTime,
      'end_time': endTime,
      'subject': subject,
      'class': class_,
      'room_number': roomNumber,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
    };
  }
}

/// Leave application model
@immutable
class TeacherLeave {
  final String id;
  final String teacherId;
  final String teacherName;
  final String leaveType; // sick, casual, earned, maternity, paternity
  final DateTime startDate;
  final DateTime endDate;
  final int durationDays;
  final String reason;
  final String status; // pending, approved, rejected, cancelled
  final String? rejectionReason;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;

  TeacherLeave({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.durationDays,
    required this.reason,
    required this.status,
    this.rejectionReason,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
  });

  factory TeacherLeave.fromJson(Map<String, dynamic> json) {
    return TeacherLeave(
      id: json['id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      leaveType: json['leave_type'] as String? ?? '',
      startDate: json['start_date'] != null 
          ? DateTime.parse(json['start_date'] as String) 
          : DateTime.now(),
      endDate: json['end_date'] != null 
          ? DateTime.parse(json['end_date'] as String) 
          : DateTime.now(),
      durationDays: json['duration_days'] as int? ?? 1,
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null 
          ? DateTime.parse(json['approved_at'] as String) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'leave_type': leaveType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'duration_days': durationDays,
      'reason': reason,
      'status': status,
      'rejection_reason': rejectionReason,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Live class model
@immutable
class TeacherLiveClass {
  final String id;
  final String title;
  final String class_;
  final String subject;
  final DateTime scheduledAt;
  final String? meetingLink;
  final String? meetingId;
  final String? meetingPassword;
  final String status; // scheduled, ongoing, completed, cancelled
  final int? participantCount;
  final String? recordingUrl;
  final DateTime? createdAt;

  TeacherLiveClass({
    required this.id,
    required this.title,
    required this.class_,
    required this.subject,
    required this.scheduledAt,
    this.meetingLink,
    this.meetingId,
    this.meetingPassword,
    required this.status,
    this.participantCount,
    this.recordingUrl,
    this.createdAt,
  });

  factory TeacherLiveClass.fromJson(Map<String, dynamic> json) {
    return TeacherLiveClass(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      class_: json['class'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      scheduledAt: json['scheduled_at'] != null 
          ? DateTime.parse(json['scheduled_at'] as String) 
          : DateTime.now(),
      meetingLink: json['meeting_link'] as String?,
      meetingId: json['meeting_id'] as String?,
      meetingPassword: json['meeting_password'] as String?,
      status: json['status'] as String? ?? 'scheduled',
      participantCount: json['participant_count'] as int?,
      recordingUrl: json['recording_url'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'class': class_,
      'subject': subject,
      'scheduled_at': scheduledAt.toIso8601String(),
      'meeting_link': meetingLink,
      'meeting_id': meetingId,
      'meeting_password': meetingPassword,
      'status': status,
      'participant_count': participantCount,
      'recording_url': recordingUrl,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

/// Teaching material model
@immutable
class TeachingMaterial {
  final String id;
  final String title;
  final String description;
  final String class_;
  final String subject;
  final String materialType; // pdf, video, ppt, doc, link
  final String? fileUrl;
  final String? thumbnailUrl;
  final int? fileSize;
  final String uploadedBy;
  final DateTime uploadedAt;
  final int downloadCount;
  final double? rating;

  TeachingMaterial({
    required this.id,
    required this.title,
    required this.description,
    required this.class_,
    required this.subject,
    required this.materialType,
    this.fileUrl,
    this.thumbnailUrl,
    this.fileSize,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.downloadCount,
    this.rating,
  });

  factory TeachingMaterial.fromJson(Map<String, dynamic> json) {
    return TeachingMaterial(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      class_: json['class'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      materialType: json['material_type'] as String? ?? '',
      fileUrl: json['file_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      fileSize: json['file_size'] as int?,
      uploadedBy: json['uploaded_by'] as String? ?? '',
      uploadedAt: json['uploaded_at'] != null 
          ? DateTime.parse(json['uploaded_at'] as String) 
          : DateTime.now(),
      downloadCount: json['download_count'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'class': class_,
      'subject': subject,
      'material_type': materialType,
      'file_url': fileUrl,
      'thumbnail_url': thumbnailUrl,
      'file_size': fileSize,
      'uploaded_by': uploadedBy,
      'uploaded_at': uploadedAt.toIso8601String(),
      'download_count': downloadCount,
      'rating': rating,
    };
  }
}

/// Salary slip model
@immutable
class SalarySlip {
  final String id;
  final String teacherId;
  final String teacherName;
  final int month;
  final int year;
  final double basicSalary;
  final double allowances;
  final double deductions;
  final double netSalary;
  final DateTime? paidAt;
  final String status; // paid, pending, processing
  final String? slipUrl;
  final DateTime createdAt;

  SalarySlip({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.month,
    required this.year,
    required this.basicSalary,
    required this.allowances,
    required this.deductions,
    required this.netSalary,
    this.paidAt,
    required this.status,
    this.slipUrl,
    required this.createdAt,
  });

  factory SalarySlip.fromJson(Map<String, dynamic> json) {
    return SalarySlip(
      id: json['id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      month: json['month'] as int? ?? 1,
      year: json['year'] as int? ?? DateTime.now().year,
      basicSalary: (json['basic_salary'] as num?)?.toDouble() ?? 0.0,
      allowances: (json['allowances'] as num?)?.toDouble() ?? 0.0,
      deductions: (json['deductions'] as num?)?.toDouble() ?? 0.0,
      netSalary: (json['net_salary'] as num?)?.toDouble() ?? 0.0,
      paidAt: json['paid_at'] != null 
          ? DateTime.parse(json['paid_at'] as String) 
          : null,
      status: json['status'] as String? ?? 'pending',
      slipUrl: json['slip_url'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'month': month,
      'year': year,
      'basic_salary': basicSalary,
      'allowances': allowances,
      'deductions': deductions,
      'net_salary': netSalary,
      'paid_at': paidAt?.toIso8601String(),
      'status': status,
      'slip_url': slipUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Paper builder question model
@immutable
class PaperQuestion {
  final String id;
  final String questionText;
  final String subject;
  final String class_;
  final String questionType; // mcq, short, long, essay
  final int marks;
  final String? difficulty; // easy, medium, hard
  final String? chapter;
  final String? topic;
  final List<String>? options; // for MCQ
  final String? correctAnswer;
  final String? explanation;
  final String createdBy;
  final DateTime createdAt;

  PaperQuestion({
    required this.id,
    required this.questionText,
    required this.subject,
    required this.class_,
    required this.questionType,
    required this.marks,
    this.difficulty,
    this.chapter,
    this.topic,
    this.options,
    this.correctAnswer,
    this.explanation,
    required this.createdBy,
    required this.createdAt,
  });

  factory PaperQuestion.fromJson(Map<String, dynamic> json) {
    return PaperQuestion(
      id: json['id'] as String? ?? '',
      questionText: json['question_text'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      class_: json['class'] as String? ?? '',
      questionType: json['question_type'] as String? ?? '',
      marks: json['marks'] as int? ?? 0,
      difficulty: json['difficulty'] as String?,
      chapter: json['chapter'] as String?,
      topic: json['topic'] as String?,
      options: (json['options'] as List<dynamic>?)?.cast<String>(),
      correctAnswer: json['correct_answer'] as String?,
      explanation: json['explanation'] as String?,
      createdBy: json['created_by'] as String? ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_text': questionText,
      'subject': subject,
      'class': class_,
      'question_type': questionType,
      'marks': marks,
      'difficulty': difficulty,
      'chapter': chapter,
      'topic': topic,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Teacher notice model
@immutable
class TeacherNotice {
  final String id;
  final String title;
  final String content;
  final String noticeType; // general, urgent, event, announcement
  final String? targetAudience; // all, teachers, students, parents
  final DateTime publishDate;
  final DateTime? expiryDate;
  final String status; // draft, published, archived
  final String createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  TeacherNotice({
    required this.id,
    required this.title,
    required this.content,
    required this.noticeType,
    this.targetAudience,
    required this.publishDate,
    this.expiryDate,
    required this.status,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeacherNotice.fromJson(Map<String, dynamic> json) {
    return TeacherNotice(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      noticeType: json['notice_type'] as String? ?? '',
      targetAudience: json['target_audience'] as String?,
      publishDate: json['publish_date'] != null 
          ? DateTime.parse(json['publish_date'] as String) 
          : DateTime.now(),
      expiryDate: json['expiry_date'] != null 
          ? DateTime.parse(json['expiry_date'] as String) 
          : null,
      status: json['status'] as String? ?? 'draft',
      createdBy: json['created_by'] as String? ?? '',
      createdByName: json['created_by_name'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'notice_type': noticeType,
      'target_audience': targetAudience,
      'publish_date': publishDate.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      'status': status,
      'created_by': createdBy,
      'created_by_name': createdByName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Teacher notification model
@immutable
class TeacherNotification {
  final String id;
  final String title;
  final String message;
  final String type; // general, homework, attendance, exam, system
  final bool isRead;
  final String? actionUrl;
  final DateTime createdAt;
  final DateTime? readAt;

  TeacherNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.actionUrl,
    required this.createdAt,
    this.readAt,
  });

  factory TeacherNotification.fromJson(Map<String, dynamic> json) {
    return TeacherNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      actionUrl: json['action_url'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      readAt: json['read_at'] != null 
          ? DateTime.parse(json['read_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
      'action_url': actionUrl,
      'created_at': createdAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
    };
  }
}

/// My Class model
@immutable
class TeacherMyClass {
  final String id;
  final String name;
  final String section;
  final String? classTeacher;
  final int studentCount;
  final String? schedule;
  final String? roomNumber;
  final DateTime? createdAt;

  TeacherMyClass({
    required this.id,
    required this.name,
    required this.section,
    this.classTeacher,
    required this.studentCount,
    this.schedule,
    this.roomNumber,
    this.createdAt,
  });

  factory TeacherMyClass.fromJson(Map<String, dynamic> json) {
    return TeacherMyClass(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      section: json['section'] as String? ?? '',
      classTeacher: json['class_teacher'] as String?,
      studentCount: json['student_count'] as int? ?? 0,
      schedule: json['schedule'] as String?,
      roomNumber: json['room_number'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'section': section,
      'class_teacher': classTeacher,
      'student_count': studentCount,
      'schedule': schedule,
      'room_number': roomNumber,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}