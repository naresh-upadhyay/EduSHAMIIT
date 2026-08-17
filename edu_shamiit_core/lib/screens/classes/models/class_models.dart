import 'package:flutter/material.dart';

class AcademicClassModel {
  final String id;
  final String name;
  final String code;
  final String stage;
  final String academicYear;
  final int displayOrder;
  final String status;
  final int sectionsCount;
  final int studentsCount;
  final int subjectsCount;
  final int classTeachersCount;
  final AcademicTeacherModel? primaryTeacher;
  final List<AcademicSectionModel> sections;
  final List<AcademicSubjectModel> subjects;
  final List<AcademicTeacherModel> classTeachers;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AcademicClassModel({
    required this.id,
    required this.name,
    required this.code,
    this.stage = 'Secondary',
    this.academicYear = '2026-27',
    this.displayOrder = 1,
    this.status = 'ACTIVE',
    this.sectionsCount = 0,
    this.studentsCount = 0,
    this.subjectsCount = 0,
    this.classTeachersCount = 0,
    this.primaryTeacher,
    this.sections = const [],
    this.subjects = const [],
    this.classTeachers = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  Color get badgeColor {
    // Curated distinctive pastel/gradient accent colors based on display order or name
    final hash = name.hashCode.abs();
    final colors = [
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEC4899), // Pink
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFEAB308), // Yellow
      const Color(0xFF6366F1), // Indigo
    ];
    return colors[hash % colors.length];
  }

