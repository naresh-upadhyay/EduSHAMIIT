import 'package:edu_shamiit_ai/core/services/api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';

/// API service for teacher-specific endpoints
class TeacherApiService {
  static final TeacherApiService _instance = TeacherApiService._internal();
  factory TeacherApiService() => _instance;
  TeacherApiService._internal();

  final ApiService _apiService = ApiService();

  // ============================================
  // HOMEWORK ENDPOINTS
  // ============================================

  /// Get homework assignments for a class
  Future<List<Homework>> getHomework({
    String? classId,
    String? subject,
  }) async {
    try {
      final response = await _apiService.get('/api/teacher/homework', query: {
        if (classId != null) 'class_id': classId,
        if (subject != null) 'subject': subject,
      });

      if (response['success'] == true && response['data'] is List) {
        return (response['data'] as List)
            .map((json) => Homework.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching homework: $e');
      return [];
    }
  }

  /// Get submissions for a specific homework
  Future<List<HomeworkSubmission>> getHomeworkSubmissions(String homeworkId) async {
    try {
      final response = await _apiService.get('/api/teacher/homework/$homeworkId/submissions');

      if (response['success'] == true && response['data'] is List) {
        return (response['data'] as List)
            .map((json) => HomeworkSubmission.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching submissions: $e');
      return [];
    }
  }

  /// Grade a homework submission
  Future<bool> gradeSubmission({
    required String submissionId,
    required double marks,
    required String grade,
    String? remarks,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/teacher/submissions/$submissionId/grade',
        {
          'marks': marks,
          'grade': grade,
          if (remarks != null) 'remarks': remarks,
        },
      );
      return response['success'] == true;
    } catch (e) {
      print('Error grading submission: $e');
      return false;
    }
  }

  // ============================================
  // EXAM ENDPOINTS
  // ============================================

  /// Get exams by status
  Future<List<Exam>> getExams({String? status}) async {
    try {
      final response = await _apiService.get('/api/teacher/exams', query: {
        if (status != null) 'status': status,
      });

      if (response['success'] == true && response['data'] is List) {
        return (response['data'] as List).map((json) => Exam.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching exams: $e');
      return [];
    }
  }

  /// Get exam analytics
  Future<ExamAnalytics?> getExamAnalytics(String examId) async {
    try {
      final response = await _apiService.get('/api/teacher/exams/$examId/analytics');

      if (response['success'] == true && response['data'] != null) {
        return ExamAnalytics.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      print('Error fetching exam analytics: $e');
      return null;
    }
  }

  // ============================================
  // LEAVE ENDPOINTS
  // ============================================

  /// Get teacher's leave applications
  Future<List<LeaveApplication>> getLeaveApplications() async {
    try {
      final response = await _apiService.get('/api/teacher/leave');

      if (response['success'] == true && response['data'] is List) {
        return (response['data'] as List)
            .map((json) => LeaveApplication.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching leave applications: $e');
      return [];
    }
  }

  /// Get leave balance
  Future<LeaveBalance?> getLeaveBalance() async {
    try {
      final response = await _apiService.get('/api/teacher/leave/balance');

      if (response['success'] == true && response['data'] != null) {
        return LeaveBalance.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      print('Error fetching leave balance: $e');
      return null;
    }
  }

  /// Apply for leave
  Future<bool> applyLeave({
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    try {
      final response = await _apiService.post('/api/teacher/leave/apply', {
        'leave_type': leaveType,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'reason': reason,
      });
      return response['success'] == true;
    } catch (e) {
      print('Error applying for leave: $e');
      return false;
    }
  }

  // ============================================
  // SALARY ENDPOINTS
  // ============================================

  /// Get teacher's salary information
  Future<Salary?> getSalary({String? month}) async {
    try {
      final response = await _apiService.get('/api/teacher/salary', query: {
        if (month != null) 'month': month,
      });

      if (response['success'] == true && response['data'] != null) {
        return Salary.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      print('Error fetching salary: $e');
      return null;
    }
  }

  // ============================================
  // STUDENT DIRECTORY ENDPOINTS
  // ============================================

  /// Get students by class
  Future<List<Student>> getStudentsByClass(String className) async {
    try {
      final response = await _apiService.get('/api/teacher/students', query: {
        'class': className,
      });

      if (response['success'] == true && response['data'] is List) {
        return (response['data'] as List).map((json) => Student.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching students: $e');
      return [];
    }
  }

  /// Get class performance analytics
  Future<ClassPerformance?> getClassPerformance(String className) async {
    try {
      final response = await _apiService.get('/api/teacher/classes/$className/performance');

      if (response['success'] == true && response['data'] != null) {
        return ClassPerformance.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      print('Error fetching class performance: $e');
      return null;
    }
  }

  // ============================================
  // LIVE CLASSES ENDPOINTS
  // ============================================

  /// Get live classes
  Future<List<LiveClass>> getLiveClasses({String? status}) async {
    try {
      final response = await _apiService.get('/api/teacher/live-classes', query: {
        if (status != null) 'status': status,
      });

      if (response['success'] == true && response['data'] is List) {
        return (response['data'] as List).map((json) => LiveClass.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching live classes: $e');
      return [];
    }
  }

  /// Start a live class
  Future<String?> startLiveClass(String classId) async {
    try {
      final response = await _apiService.post('/api/teacher/live-classes/$classId/start', {});
      if (response['success'] == true) {
        return response['meeting_link'] as String?;
      }
      return null;
    } catch (e) {
      print('Error starting live class: $e');
      return null;
    }
  }

  // ============================================
  // STUDY MATERIALS ENDPOINTS
  // ============================================

  /// Get study materials
  Future<List<StudyMaterial>> getStudyMaterials({
    String? classId,
    String? materialType,
  }) async {
    try {
      final response = await _apiService.get('/api/teacher/materials', query: {
        if (classId != null) 'class_id': classId,
        if (materialType != null) 'type': materialType,
      });

      if (response['success'] == true && response['data'] is List) {
        return (response['data'] as List)
            .map((json) => StudyMaterial.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching study materials: $e');
      return [];
    }
  }

  /// Upload study material
  Future<bool> uploadStudyMaterial({
    required String title,
    required String description,
    required String materialType,
    required String targetClass,
    required String subject,
  }) async {
    try {
      final response = await _apiService.post('/api/teacher/materials', {
        'title': title,
        'description': description,
        'material_type': materialType,
        'target_class': targetClass,
        'subject': subject,
      });
      return response['success'] == true;
    } catch (e) {
      print('Error uploading material: $e');
      return false;
    }
  }

  // ============================================
  // NOTIFICATIONS ENDPOINTS
  // ============================================

  /// Get notifications
  Future<List<Notification>> getNotifications({String? type}) async {
    try {
      final response = await _apiService.get('/api/notifications', query: {
        if (type != null) 'type': type,
      });

      if (response['success'] == true && response['data'] is List) {
        return (response['data'] as List)
            .map((json) => Notification.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final response = await _apiService.put(
        '/api/notifications/$notificationId/read',
        {},
      );
      return response['success'] == true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  // ============================================
  // GRADING ENDPOINTS
  // ============================================

  /// Get papers to grade
  Future<List<HomeworkSubmission>> getPapersToGrade({
    String? classId,
    String? subject,
  }) async {
    try {
      final response = await _apiService.get('/api/teacher/grading/papers', query: {
        if (classId != null) 'class_id': classId,
        if (subject != null) 'subject': subject,
      });

      if (response['success'] == true && response['data'] is List) {
        return (response['data'] as List)
            .map((json) => HomeworkSubmission.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching papers to grade: $e');
      return [];
    }
  }

  /// Get grading statistics
  Future<Map<String, dynamic>?> getGradingStats() async {
    try {
      final response = await _apiService.get('/api/teacher/grading/stats');
      if (response['success'] == true) {
        return response['data'];
      }
      return null;
    } catch (e) {
      print('Error fetching grading stats: $e');
      return null;
    }
  }

  // ============================================
  // PAPER BUILDER ENDPOINTS
  // ============================================

  /// Get question bank
  Future<List<Map<String, dynamic>>> getQuestionBank({
    String? subject,
    String? topic,
    String? questionType,
  }) async {
    try {
      final response = await _apiService.get('/api/teacher/question-bank', query: {
        if (subject != null) 'subject': subject,
        if (topic != null) 'topic': topic,
        if (questionType != null) 'type': questionType,
      });

      if (response['success'] == true && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('Error fetching question bank: $e');
      return [];
    }
  }

  /// Create exam paper
  Future<bool> createExamPaper({
    required String title,
    required String subject,
    required String targetClass,
    required DateTime startDate,
    required DateTime endDate,
    required int durationMinutes,
    required List<String> questionIds,
  }) async {
    try {
      final response = await _apiService.post('/api/teacher/exams', {
        'title': title,
        'subject': subject,
        'target_class': targetClass,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'duration_minutes': durationMinutes,
        'question_ids': questionIds,
      });
      return response['success'] == true;
    } catch (e) {
      print('Error creating exam paper: $e');
      return false;
    }
  }
}