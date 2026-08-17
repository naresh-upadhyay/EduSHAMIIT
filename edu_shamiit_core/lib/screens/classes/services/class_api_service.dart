import '../../../../services/api_service.dart';
import '../models/class_models.dart';

class ClassApiService {
  final ApiService _api = ApiService();

  /// Retrieve academic overview statistics
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
    String academicYear = '2026-27',
    String status = 'ALL',
    int page = 1,
    int pageSize = 10,
    String sortBy = 'display_order',
    String sortOrder = 'ASC',
  }) async {
    final res = await _api.get('/classes', query: {
      'search': search,
      'academic_year': academicYear,
      'status': status,
      'page': page,
      'page_size': pageSize,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    }, useCache: false);

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
  Future<AcademicClassModel> getClassDetail(String classId) async {
    final res = await _api.get('/classes/$classId', useCache: false);
    final data = res['data'] as Map<String, dynamic>? ?? {};
    return AcademicClassModel.fromJson(data);
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
    int page = 1,
    int pageSize = 10,
    String sortBy = 'class_name',
    String sortOrder = 'ASC',
  }) async {
    final query = <String, dynamic>{
      'search': search,
      'academic_year': academicYear,
      'status': status,
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
    String academicYear = '2026-27',
    String status = 'ACTIVE',
  }) async {
    return await _api.post('/classes/sections', {
      'class_id': classId,
      'name': name,
      'code': code,
      'capacity': capacity,
      'room_number': roomNumber,
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
    String? status,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (code != null) body['code'] = code;
    if (capacity != null) body['capacity'] = capacity;
    if (roomNumber != null) body['room_number'] = roomNumber;
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
    int page = 1,
    int pageSize = 10,
    String sortBy = 'name',
    String sortOrder = 'ASC',
  }) async {
    final res = await _api.get('/classes/subjects/all', query: {
      'search': search,
      'type': type,
      'status': status,
      'page': page,
      'page_size': pageSize,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    }, useCache: false);

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
}
