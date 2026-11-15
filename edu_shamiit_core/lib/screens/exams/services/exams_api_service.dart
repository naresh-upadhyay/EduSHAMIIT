import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/app_config.dart';
import '../../../models/teacher_models.dart';

/// Generic Universal API Service for Examinations and Question Bank management.
/// Works seamlessly across both Academic (Teacher) and Admin portals.
class ExamsApiService {
  static final ExamsApiService instance = ExamsApiService._internal();
  factory ExamsApiService() => instance;
  ExamsApiService._internal();

  final http.Client _client = http.Client();

  String get baseUrl => AppConfig.apiBaseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _toMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  List<dynamic> _toList(dynamic decoded, {List<String>? candidateKeys}) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      if (candidateKeys != null) {
        for (var k in candidateKeys) {
          if (decoded.containsKey(k) && decoded[k] is List) {
            return decoded[k] as List;
          }
        }
      }
      if (decoded.containsKey('data')) {
        final d = decoded['data'];
        if (d is List) return d;
        if (d is Map && candidateKeys != null) {
          for (var k in candidateKeys) {
            if (d.containsKey(k) && d[k] is List) {
              return d[k] as List;
            }
          }
        }
      }
    }
    return [];
  }

  // ============================================================================
  // 1. EXAM CRUD & RETRIEVAL
  // ============================================================================

  /// Get exams with optional filters
  Future<List<TeacherExam>> getExams({
    String? classId,
    String? examType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final params = <String, String>{};
      if (classId != null) params['class_name'] = classId;
      if (examType != null) params['type'] = examType;
      if (startDate != null) {
        params['start_date'] = startDate.toIso8601String().split('T')[0];
      }
      if (endDate != null) {
        params['end_date'] = endDate.toIso8601String().split('T')[0];
      }

      final queryString = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final querySuffix = queryString.isNotEmpty ? '?$queryString' : '';

      final endpoints = [
        '$baseUrl/exams$querySuffix',
        '$baseUrl/v1/exams$querySuffix',
        '$baseUrl/teacher/exams$querySuffix',
      ];

      http.Response? response;
      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            response = res;
            break;
          }
        } catch (_) {}
      }

      if (response != null && response.statusCode == 200) {
        final List<dynamic> data = _toList(
          json.decode(response.body),
          candidateKeys: ['exams', 'items', 'results'],
        );
        return data.map((item) => TeacherExam.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      } else {
        throw Exception('Failed to load exams: ${response?.statusCode ?? "no response"}');
      }
    } catch (e) {
      throw Exception('Error fetching exams: $e');
    }
  }

  /// Get executive dashboard overview (KPIs, 8-month trend, top performers, calendar, recent activities)
  Future<Map<String, dynamic>> getExamsDashboardOverview() async {
    try {
      final endpoints = [
        '$baseUrl/exams/dashboard/overview',
        '$baseUrl/v1/exams/dashboard/overview',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            return (data['data'] is Map ? _toMap(data['data']) : data);
          }
        } catch (_) {}
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Get paginated and filtered exams matching executive dashboard table
  Future<Map<String, dynamic>> getExamsPaged({
    String statusTab = 'all',
    String? search,
    String? className,
    String? type,
    String? status,
    String? startDate,
    String? endDate,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final params = <String, String>{
        'status_tab': statusTab,
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
      if (className != null && className != 'All' && className != 'All Classes') params['class_name'] = className;
      if (type != null && type != 'All' && type != 'All Types') params['type'] = type;
      if (status != null && status != 'All' && status != 'All Status') params['status'] = status;
      if (startDate != null) params['start_date'] = startDate;
      if (endDate != null) params['end_date'] = endDate;

      final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final endpoints = [
        '$baseUrl/exams?$qs',
        '$baseUrl/v1/exams?$qs',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            final payload = data['data'] is Map ? _toMap(data['data']) : data;
            final rawExams = payload['exams'] is List ? payload['exams'] as List : [];
            final items = rawExams.map((e) => Map<String, dynamic>.from(e as Map)).toList();

            return {
              'exams': items,
              'total_count': payload['total_count'] ?? items.length,
              'page': payload['page'] ?? page,
              'page_size': payload['page_size'] ?? pageSize,
              'total_pages': payload['total_pages'] ?? 1,
              'tab_counts': payload['tab_counts'] is Map ? Map<String, dynamic>.from(payload['tab_counts'] as Map) : {},
              'kpis': payload['kpis'] is Map ? Map<String, dynamic>.from(payload['kpis'] as Map) : {},
            };
          }
        } catch (_) {}
      }
      return {'exams': <Map<String, dynamic>>[], 'total_count': 0, 'page': page, 'page_size': pageSize, 'total_pages': 1, 'tab_counts': {}, 'kpis': {}};
    } catch (e) {
      return {'exams': <Map<String, dynamic>>[], 'total_count': 0, 'page': page, 'page_size': pageSize, 'total_pages': 1, 'tab_counts': {}, 'kpis': {}};
    }
  }

  /// Get dynamic dropdown lookup values from Lookup Key-Value management
  Future<Map<String, dynamic>> getExamManagementLookups() async {
    try {
      final endpoints = [
        '$baseUrl/exams/lookups/exam-management',
        '$baseUrl/v1/exams/lookups/exam-management',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            return (data['data'] is Map ? _toMap(data['data']) : data);
          }
        } catch (_) {}
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Get exam schedule / date sheet
  Future<List<Map<String, dynamic>>> getExamSchedules(String examId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/schedules',
        '$baseUrl/v1/exams/$examId/schedules',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final list = _toList(decoded);
            return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (_) {}
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Create exam schedule item
  Future<Map<String, dynamic>> createExamSchedule(String examId, Map<String, dynamic> data) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/schedules',
        '$baseUrl/v1/exams/$examId/schedules',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.post(Uri.parse(ep), headers: await _getHeaders(), body: json.encode(data));
          if (res.statusCode == 200 || res.statusCode == 201) {
            final decoded = json.decode(res.body);
            return _toMap(decoded);
          }
        } catch (_) {}
      }
      throw Exception('Failed to create schedule');
    } catch (e) {
      throw Exception('Schedule creation error: $e');
    }
  }

  /// Delete exam schedule
  Future<void> deleteExamSchedule(String scheduleId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/schedules/$scheduleId',
        '$baseUrl/v1/exams/schedules/$scheduleId',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.delete(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) return;
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Get student marks roster
  Future<List<Map<String, dynamic>>> getExamMarks(String examId, {String? subjectId, String? className}) async {
    try {
      final params = <String, String>{};
      if (subjectId != null) params['subject_id'] = subjectId;
      if (className != null) params['class_name'] = className;
      final qs = params.isNotEmpty ? '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}' : '';

      final endpoints = [
        '$baseUrl/exams/$examId/marks$qs',
        '$baseUrl/v1/exams/$examId/marks$qs',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final list = _toList(decoded);
            return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (_) {}
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Save student marks roster
  Future<Map<String, dynamic>> saveExamMarks(String examId, List<Map<String, dynamic>> entries, {String? subjectId, String? subjectName}) async {
    try {
      final body = {
        'entries': entries,
        if (subjectId != null) 'subject_id': subjectId,
        if (subjectName != null) 'subject_name': subjectName,
      };
      final endpoints = [
        '$baseUrl/exams/$examId/marks',
        '$baseUrl/v1/exams/$examId/marks',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.post(Uri.parse(ep), headers: await _getHeaders(), body: json.encode(body));
          if (res.statusCode == 200 || res.statusCode == 201) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      throw Exception('Failed to save marks');
    } catch (e) {
      throw Exception('Marks saving error: $e');
    }
  }

  /// Calculate examination results
  Future<Map<String, dynamic>> calculateExamResults(String examId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/results/calculate',
        '$baseUrl/v1/exams/$examId/results/calculate',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.post(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) return _toMap(json.decode(res.body));
        } catch (_) {}
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Get examination results summary
  Future<Map<String, dynamic>> getExamResults(String examId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/results',
        '$baseUrl/v1/exams/$examId/results',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) return _toMap(json.decode(res.body));
        } catch (_) {}
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Get single exam details
  Future<Map<String, dynamic>> getExam(String examId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId',
        '$baseUrl/v1/exams/$examId',
        '$baseUrl/teacher/exams/$examId',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            return (data['data'] is Map ? _toMap(data['data']) : data);
          }
        } catch (_) {}
      }
      throw Exception('Failed to load exam details');
    } catch (e) {
      throw Exception('Error fetching exam details: $e');
    }
  }

  /// Create a new exam
  Future<TeacherExam> createExam({
    required String title,
    required String subject,
    List<String> targetClasses = const [],
    List<String> applicableSections = const [],
    List<String> targetStudents = const [],
    String? scope,
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
      final payload = {
        'title': title,
        'subject': subject,
        if (subjectId != null) 'subject_id': subjectId,
        'target_classes': targetClasses,
        'applicable_sections': applicableSections,
        'target_students': targetStudents,
        'scope': scope ?? (targetStudents.isNotEmpty && targetClasses.isEmpty ? 'Targeted Users' : (targetClasses.isNotEmpty ? 'Target Classes' : 'All Students')),
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
      };

      final endpoints = [
        '$baseUrl/exams/create',
        '$baseUrl/exams',
        '$baseUrl/v1/exams/create',
        '$baseUrl/teacher/exams/create',
        '$baseUrl/teacher/exams',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode(payload),
          );
          if (res.statusCode == 200 || res.statusCode == 201) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            final examData = data['data'] ?? data;
            return TeacherExam.fromJson(Map<String, dynamic>.from(examData as Map));
          }
        } catch (_) {}
      }
      throw Exception('Failed to create exam');
    } catch (e) {
      throw Exception('Error creating exam: $e');
    }
  }

  /// Update existing exam
  Future<void> updateExam(String examId, Map<String, dynamic> updates) async {
    String? lastError;
    final endpoints = [
      '$baseUrl/exams/$examId',
      '$baseUrl/v1/exams/$examId',
      '$baseUrl/teacher/exams/$examId',
    ];

    for (final ep in endpoints) {
      try {
        final res = await _client.put(
          Uri.parse(ep),
          headers: await _getHeaders(),
          body: json.encode(updates),
        );
        if (res.statusCode == 200) {
          return;
        }
        lastError = _extractApiError(res, 'Failed to update exam (HTTP ${res.statusCode})');
        if (res.statusCode >= 400 && res.statusCode < 500) {
          throw Exception(lastError);
        }
      } catch (e) {
        lastError = e.toString().replaceAll('Exception: ', '');
        if (!lastError.contains('SocketException')) rethrow;
      }
    }
    throw Exception(lastError ?? 'Failed to update exam');
  }

  /// Delete exam
  Future<void> deleteExam(String examId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId',
        '$baseUrl/v1/exams/$examId',
        '$baseUrl/teacher/exams/$examId',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.delete(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            return;
          }
        } catch (_) {}
      }
      throw Exception('Failed to delete exam');
    } catch (e) {
      throw Exception('Error deleting exam: $e');
    }
  }

  /// Bulk update examination status
  Future<Map<String, dynamic>> bulkUpdateExamStatus(List<String> examIds, String status) async {
    try {
      final endpoints = [
        '$baseUrl/exams/bulk/status',
        '$baseUrl/v1/exams/bulk/status',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode({'exam_ids': examIds, 'status': status}),
          );
          if (res.statusCode == 200) {
            try {
              final decoded = json.decode(res.body);
              if (decoded is Map<String, dynamic>) return decoded;
              return {'success': true, 'updated_count': examIds.length};
            } catch (_) {
              return {'success': true, 'updated_count': examIds.length};
            }
          }
        } catch (_) {}
      }
      throw Exception('Failed to update status for selected examinations');
    } catch (e) {
      throw Exception('Error updating bulk exam status: $e');
    }
  }

  /// Bulk publish results for multiple examinations
  Future<Map<String, dynamic>> bulkPublishExams(List<String> examIds) async {
    try {
      final endpoints = [
        '$baseUrl/exams/bulk/publish',
        '$baseUrl/v1/exams/bulk/publish',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode({'exam_ids': examIds}),
          );
          if (res.statusCode == 200) {
            try {
              final decoded = json.decode(res.body);
              if (decoded is Map<String, dynamic>) return decoded;
              return {'success': true, 'updated_count': examIds.length};
            } catch (_) {
              return {'success': true, 'updated_count': examIds.length};
            }
          }
        } catch (_) {}
      }
      throw Exception('Failed to bulk publish examination results');
    } catch (e) {
      throw Exception('Error publishing bulk exam results: $e');
    }
  }

  /// Bulk export schedule & hall ticket metadata as CSV bytes
  Future<Uint8List> bulkExportSchedules(List<String> examIds) async {
    try {
      final endpoints = [
        '$baseUrl/exams/bulk/export-schedules',
        '$baseUrl/v1/exams/bulk/export-schedules',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode({'exam_ids': examIds}),
          );
          if (res.statusCode == 200) return res.bodyBytes;
        } catch (_) {}
      }
      throw Exception('Failed to export examination schedules');
    } catch (e) {
      throw Exception('Error exporting examination schedules: $e');
    }
  }

  /// Export question bank data with Bearer token authentication
  Future<Uint8List> exportQuestionBankFile({String type = 'all', String? subject}) async {
    try {
      final qs = 'type=$type${subject != null ? "&subject=$subject" : ""}';
      final endpoints = [
        '$baseUrl/exams/question-bank/export-template?$qs',
        '$baseUrl/question-bank/export-template?$qs',
        '$baseUrl/v1/question-bank/export-template?$qs',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) return res.bodyBytes;
        } catch (_) {}
      }
      throw Exception('Failed to download question repository file');
    } catch (e) {
      throw Exception('Error exporting question bank: $e');
    }
  }

  /// Download exam paper as PDF
  Future<Uint8List> downloadExamPaperPdf(String examId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/pdf',
        '$baseUrl/v1/exams/$examId/pdf',
        '$baseUrl/teacher/exams/$examId/pdf',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            return res.bodyBytes;
          }
        } catch (_) {}
      }
      throw Exception('Failed to download exam paper PDF');
    } catch (e) {
      throw Exception('Error downloading exam paper: $e');
    }
  }

  // ============================================================================
  // 2. EXAM QUESTIONS MANAGEMENT
  // ============================================================================

  /// Get questions for an exam
  Future<List<Map<String, dynamic>>> getExamQuestions(String examId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/questions',
        '$baseUrl/v1/exams/$examId/questions',
        '$baseUrl/teacher/exams/$examId/questions',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            final questions = (data['questions'] ?? data['data']?['questions']) as List? ?? [];
            return questions.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (_) {}
      }
      return [];
    } catch (e) {
      throw Exception('Error fetching exam questions: $e');
    }
  }

  /// Add question to exam directly
  Future<Map<String, dynamic>> addExamQuestion(String examId, Map<String, dynamic> question) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/questions',
        '$baseUrl/v1/exams/$examId/questions',
        '$baseUrl/teacher/exams/$examId/questions',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode(question),
          );
          if (res.statusCode == 200 || res.statusCode == 201) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      throw Exception('Failed to add exam question');
    } catch (e) {
      throw Exception('Error adding exam question: $e');
    }
  }

  /// Update exam question
  Future<Map<String, dynamic>> updateExamQuestion(String examId, String questionId, Map<String, dynamic> updates) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/questions/$questionId',
        '$baseUrl/v1/exams/$examId/questions/$questionId',
        '$baseUrl/teacher/exams/$examId/questions/$questionId',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.put(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode(updates),
          );
          if (res.statusCode == 200) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      throw Exception('Failed to update exam question');
    } catch (e) {
      throw Exception('Error updating exam question: $e');
    }
  }

  /// Delete exam question
  Future<void> deleteExamQuestion(String examId, String questionId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/questions/$questionId',
        '$baseUrl/v1/exams/$examId/questions/$questionId',
        '$baseUrl/teacher/exams/$examId/questions/$questionId',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.delete(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) return;
        } catch (_) {}
      }
      throw Exception('Failed to delete exam question');
    } catch (e) {
      throw Exception('Error deleting exam question: $e');
    }
  }

  // ============================================================================
  // 3. ATTENDANCE & PROCTORING (ONLINE / OFFLINE)
  // ============================================================================

  /// Get exam attendance for offline exams
  Future<Map<String, dynamic>> getExamAttendance(String examId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/attendance',
        '$baseUrl/v1/exams/$examId/attendance',
        '$baseUrl/teacher/exams/$examId/attendance',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      return {'students': []};
    } catch (e) {
      throw Exception('Error fetching exam attendance: $e');
    }
  }

  /// Save exam attendance for offline exams
  Future<Map<String, dynamic>> saveExamAttendance(String examId, List<String> studentIds) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/attendance',
        '$baseUrl/v1/exams/$examId/attendance',
        '$baseUrl/teacher/exams/$examId/attendance',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode({'student_ids': studentIds}),
          );
          if (res.statusCode == 200) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      throw Exception('Failed to save exam attendance');
    } catch (e) {
      throw Exception('Error saving exam attendance: $e');
    }
  }

  /// Get live student sessions for online exam monitoring
  Future<List<Map<String, dynamic>>> getExamSessions(String examId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/sessions',
        '$baseUrl/v1/exams/$examId/sessions',
        '$baseUrl/teacher/exams/$examId/sessions',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            final sessions = (data['sessions'] ?? data['data']?['sessions']) as List? ?? [];
            return sessions.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (_) {}
      }
      return [];
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
      final payload = {
        'action': action,
        'extra_minutes': extraMinutes,
        'message': message,
        if (cameraActive != null) 'camera_active': cameraActive,
        if (micActive != null) 'mic_active': micActive,
      };

      final endpoints = [
        '$baseUrl/exams/$examId/sessions/$sessionId/action',
        '$baseUrl/v1/exams/$examId/sessions/$sessionId/action',
        '$baseUrl/teacher/exams/$examId/sessions/$sessionId/action',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode(payload),
          );
          if (res.statusCode == 200) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      throw Exception('Failed to send proctor action');
    } catch (e) {
      throw Exception('Error sending proctor action: $e');
    }
  }

  /// Get LiveKit token for real-time video monitoring
  Future<Map<String, dynamic>> getLiveKitToken({required String room, String? identity, String? name}) async {
    try {
      final queryParams = {
        'room': room,
        if (identity != null) 'identity': identity,
        if (name != null) 'name': name,
      };

      final uri = Uri.parse('$baseUrl/livekit/token').replace(queryParameters: queryParams);
      final res = await _client.get(uri, headers: await _getHeaders());
      if (res.statusCode == 200) {
        return _toMap(json.decode(res.body));
      }
      throw Exception('Failed to get LiveKit token: ${res.statusCode}');
    } catch (e) {
      throw Exception('Get LiveKit token failed: $e');
    }
  }

  // ============================================================================
  // 4. SUBMISSIONS, EVALUATION & ANALYTICS
  // ============================================================================

  /// Get student submissions for evaluation
  Future<List<Map<String, dynamic>>> getExamSubmissions(String examId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/submissions',
        '$baseUrl/v1/exams/$examId/submissions',
        '$baseUrl/teacher/exams/$examId/submissions',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            final submissions = (data['submissions'] ?? data['data']?['submissions']) as List? ?? [];
            return submissions.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (_) {}
      }
      return [];
    } catch (e) {
      throw Exception('Error fetching exam submissions: $e');
    }
  }

  /// Grade a student submission
  Future<Map<String, dynamic>> gradeExamSubmission(
    String examId,
    String submissionId, {
    required double score,
    String? remarks,
    Map<String, dynamic>? answers,
  }) async {
    try {
      final payload = {
        'score': score,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        if (answers != null) 'answers': answers,
      };

      final endpoints = [
        '$baseUrl/exams/$examId/submissions/$submissionId/grade',
        '$baseUrl/v1/exams/$examId/submissions/$submissionId/grade',
        '$baseUrl/teacher/exams/$examId/submissions/$submissionId/grade',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode(payload),
          );
          if (res.statusCode == 200) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      throw Exception('Failed to grade submission');
    } catch (e) {
      throw Exception('Error grading submission: $e');
    }
  }

  /// Publish exam results
  Future<Map<String, dynamic>> publishExamResults(String examId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/results/publish',
        '$baseUrl/v1/exams/$examId/results/publish',
        '$baseUrl/teacher/exams/$examId/results/publish',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.post(Uri.parse(ep), headers: await _getHeaders(), body: json.encode({}));
          if (res.statusCode == 200) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      throw Exception('Failed to publish results');
    } catch (e) {
      throw Exception('Error publishing results: $e');
    }
  }

  /// Get exam analytics
  Future<Map<String, dynamic>> getExamAnalytics(String examId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/analytics',
        '$baseUrl/v1/exams/$examId/analytics',
        '$baseUrl/teacher/exams/$examId/analytics',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            return (data['data'] is Map ? _toMap(data['data']) : data);
          }
        } catch (_) {}
      }
      return {};
    } catch (e) {
      throw Exception('Error fetching exam analytics: $e');
    }
  }

  // ============================================================================
  // 5. QUESTION BANK & PAPER BUILDER
  // ============================================================================

  /// Get question bank questions
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

      final endpoints = [
        Uri.parse('$baseUrl/exams/question-bank').replace(queryParameters: params),
        Uri.parse('$baseUrl/question-bank').replace(queryParameters: params),
        Uri.parse('$baseUrl/teacher/question-bank').replace(queryParameters: params),
      ];

      for (final uri in endpoints) {
        try {
          final res = await _client.get(uri, headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            final list = (data['questions'] ?? data['data']?['questions']) as List? ?? [];
            return list.map((e) => QuestionBankItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          }
        } catch (_) {}
      }
      return [];
    } catch (e) {
      throw Exception('Error fetching question bank: $e');
    }
  }

  /// Add question to bank
  Future<QuestionBankItem> addQuestionToBank(Map<String, dynamic> question) async {
    try {
      final endpoints = [
        '$baseUrl/exams/question-bank',
        '$baseUrl/question-bank',
        '$baseUrl/teacher/question-bank',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode(question),
          );
          if (res.statusCode == 200 || res.statusCode == 201) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            final item = data['data'] ?? data;
            return QuestionBankItem.fromJson(Map<String, dynamic>.from(item as Map));
          }
        } catch (_) {}
      }
      throw Exception('Failed to add question to bank');
    } catch (e) {
      throw Exception('Error adding question to bank: $e');
    }
  }

  /// Update question in bank
  Future<QuestionBankItem> updateQuestionInBank(String id, Map<String, dynamic> updates) async {
    try {
      final endpoints = [
        '$baseUrl/exams/question-bank/$id',
        '$baseUrl/question-bank/$id',
        '$baseUrl/teacher/question-bank/$id',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.put(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode(updates),
          );
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            final item = data['data'] ?? data;
            return QuestionBankItem.fromJson(Map<String, dynamic>.from(item as Map));
          }
        } catch (_) {}
      }
      throw Exception('Failed to update question in bank');
    } catch (e) {
      throw Exception('Error updating question in bank: $e');
    }
  }

  /// Delete question from bank
  Future<void> deleteQuestionFromBank(String id) async {
    try {
      final endpoints = [
        '$baseUrl/exams/question-bank/$id',
        '$baseUrl/question-bank/$id',
        '$baseUrl/teacher/question-bank/$id',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.delete(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) return;
        } catch (_) {}
      }
      throw Exception('Failed to delete question from bank');
    } catch (e) {
      throw Exception('Error deleting question from bank: $e');
    }
  }

  /// Duplicate question in question bank
  Future<Map<String, dynamic>> duplicateQuestion(String id) async {
    try {
      final endpoints = [
        '$baseUrl/exams/question-bank/$id/duplicate',
        '$baseUrl/question-bank/$id/duplicate',
        '$baseUrl/teacher/question-bank/$id/duplicate',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.post(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200 || res.statusCode == 201) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      throw Exception('Failed to duplicate question');
    } catch (e) {
      throw Exception('Error duplicating question: $e');
    }
  }

  /// Bulk upload questions from CSV
  Future<int> bulkUploadQuestions(String csvContent, String subject, String questionType) async {
    try {
      final payload = {
        'csv_content': csvContent,
        'subject': subject,
        'question_type': questionType,
      };

      final endpoints = [
        '$baseUrl/exams/question-bank/bulk-upload',
        '$baseUrl/question-bank/bulk-upload',
        '$baseUrl/teacher/question-bank/bulk-upload',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode(payload),
          );
          if (res.statusCode == 200 || res.statusCode == 201) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            return data['count'] as int? ?? 0;
          }
        } catch (_) {}
      }
      throw Exception('Failed to bulk upload questions');
    } catch (e) {
      throw Exception('Error bulk uploading questions: $e');
    }
  }

  /// Upload an image or document bytes (e.g. for diagram questions)
  Future<String?> uploadFileBytes({
    required List<int> bytes,
    required String filename,
    String category = 'question_diagrams',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/documents/upload');
      final request = http.MultipartRequest('POST', uri);
      final headers = await _getHeaders();
      // Remove content-type so MultipartRequest sets boundary correctly
      headers.remove('Content-Type');
      headers.remove('content-type');
      request.headers.addAll(headers);
      request.fields['title'] = filename;
      request.fields['category'] = category;
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

      final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['data'] is Map && decoded['data']['document'] is Map) {
          return decoded['data']['document']['file_url']?.toString();
        }
        if (decoded is Map) {
          return decoded['url']?.toString() ?? decoded['file_url']?.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  /// Generate paper from question bank
  Future<Map<String, dynamic>> generatePaper({
    required String title,
    required String subject,
    required String classId,
    required int totalMarks,
    required String duration,
    Map<String, int>? questionDistribution,
  }) async {
    try {
      final payload = {
        'title': title,
        'subject': subject,
        'class': classId,
        'total_marks': totalMarks,
        'duration': duration,
        'question_distribution': questionDistribution,
      };

      final endpoints = [
        '$baseUrl/exams/paper-builder/generate',
        '$baseUrl/v1/exams/paper-builder/generate',
        '$baseUrl/teacher/paper-builder/generate',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode(payload),
          );
          if (res.statusCode == 200) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      throw Exception('Failed to generate paper');
    } catch (e) {
      throw Exception('Error generating paper: $e');
    }
  }

  // ============================================================================
  // 6. METADATA HELPERS (CLASSES, SUBJECTS, STUDENTS)
  // ============================================================================

  /// Get subjects available for exam creation
  Future<List<TeacherSubject>> getSubjects({String? classId, bool allSubjects = false}) async {
    try {
      final params = <String, String>{};
      if (allSubjects) params['all_subjects'] = 'true';
      if (classId != null) params['class_name'] = classId;

      final endpoints = [
        Uri.parse('$baseUrl/exams/meta/subjects').replace(queryParameters: params),
        Uri.parse('$baseUrl/teacher/subjects').replace(queryParameters: params),
      ];

      for (final uri in endpoints) {
        try {
          final res = await _client.get(uri, headers: await _getHeaders());
          if (res.statusCode == 200) {
            final List<dynamic> data = _toList(
              json.decode(res.body),
              candidateKeys: ['subjects', 'items', 'results'],
            );
            return data.map((item) => TeacherSubject.fromJson(Map<String, dynamic>.from(item as Map))).toList();
          }
        } catch (_) {}
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get classes available for exam creation / assignment
  Future<List<TeacherMyClass>> getMyClasses() async {
    try {
      final endpoints = [
        '$baseUrl/exams/meta/classes',
        '$baseUrl/teacher/classes',
        '$baseUrl/teacher/my-classes',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final List<dynamic> data = _toList(
              json.decode(res.body),
              candidateKeys: ['classes', 'items', 'results'],
            );
            return data.map((item) => TeacherMyClass.fromJson(Map<String, dynamic>.from(item as Map))).toList();
          }
        } catch (_) {}
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get students for a specific class
  Future<List<StudentDirectoryEntry>> getStudentsForClass(String classId) async {
    try {
      final endpoints = [
        Uri.parse('$baseUrl/exams/meta/students?class_name=$classId'),
        Uri.parse('$baseUrl/teacher/students?class_name=$classId'),
      ];

      for (final uri in endpoints) {
        try {
          final res = await _client.get(uri, headers: await _getHeaders());
          if (res.statusCode == 200) {
            final List<dynamic> data = _toList(
              json.decode(res.body),
              candidateKeys: ['students', 'items', 'results'],
            );
            return data.map((item) => StudentDirectoryEntry.fromJson(Map<String, dynamic>.from(item as Map))).toList();
          }
        } catch (_) {}
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Search users (students, staff, teachers, new joiners) for targeted examination scheduling
  Future<List<Map<String, dynamic>>> searchExamTargetUsers(String query, {String role = 'all', int limit = 30}) async {
    try {
      final qs = 'search=${Uri.encodeComponent(query)}&role=${Uri.encodeComponent(role)}&limit=$limit';
      final endpoints = [
        '$baseUrl/exams/meta/users?$qs',
        '$baseUrl/v1/exams/meta/users?$qs',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            final list = (data['users'] ?? data['data']) as List? ?? [];
            return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          }
        } catch (_) {}
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Fetch user profile details by IDs for target user chip rendering
  Future<List<Map<String, dynamic>>> getExamTargetUsersBatch(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    try {
      final endpoints = [
        '$baseUrl/exams/meta/users/batch',
        '$baseUrl/v1/exams/meta/users/batch',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode({'user_ids': userIds}),
          );
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            final list = (data['users'] ?? data['data']) as List? ?? [];
            return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          }
        } catch (_) {}
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ============================================================================
  // 7. SECTIONS & ADVANCED PAPER BUILDER
  // ============================================================================

  /// Get distinct chapters in Question Bank
  Future<List<String>> getQuestionBankChapters({String? subject, String? className}) async {
    try {
      final params = <String, String>{};
      if (subject != null) params['subject'] = subject;
      if (className != null) params['class_name'] = className;
      final queryString = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final querySuffix = queryString.isNotEmpty ? '?$queryString' : '';

      final endpoints = [
        '$baseUrl/exams/question-bank/chapters$querySuffix',
        '$baseUrl/question-bank/chapters$querySuffix',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            final list = (data['chapters'] ?? data['data']) as List? ?? [];
            return list.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get distinct classes in Question Bank
  Future<List<String>> getQuestionBankClasses() async {
    try {
      final endpoints = [
        '$baseUrl/exams/question-bank/classes',
        '$baseUrl/question-bank/classes',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            final list = (data['classes'] ?? data['data']) as List? ?? [];
            return list.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get paginated question bank with search and filters
  Future<Map<String, dynamic>> getQuestionBankPaged({
    String? search,
    String? subject,
    String? className,
    String? chapter,
    String? difficulty,
    String? questionType,
    String? tab,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (subject != null && subject != 'All') params['subject'] = subject;
      if (className != null && className != 'All') params['class_name'] = className;
      if (chapter != null && chapter != 'All' && chapter != 'All Chapters') params['chapter'] = chapter;
      if (difficulty != null && difficulty != 'All' && difficulty != 'All Difficulty') params['difficulty'] = difficulty;
      if (questionType != null && questionType != 'All' && questionType != 'All Types') params['question_type'] = questionType;
      if (tab != null && tab != 'all') params['tab'] = tab;

      final queryString = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final querySuffix = queryString.isNotEmpty ? '?$queryString' : '';

      final endpoints = [
        '$baseUrl/exams/question-bank$querySuffix',
        '$baseUrl/question-bank$querySuffix',
      ];

      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            final innerData = (data['data'] is Map ? _toMap(data['data']) : data);
            final questionsRaw = (innerData['questions'] ?? data['questions']) as List? ?? [];
            final questions = questionsRaw.map((e) => QuestionBankItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();

            final total = int.tryParse(innerData['total']?.toString() ?? '') ??
                int.tryParse(innerData['total_count']?.toString() ?? '') ??
                int.tryParse(data['total']?.toString() ?? '') ??
                int.tryParse(data['total_count']?.toString() ?? '') ??
                questions.length;

            final totalPages = int.tryParse(innerData['total_pages']?.toString() ?? '') ??
                int.tryParse(innerData['totalPages']?.toString() ?? '') ??
                int.tryParse(data['total_pages']?.toString() ?? '') ??
                int.tryParse(data['totalPages']?.toString() ?? '') ??
                ((total + pageSize - 1) ~/ (pageSize > 0 ? pageSize : 1));

            return {
              'questions': questions,
              'total': total,
              'total_count': total,
              'totalPages': totalPages,
              'total_pages': totalPages,
              'page': int.tryParse(innerData['page']?.toString() ?? '') ?? int.tryParse(data['page']?.toString() ?? '') ?? page,
              'page_size': int.tryParse(innerData['page_size']?.toString() ?? '') ?? int.tryParse(data['page_size']?.toString() ?? '') ?? pageSize,
              'kpis': innerData['kpis'] ?? data['kpis'] ?? {},
            };
          }
        } catch (_) {}
      }
      return {'questions': <QuestionBankItem>[], 'total_count': 0, 'page': 1, 'page_size': pageSize, 'kpis': {}};
    } catch (e) {
      return {'questions': <QuestionBankItem>[], 'total_count': 0, 'page': 1, 'page_size': pageSize, 'kpis': {}};
    }
  }

  /// Get sections and assigned questions for an exam paper
  Future<Map<String, dynamic>> getExamSections(String examId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/sections',
        '$baseUrl/v1/exams/$examId/sections',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            return (data['data'] is Map ? _toMap(data['data']) : data);
          }
        } catch (_) {}
      }
      return {'sections': [], 'unassigned_questions': []};
    } catch (_) {
      return {'sections': [], 'unassigned_questions': []};
    }
  }

  /// Create a new section in an exam paper
  Future<Map<String, dynamic>> createExamSection(String examId, Map<String, dynamic> data) async {
    try {
      final ep = '$baseUrl/exams/$examId/sections';
      final res = await _client.post(Uri.parse(ep), headers: await _getHeaders(), body: json.encode(data));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return _toMap(json.decode(res.body));
      }
      throw Exception('Failed to create section');
    } catch (e) {
      throw Exception('Error creating section: $e');
    }
  }

  /// Update a section in an exam paper
  Future<Map<String, dynamic>> updateExamSection(String examId, String sectionId, Map<String, dynamic> data) async {
    try {
      final ep = '$baseUrl/exams/$examId/sections/$sectionId';
      final res = await _client.put(Uri.parse(ep), headers: await _getHeaders(), body: json.encode(data));
      if (res.statusCode == 200) {
        return _toMap(json.decode(res.body));
      }
      throw Exception('Failed to update section');
    } catch (e) {
      throw Exception('Error updating section: $e');
    }
  }

  /// Delete a section from an exam paper
  Future<void> deleteExamSection(String examId, String sectionId) async {
    try {
      final ep = '$baseUrl/exams/$examId/sections/$sectionId';
      await _client.delete(Uri.parse(ep), headers: await _getHeaders());
    } catch (e) {
      throw Exception('Error deleting section: $e');
    }
  }

  /// Reorder sections in an exam paper
  Future<void> reorderExamSections(String examId, List<String> sectionIds) async {
    try {
      final ep = '$baseUrl/exams/$examId/sections/reorder';
      await _client.post(Uri.parse(ep), headers: await _getHeaders(), body: json.encode({'section_ids': sectionIds}));
    } catch (_) {}
  }

  /// Bulk add questions from question bank into paper
  Future<void> bulkAddQuestionsFromBank(
    String examId,
    List<String> questionBankIds, {
    String? sectionId,
    int? marks,
  }) async {
    try {
      final ep = '$baseUrl/exams/$examId/questions/bulk-add';
      final payload = {
        'question_bank_ids': questionBankIds,
        if (sectionId != null) 'section_id': sectionId,
        if (marks != null) 'marks': marks,
      };
      final res = await _client.post(Uri.parse(ep), headers: await _getHeaders(), body: json.encode(payload));
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw Exception('Failed to add questions: ${res.statusCode}');
      }
    } catch (e) {
      throw Exception('Error adding questions: $e');
    }
  }

  /// Reorder questions within and across sections
  Future<void> reorderExamQuestions(String examId, List<Map<String, dynamic>> items) async {
    try {
      final ep = '$baseUrl/exams/$examId/questions/reorder';
      await _client.post(Uri.parse(ep), headers: await _getHeaders(), body: json.encode({'items': items}));
    } catch (_) {}
  }

  /// Randomize questions and options in paper
  Future<void> randomizeExamQuestions(String examId, {bool shuffleOptions = false}) async {
    try {
      final ep = '$baseUrl/exams/$examId/randomize';
      final res = await _client.post(
        Uri.parse(ep),
        headers: await _getHeaders(),
        body: json.encode({'shuffle_options': shuffleOptions}),
      );
      if (res.statusCode != 200) throw Exception('Failed to randomize');
    } catch (e) {
      throw Exception('Error randomizing questions: $e');
    }
  }

  /// Clear all questions from exam paper
  Future<void> clearAllExamQuestions(String examId) async {
    try {
      final ep = '$baseUrl/exams/$examId/clear-all';
      await _client.post(Uri.parse(ep), headers: await _getHeaders(), body: json.encode({}));
    } catch (e) {
      throw Exception('Error clearing questions: $e');
    }
  }

  /// Get formatted printable preview of exam paper
  Future<Map<String, dynamic>> getPaperPreview(String examId) async {
    try {
      final endpoints = [
        '$baseUrl/exams/$examId/preview',
        '$baseUrl/v1/exams/$examId/preview',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            return (data['data'] is Map ? _toMap(data['data']) : data);
          }
        } catch (_) {}
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Save paper configuration metadata & version snapshot
  Future<Map<String, dynamic>> savePaperConfiguration(String examId, Map<String, dynamic> config) async {
    try {
      final ep = '$baseUrl/exams/$examId/save-paper';
      final res = await _client.post(Uri.parse(ep), headers: await _getHeaders(), body: json.encode(config));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return _toMap(json.decode(res.body));
      }
      throw Exception('Failed to save paper configuration');
    } catch (e) {
      throw Exception('Error saving paper configuration: $e');
    }
  }

  // ============================================================================
  // TAKE EXAM (GENERIC CANDIDATE WORKSPACE: STUDENT, TEACHER, ONBOARDING, ADMIN)
  // ============================================================================

  /// Fetch full examination, sanitized questions, sections, candidate profile, and active session
  Future<Map<String, dynamic>> getExamTakeInfo(String examId) async {
    try {
      final endpoints = [
        '$baseUrl/v1/exams/$examId/take-info',
        '$baseUrl/exams/$examId/take-info',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            return (data['data'] is Map ? _toMap(data['data']) : data);
          }
        } catch (_) {}
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Start or resume an exam session with server-authoritative countdown
  Future<Map<String, dynamic>> startExamSession(String examId, {String? passcode}) async {
    try {
      final endpoints = [
        '$baseUrl/v1/exams/$examId/session/start',
        '$baseUrl/exams/$examId/session/start',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode({'passcode': passcode}),
          );
          if (res.statusCode == 200) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      return {'success': false, 'message': 'Could not connect to examination server'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Debounced autosave of draft answers to backend
  Future<Map<String, dynamic>> saveExamAnswer(
    String examId, {
    required Map<String, dynamic> answers,
    String? currentQuestionId,
  }) async {
    try {
      final endpoints = [
        '$baseUrl/v1/exams/$examId/session/save-answer',
        '$baseUrl/exams/$examId/session/save-answer',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode({
              'answers': answers,
              if (currentQuestionId != null) 'current_question_id': currentQuestionId,
            }),
          );
          if (res.statusCode == 200) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      return {'success': false};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Periodic proctor heartbeat ping reporting online status and anti-cheat events
  Future<Map<String, dynamic>> pingExamSession(
    String examId, {
    String? event,
    String? severity,
  }) async {
    try {
      final endpoints = [
        '$baseUrl/v1/exams/$examId/session/ping',
        '$baseUrl/exams/$examId/session/ping',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode({
              if (event != null) 'event': event,
              if (severity != null) 'severity': severity,
            }),
          );
          if (res.statusCode == 200) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      return {'success': false};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Final submission of candidate's exam answers
  Future<Map<String, dynamic>> submitExam(
    String examId, {
    required Map<String, dynamic> answers,
    bool isAutoSubmit = false,
  }) async {
    try {
      final endpoints = [
        '$baseUrl/v1/exams/$examId/session/submit',
        '$baseUrl/exams/$examId/session/submit',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode({
              'answers': answers,
              'is_auto_submit': isAutoSubmit,
            }),
          );
          if (res.statusCode == 200) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      return {'success': false, 'message': 'Failed to submit exam paper'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ============================================================================
  // PRE-START INSTRUCTIONS & SYSTEM READINESS CHECK
  // ============================================================================

  /// Fetch full examination pre-start details, readiness policy, instructions, and warnings
  Future<Map<String, dynamic>> getExamPrestartInfo(String examId) async {
    String? lastError;
    try {
      final endpoints = [
        '$baseUrl/v1/exams/$examId/prestart',
        '$baseUrl/exams/$examId/prestart',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            final data = _toMap(decoded);
            return (data['data'] is Map ? _toMap(data['data']) : data);
          }
          lastError = 'HTTP ${res.statusCode}: ${res.body}';
        } catch (e) {
          lastError = e.toString();
        }
      }
      return {'_error': lastError ?? 'Failed to fetch exam pre-start details'};
    } catch (e) {
      return {'_error': e.toString()};
    }
  }

  /// Persist device readiness check results (camera, mic, screen share, browser/internet)
  Future<Map<String, dynamic>> recordPrestartChecks(
    String examId,
    Map<String, dynamic> checkData,
  ) async {
    try {
      final endpoints = [
        '$baseUrl/v1/exams/$examId/prestart/checks',
        '$baseUrl/exams/$examId/prestart/checks',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode(checkData),
          );
          if (res.statusCode == 200) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      return {'success': false};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update pre-start proctoring policies & custom warnings (Exam Setter / Admin only)
  Future<Map<String, dynamic>> updatePrestartConfig(
    String examId,
    Map<String, dynamic> configData,
  ) async {
    final endpoints = [
      '$baseUrl/v1/exams/$examId/prestart/config',
      '$baseUrl/exams/$examId/prestart/config',
    ];
    String? lastError;
    for (final ep in endpoints) {
      try {
        final res = await _client.put(
          Uri.parse(ep),
          headers: await _getHeaders(),
          body: json.encode(configData),
        );
        if (res.statusCode == 200) {
          final decoded = _toMap(json.decode(res.body));
          return decoded['data'] is Map ? _toMap(decoded['data']) : decoded;
        }
        lastError = 'HTTP ${res.statusCode}: ${res.body}';
      } catch (e) {
        lastError = e.toString();
      }
    }
    throw Exception(lastError ?? 'Failed to update prestart configuration');
  }

  /// Save per-exam categorized instructions (Exam Setter / Admin only)
  Future<Map<String, dynamic>> savePrestartInstructions(
    String examId,
    Map<String, dynamic> instructionsByCategory,
  ) async {
    final endpoints = [
      '$baseUrl/v1/exams/$examId/prestart/instructions',
      '$baseUrl/exams/$examId/prestart/instructions',
    ];
    String? lastError;
    for (final ep in endpoints) {
      try {
        final res = await _client.put(
          Uri.parse(ep),
          headers: await _getHeaders(),
          body: json.encode({'instructions': instructionsByCategory}),
        );
        if (res.statusCode == 200) {
          return _toMap(json.decode(res.body));
        }
        lastError = 'HTTP ${res.statusCode}: ${res.body}';
      } catch (e) {
        lastError = e.toString();
      }
    }
    throw Exception(lastError ?? 'Failed to save exam instructions');
  }

  /// Measure real round-trip latency to backend server in milliseconds
  Future<int> measureNetworkLatencyMs() async {
    final stopwatch = Stopwatch()..start();
    try {
      final healthUri = Uri.parse(baseUrl).replace(path: '/health');
      final res = await _client.get(healthUri).timeout(const Duration(seconds: 5));
      stopwatch.stop();
      if (res.statusCode == 200) {
        return stopwatch.elapsedMilliseconds.clamp(1, 9999);
      }
    } catch (_) {}
    stopwatch.stop();
    return stopwatch.elapsedMilliseconds > 0 ? stopwatch.elapsedMilliseconds : -1;
  }

  /// Persist student acknowledgment of examination rules and warnings
  Future<Map<String, dynamic>> recordPrestartAcknowledgment(
    String examId, {
    required bool acknowledged,
  }) async {
    try {
      final endpoints = [
        '$baseUrl/v1/exams/$examId/prestart/acknowledgment',
        '$baseUrl/exams/$examId/prestart/acknowledgment',
      ];
      for (final ep in endpoints) {
        try {
          final res = await _client.post(
            Uri.parse(ep),
            headers: await _getHeaders(),
            body: json.encode({'acknowledged': acknowledged}),
          );
          if (res.statusCode == 200) {
            return _toMap(json.decode(res.body));
          }
        } catch (_) {}
      }
      return {'success': false};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==========================================================================
  // LIVE EXAMINATION MONITORING & INVIGILATION ENGINE
  // ==========================================================================

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Build WebSocket URI (`ws://` or `wss://`) for authenticated real-time monitoring.
  Future<Uri> buildMonitoringWsUri(
    String examId, {
    required bool isInvigilator,
  }) async {
    final token = await getAuthToken();
    final httpUri = Uri.parse(AppConfig.baseUrl);
    final wsScheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    final endpoint = isInvigilator
        ? '/api/ws/exams/$examId/monitoring'
        : '/api/ws/exams/$examId/candidate';
    return Uri(
      scheme: wsScheme,
      host: httpUri.host,
      port: httpUri.hasPort ? httpUri.port : null,
      path: endpoint,
      queryParameters: {
        if (token != null && token.isNotEmpty) 'token': token,
      },
    );
  }

  String _extractApiError(http.Response res, String fallback) {
    try {
      final decoded = json.decode(res.body);
      if (decoded is Map) {
        return (decoded['detail'] ?? decoded['error'] ?? decoded['message'] ?? fallback).toString();
      }
    } catch (_) {}
    return '$fallback (HTTP ${res.statusCode})';
  }

  /// Fetch role-scoped LiveKit room token for either invigilator (subscribe+admin) or candidate (publish-only).
  Future<Map<String, dynamic>> getExamMonitoringLivekitToken(
    String examId, {
    String? mode,
  }) async {
    final query = mode != null ? '?mode=${Uri.encodeQueryComponent(mode)}' : '';
    final endpoints = [
      '$baseUrl/exams/$examId/monitoring/livekit-token$query',
      '$baseUrl/v1/exams/$examId/monitoring/livekit-token$query',
    ];
    String? lastErr;
    for (final ep in endpoints) {
      try {
        final res = await _client.post(
          Uri.parse(ep),
          headers: await _getHeaders(),
        );
        if (res.statusCode == 200) {
          return _toMap(json.decode(res.body));
        }
        lastErr = _extractApiError(res, 'Failed to obtain LiveKit proctoring token');
        if (res.statusCode == 403 || res.statusCode == 404) {
          throw Exception(lastErr);
        }
      } catch (e) {
        if (e.toString().contains('Not authorized') || e.toString().contains('Tenant isolation')) rethrow;
        lastErr = e.toString();
      }
    }
    throw Exception(lastErr ?? 'Failed to fetch LiveKit monitoring token');
  }

  /// Fetch live monitoring header context, KPIs, mutually-exclusive status breakdown, settings & announcements.
  Future<Map<String, dynamic>> getMonitoringOverview(String examId) async {
    final endpoints = [
      '$baseUrl/exams/$examId/monitoring/overview',
      '$baseUrl/v1/exams/$examId/monitoring/overview',
    ];
    String? lastErr;
    for (final ep in endpoints) {
      try {
        final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
        if (res.statusCode == 200) {
          return _toMap(json.decode(res.body));
        }
        lastErr = _extractApiError(res, 'Failed to load monitoring overview');
        if (res.statusCode == 403 || res.statusCode == 404) {
          throw Exception(lastErr);
        }
      } catch (e) {
        lastErr = e.toString();
        if (lastErr.contains('403') || lastErr.contains('authorized')) rethrow;
      }
    }
    throw Exception(lastErr ?? 'Failed to fetch monitoring overview');
  }

  /// Fetch paginated, filtered, sorted monitoring candidate roster.
  Future<Map<String, dynamic>> getMonitoringCandidates(
    String examId, {
    String? status,
    String? violationFilter,
    String? search,
    String? classFilter,
    int page = 1,
    int pageSize = 8,
    String sortBy = 'status_priority',
    String sortDir = 'asc',
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'sort_by': sortBy,
      'sort_dir': sortDir,
      if (status != null && status.isNotEmpty) 'status': status,
      if (violationFilter != null && violationFilter.isNotEmpty) 'violation_filter': violationFilter,
      if (search != null && search.isNotEmpty) 'search': search,
      if (classFilter != null && classFilter.isNotEmpty) 'class_filter': classFilter,
    };
    final qs = Uri(queryParameters: params).query;
    final endpoints = [
      '$baseUrl/exams/$examId/monitoring/candidates?$qs',
      '$baseUrl/v1/exams/$examId/monitoring/candidates?$qs',
    ];
    String? lastErr;
    for (final ep in endpoints) {
      try {
        final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
        if (res.statusCode == 200) {
          return _toMap(json.decode(res.body));
        }
        lastErr = _extractApiError(res, 'Failed to fetch candidates');
        if (res.statusCode == 403 || res.statusCode == 404) throw Exception(lastErr);
      } catch (e) {
        lastErr = e.toString();
      }
    }
    throw Exception(lastErr ?? 'Failed to fetch monitored candidates');
  }

  /// Fetch detailed live timeline, incidents, time adjustments & re-entry history for one candidate.
  Future<Map<String, dynamic>> getMonitoringCandidateDetail(
    String examId,
    String candidateId,
  ) async {
    final endpoints = [
      '$baseUrl/exams/$examId/monitoring/candidates/$candidateId',
      '$baseUrl/v1/exams/$examId/monitoring/candidates/$candidateId',
    ];
    String? lastErr;
    for (final ep in endpoints) {
      try {
        final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
        if (res.statusCode == 200) {
          return _toMap(json.decode(res.body));
        }
        lastErr = _extractApiError(res, 'Failed to load candidate detail');
      } catch (e) {
        lastErr = e.toString();
      }
    }
    throw Exception(lastErr ?? 'Failed to load candidate details');
  }

  /// Execute single or bulk invigilator proctoring action atomically.
  Future<Map<String, dynamic>> executeInvigilatorAction(
    String examId, {
    required String actionType,
    required List<String> candidateIds,
    String? reason,
    String? message,
    int? minutes,
    String timerPausePolicy = 'freeze',
    String? idempotencyKey,
    bool overridePolicy = false,
  }) async {
    final body = {
      'action_type': actionType,
      'candidate_ids': candidateIds,
      if (reason != null) 'reason': reason,
      if (message != null) 'message': message,
      if (minutes != null) 'minutes': minutes,
      'timer_pause_policy': timerPausePolicy,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      'override': overridePolicy,
    };
    final endpoints = [
      '$baseUrl/exams/$examId/monitoring/actions',
      '$baseUrl/v1/exams/$examId/monitoring/actions',
    ];
    String? lastErr;
    for (final ep in endpoints) {
      try {
        final res = await _client.post(
          Uri.parse(ep),
          headers: await _getHeaders(),
          body: json.encode(body),
        );
        if (res.statusCode == 200) {
          return _toMap(json.decode(res.body));
        }
        lastErr = _extractApiError(res, 'Action failed');
        if (res.statusCode >= 400 && res.statusCode < 500) {
          throw Exception(lastErr);
        }
      } catch (e) {
        lastErr = e.toString().replaceFirst('Exception: ', '');
        if (!lastErr.contains('SocketException')) rethrow;
      }
    }
    throw Exception(lastErr ?? 'Failed to execute invigilator action');
  }

  /// Execute exam-wide monitoring controls (pause_exam, resume_exam, extend_exam_deadline, close_reentry, open_reentry, emergency_submit_all, update_settings).
  Future<Map<String, dynamic>> executeExamMonitoringControl(
    String examId, {
    required String controlAction,
    String? reason,
    String? message,
    int? minutes,
    Map<String, dynamic>? extraPayload,
  }) async {
    final body = <String, dynamic>{
      'control_action': controlAction,
      if (reason != null) 'reason': reason,
      if (message != null) 'message': message,
      if (minutes != null) 'minutes': minutes,
      ...?extraPayload,
    };
    final endpoints = [
      '$baseUrl/exams/$examId/monitoring/controls',
      '$baseUrl/v1/exams/$examId/monitoring/controls',
    ];
    String? lastErr;
    for (final ep in endpoints) {
      try {
        final res = await _client.post(
          Uri.parse(ep),
          headers: await _getHeaders(),
          body: json.encode(body),
        );
        if (res.statusCode == 200) {
          return _toMap(json.decode(res.body));
        }
        lastErr = _extractApiError(res, 'Exam control failed');
        if (res.statusCode >= 400 && res.statusCode < 500) {
          throw Exception(lastErr);
        }
      } catch (e) {
        lastErr = e.toString().replaceFirst('Exception: ', '');
      }
    }
    throw Exception(lastErr ?? 'Failed to execute exam control');
  }

  /// Fetch filtered violation reports / incidents.
  Future<Map<String, dynamic>> getMonitoringIncidents(
    String examId, {
    String? severity,
    String? violationType,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      if (severity != null && severity.isNotEmpty) 'severity': severity,
      if (violationType != null && violationType.isNotEmpty) 'violation_type': violationType,
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final qs = Uri(queryParameters: params).query;
    final endpoints = [
      '$baseUrl/exams/$examId/monitoring/incidents?$qs',
      '$baseUrl/v1/exams/$examId/monitoring/incidents?$qs',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
        if (res.statusCode == 200) {
          return _toMap(json.decode(res.body));
        }
      } catch (_) {}
    }
    throw Exception('Failed to load monitoring incidents');
  }

  /// Resolve, acknowledge, dismiss, or escalate a monitoring incident.
  Future<Map<String, dynamic>> resolveMonitoringIncident(
    String examId,
    String incidentId, {
    required String status,
    String? resolutionNote,
    String? assignTo,
  }) async {
    final body = {
      'status': status,
      if (resolutionNote != null) 'resolution_note': resolutionNote,
      if (assignTo != null) 'assign_to': assignTo,
    };
    final endpoints = [
      '$baseUrl/exams/$examId/monitoring/incidents/$incidentId/resolve',
      '$baseUrl/v1/exams/$examId/monitoring/incidents/$incidentId/resolve',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _client.post(
          Uri.parse(ep),
          headers: await _getHeaders(),
          body: json.encode(body),
        );
        if (res.statusCode == 200) {
          return _toMap(json.decode(res.body));
        }
      } catch (_) {}
    }
    throw Exception('Failed to update incident status');
  }

  /// Broadcast an announcement to all or targeted candidates.
  Future<Map<String, dynamic>> sendMonitoringAnnouncement(
    String examId, {
    required String title,
    required String message,
    String priority = 'normal',
    String targetScope = 'all',
    List<String> targetCandidateIds = const [],
    bool requiresAcknowledgement = false,
  }) async {
    final body = {
      'title': title,
      'message': message,
      'priority': priority,
      'target_scope': targetScope,
      'target_candidate_ids': targetCandidateIds,
      'requires_acknowledgement': requiresAcknowledgement,
    };
    final endpoints = [
      '$baseUrl/exams/$examId/monitoring/announcements',
      '$baseUrl/v1/exams/$examId/monitoring/announcements',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _client.post(
          Uri.parse(ep),
          headers: await _getHeaders(),
          body: json.encode(body),
        );
        if (res.statusCode == 200) {
          return _toMap(json.decode(res.body));
        }
        throw Exception(_extractApiError(res, 'Failed to send announcement'));
      } catch (e) {
        if (!e.toString().contains('SocketException')) rethrow;
      }
    }
    throw Exception('Failed to send announcement');
  }

  /// Candidate acknowledges an examination announcement.
  Future<Map<String, dynamic>> acknowledgeMonitoringAnnouncement(
    String examId,
    String announcementId,
  ) async {
    final endpoints = [
      '$baseUrl/exams/$examId/monitoring/announcements/$announcementId/ack',
      '$baseUrl/v1/exams/$examId/monitoring/announcements/$announcementId/ack',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _client.post(Uri.parse(ep), headers: await _getHeaders());
        if (res.statusCode == 200) return _toMap(json.decode(res.body));
      } catch (_) {}
    }
    return {'success': false};
  }

  /// Candidate requests re-entry approval after interruption/disconnect.
  Future<Map<String, dynamic>> requestExamReentry(
    String examId, {
    required String reason,
  }) async {
    final endpoints = [
      '$baseUrl/exams/$examId/monitoring/reentry-request',
      '$baseUrl/v1/exams/$examId/monitoring/reentry-request',
    ];
    String? lastErr;
    for (final ep in endpoints) {
      try {
        final res = await _client.post(
          Uri.parse(ep),
          headers: await _getHeaders(),
          body: json.encode({'reason': reason}),
        );
        if (res.statusCode == 200) return _toMap(json.decode(res.body));
        lastErr = _extractApiError(res, 'Failed to request re-entry');
      } catch (e) {
        lastErr = e.toString();
      }
    }
    throw Exception(lastErr ?? 'Failed to submit re-entry request');
  }

  /// Fetch chronological invigilator intervention audit logs.
  Future<Map<String, dynamic>> getMonitoringAuditLogs(
    String examId, {
    String? actionType,
    int page = 1,
    int pageSize = 30,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      if (actionType != null && actionType.isNotEmpty) 'action_type': actionType,
    };
    final qs = Uri(queryParameters: params).query;
    final endpoints = [
      '$baseUrl/exams/$examId/monitoring/audit-logs?$qs',
      '$baseUrl/v1/exams/$examId/monitoring/audit-logs?$qs',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
        if (res.statusCode == 200) return _toMap(json.decode(res.body));
      } catch (_) {}
    }
    throw Exception('Failed to load monitoring audit logs');
  }

  /// Download CSV/JSON monitoring & incident report bytes.
  Future<Uint8List> exportMonitoringReportCsv(String examId) async {
    final endpoints = [
      '$baseUrl/exams/$examId/monitoring/report?format=csv',
      '$baseUrl/v1/exams/$examId/monitoring/report?format=csv',
    ];
    for (final ep in endpoints) {
      try {
        final res = await _client.get(Uri.parse(ep), headers: await _getHeaders());
        if (res.statusCode == 200) return res.bodyBytes;
      } catch (_) {}
    }
    throw Exception('Failed to export monitoring report CSV');
  }
}
