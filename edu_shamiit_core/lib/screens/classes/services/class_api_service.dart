import '../../../../services/api_service.dart';
import '../models/class_models.dart';

class ClassApiService {
  final ApiService _api = ApiService();

  /// Retrieve academic overview statistics (Classes, Sections, Subjects, Rooms)
  Future<AcademicStatsModel> getStats({String academicYear = '2026-27'}) async {
    try {
      final res = await _api.get('/classes/stats', query: {'academic_year': academicYear}, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return AcademicStatsModel.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return AcademicStatsModel(academicYear: academicYear);
  }

  /// Get paginated academic classes list
  Future<Map<String, dynamic>> getClasses({
    String search = '',
    String stage = 'ALL',
    String academicYear = '2026-27',
    String status = 'ALL',
    int page = 1,
    int pageSize = 10,
    String sortBy = 'display_order',
    String sortOrder = 'ASC',
  }) async {
    final query = <String, dynamic>{
      'search': search,
      'academic_year': academicYear,
      'status': status,
      'stage': stage,
      'page': page,
      'page_size': pageSize,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    };

    final res = await _api.get('/classes', query: query, useCache: false);

    final data = res['data'] as Map<String, dynamic>? ?? {};
    final rawList = data['classes'] as List? ?? [];
    final classes = rawList.map((e) => AcademicClassModel.fromJson(e as Map<String, dynamic>)).toList();

    return {
      'classes': classes,
      'totalCount': data['total_count'] ?? 0,
      'page': data['page'] ?? page,
      'pageSize': data['page_size'] ?? pageSize,
      'totalPages': data['total_pages'] ?? 1,
    };
  }

  /// Get detailed class object with sections, subjects, and teachers
  Future<AcademicClassDetailModel> getClassDetail(String classId) async {
    try {
      final res = await _api.get('/classes/$classId', useCache: false);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      return AcademicClassDetailModel.fromJson(data);
    } catch (_) {
      return AcademicClassDetailModel(id: classId, name: '', code: '');
    }
  }

  /// Get sections overview statistics and distribution
  Future<SectionsOverviewStatsModel> getSectionsOverviewStats({String academicYear = '2026-27'}) async {
    try {
      final res = await _api.get('/classes/sections/stats', query: {'academic_year': academicYear}, useCache: false);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      return SectionsOverviewStatsModel.fromJson(data);
    } catch (_) {
      return SectionsOverviewStatsModel();
    }
  }

  /// Create a class with optional inline sections
  Future<Map<String, dynamic>> createClass({
    required String name,
    required String code,
    String stage = 'Secondary',
    String academicYear = '2026-27',
    int displayOrder = 1,
    String status = 'ACTIVE',
    List<Map<String, dynamic>> sections = const [],
  }) async {
    return await _api.post('/classes', {
      'name': name,
      'code': code,
      'stage': stage,
      'academic_year': academicYear,
      'display_order': displayOrder,
      'status': status,
      'sections': sections,
    });
  }

  /// Update class details
  Future<Map<String, dynamic>> updateClass(
    String classId, {
    String? name,
    String? code,
    String? stage,
    String? academicYear,
    int? displayOrder,
    String? status,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (code != null) body['code'] = code;
    if (stage != null) body['stage'] = stage;
    if (academicYear != null) body['academic_year'] = academicYear;
    if (displayOrder != null) body['display_order'] = displayOrder;
    if (status != null) body['status'] = status;

    return await _api.patch('/classes/$classId', body);
  }

  /// Archive or delete a class
  Future<Map<String, dynamic>> archiveClass(String classId, {bool force = false}) async {
    return await _api.delete('/classes/$classId?force=$force');
  }

  /// Restore an archived class
  Future<Map<String, dynamic>> restoreClass(String classId) async {
    return await _api.post('/classes/$classId/restore', {});
  }

  /// Get paginated list of sections across all classes
  Future<Map<String, dynamic>> getSections({
    String search = '',
    String? classId,
    String academicYear = '2026-27',
    String status = 'ALL',
    String building = 'ALL',
    String floor = 'ALL',
    int page = 1,
    int pageSize = 10,
    String sortBy = 'class_name',
    String sortOrder = 'ASC',
  }) async {
    final query = <String, dynamic>{
      'search': search,
      'academic_year': academicYear,
      'status': status,
      'building': building,
      'floor': floor,
      'page': page,
      'page_size': pageSize,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    };
    if (classId != null && classId.isNotEmpty) {
      query['class_id'] = classId;
    }

    final res = await _api.get('/classes/sections/all', query: query, useCache: false);
    final data = res['data'] as Map<String, dynamic>? ?? {};
    final rawList = data['sections'] as List? ?? [];
    final sections = rawList.map((e) => AcademicSectionModel.fromJson(e as Map<String, dynamic>)).toList();

    return {
      'sections': sections,
      'totalCount': data['total_count'] ?? 0,
      'page': data['page'] ?? page,
      'pageSize': data['page_size'] ?? pageSize,
      'totalPages': data['total_pages'] ?? 1,
    };
  }

  /// Create standalone section
  Future<Map<String, dynamic>> createSection({
    required String classId,
    required String name,
    required String code,
    int capacity = 40,
    String? roomNumber,
    String? roomId,
    String academicYear = '2026-27',
    String status = 'ACTIVE',
  }) async {
    return await _api.post('/classes/sections', {
      'class_id': classId,
      'name': name,
      'code': code,
      'capacity': capacity,
      'room_number': roomNumber,
      'room_id': roomId,
      'academic_year': academicYear,
      'status': status,
    });
  }

  /// Update section
  Future<Map<String, dynamic>> updateSection(
    String sectionId, {
    String? name,
    String? code,
    int? capacity,
    String? roomNumber,
    String? roomId,
    String? status,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (code != null) body['code'] = code;
    if (capacity != null) body['capacity'] = capacity;
    if (roomNumber != null) body['room_number'] = roomNumber;
    if (roomId != null) body['room_id'] = roomId;
    if (status != null) body['status'] = status;

    return await _api.patch('/classes/sections/$sectionId', body);
  }

  /// Archive section
  Future<Map<String, dynamic>> archiveSection(String sectionId, {bool force = false}) async {
    return await _api.delete('/classes/sections/$sectionId?force=$force');
  }

  /// Restore an archived section
  Future<Map<String, dynamic>> restoreSection(String sectionId) async {
    return await _api.post('/classes/sections/$sectionId/restore', {});
  }

  /// Get subjects catalog
  Future<Map<String, dynamic>> getSubjects({
    String search = '',
    String type = 'ALL',
    String status = 'ALL',
    String? classId,
    String academicYear = '2026-27',
    int page = 1,
    int pageSize = 10,
    String sortBy = 'name',
    String sortOrder = 'ASC',
  }) async {
    final query = <String, dynamic>{
      'search': search,
      'type': type,
      'status': status,
      'academic_year': academicYear,
      'page': page,
      'page_size': pageSize,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    };
    if (classId != null && classId.isNotEmpty && classId != 'ALL') {
      query['class_id'] = classId;
    }

    final res = await _api.get('/classes/subjects/all', query: query, useCache: false);

    final data = res['data'] as Map<String, dynamic>? ?? {};
    final rawList = data['subjects'] as List? ?? [];
    final subjects = rawList.map((e) => AcademicSubjectModel.fromJson(e as Map<String, dynamic>)).toList();

    return {
      'subjects': subjects,
      'totalCount': data['total_count'] ?? 0,
      'page': data['page'] ?? page,
      'pageSize': data['page_size'] ?? pageSize,
      'totalPages': data['total_pages'] ?? 1,
    };
  }

  /// Create subject
  Future<Map<String, dynamic>> createSubject({
    required String name,
    required String code,
    String type = 'Core',
    String? description,
    int periodsPerWeek = 5,
    String color = '#4F46E5',
    String icon = 'book',
    String status = 'ACTIVE',
    bool isOptional = false,
    List<String> classIds = const [],
  }) async {
    return await _api.post('/classes/subjects', {
      'name': name,
      'code': code,
      'type': type,
      'description': description,
      'periods_per_week': periodsPerWeek,
      'color': color,
      'icon': icon,
      'status': status,
      'is_optional': isOptional,
      'class_ids': classIds,
    });
  }

  /// Update subject
  Future<Map<String, dynamic>> updateSubject(
    String subjectId, {
    String? name,
    String? code,
    String? type,
    String? description,
    int? periodsPerWeek,
    String? color,
    String? icon,
    String? status,
    bool? isOptional,
    List<String>? classIds,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (code != null) body['code'] = code;
    if (type != null) body['type'] = type;
    if (description != null) body['description'] = description;
    if (periodsPerWeek != null) body['periods_per_week'] = periodsPerWeek;
    if (color != null) body['color'] = color;
    if (icon != null) body['icon'] = icon;
    if (status != null) body['status'] = status;
    if (isOptional != null) body['is_optional'] = isOptional;
    if (classIds != null) body['class_ids'] = classIds;

    return await _api.patch('/classes/subjects/$subjectId', body);
  }

  /// Archive subject
  Future<Map<String, dynamic>> archiveSubject(String subjectId, {bool force = false}) async {
    return await _api.delete('/classes/subjects/$subjectId?force=$force');
  }

  /// Restore an archived subject
  Future<Map<String, dynamic>> restoreSubject(String subjectId) async {
    return await _api.post('/classes/subjects/$subjectId/restore', {});
  }

  /// Get subject section offerings and mappings
  Future<List<SubjectSectionMappingModel>> getSubjectSectionMappings({
    String? subjectId,
    String academicYear = '2026-27',
  }) async {
    try {
      final query = <String, dynamic>{'academic_year': academicYear};
      if (subjectId != null) query['subject_id'] = subjectId;

      final res = await _api.get('/classes/subjects/mappings', query: query, useCache: false);
      final rawList = res['data'] as List? ?? [];
      return rawList.map((e) => SubjectSectionMappingModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Assign subject to class & sections (with auto-enrollment if Mandatory)
  Future<Map<String, dynamic>> assignSubjectToSections({
    required String classId,
    required List<String> sectionIds,
    required String subjectId,
    String? teacherId,
    String academicYear = '2026-27',
  }) async {
    return await _api.post('/classes/subjects/assign-sections', {
      'class_id': classId,
      'section_ids': sectionIds,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'academic_year': academicYear,
    });
  }

  /// Unassign subject from a section or direct class
  Future<Map<String, dynamic>> unassignSubjectFromSection({
    required String classId,
    String? sectionId,
    required String subjectId,
    String academicYear = '2026-27',
  }) async {
    final body = <String, dynamic>{
      'class_id': classId,
      'subject_id': subjectId,
      'academic_year': academicYear,
    };
    if (sectionId != null && sectionId.isNotEmpty) {
      body['section_id'] = sectionId;
    }
    return await _api.post('/classes/subjects/unassign-section', body);
  }

  /// Toggle status (ACTIVE / INACTIVE) of a subject offering for a class & section combo
  Future<Map<String, dynamic>> toggleClassSubjectStatus({
    required String classId,
    String? sectionId,
    required String subjectId,
    required String status,
    String academicYear = '2026-27',
  }) async {
    final body = <String, dynamic>{
      'class_id': classId,
      'subject_id': subjectId,
      'status': status,
      'academic_year': academicYear,
    };
    if (sectionId != null && sectionId.isNotEmpty) {
      body['section_id'] = sectionId;
    }
    return await _api.post('/classes/subjects/toggle-status', body);
  }

  /// Assign or unassign teacher to subject for sections
  Future<Map<String, dynamic>> assignSectionSubjectTeacher({
    required String classId,
    required List<String> sectionIds,
    required String subjectId,
    String? teacherId,
    String academicYear = '2026-27',
  }) async {
    return await _api.post('/classes/subjects/section-teachers', {
      'class_id': classId,
      'section_ids': sectionIds,
      'subject_id': subjectId,
      'teacher_id': (teacherId != null && teacherId.isNotEmpty) ? teacherId : null,
      'academic_year': academicYear,
    });
  }

  /// Enroll students in optional / elective subject
  Future<Map<String, dynamic>> manageOptionalEnrollments({
    required String classId,
    String? sectionId,
    required String subjectId,
    required List<String> studentIds,
    String academicYear = '2026-27',
  }) async {
    final body = <String, dynamic>{
      'class_id': classId,
      'subject_id': subjectId,
      'student_ids': studentIds,
      'academic_year': academicYear,
    };
    if (sectionId != null && sectionId.isNotEmpty) {
      body['section_id'] = sectionId;
    }
    return await _api.post('/classes/subjects/enrollments', body);
  }

  /// Get optional student enrollments with student list
  Future<List<AcademicStudentModel>> getOptionalSubjectStudents({
    String? sectionId,
    String? classId,
    required String subjectId,
    String academicYear = '2026-27',
  }) async {
    try {
      final query = <String, String>{
        'subject_id': subjectId,
        'academic_year': academicYear,
      };
      if (sectionId != null && sectionId.isNotEmpty) {
        query['section_id'] = sectionId;
      }
      if (classId != null && classId.isNotEmpty) {
        query['class_id'] = classId;
      }

      final res = await _api.get('/classes/subjects/enrollments', query: query, useCache: false);
      final rawList = res['data'] as List? ?? [];
      return rawList.map((e) => AcademicStudentModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // =========================================================================
  // ROOMS API
  // =========================================================================

  /// Get rooms dashboard statistics
  Future<AcademicStatsModel> getRoomStats({String academicYear = '2026-27'}) async {
    try {
      final res = await _api.get('/classes/rooms/stats', query: {'academic_year': academicYear}, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return AcademicStatsModel.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return AcademicStatsModel(academicYear: academicYear);
  }

  /// Get paginated rooms list with real-time status and schedule filters
  Future<Map<String, dynamic>> getRooms({
    String search = '',
    String type = 'ALL',
    String building = 'ALL',
    String floor = 'ALL',
    String status = 'ALL',
    String academicYear = '2026-27',
    int page = 1,
    int pageSize = 10,
    String sortBy = 'name',
    String sortOrder = 'ASC',
  }) async {
    final res = await _api.get('/classes/rooms', query: {
      'search': search,
      'type': type,
      'building': building,
      'floor': floor,
      'status': status,
      'academic_year': academicYear,
      'page': page,
      'page_size': pageSize,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    }, useCache: false);

    final data = res['data'] as Map<String, dynamic>? ?? {};
    final rawList = data['rooms'] as List? ?? [];
    final rooms = rawList.map((e) => AcademicRoomModel.fromJson(e as Map<String, dynamic>)).toList();

    return {
      'rooms': rooms,
      'totalCount': data['total_count'] ?? 0,
      'page': data['page'] ?? page,
      'pageSize': data['page_size'] ?? pageSize,
      'totalPages': data['total_pages'] ?? 1,
    };
  }

  /// Get room details including weekly schedule allocations
  Future<AcademicRoomModel> getRoomDetail(String roomId, {String academicYear = '2026-27'}) async {
    final res = await _api.get('/classes/rooms/$roomId', query: {'academic_year': academicYear}, useCache: false);
    final data = res['data'] as Map<String, dynamic>? ?? {};
    return AcademicRoomModel.fromJson(data);
  }

  /// Create a new room / facility
  Future<Map<String, dynamic>> createRoom({
    required String name,
    required String code,
    String type = 'Classroom',
    String building = 'Academic Block',
    String floor = 'Ground Floor',
    int capacity = 40,
    List<String> facilities = const [],
    String status = 'AVAILABLE',
    String? description,
  }) async {
    return await _api.post('/classes/rooms', {
      'name': name,
      'code': code,
      'type': type,
      'building': building,
      'floor': floor,
      'capacity': capacity,
      'facilities': facilities,
      'status': status,
      'description': description,
    });
  }

  /// Update room attributes
  Future<Map<String, dynamic>> updateRoom(
    String roomId, {
    String? name,
    String? code,
    String? type,
    String? building,
    String? floor,
    int? capacity,
    List<String>? facilities,
    String? status,
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (code != null) body['code'] = code;
    if (type != null) body['type'] = type;
    if (building != null) body['building'] = building;
    if (floor != null) body['floor'] = floor;
    if (capacity != null) body['capacity'] = capacity;
    if (facilities != null) body['facilities'] = facilities;
    if (status != null) body['status'] = status;
    if (description != null) body['description'] = description;

    return await _api.patch('/classes/rooms/$roomId', body);
  }

  /// Archive a room
  Future<Map<String, dynamic>> archiveRoom(String roomId, {bool force = false}) async {
    return await _api.delete('/classes/rooms/$roomId?force=$force');
  }

  /// Restore an archived room
  Future<Map<String, dynamic>> restoreRoom(String roomId) async {
    return await _api.post('/classes/rooms/$roomId/restore', {});
  }

  /// Get distinct buildings and floors
  Future<Map<String, List<String>>> getBuildingsAndFloors() async {
    try {
      final res = await _api.get('/classes/rooms/buildings-floors', useCache: false);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final bList = (data['buildings'] as List? ?? []).map((e) => e.toString()).toList();
      final fList = (data['floors'] as List? ?? []).map((e) => e.toString()).toList();
      return {'buildings': bList, 'floors': fList};
    } catch (_) {
      return {'buildings': [], 'floors': []};
    }
  }

  /// Bulk status update for rooms
  Future<Map<String, dynamic>> bulkUpdateRoomStatus({
    required List<String> roomIds,
    required String status,
  }) async {
    return await _api.post('/classes/rooms/bulk-status', {
      'room_ids': roomIds,
      'status': status,
    });
  }

  // =========================================================================
  // ASSIGNMENTS & USER SEARCH
  // =========================================================================

  /// Contextual Teacher Assignment
  Future<Map<String, dynamic>> assignTeachers({
    required String classId,
    String? sectionId,
    required List<String> teacherIds,
    String academicYear = '2026-27',
  }) async {
    final endpoint = sectionId != null
        ? '/classes/$classId/teachers?section_id=$sectionId'
        : '/classes/$classId/teachers';
    return await _api.post(endpoint, {
      'teacher_ids': teacherIds,
      'academic_year': academicYear,
    });
  }

  /// Contextual Student Assignment
  Future<Map<String, dynamic>> assignStudents({
    required String classId,
    String? sectionId,
    required List<String> studentIds,
    String academicYear = '2026-27',
    bool confirmMove = false,
  }) async {
    final endpoint = sectionId != null
        ? '/classes/$classId/students?section_id=$sectionId'
        : '/classes/$classId/students';
    return await _api.post(endpoint, {
      'student_ids': studentIds,
      'academic_year': academicYear,
      'confirm_move': confirmMove,
    });
  }

  /// Contextual Subject Management
  Future<Map<String, dynamic>> manageSubjects({
    required String classId,
    String? sectionId,
    required List<String> subjectIds,
    String academicYear = '2026-27',
  }) async {
    final endpoint = sectionId != null
        ? '/classes/$classId/subjects?section_id=$sectionId'
        : '/classes/$classId/subjects';
    return await _api.post(endpoint, {
      'subject_ids': subjectIds,
      'academic_year': academicYear,
    });
  }

  /// Search Teachers from User Management
  Future<List<AcademicTeacherModel>> searchTeachers({String search = '', int limit = 20}) async {
    try {
      final res = await _api.get('/classes/users/teachers', query: {'search': search, 'limit': limit}, useCache: false);
      final rawList = res['data'] as List? ?? [];
      return rawList.map((e) => AcademicTeacherModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Search Students from User Management
  Future<List<AcademicStudentModel>> searchStudents({
    String search = '',
    String academicYear = '2026-27',
    String? classId,
    String? sectionId,
    int limit = 50,
  }) async {
    try {
      final query = <String, dynamic>{
        'search': search,
        'academic_year': academicYear,
        'limit': limit,
      };
      if (classId != null) query['class_id'] = classId;
      if (sectionId != null) query['section_id'] = sectionId;

      final res = await _api.get('/classes/users/students', query: query, useCache: false);
      final rawList = res['data'] as List? ?? [];
      return rawList.map((e) => AcademicStudentModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Check student moves
  Future<List<StudentConflictModel>> checkStudentMoves({
    required List<String> studentIds,
    String academicYear = '2026-27',
    String? targetClassId,
    String? targetSectionId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'student_ids': studentIds,
        'academic_year': academicYear,
      };
      if (targetClassId != null) payload['target_class_id'] = targetClassId;
      if (targetSectionId != null) payload['target_section_id'] = targetSectionId;

      final res = await _api.post('/classes/users/check-student-moves', payload);
      final rawList = res['conflicts'] as List? ?? [];
      return rawList.map((e) => StudentConflictModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Export academic data as CSV text
  Future<String> exportCsv(String entity, {String academicYear = '2026-27'}) async {
    return await _api.getString('/classes/export/$entity', query: {'academic_year': academicYear});
  }

  /// Download template as CSV text
  Future<String> downloadTemplate(String entity, {String academicYear = '2026-27'}) async {
    return await _api.getString('/classes/template/$entity', query: {'academic_year': academicYear});
  }

  /// Bulk import CSV records
  Future<Map<String, dynamic>> importCsv(
    String entity, {
    String? csvContent,
    List<Map<String, dynamic>>? records,
    String academicYear = '2026-27',
  }) async {
    return await _api.post('/classes/import/$entity', {
      if (csvContent != null) 'csv_content': csvContent,
      if (records != null) 'records': records,
      'academic_year': academicYear,
    });
  }
}

