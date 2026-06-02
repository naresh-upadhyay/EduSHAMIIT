import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/services/api_service.dart';
import 'package:edu_shamiit_ai/core/providers/api_provider.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

/// Attendance record model (matches backend response)
class AttendanceRecord {
  final String status; // present, absent, late
  final String? subjectName;
  final Map<String, dynamic>? subject;

  AttendanceRecord({
    required this.status,
    this.subjectName,
    this.subject,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      status: json['status'] as String? ?? 'present',
      subjectName: (json['subjects']?['name'] ?? json['subject']) as String?,
      subject: json['subjects'] as Map<String, dynamic>?,
    );
  }
}

/// Leave application model (matches backend response)
class LeaveApplication {
  final String id;
  final String leaveType;
  final String startDate;
  final String endDate;
  final String reason;
  final String status;
  final DateTime createdAt;

  LeaveApplication({
    required this.id,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory LeaveApplication.fromJson(Map<String, dynamic> json) {
    return LeaveApplication(
      id: json['id'] as String,
      leaveType: json['leave_type'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String,
      createdAt: _parseDateTime(json['created_at']),
    );
  }
}

/// Library borrow model (matches backend response)
class LibraryBorrow {
  final String id;
  final String bookTitle;
  final String bookAuthor;
  final String coverUrl;
  final DateTime borrowedAt;
  final DateTime? dueDate;
  final DateTime? returnedAt;
  final String status;

  LibraryBorrow({
    required this.id,
    required this.bookTitle,
    required this.bookAuthor,
    required this.coverUrl,
    required this.borrowedAt,
    this.dueDate,
    this.returnedAt,
    required this.status,
  });

  factory LibraryBorrow.fromJson(Map<String, dynamic> json) {
    final book = json['library_books'] as Map<String, dynamic>? ?? {};
    return LibraryBorrow(
      id: json['id'] as String,
      bookTitle: book['title'] as String? ?? 'Unknown',
      bookAuthor: book['author'] as String? ?? 'Unknown',
      coverUrl: book['cover_url'] as String? ?? '',
      borrowedAt: _parseDateTime(json['borrowed_at']),
      dueDate: _parseDateTimeNullable(json['due_date']),
      returnedAt: _parseDateTimeNullable(json['returned_at']),
      status: json['status'] as String,
    );
  }
}

/// Course model (matches backend response)
class Course {
  final String id;
  final String name;
  final String? description;
  final String? schedule;
  final String? room;
  final String? credits;
  final Map<String, dynamic>? subject;

  Course({
    required this.id,
    required this.name,
    this.description,
    this.schedule,
    this.room,
    this.credits,
    this.subject,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      description: json['description'] as String?,
      schedule: json['schedule'] as String?,
      room: json['room'] as String?,
      credits: json['credits'] as String?,
      subject: json['subjects'] as Map<String, dynamic>?,
    );
  }
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  final str = value.toString().trim();
  if (str.isEmpty) return DateTime.now();
  
  String cleaned = str;
  if (cleaned.endsWith('+00')) {
    cleaned = cleaned.substring(0, cleaned.length - 3) + 'Z';
  } else if (cleaned.contains('+') && !cleaned.substring(cleaned.indexOf('+')).contains(':')) {
    final plusIndex = cleaned.lastIndexOf('+');
    final offset = cleaned.substring(plusIndex + 1);
    if (offset.length == 2) {
      cleaned = cleaned.substring(0, plusIndex) + '+$offset:00';
    } else if (offset.length == 4) {
      cleaned = cleaned.substring(0, plusIndex) + '+${offset.substring(0, 2)}:${offset.substring(2)}';
    }
  } else if (cleaned.contains('-') && cleaned.lastIndexOf('-') > cleaned.lastIndexOf(':') && !cleaned.substring(cleaned.lastIndexOf('-')).contains(':')) {
    final minusIndex = cleaned.lastIndexOf('-');
    final offset = cleaned.substring(minusIndex + 1);
    if (offset.length == 2) {
      cleaned = cleaned.substring(0, minusIndex) + '-$offset:00';
    } else if (offset.length == 4) {
      cleaned = cleaned.substring(0, minusIndex) + '-${offset.substring(0, 2)}:${offset.substring(2)}';
    }
  }
  cleaned = cleaned.replaceAll(' ', 'T');
  return DateTime.tryParse(cleaned) ?? DateTime.tryParse(str) ?? DateTime.now();
}

DateTime? _parseDateTimeNullable(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final str = value.toString().trim();
  if (str.isEmpty) return null;
  
  String cleaned = str;
  if (cleaned.endsWith('+00')) {
    cleaned = cleaned.substring(0, cleaned.length - 3) + 'Z';
  } else if (cleaned.contains('+') && !cleaned.substring(cleaned.indexOf('+')).contains(':')) {
    final plusIndex = cleaned.lastIndexOf('+');
    final offset = cleaned.substring(plusIndex + 1);
    if (offset.length == 2) {
      cleaned = cleaned.substring(0, plusIndex) + '+$offset:00';
    } else if (offset.length == 4) {
      cleaned = cleaned.substring(0, plusIndex) + '+${offset.substring(0, 2)}:${offset.substring(2)}';
    }
  } else if (cleaned.contains('-') && cleaned.lastIndexOf('-') > cleaned.lastIndexOf(':') && !cleaned.substring(cleaned.lastIndexOf('-')).contains(':')) {
    final minusIndex = cleaned.lastIndexOf('-');
    final offset = cleaned.substring(minusIndex + 1);
    if (offset.length == 2) {
      cleaned = cleaned.substring(0, minusIndex) + '-$offset:00';
    } else if (offset.length == 4) {
      cleaned = cleaned.substring(0, minusIndex) + '-${offset.substring(0, 2)}:${offset.substring(2)}';
    }
  }
  cleaned = cleaned.replaceAll(' ', 'T');
  return DateTime.tryParse(cleaned) ?? DateTime.tryParse(str);
}

/// Notification model (matches backend response)
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type;
  final String? referenceId;
  final DateTime createdAt;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.referenceId,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      referenceId: json['reference_id'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}

/// Live class model (matches backend response)
class LiveClass {
  final String id;
  final String title;
  final String? teacherName;
  final DateTime scheduledAt;
  final String? joinUrl;
  final String status; // live, scheduled, ended
  final Map<String, dynamic>? subject;

  LiveClass({
    required this.id,
    required this.title,
    this.teacherName,
    required this.scheduledAt,
    this.joinUrl,
    required this.status,
    this.subject,
  });

  factory LiveClass.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? {};
    return LiveClass(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Unknown',
      teacherName: profile['full_name'] as String?,
      scheduledAt: _parseDateTime(json['scheduled_at']),
      joinUrl: json['join_url'] as String?,
      status: json['status'] as String,
      subject: json['subjects'] as Map<String, dynamic>?,
    );
  }
}

/// Leaderboard entry model (matches backend response)
class LeaderboardEntry {
  final int rank;
  final String studentId;
  final String studentName;
  final String? avatarUrl;
  final int xpPoints;
  final int learningStreak;

  LeaderboardEntry({
    required this.rank,
    required this.studentId,
    required this.studentName,
    this.avatarUrl,
    required this.xpPoints,
    required this.learningStreak,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json, int index) {
    return LeaderboardEntry(
      rank: index + 1,
      studentId: json['id']?.toString() ?? '',
      studentName: json['full_name']?.toString() ?? 'Student',
      avatarUrl: json['avatar_url']?.toString(),
      xpPoints: json['xp_points'] as int? ?? 0,
      learningStreak: json['learning_streak'] as int? ?? 0,
    );
  }
}

/// Message model (matches backend response)
class MessageItem {
  final String id;
  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final String? senderRole;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  MessageItem({
    required this.id,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    this.senderRole,
    required this.content,
    required this.createdAt,
    required this.isRead,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? {};
    return MessageItem(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      senderName: profile['full_name'] as String?,
      senderAvatar: profile['avatar_url'] as String?,
      senderRole: profile['role'] as String?,
      content: json['content'] as String,
      createdAt: _parseDateTime(json['created_at']),
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}

/// Exam model (matches backend response)
class ExamItem {
  final String id;
  final String title;
  final String? description;
  final String examDate;
  final String? startTime;
  final String? endTime;
  final String status; // upcoming, ongoing, completed
  final Map<String, dynamic>? subject;

  ExamItem({
    required this.id,
    required this.title,
    this.description,
    required this.examDate,
    this.startTime,
    this.endTime,
    required this.status,
    this.subject,
  });

  factory ExamItem.fromJson(Map<String, dynamic> json) {
    return ExamItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      examDate: json['exam_date'] as String,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      status: json['status'] as String,
      subject: json['subjects'] as Map<String, dynamic>?,
    );
  }
}

// ============================================================================
// ATTENDANCE PROVIDER
// ============================================================================

class AttendanceState {
  final bool isLoading;
  final String? error;
  final List<AttendanceRecord> records;
  final Map<String, dynamic> summary;

  AttendanceState({
    this.isLoading = false,
    this.error,
    this.records = const [],
    this.summary = const {},
  });

  AttendanceState copyWith({
    bool? isLoading,
    String? error,
    List<AttendanceRecord>? records,
    Map<String, dynamic>? summary,
  }) {
    return AttendanceState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      records: records ?? this.records,
      summary: summary ?? this.summary,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final ApiService _apiService;

  AttendanceNotifier(this._apiService) : super(AttendanceState());

  Future<void> fetchAttendance() async {
    if (state.records.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final response = await _apiService.get('/student/attendance');
      final data = response.containsKey('data') ? response['data'] : response;
      final rawRecords = data['records'] ?? data['subject_wise'] ?? [];
      final recordsList = (rawRecords as List).map((r) => AttendanceRecord.fromJson(r)).toList();
      state = state.copyWith(
        isLoading: false,
        records: recordsList,
        summary: data['summary'] as Map<String, dynamic>? ?? data,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

final attendanceProvider = StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  return AttendanceNotifier(ref.watch(apiServiceProvider));
});

// ============================================================================
// LEAVE APPLICATION PROVIDER
// ============================================================================

class LeaveState {
  final bool isLoading;
  final String? error;
  final List<LeaveApplication> applications;

  LeaveState({
    this.isLoading = false,
    this.error,
    this.applications = const [],
  });

  LeaveState copyWith({
    bool? isLoading,
    String? error,
    List<LeaveApplication>? applications,
  }) {
    return LeaveState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      applications: applications ?? this.applications,
    );
  }
}

class LeaveNotifier extends StateNotifier<LeaveState> {
  final ApiService _apiService;

  LeaveNotifier(this._apiService) : super(LeaveState());

  Future<void> fetchLeaveApplications() async {
    if (state.applications.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final response = await _apiService.get('/student/leave-applications');
      final data = response.containsKey('data') ? response['data'] : response;
      final apps = (data['applications'] ?? data['leave'] ?? []).map((a) => LeaveApplication.fromJson(a)).toList();
      state = state.copyWith(
        isLoading: false,
        applications: apps,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> submitLeaveApplication({
    required String type,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _apiService.post('/student/leave-applications', {
        'type': type,
        'start_date': startDate,
        'end_date': endDate,
        'reason': reason,
      });
      await fetchLeaveApplications();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final leaveProvider = StateNotifierProvider<LeaveNotifier, LeaveState>((ref) {
  return LeaveNotifier(ref.watch(apiServiceProvider));
});

// ============================================================================
// LIBRARY PROVIDER
// ============================================================================

class LibraryState {
  final bool isLoading;
  final String? error;
  final List<LibraryBorrow> borrows;
  final int totalBorrows;
  final int activeBorrows;
  final int overdueBooks;

  LibraryState({
    this.isLoading = false,
    this.error,
    this.borrows = const [],
    this.totalBorrows = 0,
    this.activeBorrows = 0,
    this.overdueBooks = 0,
  });

  LibraryState copyWith({
    bool? isLoading,
    String? error,
    List<LibraryBorrow>? borrows,
    int? totalBorrows,
    int? activeBorrows,
    int? overdueBooks,
  }) {
    return LibraryState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      borrows: borrows ?? this.borrows,
      totalBorrows: totalBorrows ?? this.totalBorrows,
      activeBorrows: activeBorrows ?? this.activeBorrows,
      overdueBooks: overdueBooks ?? this.overdueBooks,
    );
  }
}

class LibraryNotifier extends StateNotifier<LibraryState> {
  final ApiService _apiService;

  LibraryNotifier(this._apiService) : super(LibraryState());

  Future<void> fetchLibraryData() async {
    if (state.borrows.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final response = await _apiService.get('/student/library');
      final data = response.containsKey('data') ? response['data'] : response;
      final borrowsList = (data['borrows'] ?? []).map((b) => LibraryBorrow.fromJson(b)).toList();
      final active = borrowsList.where((b) => b.status == 'borrowed').length;
      final overdue = borrowsList.where((b) => b.dueDate != null && b.dueDate!.isBefore(DateTime.now()) && b.returnedAt == null).length;
      state = state.copyWith(
        isLoading: false,
        borrows: borrowsList,
        totalBorrows: borrowsList.length,
        activeBorrows: active,
        overdueBooks: overdue,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  return LibraryNotifier(ref.watch(apiServiceProvider));
});

// ============================================================================
// COURSES PROVIDER
// ============================================================================

class CoursesState {
  final bool isLoading;
  final String? error;
  final List<Course> courses;
  final int totalCredits;
  final double averageProgress;

  CoursesState({
    this.isLoading = false,
    this.error,
    this.courses = const [],
    this.totalCredits = 0,
    this.averageProgress = 0.0,
  });

  CoursesState copyWith({
    bool? isLoading,
    String? error,
    List<Course>? courses,
    int? totalCredits,
    double? averageProgress,
  }) {
    return CoursesState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      courses: courses ?? this.courses,
      totalCredits: totalCredits ?? this.totalCredits,
      averageProgress: averageProgress ?? this.averageProgress,
    );
  }
}

class CoursesNotifier extends StateNotifier<CoursesState> {
  final ApiService _apiService;

  CoursesNotifier(this._apiService) : super(CoursesState());

  Future<void> fetchCourses() async {
    if (state.courses.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final response = await _apiService.get('/student/courses');
      final data = response.containsKey('data') ? response['data'] : response;
      final coursesList = (data['courses'] ?? []).map((c) => Course.fromJson(c)).toList();
      state = state.copyWith(
        isLoading: false,
        courses: coursesList,
        totalCredits: data['total_credits'] as int? ?? 0,
        averageProgress: (data['average_progress'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final coursesProvider = StateNotifierProvider<CoursesNotifier, CoursesState>((ref) {
  return CoursesNotifier(ref.watch(apiServiceProvider));
});

// ============================================================================
// ============================================================================
// NOTIFICATIONS PROVIDER
// ============================================================================

class NotificationsState {
  final bool isLoading;
  final String? error;
  final List<NotificationItem> notifications;
  final int unreadCount;

  NotificationsState({
    this.isLoading = false,
    this.error,
    this.notifications = const [],
    this.unreadCount = 0,
  });

  NotificationsState copyWith({
    bool? isLoading,
    String? error,
    List<NotificationItem>? notifications,
    int? unreadCount,
  }) {
    return NotificationsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final ApiService _apiService;

  NotificationsNotifier(this._apiService) : super(NotificationsState());

  /// Always fetch fresh data (no isEmpty guard) so badge stays current.
  Future<void> fetchNotifications({bool useCache = true}) async {
    if (state.notifications.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final response = await _apiService.get('/student/notifications', useCache: useCache);
      final data = response.containsKey('data') ? response['data'] : response;
      final rawList = (data['notifications'] as List? ?? []);
      final notificationsList = rawList.map((n) => NotificationItem.fromJson(n as Map<String, dynamic>)).toList();
      final unread = notificationsList.where((n) => !n.isRead).length;
      state = state.copyWith(
        isLoading: false,
        notifications: notificationsList,
        unreadCount: unread,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Force-refresh ignoring cache (for realtime updates).
  Future<void> forceRefresh() async {
    try {
      final response = await _apiService.get('/student/notifications', useCache: false);
      final data = response.containsKey('data') ? response['data'] : response;
      final rawList = (data['notifications'] as List? ?? []);
      final notificationsList = rawList.map((n) => NotificationItem.fromJson(n as Map<String, dynamic>)).toList();
      final unread = notificationsList.where((n) => !n.isRead).length;
      state = state.copyWith(
        isLoading: false,
        notifications: notificationsList,
        unreadCount: unread,
      );
    } catch (_) {}
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _apiService.put('/student/notifications/$notificationId/read', {});
      // Update local state immediately
      final updated = state.notifications.map((n) {
        if (n.id == notificationId) {
          return NotificationItem(
            id: n.id,
            title: n.title,
            message: n.message,
            type: n.type,
            referenceId: n.referenceId,
            createdAt: n.createdAt,
            isRead: true,
          );
        }
        return n;
      }).toList();
      state = state.copyWith(
        notifications: updated,
        unreadCount: updated.where((n) => !n.isRead).length,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.patch('/notifications/read-all', {});
      final updated = state.notifications.map((n) => NotificationItem(
        id: n.id, title: n.title, message: n.message, type: n.type,
        referenceId: n.referenceId, createdAt: n.createdAt, isRead: true,
      )).toList();
      state = state.copyWith(notifications: updated, unreadCount: 0);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _apiService.delete('/student/notifications/$notificationId');
      final updated = state.notifications.where((n) => n.id != notificationId).toList();
      state = state.copyWith(
        notifications: updated,
        unreadCount: updated.where((n) => !n.isRead).length,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref.watch(apiServiceProvider));
});

// ============================================================================
// LIVE CLASSES PROVIDER
// ============================================================================

class LiveClassesState {
  final bool isLoading;
  final String? error;
  final List<LiveClass> classes;
  final int liveCount;
  final int upcomingCount;

  LiveClassesState({
    this.isLoading = false,
    this.error,
    this.classes = const [],
    this.liveCount = 0,
    this.upcomingCount = 0,
  });

  LiveClassesState copyWith({
    bool? isLoading,
    String? error,
    List<LiveClass>? classes,
    int? liveCount,
    int? upcomingCount,
  }) {
    return LiveClassesState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      classes: classes ?? this.classes,
      liveCount: liveCount ?? this.liveCount,
      upcomingCount: upcomingCount ?? this.upcomingCount,
    );
  }
}

class LiveClassesNotifier extends StateNotifier<LiveClassesState> {
  final ApiService _apiService;

  LiveClassesNotifier(this._apiService) : super(LiveClassesState());

  Future<void> fetchLiveClasses() async {
    if (state.classes.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final response = await _apiService.get('/student/live-classes');
      final data = response.containsKey('data') ? response['data'] : response;
      final classesList = (data['classes'] ?? []).map((c) => LiveClass.fromJson(c)).toList();
      state = state.copyWith(
        isLoading: false,
        classes: classesList,
        liveCount: data['live_count'] as int? ?? 0,
        upcomingCount: data['upcoming_count'] as int? ?? 0,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final liveClassesProvider = StateNotifierProvider<LiveClassesNotifier, LiveClassesState>((ref) {
  return LiveClassesNotifier(ref.watch(apiServiceProvider));
});

// ============================================================================
// LEADERBOARD PROVIDER
// ============================================================================

class LeaderboardState {
  final bool isLoading;
  final String? error;
  final List<LeaderboardEntry> entries;
  final int userRank;
  final double userCgpa;

  LeaderboardState({
    this.isLoading = false,
    this.error,
    this.entries = const [],
    this.userRank = 0,
    this.userCgpa = 0.0,
  });

  LeaderboardState copyWith({
    bool? isLoading,
    String? error,
    List<LeaderboardEntry>? entries,
    int? userRank,
    double? userCgpa,
  }) {
    return LeaderboardState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      entries: entries ?? this.entries,
      userRank: userRank ?? this.userRank,
      userCgpa: userCgpa ?? this.userCgpa,
    );
  }
}

class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  final ApiService _apiService;

  LeaderboardNotifier(this._apiService) : super(LeaderboardState());

  Future<void> fetchLeaderboard() async {
    if (state.entries.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final response = await _apiService.get('/student/leaderboard');
      final data = response.containsKey('data') ? response['data'] : response;
      final rawEntries = data['entries'] ?? data['leaderboard'] ?? [];
      
      List<LeaderboardEntry> entriesList = [];
      for (int i = 0; i < (rawEntries as List).length; i++) {
        entriesList.add(LeaderboardEntry.fromJson(rawEntries[i], i));
      }
      
      state = state.copyWith(
        isLoading: false,
        entries: entriesList,
        userRank: data['user_rank'] as int? ?? 0,
        userCgpa: (data['user_cgpa'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final leaderboardProvider = StateNotifierProvider<LeaderboardNotifier, LeaderboardState>((ref) {
  return LeaderboardNotifier(ref.watch(apiServiceProvider));
});

// ============================================================================
// MESSAGING PROVIDER
// ============================================================================

class ChatConversation {
  final String id;
  final String name;
  final String? avatarUrl;
  final String type; // 'direct' or 'group'
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String? role; // 'student' or 'teacher' (only for direct type)

  ChatConversation({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.type,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    this.role,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      avatarUrl: json['avatar_url'] as String?,
      type: json['type'] as String? ?? 'direct',
      lastMessage: json['last_message'] as String? ?? '',
      lastMessageTime: _parseDateTime(json['last_message_time']),
      unreadCount: json['unread_count'] as int? ?? 0,
      role: json['role'] as String?,
    );
  }
}

class MessagingState {
  final bool isLoading;
  final String? error;
  final List<ChatConversation> conversations;
  final List<MessageItem> chatHistory;
  final int unreadCount;
  final List<String> blockedUserIds;

  MessagingState({
    this.isLoading = false,
    this.error,
    this.conversations = const [],
    this.chatHistory = const [],
    this.unreadCount = 0,
    this.blockedUserIds = const [],
  });

  MessagingState copyWith({
    bool? isLoading,
    String? error,
    List<ChatConversation>? conversations,
    List<MessageItem>? chatHistory,
    int? unreadCount,
    List<String>? blockedUserIds,
  }) {
    return MessagingState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      conversations: conversations ?? this.conversations,
      chatHistory: chatHistory ?? this.chatHistory,
      unreadCount: unreadCount ?? this.unreadCount,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
    );
  }
}

class MessagingNotifier extends StateNotifier<MessagingState> {
  final ApiService _apiService;

  MessagingNotifier(this._apiService) : super(MessagingState());

  Future<void> fetchMessages({bool useCache = true}) async {
    if (state.conversations.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      try {
        await fetchBlockedUsers();
      } catch (_) {}
      
      final response = await _apiService.get('/student/messages', useCache: useCache);
      final data = response.containsKey('data') ? response['data'] : response;
      final rawConvs = data['conversations'] as List? ?? [];
      final conversationsList = rawConvs.map((c) => ChatConversation.fromJson(c as Map<String, dynamic>)).toList();
      final totalUnread = conversationsList.fold<int>(0, (sum, c) => sum + c.unreadCount);
      
      state = state.copyWith(
        isLoading: false,
        conversations: conversationsList,
        unreadCount: totalUnread,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchChatHistory(String chatId, {bool refreshConversations = true}) async {
    if (state.chatHistory.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final response = await _apiService.get('/student/messages/chat?chat_id=$chatId', useCache: false);
      final data = response.containsKey('data') ? response['data'] : response;
      final rawMsgs = data['messages'] as List? ?? [];
      final history = rawMsgs.map((m) => MessageItem.fromJson(m as Map<String, dynamic>)).toList();
      state = state.copyWith(
        isLoading: false,
        chatHistory: history,
      );
      // Refresh conversations to clear unread counts locally
      if (refreshConversations) {
        fetchMessages(useCache: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Directly append a new message from realtime payload to avoid an extra API call.
  /// Falls back to a full fetchChatHistory if the payload is incomplete.
  void appendNewMessage(Map<String, dynamic> rawPayload, String currentUserId) {
    try {
      final id = rawPayload['id'] as String?;
      final senderId = rawPayload['sender_id'] as String?;
      final content = rawPayload['content'] as String?;
      final createdAtStr = rawPayload['created_at'] as String?;
      if (id == null || senderId == null || content == null || createdAtStr == null) return;

      // Avoid duplicates (our own send already optimistically refreshes)
      if (state.chatHistory.any((m) => m.id == id)) return;

      final newMsg = MessageItem(
        id: id,
        senderId: senderId,
        senderName: null, // will be filled when full history is fetched next time
        senderAvatar: null,
        senderRole: null,
        content: content,
        createdAt: _parseDateTime(createdAtStr),
        isRead: senderId == currentUserId,
      );

      state = state.copyWith(chatHistory: [...state.chatHistory, newMsg]);
    } catch (_) {
      // ignore parse errors – the subscription callback will do a fallback fetchChatHistory
    }
  }


  Future<bool> sendMessage(String content, {String? receiverId, String? groupId}) async {
    try {
      final body = {
        'content': content,
      };
      if (groupId != null) {
        body['group_id'] = groupId;
      } else {
        body['receiver_id'] = receiverId ?? '';
      }

      await _apiService.post('/student/messages/send', body);
      
      // If we are currently viewing this chat, refresh its history
      final activeChatId = groupId ?? receiverId;
      if (activeChatId != null) {
        await fetchChatHistory(activeChatId);
      } else {
        await fetchMessages(useCache: false);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await _apiService.get('/users/search?q=$query');
      final data = response.containsKey('data') ? response['data'] : response;
      final users = data['users'] as List? ?? [];
      return List<Map<String, dynamic>>.from(users);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchGroups() async {
    try {
      final response = await _apiService.get('/student/groups');
      final data = response.containsKey('data') ? response['data'] : response;
      final groups = data['groups'] as List? ?? [];
      return List<Map<String, dynamic>>.from(groups);
    } catch (e) {
      return [];
    }
  }

  Future<bool> createGroup(
    String name,
    String description, {
    List<String> memberIds = const [],
    Uint8List? avatarBytes,
    String? avatarFilename,
    String groupLevel = 'school',
    String? className,
    bool isPrivate = false,
  }) async {
    try {
      final response = await _apiService.post('/student/groups/create', {
        'name': name,
        'description': description,
        'group_level': groupLevel,
        'class_name': className,
        'is_private': isPrivate,
      });
      final data = response.containsKey('data') ? response['data'] : response;
      final group = data['group'] as Map<String, dynamic>?;
      final groupId = group?['id'] as String?;

      if (groupId != null) {
        if (avatarBytes != null && avatarFilename != null) {
          try {
            await _apiService.multipartPostBytes(
              '/groups/$groupId/avatar',
              avatarBytes,
              avatarFilename,
              'avatar',
            );
          } catch (_) {}
        }

        if (memberIds.isNotEmpty) {
          for (final mid in memberIds) {
            try {
              await _apiService.post('/groups/$groupId/members', {
                'member_id': mid,
              });
            } catch (_) {}
          }
          
          try {
            await _apiService.post('/student/messages/send', {
              'group_id': groupId,
              'content': '📢 Group squad revision formed with ${memberIds.length + 1} members!'
            });
          } catch (_) {}
        }
      }

      _apiService.clearCache();
      await fetchMessages(useCache: false);
      return true;
    } catch (e) {
      return false;
    }
  }



  Future<bool> joinGroup(String groupId) async {
    try {
      await _apiService.post('/groups/$groupId/join', {});
      _apiService.clearCache();
      await fetchMessages(useCache: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> leaveGroup(String groupId) async {
    try {
      await _apiService.post('/groups/$groupId/leave', {});
      _apiService.clearCache();
      await fetchMessages(useCache: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchGroupMembers(String groupId) async {
    try {
      final response = await _apiService.get('/groups/$groupId/members');
      final data = response.containsKey('data') ? response['data'] : response;
      final members = data['members'] as List? ?? [];
      return List<Map<String, dynamic>>.from(members);
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteMessage(String messageId, String chatId) async {
    try {
      await _apiService.delete('/student/messages/$messageId');
      await fetchChatHistory(chatId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearChat(String chatId) async {
    try {
      await _apiService.post('/student/messages/clear', {'chat_id': chatId});
      await fetchChatHistory(chatId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> fetchBlockedUsers() async {
    try {
      final response = await _apiService.get('/users/blocked');
      final data = response.containsKey('data') ? response['data'] : response;
      final blocked = data['blocked_ids'] as List? ?? [];
      state = state.copyWith(blockedUserIds: List<String>.from(blocked));
    } catch (_) {}
  }

  Future<bool> blockUser(String userId) async {
    try {
      await _apiService.post('/users/$userId/block', {});
      await fetchBlockedUsers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> unblockUser(String userId) async {
    try {
      await _apiService.post('/users/$userId/unblock', {});
      await fetchBlockedUsers();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteGroup(String groupId) async {
    try {
      await _apiService.delete('/groups/$groupId');
      _apiService.clearCache();
      await fetchMessages(useCache: false);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeGroupMember(String groupId, String memberId) async {
    try {
      await _apiService.delete('/groups/$groupId/members/$memberId');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> changeMemberRole(String groupId, String memberId, String role) async {
    try {
      await _apiService.post('/groups/$groupId/members/$memberId/role', {
        'role': role,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateGroupAvatar(String groupId, Uint8List bytes, String filename) async {
    try {
      await _apiService.multipartPostBytes(
        '/groups/$groupId/avatar',
        bytes,
        filename,
        'avatar',
      );
      _apiService.clearCache();
      await fetchMessages(useCache: false);
      return true;
    } catch (e) {
      return false;
    }
  }
}

final messagingProvider = StateNotifierProvider<MessagingNotifier, MessagingState>((ref) {
  return MessagingNotifier(ref.watch(apiServiceProvider));
});

// ============================================================================
// ONLINE EXAM PROVIDER
// ============================================================================

class OnlineExamState {
  final bool isLoading;
  final String? error;
  final List<ExamItem> exams;
  final int upcomingCount;
  final int ongoingCount;
  final int completedCount;

  OnlineExamState({
    this.isLoading = false,
    this.error,
    this.exams = const [],
    this.upcomingCount = 0,
    this.ongoingCount = 0,
    this.completedCount = 0,
  });

  OnlineExamState copyWith({
    bool? isLoading,
    String? error,
    List<ExamItem>? exams,
    int? upcomingCount,
    int? ongoingCount,
    int? completedCount,
  }) {
    return OnlineExamState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      exams: exams ?? this.exams,
      upcomingCount: upcomingCount ?? this.upcomingCount,
      ongoingCount: ongoingCount ?? this.ongoingCount,
      completedCount: completedCount ?? this.completedCount,
    );
  }
}

class OnlineExamNotifier extends StateNotifier<OnlineExamState> {
  final ApiService _apiService;

  OnlineExamNotifier(this._apiService) : super(OnlineExamState());

  Future<void> fetchExams() async {
    if (state.exams.isEmpty) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final response = await _apiService.get('/student/exams');
      final data = response.containsKey('data') ? response['data'] : response;
      final examsList = (data['exams'] ?? []).map((e) => ExamItem.fromJson(e)).toList();
      final upcoming = examsList.where((e) => e.status == 'upcoming').length;
      final ongoing = examsList.where((e) => e.status == 'ongoing').length;
      final completed = examsList.where((e) => e.status == 'completed').length;
      state = state.copyWith(
        isLoading: false,
        exams: examsList,
        upcomingCount: upcoming,
        ongoingCount: ongoing,
        completedCount: completed,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final onlineExamProvider = StateNotifierProvider<OnlineExamNotifier, OnlineExamState>((ref) {
  return OnlineExamNotifier(ref.watch(apiServiceProvider));
});
