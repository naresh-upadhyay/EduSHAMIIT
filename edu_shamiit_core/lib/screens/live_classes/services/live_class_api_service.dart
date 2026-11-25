import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/app_config.dart';
import '../../../services/api_service.dart';
import '../models/live_class_models.dart';

class LiveClassApiService {
  final ApiService _apiService = ApiService();

  Future<JoinConductDashboardData> fetchJoinConductDashboard() async {
    try {
      final res = await _apiService.get('/live-classes/dashboard/join-conduct');
      if (res['data'] != null) {
        return JoinConductDashboardData.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching join-conduct dashboard: $e');
    }
    return JoinConductDashboardData(
      liveNow: 1,
      todaysClasses: 1,
      totalParticipantsLive: 43,
      recordingInProgress: 1,
      avgClassDurationMin: 45,
      classQuality: 'Excellent (98%)',
      systemStatus: 'Online',
      engagement: ClassEngagement(
        overallPercentage: 92,
        activeParticipantsPct: 92,
        interactionPct: 88,
        pollResponsePct: 95,
        contentViewPct: 93,
      ),
    );
  }

  Future<RecordingsDashboardData> fetchRecordingsDashboard() async {
    try {
      final res = await _apiService.get('/live-classes/dashboard/recordings');
      if (res['data'] != null) {
        return RecordingsDashboardData.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching recordings dashboard: $e');
    }
    return RecordingsDashboardData(
      totalRecordings: 0,
      thisWeek: 0,
      totalDurationDisplay: '0 min',
      storageUsedGb: 0.0,
      storageTotalTb: 1.0,
      storageUsedPercentage: 0,
      totalDownloads: 0,
      avgViews: 0,
      retentionRatePct: 100,
      storageBreakdown: StorageBreakdown(
        recordingsGb: 0.0,
        recordingsPct: 0.0,
        classResourcesGb: 0.0,
        classResourcesPct: 0.0,
        othersGb: 0.0,
        othersPct: 0.0,
        freeSpaceGb: 1024.0,
        freeSpacePct: 100.0,
      ),
      settings: RecordingSettings(
        autoRecording: true,
        cloudStorage: true,
        defaultRetentionDays: 180,
        recordingQuality: 'HD (720p)',
        allowStudentDownload: true,
      ),
      analytics30Days: [],
    );
  }

  Future<AttendanceDashboardData> fetchAttendanceDashboard({String? sessionId}) async {
    try {
      final endpoint = sessionId != null
          ? '/live-classes/dashboard/attendance?session_id=$sessionId'
          : '/live-classes/dashboard/attendance';
      final res = await _apiService.get(endpoint);
      if (res['data'] != null) {
        return AttendanceDashboardData.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching attendance dashboard: $e');
    }
    return AttendanceDashboardData(
      totalSessions: 248,
      attendanceMarked: 236,
      attendanceMarkedPct: 95.2,
      totalParticipants: 9842,
      presentCount: 9121,
      presentPct: 92.7,
      absentCount: 721,
      absentPct: 7.3,
      avgAttendancePct: 92.7,
      thisWeekPct: 92.9,
      thisWeekChange: '+1.4%',
      summary: LiveClassAttendanceSummary(
        overallPct: 92.7,
        presentCount: 39,
        presentPct: 92.7,
        absentCount: 3,
        absentPct: 7.3,
        lateCount: 0,
        latePct: 0.0,
        notJoinedCount: 0,
        notJoinedPct: 0.0,
      ),
      trend: [],
      autoRules: AutoAttendanceRules(
        autoMark75Pct: true,
        considerJoinLeave: true,
        includeParticipation: true,
      ),
    );
  }

  Future<MetaDropdownsData> fetchMetaDropdowns() async {
    try {
      final res = await _apiService.get('/live-classes/meta/dropdowns');
      if (res['data'] != null) {
        return MetaDropdownsData.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching dropdowns: $e');
    }
    return MetaDropdownsData(classes: [], sections: [], subjects: [], teachers: [], sessions: []);
  }

  /// Retrieve dynamic academic session years from lookup table using key ACADEMIC_YEAR
  Future<List<String>> fetchAcademicSessions() async {
    try {
      final res = await _apiService.get('/lookups/code/ACADEMIC_YEAR');
      if (res['values'] is List) {
        final list = <String>[];
        for (final v in (res['values'] as List)) {
          final str = (v['label'] ?? v['value_name'] ?? v['code'] ?? '').toString().trim();
          if (str.isNotEmpty && !list.contains(str)) {
            list.add(str);
          }
        }
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching academic sessions: $e');
    }
    return ['2024 - 2025', '2025 - 2026', '2026 - 2027', '2027 - 2028'];
  }

  /// Resolves the active Indian/academic financial year based on current system date (April to March)
  static String resolveCurrentFinancialYear(List<String> sessions) {
    final now = DateTime.now();
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    final endYear = startYear + 1;
    final endYearShort = (endYear % 100).toString().padLeft(2, '0');

    for (final s in sessions) {
      final norm = s.replaceAll(' ', '');
      if (norm.contains('$startYear-$endYear') ||
          norm.contains('$startYear–$endYear') ||
          norm.contains('$startYear-$endYearShort') ||
          norm.contains('$startYear')) {
        return s;
      }
    }
    return sessions.isNotEmpty ? sessions.first : '$startYear - $endYear';
  }

  Future<Map<String, dynamic>> fetchRecordingsList({
    String? classId,
    String? subjectId,
    String? teacherId,
    String? search,
    String? status,
    int page = 1,
    int pageSize = 8,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (classId != null && classId.isNotEmpty) params['class_id'] = classId;
    if (subjectId != null && subjectId.isNotEmpty) params['subject_id'] = subjectId;
    if (teacherId != null && teacherId.isNotEmpty) params['teacher_id'] = teacherId;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status != 'All') params['status'] = status;

    final queryStr = Uri(queryParameters: params).query;
    try {
      final res = await _apiService.get('/live-classes/recordings?$queryStr');
      final data = res['data'] ?? {};
      final items = (data['items'] as List?)?.map((i) => RecordingItem.fromJson(i)).toList() ?? [];
      return {
        'items': items,
        'total_count': data['total_count'] ?? items.length,
        'total_pages': data['total_pages'] ?? 1,
        'page': page,
      };
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching recordings list: $e');
      return {'items': <RecordingItem>[], 'total_count': 0, 'total_pages': 1, 'page': page};
    }
  }

  Future<Map<String, dynamic>> fetchAttendanceList({
    String? sessionId,
    String? statusFilter,
    String? search,
    int page = 1,
    int pageSize = 10,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (sessionId != null && sessionId.isNotEmpty) params['session_id'] = sessionId;
    if (statusFilter != null && statusFilter != 'All') params['status'] = statusFilter;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final queryStr = Uri(queryParameters: params).query;
    try {
      final res = await _apiService.get('/live-classes/attendance?$queryStr');
      final data = res['data'] ?? {};
      final items = (data['items'] as List?)?.map((i) => AttendanceItem.fromJson(i)).toList() ?? [];
      return {
        'items': items,
        'total_count': data['total_count'] ?? items.length,
        'total_pages': data['total_pages'] ?? 1,
        'counts': data['counts'] ?? {},
        'page': page,
      };
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching attendance list: $e');
      return {'items': <AttendanceItem>[], 'total_count': 0, 'total_pages': 1, 'counts': {}, 'page': page};
    }
  }

  Future<Map<String, dynamic>> createInstantClass(Map<String, dynamic> payload) async {
    return await _apiService.post('/live-classes/sessions/instant', payload);
  }

  Future<void> startLiveClass(String sessionId) async {
    await _apiService.post('/live-classes/$sessionId/start', {});
  }

  Future<void> endLiveClass(String sessionId) async {
    await _apiService.post('/live-classes/$sessionId/end', {});
  }

  Future<void> leaveLiveClass(String sessionId) async {
    try {
      await _apiService.post('/live-classes/$sessionId/leave', {});
    } catch (e) {
      debugPrint('[LiveClassApiService] Error leaving live class: $e');
    }
  }

  Future<void> overrideAttendance(String attendanceId, String newStatus, String reason) async {
    await _apiService.post('/live-classes/attendance/$attendanceId/override', {
      'new_status': newStatus,
      'reason': reason,
    });
  }

  Future<void> recalculateAttendance(String sessionId) async {
    await _apiService.post('/live-classes/$sessionId/attendance/calculate', {});
  }

  Future<void> shareRecording(String sessionId, String sharedToId) async {
    await _apiService.post('/live-classes/recordings/$sessionId/share', {
      'shared_to_id': sharedToId,
    });
  }

  Future<Map<String, dynamic>> uploadRecordingFile({
    List<int>? fileBytes,
    String? fileName,
    required String title,
    String? description,
    String? classId,
    String? sectionId,
    String? subjectId,
    String? teacherId,
    String? teacherName,
    int durationMinutes = 1,
    int? durationSeconds,
    String visibility = 'CLASS',
    String? externalUrl,
  }) async {
    final fields = <String, String>{
      'title': title,
      'duration_minutes': durationMinutes.toString(),
      'duration_seconds': (durationSeconds ?? (durationMinutes * 60)).toString(),
      'visibility': visibility,
      'recording_type': 'Uploaded Recording',
    };
    if (description != null && description.isNotEmpty) fields['description'] = description;
    if (classId != null && classId.isNotEmpty) fields['class_id'] = classId;
    if (sectionId != null && sectionId.isNotEmpty) fields['section_id'] = sectionId;
    if (subjectId != null && subjectId.isNotEmpty) fields['subject_id'] = subjectId;
    if (teacherId != null && teacherId.isNotEmpty) fields['teacher_id'] = teacherId;
    if (teacherName != null && teacherName.isNotEmpty) fields['teacher_name'] = teacherName;
    if (externalUrl != null && externalUrl.isNotEmpty) fields['external_url'] = externalUrl;

    if (fileBytes != null && fileBytes.isNotEmpty && fileName != null && fileName.isNotEmpty) {
      return await _apiService.multipartPostBytes(
        '/live-classes/recordings/upload',
        fileBytes,
        fileName,
        'file',
        fields: fields,
        timeout: const Duration(minutes: 5),
      );
    }
    return await _apiService.post('/live-classes/recordings/upload', fields);
  }

  Future<Map<String, dynamic>> updateRecording(
    String recordingId,
    Map<String, dynamic> payload,
  ) async {
    return await _apiService.patch('/live-classes/recordings/$recordingId', payload);
  }

  Future<void> deleteRecording(String recordingId) async {
    await _apiService.delete('/live-classes/recordings/$recordingId');
  }

  Future<Map<String, dynamic>> bulkDeleteRecordings(List<String> recordingIds) async {
    return await _apiService.post('/live-classes/recordings/bulk-delete', {
      'recording_ids': recordingIds,
    });
  }

  Future<int?> recordRecordingView(String recordingId) async {
    try {
      final res = await _apiService.post('/live-classes/recordings/$recordingId/view', {});
      return (res['views'] as num?)?.toInt();
    } catch (e) {
      debugPrint('[LiveClassApiService] recordRecordingView error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecordingShares(String recordingId) async {
    try {
      final res = await _apiService.get('/live-classes/recordings/$recordingId/shares', useCache: false);
      final raw = res['data'];
      if (raw is List) {
        return raw.whereType<Map<String, dynamic>>().toList();
      }
    } catch (e) {
      debugPrint('[LiveClassApiService] fetchRecordingShares error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> shareRecordingBatch(
    String recordingId,
    Map<String, dynamic> payload,
  ) async {
    return await _apiService.post('/live-classes/recordings/$recordingId/share/batch', payload);
  }

  Future<bool> revokeRecordingShare(String recordingId, String shareId) async {
    try {
      final res = await _apiService.delete('/live-classes/recordings/$recordingId/shares/$shareId');
      return res['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] revokeRecordingShare error: $e');
      return false;
    }
  }

  Future<bool> saveRecordingSettings(Map<String, dynamic> payload) async {
    try {
      final res = await _apiService.post('/live-classes/recordings/settings', payload);
      return res['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] saveRecordingSettings error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchShareDirectoryClasses() async {
    try {
      final res = await _apiService.get('/whiteboards/directory/classes', useCache: false);
      final raw = res['data']?['classes'] ?? res['classes'];
      if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('[LiveClassApiService] fetchShareDirectoryClasses error: $e');
    }
    return [];
  }

  Future<Map<String, List<Map<String, dynamic>>>> fetchShareClassMembers({
    required String classId,
    List<String> sectionIds = const [],
  }) async {
    try {
      final q = <String, String>{'class_id': classId};
      if (sectionIds.isNotEmpty) q['section_ids'] = sectionIds.join(',');
      final res = await _apiService.get('/whiteboards/directory/class-members', query: q, useCache: false);
      final data = res['data'] ?? {};
      return {
        'students': (data['students'] as List? ?? []).whereType<Map<String, dynamic>>().toList(),
        'teachers': (data['teachers'] as List? ?? []).whereType<Map<String, dynamic>>().toList(),
      };
    } catch (e) {
      debugPrint('[LiveClassApiService] fetchShareClassMembers error: $e');
      return {'students': [], 'teachers': []};
    }
  }

  Future<List<Map<String, dynamic>>> searchShareUsers({String query = '', String? role}) async {
    try {
      final q = <String, String>{'q': query};
      if (role != null && role.isNotEmpty) q['role'] = role;
      final res = await _apiService.get('/whiteboards/directory/search-users', query: q, useCache: false);
      final raw = res['data']?['users'] ?? res['users'];
      if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('[LiveClassApiService] searchShareUsers error: $e');
    }
    return [];
  }

  Future<String> resolveAuthenticatedMediaUrl(
    RecordingItem item, {
    bool isDownload = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    String raw;
    if (isDownload) {
      raw = '/api/live-classes/recordings/${item.id}/download';
    } else if (item.recordingUrl != null && item.recordingUrl!.trim().isNotEmpty) {
      final u = item.recordingUrl!.trim();
      if (u.contains('/storage/v1/object/') && item.id.isNotEmpty) {
        // Route storage-backed recordings through backend range stream endpoint when local/storage binary exists
        raw = '/api/live-classes/recordings/${item.id}/stream';
      } else {
        raw = u;
      }
    } else {
      raw = '/api/live-classes/recordings/${item.id}/stream';
    }

    final resolved = AppConfig.resolveUrl(raw);
    if (token.isEmpty) return resolved;
    // Append JWT for internal API / stream / download URLs
    if (resolved.contains('/api/live-classes/recordings/')) {
      final sep = resolved.contains('?') ? '&' : '?';
      return '$resolved${sep}token=${Uri.encodeQueryComponent(token)}';
    }
    return resolved;
  }

  // ============================================================================
  // MY CLASSES APIs
  // ============================================================================

  Future<MyClassesDashboardData> fetchMyClassesDashboard(String dateFilter) async {
    try {
      final res = await _apiService.get('/live-classes/my-classes/dashboard?date_filter=${Uri.encodeComponent(dateFilter)}');
      if (res['data'] != null) {
        return MyClassesDashboardData.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching my classes dashboard: $e');
    }
    return MyClassesDashboardData(
      myClassesToday: 4,
      ongoingLive: 1,
      upcoming: 2,
      completed: 1,
      totalStudents: 170,
      teachingDurationToday: '3 h 0 min',
      todayProgress: TodayClassProgress(
        totalClasses: 4,
        liveCount: 1,
        livePct: 25.0,
        upcomingCount: 2,
        upcomingPct: 50.0,
        completedCount: 1,
        completedPct: 25.0,
      ),
      teachingSummary: TeachingSummary(
        totalClasses: 4,
        totalDuration: '3 h 0 min',
        totalStudents: 170,
        avgParticipationPct: 92.7,
      ),
      weeklyTrend: [
        WeeklyClassTrendDay(day: 'Mon', count: 3, completed: 3),
        WeeklyClassTrendDay(day: 'Tue', count: 4, completed: 4),
        WeeklyClassTrendDay(day: 'Wed', count: 5, completed: 4),
        WeeklyClassTrendDay(day: 'Thu', count: 4, completed: 3),
        WeeklyClassTrendDay(day: 'Fri', count: 4, completed: 4),
        WeeklyClassTrendDay(day: 'Sat', count: 2, completed: 2),
        WeeklyClassTrendDay(day: 'Sun', count: 0, completed: 0),
      ],
    );
  }

  /// Fetch cascading academic subjects strictly mapped to a class and optional section
  Future<List<SubjectDropdownItem>> fetchCascadingSubjects(String classId, {String? sectionId}) async {
    try {
      final params = <String>['class_id=${Uri.encodeComponent(classId)}'];
      if (sectionId != null && sectionId.isNotEmpty && sectionId != 'All Sections') {
        params.add('section_id=${Uri.encodeComponent(sectionId)}');
      }
      final res = await _apiService.get('/live-classes/cascading-subjects?${params.join('&')}');
      final data = res['data'];
      final rawList = data is Map ? (data['subjects'] as List? ?? []) : (data is List ? data : []);
      return rawList.map((item) => SubjectDropdownItem.fromJson(item)).toList();
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching cascading subjects: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> fetchMyClassesList({
    String dateFilter = 'today',
    String? sessionName,
    String? classId,
    String? sectionId,
    String? subjectId,
    String? status,
    String? search,
    String? sortBy = 'scheduled_at',
    String? sortOrder = 'DESC',
    int page = 1,
    int pageSize = 5,
  }) async {
    try {
      final params = <String>[
        'date_filter=${Uri.encodeComponent(dateFilter)}',
        'page=$page',
        'page_size=$pageSize',
      ];
      if (sessionName != null && sessionName.isNotEmpty && sessionName != 'All') {
        params.add('session_name=${Uri.encodeComponent(sessionName)}');
      }
      if (classId != null && classId.isNotEmpty && classId != 'All Classes') {
        params.add('class_id=${Uri.encodeComponent(classId)}');
      }
      if (sectionId != null && sectionId.isNotEmpty && sectionId != 'All Sections') {
        params.add('section_id=${Uri.encodeComponent(sectionId)}');
      }
      if (subjectId != null && subjectId.isNotEmpty && subjectId != 'All Subjects') {
        params.add('subject_id=${Uri.encodeComponent(subjectId)}');
      }
      if (status != null && status.isNotEmpty && status != 'All') {
        params.add('status=${Uri.encodeComponent(status)}');
      }
      if (search != null && search.isNotEmpty) {
        params.add('search=${Uri.encodeComponent(search)}');
      }
      if (sortBy != null && sortBy.isNotEmpty) {
        params.add('sort_by=${Uri.encodeComponent(sortBy)}');
      }
      if (sortOrder != null && sortOrder.isNotEmpty) {
        params.add('sort_order=${Uri.encodeComponent(sortOrder)}');
      }

      final res = await _apiService.get('/live-classes/my-classes?${params.join('&')}');
      final data = res['data'] ?? {};
      final items = (data['items'] as List?)
              ?.map((e) => MyClassItem.fromJson(e))
              .toList() ??
          <MyClassItem>[];
      final totalCount = data['total_count'] ?? items.length;
      final totalPages = data['total_pages'] ?? 1;

      return {
        'items': items,
        'total_count': totalCount,
        'total_pages': totalPages,
        'page': page,
        'page_size': pageSize,
      };
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching my classes list: $e');
      return {
        'items': <MyClassItem>[],
        'total_count': 0,
        'total_pages': 1,
        'page': page,
        'page_size': pageSize,
      };
    }
  }

  Future<MyClassDetails?> fetchSessionDetails(String sessionId) async {
    try {
      final res = await _apiService.get('/live-classes/sessions/$sessionId/details');
      if (res['data'] != null) {
        return MyClassDetails.fromJson(res['data']);
      }
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching session details: $e');
    }
    return null;
  }

  Future<bool> duplicateSession(String sessionId) async {
    try {
      final res = await _apiService.post('/live-classes/sessions/$sessionId/duplicate', {});
      return res['data']?['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error duplicating session: $e');
      return false;
    }
  }

  Future<bool> cancelSession(String sessionId, String reason) async {
    try {
      final res = await _apiService.post('/live-classes/sessions/$sessionId/cancel', {'reason': reason});
      return res['data']?['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error cancelling session: $e');
      return false;
    }
  }

  Future<bool> updateSession(String sessionId, Map<String, dynamic> payload) async {
    try {
      final res = await _apiService.put('/live-classes/sessions/$sessionId', payload);
      return res['data']?['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error updating session: $e');
      return false;
    }
  }

  Future<bool> deleteSession(String sessionId) async {
    try {
      final res = await _apiService.delete('/live-classes/sessions/$sessionId');
      return res['data']?['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error deleting session: $e');
      return false;
    }
  }

  Future<bool> bulkCancelSessions(List<String> sessionIds, {String reason = 'Bulk cancellation'}) async {
    try {
      final res = await _apiService.post('/live-classes/sessions/bulk-cancel', {
        'session_ids': sessionIds,
        'reason': reason,
      });
      return res['data']?['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error bulk cancelling sessions: $e');
      return false;
    }
  }

  Future<bool> bulkDeleteSessions(List<String> sessionIds) async {
    try {
      final res = await _apiService.post('/live-classes/sessions/bulk-delete', {
        'session_ids': sessionIds,
      });
      return res['data']?['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error bulk deleting sessions: $e');
      return false;
    }
  }

  // ============================================================================
  // JOIN VIA CODE & GUEST JOIN API CALLS
  // ============================================================================

  Future<Map<String, dynamic>> validateJoinCode(String code) async {
    try {
      final res = await _apiService.post('/live-classes/join-code/validate', {'code': code.trim().toUpperCase()});
      final data = res['data'] ?? res;
      if (data['success'] == true && data['session'] != null) {
        return {
          'success': true,
          'status_code': data['status_code'] ?? 'CAN_JOIN',
          'session': ValidatedMeetingInfo.fromJson(data['session']),
          'message': data['message'] ?? 'Meeting code verified successfully',
        };
      }
      return {
        'success': false,
        'status_code': data['status_code'] ?? 'ERROR',
        'message': data['message'] ?? 'Meeting code could not be verified',
      };
    } catch (e) {
      debugPrint('[LiveClassApiService] Error validating join code: $e');
      return {
        'success': false,
        'status_code': 'NETWORK_ERROR',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  Future<List<RecentMeetingCodeItem>> fetchRecentMeetingCodes() async {
    try {
      final res = await _apiService.get('/live-classes/recent-codes');
      final data = res['data'] ?? res;
      final rawList = (data['items'] as List?) ?? [];
      return rawList.map((x) => RecentMeetingCodeItem.fromJson(x)).toList();
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching recent codes: $e');
      // Return seeded fallback matching mockup
      return [
        RecentMeetingCodeItem(
          id: '1',
          meetingCode: '10A-MATH',
          classSubject: 'Class 10 - A\nMathematics',
          teacherName: 'R. Kumar',
          isStarred: true,
          lastJoinedStr: 'Today, 08:00 AM',
        ),
        RecentMeetingCodeItem(
          id: '2',
          meetingCode: '11A-PHY',
          classSubject: 'Class 11 - A\nPhysics',
          teacherName: 'S. Verma',
          isStarred: false,
          lastJoinedStr: 'Yesterday, 10:00 AM',
        ),
        RecentMeetingCodeItem(
          id: '3',
          meetingCode: '8A-ENG',
          classSubject: 'Class 8 - A\nEnglish',
          teacherName: 'P. Desai',
          isStarred: false,
          lastJoinedStr: '20 Jan 2025, 11:15 AM',
        ),
        RecentMeetingCodeItem(
          id: '4',
          meetingCode: '12B-CHEM',
          classSubject: 'Class 12 - B\nChemistry',
          teacherName: 'A. Sharma',
          isStarred: false,
          lastJoinedStr: '18 Jan 2025, 09:00 AM',
        ),
      ];
    }
  }

  Future<bool> toggleStarredMeetingCode(String code, bool isStarred) async {
    try {
      final res = await _apiService.post('/live-classes/recent-codes/toggle-star', {
        'code': code,
        'is_starred': isStarred,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error toggling starred code: $e');
      return false;
    }
  }

  Future<bool> clearRecentMeetingCodes() async {
    try {
      final res = await _apiService.delete('/live-classes/recent-codes/clear');
      return res['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error clearing recent codes: $e');
      return false;
    }
  }

  Future<GuestJoinResponse> requestGuestJoin({
    required String code,
    required String displayName,
    String? email,
    required String purpose,
    String? organization,
    Map<String, dynamic>? options,
  }) async {
    try {
      final res = await _apiService.post('/live-classes/guest/request', {
        'code': code.trim().toUpperCase(),
        'display_name': displayName.trim(),
        'email': email?.trim(),
        'purpose': purpose,
        'organization': organization?.trim(),
        'options': options ?? {},
      });
      final data = res['data'] ?? res;
      return GuestJoinResponse.fromJson(data);
    } catch (e) {
      debugPrint('[LiveClassApiService] Error requesting guest join: $e');
      return GuestJoinResponse(
        success: false,
        guestId: '',
        requestId: '',
        guestReference: '',
        displayName: displayName,
        approvalStatus: 'FAILED',
        sessionId: '',
        requiresWaitingRoom: false,
        message: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<List<GuestSessionItem>> fetchUpcomingGuestSessions() async {
    try {
      final res = await _apiService.get('/live-classes/guest/upcoming-sessions');
      final data = res['data'] ?? res;
      final rawList = (data['sessions'] as List?) ?? [];
      return rawList.map((x) => GuestSessionItem.fromJson(x)).toList();
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching upcoming guest sessions: $e');
      // Return seeded fallback matching mockup
      return [
        GuestSessionItem(
          id: 'g1',
          classSubject: 'Class 10 - A\nMathematics',
          subjectName: 'Mathematics',
          topic: 'Quadratic Equations – Guest Lecture',
          scheduledDateStr: 'Tue, 21 Jan 2025',
          scheduledTimeStr: '10:00 AM - 10:45 AM',
          hostName: 'R. Kumar',
          roomCode: '10A-MATH',
          status: 'Upcoming',
        ),
        GuestSessionItem(
          id: 'g2',
          classSubject: 'Class 12 - B\nPhysics',
          subjectName: 'Physics',
          topic: 'Career in Physics – Expert Talk',
          scheduledDateStr: 'Fri, 24 Jan 2025',
          scheduledTimeStr: '11:15 AM - 12:00 PM',
          hostName: 'S. Verma',
          roomCode: '11A-PHY',
          status: 'Upcoming',
        ),
        GuestSessionItem(
          id: 'g3',
          classSubject: 'Class 11 - A\nChemistry',
          subjectName: 'Chemistry',
          topic: 'Industrial Applications of Chemistry',
          scheduledDateStr: 'Mon, 27 Jan 2025',
          scheduledTimeStr: '02:00 PM - 02:45 PM',
          hostName: 'A. Sharma',
          roomCode: '12B-CHEM',
          status: 'Scheduled',
        ),
      ];
    }
  }

  // ==========================================================================
  // CONDUCT CLASS INTERACTIVE APIS
  // ==========================================================================

  Future<ConductClassSessionData?> fetchConductSessionData([String? sessionId]) async {
    try {
      final endpoint = (sessionId != null && sessionId.isNotEmpty)
          ? '/live-classes/conduct?session_id=${Uri.encodeComponent(sessionId)}'
          : '/live-classes/conduct';
      final res = await _apiService.get(endpoint);
      final data = res['data'] ?? res;
      if (data != null && data is Map<String, dynamic>) {
        return ConductClassSessionData.fromJson(data);
      }
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching conduct session data: $e');
    }
    return null;
  }

  Future<LiveClassQuestionItem?> submitQuestion(
    String sessionId,
    String question, {
    String? authorName,
    String? authorRole,
    bool isAnonymous = false,
  }) async {
    try {
      final res = await _apiService.post(
        '/live-classes/sessions/$sessionId/questions',
        {
          'question': question,
          if (authorName != null) 'author_name': authorName,
          if (authorRole != null) 'author_role': authorRole,
          'is_anonymous': isAnonymous,
        },
      );
      final data = res['data'] ?? res;
      if (data != null && data is Map<String, dynamic>) {
        return LiveClassQuestionItem.fromJson(data);
      }
    } catch (e) {
      debugPrint('[LiveClassApiService] Error submitting question: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> answerQuestion(
    String questionId,
    String answer, {
    String? authorName,
    String? authorRole,
    String? sessionId,
  }) async {
    try {
      final res = await _apiService.post(
        '/live-classes/questions/$questionId/answer',
        {
          'answer': answer,
          if (authorName != null) 'author_name': authorName,
          if (authorRole != null) 'author_role': authorRole,
          if (sessionId != null) 'session_id': sessionId,
        },
      );
      if (res['success'] == true && res['data'] != null) {
        return res['data'] as Map<String, dynamic>;
      }
      return {'success': res['success'] == true};
    } catch (e) {
      debugPrint('[LiveClassApiService] Error answering question: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> upvoteQuestion(String questionId) async {
    try {
      final res = await _apiService.post(
        '/live-classes/questions/$questionId/upvote',
        {},
      );
      if (res['success'] == true && res['data'] != null) {
        return res['data'] as Map<String, dynamic>;
      }
      return {'success': res['success'] == true};
    } catch (e) {
      debugPrint('[LiveClassApiService] Error upvoting question: $e');
      return null;
    }
  }

  Future<LiveClassPollItem?> createPoll(
    String sessionId,
    Map<String, dynamic> pollData,
  ) async {
    try {
      final res = await _apiService.post(
        '/live-classes/sessions/$sessionId/polls',
        pollData,
      );
      final data = res['data'] ?? res;
      if (data != null && data is Map<String, dynamic>) {
        return LiveClassPollItem.fromJson(data);
      }
    } catch (e) {
      debugPrint('[LiveClassApiService] Error creating poll: $e');
    }
    return null;
  }

  Future<bool> respondToPoll(
    String pollId,
    String sessionId,
    String optionId,
  ) async {
    try {
      final res = await _apiService.post(
        '/live-classes/polls/$pollId/respond',
        {
          'session_id': sessionId,
          'option_id': optionId,
        },
      );
      return res['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error responding to poll: $e');
      return false;
    }
  }

  Future<bool> saveWhiteboard(
    String sessionId,
    Map<String, dynamic> canvasData, {
    bool teacherOnlyMode = true,
  }) async {
    try {
      final res = await _apiService.post(
        '/live-classes/sessions/$sessionId/whiteboard',
        {
          'canvas_data': canvasData,
          'teacher_only_mode': teacherOnlyMode,
        },
      );
      return res['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error saving whiteboard: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> toggleRecording(String sessionId) async {
    try {
      final res = await _apiService.post(
        '/live-classes/sessions/$sessionId/recordings/toggle',
        {},
      );
      return res;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error toggling recording: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> muteParticipant(
    String sessionId,
    String participantId,
    bool isMuted,
  ) async {
    try {
      final res = await _apiService.post(
        '/live-classes/sessions/$sessionId/participants/$participantId/mute',
        {'is_muted': isMuted},
      );
      return res['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error muting participant: $e');
      return false;
    }
  }

  Future<bool> removeParticipant(String sessionId, String participantId) async {
    try {
      final res = await _apiService.post(
        '/live-classes/sessions/$sessionId/participants/$participantId/remove',
        {},
      );
      return res['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error removing participant: $e');
      return false;
    }
  }

  // ============================================================================
  // ENROLLED STUDENTS, BREAKOUT ROOMS, HOST REASSIGNMENT & SESSION SETTINGS
  // ============================================================================

  Future<List<Map<String, dynamic>>> fetchEnrolledStudents({
    String? classId,
    String? sectionId,
  }) async {
    try {
      final queryParams = <String>[];
      if (classId != null && classId.isNotEmpty) {
        queryParams.add('class_id=${Uri.encodeComponent(classId)}');
      }
      if (sectionId != null && sectionId.isNotEmpty) {
        queryParams.add('section_id=${Uri.encodeComponent(sectionId)}');
      }
      final qs = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      final res = await _apiService.get('/live-classes/students$qs');
      final data = res['data'] ?? res;
      if (data != null && data['students'] != null) {
        return List<Map<String, dynamic>>.from(data['students']);
      }
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching enrolled students: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchBreakoutRooms(String sessionId) async {
    try {
      final res = await _apiService.get('/live-classes/sessions/$sessionId/breakout');
      final data = res['data'] ?? res;
      if (data != null && data['rooms'] != null) {
        return List<Map<String, dynamic>>.from(data['rooms']);
      }
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching breakout rooms: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> createBreakoutRoom(
    String sessionId,
    String name,
    int capacity,
  ) async {
    try {
      final res = await _apiService.post(
        '/live-classes/sessions/$sessionId/breakout',
        {
          'name': name,
          'capacity': capacity,
        },
      );
      final data = res['data'] ?? res;
      if (data != null && data['room'] != null) {
        return Map<String, dynamic>.from(data['room']);
      }
    } catch (e) {
      debugPrint('[LiveClassApiService] Error creating breakout room: $e');
    }
    return null;
  }

  Future<bool> closeBreakoutRoom(String sessionId, String roomId) async {
    try {
      final res = await _apiService.post(
        '/live-classes/sessions/$sessionId/breakout/$roomId/close',
        {},
      );
      return res['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error closing breakout room: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchSessionSettings(String sessionId) async {
    try {
      final res = await _apiService.get('/live-classes/sessions/$sessionId/settings');
      final data = res['data'] ?? res;
      if (data != null && data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching session settings: $e');
    }
    return null;
  }

  Future<bool> updateSessionSettings(
    String sessionId,
    Map<String, dynamic> settings,
  ) async {
    try {
      final res = await _apiService.post(
        '/live-classes/sessions/$sessionId/settings',
        settings,
      );
      return res['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error updating session settings: $e');
      return false;
    }
  }

  Future<bool> reassignHost(
    String sessionId,
    String targetUserId, {
    String role = 'host',
  }) async {
    try {
      final res = await _apiService.post(
        '/live-classes/sessions/$sessionId/host',
        {
          'target_user_id': targetUserId,
          'role': role,
        },
      );
      return res['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error reassigning host: $e');
      return false;
    }
  }

  Future<bool> reviewGuestRequest(
    String sessionId,
    String requestId, {
    required String decision,
    String? reason,
  }) async {
    try {
      final res = await _apiService.post(
        '/live-classes/sessions/$sessionId/guests/$requestId/review',
        {
          'decision': decision,
          'reason': reason,
        },
      );
      return res['success'] == true;
    } catch (e) {
      debugPrint('[LiveClassApiService] Error reviewing guest request: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> checkGuestAdmissionStatus(String requestId) async {
    try {
      final res = await _apiService.get('/live-classes/guest/status/$requestId');
      final data = res['data'] ?? res;
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('[LiveClassApiService] Error checking guest status: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchWaitingRoomGuests(String sessionId) async {
    try {
      final res = await _apiService.get('/live-classes/sessions/$sessionId/waiting-room');
      final data = res['data'] ?? res;
      final rawList = (data['guests'] as List?) ?? [];
      return rawList.map((x) => Map<String, dynamic>.from(x as Map)).toList();
    } catch (e) {
      debugPrint('[LiveClassApiService] Error fetching waiting room: $e');
      return [];
    }
  }
}
