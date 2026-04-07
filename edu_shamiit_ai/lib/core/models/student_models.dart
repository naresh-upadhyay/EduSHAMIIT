/// Data models for student-related entities
library;

/// Student profile model
class StudentProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? photoUrl;
  final String className;
  final String section;
  final String rollNumber;
  final int? xpPoints;
  final int? learningStreak;
  final DateTime? dateOfBirth;
  final String? parentName;
  final String? parentPhone;
  final String? parentEmail;
  final String? address;

  StudentProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.photoUrl,
    required this.className,
    required this.section,
    required this.rollNumber,
    this.xpPoints,
    this.learningStreak,
    this.dateOfBirth,
    this.parentName,
    this.parentPhone,
    this.parentEmail,
    this.address,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      photoUrl: json['photo_url'] ?? json['profile_photo'],
      className: json['class'] ?? '',
      section: json['section'] ?? '',
      rollNumber: json['roll_number'] ?? '',
      xpPoints: json['xp_points'],
      learningStreak: json['learning_streak'],
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'])
          : null,
      parentName: json['father_name'] ?? json['parent_name'],
      parentPhone: json['father_phone'] ?? json['parent_phone'],
      parentEmail: json['email'],
      address: json['address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'photo_url': photoUrl,
      'class': className,
      'section': section,
      'roll_number': rollNumber,
      'xp_points': xpPoints,
      'learning_streak': learningStreak,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'father_name': parentName,
      'parent_name': parentName,
      'father_phone': parentPhone,
      'parent_phone': parentPhone,
      'address': address,
    };
  }
}

/// Achievement model
class Achievement {
  final String id;
  final String title;
  final String description;
  final String category;
  final int xpReward;
  final String? iconUrl;
  final DateTime? earnedAt;
  final bool isLocked;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.xpReward,
    this.iconUrl,
    this.earnedAt,
    required this.isLocked,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      xpReward: json['xp_reward'] ?? 0,
      iconUrl: json['icon_url'],
      earnedAt: json['earned_at'] != null
          ? DateTime.tryParse(json['earned_at'])
          : null,
      isLocked: json['is_locked'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'xp_reward': xpReward,
      'icon_url': iconUrl,
      'earned_at': earnedAt?.toIso8601String(),
      'is_locked': isLocked,
    };
  }
}

/// Attendance record model
class AttendanceRecord {
  final String id;
  final DateTime date;
  final bool present;
  final String? status; // 'present', 'absent', 'late', 'excused'
  final String? remarks;

  AttendanceRecord({
    required this.id,
    required this.date,
    required this.present,
    this.status,
    this.remarks,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      present: json['present'] ?? false,
      status: json['status'],
      remarks: json['remarks'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'present': present,
      'status': status,
      'remarks': remarks,
    };
  }
}

/// Attendance summary model
class AttendanceSummary {
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final double percentage;

