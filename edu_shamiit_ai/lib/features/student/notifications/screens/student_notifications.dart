import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentNotifications extends ConsumerStatefulWidget {
  const StudentNotifications({super.key});

  @override
  ConsumerState<StudentNotifications> createState() => _StudentNotificationsState();
}

class _StudentNotificationsState extends ConsumerState<StudentNotifications> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'icon': '📝',
      'title': 'Homework Due Today!',
      'message': 'Integration Practice Set due at 5 PM',
      'time': '2 mins ago',
      'color': StudentColors.error,
      'bgColor': StudentColors.errorBg,
      'unread': true,
    },
    {
      'icon': '💳',
      'title': 'Fee Reminder',
      'message': '₹12,500 due by April 5',
      'time': '1 hour ago',
      'color': StudentColors.warning,
      'bgColor': StudentColors.warningBg,
      'unread': true,
    },
    {
      'icon': '📊',
      'title': 'Results Published!',
      'message': 'Term 2 results are now available',
      'time': '3 hours ago',
      'color': StudentColors.primary,
      'bgColor': StudentColors.primaryLight,
      'unread': false,
    },
    {
      'icon': '🚌',
      'title': 'Bus Update',
      'message': 'Bus Route 7B will arrive 5 min late today',
      'time': 'Today, 2:30 PM',
      'color': StudentColors.info,
      'bgColor': StudentColors.infoBg,
      'unread': false,
    },
    {
      'icon': '🏆',
      'title': 'Achievement Unlocked!',
      'message': 'You earned the "Academic Excellence" badge',
      'time': 'Yesterday',
      'color': StudentColors.success,
      'bgColor': StudentColors.successBg,
      'unread': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF302B63)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (var n in _notifications) {
                        n['unread'] = false;
                      }
                    });
                  },
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white60,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                return _buildNotificationCard(notif);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
        border: Border(
          left: BorderSide(
            color: notif['unread'] as bool? ?? false ? notif['color'] as Color : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: notif['bgColor'] as Color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(notif['icon']!, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif['title']!,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notif['message']!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: StudentColors.text3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notif['time']!,
                  style: const TextStyle(
                    fontSize: 9,
                    color: StudentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          if (notif['unread'] as bool? ?? false)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: notif['color'] as Color,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}