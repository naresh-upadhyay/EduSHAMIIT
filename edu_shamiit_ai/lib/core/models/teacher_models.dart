import 'package:flutter/foundation.dart';
import '../providers/profile_provider.dart';

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _toDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

String _toStr(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.trim().isEmpty ? fallback : text;
}

bool _toBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (['true', '1', 'yes', 'y'].contains(normalized)) return true;
    if (['false', '0', 'no', 'n'].contains(normalized)) return false;
  }
  return fallback;
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final str = value.toString().trim();
  if (str.isEmpty) return null;
  
  String cleaned = str;
  if (cleaned.endsWith('+00')) {
    cleaned = cleaned.substring(0, cleaned.length - 3) + 'Z';
  } else if (cleaned.contains('+') && !cleaned.substring(cleaned.indexOf('+')).contains(':')) {
    final plusIndex = cleaned.lastIndexOf('+');
    final offset = cleaned.substring(plusIndex + 1);
    if (offset.length == 2) {
      cleaned = cleaned.substring(0, plusIndex) + '+$offset:00';
    } else if (offset.length == 4) {
      cleaned = cleaned.substring(0, plusIndex) + '+${offset.substring(0, 2)}:${offset.substring(2)}';
    }
  } else if (cleaned.contains('-') && cleaned.lastIndexOf('-') > cleaned.lastIndexOf(':') && !cleaned.substring(cleaned.lastIndexOf('-')).contains(':')) {
    final minusIndex = cleaned.lastIndexOf('-');
    final offset = cleaned.substring(minusIndex + 1);
    if (offset.length == 2) {
      cleaned = cleaned.substring(0, minusIndex) + '-$offset:00';
    } else if (offset.length == 4) {
      cleaned = cleaned.substring(0, minusIndex) + '-${offset.substring(0, 2)}:${offset.substring(2)}';
    }
  }
  cleaned = cleaned.replaceAll(' ', 'T');
  return DateTime.tryParse(cleaned) ?? DateTime.tryParse(str);
}