  factory AcademicClassModel.fromJson(Map<String, dynamic> json) {
    List<AcademicSectionModel> secList = [];
    if (json['sections'] != null && json['sections'] is List) {
      secList = (json['sections'] as List)
          .map((s) => AcademicSectionModel.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    List<AcademicSubjectModel> subList = [];
    if (json['subjects'] != null && json['subjects'] is List) {
      subList = (json['subjects'] as List)
          .map((s) => AcademicSubjectModel.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    List<AcademicTeacherModel> teacherList = [];
    if (json['class_teachers'] != null && json['class_teachers'] is List) {
      teacherList = (json['class_teachers'] as List)
          .map((t) => AcademicTeacherModel.fromJson(t as Map<String, dynamic>))
          .toList();
    }

    AcademicTeacherModel? pTeacher;
    if (json['primary_teacher'] != null && json['primary_teacher'] is Map) {
      pTeacher = AcademicTeacherModel.fromJson(json['primary_teacher'] as Map<String, dynamic>);
    } else if (teacherList.isNotEmpty) {
      pTeacher = teacherList.first;
    }

    return AcademicClassModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      stage: json['stage']?.toString() ?? 'Secondary',
      academicYear: json['academic_year']?.toString() ?? '2026-27',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 1,
      status: json['status']?.toString() ?? 'ACTIVE',
      sectionsCount: (json['sections_count'] as num?)?.toInt() ?? secList.length,
      studentsCount: (json['students_count'] as num?)?.toInt() ?? 0,
      subjectsCount: (json['subjects_count'] as num?)?.toInt() ?? subList.length,
      classTeachersCount: (json['class_teachers_count'] as num?)?.toInt() ?? teacherList.length,
      primaryTeacher: pTeacher,
      sections: secList,
      subjects: subList,
      classTeachers: teacherList,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
}

class AcademicSectionModel {
  final String id;
  final String? classId;
  final String? className;
  final String? classCode;
  final String name;
  final String code;
  final int capacity;
  final String? roomNumber;
  final String academicYear;
  final String status;
  final int studentsCount;
  final int subjectsCount;
  final List<String> assignedSubjectIds;
  final AcademicTeacherModel? classTeacher;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AcademicSectionModel({
    required this.id,
    this.classId,
    this.className,
    this.classCode,
    required this.name,
    required this.code,
    this.capacity = 40,
    this.roomNumber,
    this.academicYear = '2026-27',
    this.status = 'ACTIVE',
    this.studentsCount = 0,
    this.subjectsCount = 0,
    this.assignedSubjectIds = const [],
    this.classTeacher,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory AcademicSectionModel.fromJson(Map<String, dynamic> json) {
    AcademicTeacherModel? teacher;
    if (json['class_teacher'] != null && json['class_teacher'] is Map) {
      teacher = AcademicTeacherModel.fromJson(json['class_teacher'] as Map<String, dynamic>);
    }

    List<String> subIds = [];
    if (json['assigned_subject_ids'] != null && json['assigned_subject_ids'] is List) {
      subIds = (json['assigned_subject_ids'] as List).map((e) => e.toString()).toList();
    }

    return AcademicSectionModel(
      id: json['id']?.toString() ?? '',
      classId: json['class_id']?.toString(),
      className: json['class_name']?.toString(),
      classCode: json['class_code']?.toString(),
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 40,
      roomNumber: json['room_number']?.toString(),
      academicYear: json['academic_year']?.toString() ?? '2026-27',
      status: json['status']?.toString() ?? 'ACTIVE',
      studentsCount: (json['students_count'] as num?)?.toInt() ?? 0,
      subjectsCount: (json['subjects_count'] as num?)?.toInt() ?? subIds.length,
      assignedSubjectIds: subIds,
      classTeacher: teacher,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
}

class AcademicSubjectModel {
  final String id;
  final String name;
  final String code;
  final String type; // Core, Elective, Language, Practical, Activity, Other
  final String? description;
  final int periodsPerWeek;
  final String color;
  final String icon;
  final String status;
  final int classesCount;
  final int sectionsCount;
  final bool isClassWide;
  final String? sectionId;
  final String? sectionNames;
  final List<String> assignedClassIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AcademicSubjectModel({
    required this.id,
    required this.name,
    required this.code,
    this.type = 'Core',
    this.description,
    this.periodsPerWeek = 5,
    this.color = '#4F46E5',
    this.icon = 'book',
    this.status = 'ACTIVE',
    this.classesCount = 0,
    this.sectionsCount = 0,
    this.isClassWide = true,
    this.sectionId,
    this.sectionNames,
    this.assignedClassIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  Color get subjectColor {
    try {
      final hex = color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF4F46E5);
    }
  }

  factory AcademicSubjectModel.fromJson(Map<String, dynamic> json) {
    List<String> clsIds = [];
    if (json['assigned_class_ids'] != null && json['assigned_class_ids'] is List) {
      clsIds = (json['assigned_class_ids'] as List).map((e) => e.toString()).toList();
    }

    return AcademicSubjectModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Core',
      description: json['description']?.toString(),
      periodsPerWeek: (json['periods_per_week'] as num?)?.toInt() ?? 5,
      color: json['color']?.toString() ?? '#4F46E5',
      icon: json['icon']?.toString() ?? 'book',
      status: json['status']?.toString() ?? 'ACTIVE',
      classesCount: (json['classes_count'] as num?)?.toInt() ?? clsIds.length,
      sectionsCount: (json['sections_count'] as num?)?.toInt() ?? 0,
      isClassWide: json['is_class_wide'] == true || json['section_id'] == null,
      sectionId: json['section_id']?.toString(),
      sectionNames: json['section_names']?.toString(),
      assignedClassIds: clsIds,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
}

class AcademicTeacherModel {
  final String id;
  final String fullName;
  final String? email;
  final String? employeeId;
  final String? department;
  final String? avatarUrl;
  final String status;
  final bool isPrimary;

  AcademicTeacherModel({
    required this.id,
    required this.fullName,
    this.email,
    this.employeeId,
    this.department,
    this.avatarUrl,
    this.status = 'ACTIVE',
    this.isPrimary = true,
  });

  factory AcademicTeacherModel.fromJson(Map<String, dynamic> json) {
    return AcademicTeacherModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Teacher',
      email: json['email']?.toString(),
      employeeId: json['employee_id']?.toString(),
      department: json['department']?.toString() ?? 'Academic',
      avatarUrl: json['avatar_url']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      isPrimary: json['is_primary'] == true,
    );
  }
}

class AcademicStudentModel {
  final String id;
  final String fullName;
  final String? email;
  final String? admissionNumber;
  final String? rollNumber;
  final String? avatarUrl;
  final String status;
  final String? currentClassId;
  final String? currentClassName;
  final String? currentSectionId;
  final String? currentSectionName;
  final bool isAssigned;

  AcademicStudentModel({
    required this.id,
    required this.fullName,
    this.email,
    this.admissionNumber,
    this.rollNumber,
    this.avatarUrl,
    this.status = 'ACTIVE',
    this.currentClassId,
    this.currentClassName,
    this.currentSectionId,
    this.currentSectionName,
    this.isAssigned = false,
  });

  String get assignmentSummary {
    if (!isAssigned || currentClassName == null) return 'Unassigned';
    if (currentSectionName != null) {
      return '$currentClassName • Section $currentSectionName';
    }
    return currentClassName!;
  }

  factory AcademicStudentModel.fromJson(Map<String, dynamic> json) {
    return AcademicStudentModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Student',
      email: json['email']?.toString(),
      admissionNumber: json['admission_number']?.toString(),
      rollNumber: json['roll_number']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      currentClassId: json['current_class_id']?.toString(),
      currentClassName: json['current_class_name']?.toString(),
      currentSectionId: json['current_section_id']?.toString(),
      currentSectionName: json['current_section_name']?.toString(),
      isAssigned: json['is_assigned'] == true,
    );
  }
}

class StudentConflictModel {
  final String studentId;
  final String studentName;
  final String? admissionNumber;
  final String? rollNumber;
  final String currentClassId;
  final String currentClassName;
  final String? currentSectionId;
  final String? currentSectionName;

  StudentConflictModel({
    required this.studentId,
    required this.studentName,
    this.admissionNumber,
    this.rollNumber,
    required this.currentClassId,
    required this.currentClassName,
    this.currentSectionId,
    this.currentSectionName,
  });

  String get locationString {
    if (currentSectionName != null && currentSectionName!.isNotEmpty) {
      return '$currentClassName-$currentSectionName';
    }
    return currentClassName;
  }

  factory StudentConflictModel.fromJson(Map<String, dynamic> json) {
    return StudentConflictModel(
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Student',
      admissionNumber: json['admission_number']?.toString(),
      rollNumber: json['roll_number']?.toString(),
      currentClassId: json['current_class_id']?.toString() ?? '',
      currentClassName: json['current_class_name']?.toString() ?? '',
      currentSectionId: json['current_section_id']?.toString(),
      currentSectionName: json['current_section_name']?.toString(),
    );
  }
}

class AcademicStatsModel {
  final int totalClasses;
  final int activeClasses;
  final int totalSections;
  final int totalSubjects;
  final int totalStudents;
  final int totalTeachers;
  final String academicYear;

  AcademicStatsModel({
    this.totalClasses = 0,
    this.activeClasses = 0,
    this.totalSections = 0,
    this.totalSubjects = 0,
    this.totalStudents = 0,
    this.totalTeachers = 0,
    this.academicYear = '2026-27',
  });

  factory AcademicStatsModel.fromJson(Map<String, dynamic> json) {
    return AcademicStatsModel(
      totalClasses: (json['total_classes'] as num?)?.toInt() ?? 0,
      activeClasses: (json['active_classes'] as num?)?.toInt() ?? 0,
      totalSections: (json['total_sections'] as num?)?.toInt() ?? 0,
      totalSubjects: (json['total_subjects'] as num?)?.toInt() ?? 0,
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      totalTeachers: (json['total_teachers'] as num?)?.toInt() ?? 0,
      academicYear: json['academic_year']?.toString() ?? '2026-27',
    );
  }
}
