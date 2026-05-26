import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';

class TeacherNotifications extends ConsumerStatefulWidget {
  const TeacherNotifications({super.key});

  @override
  ConsumerState<TeacherNotifications> createState() => _TeacherNotificationsState();
}

class _TeacherNotificationsState extends ConsumerState<TeacherNotifications> {
  final TeacherApiService _apiService = TeacherApiService();
  
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Unread', 'Read'];
  List<TeacherNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      bool? isRead;
      if (_selectedFilter == 'Unread') isRead = false;
      if (_selectedFilter == 'Read') isRead = true;
      
      final notifications = await _apiService.getNotifications(isRead: isRead);
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'homework':
        return Icons.home_work;
      case 'attendance':
        return Icons.check_circle;
      case 'exam':
        return Icons.school;
      case 'system':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'homework':
        return Colors.orange;
      case 'attendance':
        return Colors.green;
      case 'exam':
        return Colors.blue;
      case 'system':
        return Colors.grey;
      default:
        return Colors.purple;
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
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/teacher/dashboard'),
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
                if (_notifications.any((n) => !n.isRead))
                  TextButton(
                    onPressed: () async {
                      await _apiService.markAllNotificationsAsRead();
                      _loadNotifications();
                    },
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),

          // Filter tabs
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedFilter = filter);
                    _loadNotifications();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEC4899) : const Color(0xFFFCE7F3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFFEC4899),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Loading state
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),

          // Error state
          if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadNotifications,
                      child: Text('Retry'.tr(ref)),
                    ),
                  ],
                ),
              ),
            ),

          // Notifications list
          if (!_isLoading && _error == null)
            Expanded(
              child: _notifications.isEmpty
                  ? Center(child: Text('No notifications'.tr(ref)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        return _buildNotificationCard(_notifications[index]);
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(TeacherNotification notification) {
    final typeColor = _getTypeColor(notification.type);
    final icon = _getTypeIcon(notification.type);
    
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      onDismissed: (_) async {
        await _apiService.markNotificationAsRead(notification.id);
        _loadNotifications();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : typeColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead ? const Color(0xFFE2E8F0) : typeColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: typeColor, size: 20),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 14,
                      fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimeAgo(notification.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            // Unread indicator
            if (!notification.isRead)
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
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return dateTime.toString().split(' ')[0];
  }
}