String _normalizeTeacherRoute(dynamic value, {String fallback = '/teacher/dashboard'}) {
  var route = _toStr(value, fallback: fallback);
  if (route.isEmpty) return fallback;
  if (!route.startsWith('/')) route = '/$route';

  const aliases = {
    '/dashboard': '/teacher/dashboard',
    '/myclasses': '/teacher/my-classes',
    '/attendance': '/teacher/attendance',
    '/homework': '/teacher/homework',
    '/results': '/teacher/gradebook',
    '/gradebook': '/teacher/gradebook',
    '/students': '/teacher/student-directory',
    '/student-directory': '/teacher/student-directory',
    '/timetable': '/teacher/timetable',
    '/notices': '/teacher/notices',
    '/leave': '/teacher/leave',
    '/liveclasses': '/teacher/live-classes',
    '/live-classes': '/teacher/live-classes',
    '/materials': '/teacher/materials',
    '/salary': '/teacher/salary',
    '/profile': '/teacher/profile',
    '/notifications': '/teacher/notifications',
  };

  return aliases[route] ?? route;
}

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

  // New personal info
  final String gender;
  final String dateOfBirth;
  final String bloodGroup;
  final String nationality;
  final String religion;
  final String category;
  final String address;

  // New guardian/mother details
  final String fatherName;
  final String fatherOccupation;
  final String fatherPhone;
  final String motherName;
  final String motherOccupation;
  final String motherPhone;
  final String localGuardian;

  // Documents
  final List<DocumentModel> documents;

  const TeacherProfile({
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
    this.gender = '',
    this.dateOfBirth = '',
    this.bloodGroup = '',
    this.nationality = '',
    this.religion = '',
    this.category = '',
    this.address = '',
    this.fatherName = '',
    this.fatherOccupation = '',
    this.fatherPhone = '',
    this.motherName = '',
    this.motherOccupation = '',
    this.motherPhone = '',
    this.localGuardian = '',
    this.documents = const [],
  });

  factory TeacherProfile.fromJson(Map<String, dynamic> json) {
    final dynamic classesRaw =
        json['classes'] ?? json['assigned_classes'] ?? json['class'];
    final List<String> classList = classesRaw is List
        ? classesRaw.map((e) => e.toString()).toList()
        : classesRaw != null && classesRaw.toString().isNotEmpty
            ? [classesRaw.toString()]
            : <String>[];

    return TeacherProfile(
      id: (json['id'] ?? json['teacher_id'] ?? '').toString(),
      userId: (json['user_id'] ?? json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? json['name'] ?? '').toString(),
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      profileImageUrl:
          (json['profile_image_url'] ?? json['avatar_url']) as String?,
      subject: (json['subject'] ?? json['primary_subject'] ?? '').toString(),
      specialization: json['specialization'] as String?,
      classes: classList,
      qualification: json['qualification'] as String? ?? '',
      experienceYears: _toInt(json['experience_years']),
      joiningDate: json['joining_date'] != null
          ? DateTime.parse(json['joining_date'] as String) 
          : null,
      xpPoints: _toInt(json['xp_points']),
      streak: _toInt(json['streak'] ?? json['learning_streak']),
      bio: json['bio'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String) 
          : DateTime.now(),
      gender: _toStr(json['gender']),
      dateOfBirth: _toStr(json['date_of_birth']),
      bloodGroup: _toStr(json['blood_group']),
      nationality: _toStr(json['nationality']),
      religion: _toStr(json['religion']),
      category: _toStr(json['category']),
      address: _toStr(json['address']),
      fatherName: _toStr(json['father_name']),
      fatherOccupation: _toStr(json['father_occupation']),
      fatherPhone: _toStr(json['father_phone']),
      motherName: _toStr(json['mother_name']),
      motherOccupation: _toStr(json['mother_occupation']),
      motherPhone: _toStr(json['mother_phone']),
      localGuardian: _toStr(json['local_guardian']),
      documents: (json['documents'] as List<dynamic>?)
              ?.map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
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
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'blood_group': bloodGroup,
      'nationality': nationality,
      'religion': religion,
      'category': category,
      'address': address,
      'father_name': fatherName,
      'father_occupation': fatherOccupation,
      'father_phone': fatherPhone,
      'mother_name': motherName,
      'mother_occupation': motherOccupation,
      'mother_phone': motherPhone,
      'local_guardian': localGuardian,
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
    String? gender,
    String? dateOfBirth,
    String? bloodGroup,
    String? nationality,
    String? religion,
    String? category,
    String? address,
    String? fatherName,
    String? fatherOccupation,
    String? fatherPhone,
    String? motherName,
    String? motherOccupation,
    String? motherPhone,
    String? localGuardian,
    List<DocumentModel>? documents,
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
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      nationality: nationality ?? this.nationality,
      religion: religion ?? this.religion,
      category: category ?? this.category,
      address: address ?? this.address,
      fatherName: fatherName ?? this.fatherName,
      fatherOccupation: fatherOccupation ?? this.fatherOccupation,
      fatherPhone: fatherPhone ?? this.fatherPhone,
      motherName: motherName ?? this.motherName,
      motherOccupation: motherOccupation ?? this.motherOccupation,
      motherPhone: motherPhone ?? this.motherPhone,
      localGuardian: localGuardian ?? this.localGuardian,
      documents: documents ?? this.documents,
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

  const TeacherDashboard({
    required this.user,
    required this.stats,
    required this.todaySchedule,
    required this.pendingTasks,
    required this.quickAccess,
  });

  factory TeacherDashboard.fromJson(Map<String, dynamic> json) {
    final userJson = (json['user'] ?? json['teacher'] ?? json['profile'])
        as Map<String, dynamic>?;
    final scheduleRaw =
        (json['today_schedule'] ?? json['schedule']) as List<dynamic>?;
    final quickAccessRaw = (json['quick_access'] as List<dynamic>?);

    return TeacherDashboard(
      user: TeacherProfile.fromJson(userJson ?? const {}),
      stats: TeacherStats.fromJson(
          (json['stats'] as Map<String, dynamic>?) ?? const {}),
      todaySchedule: scheduleRaw
              ?.map((item) => TeacherScheduleItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      pendingTasks: (json['pending_tasks'] as List<dynamic>?)
              ?.map((item) => TeacherTask.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      quickAccess: quickAccessRaw
              ?.map((item) => QuickAccessItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [
            QuickAccessItem(title: 'My Classes', icon: '📚', route: '/teacher/my-classes'),
            QuickAccessItem(title: 'Attendance', icon: '📋', route: '/teacher/attendance'),
            QuickAccessItem(title: 'Homework', icon: '📝', route: '/teacher/homework'),
            QuickAccessItem(title: 'Exams', icon: '📝', route: '/teacher/exams'),
            QuickAccessItem(title: 'Gradebook', icon: '📊', route: '/teacher/gradebook'),
            QuickAccessItem(title: 'Students', icon: '👥', route: '/teacher/student-directory'),
            QuickAccessItem(title: 'Timetable', icon: '🗓️', route: '/teacher/timetable'),
            QuickAccessItem(title: 'Notices', icon: '📢', route: '/teacher/notices'),
            QuickAccessItem(title: 'Leave', icon: '🏖️', route: '/teacher/leave'),
            QuickAccessItem(title: 'Live Class', icon: '🎥', route: '/teacher/live-classes'),
            QuickAccessItem(title: 'Materials', icon: '📁', route: '/teacher/materials'),
            QuickAccessItem(title: 'Salary', icon: '💰', route: '/teacher/salary'),
          ],
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

  const TeacherStats({
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
      attendancePct: _toDouble(json['attendance_pct']),
      avgScore: _toDouble(json['avg_score']),
      classesCount: _toInt(json['classes_count'] ?? json['total_classes']),
      studentsCount: _toInt(json['students_count'] ?? json['total_students']),
      totalHomework: _toInt(json['total_homework']),
      pendingGrading: _toInt(json['pending_grading'] ?? json['pending_tasks']),
      avgCompletionRate:
          (json['avg_completion_rate'] as num?)?.toDouble(),
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

  const TeacherScheduleItem({
    required this.subject,
    required this.icon,
    required this.class_,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.isNow,
  });

  factory TeacherScheduleItem.fromJson(Map<String, dynamic> json) {
    final subjectMap = json['subjects'] as Map<String, dynamic>?;

    return TeacherScheduleItem(
      subject: (json['subject'] ?? subjectMap?['name'] ?? '').toString(),
      icon: (json['icon'] ?? subjectMap?['icon'] ?? '📘').toString(),
      class_: json['class'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      room: (json['room'] ?? json['room_number'] ?? '').toString(),
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

  const TeacherTask({
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

  const QuickAccessItem({
    required this.title,
    required this.icon,
    required this.route,
  });

  factory QuickAccessItem.fromJson(Map<String, dynamic> json) {
    return QuickAccessItem(
      title: _toStr(json['title']),
      icon: _toStr(json['icon']),
      route: _normalizeTeacherRoute(
        json['route'] ?? json['path'] ?? json['url'],
        fallback: '/teacher/dashboard',
      ),
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
  final int? classRank;
  final int? classTotal;

  const StudentDirectoryEntry({
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
    this.classRank,
    this.classTotal,
  });

  factory StudentDirectoryEntry.fromJson(Map<String, dynamic> json) {
    return StudentDirectoryEntry(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['full_name'] ?? '').toString(),
      rollNo: (json['roll_no'] ?? json['roll_number'] ?? '').toString(),
      class_: _toStr(json['class'] ?? json['class_name']),
      section: _toStr(json['section']).isEmpty ? null : _toStr(json['section']),
      email: _toStr(json['email']).isEmpty ? null : _toStr(json['email']),
      phone: _toStr(json['phone']).isEmpty ? null : _toStr(json['phone']),
      dateOfBirth: _toDateTime(json['date_of_birth']),
      parentName: _toStr(json['parent_name'] ?? json['father_name']).isEmpty
          ? null
          : _toStr(json['parent_name'] ?? json['father_name']),
      parentPhone: _toStr(json['parent_phone'] ?? json['father_phone']).isEmpty
          ? null
          : _toStr(json['parent_phone'] ?? json['father_phone']),
      attendancePct: json['attendance_pct'] == null
          ? null
          : _toDouble(json['attendance_pct']),
      avgMarks: json['avg_marks'] == null ? null : _toDouble(json['avg_marks']),
      profileImageUrl: _toStr(json['profile_image_url'] ?? json['avatar_url']).isEmpty
          ? null
          : _toStr(json['profile_image_url'] ?? json['avatar_url']),
      classRank: json['class_rank'] == null ? null : _toInt(json['class_rank']),
      classTotal: json['class_total'] == null ? null : _toInt(json['class_total']),
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
      'class_rank': classRank,
      'class_total': classTotal,
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

  const TeacherAttendanceRecord({
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
      id: _toStr(json['id']),
      studentId: _toStr(json['student_id']),
      studentName: _toStr(json['student_name']),
      rollNo: _toStr(json['roll_no']),
      class_: _toStr(json['class'] ?? json['class_name']),
      date: _toDateTime(json['date']) ?? DateTime.now(),
      status: _toStr(json['status'], fallback: 'absent'),
      period: _toStr(json['period']).isEmpty ? null : _toStr(json['period']),
      markedBy: _toStr(json['marked_by']).isEmpty ? null : _toStr(json['marked_by']),
      createdAt: _toDateTime(json['created_at']),
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

  const TeacherHomeworkAssignment({
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
      id: _toStr(json['id']),
      title: _toStr(json['title']),
      description: _toStr(json['description']),
      class_: _toStr(json['class'] ?? json['class_name']),
      subject: _toStr(json['subject']),
      dueDate: _toDateTime(json['due_date']) ?? DateTime.now(),
      status: _toStr(json['status'], fallback: 'active'),
      submittedCount: _toInt(json['submitted_count']),
      totalCount: _toInt(json['total_count']),
      attachmentUrl: _toStr(json['attachment_url']).isEmpty ? null : _toStr(json['attachment_url']),
      maxMarks: json['max_marks'] == null ? null : _toInt(json['max_marks']),
      instructions: _toStr(json['instructions']).isEmpty ? null : _toStr(json['instructions']),
      createdBy: _toStr(json['created_by']).isEmpty ? null : _toStr(json['created_by']),
      createdAt: _toDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _toDateTime(json['updated_at']) ?? DateTime.now(),
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

  const HomeworkSubmission({
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
    final profilesMap = json['profiles'] as Map<String, dynamic>?;
    
    return HomeworkSubmission(
      id: _toStr(json['id']),
      homeworkId: _toStr(json['homework_id']),
      studentId: _toStr(json['student_id']),
      studentName: _toStr(json['student_name'] ?? profilesMap?['full_name'] ?? profilesMap?['name']),
      class_: _toStr(json['class'] ?? json['class_name']),
      submissionText:
          _toStr(json['submission_text']).isEmpty ? null : _toStr(json['submission_text']),
      attachmentUrl:
          _toStr(json['attachment_url']).isEmpty ? null : _toStr(json['attachment_url']),
      submittedAt: _toDateTime(json['submitted_at']) ?? DateTime.now(),
      marksObtained:
          (json['marks_obtained'] ?? json['marks']) == null ? null : _toDouble(json['marks_obtained'] ?? json['marks']),
      feedback: _toStr(json['feedback'] ?? json['teacher_remarks']).isEmpty ? null : _toStr(json['feedback'] ?? json['teacher_remarks']),
      status: _toStr(json['status'], fallback: 'submitted'),
      gradedBy: _toStr(json['graded_by']).isEmpty ? null : _toStr(json['graded_by']),
      gradedAt: _toDateTime(json['graded_at']),
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

  const TeacherExam({
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
      id: (json['id'] ?? json['exam_id'] ?? '').toString(),
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      class_: (json['class'] ?? json['target_class'] ?? '').toString(),
      examDate: json['exam_date'] != null 
          ? DateTime.parse(json['exam_date'] as String) 
          : DateTime.now(),
      duration: json['duration'] as String? ?? '',
      totalMarks: json['total_marks'] as int? ?? 0,
      syllabus: json['syllabus'] as String?,
      examType: (json['exam_type'] ?? json['exam_category'] ?? 'term').toString(),
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

  const GradeRecord({
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
      id: _toStr(json['id']),
      studentId: _toStr(json['student_id']),
      studentName: _toStr(json['student_name']),
      rollNo: _toStr(json['roll_no']),
      class_: _toStr(json['class'] ?? json['class_name']),
      subject: _toStr(json['subject']),
      assessmentType: _toStr(json['assessment_type']),
      assessmentName: _toStr(json['assessment_name']),
      marksObtained: _toDouble(json['marks_obtained']),
      totalMarks: _toInt(json['total_marks']),
      grade: _toStr(json['grade']),
      remarks: _toStr(json['remarks']).isEmpty ? null : _toStr(json['remarks']),
      gradedAt: _toDateTime(json['graded_at']),
      gradedBy: _toStr(json['graded_by']).isEmpty ? null : _toStr(json['graded_by']),
      trend: _toStr(json['trend'], fallback: 'stable'),
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
  final String? subjectId;
  final String class_;
  final String? roomNumber;
  final String? teacherId;
  final String? teacherName;
  final String? platform;
  final String? meetingLink;
  final String? status;

  const TeacherTimetablePeriod({
    required this.id,
    required this.dayOfWeek,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    required this.subject,
    this.subjectId,
    required this.class_,
    this.roomNumber,
    this.teacherId,
    this.teacherName,
    this.platform,
    this.meetingLink,
    this.status,
  });

  factory TeacherTimetablePeriod.fromJson(Map<String, dynamic> json) {
    return TeacherTimetablePeriod(
      id: _toStr(json['id']),
      dayOfWeek: _toStr(json['day_of_week'] ?? json['day']),
      periodNumber: _toStr(json['period_number'] ?? json['period']),
      startTime: _toStr(json['start_time']),
      endTime: _toStr(json['end_time']),
      subject: _toStr(json['subject']),
      subjectId: json['subject_id'] != null ? _toStr(json['subject_id']) : null,
      class_: _toStr(json['class'] ?? json['class_name']),
      roomNumber:
          _toStr(json['room_number']).isEmpty ? null : _toStr(json['room_number']),
      teacherId: _toStr(json['teacher_id']).isEmpty ? null : _toStr(json['teacher_id']),
      teacherName:
          _toStr(json['teacher_name']).isEmpty ? null : _toStr(json['teacher_name']),
      platform: json['platform']?.toString(),
      meetingLink: json['meeting_link']?.toString(),
      status: json['status']?.toString(),
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
      'subject_id': subjectId,
      'class': class_,
      'room_number': roomNumber,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'platform': platform,
      'meeting_link': meetingLink,
      'status': status,
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

  const TeacherLeave({
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
  final String platform; // Zoom, Google Meet, YouTube, In-App

  const TeacherLiveClass({
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
    this.platform = 'In-App',
  });

  factory TeacherLiveClass.fromJson(Map<String, dynamic> json) {
    return TeacherLiveClass(
      id: (json['id'] ?? json['live_class_id'] ?? '').toString(),
      title: json['title'] as String? ?? '',
      class_: (json['class'] ?? json['target_class'] ?? '').toString(),
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
      platform: json['platform'] as String? ?? 'In-App',
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
      'platform': platform,
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

  const TeachingMaterial({
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
    final attachments = json['attachment_urls'];
    String? attachmentUrl;
    if (attachments is List && attachments.isNotEmpty) {
      attachmentUrl = attachments.first.toString();
    }

    return TeachingMaterial(
      id: (json['id'] ?? json['material_id'] ?? '').toString(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      class_: (json['class'] ?? json['target_class'] ?? '').toString(),
      subject: json['subject'] as String? ?? '',
      materialType: (json['material_type'] ?? json['type'] ?? '').toString(),
      fileUrl: (json['file_url'] ?? attachmentUrl) as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      fileSize: json['file_size'] as int?,
      uploadedBy: json['uploaded_by'] as String? ?? '',
      uploadedAt: (json['uploaded_at'] ?? json['created_at']) != null
          ? DateTime.parse((json['uploaded_at'] ?? json['created_at']) as String)
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
  final double specialAllowance;
  final double pfDeduction;
  final double tds;
  final double professionalTax;
  final double miscellaneous;
  final double hra;
  final double da;
  final double advanceDeduction;

  const SalarySlip({
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
    this.specialAllowance = 0.0,
    this.pfDeduction = 0.0,
    this.tds = 0.0,
    this.professionalTax = 0.0,
    this.miscellaneous = 0.0,
    this.hra = 0.0,
    this.da = 0.0,
    this.advanceDeduction = 0.0,
  });

  factory SalarySlip.fromJson(Map<String, dynamic> json) {
    return SalarySlip(
      id: (json['id'] ?? '').toString(),
      teacherId: (json['teacher_id'] ?? '').toString(),
      teacherName: (json['teacher_name'] ?? '').toString(),
      month: _toInt(json['month'], fallback: 1),
      year: _toInt(json['year'], fallback: DateTime.now().year),
      basicSalary: (json['basic_salary'] ?? json['basic_pay'] as num?)?.toDouble() ?? 0.0,
      allowances: (json['allowances'] as num?)?.toDouble() ?? 0.0,
      deductions: (json['deductions'] as num?)?.toDouble() ?? 0.0,
      netSalary: (json['net_salary'] ?? json['net_pay'] ?? json['amount'] as num?)?.toDouble() ?? 0.0,
      paidAt: json['paid_at'] != null 
          ? DateTime.parse(json['paid_at'] as String) 
          : null,
      status: json['status'] as String? ?? 'pending',
      slipUrl: json['slip_url'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      specialAllowance: (json['special_allowance'] as num?)?.toDouble() ?? 0.0,
      pfDeduction: (json['pf_deduction'] as num?)?.toDouble() ?? 0.0,
      tds: (json['tds'] as num?)?.toDouble() ?? 0.0,
      professionalTax: (json['professional_tax'] as num?)?.toDouble() ?? 0.0,
      miscellaneous: (json['miscellaneous'] as num?)?.toDouble() ?? 0.0,
      hra: (json['hra'] as num?)?.toDouble() ?? 0.0,
      da: (json['da'] as num?)?.toDouble() ?? 0.0,
      advanceDeduction: (json['advance_deduction'] as num?)?.toDouble() ?? 0.0,
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
      'special_allowance': specialAllowance,
      'pf_deduction': pfDeduction,
      'tds': tds,
      'professional_tax': professionalTax,
      'miscellaneous': miscellaneous,
      'hra': hra,
      'da': da,
      'advance_deduction': advanceDeduction,
    };
  }
}

/// Salary advance request model
@immutable
class SalaryAdvance {
  final String id;
  final String schoolId;
  final String teacherId;
  final double amount;
  final String purposeType;
  final String? reason;
  final String status; // pending, approved, rejected
  final int month;
  final int year;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SalaryAdvance({
    required this.id,
    required this.schoolId,
    required this.teacherId,
    required this.amount,
    required this.purposeType,
    this.reason,
    required this.status,
    required this.month,
    required this.year,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SalaryAdvance.fromJson(Map<String, dynamic> json) {
    return SalaryAdvance(
      id: (json['id'] ?? '').toString(),
      schoolId: (json['school_id'] ?? '').toString(),
      teacherId: (json['teacher_id'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      purposeType: json['purpose_type'] as String? ?? 'other',
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'pending',
      month: _toInt(json['month'], fallback: 1),
      year: _toInt(json['year'], fallback: DateTime.now().year),
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
      'school_id': schoolId,
      'teacher_id': teacherId,
      'amount': amount,
      'purpose_type': purposeType,
      'reason': reason,
      'status': status,
      'month': month,
      'year': year,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
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

  const PaperQuestion({
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

class TeacherNotice {
  final String id;
  final String title;
  final String content;
  final String noticeType; // general, urgent, event, announcement
  final String? targetAudience; // all, teachers, students, parents
  final DateTime publishDate;
  final DateTime? expiryDate;
  final String status; // draft, published, scheduled
  final String createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? attachmentUrl;
  final bool isUrgent;
  final DateTime? scheduledAt;
  final List<String>? targetClasses;
  final int registrationCount;

  const TeacherNotice({
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
    this.attachmentUrl,
    required this.isUrgent,
    this.scheduledAt,
    this.targetClasses,
    this.registrationCount = 0,
  });

  factory TeacherNotice.fromJson(Map<String, dynamic> json) {
    final rawType = (json['notice_type'] ?? json['category'] ?? '').toString();
    final typeLower = rawType.toLowerCase();
    final category = typeLower == 'announcement' ? 'general' : typeLower;

    return TeacherNotice(
      id: (json['id'] ?? json['notice_id'] ?? '').toString(),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      noticeType: category.isNotEmpty ? category : 'general',
      targetAudience: json['target_audience'] as String?,
      publishDate: json['publish_date'] != null 
          ? DateTime.parse(json['publish_date'] as String) 
          : (json['published_at'] != null 
              ? DateTime.parse(json['published_at'] as String) 
              : (json['created_at'] != null 
                  ? DateTime.parse(json['created_at'] as String) 
                  : DateTime.now())),
      expiryDate: json['expiry_date'] != null 
          ? DateTime.parse(json['expiry_date'] as String) 
          : (json['expires_at'] != null 
              ? DateTime.parse(json['expires_at'] as String) 
              : null),
      status: json['status'] as String? ?? 'draft',
      createdBy: (json['created_by'] ?? json['author_id'] ?? '').toString(),
      createdByName: (json['created_by_name'] ?? json['author_name']) as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : DateTime.now(),
      attachmentUrl: json['attachment_url'] as String?,
      isUrgent: json['is_urgent'] as bool? ?? (json['category']?.toString().toLowerCase() == 'urgent'),
      scheduledAt: json['scheduled_at'] != null 
          ? DateTime.parse(json['scheduled_at'] as String) 
          : null,
      targetClasses: json['target_classes'] != null 
          ? List<String>.from(json['target_classes'] as List) 
          : null,
      registrationCount: json['registration_count'] ?? 0,
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
      'attachment_url': attachmentUrl,
      'is_urgent': isUrgent,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'target_classes': targetClasses,
      'registration_count': registrationCount,
    };
  }
}

/// Teacher notification model
@immutable
class TeacherNotification {
  final String id;
  final String title;
  final String message;
  final String type; // general, homework, attendance, exam, system, message
  final bool isRead;
  final String? actionUrl;
  final String? referenceId;
  final DateTime createdAt;
  final DateTime? readAt;

  const TeacherNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.actionUrl,
    this.referenceId,
    required this.createdAt,
    this.readAt,
  });

  factory TeacherNotification.fromJson(Map<String, dynamic> json) {
    return TeacherNotification(
      id: _toStr(json['id']),
      title: _toStr(json['title']),
      message: (json['message'] ?? json['content'] ?? json['body'] ?? '').toString(),
      type: _toStr(json['type']),
      isRead: _toBool(json['is_read']),
      actionUrl: _toStr(json['action_url']).isEmpty ? null : _toStr(json['action_url']),
      referenceId: json['reference_id'] as String?,
      createdAt: _toDateTime(json['created_at']) ?? DateTime.now(),
      readAt: _toDateTime(json['read_at']),
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
      'reference_id': referenceId,
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

  const TeacherMyClass({
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
    final classValue = (json['class'] ?? json['name'] ?? '').toString();
    return TeacherMyClass(
      id: (json['id'] ?? classValue).toString(),
      name: classValue,
      section: (json['section'] ?? '').toString(),
      classTeacher: json['class_teacher'] as String?,
      studentCount: _toInt(json['student_count']),
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

/// Teacher Subject model
@immutable
class TeacherSubject {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final String? className;

  const TeacherSubject({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.className,
  });

  factory TeacherSubject.fromJson(Map<String, dynamic> json) {
    return TeacherSubject(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      icon: json['icon']?.toString(),
      color: json['color']?.toString(),
      className: json['class']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'class': className,
    };
  }
}