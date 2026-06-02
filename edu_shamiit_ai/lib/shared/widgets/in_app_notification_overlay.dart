import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

/// WhatsApp-style sliding notification banner shown at the top of the screen.
/// Triggered whenever a new unread notification arrives via Supabase realtime.
class InAppNotificationOverlay extends StatefulWidget {
  final String userId;
  final String userRole; // 'student' or 'teacher'
  final Widget child;

  const InAppNotificationOverlay({
    super.key,
    required this.userId,
    required this.userRole,
    required this.child,
  });

  @override
  State<InAppNotificationOverlay> createState() =>
      _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  RealtimeChannel? _channel;
  Timer? _dismissTimer;

  _NotifData? _currentNotif;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _subscribe();
  }

  void _subscribe() {
    _channel = Supabase.instance.client
        .channel('inapp_notif_${widget.userId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: widget.userId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final isRead = record['is_read'] as bool? ?? false;
            if (isRead) return; // Only show unread notifications
            _showBanner(
              title: (record['title'] ?? 'Notification') as String,
              body: (record['body'] ?? record['message'] ?? '') as String,
              type: (record['type'] ?? 'general') as String,
              referenceId: record['reference_id'] as String?,
            );
          },
        )
        .subscribe();
  }

  void _showBanner({
    required String title,
    required String body,
    required String type,
    String? referenceId,
  }) {
    if (!mounted) return;
    _dismissTimer?.cancel();
    setState(() {
      _currentNotif = _NotifData(
          title: title, body: body, type: type, referenceId: referenceId);
    });
    _controller.forward(from: 0);
    HapticFeedback.mediumImpact();
    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) setState(() => _currentNotif = null);
    });
  }

  void _handleTap() {
    _dismiss();
    final notif = _currentNotif;
    if (notif == null) return;
    final normType = notif.type.toLowerCase().trim();
    final route = widget.userRole == 'teacher' ? '/teacher' : '/student';
    if (normType == 'message') {
      final chatParam = notif.referenceId != null
          ? '?chat_id=${notif.referenceId}'
          : '';
      context.push('$route/messaging$chatParam');
    } else {
      context.push('$route/notifications');
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'message':     return const Color(0xFF6366F1);
      case 'homework':    return const Color(0xFFF97316);
      case 'fee':         return const Color(0xFF10B981);
      case 'notice':      return const Color(0xFF8B5CF6);
      case 'attendance':  return const Color(0xFFEF4444);
      case 'exam':        return const Color(0xFF3B82F6);
      case 'salary':      return const Color(0xFF14B8A6);
      default:            return const Color(0xFFEC4899);
    }
  }

  String _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'message':    return '💬';
      case 'homework':   return '📚';
      case 'fee':        return '💰';
      case 'notice':     return '📢';
      case 'attendance': return '✅';
      case 'exam':       return '📝';
      case 'salary':     return '💵';
      default:           return '🔔';
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentNotif != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildBanner(_currentNotif!),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBanner(_NotifData notif) {
    final color = _colorForType(notif.type);
    final icon = _iconForType(notif.type);

    return GestureDetector(
      onTap: _handleTap,
      onVerticalDragUpdate: (details) {
        if (details.delta.dy < -4) _dismiss();
      },
      child: Material(
        elevation: 16,
        borderRadius: BorderRadius.circular(18),
        shadowColor: color.withValues(alpha: 0.35),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                color.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // ── App icon chip ───────────────────────────────────
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.9), color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              // ── Text content ────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'now',
                          style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notif.body,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ── Dismiss button ──────────────────────────────────
              GestureDetector(
                onTap: _dismiss,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 13, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifData {
  final String title;
  final String body;
  final String type;
  final String? referenceId;
  _NotifData(
      {required this.title,
      required this.body,
      required this.type,
      this.referenceId});
}
