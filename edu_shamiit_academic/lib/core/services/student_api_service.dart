import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'package:edu_shamiit_core/models/student_models.dart';
import 'package:edu_shamiit_academic/core/services/mock_data_service.dart';
import 'package:edu_shamiit_core/services/api_service.dart';

/// Student API service for communicating with FastAPI backend
class StudentApiService {
  static final StudentApiService _instance = StudentApiService._internal();
  factory StudentApiService() => _instance;
  StudentApiService._internal();

  final http.Client _client = InterceptorClient();

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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') ? decoded['data'] : decoded;
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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') ? decoded['data'] : decoded;
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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is List 
                ? decoded['data'] as List 
                : (decoded['data'] as Map).values.firstWhere((v) => v is List, orElse: () => []) as List)
            : [];
        return data
            .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getAttendanceRecords())
            .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getAttendanceRecords())
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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is List 
                ? decoded['data'] as List 
                : (decoded['data'] as Map).values.firstWhere((v) => v is List, orElse: () => []) as List)
            : [];
        return data
            .map((e) => HomeworkAssignment.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getHomeworkAssignments())
            .map((e) => HomeworkAssignment.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getHomeworkAssignments())
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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is List 
                ? decoded['data'] as List 
                : (decoded['data'] as Map).values.firstWhere((v) => v is List, orElse: () => []) as List)
            : [];
        return data
            .map((e) => ExamSchedule.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getUpcomingExams())
            .map((e) => ExamSchedule.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getUpcomingExams())
          .map((e) => ExamSchedule.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Get exam schedule
  Future<List<ExamSchedule>> getExamSchedule() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/exams'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is List 
                ? decoded['data'] as List 
                : (decoded['data'] as Map).values.firstWhere((v) => v is List, orElse: () => []) as List)
            : [];
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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is List 
                ? decoded['data'] as List 
                : (decoded['data'] as Map).values.firstWhere((v) => v is List, orElse: () => []) as List)
            : [];
        return data
            .map((e) => ExamResult.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getExamResults())
            .map((e) => ExamResult.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getExamResults())
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

  /// Submit online exam with dynamic answers map (questionId -> studentAnswer)
  Future<Map<String, dynamic>> submitOnlineExamDynamic({
    required String examId,
    required Map<String, dynamic> answers,
    bool isAutoSave = false,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/student/exams/$examId/submit'),
            headers: await _headers,
            body: jsonEncode({
              'answers': answers,
              'is_auto_save': isAutoSave,
            }),
          )
          .timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException('Failed to submit exam: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Submit online exam failed: $e');
    }
  }

  /// Start online exam session
  Future<void> startOnlineExamSession(String examId, {String? passcode}) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/student/exams/$examId/session/start'),
            headers: await _headers,
            body: passcode != null ? jsonEncode({'passcode': passcode}) : null,
          )
          .timeout(AppConfig.apiTimeout);
      if (response.statusCode != 200 && response.statusCode != 201) {
        String msg = 'Failed to start session';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body.containsKey('detail')) {
            msg = body['detail'].toString();
          }
        } catch (_) {}
        throw ApiException(msg);
      }
    } catch (e) {
      throw ApiException(e.toString().replaceAll('ApiException: ', ''));
    }
  }

  /// Get online exam result details
  Future<Map<String, dynamic>> getOnlineExamResultDetails(String examId) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/exams/$examId/result'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['success'] == true) {
          return body['data'] as Map<String, dynamic>;
        }
        throw ApiException(body['message']?.toString() ?? 'Failed to load result analysis');
      } else {
        String msg = 'Failed to load result details';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body.containsKey('detail')) {
            msg = body['detail'].toString();
          }
        } catch (_) {}
        throw ApiException(msg);
      }
    } catch (e) {
      throw ApiException(e.toString().replaceAll('ApiException: ', ''));
    }
  }

  /// Verify exam passcode early without starting session
  Future<Map<String, dynamic>> verifyExamPasscode(String examId, String passcode) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/student/exams/$examId/verify-passcode'),
            headers: await _headers,
            body: jsonEncode({'passcode': passcode}),
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        String msg = 'Invalid passcode';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body.containsKey('detail')) {
            msg = body['detail'].toString();
          }
        } catch (_) {}
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
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
        Uri.parse('${AppConfig.apiBaseUrl}/livekit/token').replace(queryParameters: queryParams),
        headers: await _headers,
      ).timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException('Failed to load LiveKit token: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Get LiveKit token failed: $e');
    }
  }

  /// Ping online exam session to update status and fetch proctor instructions
  Future<Map<String, dynamic>> pingOnlineExamSession(
    String examId, {
    required int warningsCount,
    String? activeQuestionId,
    bool isOnline = true,
    String? logEvent,
    bool? cameraActive,
    bool? micActive,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/student/exams/$examId/session/ping'),
            headers: await _headers,
            body: jsonEncode({
              'warnings_count': warningsCount,
              'active_question': activeQuestionId,
              'is_online': isOnline,
              'log_event': logEvent,
              if (cameraActive != null) 'camera_active': cameraActive,
              if (micActive != null) 'mic_active': micActive,
            }),
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException('Ping failed: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Ping online exam session failed: $e');
    }
  }

  /// Upload subjective answer sheets to storage
  Future<Map<String, dynamic>> uploadExamAttachment({
    required List<int> fileBytes,
    required String filename,
    required String contentType,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/student/exams/upload');
      final request = http.MultipartRequest('POST', uri);
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: filename,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(const Duration(minutes: 2));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException('Upload failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw ApiException('Upload exam attachment failed: $e');
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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        List<dynamic> list = [];
        if (decoded.containsKey('data')) {
          final data = decoded['data'];
          if (data is Map) {
            if (data.containsKey('fees')) {
              list = data['fees'] as List;
            } else {
              list = data.values.firstWhere((v) => v is List, orElse: () => []) as List;
            }
          } else if (data is List) {
            list = data;
          }
        }
        return list
            .map((e) => FeeRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getFeeRecords())
            .map((e) => FeeRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getFeeRecords())
          .map((e) => FeeRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Process direct payment for a fee
  Future<Map<String, dynamic>> payDirect({
    required String feeId,
    required double amount,
    required String paymentMethod,
    String? upiId,
    String? cardNumber,
    String? cardExpiry,
    String? cardCvv,
    String? bankName,
    String? description,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/payments/pay-direct'),
            headers: await _headers,
            body: jsonEncode({
              'fee_id': feeId,
              'amount': amount,
              'payment_method': paymentMethod,
              if (upiId != null) 'upi_id': upiId,
              if (cardNumber != null) 'card_number': cardNumber,
              if (cardExpiry != null) 'card_expiry': cardExpiry,
              if (cardCvv != null) 'card_cvv': cardCvv,
              if (bankName != null) 'bank_name': bankName,
              if (description != null) 'description': description,
            }),
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final decoded = jsonDecode(response.body);
        final detail = (decoded is Map && decoded.containsKey('detail'))
            ? decoded['detail'].toString()
            : 'Payment failed with status: ${response.statusCode}';
        throw ApiException(detail);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Payment processing failed: $e');
    }
  }

  /// Process bulk payment for multiple fees
  Future<Map<String, dynamic>> payBulk({
    required List<String> feeIds,
    required double amount,
    required String paymentMethod,
    String? upiId,
    String? cardNumber,
    String? cardExpiry,
    String? cardCvv,
    String? bankName,
    String? description,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/payments/pay-bulk'),
            headers: await _headers,
            body: jsonEncode({
              'fee_ids': feeIds,
              'amount': amount,
              'payment_method': paymentMethod,
              if (upiId != null) 'upi_id': upiId,
              if (cardNumber != null) 'card_number': cardNumber,
              if (cardExpiry != null) 'card_expiry': cardExpiry,
              if (cardCvv != null) 'card_cvv': cardCvv,
              if (bankName != null) 'bank_name': bankName,
              if (description != null) 'description': description,
            }),
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final decoded = jsonDecode(response.body);
        final detail = (decoded is Map && decoded.containsKey('detail'))
            ? decoded['detail'].toString()
            : 'Bulk payment failed with status: ${response.statusCode}';
        throw ApiException(detail);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Bulk payment processing failed: $e');
    }
  }

  /// Get dynamic outstanding balance from API
  Future<double> getOutstandingBalance() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/fees'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded.containsKey('data')) {
          final data = decoded['data'];
          if (data is Map && data.containsKey('total_outstanding')) {
            return double.tryParse(data['total_outstanding'].toString()) ?? 0.0;
          }
        }
      }
      return 0.0;
    } catch (e) {
      return 0.0;
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
    String? day, // 'monday', 'tuesday', etc. or 'today'
    String? date,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (day != null) queryParams['day'] = day;
      if (date != null) queryParams['date'] = date;

      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/timetable').replace(
              queryParameters: queryParams,
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is List 
                ? decoded['data'] as List 
                : (decoded['data'] as Map).values.firstWhere((v) => v is List, orElse: () => []) as List)
            : [];
        return data
            .map((e) => TimetablePeriod.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getTimetable())
            .map((e) => TimetablePeriod.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getTimetable())
          .map((e) => TimetablePeriod.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Get student's class name from profile
  Future<String> getStudentClass() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/profile'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') ? decoded['data'] : decoded;
        return (data['class'] ?? data['class_name'] ?? '').toString();
      }
    } catch (_) {}
    return '';
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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is List 
                ? decoded['data'] as List 
                : (decoded['data'] as Map).values.firstWhere((v) => v is List, orElse: () => []) as List)
            : [];
        return data
            .map((e) => StudentLiveClass.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getLiveClasses())
            .map((e) => StudentLiveClass.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getLiveClasses())
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
    String? search,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/notices').replace(
              queryParameters: {
                // Pass 'All' to get all notices from backend - category filter done client-side
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        // API returns: {success: true, data: {notices: [...]}}
        List<dynamic> items = const [];
        final dataField = decoded['data'];
        if (dataField is List) {
          items = dataField;
        } else if (dataField is Map<String, dynamic>) {
          if (dataField.containsKey('notices') && dataField['notices'] is List) {
            items = dataField['notices'] as List;
          } else {
            // Look for a list inside data (e.g. data.notices, data.items)
            for (final val in dataField.values) {
              if (val is List) {
                items = val;
                break;
              }
            }
          }
        }
        return items
            .map((e) => Notice.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getNotices())
            .map((e) => Notice.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getNotices())
          .map((e) => Notice.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Register for notice event
  Future<bool> registerForNotice(String noticeId) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/student/notices/$noticeId/register'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw ApiException('Register for notice event failed: $e');
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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is List 
                ? decoded['data'] as List 
                : (decoded['data'] as Map).values.firstWhere((v) => v is List, orElse: () => []) as List)
            : [];
        return data
            .map((e) => StudentNotification.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getNotifications())
            .map((e) => StudentNotification.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getNotifications())
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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is List 
                ? decoded['data'] as List 
                : (decoded['data'] as Map).values.firstWhere((v) => v is List, orElse: () => []) as List)
            : [];
        return data
            .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getAchievements())
            .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getAchievements())
          .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Get achievements dashboard containing total XP, ranks, unlocked and locked achievements (excluding heavy leaderboard/history data)
  Future<StudentAchievementsDashboard> getAchievementsDashboard() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/achievements?exclude_leaderboards=true&exclude_history=true'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') ? decoded['data'] : decoded;
        return StudentAchievementsDashboard.fromJson(data);
      } else {
        throw ApiException('Failed to load achievements dashboard: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Achievements dashboard request failed: $e');
    }
  }

  // ============================================
  // LEADERBOARD
  // ============================================

  /// Get leaderboard with scope, limit and offset pagination
  Future<List<LeaderboardEntry>> getLeaderboard({
    String? scope, // 'class', 'school'
    int? limit,
    int? offset,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/leaderboard').replace(
              queryParameters: {
                if (scope != null) 'scope': scope,
                if (limit != null) 'limit': limit.toString(),
                if (offset != null) 'offset': offset.toString(),
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      print('[getLeaderboard] Scope: $scope, Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is Map && (decoded['data'] as Map).containsKey('leaderboard')
                ? decoded['data']['leaderboard'] as List
                : (decoded['data'] is List ? decoded['data'] as List : []))
            : [];
        return data
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('API returned status code ${response.statusCode}');
      }
    } catch (e) {
      print('[getLeaderboard] Error: $e');
      rethrow;
    }
  }

  /// Get XP transaction history with pagination
  Future<List<XpTransaction>> getXpHistory({
    int? limit,
    int? offset,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/achievements/xp-history').replace(
              queryParameters: {
                if (limit != null) 'limit': limit.toString(),
                if (offset != null) 'offset': offset.toString(),
              },
            ),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      print('[getXpHistory] Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') ? decoded['data'] as List : [];
        return data
            .map((e) => XpTransaction.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('API returned status code ${response.statusCode}');
      }
    } catch (e) {
      print('[getXpHistory] Error: $e');
      rethrow;
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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is List 
                ? decoded['data'] as List 
                : (decoded['data'] as Map).values.firstWhere((v) => v is List, orElse: () => []) as List)
            : [];
        return data
            .map((e) =>
                StudentLeaveApplication.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getLeaveApplications())
            .map((e) =>
                StudentLeaveApplication.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getLeaveApplications())
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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is List 
                ? decoded['data'] as List 
                : (decoded['data'] as Map).values.firstWhere((v) => v is List, orElse: () => []) as List)
            : [];
        return data
            .map((e) => LibraryBook.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getLibraryBooks())
            .map((e) => LibraryBook.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getLibraryBooks())
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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is List 
                ? decoded['data'] as List 
                : (decoded['data'] as Map).values.firstWhere((v) => v is List, orElse: () => []) as List)
            : [];
        return data
            .map((e) => LibraryBook.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getIssuedBooks())
            .map((e) => LibraryBook.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getIssuedBooks())
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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is List 
                ? decoded['data'] as List 
                : (decoded['data'] as Map).values.firstWhere((v) => v is List, orElse: () => []) as List)
            : [];
        return data
            .map((e) => Course.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getCourses())
            .map((e) => Course.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getCourses())
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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is List 
                ? decoded['data'] as List 
                : (decoded['data'] as Map).values.firstWhere((v) => v is List, orElse: () => []) as List)
            : [];
        return data
            .map((e) => Message.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getMessages())
            .map((e) => Message.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getMessages())
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
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded.containsKey('data') 
            ? (decoded['data'] is List 
                ? decoded['data'] as List 
                : (decoded['data'] as Map).values.firstWhere((v) => v is List, orElse: () => []) as List)
            : [];
        return data
            .map(
                (e) => PerformanceAnalytics.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        // Fallback to mock data when API fails
        return (MockDataService().getPerformanceAnalytics())
            .map(
                (e) => PerformanceAnalytics.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback to mock data when API fails
      return (MockDataService().getPerformanceAnalytics())
          .map(
              (e) => PerformanceAnalytics.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Get all subjects dynamically
  Future<List<StudentSubject>> getSubjects() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/subjects'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> data = decoded.containsKey('data')
            ? (decoded['data'] is Map ? (decoded['data']['subjects'] ?? []) : decoded['data'])
            : [];
        return data.map((item) => StudentSubject.fromJson(item)).toList();
      } else {
        return _fallbackSubjects();
      }
    } catch (e) {
      return _fallbackSubjects();
    }
  }

  List<StudentSubject> _fallbackSubjects() {
    return [
      StudentSubject(id: 'sub_math', name: 'Mathematics', icon: '📐', color: '#4F46E5'),
      StudentSubject(id: 'sub_phys', name: 'Physics', icon: '⚛️', color: '#0EA5E9'),
      StudentSubject(id: 'sub_chem', name: 'Chemistry', icon: '⚗️', color: '#10B981'),
      StudentSubject(id: 'sub_bio', name: 'Biology', icon: '🧬', color: '#EF4444'),
      StudentSubject(id: 'sub_eng', name: 'English', icon: '📖', color: '#F59E0B'),
    ];
  }

  /// Get course details (chapters & topics)
  Future<Map<String, dynamic>> getCourseDetails(String courseId) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/student/courses/$courseId/details'),
            headers: await _headers,
          )
          .timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return decoded['data'] ?? decoded;
      } else {
        return {'course': {}, 'chapters': []};
      }
    } catch (e) {
      return {'course': {}, 'chapters': []};
    }
  }

  /// Toggle topic completion progress
  Future<bool> toggleTopicProgress(String topicId, bool completed) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/student/courses/topics/$topicId/progress'),
            headers: await _headers,
            body: jsonEncode({'completed': completed}),
          )
          .timeout(AppConfig.apiTimeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Download exam results PDF
  Future<List<int>> downloadResultsPdf(List<String> examIds) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/student/results/pdf'),
            headers: await _headers,
            body: jsonEncode({
              'exam_ids': examIds,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw ApiException('Failed to download PDF report: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Download PDF report failed: $e');
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