  AttendanceSummary({
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.percentage,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      totalDays: json['total_days'] ?? 0,
      presentDays: json['present_days'] ?? 0,
      absentDays: json['absent_days'] ?? 0,
      lateDays: json['late_days'] ?? 0,
      percentage: double.tryParse(json['percentage']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Course model
class Course {
  final String id;
  final String title;
  final String subject;
  final String description;
  final String teacherName;
  final double progress;
  final int totalLessons;
  final int completedLessons;
  final String? thumbnailUrl;

  Course({
    required this.id,
    required this.title,
    required this.subject,
    required this.description,
    required this.teacherName,
    required this.progress,
    required this.totalLessons,
    required this.completedLessons,
    this.thumbnailUrl,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subject: json['subject'] ?? '',
      description: json['description'] ?? '',
      teacherName: json['teacher_name'] ?? '',
      progress: double.tryParse(json['progress']?.toString() ?? '0') ?? 0,
      totalLessons: json['total_lessons'] ?? 0,
      completedLessons: json['completed_lessons'] ?? 0,
      thumbnailUrl: json['thumbnail_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'description': description,
      'teacher_name': teacherName,
      'progress': progress,
      'total_lessons': totalLessons,
      'completed_lessons': completedLessons,
      'thumbnail_url': thumbnailUrl,
    };
  }
}

/// Event model
class Event {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final String location;
  final String type; // 'academic', 'sports', 'cultural', 'exam'
  final String? imageUrl;
  final bool isRegistered;
  final DateTime? registrationDeadline;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.type,
    this.imageUrl,
    required this.isRegistered,
    this.registrationDeadline,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      startDate: DateTime.tryParse(json['start_date'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date'] ?? '') ?? DateTime.now(),
      location: json['location'] ?? '',
      type: json['type'] ?? 'academic',
      imageUrl: json['image_url'],
      isRegistered: json['is_registered'] ?? false,
      registrationDeadline: json['registration_deadline'] != null
          ? DateTime.tryParse(json['registration_deadline'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'location': location,
      'type': type,
      'image_url': imageUrl,
      'is_registered': isRegistered,
      'registration_deadline': registrationDeadline?.toIso8601String(),
    };
  }
}

/// Exam result model
class ExamResult {
  final String id;
  final String examTitle;
  final String subject;
  final DateTime examDate;
  final double marksObtained;
  final double maxMarks;
  final String grade;
  final String? remarks;
  final double? classAverage;
  final int? rank;

  ExamResult({
    required this.id,
    required this.examTitle,
    required this.subject,
    required this.examDate,
    required this.marksObtained,
    required this.maxMarks,
    required this.grade,
    this.remarks,
    this.classAverage,
    this.rank,
  });

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    return ExamResult(
      id: json['id'] ?? '',
      examTitle: json['exam_title'] ?? '',
      subject: json['subject'] ?? '',
      examDate: DateTime.tryParse(json['exam_date'] ?? '') ?? DateTime.now(),
      marksObtained:
          double.tryParse(json['marks_obtained']?.toString() ?? '0') ?? 0,
      maxMarks: double.tryParse(json['max_marks']?.toString() ?? '0') ?? 0,
      grade: json['grade'] ?? '',
      remarks: json['remarks'],
      classAverage: json['class_average'] != null
          ? double.tryParse(json['class_average'].toString())
          : null,
      rank: json['rank'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_title': examTitle,
      'subject': subject,
      'exam_date': examDate.toIso8601String(),
      'marks_obtained': marksObtained,
      'max_marks': maxMarks,
      'grade': grade,
      'remarks': remarks,
      'class_average': classAverage,
      'rank': rank,
    };
  }
}

/// Fee record model
class FeeRecord {
  final String id;
  final String month;
  final double amount;
  final double paidAmount;
  final double dueAmount;
  final String status; // 'pending', 'paid', 'partial', 'overdue'
  final DateTime dueDate;
  final DateTime? paidDate;
  final String? transactionId;
  final String? receiptUrl;

  FeeRecord({
    required this.id,
    required this.month,
    required this.amount,
    required this.paidAmount,
    required this.dueAmount,
    required this.status,
    required this.dueDate,
    this.paidDate,
    this.transactionId,
    this.receiptUrl,
  });

  factory FeeRecord.fromJson(Map<String, dynamic> json) {
    return FeeRecord(
      id: json['id'] ?? '',
      month: json['month'] ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      paidAmount:
          double.tryParse(json['paid_amount']?.toString() ?? '0') ?? 0,
      dueAmount: double.tryParse(json['due_amount']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? 'pending',
      dueDate: DateTime.tryParse(json['due_date'] ?? '') ?? DateTime.now(),
      paidDate: json['paid_date'] != null
          ? DateTime.tryParse(json['paid_date'])
          : null,
      transactionId: json['transaction_id'],
      receiptUrl: json['receipt_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'month': month,
      'amount': amount,
      'paid_amount': paidAmount,
      'due_amount': dueAmount,
      'status': status,
      'due_date': dueDate.toIso8601String(),
      'paid_date': paidDate?.toIso8601String(),
      'transaction_id': transactionId,
      'receipt_url': receiptUrl,
    };
  }
}

/// Homework assignment model (student view)
class HomeworkAssignment {
  final String id;
  final String title;
  final String description;
  final String subject;
  final DateTime assignedDate;
  final DateTime dueDate;
  final String status; // 'pending', 'submitted', 'graded', 'late'
  final int? maxMarks;
  final double? marksObtained;
  final String? grade;
  final String? teacherRemarks;
  final String? submissionUrl;
  final DateTime? submittedAt;

  HomeworkAssignment({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.assignedDate,
    required this.dueDate,
    required this.status,
    this.maxMarks,
    this.marksObtained,
    this.grade,
    this.teacherRemarks,
    this.submissionUrl,
    this.submittedAt,
  });

  factory HomeworkAssignment.fromJson(Map<String, dynamic> json) {
    return HomeworkAssignment(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      subject: json['subject'] ?? '',
      assignedDate:
          DateTime.tryParse(json['assigned_date'] ?? '') ?? DateTime.now(),
      dueDate: DateTime.tryParse(json['due_date'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'pending',
      maxMarks: json['max_marks'],
      marksObtained: json['marks_obtained'] != null
          ? double.tryParse(json['marks_obtained'].toString())
          : null,
      grade: json['grade'],
      teacherRemarks: json['teacher_remarks'],
      submissionUrl: json['submission_url'],
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subject': subject,
      'assigned_date': assignedDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'status': status,
      'max_marks': maxMarks,
      'marks_obtained': marksObtained,
      'grade': grade,
      'teacher_remarks': teacherRemarks,
      'submission_url': submissionUrl,
      'submitted_at': submittedAt?.toIso8601String(),
    };
  }
}

/// Leaderboard entry model
class LeaderboardEntry {
  final int rank;
  final String studentId;
  final String studentName;
  final String className;
  final int xpPoints;
  final String? photoUrl;

  LeaderboardEntry({
    required this.rank,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.xpPoints,
    this.photoUrl,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] ?? 0,
      studentId: json['student_id'] ?? '',
      studentName: json['student_name'] ?? json['full_name'] ?? '',
      className: json['class_name'] ?? '',
      xpPoints: json['xp_points'] ?? 0,
      photoUrl: json['photo_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'student_id': studentId,
      'student_name': studentName,
      'class_name': className,
      'xp_points': xpPoints,
      'photo_url': photoUrl,
    };
  }
}

/// Leave application model (student view)
class StudentLeaveApplication {
  final String id;
  final String leaveType; // 'sick', 'personal', 'emergency'
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final String? reviewedBy;
  final String? reviewRemarks;

  StudentLeaveApplication({
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

  factory StudentLeaveApplication.fromJson(Map<String, dynamic> json) {
    return StudentLeaveApplication(
      id: json['id'] ?? '',
      leaveType: json['leave_type'] ?? 'personal',
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

/// Library book model
class LibraryBook {
  final String id;
  final String title;
  final String author;
  final String isbn;
  final String category;
  final int totalCopies;
  final int availableCopies;
  final String? coverUrl;
  final DateTime? dueDate;
  final bool isIssued;

  LibraryBook({
    required this.id,
    required this.title,
    required this.author,
    required this.isbn,
    required this.category,
    required this.totalCopies,
    required this.availableCopies,
    this.coverUrl,
    this.dueDate,
    required this.isIssued,
  });

  factory LibraryBook.fromJson(Map<String, dynamic> json) {
    return LibraryBook(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      isbn: json['isbn'] ?? '',
      category: json['category'] ?? '',
      totalCopies: json['total_copies'] ?? 0,
      availableCopies: json['available_copies'] ?? 0,
      coverUrl: json['cover_url'],
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'])
          : null,
      isIssued: json['is_issued'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'isbn': isbn,
      'category': category,
      'total_copies': totalCopies,
      'available_copies': availableCopies,
      'cover_url': coverUrl,
      'due_date': dueDate?.toIso8601String(),
      'is_issued': isIssued,
    };
  }
}

/// Live class model (student view)
class StudentLiveClass {
  final String id;
  final String title;
  final String subject;
  final String teacherName;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? meetingLink;
  final String status; // 'live', 'scheduled', 'completed', 'recorded'
  final String? recordingUrl;

  StudentLiveClass({
    required this.id,
    required this.title,
    required this.subject,
    required this.teacherName,
    required this.scheduledAt,
    required this.durationMinutes,
    this.meetingLink,
    required this.status,
    this.recordingUrl,
  });

  factory StudentLiveClass.fromJson(Map<String, dynamic> json) {
    return StudentLiveClass(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subject: json['subject'] ?? '',
      teacherName: json['teacher_name'] ?? '',
      scheduledAt:
          DateTime.tryParse(json['scheduled_at'] ?? '') ?? DateTime.now(),
      durationMinutes: json['duration_minutes'] ?? 60,
      meetingLink: json['meeting_link'] ?? json['join_url'],
      status: json['status'] ?? 'scheduled',
      recordingUrl: json['recording_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'teacher_name': teacherName,
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'meeting_link': meetingLink,
      'status': status,
      'recording_url': recordingUrl,
    };
  }
}

/// Message model
class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhoto;
  final String content;
  final DateTime sentAt;
  final bool isRead;
  final String? attachmentUrl;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhoto,
    required this.content,
    required this.sentAt,
    required this.isRead,
    this.attachmentUrl,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      senderId: json['sender_id'] ?? '',
      senderName: json['sender_name'] ?? '',
      senderPhoto: json['sender_photo'],
      content: json['content'] ?? '',
      sentAt: DateTime.tryParse(json['sent_at'] ?? '') ?? DateTime.now(),
      isRead: json['is_read'] ?? false,
      attachmentUrl: json['attachment_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_photo': senderPhoto,
      'content': content,
      'sent_at': sentAt.toIso8601String(),
      'is_read': isRead,
      'attachment_url': attachmentUrl,
    };
  }
}

/// Notice model
class Notice {
  final String id;
  final String title;
  final String content;
  final String category; // 'urgent', 'general', 'exam', 'event'
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? attachmentUrl;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
    this.expiresAt,
    this.attachmentUrl,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? 'general',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'])
          : null,
      attachmentUrl: json['attachment_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'attachment_url': attachmentUrl,
    };
  }
}

/// Notification model (student view)
class StudentNotification {
  final String id;
  final String title;
  final String message;
  final String type; // 'academic', 'administrative', 'event', 'reminder'
  final DateTime createdAt;
  final bool isRead;
  final String? actionUrl;

  StudentNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
    this.actionUrl,
  });

  factory StudentNotification.fromJson(Map<String, dynamic> json) {
    return StudentNotification(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? json['content'] ?? '',
      type: json['type'] ?? 'academic',
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

/// Online exam question model
class ExamQuestion {
  final int questionNumber;
  final String questionText;
  final List<String> options;
  final int? correctOption;
  final int? selectedOption;
  final bool isAnswered;
  final bool isMarkedForReview;

  ExamQuestion({
    required this.questionNumber,
    required this.questionText,
    required this.options,
    this.correctOption,
    this.selectedOption,
    required this.isAnswered,
    required this.isMarkedForReview,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    return ExamQuestion(
      questionNumber: json['question_number'] ?? 0,
      questionText: json['question_text'] ?? '',
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
      correctOption: json['correct_option'],
      selectedOption: json['selected_option'],
      isAnswered: json['is_answered'] ?? false,
      isMarkedForReview: json['is_marked_for_review'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_number': questionNumber,
      'question_text': questionText,
      'options': options,
      'correct_option': correctOption,
      'selected_option': selectedOption,
      'is_answered': isAnswered,
      'is_marked_for_review': isMarkedForReview,
    };
  }
}

/// Timetable period model
class TimetablePeriod {
  final String subject;
  final String teacherName;
  final String roomNumber;
  final String startTime;
  final String endTime;
  final String day;

  TimetablePeriod({
    required this.subject,
    required this.teacherName,
    required this.roomNumber,
    required this.startTime,
    required this.endTime,
    required this.day,
  });

  factory TimetablePeriod.fromJson(Map<String, dynamic> json) {
    return TimetablePeriod(
      subject: json['subject'] ?? '',
      teacherName: json['teacher_name'] ?? '',
      roomNumber: json['room_number'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      day: json['day'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject': subject,
      'teacher_name': teacherName,
      'room_number': roomNumber,
      'start_time': startTime,
      'end_time': endTime,
      'day': day,
    };
  }
}

/// Transport route model
class TransportRoute {
  final String id;
  final String routeName;
  final String busNumber;
  final String driverName;
  final String driverPhone;
  final List<TransportStop> stops;
  final DateTime? departureTime;
  final DateTime? arrivalTime;
  final String? studentStopName;
  final String? seatNumber;
  final DateTime? estimatedArrival;
  final String? vehicleNumber;

  TransportRoute({
    required this.id,
    required this.routeName,
    required this.busNumber,
    required this.driverName,
    required this.driverPhone,
    required this.stops,
    this.departureTime,
    this.arrivalTime,
    this.studentStopName,
    this.seatNumber,
    this.estimatedArrival,
    this.vehicleNumber,
  });

  factory TransportRoute.fromJson(Map<String, dynamic> json) {
    return TransportRoute(
      id: json['id'] ?? '',
      routeName: json['route_name'] ?? '',
      busNumber: json['bus_number'] ?? '',
      driverName: json['driver_name'] ?? '',
      driverPhone: json['driver_phone'] ?? '',
      stops: (json['stops'] as List?)
          ?.map((e) => TransportStop.fromJson(e))
          .toList() ?? [],
      departureTime: json['departure_time'] != null
          ? DateTime.tryParse(json['departure_time'])
          : null,
      arrivalTime: json['arrival_time'] != null
          ? DateTime.tryParse(json['arrival_time'])
          : null,
      studentStopName: json['student_stop_name'],
      seatNumber: json['seat_number'],
      estimatedArrival: json['estimated_arrival'] != null
          ? DateTime.tryParse(json['estimated_arrival'])
          : null,
      vehicleNumber: json['vehicle_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_name': routeName,
      'bus_number': busNumber,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'stops': stops.map((e) => e.toJson()).toList(),
      'departure_time': departureTime?.toIso8601String(),
      'arrival_time': arrivalTime?.toIso8601String(),
      'student_stop_name': studentStopName,
      'seat_number': seatNumber,
      'estimated_arrival': estimatedArrival?.toIso8601String(),
      'vehicle_number': vehicleNumber,
    };
  }
}

/// Transport stop model
class TransportStop {
  final String id;
  final String stopName;
  final String? arrivalTime;
  final bool isBoarded;

  TransportStop({
    required this.id,
    required this.stopName,
    this.arrivalTime,
    required this.isBoarded,
  });

  factory TransportStop.fromJson(Map<String, dynamic> json) {
    return TransportStop(
      id: json['id'] ?? '',
      stopName: json['stop_name'] ?? '',
      arrivalTime: json['arrival_time'],
      isBoarded: json['is_boarded'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stop_name': stopName,
      'arrival_time': arrivalTime,
      'is_boarded': isBoarded,
    };
  }
}

/// Exam schedule model
class ExamSchedule {
  final String id;
  final String subject;
  final String examType;
  final DateTime dateTime;
  final String duration;
  final String venue;

  ExamSchedule({
    required this.id,
    required this.subject,
    required this.examType,
    required this.dateTime,
    required this.duration,
    required this.venue,
  });

  factory ExamSchedule.fromJson(Map<String, dynamic> json) {
    return ExamSchedule(
      id: json['id'] ?? '',
      subject: json['subject'] ?? '',
      examType: json['exam_type'] ?? '',
      dateTime: DateTime.tryParse(json['date_time'] ?? json['datetime'] ?? '') ?? DateTime.now(),
      duration: json['duration'] ?? '',
      venue: json['venue'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'exam_type': examType,
      'date_time': dateTime.toIso8601String(),
      'duration': duration,
      'venue': venue,
    };
  }
}

/// Performance analytics model
class PerformanceAnalytics {
  final String subject;
  final double averageScore;
  final double highestScore;
  final double lowestScore;
  final String trend; // 'up', 'down', 'stable'
  final List<MonthlyPerformance> monthlyData;

  PerformanceAnalytics({
    required this.subject,
    required this.averageScore,
    required this.highestScore,
    required this.lowestScore,
    required this.trend,
    required this.monthlyData,
  });

  factory PerformanceAnalytics.fromJson(Map<String, dynamic> json) {
    return PerformanceAnalytics(
      subject: json['subject'] ?? '',
      averageScore:
          double.tryParse(json['average_score']?.toString() ?? '0') ?? 0,
      highestScore:
          double.tryParse(json['highest_score']?.toString() ?? '0') ?? 0,
      lowestScore:
          double.tryParse(json['lowest_score']?.toString() ?? '0') ?? 0,
      trend: json['trend'] ?? 'stable',
      monthlyData: (json['monthly_data'] as List?)
              ?.map((e) => MonthlyPerformance.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class MonthlyPerformance {
  final String month;
  final double score;

  MonthlyPerformance({required this.month, required this.score});

  factory MonthlyPerformance.fromJson(Map<String, dynamic> json) {
    return MonthlyPerformance(
      month: json['month'] ?? '',
      score: double.tryParse(json['score']?.toString() ?? '0') ?? 0,
    );
  }
}