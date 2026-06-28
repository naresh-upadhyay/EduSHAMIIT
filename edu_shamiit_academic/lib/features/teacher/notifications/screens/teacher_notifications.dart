import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:edu_shamiit_academic/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_academic/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_core/models/teacher_models.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';

class TeacherNotifications extends ConsumerStatefulWidget {
  const TeacherNotifications({super.key});

  @override
  ConsumerState<TeacherNotifications> createState() =>
      _TeacherNotificationsState();
}

class _TeacherNotificationsState extends ConsumerState<TeacherNotifications>
    with SingleTickerProviderStateMixin {
  final TeacherApiService _apiService = TeacherApiService();
  late TabController _tabController;
  RealtimeChannel? _realtimeChannel;

  List<TeacherNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotifications();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    if (_realtimeChannel != null) return;
    final currentUserId = ref.read(authProvider).userData?['id'] as String?;
    if (currentUserId == null) return;

    _realtimeChannel = Supabase.instance.client
        .channel('teacher_notif_screen_$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: currentUserId,
          ),
          callback: (payload) {
            if (!mounted) return;
            _loadNotifications();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Always load all notifications; filter client-side for tabs
      final notifications = await _apiService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(TeacherNotification notification) async {
    try {
      await _apiService.markNotificationAsRead(notification.id);
      if (!mounted) return;
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notification.id);
        if (idx != -1) {
          _notifications[idx] = TeacherNotification(
            id: notification.id,
            title: notification.title,
            message: notification.message,
            type: notification.type,
            referenceId: notification.referenceId,
            actionUrl: notification.actionUrl,
            createdAt: notification.createdAt,
            isRead: true,
            readAt: DateTime.now(),
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      await _apiService.markAllNotificationsAsRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((n) => TeacherNotification(
          id: n.id, title: n.title, message: n.message, type: n.type,
          referenceId: n.referenceId, actionUrl: n.actionUrl,
          createdAt: n.createdAt, isRead: true, readAt: DateTime.now(),
        )).toList();
      });
    } catch (_) {}
  }

  Future<void> _deleteNotification(TeacherNotification notification) async {
    try {
      await _apiService.deleteNotification(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications.removeWhere((n) => n.id == notification.id);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase().trim()) {
      case 'attendance': return Icons.person_off_outlined;
      case 'homework':   return Icons.assignment_outlined;
      case 'message':    return Icons.chat_bubble_outline;
      case 'notice':     return Icons.campaign_outlined;
      case 'salary':     return Icons.monetization_on_outlined;
      case 'exam':       return Icons.school_outlined;
      case 'system':     return Icons.settings_outlined;
      default:           return Icons.notifications_none_outlined;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase().trim()) {
      case 'attendance': return Colors.red;
      case 'homework':   return Colors.orange;
      case 'message':    return const Color(0xFF6366F1);
      case 'notice':     return Colors.purple;
      case 'salary':     return Colors.teal;
      case 'exam':       return Colors.indigo;
      case 'system':     return Colors.grey;
      default:           return const Color(0xFFEC4899);
    }
  }

  void _handleNotificationTap(TeacherNotification notification) {
    _markAsRead(notification);
    final normType = notification.type.toLowerCase().trim();
    switch (normType) {
      case 'attendance': context.push('/teacher/student-directory'); break;
      case 'homework':   context.push('/teacher/homework'); break;
      case 'notice':     context.push('/teacher/notices'); break;
      case 'salary':     context.push('/teacher/salary'); break;
      case 'exam':       context.push('/teacher/exams'); break;
      case 'system':     context.push('/teacher/settings'); break;
      case 'message':
        if (notification.referenceId != null) {
          context.push('/teacher/messaging?chat_id=${notification.referenceId}');
        } else {
          context.push('/teacher/messaging');
        }
        break;
      default: break;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).userData?['id'] as String?;
    if (currentUserId != null && _realtimeChannel == null) {
      Future.microtask(() => _setupRealtimeSubscription());
    }
    final unreadNotifications = _notifications.where((n) => !n.isRead).toList();
    final readNotifications = _notifications.where((n) => n.isRead).toList();
    final unreadCount = unreadNotifications.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
                16, Responsive.headerTopPadding(context), 16, 0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => safeGoBack(context, '/teacher/dashboard'),
                    ),
                    const SizedBox(width: 8),
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
                    if (unreadCount > 0)
                      TextButton(
                        onPressed: _markAllAsRead,
                        child: Text(
                          'Mark all read ($unreadCount)',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                // ── Tabs ────────────────────────────────────────
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                  tabs: [
                    const Tab(text: 'All'),
                    Tab(text: unreadCount > 0 ? 'Unread ($unreadCount)' : 'Unread'),
                    Tab(text: 'Read (${readNotifications.length})'),
                  ],
                ),
              ],
            ),
          ),

          // ── Content ─────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: $_error',
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                                onPressed: _loadNotifications,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildList(_notifications),
                          _buildList(unreadNotifications),
                          _buildList(readNotifications),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<TeacherNotification> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No notifications here',
              style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 15,
                  color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) =>
            _buildNotificationCard(notifications[index]),
      ),
    );
  }

  Widget _buildNotificationCard(TeacherNotification notification) {
    final typeColor = _getTypeColor(notification.type);
    final icon = _getTypeIcon(notification.type);

    return Dismissible(
      key: Key('teacher_notif_${notification.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEC4899),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.done, color: Colors.white),
            Text('Read', style: TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            Text('Delete', style: TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          await _deleteNotification(notification);
          return true;
        } else {
          await _markAsRead(notification);
          return false;
        }
      },
      child: GestureDetector(
        onTap: () => _handleNotificationTap(notification),
        onLongPress: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Delete Notification',
                  style: TextStyle(
                      fontFamily: AppFonts.heading, fontSize: 16)),
              content: const Text('Remove this notification?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444)),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
          if (confirmed == true && mounted) {
            await _deleteNotification(notification);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.white
                : typeColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? const Color(0xFFE2E8F0)
                  : typeColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 13,
                        fontWeight: notification.isRead
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimeAgo(notification.createdAt),
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: typeColor, shape: BoxShape.circle),
                    ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _deleteNotification(notification),
                    child: Icon(Icons.close,
                        size: 16, color: Colors.grey[400]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
