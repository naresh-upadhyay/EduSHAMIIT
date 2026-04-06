/// Data models for teacher-related entities

/// Teacher profile model
class TeacherProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? photoUrl;
  final List<String> subjects;
  final List<String> classes;
  final int? experienceYears;
  final String? qualification;
  final DateTime? joinDate;

  TeacherProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.photoUrl,
    required this.subjects,
    required this.classes,
    this.experienceYears,
    this.qualification,
    this.joinDate,
  });

  factory TeacherProfile.fromJson(Map<String, dynamic> json) {
    return TeacherProfile(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      photoUrl: json['photo_url'] ?? json['profile_photo'],
      subjects: json['subjects'] != null
          ? List<String>.from(json['subjects'])
          : [],
      classes: json['classes'] != null
          ? List<String>.from(json['classes'])
          : [],
      experienceYears: json['experience_years'],
      qualification: json['qualification'],
      joinDate: json['join_date'] != null
          ? DateTime.tryParse(json['join_date'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'photo_url': photoUrl,
      'subjects': subjects,
      'classes': classes,
      'experience_years': experienceYears,
      'qualification': qualification,
      'join_date': joinDate?.toIso8601String(),
    };
  }
}

/// Student model for teacher view
class Student {
  final String id;
  final String fullName;
  final String? rollNumber;
  final String className;
  final String? section;
  final int? xpPoints;
  final int? learningStreak;
  final double? attendancePercentage;
  final double? averageScore;
  final String? parentPhone;
  final String? parentEmail;

  Student({
    required this.id,
    required this.fullName,
    this.rollNumber,
    required this.className,
    this.section,
    this.xpPoints,
    this.learningStreak,
    this.attendancePercentage,
    this.averageScore,
    this.parentPhone,
    this.parentEmail,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? '',
      rollNumber: json['roll_number'],
      className: json['class'] ?? '',
      section: json['section'],
      xpPoints: json['xp_points'],
      learningStreak: json['learning_streak'],
      attendancePercentage: json['attendance_percentage'] != null
          ? double.tryParse(json['attendance_percentage'].toString())
          : null,
      averageScore: json['average_score'] != null
          ? double.tryParse(json['average_score'].toString())
          : null,
      parentPhone: json['father_phone'] ?? json['parent_phone'],
      parentEmail: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'roll_number': rollNumber,
      'class': className,
      'section': section,
      'xp_points': xpPoints,
      'learning_streak': learningStreak,
      'attendance_percentage': attendancePercentage,
      'average_score': averageScore,
      'father_phone': parentPhone,
      'parent_phone': parentPhone,
      'email': parentEmail,
    };
  }
}

/// Homework/Assignment model
class Homework {
  final String id;
  final String title;
  final String description;
  final String subject;
  final String targetClass;
  final DateTime dueDate;
  final int? maxMarks;
  final String status; // 'draft', 'active', 'completed'
  final int totalStudents;
  final int submittedCount;
  final int gradedCount;

  Homework({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.targetClass,
    required this.dueDate,
    this.maxMarks,
    required this.status,
    required this.totalStudents,
    required this.submittedCount,
    required this.gradedCount,
  });

  factory Homework.fromJson(Map<String, dynamic> json) {
    return Homework(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      subject: json['subject'] ?? '',
      targetClass: json['target_class'] ?? '',
      dueDate: DateTime.tryParse(json['due_date'] ?? '') ?? DateTime.now(),
      maxMarks: json['max_marks'],
      status: json['status'] ?? 'draft',
      totalStudents: json['total_students'] ?? 0,
      submittedCount: json['submitted_count'] ?? 0,
      gradedCount: json['graded_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subject': subject,
      'target_class': targetClass,
      'due_date': dueDate.toIso8601String(),
      'max_marks': maxMarks,
      'status': status,
      'total_students': totalStudents,
      'submitted_count': submittedCount,
      'graded_count': gradedCount,
    };
  }
}

/// Homework submission model
class HomeworkSubmission {
  final String id;
  final String homeworkId;
  final String studentId;
  final String studentName;
  final DateTime submittedAt;
  final String? fileUrl;
  final String status; // 'submitted', 'graded'
  final double? marks;
  final String? grade;
  final String? teacherRemarks;

  HomeworkSubmission({
    required this.id,
    required this.homeworkId,
    required this.studentId,
    required this.studentName,
    required this.submittedAt,
    this.fileUrl,
    required this.status,
    this.marks,
    this.grade,
    this.teacherRemarks,
  });

  factory HomeworkSubmission.fromJson(Map<String, dynamic> json) {
    return HomeworkSubmission(
      id: json['id'] ?? '',
      homeworkId: json['homework_id'] ?? '',
      studentId: json['student_id'] ?? '',
      studentName: json['student_name'] ??
          (json['profiles']?['full_name'] ?? ''),
      submittedAt: DateTime.tryParse(json['submitted_at'] ?? '') ?? DateTime.now(),
      fileUrl: json['file_url'] ?? json['submission_url'],
      status: json['status'] ?? 'submitted',
      marks: json['marks'] != null
          ? double.tryParse(json['marks'].toString())
          : null,
      grade: json['grade'],
      teacherRemarks: json['teacher_remarks'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'homework_id': homeworkId,
      'student_id': studentId,
      'student_name': studentName,
      'submitted_at': submittedAt.toIso8601String(),
      'file_url': fileUrl,
      'status': status,
      'marks': marks,
      'grade': grade,
      'teacher_remarks': teacherRemarks,
    };
  }
}

/// Exam model
class Exam {
  final String id;
  final String title;
  final String subject;
  final String targetClass;
  final DateTime startDate;
  final DateTime endDate;
  final int durationMinutes;
  final int totalQuestions;
  final int? maxMarks;
  final String status; // 'upcoming', 'active', 'completed'
  final int? attemptCount;

  Exam({
    required this.id,
    required this.title,
    required this.subject,
    required this.targetClass,
    required this.startDate,
    required this.endDate,
    required this.durationMinutes,
    required this.totalQuestions,
    this.maxMarks,
    required this.status,
    this.attemptCount,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subject: json['subject'] ?? '',
      targetClass: json['target_class'] ?? '',
      startDate: DateTime.tryParse(json['start_date'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date'] ?? '') ?? DateTime.now(),
      durationMinutes: json['duration_minutes'] ?? 60,
      totalQuestions: json['total_questions'] ?? 0,
      maxMarks: json['max_marks'],
      status: json['status'] ?? 'upcoming',
      attemptCount: json['attempt_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'target_class': targetClass,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'duration_minutes': durationMinutes,
      'total_questions': totalQuestions,
      'max_marks': maxMarks,
      'status': status,
      'attempt_count': attemptCount,
    };
  }
}

/// Leave application model
class LeaveApplication {
  final String id;
  final String leaveType; // 'sick', 'casual', 'other'
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final String? reviewedBy;
  final String? reviewRemarks;

  LeaveApplication({
    required this.id,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.reviewedBy,
    this.reviewRemarks,
  });

  factory LeaveApplication.fromJson(Map<String, dynamic> json) {
    return LeaveApplication(
      id: json['id'] ?? '',
      leaveType: json['leave_type'] ?? 'other',
      startDate: DateTime.tryParse(json['start_date'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date'] ?? '') ?? DateTime.now(),
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      reviewedBy: json['reviewed_by'],
      reviewRemarks: json['review_remarks'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'leave_type': leaveType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'reason': reason,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'reviewed_by': reviewedBy,
      'review_remarks': reviewRemarks,
    };
  }
}

/// Leave balance model
class LeaveBalance {
  final int sickLeaveBalance;
  final int casualLeaveBalance;
  final int earnedLeaveBalance;
  final int totalDaysTaken;

  LeaveBalance({
    required this.sickLeaveBalance,
    required this.casualLeaveBalance,
    required this.earnedLeaveBalance,
    required this.totalDaysTaken,
  });

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      sickLeaveBalance: json['sick_leave'] ?? json['sick_balance'] ?? 0,
      casualLeaveBalance: json['casual_leave'] ?? json['casual_balance'] ?? 0,
      earnedLeaveBalance: json['earned_leave'] ?? json['earned_balance'] ?? 0,
      totalDaysTaken: json['total_days_taken'] ?? 0,
    );
  }
}

/// Salary model
class Salary {
  final String id;
  final String month; // YYYY-MM format
  final double basicPay;
  final double hra;
  final double da;
  final double specialAllowance;
  final double pfDeduction;
  final double tdsDeduction;
  final double professionalTax;
  final double grossSalary;
  final double netSalary;
  final String status; // 'pending', 'paid', 'disbursed'

  Salary({
    required this.id,
    required this.month,
    required this.basicPay,
    required this.hra,
    required this.da,
    required this.specialAllowance,
    required this.pfDeduction,
    required this.tdsDeduction,
    required this.professionalTax,
    required this.grossSalary,
    required this.netSalary,
    required this.status,
  });

  factory Salary.fromJson(Map<String, dynamic> json) {
    return Salary(
      id: json['id'] ?? '',
      month: json['month'] ?? '',
      basicPay: double.tryParse(json['basic_pay']?.toString() ?? '0') ?? 0,
      hra: double.tryParse(json['hra']?.toString() ?? '0') ?? 0,
      da: double.tryParse(json['da']?.toString() ?? '0') ?? 0,
      specialAllowance:
          double.tryParse(json['special_allowance']?.toString() ?? '0') ?? 0,
      pfDeduction:
          double.tryParse(json['pf_deduction']?.toString() ?? '0') ?? 0,
      tdsDeduction:
          double.tryParse(json['tds_deduction']?.toString() ?? '0') ?? 0,
      professionalTax:
          double.tryParse(json['professional_tax']?.toString() ?? '0') ?? 0,
      grossSalary:
          double.tryParse(json['gross_salary']?.toString() ?? '0') ?? 0,
      netSalary:
          double.tryParse(json['net_salary']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'month': month,
      'basic_pay': basicPay,
      'hra': hra,
      'da': da,
      'special_allowance': specialAllowance,
      'pf_deduction': pfDeduction,
      'tds_deduction': tdsDeduction,
      'professional_tax': professionalTax,
      'gross_salary': grossSalary,
      'net_salary': netSalary,
      'status': status,
    };
  }
}

/// Study material model
class StudyMaterial {
  final String id;
  final String title;
  final String description;
  final String materialType; // 'Notes', 'PPTs', 'Videos', 'Worksheets'
  final String targetClass;
  final String subject;
  final String? fileUrl;
  final DateTime uploadedAt;
  final String teacherName;

  StudyMaterial({
    required this.id,
    required this.title,
    required this.description,
    required this.materialType,
    required this.targetClass,
    required this.subject,
    this.fileUrl,
    required this.uploadedAt,
    required this.teacherName,
  });

  factory StudyMaterial.fromJson(Map<String, dynamic> json) {
    return StudyMaterial(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      materialType: json['material_type'] ?? '',
      targetClass: json['target_class'] ?? '',
      subject: json['subject'] ?? '',
      fileUrl: json['file_url'] ?? json['url'],
      uploadedAt: DateTime.tryParse(json['uploaded_at'] ?? '') ?? DateTime.now(),
      teacherName: json['teacher_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'material_type': materialType,
      'target_class': targetClass,
      'subject': subject,
      'file_url': fileUrl,
      'uploaded_at': uploadedAt.toIso8601String(),
      'teacher_name': teacherName,
    };
  }
}

/// Live class model
class LiveClass {
  final String id;
  final String title;
  final String subject;
  final String targetClass;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? meetingLink;
  final String status; // 'live', 'scheduled', 'completed', 'recorded'
  final String? recordingUrl;
  final int? participantCount;

  LiveClass({
    required this.id,
    required this.title,
    required this.subject,
    required this.targetClass,
    required this.scheduledAt,
    required this.durationMinutes,
    this.meetingLink,
    required this.status,
    this.recordingUrl,
    this.participantCount,
  });

  factory LiveClass.fromJson(Map<String, dynamic> json) {
    return LiveClass(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subject: json['subject'] ?? '',
      targetClass: json['target_class'] ?? '',
      scheduledAt:
          DateTime.tryParse(json['scheduled_at'] ?? '') ?? DateTime.now(),
      durationMinutes: json['duration_minutes'] ?? 60,
      meetingLink: json['meeting_link'] ?? json['join_url'],
      status: json['status'] ?? 'scheduled',
      recordingUrl: json['recording_url'],
      participantCount: json['participant_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'target_class': targetClass,
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'meeting_link': meetingLink,
      'status': status,
      'recording_url': recordingUrl,
      'participant_count': participantCount,
    };
  }
}

/// Notification model
class Notification {
  final String id;
  final String title;
  final String message;
  final String type; // 'announcement', 'reminder', 'alert', 'system'
  final DateTime createdAt;
  final bool isRead;
  final String? actionUrl;

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
    this.actionUrl,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? json['content'] ?? '',
      type: json['type'] ?? 'system',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      isRead: json['is_read'] ?? false,
      actionUrl: json['action_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'action_url': actionUrl,
    };
  }
}

/// Exam analytics model
class ExamAnalytics {
  final String examId;
  final String examTitle;
  final int totalStudents;
  final double averageScore;
  final double highestScore;
  final double lowestScore;
  final List<TopPerformer> topPerformers;

  ExamAnalytics({
    required this.examId,
    required this.examTitle,
    required this.totalStudents,
    required this.averageScore,
    required this.highestScore,
    required this.lowestScore,
    required this.topPerformers,
  });

  factory ExamAnalytics.fromJson(Map<String, dynamic> json) {
    return ExamAnalytics(
      examId: json['exam_id'] ?? '',
      examTitle: json['exam_title'] ?? '',
      totalStudents: json['total_students'] ?? 0,
      averageScore: double.tryParse(json['average_score']?.toString() ?? '0') ?? 0,
      highestScore: double.tryParse(json['highest_score']?.toString() ?? '0') ?? 0,
      lowestScore: double.tryParse(json['lowest_score']?.toString() ?? '0') ?? 0,
      topPerformers: (json['top_performers'] as List?)
              ?.map((e) => TopPerformer.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class TopPerformer {
  final String studentId;
  final String studentName;
  final double score;
  final int? correctAnswers;

  TopPerformer({
    required this.studentId,
    required this.studentName,
    required this.score,
    this.correctAnswers,
  });

  factory TopPerformer.fromJson(Map<String, dynamic> json) {
    return TopPerformer(
      studentId: json['student_id'] ?? '',
      studentName: json['student_name'] ?? json['full_name'] ?? '',
      score: double.tryParse(json['score']?.toString() ?? json['total_marks']?.toString() ?? '0') ?? 0,
      correctAnswers: json['correct_answers'] ?? json['total_correct'],
    );
  }
}

/// Class performance model
class ClassPerformance {
  final String className;
  final int totalStudents;
  final double classAverage;
  final List<StudentPerformance> topPerformers;
  final List<AtRiskStudent> atRiskStudents;

  ClassPerformance({
    required this.className,
    required this.totalStudents,
    required this.classAverage,
    required this.topPerformers,
    required this.atRiskStudents,
  });

  factory ClassPerformance.fromJson(Map<String, dynamic> json) {
    return ClassPerformance(
      className: json['class_name'] ?? '',
      totalStudents: json['total_students'] ?? 0,
      classAverage: double.tryParse(json['class_average']?.toString() ?? '0') ?? 0,
      topPerformers: (json['top_performers'] as List?)
              ?.map((e) => StudentPerformance.fromJson(e))
              .toList() ??
          [],
      atRiskStudents: (json['at_risk_students'] as List?)
              ?.map((e) => AtRiskStudent.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class StudentPerformance {
  final String name;
  final double averageScore;

  StudentPerformance({required this.name, required this.averageScore});

  factory StudentPerformance.fromJson(Map<String, dynamic> json) {
    return StudentPerformance(
      name: json['name'] ?? '',
      averageScore: double.tryParse(json['avg_score']?.toString() ?? '0') ?? 0,
    );
  }
}

class AtRiskStudent {
  final String name;
  final List<String> issues;

  AtRiskStudent({required this.name, required this.issues});

  factory AtRiskStudent.fromJson(Map<String, dynamic> json) {
    return AtRiskStudent(
      name: json['name'] ?? '',
      issues: (json['issues'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}