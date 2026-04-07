import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/student_providers.dart';

class StudentNotifications extends ConsumerStatefulWidget {
  const StudentNotifications({super.key});

  @override
  ConsumerState<StudentNotifications> createState() => _StudentNotificationsState();
}

class _StudentNotificationsState extends ConsumerState<StudentNotifications> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(notificationsProvider.notifier).fetchNotifications();
    });
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'homework':
        return StudentColors.error;
      case 'fee':
        return StudentColors.warning;
      case 'result':
        return StudentColors.primary;
      case 'transport':
        return StudentColors.info;
      case 'achievement':
        return StudentColors.success;
      default:
        return StudentColors.primary;
    }
  }

  String _getIconForType(String type) {
    switch (type) {
      case 'homework':
        return '📝';
      case 'fee':
        return '💳';
      case 'result':
        return '📊';
      case 'transport':
        return '🚌';
      case 'achievement':
        return '🏆';
      default:
        return '📢';
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final notificationsState = ref.watch(notificationsProvider);
    final notifications = notificationsState.notifications;
    final unreadCount = notificationsState.unreadCount;

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
                    // Mark all as read
                    for (final notif in notifications.where((n) => !n.isRead)) {
                      ref.read(notificationsProvider.notifier).markAsRead(notif.id);
                    }
                  },
                  child: Text(
                    unreadCount > 0 ? 'Mark all read ($unreadCount)' : 'All read',
                    style: const TextStyle(
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
            child: notificationsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : notifications.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none, size: 64, color: StudentColors.text3),
                            SizedBox(height: 16),
                            Text(
                              'No notifications',
                              style: TextStyle(
                                fontFamily: AppFonts.heading,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: StudentColors.text3,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notif = notifications[index];
                          return _buildNotificationCard(notif);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notif) {
    final color = _getColorForType(notif.type);
    final icon = _getIconForType(notif.type);
    final bgColor = color.withValues(alpha: 0.1);
    
    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: StudentColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.done, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(notificationsProvider.notifier).markAsRead(notif.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
          ],
          border: Border(
            left: BorderSide(
              color: notif.isRead ? Colors.transparent : color,
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
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.title,
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notif.message,
                    style: const TextStyle(
                      fontSize: 10,
                      color: StudentColors.text3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatTime(notif.createdAt),
                    style: const TextStyle(
                      fontSize: 9,
                      color: StudentColors.text3,
                    ),
                  ),
                ],
              ),
            ),
            if (!notif.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
