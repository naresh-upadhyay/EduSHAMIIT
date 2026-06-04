import '../constants/mock_data.dart';

/// Service that provides mock data when API calls fail
/// This service acts as a fallback mechanism to ensure the UI always has data to display
/// To disable mock data fallback, simply delete the mock_data.dart file
class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;
  MockDataService._internal();

  // Student Profile
  Map<String, dynamic> getStudentProfile() => MockData.studentProfile;

  // Attendance
  Map<String, dynamic> getAttendanceSummary() => MockData.attendanceSummary;
  List<dynamic> getAttendanceRecords() => MockData.attendanceRecords;

  // Homework
  List<dynamic> getHomeworkAssignments() => MockData.homeworkAssignments;

  // Exams
  List<dynamic> getUpcomingExams() => MockData.upcomingExams;
  List<dynamic> getExamResults() => MockData.examResults;

  // Fees
  List<dynamic> getFeeRecords() => MockData.feeRecords;

  // Timetable
  List<dynamic> getTimetable() => MockData.timetable;

  // Live Classes
  List<dynamic> getLiveClasses() => MockData.liveClasses;

  // Notices
  List<dynamic> getNotices() => MockData.notices;

  // Notifications
  List<dynamic> getNotifications() => MockData.notifications;



  // Achievements
  List<dynamic> getAchievements() => MockData.achievements;

  // Leaderboard
  List<dynamic> getLeaderboard() => MockData.leaderboard;

  // Leave
  List<dynamic> getLeaveApplications() => MockData.leaveApplications;

  // Library
  List<dynamic> getLibraryBooks() => MockData.libraryBooks;
  List<dynamic> getIssuedBooks() => MockData.issuedBooks;

  // Courses
  List<dynamic> getCourses() => MockData.courses;

  // Messages
  List<dynamic> getMessages() => MockData.messages;

  // Transport
  Map<String, dynamic> getTransportRoute() => MockData.transportRoute;

  // Performance Analytics
  List<dynamic> getPerformanceAnalytics() => MockData.performanceAnalytics;
}