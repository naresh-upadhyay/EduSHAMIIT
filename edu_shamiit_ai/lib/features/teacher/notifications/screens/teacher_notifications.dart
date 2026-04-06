import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class TeacherNotifications extends StatefulWidget {
  const TeacherNotifications({super.key});

  @override
  State<TeacherNotifications> createState() => _TeacherNotificationsState();
}

class _TeacherNotificationsState extends State<TeacherNotifications> {
  String _selectedTab = 'All';
  final List<String> _tabs = ['All', 'Unread', 'System', 'Student', 'Admin'];

  final List<Map<String, dynamic>> _notifications = [
    {
      'id': '1',
      'title': 'New Homework Submission',
      'message': 'Aarav Sharma submitted the Trigonometry assignment',
      'type': 'Student',
      'time': DateTime.now().subtract(const Duration(minutes: 15)),
      'read': false,
      'icon': '📝',
    },
    {
      'id': '2',
      'title': 'Staff Meeting Reminder',
      'message': 'Meeting scheduled for tomorrow at 2:00 PM in Conference Room',
      'type': 'Admin',
      'time': DateTime.now().subtract(const Duration(hours: 2)),
      'read': false,
      'icon': '📅',
    },
    {
      'id': '3',
      'title': 'System Update',
      'message': 'LMS will be updated tonight from 11 PM to 1 AM',
      'type': 'System',
      'time': DateTime.now().subtract(const Duration(hours: 5)),
      'read': true,
      'icon': '⚙️',
    },
    {
      'id': '4',
      'title': 'Leave Request',
      'message': 'Vivaan Patel has requested leave for tomorrow',
      'type': 'Student',
      'time': DateTime.now().subtract(const Duration(days: 1)),
      'read': true,
      'icon': '📅',
    },
    {
      'id': '5',
      'title': 'Exam Schedule Released',
      'message': 'Term 2 exam schedule has been published',
      'type': 'Admin',
      'time': DateTime.now().subtract(const Duration(days: 2)),
      'read': true,
      'icon': '📋',
    },
    {
      'id': '6',
      'title': 'Low Attendance Alert',
      'message': 'Aditya Singh attendance dropped below 75%',
      'type': 'Student',
      'time': DateTime.now().subtract(const Duration(days: 3)),
      'read': false,
      'icon': '⚠️',
    },
  ];

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_selectedTab == 'All') return _notifications;
    if (_selectedTab == 'Unread') return _notifications.where((n) => !(n['read'] as bool)).toList();
    return _notifications.where((n) => n['type'] == _selectedTab).toList();
  }

  int get _unreadCount => _notifications.where((n) => !(n['read'] as bool)).length;

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Student': return const Color(0xFF4F46E5);
      case 'Admin': return const Color(0xFF0EA5E9);
      case 'System': return const Color(0xFF6B7280);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
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
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: () {},
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$_unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = _selectedTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTab = tab),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tab,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF0369A1),
                          ),
                        ),
                        if (tab == 'Unread' && _unreadCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_unreadCount',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Notifications list
          Expanded(
            child: _filteredNotifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🔔', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        Text(
                          'No $_selectedTab notifications',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredNotifications.length,
                    itemBuilder: (context, index) {
                      return _buildNotificationCard(_filteredNotifications[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isUnread = !(notification['read'] as bool);
    final typeColor = _getTypeColor(notification['type'] as String);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? typeColor.withOpacity(0.3) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                notification['icon'] as String,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification['title'] as String,
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isUnread ? const Color(0xFF0F172A) : Colors.grey[700],
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: typeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification['message'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        notification['type'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimeAgo(notification['time'] as DateTime),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          Column(
            children: [
              IconButton(
                icon: Icon(
                  isUnread ? Icons.mark_email_unread_outlined : Icons.check_circle_outline,
                  color: isUnread ? typeColor : Colors.grey[400],
                ),
                onPressed: () {
                  setState(() {
                    notification['read'] = true;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.grey[400]),
                onPressed: () {
                  setState(() {
                    _notifications.removeWhere((n) => n['id'] == notification['id']);
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}