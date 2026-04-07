import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_ai/core/config/app_config.dart';
import 'package:edu_shamiit_ai/core/models/student_models.dart';
import 'package:edu_shamiit_ai/core/services/mock_data_service.dart';

/// Student API service for communicating with FastAPI backend
class StudentApiService {
  static final StudentApiService _instance = StudentApiService._internal();
  factory StudentApiService() => _instance;
  StudentApiService._internal();

  final http.Client _client = http.Client();

  /// Get headers with authorization
  Future<Map<String, String>> get _headers async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ============================================
  // STUDENT PROFILE
  // ============================================

  /// Get student profile
  Future<StudentProfile> getProfile() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/profile'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return StudentProfile.fromJson(data);
      } else {
        // Fallback to mock data when API fails
        return StudentProfile.fromJson(MockDataService().getStudentProfile());
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return StudentProfile.fromJson(MockDataService().getStudentProfile());
    }
  }

  /// Update student profile
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _client
          .put(
            Uri.parse('${AppConfig.apiBaseUrl}/student/profile'),
            headers: await _headers,
            body: jsonEncode(data),
          )
          .timeout(AppConfig.apiTimeout);

      return response.statusCode == 200;
    } catch (e) {
      throw ApiException('Update profile failed: $e');
    }
  }

  // ============================================
  // ATTENDANCE
  // ============================================

  /// Get attendance summary
  Future<AttendanceSummary> getAttendanceSummary({
    String? month,
    String? year,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/attendance/summary')
                .replace(
              queryParameters: {
                if (month != null) 'month': month,
                if (year != null) 'year': year,
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return AttendanceSummary.fromJson(data);
      } else {
        // Fallback to mock data when API fails
        return AttendanceSummary.fromJson(MockDataService().getAttendanceSummary());
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return AttendanceSummary.fromJson(MockDataService().getAttendanceSummary());
    }
  }

  /// Get attendance records
  Future<List<AttendanceRecord>> getAttendanceRecords({
    required String month,
    required String year,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/attendance/records')
                .replace(
              queryParameters: {
                'month': month,
                'year': year,
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getAttendanceRecords() as List)
            .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getAttendanceRecords() as List)
          .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  // ============================================
  // HOMEWORK
  // ============================================

  /// Get homework assignments
  Future<List<HomeworkAssignment>> getHomeworkAssignments({
    String? status, // 'pending', 'submitted', 'graded', 'late'
    String? subject,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/homework').replace(
              queryParameters: {
                if (status != null) 'status': status,
                if (subject != null) 'subject': subject,
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => HomeworkAssignment.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getHomeworkAssignments() as List)
            .map((e) => HomeworkAssignment.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getHomeworkAssignments() as List)
          .map((e) => HomeworkAssignment.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Submit homework
  Future<bool> submitHomework({
    required String homeworkId,
    String? submissionText,
    String? fileUrl,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse(
                '${AppConfig.apiBaseUrl}/student/homework/$homeworkId/submit'),
            headers: await _headers,
            body: jsonEncode({
              'submission_text': submissionText,
              'file_url': fileUrl,
            }),
          )
          .timeout(AppConfig.apiTimeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw ApiException('Submit homework failed: $e');
    }
  }

  // ============================================
  // EXAMS & RESULTS
  // ============================================

  /// Get upcoming exams
  Future<List<ExamSchedule>> getUpcomingExams() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/exams/upcoming'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => ExamSchedule.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getUpcomingExams() as List)
            .map((e) => ExamSchedule.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getUpcomingExams() as List)
          .map((e) => ExamSchedule.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Get exam schedule
  Future<List<ExamSchedule>> getExamSchedule() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/exams/schedule'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => ExamSchedule.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
            'Failed to load exam schedule: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Get exam schedule failed: $e');
    }
  }

  /// Get exam results
  Future<List<ExamResult>> getExamResults({
    String? subject,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/results').replace(
              queryParameters: {
                if (subject != null) 'subject': subject,
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => ExamResult.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getExamResults() as List)
            .map((e) => ExamResult.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getExamResults() as List)
          .map((e) => ExamResult.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Get online exam details
  Future<Map<String, dynamic>> getOnlineExamDetails(String examId) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/exams/$examId/online'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
            'Failed to load exam details: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Get online exam details failed: $e');
    }
  }

  /// Submit online exam
  Future<bool> submitOnlineExam({
    required String examId,
    required Map<int, int> answers, // questionNumber -> selectedOption
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/student/exams/$examId/submit'),
            headers: await _headers,
            body: jsonEncode({
              'answers': answers.map((k, v) => MapEntry(k.toString(), v)),
            }),
          )
          .timeout(const Duration(minutes: 5)); // Longer timeout for exam submission

      return response.statusCode == 200;
    } catch (e) {
      throw ApiException('Submit online exam failed: $e');
    }
  }

  // ============================================
  // FEES
  // ============================================

  /// Get fee records
  Future<List<FeeRecord>> getFeeRecords({
    String? status, // 'pending', 'paid', 'partial', 'overdue'
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/fees').replace(
              queryParameters: {
                if (status != null) 'status': status,
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => FeeRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getFeeRecords() as List)
            .map((e) => FeeRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getFeeRecords() as List)
          .map((e) => FeeRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Get fee summary
  Future<Map<String, dynamic>> getFeeSummary() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/fees/summary'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
            'Failed to load fee summary: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Get fee summary failed: $e');
    }
  }

  // ============================================
  // TIMETABLE
  // ============================================

  /// Get timetable for a specific day
  Future<List<TimetablePeriod>> getTimetable({
    required String day, // 'monday', 'tuesday', etc. or 'today'
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/timetable').replace(
              queryParameters: {'day': day},
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => TimetablePeriod.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getTimetable() as List)
            .map((e) => TimetablePeriod.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getTimetable() as List)
          .map((e) => TimetablePeriod.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Get full week timetable
  Future<Map<String, List<TimetablePeriod>>> getWeekTimetable() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/timetable/week'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        Map<String, List<TimetablePeriod>> result = {};
        data.forEach((key, value) {
          result[key] = (value as List)
              .map((e) => TimetablePeriod.fromJson(e as Map<String, dynamic>))
              .toList();
        });
        return result;
      } else {
        throw ApiException(
            'Failed to load week timetable: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Get week timetable failed: $e');
    }
  }

  // ============================================
  // LIVE CLASSES
  // ============================================

  /// Get live classes
  Future<List<StudentLiveClass>> getLiveClasses({
    String? status, // 'live', 'scheduled', 'completed', 'recorded'
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/live-classes').replace(
              queryParameters: {
                if (status != null) 'status': status,
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => StudentLiveClass.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getLiveClasses() as List)
            .map((e) => StudentLiveClass.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getLiveClasses() as List)
          .map((e) => StudentLiveClass.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Join live class
  Future<String?> joinLiveClass(String classId) async {
    try {
      final response = await _client
          .post(
            Uri.parse(
                '${AppConfig.apiBaseUrl}/student/live-classes/$classId/join'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['meeting_link'] as String?;
      } else {
        throw ApiException('Failed to join class: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Join live class failed: $e');
    }
  }

  // ============================================
  // NOTICES
  // ============================================

  /// Get notices
  Future<List<Notice>> getNotices({
    String? category, // 'urgent', 'general', 'exam', 'event'
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/notices').replace(
              queryParameters: {
                if (category != null) 'category': category,
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => Notice.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getNotices() as List)
            .map((e) => Notice.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getNotices() as List)
          .map((e) => Notice.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  // ============================================
  // NOTIFICATIONS
  // ============================================

  /// Get notifications
  Future<List<StudentNotification>> getNotifications({
    String? type, // 'academic', 'administrative', 'event', 'reminder'
    bool? unreadOnly,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/notifications').replace(
              queryParameters: {
                if (type != null) 'type': type,
                if (unreadOnly != null) 'unread_only': unreadOnly.toString(),
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => StudentNotification.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getNotifications() as List)
            .map((e) => StudentNotification.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getNotifications() as List)
          .map((e) => StudentNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final response = await _client
          .put(
            Uri.parse(
                '${AppConfig.apiBaseUrl}/student/notifications/$notificationId/read'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      return response.statusCode == 200;
    } catch (e) {
      throw ApiException('Mark notification as read failed: $e');
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllNotificationsAsRead() async {
    try {
      final response = await _client
          .put(
            Uri.parse('${AppConfig.apiBaseUrl}/student/notifications/read-all'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      return response.statusCode == 200;
    } catch (e) {
      throw ApiException('Mark all notifications as read failed: $e');
    }
  }

  // ============================================
  // EVENTS
  // ============================================

  /// Get events
  Future<List<Event>> getEvents({
    String? filter, // 'upcoming', 'registered', 'past'
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/events').replace(
              queryParameters: {
                if (filter != null) 'filter': filter,
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => Event.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getEvents() as List)
            .map((e) => Event.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getEvents() as List)
          .map((e) => Event.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Register for event
  Future<bool> registerForEvent(String eventId) async {
    try {
      final response = await _client
          .post(
            Uri.parse(
                '${AppConfig.apiBaseUrl}/student/events/$eventId/register'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw ApiException('Register for event failed: $e');
    }
  }

  // ============================================
  // ACHIEVEMENTS
  // ============================================

  /// Get achievements
  Future<List<Achievement>> getAchievements({
    bool? earnedOnly,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/achievements').replace(
              queryParameters: {
                if (earnedOnly != null) 'earned_only': earnedOnly.toString(),
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getAchievements() as List)
            .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getAchievements() as List)
          .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  // ============================================
  // LEADERBOARD
  // ============================================

  /// Get leaderboard
  Future<List<LeaderboardEntry>> getLeaderboard({
    String? scope, // 'class', 'school', 'global'
    int? limit,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/leaderboard').replace(
              queryParameters: {
                if (scope != null) 'scope': scope,
                if (limit != null) 'limit': limit.toString(),
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getLeaderboard() as List)
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getLeaderboard() as List)
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  // ============================================
  // LEAVE
  // ============================================

  /// Get leave applications
  Future<List<StudentLeaveApplication>> getLeaveApplications({
    String? status, // 'pending', 'approved', 'rejected'
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/leave').replace(
              queryParameters: {
                if (status != null) 'status': status,
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) =>
                StudentLeaveApplication.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getLeaveApplications() as List)
            .map((e) =>
                StudentLeaveApplication.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getLeaveApplications() as List)
          .map((e) =>
              StudentLeaveApplication.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Apply for leave
  Future<bool> applyForLeave({
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/student/leave/apply'),
            headers: await _headers,
            body: jsonEncode({
              'leave_type': leaveType,
              'start_date': startDate.toIso8601String(),
              'end_date': endDate.toIso8601String(),
              'reason': reason,
            }),
          )
          .timeout(AppConfig.apiTimeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw ApiException('Apply for leave failed: $e');
    }
  }

  // ============================================
  // LIBRARY
  // ============================================

  /// Get library books
  Future<List<LibraryBook>> getLibraryBooks({
    String? search,
    String? category,
    bool? availableOnly,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/library/books').replace(
              queryParameters: {
                if (search != null) 'search': search,
                if (category != null) 'category': category,
                if (availableOnly != null)
                  'available_only': availableOnly.toString(),
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => LibraryBook.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getLibraryBooks() as List)
            .map((e) => LibraryBook.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getLibraryBooks() as List)
          .map((e) => LibraryBook.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Get issued books
  Future<List<LibraryBook>> getIssuedBooks() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/library/issued'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => LibraryBook.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getIssuedBooks() as List)
            .map((e) => LibraryBook.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getIssuedBooks() as List)
          .map((e) => LibraryBook.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  // ============================================
  // COURSES
  // ============================================

  /// Get courses
  Future<List<Course>> getCourses({
    String? subject,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/courses').replace(
              queryParameters: {
                if (subject != null) 'subject': subject,
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => Course.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getCourses() as List)
            .map((e) => Course.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getCourses() as List)
          .map((e) => Course.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  // ============================================
  // MESSAGING
  // ============================================

  /// Get messages (conversation with teacher)
  Future<List<Message>> getMessages({
    String? teacherId,
    int? page,
    int? limit,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/messages').replace(
              queryParameters: {
                if (teacherId != null) 'teacher_id': teacherId,
                if (page != null) 'page': page.toString(),
                if (limit != null) 'limit': limit.toString(),
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map((e) => Message.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getMessages() as List)
            .map((e) => Message.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getMessages() as List)
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Send message
  Future<bool> sendMessage({
    required String recipientId,
    required String content,
    String? attachmentUrl,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/student/messages/send'),
            headers: await _headers,
            body: jsonEncode({
              'recipient_id': recipientId,
              'content': content,
              'attachment_url': attachmentUrl,
            }),
          )
          .timeout(AppConfig.apiTimeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw ApiException('Send message failed: $e');
    }
  }

  // ============================================
  // TRANSPORT
  // ============================================

  /// Get transport route
  Future<TransportRoute?> getTransportRoute() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/transport/route'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return TransportRoute.fromJson(data);
      } else if (response.statusCode == 404) {
        return null; // No transport assigned
      } else {
        // Fallback to mock data when API fails
        return TransportRoute.fromJson(MockDataService().getTransportRoute());
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return TransportRoute.fromJson(MockDataService().getTransportRoute());
    }
  }

  // ============================================
  // PERFORMANCE ANALYTICS
  // ============================================

  /// Get performance analytics
  Future<List<PerformanceAnalytics>> getPerformanceAnalytics() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/performance'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data
            .map(
                (e) => PerformanceAnalytics.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getPerformanceAnalytics() as List)
            .map(
                (e) => PerformanceAnalytics.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getPerformanceAnalytics() as List)
          .map(
              (e) => PerformanceAnalytics.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }
}

/// API Exception
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}
