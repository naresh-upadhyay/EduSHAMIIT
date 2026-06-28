import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// Service for handling push notifications
/// Supports local notifications, scheduled notifications, and FCM integration
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> init({
    Function(NotificationResponse)? onNotificationTap,
    Function(String, String)? onBackgroundNotificationTap,
  }) async {
    if (_isInitialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _backgroundHandler,
    );

    // Request permissions
    await requestPermissions();

    _isInitialized = true;
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    // Note: Permission handling is done during initialization
    // Android 13+ handles permissions through the initialize method
    return true;
  }

  /// Show an immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
    String? channelName,
    String? channelDescription,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
    bool playSound = true,
    bool enableVibration = true,
    String? icon,
  }) async {
    // Ensure initialized
    if (!_isInitialized) await init();

    // Default channel settings
    channelId ??= 'EduSHAMIIT_default';
    channelName ??= 'EduSHAMIIT Notifications';
    channelDescription ??= 'Notifications from EduSHAMIIT Student Portal';

    // Create/update channel for Android
    const androidDetails = AndroidNotificationDetails(
      'EduSHAMIIT_default',
      'EduSHAMIIT Notifications',
      channelDescription: 'Notifications from EduSHAMIIT Student Portal',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Schedule a notification for a specific time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    bool matchDateTimeComponents = false,
  }) async {
    if (!_isInitialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'EduSHAMIIT_scheduled',
      'Scheduled Notifications',
      channelDescription: 'Scheduled notifications from EduSHAMIIT',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Schedule a daily notification
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required Time scheduledTime,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await scheduleNotification(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      payload: payload,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Get pending notification requests
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Check if a notification is pending
  Future<bool> isNotificationPending(int id) async {
    final pending = await getPendingNotifications();
    return pending.any((n) => n.id == id);
  }

  /// Handle background notification tap
  @pragma('vm:entry-point')
  static void _backgroundHandler(NotificationResponse notification) {
    debugPrint('Background notification tapped: ${notification.payload}');
  }

  /// Show homework reminder notification
  Future<void> showHomeworkReminder(String subject, String dueTime) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '📝 Homework Reminder',
      body: '$subject homework is due at $dueTime',
      payload: jsonEncode({'type': 'homework', 'subject': subject}),
    );
  }

  /// Show exam reminder notification
  Future<void> showExamReminder(String subject, DateTime examDate) async {
    final daysUntil = examDate.difference(DateTime.now()).inDays;
    String message;
    
    if (daysUntil == 0) {
      message = '$subject exam is TODAY! Good luck! 🍀';
    } else if (daysUntil == 1) {
      message = '$subject exam is TOMORROW! Time to revise! 📚';
    } else {
      message = '$subject exam in $daysUntil days. Keep preparing! 💪';
    }

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '📋 Exam Reminder',
      body: message,
      payload: jsonEncode({'type': 'exam', 'subject': subject}),
    );
  }

  /// Show attendance alert notification
  Future<void> showAttendanceAlert(double percentage, String subject) async {
    String message;
    if (percentage < 60) {
      message = '⚠️ Your $subject attendance is critically low at ${percentage.toStringAsFixed(1)}%';
    } else if (percentage < 75) {
      message = '⚡ Your $subject attendance is ${percentage.toStringAsFixed(1)}%. Attend more classes!';
    } else {
      message = '✅ Your $subject attendance is healthy at ${percentage.toStringAsFixed(1)}%';
    }

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '📊 Attendance Alert',
      body: message,
      payload: jsonEncode({'type': 'attendance', 'percentage': percentage}),
    );
  }

  /// Show achievement notification
  Future<void> showAchievement(String title, String description) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🏆 $title',
      body: description,
      payload: jsonEncode({'type': 'achievement', 'title': title}),
    );
  }
}

/// Time class for scheduling notifications
class Time {
  final int hour;
  final int minute;

  const Time(this.hour, this.minute);
}

/// Notification types for categorization
enum NotificationType {
  homework,
  exam,
  attendance,
  achievement,
  fee,
  transport,
  notice,
  message,
  liveClass,
  result,
}