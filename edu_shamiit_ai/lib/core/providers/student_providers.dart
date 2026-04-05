import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:edu_shamiit_ai/core/config/app_config.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';

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
      status: json['status'] as String,
      subjectName: json['subjects']?['name'] as String?,
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
      createdAt: DateTime.parse(json['created_at'] as String),
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
      borrowedAt: DateTime.parse(json['borrowed_at'] as String),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      returnedAt: json['returned_at'] != null ? DateTime.parse(json['returned_at'] as String) : null,
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

/// Notification model (matches backend response)
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type;
  final DateTime createdAt;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      createdAt: DateTime.parse(json['created_at'] as String),
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
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
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

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: 0, // Will be set by list index
      studentId: json['id'] as String,
      studentName: json['full_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
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
      createdAt: DateTime.parse(json['created_at'] as String),
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
  final Ref ref;

  AttendanceNotifier(this.ref) : super(AttendanceState());

  Future<void> fetchAttendance() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = ref.read(authProvider).token;
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/student/attendance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final recordsList = (data['records'] as List).map((r) => AttendanceRecord.fromJson(r)).toList();
        state = state.copyWith(
          isLoading: false,
          records: recordsList,
          summary: data['summary'] as Map<String, dynamic>? ?? {},
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to fetch attendance',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

final attendanceProvider = StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  return AttendanceNotifier(ref);
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
  final Ref ref;

  LeaveNotifier(this.ref) : super(LeaveState());

  Future<void> fetchLeaveApplications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = ref.read(authProvider).token;
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/student/leave-applications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final apps = (data['applications'] as List).map((a) => LeaveApplication.fromJson(a)).toList();
        state = state.copyWith(
          isLoading: false,
          applications: apps,
        );
      } else {
        state = state.copyWith(isLoading: false, error: 'Failed to fetch leave applications');
      }
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
      final token = ref.read(authProvider).token;
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/student/leave-applications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'type': type,
          'start_date': startDate,
          'end_date': endDate,
          'reason': reason,
        }),
      ).timeout(AppConfig.apiTimeout);

      if (response.statusCode == 201) {
        await fetchLeaveApplications();
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: 'Failed to submit leave application');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final leaveProvider = StateNotifierProvider<LeaveNotifier, LeaveState>((ref) {
  return LeaveNotifier(ref);
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
  final Ref ref;

  LibraryNotifier(this.ref) : super(LibraryState());

  Future<void> fetchLibraryData() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = ref.read(authProvider).token;
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/student/library'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final borrowsList = (data['borrows'] as List).map((b) => LibraryBorrow.fromJson(b)).toList();
        final active = borrowsList.where((b) => b.status == 'borrowed').length;
        final overdue = borrowsList.where((b) => b.dueDate != null && b.dueDate!.isBefore(DateTime.now()) && b.returnedAt == null).length;
        state = state.copyWith(
          isLoading: false,
          borrows: borrowsList,
          totalBorrows: borrowsList.length,
          activeBorrows: active,
          overdueBooks: overdue,
        );
      } else {
        state = state.copyWith(isLoading: false, error: 'Failed to fetch library data');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  return LibraryNotifier(ref);
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
  final Ref ref;

  CoursesNotifier(this.ref) : super(CoursesState());

  Future<void> fetchCourses() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = ref.read(authProvider).token;
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/student/courses'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final courses = (data['courses'] as List).map((c) => Course.fromJson(c)).toList();
        state = state.copyWith(
          isLoading: false,
          courses: courses,
          totalCredits: data['total_credits'] as int? ?? 0,
          averageProgress: (data['average_progress'] as num?)?.toDouble() ?? 0.0,
        );
      } else {
        state = state.copyWith(isLoading: false, error: 'Failed to fetch courses');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final coursesProvider = StateNotifierProvider<CoursesNotifier, CoursesState>((ref) {
  return CoursesNotifier(ref);
});

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
  final Ref ref;

  NotificationsNotifier(this.ref) : super(NotificationsState());

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = ref.read(authProvider).token;
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/student/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final notifications = (data['notifications'] as List).map((n) => NotificationItem.fromJson(n)).toList();
        final unread = notifications.where((n) => !n.isRead).length;
        state = state.copyWith(
          isLoading: false,
          notifications: notifications,
          unreadCount: unread,
        );
      } else {
        state = state.copyWith(isLoading: false, error: 'Failed to fetch notifications');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final token = ref.read(authProvider).token;
      await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/student/notifications/$notificationId/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(AppConfig.apiTimeout);

      // Update local state
      state = state.copyWith(
        notifications: state.notifications.map((n) {
          if (n.id == notificationId) {
            return NotificationItem(
              id: n.id,
              title: n.title,
              message: n.message,
              type: n.type,
              createdAt: n.createdAt,
              isRead: true,
            );
          }
          return n;
        }).toList(),
        unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref);
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
  final Ref ref;

  LiveClassesNotifier(this.ref) : super(LiveClassesState());

  Future<void> fetchLiveClasses() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = ref.read(authProvider).token;
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/student/live-classes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final classes = (data['classes'] as List).map((c) => LiveClass.fromJson(c)).toList();
        state = state.copyWith(
          isLoading: false,
          classes: classes,
          liveCount: data['live_count'] as int? ?? 0,
          upcomingCount: data['upcoming_count'] as int? ?? 0,
        );
      } else {
        state = state.copyWith(isLoading: false, error: 'Failed to fetch live classes');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final liveClassesProvider = StateNotifierProvider<LiveClassesNotifier, LiveClassesState>((ref) {
  return LiveClassesNotifier(ref);
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
  final Ref ref;

  LeaderboardNotifier(this.ref) : super(LeaderboardState());

  Future<void> fetchLeaderboard() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = ref.read(authProvider).token;
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/student/leaderboard'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final entries = (data['entries'] as List).map((e) => LeaderboardEntry.fromJson(e)).toList();
        state = state.copyWith(
          isLoading: false,
          entries: entries,
          userRank: data['user_rank'] as int? ?? 0,
          userCgpa: (data['user_cgpa'] as num?)?.toDouble() ?? 0.0,
        );
      } else {
        state = state.copyWith(isLoading: false, error: 'Failed to fetch leaderboard');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final leaderboardProvider = StateNotifierProvider<LeaderboardNotifier, LeaderboardState>((ref) {
  return LeaderboardNotifier(ref);
});

// ============================================================================
// MESSAGING PROVIDER
// ============================================================================

class MessagingState {
  final bool isLoading;
  final String? error;
  final List<MessageItem> messages;
  final int unreadCount;

  MessagingState({
    this.isLoading = false,
    this.error,
    this.messages = const [],
    this.unreadCount = 0,
  });

  MessagingState copyWith({
    bool? isLoading,
    String? error,
    List<MessageItem>? messages,
    int? unreadCount,
  }) {
    return MessagingState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      messages: messages ?? this.messages,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class MessagingNotifier extends StateNotifier<MessagingState> {
  final Ref ref;

  MessagingNotifier(this.ref) : super(MessagingState());

  Future<void> fetchMessages() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = ref.read(authProvider).token;
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/student/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final messages = (data['messages'] as List).map((m) => MessageItem.fromJson(m)).toList();
        final unread = messages.where((m) => !m.isRead).length;
        state = state.copyWith(
          isLoading: false,
          messages: messages,
          unreadCount: unread,
        );
      } else {
        state = state.copyWith(isLoading: false, error: 'Failed to fetch messages');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> sendMessage(String content, String receiverId) async {
    try {
      final token = ref.read(authProvider).token;
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/student/messages/send'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'content': content, 'receiver_id': receiverId}),
      ).timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        await fetchMessages();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

final messagingProvider = StateNotifierProvider<MessagingNotifier, MessagingState>((ref) {
  return MessagingNotifier(ref);
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
  final Ref ref;

  OnlineExamNotifier(this.ref) : super(OnlineExamState());

  Future<void> fetchExams() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = ref.read(authProvider).token;
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/student/exams'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(AppConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final examsList = (data['exams'] as List).map((e) => ExamItem.fromJson(e)).toList();
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
      } else {
        state = state.copyWith(isLoading: false, error: 'Failed to fetch exams');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final onlineExamProvider = StateNotifierProvider<OnlineExamNotifier, OnlineExamState>((ref) {
  return OnlineExamNotifier(ref);
});
