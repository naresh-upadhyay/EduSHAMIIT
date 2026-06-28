import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/teacher_models.dart';

/// Service for teacher-related API calls
class TeacherApiService {
  static final TeacherApiService _instance = TeacherApiService._internal();
  factory TeacherApiService() => _instance;
  TeacherApiService._internal();

  final http.Client _client = http.Client();

  String get _baseUrl => AppConfig.apiBaseUrl;
  String get baseUrl => _baseUrl;

  final Map<String, dynamic> _cache = {};

  dynamic _unwrapData(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      if (payload['data'] != null) return payload['data'];
      if (payload['result'] != null) return payload['result'];
    }
    return payload;
  }

  Future<dynamic> _getCached(String path, {bool useCache = true}) async {
    if (useCache && _cache.containsKey(path)) {
      _fetchAndCache(path);
      return _cache[path];
    }
    return _fetchAndCache(path);
  }

  Future<dynamic> _fetchAndCache(String path) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl$path'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _cache[path] = data;
      return data;
    } else {
      if (_cache.containsKey(path)) return _cache[path];
      throw Exception('Failed to load $path: ${response.statusCode}');
    }
  }

  Map<String, dynamic> _toMap(dynamic payload,
      {List<String> candidateKeys = const []}) {
    final unwrapped = _unwrapData(payload);
    if (unwrapped is Map<String, dynamic>) {
      for (final key in candidateKeys) {
        final candidate = unwrapped[key];
        if (candidate is Map<String, dynamic>) return candidate;
      }
      return unwrapped;
    }
    return <String, dynamic>{};
  }

  List<dynamic> _toList(dynamic payload,
      {List<String> candidateKeys = const []}) {
    final unwrapped = _unwrapData(payload);
    if (unwrapped is List) return unwrapped;
    if (unwrapped is Map<String, dynamic>) {
      for (final key in candidateKeys) {
        final candidate = unwrapped[key];
        if (candidate is List) return candidate;
      }
    }
    return const [];
  }

  Future<http.Response> _getWithFallback(List<String> paths) async {
    final headers = await _getHeaders();
    http.Response? lastResponse;

    for (final path in paths) {
      final response = await _client.get(
        Uri.parse('$_baseUrl$path'),
        headers: headers,
      );
      lastResponse = response;
      if (response.statusCode == 200) return response;
    }

    return lastResponse ??
        http.Response('No path attempted', 500, request: null);
  }

  Future<http.Response> _postWithFallback({
    required List<String> paths,
    required Map<String, dynamic> body,
  }) async {
    final headers = await _getHeaders();
    http.Response? lastResponse;

    for (final path in paths) {
      final response = await _client.post(
        Uri.parse('$_baseUrl$path'),
        headers: headers,
        body: json.encode(body),
      );
      lastResponse = response;
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response;
      }
    }

    return lastResponse ??
        http.Response('No path attempted', 500, request: null);
  }

  /// Get headers with authorization
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get authentication token
  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // ========== Dashboard API ==========

  /// Get teacher dashboard data
  Future<TeacherDashboard> getDashboard() async {
    try {
      final body = await _getCached('/teacher/dashboard');
      final data = _toMap(body);
      return TeacherDashboard.fromJson(data);
    } catch (e) {
      throw Exception('Error fetching dashboard: $e');
    }
  }

  // ========== Profile API ==========

  /// Get teacher profile
  Future<TeacherProfile> getProfile() async {
    try {
      final body = await _getCached('/teacher/profile');
      final data = _toMap(
        body,
        candidateKeys: ['profile', 'teacher', 'user'],
      );
      return TeacherProfile.fromJson(data);
    } catch (e) {
      throw Exception('Error fetching profile: $e');
    }
  }

  /// Update teacher profile
  Future<TeacherProfile> updateProfile(Map<String, dynamic> updates) async {
    try {
      final response = await _client.patch(
        Uri.parse('$_baseUrl/teacher/profile'),
        headers: await _getHeaders(),
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        final data = _toMap(json.decode(response.body));
        return TeacherProfile.fromJson(data);
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating profile: $e');
    }
  }

  // ========== Attendance API ==========

  /// Get students for a class (for attendance marking)
  Future<List<StudentDirectoryEntry>> getStudentsForClass(
      String classId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/students?class_name=$classId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['students', 'items', 'results'],
        );
        return data
            .map((item) => StudentDirectoryEntry.fromJson(item))
            .toList();
      } else {
        throw Exception('Failed to load students: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching students: $e');
    }
  }

  /// Mark attendance for a class (with retry for transient network errors)
  Future<void> markAttendance({
    required String classId,
    required String date,
    String? subjectId,
    required List<Map<String, dynamic>> attendanceRecords,
  }) async {
    const maxAttempts = 3;
    Exception? lastError;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _client.post(
          Uri.parse('$_baseUrl/teacher/attendance/mark'),
          headers: await _getHeaders(),
          body: json.encode({
            'class_name': classId,
            'class_id': classId,
            'date': date,
            'subject_id': subjectId,
            'attendance_records': attendanceRecords,
            'records': attendanceRecords,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return; // Success
        }
        lastError = Exception('Failed to mark attendance: ${response.statusCode}');
      } catch (e) {
        lastError = Exception('Error marking attendance: $e');
      }

      // Wait before retrying (exponential backoff: 1s, 2s)
      if (attempt < maxAttempts) {
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    throw lastError!;
  }

  /// Get subjects for class or teacher
  Future<List<TeacherSubject>> getSubjects({String? classId, bool allSubjects = false}) async {
    try {
      String path = '/teacher/subjects';
      if (allSubjects) {
        path = '/teacher/subjects?all_subjects=true';
      } else if (classId != null) {
        path = '/teacher/subjects?class_name=$classId';
      }
      final response = await _client.get(
        Uri.parse('$_baseUrl$path'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['subjects', 'items', 'results'],
        );
        return data.map((item) => TeacherSubject.fromJson(item)).toList();
      } else {
        return _fallbackSubjects();
      }
    } catch (e) {
      return _fallbackSubjects();
    }
  }

  List<TeacherSubject> _fallbackSubjects() {
    return [
      const TeacherSubject(id: 'sub_math', name: 'Mathematics', icon: '📐', color: '#4F46E5'),
      const TeacherSubject(id: 'sub_phys', name: 'Physics', icon: '⚛️', color: '#0EA5E9'),
      const TeacherSubject(id: 'sub_chem', name: 'Chemistry', icon: '⚗️', color: '#10B981'),
      const TeacherSubject(id: 'sub_bio', name: 'Biology', icon: '🧬', color: '#EF4444'),
      const TeacherSubject(id: 'sub_eng', name: 'English', icon: '📖', color: '#F59E0B'),
    ];
  }

  /// Fetch existing attendance details for class, date and subject
  Future<List<Map<String, dynamic>>> fetchAttendance({
    required String classId,
    required String date,
    String? subjectId,
  }) async {
    try {
      final params = {'class_name': classId, 'date': date};
      if (subjectId != null) {
        params['subject_id'] = subjectId;
      }
      final queryString =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/attendance/fetch?$queryString'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> data = _toList(
          decoded,
          candidateKeys: ['students', 'items', 'results'],
        );
        return data.map((e) => e as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to fetch attendance: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching attendance: $e');
    }
  }

  /// Get attendance history for a class
  Future<List<TeacherAttendanceRecord>> getAttendanceHistory({
    required String classId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final params = {'class': classId};
      if (startDate != null) {
        params['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        params['end_date'] = endDate.toIso8601String().split('T')[0];
      }

      final queryString =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/attendance/history?$queryString'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['attendance', 'items', 'results'],
        );
        return data
            .map((item) => TeacherAttendanceRecord.fromJson(item))
            .toList();
      } else {
        throw Exception(
            'Failed to load attendance history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching attendance history: $e');
    }
  }

  // ========== Homework API ==========

  /// Get homework assignments for teacher
  Future<List<TeacherHomeworkAssignment>> getHomeworkAssignments({
    String? classId,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final params = <String, String>{};
      if (classId != null) params['class'] = classId;
      if (status != null) params['status'] = status;
      params['page'] = page.toString();
      params['limit'] = limit.toString();

      final queryString =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/homework?$queryString'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['homework', 'assignments', 'items', 'results'],
        );
        return data
            .map((item) => TeacherHomeworkAssignment.fromJson(item))
            .toList();
      } else {
        throw Exception('Failed to load homework: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching homework: $e');
    }
  }

  /// Create homework assignment
  Future<TeacherHomeworkAssignment> createHomework({
    required String title,
    required String description,
    required String classId,
    required String subject,
    required DateTime dueDate,
    String? instructions,
    int? maxMarks,
    String? attachmentUrl,
  }) async {
    try {
      final response = await _postWithFallback(
        paths: ['/teacher/homework', '/teacher/homework/create'],
        body: {
          'title': title,
          'description': description,
          'class': classId,
          'class_id': classId,
          'subject': subject,
          'due_date': dueDate.toIso8601String().split('T')[0],
          'instructions': instructions,
          'max_marks': maxMarks,
          'attachment_url': attachmentUrl,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = _toMap(json.decode(response.body));
        return TeacherHomeworkAssignment.fromJson(data);
      } else {
        throw Exception('Failed to create homework: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating homework: $e');
    }
  }

  /// Update homework assignment
  Future<TeacherHomeworkAssignment> updateHomework({
    required String homeworkId,
    Map<String, dynamic>? updates,
  }) async {
    try {
      final response = await _client.patch(
        Uri.parse('$_baseUrl/teacher/homework/$homeworkId'),
        headers: await _getHeaders(),
        body: json.encode(updates ?? {}),
      );

      if (response.statusCode == 200) {
        final data = _toMap(json.decode(response.body));
        return TeacherHomeworkAssignment.fromJson(data);
      } else {
        throw Exception('Failed to update homework: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating homework: $e');
    }
  }

  /// Delete homework assignment
  Future<void> deleteHomework(String homeworkId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/teacher/homework/$homeworkId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete homework: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting homework: $e');
    }
  }

  /// Send reminder to students for a homework assignment
  Future<void> sendHomeworkReminder(String homeworkId) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/homework/$homeworkId/remind'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to send reminder: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error sending reminder: $e');
    }
  }

  /// Send bulk targeted notifications to students for selected homework assignments
  Future<Map<String, dynamic>> sendBulkHomeworkNotifications(List<String> homeworkIds, {String? mode}) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/homework/bulk-notify'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'homework_ids': homeworkIds,
          if (mode != null) 'mode': mode,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to send bulk notifications: ${response.statusCode}');
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error sending bulk notifications: $e');
    }
  }

  /// Get homework submissions
  Future<List<HomeworkSubmission>> getHomeworkSubmissions({
    required String homeworkId,
    String? status,
  }) async {
    try {
      final params = <String, String>{};
      if (status != null) params['status'] = status;
      if (homeworkId.trim().isNotEmpty) params['homework_id'] = homeworkId;
      
      final queryString =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');
      
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/submissions${queryString.isEmpty ? '' : '?$queryString'}'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['submissions', 'items', 'results'],
        );
        return data.map((item) => HomeworkSubmission.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load submissions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching submissions: $e');
    }
  }

  /// Grade homework submission
  Future<HomeworkSubmission> gradeSubmission({
    required String submissionId,
    required double marks,
    String? feedback,
  }) async {
    try {
      final response = await _postWithFallback(
        paths: [
          '/teacher/submissions/$submissionId/grade',
          '/teacher/submissions/grade',
        ],
        body: {
          'submission_id': submissionId,
          'marks': marks,
          'feedback': feedback,
        },
      );

      if (response.statusCode == 200) {
        final data = _toMap(json.decode(response.body));
        return HomeworkSubmission.fromJson(data);
      } else {
        throw Exception('Failed to grade submission: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error grading submission: $e');
    }
  }

  /// Return homework submission to student for correction
  Future<void> returnSubmission({
    required String submissionId,
    String? feedback,
  }) async {
    try {
      final response = await _postWithFallback(
        paths: [
          '/teacher/submissions/return',
        ],
        body: {
          'submission_id': submissionId,
          'feedback': feedback,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to return submission: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error returning submission: $e');
    }
  }

  // ========== Gradebook API ==========

  /// Get grade records for a class
  Future<List<GradeRecord>> getGradeRecords({
    required String classId,
    String? assessmentType,
    String? studentId,
  }) async {
    try {
      final params = <String, String>{'class_name': classId};
      if (assessmentType != null) params['assessment_type'] = assessmentType;
      if (studentId != null) params['student_id'] = studentId;

      final queryString =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/gradebook?$queryString'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['grades', 'gradebook', 'items', 'results'],
        );
        return data.map((item) => GradeRecord.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load grades: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching grades: $e');
    }
  }

  /// Get consolidated gradebook data (roster, homeworks, submissions)
  Future<Map<String, dynamic>> getConsolidatedGradebook({
    required String classId,
    String? assessmentType,
    String? subjectId,
  }) async {
    try {
      final params = <String, String>{'class_name': classId};
      if (assessmentType != null && assessmentType != 'All') params['assessment_type'] = assessmentType;
      if (subjectId != null) params['subject_id'] = subjectId;

      final queryString =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/gradebook?$queryString'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded['data'] ?? decoded;
        return Map<String, dynamic>.from(data as Map);
      } else {
        throw Exception('Failed to load gradebook: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching gradebook: $e');
    }
  }

  /// Add grade record
  Future<GradeRecord> addGrade({
    required String studentId,
    required String assessmentName,
    required String assessmentType,
    required double marksObtained,
    required int totalMarks,
    required String classId,
    required String subject,
    String? remarks,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/gradebook'),
        headers: await _getHeaders(),
        body: json.encode({
          'student_id': studentId,
          'assessment_name': assessmentName,
          'assessment_type': assessmentType,
          'marks_obtained': marksObtained,
          'total_marks': totalMarks,
          'class': classId,
          'subject': subject,
          'remarks': remarks,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return GradeRecord.fromJson(data);
      } else {
        throw Exception('Failed to add grade: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error adding grade: $e');
    }
  }

  /// Update grade record
  Future<GradeRecord> updateGrade({
    required String gradeId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await _client.patch(
        Uri.parse('$_baseUrl/teacher/gradebook/$gradeId'),
        headers: await _getHeaders(),
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return GradeRecord.fromJson(data);
      } else {
        throw Exception('Failed to update grade: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating grade: $e');
    }
  }

  // ========== Exam API ==========

  /// Get exams for teacher
  Future<List<TeacherExam>> getExams({
    String? classId,
    String? examType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final params = <String, String>{};
      if (classId != null) params['class'] = classId;
      if (examType != null) params['type'] = examType;
      if (startDate != null) {
        params['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        params['end_date'] = endDate.toIso8601String().split('T')[0];
      }

      final queryString =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final response = await _getWithFallback([
        '/teacher/exams?$queryString',
      ]);

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['exams', 'items', 'results'],
        );
        return data.map((item) => TeacherExam.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load exams: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching exams: $e');
    }
  }

  Future<TeacherExam> createExam({
    required String title,
    required String subject,
    required List<String> targetClasses,
    DateTime? examDate,
    required String duration,
    required int totalMarks,
    required String examType,
    required String examCategory,
    String? subjectId,
    String? syllabus,
    String? roomNumber,
    DateTime? startTime,
    String? status,
    String? instructions,
    bool negativeMarking = false,
    bool shuffleQuestions = true,
    bool shuffleOptions = true,
    bool allowCalculator = false,
    bool cameraRequired = true,
    bool micRequired = true,
    bool autoSubmitOnTimer = true,
  }) async {
    try {
      final response = await _postWithFallback(
        paths: ['/teacher/exams', '/teacher/exams/create'],
        body: {
          'title': title,
          'subject': subject,
          if (subjectId != null) 'subject_id': subjectId,
          'target_classes': targetClasses,
          'class': targetClasses.isNotEmpty ? targetClasses.first : '',
          'class_id': targetClasses.isNotEmpty ? targetClasses.first : '',
          if (examDate != null) 'exam_date': examDate.toIso8601String().split('T')[0],
          'duration': duration,
          'total_marks': totalMarks,
          'exam_type': examType,
          'exam_category': examCategory,
          'syllabus': syllabus,
          'room_number': roomNumber,
          'venue': roomNumber,
          if (startTime != null) 'start_time': startTime.toUtc().toIso8601String(),
          if (status != null) 'status': status,
          if (instructions != null) 'instructions': instructions,
          'negative_marking': negativeMarking,
          'shuffle_questions': shuffleQuestions,
          'shuffle_options': shuffleOptions,
          'allow_calculator': allowCalculator,
          'camera_required': cameraRequired,
          'mic_required': micRequired,
          'auto_submit_on_timer': autoSubmitOnTimer,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = _toMap(decoded is Map ? decoded : (decoded as Map<String, dynamic>));
        // backend returns nested "data" or direct object
        final examData = data['data'] ?? data;
        return TeacherExam.fromJson(Map<String, dynamic>.from(examData as Map));
      } else {
        throw Exception('Failed to create exam: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating exam: $e');
    }
  }
  /// Update exam details
  Future<void> updateExam(String examId, Map<String, dynamic> updates) async {
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/teacher/exams/$examId'),
        headers: await _getHeaders(),
        body: json.encode(updates),
      );

      if (response.statusCode != 200) {
        String msg = 'Failed to update exam: ${response.statusCode}';
        try {
          final body = json.decode(response.body);
          if (body is Map && body.containsKey('detail')) {
            msg = body['detail'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Delete an exam
  Future<void> deleteExam(String examId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/teacher/exams/$examId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete exam: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting exam: $e');
    }
  }

  /// Download exam paper as PDF
  Future<Uint8List> downloadExamPaperPdf(String examId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/exams/$examId/pdf'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download exam paper PDF: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error downloading exam paper PDF: $e');
    }
  }

  // ========== Timetable API ==========

  /// Get timetable for teacher
  Future<List<TeacherTimetablePeriod>> getTimetable({
    String? classId,
    String? dayOfWeek,
    String? date,
  }) async {
    try {
      final params = <String, String>{};
      if (classId != null) params['class'] = classId;
      if (dayOfWeek != null) params['day'] = dayOfWeek;
      if (date != null) params['date'] = date;

      final queryString =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/timetable?$queryString'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['timetable', 'schedule', 'periods', 'items', 'results'],
        );
        return data
            .map((item) => TeacherTimetablePeriod.fromJson(item))
            .toList();
      } else {
        throw Exception('Failed to load timetable: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching timetable: $e');
    }
  }

  /// Schedule a timetable slot (Extra Class, PTM, Staff Meeting, Live Class)
  Future<void> scheduleTimetableSlot({
    required String date,
    required String slotType,
    required String customSubject,
    required String classId,
    required String startTime,
    required String endTime,
    required String room,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/timetable'),
        headers: await _getHeaders(),
        body: json.encode({
          'date': date,
          'slot_type': slotType,
          'custom_subject': customSubject,
          'class_name': classId,
          'class': classId,
          'start_time': startTime,
          'end_time': endTime,
          'room': room,
          'room_number': room,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to schedule timetable slot: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error scheduling timetable slot: $e');
    }
  }

  // ========== Leave API ==========

  /// Get teacher's leave applications
  Future<List<TeacherLeave>> getLeaveApplications({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final params = <String, String>{};
      if (status != null) params['status'] = status;
      params['page'] = page.toString();
      params['limit'] = limit.toString();

      final queryString =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final response = await _getWithFallback([
        '/teacher/leave?$queryString',
      ]);

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['leave', 'applications', 'items', 'results'],
        );
        return data.map((item) => TeacherLeave.fromJson(item)).toList();
      } else {
        throw Exception(
            'Failed to load leave applications: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching leave applications: $e');
    }
  }

  /// Apply for leave
  Future<TeacherLeave> applyLeave({
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    try {
      final response = await _postWithFallback(
        paths: ['/teacher/leave', '/teacher/leave/apply'],
        body: {
          'leave_type': leaveType,
          'start_date': startDate.toIso8601String().split('T')[0],
          'end_date': endDate.toIso8601String().split('T')[0],
          'reason': reason,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = _toMap(json.decode(response.body));
        return TeacherLeave.fromJson(data);
      } else {
        throw Exception('Failed to apply for leave: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error applying for leave: $e');
    }
  }

  // ========== Live Classes API ==========

  /// Get live classes for teacher
  Future<List<TeacherLiveClass>> getLiveClasses({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final params = <String, String>{};
      if (status != null) params['status'] = status;
      if (startDate != null) {
        params['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        params['end_date'] = endDate.toIso8601String().split('T')[0];
      }

      final queryString =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final response = await _getWithFallback([
        '/teacher/live-classes?$queryString',
        '/teacher/live-classes',
      ]);

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['live_classes', 'classes', 'items', 'results'],
        );
        return data.map((item) => TeacherLiveClass.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load live classes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching live classes: $e');
    }
  }

  /// Schedule live class
  Future<TeacherLiveClass> scheduleLiveClass({
    required String title,
    required String classId,
    required String subject,
    required DateTime scheduledAt,
    String? meetingLink,
    String? meetingId,
    String? meetingPassword,
    String platform = 'In-App',
  }) async {
    try {
      final response = await _postWithFallback(
        paths: ['/teacher/live-classes', '/teacher/live-classes/start'],
        body: {
          'title': title,
          'class': classId,
          'class_id': classId,
          'subject': subject,
          'scheduled_at': scheduledAt.toIso8601String(),
          'meeting_link': meetingLink,
          'meeting_id': meetingId,
          'meeting_password': meetingPassword,
          'platform': platform,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = _toMap(json.decode(response.body));
        return TeacherLiveClass.fromJson(data);
      } else {
        throw Exception(
            'Failed to schedule live class: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error scheduling live class: $e');
    }
  }

  /// Create a live class or recorded class
  Future<TeacherLiveClass> createLiveClass({
    required String title,
    required String classId,
    required String subject,
    required DateTime scheduledAt,
    required int durationMinutes,
    String? status, // 'scheduled', 'recorded', 'live'
    String? streamUrl,
    String? recordingUrl,
    String platform = 'In-App',
    String? meetingLink,
  }) async {
    try {
      final response = await _postWithFallback(
        paths: ['/teacher/live-classes'],
        body: {
          'title': title,
          'class': classId,
          'class_id': classId,
          'subject': subject,
          'scheduled_at': scheduledAt.toIso8601String(),
          'duration_minutes': durationMinutes,
          'status': status ?? 'scheduled',
          'stream_url': streamUrl,
          'recording_url': recordingUrl,
          'platform': platform,
          'meeting_link': meetingLink,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = _toMap(json.decode(response.body));
        return TeacherLiveClass.fromJson(data);
      } else {
        throw Exception(
            'Failed to create live class: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating live class: $e');
    }
  }

  /// Update live class details (PATCH)
  Future<TeacherLiveClass> patchLiveClass(String liveClassId, Map<String, dynamic> updates) async {
    try {
      final response = await _client.patch(
        Uri.parse('$_baseUrl/teacher/live-classes/$liveClassId'),
        headers: await _getHeaders(),
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        final data = _toMap(json.decode(response.body));
        return TeacherLiveClass.fromJson(data);
      } else {
        throw Exception('Failed to update live class: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating live class: $e');
    }
  }

  /// Delete live class
  Future<void> deleteLiveClass(String liveClassId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/teacher/live-classes/$liveClassId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete live class: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting live class: $e');
    }
  }

  /// Get comments for a live class
  Future<List<Map<String, dynamic>>> getComments(String liveClassId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/student/live-classes/$liveClassId/comments'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final unwrapped = json.decode(response.body);
        final List<dynamic> list = unwrapped['data']['comments'] ?? [];
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Post a teacher comment or pinned message
  Future<Map<String, dynamic>?> postComment(String liveClassId, String text, {bool isPinned = false, String? parentId}) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/student/live-classes/$liveClassId/comments'),
        headers: await _getHeaders(),
        body: json.encode({
          'comment': text,
          'is_pinned': isPinned,
          if (parentId != null) 'parent_id': parentId,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final unwrapped = json.decode(response.body);
        return Map<String, dynamic>.from(unwrapped['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }





  // ========== Student Directory API ==========

  /// Get student directory
  Future<List<StudentDirectoryEntry>> getStudentDirectory({
    String? classId,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final params = <String, String>{};
      if (classId != null) params['class_name'] = classId;
      if (search != null) params['search'] = search;
      params['page'] = page.toString();
      params['limit'] = limit.toString();

      final queryString =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/students?$queryString'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['students', 'items', 'results'],
        );
        return data
            .map((item) => StudentDirectoryEntry.fromJson(item))
            .toList();
      } else {
        throw Exception('Failed to load students: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching students: $e');
    }
  }

  /// Get student details
  Future<StudentDirectoryEntry> getStudentDetails(String studentId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/students/$studentId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = _toMap(json.decode(response.body));
        return StudentDirectoryEntry.fromJson(data);
      } else {
        throw Exception('Failed to load student: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching student: $e');
    }
  }

  // ========== My Classes API ==========

  /// Get teacher's classes
  Future<List<TeacherMyClass>> getMyClasses() async {
    try {
      final response = await _getWithFallback([
        '/teacher/classes',
        '/teacher/my-classes',
      ]);

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['classes', 'items', 'results'],
        );
        return data.map((item) => TeacherMyClass.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load classes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching classes: $e');
    }
  }

  // ========== Notices API ==========

  /// Get notices for teacher
  Future<List<TeacherNotice>> getNotices({
    String? noticeType,
    String? tab,
    String? search,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final params = <String, String>{};
      if (noticeType != null && noticeType != 'All') params['category'] = noticeType;
      if (tab != null) params['tab'] = tab;
      if (search != null) params['search'] = search;
      params['page'] = page.toString();
      params['limit'] = limit.toString();

      final queryString =
          params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final response = await _getWithFallback([
        '/teacher/notices?$queryString',
        '/teacher/notices',
      ]);

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['notices', 'items', 'results'],
        );
        return data.map((item) => TeacherNotice.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load notices: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching notices: $e');
    }
  }

  /// Create notice
  Future<bool> createNotice({
    required String title,
    required String content,
    required String category,
    required String status,
    bool isUrgent = false,
    String? scheduledAt,
    String? targetAudience,
    String? attachmentUrl,
    List<String>? targetClasses,
  }) async {
    try {
      final response = await _postWithFallback(
        paths: ['/teacher/notices/create', '/teacher/notices'],
        body: {
          'title': title,
          'content': content,
          'category': category,
          'status': status,
          'is_urgent': isUrgent,
          'scheduled_at': scheduledAt,
          'target_audience': targetAudience ?? 'all',
          'attachment_url': attachmentUrl,
          'target_classes': targetClasses,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Error creating notice: $e');
    }
  }

  /// Update notice
  Future<bool> updateNotice({
    required String noticeId,
    required String title,
    required String content,
    required String category,
    required String status,
    bool isUrgent = false,
    String? scheduledAt,
    String? targetAudience,
    String? attachmentUrl,
    List<String>? targetClasses,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.put(
        Uri.parse('$_baseUrl/teacher/notices/$noticeId'),
        headers: headers,
        body: json.encode({
          'title': title,
          'content': content,
          'category': category,
          'status': status,
          'is_urgent': isUrgent,
          'scheduled_at': scheduledAt,
          'target_audience': targetAudience ?? 'all',
          'attachment_url': attachmentUrl,
          'target_classes': targetClasses,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error updating notice: $e');
    }
  }

  /// Delete notice
  Future<bool> deleteNotice(String noticeId) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.delete(
        Uri.parse('$_baseUrl/teacher/notices/$noticeId'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error deleting notice: $e');
    }
  }

  /// Get registered students list for a notice event
  Future<List<Map<String, dynamic>>> getNoticeRegistrations(String noticeId) async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/notices/$noticeId/registrations'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);
        final List<dynamic> data = decoded['data']?['registrations'] ?? [];
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        throw Exception('Failed to load registrations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching notice registrations: $e');
    }
  }

  // ========== Notifications API ==========

  /// Get notifications for teacher
  Future<List<TeacherNotification>> getNotifications({
    String? type,
    bool? isRead,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final params = <String, String>{};
      if (type != null) params['type'] = type;
      if (isRead != null) params['is_read'] = isRead.toString();
      params['page'] = page.toString();
      params['limit'] = limit.toString();

      final queryString =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final response = await _getWithFallback([
        '/teacher/notifications?$queryString',
        '/teacher/notifications',
      ]);

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['notifications', 'items', 'results'],
        );
        return data.map((item) => TeacherNotification.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load notifications: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching notifications: $e');
    }
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final response = await _client.patch(
        Uri.parse('$_baseUrl/teacher/notifications/$notificationId/read'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
            'Failed to mark notification as read: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error marking notification: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    try {
      final response = await _client.patch(
        Uri.parse('$_baseUrl/notifications/read-all'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to mark all as read: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error marking all notifications: $e');
    }
  }

  /// Delete a single notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/teacher/notifications/$notificationId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete notification: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting notification: $e');
    }
  }

  // ========== Salary API ==========

  /// Get salary slips
  Future<List<SalarySlip>> getSalarySlips({
    int? year,
    int page = 1,
    int limit = 12,
  }) async {
    try {
      final params = <String, String>{};
      if (year != null) params['year'] = year.toString();
      params['page'] = page.toString();
      params['limit'] = limit.toString();

      final queryString =
          params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final response = await _getWithFallback([
        '/teacher/salary?$queryString',
        '/teacher/salary',
      ]);

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['salary_slips', 'salary_history', 'items', 'results'],
        );
        return data.map((item) => SalarySlip.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load salary slips: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching salary slips: $e');
    }
  }

  /// Get specific salary slip
  Future<SalarySlip> getSalarySlip(String slipId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/salary/$slipId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = _toMap(json.decode(response.body));
        return SalarySlip.fromJson(data);
      } else {
        throw Exception('Failed to load salary slip: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching salary slip: $e');
    }
  }

  /// Get salary advance history
  Future<List<SalaryAdvance>> getSalaryAdvances() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/salary/advance'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['salary_advances', 'items', 'results', 'data'],
        );
        return data.map((item) => SalaryAdvance.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load salary advances: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching salary advances: $e');
    }
  }

  /// Request salary advance
  Future<void> requestSalaryAdvance({
    required double amount,
    required String purposeType,
    String? reason,
    required int month,
    required int year,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/salary/advance'),
        headers: await _getHeaders(),
        body: json.encode({
          'amount': amount,
          'purpose_type': purposeType,
          'reason': reason,
          'month': month,
          'year': year,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final errBody = json.decode(response.body);
        final errMsg = errBody['detail'] ?? errBody['message'] ?? 'Failed to request advance';
        throw Exception(errMsg);
      }
    } catch (e) {
      throw Exception('Error requesting salary advance: $e');
    }
  }

  /// Simulate salary advance approval (debug)
  Future<void> simulateAdvanceApproval(String advanceId) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/salary/advance/$advanceId/approve-debug'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        final errBody = json.decode(response.body);
        final errMsg = errBody['detail'] ?? errBody['message'] ?? 'Failed to approve advance';
        throw Exception(errMsg);
      }
    } catch (e) {
      throw Exception('Error simulating advance approval: $e');
    }
  }

  /// Cancel salary advance request
  Future<void> cancelSalaryAdvance(String advanceId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/teacher/salary/advance/$advanceId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        final errBody = json.decode(response.body);
        final errMsg = errBody['detail'] ?? errBody['message'] ?? 'Failed to cancel advance';
        throw Exception(errMsg);
      }
    } catch (e) {
      throw Exception('Error cancelling salary advance: $e');
    }
  }

  // ========== Paper Builder API ==========

  /// Get question bank
  Future<List<QuestionBankItem>> getQuestionBank({
    String? subject,
    String? classId,
    String? questionType,
    String? difficulty,
    String? chapter,
    String? topic,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final params = <String, String>{};
      if (subject != null) params['subject'] = subject;
      if (classId != null) params['class'] = classId;
      if (questionType != null) params['type'] = questionType;
      if (difficulty != null) params['difficulty'] = difficulty;
      if (chapter != null) params['chapter'] = chapter;
      if (topic != null) params['topic'] = topic;
      params['page'] = page.toString();
      params['limit'] = limit.toString();

      final uri = Uri.parse('$_baseUrl/teacher/question-bank').replace(queryParameters: params);
      
      final response = await _client.get(
        uri,
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = _toMap(decoded);
        final list = (data['questions'] ?? data['data']?['questions']) as List? ?? [];
        return list.map((e) => QuestionBankItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      } else {
        throw Exception('Failed to load questions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching questions: $e');
    }
  }

  /// Add question to bank
  Future<PaperQuestion> addQuestion({
    required String questionText,
    required String subject,
    required String classId,
    required String questionType,
    required int marks,
    String? difficulty,
    String? chapter,
    String? topic,
    List<String>? options,
    String? correctAnswer,
    String? explanation,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/question-bank'),
        headers: await _getHeaders(),
        body: json.encode({
          'question_text': questionText,
          'subject': subject,
          'class': classId,
          'question_type': questionType,
          'marks': marks,
          'difficulty': difficulty,
          'chapter': chapter,
          'topic': topic,
          'options': options,
          'correct_answer': correctAnswer,
          'explanation': explanation,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = _toMap(json.decode(response.body));
        return PaperQuestion.fromJson(data);
      } else {
        throw Exception('Failed to add question: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error adding question: $e');
    }
  }

  /// Generate paper from question bank
  Future<Map<String, dynamic>> generatePaper({
    required String title,
    required String subject,
    required String classId,
    required int totalMarks,
    required String duration,
    Map<String, int>?
        questionDistribution, // e.g., {'mcq': 10, 'short': 5, 'long': 3}
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/paper-builder/generate'),
        headers: await _getHeaders(),
        body: json.encode({
          'title': title,
          'subject': subject,
          'class': classId,
          'total_marks': totalMarks,
          'duration': duration,
          'question_distribution': questionDistribution,
        }),
      );

      if (response.statusCode == 200) {
        return _toMap(json.decode(response.body));
      } else {
        throw Exception('Failed to generate paper: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error generating paper: $e');
    }
  }

  /// Get single exam details
  Future<Map<String, dynamic>> getExam(String examId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/exams/$examId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return _toMap(decoded);
      } else {
        throw Exception('Failed to load exam details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching exam details: $e');
    }
  }

  /// Get exam manual attendance for offline exams
  Future<Map<String, dynamic>> getExamAttendance(String examId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/exams/$examId/attendance'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load exam attendance: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching exam attendance: $e');
    }
  }

  /// Save exam manual attendance for offline exams
  Future<Map<String, dynamic>> saveExamAttendance(String examId, List<String> studentIds) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/exams/$examId/attendance'),
        headers: await _getHeaders(),
        body: json.encode({'student_ids': studentIds}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to save exam attendance: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error saving exam attendance: $e');
    }
  }

  /// Get all live student sessions for an exam
  Future<List<Map<String, dynamic>>> getExamSessions(String examId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/exams/$examId/sessions'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = _toMap(decoded);
        final sessions = (data['sessions'] ?? data['data']?['sessions']) as List? ?? [];
        return sessions.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        throw Exception('Failed to load exam sessions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching exam sessions: $e');
    }
  }

  /// Send a proctor action command to a student session
  Future<Map<String, dynamic>> sendProctorAction(
    String examId,
    String sessionId, {
    required String action,
    int? extraMinutes,
    String? message,
    bool? cameraActive,
    bool? micActive,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/exams/$examId/sessions/$sessionId/action'),
        headers: await _getHeaders(),
        body: json.encode({
          'action': action,
          'extra_minutes': extraMinutes,
          'message': message,
          if (cameraActive != null) 'camera_active': cameraActive,
          if (micActive != null) 'mic_active': micActive,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to send proctor action: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error sending proctor action: $e');
    }
  }

  /// Get LiveKit room join token
  Future<Map<String, dynamic>> getLiveKitToken({required String room, String? identity, String? name}) async {
    try {
      final queryParams = {
        'room': room,
        if (identity != null) 'identity': identity,
        if (name != null) 'name': name,
      };
      final response = await _client.get(
        Uri.parse('$_baseUrl/livekit/token').replace(queryParameters: queryParams),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load LiveKit token: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get LiveKit token failed: $e');
    }
  }

  /// Get student submissions for manual evaluation
  Future<List<Map<String, dynamic>>> getExamSubmissions(String examId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/exams/$examId/submissions'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = _toMap(decoded);
        final submissions = (data['submissions'] ?? data['data']?['submissions']) as List? ?? [];
        return submissions.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        throw Exception('Failed to load exam submissions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching exam submissions: $e');
    }
  }

  /// Grade a student subjective/overall submission score
  Future<Map<String, dynamic>> gradeExamSubmission(
    String examId,
    String submissionId, {
    required double score,
    String? remarks,
    Map<String, dynamic>? answers,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/exams/$examId/submissions/$submissionId/grade'),
        headers: await _getHeaders(),
        body: json.encode({
          'score': score,
          if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
          if (answers != null) 'answers': answers,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to grade submission: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error grading submission: $e');
    }
  }

  /// Get analytics for a specific exam (real aggregated stats)
  Future<Map<String, dynamic>> getExamAnalytics(String examId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/exams/$examId/analytics'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = _toMap(decoded);
        return (data['data'] ?? data) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to load exam analytics: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching exam analytics: $e');
    }
  }

  /// Publish exam results to students (computes ranks, updates exam status)
  Future<Map<String, dynamic>> publishExamResults(String examId) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/exams/$examId/results/publish'),
        headers: await _getHeaders(),
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to publish results: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error publishing exam results: $e');
    }
  }

  /// Get all questions for a specific exam
  Future<List<Map<String, dynamic>>> getExamQuestions(String examId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/exams/$examId/questions'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = _toMap(decoded);
        final questions = (data['questions'] ?? data['data']?['questions']) as List? ?? [];
        return questions.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        throw Exception('Failed to load exam questions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching exam questions: $e');
    }
  }

  /// Add question to exam questions directly
  Future<Map<String, dynamic>> addExamQuestion(String examId, Map<String, dynamic> question) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/exams/$examId/questions'),
        headers: await _getHeaders(),
        body: json.encode(question),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = _toMap(decoded);
        return data;
      } else {
        throw Exception('Failed to add exam question: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error adding exam question: $e');
    }
  }

  /// Update exam question
  Future<Map<String, dynamic>> updateExamQuestion(String examId, String questionId, Map<String, dynamic> updates) async {
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/teacher/exams/$examId/questions/$questionId'),
        headers: await _getHeaders(),
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = _toMap(decoded);
        return data;
      } else {
        throw Exception('Failed to update exam question: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating exam question: $e');
    }
  }

  /// Delete exam question
  Future<void> deleteExamQuestion(String examId, String questionId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/teacher/exams/$examId/questions/$questionId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete exam question: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting exam question: $e');
    }
  }


  /// Add question to bank
  Future<QuestionBankItem> addQuestionToBank(Map<String, dynamic> question) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/question-bank'),
        headers: await _getHeaders(),
        body: json.encode(question),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = _toMap(decoded);
        final item = data['data'] ?? data;
        return QuestionBankItem.fromJson(Map<String, dynamic>.from(item as Map));
      } else {
        throw Exception('Failed to add question to bank: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error adding question to bank: $e');
    }
  }

  /// Update question in bank
  Future<QuestionBankItem> updateQuestionInBank(String id, Map<String, dynamic> updates) async {
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/teacher/question-bank/$id'),
        headers: await _getHeaders(),
        body: json.encode(updates),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = _toMap(decoded);
        final item = data['data'] ?? data;
        return QuestionBankItem.fromJson(Map<String, dynamic>.from(item as Map));
      } else {
        throw Exception('Failed to update question in bank: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating question in bank: $e');
    }
  }

  /// Delete question from bank
  Future<void> deleteQuestionFromBank(String id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/teacher/question-bank/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete question from bank: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting question from bank: $e');
    }
  }

  /// Bulk upload questions
  Future<int> bulkUploadQuestions(String csvContent, String subject, String questionType) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/question-bank/bulk-upload'),
        headers: await _getHeaders(),
        body: json.encode({
          'csv_content': csvContent,
          'subject': subject,
          'question_type': questionType,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = _toMap(decoded);
        return data['count'] as int? ?? 0;
      } else {
        throw Exception('Failed to bulk upload questions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error bulk uploading questions: $e');
    }
  }

  /// Get course details (chapters & topics) for teacher
  Future<Map<String, dynamic>> getCourseDetails(String courseId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/courses/$courseId/details'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return decoded['data'] ?? decoded;
      } else {
        return {'course': {}, 'chapters': []};
      }
    } catch (e) {
      return {'course': {}, 'chapters': []};
    }
  }

  /// Create a new course chapter
  Future<Map<String, dynamic>> createChapter(String courseId, Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/teacher/courses/$courseId/chapters'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return decoded['data'] ?? decoded;
    } else {
      throw Exception('Failed to create chapter: ${response.statusCode}');
    }
  }

  /// Update an existing chapter
  Future<Map<String, dynamic>> updateChapter(String chapterId, Map<String, dynamic> data) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/teacher/courses/chapters/$chapterId'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return decoded['data'] ?? decoded;
    } else {
      throw Exception('Failed to update chapter: ${response.statusCode}');
    }
  }

  /// Delete a chapter
  Future<void> deleteChapter(String chapterId) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/teacher/courses/chapters/$chapterId'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete chapter: ${response.statusCode}');
    }
  }

  /// Create a new topic under a chapter
  Future<Map<String, dynamic>> createTopic(String chapterId, Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/teacher/courses/chapters/$chapterId/topics'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return decoded['data'] ?? decoded;
    } else {
      throw Exception('Failed to create topic: ${response.statusCode}');
    }
  }

  /// Update an existing topic
  Future<Map<String, dynamic>> updateTopic(String topicId, Map<String, dynamic> data) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/teacher/courses/topics/$topicId'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return decoded['data'] ?? decoded;
    } else {
      throw Exception('Failed to update topic: ${response.statusCode}');
    }
  }

  /// Delete a topic
  Future<void> deleteTopic(String topicId) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/teacher/courses/topics/$topicId'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete topic: ${response.statusCode}');
    }
  }

  /// Get courses for a class
  Future<List<dynamic>> getClassCourses(String classId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/classes/$classId/courses'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return decoded['data'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // ============================================
  // TEACHER ACHIEVEMENTS & TASKS
  // ============================================

  /// Get all achievement/task templates
  Future<List<dynamic>> getTeacherTasks() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/achievements/tasks'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>? ?? {};
        return data['tasks'] as List<dynamic>? ?? [];
      } else {
        throw Exception('Failed to load tasks: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Load tasks request failed: $e');
    }
  }

  /// Create a new task template
  Future<Map<String, dynamic>> createTeacherTask(Map<String, dynamic> taskData) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/achievements/tasks'),
        headers: await _getHeaders(),
        body: json.encode(taskData),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return decoded['data'] as Map<String, dynamic>? ?? {};
      } else {
        throw Exception('Failed to create task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Create task request failed: $e');
    }
  }

  /// Update an existing task template
  Future<void> updateTeacherTask(String taskId, Map<String, dynamic> taskData) async {
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/teacher/achievements/tasks/$taskId'),
        headers: await _getHeaders(),
        body: json.encode(taskData),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Update task request failed: $e');
    }
  }

  /// Delete a task template
  Future<void> deleteTeacherTask(String taskId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/teacher/achievements/tasks/$taskId'),
        headers: await _getHeaders(),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to delete task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Delete task request failed: $e');
    }
  }

  /// Get student achievements progress list for a classroom
  Future<List<dynamic>> getStudentProgress(String className) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/teacher/achievements/student-progress').replace(
          queryParameters: {'class_name': className},
        ),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>? ?? {};
        return data['students'] as List<dynamic>? ?? [];
      } else {
        throw Exception('Failed to load student progress: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Load student progress request failed: $e');
    }
  }

  /// Manually unlock a task for a student
  Future<bool> unlockStudentTask(String studentId, String taskId) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/achievements/unlock'),
        headers: await _getHeaders(),
        body: json.encode({
          'student_id': studentId,
          'task_id': taskId,
        }),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to unlock task: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Unlock task request failed: $e');
    }
  }

  /// Deduct/apply an XP penalty to a student
  Future<bool> applyStudentPenalty(String studentId, int amount, String reason) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/teacher/achievements/penalty'),
        headers: await _getHeaders(),
        body: json.encode({
          'student_id': studentId,
          'amount': amount,
          'reason': reason,
        }),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        try {
          final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
          if (data.containsKey('detail')) {
            throw Exception(data['detail']);
          }
        } catch (_) {}
        throw Exception('Failed to apply penalty: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
