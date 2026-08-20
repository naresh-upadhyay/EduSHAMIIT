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

class AcademicClassDetailModel {
  final String id;
  final String name;
  final String code;
  final String stage;
  final String academicYear;
  final String status;
  final int totalSections;
  final int totalStudents;
  final int totalCapacity;
  final int coreSubjectsCount;
  final int optionalSubjectsCount;
  final int totalSubjectsCount;
  final AcademicTeacherModel? classTeacher;
  final List<AcademicSectionModel> sections;
  final List<ClassSubjectDetailModel> subjects;

  AcademicClassDetailModel({
    required this.id,
    required this.name,
    required this.code,
    this.stage = 'Secondary',
    this.academicYear = '2026-27',
    this.status = '',
    this.totalSections = 0,
    this.totalStudents = 0,
    this.totalCapacity = 0,
    this.coreSubjectsCount = 0,
    this.optionalSubjectsCount = 0,
    this.totalSubjectsCount = 0,
    this.classTeacher,
    this.sections = const [],
    this.subjects = const [],
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  double get capacityPercentage =>
      totalCapacity > 0 ? ((totalStudents / totalCapacity) * 100).clamp(0.0, 100.0) : 0.0;

  factory AcademicClassDetailModel.fromJson(Map<String, dynamic> json) {
    AcademicTeacherModel? teacher;
    if (json['class_teacher'] != null && json['class_teacher'] is Map) {
      teacher = AcademicTeacherModel.fromJson(json['class_teacher'] as Map<String, dynamic>);
    }

    List<AcademicSectionModel> secList = [];
    if (json['sections'] != null && json['sections'] is List) {
      secList = (json['sections'] as List)
          .map((s) => AcademicSectionModel.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    List<ClassSubjectDetailModel> subList = [];
    if (json['subjects'] != null && json['subjects'] is List) {
      subList = (json['subjects'] as List)
          .map((s) => ClassSubjectDetailModel.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    return AcademicClassDetailModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      stage: json['stage']?.toString() ?? 'Secondary',
      academicYear: json['academic_year']?.toString() ?? '2026-27',
      status: json['status']?.toString() ?? '',
      totalSections: (json['total_sections'] as num?)?.toInt() ?? secList.length,
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      totalCapacity: (json['total_capacity'] as num?)?.toInt() ?? 0,
      coreSubjectsCount: (json['core_subjects_count'] as num?)?.toInt() ?? 0,
      optionalSubjectsCount: (json['optional_subjects_count'] as num?)?.toInt() ?? 0,
      totalSubjectsCount: (json['total_subjects_count'] as num?)?.toInt() ?? subList.length,
      classTeacher: teacher,
      sections: secList,
      subjects: subList,
    );
  }
}

class ClassSubjectDetailModel {
  final String id;
  final String name;
  final String code;
  final String type;
  final String offeredAs;
  final int periodsPerWeek;
  final String status;
  final int assignedSectionsCount;
  final List<TeacherSectionAssignmentModel> assignedTeachers;

  ClassSubjectDetailModel({
    required this.id,
    required this.name,
    required this.code,
    this.type = 'Core',
    this.offeredAs = 'All Sections',
    this.periodsPerWeek = 5,
    this.status = 'ACTIVE',
    this.assignedSectionsCount = 0,
    this.assignedTeachers = const [],
  });

  bool get isCore => type.toLowerCase() == 'core';
  bool get isOptional => type.toLowerCase() == 'optional' || type.toLowerCase() == 'elective';

  factory ClassSubjectDetailModel.fromJson(Map<String, dynamic> json) {
    List<TeacherSectionAssignmentModel> teachers = [];
    if (json['assigned_teachers'] != null && json['assigned_teachers'] is List) {
      teachers = (json['assigned_teachers'] as List)
          .map((t) => TeacherSectionAssignmentModel.fromJson(t as Map<String, dynamic>))
          .toList();
    }

    return ClassSubjectDetailModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Core',
      offeredAs: json['offered_as']?.toString() ??
          (json['section_names']?.toString().isNotEmpty == true
              ? json['section_names'].toString()
              : (json['type'] == 'Core' ? 'All Sections' : 'Offered by Section')),
      periodsPerWeek: (json['periods_per_week'] as num?)?.toInt() ?? 5,
      status: json['status']?.toString() ?? 'ACTIVE',
      assignedSectionsCount: (json['assigned_sections_count'] as num?)?.toInt() ?? teachers.length,
      assignedTeachers: teachers,
    );
  }
}

class TeacherSectionAssignmentModel {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? sectionId;
  final String? sectionName;

  TeacherSectionAssignmentModel({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.sectionId,
    this.sectionName,
  });

  factory TeacherSectionAssignmentModel.fromJson(Map<String, dynamic> json) {
    return TeacherSectionAssignmentModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      sectionId: json['section_id']?.toString(),
      sectionName: json['section_name']?.toString(),
    );
  }
}

class SectionsOverviewStatsModel {
  final int totalSections;
  final int activeSections;
  final int inactiveSections;
  final int totalStudents;
  final double avgStudentsPerSection;
  final List<SectionByClassModel> sectionsByClass;
  final List<BuildingSectionsModel> buildingsOverview;

  SectionsOverviewStatsModel({
    this.totalSections = 0,
    this.activeSections = 0,
    this.inactiveSections = 0,
    this.totalStudents = 0,
    this.avgStudentsPerSection = 0.0,
    this.sectionsByClass = const [],
    this.buildingsOverview = const [],
  });

  factory SectionsOverviewStatsModel.fromJson(Map<String, dynamic> json) {
    List<SectionByClassModel> byClass = [];
    if (json['sections_by_class'] != null && json['sections_by_class'] is List) {
      byClass = (json['sections_by_class'] as List)
          .map((c) => SectionByClassModel.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    List<BuildingSectionsModel> bList = [];
    if (json['buildings_overview'] != null && json['buildings_overview'] is List) {
      bList = (json['buildings_overview'] as List)
          .map((b) => BuildingSectionsModel.fromJson(b as Map<String, dynamic>))
          .toList();
    }

    return SectionsOverviewStatsModel(
      totalSections: (json['total_sections'] as num?)?.toInt() ?? 0,
      activeSections: (json['active_sections'] as num?)?.toInt() ?? 0,
      inactiveSections: (json['inactive_sections'] as num?)?.toInt() ?? 0,
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      avgStudentsPerSection: (json['avg_students_per_section'] as num?)?.toDouble() ?? 0.0,
      sectionsByClass: byClass,
      buildingsOverview: bList,
    );
  }
}

class SectionByClassModel {
  final String classId;
  final String className;
  final int sectionsCount;
  final double percentage;

  SectionByClassModel({
    required this.classId,
    required this.className,
    this.sectionsCount = 0,
    this.percentage = 0.0,
  });

  factory SectionByClassModel.fromJson(Map<String, dynamic> json) {
    return SectionByClassModel(
      classId: json['class_id']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
      sectionsCount: (json['sections_count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BuildingSectionsModel {
  final String buildingName;
  final int sectionsCount;
  final double percentage;

  BuildingSectionsModel({
    required this.buildingName,
    this.sectionsCount = 0,
    this.percentage = 0.0,
  });

  factory BuildingSectionsModel.fromJson(Map<String, dynamic> json) {
    return BuildingSectionsModel(
      buildingName: json['building_name']?.toString() ?? json['building']?.toString() ?? json['name']?.toString() ?? '',
      sectionsCount: (json['sections_count'] as num?)?.toInt() ?? (json['count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
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
  final String? roomId;
  final String? roomName;
  final String? building;
  final String academicYear;
  final String status;
  final int studentsCount;
  final int subjectsCount;
  final int optionalSubjectsCount;
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
    this.roomId,
    this.roomName,
    this.building,
    this.academicYear = '2026-27',
    this.status = 'ACTIVE',
    this.studentsCount = 0,
    this.subjectsCount = 0,
    this.optionalSubjectsCount = 0,
    this.assignedSubjectIds = const [],
    this.classTeacher,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  String get effectiveRoomDisplay {
    if (roomName != null && roomName!.isNotEmpty) return roomName!;
    if (roomNumber != null && roomNumber!.isNotEmpty) return roomNumber!;
    return 'Not Assigned';
  }

  factory AcademicSectionModel.fromJson(Map<String, dynamic> json) {
    AcademicTeacherModel? teacher;
    if (json['class_teacher'] != null && json['class_teacher'] is Map) {
      teacher = AcademicTeacherModel.fromJson(json['class_teacher'] as Map<String, dynamic>);
    } else if (json['section_teacher'] != null && json['section_teacher'] is Map) {
      teacher = AcademicTeacherModel.fromJson(json['section_teacher'] as Map<String, dynamic>);
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
      roomId: json['room_id']?.toString(),
      roomName: json['room_name']?.toString(),
      building: json['building']?.toString(),
      academicYear: json['academic_year']?.toString() ?? '2026-27',
      status: json['status']?.toString() ?? 'ACTIVE',
      studentsCount: (json['students_count'] as num?)?.toInt() ?? 0,
      subjectsCount: (json['subjects_count'] as num?)?.toInt() ?? subIds.length,
      optionalSubjectsCount: (json['optional_subjects_count'] as num?)?.toInt() ?? 0,
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
  final bool isOptional;
  final int classesCount;
  final int sectionsCount;
  final int teachersCount;
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
    this.isOptional = false,
    this.classesCount = 0,
    this.sectionsCount = 0,
    this.teachersCount = 0,
    this.isClassWide = true,
    this.sectionId,
    this.sectionNames,
    this.assignedClassIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isCore => type.toLowerCase().contains('core');
  bool get isElective => type.toLowerCase().contains('elec') || type.toLowerCase().contains('opt');
  bool get isPractical => type.toLowerCase().contains('prac') || type.toLowerCase().contains('lab');
  bool get isLanguage => type.toLowerCase().contains('lang');
  bool get isElectiveOrOptional => isOptional || isElective;

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
    } else if (json['assigned_classes'] != null && json['assigned_classes'] is List) {
      for (final item in json['assigned_classes'] as List) {
        if (item is Map && item['class_id'] != null) {
          clsIds.add(item['class_id'].toString());
        } else if (item != null) {
          clsIds.add(item.toString());
        }
      }
    }

    final isOpt = json['is_optional'] == true ||
        (json['type']?.toString().toLowerCase() == 'elective') ||
        (json['type']?.toString().toLowerCase() == 'optional');

    final sectionsCount = (json['assigned_sections_count'] as num?)?.toInt() ??
        (json['sections_count'] as num?)?.toInt() ?? 0;

    final teachersCount = (json['teachers_count'] as num?)?.toInt() ?? 0;

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
      isOptional: isOpt,
      classesCount: (json['classes_count'] as num?)?.toInt() ?? clsIds.length,
      sectionsCount: sectionsCount,
      teachersCount: teachersCount,
      isClassWide: json['is_class_wide'] == true || json['section_id'] == null,
      sectionId: json['section_id']?.toString(),
      sectionNames: json['section_names']?.toString(),
      assignedClassIds: clsIds,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
}

class AcademicRoomModel {
  final String id;
  final String name;
  final String code;
  final String type; // Classroom, Laboratory, Computer Lab, Auditorium, Library, Staff Room, Activity Room, Other
  final String building;
  final String floor;
  final int capacity;
  final List<String> facilities;
  final String status; // AVAILABLE, OCCUPIED, MAINTENANCE, RESERVED
  final String? description;
  final String inUseStatus;
  final String? inUseTitle;
  final String? inUseTimings;
  final String? inUseClassSection;
  final int allocationsCount;
  final List<RoomAllocationModel> allocations;
  final List<AcademicSectionModel> assignedSections;
  final int assignedSectionsCount;
  final int totalStudentsSeated;
  final double capacityUtilization;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AcademicRoomModel({
    required this.id,
    required this.name,
    required this.code,
    this.type = 'Classroom',
    this.building = 'Academic Block',
    this.floor = 'Ground Floor',
    this.capacity = 40,
    this.facilities = const [],
    this.status = 'AVAILABLE',
    this.description,
    this.inUseStatus = 'AVAILABLE',
    this.inUseTitle,
    this.inUseTimings,
    this.inUseClassSection,
    this.allocationsCount = 0,
    this.allocations = const [],
    this.assignedSections = const [],
    this.assignedSectionsCount = 0,
    this.totalStudentsSeated = 0,
    this.capacityUtilization = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  bool get isMaintenance {
    final s = status.toUpperCase().replaceAll('_', ' ').replaceAll('-', ' ');
    final inUse = inUseStatus.toUpperCase().replaceAll('_', ' ').replaceAll('-', ' ');
    return s.contains('MAINTENANCE') || inUse.contains('MAINTENANCE') || s.contains('REPAIR');
  }

  bool get isInUse {
    if (isMaintenance) return false;
    final s = status.toUpperCase().replaceAll('_', ' ').replaceAll('-', ' ');
    final inUse = inUseStatus.toUpperCase().replaceAll('_', ' ').replaceAll('-', ' ');
    return inUse.contains('IN USE') ||
        inUse == 'OCCUPIED' ||
        s.contains('IN USE') ||
        s == 'OCCUPIED';
  }

  bool get isReserved {
    if (isMaintenance || isInUse) return false;
    final s = status.toUpperCase();
    final inUse = inUseStatus.toUpperCase();
    return s.contains('RESERVED') || inUse.contains('RESERVED');
  }

  bool get isAvailable => !isMaintenance && !isInUse && !isReserved;

  Color get statusBadgeColor {
    if (isMaintenance) return const Color(0xFFEF4444); // Red
    if (isInUse) return const Color(0xFFF59E0B); // Amber
    if (isReserved) return const Color(0xFF6366F1); // Indigo
    return const Color(0xFF10B981); // Emerald Green
  }

  factory AcademicRoomModel.fromJson(Map<String, dynamic> json) {
    List<String> facList = [];
    if (json['facilities'] != null) {
      if (json['facilities'] is List) {
        facList = (json['facilities'] as List).map((e) => e.toString()).toList();
      } else if (json['facilities'] is String) {
        facList = (json['facilities'] as String)
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    List<RoomAllocationModel> allocList = [];
    if (json['allocations'] != null && json['allocations'] is List) {
      allocList = (json['allocations'] as List)
          .map((a) => RoomAllocationModel.fromJson(a as Map<String, dynamic>))
          .toList();
    }

    List<AcademicSectionModel> secList = [];
    if (json['assigned_sections'] != null && json['assigned_sections'] is List) {
      secList = (json['assigned_sections'] as List)
          .map((s) => AcademicSectionModel.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    String rawStatus = json['status']?.toString() ?? 'AVAILABLE';
    String rawInUseStatus = json['in_use_status']?.toString() ?? rawStatus;
    int cap = (json['capacity'] as num?)?.toInt() ?? 40;
    int totalStudents = (json['total_students_seated'] as num?)?.toInt() ??
        secList.fold<int>(0, (sum, item) => sum + item.studentsCount);
    double utilRate = (json['capacity_utilization'] as num?)?.toDouble() ??
        (cap > 0 ? (totalStudents / cap) * 100 : 0.0);

    return AcademicRoomModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Classroom',
      building: json['building']?.toString() ?? 'Academic Block',
      floor: json['floor']?.toString() ?? 'Ground Floor',
      capacity: cap,
      facilities: facList,
      status: rawStatus,
      description: json['description']?.toString(),
      inUseStatus: rawInUseStatus,
      inUseTitle: json['in_use_title']?.toString() ?? json['in_use_by']?.toString(),
      inUseTimings: json['in_use_timings']?.toString() ?? json['timings']?.toString(),
      inUseClassSection: json['in_use_class_section']?.toString(),
      allocationsCount: (json['allocations_count'] as num?)?.toInt() ?? allocList.length,
      allocations: allocList,
      assignedSections: secList,
      assignedSectionsCount: (json['assigned_sections_count'] as num?)?.toInt() ?? secList.length,
      totalStudentsSeated: totalStudents,
      capacityUtilization: utilRate,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
}

class RoomAllocationModel {
  final String id;
  final String roomId;
  final String academicYear;
  final String? classId;
  final String? className;
  final String? sectionId;
  final String? sectionName;
  final String? subjectId;
  final String? subjectName;
  final String? teacherId;
  final String? teacherName;
  final int dayOfWeek; // 0: Sun, 1: Mon, ..., 6: Sat
  final String startTime;
  final String endTime;
  final String? title;
  final String allocationType;
  final String status;
  final String? notes;

  RoomAllocationModel({
    required this.id,
    required this.roomId,
    this.academicYear = '2026-27',
    this.classId,
    this.className,
    this.sectionId,
    this.sectionName,
    this.subjectId,
    this.subjectName,
    this.teacherId,
    this.teacherName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.title,
    this.allocationType = 'TIMETABLE',
    this.status = 'ACTIVE',
    this.notes,
  });

  String get dayName {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    if (dayOfWeek >= 0 && dayOfWeek < days.length) return days[dayOfWeek];
    return 'Day $dayOfWeek';
  }

  String get timeSlotDisplay => '$startTime - $endTime';

  factory RoomAllocationModel.fromJson(Map<String, dynamic> json) {
    return RoomAllocationModel(
      id: json['id']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? '',
      academicYear: json['academic_year']?.toString() ?? '2026-27',
      classId: json['class_id']?.toString(),
      className: json['class_name']?.toString(),
      sectionId: json['section_id']?.toString(),
      sectionName: json['section_name']?.toString(),
      subjectId: json['subject_id']?.toString(),
      subjectName: json['subject_name']?.toString(),
      teacherId: json['teacher_id']?.toString(),
      teacherName: json['teacher_name']?.toString(),
      dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 1,
      startTime: json['start_time']?.toString() ?? '09:00',
      endTime: json['end_time']?.toString() ?? '10:00',
      title: json['title']?.toString(),
      allocationType: json['allocation_type']?.toString() ?? 'TIMETABLE',
      status: json['status']?.toString() ?? 'ACTIVE',
      notes: json['notes']?.toString(),
    );
  }
}

class SubjectSectionMappingModel {
  final String subjectId;
  final String subjectName;
  final String subjectCode;
  final String subjectType;
  final int periodsPerWeek;
  final String classId;
  final String className;
  final String classStatus;
  final String sectionId;
  final String sectionName;
  final String sectionStatus;
  final AcademicTeacherModel? assignedTeacher;
  final int enrolledStudentsCount;
  final int totalCapacity;
  final bool isClassWide;
  final bool isOfferedAsOptional;
  final String status;

  SubjectSectionMappingModel({
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    this.subjectType = 'Core',
    this.periodsPerWeek = 5,
    required this.classId,
    required this.className,
    this.classStatus = 'ACTIVE',
    required this.sectionId,
    required this.sectionName,
    this.sectionStatus = 'ACTIVE',
    this.assignedTeacher,
    this.enrolledStudentsCount = 0,
    this.totalCapacity = 40,
    this.isClassWide = false,
    this.isOfferedAsOptional = false,
    this.status = 'ACTIVE',
  });

  factory SubjectSectionMappingModel.fromJson(Map<String, dynamic> json) {
    AcademicTeacherModel? teacher;
    if (json['assigned_teacher'] != null && json['assigned_teacher'] is Map) {
      teacher = AcademicTeacherModel.fromJson(json['assigned_teacher'] as Map<String, dynamic>);
    } else if (json['assigned_teachers'] != null && json['assigned_teachers'] is List && (json['assigned_teachers'] as List).isNotEmpty) {
      teacher = AcademicTeacherModel.fromJson((json['assigned_teachers'] as List).first as Map<String, dynamic>);
    }

    final totalCap = (json['total_section_students'] as num?)?.toInt() ??
        (json['total_capacity'] as num?)?.toInt() ?? 40;

    return SubjectSectionMappingModel(
      subjectId: json['subject_id']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      subjectCode: json['subject_code']?.toString() ?? '',
      subjectType: json['subject_type']?.toString() ?? 'Core',
      periodsPerWeek: (json['periods_per_week'] as num?)?.toInt() ?? 5,
      classId: json['class_id']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
      classStatus: json['class_status']?.toString() ?? 'ACTIVE',
      sectionId: json['section_id']?.toString() ?? '',
      sectionName: json['section_name']?.toString() ?? '',
      sectionStatus: json['section_status']?.toString() ?? 'ACTIVE',
      assignedTeacher: teacher,
      enrolledStudentsCount: (json['enrolled_students_count'] as num?)?.toInt() ?? 0,
      totalCapacity: totalCap,
      isClassWide: json['is_class_wide'] == true,
      isOfferedAsOptional: json['is_offered_as_optional'] == true || json['is_optional'] == true,
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }
}

class ConflictCheckResult {
  final bool hasConflict;
  final String? conflictType; // ROOM_OVERLAP, TEACHER_OVERLAP, SECTION_OVERLAP
  final String message;

  ConflictCheckResult({
    required this.hasConflict,
    this.conflictType,
    required this.message,
  });

  factory ConflictCheckResult.fromJson(Map<String, dynamic> json) {
    return ConflictCheckResult(
      hasConflict: json['has_conflict'] == true,
      conflictType: json['conflict_type']?.toString(),
      message: json['message']?.toString() ?? (json['has_conflict'] == true ? 'Conflict detected' : 'No conflicts'),
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

  String? get subject => department;

  factory AcademicTeacherModel.fromJson(Map<String, dynamic> json) {
    return AcademicTeacherModel(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['name']?.toString() ?? 'Teacher',
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
  final bool isEnrolledInSubject;

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
    this.isEnrolledInSubject = false,
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
      isEnrolledInSubject: json['is_enrolled'] == true,
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
  final int inactiveClasses;
  final int totalSections;
  final int activeSections;
  final int inactiveSections;
  final int totalSubjects;
  final int coreSubjects;
  final int electiveSubjects;
  final int practicalSubjects;
  final int languageSubjects;
  final int inactiveSubjects;
  final int totalStudents;
  final int totalTeachers;
  final double avgStudentsPerSection;
  final int totalRooms;
  final int availableRooms;
  final int inUseRooms;
  final int maintenanceRooms;
  final int totalRoomCapacity;
  final List<Map<String, dynamic>> subjectTypesBreakdown;
  final List<Map<String, dynamic>> subjectsByClass;
  final List<Map<String, dynamic>> roomTypesBreakdown;
  final List<Map<String, dynamic>> buildingsBreakdown;
  final List<Map<String, dynamic>> sectionsByClass;
  final String academicYear;

  AcademicStatsModel({
    this.totalClasses = 0,
    this.activeClasses = 0,
    this.inactiveClasses = 0,
    this.totalSections = 0,
    this.activeSections = 0,
    this.inactiveSections = 0,
    this.totalSubjects = 0,
    this.coreSubjects = 0,
    this.electiveSubjects = 0,
    this.practicalSubjects = 0,
    this.languageSubjects = 0,
    this.inactiveSubjects = 0,
    this.totalStudents = 0,
    this.totalTeachers = 0,
    this.avgStudentsPerSection = 0.0,
    this.totalRooms = 0,
    this.availableRooms = 0,
    this.inUseRooms = 0,
    this.maintenanceRooms = 0,
    this.totalRoomCapacity = 0,
    this.subjectTypesBreakdown = const [],
    this.subjectsByClass = const [],
    this.roomTypesBreakdown = const [],
    this.buildingsBreakdown = const [],
    this.sectionsByClass = const [],
    this.academicYear = '2026-27',
  });

  factory AcademicStatsModel.fromJson(Map<String, dynamic> json) {
    return AcademicStatsModel(
      totalClasses: (json['total_classes'] as num?)?.toInt() ?? 0,
      activeClasses: (json['active_classes'] as num?)?.toInt() ?? 0,
      inactiveClasses: (json['inactive_classes'] as num?)?.toInt() ?? 0,
      totalSections: (json['total_sections'] as num?)?.toInt() ?? 0,
      activeSections: (json['active_sections'] as num?)?.toInt() ?? 0,
      inactiveSections: (json['inactive_sections'] as num?)?.toInt() ?? 0,
      totalSubjects: (json['total_subjects'] as num?)?.toInt() ?? 0,
      coreSubjects: (json['core_subjects'] as num?)?.toInt() ?? 0,
      electiveSubjects: (json['elective_subjects'] as num?)?.toInt() ?? 0,
      practicalSubjects: (json['practical_subjects'] as num?)?.toInt() ?? 0,
      languageSubjects: (json['language_subjects'] as num?)?.toInt() ?? 0,
      inactiveSubjects: (json['inactive_subjects'] as num?)?.toInt() ?? 0,
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      totalTeachers: (json['total_teachers'] as num?)?.toInt() ?? 0,
      avgStudentsPerSection: (json['avg_students_per_section'] as num?)?.toDouble() ?? 0.0,
      totalRooms: (json['total_rooms'] as num?)?.toInt() ?? 0,
      availableRooms: (json['available_rooms'] as num?)?.toInt() ?? 0,
      inUseRooms: (json['in_use_rooms'] as num?)?.toInt() ?? 0,
      maintenanceRooms: (json['maintenance_rooms'] as num?)?.toInt() ?? 0,
      totalRoomCapacity: (json['total_room_capacity'] as num?)?.toInt() ?? 0,
      subjectTypesBreakdown: json['subject_types_breakdown'] is List
          ? (json['subject_types_breakdown'] as List).cast<Map<String, dynamic>>()
          : [],
      subjectsByClass: json['subjects_by_class'] is List
          ? (json['subjects_by_class'] as List).cast<Map<String, dynamic>>()
          : [],
      roomTypesBreakdown: json['room_types_breakdown'] is List
          ? (json['room_types_breakdown'] as List).cast<Map<String, dynamic>>()
          : [],
      buildingsBreakdown: json['buildings_breakdown'] is List
          ? (json['buildings_breakdown'] as List).cast<Map<String, dynamic>>()
          : [],
      sectionsByClass: json['sections_by_class'] is List
          ? (json['sections_by_class'] as List).cast<Map<String, dynamic>>()
          : [],
      academicYear: json['academic_year']?.toString() ?? '2026-27',
    );
  }
}
