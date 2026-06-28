import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:edu_shamiit_academic/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_core/constants/student_colors.dart';
import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_academic/core/providers/student_providers.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';

class StudentNotifications extends ConsumerStatefulWidget {
  const StudentNotifications({super.key});

  @override
  ConsumerState<StudentNotifications> createState() => _StudentNotificationsState();
}

class _StudentNotificationsState extends ConsumerState<StudentNotifications>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      ref.read(notificationsProvider.notifier).fetchNotifications();
      _setupRealtimeSubscription();
    });
  }

  void _setupRealtimeSubscription() {
    if (_realtimeChannel != null) return;
    final currentUserId = ref.read(authProvider).userData?['id'] as String?;
    if (currentUserId == null) return;

    _realtimeChannel = Supabase.instance.client
        .channel('notif_screen_$currentUserId')
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
            ref.read(notificationsProvider.notifier).forceRefresh();
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

  Color _getColorForType(String type) {
    switch (type.toLowerCase().trim()) {
      case 'homework':  return StudentColors.error;
      case 'fee':       return StudentColors.warning;
      case 'result':    return StudentColors.primary;
      case 'transport': return StudentColors.info;
      case 'achievement': return StudentColors.success;
      case 'message':   return const Color(0xFF6366F1);
      case 'notice':    return StudentColors.warning;
      default:          return StudentColors.primary;
    }
  }

  String _getIconForType(String type) {
    switch (type.toLowerCase().trim()) {
      case 'homework':    return '📚';
      case 'fee':         return '💰';
      case 'result':      return '📝';
      case 'transport':   return '🚌';
      case 'achievement': return '🏆';
      case 'message':     return '💬';
      case 'notice':      return '📢';
      default:            return '🔔';
    }
  }

  String _formatTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  void _handleNotificationTap(NotificationItem notif) {
    ref.read(notificationsProvider.notifier).markAsRead(notif.id);
    final normType = notif.type.toLowerCase().trim();
    switch (normType) {
      case 'homework':    context.push('/student/homework'); break;
      case 'fee':         context.push('/student/fees'); break;
      case 'result':      context.push('/student/results'); break;
      case 'transport':   context.push('/student/transport'); break;
      case 'achievement': context.push('/student/achievements'); break;
      case 'notice':      context.push('/student/notices'); break;
      case 'message':
        if (notif.referenceId != null) {
          context.push('/student/messaging?chat_id=${notif.referenceId}');
        } else {
          context.push('/student/messaging');
        }
        break;
      default: break;
    }
  }

  Future<void> _deleteNotification(NotificationItem notif) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Notification', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 16)),
        content: const Text('Remove this notification?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(notificationsProvider.notifier).deleteNotification(notif.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).userData?['id'] as String?;
    if (currentUserId != null && _realtimeChannel == null) {
      Future.microtask(() => _setupRealtimeSubscription());
    }
    final notificationsState = ref.watch(notificationsProvider);
    final allNotifications = notificationsState.notifications;
    final unreadNotifications = allNotifications.where((n) => !n.isRead).toList();
    final readNotifications = allNotifications.where((n) => n.isRead).toList();
    final unreadCount = notificationsState.unreadCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
                16, Responsive.headerTopPadding(context), 16, 0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF302B63)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => safeGoBack(context, '/student/dashboard'),
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
                        onPressed: () =>
                            ref.read(notificationsProvider.notifier).markAllAsRead(),
                        child: Text(
                          'Mark all read ($unreadCount)',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600),
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
                      fontFamily: AppFonts.heading, fontSize: 12, fontWeight: FontWeight.w700),
                  tabs: [
                    const Tab(text: 'All'),
                    Tab(text: unreadCount > 0 ? 'Unread ($unreadCount)' : 'Unread'),
                    Tab(text: 'Read (${readNotifications.length})'),
                  ],
                ),
              ],
            ),
          ),

          // ── Tab views ──────────────────────────────────────────
          Expanded(
            child: notificationsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(allNotifications),
                      _buildList(unreadNotifications),
                      _buildList(readNotifications),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<NotificationItem> notifications) {
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
      onRefresh: () =>
          ref.read(notificationsProvider.notifier).forceRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: notifications.length,
        itemBuilder: (context, index) =>
            _buildNotificationCard(notifications[index]),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notif) {
    final color = _getColorForType(notif.type);
    final icon = _getIconForType(notif.type);
    final bgColor = color.withValues(alpha: 0.08);

    return Dismissible(
      key: Key('notif_${notif.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5),
          borderRadius: BorderRadius.circular(14),
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
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(14),
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
          // Delete
          await ref.read(notificationsProvider.notifier).deleteNotification(notif.id);
          return true;
        } else {
          // Mark as read
          await ref.read(notificationsProvider.notifier).markAsRead(notif.id);
          return false; // Don't remove from list, just mark read
        }
      },
      child: GestureDetector(
        onTap: () => _handleNotificationTap(notif),
        onLongPress: () => _deleteNotification(notif),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: notif.isRead ? Colors.white : bgColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 17))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif.title,
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 12,
                        fontWeight: notif.isRead
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notif.message,
                      style: const TextStyle(fontSize: 11, color: StudentColors.text3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatTime(notif.createdAt),
                      style: const TextStyle(fontSize: 9, color: StudentColors.text3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                children: [
                  if (!notif.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _deleteNotification(notif),
                    child: Icon(Icons.close, size: 14, color: Colors.grey[400]),
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
